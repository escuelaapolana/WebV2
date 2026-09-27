-- 242_general_resumen.sql
-- Recuentos del «día a día» para el Resumen del mundo General (portal/general/):
-- altas nuevas, inscripciones/solicitudes, mensajes pendientes… Solo admin/staff.
-- Un único RPC para no depender de las RLS de cada tabla ni hacer N consultas.

create or replace function public.general_resumen()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case when not (public.es_admin() or public.es_staff()) then '{}'::jsonb
  else jsonb_build_object(
    'altas_socio',   (select count(*) from altas_socio   where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'altas_escuela', (select count(*) from altas_escuela where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'cubo_altas',    (select count(*) from cubo_altas    where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'cubo_prueba',   (select count(*) from cubo_prueba),
    'buzon',         (select count(*) from buzon_bandeja where atendido is not true),
    'solicitudes',   (select count(*) from solicitudes_inscripcion where atendida is not true)
  ) end
$$;

grant execute on function public.general_resumen() to authenticated, service_role;
