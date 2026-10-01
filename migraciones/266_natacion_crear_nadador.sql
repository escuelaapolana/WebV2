-- ============================================================
-- 266 · Alta de un nadador de ESCUELA en un paso (para Mario)
-- ------------------------------------------------------------
-- Hasta ahora el panel de natación solo escribía en
-- `natacion_inscripciones` (una fila-texto por franja). Un nadador
-- NUEVO quedaba «suelto»: sin ficha (donde vive el email del tutor,
-- el DNI y la fecha de nacimiento), sin código de acceso (el que usa
-- el enlace de «mi plaza» y el correo de horarios) y sin forma de que
-- la familia tenga cuenta. Por eso Mario veía «antes hay que dar de
-- alta los correos».
--
-- Esta función hace el alta COMPLETA en una sola llamada, igual que
-- los ~130 nadadores reales: crea (o reutiliza) la ficha en `atletas`
-- con el email del tutor, crea su `natacion_accesos` (código único) y
-- una `natacion_inscripciones` por franja elegida. Si la familia NO
-- tiene cuenta todavía, deja preparado un token de invitación en
-- `familia_invitaciones` para que el correo «crea tu contraseña»
-- pueda salir (lo manda familia-invitar). La ASOCIACIÓN familia↔hijo
-- se consuma sola cuando la familia abre el enlace: `acceso_enganchar`
-- empareja por `email_tutor` (migración 108/246). Por eso lo único
-- imprescindible aquí es guardar bien el `email_tutor`.
--
-- Idempotente y sin duplicar: reutiliza la ficha si ya existe por DNI,
-- el acceso si ya lo tiene, y no repite una inscripción ya activa en
-- la misma franja. Solo rellena huecos (no pisa datos existentes).
--
-- Permiso: solo gestor de natación (admin, staff o responsable de
-- natación / escuela-natación) — `soy_gestor_natacion()`.
-- ============================================================

