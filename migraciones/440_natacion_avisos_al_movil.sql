-- 440 · Que los avisos de natación hagan sonar el móvil
-- ---------------------------------------------------------------------------
-- Dos fallos que se arreglan juntos (23-oct):
--
-- 1) La lista de espera (mig 272/415) apunta en la cola el toque 'nat_hueco',
--    pero la cola de la 136 solo admitía tres clases ('solicitud_plaza',
--    'plaza_si', 'plaza_no') y `avisos_cola_movil_poner` lo tiraba en silencio.
--    Resultado: el hueco llegaba al buzón de la app y por correo, pero el
--    móvil no sonaba nunca.
--
-- 2) Los avisos que escribe Mario (mig 418, «Avisos» del mundo Natación) iban
--    por correo y al buzón de la app (con p_movil = false), sin toque al móvil.
--    Ahora apuntan 'nat_aviso' en la cola con `ref` = la fila del historial
--    (natacion_avisos), y `aviso-enviar` pone de título el ASUNTO que escribió
--    Mario («Cierre de la piscina el jueves»). Es texto del club, el mismo que
--    ya sale en el correo; no lleva datos de nadie. La cola sigue sin guardar
--    ni una palabra: solo clase, persona y referencia.
--
-- 3) Y la cola ya no depende de que alguien abra el portal: la 136 decía que
--    la base no podía llamar a la función (no había pg_net); hoy sí lo hay
--    (cron_llamar_edge lo usa). Un cron cada minuto mira si hay toques
--    pendientes y, SOLO si los hay y es hora decente, llama a aviso-enviar
--    {cola:true}. Con la cola vacía no se llama a nada.
-- ---------------------------------------------------------------------------
begin;

-- 1 · Las dos clases nuevas y la referencia -----------------------------------
alter table public.avisos_cola_movil drop constraint if exists avisos_cola_movil_clase_check;
alter table public.avisos_cola_movil add constraint avisos_cola_movil_clase_check
  check (clase in ('solicitud_plaza', 'plaza_si', 'plaza_no', 'nat_hueco', 'nat_aviso'));

-- A qué se refiere el toque cuando hace falta (nat_aviso → natacion_avisos.id).
alter table public.avisos_cola_movil add column if not exists ref uuid;

-- 2 · Apuntar un recado (ahora con referencia opcional) -----------------------
drop function if exists public.avisos_cola_movil_poner(text, uuid);
create or replace function public.avisos_cola_movil_poner(
  p_clase  text,
  p_perfil uuid,
  p_ref    uuid default null
)
returns void
language plpgsql
volatile
security definer
set search_path to 'public'
as $$
begin
  if p_perfil is null
     or p_clase is null
     or p_clase not in ('solicitud_plaza', 'plaza_si', 'plaza_no', 'nat_hueco', 'nat_aviso') then
    return;
  end if;

  -- Uno igual esperando (misma clase y misma referencia) ya basta.
  if exists (
    select 1 from public.avisos_cola_movil
     where perfil_id = p_perfil
       and clase = p_clase
       and ref is not distinct from p_ref
       and enviado_en is null
  ) then
    return;
  end if;

  insert into public.avisos_cola_movil (clase, perfil_id, ref)
  values (p_clase, p_perfil, p_ref);
end;
$$;
revoke all on function public.avisos_cola_movil_poner(text, uuid, uuid) from public, anon, authenticated;

