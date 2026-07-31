-- El atleta puede registrar/editar SUS propias marcas.
drop policy if exists "atleta anade sus marcas" on public.marcas_atleta;
create policy "atleta anade sus marcas" on public.marcas_atleta
for insert to authenticated
with check (atleta_id in (select mis_atletas()));

drop policy if exists "atleta edita sus marcas" on public.marcas_atleta;
create policy "atleta edita sus marcas" on public.marcas_atleta
for update to authenticated
using (atleta_id in (select mis_atletas()))
with check (atleta_id in (select mis_atletas()));
