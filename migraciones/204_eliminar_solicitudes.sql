-- 204 · Eliminar solicitudes de alta (socio/escuela y Cubo)
-- Andrés quiere poder borrar solicitudes que rechaza o de prueba. Borra la
-- FILA de la solicitud (el registro de intake); no toca a un socio/atleta ya
-- creado. Solo admin/tesorería.
create or replace function public.alta_eliminar(p_que text, p_id uuid)
 returns jsonb
 language plpgsql security definer set search_path to 'public'
as $function$
declare v_filas int;
begin
  if not (public.es_admin() or public.es_tesoreria()) then
    raise exception 'Solo administración y tesorería pueden borrar altas' using errcode = '42501';
  end if;
  if p_que = 'escuela' then
    delete from public.altas_escuela where id = p_id;
  elsif p_que = 'socio' then
    delete from public.altas_socio where id = p_id;
  else
    raise exception 'No sé qué alta es «%»', p_que using errcode = 'P0001';
  end if;
  get diagnostics v_filas = row_count;
  return jsonb_build_object('ok', v_filas > 0);
end;
$function$;

-- Cubo: borrar una solicitud. SEGURO: no se puede borrar si ya tiene una
-- suscripción de Stripe (para no dejar un cobro huérfano cobrando). Para esas,
-- primero «Dar de baja» (cancela la suscripción) y luego se puede borrar.
create or replace function public.cubo_alta_eliminar(p_id uuid)
 returns jsonb
 language plpgsql security definer set search_path to 'public'
as $function$
declare v_sub text; v_filas int;
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede borrar altas del Cubo' using errcode = '42501';
  end if;
  select stripe_subscription_id into v_sub from public.cubo_altas where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'motivo', 'no-esta');
  end if;
  if v_sub is not null then
    return jsonb_build_object('ok', false, 'motivo', 'con-suscripcion',
      'mensaje', 'Esta persona tiene la cuota activa. Dale antes a «Dar de baja» (cancela el cobro) y luego bórrala.');
  end if;
  delete from public.cubo_altas where id = p_id;
  get diagnostics v_filas = row_count;
  return jsonb_build_object('ok', v_filas > 0);
end;
$function$;

grant execute on function public.alta_eliminar(text, uuid) to authenticated;
grant execute on function public.cubo_alta_eliminar(uuid) to authenticated;
