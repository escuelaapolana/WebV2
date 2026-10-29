-- 476 · Natación · solicitudes: lectura ajustada a los Excel REALES de Mario
-- -----------------------------------------------------------------------------
-- (29-oct-2026) Vistos los dos formularios («Escuela Natación Apol*Ana 2026-27» y
-- «Master Natación Apol*Ana 2026-27»):
--   · el horario de este curso va en «Inscripción VÍA PARQUE DE OCTUBRE'26 A
--     JUNIO'27» y se escribe «MARTES de 19:30 a 21:00 horas (…), JUEVES …»,
--     «SÁBADOS de 08:30 …» o «No estoy interesada/o en asistir…»;
--   · niveles «Nivel 1 – Iniciación básica · 2 – Iniciación avanzada ·
--     3 – Desarrollo · 4 – Perfeccionamiento» (la 475 leía «avanzada» como
--     perfeccionamiento y «19:30 horas» como «19:30:00»);
--   · a veces el nombre completo va en los dos campos;
--   · una persona puede rellenarlo dos veces → «repetida» a revisar.
-- -----------------------------------------------------------------------------

create or replace function public._nat_sol_nivel(p text) returns text
 language sql stable set search_path to 'public'
as $$
  -- Formularios de Mario: «Nivel 1 – Iniciación básica», «Nivel 2 – Iniciación
  -- avanzada», «Nivel 3 – Desarrollo», «Nivel 4 – Perfeccionamiento».
  select case
    when t ~ 'perfecc' then 'Perfeccionamiento'
    when t ~ 'desarroll' then 'Desarrollo'
    when t ~ 'inicia|no sabe' then 'Iniciación'
    when t ~ '^(nivel )?[45]\M' then 'Perfeccionamiento'
    when t ~ '^(nivel )?3\M' then 'Desarrollo'
    when t ~ '^(nivel )?[12]\M' then 'Iniciación'
  end
  from (select public._nat_sol_norm(p) as t) x
$$;

create or replace function public._nat_sol_franjas(p_pide text, p_tipo text, out franjas uuid[], out duda text)
 language plpgsql stable set search_path to 'public'
