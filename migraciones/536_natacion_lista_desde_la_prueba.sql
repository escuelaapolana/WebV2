-- ============================================================
-- 536 · Natación · quien tiene la prueba más adelante no sale antes en la lista
-- ------------------------------------------------------------
-- Andrés (19-nov-2026): «si los metemos antes y a lo mejor tienen prueba dentro de dos
-- semanas, no quiero que estén antes en la lista de asistencia, porque si no aparece como
-- que llevan más semanas de las que realmente están».
--
-- · natacion_inscripciones.desde: primer día que viene. La plaza sigue RESERVADA desde que
--   se le da (cuenta en cupos, semáforo y ocupación), pero en Pasar lista solo sale desde ese
--   día, y la asistencia de su ficha solo cuenta las listas desde entonces.
-- · Al dar la prueba (a mano con «asignar» o sola al llegar el formulario) se pone
--   desde = fecha de la prueba. Si se cambia la fecha de la prueba, cambia también.
-- · Vacío = sale siempre, como hasta ahora (las plazas de antes no cambian).
-- ============================================================
begin;

alter table public.natacion_inscripciones add column if not exists desde date;
comment on column public.natacion_inscripciones.desde is
  'Primer día que viene (la fecha de su prueba). Antes no sale en Pasar lista, aunque la plaza ya esté reservada. Vacío = siempre.';

-- Pone desde = fecha de la prueba en las plazas que se le dieron con esa solicitud.
create or replace function public._nat_sol_poner_desde(p_id uuid)
returns integer
language sql security definer
set search_path = public
as $$
  with u as (
    update public.natacion_inscripciones i
       set desde = s.fecha_prueba, updated_at = now()
      from public.natacion_solicitudes s
     where s.id = p_id and s.estado = 'prueba' and s.fecha_prueba is not null
       and i.activa and i.acceso_id = s.acceso_id and i.franja_id = any(s.franjas)
       and i.created_at >= coalesce(s.alta_en, s.creado_en) - interval '1 minute'
       and i.desde is distinct from s.fecha_prueba
    returning 1)
  select count(*)::int from u;
