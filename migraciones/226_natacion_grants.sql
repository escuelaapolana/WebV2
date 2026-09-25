-- 226 · Permisos de tabla (GRANT) para las tablas de natación
--
-- Al crearlas por psql como superusuario, el rol `authenticated` no recibió
-- acceso a las tablas, así que a staff/responsable le salía "permission denied"
-- ANTES de aplicar la RLS (la asistencia de natación aparecía vacía). La RLS
-- ya acota las FILAS (solo admin/staff/responsable); esto concede el acceso a
-- la tabla. `anon` NO recibe nada: siguen siendo privadas (lo público va por la
-- vista natacion_vacantes y por las funciones security definer).

grant select, insert, update, delete on public.natacion_franjas       to authenticated;
grant select, insert, update, delete on public.natacion_inscripciones to authenticated;
grant select, insert, update, delete on public.natacion_ausencias     to authenticated;
grant select, insert, update, delete on public.natacion_accesos       to authenticated;
