-- 289 · Inicio · separar el KPI «Atletismo pista/escuela» en dos: Atletismo pista
-- (grupos de competición) y Escuela de atletismo (grupos de escuela). No es lo
-- mismo. Sustituye la clave 'atletismo' por 'atletismo_pista' y 'escuela_atletismo'.

create or replace function public.general_secciones()
returns jsonb
language sql stable security definer set search_path to 'public'
as $function$
  select case when not (public.es_admin() or public.es_staff()) then '{}'::jsonb
  else jsonb_build_object(
    'socios',           (select count(*) from atletas where tipo_membresia = 'socio' or numero_socio is not null),
    'familias',         (select count(*) from perfiles where 'padre' = any(roles)),
    'escuela_natacion', (select count(distinct coalesce(atleta_id::text, lower(nombre))) from natacion_inscripciones where activa and tipo = 'Escuela'),
    'natacion_master',  (select count(distinct coalesce(atleta_id::text, lower(nombre))) from natacion_inscripciones where activa and tipo = 'Máster'),
    'cubo',             (select count(*) from cubo_altas where estado = 'aprobada'),
    'atletismo_pista',  (select count(*) from atletas a join grupos g on g.id = a.grupo_id
                          where g.seccion = 'competicion'
                            and coalesce(a.estado,'activo') in ('activo','prueba','lesionado')),
    'escuela_atletismo',(select count(*) from atletas a join grupos g on g.id = a.grupo_id
                          where g.seccion = 'escuela'
                            and coalesce(a.estado,'activo') in ('activo','prueba','lesionado'))
  ) end
$function$;

notify pgrst, 'reload schema';
