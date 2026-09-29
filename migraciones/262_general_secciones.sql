-- 262 · Recuento de personas POR SECCIÓN para el Resumen del panel.
-- El KPI viejo decía «357 socios activos +357 esta temporada» (falso: contaba
-- TODOS los atletas como socios y como nuevos). Cada sección tiene su fuente:
--   socios           = tipo_membresia 'socio' o con número de socio
--   familias         = perfiles con papel 'padre'
--   escuela_natacion = nadadores distintos con inscripción activa tipo 'Escuela'
--   natacion_master  = nadadores distintos con inscripción activa tipo 'Máster'
--   cubo             = altas del Cubo aprobadas
--   atletismo        = atletas en grupos de escuela/pista (activos/prueba)
-- SECURITY DEFINER, gated por es_admin()/es_staff() (igual que general_resumen).
begin;

create or replace function public.general_secciones()
 returns jsonb
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select case when not (public.es_admin() or public.es_staff()) then '{}'::jsonb
  else jsonb_build_object(
    'socios',           (select count(*) from atletas where tipo_membresia = 'socio' or numero_socio is not null),
    'familias',         (select count(*) from perfiles where 'padre' = any(roles)),
    'escuela_natacion', (select count(distinct coalesce(atleta_id::text, lower(nombre))) from natacion_inscripciones where activa and tipo = 'Escuela'),
    'natacion_master',  (select count(distinct coalesce(atleta_id::text, lower(nombre))) from natacion_inscripciones where activa and tipo = 'Máster'),
    'cubo',             (select count(*) from cubo_altas where estado = 'aprobada'),
    'atletismo',        (select count(*) from atletas a join grupos g on g.id = a.grupo_id
                          where g.seccion in ('escuela','competicion')
                            and coalesce(a.estado,'activo') in ('activo','prueba','lesionado'))
  ) end
$function$;

grant execute on function public.general_secciones() to authenticated;

commit;