as $$
declare
  t       text := public._nat_sol_norm(p_pide);
  nombres text[] := array['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
  bonito  text[] := array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  tok     text;
  d       int;
  dias    int[] := '{}';
  pares   text[] := '{}';
  par     text;
  vio_dia boolean := false;
  ult_h   boolean := false;
  v_ids   uuid[];
  v_n     int;
  v_lab   text;
begin
  franjas := '{}';
  if t = '' then duda := 'No dice qué día ni a qué hora quiere venir.'; return; end if;
  if t ~ 'no estoy interesad' and t !~ '\d{1,2}[:.h]\d{2}' then
    duda := 'Dice que no le interesa este curso: «' || btrim(p_pide) || '».'; return;
  end if;
  t := regexp_replace(t, '(\d{1,2})[.h](\d{2})', '\1:\2', 'g');
  t := regexp_replace(t, '(^|[^:\d])(\d{1,2}) ?(h|horas)\M', '\1\2:00', 'g');   -- «a las 19 h» (no «19:30 horas»)
  foreach tok in array regexp_split_to_array(t, '[^a-z0-9:]+') loop
    d := array_position(nombres, regexp_replace(tok, '(sabado|domingo)s$', '\1'));
    if d is not null then dias := dias || d; vio_dia := true; ult_h := false; continue; end if;
    if tok ~ '^\d{1,2}:\d{2}$' then
      if array_length(dias, 1) is not null then
        foreach d in array dias loop pares := pares || (d::text || '|' || tok); end loop;
        dias := '{}';
      elsif not vio_dia and not ult_h then
        pares := pares || ('0|' || tok);         -- solo la hora
      end if;                                    -- («de 19:30 a 20:30»: la 2.ª hora no cuenta)
      ult_h := true;
    end if;
  end loop;
  foreach d in array dias loop pares := pares || (d::text || '|'); end loop;   -- días sin hora
  if array_length(pares, 1) is null then
    duda := 'No entiendo qué horario pide: «' || btrim(p_pide) || '».'; return;
  end if;

  foreach par in array pares loop
    select array_agg(f.id order by f.hora) into v_ids
      from public.natacion_franjas f
     where coalesce(f.activa, true)
       and case when p_tipo = 'Máster' then public.natacion_es_master(f.grupo, f.admite_master)
                else public.natacion_es_escuela(f.grupo) end
       and (split_part(par, '|', 1) = '0' or f.dia = split_part(par, '|', 1)::int)
       and (split_part(par, '|', 2) = '' or f.hora = split_part(par, '|', 2)::time);
    v_n := coalesce(array_length(v_ids, 1), 0);
    v_lab := btrim(case when split_part(par, '|', 1) = '0' then '' else bonito[split_part(par, '|', 1)::int] end
                   || ' ' || split_part(par, '|', 2));
    if v_n = 1 then
      if not (v_ids[1] = any(franjas)) then franjas := franjas || v_ids[1]; end if;
    elsif v_n = 0 then
      duda := concat_ws(' ', duda, 'No hay franja de ' || case when p_tipo = 'Máster' then 'máster' else 'escuela' end
                                   || ' el ' || v_lab || '.');
    else
      duda := concat_ws(' ', duda, 'El ' || v_lab || ' hay varias horas: elige cuál.');
    end if;
  end loop;
end $$;

create or replace function public._nat_sol_procesar(p_id uuid) returns text
 language plpgsql security definer set search_path to 'public'
as $$
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
end $$;

create or replace function public._nat_sol_ingerir(p_filas jsonb) returns jsonb
 language plpgsql security definer set search_path to 'public'
as $$
declare
  f         jsonb;
  v_origen  text;
  v_datos   jsonb;
  v_marca   text;
  v_nombre  text;
  v_apell   text;
  v_full    text;
  v_pal     text[];
  v_dni     text;
  v_socio   text;
  v_pide    text;
  v_fr      record;
  v_clave   text;
  v_id      uuid;
  v_estado  text;
  v_primera jsonb := '{}'::jsonb;
  v_leidas  int := 0;
  v_ya      int := 0;
  v_ant     int := 0;
  v_prueba  jsonb := '[]'::jsonb;
  v_revisar jsonb := '[]'::jsonb;
  NO_TUTOR  constant text := '(padre|madre|tutor|responsable|progenitor)';
begin
  -- la 1.ª vez que llega cada formulario, lo que ya había queda como «anterior»
  v_primera := jsonb_build_object(
    'Escuela', not exists (select 1 from public.natacion_solicitudes where origen = 'Escuela'),
    'Máster',  not exists (select 1 from public.natacion_solicitudes where origen = 'Máster'));

  for f in select * from jsonb_array_elements(coalesce(p_filas, '[]'::jsonb)) loop
    v_origen := case when public._nat_sol_norm(f ->> 'origen') ~ 'master' then 'Máster' else 'Escuela' end;
    v_datos  := case when jsonb_typeof(f -> 'datos') = 'array' then f -> 'datos' else '[]'::jsonb end;

    v_full   := public._nat_sol_campo(v_datos, 'nombre.*apellido|apellido.*nombre', NO_TUTOR || '|titular|cuenta|banc');
    v_nombre := public._nat_sol_campo(v_datos, 'nombre', NO_TUTOR || '|apellido|usuario|contacto|club|centro|colegio|entidad|banc|titular|cuenta');
    v_apell  := public._nat_sol_campo(v_datos, 'apellido', NO_TUTOR || '|nombre|titular|cuenta', ' ');
    if v_nombre is null and v_full is not null then
      v_pal := regexp_split_to_array(btrim(v_full), '\s+');
      if array_length(v_pal, 1) >= 3 then
        v_nombre := array_to_string(v_pal[1:array_length(v_pal, 1) - 2], ' ');
        v_apell  := array_to_string(v_pal[array_length(v_pal, 1) - 1:], ' ');
      else
        v_nombre := v_pal[1]; v_apell := nullif(array_to_string(v_pal[2:], ' '), '');
      end if;
    end if;
    -- a veces escriben el nombre completo en los dos campos («NOAH IVARS IGLESIAS» y «NOAH IVARS IGLESIAS»)
    if v_nombre is not null and v_apell is not null
       and public._nat_sol_norm(v_apell) like public._nat_sol_norm(v_nombre) || ' %' then
      v_apell := btrim(substr(btrim(v_apell), length(btrim(v_nombre)) + 1));
    elsif v_nombre is not null and v_apell is not null and public._nat_sol_norm(v_apell) = public._nat_sol_norm(v_nombre) then
      v_pal := regexp_split_to_array(btrim(v_nombre), '\s+');
      if array_length(v_pal, 1) >= 3 then
        v_nombre := array_to_string(v_pal[1:array_length(v_pal, 1) - 2], ' ');
        v_apell  := array_to_string(v_pal[array_length(v_pal, 1) - 1:], ' ');
      end if;
    end if;
    if coalesce(v_nombre, '') = '' and coalesce(v_apell, '') = '' then continue; end if;
    v_leidas := v_leidas + 1;

    v_marca := public._nat_sol_campo(v_datos, '^marca temporal|^timestamp');
    v_clave := v_origen || '|' || coalesce(v_marca, 'fila ' || coalesce(f ->> 'fila', '?')) || '|'
               || public._nat_sol_norm(v_nombre || ' ' || coalesce(v_apell, ''));
    if exists (select 1 from public.natacion_solicitudes where clave = v_clave) then
      v_ya := v_ya + 1; continue;
    end if;

    v_dni := upper(regexp_replace(coalesce(public._nat_sol_campo(v_datos, '(^|\W)(dni|nie)(\W|$)|documento', NO_TUTOR), ''), '[\s.-]', '', 'g'));
    if v_dni !~ '^[0-9XYZ][0-9]{7}[A-Z]$' then v_dni := null; end if;
    v_socio := public._nat_sol_norm(public._nat_sol_campo(v_datos, '(^|\W)socio'));
    -- lo que pide para ESTE curso: la columna de la temporada (los formularios de Mario
    -- tienen una por periodo: «Inscripción VÍA PARQUE DE OCTUBRE'26 A JUNIO'27»,
    -- «… TOSSAL JULIO …», «… TOSSAL SEPTIEMBRE …»); si no hay, cualquier «horario».
    v_pide := coalesce(
      public._nat_sol_campo(v_datos,
        case when extract(month from current_date) = 7 then 'inscripcion.*julio'
             when extract(month from current_date) in (8, 9) then 'inscripcion.*septiembre'
             else 'inscripcion.*via parque|via parque' end),
      public._nat_sol_campo(v_datos, 'horario|(^|\W)dias?(\W|$)|franja|grupo|turno|(^|\W)hora',
                            'nacimiento|marca temporal|nivel|socio|inscripcion|concejal|conceji', ' · '));
    select * into v_fr from public._nat_sol_franjas(v_pide, v_origen);
    v_estado := case when (v_primera ->> v_origen)::boolean then 'anterior' else 'revisar' end;

    insert into public.natacion_solicitudes
      (origen, clave, fila, marca, datos, nombre, apellidos, fecha_nac, dni, tutor, email, telefono,
       nivel, socio, pide, observaciones, franjas_pedidas, estado, motivo, avisado)
    values (
      v_origen, v_clave, nullif(f ->> 'fila', '')::int,
      case when v_marca ~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$' then (v_marca::timestamp at time zone 'Europe/Madrid') end,
      v_datos, btrim(v_nombre), nullif(btrim(coalesce(v_apell, '')), ''),
      public._nat_sol_fecha(public._nat_sol_campo(v_datos, 'nacimiento', NO_TUTOR)),
      v_dni,
      case when v_origen = 'Escuela' then public._nat_sol_campo(v_datos, NO_TUTOR, 'correo|mail|telefono|movil|dni|nie|documento|pasaporte|direccion|domicilio|socio|inscribir|titular|cuenta') end,
      lower(public._nat_sol_campo(v_datos, 'correo|e-?mail')),
      public._nat_sol_campo(v_datos, 'telefono|movil|whatsapp'),
      public._nat_sol_nivel(public._nat_sol_campo(v_datos, 'nivel')),
      case when v_socio ~ '^si\M' then true when v_socio ~ '^no\M' then false end,
      v_pide,
      public._nat_sol_campo(v_datos, 'observ|coment|algo mas|lesion|alergi|enfermedad|indica', 'marca temporal', ' · '),
      coalesce(v_fr.franjas, '{}'), v_estado, v_fr.duda,
      case when v_estado = 'anterior' then 'anterior' end)
    returning id into v_id;

    if v_estado = 'anterior' then
      v_ant := v_ant + 1;
    elsif public._nat_sol_procesar(v_id) = 'prueba' then
      v_prueba := v_prueba || (select jsonb_build_object('nombre', nombre || ' ' || coalesce(apellidos, ''), 'origen', origen)
                                 from public.natacion_solicitudes where id = v_id);
    else
      v_revisar := v_revisar || (select jsonb_build_object('nombre', nombre || ' ' || coalesce(apellidos, ''), 'origen', origen, 'motivo', motivo)
                                   from public.natacion_solicitudes where id = v_id);
    end if;
  end loop;

  return jsonb_build_object('leidas', v_leidas, 'ya_estaban', v_ya, 'anteriores', v_ant,
                            'prueba', v_prueba, 'revisar', v_revisar);
end $$;
