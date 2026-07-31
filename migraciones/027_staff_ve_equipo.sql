-- El equipo técnico puede ver los nombres del equipo técnico (para mostrar quién lleva cada grupo).
-- No expone datos de atletas ni de familias: solo perfiles de admin/coordinador/entrenador.
drop policy if exists "staff lee al equipo tecnico" on public.perfiles;
create policy "staff lee al equipo tecnico" on public.perfiles
for select to authenticated
using (public.es_staff() and rol in ('admin','coordinador','entrenador'));
