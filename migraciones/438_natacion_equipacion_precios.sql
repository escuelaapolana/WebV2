-- 438 · Natación: precios y tallas de los bañadores (formulario de Mario,
-- 22-oct-2026) y ajustes del pedido de equipación.
--   · Slip 29 €, Jammer 41 €, Tirante ancho 40 €, Tirante fino 40 €, Bikini 40 €.
--   · La «chaqueta» del formulario es la sudadera con capucha (= Chaqueta de
--     chándal de la tienda): no se ofrece otra vez como extra.
--   · Los bañadores NO salen en la tienda pública (solo en el pedido de natación).
begin;
update public.productos set nombre = 'Bañador niño (slip)',        precio = 29, tallas_disponibles = '{8,10,XXS,XS,S,M}', activo = true where nombre = 'Slip';
update public.productos set nombre = 'Bañador jammer',             precio = 41, tallas_disponibles = '{8,10,XXS,XS,S,M}', activo = true where nombre = 'Jammer';
update public.productos set nombre = 'Bañador niña tirante ancho', precio = 40, tallas_disponibles = '{8,10,XXS,XS,S,M}', activo = true where nombre = 'Bañador tirante ancho';
update public.productos set nombre = 'Bañador niña tirante fino',  precio = 40, tallas_disponibles = '{10,XXS,XS,S,M}',  activo = true where nombre = 'Bañador tirante fino';
update public.productos set nombre = 'Bikini',                     precio = 40, tallas_disponibles = '{10,XXS,XS,S,M}',  activo = true where nombre = 'Bikini' and categoria = 'banador';
update public.productos set orden = 1 where nombre = 'Bañador niño (slip)';
update public.productos set orden = 2 where nombre = 'Bañador jammer';
update public.productos set orden = 3 where nombre = 'Bañador niña tirante ancho';
update public.productos set orden = 4 where nombre = 'Bañador niña tirante fino';
update public.productos set orden = 5 where nombre = 'Bikini' and categoria = 'banador';
update public.productos set equipacion_natacion = false where nombre = 'Chaqueta de chándal';
commit;
