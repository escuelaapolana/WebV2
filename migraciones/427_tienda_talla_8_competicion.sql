-- 427 · Tienda: talla 8 en la ropa de competición (Andrés, 22-oct-2026).
-- Las prendas de competición que empezaban en la 10 (tirantes, tops, mallas,
-- pantalón) pasan a empezar en la 8. El mono va de XS a XXL y no se toca.
begin;
update public.productos
   set tallas_disponibles = array['8'] || tallas_disponibles
 where activo and categoria = 'equipacion'
   and tallas_disponibles[1] = '10'
   and not ('8' = any(tallas_disponibles));
commit;
