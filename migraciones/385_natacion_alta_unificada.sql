-- ============================================================
-- 385 · Natación: UN solo «Dar de alta» (asistente de Mario)
-- ------------------------------------------------------------
-- Pantalla nueva portal/natacion-alta/ (asistente en 5 pasos). Hasta
-- ahora el alta estaba repartida en varios «+ Nuevo nadador» y se
-- elegía UNA calle para todas las franjas, sin ver los huecos. Ahora:
--   1) Escuela o Máster   2) ¿ya está en el club?   3) datos
--   4) franjas (1-3) con su calle, viendo nivel y HUECOS de cada calle
--   5) resumen → alta + correo a la familia / nadador.
--
-- Funciones nuevas (todas con gate soy_gestor_natacion(), SECURITY
-- DEFINER, GRANT solo a authenticated):
--   natacion_alta_franjas(tipo)        → franjas del tipo, por calle: cupo,
--                                        ocupados y huecos del PRÓXIMO día
--                                        de clase (regla única de la 330,
--                                        natacion_ocupacion) + nivel habitual.
--   natacion_alta_ficha_faltan(atleta) → qué datos le FALTAN a una ficha que
--                                        ya existe (solo sí/no: nada de datos).
--   natacion_alta_unificada(...)       → todo en UNA transacción: ficha
--                                        (crea o completa huecos), código,
--                                        una inscripción por franja con SU
--                                        calle y nivel, y deja lista la
--                                        invitación si no tiene cuenta.
--                                        Calle llena → se para con aviso
--                                        salvo que se confirme. Guarda la
--                                        CUOTA en la ficha (cuota_importe,
--                                        cuota_periodicidad, cuota_nota).
--   natacion_alta_cuota(tipo, atleta)  → tarifas de natación (tabla `tarifas`)
--                                        por nº de días + si la ficha es socia,
--                                        para que el asistente calcule la cuota.
--
-- TARIFAS que se leen (activas y vigentes hoy):
--   Escuela → seccion = 'escuela-natacion'; Máster → seccion = 'natacion'.
--   El nº de días sale del número al principio de `dias` («1 día», «2 días»,
--   «3 días»). Socio → importe_socio; no socio → importe_no_socio (si está
--   vacío, el de socio: «precio único», como la escuela hoy).
--   Hoy: escuela-natacion-1/2/3 (35/45/55, sin precio no socio) y
--        natacion-bono-4/8/12 (35/45/55 socio · 50/60/70 no socio).
--   Socio = tipo_membresia 'socio' o con numero_socio (la regla del panel).
-- No crea cobros ni suscripciones: solo deja la cuota apuntada en la ficha.
-- Reutiliza natacion_crear_nadador (ficha nueva/dedupe por DNI o
-- nombre+nacimiento) y natacion_alta_desde_ficha (ficha existente:
-- código, reactivar, correo, token) llamándolas SIN franjas; las
-- inscripciones las pone esta función, cada una con su calle.
-- El correo lo sigue mandando el navegador (familia-invitar /
-- correo-natacion-horarios), como en la 350: no hay Edge nueva.
-- No toca datos existentes.
-- ============================================================

-- ---------- 1 · franjas + calles con huecos para el asistente ----------
create or replace function public.natacion_alta_franjas(p_tipo text)
returns table(
  franja_id uuid, dia smallint, hora time without time zone, grupo text,
  fecha date, cancelado boolean,
  calle text, cupo integer, fijos integer, ocupados integer, huecos integer,
  libres integer, nivel text)
