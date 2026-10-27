-- 454 · Competiciones de natación: «por revisar» (bajas, datos que faltan) solo cuenta a los que VAN o no han respondido
begin;
create or replace function public.natacion_comp_listar()
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v jsonb;
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select jsonb_build_object(
    'categorias', coalesce((select jsonb_agg(jsonb_build_object('clave', c.clave, 'nombre', c.nombre, 'desde', c.desde_anio, 'hasta', c.hasta_anio,
        'ninos', (select count(*) from public.atletas a where a.id in (select public._natacion_comp_ninos())
                    and extract(year from a.fecha_nacimiento) between c.desde_anio and c.hasta_anio)) order by c.orden)
      from public.natacion_comp_categorias c where c.temporada = '2026/27'), '[]'),
    'jornadas', coalesce((select jsonb_agg(jsonb_build_object('id', j.id, 'fecha', j.fecha, 'hora', j.hora, 'lugar', j.lugar, 'nombre', j.nombre,
        'categorias', j.categorias, 'convoca', j.convoca,
        'convocados', (select count(*) from public.natacion_comp_convocados x where x.jornada_id = j.id and x.convocado),
        'van', (select count(*) from public.natacion_comp_convocados x where x.jornada_id = j.id and x.convocado and x.respuesta = 'si'),
        'sin_respuesta', (select count(*) from public.natacion_comp_convocados x where x.jornada_id = j.id and x.convocado and x.respuesta = 'pendiente'),
        'de_baja', (select count(*) from public.natacion_comp_convocados x where x.jornada_id = j.id and x.convocado and x.respuesta <> 'no'
                      and x.atleta_id not in (select public._natacion_comp_ninos())),
        'sin_datos', (select count(*) from public.natacion_comp_convocados x 
                      where x.jornada_id = j.id and x.convocado and x.respuesta <> 'no' and cardinality(public._natacion_comp_falta(x.atleta_id)) > 0))
      order by j.fecha, j.hora nulls first, j.lugar)
      from public.natacion_comp_jornadas j where j.temporada = '2026/27'), '[]')
  ) into v;
  return v;
end $$;
commit;
