-- 389 · Correos a un grupo desde el panel (salen de info@ por Brevo)
-- ---------------------------------------------------------------------------
-- Andrés (15-oct): «una pantalla en el panel para mandar correos a un grupo,
-- desde info@ y con el diseño del club». La Edge `correo-grupo` envía y deja
-- aquí constancia de cada envío (quién, a qué grupos, cuántos). Solo admin.
-- ---------------------------------------------------------------------------
begin;

create table if not exists public.correos_grupo (
  id              uuid primary key default gen_random_uuid(),
  enviado_por     uuid references public.perfiles(id) on delete set null,
  enviado_email   text,
  grupo_ids       uuid[] not null default '{}',
  asunto          text not null,
  titular         text,
  n_enviados      integer not null default 0,
  n_fallidos      integer not null default 0,
  destinatarios   text[] not null default '{}',
  created_at      timestamptz not null default now()
);
comment on table public.correos_grupo is 'Registro de los correos enviados a grupos desde admin/correo-grupo (Edge correo-grupo, Brevo, remitente info@).';

alter table public.correos_grupo enable row level security;
drop policy if exists "admin lee correos de grupo" on public.correos_grupo;
create policy "admin lee correos de grupo" on public.correos_grupo
  for select to authenticated using ((select public.es_admin()));

create index if not exists idx_correos_grupo_fecha on public.correos_grupo (created_at desc);

commit;
