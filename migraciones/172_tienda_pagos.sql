-- 172 · Pagos de la tienda (ropa) con tarjeta
-- ------------------------------------------------------------
-- Reutiliza el circuito de pagos que ya existe (pagos_online +
-- pago-webhook + pagos_confirmar/pagos_aplicar_efecto). El `tipo`
-- 'ropa' ya estaba previsto en el CHECK de pagos_online. Añade:
--   1) Columnas en `pedidos`: `contacto` (datos de quien compra sin
--      cuenta), `pago_online_id` (cruce con el pago) y `pagado_en`.
--   2) tienda_pago_iniciar(): desde un carrito, valida contra
--      `productos` (EL PRECIO SALE DE LA BASE), crea el pedido + líneas
--      y su fila de pago, y devuelve la referencia. SECURITY DEFINER,
--      así que vale también para INVITADOS (sin sesión).
--   3) pagos_aplicar_efecto(): cuando el pago es de tipo 'ropa', marca
--      el pedido como pagado (pagado_en). El caso 'bono' sigue igual.
--
-- El `estado` del pedido NO cambia al pagar: es su ciclo de preparación
-- (pendiente→preparando→listo→entregado). «Pagado» se sabe por pagado_en.
-- ============================================================

begin;

-- 1 · Columnas nuevas en pedidos
alter table public.pedidos
  add column if not exists contacto        jsonb not null default '{}'::jsonb,
  add column if not exists pago_online_id  uuid references public.pagos_online(id),
  add column if not exists pagado_en       timestamptz;

-- 2 · El efecto al confirmar: bono (igual) + ropa (marca el pedido pagado)
create or replace function public.pagos_aplicar_efecto(p_pago uuid)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_pago public.pagos_online;
  v_usos integer;
  v_dias integer;
  v_bono uuid;
begin
  select * into v_pago from public.pagos_online where id = p_pago for update;
  if not found then return 'no-existe'; end if;
  if v_pago.estado <> 'pagado' then return 'no-pagado'; end if;
  if v_pago.aplicado_en is not null then return 'ya-aplicado'; end if;

  if v_pago.tipo = 'bono' then
    v_usos := nullif(v_pago.metadatos ->> 'usos', '')::int;
    v_dias := nullif(v_pago.metadatos ->> 'caducidad_dias', '')::int;

    if v_pago.atleta_id is null or v_usos is null or v_usos <= 0 then
      update public.pagos_online
         set metadatos = metadatos || jsonb_build_object('aviso', 'Pago cobrado sin datos para dar el bono; revisar a mano.')
       where id = p_pago;
      return 'sin-datos';
    end if;

    insert into public.cubo_bonos (atleta_id, usos_totales, precio, fecha_compra, caducidad, activo, notas, pago_online_id)
    values (v_pago.atleta_id, v_usos, round(v_pago.importe_centimos::numeric / 100, 2), current_date,
            case when v_dias is not null then current_date + v_dias else null end,
            true, 'Pagado con tarjeta · ' || v_pago.referencia, v_pago.id)
    on conflict (pago_online_id) where pago_online_id is not null do nothing
    returning id into v_bono;

    if v_bono is null then
      update public.pagos_online set aplicado_en = coalesce(aplicado_en, now()) where id = p_pago;
      return 'ya-aplicado';
    end if;

  elsif v_pago.tipo = 'ropa' then
    -- El pedido de la tienda queda marcado como pagado. El ciclo de
    -- preparación (estado) lo lleva el club desde el panel.
    update public.pedidos
       set pagado_en = coalesce(pagado_en, now())
     where pago_online_id = v_pago.id;
  end if;

  update public.pagos_online set aplicado_en = now() where id = p_pago;
  return 'aplicado';
end;
$function$;

-- 3 · Abrir el pago de un carrito de la tienda
--     p_items:    [{"producto_id":"...","talla":"M","cantidad":2}, ...]
--     p_contacto: {"nombre":"...","email":"...","telefono":"...","recogida":"..."}
--     p_perfil:   la ficha del socio si viene con sesión; null si es invitado.
create or replace function public.tienda_pago_iniciar(
  p_items jsonb,
  p_contacto jsonb default '{}'::jsonb,
  p_perfil uuid default null,
  p_metadatos jsonb default '{}'::jsonb
)
returns public.pagos_online
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_cfg      public.pagos_config;
  v_item     jsonb;
  v_prod     public.productos;
  v_talla    text;
  v_cant     integer;
  v_total    numeric := 0;
  v_n        integer := 0;
  v_pedido   uuid;
  v_ref      text;
  v_pago     public.pagos_online;
  v_concepto text;
begin
  select * into v_cfg from public.pagos_config where id = 1;
  if not found or not v_cfg.activo then
    raise exception 'El pago con tarjeta todavía no está activado.' using errcode = 'P0001';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'El carrito está vacío.' using errcode = 'P0001';
  end if;

  -- El pedido nace primero, para colgar las líneas de él.
  insert into public.pedidos (perfil_id, estado, total, contacto)
  values (p_perfil, 'pendiente', 0, coalesce(p_contacto, '{}'::jsonb))
  returning id into v_pedido;

  -- Cada línea: se valida contra `productos` y el PRECIO SALE DE LA BASE.
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

    -- Si el producto tiene tallas, la elegida debe existir y no estar agotada.
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

    v_total := v_total + v_prod.precio * v_cant;
    v_n := v_n + v_cant;
  end loop;

  if v_total <= 0 then
    raise exception 'El total del pedido no es válido.' using errcode = 'P0001';
  end if;

  update public.pedidos set total = v_total where id = v_pedido;

  v_concepto := 'Pedido de tienda · ' || v_n || case when v_n = 1 then ' artículo' else ' artículos' end;

  v_ref := 'APO-' || to_char(now(), 'YYMMDD') || '-' ||
           upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  insert into public.pagos_online
    (referencia, perfil_id, concepto, tipo, importe_centimos, metadatos)
  values
    (v_ref, p_perfil, v_concepto, 'ropa', round(v_total * 100)::int,
     coalesce(p_metadatos, '{}'::jsonb) || jsonb_build_object('pedido_id', v_pedido, 'articulos', v_n))
  returning * into v_pago;

  -- Se cruza el pedido con su pago (para el efecto y para el panel).
  update public.pedidos set pago_online_id = v_pago.id where id = v_pedido;

  return v_pago;
end;
$function$;

-- Invitados (anon) y socios (authenticated) pueden abrir el pago.
-- Es SECURITY DEFINER: la función lo controla todo; el importe sale de la base.
grant execute on function public.tienda_pago_iniciar(jsonb, jsonb, uuid, jsonb) to anon, authenticated;

commit;
