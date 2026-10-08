-- 302 · Reenviar el correo de acceso a una familia de natación ya dada de alta
-- Da, para un acceso existente, el correo, el código y si la familia ya tiene
-- cuenta → la pantalla decide si manda la INVITACIÓN (familia-invitar) o los
-- HORARIOS (correo-natacion-horarios), igual que hace el alta.
-- Hace falta porque a veces la ficha se crea sin que salga el correo (p. ej. un
-- alta hecha por detrás) y el monitor necesita reenviarlo con un botón.

create or replace function public.natacion_acceso_de(p_acceso uuid)
returns table(email text, codigo text, ya_tiene_cuenta boolean, publico text)
language sql stable security definer set search_path to 'public' as $$
  select
    lower(coalesce(nullif(btrim(a.email), ''), nullif(btrim(a.email_tutor), ''))) as email,
    acc.codigo,
    exists (
      select 1 from public.perfiles p
      where lower(p.email) = lower(coalesce(nullif(btrim(a.email), ''), nullif(btrim(a.email_tutor), '')))
    ) as ya_tiene_cuenta,
    case when nullif(btrim(a.email), '') is not null then 'master' else 'familia' end as publico
  from public.natacion_accesos acc
  join public.atletas a on a.id = acc.atleta_id
  where acc.id = p_acceso
    and (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))
  limit 1;
$$;

grant execute on function public.natacion_acceso_de(uuid) to authenticated;
