-- 391 · Salud diaria («avisarte cuando algo se rompe») + re-sincronización
--       automática de las cuotas domiciliadas, con pg_cron + pg_net
-- ---------------------------------------------------------------------------
-- Por qué: el alta de entrenador estuvo semanas rota (mig 388) sin que nadie se
-- enterase, y para saber si un cobro SEPA ya ha llegado había que pulsar
-- «Re-sincronizar» a mano en admin/cuotas-entreno.
--
-- Qué hace:
--   1. Activa pg_cron y pg_net (estaban disponibles, sin activar).
--   2. `salud_registro`   → una fila por cada comprobación diaria (ok / fallos).
--      `salud_rpc_front`  → qué funciones llama la web/app (para mirar permisos).
--      `cron_llamadas`    → qué llamada HTTP lanzó cada tarea programada (para
--                           saber al día siguiente si respondió bien).
--   3. `cron_llamar_edge()` → llama a una Edge con la cabecera x-cron-secret,
--      leyendo el secreto de Supabase Vault (solo lo lee `postgres`).
--   4. `salud_comprobar()`  → las comprobaciones de la base: formularios
--      simulados de verdad (y deshechos), permisos, pagos. Solo service_role.
--   5. Dos tareas pg_cron: entreno-resync a las 7:00 y salud-diaria a las 7:30
--      (hora de Madrid; ver la nota del horario de verano abajo).
--
-- ANTES DE QUE FUNCIONE hace falta el secreto (NO va en el repo):
--   · en Vault:    select vault.create_secret('<VALOR>', 'cron_secret',
--                    'Secreto compartido pg_cron → Edge (x-cron-secret)');
--   · en las Edge: supabase secrets set CRON_SECRET=<VALOR> --project-ref icaxokjsvhlreuwpyxeb
--   (el mismo valor en los dos sitios).
-- ---------------------------------------------------------------------------
begin;

-- ============================================================
-- 1 · Extensiones
-- ============================================================
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net  with schema extensions;

-- ============================================================
-- 2 · Tablas
-- ============================================================
create table if not exists public.salud_registro (
  id             bigint generated always as identity primary key,
  creado_en      timestamptz not null default now(),
  ok             boolean not null,
  fallos         jsonb not null default '[]'::jsonb,
  detalle        jsonb not null default '{}'::jsonb,
  correo_enviado boolean not null default false,
  origen         text not null default 'cron'
);
comment on table public.salud_registro is
  'Resultado de cada comprobación diaria (Edge salud-diaria, mig 391). ok=false → se mandó un correo a Andrés.';
create index if not exists idx_salud_registro_fecha on public.salud_registro (creado_en desc);
alter table public.salud_registro enable row level security;
drop policy if exists "admin lee salud_registro" on public.salud_registro;
create policy "admin lee salud_registro" on public.salud_registro
  for select to authenticated using ((select public.es_admin()));
revoke all on public.salud_registro from anon, authenticated;
grant select on public.salud_registro to authenticated;
grant all on public.salud_registro to service_role;

create table if not exists public.salud_rpc_front (
  nombre     text primary key,
  en_publica boolean not null default false,
  anadido_en timestamptz not null default now()
);
comment on table public.salud_rpc_front is
  'Funciones que llama la web/app (se regenera con herramientas/salud_rpc_front.py --sql). en_publica = se llama desde una página sin sesión → anon necesita EXECUTE.';
alter table public.salud_rpc_front enable row level security;
revoke all on public.salud_rpc_front from anon, authenticated;
grant all on public.salud_rpc_front to service_role;

create table if not exists public.cron_llamadas (
  id         bigint generated always as identity primary key,
  request_id bigint,
  funcion    text not null,
  error      text,
  creado_en  timestamptz not null default now()
);
comment on table public.cron_llamadas is
  'Cada llamada HTTP de una tarea pg_cron a una Edge (request_id de pg_net → net._http_response). La usa salud_comprobar().';
create index if not exists idx_cron_llamadas_funcion on public.cron_llamadas (funcion, creado_en desc);
alter table public.cron_llamadas enable row level security;
revoke all on public.cron_llamadas from anon, authenticated;
grant all on public.cron_llamadas to service_role;

-- Cuotas de entreno: cuándo se avisó a Andrés de que una cuota está en impago
-- (entreno-resync manda UN correo por cuota; si sale de impago se vacía).
alter table public.cuotas_entreno add column if not exists impago_avisado_en timestamptz;
comment on column public.cuotas_entreno.impago_avisado_en is
  'Mig 391 · cuándo avisó entreno-resync por correo de que esta cuota está en impago (null = sin avisar / ya no está en impago).';

-- ============================================================
-- 3 · Llamar a una Edge desde pg_cron (con el secreto de Vault)
-- ------------------------------------------------------------
-- p_hora_madrid: pg_cron va en UTC y Madrid cambia de hora. La tarea se programa
-- a dos horas UTC seguidas (5 y 6) y aquí solo se lanza la que cae a la hora de
-- Madrid pedida. Así son las 7:xx de Madrid en verano y en invierno.
-- ============================================================
create or replace function public.cron_llamar_edge(
  p_funcion     text,
  p_cuerpo      jsonb default '{}'::jsonb,
  p_hora_madrid integer default null
) returns bigint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_secreto text;
  v_id      bigint;
begin
  if p_hora_madrid is not null
     and extract(hour from (now() at time zone 'Europe/Madrid'))::int <> p_hora_madrid then
    return null;
  end if;
  if coalesce(p_funcion, '') !~ '^[a-z0-9-]{1,60}$' then
    raise exception 'cron_llamar_edge: nombre de función no válido';
  end if;

  delete from public.cron_llamadas where creado_en < now() - interval '60 days';

  select decrypted_secret into v_secreto
    from vault.decrypted_secrets where name = 'cron_secret'
   order by created_at desc limit 1;
  if v_secreto is null or v_secreto = '' then
    insert into public.cron_llamadas (funcion, error)
    values (p_funcion, 'Falta el secreto cron_secret en Vault');
    return null;
  end if;

  v_id := net.http_post(
    url                  := 'https://icaxokjsvhlreuwpyxeb.supabase.co/functions/v1/' || p_funcion,
    body                 := coalesce(p_cuerpo, '{}'::jsonb),
    headers              := jsonb_build_object('Content-Type', 'application/json',
                                               'x-cron-secret', v_secreto),
    timeout_milliseconds := 150000
  );
  insert into public.cron_llamadas (request_id, funcion) values (v_id, p_funcion);
  return v_id;
