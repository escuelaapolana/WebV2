-- 272_natacion_lista_espera.sql
-- Natación · LISTA DE ESPERA (versión A: aviso a todos, primero que reserve).
-- Pedido por Lucas/Mario: en las franjas llenas, apuntarse a una lista; cuando
-- alguien marca «no voy» (se libera un hueco), AVISAR por push a los que esperan
-- para que el primero que reserve se lo quede. Así nadie tiene que estar mirando.
--
-- Piezas:
--   · tabla natacion_lista_espera (quién espera qué franja).
--   · RPCs apuntarse / quitarse / mías / de-franja (gestor).
--   · natacion_espera_avisar(franja, fecha): manda el push a los que esperan.
--   · trigger en natacion_ausencias: cualquier «no voy» (master/familia/marcar)
--     dispara el aviso. Patrón de push dirigido copiado de sesion_solicitud_avisa.
-- El correo queda para una segunda pasada (necesita Edge; el push ya es instantáneo).

begin;

-- 1) Tabla
create table if not exists public.natacion_lista_espera (
  id         uuid primary key default gen_random_uuid(),
  franja_id  uuid not null references public.natacion_franjas(id) on delete cascade,
  perfil_id  uuid references public.perfiles(id) on delete cascade,
  atleta_id  uuid references public.atletas(id) on delete set null,
  nombre     text,
  activa     boolean not null default true,
  creado_en  timestamptz not null default now(),
  avisado_en timestamptz
);
create index if not exists nat_espera_franja_idx on public.natacion_lista_espera (franja_id) where activa;
create index if not exists nat_espera_perfil_idx on public.natacion_lista_espera (perfil_id) where activa;
-- No duplicar: una persona (y, si acaso, un atleta concreto) una vez por franja.
create unique index if not exists nat_espera_uniq on public.natacion_lista_espera
  (franja_id, perfil_id, (coalesce(atleta_id, '00000000-0000-0000-0000-000000000000'::uuid)));

-- Acceso solo por las RPC (SECURITY DEFINER). Nada directo.
alter table public.natacion_lista_espera enable row level security;
revoke all on public.natacion_lista_espera from anon, authenticated;

-- 2) Avisar a los que esperan una franja (push). Lo llama el trigger.
create or replace function public.natacion_espera_avisar(p_franja uuid, p_fecha date)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_rec    record;
  v_n      integer := 0;
  v_franja text;
  v_cuando text := to_char(p_fecha, 'DD/MM');
begin
  select coalesce(nullif(btrim(f.grupo), ''), 'Natación') || ' · ' || to_char(f.hora, 'HH24:MI')
    into v_franja
  from public.natacion_franjas f where f.id = p_franja;
  if v_franja is null then return 0; end if;

  for v_rec in
    select le.id, le.perfil_id
    from public.natacion_lista_espera le
    where le.franja_id = p_franja
      and le.activa
      and le.perfil_id is not null
      and (le.avisado_en is null or le.avisado_en < now() - interval '1 hour')
  loop
    perform public.avisos_registrar(
      'Se ha liberado un hueco en natación',
      'Hay sitio en ' || v_franja || ' el ' || v_cuando || '. El primero que reserve se lo queda.',
      'natacion/',
      'persona', 'entrenos',
      null, null, v_rec.perfil_id,
      'Lista de espera', 0, 0, null, null, 'importante', null, true, '{}'
    );
    perform public.avisos_cola_movil_poner('nat_hueco', v_rec.perfil_id);
    update public.natacion_lista_espera set avisado_en = now() where id = v_rec.id;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- 3) Trigger: cualquier «no voy» (insert en natacion_ausencias) avisa a la lista.
--    Envuelto: si el aviso falla, la ausencia queda guardada igual.
create or replace function public.trg_natacion_ausencia_avisa()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  begin
    perform public.natacion_espera_avisar(NEW.franja_id, NEW.fecha);
  exception when others then
    null;
  end;
  return null;
end;
$$;

