-- 310 · El aviso «de prueba del Cubo con 2 asistencias» deja de contar a quien
-- ya tiene marcado «Se queda» (confirmado_sigue). Antes seguía contando hasta
-- que se abría el cobro, y un aviso que no se apaga deja de ser aviso.
-- (La Fuerza gratis —cubo_prueba— ya no se enseña como pendiente en General.)
begin;
create or replace function public.general_resumen()
returns jsonb language sql stable security definer set search_path to 'public' as $function$
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
    'buzon',         (select count(*) from buzon_bandeja where atendido is not true),
    'solicitudes',   (select count(*) from solicitudes_inscripcion
                       where atendida is not true
                         and coalesce(comentario,'') not ilike 'SOLICITUD DE PRUEBA%'),
    'liga_validar',  (select count(*) from liga_participaciones where estado = 'pendiente')
  ) end
$function$;
commit;
