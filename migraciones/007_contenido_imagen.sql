-- 007_contenido_imagen.sql
-- Añade una columna para la imagen de cabecera (hero) de cada página de sección.
-- La URL apunta a una foto del bucket público "imagenes" (la biblioteca).
alter table public.contenido_secciones
  add column if not exists imagen_url text;
