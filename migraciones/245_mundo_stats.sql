-- 245_mundo_stats.sql
-- Cifras en vivo para el «Resumen» de cada mundo (las pinta assets/js/mundos.js
-- encima del hub). Devuelve un array [{n,l}] con 2-3 números fiables por mundo.
-- Lo ve quien tenga acceso a ese mundo (admin/staff o su responsable).

create or replace function public.mundo_stats(p_world text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
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
      jsonb_build_object('n', (select count(*) from natacion_franjas where coalesce(activa,true) and grupo ilike '%escuela%'), 'l','franjas') )
    when p_world = 'running' then jsonb_build_array(
      jsonb_build_object('n', (select count(*) from grupos where seccion='running'), 'l','grupos') )
    else '[]'::jsonb
  end
$$;

grant execute on function public.mundo_stats(text) to authenticated, service_role;
