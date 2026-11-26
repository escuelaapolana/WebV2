-- ===========================================================================
-- 540 · Natación · equipación: cobrar un artículo que iba gratis (26-nov-2026)
-- ---------------------------------------------------------------------------
-- Petición de Mario: «algunas camisetas que a priori eran gratis ahora son de
-- pago y quiere poder marcarlo». natacion_equip_linea_set admite p_precio: pone
-- ese precio al artículo (y lo deja «de pago»), recalcula el total y:
--   · pedido sin llegar → solo cambia el total;
--   · ha llegado y tenía enlace sin pagar → cambia su importe;
--   · ha llegado SIN enlace (iba todo gratis) → crea el enlace de pago, igual
--     que al marcar «ha llegado» (natacion_equip_estado_set);
--   · ya pagado o entregado → no toca el cobro y avisa para cobrarlo aparte.
-- Se rehace la función con un parámetro más (se quita la de 3 para que una
-- llamada con nombres no sea ambigua).
-- ===========================================================================
begin;

drop function if exists public.natacion_equip_linea_set(uuid, boolean, boolean);

create or replace function public.natacion_equip_linea_set(p_linea uuid, p_entregado boolean default null, p_sin_cargo boolean default null, p_precio numeric default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_l public.natacion_equip_lineas%rowtype; v_f public.natacion_equip_familias%rowtype; v_r jsonb := '{}'::jsonb; v_pend int; v_aviso text;
begin
  if not public.natacion_ropa_puede() then raise exception 'Solo quien lleva la natación o su ropa.' using errcode = '42501'; end if;
  select * into v_l from public.natacion_equip_lineas where id = p_linea for update;
  if not found then raise exception 'No encuentro ese artículo.'; end if;
  if p_entregado is not null then
    update public.natacion_equip_lineas set entregado_en = case when p_entregado then coalesce(entregado_en, now()) end where id = p_linea;
    select count(*) into v_pend from public.natacion_equip_lineas where familia_id = v_l.familia_id and entregado_en is null;
    if v_pend = 0 then
      update public.natacion_equip_familias set estado = 'entregado', entregado_en = coalesce(entregado_en, now()) where id = v_l.familia_id and estado <> 'entregado';
    elsif not p_entregado then
      update public.natacion_equip_familias f set estado = case when exists (select 1 from public.pagos p where p.id = f.pago_id and p.estado = 'pagado') then 'pagado' else 'llegado' end,
             entregado_en = null
       where f.id = v_l.familia_id and f.estado = 'entregado';
    end if;
  end if;
  if p_precio is not null then
    if p_precio < 0 or p_precio > 500 then raise exception 'Precio no válido.'; end if;
    update public.natacion_equip_lineas set precio_unitario = p_precio, sin_cargo = false where id = p_linea;
    v_r := public._natacion_equip_recalcular(v_l.familia_id);
    select * into v_f from public.natacion_equip_familias where id = v_l.familia_id;
    if v_f.total > 0 and v_f.pago_id is null then
      if v_f.estado = 'llegado' then
        perform public.natacion_equip_estado_set(v_f.id, 'llegado');   -- crea el enlace de pago
        v_aviso := 'Ahora tiene ' || v_f.total || ' € por pagar: se ha creado su enlace de pago (mándaselo por WhatsApp).';
      elsif v_f.estado in ('pagado', 'entregado') then
        v_aviso := 'Su pedido ya estaba cerrado: estos ' || v_f.total || ' € hay que cobrárselos aparte.';
      end if;
    end if;
    if v_aviso is not null then v_r := v_r || jsonb_build_object('aviso', v_aviso); end if;
  elsif p_sin_cargo is not null and p_sin_cargo <> v_l.sin_cargo then
    update public.natacion_equip_lineas set sin_cargo = p_sin_cargo where id = p_linea;
    v_r := public._natacion_equip_recalcular(v_l.familia_id);
  end if;
  return jsonb_build_object('ok', true) || v_r ||
         jsonb_build_object('estado', (select estado from public.natacion_equip_familias where id = v_l.familia_id));
end $$;
revoke all on function public.natacion_equip_linea_set(uuid, boolean, boolean, numeric) from public, anon;
grant execute on function public.natacion_equip_linea_set(uuid, boolean, boolean, numeric) to authenticated;

commit;
