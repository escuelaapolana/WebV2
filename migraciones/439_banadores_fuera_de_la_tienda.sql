-- 439 · Los bañadores de natación NO se leen desde la tienda pública (ni con
-- una versión vieja de /tienda/ guardada en caché). Una madre de atletismo los
-- vio el 22-oct. Solo los ve el pedido de equipación de natación, que va por
-- RPC SECURITY DEFINER (natacion_equip_publica), y el panel (admin/escuela).
begin;
alter policy "lectura publica" on public.productos using (coalesce(categoria, '') <> 'banador');
alter policy "Productos visibles logueados" on public.productos
  using (((select auth.uid()) is not null) and activo = true and coalesce(categoria, '') <> 'banador');
commit;
