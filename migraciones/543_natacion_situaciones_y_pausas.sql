-- 543 · Natación: SITUACIONES del nadador (baja médica, ausencia, exención…)
--       y PAUSA de la cuota (no cobrar uno o más meses) con su motivo
-- ---------------------------------------------------------------------------
-- Criterio de Mario aprobado por Andrés (26-nov-2026): las bajas y exenciones
-- se apuntan con su motivo y una fecha de revisión, y la cuota se PAUSA (no se
-- anula). Mario anuló las de Juani y Andrés Macías porque no había forma.
--   · natacion_situaciones: una fila por situación (abierta / cerrada).
--     sin_cobro + cobro_desde/cobro_hasta (meses; hasta null = «hasta nuevo
--     aviso»). La parte de Stripe (pause_collection) la hace la Edge
--     natacion-pausa, que es la que inserta y cierra las filas con pausa.
--   · natacion_recibos_generar (mes a mes / transferencia) se salta los meses
--     en pausa. natacion_aviso21_pendientes no avisa a quien está en pausa.
--   · natacion_situaciones_listar(): lo que ve la pantalla de Cuotas.
--   · natacion_situacion_guardar / _cerrar: situaciones SIN tocar el cobro.
-- ---------------------------------------------------------------------------
begin;

create table if not exists public.natacion_situaciones (
  id               uuid primary key default gen_random_uuid(),
  atleta_id        uuid not null references public.atletas(id) on delete cascade,
  cuota_id         uuid references public.cuotas_entreno(id) on delete set null,
  tipo             text not null check (tipo in ('baja_medica', 'ausencia', 'exencion', 'rebaja', 'transferencia', 'otra')),
  motivo           text not null check (btrim(motivo) <> ''),
  desde            date not null default ((now() at time zone 'Europe/Madrid')::date),
  revisar_el       date,
  guarda_plaza     boolean not null default true,
  sin_cobro        boolean not null default false,
  cobro_desde      date,          -- primer mes que NO se cobra (día 1)
  cobro_hasta      date,          -- último mes que NO se cobra (día 1); null = hasta nuevo aviso
  stripe_pausa     boolean not null default false,
  stripe_resumes_at timestamptz,
  estado           text not null default 'abierta' check (estado in ('abierta', 'cerrada')),
  cierre_nota      text,
  creado_por       text,
  creado_en        timestamptz not null default now(),
  cerrada_en       timestamptz,
  check (not sin_cobro or cobro_desde is not null),
  check (cobro_hasta is null or cobro_desde is null or cobro_hasta >= cobro_desde)
);
create index if not exists natacion_situaciones_atleta on public.natacion_situaciones (atleta_id) where estado = 'abierta';
alter table public.natacion_situaciones enable row level security;
drop policy if exists "natacion situaciones staff" on public.natacion_situaciones;
create policy "natacion situaciones staff" on public.natacion_situaciones for select to authenticated
  using ((select public.natacion_cuotas_puede()));
grant select on public.natacion_situaciones to authenticated;
comment on table public.natacion_situaciones is
  '543 · Bajas médicas, ausencias, exenciones… de natación, con motivo, fecha de revisión y (si toca) pausa del cobro.';

-- ¿Ese mes de esa cuota está en pausa?
create or replace function public._natacion_mes_en_pausa(p_cuota uuid, p_mes date)
returns boolean
language sql stable security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from public.natacion_situaciones s
     where s.estado = 'abierta' and s.sin_cobro and s.cuota_id = p_cuota
       and date_trunc('month', p_mes)::date >= s.cobro_desde
       and (s.cobro_hasta is null or date_trunc('month', p_mes)::date <= s.cobro_hasta));
$$;
revoke all on function public._natacion_mes_en_pausa(uuid, date) from public, anon, authenticated;
grant execute on function public._natacion_mes_en_pausa(uuid, date) to service_role;

-- Recibos «mes a mes»: igual que en la 431, pero saltando los meses en pausa.
create or replace function public.natacion_recibos_generar(p_hoy date default null)
returns integer
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_hoy  date := coalesce(p_hoy, (now() at time zone 'Europe/Madrid')::date);
  v_q    record;
  v_n    int;
  v_dif  int;
  v_ini  date;
  v_ya   int;
  v_c    int := 0;
begin
  for v_q in select * from public.cuotas_entreno
              where origen = 'natacion' and metodo = 'mes_a_mes'
                and suscripcion_estado <> 'cancelada' and coalesce(cobro_abierto, true)
                and inicio is not null
  loop
    v_n := case v_q.periodicidad when 'mensual' then 1 when 'anual' then 12 else 3 end;
    v_dif := (extract(year from v_hoy)::int * 12 + extract(month from v_hoy)::int)
           - (extract(year from v_q.inicio)::int * 12 + extract(month from v_q.inicio)::int);
    continue when v_dif < 0;
    v_ini := (date_trunc('month', v_q.inicio) + make_interval(months => (v_dif / v_n) * v_n))::date;
    continue when v_q.fin is not null and v_ini > v_q.fin;
    continue when public._natacion_mes_en_pausa(v_q.id, v_ini);   -- 543
    select count(*) into v_ya from public.pagos
     where cuota_entreno_id = v_q.id and periodo = to_char(v_ini, 'YYYY-MM') and not anulado;
    if v_ya = 0 then
      perform public._natacion_recibo_crear(v_q.id, v_ini, null, null, false);
      v_c := v_c + 1;
    end if;
  end loop;
  return v_c;
end;
$$;
revoke all on function public.natacion_recibos_generar(date) from public, anon, authenticated;
grant execute on function public.natacion_recibos_generar(date) to service_role;

