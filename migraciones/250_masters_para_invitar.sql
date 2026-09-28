-- 250 · Datos para el correo de acceso de cada nadador MÁSTER
-- ---------------------------------------------------------------------------
-- Por nadador Máster (su propio correo): su token sin usar y sus franjas
-- (día/hora/calle/nivel). Calles y grupos vienen tal cual de la app («Por
-- franja»), no se recalcula nada. La usa la Edge familia-invitar (modo master).
-- ---------------------------------------------------------------------------
begin;

create or replace function public.masters_para_invitar()
returns table(email text, token text, nombre text, franjas jsonb, invitado_en timestamptz)
language sql stable security definer set search_path = 'public' as $$
  with base as (
    select lower(a.email) email, btrim(a.nombre || ' ' || coalesce(a.apellidos, '')) nombre,
           f.dia, to_char(f.hora, 'HH24:MI') hora,
           coalesce(nullif(btrim(i.calle::text), ''), '') calle, coalesce(i.nivel, '') nivel
    from public.natacion_inscripciones i
    join public.atletas a on a.id = i.atleta_id
    join public.natacion_franjas f on f.id = i.franja_id
    where i.activa and i.tipo = 'Máster' and a.email is not null and btrim(a.email) <> ''
  ),
  porpersona as (
    select email, min(nombre) nombre,
      jsonb_agg(distinct jsonb_build_object('dia', dia, 'hora', hora, 'calle', calle, 'nivel', nivel)) franjas
    from base group by email
  )
  select pp.email, t.token, pp.nombre, pp.franjas, t.invitado_en
  from porpersona pp
  left join lateral (
    select fi.token, fi.invitado_en from public.familia_invitaciones fi
     where lower(fi.email_tutor) = pp.email and fi.usado_en is null and fi.caduca_en > now()
     order by fi.creado_en desc limit 1
  ) t on true
  order by pp.email;
$$;
revoke all on function public.masters_para_invitar() from public, anon, authenticated;

commit;
