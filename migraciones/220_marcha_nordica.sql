-- 220 · Nueva disciplina de la Liga: MARCHA NÓRDICA
--
-- Se añade 'marcha_nordica' como disciplina propia, con su baremo (más bajo que
-- correr: andar no cuesta lo mismo). Para la clasificación cuenta DENTRO de
-- 'trail' (resistencia al aire libre), pero puntúa aparte con su propia escala.

-- 1) Ampliar el enum de disciplina en las dos tablas que lo comprueban
alter table public.liga_participaciones drop constraint if exists liga_part_disciplina_check;
alter table public.liga_participaciones add constraint liga_part_disciplina_check
  check (disciplina = any (array['atletismo','running','trail','triatlon','duatlon','aquabike','acuatlon','natacion','marcha_nordica']));

alter table public.liga_baremo drop constraint if exists liga_baremo_disciplina_check;
alter table public.liga_baremo add constraint liga_baremo_disciplina_check
  check (disciplina = any (array['atletismo','running','trail','triatlon','duatlon','aquabike','acuatlon','natacion','marcha_nordica']));

-- 2) Baremo de marcha nórdica (por debajo de running: 16/20/28/38)
insert into public.liga_baremo (edicion_id, disciplina, familia, modalidad, distancia_km, puntos, orden)
values
  ('11111111-2026-4000-8000-000000000001','marcha_nordica','marcha_nordica','5 km',        5, 10, 35),
  ('11111111-2026-4000-8000-000000000001','marcha_nordica','marcha_nordica','10 km',       10,14, 36),
  ('11111111-2026-4000-8000-000000000001','marcha_nordica','marcha_nordica','Más de 20 km',20,20, 37),
  ('11111111-2026-4000-8000-000000000001','marcha_nordica','marcha_nordica','Más de 40 km',40,28, 38)
on conflict (edicion_id, disciplina, modalidad) do nothing;

-- 3) Que la clasificación la agrupe dentro de 'trail'
create or replace function public.liga_disciplina_principal(p_disciplina text)
returns text language sql immutable as $function$
  select case p_disciplina
           when 'atletismo'      then 'atletismo'
           when 'running'        then 'running'
           when 'trail'          then 'trail'
           when 'marcha_nordica' then 'trail'
           when 'natacion'       then 'natacion'
           when 'triatlon'       then 'triatlon'
           when 'duatlon'        then 'triatlon'
           when 'aquabike'       then 'triatlon'
           when 'acuatlon'       then 'triatlon'
           else 'otra'
         end;
$function$;
