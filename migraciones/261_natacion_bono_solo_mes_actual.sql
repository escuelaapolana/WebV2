-- 261 · Regla de Mario: la recuperación con bono (máster «no voy» → reservar otro día)
-- solo se permite DENTRO DEL MES EN CURSO. Para el mes siguiente el nadador tiene que
-- hablar con Mario (futuro: Adriana), que así controla los cambios. Se añade un único
-- guard a natacion_master_usar_bono; el resto de la función queda idéntico.
begin;

create or replace function public.natacion_master_usar_bono(p_franja uuid, p_fecha date)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare v_acc uuid; v_nombre text; v_calle_num int; v_saldo int; v_calle text;
begin
  select acceso_id, nombre, calle_num into v_acc, v_nombre, v_calle_num from public.natacion_master_yo();
  if v_acc is null then return jsonb_build_object('ok', false, 'error', 'no_master'); end if;
  if p_fecha < current_date then return jsonb_build_object('ok', false, 'error', 'fecha',
    'msg', 'No puedes reservar un día que ya pasó.'); end if;
  -- Regla de Mario (mig 261): la recuperación es solo dentro del mes en curso.
  if date_trunc('month', p_fecha) > date_trunc('month', current_date) then
    return jsonb_build_object('ok', false, 'error', 'mes_siguiente',
      'msg', 'La recuperación es solo dentro de este mes. Para el mes que viene, escribe a Mario y él te la coloca.'); end if;
  select saldo into v_saldo from public.natacion_abonos where acceso_id = v_acc;
  if coalesce(v_saldo, 0) <= 0 then
    return jsonb_build_object('ok', false, 'error', 'sin_saldo', 'msg', 'No te quedan bonos. Marca "no voy" un día para ganar uno.'); end if;
  if not (coalesce(exists(select 1 from public.natacion_franjas where id = p_franja and coalesce(activa,true)
             and dia = extract(isodow from p_fecha)::smallint), false)) then
    return jsonb_build_object('ok', false, 'error', 'franja', 'msg', 'Esa franja no es de ese día.'); end if;
  -- Ya tiene reserva o es su franja fija ese día → no tiene sentido gastar bono.
  if exists(select 1 from public.natacion_reservas where acceso_id = v_acc and franja_id = p_franja and fecha = p_fecha and estado = 'reservada') then
    return jsonb_build_object('ok', false, 'error', 'ya_reservada', 'msg', 'Ya tienes esa sesión reservada.'); end if;
  -- Elige la calle: la más alta a la que llega con hueco.
  select h.calle into v_calle
  from public.natacion_huecos_calle(p_franja, p_fecha) h
  where public._num_calle(h.calle) <= v_calle_num and h.huecos > 0
  order by public._num_calle(h.calle) desc
  limit 1;
  if v_calle is null then
    return jsonb_build_object('ok', false, 'error', 'sin_hueco', 'msg', 'No hay hueco en ninguna calle a la que llegues ese día.'); end if;
  insert into public.natacion_reservas(franja_id, fecha, acceso_id, nombre, calle, estado, creada_por)
    values (p_franja, p_fecha, v_acc, coalesce(v_nombre, (select nombre from public.natacion_accesos where id = v_acc)),
            v_calle, 'reservada', public.mi_perfil_id());
  update public.natacion_abonos set saldo = saldo - 1, updated_at = now() where acceso_id = v_acc;
  return jsonb_build_object('ok', true, 'calle', v_calle, 'saldo', v_saldo - 1);
end $function$;

commit;
