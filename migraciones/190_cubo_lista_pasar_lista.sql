-- 190 · El Cubo: Claudia (rol cubo-lista) pasa lista
-- --------------------------------------------------------------------
-- El rol `cubo-lista` (Claudia) solo pasa lista en El Cubo. Se le da
-- permiso POR ROL (no por entrenador_id de los grupos, que la marcaría
-- como «entrenadora» en el enrutado de la app):
--   · leer las altas del Cubo (para el roster de cada grupo),
--   · escribir/corregir la asistencia SOLO de grupos de sección 'cubo'.
-- La asistencia usa la misma tabla `asistencia` que el resto del club.

create or replace function public.es_cubo_lista()
  returns boolean
  language sql stable security definer set search_path to 'public'
as $$
  select coalesce((
    select coalesce(p.rol_activo, p.rol) = 'cubo-lista'
      from public.perfiles p
     where p.id = public.mi_perfil_id()
  ), false);
$$;

-- Imprescindible: sin EXECUTE para los roles del front, la política de abajo
-- que la usa hace fallar TODA lectura de cubo_altas (ver mig 191). Se concede
-- igual que es_admin().
grant execute on function public.es_cubo_lista() to anon, authenticated;

-- Ve las altas del Cubo (para saber quién entrena en cada grupo)
drop policy if exists "cubo-lista ve altas del cubo" on public.cubo_altas;
create policy "cubo-lista ve altas del cubo" on public.cubo_altas
  for select to authenticated
  using ( public.es_cubo_lista() );

-- Pasa (y corrige) lista de asistencia, solo de los grupos del Cubo
drop policy if exists "cubo-lista pasa lista del cubo" on public.asistencia;
create policy "cubo-lista pasa lista del cubo" on public.asistencia
  for all to authenticated
  using ( public.es_cubo_lista()
          and grupo_id in (select id from public.grupos where seccion = 'cubo') )
  with check ( public.es_cubo_lista()
          and grupo_id in (select id from public.grupos where seccion = 'cubo') );