language plpgsql stable security definer
set search_path to 'public'
as $$
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Solo quien gestiona natación puede dar altas.' using errcode = '42501';
  end if;
  return query
  with fr as (
    select f.id, f.dia, f.hora, f.grupo,
           public.natacion_franja_seccion(f.grupo, f.admite_master) as secc
      from public.natacion_franjas f
     where coalesce(f.activa, true)
       and case when p_tipo = 'Máster' then public.natacion_es_master(f.grupo, f.admite_master)
                else public.natacion_es_escuela(f.grupo) end
  ),
  -- el próximo día de clase de cada franja (hoy incluido) que no esté cancelado;
  -- si las 6 próximas semanas están cerradas, la primera.
  fe as (
    select fr.*,
           coalesce(
             (select x.d from generate_series(0, 5) w,
                     lateral (select (current_date
                                      + ((fr.dia - extract(isodow from current_date)::int + 7) % 7)
                                      + 7 * w)::date as d) x
               where not (public.hay_excepcion(x.d, null, 'natacion', null)
                          or (fr.secc = 'escuela-natacion'
                              and public.hay_excepcion(x.d, null, 'escuela-natacion', null)))
               order by w limit 1),
             (current_date + ((fr.dia - extract(isodow from current_date)::int + 7) % 7))::date
           ) as fecha
      from fr
  )
  select fe.id, fe.dia, fe.hora, fe.grupo, fe.fecha, o.cancelado,
         o.calle, o.cupo, o.fijos, o.ocupados, o.huecos,
         -- lo que de verdad queda para una plaza FIJA: ni más que los huecos de
         -- ese día ni más que el cupo menos los fijos (una falta suelta no
         -- libera la plaza de siempre)
         least(o.huecos, o.cupo - o.fijos)::int,
         -- nivel de la calle = el que más se repite entre sus inscritos; en empate
         -- (o calle vacía) el de siempre: Vaso/C1 iniciación, C2 desarrollo, C3 perf.
         coalesce(
           (select i.nivel
              from public.natacion_inscripciones i
             where i.franja_id = fe.id and i.calle = o.calle and i.activa and i.nivel is not null
             group by i.nivel
             order by count(*) desc, (i.nivel = nd.nivel) desc, i.nivel
             limit 1),
           nd.nivel)
    from fe
    cross join lateral public.natacion_ocupacion(fe.fecha, fe.id) o
    cross join lateral (select case when o.calle ilike 'vaso' or o.calle = 'C1' then 'Iniciación'
                                    when o.calle = 'C2' then 'Desarrollo'
                                    else 'Perfeccionamiento' end as nivel) nd
   where o.en_cupos
   order by fe.dia, fe.hora, public._num_calle(o.calle) nulls first, o.calle;
end $$;

revoke all on function public.natacion_alta_franjas(text) from public, anon;
grant execute on function public.natacion_alta_franjas(text) to authenticated;

-- ---------- 2 · ¿qué le falta a una ficha que ya existe? ----------
-- Solo sí/no (nada de DNI, teléfonos ni correos): el asistente pide
-- únicamente lo que falta.
create or replace function public.natacion_alta_ficha_faltan(p_atleta uuid)
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $$
declare v_a public.atletas%rowtype;
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Solo quien gestiona natación puede dar altas.' using errcode = '42501';
  end if;
  select * into v_a from public.atletas where id = p_atleta and anonimizado_en is null;
  if not found then
    raise exception 'No encuentro esa ficha. Búscala otra vez o da de alta a la persona como nueva.';
  end if;
  return jsonb_build_object(
    'apellidos',        nullif(btrim(coalesce(v_a.apellidos, '')), '') is null,
    'fecha_nacimiento', v_a.fecha_nacimiento is null,
    'dni',              nullif(btrim(coalesce(v_a.dni, '')), '') is null,
    'email',            nullif(btrim(coalesce(v_a.email, '')), '') is null,
    'telefono',         nullif(btrim(coalesce(v_a.telefono, '')), '') is null,
    'nombre_tutor',     nullif(btrim(coalesce(v_a.nombre_tutor, '')), '') is null,
    'email_tutor',      nullif(btrim(coalesce(v_a.email_tutor, '')), '') is null,
    'telefono_tutor',   nullif(btrim(coalesce(v_a.telefono_tutor, '')), '') is null,
    'de_baja',          v_a.estado = 'baja'
  );
end $$;

revoke all on function public.natacion_alta_ficha_faltan(uuid) from public, anon;
grant execute on function public.natacion_alta_ficha_faltan(uuid) to authenticated;

