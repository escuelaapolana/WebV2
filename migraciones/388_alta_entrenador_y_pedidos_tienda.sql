-- 388 · Dos fallos que ya existían, hallados en la revisión del 15-oct-2026
-- 1) Alta de entrenador ROTA: alta_entrenador (mig 233) guarda la invitación con el
--    papel 'pendiente' (sin permisos hasta que un admin lo apruebe), pero las reglas de
--    invitaciones_equipo y perfiles no lo admitían → «No se ha podido» a todo correo nuevo.
-- 2) Tienda: los pedidos hechos con sesión se guardaban sin perfil (ver abajo).
begin;

alter table public.invitaciones_equipo drop constraint invitaciones_rol_valido;
alter table public.invitaciones_equipo add constraint invitaciones_rol_valido check (rol = any (array['admin','coordinador','entrenador','atleta','padre','tesoreria','contabilidad','junta','cubo','cubo-atleta','cubo-lista','socio','pendiente']));
alter table public.invitaciones_equipo drop constraint invitaciones_roles_validos;
alter table public.invitaciones_equipo add constraint invitaciones_roles_validos check (roles is null or roles <@ array['admin','coordinador','entrenador','atleta','padre','tesoreria','contabilidad','junta','cubo','cubo-atleta','cubo-lista','socio','pendiente']);
alter table public.perfiles drop constraint perfiles_rol_check;
alter table public.perfiles add constraint perfiles_rol_check check (rol = any (array['admin','coordinador','entrenador','atleta','padre','tesoreria','contabilidad','junta','cubo','escuela','cubo-atleta','cubo-lista','socio','responsable','pendiente']));
alter table public.perfiles drop constraint perfiles_roles_check;
alter table public.perfiles add constraint perfiles_roles_check check (roles is null or roles <@ array['admin','coordinador','entrenador','atleta','padre','tesoreria','contabilidad','junta','cubo','escuela','cubo-atleta','cubo-lista','socio','responsable','pendiente']);

CREATE OR REPLACE FUNCTION public.tienda_pago_iniciar(p_items jsonb, p_contacto jsonb DEFAULT '{}'::jsonb, p_perfil uuid DEFAULT NULL::uuid, p_metadatos jsonb DEFAULT '{}'::jsonb)
 RETURNS pagos_online
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  -- 386 · Freno por IP a las llamadas directas (la Edge tienda-pagar llama con
  -- service_role: ahí la IP sería la de Supabase, no la del comprador).
  if coalesce(auth.role(), '') <> 'service_role' then
    perform public.anti_spam('tienda_pago', 10, interval '10 minutes');
  end if;

  select * into v_cfg from public.pagos_config where id = 1;
  if not found or not v_cfg.activo then
    raise exception 'El pago con tarjeta todavía no está activado.' using errcode = 'P0001';
  end if;

  -- SEGURIDAD: no fiarse del p_perfil del cliente. Se ata al perfil de la sesión
  -- (mi_perfil_id() = null si es invitado, y entonces el pedido va sin perfil, con
  -- los datos de contacto). Solo un admin puede crear a nombre de otro.
  -- 388 · La Edge tienda-pagar (service_role) ya resuelve el perfil del comprador
  -- en el servidor a partir de SU sesión; con service_role mi_perfil_id() es null
  -- y el pedido se quedaba sin dueño. Desde el navegador sigue sin fiarse.
  if not public.es_admin() and coalesce(auth.role(), '') <> 'service_role' then
    p_perfil := public.mi_perfil_id();
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'El carrito está vacío.' using errcode = 'P0001';
  end if;

  insert into public.pedidos (perfil_id, estado, total, contacto)
  values (p_perfil, 'pendiente', 0, coalesce(p_contacto, '{}'::jsonb))
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

  update public.pedidos set pago_online_id = v_pago.id where id = v_pedido;

  return v_pago;
end;
$function$;

CREATE OR REPLACE FUNCTION public.tienda_pedido_efectivo(p_items jsonb, p_contacto jsonb DEFAULT '{}'::jsonb, p_perfil uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item   jsonb;
  v_prod   public.productos;
  v_talla  text;
  v_cant   integer;
  v_n      integer := 0;
  v_pedido uuid;
  v_total  numeric;
begin
  -- 386 · Freno por IP a las llamadas directas (la Edge tienda-pagar llama con
  -- service_role: ahí la IP sería la de Supabase, no la del comprador).
  if coalesce(auth.role(), '') <> 'service_role' then
    perform public.anti_spam('tienda_efectivo', 10, interval '10 minutes');
  end if;
  -- Al perfil de la sesión (invitado = sin perfil, con datos de contacto).
  -- 388 · La Edge tienda-pagar (service_role) ya resuelve el perfil del comprador
  -- en el servidor a partir de SU sesión; con service_role mi_perfil_id() es null
  -- y el pedido se quedaba sin dueño. Desde el navegador sigue sin fiarse.
  if not public.es_admin() and coalesce(auth.role(), '') <> 'service_role' then
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

commit;
