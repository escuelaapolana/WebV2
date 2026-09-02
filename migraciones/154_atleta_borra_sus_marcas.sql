-- 154 · El atleta (y su familia) puede BORRAR sus propias marcas
--
-- Ya podía añadir y editar sus marcas, pero no borrarlas: si se equivocaba
-- al subir una, se quedaba ahí para siempre (solo la borraba un admin). Se
-- añade el permiso de borrado con la misma condición que el de editar
-- (mis_atletas()), y también para el entrenador, que ya podía corregirlas.

drop policy if exists "atleta borra sus marcas" on public.marcas_atleta;
create policy "atleta borra sus marcas" on public.marcas_atleta
  for delete to authenticated
  using (atleta_id in (select mis_atletas()));
