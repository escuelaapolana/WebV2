-- 182 · El atleta apunta sus propias marcas de tests
-- ------------------------------------------------------------
-- Hasta ahora las marcas las metía solo el equipo técnico. El club
-- quiere que cada atleta suba las suyas. Se abren dos cosas, con cuidado:
--   1) veo_bateria(): el atleta ve las baterías de SU grupo (antes solo
--      las veía si ya tenía una marca dentro → pez que se muerde la cola).
--   2) test_resultados INSERT/UPDATE: el atleta puede escribir su PROPIA
--      marca (atleta_id ∈ mis_atletas) y solo en una batería que ve.
-- La batería la sigue creando el técnico (define el día de test); el
-- atleta solo rellena su ficha. Borrar sigue siendo solo admin.
-- ============================================================
begin;

create or replace function public.veo_bateria(p_bateria uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.es_staff()
    or exists (
      select 1 from public.test_resultados r
      where r.bateria_id = p_bateria
        and r.atleta_id in (select public.mis_atletas())
    )
    or exists (
      select 1 from public.test_baterias b
      join public.atletas a on a.grupo_id = b.grupo_id
      where b.id = p_bateria
        and a.id in (select public.mis_atletas())
    );
$function$;

drop policy if exists "tests resultado alta del equipo" on public.test_resultados;
create policy "tests resultado alta" on public.test_resultados
  for insert to authenticated
  with check (
    public.es_staff()
    or (atleta_id in (select public.mis_atletas()) and public.veo_bateria(bateria_id))
  );

drop policy if exists "tests resultado cambia el equipo" on public.test_resultados;
create policy "tests resultado cambia" on public.test_resultados
  for update to authenticated
  using (
    public.es_staff()
    or atleta_id in (select public.mis_atletas())
  )
  with check (
    public.es_staff()
    or (atleta_id in (select public.mis_atletas()) and public.veo_bateria(bateria_id))
  );

commit;
