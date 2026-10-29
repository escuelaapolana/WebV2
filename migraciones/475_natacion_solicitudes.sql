-- 475 · Natación · solicitudes que llegan de los formularios (escuela y máster)
-- -----------------------------------------------------------------------------
-- (29-oct-2026, Andrés) Un Apps Script en escuelaapolana@gmail.com lee cada mañana
-- los Excel de respuestas de los dos formularios de natación y los manda a la Edge
-- `natacion-form-sync`, que llama a natacion_form_sincronizar():
--   · cada respuesta NUEVA se guarda una sola vez (clave = formulario + marca
--     temporal + nombre) con la fila tal cual (`datos`, título → valor en orden);
--   · si el grupo que pide tiene hueco → alta de PRUEBA (ficha + código + franja)
--     con la MISMA función que «Dar de alta» (natacion_alta_unificada);
--   · si está completo, no se entiende el horario o falta un dato → «por revisar»
--     y Andrés le da grupo desde portal/natacion-solicitudes;
--   · la 1.ª vez que llega un Excel, lo que ya tenía queda como «anterior» (no se
--     toca a nadie que ya estuviera gestionado a mano).
-- Cada día (natacion_solicitudes_revisar) se mira quién vino a su clase de prueba
-- (lista pasada DESPUÉS del alta y sin falta), quién ya tiene cuota (= alta) y
-- quién cumple los 15 días de espera; la Edge avisa a Andrés por correo UNA vez
-- por cosa (columna `avisado`). Los mensajes a las familias los manda Andrés por
-- WhatsApp desde la pantalla; aquí solo se apunta cuándo.
-- Estados: anterior · revisar · prueba · probo · espera · formaliza · alta ·
--          no_sigue · sin_hueco · descartada
-- -----------------------------------------------------------------------------

create table if not exists public.natacion_solicitudes (
  id               uuid primary key default gen_random_uuid(),
  origen           text not null check (origen in ('Escuela', 'Máster')),
  clave            text not null unique,
  fila             integer,
  marca            timestamptz,
  datos            jsonb not null default '[]'::jsonb,
  nombre           text,
  apellidos        text,
  fecha_nac        date,
  dni              text,
  tutor            text,
  email            text,
  telefono         text,
  nivel            text check (nivel is null or nivel in ('Iniciación', 'Desarrollo', 'Perfeccionamiento')),
  socio            boolean,
  pide             text,
  observaciones    text,
  franjas_pedidas  uuid[] not null default '{}',
  estado           text not null default 'revisar' check (estado in
                   ('anterior', 'revisar', 'prueba', 'probo', 'espera', 'formaliza', 'alta', 'no_sigue', 'sin_hueco', 'descartada')),
  motivo           text,
  atleta_id        uuid references public.atletas(id) on delete set null,
  acceso_id        uuid references public.natacion_accesos(id) on delete set null,
  franjas          uuid[] not null default '{}',
  alta_en          timestamptz,
  fecha_prueba     date,
  vino_el          date,
  falto_el         date,
  espera_hasta     date,
  msg_prueba_en    timestamptz,
  msg_espera_en    timestamptz,
  msg_formaliza_en timestamptz,
  msg_sin_hueco_en timestamptz,
  avisado          text,
  nota             text,
  creado_en        timestamptz not null default now(),
  actualizado_en   timestamptz not null default now()
);
create index if not exists natacion_solicitudes_estado on public.natacion_solicitudes (estado);
create index if not exists natacion_solicitudes_atleta on public.natacion_solicitudes (atleta_id);
create index if not exists natacion_solicitudes_acceso on public.natacion_solicitudes (acceso_id);

alter table public.natacion_solicitudes enable row level security;
drop policy if exists "nat solicitudes leer gestor" on public.natacion_solicitudes;
create policy "nat solicitudes leer gestor" on public.natacion_solicitudes
  for select to authenticated using ((select public.soy_gestor_natacion()));
revoke all on public.natacion_solicitudes from anon, authenticated;
grant select on public.natacion_solicitudes to authenticated;
-- (se escribe solo por las funciones de abajo)

-- El proceso automático hace las altas con las funciones de siempre, que piden
-- «quien gestiona natación». Se identifica con apolana.sistema = 'natacion', que
-- SOLO ponen las funciones de este fichero dentro de su propia transacción (no
-- hay ninguna RPC que deje poner un ajuste con nombre elegido desde fuera).
create or replace function public.soy_gestor_natacion()
 returns boolean language sql stable security definer set search_path to 'public'
as $function$
  select coalesce(current_setting('apolana.sistema', true), '') = 'natacion'
      or public.es_admin() or public.es_staff() or exists (
    select 1 from public.responsable_seccion rs
    join public.perfiles p on p.id = rs.perfil_id
    where p.email = (auth.jwt() ->> 'email') and coalesce(p.activo, true)
      and rs.seccion in ('natacion','escuela-natacion') and coalesce(rs.gestor, true)
  );
