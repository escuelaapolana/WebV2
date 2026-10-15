-- 372 · «% de plazas ocupadas» en los Resúmenes de Natación y Escuela de natación
-- ---------------------------------------------------------------------------
-- Andrés lo echaba en falta (15-oct). Plazas = suma de los cupos por calle de las
-- franjas activas de esa sección (regla única natacion_franja_seccion, mig 330);
-- ocupadas = inscripciones fijas activas en esas franjas.
-- ---------------------------------------------------------------------------
begin;

create or replace function public._natacion_pct_ocupado(p_sec text)
returns text language sql stable security definer set search_path to 'public' as $$
  with f as (
    select fr.id,
           (select coalesce(sum(value::int), 0) from jsonb_each_text(coalesce(fr.cupos, '{}'::jsonb))) as cupo
      from public.natacion_franjas fr
     where coalesce(fr.activa, true)
       and public.natacion_franja_seccion(fr.grupo, fr.admite_master) = p_sec)
  select case when sum(f.cupo) > 0
              then round(100.0 * sum((select count(*) from public.natacion_inscripciones i
                                       where i.franja_id = f.id and i.activa)) / sum(f.cupo))::int || ' %'
              else '—' end
    from f;
$$;
revoke all on function public._natacion_pct_ocupado(text) from public, anon, authenticated;

create or replace function public.mundo_stats(p_world text)
returns jsonb language sql stable security definer set search_path to 'public' as $function$
  select case
    when not (public.es_admin() or public.es_staff() or (p_world = any(public.mis_mundos()))) then '[]'::jsonb
    when p_world = 'cubo' then jsonb_build_array(
      jsonb_build_object('n', (select count(*) from atletas where tipo_membresia='cubo'), 'l','integrantes'),
      jsonb_build_object('n', (select count(*) from grupos where seccion='cubo'),          'l','grupos'),
      jsonb_build_object('n', (select count(*) from cubo_prueba),                          'l','a prueba') )
    when p_world = 'pista' then jsonb_build_array(
      jsonb_build_object('n', (select count(*) from atletas where 'atletismo' = any(secciones)), 'l','atletas'),
      jsonb_build_object('n', (select count(*) from grupos where seccion='competicion'),         'l','grupos'),
      jsonb_build_object('n', (select count(*) from competiciones where fecha_inicio >= current_date), 'l','próximas carreras') )
    when p_world = 'escuela-atl' then jsonb_build_array(
      jsonb_build_object('n', (select count(*) from grupos where seccion='escuela'), 'l','grupos'),
      jsonb_build_object('n', (select count(*) from altas_escuela where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')), 'l','altas nuevas') )
    when p_world = 'escuela-nat' then jsonb_build_array(
      jsonb_build_object('n', (select count(distinct coalesce(acceso_id::text, nombre)) from natacion_inscripciones where activa and tipo='Escuela'), 'l','niños/as'),
      jsonb_build_object('n', (select count(*) from natacion_franjas where coalesce(activa,true) and grupo ilike '%escuela%'), 'l','franjas'),
      jsonb_build_object('n', public._natacion_pct_ocupado('escuela-natacion'), 'l','plazas ocupadas') )
    when p_world = 'natacion' then jsonb_build_array(
      jsonb_build_object('n', public._natacion_pct_ocupado('natacion'), 'l','plazas ocupadas') )
    when p_world = 'running' then jsonb_build_array(
      jsonb_build_object('n', (select count(*) from grupos where seccion='running'), 'l','grupos') )
    else '[]'::jsonb
  end
$function$;

commit;
