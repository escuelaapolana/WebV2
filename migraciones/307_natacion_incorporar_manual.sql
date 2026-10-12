-- 307 · Añadir una incorporación a mano desde «pasar lista»
-- Mario: cuando alguien aparece a nadar un día sin haberse apuntado (p.ej.
-- Javier Vidal el jueves), que el monitor pueda meterlo en el momento en la
-- lista. Crea una reserva (incorporación del día). Si la persona tiene bono, le
-- descuenta 1 (clase extra); si no, se añade igual (asistencia registrada). El
-- descuento es simétrico con natacion_cancelar_reserva (que devuelve el bono),
-- así que quitarla luego desde la pantalla de reservas cuadra.
-- Guard igual que pasar lista (admin / responsable natación o escuela-natación),
-- porque natacion_reservas solo la escribe un gestor por RLS. No toca tablas.

create or replace function public.natacion_incorporar_manual(
  p_franja uuid, p_fecha date, p_acceso_id uuid, p_calle text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_nombre text; v_saldo int;
begin
  if not (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion')) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.');
  end if;
  if p_franja is null or p_fecha is null or p_acceso_id is null then
    return jsonb_build_object('ok', false, 'msg', 'Faltan datos.');
  end if;
  select nombre into v_nombre from public.natacion_accesos where id = p_acceso_id;
  if v_nombre is null then
    return jsonb_build_object('ok', false, 'msg', 'Esa persona no existe.');
  end if;
  -- Si ya es fijo activo de esa franja, no es una incorporación.
  if exists (select 1 from public.natacion_inscripciones i
             where i.franja_id = p_franja and i.acceso_id = p_acceso_id and i.activa) then
    return jsonb_build_object('ok', false, 'msg', v_nombre || ' ya es fijo de esa franja.');
  end if;
  -- No duplicar la incorporación ese día.
  if exists (select 1 from public.natacion_reservas r
             where r.franja_id = p_franja and r.fecha = p_fecha
               and r.acceso_id = p_acceso_id and r.estado = 'reservada') then
    return jsonb_build_object('ok', true, 'msg', v_nombre || ' ya estaba en la lista.');
  end if;
  insert into public.natacion_reservas(franja_id, fecha, acceso_id, nombre, calle, creada_por)
    values (p_franja, p_fecha, p_acceso_id, v_nombre, nullif(btrim(coalesce(p_calle,'')), ''), public.mi_perfil_id());
  -- Si tiene bono, se le descuenta 1 (clase extra pagada). Si no, se añade igual.
  select saldo into v_saldo from public.natacion_abonos where acceso_id = p_acceso_id;
  if coalesce(v_saldo, 0) > 0 then
    update public.natacion_abonos set saldo = saldo - 1, updated_at = now() where acceso_id = p_acceso_id;
  end if;
  return jsonb_build_object('ok', true,
    'msg', v_nombre || ' añadido a la lista de hoy' ||
           case when coalesce(v_saldo,0) > 0 then ' (usa 1 bono)' else '' end || '.');
end $$;

grant execute on function public.natacion_incorporar_manual(uuid, date, uuid, text) to authenticated;
