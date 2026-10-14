-- 360 · El Cubo: «Pausar un mes» la cuota (la pide la persona, la aprueba el club)
-- ------------------------------------------------------------
-- QUÉ ES (reglas de Andrés, 13-14 oct 2026)
--   1) La persona, desde su zona (cubo-cuota.js), con la cuota ACTIVA, pide
--      pausar UN mes (el siguiente cobro que aún esté a tiempo o el de
--      después). Queda «solicitada». El club la aprueba o rechaza en
--      admin/cubo-altas (aviso en el resumen del panel y en general_resumen).
--   2) Antelación de 15 días al cobro de ese mes (el cobro es el día 5):
--      se puede pedir como tarde el DÍA 20 DEL MES ANTERIOR (hora de Madrid).
--   3) Máximo 1 mes por temporada y por cuota. Temporada = sep→ago
--      (sep-jun de curso; jul/ago, si se cobran, cuentan con la que acaba).
--      `temporada` = año en que empieza: nov-2026 → 2026 (2026/27).
--   4) Se le GUARDA LA PLAZA: sigue contando en el aforo (cubo_turno_lleno
--      no cambia), pero en los días de ese mes NO cuenta como que viene
--      (cubo_apuntados_dia → calendario_club) y Claudia lo ve marcado.
--   5) Cobro: al aprobar, la Edge `cubo-pausa` pone `pause_collection`
--      (behavior=void, resumes_at = día 6 a las 12:00 de Madrid del mes
--      pausado) en la suscripción. Si el mes pausado NO es el próximo
--      recibo (p. ej. aprueba en octubre una pausa de diciembre), la pausa
--      se aplica en Stripe DESPUÉS del cobro del mes anterior: lo hace
--      `cubo-webhook` al llegar ese invoice.paid (y, de reserva, el botón
--      «Aplicar en Stripe» del panel). Ver `stripe_aplicada_en`.
--   6) Correo de confirmación (Brevo) al aprobar: lo manda la Edge.
--
-- QUÉ NO TOCA
--   · cubo_altas.suscripcion_estado sigue 'activa' durante la pausa (la
--     suscripción de Stripe sigue 'active'; el recibo del mes sale ANULADO).
--   · cubo_turno_lleno / cubo_aforo / cubo_aforos: sin cambios (la plaza
--     se mantiene).
--
-- ORDEN DE DESPLIEGUE: esta migración → Edge cubo-pausa → cubo-webhook →
-- web (cubo-cuota.js, admin/cubo-altas, admin/index, portal/general,
-- portal/cubo-lista).
-- ============================================================
begin;

-- ---------- 1 · La tabla ----------
create table if not exists public.cubo_pausas (
  id                 uuid primary key default gen_random_uuid(),
  alta_id            uuid not null references public.cubo_altas(id) on delete cascade,
  perfil_id          uuid references public.perfiles(id) on delete set null,
  mes                date not null,               -- día 1 del mes pausado
  temporada          integer generated always as (
                       extract(year from mes)::int
                       - case when extract(month from mes) < 9 then 1 else 0 end
                     ) stored,                    -- 2026 = temporada 2026/27
  estado             text not null default 'solicitada',
  solicitada_en      timestamptz not null default now(),
  decidida_en        timestamptz,
  decidida_por       uuid references public.perfiles(id) on delete set null,
  motivo_rechazo     text,
  stripe_aplicada_en timestamptz,                 -- cuándo se puso pause_collection
  stripe_resumes_at  timestamptz,                 -- hasta cuándo (Stripe la quita sola)
  correo_enviado_en  timestamptz,
  constraint cubo_pausas_mes_dia1 check (extract(day from mes) = 1),
  constraint cubo_pausas_estado_check
    check (estado in ('solicitada', 'aprobada', 'rechazada', 'anulada'))
);

