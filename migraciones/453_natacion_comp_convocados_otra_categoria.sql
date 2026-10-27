-- 453 · Competiciones de natación: un convocado de OTRO año de nacimiento también sale en la jornada
-- (en Pilar 07-11 había 11 convocados y la lista enseñaba 10). Se marca con en_cat = false.
begin;
create or replace function public.natacion_comp_jornada(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare j public.natacion_comp_jornadas; v jsonb;
begin
  if not public.natacion_comp_puede() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into j from public.natacion_comp_jornadas where id = p_id;
  if not found then raise exception 'Esa jornada ya no existe.' using errcode = 'P0001'; end if;
  with cats as (select * from public.natacion_comp_categorias c where c.temporada = j.temporada and c.clave = any(j.categorias)),
  act as (select public._natacion_comp_ninos() as id),
  encat as (select a.id from public.atletas a
             where a.id in (select id from act)
               and exists (select 1 from cats c where extract(year from a.fecha_nacimiento) between c.desde_anio and c.hasta_anio)),
  ninos as (
    -- los de la categoría hoy + cualquier convocado (aunque sea de otro año o ya no esté)
    select a.*, (a.id in (select id from act)) as activo, (a.id in (select id from encat)) as en_cat
      from public.atletas a
     where a.id in (select id from encat)
        or a.id in (select x.atleta_id from public.natacion_comp_convocados x where x.jornada_id = j.id and x.convocado)
  )
  select jsonb_build_object(
    'jornada', to_jsonb(j),
    'categorias', (select jsonb_agg(jsonb_build_object('clave', c.clave, 'nombre', c.nombre, 'desde', c.desde_anio, 'hasta', c.hasta_anio) order by c.orden) from cats c),
    'ninos', coalesce(jsonb_agg(jsonb_build_object(
        'id', n.id, 'nombre', btrim(coalesce(n.nombre,'') || ' ' || coalesce(n.apellidos,'')), 'anio', extract(year from n.fecha_nacimiento)::int,
        'sexo', n.sexo, 'activo', n.activo, 'en_cat', n.en_cat, 'baja_en', n.fecha_baja,
        'nivel', (select string_agg(distinct i.nivel, ', ') from public.natacion_inscripciones i where i.atleta_id = n.id and i.activa),
        'falta', to_jsonb(public._natacion_comp_falta(n.id)),
        'licencia', coalesce((select l.tramitada from public.natacion_licencias l where l.atleta_id = n.id and l.temporada = j.temporada), false),
        'convocado', coalesce(x.convocado, false), 'pruebas', x.pruebas, 'respuesta', coalesce(x.respuesta, 'pendiente'), 'nota', x.nota)
      order by n.nombre, n.apellidos), '[]')
  ) into v
  from ninos n
  left join public.natacion_comp_convocados x on x.jornada_id = j.id and x.atleta_id = n.id;
  return v;
end $$;
commit;
