-- Permisos de lectura del entreno para el atleta (y familia/entrenador por mis_atletas())
-- Reutiliza mis_atletas(): el atleta ve las sesiones publicadas de su grupo.

drop policy if exists "ver sesiones de mi grupo" on public.sesiones;
create policy "ver sesiones de mi grupo" on public.sesiones
for select to authenticated
using (
  publicada = true
  and grupo_id in (select grupo_id from public.atletas where id in (select mis_atletas()))
);

drop policy if exists "ver entrenamientos de mi grupo" on public.entrenamientos;
create policy "ver entrenamientos de mi grupo" on public.entrenamientos
for select to authenticated
using (
  grupo_id in (select grupo_id from public.atletas where id in (select mis_atletas()))
);
