-- 445 · Equipación de natación: gorros de más, de pago (6 €)
-- ---------------------------------------------------------------------------
-- Andrés (26-oct): «si quieren gorro extra, 6 €. Añádelo».
--   · Cada nadador sigue teniendo SU gorro gratis (o «no»).
--   · Puede pedir hasta 5 gorros más a 6 € cada uno (talla única).
--   · Se guardan como UNA línea 'gorro' con el mismo nombre que el gratis,
--     cantidad = cuántos y precio_unitario = 6 (el Excel del proveedor suma
--     por nombre y talla; el formulario distingue la gratis por precio > 0).
-- Igual que las camisetas de más (mig 443).
-- ---------------------------------------------------------------------------
begin;

create or replace function public._natacion_equip_precio_gorro()
returns numeric
language sql immutable
as $function$ select 6::numeric $function$;
revoke all on function public._natacion_equip_precio_gorro() from public, anon, authenticated;

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
    'precio_gorro', public._natacion_equip_precio_gorro(),
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
     -- (mig 445) Gorros de más, de pago: una línea con la cantidad.
     v_cant := least(5, greatest(0, coalesce((x ->> 'gorros_extra')::int, 0)));
     if v_cant > 0 then
       insert into public.natacion_equip_lineas (familia_id, nadador_id, articulo, nombre, talla, cantidad, precio_unitario)
       values (v_f.id, v_n.id, 'gorro', 'Gorro de natación', null, v_cant, public._natacion_equip_precio_gorro());
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

-- Los textos del correo (mig 444; Mario aún no los había tocado) mencionan el gorro.
update public.natacion_equip_textos
   set cuerpo = replace(cuerpo, 'Si queréis más de una camiseta, cada una de más cuesta 15 €.', 'Si queréis más, cada camiseta de más cuesta 15 € y cada gorro de más, 6 €.'), updated_at = now()
 where clave in ('escuela', 'nuevo') and updated_by is null;
update public.natacion_equip_textos
   set cuerpo = replace(cuerpo, 'Si quieres más de una camiseta, cada una de más cuesta 15 €.', 'Si quieres más, cada camiseta de más cuesta 15 € y cada gorro de más, 6 €.'), updated_at = now()
 where clave = 'master' and updated_by is null;

commit;
