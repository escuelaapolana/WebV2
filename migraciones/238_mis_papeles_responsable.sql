-- 238 · mis_papeles() añade las secciones de las que soy responsable, para que
-- el selector etiquete el papel por su sección ("Responsable natación",
-- "Responsable escuela de atletismo"…) en vez de un "Responsable" genérico.

create or replace function public.mis_papeles()
 returns jsonb
 language sql stable security definer set search_path to 'public'
as $function$
  select jsonb_build_object(
    'nombre',    btrim(coalesce(p.nombre,'') || ' ' || coalesce(p.apellidos,'')),
    'principal', p.rol,
    'activo',    coalesce(p.rol_activo, p.papel_al_entrar, p.rol),
    'elegido',   p.rol_activo,
    'al_entrar', p.papel_al_entrar,
    'roles',     to_jsonb(coalesce(p.roles, array[p.rol])),
    'responsable', coalesce(
      (select jsonb_agg(rs.seccion order by rs.seccion)
         from public.responsable_seccion rs where rs.perfil_id = p.id),
      '[]'::jsonb)
  )
    from public.perfiles p
   where p.email = (auth.jwt() ->> 'email')
   limit 1;
$function$;
