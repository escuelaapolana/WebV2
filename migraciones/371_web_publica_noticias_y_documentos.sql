-- 371 · Noticias y documentos públicos vuelven a verse SIN sesión
-- ---------------------------------------------------------------------------
-- Revisión de la web (15-oct-2026): con la clave pública, `noticias` y
-- `documentos` daban 401, así que la portada enseñaba las noticias de ejemplo
-- del HTML y /club/normativa/ no cargaba sus documentos.
--   · noticias: la política «Admin gestiona noticias» era para TODOS los papeles
--     (también anon) y consultaba `perfiles`, que anon no puede leer → error
--     para todo el SELECT. Está repetida por «admin gestiona» (es_admin()) → fuera.
--   · documentos: «el grupo lee sus recursos» y «entrenador gestiona…» eran para
--     todos y llamaban a funciones que anon no puede ejecutar → solo authenticated.
-- Nada se abre de más: solo se quitan/estrechan políticas.
-- ---------------------------------------------------------------------------
begin;

drop policy if exists "Admin gestiona noticias" on public.noticias;

alter policy "el grupo lee sus recursos" on public.documentos to authenticated;
alter policy "entrenador gestiona recursos de su grupo" on public.documentos to authenticated;

commit;