$function$;

-- ---------------------------------------------------------------- utilidades
create or replace function public._nat_sol_norm(p text) returns text
 language sql stable set search_path to 'public'
as $$ select lower(regexp_replace(btrim(public.unaccent(coalesce(p, ''))), '\s+', ' ', 'g')) $$;

-- Valor de la 1.ª columna cuyo TÍTULO casa con p_si (y no con p_no). Con p_sep,
-- junta todas las que casan, en el orden del Excel.
create or replace function public._nat_sol_campo(p_datos jsonb, p_si text, p_no text default null, p_sep text default null)
 returns text language sql stable set search_path to 'public'
as $$
  select case when p_sep is null then (array_agg(v order by n))[1]
              else nullif(string_agg(v, p_sep order by n), '') end
    from (select n, btrim(x ->> 1) as v, public._nat_sol_norm(x ->> 0) as k
            from jsonb_array_elements(case when jsonb_typeof(p_datos) = 'array' then p_datos else '[]'::jsonb end)
                 with ordinality as t(x, n)) s
   where k ~ p_si and (p_no is null or k !~ p_no) and coalesce(v, '') <> ''
$$;

create or replace function public._nat_sol_fecha(p text) returns date
 language plpgsql stable
as $$
declare t text := btrim(coalesce(p, ''));
begin
  if t ~ '^\d{4}-\d{1,2}-\d{1,2}' then return to_date(substring(t from '^\d{4}-\d{1,2}-\d{1,2}'), 'YYYY-MM-DD'); end if;
  if t ~ '^\d{1,2}[/.-]\d{1,2}[/.-]\d{4}' then
    return to_date(regexp_replace(substring(t from '^\d{1,2}[/.-]\d{1,2}[/.-]\d{4}'), '[.-]', '/', 'g'), 'DD/MM/YYYY');
  end if;
  return null;
exception when others then return null;
end $$;

create or replace function public._nat_sol_nivel(p text) returns text
 language sql stable set search_path to 'public'
as $$
  select case
    when t ~ 'perfecc|avanzad' then 'Perfeccionamiento'
    when t ~ 'desarroll' then 'Desarrollo'
    when t ~ 'inicia|no sabe' then 'Iniciación'
    when t ~ '^(nivel )?3\M' then 'Perfeccionamiento'
    when t ~ '^(nivel )?2\M' then 'Desarrollo'
    when t ~ '^(nivel )?1\M' then 'Iniciación'
  end
  from (select public._nat_sol_norm(p) as t) x
$$;

-- Próxima clase de una franja desde p_desde (incluido), saltando festivos y cierres.
create or replace function public._nat_proxima_clase(p_franja uuid, p_desde date) returns date
 language sql stable set search_path to 'public'
as $$
  select x.d
    from public.natacion_franjas f
    cross join generate_series(0, 8) w
    cross join lateral (select (p_desde + ((f.dia - extract(isodow from p_desde)::int + 7) % 7) + 7 * w)::date as d) x
   where f.id = p_franja
     and not (public.hay_excepcion(x.d, null, 'natacion', null)
              or (public.natacion_franja_seccion(f.grupo, f.admite_master) = 'escuela-natacion'
                  and public.hay_excepcion(x.d, null, 'escuela-natacion', null)))
   order by w limit 1
$$;

-- Qué franjas pide, a partir del texto del formulario («Martes 19:30», «lunes y
-- miércoles 17:30», «Jueves de 18.30 a 19.30»…). Lo que no se entiende va a `duda`.
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
  t := regexp_replace(t, '(\d{1,2})[.h](\d{2})', '\1:\2', 'g');
  t := regexp_replace(t, '(\d{1,2}) ?(h|horas)\M', '\1:00', 'g');
  foreach tok in array regexp_split_to_array(t, '[^a-z0-9:]+') loop
    d := array_position(nombres, tok);
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

-- ------------------------------------------------- alta de prueba si hay hueco
-- Para una solicitud «por revisar»: si se entiende el horario y hay hueco en una
-- calle de su tipo (escuela/máster), la da de alta con natacion_alta_unificada.
-- Si no, deja el motivo para Andrés. Nunca levanta error.
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

