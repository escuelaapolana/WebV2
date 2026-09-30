-- 263 · El responsable de la Liga (José Luis) no podía VALIDAR porque todas las
-- participaciones salían «Sin nombre»: es_responsable_liga puede leer
-- liga_participaciones (mig 259) pero NO la tabla atletas (RLS solo staff), así
-- que no resolvía el nombre del atleta. Se le da una función acotada que
-- devuelve SOLO id + nombre + apellidos + fecha de nacimiento (para la
-- categoría) — nada de DNI, email ni contacto. Abierta a staff o resp. de liga.
begin;

create or replace function public.liga_atletas_nombres()
 returns table(id uuid, nombre text, apellidos text, fecha_nacimiento date)
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select a.id, a.nombre, a.apellidos, a.fecha_nacimiento
  from public.atletas a
  where public.es_staff() or public.es_responsable_liga()
  order by a.apellidos, a.nombre
$function$;

grant execute on function public.liga_atletas_nombres() to authenticated;

commit;