comment on table public.cubo_pausas is
  'El Cubo · «Pausar un mes» la cuota. La pide la persona (cubo_pausa_solicitar), la aprueba el club (Edge cubo-pausa → pause_collection en Stripe) o la rechaza (cubo_pausa_rechazar). 1 por cuota y temporada (sep-ago).';

-- Máximo 1 mes por temporada y cuota (las rechazadas/anuladas no cuentan).
create unique index if not exists cubo_pausas_una_por_temporada
  on public.cubo_pausas (alta_id, temporada)
  where estado in ('solicitada', 'aprobada');
create index if not exists cubo_pausas_mes_idx on public.cubo_pausas (mes) where estado = 'aprobada';
create index if not exists cubo_pausas_perfil_idx on public.cubo_pausas (perfil_id);

alter table public.cubo_pausas enable row level security;
-- Solo lectura: la propia persona, el club, Claudia (cubo-lista) y monitores
-- del Cubo. Nadie escribe directo: todo por las funciones de abajo.
drop policy if exists cubo_pausas_lee on public.cubo_pausas;
create policy cubo_pausas_lee on public.cubo_pausas for select to authenticated
  using (perfil_id = public.mi_perfil_id() or public.es_admin()
         or public.es_cubo_lista() or public.cubo_es_gestor());
revoke all on public.cubo_pausas from anon;
revoke insert, update, delete, truncate on public.cubo_pausas from authenticated;
grant select on public.cubo_pausas to authenticated;

-- ---------- 2 · Reglas de calendario (una sola fuente) ----------
-- Último día para PEDIR la pausa de un mes: el 20 del mes anterior
-- (15 días antes del cobro del día 5).
create or replace function public.cubo_pausa_limite(p_mes date)
returns date language sql immutable as $$
  select (date_trunc('month', p_mes) - interval '1 month')::date + 19;
$$;

-- Meses que esta cuota puede pedir HOY: los 2 próximos cobros que aún
-- están a tiempo (≥ 15 días), quitando los de una temporada ya usada.
create or replace function public.cubo_pausa_meses(p_alta uuid)
returns setof date
language sql stable security definer set search_path to 'public' as $$
  with hoy as (select (now() at time zone 'Europe/Madrid')::date as d),
  cand as (
    select (date_trunc('month', hoy.d) + make_interval(months => k))::date as m
      from hoy, generate_series(1, 3) k
     where hoy.d <= public.cubo_pausa_limite(
             (date_trunc('month', hoy.d) + make_interval(months => k))::date)
     order by 1
     limit 2
  )
  select c.m from cand c
   where not exists (
     select 1 from public.cubo_pausas p
      where p.alta_id = p_alta and p.estado in ('solicitada', 'aprobada')
        and p.temporada = extract(year from c.m)::int
                          - case when extract(month from c.m) < 9 then 1 else 0 end)
   order by 1;
$$;
revoke all on function public.cubo_pausa_meses(uuid) from public, anon, authenticated;

-- La cuota de la persona que llama que puede pausarse (la que ya paga).
create or replace function public.cubo_pausa_mi_alta()
returns uuid
language sql stable security definer set search_path to 'public' as $$
  select a.id from public.cubo_altas a
   where a.perfil_id = public.mi_perfil_id()
     and a.estado = 'aprobada'
     and a.suscripcion_estado = 'activa'
     and a.stripe_subscription_id is not null
   order by a.created_at desc
   limit 1;
$$;
revoke all on function public.cubo_pausa_mi_alta() from public, anon, authenticated;

-- ---------- 3 · Lo que ve la persona ----------
-- { ok, puede, meses:[{mes, limite}], pausas:[{id, mes, estado, ...}], motivo }
create or replace function public.cubo_pausa_mia()
returns jsonb
language plpgsql stable security definer set search_path to 'public' as $$
declare
  v_alta uuid := public.cubo_pausa_mi_alta();
  v_baja timestamptz;
  v_meses jsonb;
  v_pausas jsonb;
