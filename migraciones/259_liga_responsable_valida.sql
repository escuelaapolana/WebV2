-- 259 · El responsable de la Liga puede validar participaciones
-- --------------------------------------------------------------
-- Bug (29-sep): José Luis Picazo (responsable de comunicación = es_responsable_liga)
-- no podía VALIDAR pruebas de la Liga: «new row violates row-level security policy
-- for table liga_participaciones». Causa: las políticas de `liga_participaciones`
-- solo permitían escribir a `es_staff()` (o al dueño mientras la fila está
-- 'pendiente'). Al validar, la fila deja de estar 'pendiente' y el responsable
-- NO es es_staff() → RLS lo bloquea.
--
-- Arreglo: añadir `es_responsable_liga()` (admin/coordinador o responsable de
-- comunicación) a las 4 políticas, para que gestione las participaciones como el
-- staff. La función ya tiene execute a authenticated y es SECURITY DEFINER.
-- Se conserva TODO lo demás (la rama del dueño con estado 'pendiente', mis_atletas).

begin;

-- LECTURA
drop policy if exists "liga participaciones lectura" on public.liga_participaciones;
create policy "liga participaciones lectura" on public.liga_participaciones
  for select to authenticated
  using (
    public.es_staff()
    or public.es_responsable_liga()
    or (atleta_id in ( select public.mis_atletas() ))
  );

-- ALTA (INSERT)
drop policy if exists "liga participaciones alta del equipo" on public.liga_participaciones;
create policy "liga participaciones alta del equipo" on public.liga_participaciones
  for insert to authenticated
  with check (
    public.es_staff()
    or public.es_responsable_liga()
    or ( (estado = 'pendiente')
         and (atleta_id in ( select atletas.id from public.atletas
                             where atletas.perfil_id = public.mi_perfil_id()
                                or atletas.perfil_padre_id = public.mi_perfil_id() )) )
  );

-- CAMBIA (UPDATE)
drop policy if exists "liga participaciones cambia el equipo" on public.liga_participaciones;
create policy "liga participaciones cambia el equipo" on public.liga_participaciones
  for update to authenticated
  using (
    public.es_staff()
    or public.es_responsable_liga()
    or ( (estado = 'pendiente')
         and (atleta_id in ( select atletas.id from public.atletas
                             where atletas.perfil_id = public.mi_perfil_id()
                                or atletas.perfil_padre_id = public.mi_perfil_id() )) )
  )
  with check (
    public.es_staff()
    or public.es_responsable_liga()
    or ( (estado = 'pendiente')
         and (atleta_id in ( select atletas.id from public.atletas
                             where atletas.perfil_id = public.mi_perfil_id()
                                or atletas.perfil_padre_id = public.mi_perfil_id() )) )
  );

-- BORRA (DELETE)
drop policy if exists "liga participaciones borra el equipo" on public.liga_participaciones;
create policy "liga participaciones borra el equipo" on public.liga_participaciones
  for delete to authenticated
  using (
    public.es_staff()
    or public.es_responsable_liga()
    or ( (estado = 'pendiente')
         and (atleta_id in ( select atletas.id from public.atletas
                             where atletas.perfil_id = public.mi_perfil_id()
                                or atletas.perfil_padre_id = public.mi_perfil_id() )) )
  );

commit;
