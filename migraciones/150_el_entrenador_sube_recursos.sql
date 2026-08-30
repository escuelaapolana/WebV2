-- ============================================================
-- 150 · EL ENTRENADOR SUBE LOS RECURSOS DE SU GRUPO
-- ------------------------------------------------------------
-- QUÉ RESUELVE
-- Los recursos de grupo (migración 143) solo los podía subir administración,
-- desde el panel. Pero Andrés lo vio claro desde el portal de entrenador:
-- «como entrenador, ¿cómo lo subo?». Y sobre todo, pensando en Cristian, que
-- va a ser SOLO entrenador y no tendrá panel: el entrenador tiene que poder
-- colgarle material a SU grupo desde su propio portal.
--
-- QUÉ ABRE, Y HASTA DÓNDE
--   1. La FILA del recurso (tabla `documentos`): un entrenador puede crear,
--      cambiar y borrar recursos, pero SOLO los de visibilidad «grupo» y SOLO
--      de un grupo que entrena él. Ni tocar la normativa del club, ni recursos
--      de grupos ajenos.
--   2. El ARCHIVO (almacén `documentos-socios`): un entrenador puede subir, y
--      borrar lo que él mismo subió. No puede borrar lo de otros.
--
-- POR QUÉ EL ARCHIVO NO SE ATA AL GRUPO EN EL ALMACÉN
-- El almacén no sabe de grupos: guarda archivos. Quién ve un archivo lo
-- decide la FILA de `documentos` que lo apunta, y esa sí está atada al grupo.
-- Un archivo subido y no apuntado por ninguna fila no lo ve nadie: es basura
-- inofensiva, no una fuga. Por eso basta con dejar subir a quien entrena algún
-- grupo, y afinar el «para quién» en la fila.
-- ============================================================

-- ------------------------------------------------------------
-- 1 · ¿ENTRENO ESTE GRUPO? / ¿ENTRENO ALGUNO?
-- ------------------------------------------------------------
create or replace function soy_entrenador_de_grupo(p_grupo uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select public.es_admin() or exists (
    select 1 from public.grupos g
     where g.id = p_grupo and g.entrenador_id = public.mi_perfil_id()
  );
$$;
grant execute on function soy_entrenador_de_grupo(uuid) to authenticated;

-- Para el almacén, que no sabe de qué grupo es cada archivo: basta con ser
-- entrenador de ALGÚN grupo para poder subir.
create or replace function soy_entrenador_de_algun_grupo()
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select public.es_admin() or exists (
    select 1 from public.grupos g
     where g.entrenador_id = public.mi_perfil_id() and coalesce(g.activo, true)
  );
$$;
grant execute on function soy_entrenador_de_algun_grupo() to authenticated;

-- ------------------------------------------------------------
-- 2 · LA FILA DEL RECURSO · el entrenador gestiona los de SU grupo
-- (La política de admin sigue; ésta se suma para el entrenador.)
-- ------------------------------------------------------------
drop policy if exists "entrenador gestiona recursos de su grupo" on documentos;
create policy "entrenador gestiona recursos de su grupo"
  on documentos for all
  using (visibilidad = 'grupo' and soy_entrenador_de_grupo(grupo_id))
  with check (visibilidad = 'grupo' and soy_entrenador_de_grupo(grupo_id));

-- ------------------------------------------------------------
-- 3 · EL ARCHIVO · subir al almacén cerrado, y borrar lo propio
-- ------------------------------------------------------------
drop policy if exists "entrenador sube recursos de grupo" on storage.objects;
create policy "entrenador sube recursos de grupo"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos-socios' and soy_entrenador_de_algun_grupo());

drop policy if exists "entrenador borra sus subidas" on storage.objects;
create policy "entrenador borra sus subidas"
  on storage.objects for delete to authenticated
  using (bucket_id = 'documentos-socios' and owner = auth.uid() and soy_entrenador_de_algun_grupo());