begin
  if v_alta is null then
    return jsonb_build_object('ok', true, 'puede', false, 'motivo', 'sin_cuota_activa',
                              'meses', '[]'::jsonb, 'pausas', '[]'::jsonb);
  end if;
  select baja_solicitada into v_baja from public.cubo_altas where id = v_alta;

  select coalesce(jsonb_agg(jsonb_build_object('mes', m, 'limite', public.cubo_pausa_limite(m)) order by m), '[]'::jsonb)
    into v_meses from public.cubo_pausa_meses(v_alta) m;

  -- Las de esta temporada en adelante (para pintar «solicitada»/«en pausa»).
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', p.id, 'mes', p.mes, 'estado', p.estado,
           'solicitada_en', p.solicitada_en, 'decidida_en', p.decidida_en,
           'motivo_rechazo', p.motivo_rechazo) order by p.mes desc, p.solicitada_en desc), '[]'::jsonb)
    into v_pausas
    from public.cubo_pausas p
   where p.alta_id = v_alta
     and p.mes >= date_trunc('month', (now() at time zone 'Europe/Madrid')::date)::date - interval '1 month';

  return jsonb_build_object(
    'ok', true,
    'alta_id', v_alta,
    'puede', v_baja is null and jsonb_array_length(v_meses) > 0,
    'motivo', case when v_baja is not null then 'baja_solicitada'
                   when jsonb_array_length(v_meses) = 0 then 'sin_meses' end,
    'meses', v_meses,
    'pausas', v_pausas);
end; $$;
grant execute on function public.cubo_pausa_mia() to authenticated;

-- ---------- 4 · Pedirla (la persona) ----------
create or replace function public.cubo_pausa_solicitar(p_mes date)
returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare
  v_alta   uuid := public.cubo_pausa_mi_alta();
  v_perfil uuid := public.mi_perfil_id();
  v_mes    date := date_trunc('month', p_mes)::date;
  v_id     uuid;
begin
  if v_perfil is null then
    return jsonb_build_object('ok', false, 'motivo', 'sin_sesion', 'error', 'Entra en tu cuenta.');
  end if;
  if v_alta is null then
    return jsonb_build_object('ok', false, 'motivo', 'sin_cuota_activa',
      'error', 'Solo se puede pausar una cuota activa.');
  end if;
  if exists (select 1 from public.cubo_altas where id = v_alta and baja_solicitada is not null) then
    return jsonb_build_object('ok', false, 'motivo', 'baja_solicitada',
      'error', 'Ya has pedido la baja; no hace falta pausar.');
  end if;
  if p_mes is null or v_mes not in (select m from public.cubo_pausa_meses(v_alta) m) then
    return jsonb_build_object('ok', false, 'motivo', 'mes_no_valido',
      'error', 'Ese mes no se puede pausar: hay que pedirlo como tarde el día 20 del mes anterior, y solo un mes por temporada.');
  end if;

  insert into public.cubo_pausas (alta_id, perfil_id, mes)
  values (v_alta, v_perfil, v_mes)
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id, 'mes', v_mes);
exception when unique_violation then
  return jsonb_build_object('ok', false, 'motivo', 'ya_tiene',
    'error', 'Ya tienes una pausa pedida o aprobada esta temporada (máximo un mes).');
end; $$;
grant execute on function public.cubo_pausa_solicitar(date) to authenticated;

-- Retirar la propia solicitud mientras el club no la ha decidido.
create or replace function public.cubo_pausa_anular(p_id uuid)
returns jsonb
language plpgsql security definer set search_path to 'public' as $$
begin
  update public.cubo_pausas
     set estado = 'anulada', decidida_en = now()
   where id = p_id and perfil_id = public.mi_perfil_id() and estado = 'solicitada';
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Esa solicitud ya no se puede retirar.');
  end if;
  return jsonb_build_object('ok', true);
end; $$;
grant execute on function public.cubo_pausa_anular(uuid) to authenticated;

