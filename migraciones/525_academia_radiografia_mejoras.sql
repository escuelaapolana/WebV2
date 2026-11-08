-- 525 · Academia · Radiografía: cómo mejorar cada punto
-- ---------------------------------------------------------------------------
-- Andrés (8-nov-2026): que la radiografía diga cómo mejoraría las partes malas y
-- si cada una se trabaja o no. Por punto: {punto, decision, porque, como}, donde
-- decision es 'si' | 'mantener' | 'no_ahora' | 'medir'. Misma tabla y mismos
-- permisos que la 524: solo la lee el entrenador del grupo.
-- ---------------------------------------------------------------------------
alter table public.academia_radiografia add column if not exists mejoras jsonb not null default '[]'::jsonb;
