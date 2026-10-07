-- 296 · Tienda: pedidos SIN pago online (pago en efectivo al recoger)
-- Andrés (7-oct): a día de hoy los pedidos de ropa llegan a admin pero se pagan
-- EN EFECTIVO en la oficina al recogerlos (se avisa cuando llega). Se DESACTIVA
-- el pago con tarjeta de la tienda, pero se siguen tomando pedidos.
--   · Flag nuevo `tienda_pago_online` en pagos_config (false = efectivo).
--   · RPC `tienda_pedido_efectivo`: crea el pedido + líneas (como tienda_pago_iniciar)
--     pero SIN pagos_online ni cobro, con nota de pago en efectivo.

alter table public.pagos_config
  add column if not exists tienda_pago_online boolean not null default true;

-- Desactivar el pago online de la tienda a partir de hoy.
update public.pagos_config set tienda_pago_online = false where id = 1;

create or replace function public.tienda_pedido_efectivo(p_items jsonb, p_contacto jsonb default '{}'::jsonb, p_perfil uuid default null)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_item   jsonb;
  v_prod   public.productos;
  v_talla  text;
  v_cant   integer;
  v_n      integer := 0;
  v_pedido uuid;
  v_total  numeric;
begin
  -- Al perfil de la sesión (invitado = sin perfil, con datos de contacto).
  if not public.es_admin() then
    p_perfil := public.mi_perfil_id();
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'El carrito está vacío.' using errcode = 'P0001';
  end if;

  insert into public.pedidos (perfil_id, estado, total, contacto, notas)
  values (p_perfil, 'pendiente', 0, coalesce(p_contacto, '{}'::jsonb), 'Pago en efectivo al recoger')
  returning id into v_pedido;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_talla := trim(coalesce(v_item ->> 'talla', ''));
    v_cant  := greatest(1, least(10, coalesce((v_item ->> 'cantidad')::int, 1)));
    select * into v_prod from public.productos
      where id = (v_item ->> 'producto_id')::uuid and activo;
    if not found then
      raise exception 'Uno de los productos ya no está disponible.' using errcode = 'P0001';
    end if;
    if v_prod.precio is null or v_prod.precio <= 0 then
      raise exception 'Un producto no tiene precio.' using errcode = 'P0001';
    end if;
    if v_prod.tallas_disponibles is not null and array_length(v_prod.tallas_disponibles, 1) > 0 then
      if v_talla = '' or not (v_talla = any(v_prod.tallas_disponibles)) then
        raise exception 'Talla no válida para %.', v_prod.nombre using errcode = 'P0001';
      end if;
      if v_prod.tallas_agotadas is not null and v_talla = any(v_prod.tallas_agotadas) then
        raise exception '% en talla % está agotado.', v_prod.nombre, v_talla using errcode = 'P0001';
      end if;
    else
      v_talla := nullif(v_talla, '');
    end if;
    insert into public.pedido_items (pedido_id, producto_id, talla, cantidad, precio_unitario)
    values (v_pedido, v_prod.id, v_talla, v_cant, v_prod.precio);
    v_n := v_n + v_cant;
  end loop;

  select total into v_total from public.pedidos where id = v_pedido;   -- lo fija el trigger
  return jsonb_build_object('ok', true, 'pedido_id', v_pedido, 'total', coalesce(v_total,0), 'n', v_n);
end;
$function$;

grant execute on function public.tienda_pedido_efectivo(jsonb, jsonb, uuid) to authenticated, anon;
