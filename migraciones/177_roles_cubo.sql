-- 177 · Registrar los papeles del Cubo en la base
-- ------------------------------------------------------------
-- Los papeles `cubo-atleta` (quien entrena) y `cubo-lista` (entrenador
-- que solo pasa lista) ya estaban en el front (papeles.js), pero los
-- CHECK de la base solo conocían los de siempre, así que ni el registro
-- ni el reparto de papeles los aceptaba. Los añadimos a los cuatro sitios
-- donde se enumeran los roles válidos.
-- ============================================================

begin;

alter table public.invitaciones_equipo drop constraint invitaciones_rol_valido;
alter table public.invitaciones_equipo add constraint invitaciones_rol_valido
  check (rol = any (array['admin','coordinador','entrenador','atleta','padre',
                          'tesoreria','contabilidad','junta','cubo','cubo-atleta','cubo-lista']));

alter table public.invitaciones_equipo drop constraint invitaciones_roles_validos;
alter table public.invitaciones_equipo add constraint invitaciones_roles_validos
  check (roles is null or roles <@ array['admin','coordinador','entrenador','atleta','padre',
                          'tesoreria','contabilidad','junta','cubo','cubo-atleta','cubo-lista']);

alter table public.perfiles drop constraint perfiles_rol_check;
alter table public.perfiles add constraint perfiles_rol_check
  check (rol = any (array['admin','coordinador','entrenador','atleta','padre',
                          'tesoreria','contabilidad','junta','cubo','escuela','cubo-atleta','cubo-lista']));

alter table public.perfiles drop constraint perfiles_roles_check;
alter table public.perfiles add constraint perfiles_roles_check
  check (roles is null or roles <@ array['admin','coordinador','entrenador','atleta','padre',
                          'tesoreria','contabilidad','junta','cubo','escuela','cubo-atleta','cubo-lista']);

commit;
