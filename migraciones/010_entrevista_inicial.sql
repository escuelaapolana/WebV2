-- Entrevista inicial que rellena el propio atleta (onboarding).
create table if not exists public.entrevista_inicial (
  id uuid primary key default gen_random_uuid(),
  atleta_id uuid not null unique references public.atletas(id) on delete cascade,
  motivo text,               -- por qué hace atletismo / qué busca
  objetivos text,            -- objetivos de la temporada
  objetivo_largo text,       -- objetivo a largo plazo
  experiencia text,          -- años, clubes anteriores
  disponibilidad text,       -- días y horas que puede entrenar
  lesiones_previas text,
  otros_deportes text,
  notas text,
  completada boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
alter table public.entrevista_inicial enable row level security;
-- El atleta (y su familia) leen/escriben la suya; el staff la lee via mis_atletas(); admin todo.
drop policy if exists "ver entrevista de mis atletas" on public.entrevista_inicial;
create policy "ver entrevista de mis atletas" on public.entrevista_inicial for select to authenticated
  using (public.es_admin() or atleta_id in (select public.mis_atletas()));
drop policy if exists "escribir entrevista de mis atletas" on public.entrevista_inicial;
create policy "escribir entrevista de mis atletas" on public.entrevista_inicial for insert to authenticated
  with check (atleta_id in (select public.mis_atletas()));
drop policy if exists "actualizar entrevista de mis atletas" on public.entrevista_inicial;
create policy "actualizar entrevista de mis atletas" on public.entrevista_inicial for update to authenticated
  using (atleta_id in (select public.mis_atletas())) with check (atleta_id in (select public.mis_atletas()));
