-- 221 · El responsable de sección edita los TEXTOS y FOTOS de las páginas de su
-- sección (el editor en vivo del sitio público).
--
-- Se scopea por el PREFIJO de la clave (data-texto / data-img), que siempre es
-- el slug de la sección: 'natacion.hero.titulo', 'escuela-natacion.cuotas.nota'…
-- Así Mario (responsable de natacion + escuela-natacion) solo puede tocar esas
-- páginas, y no las demás. La lectura ya es pública; esto añade la escritura.

drop policy if exists "responsable edita textos de su seccion" on public.textos_web;
create policy "responsable edita textos de su seccion" on public.textos_web for all to authenticated
  using      (public.soy_responsable(split_part(clave, '.', 1)))
  with check (public.soy_responsable(split_part(clave, '.', 1)));

drop policy if exists "responsable edita imagenes de su seccion" on public.imagenes_web;
create policy "responsable edita imagenes de su seccion" on public.imagenes_web for all to authenticated
  using      (public.soy_responsable(split_part(clave, '.', 1)))
  with check (public.soy_responsable(split_part(clave, '.', 1)));