end;
$$;
comment on function public.cron_llamar_edge(text, jsonb, integer) is
  'pg_cron → Edge con x-cron-secret (Vault cron_secret). Solo postgres. Para forzar una ejecución: select public.cron_llamar_edge(''salud-diaria'');';
revoke all on function public.cron_llamar_edge(text, jsonb, integer) from public, anon, authenticated, service_role;

-- ============================================================
-- 4 · salud_comprobar() · lo que se comprueba DENTRO de la base
-- ------------------------------------------------------------
-- Cada formulario se simula con los MISMOS pasos y valores que su Edge/RPC, en
-- un bloque BEGIN … EXCEPTION: al final se lanza a propósito la excepción
-- 'SA001' y Postgres deshace TODO lo del bloque (filas, contadores anti-spam,
-- cuentas). Nada queda escrito y no se manda ningún correo (los correos los
-- mandan las Edge, que aquí no se llaman). Si algo falla por el camino (una
-- restricción CHECK, un permiso, una columna que ya no existe…), se apunta.
--
-- Devuelve { ok, fallos:[{clave,titulo,donde,detalle}], notas:[…], comprobado:[…] }.
-- ============================================================
create or replace function public.salud_comprobar()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_fallos  jsonb := '[]'::jsonb;
  v_notas   jsonb := '[]'::jsonb;
  v_hecho   text[] := array[]::text[];
  v_paso    text;
  v_res     jsonb;
  v_txt     text;
  v_n       integer;
  v_uid     uuid;
  v_atleta  uuid;
  v_grupo   uuid;
  v_precio  integer;
  v_lleno   boolean;
  v_bool    boolean;
  v_alta    uuid;
  v_prod    uuid;
  v_talla   text;
  v_cfg     public.pagos_config;
  v_email   text;
  v_sello   text := to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');
  v_ts      timestamptz;
  v_res_txt text;
  r         record;
