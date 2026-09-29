-- SLUG · Acotar los tests al staff que de verdad lleva a ese atleta
--        (antes: es_staff() global). Fotos: se dejan como están, con nota.
-- ------------------------------------------------------------
-- Hallazgo de seguridad F6 (baja, exceso de privilegio interno):
-- las policies de `test_resultados` daban acceso a CUALQUIER miembro del
-- equipo (es_staff(): admin, coordinador, entrenador, tesoreria,
-- contabilidad, junta) a las marcas de TODOS los atletas, sin acotar a la
-- sección/grupo. Es decir, un entrenador podía ver (y editar) los tests
-- de atletas de OTRO entrenador.
--
-- Se sustituye ese `es_staff()` global por `conf_soy_su_staff(atleta_id)`,
-- que ya existe y está en uso en producción (policy de
-- confirmaciones_respuestas):
--   conf_soy_su_staff(a) = es_admin() OR (es_staff() AND conf_ve_atleta(a))
--   conf_ve_atleta(a)    = admin, o el propio atleta / su padre /
--                          su entrenador / el entrenador de su grupo /
--                          el coordinador de la sección del grupo.
-- Se mantiene además `es_tesoreria()` para respetar el acceso total de
-- admin/tesorería pedido en la revisión (si se decide que tesorería NO
-- debe ver marcas deportivas, basta quitar `or public.es_tesoreria()`).
--
-- El atleta y su familia siguen entrando por `atleta_id in mis_atletas()`
-- (no se toca), así que «los tests los sube el atleta» sigue funcionando.
-- Borrar sigue siendo SOLO admin (esa policy no usa es_staff → no se toca).
--
-- FOTOS (bucket `fotos-atletas`): NO se tocan aquí a propósito. El bucket
-- está vacío y ningún código de la app sube/lee ahí, así que no hay
-- convención ruta→atleta con la que acotar por sección sin inventarla y
-- arriesgar la (futura) subida. Cuando se construya la función de fotos,
-- fijar la ruta = <perfil_id o atleta_id>/… y acotar con conf_ve_atleta
-- sobre storage.foldername(name). Pendiente de revisar con Andrés.
-- ============================================================
begin;

-- Lectura: el staff solo ve los tests de SUS atletas (+ admin/tesorería);
-- el propio atleta y su familia siguen entrando por mis_atletas().
drop policy if exists "tests resultado lectura" on public.test_resultados;
create policy "tests resultado lectura" on public.test_resultados
  for select to authenticated
  using (
    public.conf_soy_su_staff(atleta_id)
    or public.es_tesoreria()
    or atleta_id in (select public.mis_atletas())
  );

-- Alta: mismo criterio; el atleta/familia necesita además ver la batería.
drop policy if exists "tests resultado alta" on public.test_resultados;
create policy "tests resultado alta" on public.test_resultados
  for insert to authenticated
  with check (
    public.conf_soy_su_staff(atleta_id)
    or public.es_tesoreria()
    or (atleta_id in (select public.mis_atletas()) and public.veo_bateria(bateria_id))
  );

-- Cambio: mismo criterio en using y with_check.
drop policy if exists "tests resultado cambia" on public.test_resultados;
create policy "tests resultado cambia" on public.test_resultados
  for update to authenticated
  using (
    public.conf_soy_su_staff(atleta_id)
    or public.es_tesoreria()
    or atleta_id in (select public.mis_atletas())
  )
  with check (
    public.conf_soy_su_staff(atleta_id)
    or public.es_tesoreria()
    or (atleta_id in (select public.mis_atletas()) and public.veo_bateria(bateria_id))
  );

commit;
