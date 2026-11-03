-- ============================================================
-- 511 · Natación · a quién le llega el correo de las solicitudes
-- ------------------------------------------------------------
-- 3-nov-2026. Además de Andrés (CORREO_RESPUESTAS de la Edge natacion-form-sync),
-- el correo de las solicitudes (agenda de pruebas + mensajes para las familias) le
-- llega a quien esté aquí. Las direcciones se meten por psql o desde el panel, NO
-- en este fichero (el repo es público). Solo el admin la ve; la Edge la lee con
-- service_role.
-- ============================================================

create table if not exists public.natacion_avisos_destinos (
  email      text primary key check (email = lower(btrim(email)) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  nombre     text,
  activo     boolean not null default true,
  creado_en  timestamptz not null default now()
);

alter table public.natacion_avisos_destinos enable row level security;
revoke all on public.natacion_avisos_destinos from anon;
grant select, insert, update, delete on public.natacion_avisos_destinos to authenticated;

drop policy if exists "destinos natación: solo admin" on public.natacion_avisos_destinos;
create policy "destinos natación: solo admin" on public.natacion_avisos_destinos
  for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
