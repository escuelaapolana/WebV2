-- 191 · Arreglo: dar EXECUTE de es_cubo_lista() a anon/authenticated
-- --------------------------------------------------------------------
-- La mig 190 creó es_cubo_lista() y una política de cubo_altas que la usa,
-- pero NO le dio permiso de EXECUTE a los roles del front. Como la política
-- se evalúa en CADA lectura de cubo_altas, cualquier usuario (admin, portal
-- del padre, panel) recibía «permission denied for function es_cubo_lista»
-- y no podía leer las altas. Se concede igual que es_admin() (a PUBLIC).

grant execute on function public.es_cubo_lista() to anon, authenticated;
