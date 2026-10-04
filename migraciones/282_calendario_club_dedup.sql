-- 282 · Calendario del club: deduplicar sesiones.
-- Hay grupos duplicados en la base (p. ej. dos filas «Azul 1»), que hacían
-- aparecer la misma sesión dos veces. Se colapsan por (fecha, sección, grupo,
-- hora), quedándose con la de más apuntados.

create or replace function public.calendario_club(p_desde date, p_hasta date, p_seccion text default null)
returns table(fecha date, seccion text, grupo_id uuid, grupo text,
              hora time without time zone, hora_fin time without time zone,
              lugar text, apuntados integer, cancelado boolean, motivo text, origen text)
language plpgsql stable security definer set search_path to 'public'
as $function$
begin
  if not (public.es_admin() or public.es_staff()) then
    if p_seccion is null
       or not exists (select 1 from public.mis_secciones_responsable() s where s = p_seccion) then
      return;
    end if;
  end if;
  if p_hasta - p_desde > 62 then p_hasta := p_desde + 62; end if;

  return query
  with dias as (
    select d::date as fecha from generate_series(p_desde, p_hasta, interval '1 day') d
  ),
  base as (
    select dd.fecha, g.seccion, g.id as grupo_id, g.nombre as grupo,
           h.hora_inicio as hora, h.hora_fin as hora_fin, coalesce(h.lugar,'') as lugar,
           (select count(*)::int from public.atleta_grupos ag where ag.grupo_id = g.id) as apuntados,
           'grupo'::text as origen
    from dias dd
    join public.grupo_horarios h
      on coalesce(h.activo, true) and not coalesce(h.apagado_a_mano, false)
     and h.dia_semana = extract(isodow from dd.fecha)::int
    join public.grupos g on g.id = h.grupo_id and coalesce(g.activo, true)
    where (p_seccion is null or g.seccion = p_seccion)
    union all
    -- Natación: las franjas son compartidas. «Escuela» = peques (escuela-natación),
    -- «Máster/Perfeccionamiento» = adultos (natación), «Escuela + Máster» = las dos.
    select dd.fecha,
           case when f.grupo ilike '%escuela%' and not (f.grupo ilike '%máster%' or f.grupo ilike '%master%')
                then 'escuela-natacion' else 'natacion' end as seccion,
           f.id, f.grupo, f.hora, null::time, ''::text,
           (select count(*)::int from public.natacion_inscripciones i where i.franja_id = f.id and i.activa),
           'natacion'::text
    from dias dd
    join public.natacion_franjas f
      on coalesce(f.activa, true) and f.dia = extract(isodow from dd.fecha)::int
    where p_seccion is null
       or (p_seccion = 'natacion'
             and ((f.grupo ilike '%máster%' or f.grupo ilike '%master%' or f.grupo ilike '%perfeccion%')
                  or f.grupo not ilike '%escuela%'))
       or (p_seccion = 'escuela-natacion' and f.grupo ilike '%escuela%')
  ),
  conex as (
    select b.*, (ex.id is not null) as cancelado, ex.motivo
    from base b
    left join lateral (
      select e.id, e.motivo
      from public.calendario_excepciones e
      where e.activa
        and b.fecha between e.fecha and coalesce(e.fecha_fin, e.fecha)
        and (e.grupo_id is null or e.grupo_id = b.grupo_id)
        and (e.seccion is null or e.seccion = b.seccion)
      order by (e.grupo_id = b.grupo_id) desc nulls last,
               (e.seccion = b.seccion) desc nulls last
      limit 1
    ) ex on true
  )
  select distinct on (c.fecha, c.seccion, c.grupo, c.hora)
         c.fecha, c.seccion, c.grupo_id, c.grupo, c.hora, c.hora_fin, c.lugar, c.apuntados,
         c.cancelado, c.motivo, c.origen
  from conex c
  order by c.fecha, c.seccion, c.grupo, c.hora, c.apuntados desc;
end $function$;
