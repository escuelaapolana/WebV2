-- 424 · Tienda: fotos reales (fondo blanco) y variantes de top y tirantes
-- ---------------------------------------------------------------------------
-- Andrés (22-oct-2026) pasó fotos de las prendas de verdad: «Top largo
-- (también hay corto)», «Malla chica», «Tirantes (hay de chico y chica)» y
-- «Pantalón de chico de competición». Fondo quitado y en blanco.
--   · Top de competición → «Top corto» (su foto) + nuevo «Top largo».
--   · Camiseta de tirantes → «Tirantes · chico» (foto real) + nuevo
--     «Tirantes · chica» (de momento con el diseño de chica).
--   · Mallas y Pantalón de competición: ya tienen foto.
-- Mismo precio y tallas que la prenda de la que salen (27 €). Sin pedidos
-- todavía (pedido_items vacío), así que renombrar no rompe nada.
-- ---------------------------------------------------------------------------
begin;

update public.productos set nombre = 'Top corto', imagen_url = 'tienda-top-corto-foto.jpg'
 where nombre = 'Top de competición';
insert into public.productos (nombre, descripcion, precio, categoria, tallas_disponibles, stock, activo, imagen_url, tallas_agotadas, orden)
select 'Top largo', descripcion, precio, categoria, tallas_disponibles, stock, activo, 'tienda-top-largo-foto.jpg', '{}', orden
  from public.productos where nombre = 'Top corto'
   and not exists (select 1 from public.productos where nombre = 'Top largo');

update public.productos set nombre = 'Tirantes · chico', imagen_url = 'tienda-tirantes-chico-foto.jpg'
 where nombre = 'Camiseta de tirantes';
insert into public.productos (nombre, descripcion, precio, categoria, tallas_disponibles, stock, activo, imagen_url, tallas_agotadas, orden)
select 'Tirantes · chica', descripcion, precio, categoria, tallas_disponibles, stock, activo, 'tienda-camiseta-tirantes-mujer-frente.jpg', tallas_agotadas, orden
  from public.productos where nombre = 'Tirantes · chico'
   and not exists (select 1 from public.productos where nombre = 'Tirantes · chica');

update public.productos set imagen_url = 'tienda-mallas-foto.jpg' where nombre = 'Mallas';
update public.productos set imagen_url = 'tienda-pantalon-competicion-foto.jpg' where nombre = 'Pantalón de competición';

commit;
