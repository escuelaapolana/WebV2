-- ============================================================
-- 158 · Etiqueta «escuela municipal»
-- ------------------------------------------------------------
-- Las personas eran escuela o socio. Ahora hay una tercera:
-- «municipal» (programa de la escuela municipal del Ayuntamiento).
-- Es una etiqueta de la persona, aparte del grupo, y siempre se
-- pone a mano (no se deduce por la edad). El municipal entrena 2
-- días por semana, sin viernes, aunque su grupo sea de tres.
-- ============================================================

alter table public.atletas drop constraint if exists atletas_tipo_membresia_check;
alter table public.atletas add constraint atletas_tipo_membresia_check
  check (tipo_membresia is null or tipo_membresia = any (array['escuela','socio','municipal']));
