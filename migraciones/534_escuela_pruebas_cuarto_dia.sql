-- ============================================================
-- 534 · Escuela de atletismo · aviso cuando un niño de prueba hace su 4.º entrenamiento
-- ------------------------------------------------------------
-- Pedido por Andrés (17-nov-2026): «cuando un niño o niña finaliza las 4 sesiones de
-- prueba, justo cuando cumpla el 4.º día, me notificas al correo de Adriana para que le
-- pregunte al tutor si formalizan o no».
--
-- Cómo se cuentan los entrenamientos de un niño «de prueba» (desde que entra en la app):
--   · los días que su entrenador pasa lista y le marca PRESENTE (cualquier grupo);
--   · los días de clase de SU grupo en que nadie pasó lista (los del turno de las 18:30
--     no pasan lista), desde el día siguiente a su alta y sin los días cancelados
--     (calendario de excepciones de la escuela). Si se pasó lista y no vino, no cuenta.
-- Con 4 o más, entra en la cola escuela_pruebas_aviso. Cada noche a las 20:00 la Edge
-- escuela-isa-sync ({avisar_pruebas: true}) manda UN correo a escuela_avisos_destinos
-- (Adriana) con los que han cumplido y les pone avisado_en. Sin pendientes, no sale nada.
-- Los municipales no hacen prueba (altas directas): no entran.
-- Quien ya había hecho los 4 antes de hoy queda como «previo» (no se avisa: «a partir de ahora»).
-- ============================================================
begin;

create table if not exists public.escuela_pruebas_aviso (
  atleta_id  uuid primary key references public.atletas(id) on delete cascade,
  cuarto_dia date not null,
  sesiones   jsonb not null default '[]'::jsonb,
  previo     boolean not null default false,   -- ya los había cumplido al montar el aviso
  avisado_en timestamptz,
  creado_en  timestamptz not null default now()
);
alter table public.escuela_pruebas_aviso enable row level security;
drop policy if exists "admin ve avisos de prueba" on public.escuela_pruebas_aviso;
create policy "admin ve avisos de prueba" on public.escuela_pruebas_aviso
  for select to authenticated using ((select public.es_admin()));

-- Entrenamientos de prueba de un niño hasta p_hoy: {sesiones:[{fecha,como}], faltas:[fecha]}
--   como = 'vino' (lista pasada, presente) | 'sin lista' (su grupo no pasó lista ese día)
create or replace function public._escuela_prueba_sesiones(p_atleta uuid, p_hoy date)
returns jsonb
language sql stable security definer
set search_path = public
as $$
  with a as (
    select a.id, (a.created_at at time zone 'Europe/Madrid')::date inicio, a.escuela_dias
      from public.atletas a where a.id = p_atleta
  ), g as (
    select g.id, g.horario
      from public.atleta_grupos ag join public.grupos g on g.id = ag.grupo_id
     where ag.atleta_id = p_atleta and g.seccion = 'escuela' and coalesce(g.activo, true)
     order by ag.principal desc nulls last
     limit 1
  ), dg as (   -- días del grupo (1 = lunes … 7 = domingo), sacados de «Lunes y miércoles 17:30-18:30 · …»
    select array(
      select v.d from (values ('lunes',1),('martes',2),('miercoles',3),('jueves',4),('viernes',5),('sabado',6),('domingo',7)) v(w, d)
       where translate(lower(split_part(g.horario, ' · ', 1)), 'áéíóú', 'aeiou') ~ ('\m' || v.w || '\M')) dias
      from g
  ), dk as (   -- si el niño solo viene algunos días (escuela_dias), esos
    select case when a.escuela_dias is not null and exists (select 1 from unnest(a.escuela_dias) x where x = any(dg.dias))
                then array(select x from unnest(a.escuela_dias) x where x = any(dg.dias))
                else dg.dias end dias
      from a, dg
  ), vino as (
    select distinct s.fecha, 'vino'::text como
      from public.asistencia s, a
     where s.atleta_id = a.id and s.presente and s.fecha between a.inicio and p_hoy
  ), sin_lista as (
    select d::date fecha, 'sin lista'::text como
      from a, g, dk, generate_series(a.inicio + 1, p_hoy, interval '1 day') d
     where extract(isodow from d)::int = any(dk.dias)
       and coalesce((public.excepcion_del_dia(d::date, 'escuela') ->> 'cancelado')::boolean, false) = false
       and not exists (select 1 from public.asistencia s where s.grupo_id = g.id and s.fecha = d::date)
       and not exists (select 1 from public.asistencia s where s.atleta_id = a.id and s.fecha = d::date)
  ), faltas as (   -- (informativo) días con lista en su grupo en que no vino, desde el día siguiente al alta
    select d::date fecha
      from a, g, dk, generate_series(a.inicio + 1, p_hoy, interval '1 day') d
     where extract(isodow from d)::int = any(dk.dias)
       and exists (select 1 from public.asistencia s where s.grupo_id = g.id and s.fecha = d::date)
       and not exists (select 1 from public.asistencia s where s.atleta_id = a.id and s.fecha = d::date and s.presente)
  )
  select jsonb_build_object(
    'sesiones', coalesce((select jsonb_agg(jsonb_build_object('fecha', t.fecha, 'como', t.como) order by t.fecha)
                            from (select * from vino union all select * from sin_lista) t), '[]'::jsonb),
    'faltas',   coalesce((select jsonb_agg(f.fecha order by f.fecha) from faltas f), '[]'::jsonb));
