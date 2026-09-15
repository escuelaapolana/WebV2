-- 185 · Cada atleta (y familia) ve los horarios de SU grupo
-- ------------------------------------------------------------
-- `grupo_horarios` solo dejaba leer al staff (`es_staff()`), así que un
-- atleta —y en concreto un cubo-atleta— NO veía sus propios días y horas:
-- el portal del Cubo mostraba «Aún no tienes horarios asignados» aunque el
-- grupo sí los tuviera. Se añade una política de SOLO LECTURA para quien
-- pertenece al grupo (por su ficha o por la de un hijo). Es aditiva: no
-- toca las políticas de gestión (escuela/admin) ni la de staff.
-- ============================================================
begin;

drop policy if exists "horarios lee su grupo" on public.grupo_horarios;
create policy "horarios lee su grupo" on public.grupo_horarios
  for select using (
    exists (
      select 1 from public.atletas a
      where a.grupo_id = grupo_horarios.grupo_id
        and (a.perfil_id = public.mi_perfil_id()
             or a.perfil_padre_id = public.mi_perfil_id())
    )
  );

commit;
