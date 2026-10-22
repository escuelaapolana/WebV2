-- 425 · Tienda (22-oct-2026, Andrés): sudadera fuera de la tienda y fotos
-- reales sobre blanco de la camiseta del club (unisex) y los tirantes de chica.
-- Aplicada a mano por psql el mismo día; aquí queda por escrito.
begin;
update public.productos set activo = false where nombre = 'Sudadera del club';
update public.productos set imagen_url = 'tienda-camiseta-club-foto.jpg' where nombre = 'Camiseta del club';
update public.productos set imagen_url = 'tienda-tirantes-chica-foto.jpg' where nombre = 'Tirantes · chica';
commit;