-- ---------- 3 · el alta entera, en una transacción ----------
-- p_plazas = [{"franja":"<uuid>","calle":"C1","nivel":"Iniciación"}, …]
-- p_confirmar_llenas = true → se mete aunque la calle esté sin hueco
-- (como natacion_incorporar_manual: no bloquea, avisa).
create or replace function public.natacion_alta_unificada(
  p_tipo             text,
  p_plazas           jsonb,
  p_atleta           uuid    default null,
  p_nombre           text    default null,
  p_apellidos        text    default null,
  p_fecha_nac        date    default null,
  p_dni              text    default null,
  p_email            text    default null,
  p_telefono         text    default null,
  p_nombre_tutor     text    default null,
  p_nivel            text    default null,
  p_confirmar_llenas boolean default false,
  p_cuota_importe    numeric default null,
  p_cuota_periodicidad text  default 'mensual',
  p_cuota_nota       text    default null
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_tipo    text;
  v_email   text := lower(btrim(coalesce(p_email, '')));
  v_tel     text := nullif(btrim(coalesce(p_telefono, '')), '');
  v_dni     text := nullif(upper(regexp_replace(coalesce(p_dni, ''), '[\s.-]', '', 'g')), '');
  v_res     jsonb;
  v_atleta  uuid;
  v_acceso  uuid;
  v_nommay  text;
  v_p       jsonb;
  v_franja  uuid;
  v_calle   text;
  v_nivel   text;
  v_f       public.natacion_franjas%rowtype;
  v_libres  int;
  v_lab     text;
  v_llenas  text[] := '{}';
  v_vistas  uuid[] := '{}';
  v_hechas  jsonb := '[]'::jsonb;
  v_ya      jsonb := '[]'::jsonb;
  v_sobre   jsonb := '[]'::jsonb;
  v_dias    text[] := array['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  v_mail_re text := '^[^@\s]+@[^@\s]+\.[^@\s]+$';
  v_cuota_ok boolean := null;
  v_cuota_msg text := null;
  v_cuota_prev numeric;
  v_nota_prev text;
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Solo quien gestiona natación puede dar altas.' using errcode = '42501';
  end if;
  if p_tipo not in ('Escuela', 'Máster') then
    raise exception 'Falta elegir si es de la escuela o adulto/máster.';
  end if;
  v_tipo := p_tipo;
  if p_nivel is not null and p_nivel not in ('Iniciación', 'Desarrollo', 'Perfeccionamiento') then
    raise exception 'Nivel no válido: %', p_nivel;
  end if;
  if jsonb_typeof(coalesce(p_plazas, 'null'::jsonb)) <> 'array' or jsonb_array_length(p_plazas) = 0 then
    raise exception 'Falta elegir al menos un día (franja) y su calle.';
  end if;
  if jsonb_array_length(p_plazas) > 7 then
    raise exception 'Demasiadas franjas a la vez (máximo 7).';
  end if;
  if v_email <> '' and v_email !~ v_mail_re then
    raise exception 'Ese correo no parece válido: %', v_email;
  end if;
  if p_cuota_importe is not null and (p_cuota_importe < 0 or p_cuota_importe > 2000) then
    raise exception 'La cuota no parece correcta: % €.', p_cuota_importe;
  end if;
  if coalesce(p_cuota_periodicidad, 'mensual') not in ('mensual', 'trimestral', 'temporada', 'anual') then
    raise exception 'La periodicidad de la cuota no es válida.';
  end if;
  if v_dni is not null and v_dni !~ '^[0-9XYZ][0-9]{7}[A-Z]$' then
    raise exception 'Ese DNI/NIE no parece válido: % (8 números y una letra; NIE con X/Y/Z delante).', v_dni;
  end if;

  -- ---- comprobar TODAS las plazas antes de tocar nada ----
  for v_p in select * from jsonb_array_elements(p_plazas) loop
    begin
      v_franja := (v_p ->> 'franja')::uuid;
    exception when others then
      raise exception 'Hay una franja que no reconozco. Recarga la página y vuelve a elegir.';
    end;
    v_calle := nullif(btrim(coalesce(v_p ->> 'calle', '')), '');
    v_nivel := coalesce(nullif(btrim(coalesce(v_p ->> 'nivel', '')), ''), p_nivel);
    select * into v_f from public.natacion_franjas where id = v_franja;
    if not found or not coalesce(v_f.activa, true) then
      raise exception 'Una de las franjas ya no existe o está cerrada. Recarga la página y vuelve a elegir.';
    end if;
    if v_franja = any(v_vistas) then
      raise exception 'La franja del % a las % está elegida dos veces.', v_dias[v_f.dia], to_char(v_f.hora, 'HH24:MI');
    end if;
    v_vistas := v_vistas || v_franja;
    if (v_tipo = 'Máster' and not public.natacion_es_master(v_f.grupo, v_f.admite_master))
       or (v_tipo = 'Escuela' and not public.natacion_es_escuela(v_f.grupo)) then
      raise exception 'La franja del % a las % no es de %.', v_dias[v_f.dia], to_char(v_f.hora, 'HH24:MI'),
        case when v_tipo = 'Máster' then 'adultos/máster' else 'la escuela' end;
    end if;
    if v_calle is null then
      raise exception 'Falta elegir la calle del % a las %.', v_dias[v_f.dia], to_char(v_f.hora, 'HH24:MI');
    end if;
    if not (coalesce(v_f.cupos, '{}'::jsonb) ? v_calle) then
      raise exception 'La calle % no existe en la franja del % a las %.', v_calle, v_dias[v_f.dia], to_char(v_f.hora, 'HH24:MI');
    end if;
    if v_nivel is not null and v_nivel not in ('Iniciación', 'Desarrollo', 'Perfeccionamiento') then
      raise exception 'Nivel no válido: %', v_nivel;
    end if;
  end loop;

  -- ---- la ficha ----
  if p_atleta is not null then
    -- YA existe: código, reactivar si estaba de baja, correo si faltaba, token
    v_res := public.natacion_alta_desde_ficha(p_atleta, '{}'::uuid[], p_nivel, null, v_tipo,
                                              nullif(v_email, ''), '{}'::uuid[]);
    v_atleta := p_atleta;
    if nullif(v_res ->> 'email_tutor', '') is null then
      raise exception '%', case when v_tipo = 'Máster'
        then 'Falta el correo del nadador: su ficha no tiene y es por donde le llega el acceso.'
        else 'Falta el correo del tutor: la ficha no tiene y es por donde le llega el acceso a la familia.' end;
    end if;
    -- completar SOLO los huecos (nunca pisa lo que ya hay)
    perform set_config('apolana.via_natacion', '1', true);
    update public.atletas set
      apellidos        = coalesce(nullif(btrim(coalesce(apellidos, '')), ''), nullif(btrim(coalesce(p_apellidos, '')), '')),
      fecha_nacimiento = coalesce(fecha_nacimiento, p_fecha_nac),
      dni              = coalesce(nullif(btrim(coalesce(dni, '')), ''), v_dni),
      telefono         = case when v_tipo = 'Máster'
                              then coalesce(nullif(btrim(coalesce(telefono, '')), ''), v_tel) else telefono end,
      telefono_tutor   = case when v_tipo = 'Escuela'
                              then coalesce(nullif(btrim(coalesce(telefono_tutor, '')), ''), v_tel) else telefono_tutor end,
      nombre_tutor     = case when v_tipo = 'Escuela'
                              then coalesce(nullif(btrim(coalesce(nombre_tutor, '')), ''), nullif(btrim(coalesce(p_nombre_tutor, '')), ''))
                              else nombre_tutor end,
      updated_at       = now()
    where id = p_atleta;
    perform set_config('apolana.via_natacion', '', true);
  else
    -- NUEVA (natacion_crear_nadador ya evita duplicar por DNI o nombre+nacimiento)
    if btrim(coalesce(p_nombre, '')) = '' then
      raise exception 'Falta el nombre.';
    end if;
    if btrim(coalesce(p_apellidos, '')) = '' then
      raise exception 'Faltan los apellidos.';
    end if;
    if p_fecha_nac is null then
      raise exception 'Falta la fecha de nacimiento.';
    end if;
    if p_fecha_nac > current_date or p_fecha_nac < date '1920-01-01' then
      raise exception 'La fecha de nacimiento no parece correcta.';
    end if;
    if v_email = '' then
      raise exception '%', case when v_tipo = 'Máster' then 'Falta el correo del nadador.' else 'Falta el correo del tutor.' end;
    end if;
    if v_tipo = 'Escuela' and btrim(coalesce(p_nombre_tutor, '')) = '' then
      raise exception 'Falta el nombre del padre, madre o tutor.';
    end if;
    v_res := public.natacion_crear_nadador(
      btrim(p_nombre), btrim(p_apellidos), v_dni, p_fecha_nac, v_email,
      case when v_tipo = 'Escuela' then btrim(p_nombre_tutor) end, v_tel,
      '{}'::uuid[], coalesce(p_nivel, 'Iniciación'), 'C1', v_tipo);
    v_atleta := (v_res ->> 'atleta_id')::uuid;
    v_res := v_res || jsonb_build_object('publico', case when v_tipo = 'Máster' then 'master' else 'familia' end);
  end if;

  v_acceso := (v_res ->> 'acceso_id')::uuid;
  select upper(btrim(nombre || ' ' || coalesce(apellidos, ''))) into v_nommay
    from public.atletas where id = v_atleta;

  -- ---- una inscripción por franja, cada una con SU calle y nivel ----
  for v_p in select * from jsonb_array_elements(p_plazas) loop
    v_franja := (v_p ->> 'franja')::uuid;
    v_calle  := btrim(v_p ->> 'calle');
    v_nivel  := coalesce(nullif(btrim(coalesce(v_p ->> 'nivel', '')), ''), p_nivel);
    select * into v_f from public.natacion_franjas where id = v_franja;
    v_lab    := v_dias[v_f.dia] || ' ' || to_char(v_f.hora, 'HH24:MI') || ' · ' || v_calle;
    -- ya estaba en esa franja (repetir el alta no duplica ni cuenta como «llena»)
    if exists (select 1 from public.natacion_inscripciones
                where franja_id = v_franja and activa and (atleta_id = v_atleta or acceso_id = v_acceso)) then
      v_ya := v_ya || jsonb_build_array(v_dias[v_f.dia] || ' ' || to_char(v_f.hora, 'HH24:MI'));
      continue;
    end if;
    -- hueco: el mismo cálculo que enseña el asistente (antes de meterle)
    select a.libres into v_libres
      from public.natacion_alta_franjas(v_tipo) a
     where a.franja_id = v_franja and a.calle = v_calle;
    if coalesce(v_libres, 0) <= 0 then
      v_llenas := v_llenas || v_lab;
    end if;
    insert into public.natacion_inscripciones
      (franja_id, nombre, tipo, nivel, calle, acceso_id, atleta_id, activa)
    values (v_franja, v_nommay, v_tipo, v_nivel, v_calle, v_acceso, v_atleta, true);
    v_hechas := v_hechas || jsonb_build_array(v_lab);
  end loop;

  -- calle sin hueco y sin confirmar → se deshace TODO (es una sola transacción)
  if array_length(v_llenas, 1) > 0 and not coalesce(p_confirmar_llenas, false) then
    raise exception 'CALLE LLENA: % no tiene hueco. Si quieres meterle igualmente, confírmalo.',
      array_to_string(v_llenas, ', ');
  end if;
  v_sobre := to_jsonb(v_llenas);

  -- ---- la cuota, apuntada en la ficha (sin cobrar nada) ----
  -- Una ficha tiene UNA cuota. Si ya tenía una que NO es de natación (Cubo,
  -- escuela de atletismo…), no se pisa: se avisa para que lo vea administración.
  if p_cuota_importe is not null then
    select cuota_importe, cuota_nota into v_cuota_prev, v_nota_prev from public.atletas where id = v_atleta;
    if v_cuota_prev is not null and coalesce(v_nota_prev, '') !~* '^nataci' then
      v_cuota_ok := false;
      v_cuota_msg := 'Ya tenía otra cuota de ' || replace(to_char(v_cuota_prev, 'FM999990.00'), '.', ',') || ' € (de otra sección): no la he cambiado. Si debe cambiar, que lo vea administración.';
    else
      perform set_config('apolana.via_natacion', '1', true);
      update public.atletas set
        cuota_importe      = round(p_cuota_importe, 2),
        cuota_periodicidad = coalesce(p_cuota_periodicidad, 'mensual'),
        cuota_nota         = left(coalesce(nullif(btrim(coalesce(p_cuota_nota, '')), ''),
                                  'Natación ' || case when v_tipo = 'Máster' then 'máster' else 'escuela' end), 300),
        cuota_fijada_en    = now(),
        cuota_fijada_por   = public.mi_perfil_id(),
        updated_at         = now()
      where id = v_atleta;
      perform set_config('apolana.via_natacion', '', true);
      v_cuota_ok := true;
    end if;
  end if;

  return v_res || jsonb_build_object(
    'atleta_id', v_atleta, 'acceso_id', v_acceso, 'nombre', v_nommay, 'tipo', v_tipo,
    'franjas', v_hechas, 'inscripciones', jsonb_array_length(v_hechas),
    'ya_estaba', v_ya, 'sobre_cupo', v_sobre,
    'cuota_guardada', v_cuota_ok, 'cuota_aviso', v_cuota_msg);
end $$;

revoke all on function public.natacion_alta_unificada(text, jsonb, uuid, text, text, date, text, text, text, text, text, boolean, numeric, text, text) from public, anon;
grant execute on function public.natacion_alta_unificada(text, jsonb, uuid, text, text, date, text, text, text, text, text, boolean, numeric, text, text) to authenticated;

comment on function public.natacion_alta_unificada(text, jsonb, uuid, text, text, date, text, text, text, text, text, boolean, numeric, text, text) is
  'Mig 385 · alta de nadador en una transacción (asistente portal/natacion-alta): ficha nueva o existente (completa huecos), código, una inscripción por franja con su calle/nivel, cuota apuntada en la ficha, token de invitación. Calle llena → excepción «CALLE LLENA» salvo p_confirmar_llenas.';

-- ---------- 4 · tarifas para calcular la cuota en el asistente ----------
create or replace function public.natacion_alta_cuota(p_tipo text, p_atleta uuid default null)
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $$
declare
  v_socio boolean := false;
  v_tar   jsonb;
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Solo quien gestiona natación puede dar altas.' using errcode = '42501';
  end if;
  if p_atleta is not null then
    select (a.tipo_membresia = 'socio' or a.numero_socio is not null) into v_socio
      from public.atletas a where a.id = p_atleta;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'dias', x.n, 'clave', x.clave, 'concepto', x.concepto,
           'socio', x.importe_socio, 'no_socio', x.importe_no_socio,
           'periodicidad', coalesce(x.periodicidad, 'mensual')) order by x.n), '[]'::jsonb)
    into v_tar
    from (
      select distinct on (substring(t.dias from '^\s*(\d+)')::int)
             substring(t.dias from '^\s*(\d+)')::int as n, t.*
        from public.tarifas t
       where t.activo
         and t.seccion = case when p_tipo = 'Máster' then 'natacion' else 'escuela-natacion' end
         and t.vigente_desde <= current_date
         and (t.vigente_hasta is null or t.vigente_hasta >= current_date)
         and substring(t.dias from '^\s*(\d+)') is not null
       order by substring(t.dias from '^\s*(\d+)')::int, t.vigente_desde desc, t.orden
    ) x;
  return jsonb_build_object('es_socio', coalesce(v_socio, false), 'tarifas', v_tar);
end $$;

revoke all on function public.natacion_alta_cuota(text, uuid) from public, anon;
grant execute on function public.natacion_alta_cuota(text, uuid) to authenticated;
