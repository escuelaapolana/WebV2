-- 228 · Lectura pública de la edición activa y del baremo de la Liga
--
-- El formulario público de "comunica tu prueba" necesita leer la edición en
-- marcha y la tabla de puntos (baremo) para poblar los desplegables y enseñar
-- los puntos. No son datos sensibles (el baremo se publica como "Tabla de
-- puntos"). Escritura sigue solo para admin/junta.

grant select on public.liga_ediciones to anon;
grant select on public.liga_baremo    to anon;

drop policy if exists "liga ediciones lectura publica" on public.liga_ediciones;
create policy "liga ediciones lectura publica" on public.liga_ediciones for select to anon using (true);

drop policy if exists "liga baremo lectura publica" on public.liga_baremo;
create policy "liga baremo lectura publica" on public.liga_baremo for select to anon using (true);