$$;
revoke all on function public._escuela_prueba_sesiones(uuid, date) from public, anon, authenticated;

-- Mete en la cola a quien ya ha hecho 4 y devuelve los pendientes de avisar, con todo lo
-- que lleva el correo (grupo, monitor, entrenamientos, familia). La llama la Edge.
create or replace function public.escuela_pruebas_revisar()
returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
  v_hoy date := (now() at time zone 'Europe/Madrid')::date;
begin
  insert into public.escuela_pruebas_aviso (atleta_id, cuarto_dia, sesiones)
  select x.id, (x.s -> 'sesiones' -> 3 ->> 'fecha')::date, x.s -> 'sesiones'
    from (select a.id, public._escuela_prueba_sesiones(a.id, v_hoy) s
            from public.atletas a
           where a.estado = 'prueba' and a.anonimizado_en is null
             and coalesce(a.tipo_membresia, '') <> 'municipal'
             and (a.tipo_membresia = 'escuela' or 'escuela' = any(coalesce(a.secciones, '{}')))) x
   where jsonb_array_length(x.s -> 'sesiones') >= 4
  on conflict (atleta_id) do nothing;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'atleta_id',     a.id,
             'nombre',        initcap(lower(btrim(a.nombre || ' ' || coalesce(a.apellidos, '')))),
             'nombre_pila',   initcap(lower(split_part(btrim(a.nombre), ' ', 1))),
             'grupo',         g.nombre,
             'grupo_horario', g.horario,
             'monitor',       nullif(btrim(coalesce(g.monitor, '')), ''),
             'alta',          (a.created_at at time zone 'Europe/Madrid')::date,
             'cuarto_dia',    q.cuarto_dia,
             'sesiones',      (select jsonb_agg(e) from (select e from jsonb_array_elements(q.sesiones) e limit 4) z),
             'faltas',        public._escuela_prueba_sesiones(a.id, q.cuarto_dia) -> 'faltas',
             'tutor',         nullif(btrim(coalesce(a.nombre_tutor, '')), ''),
             'telefono',      nullif(btrim(coalesce(a.telefono_tutor, a.telefono, '')), ''))
           order by q.cuarto_dia, a.nombre)
      from public.escuela_pruebas_aviso q
      join public.atletas a on a.id = q.atleta_id
      left join lateral (
        select g.nombre, g.horario, p.nombre monitor
          from public.atleta_grupos ag join public.grupos g on g.id = ag.grupo_id
          left join public.perfiles p on p.id = g.entrenador_id
         where ag.atleta_id = a.id and g.seccion = 'escuela'
         order by ag.principal desc nulls last limit 1) g on true
     where q.avisado_en is null and not q.previo and a.estado = 'prueba'), '[]'::jsonb);
end $$;
revoke all on function public.escuela_pruebas_revisar() from public, anon, authenticated;
grant execute on function public.escuela_pruebas_revisar() to service_role;

create or replace function public.escuela_pruebas_marcar(p_ids uuid[])
returns integer
language sql security definer
set search_path = public
as $$
  with m as (
    update public.escuela_pruebas_aviso set avisado_en = now()
     where atleta_id = any(p_ids) and avisado_en is null
    returning 1)
  select count(*)::int from m;
$$;
revoke all on function public.escuela_pruebas_marcar(uuid[]) from public, anon, authenticated;
grant execute on function public.escuela_pruebas_marcar(uuid[]) to service_role;

-- «A partir de ahora»: quien ya hizo su 4.º entrenamiento antes de hoy queda como previo.
insert into public.escuela_pruebas_aviso (atleta_id, cuarto_dia, sesiones, previo)
select x.id, (x.s -> 'sesiones' -> 3 ->> 'fecha')::date, x.s -> 'sesiones', true
  from (select a.id, public._escuela_prueba_sesiones(a.id, (now() at time zone 'Europe/Madrid')::date - 1) s
          from public.atletas a
         where a.estado = 'prueba' and a.anonimizado_en is null
           and coalesce(a.tipo_membresia, '') <> 'municipal'
           and (a.tipo_membresia = 'escuela' or 'escuela' = any(coalesce(a.secciones, '{}')))) x
 where jsonb_array_length(x.s -> 'sesiones') >= 4
on conflict (atleta_id) do nothing;

-- Cada noche a las 20:00 (hora de Madrid, invierno y verano), después de las clases.
select cron.unschedule('apolana-escuela-pruebas') where exists (select 1 from cron.job where jobname = 'apolana-escuela-pruebas');
select cron.schedule('apolana-escuela-pruebas', '0 18,19 * * *',
  $c$ select public.cron_llamar_edge('escuela-isa-sync', '{"avisar_pruebas": true}'::jsonb, 20) $c$);

commit;
