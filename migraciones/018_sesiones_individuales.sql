-- Una sesión puede ir dirigida a TODO el grupo (atletas_ids null)
-- o solo a ciertos atletas (lista de ids). En ese caso, únicamente ellos la ven.
alter table public.sesiones add column if not exists atletas_ids uuid[];

-- El atleta ve: las sesiones publicadas de su grupo dirigidas a todos,
-- o las dirigidas expresamente a él (aunque cambie de grupo).
drop policy if exists "ver sesiones de mi grupo" on public.sesiones;
create policy "ver sesiones de mi grupo" on public.sesiones
for select to authenticated
using (
  publicada = true
  and (
    (atletas_ids is null and grupo_id in (select grupo_id from public.atletas where id in (select mis_atletas())))
    or (atletas_ids is not null and exists (select 1 from unnest(atletas_ids) x where x in (select mis_atletas())))
  )
);
