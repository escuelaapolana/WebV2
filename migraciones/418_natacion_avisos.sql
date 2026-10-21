-- 418 · Natación · AVISOS del mundo Natación (encargo pendiente de Mario)
-- ------------------------------------------------------------------------
-- Mario (y admin) manda un aviso —«cierre de la piscina el jueves», «cambio de
-- horario»— a una o varias FRANJAS, a toda la natación, solo a la escuela o solo
-- al máster. Llega por dos sitios:
--   1) dentro de la app, como aviso (avisos_registrar, uno por persona, igual
--      que natacion_espera_avisar);
--   2) por CORREO con el diseño del club (Edge natacion-aviso, Brevo, desde info@,
--      uno a uno, sin que nadie vea los correos de los demás).
--
-- A quién (por inscripción ACTIVA en franja ACTIVA):
--   · Escuela → la familia: atletas.email_tutor, o el correo del perfil del padre
--     (perfil_padre_id); si no hay, el correo propio del niño.
--   · Máster  → el nadador: atletas.email, o el de su perfil (perfil_id); si no, el del tutor.
--   Un correo por dirección (hermanos = un solo correo con los dos nombres).
--   En la app: el perfil del padre (escuela) / el propio (máster), o el perfil con ese correo.
--
-- Permiso: natacion_cuotas_puede() = admin o responsable de natación / escuela de
-- natación con gestor. Las RPC son SECURITY DEFINER y comprueban dentro.
--   · natacion_aviso_franjas()                 → franjas con cuántos de escuela/máster (authenticated)
--   · natacion_aviso_destinatarios(tipo, ids)  → a quién llegaría (authenticated, no envía nada)
--   · natacion_aviso_registrar(...)            → SOLO service_role (la Edge, tras enviar los correos):
--                                                avisos en la app + fila en el historial
--   · tabla natacion_avisos                    → historial (lectura: quien puede mandar)
-- ------------------------------------------------------------------------
begin;

create table if not exists public.natacion_avisos (
  id              uuid primary key default gen_random_uuid(),
  creado_por      uuid references public.perfiles(id) on delete set null,
  creado_nombre   text,
  creado_email    text,
  tipo            text not null default 'todos' check (tipo in ('todos', 'escuela', 'master')),
  franja_ids      uuid[] not null default '{}',
  alcance         text not null,
  asunto          text not null,
  mensaje         text not null,
  n_nadadores     integer not null default 0,
  n_correos       integer not null default 0,
  n_fallidos      integer not null default 0,
  n_app           integer not null default 0,
  destinatarios   text[] not null default '{}',
  created_at      timestamptz not null default now()
);
create index if not exists natacion_avisos_fecha_idx on public.natacion_avisos (created_at desc);

alter table public.natacion_avisos enable row level security;
revoke all on public.natacion_avisos from public, anon, authenticated;
grant select on public.natacion_avisos to authenticated;
grant all on public.natacion_avisos to service_role;
drop policy if exists "nat avisos leer gestor" on public.natacion_avisos;
create policy "nat avisos leer gestor" on public.natacion_avisos for select to authenticated
  using ((select public.natacion_cuotas_puede()));
-- Escribir: solo por natacion_aviso_registrar (service_role). Sin policies de escritura.


-- Texto legible del alcance: «Toda la natación», «Escuela · Martes 17:30, Jueves 17:30»…
create or replace function public.natacion_aviso_alcance_texto(p_tipo text, p_franjas uuid[])
returns text
language sql stable security definer set search_path to 'public' as $$
  select case coalesce(p_tipo, 'todos')
           when 'escuela' then 'Escuela de natación'
           when 'master'  then 'Máster'
           else case when coalesce(cardinality(p_franjas), 0) = 0 then 'Toda la natación' else 'Natación' end
         end
      || coalesce(' · ' || (
           select string_agg((array['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'])[f.dia]
                             || ' ' || to_char(f.hora, 'HH24:MI'), ', ' order by f.dia, f.hora)
             from public.natacion_franjas f
            where coalesce(cardinality(p_franjas), 0) > 0 and f.id = any(p_franjas)), '');
$$;


-- Una fila por inscripción alcanzada, con su correo y su perfil (interna, sin grants).
create or replace function public.natacion_aviso_alcance(p_tipo text, p_franjas uuid[])
returns table(ins_id uuid, atleta_id uuid, nadador text, tipo text, franja text,
              dia smallint, hora time, email text, perfil_id uuid)
