-- 197 · Marcas en texto libre por sesión
-- Modo simple del entreno (grupo Academia AC98 de momento): el atleta ya no
-- rellena tiempo por serie; marca cada bloque como hecho y escribe sus marcas
-- en un cuadro de texto libre («150 s1: 22.4 / s2: 22.1…»). Ese texto vive
-- aquí, aparte de `notas_atleta` (que es «cómo me fue»), para que el
-- entrenador lo lea claro.
alter table public.registros_sesion
  add column if not exists marcas_texto text;