begin
  -- Un correo que no puede existir (dominio .invalid) y no choca con nadie.
  v_email := 'salud.diaria.' || v_sello || '@apolana.invalid';

  -- ----------------------------------------------------------
  -- F1 · Alta de SOCIO (RPC enviar_alta_socio + socio-pagar + socio-cuenta)
  -- ----------------------------------------------------------
  begin
    v_paso := 'enviar_alta_socio';
    v_res := public.enviar_alta_socio(jsonb_build_object(
      'nombre', 'Salud', 'apellidos', 'Diaria Prueba', 'dni', '00000000T',
      'fecha_nacimiento', '1990-01-01', 'sexo', 'hombre',
      'direccion', 'Calle Prueba 1', 'cp', '03000', 'localidad', 'Alicante', 'provincia', 'Alicante',
      'telefono', '600000000', 'email', v_email, 'secciones', jsonb_build_array('atletismo'),
      'acepta_normas', true, 'texto_normas', 'prueba',
      'acepta_proteccion_datos', true, 'texto_proteccion_datos', 'prueba',
      'telefono_info_apolana', true,
      'consiente_domiciliacion', true, 'texto_domiciliacion', 'prueba',
      'iban', 'ES9121000418450200051332', 'titular_cuenta', 'Salud Diaria',
      'permiso_imagen', false, 'permiso_imagen_ambitos', jsonb_build_array(),
      'texto_imagen', 'prueba', 'texto_condiciones', 'prueba',
      'nacionalidad', 'España', 'talla_camiseta', 'M',
      'segundos', 120, 'apellido_de_soltera', ''));
    if coalesce((v_res ->> 'ok')::boolean, false) is not true or v_res ? 'repetida' then
      raise exception 'respuesta inesperada: %', v_res::text;
    end if;
    select id into v_alta from public.altas_socio where referencia = v_res ->> 'referencia';
    if v_alta is null then raise exception 'el alta no se ha guardado (referencia %)', v_res ->> 'referencia'; end if;

    v_paso := 'socio-pagar (pagos_online)';
    insert into public.pagos_online (referencia, tipo, concepto, importe_centimos, moneda, estado, metadatos)
    values ('socio-' || v_alta, 'alta_socio', 'Primera cuota de socio',
            coalesce((select precio_alta_socio_cent from public.pagos_config where id = 1), 3500),
            'eur', 'iniciado', jsonb_build_object('alta_id', v_alta, 'alta_ref', v_res ->> 'referencia'));
    update public.altas_socio set stripe_session_id = 'cs_salud_' || v_sello where id = v_alta;

    v_paso := 'socio-cuenta (cuenta + perfil socio)';
    v_uid := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at)
    values ('00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated', v_email, now(), now(), now());
    if not exists (select 1 from public.perfiles where id = v_uid) then
      raise exception 'el perfil no se ha creado al nacer la cuenta';
    end if;
    update public.perfiles set nombre = 'Salud', apellidos = 'Diaria Prueba', rol = 'socio', roles = array['socio']
     where id = v_uid;

    raise exception using errcode = 'SA001', message = 'deshacer';
  exception
    when sqlstate 'SA001' then v_hecho := array_append(v_hecho, 'form:socio');
    when others then
      v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
        'clave', 'form:socio', 'titulo', 'El alta de socio no se puede completar',
        'donde', 'Web · Hazte socio (/socio/alta/)', 'detalle', v_paso || ': ' || sqlerrm));
  end;

  -- ----------------------------------------------------------
  -- F2 · Alta de la ESCUELA (RPC enviar_alta_escuela)
  -- ----------------------------------------------------------
  begin
    v_paso := 'enviar_alta_escuela';
    v_res := public.enviar_alta_escuela(jsonb_build_object(
      'tutor_nombre_pila', 'Salud', 'tutor_apellido1', 'Diaria', 'tutor_apellido2', 'Prueba',
      'tutor_dni', '00000000T', 'tutor_email', v_email, 'tutor_telefono', '600000000',
      'direccion', 'Calle Prueba 1', 'cp', '03000', 'localidad', 'Alicante',
      'acepta_normas', true, 'texto_normas', 'prueba', 'forma_pago', 'dos-pagos',
      'segundos', 120, 'apellido_de_soltera', '',
      'ninos', jsonb_build_array(jsonb_build_object(
        'nombre_pila', 'Peque', 'apellido1', 'Diaria', 'apellido2', 'Prueba',
        'fecha_nacimiento', (extract(year from now())::int - 9) || '-03-01', 'sexo', 'mujer',
        'turno', 'lunes-miercoles', 'permiso_imagen', false, 'texto_imagen', 'prueba', 'talla_camiseta', 'S'))));
    if coalesce((v_res ->> 'ok')::boolean, false) is not true or v_res ? 'repetida' then
      raise exception 'respuesta inesperada: %', v_res::text;
    end if;
    if not exists (select 1 from public.altas_escuela where referencia = v_res ->> 'referencia') then
      raise exception 'el alta no se ha guardado';
    end if;
    raise exception using errcode = 'SA001', message = 'deshacer';
  exception
    when sqlstate 'SA001' then v_hecho := array_append(v_hecho, 'form:escuela');
    when others then
      v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
        'clave', 'form:escuela', 'titulo', 'El alta de la escuela no se puede completar',
        'donde', 'Web · Apuntarse a la escuela (/escuelas/apuntar/)', 'detalle', v_paso || ': ' || sqlerrm));
  end;

  -- ----------------------------------------------------------
  -- F3 · Alta del CUBO (Edge cubo-alta: precio, aforo, cuenta, ficha, alta)
  -- ----------------------------------------------------------
  begin
    v_paso := 'cubo_precio';
    v_precio := public.cubo_precio(2, false);
    if v_precio is null or v_precio <= 0 then raise exception 'no hay tarifa vigente para 2 días (cubo_precio = %)', v_precio; end if;
    v_precio := public.cubo_precio(1, true);
    if v_precio is null or v_precio <= 0 then raise exception 'no hay tarifa vigente reducida de 1 día (cubo_precio = %)', v_precio; end if;
    v_precio := public.cubo_precio(2, false);

    v_paso := 'grupos del Cubo';
    select count(*) into v_n from public.grupos
     where seccion = 'cubo' and nombre in ('El Cubo · L y X 17:30', 'El Cubo · M y J 17:30', 'El Cubo · L y X 18:45');
    if v_n < 3 then raise exception 'faltan grupos de turno (hay % de 3); el alta quedaría sin grupo', v_n; end if;
    select id into v_grupo from public.grupos where seccion = 'cubo' and nombre = 'El Cubo · L y X 17:30' limit 1;

    v_paso := 'cubo_turno_lleno';
    v_lleno := public.cubo_turno_lleno('El Cubo · L y X 17:30');

    v_paso := 'correo_ya_del_club';
    perform public.correo_ya_del_club(v_email);

    v_paso := 'crear la cuenta (perfil)';
    v_uid := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at)
    values ('00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated', v_email, now(), now(), now());
    if not exists (select 1 from public.perfiles where id = v_uid) then
      raise exception 'el perfil no se ha creado al nacer la cuenta';
    end if;
    v_paso := 'perfil → cubo-atleta';
    update public.perfiles set nombre = 'Salud', apellidos = 'Diaria Prueba', telefono = '600000000',
           rol = 'cubo-atleta', roles = array['cubo-atleta']
     where id = v_uid;

    v_paso := 'ficha de atleta';
    insert into public.atletas (perfil_id, nombre, apellidos, dni, email, telefono, tipo_membresia, grupo_id, estado)
    values (v_uid, 'Salud', 'Diaria Prueba', null, v_email, '600000000', 'cubo', v_grupo, 'prueba')
    returning id into v_atleta;

    v_paso := 'atleta_grupos';
    insert into public.atleta_grupos (atleta_id, grupo_id, principal)
    values (v_atleta, v_grupo, false) on conflict do nothing;

    v_paso := 'cubo_altas';
    insert into public.cubo_altas (nombre, apellidos, dni, telefono, hijo, direccion, horario, dias, dias_semana,
                                   precio_mes, nota, es_escuela, es_socio, estado, perfil_id, atleta_id, lista_espera)
    values ('Salud', 'Diaria Prueba', null, '600000000', null, null, 'El Cubo · L y X 17:30', 2, array[1,3]::smallint[],
            v_precio, null, false, false, 'pendiente', v_uid, v_atleta, coalesce(v_lleno, false));

    raise exception using errcode = 'SA001', message = 'deshacer';
  exception
    when sqlstate 'SA001' then v_hecho := array_append(v_hecho, 'form:cubo');
    when others then
      v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
        'clave', 'form:cubo', 'titulo', 'El alta del Cubo no se puede completar',
        'donde', 'Web · Apuntarse al Cubo (/cubo/apuntarse/)', 'detalle', v_paso || ': ' || sqlerrm));
  end;

  -- ----------------------------------------------------------
  -- F4 · FUERZA GRATIS (Edge cubo-prueba-alta)
  -- ----------------------------------------------------------
  begin
    v_paso := 'cubo_prueba_aforo';
    perform * from public.cubo_prueba_aforo();

    select id into v_grupo from public.grupos
     where seccion = 'cubo' and nombre like 'El Cubo · Fuerza gratis%' order by nombre limit 1;

    v_paso := 'crear la cuenta (perfil)';
    v_uid := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at)
    values ('00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated', v_email, now(), now(), now());
    if not exists (select 1 from public.perfiles where id = v_uid) then
      raise exception 'el perfil no se ha creado al nacer la cuenta';
    end if;
    v_paso := 'perfil → cubo-atleta';
    update public.perfiles set nombre = 'Salud', apellidos = 'Diaria Prueba', telefono = '600000000',
           rol = 'cubo-atleta', roles = array['cubo-atleta']
     where id = v_uid;

    v_paso := 'ficha de atleta';
    insert into public.atletas (perfil_id, nombre, apellidos, email, telefono, tipo_membresia, estado, grupo_id)
    values (v_uid, 'Salud', 'Diaria Prueba', v_email, '600000000', 'cubo', 'prueba', v_grupo)
    returning id into v_atleta;

    if v_grupo is not null then
      v_paso := 'atleta_grupos';
      insert into public.atleta_grupos (atleta_id, grupo_id, principal)
      values (v_atleta, v_grupo, false) on conflict do nothing;
    end if;

    v_paso := 'cubo_prueba';
    insert into public.cubo_prueba (nombre, apellidos, telefono, email, turnos, quien, hijo, alternativa,
                                    perfil_id, atleta_id, estado)
    values ('Salud', 'Diaria Prueba', '600000000', v_email, array['viernes'], 'otro', null, null,
            v_uid, v_atleta, 'apuntado');

    raise exception using errcode = 'SA001', message = 'deshacer';
  exception
    when sqlstate 'SA001' then v_hecho := array_append(v_hecho, 'form:fuerza-gratis');
    when others then
      v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
        'clave', 'form:fuerza-gratis', 'titulo', 'La inscripción a Fuerza gratis no se puede completar',
        'donde', 'Web · Fuerza gratis (/cubo/fuerza-gratis/)', 'detalle', v_paso || ': ' || sqlerrm));
  end;

  -- ----------------------------------------------------------
  -- F5 · Alta de ENTRENADOR (Edge entrenador-alta → alta_entrenador + cuenta
  --      + entrenador_ficha). Es justo el fallo de la mig 388.
  -- ----------------------------------------------------------
  begin
    v_paso := 'alta_entrenador';
    v_res := public.alta_entrenador(jsonb_build_object(
      'nombre', 'Salud', 'apellidos', 'Diaria Prueba', 'email', v_email,
      'segundos', 120, 'apellido_de_soltera', ''));
    if coalesce((v_res ->> 'ok')::boolean, false) is not true or coalesce(v_res ->> 'ya', '') <> 'nuevo' then
      raise exception 'respuesta inesperada: %', v_res::text;
    end if;

    v_paso := 'crear la cuenta (perfil pendiente)';
    v_uid := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at)
    values ('00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated', v_email, now(), now(), now());
    select rol into v_txt from public.perfiles where id = v_uid;
    if v_txt is null then raise exception 'el perfil no se ha creado al nacer la cuenta'; end if;
    if v_txt <> 'pendiente' then raise exception 'el perfil nace con rol «%» en vez de «pendiente»', v_txt; end if;

    v_paso := 'teléfono al perfil';
    update public.perfiles set telefono = '600000000' where id = v_uid;

    v_paso := 'entrenador_ficha';
    insert into public.entrenador_ficha (perfil_id, fecha_nacimiento, dni, sexo, direccion, cp, localidad, updated_at)
    values (v_uid, '1990-01-01', '00000000T', 'hombre', 'Calle Prueba 1', '03000', 'Alicante', now())
    on conflict (perfil_id) do update set dni = excluded.dni, updated_at = excluded.updated_at;

    raise exception using errcode = 'SA001', message = 'deshacer';
  exception
    when sqlstate 'SA001' then v_hecho := array_append(v_hecho, 'form:entrenador');
    when others then
      v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
        'clave', 'form:entrenador', 'titulo', 'El alta de entrenador no se puede completar',
        'donde', 'Web · Alta de entrenador (/entrenador/alta/)', 'detalle', v_paso || ': ' || sqlerrm));
  end;

  -- ----------------------------------------------------------
  -- F6 · TIENDA (Edge tienda-pagar → el camino que esté en uso: pago online
  --      con tienda_pago_iniciar, o pedido en efectivo)
  -- ----------------------------------------------------------
  begin
    v_paso := 'pagos_config';
    select * into v_cfg from public.pagos_config where id = 1;
    v_paso := 'producto de prueba';
    select p.id,
           (select t from unnest(p.tallas_disponibles) t
             where not (t = any(coalesce(p.tallas_agotadas, array[]::text[]))) limit 1)
      into v_prod, v_talla
      from public.productos p
     where p.activo and p.precio > 0
       and (coalesce(array_length(p.tallas_disponibles, 1), 0) = 0
            or exists (select 1 from unnest(p.tallas_disponibles) t
                        where not (t = any(coalesce(p.tallas_agotadas, array[]::text[])))))
     order by p.precio limit 1;
    if v_prod is null then
      raise exception 'no hay ningún producto activo con precio y talla disponible';
    end if;
    if coalesce(v_cfg.tienda_pago_online, true) then
      v_paso := 'tienda_pago_iniciar';
      perform public.tienda_pago_iniciar(
        jsonb_build_array(jsonb_build_object('producto_id', v_prod, 'talla', coalesce(v_talla, ''), 'cantidad', 1)),
        jsonb_build_object('nombre', 'Salud Diaria', 'email', v_email, 'telefono', '600000000'),
        null, jsonb_build_object('origen', 'web'));
    else
      v_paso := 'tienda_pedido_efectivo';
      perform public.tienda_pedido_efectivo(
        jsonb_build_array(jsonb_build_object('producto_id', v_prod, 'talla', coalesce(v_talla, ''), 'cantidad', 1)),
        jsonb_build_object('nombre', 'Salud Diaria', 'email', v_email, 'telefono', '600000000'),
        null);
    end if;
    raise exception using errcode = 'SA001', message = 'deshacer';
  exception
    when sqlstate 'SA001' then v_hecho := array_append(v_hecho, 'form:tienda');
    when others then
      v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
        'clave', 'form:tienda', 'titulo', 'La tienda no puede registrar pedidos',
        'donde', 'Web · Tienda (/tienda/)', 'detalle', v_paso || ': ' || sqlerrm));
  end;

  -- ----------------------------------------------------------
  -- F7 · PRUEBA DE PISTA (Edge pista-prueba)
  -- ----------------------------------------------------------
  begin
    v_paso := 'pista_pruebas';
    insert into public.pista_pruebas (nombre, telefono, dia_preferido, es_menor, edad, tutor, nota, seccion, estado)
    values ('Salud Diaria Prueba', '600000000', 'Lunes y miércoles', true, 12, 'Tutor Prueba', null, 'pista', 'nueva');
    raise exception using errcode = 'SA001', message = 'deshacer';
  exception
    when sqlstate 'SA001' then v_hecho := array_append(v_hecho, 'form:pista');
    when others then
      v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
        'clave', 'form:pista', 'titulo', 'La solicitud de prueba de pista no se guarda',
        'donde', 'Web · Probar en pista (/pista/probar/)', 'detalle', v_paso || ': ' || sqlerrm));
  end;

  -- ----------------------------------------------------------
  -- F8 · ACCESO por enlace (Edge acceso-enlace)
  -- ----------------------------------------------------------
  begin
    v_paso := 'acceso_pedir_apuntar';
    v_bool := public.acceso_pedir_apuntar(v_email, 'salud-diaria');
    if v_bool is not true then raise exception 'devuelve % para un correo nuevo', v_bool; end if;
    v_paso := 'acceso_puede_entrar';
    select email into v_txt from public.perfiles where coalesce(activo, true) and email is not null limit 1;
    if v_txt is not null and public.acceso_puede_entrar(v_txt) is not true then
      raise exception 'dice que una cuenta activa del club no puede entrar';
    end if;
    raise exception using errcode = 'SA001', message = 'deshacer';
  exception
    when sqlstate 'SA001' then v_hecho := array_append(v_hecho, 'form:acceso');
    when others then
      v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
        'clave', 'form:acceso', 'titulo', 'El acceso por enlace a la app falla',
        'donde', 'App · Pantalla de acceso (enlace por correo / primera vez)', 'detalle', v_paso || ': ' || sqlerrm));
  end;

  -- ----------------------------------------------------------
  -- P1 · PERMISOS · funciones que llama la web/app sin EXECUTE
  --      (authenticated siempre; anon si se llama desde una página pública)
  -- ----------------------------------------------------------
  for r in
    select f.nombre, f.en_publica,
           count(p.oid) as firmas,
           coalesce(bool_or(has_function_privilege('authenticated', p.oid, 'execute')), false) as auth_ok,
           coalesce(bool_or(has_function_privilege('anon', p.oid, 'execute')), false) as anon_ok
      from public.salud_rpc_front f
      left join pg_proc p on p.proname = f.nombre and p.pronamespace = 'public'::regnamespace
     group by f.nombre, f.en_publica
    having count(p.oid) = 0
        or not coalesce(bool_or(has_function_privilege('authenticated', p.oid, 'execute')), false)
        or (f.en_publica and not coalesce(bool_or(has_function_privilege('anon', p.oid, 'execute')), false))
     order by f.nombre
  loop
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'permiso:' || r.nombre,
      'titulo', case when r.firmas = 0 then 'La web/app llama a una función que no existe: ' || r.nombre
                     else 'Función sin permiso de ejecución: ' || r.nombre end,
      'donde', 'La pantalla que llama a ' || r.nombre || ' (buscar en el repo)',
      'detalle', case when r.firmas = 0 then 'no existe en public'
                      when not r.auth_ok then 'authenticated no tiene EXECUTE (con sesión da «permission denied»)'
                      else 'anon no tiene EXECUTE y se llama desde una página pública' end));
  end loop;
  v_hecho := array_append(v_hecho, 'permisos:front');

  -- P2 · El patrón de `_dia_corto`: una función normal (no SECURITY DEFINER)
  --      que authenticated puede ejecutar, pero que por dentro llama a otra que
  --      no puede; y políticas RLS que llaman a funciones sin permiso.
  for r in
    with fun as (
      select p.oid, p.proname, p.prosecdef, p.prosrc
        from pg_proc p
       where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'
    ), nombres as (
      select proname,
             bool_or(has_function_privilege('authenticated', oid, 'execute')) as auth_ok,
             bool_or(has_function_privilege('anon', oid, 'execute')) as anon_ok
        from fun group by proname
    )
    select f.proname as quien, n.proname as llamada, 'función' as tipo
      from fun f
      join nombres n on n.proname <> f.proname and f.prosrc ~ ('\m' || n.proname || '\s*\(')
     where not f.prosecdef and has_function_privilege('authenticated', f.oid, 'execute') and not n.auth_ok
    union
    select pol.tablename || ' · ' || pol.policyname, n.proname, 'política'
      from pg_policies pol
      join nombres n on (coalesce(pol.qual, '') || ' ' || coalesce(pol.with_check, '')) ~ ('\m' || n.proname || '\s*\(')
     where pol.schemaname = 'public'
       and (pol.roles && array['authenticated', 'public']::name[]) and not n.auth_ok
    order by 1, 2
  loop
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'permiso-dentro:' || r.quien || ':' || r.llamada,
      'titulo', 'Falta permiso para ' || r.llamada || ' (lo usa ' || r.tipo || ' ' || r.quien || ')',
      'donde', 'Lo que use ' || r.quien || ' con sesión iniciada',
      'detalle', 'authenticated no tiene EXECUTE sobre ' || r.llamada || ' → «permission denied for function ' || r.llamada || '»'));
  end loop;
  v_hecho := array_append(v_hecho, 'permisos:dentro');

  -- P3 · service_role (lo que usan TODAS las Edge) puede hacer lo suyo.
  for r in
    select x.obj, x.tipo, x.priv
      from (values
        ('public.atletas', 'tabla', 'INSERT'), ('public.atletas', 'tabla', 'UPDATE'),
        ('public.atleta_grupos', 'tabla', 'INSERT'), ('public.perfiles', 'tabla', 'UPDATE'),
        ('public.cubo_altas', 'tabla', 'INSERT'), ('public.cubo_prueba', 'tabla', 'INSERT'),
        ('public.pista_pruebas', 'tabla', 'INSERT'), ('public.entrenador_ficha', 'tabla', 'INSERT'),
        ('public.entrenador_ficha', 'tabla', 'UPDATE'), ('public.pagos_online', 'tabla', 'INSERT'),
        ('public.pagos_online', 'tabla', 'UPDATE'), ('public.altas_socio', 'tabla', 'UPDATE'),
        ('public.rate_limit_log', 'tabla', 'INSERT'), ('public.cuotas_entreno', 'tabla', 'UPDATE'),
        ('public.cubo_altas', 'tabla', 'UPDATE'), ('public.salud_registro', 'tabla', 'INSERT')
      ) as x(obj, tipo, priv)
     where to_regclass(x.obj) is null or not has_table_privilege('service_role', x.obj, x.priv)
  loop
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'permiso-servicio:' || r.obj || ':' || r.priv,
      'titulo', 'Las funciones del servidor no pueden ' || lower(r.priv) || ' en ' || r.obj,
      'donde', 'Formularios y pagos que escriben en ' || r.obj,
      'detalle', 'service_role sin ' || r.priv || ' (o la tabla no existe)'));
  end loop;
  for r in
    select x.fn
      from unnest(array[
        'cubo_precio','cubo_turno_lleno','correo_ya_del_club','alta_entrenador','alta_ritmo',
        'tienda_pago_iniciar','tienda_pedido_efectivo','pagos_confirmar','pagos_marcar',
        'acceso_pedir_apuntar','acceso_puede_entrar','acceso_enganchar','marcar_cambio_clave',
        'dinero_registrar_cobro_stripe','salud_comprobar']) as x(fn)
     where not exists (select 1 from pg_proc p
                        where p.pronamespace = 'public'::regnamespace and p.proname = x.fn
                          and has_function_privilege('service_role', p.oid, 'execute'))
  loop
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'permiso-servicio:' || r.fn,
      'titulo', 'Las funciones del servidor no pueden llamar a ' || r.fn,
      'donde', 'La Edge que llama a ' || r.fn,
      'detalle', 'service_role sin EXECUTE (o la función no existe)'));
  end loop;
  v_hecho := array_append(v_hecho, 'permisos:servicio');

  -- ----------------------------------------------------------
  -- G1 · PAGOS
  -- ----------------------------------------------------------
  select * into v_cfg from public.pagos_config where id = 1;
  if v_cfg.id is null or v_cfg.modo <> 'real' or not v_cfg.activo then
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'pagos:modo', 'titulo', 'Los pagos no están en modo real',
      'donde', 'Todos los cobros (Cubo, alta de socio, recibos)',
      'detalle', 'pagos_config: modo=' || coalesce(v_cfg.modo, '¿?') || ', activo=' || coalesce(v_cfg.activo::text, '¿?')));
  end if;
  v_hecho := array_append(v_hecho, 'pagos:modo');

  -- Cobros del Cubo que ya tendrían que haber pasado y el webhook no ha anotado.
  select count(*), string_agg(nombre || ' ' || apellidos || ' (' || to_char(proximo_cobro at time zone 'Europe/Madrid', 'DD/MM') || ')', ', ' order by proximo_cobro)
    into v_n, v_txt
    from public.cubo_altas
   where suscripcion_estado = 'activa' and proximo_cobro < now() - interval '2 days';
  if v_n > 0 then
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'pagos:cubo-sin-actualizar', 'titulo', v_n || ' cuota(s) del Cubo con el cobro vencido y sin anotar',
      'donde', 'Panel · El Cubo › Pagos y Dinero (¿le llega el aviso de Stripe al webhook?)',
      'detalle', v_txt));
  end if;

  -- Cuotas de entreno con el próximo cobro pasado (la re-sincronización de las
  -- 7:00 tendría que haberlo movido).
  select count(*), string_agg(coalesce(nombre, '') || ' ' || coalesce(apellidos, '') || ' (' || to_char(proximo_cobro at time zone 'Europe/Madrid', 'DD/MM') || ')', ', ' order by proximo_cobro)
    into v_n, v_txt
    from public.cuotas_entreno
   where suscripcion_estado in ('activa', 'en_camino') and proximo_cobro < now() - interval '2 days';
  if v_n > 0 then
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'pagos:entreno-sin-actualizar', 'titulo', v_n || ' cuota(s) de entreno con el cobro vencido y sin anotar',
      'donde', 'Panel · Cuotas de entreno (admin/cuotas-entreno)',
      'detalle', v_txt));
  end if;

  -- Adeudos SEPA «en camino» desde hace más de 10 días.
  select count(*), string_agg(coalesce(nombre, '') || ' ' || coalesce(apellidos, '') || ' (desde ' || to_char(coalesce(factura_fecha, created_at) at time zone 'Europe/Madrid', 'DD/MM') || ')', ', ')
    into v_n, v_txt
    from public.cuotas_entreno
   where suscripcion_estado = 'en_camino' and coalesce(factura_fecha, created_at) < now() - interval '10 days';
  if v_n > 0 then
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'pagos:entreno-en-camino', 'titulo', v_n || ' cuota(s) de entreno «en camino» desde hace más de 10 días',
      'donde', 'Panel · Cuotas de entreno (admin/cuotas-entreno) y Dinero',
      'detalle', v_txt));
  end if;
  select count(*), string_agg(nombre || ' ' || coalesce(apellidos, '') || ' (desde ' || to_char(coalesce(mandato_firmado_en, created_at) at time zone 'Europe/Madrid', 'DD/MM') || ')', ', ')
    into v_n, v_txt
    from public.altas_socio
   where pago_estado = 'en_camino' and coalesce(mandato_firmado_en, created_at) < now() - interval '10 days';
  if v_n > 0 then
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'pagos:socio-en-camino', 'titulo', v_n || ' alta(s) de socio con el adeudo «en camino» desde hace más de 10 días',
      'donde', 'Panel · Socios › Altas y Dinero',
      'detalle', v_txt));
  end if;

  -- ¿Llega algo de Stripe? (el Cubo cobra todos los meses: 35 días sin nada es raro)
  select greatest(
           (select max(recibido_en) from public.pagos_eventos_stripe),
           (select max(created_at) from public.pagos where notas like 'stripe:in_%'),
           (select max(ultimo_cobro) from public.cubo_altas),
           (select max(ultimo_cobro) from public.cuotas_entreno))
    into v_ts;
  if v_ts is null or v_ts < now() - interval '35 days' then
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'pagos:stripe-silencio', 'titulo', 'No llega nada de Stripe desde hace más de 35 días',
      'donde', 'Webhooks de Stripe (cubo-webhook / pago-webhook) · todos los cobros',
      'detalle', 'Último movimiento de Stripe anotado: ' || coalesce(to_char(v_ts at time zone 'Europe/Madrid', 'DD/MM/YYYY HH24:MI'), 'ninguno')));
  end if;
  v_notas := v_notas || jsonb_build_array('Último movimiento de Stripe anotado: '
             || coalesce(to_char(v_ts at time zone 'Europe/Madrid', 'DD/MM/YYYY HH24:MI'), 'ninguno'));
  v_hecho := array_append(v_hecho, 'pagos:cobros');

  -- ----------------------------------------------------------
  -- C1 · TAREAS PROGRAMADAS (pg_cron) y sus llamadas a las Edge
  -- ----------------------------------------------------------
  if to_regclass('cron.job_run_details') is not null then
    for r in execute $q$
      select j.jobname, d.status, d.return_message, d.start_time
        from cron.job_run_details d join cron.job j on j.jobid = d.jobid
       where j.jobname like 'apolana-%' and d.status = 'failed'
         and d.start_time > now() - interval '26 hours'
       order by d.start_time desc limit 5 $q$
    loop
      v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
        'clave', 'cron:' || r.jobname, 'titulo', 'La tarea programada ' || r.jobname || ' ha fallado',
        'donde', 'pg_cron (cron.job_run_details)',
        'detalle', coalesce(r.return_message, '') || ' · ' || to_char(r.start_time at time zone 'Europe/Madrid', 'DD/MM HH24:MI')));
    end loop;
  end if;

  -- Última llamada a entreno-resync: ¿se lanzó en las últimas 26 h y respondió bien?
  select * into r from public.cron_llamadas
   where funcion = 'entreno-resync' order by creado_en desc limit 1;
  if not found then
    v_notas := v_notas || jsonb_build_array('La re-sincronización automática de cuotas todavía no se ha lanzado nunca.');
  elsif r.creado_en < now() - interval '26 hours' then
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'cron:entreno-resync-no-lanzado', 'titulo', 'La re-sincronización de cuotas no se lanza desde hace más de un día',
      'donde', 'Panel · Cuotas de entreno (los estados SEPA no se actualizan solos)',
      'detalle', 'Última llamada: ' || to_char(r.creado_en at time zone 'Europe/Madrid', 'DD/MM HH24:MI')));
  elsif r.error is not null then
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'cron:entreno-resync-error', 'titulo', 'La re-sincronización de cuotas no se ha podido lanzar',
      'donde', 'Panel · Cuotas de entreno (los estados SEPA no se actualizan solos)',
      'detalle', r.error));
  elsif to_regclass('net._http_response') is not null then
    execute 'select status_code, timed_out, error_msg, left(content, 300) from net._http_response where id = $1'
       into v_n, v_bool, v_txt, v_res_txt using r.request_id;
    if v_n is null and v_bool is null and v_txt is null then
      v_notas := v_notas || jsonb_build_array('La respuesta de la re-sincronización de hoy ya no está en net._http_response (o sigue en curso).');
    elsif coalesce(v_bool, false) or v_txt is not null or v_n not between 200 and 299 then
      v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
        'clave', 'cron:entreno-resync-respuesta', 'titulo', 'La re-sincronización de cuotas de hoy ha fallado',
        'donde', 'Panel · Cuotas de entreno (los estados SEPA no se actualizan solos)',
        'detalle', 'HTTP ' || coalesce(v_n::text, '—')
                   || case when coalesce(v_bool, false) then ' · tiempo agotado' else '' end
                   || coalesce(' · ' || v_txt, '') || coalesce(' · ' || v_res_txt, '')));
    end if;
  end if;
  v_hecho := array_append(v_hecho, 'cron');

  return jsonb_build_object('ok', jsonb_array_length(v_fallos) = 0, 'fallos', v_fallos,
                            'notas', v_notas, 'comprobado', to_jsonb(v_hecho));
