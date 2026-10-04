-- 278 · Natación: cancelar un día (festivo) y que se vea como cancelado.
-- Mario (4-oct-2026): «tiene que permitirme cancelar los festivos, y que se
-- vea como cancelada». Se apoya en calendario_excepciones (seccion='natacion',
-- día entero). La asistencia muestra el día cancelado y la recuperación del
-- máster no ofrece esos días.

-- Consulta: ¿está cancelado ese día la natación? (lectura, sin gate)
create or replace function public.natacion_dia_cancelado(p_fecha date)
returns jsonb
language sql stable security definer set search_path to 'public'
as $function$
  select coalesce(
    (select jsonb_build_object('cancelado', true, 'motivo', coalesce(e.motivo,'Festivo'))
       from public.calendario_excepciones e
      where e.activa
        and (e.seccion is null or e.seccion = 'natacion')
        and e.grupo_id is null
        and p_fecha between e.fecha and coalesce(e.fecha_fin, e.fecha)
      order by (e.seccion = 'natacion') desc
      limit 1),
    jsonb_build_object('cancelado', false));
$function$;

-- Cancelar el día (lo marca como festivo/cancelación). Solo natación/staff/admin.
create or replace function public.natacion_cancelar_dia(p_fecha date, p_motivo text default 'Festivo')
returns jsonb
language plpgsql security definer set search_path to 'public'
as $function$
declare v_motivo text := coalesce(nullif(btrim(p_motivo),''), 'Festivo');
begin
  if not (public.es_admin() or public.es_staff() or public.soy_responsable('natacion')) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.'); end if;
  if p_fecha is null then return jsonb_build_object('ok', false, 'msg', 'Falta la fecha.'); end if;
  -- Si ya hay una excepción de natación ese día (aunque esté apagada), la reenciende.
  update public.calendario_excepciones
     set activa = true, motivo = v_motivo, creado_por = public.mi_perfil_id()
   where seccion = 'natacion' and grupo_id is null
     and fecha = p_fecha and coalesce(fecha_fin, fecha) = p_fecha;
  if not found then
    insert into public.calendario_excepciones(fecha, tipo, motivo, seccion, activa, creado_por)
    values (p_fecha, 'festivo', v_motivo, 'natacion', true, public.mi_perfil_id());
  end if;
  return jsonb_build_object('ok', true, 'motivo', v_motivo);
end $function$;

-- Reactivar el día (quitar la cancelación). Solo natación/staff/admin.
create or replace function public.natacion_reactivar_dia(p_fecha date)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $function$
begin
  if not (public.es_admin() or public.es_staff() or public.soy_responsable('natacion')) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.'); end if;
  update public.calendario_excepciones set activa = false
   where seccion = 'natacion' and grupo_id is null
     and fecha = p_fecha and coalesce(fecha_fin, fecha) = p_fecha and activa;
  return jsonb_build_object('ok', true);
end $function$;

grant execute on function public.natacion_dia_cancelado(date) to authenticated;
grant execute on function public.natacion_cancelar_dia(date, text) to authenticated;
grant execute on function public.natacion_reactivar_dia(date) to authenticated;

-- La recuperación del máster no ofrece días cancelados.
create or replace function public.natacion_master_disponibles(p_fecha date)
 returns table(franja_id uuid, hora time without time zone, grupo text, calle text, huecos integer)
 language plpgsql stable security definer set search_path to 'public'
as $function$
declare v_calle int;
begin
  select calle_num into v_calle from public.natacion_master_yo();
  if v_calle is null then return; end if;
  if public.hay_excepcion(p_fecha, null, 'natacion', null) then return; end if;  -- día cancelado
  return query
  select f.id, f.hora, f.grupo, hc.calle, hc.huecos
  from public.natacion_franjas f
  join lateral (
    select h.calle, h.huecos
    from public.natacion_huecos_calle(f.id, p_fecha) h
    where public._num_calle(h.calle) <= v_calle and h.huecos > 0
    order by public._num_calle(h.calle) desc
    limit 1
  ) hc on true
  where coalesce(f.activa, true)
    and f.admite_master
    and f.dia = extract(isodow from p_fecha)::smallint
  order by f.hora;
end $function$;
