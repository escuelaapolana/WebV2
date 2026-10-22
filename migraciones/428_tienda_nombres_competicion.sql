-- 428 · Tienda: «de competición» en el nombre de la ropa de competición
-- (Andrés, 22-oct-2026: «tirantes competición, top competición, etc.»).
begin;
update public.productos set nombre = 'Tirantes de competición · chico' where nombre = 'Tirantes · chico';
update public.productos set nombre = 'Tirantes de competición · chica' where nombre = 'Tirantes · chica';
update public.productos set nombre = 'Top de competición corto'        where nombre = 'Top corto';
update public.productos set nombre = 'Top de competición largo'        where nombre = 'Top largo';
update public.productos set nombre = 'Mallas de competición'           where nombre = 'Mallas';
commit;
