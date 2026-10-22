-- 437 · Natación: los bañadores Mad Wave del club (diseño 2025) en el catálogo,
-- APAGADOS (precio 0) hasta que Mario pase precio y tallas (salen en el pedido de
-- equipación, mig 436, en cuanto estén activos y con precio).
begin;
alter table public.productos drop constraint if exists productos_categoria_check;
alter table public.productos add constraint productos_categoria_check
  check (categoria = any (array['ropa'::text, 'accesorio'::text, 'equipacion'::text, 'otro'::text, 'banador'::text]));
insert into public.productos (nombre, descripcion, precio, categoria, tallas_disponibles, stock, activo, imagen_url, tallas_agotadas, orden, seccion, equipacion_natacion)
select x.nombre, x.descr, 0, 'banador', '{}', 0, false, x.img, '{}', x.ord, 'natacion', true
  from (values ('Bañador tirante fino', 'Mad Wave · diseño del club', 'natacion-banador-tfds.jpg', 1),
               ('Bañador tirante ancho', 'Mad Wave · diseño del club', 'natacion-banador-tadsn.jpg', 2),
               ('Bikini', 'Mad Wave · diseño del club', 'natacion-bikini.jpg', 3),
               ('Jammer', 'Mad Wave · diseño del club', 'natacion-jammer.jpg', 4),
               ('Slip', 'Mad Wave · diseño del club', 'natacion-slip.jpg', 5)) as x(nombre, descr, img, ord)
 where not exists (select 1 from public.productos p where p.nombre = x.nombre);
commit;