-- 3 · Coger lo que toca mandar (devuelve además el asunto de nat_aviso) -------
drop function if exists public.avisos_cola_movil_tomar(integer);
create or replace function public.avisos_cola_movil_tomar(p_tope integer default 40)
returns table (id uuid, clase text, detalle text)
language plpgsql
volatile
security definer
set search_path to 'public'
as $$
begin
  if not public.novedades_hora_decente(now()) then
    return;
  end if;

  delete from public.avisos_cola_movil
   where enviado_en is null
     and creado_en < now() - interval '12 hours';

  delete from public.avisos_cola_movil
   where enviado_en is not null
     and enviado_en < now() - interval '7 days';

  return query
  with cogidas as (
    select c.id
      from public.avisos_cola_movil c
     where c.enviado_en is null
       and (c.tomado_en is null or c.tomado_en < now() - interval '5 minutes')
     order by c.creado_en
     limit greatest(1, least(coalesce(p_tope, 40), 200))
     for update skip locked
  ), marcadas as (
    update public.avisos_cola_movil c
       set tomado_en = now()
      from cogidas
     where c.id = cogidas.id
    returning c.id, c.clase, c.ref
  )
  select m.id, m.clase,
         case when m.clase = 'nat_aviso' then (select na.asunto from public.natacion_avisos na where na.id = m.ref) end
    from marcadas m;
end;
$$;
revoke all on function public.avisos_cola_movil_tomar(integer) from public, anon, authenticated;
grant execute on function public.avisos_cola_movil_tomar(integer) to service_role;

-- 4 · Los avisos de Mario: historial primero (para tener su id) y toque -------
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
     coalesce(v_nad, 0), coalesce(cardinality(p_correos), 0), greatest(coalesce(p_fallidos, 0), 0), 0,
     coalesce(p_correos, '{}'))
  returning id into v_id;

  for v_perfil in
    select distinct a.perfil_id from public.natacion_aviso_alcance(p_tipo, p_franjas) a where a.perfil_id is not null
  loop
    perform public.avisos_registrar(
      left(btrim(p_asunto), 150), left(btrim(p_mensaje), 4000), null,
      'persona', 'entrenos', null, null, v_perfil,
      case when v_alcance ilike 'natación%' or v_alcance ilike 'toda la natación%' or v_alcance ilike 'escuela de natación%'
           then v_alcance else 'Natación · ' || v_alcance end,
      0, 0, p_autor, null, 'importante', null, true, '{}'
    );
    -- (mig 440) Y que suene el móvil. Si apuntarlo fallara, el aviso ya está
    -- en la app y en el correo: no se deshace nada.
    begin
      perform public.avisos_cola_movil_poner('nat_aviso', v_perfil, v_id);
    exception when others then
      raise warning 'natacion_aviso_registrar: no se pudo apuntar el toque: %', sqlerrm;
    end;
    v_app := v_app + 1;
  end loop;

  update public.natacion_avisos set n_app = v_app where id = v_id;

  return jsonb_build_object('id', v_id, 'en_app', v_app, 'alcance', v_alcance);
end $$;
revoke all on function public.natacion_aviso_registrar(uuid, text, text, uuid[], text, text, text[], integer) from public, anon, authenticated;
grant execute on function public.natacion_aviso_registrar(uuid, text, text, uuid[], text, text, text[], integer) to service_role;

-- 5 · El cron que vacía la cola sin esperar a que alguien abra el portal -------
create or replace function public.avisos_cola_movil_empujar()
returns bigint
language plpgsql
volatile
security definer
set search_path to 'public'
as $$
begin
  if not public.novedades_hora_decente(now()) then
    return null;
  end if;
  if not exists (
    select 1 from public.avisos_cola_movil c
     where c.enviado_en is null
       and c.creado_en > now() - interval '12 hours'
       and (c.tomado_en is null or c.tomado_en < now() - interval '5 minutes')
  ) then
    return null;
  end if;
  return public.cron_llamar_edge('aviso-enviar', '{"cola": true}'::jsonb, null);
end;
$$;
revoke all on function public.avisos_cola_movil_empujar() from public, anon, authenticated;
grant execute on function public.avisos_cola_movil_empujar() to service_role;

select cron.unschedule('apolana-avisos-cola-movil')
 where exists (select 1 from cron.job where jobname = 'apolana-avisos-cola-movil');
select cron.schedule('apolana-avisos-cola-movil', '* * * * *', $$ select public.avisos_cola_movil_empujar() $$);

commit;
