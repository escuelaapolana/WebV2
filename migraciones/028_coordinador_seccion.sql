-- El coordinador ve las fichas de los atletas de SU sección (perfiles.seccion),
-- a través del grupo al que pertenecen. No ve otras secciones ni datos de pagos.
drop policy if exists "coordinacion ve atletas de su seccion" on public.atletas;
create policy "coordinacion ve atletas de su seccion" on public.atletas
for select to authenticated
using (exists (
  select 1 from public.perfiles p
  where p.email = (auth.jwt() ->> 'email')
    and p.rol = 'coordinador' and p.seccion is not null
    and exists (select 1 from public.grupos g
                where g.id = atletas.grupo_id and g.seccion = p.seccion)
));