language sql stable security definer set search_path to 'public' as $$
  with base as (
    select i.id as ins_id,
           coalesce(i.atleta_id, ac.atleta_id) as atleta_id,
           i.tipo, i.perfil_id as ins_perfil, f.dia, f.hora,
           coalesce(nullif(btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')), ''), btrim(i.nombre)) as nadador,
           nullif(lower(btrim(a.email)), '')       as a_email,
           nullif(lower(btrim(a.email_tutor)), '') as t_email,
           a.perfil_id, a.perfil_padre_id
      from public.natacion_inscripciones i
      join public.natacion_franjas f on f.id = i.franja_id and f.activa
      left join public.natacion_accesos ac on ac.id = i.acceso_id
      left join public.atletas a on a.id = coalesce(i.atleta_id, ac.atleta_id)
     where i.activa
       and (coalesce(p_tipo, 'todos') = 'todos'
            or (p_tipo = 'escuela' and i.tipo = 'Escuela')
            or (p_tipo = 'master'  and i.tipo = 'Máster'))
       and (coalesce(cardinality(p_franjas), 0) = 0 or i.franja_id = any(p_franjas))
  ), con_correo as (
    select b.*,
           case when b.tipo = 'Escuela'
                then coalesce(b.t_email, lower(pp.email), b.a_email, lower(pa.email), lower(pi.email))
                else coalesce(b.a_email, lower(pa.email), b.t_email, lower(pp.email), lower(pi.email)) end as correo
      from base b
      left join public.perfiles pa on pa.id = b.perfil_id
      left join public.perfiles pp on pp.id = b.perfil_padre_id
      left join public.perfiles pi on pi.id = b.ins_perfil
  )
  select c.ins_id, c.atleta_id, c.nadador, c.tipo,
         (array['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'])[c.dia] || ' ' || to_char(c.hora, 'HH24:MI'),
         c.dia, c.hora,
         case when c.correo ~* '^[^\s@,;]{1,64}@[^\s@,;]{1,190}\.[a-z]{2,}$' then c.correo end,
         case when c.tipo = 'Escuela'
              then coalesce(c.perfil_padre_id, pe.id, c.perfil_id, c.ins_perfil)
              else coalesce(c.perfil_id, pe.id, c.perfil_padre_id, c.ins_perfil) end
    from con_correo c
    left join lateral (select p.id from public.perfiles p
                        where c.correo is not null and lower(p.email) = c.correo
                        order by coalesce(p.activo, true) desc limit 1) pe on true;
$$;


-- Franjas activas con cuántos de escuela y de máster (para los chips de la pantalla).
create or replace function public.natacion_aviso_franjas()
returns table(id uuid, dia smallint, hora text, grupo text, n_escuela integer, n_master integer)
language plpgsql stable security definer set search_path to 'public' as $$
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede mandar avisos.' using errcode = '42501';
  end if;
  return query
    select f.id, f.dia, to_char(f.hora, 'HH24:MI'), f.grupo,
           (count(i.id) filter (where i.tipo = 'Escuela'))::integer,
           (count(i.id) filter (where i.tipo = 'Máster'))::integer
      from public.natacion_franjas f
      left join public.natacion_inscripciones i on i.franja_id = f.id and i.activa
     where f.activa
     group by f.id
     order by f.dia, f.hora;
end $$;


-- A quién llegaría el aviso (no envía nada). Lo usan la pantalla y la Edge.
create or replace function public.natacion_aviso_destinatarios(p_tipo text default 'todos', p_franjas uuid[] default '{}')
returns jsonb
language plpgsql stable security definer set search_path to 'public' as $$
declare v jsonb;
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede mandar avisos.' using errcode = '42501';
  end if;
  if coalesce(p_tipo, 'todos') not in ('todos', 'escuela', 'master') then
    raise exception 'El destino tiene que ser todos, escuela o máster.';
  end if;

  with x as (select * from public.natacion_aviso_alcance(p_tipo, p_franjas)),
  -- un nadador (ficha, o inscripción suelta) con sus franjas
  nad as (
    select coalesce(x.atleta_id, x.ins_id) as k, min(x.nadador) as nadador, min(x.tipo) as tipo, min(x.email) as email,
           string_agg(x.franja, ' · ' order by x.dia, x.hora) as franjas
      from x group by coalesce(x.atleta_id, x.ins_id)
  ),
  porcorreo as (
    select n.email,
           jsonb_agg(jsonb_build_object('nombre', n.nadador, 'tipo', n.tipo, 'franjas', n.franjas) order by n.nadador) as nadadores,
           bool_or(n.tipo = 'Escuela') as escuela, bool_or(n.tipo = 'Máster') as master
      from nad n where n.email is not null group by n.email
  )
  select jsonb_build_object(
    'alcance',    public.natacion_aviso_alcance_texto(p_tipo, p_franjas),
    'nadadores',  (select count(*) from nad),
    'correos',    coalesce((select jsonb_agg(jsonb_build_object('email', c.email, 'nadadores', c.nadadores,
                                                                'escuela', c.escuela, 'master', c.master) order by c.email)
                              from porcorreo c), '[]'::jsonb),
    'sin_correo', coalesce((select jsonb_agg(n.nadador order by n.nadador) from nad n where n.email is null), '[]'::jsonb),
    'en_app',     (select count(distinct x.perfil_id) from x where x.perfil_id is not null)
  ) into v;
  return v;
end $$;


-- Registrar el envío: avisos en la app (uno por persona) + fila en el historial.
-- SOLO service_role: la llama la Edge natacion-aviso después de comprobar el
-- permiso con el JWT de quien envía y de mandar los correos.
create or replace function public.natacion_aviso_registrar(
  p_autor uuid, p_autor_email text, p_tipo text, p_franjas uuid[],
  p_asunto text, p_mensaje text, p_correos text[], p_fallidos integer
) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare
  v_alcance text := public.natacion_aviso_alcance_texto(p_tipo, p_franjas);
  v_perfil  uuid;
  v_app     integer := 0;
  v_nad     integer;
  v_nombre  text;
  v_id      uuid;
begin
  if nullif(btrim(coalesce(p_asunto, '')), '') is null or nullif(btrim(coalesce(p_mensaje, '')), '') is null then
    raise exception 'Falta el asunto o el mensaje.';
  end if;
  if coalesce(p_tipo, 'todos') not in ('todos', 'escuela', 'master') then
    raise exception 'El destino tiene que ser todos, escuela o máster.';
  end if;

  for v_perfil in
    select distinct a.perfil_id from public.natacion_aviso_alcance(p_tipo, p_franjas) a where a.perfil_id is not null
  loop
    perform public.avisos_registrar(
      left(btrim(p_asunto), 150), left(btrim(p_mensaje), 4000), null,
      'persona', 'entrenos', null, null, v_perfil,
      case when v_alcance ilike 'natación%' or v_alcance ilike 'toda la natación%' or v_alcance ilike 'escuela de natación%'
           then v_alcance else 'Natación · ' || v_alcance end,
      0, 0, p_autor, null, 'importante', null, false, '{}'
    );
    v_app := v_app + 1;
  end loop;

  select count(distinct coalesce(a.atleta_id, a.ins_id)) into v_nad
    from public.natacion_aviso_alcance(p_tipo, p_franjas) a;
  select nullif(btrim(coalesce(nombre, '') || ' ' || coalesce(apellidos, '')), '') into v_nombre
    from public.perfiles where id = p_autor;

  insert into public.natacion_avisos
    (creado_por, creado_nombre, creado_email, tipo, franja_ids, alcance, asunto, mensaje,
     n_nadadores, n_correos, n_fallidos, n_app, destinatarios)
  values
    (p_autor, v_nombre, p_autor_email, coalesce(p_tipo, 'todos'), coalesce(p_franjas, '{}'), v_alcance,
     left(btrim(p_asunto), 150), left(btrim(p_mensaje), 4000),
     coalesce(v_nad, 0), coalesce(cardinality(p_correos), 0), greatest(coalesce(p_fallidos, 0), 0), v_app,
     coalesce(p_correos, '{}'))
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'en_app', v_app, 'alcance', v_alcance);
end $$;


-- Permisos de ejecución (desde mig 386 nada nuevo queda abierto a anon; aquí se
-- deja cada una solo a quien la necesita).
revoke all on function public.natacion_aviso_alcance_texto(text, uuid[]) from public, anon, authenticated;
revoke all on function public.natacion_aviso_alcance(text, uuid[])       from public, anon, authenticated;
revoke all on function public.natacion_aviso_registrar(uuid, text, text, uuid[], text, text, text[], integer) from public, anon, authenticated;
revoke all on function public.natacion_aviso_franjas()                   from public, anon;
revoke all on function public.natacion_aviso_destinatarios(text, uuid[]) from public, anon;
grant execute on function public.natacion_aviso_franjas()                   to authenticated, service_role;
grant execute on function public.natacion_aviso_destinatarios(text, uuid[]) to authenticated, service_role;
grant execute on function public.natacion_aviso_alcance_texto(text, uuid[]) to service_role;
grant execute on function public.natacion_aviso_alcance(text, uuid[])       to service_role;
grant execute on function public.natacion_aviso_registrar(uuid, text, text, uuid[], text, text, text[], integer) to service_role;

commit;
