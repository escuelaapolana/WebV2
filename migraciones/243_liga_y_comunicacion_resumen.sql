-- 243_liga_y_comunicacion_resumen.sql
-- (a) general_resumen: añade «participaciones de liga por validar» (los que
--     quieren validar sus puntos) — lo ven admin/staff.
-- (b) comunicacion_resumen: el «día a día» del mundo Comunicación (liga por
--     validar, próximas carreras, peticiones de redes) — lo ven admin/staff y
--     el responsable de comunicación (p. ej. Mario).

create or replace function public.general_resumen()
returns jsonb language sql stable security definer set search_path = public as $$
  select case when not (public.es_admin() or public.es_staff()) then '{}'::jsonb
  else jsonb_build_object(
    'altas_socio',   (select count(*) from altas_socio   where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'altas_escuela', (select count(*) from altas_escuela where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'cubo_altas',    (select count(*) from cubo_altas    where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'cubo_prueba',   (select count(*) from cubo_prueba),
    'buzon',         (select count(*) from buzon_bandeja where atendido is not true),
    'solicitudes',   (select count(*) from solicitudes_inscripcion where atendida is not true),
    'liga_validar',  (select count(*) from liga_participaciones where estado = 'pendiente')
  ) end
$$;

create or replace function public.comunicacion_resumen()
returns jsonb language sql stable security definer set search_path = public as $$
  select case when not (public.es_admin() or public.es_staff() or public.soy_responsable('comunicacion')) then '{}'::jsonb
  else jsonb_build_object(
    'liga_validar',      (select count(*) from liga_participaciones where estado = 'pendiente'),
    'competis_proximas', (select count(*) from competiciones where fecha_inicio >= current_date),
    'competis_insc',     (select count(*) from competiciones where inscripcion_abierta is true),
    'redes',             (select count(*) from peticiones_redes where coalesce(estado,'nueva') not in ('publicada','rechazada','hecha','resuelta','descartada'))
  ) end
$$;

grant execute on function public.general_resumen()      to authenticated, service_role;
grant execute on function public.comunicacion_resumen() to authenticated, service_role;
