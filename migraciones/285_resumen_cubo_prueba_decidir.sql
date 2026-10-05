-- 285 · Inicio del panel: avisar de los de PRUEBA del Cubo que ya llevan
-- ≥1 semana desde el alta (toca decidir si se quedan → abrir cobro, o borrar).
-- Se añade la clave cubo_prueba_decidir a general_resumen (lo demás igual).

create or replace function public.general_resumen()
returns jsonb
language sql stable security definer set search_path to 'public'
as $function$
  select case when not (public.es_admin() or public.es_staff()) then '{}'::jsonb
  else jsonb_build_object(
    'altas_socio',   (select count(*) from altas_socio   where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'altas_escuela', (select count(*) from altas_escuela where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'cubo_altas',    (select count(*) from cubo_altas    where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')),
    'cubo_prueba',   (select count(*) from cubo_prueba),
    'cubo_prueba_decidir', (
       select count(*) from cubo_altas
       where estado = 'aprobada'
         and suscripcion_estado is distinct from 'activa'
         and not coalesce(cobro_abierto, false)
         and not coalesce(lista_espera, false)
         and created_at <= now() - interval '7 days'),
    'buzon',         (select count(*) from buzon_bandeja where atendido is not true),
    'solicitudes',   (select count(*) from solicitudes_inscripcion where atendida is not true),
    'liga_validar',  (select count(*) from liga_participaciones where estado = 'pendiente')
  ) end
$function$;
