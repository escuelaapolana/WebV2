-- 215 · Cualquier usuario CON SESIÓN puede leer los horarios de entrenamiento
--        activos (no solo los de su propio grupo).
--
-- El calendario semanal del portal (portal/cubo-atleta → pestaña Calendario)
-- deja "asomarse" a otras secciones: con un chip sumas los entrenamientos de
-- Running, Competición o Escuela. Para eso hay que LEER los horarios activos de
-- cualquier grupo, no solo del tuyo.
--
-- Hasta ahora grupo_horarios solo lo leía el staff, la escuela (su sección) y
-- cada atleta SU grupo ("horarios lee su grupo"). Con eso, al pedir los de otra
-- sección la RLS los filtraba y volvían vacíos (los chips no añadían nada).
--
-- Son datos publicados (día, hora, lugar) y NO sensibles. Se abre la lectura a
-- `authenticated` (el rol del portal). NO a anon: las funciones de las políticas
-- vecinas (escuela_secciones → escuela_lleva_atleta → …) son SECURITY INVOKER y
-- anon no tiene EXECUTE sobre toda la cadena; darle la cadena entera ampliaría
-- su superficie sin que ninguna página pública lo necesite. Las políticas de
-- gestión (admin/escuela/staff) no se tocan.

drop policy if exists "horarios activos son públicos" on grupo_horarios;
create policy "horarios activos son públicos" on grupo_horarios
  for select to authenticated
  using (activo = true);
