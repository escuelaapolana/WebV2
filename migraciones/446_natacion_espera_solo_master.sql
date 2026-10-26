-- 446 · Natación · la lista de espera es SOLO para nadadores Máster
-- ---------------------------------------------------------------------------
-- Andrés (26-oct-2026): «Mario ha entrado desde el perfil de Lukas (escuela) y
-- le ha llegado aviso de hueco… la escuela no usa bonos. Escuela, si no puede
-- ir, no puede recuperar».
--
-- La lista de espera (mig 272) avisa cuando alguien marca «no voy» y queda un
-- hueco de UN día: «el primero que reserve se lo queda». Reservar ese hueco
-- solo se puede con bono de recuperación, y los bonos son solo de Máster
-- (natacion_master_usar_bono). Pero el botón «Avísame si se libera» de la web
-- dejaba apuntarse a cualquiera con cuenta, en cualquier franja: la familia de
-- Lukas (Escuela) estaba apuntada desde el 2-oct a las franjas Máster de lunes
-- y miércoles 15:30 y hoy le llegaron dos avisos de hueco que no podía usar.
-- Igual otras dos familias de Escuela (Carolina Navija, Ana Penalva).
--
-- Arreglo:
--   1) apuntarse: solo quien nada en Máster (natacion_master_yo) y en una
--      franja de adultos (natacion_es_master, la misma regla que la web).
--   2) avisar: solo a los de la lista que siguen siendo Máster (por si queda
--      alguna fila vieja o alguien deja de ser Máster).
--   3) Se quitan de la lista las filas de quien no es Máster (5 filas, 3
--      familias de Escuela), sin avisarles.
-- La web deja de enseñar el botón en la página de la Escuela.
-- ---------------------------------------------------------------------------
begin;

CREATE OR REPLACE FUNCTION public.natacion_espera_apuntarse(p_franja uuid, p_atleta uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_perfil uuid := public.mi_perfil_id();
  v_nombre text;
  v_id     uuid;
begin
  if v_perfil is null then
    raise exception 'Entra en tu cuenta para apuntarte a la lista de espera.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.natacion_franjas where id = p_franja and activa) then
    raise exception 'Esa franja no existe.' using errcode = 'P0001';
  end if;
  -- (mig 446) Solo Máster: el hueco de un día se recupera con bono, y en la
  -- Escuela no se recupera.
  if not exists (select 1 from public.natacion_master_yo()) then
    raise exception 'La lista de espera es para los nadadores Máster, que pueden recuperar un día con su bono. En la Escuela, si un día no se puede venir, no se recupera. Para cambiar de horario, escribe a Mario.'
      using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.natacion_franjas f
                  where f.id = p_franja and public.natacion_es_master(f.grupo, f.admite_master)) then
    raise exception 'Esa franja es solo de la Escuela.' using errcode = 'P0001';
  end if;
  -- El atleta solo si es suyo (o de un hijo); si no, se guarda sin atleta.
  if p_atleta is not null and not exists (
    select 1 from public.atletas a
    where a.id = p_atleta and (a.perfil_id = v_perfil or a.perfil_padre_id = v_perfil)
  ) then
    p_atleta := null;
  end if;

  select nullif(btrim(coalesce(p.nombre, '') || ' ' || coalesce(p.apellidos, '')), '')
    into v_nombre from public.perfiles p where p.id = v_perfil;
  if p_atleta is not null then
    select nullif(btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')), '')
      into v_nombre from public.atletas a where a.id = p_atleta;
  end if;

  update public.natacion_lista_espera
     set activa = true,
         nombre = coalesce(v_nombre, nombre),
         avisado_en = null
   where franja_id = p_franja and perfil_id = v_perfil
     and coalesce(atleta_id, '00000000-0000-0000-0000-000000000000'::uuid)
         = coalesce(p_atleta, '00000000-0000-0000-0000-000000000000'::uuid)
   returning id into v_id;

  if v_id is null then
    insert into public.natacion_lista_espera (franja_id, perfil_id, atleta_id, nombre, activa)
    values (p_franja, v_perfil, p_atleta, v_nombre, true)
    returning id into v_id;
  end if;

  -- (mig 416) Correo de confirmación: «ya estás en la lista de espera» (Andrés, 21-oct).
  begin
    perform public.cron_llamar_edge('natacion-espera-correo',
      jsonb_build_object('tipo', 'apuntado', 'franja_id', p_franja, 'perfil_ids', jsonb_build_array(v_perfil)), null);
  exception when others then
    raise warning 'natacion_espera_apuntarse: no se pudo pedir el correo: %', sqlerrm;
  end;

  return jsonb_build_object('ok', true, 'id', v_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.natacion_espera_avisar(p_franja uuid, p_fecha date)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_rec    record;
  v_n      integer := 0;
  v_franja text;
  v_cuando text := to_char(p_fecha, 'DD/MM');
  v_ids    uuid[] := '{}';
begin
  select coalesce(nullif(btrim(f.grupo), ''), 'Natación') || ' · ' || to_char(f.hora, 'HH24:MI')
    into v_franja
  from public.natacion_franjas f where f.id = p_franja;
  if v_franja is null then return 0; end if;

  for v_rec in
    select le.id, le.perfil_id
    from public.natacion_lista_espera le
    where le.franja_id = p_franja
      and le.activa
      and le.perfil_id is not null
      and (le.avisado_en is null or le.avisado_en < now() - interval '1 hour')
      -- (mig 446) Solo a quien nada en Máster: es quien puede recuperar con bono.
      and exists (select 1 from public.natacion_inscripciones i
                    join public.atletas a on a.id = i.atleta_id
                   where i.activa and i.tipo = 'Máster' and a.perfil_id = le.perfil_id)
  loop
    perform public.avisos_registrar(
      'Se ha liberado un hueco en natación',
      'Hay sitio en ' || v_franja || ' el ' || v_cuando || '. El primero que reserve se lo queda.',
      'natacion/',
      'persona', 'entrenos',
      null, null, v_rec.perfil_id,
      'Lista de espera', 0, 0, null, null, 'importante', null, true, '{}'
    );
    perform public.avisos_cola_movil_poner('nat_hueco', v_rec.perfil_id);
    update public.natacion_lista_espera set avisado_en = now() where id = v_rec.id;
    v_ids := v_ids || v_rec.perfil_id;
    v_n := v_n + 1;
  end loop;
  -- (mig 415) Además, CORREO a cada uno (Edge natacion-espera-correo): el aviso
  -- de la app y el push no llegan a quien no tiene las notificaciones activadas.
  if v_n > 0 then
    begin
      perform public.cron_llamar_edge('natacion-espera-correo',
        jsonb_build_object('franja_id', p_franja, 'fecha', p_fecha, 'perfil_ids', to_jsonb(v_ids)), null);
    exception when others then
      raise warning 'natacion_espera_avisar: no se pudo pedir el correo: %', sqlerrm;
    end;
  end if;
  return v_n;
end;
$function$;

-- Fuera de la lista quien no nada en Máster (sin avisarles).
update public.natacion_lista_espera le
   set activa = false
 where le.activa
   and not exists (select 1 from public.natacion_inscripciones i
                     join public.atletas a on a.id = i.atleta_id
                    where i.activa and i.tipo = 'Máster' and a.perfil_id = le.perfil_id);

commit;