-- ------------------------------------------------------- leer las filas del Excel
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

    v_full   := public._nat_sol_campo(v_datos, 'nombre.*apellido|apellido.*nombre', NO_TUTOR);
    v_nombre := public._nat_sol_campo(v_datos, 'nombre', NO_TUTOR || '|apellido|usuario|contacto|club|centro|colegio');
    v_apell  := public._nat_sol_campo(v_datos, 'apellido', NO_TUTOR || '|nombre', ' ');
    if v_nombre is null and v_full is not null then
      v_pal := regexp_split_to_array(btrim(v_full), '\s+');
      if array_length(v_pal, 1) >= 3 then
        v_nombre := array_to_string(v_pal[1:array_length(v_pal, 1) - 2], ' ');
        v_apell  := array_to_string(v_pal[array_length(v_pal, 1) - 1:], ' ');
      else
        v_nombre := v_pal[1]; v_apell := nullif(array_to_string(v_pal[2:], ' '), '');
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
    v_pide := public._nat_sol_campo(v_datos, 'horario|(^|\W)dias?(\W|$)|franja|grupo|turno|(^|\W)hora',
                                    'nacimiento|marca temporal|nivel|socio', ' · ');
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
      case when v_origen = 'Escuela' then public._nat_sol_campo(v_datos, NO_TUTOR, 'correo|mail|telefono|movil|dni|nie|documento|direccion|domicilio|socio', ' ') end,
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

-- Lo que llama la Edge (con la clave de servicio) y comprueba el mismo token que
-- BUENO ISA (Vault 'escuela_sync_token': el script vive en la misma cuenta).
-- p_aplicar = false → lo hace todo y lo deshace (para probar).
create or replace function public.natacion_form_sincronizar(p_token text, p_filas jsonb, p_aplicar boolean default true)
 returns jsonb language plpgsql security definer set search_path to 'public'
as $$
declare
  v_tok text;
  v_res jsonb;
begin
  select decrypted_secret into v_tok from vault.decrypted_secrets where name = 'escuela_sync_token';
  if v_tok is null or p_token is null or p_token <> v_tok then
    raise exception 'token' using errcode = '42501';
  end if;
  if jsonb_typeof(p_filas) <> 'array' then raise exception 'Faltan las filas.'; end if;

  perform set_config('apolana.sistema', 'natacion', true);
  perform set_config('apolana.autor', 'formulario de natación (automático)', true);
  begin
    v_res := public._nat_sol_ingerir(p_filas);
    if not coalesce(p_aplicar, true) then raise exception '__ensayo__'; end if;
  exception when raise_exception then
    if sqlerrm <> '__ensayo__' then raise; end if;
  end;
  perform set_config('apolana.sistema', '', true);
  return v_res || jsonb_build_object('aplicado', coalesce(p_aplicar, true));
end $$;

-- ------------------------------------------------------- repaso diario
-- vino a su prueba / ya no está en ninguna franja / ya tiene cuota
create or replace function public.natacion_solicitudes_revisar() returns jsonb
 language plpgsql security definer set search_path to 'public'
as $$
declare
  s       record;
  v_vino  date;
  v_falto date;
  n_vino  int := 0;
  n_alta  int := 0;
  n_fuera int := 0;
begin
  for s in select * from public.natacion_solicitudes
            where estado in ('prueba', 'probo', 'formaliza') and acceso_id is not null loop
    -- ya tiene cuota de natación hecha después del alta → alta (fin del circuito)
    if s.atleta_id is not null and exists (
         select 1 from public.cuotas_entreno c
          where c.atleta_id = s.atleta_id and c.origen = 'natacion'
            and c.created_at >= coalesce(s.alta_en, s.creado_en)) then
      update public.natacion_solicitudes set estado = 'alta', avisado = 'alta', actualizado_en = now() where id = s.id;
      n_alta := n_alta + 1; continue;
    end if;
    -- ya no está en ninguna franja (lo quitaron a mano) → no sigue
    if not exists (select 1 from public.natacion_inscripciones i where i.acceso_id = s.acceso_id and i.activa) then
      update public.natacion_solicitudes
         set estado = 'no_sigue', motivo = 'Ya no está en ninguna franja.', avisado = 'no_sigue', actualizado_en = now()
       where id = s.id;
      n_fuera := n_fuera + 1; continue;
    end if;
    if s.estado <> 'prueba' then continue; end if;
    -- vino: lista de su franja pasada DESPUÉS del alta y sin falta suya
    select min(l.fecha) into v_vino
      from public.natacion_lista l
     where l.franja_id in (select i.franja_id from public.natacion_inscripciones i where i.acceso_id = s.acceso_id and i.activa)
       and l.pasada_en > coalesce(s.alta_en, s.creado_en)
       and not exists (select 1 from public.natacion_ausencias a
                        where a.acceso_id = s.acceso_id and a.franja_id = l.franja_id and a.fecha = l.fecha);
    if v_vino is not null then
      update public.natacion_solicitudes set estado = 'probo', vino_el = v_vino, actualizado_en = now() where id = s.id;
      n_vino := n_vino + 1;
    else
      select max(a.fecha) into v_falto
        from public.natacion_ausencias a
        join public.natacion_lista l on l.franja_id = a.franja_id and l.fecha = a.fecha
       where a.acceso_id = s.acceso_id and l.pasada_en > coalesce(s.alta_en, s.creado_en);
      if v_falto is distinct from s.falto_el then
        update public.natacion_solicitudes set falto_el = v_falto, actualizado_en = now() where id = s.id;
      end if;
    end if;
  end loop;
  return jsonb_build_object('vinieron', n_vino, 'con_cuota', n_alta, 'fuera', n_fuera);
