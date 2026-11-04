-- 516 · Seguridad (revisión 4-nov-2026) · El Cubo: comprobar en la base que
-- quien marca «soy socio» o «familia de la escuela» lo es de verdad
-- ---------------------------------------------------------------------------
-- La Edge cubo-alta (formulario público /cubo/apuntarse/) se fiaba de las
-- casillas socio/escuela del navegador para el precio reducido y, desde la
-- 509, para el sábado gratis. No se rechaza a nadie (una persona real con otro
-- correo o DNI se quedaría fuera, y el alta ya pasa por la revisión del club):
-- si la base no lo confirma, el alta llega con un aviso en la nota para
-- comprobarlo antes de aprobarla.
--
-- Socio: ficha con tipo 'socio' o con número de socio, por correo o DNI.
-- Escuela: un niño de la escuela (ficha 'escuela', 'municipal' o en un grupo
-- de la sección escuela) que case por correo (del niño o del tutor), teléfono
-- del tutor o nombre + primer apellido del hijo que escribe en el formulario;
-- o un alta de escuela con ese correo, DNI o teléfono de tutor.
-- Con las 44 altas reales que marcaron socio/escuela: confirma 2/2 socios y
-- casi todas las de escuela (la que no, es justo la que hay que mirar).
-- Solo la llama la Edge (service_role): no delata a nadie desde fuera.

drop function if exists public.cubo_reducido_confirmado(text, text);

create or replace function public.cubo_reducido_confirmado(p_email text, p_dni text, p_telefono text default null, p_hijo text default null)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  with q as (
    select nullif(lower(btrim(coalesce(p_email, ''))), '') as email,
           nullif(upper(regexp_replace(coalesce(p_dni, ''), '[^A-Za-z0-9]', '', 'g')), '') as dni,
           case when length(regexp_replace(coalesce(p_telefono, ''), '\D', '', 'g')) >= 9
                then right(regexp_replace(p_telefono, '\D', '', 'g'), 9) end as tel,
           nullif(lower(unaccent(btrim(coalesce(p_hijo, '')))), '') as hijo
  ),
  ninos as (
    select a.* from atletas a left join grupos g on g.id = a.grupo_id
     where a.tipo_membresia in ('escuela', 'municipal') or g.seccion = 'escuela'
  )
  select jsonb_build_object(
    'socio', exists (
      select 1 from atletas a, q
       where (a.tipo_membresia = 'socio' or a.numero_socio is not null)
         and ((q.email is not null and lower(a.email) = q.email)
           or (q.dni is not null and upper(regexp_replace(coalesce(a.dni, ''), '[^A-Za-z0-9]', '', 'g')) = q.dni))),
    'escuela', exists (
      select 1 from ninos a, q
       where (q.email is not null and (lower(a.email) = q.email or lower(a.email_tutor) = q.email))
          or (q.tel is not null and right(regexp_replace(coalesce(a.telefono_tutor, ''), '\D', '', 'g'), 9) = q.tel)
          or (q.hijo is not null and length(a.nombre) > 1 and length(split_part(a.apellidos, ' ', 1)) > 1
              and q.hijo like '%' || lower(unaccent(a.nombre)) || '%'
              and q.hijo like '%' || lower(unaccent(split_part(a.apellidos, ' ', 1))) || '%'))
      or exists (
      select 1 from altas_escuela e, q
       where (q.email is not null and lower(e.tutor_email) = q.email)
          or (q.dni is not null and upper(regexp_replace(coalesce(e.tutor_dni, ''), '[^A-Za-z0-9]', '', 'g')) = q.dni)
          or (q.tel is not null and right(regexp_replace(coalesce(e.tutor_telefono, ''), '\D', '', 'g'), 9) = q.tel))
  )
  from q;
$function$;

revoke all on function public.cubo_reducido_confirmado(text, text, text, text) from public, anon, authenticated;
grant execute on function public.cubo_reducido_confirmado(text, text, text, text) to service_role;