-- ---------- 5 · Decidir (el club) ----------
-- Rechazar: no toca Stripe, va directo desde el panel.
create or replace function public.cubo_pausa_rechazar(p_id uuid, p_motivo text default null)
returns jsonb
language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede decidir las pausas del Cubo.' using errcode = '42501';
  end if;
  update public.cubo_pausas
     set estado = 'rechazada', decidida_en = now(), decidida_por = public.mi_perfil_id(),
         motivo_rechazo = nullif(btrim(coalesce(p_motivo, '')), '')
   where id = p_id and estado = 'solicitada';
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Esa solicitud ya no está pendiente.');
  end if;
  return jsonb_build_object('ok', true);
end; $$;
grant execute on function public.cubo_pausa_rechazar(uuid, text) to authenticated;

-- Datos para APROBAR (los pide la Edge cubo-pausa CON EL JWT del admin: así
-- la comprobación de admin la hace la base). Incluye cuándo quitar la pausa:
-- día 6 a las 12:00 de Madrid del mes pausado (el cobro es el día 5 ~10:00).
create or replace function public.cubo_pausa_para_aprobar(p_id uuid)
returns jsonb
language plpgsql stable security definer set search_path to 'public' as $$
declare
  p public.cubo_pausas;
  a public.cubo_altas;
  v_email text;
  v_hoy date := (now() at time zone 'Europe/Madrid')::date;
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede aprobar las pausas del Cubo.' using errcode = '42501';
  end if;
  select * into p from public.cubo_pausas where id = p_id;
  if not found then return jsonb_build_object('ok', false, 'error', 'Esa solicitud ya no está.'); end if;
  select * into a from public.cubo_altas where id = p.alta_id;
  select email into v_email from public.perfiles where id = coalesce(a.perfil_id, p.perfil_id);
  return jsonb_build_object(
    'ok', true,
    'id', p.id, 'estado', p.estado, 'mes', p.mes,
    'alta_id', a.id, 'nombre', a.nombre, 'apellidos', a.apellidos, 'horario', a.horario,
    'precio_mes', a.precio_mes,
    'suscripcion_estado', a.suscripcion_estado,
    'stripe_subscription_id', a.stripe_subscription_id,
    'email', v_email,
    -- Aún a tiempo de que Stripe no cobre: hasta el día 4 (incluido).
    'a_tiempo', v_hoy < p.mes + 4,
    'resumes_at', extract(epoch from (((p.mes + 5)::timestamp + interval '12 hours') at time zone 'Europe/Madrid'))::bigint,
    'stripe_aplicada_en', p.stripe_aplicada_en,
    'correo_enviado_en', p.correo_enviado_en);
end; $$;
grant execute on function public.cubo_pausa_para_aprobar(uuid) to authenticated;

-- Apuntar en la base lo que la Edge/webhook ya hizo en Stripe. SOLO la llave
-- de servicio (Edge cubo-pausa y cubo-webhook): así un admin desde el
-- navegador no puede dejar una pausa «aprobada» sin haber pasado por Stripe.
--   p_aprobar  → solicitada → aprobada (decidida_por = perfil de p_por_email)
--   p_resumes  → si no es null: stripe_aplicada_en = now(), stripe_resumes_at
create or replace function public.cubo_pausa_registrar(
  p_id uuid, p_aprobar boolean, p_por_email text default null, p_resumes timestamptz default null)
returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare v public.cubo_pausas;
begin
  select * into v from public.cubo_pausas where id = p_id for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'no_existe'); end if;
  if p_aprobar then
    if v.estado not in ('solicitada', 'aprobada') then
      return jsonb_build_object('ok', false, 'error', 'estado_' || v.estado);
    end if;
    update public.cubo_pausas
       set estado = 'aprobada',
           decidida_en = coalesce(decidida_en, now()),
           decidida_por = coalesce(decidida_por,
             (select id from public.perfiles where lower(email) = lower(p_por_email) limit 1))
     where id = p_id;
  elsif v.estado <> 'aprobada' then
    return jsonb_build_object('ok', false, 'error', 'no_aprobada');
  end if;
  if p_resumes is not null then
    update public.cubo_pausas
       set stripe_aplicada_en = coalesce(stripe_aplicada_en, now()),
           stripe_resumes_at = p_resumes
     where id = p_id;
  end if;
  return jsonb_build_object('ok', true);