exception
  when others then
    -- Si algo de la propia comprobación revienta, que se sepa.
    v_fallos := v_fallos || jsonb_build_array(jsonb_build_object(
      'clave', 'salud:interno', 'titulo', 'La comprobación diaria ha fallado por dentro',
      'donde', 'salud_comprobar()', 'detalle', sqlerrm));
    return jsonb_build_object('ok', false, 'fallos', v_fallos, 'notas', v_notas, 'comprobado', to_jsonb(v_hecho));
end;
$$;
comment on function public.salud_comprobar() is
  'Comprobación diaria de la base (mig 391): formularios simulados y deshechos, permisos, pagos y tareas pg_cron. La llama la Edge salud-diaria con service_role.';
revoke all on function public.salud_comprobar() from public, anon, authenticated;
grant execute on function public.salud_comprobar() to service_role;

-- ============================================================
-- 5 · Funciones que llama la web/app (para la comprobación de permisos)
-- ============================================================
-- Generado con herramientas/salud_rpc_front.py --sql
-- en_publica = aparece en una página que se abre sin sesión.
insert into public.salud_rpc_front (nombre, en_publica) values
  ('alta_crear_ficha', false),
  ('alta_eliminar', false),
  ('alta_enlace_familias', false),
  ('alta_examen', false),
  ('alta_marcar', false),
  ('alta_nota', false),
  ('alta_numero_entero', false),
  ('apo_apuntar_ejercicios', false),
  ('apo_faltas_avisadas', false),
  ('apo_grupos_de_atleta', false),
  ('apo_pasar_lista', false),
  ('apo_repartir_escuela', false),
  ('apo_reparto_escuela', false),
  ('atleta_pide_bienestar', false),
  ('atletas_etiquetar', false),
  ('atletas_sin_etiqueta', false),
  ('atletas_sin_etiqueta_cuantos', false),
  ('automatizacion_resumen', false),
  ('avisos_alcance', false),
  ('avisos_clave_publica', false),
  ('avisos_marcar_leido', false),
  ('avisos_personas', false),
  ('avisos_puede_enviar', false),
  ('biblioteca_usos', false),
  ('buscador_personas_resumen', false),
  ('calendario_cancelar_dia', false),
  ('calendario_club', false),
  ('calendario_reactivar_dia', false),
  ('cambio_clave_hecho', false),
  ('cobro_asistente_crear', false),
  ('cobro_asistente_datos', false),
  ('cobro_asistente_personas', false),
  ('cobro_grupo_lineas', false),
  ('comunicacion_resumen', false),
  ('conf_lista', false),
  ('conf_responder', false),
  ('conf_resumen', false),
  ('contacto_familia_atleta', false),
  ('cubo_aforos', false),
  ('cubo_alta_cambiar_grupo', false),
  ('cubo_alta_dar_plaza', false),
  ('cubo_alta_eliminar', false),
  ('cubo_alta_marcar', false),
  ('cubo_apuntarme', false),
  ('cubo_autoapuntarme', false),
  ('cubo_baja_solicitar', false),
  ('cubo_cobro_abrir', false),
  ('cubo_cobro_cancelar', false),
  ('cubo_cobro_poner', false),
  ('cubo_es_gestor', false),
  ('cubo_mis_ausencias', false),
  ('cubo_pago_externo_set', false),
  ('cubo_pausa_anular', false),
  ('cubo_pausa_mia', false),
  ('cubo_pausa_rechazar', false),
  ('cubo_pausa_solicitar', false),
  ('cubo_pausas_caducar', false),
  ('cubo_precios', true),
  ('cubo_primer_pago_set', false),
  ('cubo_prueba_aforo', true),
  ('cubo_prueba_paso', false),
  ('cuota_entreno_publica', true),
  ('debo_cambiar_clave', false),
  ('deshacer_importacion', false),
  ('dia_cancelado', false),
  ('dinero_bandeja', false),
  ('dinero_destinatarios', false),
  ('dinero_fijar_cuota', false),
  ('dinero_marcar_efectivo', false),
  ('dinero_marcar_movil', false),
  ('dinero_movimientos', false),
  ('dinero_movimientos_v2', false),
  ('dinero_pedir_cambio_cuota', false),
  ('dinero_puede_ver', false),
  ('dinero_quien_soy', false),
  ('dinero_resolver', false),
  ('domiciliaciones_escuela', false),
  ('entrenos_duplicados', false),
  ('entrenos_previstos', false),
  ('enviar_alta_escuela', true),
  ('enviar_alta_socio', true),
  ('es_admin', false),
  ('es_escuela', false),
  ('es_responsable_liga', false),
  ('es_staff', false),
  ('es_tesoreria', false),
  ('estado_cuentas', false),
  ('excepciones_rango', false),
  ('familia_edita_contacto', false),
  ('firmar_mandato_sepa', true),
  ('general_resumen', false),
  ('general_secciones', false),
  ('generar_entrenos_fijos', false),
  ('grupo_editar_datos', false),
  ('juego_es_menor', false),
  ('liga_atletas_nombres', false),
  ('liga_completar_prueba', false),
  ('liga_comunicar_prueba', true),
  ('liga_proponer_carrera', true),
  ('liga_publicar_pendientes', false),
  ('liga_publicar_propuesta', false),
  ('marcar_leidos', false),
  ('mi_cuota_entreno', false),
  ('mi_perfil_id', false),
  ('mis_avisos', false),
  ('mis_contactos_mensajes', false),
  ('mis_conversaciones', false),
  ('mis_mundos', false),
  ('mis_papeles', false),
  ('mis_secciones_responsable', false),
  ('mis_solicitudes_sin_contestar', false),
  ('mundo_stats', false),
  ('natacion_abono_set', false),
  ('natacion_acceso_de', false),
  ('natacion_alta_cuota', false),
  ('natacion_alta_desde_ficha', false),
  ('natacion_alta_ficha_faltan', false),
  ('natacion_alta_franjas', false),
  ('natacion_alta_unificada', false),
  ('natacion_buscar_fichas', false),
  ('natacion_cancelar_dia', false),
  ('natacion_cancelar_reserva', false),
  ('natacion_contacto_de', false),
  ('natacion_crear_nadador', false),
  ('natacion_dar_baja', false),
  ('natacion_dia_cancelado', false),
  ('natacion_enlazar_ficha', false),
  ('natacion_espera_apuntarse', false),
  ('natacion_espera_mias', false),
  ('natacion_espera_quitarse', false),
  ('natacion_familia_preparar', false),
  ('natacion_guardar_contacto', false),
  ('natacion_huecos', false),
  ('natacion_incorporar_manual', false),
  ('natacion_lista_dia', false),
  ('natacion_master_cancelar', false),
  ('natacion_master_disponibles', false),
  ('natacion_master_estado', false),
  ('natacion_master_no_voy', false),
  ('natacion_master_si_voy', false),
  ('natacion_master_usar_bono', false),
  ('natacion_mi_plaza', true),
  ('natacion_mis_plazas', false),
  ('natacion_pasar_lista', false),
  ('natacion_reactivar_dia', false),
  ('natacion_reservar', false),
  ('natacion_reservas_dia', false),
  ('natacion_set_direccion', false),
  ('pagos_disponible', false),
  ('pagos_resumen', false),
  ('papeles_pendientes', false),
  ('pedido_admin_estado', false),
  ('pedidos_admin_listar', false),
  ('perfil_roles_poner', false),
  ('perfil_socios_encendido', false),
  ('persona_ya_en_club', false),
  ('renovacion_responder', true),
  ('renovacion_ver', true),
  ('retos_actualizar', false),
  ('retos_progreso_atleta', false),
  ('retos_propios_historial', false),
  ('retos_propios_progreso', false),
  ('rol_activo_poner', false),
  ('rol_al_entrar_aplicar', false),
  ('rol_al_entrar_poner', false),
  ('sesion_solicitud_decidir', false),
  ('sesion_solicitudes', false),
  ('sincronizar_horarios_todos', false),
  ('soy_gestor_natacion', false),
  ('soy_responsable', false),
  ('tarifa_nueva_version', false),
  ('tengo_contrasena', false)
on conflict (nombre) do update set en_publica = excluded.en_publica;

-- ============================================================
-- 6 · Tareas programadas (pg_cron, en UTC)
-- ------------------------------------------------------------
-- Madrid es UTC+2 en verano y UTC+1 en invierno. Cada tarea se programa a las
-- 5:xx y a las 6:xx UTC y cron_llamar_edge() solo lanza la que cae a las 7 de
-- Madrid. Resultado: entreno-resync a las 7:00 y salud-diaria a las 7:30 de
-- Madrid todo el año (la salud va después para ver el resultado del resync).
-- cron.schedule con el mismo nombre actualiza la tarea (se puede re-ejecutar).
-- ============================================================
select cron.schedule(
  'apolana-entreno-resync',
  '0 5,6 * * *',
  $c$ select public.cron_llamar_edge('entreno-resync', '{"cron": true}'::jsonb, 7) $c$
);
select cron.schedule(
  'apolana-salud-diaria',
  '30 5,6 * * *',
  $c$ select public.cron_llamar_edge('salud-diaria', '{"cron": true}'::jsonb, 7) $c$
);

commit;
