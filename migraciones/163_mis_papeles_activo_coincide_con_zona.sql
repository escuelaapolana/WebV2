-- 163 · La franja de papel coincide con la zona en la que aterrizas
-- ---------------------------------------------------------------------------
-- Problema: quien entra con `papel_al_entrar` puesto (p. ej. Andrés, que es
-- admin pero entra en «atleta» para ver su entrenamiento) aterrizaba en la zona
-- de atleta, pero la franja/selector de arriba decía «administrador». El motivo:
-- `mis_papeles().activo` era `coalesce(rol_activo, rol)`, así que con `rol_activo`
-- en NULL caía en el rol PRINCIPAL (admin), no en la zona real. Además el salto
-- rápido del portal (recuerda la última zona en localStorage) se adelanta a
-- `rol_al_entrar_aplicar()`, así que `rol_activo` puede quedarse en NULL.
--
-- Arreglo: `activo = coalesce(rol_activo, papel_al_entrar, rol)`. Así la etiqueta
-- refleja DÓNDE ESTÁS de verdad: el papel elegido si has cambiado a mano; si no,
-- el papel con el que entras (papel_al_entrar); y solo si tampoco hay, el
-- principal. Es un cambio de PANTALLA (mis_papeles solo alimenta la franja y el
-- selector); no toca permisos ni RLS.
-- ---------------------------------------------------------------------------

create or replace function public.mis_papeles()
  returns jsonb
  language sql
  stable security definer
  set search_path to 'public'
as $function$
  select jsonb_build_object(
    'nombre',    btrim(coalesce(p.nombre,'') || ' ' || coalesce(p.apellidos,'')),
    'principal', p.rol,
    'activo',    coalesce(p.rol_activo, p.papel_al_entrar, p.rol),
    'elegido',   p.rol_activo,                 -- null = está en el suyo de siempre
    'al_entrar', p.papel_al_entrar,            -- null = el último que usé
    'roles',     to_jsonb(coalesce(p.roles, array[p.rol]))
  )
    from public.perfiles p
   where p.email = (auth.jwt() ->> 'email')
   limit 1;
$function$;
