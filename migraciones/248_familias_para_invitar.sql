-- 248 · Datos para el correo de invitación de cada familia de escuela
-- ---------------------------------------------------------------------------
-- Devuelve, por familia (email del tutor): su token de acceso sin usar y sus
-- hijos con las franjas (día/hora/nivel). Lo usa la Edge familia-invitar para
-- armar y enviar el correo. SECURITY DEFINER; la llama la Edge con service_role
-- (que además comprueba que quien dispara es admin), así que NO se abre a
-- authenticated/anon.
-- ---------------------------------------------------------------------------
begin;

-- Marca de "a esta familia ya le mandé el correo" (para reintentar sin duplicar).
alter table public.familia_invitaciones add column if not exists invitado_en timestamptz;

drop function if exists public.familias_para_invitar(boolean);
create or replace function public.familias_para_invitar(p_solo_sin_cuenta boolean default false)
returns table(email text, token text, hijos jsonb, ya_tiene_cuenta boolean, invitado_en timestamptz)
language sql stable security definer set search_path = 'public' as $$
  with base as (
    select lower(a.email_tutor) as email, a.id as atleta_id,
           btrim(a.nombre || ' ' || coalesce(a.apellidos, '')) as nombre,
           f.dia, to_char(f.hora, 'HH24:MI') as hora, coalesce(i.nivel, '') as nivel
    from public.natacion_inscripciones i
    join public.atletas a on a.id = i.atleta_id
    join public.natacion_franjas f on f.id = i.franja_id
    where i.activa and i.tipo = 'Escuela'
      and a.email_tutor is not null and a.email_tutor <> ''
  ),
  porhijo as (
    select email, atleta_id, nombre,
      jsonb_agg(distinct jsonb_build_object('dia', dia, 'hora', hora, 'nivel', nivel)) as franjas
    from base group by email, atleta_id, nombre
  ),
  porfam as (
    select email, jsonb_agg(jsonb_build_object('nombre', nombre, 'franjas', franjas) order by nombre) as hijos
    from porhijo group by email
  )
  select pf.email, t.token, pf.hijos,
    exists(select 1 from public.perfiles p where lower(p.email) = pf.email) as ya_tiene_cuenta,
    t.invitado_en
  from porfam pf
  left join lateral (
    select fi.token, fi.invitado_en from public.familia_invitaciones fi
     where lower(fi.email_tutor) = pf.email and fi.usado_en is null and fi.caduca_en > now()
     order by fi.creado_en desc limit 1
  ) t on true
  order by pf.email;
$$;
revoke all on function public.familias_para_invitar(boolean) from public, anon, authenticated;

commit;
