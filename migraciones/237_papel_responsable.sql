-- 237 · Papel "responsable" + hub de secciones
--
-- Un responsable (Mario en natación, Adriana en escuela…) entra a una vista
-- propia de TARJETAS (portal/responsable/) que le muestra solo lo suyo, agrupado
-- por sección. Las secciones de cada persona viven en responsable_seccion; esta
-- función las devuelve para el usuario con sesión.

create or replace function public.mis_secciones_responsable()
returns setof text
language sql stable security definer set search_path to 'public' as $$
  select rs.seccion
    from public.responsable_seccion rs
    join public.perfiles p on p.id = rs.perfil_id
   where p.email = (auth.jwt() ->> 'email')
     and coalesce(p.activo, true);
$$;

revoke all on function public.mis_secciones_responsable() from public;
grant execute on function public.mis_secciones_responsable() to authenticated;

-- 'responsable' es un papel nuevo: hay que admitirlo en los CHECK de perfiles.
alter table public.perfiles drop constraint if exists perfiles_roles_check;
alter table public.perfiles add constraint perfiles_roles_check
  check (roles is null or roles <@ array['admin','coordinador','entrenador','atleta','padre','tesoreria','contabilidad','junta','cubo','escuela','cubo-atleta','cubo-lista','socio','responsable']);
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles add constraint perfiles_rol_check
  check (rol = any(array['admin','coordinador','entrenador','atleta','padre','tesoreria','contabilidad','junta','cubo','escuela','cubo-atleta','cubo-lista','socio','responsable']));

-- Papel 'responsable' para Mario y la cuenta de prueba (que ya son responsables
-- de natación en responsable_seccion). Los triggers de protección de roles
-- bloquean los cambios de no-admin; aquí se actúa como sistema para saltarlos.
set session_replication_role = replica;
update public.perfiles
   set roles = (select array(select distinct unnest(coalesce(roles, array[rol]) || array['responsable'])))
 where email in ('mario.apolana@gmail.com', 'claveroandres4@gmail.com');
set session_replication_role = origin;