create or replace function public.natacion_crear_nadador(
  p_nombre          text,
  p_apellidos       text default null,
  p_dni             text default null,
  p_fecha_nac       date default null,
  p_email_tutor     text default null,
  p_nombre_tutor    text default null,
  p_telefono_tutor  text default null,
  p_franjas         uuid[] default '{}',
  p_nivel           text default null,
  p_calle           text default 'C1',
  p_tipo            text default 'Escuela'
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_atleta   uuid;
  v_acceso   uuid;
  v_codigo   text;
  v_token    text;
  v_tiene    boolean;
  v_email    text := lower(btrim(coalesce(p_email_tutor, '')));
  v_nombref  text := btrim(coalesce(p_nombre, '') || ' ' || coalesce(p_apellidos, ''));
  v_nommay   text := upper(v_nombref);
  v_dni      text := nullif(btrim(coalesce(p_dni, '')), '');
  v_franja   uuid;
  v_calle    text := coalesce(nullif(btrim(coalesce(p_calle, '')), ''), 'C1');
  v_ins      int := 0;
begin
  -- --- permiso ---
  if not public.soy_gestor_natacion() then
    raise exception 'Sin permiso: solo el gestor de natación puede dar de alta nadadores.'
      using errcode = '42501';
  end if;

  -- --- validación mínima ---
  if btrim(coalesce(p_nombre, '')) = '' then
    raise exception 'Falta el nombre del nadador.';
  end if;
  if v_email = '' or position('@' in v_email) = 0 then
    raise exception 'Falta un correo válido (es lo que ata la cuenta: del tutor en escuela, del propio nadador en máster).';
  end if;
  if p_nivel is not null and p_nivel not in ('Iniciación', 'Desarrollo', 'Perfeccionamiento') then
    raise exception 'Nivel no válido: %', p_nivel;
  end if;

  -- --- 1) ficha: reutilizar por DNI, si no crear ---
  --  ESCUELA (menor): el correo es el del TUTOR → va en `email_tutor`, y la
  --    familia ve al hijo por `perfil_padre_id` (acceso_enganchar empareja por
  --    email_tutor).
  --  MÁSTER (adulto): el correo es el SUYO → va en `email`, y ve su propia ficha
  --    por `perfil_id` (acceso_enganchar empareja por email). No lleva tutor.
  if v_dni is not null then
    select id into v_atleta from public.atletas where upper(dni) = upper(v_dni) limit 1;
  end if;

  if v_atleta is null then
    if p_tipo = 'Máster' then
      insert into public.atletas (nombre, apellidos, dni, fecha_nacimiento, email, telefono, estado)
      values (btrim(p_nombre), nullif(btrim(coalesce(p_apellidos, '')), ''), v_dni, p_fecha_nac,
              v_email, nullif(btrim(coalesce(p_telefono_tutor, '')), ''), 'activo')
      returning id into v_atleta;
    else
      insert into public.atletas (nombre, apellidos, dni, fecha_nacimiento,
                                  email_tutor, nombre_tutor, telefono_tutor, estado)
      values (btrim(p_nombre), nullif(btrim(coalesce(p_apellidos, '')), ''), v_dni, p_fecha_nac,
              v_email, nullif(btrim(coalesce(p_nombre_tutor, '')), ''),
              nullif(btrim(coalesce(p_telefono_tutor, '')), ''), 'activo')
      returning id into v_atleta;
    end if;
  else
    -- solo rellenar huecos; no pisar lo que ya haya
    if p_tipo = 'Máster' then
      update public.atletas set
        apellidos        = coalesce(apellidos, nullif(btrim(coalesce(p_apellidos, '')), '')),
        dni              = coalesce(dni, v_dni),
        fecha_nacimiento = coalesce(fecha_nacimiento, p_fecha_nac),
        email            = coalesce(nullif(btrim(coalesce(email, '')), ''), v_email),
        telefono         = coalesce(nullif(btrim(coalesce(telefono, '')), ''), nullif(btrim(coalesce(p_telefono_tutor, '')), '')),
        updated_at       = now()
      where id = v_atleta;
    else
      update public.atletas set
        apellidos        = coalesce(apellidos, nullif(btrim(coalesce(p_apellidos, '')), '')),
        dni              = coalesce(dni, v_dni),
        fecha_nacimiento = coalesce(fecha_nacimiento, p_fecha_nac),
        email_tutor      = coalesce(nullif(btrim(coalesce(email_tutor, '')), ''), v_email),
        nombre_tutor     = coalesce(nullif(btrim(coalesce(nombre_tutor, '')), ''), nullif(btrim(coalesce(p_nombre_tutor, '')), '')),
        telefono_tutor   = coalesce(nullif(btrim(coalesce(telefono_tutor, '')), ''), nullif(btrim(coalesce(p_telefono_tutor, '')), '')),
        updated_at       = now()
      where id = v_atleta;
    end if;
  end if;

  -- --- 2) código de acceso: reutilizar el suyo o crear uno único ---
  select id, codigo into v_acceso, v_codigo
  from public.natacion_accesos where atleta_id = v_atleta and activo limit 1;

  if v_acceso is null then
    loop
      v_codigo := upper(substr(md5(random()::text), 1, 8));
      exit when not exists (select 1 from public.natacion_accesos where codigo = v_codigo);
    end loop;
    insert into public.natacion_accesos (codigo, nombre, atleta_id, activo)
    values (v_codigo, v_nommay, v_atleta, true)
    returning id into v_acceso;
  end if;

  -- --- 3) una inscripción por franja (sin duplicar las activas) ---
  foreach v_franja in array coalesce(p_franjas, '{}') loop
    if v_franja is not null
       and not exists (select 1 from public.natacion_inscripciones
                       where franja_id = v_franja and atleta_id = v_atleta and activa) then
      insert into public.natacion_inscripciones
        (franja_id, nombre, tipo, nivel, calle, acceso_id, atleta_id, activa)
      values (v_franja, v_nommay, coalesce(nullif(p_tipo, ''), 'Escuela'),
              p_nivel, v_calle, v_acceso, v_atleta, true);
      v_ins := v_ins + 1;
    end if;
  end loop;

  -- --- 4) ¿la familia ya tiene cuenta? si no, dejar token listo ---
  v_tiene := exists (select 1 from public.perfiles where lower(email) = v_email);

  if not v_tiene then
    select token into v_token from public.familia_invitaciones
    where lower(email_tutor) = v_email and usado_en is null and caduca_en > now()
    order by creado_en desc limit 1;

    if v_token is null then
      loop
        -- token de 32 hex (cumple el regex [A-Za-z0-9_-]{16,80}); gen_random_uuid
        -- está disponible (es el default de los ids) y no necesita pgcrypto.
        v_token := replace(gen_random_uuid()::text, '-', '');
        exit when not exists (select 1 from public.familia_invitaciones where token = v_token);
      end loop;
      insert into public.familia_invitaciones (token, email_tutor, nota)
      values (v_token, v_email,
              'alta ' || (case when p_tipo = 'Máster' then 'máster' else 'escuela natación' end)
              || ' ' || to_char(now(), 'YYYY-MM-DD'));
    end if;
  end if;

  return jsonb_build_object(
    'atleta_id',     v_atleta,
    'acceso_id',     v_acceso,
    'codigo',        v_codigo,
    'inscripciones', v_ins,
    'ya_tiene_cuenta', v_tiene,
    'email_tutor',   v_email,
    'token',         v_token      -- null si ya tiene cuenta
  );
end;
$$;

-- Solo la app con sesión (la gateamos dentro con soy_gestor_natacion()); nunca anon.
revoke all on function public.natacion_crear_nadador(text, text, text, date, text, text, text, uuid[], text, text, text) from public, anon;
grant execute on function public.natacion_crear_nadador(text, text, text, date, text, text, text, uuid[], text, text, text) to authenticated;
