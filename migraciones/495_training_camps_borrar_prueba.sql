-- ===========================================================================
-- 495 · Training Camps · borrar un expediente de PRUEBA
-- ---------------------------------------------------------------------------
-- Para que Andrés pueda probar el formulario de verdad y limpiar después:
-- solo expedientes marcados «de prueba» y sin ningún cobro. Se llevan sus
-- recibos pendientes (sin número: no se emitieron) y, si era el último código
-- del año, el contador vuelve atrás para que la primera solicitud real siga la
-- numeración. Los archivos del almacén los borra antes el panel.
-- ===========================================================================
begin;

create or replace function public.camp_borrar_prueba(p_id uuid) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare s public.camp_solicitudes; v_anio int; v_max int;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into s from public.camp_solicitudes where id = p_id for update;
  if s.id is null then raise exception 'Ese expediente no existe.'; end if;
  if not s.es_prueba then raise exception 'Solo se borran los expedientes marcados como de prueba.'; end if;
  if exists (select 1 from public.camp_pagos cp join public.pagos p on p.id = cp.pago_id where cp.solicitud_id = s.id and p.estado = 'pagado') then
    raise exception 'Tiene cobros: no se borra.';
  end if;
  delete from public.pagos where id in (select pago_id from public.camp_pagos where solicitud_id = s.id and pago_id is not null)
     and estado <> 'pagado' and numero_recibo is null;
  delete from public.camp_solicitudes where id = s.id;
  -- Numeración: el contador vuelve al mayor código que quede de ese año.
  v_anio := substring(s.codigo from 'TC-(\d{4})-')::int;
  select coalesce(max(substring(codigo from 'TC-\d{4}-(\d+)')::int), 0) into v_max
    from public.camp_solicitudes where codigo like 'TC-' || v_anio || '-%';
  update public.camp_contadores set n = v_max where anio = v_anio and n > v_max;
  return jsonb_build_object('ok', true, 'codigo', s.codigo);
end $$;

revoke execute on function public.camp_borrar_prueba(uuid) from public, anon;
grant execute on function public.camp_borrar_prueba(uuid) to authenticated;

commit;
