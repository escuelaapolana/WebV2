-- ============================================================
-- 535 · Natación · el Máster de iniciación no prueba entre semana
-- ------------------------------------------------------------
-- Regla de Andrés/Lorena (19-nov-2026, «a partir de ahora sí o sí»): quien entra al Máster
-- y se considera de nivel INICIACIÓN no viene a probar entre semana. Viene un SÁBADO a
-- Monte Tossal con Mario, cuando no hay competición cerca y el entrenamiento se dedica a
-- ello, y Mario le da el nivel exacto. Lorena no quiere a nadie de iniciación entre semana.
--
-- La revisión automática de solicitudes (_nat_sol_procesar) ya no le da prueba sola: la
-- deja en «revisar» con ese motivo. Todo lo demás, igual. Quien ya está dentro, igual
-- (Andrés, 19-nov: Bárbara se queda como está).
-- ============================================================
begin;

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
  return 'prueba';
end $function$;

commit;