drop trigger if exists natacion_ausencia_avisa on public.natacion_ausencias;
create trigger natacion_ausencia_avisa
  after insert on public.natacion_ausencias
  for each row execute function public.trg_natacion_ausencia_avisa();

-- 4) Apuntarse a la lista de espera de una franja
create or replace function public.natacion_espera_apuntarse(p_franja uuid, p_atleta uuid default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_perfil uuid := public.mi_perfil_id();
  v_nombre text;
  v_id     uuid;
begin
  if v_perfil is null then
    raise exception 'Entra en tu cuenta para apuntarte a la lista de espera.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.natacion_franjas where id = p_franja and activa) then
    raise exception 'Esa franja no existe.' using errcode = 'P0001';
  end if;
  -- El atleta solo si es suyo (o de un hijo); si no, se guarda sin atleta.
  if p_atleta is not null and not exists (
    select 1 from public.atletas a
    where a.id = p_atleta and (a.perfil_id = v_perfil or a.perfil_padre_id = v_perfil)
  ) then
    p_atleta := null;
  end if;

  select nullif(btrim(coalesce(p.nombre, '') || ' ' || coalesce(p.apellidos, '')), '')
    into v_nombre from public.perfiles p where p.id = v_perfil;
  if p_atleta is not null then
    select nullif(btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')), '')
      into v_nombre from public.atletas a where a.id = p_atleta;
  end if;

  update public.natacion_lista_espera
     set activa = true,
         nombre = coalesce(v_nombre, nombre),
         avisado_en = null
   where franja_id = p_franja and perfil_id = v_perfil
     and coalesce(atleta_id, '00000000-0000-0000-0000-000000000000'::uuid)
         = coalesce(p_atleta, '00000000-0000-0000-0000-000000000000'::uuid)
   returning id into v_id;

  if v_id is null then
    insert into public.natacion_lista_espera (franja_id, perfil_id, atleta_id, nombre, activa)
    values (p_franja, v_perfil, p_atleta, v_nombre, true)
    returning id into v_id;
  end if;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

-- 5) Quitarse (uno mismo, o el gestor)
create or replace function public.natacion_espera_quitarse(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_perfil uuid := public.mi_perfil_id(); v_n int;
begin
  update public.natacion_lista_espera
     set activa = false
   where id = p_id and (perfil_id = v_perfil or public.soy_gestor_natacion());
  get diagnostics v_n = row_count;
  return jsonb_build_object('ok', v_n > 0);
end;
$$;

-- 6) Mis esperas (para pintar el estado en el portal)
create or replace function public.natacion_espera_mias()
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', le.id, 'franja_id', le.franja_id,
      'dia', f.dia, 'hora', to_char(f.hora, 'HH24:MI'), 'grupo', f.grupo,
      'atleta_id', le.atleta_id, 'nombre', le.nombre,
      'avisado', le.avisado_en is not null
    ) order by f.dia, f.hora), '[]'::jsonb)
  from public.natacion_lista_espera le
  join public.natacion_franjas f on f.id = le.franja_id
  where le.activa and le.perfil_id = public.mi_perfil_id();
$$;

-- 7) Quién espera una franja (solo gestor de natación)
create or replace function public.natacion_espera_de_franja(p_franja uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not public.soy_gestor_natacion() then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', le.id, 'nombre', le.nombre, 'atleta_id', le.atleta_id,
        'creado_en', le.creado_en, 'avisado_en', le.avisado_en
      ) order by le.creado_en)
    from public.natacion_lista_espera le
    where le.franja_id = p_franja and le.activa
  ), '[]'::jsonb);
end;
$$;

-- Permisos: las RPC públicas para authenticated; avisar/trigger solo internas.
revoke all on function public.natacion_espera_avisar(uuid, date) from public, anon, authenticated;
grant execute on function public.natacion_espera_apuntarse(uuid, uuid) to authenticated;
grant execute on function public.natacion_espera_quitarse(uuid)        to authenticated;
grant execute on function public.natacion_espera_mias()                to authenticated;
grant execute on function public.natacion_espera_de_franja(uuid)       to authenticated;

commit;
