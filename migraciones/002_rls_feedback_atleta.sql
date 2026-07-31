-- El atleta puede registrar y actualizar SUS sensaciones de la sesión (registros_sesion).
-- La lectura ya está cubierta por "ver datos de mis atletas".

drop policy if exists "atleta registra su sesion" on public.registros_sesion;
create policy "atleta registra su sesion" on public.registros_sesion
for insert to authenticated
with check (atleta_id in (select mis_atletas()));

drop policy if exists "atleta actualiza su registro" on public.registros_sesion;
create policy "atleta actualiza su registro" on public.registros_sesion
for update to authenticated
using (atleta_id in (select mis_atletas()))
with check (atleta_id in (select mis_atletas()));
