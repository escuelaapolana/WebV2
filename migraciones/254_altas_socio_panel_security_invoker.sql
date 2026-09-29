-- 254 · Cerrar fuga de datos personales en la vista de altas de socio
-- --------------------------------------------------------------------
-- La vista `altas_socio_panel` (mig 171) quedó SIN `security_invoker`, así que
-- corría con permisos del dueño y se saltaba la RLS de `altas_socio`: cualquier
-- cuenta autenticada del portal (familia, atleta, socio, cubo…) podía leer
-- nombre, apellidos, fecha de nacimiento, sexo, dirección, email, teléfono,
-- nacionalidad, peso, estatura y tallas de TODOS los solicitantes de socio.
--
-- Con el candado puesto, la vista respeta la RLS de la tabla base: solo
-- `es_admin()` y `es_tesoreria()` ven las filas (los paneles de admin siguen
-- funcionando); una cuenta normal recibe 0 filas.
--
-- NO revocar el SELECT a `authenticated`: en Supabase los admins también son el
-- rol `authenticated`; quien distingue admin de no-admin es la RLS, no el grant.
--
-- Verificado (29-sep-2026) con ensayo en rollback sobre producción:
--   padre normal ANTES = 3 filas  →  DESPUÉS = 0 filas ;  admin DESPUÉS = 3 filas.

alter view public.altas_socio_panel set (security_invoker = on);
