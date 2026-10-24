-- 443 · Equipación de natación: una camiseta gratis y, si se quieren, más de pago
-- ---------------------------------------------------------------------------
-- Mario (24-oct): «hay quienes quieren más de 1 camiseta, aunque sea pagando.
-- Tienen que tener la opción de 1 gratuita y más de pago».
--   · Cada nadador sigue teniendo SU camiseta gratis (o «no la necesito»).
--   · Puede añadir hasta 5 camisetas más, cada una con su talla, al precio de
--     la «Camiseta del club» de la tienda (15 €; si cambia allí, cambia aquí).
--   · Se guardan como líneas 'camiseta' con el mismo nombre que la gratis
--     (el Excel del proveedor las suma por talla) y su precio (sale en el
--     total y en el recibo que se crea al llegar la ropa).
-- ---------------------------------------------------------------------------
begin;

create or replace function public._natacion_equip_precio_camiseta()
returns numeric
language sql stable security definer
set search_path to 'public'
as $function$
  select coalesce((select precio from public.productos where nombre = 'Camiseta del club' limit 1), 15)
$function$;
revoke all on function public._natacion_equip_precio_camiseta() from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.natacion_equip_publica(p_token text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'contacto', initcap(lower(split_part(btrim(coalesce(f.contacto, '')), ' ', 1))),
    'estado', f.estado, 'total', f.total, 'compromiso', f.compromiso,
    'respondido', f.respondido_en is not null,
    'pago_enlace', case when p.token_pago is not null and p.estado <> 'pagado' and not p.anulado
                        then 'https://atletismoapolana.com/pagar/?t=' || p.token_pago end,
    'pagado', coalesce(p.estado = 'pagado', false) or f.estado in ('pagado', 'entregado'),
    'precio_sudadera', public._natacion_equip_precio_sudadera(),
    'precio_camiseta', public._natacion_equip_precio_camiseta(),
    'tallas', to_jsonb(public._natacion_equip_tallas()),
    'nadadores', coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'nombre', initcap(lower(n.nombre)), 'tipo', n.tipo, 'nuevo', n.nuevo)
                                            order by n.nombre)
                             from public.natacion_equip_nadadores n where n.familia_id = f.id), '[]'),
    'lineas', coalesce((select jsonb_agg(jsonb_build_object('nadador_id', l.nadador_id, 'articulo', l.articulo, 'producto_id', l.producto_id,
                                                             'nombre', l.nombre, 'talla', l.talla, 'cantidad', l.cantidad, 'precio', l.precio_unitario))
                          from public.natacion_equip_lineas l where l.familia_id = f.id), '[]'),
    'productos', coalesce((select jsonb_agg(jsonb_build_object('id', pr.id, 'nombre', pr.nombre, 'precio', pr.precio,
                                                                'tallas', pr.tallas_disponibles, 'imagen', pr.imagen_url,
                                                                'banador', coalesce(pr.categoria, '') = 'banador')
                                             order by coalesce(pr.categoria, '') = 'banador' desc, pr.orden nulls last, pr.nombre)
                             from public.productos pr where pr.equipacion_natacion and pr.activo), '[]'))
    from public.natacion_equip_familias f
    left join public.pagos p on p.id = f.pago_id
   where length(coalesce(p_token, '')) >= 40 and f.token = p_token
   limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.natacion_equip_guardar(p_token text, p_datos jsonb)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
 AS $function$
 declare
   v_f public.natacion_equip_familias%rowtype;
   v_n public.natacion_equip_nadadores%rowtype;
   x jsonb; v_t text; v_pr public.productos%rowtype; v_cant int; v_hay_ban boolean := false; v_total numeric := 0;
   v_tallas text[] := public._natacion_equip_tallas();
 begin
   select * into v_f from public.natacion_equip_familias where length(coalesce(p_token, '')) >= 40 and token = p_token for update;
   if not found then raise exception 'Este enlace no es válido.' using errcode = 'P0001'; end if;
   if v_f.estado not in ('pendiente', 'pedido') then
     raise exception 'El pedido ya se ha hecho y no se puede cambiar. Si necesitas algo, escríbenos.' using errcode = 'P0001';
   end if;

   delete from public.natacion_equip_lineas where familia_id = v_f.id;

   for x in select * from jsonb_array_elements(coalesce(p_datos -> 'nadadores', '[]'))
   loop
     select * into v_n from public.natacion_equip_nadadores where id = (x ->> 'id')::uuid and familia_id = v_f.id;
     continue when not found;
     v_t := nullif(btrim(coalesce(x ->> 'camiseta', '')), '');
     if v_t is not null then
       if not (v_t = any(v_tallas)) then raise exception 'Talla de camiseta no válida.' using errcode = 'P0001'; end if;
       insert into public.natacion_equip_lineas (familia_id, nadador_id, articulo, nombre, talla, precio_unitario)
       values (v_f.id, v_n.id, 'camiseta', 'Camiseta oficial del club', v_t, 0);
     end if;
     -- (mig 443) Camisetas de más, de pago: una línea por talla pedida, con el
     -- mismo nombre que la gratis para que el proveedor las sume juntas.
     for v_t in select btrim(t) from jsonb_array_elements_text(coalesce(x -> 'camisetas_extra', '[]')) with ordinality as e(t, o) where o <= 5
     loop
       continue when v_t = '';
       if not (v_t = any(v_tallas)) then raise exception 'Talla de camiseta no válida.' using errcode = 'P0001'; end if;
       insert into public.natacion_equip_lineas (familia_id, nadador_id, articulo, nombre, talla, precio_unitario)
       values (v_f.id, v_n.id, 'camiseta', 'Camiseta oficial del club', v_t, public._natacion_equip_precio_camiseta());
     end loop;
     if coalesce((x ->> 'gorro')::boolean, false) then
       insert into public.natacion_equip_lineas (familia_id, nadador_id, articulo, nombre, talla, precio_unitario)
       values (v_f.id, v_n.id, 'gorro', 'Gorro de natación', null, 0);
     end if;
     v_t := nullif(btrim(coalesce(x ->> 'sudadera', '')), '');
     if v_t is not null then
       if not (v_t = any(v_tallas)) then raise exception 'Talla de sudadera no válida.' using errcode = 'P0001'; end if;
       insert into public.natacion_equip_lineas (familia_id, nadador_id, articulo, nombre, talla, precio_unitario)
       values (v_f.id, v_n.id, 'sudadera', 'Chaqueta del club', v_t,
               case when v_n.nuevo then 0 else public._natacion_equip_precio_sudadera() end);
     end if;
   end loop;

   for x in select * from jsonb_array_elements(coalesce(p_datos -> 'extras', '[]'))
   loop
     select * into v_pr from public.productos where id = (x ->> 'producto_id')::uuid and equipacion_natacion and activo;
     if not found then raise exception 'Uno de los artículos ya no está disponible. Recarga la página.' using errcode = 'P0001'; end if;
     v_t := nullif(btrim(coalesce(x ->> 'talla', '')), '');
     if coalesce(array_length(v_pr.tallas_disponibles, 1), 0) > 0 and not (coalesce(v_t, '') = any(v_pr.tallas_disponibles)) then
       raise exception 'Talla no válida para %.', v_pr.nombre using errcode = 'P0001';
     end if;
     v_cant := greatest(1, least(10, coalesce((x ->> 'cantidad')::int, 1)));
     if coalesce(v_pr.categoria, '') = 'banador' then v_hay_ban := true; end if;
     insert into public.natacion_equip_lineas (familia_id, nadador_id, articulo, producto_id, nombre, talla, cantidad, precio_unitario)
     values (v_f.id,
             (select n.id from public.natacion_equip_nadadores n where n.id = nullif(x ->> 'nadador_id', '')::uuid and n.familia_id = v_f.id),
             'producto', v_pr.id, v_pr.nombre, v_t, v_cant, coalesce(v_pr.precio, 0));
   end loop;

   if v_hay_ban and not coalesce((p_datos ->> 'compromiso')::boolean, false) then
     raise exception 'Para encargar bañadores hay que marcar el compromiso de compra.' using errcode = 'P0001';
   end if;

   select coalesce(sum(cantidad * precio_unitario), 0) into v_total from public.natacion_equip_lineas where familia_id = v_f.id;
   update public.natacion_equip_familias
      set estado = 'pedido', total = v_total, compromiso = coalesce((p_datos ->> 'compromiso')::boolean, false), respondido_en = now()
    where id = v_f.id;
   return jsonb_build_object('ok', true, 'total', v_total);
 end;
 $function$;

commit;
