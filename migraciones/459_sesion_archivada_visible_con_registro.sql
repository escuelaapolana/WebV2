-- 459 · Una sesión ARCHIVADA (mig 458) sigue visible para quien tiene un registro en ella
-- ---------------------------------------------------------------------------
-- Archivar despublica la sesión (sale del plan del grupo). La regla de lectura de
-- los atletas («ver sesiones de mi grupo») exige publicada = true, así que el
-- atleta veía su registro pero no la sesión a la que responde. Esta regla
-- añade SOLO eso: la sesión archivada, para quien tiene un registro suyo en
-- ella (tengo_registro_en ya mira mis_atletas_entreno). El resto, igual.
-- ---------------------------------------------------------------------------
begin;
create policy "ver archivadas en las que tengo registro" on public.sesiones
  for select to authenticated
  using (archivada_en is not null and public.tengo_registro_en(id));
commit;
