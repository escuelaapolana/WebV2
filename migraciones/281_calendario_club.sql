-- 281 · Calendario del club: motor + cancelar/reactivar por sección.
-- Une los horarios recurrentes (grupo_horarios: cubo, escuela, running,
-- competición) con las franjas de natación, proyectados sobre un rango de
-- fechas, con el nº de apuntados y si el día está cancelado (festivo/cierre,
-- calendario_excepciones). Admin/staff ven todo; un responsable solo su sección.

create or replace function public.calendario_club(p_desde date, p_hasta date, p_seccion text default null)
returns table(fecha date, seccion text, grupo_id uuid, grupo text,
              hora time without time zone, hora_fin time without time zone,
              lugar text, apuntados integer, cancelado boolean, motivo text, origen text)
language plpgsql stable security definer set search_path to 'public'
as $function$
begin
  -- Permiso: admin/staff ven todo; el responsable solo su sección (ha de pedirla).
  if not (public.es_admin() or public.es_staff()) then
    if p_seccion is null
       or not exists (select 1 from public.mis_secciones_responsable() s where s = p_seccion) then
      return;
    end if;
  end if;
  -- Tope defensivo de rango (no más de ~2 meses por llamada).
  if p_hasta - p_desde > 62 then p_hasta := p_desde + 62; end if;

  return query
  with dias as (
    select d::date as fecha from generate_series(p_desde, p_hasta, interval '1 day') d
  ),
  base as (
    -- Grupos con horario recurrente (cubo, escuela, running, competición…)
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

    -- Natación (franjas)
    select dd.fecha, 'natacion'::text, f.id, f.grupo,
           f.hora, null::time, ''::text,
           (select count(*)::int from public.natacion_inscripciones i where i.franja_id = f.id and i.activa),
           'natacion'::text
    from dias dd
    join public.natacion_franjas f
      on coalesce(f.activa, true) and f.dia = extract(isodow from dd.fecha)::int
    where (p_seccion is null or p_seccion = 'natacion')
  )
  select b.fecha, b.seccion, b.grupo_id, b.grupo, b.hora, b.hora_fin, b.lugar, b.apuntados,
         (ex.id is not null) as cancelado, ex.motivo, b.origen
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
  order by b.fecha, b.hora, b.seccion, b.grupo;
end $function$;

-- Cancelar un día (o rango) para una sección. Admin/staff: cualquiera;
-- responsable: solo su sección. seccion NULL = todo el club (solo admin/staff).
create or replace function public.calendario_cancelar_dia(p_fecha date, p_seccion text,
                                                          p_motivo text default 'Festivo',
                                                          p_fecha_fin date default null)
returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare v_motivo text := coalesce(nullif(btrim(p_motivo),''), 'Festivo');
begin
  if not (public.es_admin() or public.es_staff()
          or (p_seccion is not null and public.soy_responsable(p_seccion))) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.'); end if;
  if p_fecha is null then return jsonb_build_object('ok', false, 'msg', 'Falta la fecha.'); end if;
  if p_fecha_fin is not null and p_fecha_fin < p_fecha then
    return jsonb_build_object('ok', false, 'msg', 'El fin no puede ser antes del inicio.'); end if;

  update public.calendario_excepciones
     set activa = true, motivo = v_motivo, fecha_fin = p_fecha_fin, creado_por = public.mi_perfil_id()
   where grupo_id is null and fecha = p_fecha
     and coalesce(seccion,'') = coalesce(p_seccion,'');
  if not found then
    insert into public.calendario_excepciones(fecha, fecha_fin, tipo, motivo, seccion, activa, creado_por)
    values (p_fecha, p_fecha_fin, 'festivo', v_motivo, p_seccion, true, public.mi_perfil_id());
  end if;
  return jsonb_build_object('ok', true);
end $function$;

create or replace function public.calendario_reactivar_dia(p_fecha date, p_seccion text)
returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
begin
  if not (public.es_admin() or public.es_staff()
          or (p_seccion is not null and public.soy_responsable(p_seccion))) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.'); end if;
  update public.calendario_excepciones set activa = false
   where grupo_id is null and fecha = p_fecha
     and coalesce(seccion,'') = coalesce(p_seccion,'') and activa;
  return jsonb_build_object('ok', true);
end $function$;

grant execute on function public.calendario_club(date, date, text) to authenticated;
grant execute on function public.calendario_cancelar_dia(date, text, text, date) to authenticated;
grant execute on function public.calendario_reactivar_dia(date, text) to authenticated;
