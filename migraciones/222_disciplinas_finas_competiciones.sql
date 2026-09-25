-- 222 · Disciplinas más finas en las competiciones (para filtrar bien el calendario)
--
-- Antes `ambito` solo distinguía atletismo/natacion, y "atletismo" lo mezclaba
-- todo (una carrera salía a la vez en pista, running, escuela y montaña). Ahora
-- se permiten disciplinas concretas, para que cada competición caiga en SU
-- filtro: pista (atletismo de pista/controles), running (populares), natacion,
-- triatlon, escolar (informativo), montana. 'atletismo' se mantiene por
-- compatibilidad (lo amplio de siempre).
alter table public.competiciones drop constraint if exists competiciones_ambito_check;
alter table public.competiciones add constraint competiciones_ambito_check
  check (ambito = any (array['atletismo','natacion','pista','running','triatlon','escolar','montana']));
