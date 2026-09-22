-- ============================================================
-- 209 · Rol nuevo «socio» (acceso básico: noticias + actividades)
-- ------------------------------------------------------------
-- El socio que se da de alta en /socio/alta/ sale con cuenta para
-- entrar a su zona (noticias del club y actividades a las que apuntarse).
-- Es un papel de acceso, no de entreno. Aquí solo se AMPLÍAN los CHECK de
-- roles para admitir 'socio'; el perfil lo crea el trigger de siempre a
-- partir de una invitación (igual que cubo-atleta).
-- ============================================================

-- perfiles.rol
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles add constraint perfiles_rol_check
  check (rol = any (array['admin','coordinador','entrenador','atleta','padre','tesoreria','contabilidad','junta','cubo','escuela','cubo-atleta','cubo-lista','socio']));

-- perfiles.roles (lista)
alter table public.perfiles drop constraint if exists perfiles_roles_check;
alter table public.perfiles add constraint perfiles_roles_check
  check (roles is null or roles <@ array['admin','coordinador','entrenador','atleta','padre','tesoreria','contabilidad','junta','cubo','escuela','cubo-atleta','cubo-lista','socio']);

-- invitaciones_equipo.rol
alter table public.invitaciones_equipo drop constraint if exists invitaciones_rol_valido;
alter table public.invitaciones_equipo add constraint invitaciones_rol_valido
  check (rol = any (array['admin','coordinador','entrenador','atleta','padre','tesoreria','contabilidad','junta','cubo','cubo-atleta','cubo-lista','socio']));

-- invitaciones_equipo.roles (lista)
alter table public.invitaciones_equipo drop constraint if exists invitaciones_roles_validos;
alter table public.invitaciones_equipo add constraint invitaciones_roles_validos
  check (roles is null or roles <@ array['admin','coordinador','entrenador','atleta','padre','tesoreria','contabilidad','junta','cubo','cubo-atleta','cubo-lista','socio']);
