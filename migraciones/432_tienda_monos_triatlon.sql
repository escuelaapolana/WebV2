-- 432 · Tienda: monos de triatlón (Andrés, 22-oct-2026)
-- Proveedor SP: tirantes 55,50 + IVA y larga distancia 85 + IVA, desde 1 unidad,
-- ~3 semanas, nombre sin coste. Se venden a coste redondeado: 68 € y 103 €.
-- Misma foto (diseño de hombre, v3) en los dos hasta que llegue el de mujer.
-- El nombre a estampar va en «Observaciones» del encargo.
begin;
insert into public.productos (nombre, descripcion, precio, categoria, tallas_disponibles, stock, activo, imagen_url, tallas_agotadas, orden)
select x.nombre, x.descr, x.precio, 'equipacion', array['XS','S','M','L','XL','XXL'], 0, true, 'tienda-mono-triatlon.jpg', '{}', 6
  from (values ('Mono de triatlón', 'Mono de tirantes, hombre y mujer. Con tu nombre sin coste (ponlo en observaciones).', 68.00),
               ('Mono de triatlón larga distancia', 'Para larga distancia. Con tu nombre sin coste (ponlo en observaciones).', 103.00)) as x(nombre, descr, precio)
 where not exists (select 1 from public.productos p where p.nombre = x.nombre);
commit;