end $$;

-- Qué hay que contarle a Andrés (una vez por cosa): nuevas de prueba, por revisar,
-- vinieron a la prueba y cumplen los 15 días de espera.
create or replace function public.natacion_solicitudes_avisos() returns jsonb
 language sql stable security definer set search_path to 'public'
as $$
  with x as (
    select s.*,
           case when s.estado in ('revisar', 'prueba', 'probo') then s.estado
                when s.estado = 'espera' and s.espera_hasta <= current_date then 'plazo' end as k
      from public.natacion_solicitudes s
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id, 'que', x.k, 'origen', x.origen,
           'nombre', btrim(x.nombre || ' ' || coalesce(x.apellidos, '')),
           'nacimiento', x.fecha_nac, 'pide', x.pide, 'motivo', x.motivo,
           'fecha_prueba', x.fecha_prueba, 'vino_el', x.vino_el, 'espera_hasta', x.espera_hasta,
           'franjas', (select string_agg((array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'])[f.dia]
                                         || ' ' || to_char(f.hora, 'HH24:MI'), ', ' order by f.dia, f.hora)
                         from unnest(x.franjas) u join public.natacion_franjas f on f.id = u))
           order by x.k, x.creado_en), '[]'::jsonb)
    from x
   where x.k is not null and x.k is distinct from x.avisado
$$;

create or replace function public.natacion_solicitudes_marcar_avisadas(p_items jsonb) returns integer
 language plpgsql security definer set search_path to 'public'
as $$
declare n int;
begin
  update public.natacion_solicitudes s set avisado = i ->> 'que'
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) i
   where s.id = (i ->> 'id')::uuid;
  get diagnostics n = row_count;
  return n;
end $$;

-- ------------------------------------------------------- lo que hace la pantalla
create or replace function public.natacion_solicitud_accion(p_id uuid, p_accion text, p_datos jsonb default '{}'::jsonb)
 returns jsonb language plpgsql security definer set search_path to 'public'
as $$
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
end $$;

-- ------------------------------------------------------- permisos
revoke all on function public._nat_sol_norm(text) from public, anon;
revoke all on function public._nat_sol_campo(jsonb, text, text, text) from public, anon, authenticated;
revoke all on function public._nat_sol_fecha(text) from public, anon, authenticated;
revoke all on function public._nat_sol_nivel(text) from public, anon, authenticated;
revoke all on function public._nat_sol_franjas(text, text) from public, anon, authenticated;
revoke all on function public._nat_sol_procesar(uuid) from public, anon, authenticated;
revoke all on function public._nat_sol_ingerir(jsonb) from public, anon, authenticated;
revoke all on function public.natacion_form_sincronizar(text, jsonb, boolean) from public, anon, authenticated;
revoke all on function public.natacion_solicitudes_revisar() from public, anon, authenticated;
revoke all on function public.natacion_solicitudes_avisos() from public, anon, authenticated;
revoke all on function public.natacion_solicitudes_marcar_avisadas(jsonb) from public, anon, authenticated;
grant execute on function public.natacion_form_sincronizar(text, jsonb, boolean) to service_role;
grant execute on function public.natacion_solicitudes_revisar() to service_role;
grant execute on function public.natacion_solicitudes_avisos() to service_role;
grant execute on function public.natacion_solicitudes_marcar_avisadas(jsonb) to service_role;
revoke all on function public._nat_proxima_clase(uuid, date) from public, anon;
grant execute on function public._nat_proxima_clase(uuid, date) to authenticated;
revoke all on function public.natacion_solicitud_accion(uuid, text, jsonb) from public, anon;
grant execute on function public.natacion_solicitud_accion(uuid, text, jsonb) to authenticated;

-- Repaso diario aunque el script de Google no llegue (9:30 Madrid): mira quién
-- vino a su prueba y avisa a Andrés de lo pendiente (si no hay nada, no hay correo).
select cron.unschedule('apolana-natacion-solicitudes')
 where exists (select 1 from cron.job where jobname = 'apolana-natacion-solicitudes');
select cron.schedule('apolana-natacion-solicitudes', '30 7,8 * * *',
  $c$ select public.cron_llamar_edge('natacion-form-sync', '{"cron": true}'::jsonb, 9) $c$);
