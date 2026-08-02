-- ============================================================
-- 064 · Borrar datos deportivos: cosa de administración
-- ------------------------------------------------------------
-- Muchas tablas decían «esto lo toca el equipo técnico»
-- (es_staff) en vez de «el equipo técnico DE ESE ATLETA»
-- (soy_staff_de_atleta). Con ese criterio, los once entrenadores
-- del club tienen las mismas llaves, y en una auditoría se
-- comprobó que cualquiera de ellos podía borrar de una sentada:
--
--   1.988 resultados de tests · 290 medallas · 162 logros
--   24 baterías · 48 filas de baremo · la edición entera de la
--   Liga · y encender el ranking público del club
--
-- No hay papelera ni registro de quién lo hizo. Un entrenador
-- que se marche mal del club se lleva por delante el histórico
-- de la escuela en dos minutos.
--
-- A partir de aquí: el equipo técnico sigue viendo y anotando
-- (que es su trabajo), pero BORRAR es de administración. Y el
-- interruptor del ranking público también.
--
-- Nota: leer y escribir no se tocan aquí a propósito. Compartir
-- los tests entre entrenadores puede ser lo práctico, y esa es
-- una decisión del club, no de seguridad.
-- Idempotente.
-- ============================================================

-- Resultados de tests
drop policy if exists "tests resultado borra el equipo" on public.test_resultados;
drop policy if exists "tests resultado borra admin"     on public.test_resultados;
create policy "tests resultado borra admin" on public.test_resultados
  for delete to authenticated using (public.es_admin());

-- Baterías de tests
drop policy if exists "tests bateria borra el equipo" on public.test_baterias;
drop policy if exists "tests bateria borra admin"     on public.test_baterias;
create policy "tests bateria borra admin" on public.test_baterias
  for delete to authenticated using (public.es_admin());

-- Medallas concedidas
drop policy if exists "medallas ganadas las borra el equipo" on public.atleta_medallas;
drop policy if exists "medallas ganadas las borra admin"     on public.atleta_medallas;
create policy "medallas ganadas las borra admin" on public.atleta_medallas
  for delete to authenticated using (public.es_admin());

-- Logros de retos
drop policy if exists "logros los borra el equipo" on public.reto_logros;
drop policy if exists "logros los borra admin"     on public.reto_logros;
create policy "logros los borra admin" on public.reto_logros
  for delete to authenticated using (public.es_admin());

-- La edición de la Liga: crearla y borrarla es de administración
drop policy if exists "liga ediciones gestiona el equipo" on public.liga_ediciones;
drop policy if exists "liga ediciones gestiona admin"     on public.liga_ediciones;
create policy "liga ediciones gestiona admin" on public.liga_ediciones
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

-- El interruptor del ranking público del juego
drop policy if exists "ajustes juego los cambia el equipo" on public.juego_ajustes;
drop policy if exists "ajustes juego los cambia admin"     on public.juego_ajustes;
create policy "ajustes juego los cambia admin" on public.juego_ajustes
  for update to authenticated using (public.es_admin()) with check (public.es_admin());