$$;
revoke all on function public._nat_sol_poner_desde(uuid) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.natacion_solicitud_accion(p_id uuid, p_accion text, p_datos jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  s       public.natacion_solicitudes%rowtype;
  d       jsonb := coalesce(p_datos, '{}'::jsonb);
  v_res   jsonb;
  v_franja uuid;
  v_r     text;
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Solo quien gestiona natación puede llevar las solicitudes.' using errcode = '42501';
  end if;
  select * into s from public.natacion_solicitudes where id = p_id for update;
  if not found then raise exception 'No encuentro esa solicitud.'; end if;

  if p_accion = 'datos' then
    update public.natacion_solicitudes set
      nombre    = case when d ? 'nombre'    then nullif(btrim(d ->> 'nombre'), '')    else nombre end,
      apellidos = case when d ? 'apellidos' then nullif(btrim(d ->> 'apellidos'), '') else apellidos end,
      fecha_nac = case when d ? 'fecha_nac' then nullif(d ->> 'fecha_nac', '')::date  else fecha_nac end,
      tutor     = case when d ? 'tutor'     then nullif(btrim(d ->> 'tutor'), '')     else tutor end,
      email     = case when d ? 'email'     then nullif(lower(btrim(d ->> 'email')), '') else email end,
      telefono  = case when d ? 'telefono'  then nullif(btrim(d ->> 'telefono'), '')  else telefono end,
      nivel     = case when d ? 'nivel'     then nullif(d ->> 'nivel', '')            else nivel end,
      socio     = case when d ? 'socio'     then (d ->> 'socio')::boolean             else socio end,
      nota      = case when d ? 'nota'      then nullif(btrim(d ->> 'nota'), '')      else nota end,
      fecha_prueba = case when d ? 'fecha_prueba' then nullif(d ->> 'fecha_prueba', '')::date else fecha_prueba end,
      actualizado_en = now()
    where id = p_id;
    -- (mig 536) si cambia el día de la prueba, cambia también desde cuándo sale en la lista
    if d ? 'fecha_prueba' then perform public._nat_sol_poner_desde(p_id); end if;

  elsif p_accion = 'asignar' then
    if s.estado not in ('anterior', 'revisar', 'espera', 'sin_hueco', 'no_sigue') then
      raise exception 'Esta solicitud ya tiene grupo.';
    end if;
    v_franja := (d ->> 'franja')::uuid;
    if v_franja is null or nullif(d ->> 'calle', '') is null then raise exception 'Elige franja y calle.'; end if;
    v_res := public.natacion_alta_unificada(
      s.origen, jsonb_build_array(jsonb_build_object('franja', v_franja, 'calle', d ->> 'calle',
                                                     'nivel', coalesce(nullif(d ->> 'nivel', ''), s.nivel))),
      s.atleta_id, s.nombre, s.apellidos, s.fecha_nac, s.dni, s.email, s.telefono, s.tutor,
      coalesce(nullif(d ->> 'nivel', ''), s.nivel), true, null, null, null);
    update public.natacion_solicitudes
       set estado = 'prueba', motivo = null, alta_en = now(), franjas = array[v_franja],
           fecha_prueba = public._nat_proxima_clase(v_franja, current_date + 1),
           nivel = coalesce(nullif(d ->> 'nivel', ''), nivel),
           atleta_id = (v_res ->> 'atleta_id')::uuid, acceso_id = (v_res ->> 'acceso_id')::uuid,
           vino_el = null, falto_el = null, avisado = 'prueba', actualizado_en = now()
     where id = p_id;
    perform public._nat_sol_poner_desde(p_id);   -- (mig 536) en la lista, desde el día de la prueba

  elsif p_accion = 'procesar' then          -- una «anterior» entra en el circuito
    update public.natacion_solicitudes set estado = 'revisar', avisado = 'revisar', actualizado_en = now() where id = p_id;
    v_r := public._nat_sol_procesar(p_id);
    update public.natacion_solicitudes set avisado = estado where id = p_id;

  elsif p_accion = 'espera' then
    update public.natacion_solicitudes
       set estado = 'espera', espera_hasta = current_date + 15, avisado = null, actualizado_en = now() where id = p_id;

  elsif p_accion = 'sin_hueco' then
    update public.natacion_solicitudes set estado = 'sin_hueco', avisado = null, actualizado_en = now() where id = p_id;

  elsif p_accion = 'vino' then
    update public.natacion_solicitudes
       set estado = 'probo', vino_el = coalesce(nullif(d ->> 'fecha', '')::date, current_date), avisado = 'probo',
           actualizado_en = now()
     where id = p_id;

  elsif p_accion = 'se_queda' then
    update public.natacion_solicitudes set estado = 'formaliza', avisado = null, actualizado_en = now() where id = p_id;

  elsif p_accion = 'no_sigue' then
    -- fuera de las franjas que se le dieron para probar; y si no le queda ninguna
    -- otra, baja de natación completa (código, reservas…) como en «Dar de baja»
    update public.natacion_inscripciones set activa = false, updated_at = now()
     where activa and acceso_id = s.acceso_id and s.alta_en is not null
       and created_at >= s.alta_en - interval '1 minute';
    if (s.acceso_id is not null or s.atleta_id is not null) and not exists (
         select 1 from public.natacion_inscripciones i
          where i.activa and (i.acceso_id = s.acceso_id or i.atleta_id = s.atleta_id)) then
      perform public.natacion_dar_baja(s.acceso_id, s.atleta_id);
    end if;
    update public.natacion_solicitudes set estado = 'no_sigue', avisado = 'no_sigue', actualizado_en = now() where id = p_id;

  elsif p_accion = 'descartar' then
    update public.natacion_solicitudes set estado = 'descartada', avisado = 'descartada', actualizado_en = now() where id = p_id;

  elsif p_accion = 'reabrir' then
    update public.natacion_solicitudes
       set estado = 'revisar', motivo = coalesce(motivo, 'Reabierta a mano.'), avisado = 'revisar', actualizado_en = now()
     where id = p_id;

  elsif p_accion = 'msg' then
    update public.natacion_solicitudes set
      msg_prueba_en    = case when d ->> 'que' = 'prueba'    then now() else msg_prueba_en end,
      msg_espera_en    = case when d ->> 'que' = 'espera'    then now() else msg_espera_en end,
      msg_formaliza_en = case when d ->> 'que' = 'formaliza' then now() else msg_formaliza_en end,
      msg_sin_hueco_en = case when d ->> 'que' = 'sin_hueco' then now() else msg_sin_hueco_en end,
      actualizado_en = now()
    where id = p_id;

  else
    raise exception 'Acción desconocida: %', p_accion;
  end if;

  return (select to_jsonb(x) from public.natacion_solicitudes x where x.id = p_id);
end $function$;

CREATE OR REPLACE FUNCTION public._nat_sol_procesar(p_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  s        public.natacion_solicitudes%rowtype;
  v_franja uuid;
  c        record;
  v_plazas jsonb := '[]'::jsonb;
  v_llenas text[] := '{}';
  v_cerrad text[] := '{}';
  v_elegid uuid[] := '{}';
  v_res    jsonb;
  v_ya     text;
  v_ya_at  uuid;
  v_ya_ac  uuid;
  v_dias   text[] := array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  v_prueba date;
begin
  select * into s from public.natacion_solicitudes where id = p_id for update;
  if not found or s.estado <> 'revisar' then return null; end if;

  -- ¿la misma persona ya tiene otra solicitud en marcha? → repetida, lo decide Andrés
  if exists (select 1 from public.natacion_solicitudes o
              where o.id <> s.id and o.origen = s.origen
                and o.estado in ('revisar', 'prueba', 'probo', 'espera', 'formaliza')
                and o.creado_en <= s.creado_en
                and (public._nat_sol_norm(o.nombre || ' ' || coalesce(o.apellidos, '')) = public._nat_sol_norm(s.nombre || ' ' || coalesce(s.apellidos, ''))
                     or (s.dni is not null and o.dni = s.dni))) then
    update public.natacion_solicitudes
       set motivo = 'Repetida: ya hay otra solicitud suya en marcha. Descarta una de las dos.', actualizado_en = now()
     where id = p_id;
    return 'revisar';
  end if;

  -- ¿ya nada en el club? (mismo nombre en una franja activa) → lo decide Andrés
  select string_agg(distinct v_dias[f.dia] || ' ' || to_char(f.hora, 'HH24:MI'), ', '),
         (array_agg(i.atleta_id) filter (where i.atleta_id is not null))[1],
         (array_agg(i.acceso_id) filter (where i.acceso_id is not null))[1]
    into v_ya, v_ya_at, v_ya_ac
    from public.natacion_inscripciones i join public.natacion_franjas f on f.id = i.franja_id
   where i.activa and public._nat_sol_norm(i.nombre) = public._nat_sol_norm(s.nombre || ' ' || coalesce(s.apellidos, ''));
  if v_ya is not null then
    update public.natacion_solicitudes
       set motivo = 'Ya nada en el club (' || v_ya || '). Mira si es un cambio de horario.',
           atleta_id = coalesce(atleta_id, v_ya_at), acceso_id = coalesce(acceso_id, v_ya_ac), actualizado_en = now()
     where id = p_id;
    return 'revisar';
  end if;

  -- (mig 535, 19-nov-2026) Máster de INICIACIÓN: no prueba entre semana (Lorena no quiere
  -- a nadie de iniciación entre semana). Prueba un sábado en Monte Tossal con Mario, sin
  -- competición cerca, y Mario le da el nivel. La fecha la pone a mano quien lleva natación
  -- («asignar» en la franja del sábado 8:30 y luego la fecha de prueba).
  if s.origen = 'Máster' and s.nivel = 'Iniciación' then
    update public.natacion_solicitudes
       set motivo = 'Máster de iniciación: no prueba entre semana. Prueba un sábado en Monte Tossal con Mario (sin competición cerca) y Mario le dice su nivel.',
           actualizado_en = now()
     where id = p_id;
    return 'revisar';
  end if;

  -- no se entiende el horario (o solo una parte): mejor que lo mire Andrés que
  -- apuntarle a medias
  if coalesce(array_length(s.franjas_pedidas, 1), 0) = 0 or s.motivo is not null then
    update public.natacion_solicitudes
       set motivo = coalesce(motivo, 'No entiendo qué horario pide.'), actualizado_en = now() where id = p_id;
    return 'revisar';
  end if;

  -- una calle por franja: de su tipo (o vacía), con hueco, y mejor de su nivel
  foreach v_franja in array s.franjas_pedidas loop
    -- semáforo puesto a mano en Franjas y cupos (rojo = cerrado, ámbar = consultar)
    if exists (select 1 from public.natacion_franjas f where f.id = v_franja and f.semaforo_forzado in ('rojo', 'ambar')) then
      select v_cerrad || (v_dias[f.dia] || ' ' || to_char(f.hora, 'HH24:MI')) into v_cerrad
        from public.natacion_franjas f where f.id = v_franja;
      continue;
    end if;
    select a.calle, a.libres, a.cupo, a.fijos, a.nivel, a.dia, a.hora,
           (select count(*) filter (where i.tipo = s.origen) - count(*) filter (where i.tipo <> s.origen)
              from public.natacion_inscripciones i
             where i.franja_id = v_franja and i.calle = a.calle and i.activa) as afin
      into c
      from public.natacion_alta_franjas(s.origen) a
     where a.franja_id = v_franja
     order by ((select count(*) filter (where i.tipo = s.origen) - count(*) filter (where i.tipo <> s.origen)
                  from public.natacion_inscripciones i
                 where i.franja_id = v_franja and i.calle = a.calle and i.activa) >= 0) desc,
              (a.libres > 0) desc, (a.nivel is not distinct from s.nivel) desc, a.libres desc, a.calle
     limit 1;
    if not found then
      v_llenas := v_llenas || 'una franja que ya no está abierta';
    elsif c.afin < 0 or c.libres <= 0 then
      v_llenas := v_llenas || (v_dias[c.dia] || ' ' || to_char(c.hora, 'HH24:MI')
                              || case when c.afin >= 0 then ' (calle ' || replace(c.calle, 'C', '') || ': '
                                      || c.fijos || ' de ' || c.cupo || ')' else '' end);
    else
      v_plazas := v_plazas || jsonb_build_object('franja', v_franja, 'calle', c.calle, 'nivel', coalesce(s.nivel, c.nivel));
      v_elegid := v_elegid || v_franja;
    end if;
  end loop;

  if array_length(v_llenas, 1) > 0 or array_length(v_cerrad, 1) > 0 then
    update public.natacion_solicitudes
       set motivo = concat_ws(' ',
             case when array_length(v_llenas, 1) > 0 then 'Grupo completo: ' || array_to_string(v_llenas, ', ') || '.' end,
             case when array_length(v_cerrad, 1) > 0 then 'Horario cerrado o «consultar» en Franjas y cupos: '
                                                          || array_to_string(v_cerrad, ', ') || '.' end),
           actualizado_en = now()
     where id = p_id;
    return 'revisar';
  end if;

  begin
    v_res := public.natacion_alta_unificada(
      s.origen, v_plazas, null, s.nombre, s.apellidos, s.fecha_nac, s.dni, s.email, s.telefono, s.tutor,
      s.nivel, false, null, null, null);
  exception when others then
    update public.natacion_solicitudes
       set motivo = 'No he podido darle de alta: ' || sqlerrm, actualizado_en = now() where id = p_id;
    return 'revisar';
  end;

  select min(public._nat_proxima_clase(f, current_date + 1)) into v_prueba from unnest(v_elegid) f;
  update public.natacion_solicitudes
     set estado = 'prueba', motivo = null, alta_en = now(), franjas = v_elegid, fecha_prueba = v_prueba,
         atleta_id = (v_res ->> 'atleta_id')::uuid, acceso_id = (v_res ->> 'acceso_id')::uuid, actualizado_en = now()
   where id = p_id;
  perform public._nat_sol_poner_desde(p_id);   -- (mig 536) en la lista, desde el día de la prueba
  return 'prueba';
end $function$;

-- Las pruebas que ya están puestas para más adelante.
select public._nat_sol_poner_desde(s.id)
  from public.natacion_solicitudes s
 where s.estado = 'prueba' and s.fecha_prueba > (now() at time zone 'Europe/Madrid')::date;

commit;
