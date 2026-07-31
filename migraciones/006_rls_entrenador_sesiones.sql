-- ============================================================
-- 006 · RLS para la ZONA DEL ENTRENADOR (escritura)
-- ------------------------------------------------------------
-- 1) El entrenador gestiona (crea/edita/borra) y VE todas las
--    sesiones de SUS grupos, incluidas las NO publicadas.
-- 2) La biblioteca de ejercicios es de solo lectura para
--    cualquier usuario autenticado (necesaria para poblar el
--    desplegable de ejercicios del editor de bloques).
--    Hasta ahora ejercicios tenía RLS activo y solo la policy de
--    admin, por lo que un entrenador veía 0 ejercicios.
-- ============================================================

-- 1) Sesiones: gestión completa de las sesiones de mis grupos
drop policy if exists "entrenador gestiona sesiones de su grupo" on public.sesiones;
create policy "entrenador gestiona sesiones de su grupo" on public.sesiones
for all to authenticated
using (
  grupo_id in (select id from public.grupos where entrenador_id = public.mi_perfil_id())
)
with check (
  grupo_id in (select id from public.grupos where entrenador_id = public.mi_perfil_id())
);

-- 2) Ejercicios: biblioteca de solo lectura para autenticados
drop policy if exists "lectura autenticada de ejercicios" on public.ejercicios;
create policy "lectura autenticada de ejercicios" on public.ejercicios
for select to authenticated
using (true);
