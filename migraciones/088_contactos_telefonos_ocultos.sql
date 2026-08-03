-- ============================================================
-- 088 · Los teléfonos que el club NO ha querido publicar, de verdad ocultos
-- ------------------------------------------------------------
-- La tabla `contactos` (migración 085) guarda los datos de la junta y
-- de los entrenadores con un interruptor por dato: `publicar_telefono`
-- y `publicar_email`. La idea es que un teléfono con el interruptor
-- APAGADO no salga de la base. Para eso está la vista
-- `contactos_publicos`, que devuelve NULL cuando el interruptor está
-- apagado, y es lo único que lee la web.
--
-- El fallo: la tabla base tenía una política de lectura
-- `USING (true)` para authenticated, así que **cualquier persona con
-- cuenta** (un atleta, un padre) podía leer la tabla EN CRUDO —desde
-- la consola del navegador, `/rest/v1/contactos?select=*`— y ver los
-- teléfonos apagados, saltándose la vista y los interruptores.
--
-- Comprobado en vivo (y revertido): como atleta con cuenta normal,
-- `select nombre, telefono from contactos` devolvía los móviles
-- personales de dos personas que el club aún NO ha decidido publicar.
-- `anon` (sin cuenta) ya estaba bien: no tiene permiso sobre la tabla.
-- El agujero era solo para quien tiene cuenta.
--
-- Arreglo (el mismo patrón que la 078 con récords y palmarés):
-- la tabla base la lee SOLO administración, que es quien la edita en
-- su panel. Todos los demás —con cuenta o sin ella— usan la vista
-- `contactos_publicos`, que corre como postgres y respeta los
-- interruptores. Así el dato apagado NO sale de la base por ninguna
-- vía.
-- Idempotente.
-- ============================================================

-- Fuera la lectura en crudo para cualquiera con cuenta.
drop policy if exists "lectura contactos con sesion" on public.contactos;

-- Solo administración lee la tabla base (para editarla en el panel).
-- La política "admin gestiona contactos" (ALL, es_admin) ya cubre esto,
-- pero dejamos una de SELECT explícita y con nombre claro por si algún
-- día se retira la de ALL. Si ya existe, se recrea igual.
drop policy if exists "contactos base solo admin" on public.contactos;
create policy "contactos base solo admin" on public.contactos
  for select to authenticated using (public.es_admin());

-- La web pública y la del socio NO tocan la tabla base: leen la vista.
-- Por si acaso, se retira cualquier SELECT suelto de anon sobre la
-- tabla base (la vista no lo necesita, corre como postgres).
revoke select on public.contactos from anon;
