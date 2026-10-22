-- 426 · Tienda: fotos del catálogo corregido (22-oct-2026, Andrés) — las
-- mismas prendas sin arrugas, fondo blanco. Sustituyen a las de la 424/425.
begin;
update public.productos set imagen_url = 'tienda-camiseta-club-v2.jpg'        where nombre = 'Camiseta del club';
update public.productos set imagen_url = 'tienda-tirantes-chico-v2.jpg'       where nombre = 'Tirantes · chico';
update public.productos set imagen_url = 'tienda-tirantes-chica-v2.jpg'       where nombre = 'Tirantes · chica';
update public.productos set imagen_url = 'tienda-top-corto-v2.jpg'            where nombre = 'Top corto';
update public.productos set imagen_url = 'tienda-top-largo-v2.jpg'            where nombre = 'Top largo';
update public.productos set imagen_url = 'tienda-mallas-v2.jpg'               where nombre = 'Mallas';
update public.productos set imagen_url = 'tienda-pantalon-competicion-v2.jpg' where nombre = 'Pantalón de competición';
commit;
update public.productos set imagen_url = 'tienda-mono-v2.jpg' where nombre = 'Mono de velocidad';  -- 22-oct: foto del mono centrada
