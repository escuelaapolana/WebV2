-- 396 · Las competiciones las puede editar también quien lleva Comunicación
-- ---------------------------------------------------------------------------
-- Mario (19-oct): «intento modificar o ampliar la información de alguna
-- competición en el calendario, y no puedo». Las competiciones del calendario
-- viven en la tabla `competiciones`, que solo editaba administración. Quien
-- lleva Comunicación (responsable 'comunicacion': Mario, José Luis…), además
-- de admin/coordinación, ya gestiona la Liga y el calendario de eventos: que
-- pueda también crear y corregir competiciones. es_responsable_liga() =
-- admin/coordinador o responsable de comunicación (mig 252).
begin;
drop policy if exists "comunicacion gestiona competiciones" on public.competiciones;
create policy "comunicacion gestiona competiciones" on public.competiciones
  for all to authenticated
  using ((select public.es_responsable_liga()))
  with check ((select public.es_responsable_liga()));
commit;
