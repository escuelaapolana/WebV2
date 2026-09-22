-- ============================================================
-- 208 · ¿Esta persona ya está en el club? (para no duplicar)
-- ------------------------------------------------------------
-- Dada una lista de «contactos» (correos o teléfonos, tal cual los deja
-- la gente en los formularios) y/o una lista de DNIs, devuelve cuáles
-- casan con una FICHA existente (tabla atletas), con su nombre. Así el
-- buzón y las altas pueden avisar «ojo, este ya es del club» y el club
-- decide enlazar en vez de crear un duplicado.
--
-- Coincidencia:
--   · correo: igual (sin mayúsculas ni espacios) a email o email_tutor.
--   · teléfono: mismos últimos 9 dígitos (aguanta prefijos/espacios).
--   · DNI: igual sin espacios/guiones ni mayúsculas.
-- Solo lo puede llamar el club (admin o tesorería).
-- ============================================================

create or replace function public.persona_ya_en_club(
  p_contactos text[] default '{}',
  p_dnis text[] default '{}'
)
returns table(clave text, tipo text, atleta_id uuid, nombre text, apellidos text)
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not (public.es_admin() or public.es_tesoreria()) then
    raise exception 'Solo el club puede consultar esto.' using errcode = '42501';
  end if;

  -- Por contacto (correo o teléfono)
  return query
  with e as (
    select v as clave,
           lower(trim(v)) as email_norm,
           regexp_replace(v, '\D', '', 'g') as tel_norm
    from unnest(coalesce(p_contactos, '{}')) v
    where coalesce(trim(v), '') <> ''
  )
  select distinct on (e.clave)
    e.clave, 'contacto'::text, a.id, a.nombre, a.apellidos
  from e
  join atletas a on (
    (position('@' in e.email_norm) > 0 and (lower(a.email) = e.email_norm or lower(a.email_tutor) = e.email_norm))
    or (length(e.tel_norm) >= 9
        and length(regexp_replace(coalesce(a.telefono,''), '\D', '', 'g')) >= 9
        and right(regexp_replace(a.telefono, '\D', '', 'g'), 9) = right(e.tel_norm, 9))
  )
  where a.estado is distinct from 'baja'
  order by e.clave, a.id;

  -- Por DNI
  return query
  with d as (
    select v as clave, upper(regexp_replace(v, '[^0-9A-Za-z]', '', 'g')) as dni_norm
    from unnest(coalesce(p_dnis, '{}')) v
    where coalesce(trim(v), '') <> ''
  )
  select distinct on (d.clave)
    d.clave, 'dni'::text, a.id, a.nombre, a.apellidos
  from d
  join atletas a on upper(regexp_replace(coalesce(a.dni,''), '[^0-9A-Za-z]', '', 'g')) = d.dni_norm
  where d.dni_norm <> '' and a.estado is distinct from 'baja'
  order by d.clave, a.id;
end;
$function$;

grant execute on function public.persona_ya_en_club(text[], text[]) to authenticated;