end; $$;
revoke all on function public.cubo_pausa_registrar(uuid, boolean, text, timestamptz) from public, anon, authenticated;
grant execute on function public.cubo_pausa_registrar(uuid, boolean, text, timestamptz) to service_role;

-- ---------- 6 · Apuntados del día: el que está en pausa ese mes no viene ----------
-- (copia de la 332 + la condición de la pausa; la Fuerza gratis no cambia)
create or replace function public.cubo_apuntados_dia(p_grupo uuid, p_fecha date)
returns integer
language sql stable security definer set search_path to 'public' as $$
  with g as (
    select id, nombre from public.grupos where id = p_grupo and seccion = 'cubo'
  ),
  t as (
    select case extract(isodow from p_fecha)::int
             when 5 then 'viernes' when 6 then 'sabado' when 7 then 'domingo' end as turno,
           extract(isodow from p_fecha)::smallint as dsem
  )
  select case
    when (select nombre from g) ~* 'fuerza\s*gratis' then
      (select count(*) from public.cubo_prueba p, t
        where p.estado <> 'cancelado' and t.turno = any(p.turnos)
          and not exists (select 1 from public.cubo_ausencias ca
                           where ca.perfil_id = p.perfil_id and ca.fecha = p_fecha))
    else
      (select count(*) from public.cubo_altas a, g, t
        where a.estado = 'aprobada' and a.horario = g.nombre and not a.lista_espera
          and (a.dias_semana is null or cardinality(a.dias_semana) = 0 or t.dsem = any(a.dias_semana))
          and not exists (select 1 from public.cubo_ausencias ca
                           where ca.perfil_id = a.perfil_id and ca.fecha = p_fecha)
          -- [360] en pausa ese mes: guarda la plaza pero no viene
          and not exists (select 1 from public.cubo_pausas cp
                           where cp.alta_id = a.id and cp.estado = 'aprobada'
                             and cp.mes = date_trunc('month', p_fecha)::date))
  end::int;
$$;

-- ---------- 7 · Resumen del mundo General: pausas por decidir ----------
-- (copia exacta de la vigente + 'cubo_pausas')
create or replace function public.general_resumen()
returns jsonb
language sql stable security definer set search_path to 'public' as $$
  select case when not (public.es_admin() or public.es_staff()) then '{}'::jsonb
  else jsonb_build_object(
    'altas_socio',   (select count(*) from altas_socio   where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'altas_escuela', (select count(*) from altas_escuela where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'cubo_altas',    (select count(*) from cubo_altas    where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'cubo_prueba',   (select count(*) from cubo_prueba),
    'cubo_prueba_decidir', (
       select count(*) from cubo_altas ca
       where ca.estado = 'aprobada'
         and ca.suscripcion_estado is distinct from 'activa'
         and not coalesce(ca.cobro_abierto, false)
         and not coalesce(ca.lista_espera, false)
         and ca.pago_externo is null
         and ca.confirmado_sigue is null
         and ca.atleta_id is not null
         and (select count(*) from asistencia a
                join grupos g on g.id = a.grupo_id and g.seccion = 'cubo'
              where a.atleta_id = ca.atleta_id and a.presente = true) >= 2),
    'cubo_pausas',   (select count(*) from cubo_pausas where estado = 'solicitada'),
    'buzon',         (select count(*) from buzon_bandeja where atendido is not true),
    'solicitudes',   (select count(*) from solicitudes_inscripcion
                       where atendida is not true
                         and coalesce(comentario,'') not ilike 'SOLICITUD DE PRUEBA%'),
    'liga_validar',  (select count(*) from liga_participaciones where estado = 'pendiente')
  ) end
$$;

commit;