-- Lo que enseña la pantalla: situaciones abiertas y las cerradas de los últimos 60 días.
create or replace function public.natacion_situaciones_listar()
returns table (id uuid, atleta_id uuid, cuota_id uuid, tipo text, motivo text, desde date, revisar_el date,
               guarda_plaza boolean, sin_cobro boolean, cobro_desde date, cobro_hasta date, stripe_pausa boolean,
               estado text, cierre_nota text, creado_por text, creado_en timestamptz, cerrada_en timestamptz)
language plpgsql stable security definer
set search_path to 'public'
as $$
#variable_conflict use_column
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede ver las situaciones.' using errcode = '42501';
  end if;
  return query
  select s.id, s.atleta_id, s.cuota_id, s.tipo, s.motivo, s.desde, s.revisar_el, s.guarda_plaza, s.sin_cobro,
         s.cobro_desde, s.cobro_hasta, s.stripe_pausa, s.estado, s.cierre_nota, s.creado_por, s.creado_en, s.cerrada_en
    from public.natacion_situaciones s
   where s.estado = 'abierta' or s.cerrada_en > now() - interval '60 days'
   order by s.estado, s.creado_en desc;
end;
$$;
revoke all on function public.natacion_situaciones_listar() from public, anon;
grant execute on function public.natacion_situaciones_listar() to authenticated, service_role;

-- Apuntar una situación SIN pausar el cobro (p. ej. baja médica que ya no paga
-- porque su cuota terminó, ausencia, nota). Con pausa → Edge natacion-pausa.
create or replace function public.natacion_situacion_guardar(
  p_atleta uuid, p_tipo text, p_motivo text, p_revisar_el date default null, p_guarda_plaza boolean default true)
returns uuid
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_id    uuid;
  v_quien text;
  v_rev   date := p_revisar_el;
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede apuntar situaciones.' using errcode = '42501';
  end if;
  if coalesce(btrim(p_motivo), '') = '' then raise exception 'Escribe el motivo.'; end if;
  if v_rev is null and p_tipo = 'baja_medica' then
    v_rev := (now() at time zone 'Europe/Madrid')::date + 28;   -- criterio: revisar cada 4 semanas
  end if;
  select coalesce(nullif(btrim(nombre), ''), auth.jwt() ->> 'email') into v_quien
    from public.perfiles where email = (auth.jwt() ->> 'email') limit 1;
  insert into public.natacion_situaciones (atleta_id, tipo, motivo, revisar_el, guarda_plaza, creado_por)
  values (p_atleta, p_tipo, btrim(p_motivo), v_rev, coalesce(p_guarda_plaza, true), coalesce(v_quien, auth.jwt() ->> 'email'))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.natacion_situacion_guardar(uuid, text, text, date, boolean) from public, anon;
grant execute on function public.natacion_situacion_guardar(uuid, text, text, date, boolean) to authenticated, service_role;

-- Cerrar una situación SIN pausa de Stripe (las de Stripe las cierra la Edge al reanudar).
-- Con p_revisar_el, en vez de cerrarla la deja para revisar más adelante.
create or replace function public.natacion_situacion_cerrar(p_id uuid, p_nota text default null, p_revisar_el date default null)
returns void
language plpgsql security definer
set search_path to 'public'
as $$
declare v_s public.natacion_situaciones%rowtype;
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede cerrar situaciones.' using errcode = '42501';
  end if;
  select * into v_s from public.natacion_situaciones where id = p_id for update;
  if not found or v_s.estado <> 'abierta' then raise exception 'Esa situación ya está cerrada.'; end if;
  if p_revisar_el is not null then
    update public.natacion_situaciones set revisar_el = p_revisar_el,
           motivo = motivo || coalesce(' · ' || to_char(now() at time zone 'Europe/Madrid', 'DD/MM') || ': ' || nullif(btrim(p_nota), ''), '')
     where id = p_id;
    return;
  end if;
  if v_s.stripe_pausa then raise exception 'Esta pausa está en Stripe: usa «Reanudar el cobro».'; end if;
  update public.natacion_situaciones set estado = 'cerrada', cerrada_en = now(), cierre_nota = nullif(btrim(p_nota), '')
   where id = p_id;
end;
$$;
revoke all on function public.natacion_situacion_cerrar(uuid, text, date) from public, anon;
grant execute on function public.natacion_situacion_cerrar(uuid, text, date) to authenticated, service_role;

commit;

-- (añadido) natacion_aviso21_pendientes: quien tiene el cobro en pausa no recibe «actívala».
create or replace function public.natacion_aviso21_pendientes()
 returns jsonb language sql stable security definer set search_path to 'public'
as $function$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', ce.id,
           'nombre', ce.nombre, 'apellidos', ce.apellidos, 'email', ce.email,
           'importe_cent', ce.importe_cent, 'periodicidad', ce.periodicidad,
           'cargo_inicial_cent', ce.cargo_inicial_cent, 'cargo_inicial_concepto', ce.cargo_inicial_concepto,
           'token', ce.token, 'aviso21_mes', ce.aviso21_mes)
         order by ce.created_at), '[]'::jsonb)
    from public.cuotas_entreno ce
   where ce.origen = 'natacion' and ce.suscripcion_estado = 'pendiente'
     and coalesce(ce.cobro_abierto, true) and ce.token is not null
     and nullif(btrim(coalesce(ce.email, '')), '') is not null
     and coalesce(ce.metodo, '') <> 'mes_a_mes'
     and exists (select 1 from public.natacion_inscripciones i where i.activa and i.atleta_id = ce.atleta_id)
     and not exists (select 1 from public.natacion_situaciones s where s.estado = 'abierta' and s.sin_cobro and s.cuota_id = ce.id);
$function$;
