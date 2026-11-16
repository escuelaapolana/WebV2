-- 530 · Documentos: «Solo el panel» (visibilidad 'admin')
--
-- Andrés (16-nov-2026) quiere guardar en la app documentos internos (p. ej.
-- el listado de entradas del club a piscinas y estadio) sin que los vean los
-- socios. Hasta ahora solo había público / socios / grupo.
-- Con 'admin': lo lee solo quien gestiona documentos (política «admin
-- gestiona documentos»); las políticas de socios, grupo y anon no lo
-- incluyen, y el archivo va al cubo cerrado documentos-socios, cuya política
-- de lectura tampoco incluye 'admin'.

alter table public.documentos drop constraint documentos_visibilidad_check;
alter table public.documentos add constraint documentos_visibilidad_check
  check (visibilidad = any (array['publico'::text, 'socios'::text, 'grupo'::text, 'admin'::text]));
