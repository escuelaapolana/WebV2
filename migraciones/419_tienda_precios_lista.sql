-- 419 · Tienda de ropa = la lista de precios de Andrés (21-oct-2026): camiseta 15, sudadera 35,
-- mochila 35, top 27, mallas 27, tirantes 27, pantalón de competición 27, mono 95.
-- Lo que no está en la lista (chaqueta de chándal, parka) se oculta (activo=false), no se borra.
begin;
update public.productos set precio = 27 where nombre = 'Top de competición';
update public.productos set precio = 27, nombre = 'Camiseta de tirantes' where nombre = 'Camiseta de tirantes · hombre';
update public.productos set activo = true, precio = 95 where nombre = 'Mono de velocidad';
update public.productos set precio = 35 where nombre = 'Mochila con zapatillero';
update public.productos set activo = false where nombre in ('Chaqueta de chándal', 'Parka del club');
insert into public.productos (nombre, descripcion, precio, categoria, tallas_disponibles, stock, activo, imagen_url, orden)
select v.nombre, null, v.precio, v.categoria, v.tallas, 0, true, v.img, v.orden
  from (values
    ('Camiseta del club', 15.00, 'ropa', '{4,6,8,10,12,14,XS,S,M,L,XL,XXL}'::text[], 'tienda-camiseta-competicion.jpg', 1),
    ('Sudadera del club', 35.00, 'ropa', '{4,6,8,10,12,14,S,M,L,XL,XXL}'::text[], 'tienda-sudadera-capucha.jpg', 2),
    ('Mallas', 27.00, 'equipacion', '{10,12,14,XS,S,M,L,XL,XXL}'::text[], null, 8),
    ('Pantalón de competición', 27.00, 'equipacion', '{10,12,14,XS,S,M,L,XL,XXL}'::text[], null, 9)
  ) v(nombre, precio, categoria, tallas, img, orden)
 where not exists (select 1 from public.productos p where p.nombre = v.nombre);
commit;
