-- 280 · Festivos/cierres: lector genérico para cualquier sección.
-- El sitio central para marcar festivos ya existe (admin «Se pone solo» →
-- calendario_excepciones). Natación ya lo respeta; con esto el Cubo (y quien
-- quiera) puede preguntar si un día está cancelado para su sección.
-- Un festivo «de todo el club» (seccion NULL) cae para todas las secciones;
-- uno con seccion='cubo' solo para el Cubo, etc. grupo_id NULL = día entero.

create or replace function public.dia_cancelado(p_fecha date, p_seccion text)
returns jsonb
language sql stable security definer set search_path to 'public'
as $function$
  select coalesce(
    (select jsonb_build_object('cancelado', true,
              'motivo', coalesce(e.motivo, 'Festivo'),
              'tipo',   coalesce(e.tipo, 'festivo'))
       from public.calendario_excepciones e
      where e.activa
        and e.grupo_id is null
        and p_fecha between e.fecha and coalesce(e.fecha_fin, e.fecha)
        and (e.seccion is null or e.seccion = p_seccion)
      order by (e.seccion = p_seccion) desc nulls last  -- prioriza el específico de la sección
      limit 1),
    jsonb_build_object('cancelado', false));
$function$;

grant execute on function public.dia_cancelado(date, text) to authenticated;
