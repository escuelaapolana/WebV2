-- ============================================================
-- 009 · OBSERVACIONES PRIVADAS del entrenador sobre un atleta
-- ------------------------------------------------------------
-- Notas internas del equipo técnico sobre un atleta.
-- SOLO las ve el staff: un admin o el ENTRENADOR de ESE atleta.
-- El atleta y su familia NO pueden leerlas: no hay ninguna
-- policy que les dé acceso, y con RLS activado "sin policy = sin
-- acceso". Estas notas viven en su propia tabla (separadas de
-- atletas.observaciones, que podría ser visible) precisamente
-- para poder blindar el acceso solo al staff.
-- ============================================================

create table if not exists public.notas_atleta (
  id uuid primary key default gen_random_uuid(),
  atleta_id uuid not null references public.atletas(id) on delete cascade,
  autor_id uuid,
  texto text not null,
  created_at timestamptz default now()
);

create index if not exists notas_atleta_atleta_id_idx on public.notas_atleta(atleta_id);

alter table public.notas_atleta enable row level security;

-- SOLO staff: admin o el entrenador de ESE atleta.
-- NADA para el atleta/familia (sin policy que les cubra => sin acceso).

drop policy if exists "staff lee notas privadas" on public.notas_atleta;
create policy "staff lee notas privadas" on public.notas_atleta
for select to authenticated
using (
  public.es_admin()
  or atleta_id in (select id from public.atletas where entrenador_id = public.mi_perfil_id())
);

drop policy if exists "staff escribe notas privadas" on public.notas_atleta;
create policy "staff escribe notas privadas" on public.notas_atleta
for insert to authenticated
with check (
  public.es_admin()
  or atleta_id in (select id from public.atletas where entrenador_id = public.mi_perfil_id())
);

drop policy if exists "staff borra notas privadas" on public.notas_atleta;
create policy "staff borra notas privadas" on public.notas_atleta
for delete to authenticated
using (
  public.es_admin()
  or atleta_id in (select id from public.atletas where entrenador_id = public.mi_perfil_id())
);
