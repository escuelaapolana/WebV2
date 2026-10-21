-- 417 · «Grupos y listas» (admin/escuela-grupos) daba «permission denied for table grupos»:
-- grupos tiene los permisos de SELECT columna a columna, y la columna nueva
-- entrenador_previsto (mig 407) se quedó sin él. Lectura para usuarios con sesión (RLS manda igual).
begin;
grant select (entrenador_previsto) on public.grupos to authenticated;
commit;
