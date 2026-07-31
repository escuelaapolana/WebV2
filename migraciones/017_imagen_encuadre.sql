-- 017_imagen_encuadre.sql
-- Permite elegir qué parte de la foto de cabecera se ve en cada página.
--
-- imagen_encuadre: valor CSS de object-position en porcentajes, por ejemplo '50% 30%'.
--                  Si está vacío, la página se ve exactamente como hasta ahora.
-- imagen_zoom:     escala de acercamiento, de 1.0 (sin acercar) a 2.5 (acercado al máximo).
alter table public.contenido_secciones
  add column if not exists imagen_encuadre text;

alter table public.contenido_secciones
  add column if not exists imagen_zoom numeric;
