-- 332 · Calendario del club (calendario_club): cada número sale de la misma
--       fuente que la pantalla que lo enseña. (Requiere 320 y 330.)
--
-- Auditoría 13-oct-2026:
--   · DISTINCT ON (fecha, seccion, nombre, hora) escondía grupos DISTINTOS con
--     el mismo nombre a la misma hora: viernes 18:30 de escuela hay dos
--     «Recreativo» (L-X-V y M-J-V) y dos «Sub 14», y solo salía uno de cada.
--     → Ahora se deduplica por grupo_id (solo quita horarios repetidos del
--       MISMO grupo).
--   · Apuntados contaba atleta_grupos tal cual (incluidas bajas).
--     → grupo_apuntados(): la misma regla que las listas (sin bajas).
--   · El Cubo: el calendario decía 16 en «M y J 17:30» y Claudia veía 15 en
--     portal/cubo-lista. La lista de Claudia NO sale de atleta_grupos: sale de
--     cubo_altas (aprobadas, sin lista de espera) contando SOLO a quien viene
--     ESE día (dias_semana: 14 vienen M y J, 1 solo el jueves, 1 sin marcar
--     = los dos) y quitando a quien avisó «no voy» (cubo_ausencias). Los
--     turnos de «Fuerza gratis» salen de cubo_prueba por turno.
--     → cubo_apuntados_dia(grupo, fecha) replica esa cuenta en SQL y el
--       calendario la usa para la sección cubo (cubo-lista no se toca).
--   · Natación: «apuntados» = ocupados del día de natacion_ocupacion (mig
--     330: solo resta ausencias de inscritos activos). Sección por la regla
--     única natacion_franja_seccion (la «Perfeccionamiento» del lunes 19:30
--     pasa a escuela-natacion; las mixtas salen en los dos filtros).
--   · Festivos: con la regla única de la 320 (excepcion_del_dia), en lugar de
--     la consulta propia (que ignoraba el lugar).
-- Misma firma y mismas columnas.

-- ─────────────────────────────────────────────────────────────────────────
-- 1 · Cuántos vienen un día a un grupo del Cubo (= portal/cubo-lista)
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.cubo_apuntados_dia(p_grupo uuid, p_fecha date)
returns integer
language sql stable security definer
set search_path to 'public'
as $$
  with g as (
    select id, nombre from public.grupos where id = p_grupo and seccion = 'cubo'
  ),
  t as (
    select case extract(isodow from p_fecha)::int
             when 5 then 'viernes' when 6 then 'sabado' when 7 then 'domingo' end as turno,
           extract(isodow from p_fecha)::smallint as dsem
  )
  select case
    when (select nombre from g) ~* 'fuerza\s*gratis' then
      (select count(*) from public.cubo_prueba p, t
        where p.estado <> 'cancelado' and t.turno = any(p.turnos)
          and not exists (select 1 from public.cubo_ausencias ca
                           where ca.perfil_id = p.perfil_id and ca.fecha = p_fecha))
    else
      (select count(*) from public.cubo_altas a, g, t
        where a.estado = 'aprobada' and a.horario = g.nombre and not a.lista_espera
          and (a.dias_semana is null or cardinality(a.dias_semana) = 0 or t.dsem = any(a.dias_semana))
          and not exists (select 1 from public.cubo_ausencias ca
                           where ca.perfil_id = a.perfil_id and ca.fecha = p_fecha))
  end::int;
$$;

comment on function public.cubo_apuntados_dia(uuid, date) is
  'Mig 332 · los que vienen un día a un grupo del Cubo, con la misma cuenta que portal/cubo-lista (cubo_altas por dias_semana − cubo_ausencias; Fuerza gratis = cubo_prueba por turno).';

revoke all on function public.cubo_apuntados_dia(uuid, date) from public, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 2 · calendario_club (misma firma)
-- ─────────────────────────────────────────────────────────────────────────
create or replace function public.calendario_club(p_desde date, p_hasta date, p_seccion text default null)
returns table(fecha date, seccion text, grupo_id uuid, grupo text,
              hora time without time zone, hora_fin time without time zone,
              lugar text, apuntados integer, cancelado boolean, motivo text, origen text)
language plpgsql stable security definer
set search_path to 'public'
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
  gr as (   -- grupos activos y sus apuntados «de siempre» (misma regla que las listas)
    select g.id, g.nombre, g.seccion,
           case when g.seccion = 'cubo' then null else public.grupo_apuntados(g.id) end as ap
      from public.grupos g
     where coalesce(g.activo, true)
       and (p_seccion is null or g.seccion = p_seccion)
  ),
  base as (
    select dd.fecha, gr.seccion, gr.id as grupo_id, gr.nombre as grupo,
           h.hora_inicio as hora, h.hora_fin as hora_fin, coalesce(h.lugar, '') as lugar,
           coalesce(gr.ap, public.cubo_apuntados_dia(gr.id, dd.fecha)) as apuntados,
           public.excepcion_del_dia(dd.fecha, gr.seccion, gr.id, nullif(btrim(h.lugar), '')) as exc,
           'grupo'::text as origen
      from dias dd
      join public.grupo_horarios h
        on coalesce(h.activo, true) and not coalesce(h.apagado_a_mano, false)
       and h.dia_semana = extract(isodow from dd.fecha)::int
      join gr on gr.id = h.grupo_id
    union all
    -- Natación: franjas compartidas. Sección por la regla única (mig 330);
    -- con filtro, las mixtas salen en los dos y se etiquetan con el filtro.
    select nf.fecha,
           coalesce(p_seccion, nf.seccion),
           nf.franja_id, nf.grupo, nf.hora, null::time, ''::text,
           nf.ocupados,
           public.excepcion_del_dia(nf.fecha, nf.seccion),
           'natacion'::text
      from (
        select dd.fecha, o.franja_id, o.grupo, o.hora, o.seccion,
               bool_or(o.es_escuela) as es_esc, bool_or(o.es_master) as es_mas,
               sum(o.ocupados)::int as ocupados
          from dias dd
          cross join lateral public.natacion_ocupacion(dd.fecha) o
         group by dd.fecha, o.franja_id, o.grupo, o.hora, o.seccion
      ) nf
     where p_seccion is null
        or (p_seccion = 'natacion' and nf.es_mas)
        or (p_seccion = 'escuela-natacion' and nf.es_esc)
  ),
  uno as (   -- un mismo grupo con el horario repetido sale una vez
    select distinct on (b.fecha, b.grupo_id, b.hora) b.*
      from base b
     order by b.fecha, b.grupo_id, b.hora, b.apuntados desc
  )
  select u.fecha, u.seccion, u.grupo_id, u.grupo, u.hora, u.hora_fin, u.lugar, u.apuntados,
         coalesce((u.exc->>'cancelado')::boolean, false),
         case when coalesce((u.exc->>'cancelado')::boolean, false) then u.exc->>'motivo' end,
         u.origen
    from uno u
   order by u.fecha, u.seccion, u.grupo, u.hora;
end $function$;
