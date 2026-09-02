-- ============================================================
-- 161 · Recreación 1 y 2 entran en el reparto (2ª hora, modelo simple)
-- ------------------------------------------------------------
-- Se deja el modelo SENCILLO que pidió Andrés: Recreación va en dos
-- turnos de 2 días —lunes/miércoles y martes/jueves—, igual que la 1ª
-- hora. El viernes (donde en realidad se unifican) lo lleva a mano; no
-- se modela aquí para no complicar.
--
-- Con esto, Recreación queda como grupos de escuela CON turno, así que
-- el reparto que ya existe los coge solos como columnas, y coloca a cada
-- niño por su año de nacimiento. No hace falta tocar la función.
--   · Recreación 1 → nacidos 2012, 2013 y 2014
--   · Recreación 2 → nacidos 2009, 2010 y 2011
-- Fondo-Mediofondo se queda SIN turno: es de selección, no se reparte.
-- ============================================================

-- El registro que creó la 159 (sin turno) pasa a ser el de lunes/miércoles.
update public.grupos
   set turno = 'lunes-miercoles', nacidos_desde = 2012, nacidos_hasta = 2014
 where nombre = 'Recreación 1' and turno is null;

insert into public.grupos (nombre, seccion, activo, turno, nacidos_desde, nacidos_hasta, descripcion)
select 'Recreación 1', 'escuela', true, 'martes-jueves', 2012, 2014, '2ª hora · nacidos 2012-2014'
where not exists (select 1 from public.grupos where nombre = 'Recreación 1' and turno = 'martes-jueves');

update public.grupos
   set turno = 'lunes-miercoles', nacidos_desde = 2009, nacidos_hasta = 2011
 where nombre = 'Recreación 2' and turno is null;

insert into public.grupos (nombre, seccion, activo, turno, nacidos_desde, nacidos_hasta, descripcion)
select 'Recreación 2', 'escuela', true, 'martes-jueves', 2009, 2011, '2ª hora · nacidos 2009-2011'
where not exists (select 1 from public.grupos where nombre = 'Recreación 2' and turno = 'martes-jueves');
