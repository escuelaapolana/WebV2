-- 528 · Academia · Ciclos de planificación (macro / meso / micro) por atleta
-- ---------------------------------------------------------------------------
-- Andrés (13-nov-2026): «quiero tener todo lo de Academia subido en la app y así
-- tienes toda la info para planificar». El traspaso de ChatGPT trae el libro anual
-- original (fases de cada atleta, 31-ago-2026 a 1-ago-2027) y una propuesta de
-- mesociclo de 4 semanas (9-nov a 6-dic). Hasta ahora la app no tenía dónde
-- guardarlo.
--
-- Cada fila es un periodo de un atleta. `estado` dice qué valor tiene:
--   historico  = antecedente (el libro anual original): NO vigente.
--   propuesta  = propuesto, pendiente de que Andrés lo confirme.
--   aprobado   = confirmado por Andrés.
--   descartado = se queda como rastro, no se usa.
-- Nada entra como «aprobado» sin decisión explícita del entrenador.
--
-- Lectura: el entrenador del grupo del atleta (como la radiografía). Sin
-- escritura desde la app de momento: se rellena desde la base.
-- ---------------------------------------------------------------------------
create table if not exists public.academia_ciclos (
  id            uuid primary key default gen_random_uuid(),
  atleta_id     uuid not null references public.atletas(id) on delete cascade,
  temporada_id  uuid references public.temporadas_planificacion(id),
  nivel         text not null check (nivel in ('macro','meso','micro')),
  macro         text,                       -- a qué gran bloque pertenece (p. ej. «Short track 2026-27»)
  nombre        text not null,              -- fase o intención («Específica short track I», «Descarga»)
  inicio        date not null,
  fin           date not null,
  semanas       text,                       -- etiqueta original de semanas del libro («12–15»)
  objetivo      text,
  contenidos    jsonb not null default '{}'::jsonb,  -- pista, complementario, fuerza, tests, competiciones, criterio
  carga_1_5     smallint check (carga_1_5 between 1 and 5),  -- solo si Andrés la pone
  estado        text not null check (estado in ('historico','propuesta','aprobado','descartado')),
  fuente        text not null,
  nota          text,
  orden         integer not null default 0,
  creado_por    uuid,
  creado_en     timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  check (fin >= inicio),
  check (jsonb_typeof(contenidos) = 'object')
);

create index if not exists academia_ciclos_atleta on public.academia_ciclos (atleta_id, inicio);

alter table public.academia_ciclos enable row level security;

drop policy if exists "ciclos: su entrenador" on public.academia_ciclos;
create policy "ciclos: su entrenador" on public.academia_ciclos
  for select to authenticated
  using (exists (
    select 1 from public.atletas a join public.grupos g on g.id = a.grupo_id
     where a.id = atleta_id and g.entrenador_id = (select public.mi_perfil_id())
  ));

revoke all on public.academia_ciclos from anon, authenticated;
grant select on public.academia_ciclos to authenticated;
