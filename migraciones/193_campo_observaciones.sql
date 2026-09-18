-- 193 · Observaciones de la sesión (pasar lista «En la pista»)
-- --------------------------------------------------------------------
-- Además de la asistencia y las notas por atleta (notas_atleta), hace falta
-- una observación GENERAL del grupo en un día: incidencias, cambios, «hoy
-- faltó material», etc. Una fila por (grupo, fecha). La escriben quienes pasan
-- lista de ese grupo (admin, staff o el entrenador del grupo).

create table if not exists public.campo_observaciones (
  grupo_id     uuid not null references public.grupos(id) on delete cascade,
  fecha        date not null,
  texto        text not null default '',
  autor_id     uuid references public.perfiles(id),
  actualizado  timestamptz not null default now(),
  primary key (grupo_id, fecha)
);
alter table public.campo_observaciones enable row level security;

create or replace function public.puedo_obs_grupo(p_grupo uuid)
  returns boolean language sql stable security definer set search_path to 'public' as $$
  select public.es_admin() or public.es_staff() or exists(
    select 1 from public.grupos g
     where g.id = p_grupo and g.entrenador_id = public.mi_perfil_id());
$$;
grant execute on function public.puedo_obs_grupo(uuid) to anon, authenticated;

drop policy if exists "obs campo lee" on public.campo_observaciones;
create policy "obs campo lee" on public.campo_observaciones
  for select to authenticated using ( public.puedo_obs_grupo(grupo_id) );

drop policy if exists "obs campo escribe" on public.campo_observaciones;
create policy "obs campo escribe" on public.campo_observaciones
  for all to authenticated
  using ( public.puedo_obs_grupo(grupo_id) )
  with check ( public.puedo_obs_grupo(grupo_id) );

grant select, insert, update, delete on public.campo_observaciones to authenticated;
