-- ===========================================================================
-- 492 · Training Camps · concentraciones de equipos extranjeros en Alicante
-- ---------------------------------------------------------------------------
-- La Concejalía de Deportes deriva al club a los extranjeros que preguntan
-- por venir a entrenar a Alicante. Esto monta el expediente completo:
--   1) camp_solicitudes  · el formulario de /training-camps/ (código TC-AAAA-NNN)
--   2) camp_registro     · seguimiento: notas, comunicaciones, cambios de estado
--   3) camp_tareas       · tareas pendientes de cada expediente
--   4) camp_archivos     · adjuntos (bucket privado «training-camps»)
--   5) camp_presupuestos · presupuesto por versiones; lo que ve el cliente es
--                          una foto fija al enviarlo (enlace con token)
--   6) camp_pagos        · señal y saldo: cada uno es un recibo del libro de
--                          cobros (pagos) con token → Stripe Apolana de siempre
--                          (pagos_iniciar_recibo_token + webhook). Un trigger
--                          en pagos avisa al expediente cuando Stripe lo cobra.
--   7) camp_condiciones  · condiciones de contratación versionadas (borrador)
--   8) camp_galeria      · fotos y vídeos de la página pública
--   9) camp_config       · señal, plazos, impuestos, datos del emisor
-- Nada es público salvo: la galería visible y las condiciones (lectura). El
-- resto lo lee el admin o la Edge Function con la clave de servicio.
-- ===========================================================================
begin;

-- ---------------------------------------------------------------- 9 · ajustes
create table public.camp_config (
  id                int primary key default 1 check (id = 1),
  senal_tipo        text not null default 'porcentaje' check (senal_tipo in ('porcentaje','importe')),
  senal_valor       numeric(10,2) not null default 30 check (senal_valor >= 0),
  senal_dias_pago   int not null default 7 check (senal_dias_pago between 1 and 60),
  saldo_dias_antes  int not null default 30 check (saldo_dias_antes between 0 and 365),
  validez_dias      int not null default 15 check (validez_dias between 1 and 365),
  impuestos         jsonb not null default '[{"nombre":"IVA 21 %","pct":21},{"nombre":"IVA 10 %","pct":10},{"nombre":"Sin IVA","pct":0}]'
                    check (jsonb_typeof(impuestos) = 'array'),
  impuesto_defecto  numeric(5,2) not null default 21 check (impuesto_defecto between 0 and 100),
  nota_impuestos_en text,
  nota_impuestos_es text,
  formas_pago_en    text not null default 'Payments by card through a secure payment link (Stripe). Bank transfer on request.',
  formas_pago_es    text not null default 'Pago con tarjeta mediante enlace de pago seguro (Stripe). Transferencia bancaria bajo petición.',
  emisor            jsonb not null default jsonb_build_object(
                      'nombre', 'Club Atletismo Apolana',
                      'nif', 'G-03845500',
                      'direccion', 'C/ Hondón de las Nieves 4 (Estadio Joaquín Villar), 03005 Alicante, España',
                      'email', '',
                      'web', 'atletismoapolana.com'),
  correo_avisos     text,
  revisado          boolean not null default false,   -- false = valores de partida, sin confirmar por el club
  actualizado_en    timestamptz not null default now(),
  actualizado_por   uuid
);
insert into public.camp_config default values;
comment on table public.camp_config is 'Training Camps: señal, plazos, impuestos y datos del emisor. revisado=false mientras sean los valores de partida.';

-- ---------------------------------------------------------- 1 · expedientes
create table public.camp_contadores (anio int primary key, n int not null default 0);

create or replace function public.camp_hoy() returns date
language sql stable set search_path to 'public' as $$ select (now() at time zone 'Europe/Madrid')::date $$;

create or replace function public.camp_estado_orden(p text) returns int
language sql immutable set search_path to 'public' as $$
  select array_position(array['nueva','pendiente_info','disponibilidad','preparando','enviado','pendiente_senal',
                              'confirmada','pendiente_final','pagada','en_curso','finalizada','cancelada'], p)
$$;

create or replace function public.camp_estado_texto(p text) returns text
language sql immutable set search_path to 'public' as $$
  select case p
    when 'nueva' then 'Nueva solicitud' when 'pendiente_info' then 'Pendiente de información'
    when 'disponibilidad' then 'Estudiando disponibilidad' when 'preparando' then 'Preparando presupuesto'
    when 'enviado' then 'Presupuesto enviado' when 'pendiente_senal' then 'Pendiente de señal'
    when 'confirmada' then 'Reserva confirmada' when 'pendiente_final' then 'Pendiente de pago final'
    when 'pagada' then 'Pagada' when 'en_curso' then 'En curso' when 'finalizada' then 'Finalizada'
    when 'cancelada' then 'Cancelada' else p end
$$;

-- Importe a la española para los textos del registro: 1.500,00
create or replace function public.camp_eur(p numeric) returns text
language sql immutable set search_path to 'public' as $$
  select translate(to_char(coalesce(p, 0), 'FM999,999,990.00'), ',.', '.,')
$$;

create table public.camp_solicitudes (
  id                 uuid primary key default gen_random_uuid(),
  codigo             text not null unique,
  estado             text not null default 'nueva' check (public.camp_estado_orden(estado) is not null),
  origen             text not null default 'web' check (origen in ('web','concejalia','correo','telefono','otro')),
  idioma             text not null default 'en' check (idioma in ('en','es')),
  entidad            text not null check (btrim(entidad) <> ''),
  pais               text,
  contacto           text not null check (btrim(contacto) <> ''),
  email              text not null check (email ~* '^[^\s@]+@[^\s@]+\.[a-z]{2,}$'),
  telefono           text,
  idioma_com         text,
  idioma_com_otro    text,
  n_atletas          int check (n_atletas between 0 and 1000),
  n_entrenadores     int check (n_entrenadores between 0 and 300),
  modalidades        text[] not null default '{}',
  modalidades_otro   text,
  llegada            date,
  salida             date,
  fechas_flexibles   boolean not null default false,
  dias               text[] not null default '{}',
  horario            text[] not null default '{}',
  sesiones_dia       int check (sesiones_dia between 1 and 3),
  dividir            text check (dividir in ('yes','no','unsure')),
  grupos             int check (grupos between 2 and 10),
  grupos_detalle     text,
  instalaciones      text[] not null default '{}',
  instalaciones_otro text,
  material           text,
  gimnasio           text check (gimnasio in ('yes','no','unsure')),
  gimnasio_detalle   text,
  servicios          jsonb not null default '{}' check (jsonb_typeof(servicios) = 'object'),
  necesidades        text,
  comentarios        text,
  confirma_datos     boolean not null default false,
  privacidad_en      timestamptz,
  -- gestión
  disponibilidad_ok_en  timestamptz,
  disponibilidad_ok_por uuid,
  disponibilidad_nota   text,
  cancelado_motivo   text,
  es_prueba          boolean not null default false,
  creado_en          timestamptz not null default now(),
  creado_por         uuid,
  actualizado_en     timestamptz not null default now(),
  check (salida is null or llegada is null or salida >= llegada)
);
create index camp_solicitudes_estado on public.camp_solicitudes (estado);
create index camp_solicitudes_llegada on public.camp_solicitudes (llegada);
comment on table public.camp_solicitudes is 'Training Camps: un expediente por solicitud (formulario público o alta manual).';

create or replace function public.camp_nuevo_codigo() returns text
language plpgsql security definer set search_path to 'public' as $$
declare v_anio int := extract(year from public.camp_hoy())::int; v_n int;
begin
  insert into public.camp_contadores (anio, n) values (v_anio, 1)
  on conflict (anio) do update set n = public.camp_contadores.n + 1
  returning n into v_n;
  return 'TC-' || v_anio || '-' || lpad(v_n::text, 3, '0');
end $$;

-- --------------------------------------------------------- 2 · seguimiento
create table public.camp_registro (
  id           uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.camp_solicitudes(id) on delete cascade,
  tipo         text not null check (tipo in ('nota','comunicacion','estado','sistema','presupuesto','pago','archivo','tarea')),
  canal        text check (canal in ('email','whatsapp','telefono','reunion','videollamada','otro')),
  sentido      text check (sentido in ('entrante','saliente')),
  texto        text not null check (btrim(texto) <> ''),
  datos        jsonb,
  autor_id     uuid default auth.uid(),
  creado_en    timestamptz not null default now()
);
create index camp_registro_solicitud on public.camp_registro (solicitud_id, creado_en desc);

create table public.camp_tareas (
  id           uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.camp_solicitudes(id) on delete cascade,
  texto        text not null check (btrim(texto) <> ''),
  vence        date,
  hecha_en     timestamptz,
  hecha_por    uuid,
  auto         text,          -- tarea creada por el sistema (p. ej. 'senal'); no se duplica
  creado_por   uuid default auth.uid(),
  creado_en    timestamptz not null default now()
);
create index camp_tareas_solicitud on public.camp_tareas (solicitud_id);
create unique index camp_tareas_auto_unica on public.camp_tareas (solicitud_id, auto) where auto is not null and hecha_en is null;

create table public.camp_archivos (
  id           uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.camp_solicitudes(id) on delete cascade,
  ruta         text not null unique,      -- ruta en el bucket privado «training-camps»
  nombre       text not null,
  mime         text,
  tamano       bigint,
  descripcion  text,
  origen       text not null default 'subido' check (origen in ('subido','presupuesto')),
  subido_por   uuid default auth.uid(),
  creado_en    timestamptz not null default now()
);
create index camp_archivos_solicitud on public.camp_archivos (solicitud_id);

-- Antes de guardar: código, fecha de cambio. Después: el cambio de estado queda en el registro.
create or replace function public.camp_solicitudes_antes() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if TG_OP = 'INSERT' then
    if new.codigo is null or btrim(new.codigo) = '' then new.codigo := public.camp_nuevo_codigo(); end if;
    new.creado_por := coalesce(new.creado_por, auth.uid());
  else
    if new.codigo is distinct from old.codigo then raise exception 'El código del expediente no se cambia.'; end if;
    new.actualizado_en := now();
  end if;
  return new;
end $$;
create trigger trg_camp_solicitudes_antes before insert or update on public.camp_solicitudes
  for each row execute function public.camp_solicitudes_antes();

create or replace function public.camp_solicitudes_despues() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.camp_registro (solicitud_id, tipo, texto, datos)
    values (new.id, 'sistema',
            case new.origen when 'web' then 'Solicitud recibida por el formulario de la web'
                            else 'Expediente creado a mano (' || new.origen || ')' end,
            jsonb_build_object('estado', new.estado));
  elsif new.estado is distinct from old.estado then
    insert into public.camp_registro (solicitud_id, tipo, texto, datos)
    values (new.id, 'estado', public.camp_estado_texto(old.estado) || ' → ' || public.camp_estado_texto(new.estado),
            jsonb_build_object('de', old.estado, 'a', new.estado));
    -- Ya se ha movido: la tarea automática de «contestar» queda hecha.
    if old.estado = 'nueva' then
      update public.camp_tareas set hecha_en = now(), hecha_por = auth.uid()
       where solicitud_id = new.id and auto = 'responder' and hecha_en is null;
    end if;
  end if;
  return null;
end $$;
create trigger trg_camp_solicitudes_despues after insert or update of estado on public.camp_solicitudes
  for each row execute function public.camp_solicitudes_despues();

-- Solo avanza (nunca retrocede ni resucita una cancelada).
create or replace function public.camp_avanzar(p_id uuid, p_estado text) returns void
language plpgsql security definer set search_path to 'public' as $$
begin
  update public.camp_solicitudes set estado = p_estado
   where id = p_id and estado <> 'cancelada'
     and public.camp_estado_orden(estado) < public.camp_estado_orden(p_estado);
end $$;

create or replace function public.camp_tarea_auto(p_id uuid, p_auto text, p_texto text, p_vence date) returns void
language plpgsql security definer set search_path to 'public' as $$
begin
  insert into public.camp_tareas (solicitud_id, texto, vence, auto, creado_por)
  values (p_id, p_texto, p_vence, p_auto, null)
  on conflict (solicitud_id, auto) where auto is not null and hecha_en is null do nothing;
end $$;

-- -------------------------------------------------------- 7 · condiciones
create table public.camp_condiciones (
  version      int primary key,
  estado       text not null default 'borrador' check (estado in ('borrador','publicada','archivada')),
  texto_en     text not null,
  texto_es     text not null,
  nota         text,
  creado_por   uuid default auth.uid(),
  creado_en    timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  publicada_en timestamptz
);
create unique index camp_condiciones_una_publicada on public.camp_condiciones (estado) where estado = 'publicada';
create unique index camp_condiciones_un_borrador on public.camp_condiciones (estado) where estado = 'borrador';

-- La que rige: la publicada; si aún no hay ninguna, el borrador (y se dice).
create or replace function public.camp_condiciones_vigente() returns public.camp_condiciones
language sql stable security definer set search_path to 'public' as $$
  select * from public.camp_condiciones where estado in ('publicada','borrador')
   order by (estado = 'publicada') desc, version desc limit 1
$$;

create or replace function public.camp_condiciones_publicas() returns jsonb
language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object(
    'version', c.version, 'borrador', c.estado <> 'publicada', 'texto_en', c.texto_en, 'texto_es', c.texto_es,
    'fecha', coalesce(c.publicada_en, c.actualizado_en),
    'senal_tipo', g.senal_tipo, 'senal_valor', g.senal_valor, 'senal_dias_pago', g.senal_dias_pago,
    'saldo_dias_antes', g.saldo_dias_antes, 'validez_dias', g.validez_dias, 'emisor', g.emisor)
  from public.camp_condiciones_vigente() c, public.camp_config g where c.version is not null
$$;

-- ------------------------------------------------------- 5 · presupuestos
create table public.camp_presupuestos (
  id             uuid primary key default gen_random_uuid(),
  solicitud_id   uuid not null references public.camp_solicitudes(id) on delete cascade,
  version        int not null,
  numero         text not null unique,
  estado         text not null default 'borrador' check (estado in ('borrador','enviado','aceptado','rechazado','sustituido','anulado')),
  idioma         text not null check (idioma in ('en','es')),
  fecha          date not null default public.camp_hoy(),
  valido_hasta   date,
  titulo         text,
  llegada        date,
  salida         date,
  participantes  int,
  lineas         jsonb not null default '[]' check (jsonb_typeof(lineas) = 'array'),
  notas_cliente  text,
  notas_internas text,
  senal_tipo     text not null check (senal_tipo in ('porcentaje','importe')),
  senal_valor    numeric(10,2) not null check (senal_valor >= 0),
  saldo_vence    date,
  base           numeric(10,2) not null default 0,
  impuestos      numeric(10,2) not null default 0,
  total          numeric(10,2) not null default 0,
  senal          numeric(10,2) not null default 0,
  saldo          numeric(10,2) not null default 0,
  desglose       jsonb not null default '[]',
  coste_interno  numeric(10,2),
  token          text unique check (token is null or length(token) >= 40),
  condiciones_version int,
  enviado_en     timestamptz,
  enviado_a      text,
  aceptado_en    timestamptz,
  aceptado_nombre text,
  aceptado_por   text check (aceptado_por in ('cliente','admin')),
  aceptado_condiciones int,
  rechazado_en   timestamptz,
  motivo         text,
  creado_por     uuid default auth.uid(),
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (solicitud_id, version)
);
create index camp_presupuestos_solicitud on public.camp_presupuestos (solicitud_id);
comment on column public.camp_presupuestos.lineas is
  '[{id, categoria, descripcion, detalle, cantidad, unidad, precio (sin impuestos), iva (%), importe, coste (interno, nunca al cliente)}]';

create or replace function public.camp_categoria_ok(p text) returns boolean
language sql immutable set search_path to 'public' as $$
  select p = any (array['instalaciones','gimnasio','material','transporte','entrenadores','servicios','otros'])
$$;

-- Normaliza las líneas y calcula los totales. Precios sin impuestos; el impuesto
-- se redondea por tipo (no por línea). La señal sale del total con impuestos.
create or replace function public.camp_calcular(p_lineas jsonb, p_senal_tipo text, p_senal_valor numeric) returns jsonb
language plpgsql set search_path to 'public' as $$
declare
  l jsonb; v_out jsonb := '[]'; v_cant numeric; v_precio numeric; v_iva numeric; v_imp numeric; v_coste numeric;
  v_base numeric := 0; v_coste_tot numeric := 0; v_hay_coste boolean := false; v_tasas jsonb := '{}';
  v_desglose jsonb := '[]'; v_impuestos numeric := 0; v_total numeric; v_senal numeric; k text; n int := 0;
begin
  if jsonb_typeof(coalesce(p_lineas, '[]')) <> 'array' then raise exception 'Las líneas no son una lista.'; end if;
  for l in select * from jsonb_array_elements(coalesce(p_lineas, '[]')) loop
    n := n + 1;
    if not public.camp_categoria_ok(l->>'categoria') then raise exception 'Línea %: categoría no válida.', n; end if;
    if btrim(coalesce(l->>'descripcion', '')) = '' then raise exception 'Línea %: falta la descripción.', n; end if;
    v_cant := nullif(l->>'cantidad', '')::numeric;
    v_precio := nullif(l->>'precio', '')::numeric;
    v_iva := coalesce(nullif(l->>'iva', '')::numeric, 0);
    v_coste := nullif(l->>'coste', '')::numeric;
    if v_cant is null or v_cant <= 0 then raise exception 'Línea %: la cantidad tiene que ser mayor que 0.', n; end if;
    if v_precio is null or v_precio < 0 then raise exception 'Línea %: falta el precio unitario.', n; end if;
    if v_iva < 0 or v_iva > 100 then raise exception 'Línea %: impuesto no válido.', n; end if;
    v_imp := round(v_cant * v_precio, 2);
    v_base := v_base + v_imp;
    if v_coste is not null then v_hay_coste := true; v_coste_tot := v_coste_tot + round(v_coste, 2); end if;
    k := trim(to_char(v_iva, 'FM990.00'));
    v_tasas := jsonb_set(v_tasas, array[k], to_jsonb(coalesce((v_tasas->>k)::numeric, 0) + v_imp));
    v_out := v_out || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'id', coalesce(nullif(l->>'id', ''), gen_random_uuid()::text),
      'categoria', l->>'categoria',
      'descripcion', left(btrim(l->>'descripcion'), 300),
      'detalle', nullif(left(btrim(coalesce(l->>'detalle', '')), 600), ''),
      'cantidad', v_cant, 'unidad', nullif(left(btrim(coalesce(l->>'unidad', '')), 40), ''),
      'precio', round(v_precio, 2), 'iva', v_iva, 'importe', v_imp,
      'coste', case when v_coste is null then null else round(v_coste, 2) end)));
  end loop;
  for k in select key from jsonb_each(v_tasas) order by key::numeric desc loop
    v_desglose := v_desglose || jsonb_build_array(jsonb_build_object(
      'pct', k::numeric, 'base', (v_tasas->>k)::numeric, 'cuota', round((v_tasas->>k)::numeric * k::numeric / 100, 2)));
    v_impuestos := v_impuestos + round((v_tasas->>k)::numeric * k::numeric / 100, 2);
  end loop;
  v_total := v_base + v_impuestos;
  v_senal := case when p_senal_tipo = 'importe' then least(coalesce(p_senal_valor, 0), v_total)
                  else round(v_total * least(coalesce(p_senal_valor, 0), 100) / 100, 2) end;
  return jsonb_build_object('lineas', v_out, 'base', v_base, 'impuestos', v_impuestos, 'total', v_total,
    'senal', v_senal, 'saldo', v_total - v_senal, 'desglose', v_desglose,
    'coste_interno', case when v_hay_coste then v_coste_tot else null end);
end $$;

-- Crear / editar un presupuesto (solo en borrador). p.copiar_de = id → nueva versión a partir de otra.
create or replace function public.camp_presupuesto_guardar(p jsonb) returns public.camp_presupuestos
language plpgsql security definer set search_path to 'public' as $$
declare
  v_id uuid := nullif(p->>'id', '')::uuid; e public.camp_presupuestos; s public.camp_solicitudes; g public.camp_config;
  o public.camp_presupuestos; v_calc jsonb; v_ver int; v_tipo text; v_valor numeric;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into g from public.camp_config where id = 1;
  if v_id is not null then
    select * into e from public.camp_presupuestos where id = v_id for update;
    if e.id is null then raise exception 'Ese presupuesto no existe.'; end if;
    if e.estado <> 'borrador' then raise exception 'Este presupuesto ya se ha enviado: para cambiarlo crea una versión nueva.'; end if;
    select * into s from public.camp_solicitudes where id = e.solicitud_id;
  else
    select * into s from public.camp_solicitudes where id = nullif(p->>'solicitud_id', '')::uuid;
    if s.id is null then raise exception 'Ese expediente no existe.'; end if;
    if nullif(p->>'copiar_de', '') is not null then
      select * into o from public.camp_presupuestos where id = (p->>'copiar_de')::uuid and solicitud_id = s.id;
    end if;
  end if;
  if s.estado = 'cancelada' then raise exception 'El expediente está cancelado.'; end if;

  v_tipo := coalesce(nullif(p->>'senal_tipo', ''), e.senal_tipo, o.senal_tipo, g.senal_tipo);
  v_valor := coalesce(nullif(p->>'senal_valor', '')::numeric, e.senal_valor, o.senal_valor, g.senal_valor);
  if v_tipo not in ('porcentaje','importe') then raise exception 'Tipo de señal no válido.'; end if;
  v_calc := public.camp_calcular(coalesce(p->'lineas', e.lineas, o.lineas, '[]'), v_tipo, v_valor);

  if e.id is null then
    select coalesce(max(version), 0) + 1 into v_ver from public.camp_presupuestos where solicitud_id = s.id;
    insert into public.camp_presupuestos (solicitud_id, version, numero, idioma, valido_hasta, titulo, llegada, salida,
      participantes, notas_cliente, notas_internas, senal_tipo, senal_valor, saldo_vence)
    values (s.id, v_ver, s.codigo || '-P' || v_ver,
      coalesce(nullif(p->>'idioma', ''), o.idioma, s.idioma),
      coalesce(nullif(p->>'valido_hasta', '')::date, public.camp_hoy() + g.validez_dias),
      coalesce(nullif(p->>'titulo', ''), o.titulo),
      coalesce(nullif(p->>'llegada', '')::date, o.llegada, s.llegada),
      coalesce(nullif(p->>'salida', '')::date, o.salida, s.salida),
      coalesce(nullif(p->>'participantes', '')::int, o.participantes, coalesce(s.n_atletas, 0) + coalesce(s.n_entrenadores, 0)),
      coalesce(p->>'notas_cliente', o.notas_cliente), coalesce(p->>'notas_internas', o.notas_internas),
      v_tipo, v_valor,
      coalesce(nullif(p->>'saldo_vence', '')::date, o.saldo_vence,
               case when s.llegada is not null then greatest(s.llegada - g.saldo_dias_antes, public.camp_hoy()) end))
    returning * into e;
    insert into public.camp_registro (solicitud_id, tipo, texto, datos)
    values (s.id, 'presupuesto', 'Presupuesto ' || e.numero || ' creado' || case when o.id is not null then ' (a partir de ' || o.numero || ')' else '' end,
            jsonb_build_object('presupuesto_id', e.id));
    perform public.camp_avanzar(s.id, 'preparando');
  else
    update public.camp_presupuestos set
      idioma = coalesce(nullif(p->>'idioma', ''), idioma),
      valido_hasta = case when p ? 'valido_hasta' then nullif(p->>'valido_hasta', '')::date else valido_hasta end,
      titulo = case when p ? 'titulo' then nullif(btrim(p->>'titulo'), '') else titulo end,
      llegada = case when p ? 'llegada' then nullif(p->>'llegada', '')::date else llegada end,
      salida = case when p ? 'salida' then nullif(p->>'salida', '')::date else salida end,
      participantes = case when p ? 'participantes' then nullif(p->>'participantes', '')::int else participantes end,
      notas_cliente = case when p ? 'notas_cliente' then nullif(btrim(p->>'notas_cliente'), '') else notas_cliente end,
      notas_internas = case when p ? 'notas_internas' then nullif(btrim(p->>'notas_internas'), '') else notas_internas end,
      senal_tipo = v_tipo, senal_valor = v_valor,
      saldo_vence = case when p ? 'saldo_vence' then nullif(p->>'saldo_vence', '')::date else saldo_vence end,
      actualizado_en = now()
     where id = e.id returning * into e;
  end if;
  if e.salida is not null and e.llegada is not null and e.salida < e.llegada then raise exception 'La salida es anterior a la llegada.'; end if;

  update public.camp_presupuestos set lineas = v_calc->'lineas', base = (v_calc->>'base')::numeric,
         impuestos = (v_calc->>'impuestos')::numeric, total = (v_calc->>'total')::numeric,
         senal = (v_calc->>'senal')::numeric, saldo = (v_calc->>'saldo')::numeric, desglose = v_calc->'desglose',
         coste_interno = nullif(v_calc->>'coste_interno', '')::numeric
   where id = e.id returning * into e;
  return e;
end $$;

-- Lo marca enviado la Edge Function (con el JWT del admin) tras mandar el correo.
create or replace function public.camp_presupuesto_enviado(p_id uuid, p_email text) returns public.camp_presupuestos
language plpgsql security definer set search_path to 'public' as $$
declare e public.camp_presupuestos; v_cond int;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into e from public.camp_presupuestos where id = p_id for update;
  if e.id is null then raise exception 'Ese presupuesto no existe.'; end if;
  if e.estado not in ('borrador','enviado') then raise exception 'Este presupuesto ya no se puede enviar (está %).', e.estado; end if;
  if jsonb_array_length(e.lineas) = 0 or e.total <= 0 then raise exception 'El presupuesto no tiene importes.'; end if;
  select version into v_cond from public.camp_condiciones_vigente();
  update public.camp_presupuestos set estado = 'enviado', enviado_en = now(), enviado_a = p_email,
         token = coalesce(token, replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')),
         condiciones_version = coalesce(condiciones_version, v_cond), actualizado_en = now()
   where id = e.id returning * into e;
  -- La versión anterior enviada deja de valer.
  update public.camp_presupuestos set estado = 'sustituido', actualizado_en = now()
   where solicitud_id = e.solicitud_id and id <> e.id and estado = 'enviado';
  insert into public.camp_registro (solicitud_id, tipo, canal, sentido, texto, datos)
  values (e.solicitud_id, 'presupuesto', 'email', 'saliente',
          'Presupuesto ' || e.numero || ' enviado a ' || p_email || ' · total ' || public.camp_eur(e.total) || ' €',
          jsonb_build_object('presupuesto_id', e.id));
  perform public.camp_avanzar(e.solicitud_id, 'enviado');
  return e;
end $$;

-- Aceptado (por el cliente desde su enlace, o a mano por el admin), rechazado o anulado.
create or replace function public.camp_presupuesto_aceptado(e public.camp_presupuestos, p_por text, p_nombre text) returns void
language plpgsql security definer set search_path to 'public' as $$
declare v_cond int;
begin
  select version into v_cond from public.camp_condiciones_vigente();
  update public.camp_presupuestos set estado = 'aceptado', aceptado_en = now(), aceptado_por = p_por,
         aceptado_nombre = p_nombre, aceptado_condiciones = coalesce(condiciones_version, v_cond), actualizado_en = now()
   where id = e.id;
  update public.camp_presupuestos set estado = 'sustituido', actualizado_en = now()
   where solicitud_id = e.solicitud_id and id <> e.id and estado in ('enviado','borrador');
  insert into public.camp_registro (solicitud_id, tipo, texto, datos)
  values (e.solicitud_id, 'presupuesto',
          'Presupuesto ' || e.numero || ' ACEPTADO' || case when p_por = 'cliente' then ' por el cliente (' || coalesce(p_nombre, '') || ') desde su enlace' else ' (marcado a mano)' end,
          jsonb_build_object('presupuesto_id', e.id, 'condiciones', coalesce(e.condiciones_version, v_cond)));
  perform public.camp_avanzar(e.solicitud_id, 'pendiente_senal');
  perform public.camp_tarea_auto(e.solicitud_id, 'senal', 'Confirmar disponibilidad y enviar el enlace de la señal', public.camp_hoy() + 2);
end $$;

create or replace function public.camp_presupuesto_marcar(p_id uuid, p_estado text, p_motivo text default null) returns public.camp_presupuestos
language plpgsql security definer set search_path to 'public' as $$
declare e public.camp_presupuestos;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into e from public.camp_presupuestos where id = p_id for update;
  if e.id is null then raise exception 'Ese presupuesto no existe.'; end if;
  if p_estado = 'aceptado' then
    if e.estado not in ('enviado','borrador') then raise exception 'Solo se acepta un presupuesto enviado.'; end if;
    if e.total <= 0 then raise exception 'El presupuesto no tiene importes.'; end if;
    perform public.camp_presupuesto_aceptado(e, 'admin', nullif(btrim(coalesce(p_motivo, '')), ''));
  elsif p_estado in ('rechazado','anulado') then
    if e.estado = 'aceptado' and exists (select 1 from public.camp_pagos where presupuesto_id = e.id and anulado_en is null) then
      raise exception 'Tiene pagos pedidos: anúlalos antes.';
    end if;
    update public.camp_presupuestos set estado = p_estado, motivo = nullif(btrim(coalesce(p_motivo, '')), ''),
           rechazado_en = case when p_estado = 'rechazado' then now() else rechazado_en end, actualizado_en = now()
     where id = e.id;
    insert into public.camp_registro (solicitud_id, tipo, texto, datos)
    values (e.solicitud_id, 'presupuesto', 'Presupuesto ' || e.numero || ' ' || p_estado || coalesce(' · ' || nullif(btrim(p_motivo), ''), ''),
            jsonb_build_object('presupuesto_id', e.id));
  else
    raise exception 'Estado no válido.';
  end if;
  select * into e from public.camp_presupuestos where id = p_id;
  return e;
end $$;

-- ------------------------------------------------------------ 6 · pagos
create table public.camp_pagos (
  id             uuid primary key default gen_random_uuid(),
  solicitud_id   uuid not null references public.camp_solicitudes(id) on delete cascade,
  presupuesto_id uuid references public.camp_presupuestos(id),
  pago_id        uuid unique references public.pagos(id) on delete set null,
  tipo           text not null check (tipo in ('senal','saldo','otro')),
  concepto       text not null,
  importe        numeric(10,2) not null check (importe > 0),
  vence          date,
  token          text unique,          -- el mismo que pagos.token_pago (se conserva aunque se anule)
  enviado_en     timestamptz,
  enviado_a      text,
  anulado_en     timestamptz,
  anulado_motivo text,
  creado_por     uuid default auth.uid(),
  creado_en      timestamptz not null default now()
);
create index camp_pagos_solicitud on public.camp_pagos (solicitud_id);

-- Vista para el panel: el estado real sale del libro de cobros.
create view public.camp_pagos_v with (security_invoker = true) as
select cp.*, p.estado as pago_estado, p.fecha_pago, p.metodo, p.numero_recibo,
       case when cp.anulado_en is not null then 'anulado' when p.estado = 'pagado' then 'pagado' else 'pendiente' end as situacion
  from public.camp_pagos cp left join public.pagos p on p.id = cp.pago_id;

-- Pedir un pago (señal, saldo u otro). Crea el recibo con su enlace; NO cobra nada:
-- el cliente paga cuando abre el enlace. Lo llama la Edge Function con el JWT del admin.
create or replace function public.camp_pago_crear(p_solicitud uuid, p_tipo text, p_importe numeric default null,
                                                  p_vence date default null, p_concepto text default null) returns public.camp_pagos
language plpgsql security definer set search_path to 'public' as $$
declare
  s public.camp_solicitudes; e public.camp_presupuestos; g public.camp_config; c public.camp_pagos;
  v_importe numeric; v_vence date; v_token text; v_pago uuid; v_conc text; v_pedido numeric;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into g from public.camp_config where id = 1;
  select * into s from public.camp_solicitudes where id = p_solicitud for update;
  if s.id is null then raise exception 'Ese expediente no existe.'; end if;
  if s.estado = 'cancelada' then raise exception 'El expediente está cancelado.'; end if;
  if p_tipo not in ('senal','saldo','otro') then raise exception 'Tipo de pago no válido.'; end if;
  select * into e from public.camp_presupuestos where solicitud_id = s.id and estado = 'aceptado' order by version desc limit 1;
  if e.id is null then raise exception 'Primero tiene que haber un presupuesto aceptado.'; end if;
  if p_tipo <> 'otro' and exists (select 1 from public.camp_pagos cp left join public.pagos p on p.id = cp.pago_id
                                   where cp.solicitud_id = s.id and cp.tipo = p_tipo and cp.anulado_en is null) then
    raise exception 'Ya hay un pago de % pedido: anúlalo si quieres pedir otro.', case p_tipo when 'senal' then 'señal' else 'saldo' end;
  end if;
  select coalesce(sum(importe), 0) into v_pedido from public.camp_pagos where solicitud_id = s.id and presupuesto_id = e.id and anulado_en is null;
  v_importe := round(coalesce(p_importe, case p_tipo when 'senal' then e.senal when 'saldo' then e.total - v_pedido end), 2);
  if v_importe is null or v_importe <= 0 then raise exception 'Pon el importe.'; end if;
  if p_tipo <> 'otro' and v_pedido + v_importe > e.total then
    raise exception 'Con este pago se pediría más que el total del presupuesto (% €).', public.camp_eur(e.total);
  end if;
  v_vence := coalesce(p_vence, case p_tipo when 'senal' then public.camp_hoy() + g.senal_dias_pago
                                           when 'saldo' then coalesce(e.saldo_vence, s.llegada - g.saldo_dias_antes) end);
  if v_vence is not null and v_vence < public.camp_hoy() then v_vence := public.camp_hoy(); end if;
  v_conc := coalesce(nullif(btrim(p_concepto), ''),
    case when e.idioma = 'es' then 'Concentración ' || s.codigo || ' · ' || case p_tipo when 'senal' then 'Señal' when 'saldo' then 'Pago final' else 'Pago' end
         else 'Training camp ' || s.codigo || ' · ' || case p_tipo when 'senal' then 'Deposit' when 'saldo' then 'Final payment' else 'Payment' end end);
  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into public.pagos (atleta_id, concepto, importe, estado, fecha_vencimiento, metodo, cuenta, token_pago, notas)
  values (null, left(v_conc, 200), v_importe, 'pendiente', v_vence, 'tarjeta', 'club', v_token, 'Training camp ' || s.codigo)
  returning id into v_pago;
  insert into public.camp_pagos (solicitud_id, presupuesto_id, pago_id, tipo, concepto, importe, vence, token)
  values (s.id, e.id, v_pago, p_tipo, v_conc, v_importe, v_vence, v_token) returning * into c;
  insert into public.camp_registro (solicitud_id, tipo, texto, datos)
  values (s.id, 'pago', 'Pedido el pago «' || v_conc || '» · ' || public.camp_eur(v_importe) || ' €' ||
          coalesce(' · vence el ' || to_char(v_vence, 'DD/MM/YYYY'), ''), jsonb_build_object('camp_pago_id', c.id));
  if p_tipo = 'senal' then
    perform public.camp_avanzar(s.id, 'pendiente_senal');
    update public.camp_tareas set hecha_en = now(), hecha_por = auth.uid() where solicitud_id = s.id and auto = 'senal' and hecha_en is null;
  elsif p_tipo = 'saldo' then
    perform public.camp_avanzar(s.id, 'pendiente_final');
  end if;
  return c;
end $$;

create or replace function public.camp_pago_enviado(p_id uuid, p_email text) returns void
language plpgsql security definer set search_path to 'public' as $$
declare c public.camp_pagos;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  update public.camp_pagos set enviado_en = now(), enviado_a = p_email where id = p_id returning * into c;
  if c.id is null then raise exception 'Ese pago no existe.'; end if;
  insert into public.camp_registro (solicitud_id, tipo, canal, sentido, texto, datos)
  values (c.solicitud_id, 'pago', 'email', 'saliente', 'Enlace de pago «' || c.concepto || '» enviado a ' || p_email,
          jsonb_build_object('camp_pago_id', c.id));
end $$;

-- ¿Queda confirmada? Señal cobrada + disponibilidad aprobada. ¿Pagada? Todo lo pedido cobrado y cubre el total.
create or replace function public.camp_revisar(p_id uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
declare s public.camp_solicitudes; e public.camp_presupuestos; v_cobrado numeric; v_senal_ok boolean;
begin
  select * into s from public.camp_solicitudes where id = p_id;
  if s.id is null or s.estado = 'cancelada' then return; end if;
  select * into e from public.camp_presupuestos where solicitud_id = s.id and estado = 'aceptado' order by version desc limit 1;
  if e.id is null then return; end if;
  select coalesce(sum(cp.importe) filter (where p.estado = 'pagado'), 0),
         bool_or(cp.tipo = 'senal' and p.estado = 'pagado')
    into v_cobrado, v_senal_ok
    from public.camp_pagos cp join public.pagos p on p.id = cp.pago_id
   where cp.solicitud_id = s.id and cp.presupuesto_id = e.id and cp.anulado_en is null;
  if coalesce(v_senal_ok, false) and s.disponibilidad_ok_en is not null
     and public.camp_estado_orden(s.estado) < public.camp_estado_orden('confirmada') then
    perform public.camp_avanzar(s.id, 'confirmada');
    insert into public.camp_registro (solicitud_id, tipo, texto)
    values (s.id, 'sistema', 'Reserva confirmada: señal cobrada y disponibilidad aprobada');
  end if;
  if v_cobrado >= e.total and e.total > 0 and s.disponibilidad_ok_en is not null then
    perform public.camp_avanzar(s.id, 'pagada');
  end if;
end $$;

-- Lo dispara el libro de cobros cuando un recibo pasa a «pagado» (Stripe por el
-- webhook, la comprobación al volver de la pasarela, o un cobro a mano).
-- Nunca puede tumbar el cobro: si algo falla aquí, solo deja un aviso.
create or replace function public.camp_pago_cobrado() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare c public.camp_pagos; s public.camp_solicitudes;
begin
  select * into c from public.camp_pagos where pago_id = new.id;
  if c.id is null then return null; end if;
  begin
    select * into s from public.camp_solicitudes where id = c.solicitud_id;
    insert into public.camp_registro (solicitud_id, tipo, texto, datos, autor_id)
    values (c.solicitud_id, 'pago',
            'COBRADO «' || c.concepto || '» · ' || public.camp_eur(new.importe) || ' € · ' || coalesce(new.metodo, '—') ||
            coalesce(' · recibo ' || new.numero_recibo, ''),
            jsonb_build_object('camp_pago_id', c.id, 'pago_id', new.id), auth.uid());
    if c.tipo = 'senal' and s.disponibilidad_ok_en is null then
      perform public.camp_tarea_auto(c.solicitud_id, 'disponibilidad', 'Señal cobrada: aprobar la disponibilidad para confirmar la reserva', public.camp_hoy());
    end if;
    perform public.camp_revisar(c.solicitud_id);
  exception when others then
    raise warning '[camp_pago_cobrado] %', sqlerrm;
  end;
  return null;
end $$;
create trigger trg_pagos_camp_cobrado after update of estado on public.pagos
  for each row when (new.estado = 'pagado' and old.estado is distinct from 'pagado')
  execute function public.camp_pago_cobrado();

-- Aprobar (o retirar) la disponibilidad.
create or replace function public.camp_disponibilidad(p_id uuid, p_ok boolean, p_nota text default null) returns public.camp_solicitudes
language plpgsql security definer set search_path to 'public' as $$
declare s public.camp_solicitudes;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  update public.camp_solicitudes set
         disponibilidad_ok_en = case when p_ok then coalesce(disponibilidad_ok_en, now()) end,
         disponibilidad_ok_por = case when p_ok then coalesce(disponibilidad_ok_por, auth.uid()) end,
         disponibilidad_nota = nullif(btrim(coalesce(p_nota, '')), '')
   where id = p_id returning * into s;
  if s.id is null then raise exception 'Ese expediente no existe.'; end if;
  insert into public.camp_registro (solicitud_id, tipo, texto)
  values (s.id, 'sistema', case when p_ok then 'Disponibilidad APROBADA' else 'Disponibilidad retirada' end ||
          coalesce(' · ' || s.disponibilidad_nota, ''));
  if p_ok then
    update public.camp_tareas set hecha_en = now(), hecha_por = auth.uid() where solicitud_id = s.id and auto = 'disponibilidad' and hecha_en is null;
    perform public.camp_revisar(s.id);
  end if;
  select * into s from public.camp_solicitudes where id = p_id;
  return s;
end $$;

-- Cobro recibido por otra vía (transferencia, efectivo…): queda en el libro de cobros.
create or replace function public.camp_pago_manual(p_id uuid, p_metodo text, p_fecha date default null, p_nota text default null) returns void
language plpgsql security definer set search_path to 'public' as $$
declare c public.camp_pagos;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if p_metodo not in ('transferencia','efectivo','tarjeta','otro') then raise exception 'Forma de pago no válida.'; end if;
  select * into c from public.camp_pagos where id = p_id;
  if c.id is null or c.pago_id is null then raise exception 'Ese pago no existe.'; end if;
  if c.anulado_en is not null then raise exception 'Ese pago está anulado.'; end if;
  update public.pagos set estado = 'pagado', metodo = p_metodo, fecha_pago = coalesce(p_fecha, public.camp_hoy())
   where id = c.pago_id and estado <> 'pagado';
  if not found then raise exception 'Ese pago ya estaba cobrado.'; end if;
  if nullif(btrim(coalesce(p_nota, '')), '') is not null then
    insert into public.camp_registro (solicitud_id, tipo, texto) values (c.solicitud_id, 'nota', 'Cobro a mano: ' || btrim(p_nota));
  end if;
end $$;

-- Anular un pago pedido que aún no se ha cobrado: el enlace deja de funcionar
-- y el recibo pendiente sale del libro de cobros (no tenía número: no se emitió).
create or replace function public.camp_pago_anular(p_id uuid, p_motivo text) returns void
language plpgsql security definer set search_path to 'public' as $$
declare c public.camp_pagos; v_estado text;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if btrim(coalesce(p_motivo, '')) = '' then raise exception 'Escribe el motivo.'; end if;
  select * into c from public.camp_pagos where id = p_id for update;
  if c.id is null then raise exception 'Ese pago no existe.'; end if;
  if c.anulado_en is not null then return; end if;
  select estado into v_estado from public.pagos where id = c.pago_id for update;
  if v_estado = 'pagado' then raise exception 'Ese pago ya está cobrado: la devolución se hace en Stripe y se anota en el expediente.'; end if;
  update public.camp_pagos set anulado_en = now(), anulado_motivo = btrim(p_motivo), pago_id = null where id = c.id;
  delete from public.pagos where id = c.pago_id and estado <> 'pagado' and numero_recibo is null;
  insert into public.camp_registro (solicitud_id, tipo, texto, datos)
  values (c.solicitud_id, 'pago', 'Anulado el pago «' || c.concepto || '» · ' || btrim(p_motivo), jsonb_build_object('camp_pago_id', c.id));
end $$;

-- Cancelar el expediente: los pagos pendientes se anulan (lo cobrado se queda: devolución en Stripe).
create or replace function public.camp_cancelar(p_id uuid, p_motivo text) returns void
language plpgsql security definer set search_path to 'public' as $$
declare c record;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if btrim(coalesce(p_motivo, '')) = '' then raise exception 'Escribe el motivo.'; end if;
  for c in select cp.id from public.camp_pagos cp left join public.pagos p on p.id = cp.pago_id
            where cp.solicitud_id = p_id and cp.anulado_en is null and coalesce(p.estado, '') <> 'pagado' loop
    perform public.camp_pago_anular(c.id, 'Expediente cancelado');
  end loop;
  update public.camp_presupuestos set estado = 'anulado', motivo = 'Expediente cancelado', actualizado_en = now()
   where solicitud_id = p_id and estado in ('borrador','enviado');
  update public.camp_solicitudes set estado = 'cancelada', cancelado_motivo = btrim(p_motivo) where id = p_id;
  update public.camp_tareas set hecha_en = now(), hecha_por = auth.uid() where solicitud_id = p_id and auto is not null and hecha_en is null;
end $$;

-- ------------------------------------------- funciones solo para la Edge Function pública
-- (clave de servicio; no se abren a anon ni a authenticated)
create or replace function public.camp_solicitud_crear(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare s public.camp_solicitudes;
begin
  insert into public.camp_solicitudes (origen, idioma, entidad, pais, contacto, email, telefono, idioma_com, idioma_com_otro,
    n_atletas, n_entrenadores, modalidades, modalidades_otro, llegada, salida, fechas_flexibles, dias, horario, sesiones_dia,
    dividir, grupos, grupos_detalle, instalaciones, instalaciones_otro, material, gimnasio, gimnasio_detalle, servicios,
    necesidades, comentarios, confirma_datos, privacidad_en)
  values ('web', coalesce(nullif(p->>'lang', ''), 'en'), p->>'entidad', nullif(p->>'pais', ''), p->>'contacto', lower(p->>'email'),
    nullif(p->>'telefono', ''), nullif(p->>'idioma_com', ''), nullif(p->>'idioma_com_otro', ''),
    nullif(p->>'n_atletas', '')::int, nullif(p->>'n_entrenadores', '')::int,
    coalesce(array(select jsonb_array_elements_text(p->'modalidades')), '{}'), nullif(p->>'modalidades_otro', ''),
    nullif(p->>'llegada', '')::date, nullif(p->>'salida', '')::date, coalesce((p->>'fechas_flexibles')::boolean, false),
    coalesce(array(select jsonb_array_elements_text(p->'dias')), '{}'), coalesce(array(select jsonb_array_elements_text(p->'horario')), '{}'),
    nullif(p->>'sesiones_dia', '')::int, nullif(p->>'dividir', ''), nullif(p->>'grupos', '')::int, nullif(p->>'grupos_detalle', ''),
    coalesce(array(select jsonb_array_elements_text(p->'instalaciones')), '{}'), nullif(p->>'instalaciones_otro', ''),
    nullif(p->>'material', ''), nullif(p->>'gimnasio', ''), nullif(p->>'gimnasio_detalle', ''), coalesce(p->'servicios', '{}'),
    nullif(p->>'necesidades', ''), nullif(p->>'comentarios', ''), true, now())
  returning * into s;
  perform public.camp_tarea_auto(s.id, 'responder', 'Contestar a la solicitud y estudiar disponibilidad', public.camp_hoy() + 2);
  return jsonb_build_object('id', s.id, 'codigo', s.codigo);
end $$;

-- Lo que ve el cliente de su presupuesto (sin costes internos ni notas internas).
create or replace function public.camp_propuesta_publica(p_token text) returns jsonb
language plpgsql stable security definer set search_path to 'public' as $$
declare e public.camp_presupuestos; s public.camp_solicitudes; g public.camp_config; v_actual text;
begin
  if length(coalesce(p_token, '')) < 40 then return null; end if;
  select * into e from public.camp_presupuestos where token = p_token;
  if e.id is null then return null; end if;
  select * into s from public.camp_solicitudes where id = e.solicitud_id;
  select * into g from public.camp_config where id = 1;
  select token into v_actual from public.camp_presupuestos
   where solicitud_id = e.solicitud_id and estado in ('enviado','aceptado') and id <> e.id and token is not null
   order by version desc limit 1;
  return jsonb_build_object(
    'numero', e.numero, 'version', e.version, 'estado', e.estado, 'idioma', e.idioma, 'fecha', e.fecha,
    'valido_hasta', e.valido_hasta, 'caducado', e.estado = 'enviado' and e.valido_hasta is not null and e.valido_hasta < public.camp_hoy(),
    'titulo', e.titulo, 'llegada', e.llegada, 'salida', e.salida, 'participantes', e.participantes,
    'lineas', (select coalesce(jsonb_agg(l - 'coste' - 'id'), '[]') from jsonb_array_elements(e.lineas) l),
    'base', e.base, 'impuestos', e.impuestos, 'total', e.total, 'senal', e.senal, 'saldo', e.saldo,
    'senal_tipo', e.senal_tipo, 'senal_valor', e.senal_valor, 'saldo_vence', e.saldo_vence, 'desglose', e.desglose,
    'notas_cliente', e.notas_cliente, 'condiciones_version', coalesce(e.aceptado_condiciones, e.condiciones_version),
    'aceptado_en', e.aceptado_en, 'aceptado_nombre', e.aceptado_nombre, 'aceptado_por', e.aceptado_por,
    'sustituido_por', case when e.estado = 'sustituido' then v_actual end,
    'expediente', jsonb_build_object('codigo', s.codigo, 'entidad', s.entidad, 'contacto', s.contacto, 'pais', s.pais,
                                     'email', s.email, 'cancelado', s.estado = 'cancelada'),
    'emisor', g.emisor, 'nota_impuestos', case when e.idioma = 'es' then g.nota_impuestos_es else g.nota_impuestos_en end,
    'formas_pago', case when e.idioma = 'es' then g.formas_pago_es else g.formas_pago_en end,
    'pagos', (select coalesce(jsonb_agg(jsonb_build_object('tipo', cp.tipo, 'concepto', cp.concepto, 'importe', cp.importe,
                'vence', cp.vence, 'pagado', p.estado = 'pagado', 'fecha_pago', p.fecha_pago,
                'token', case when p.estado <> 'pagado' then cp.token end) order by cp.creado_en), '[]')
              from public.camp_pagos cp join public.pagos p on p.id = cp.pago_id
             where cp.presupuesto_id = e.id and cp.anulado_en is null));
end $$;

create or replace function public.camp_propuesta_aceptar(p_token text, p_nombre text) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare e public.camp_presupuestos; s public.camp_solicitudes;
begin
  if length(coalesce(p_token, '')) < 40 then return jsonb_build_object('ok', false, 'error', 'enlace'); end if;
  if btrim(coalesce(p_nombre, '')) = '' then return jsonb_build_object('ok', false, 'error', 'nombre'); end if;
  select * into e from public.camp_presupuestos where token = p_token for update;
  if e.id is null then return jsonb_build_object('ok', false, 'error', 'enlace'); end if;
  select * into s from public.camp_solicitudes where id = e.solicitud_id;
  if e.estado = 'aceptado' then return jsonb_build_object('ok', true, 'repetido', true); end if;
  if s.estado = 'cancelada' or e.estado <> 'enviado' then return jsonb_build_object('ok', false, 'error', 'estado', 'estado', e.estado); end if;
  if e.valido_hasta is not null and e.valido_hasta < public.camp_hoy() then return jsonb_build_object('ok', false, 'error', 'caducado'); end if;
  perform public.camp_presupuesto_aceptado(e, 'cliente', left(btrim(p_nombre), 120));
  return jsonb_build_object('ok', true, 'numero', e.numero, 'codigo', s.codigo, 'entidad', s.entidad, 'total', e.total,
                            'solicitud_id', s.id);
end $$;

-- Para la página de pago (/training-camps/pay/?t=…).
create or replace function public.camp_pago_publico(p_token text) returns jsonb
language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object('tipo', cp.tipo, 'concepto', cp.concepto, 'importe', cp.importe, 'vence', cp.vence,
    'anulado', cp.anulado_en is not null, 'pagado', coalesce(p.estado = 'pagado', false), 'fecha_pago', p.fecha_pago,
    'codigo', s.codigo, 'entidad', s.entidad, 'email', s.email, 'idioma', coalesce(e.idioma, s.idioma),
    'presupuesto', e.numero, 'propuesta_token', e.token, 'total', e.total, 'llegada', s.llegada, 'salida', s.salida,
    'cancelado', s.estado = 'cancelada', 'emisor', (select emisor from public.camp_config where id = 1))
  from public.camp_pagos cp
  join public.camp_solicitudes s on s.id = cp.solicitud_id
  left join public.camp_presupuestos e on e.id = cp.presupuesto_id
  left join public.pagos p on p.id = cp.pago_id
  where length(coalesce(p_token, '')) >= 40 and cp.token = p_token
$$;

-- --------------------------------------------------------------- 8 · galería
create table public.camp_galeria (
  id        uuid primary key default gen_random_uuid(),
  tipo      text not null check (tipo in ('foto','video','enlace')),
  url       text not null check (url ~ '^https://'),
  ruta      text,                         -- si se subió al bucket «training-camps-galeria»
  titulo_en text,
  titulo_es text,
  orden     int not null default 0,
  visible   boolean not null default true,
  creado_en timestamptz not null default now()
);

-- ------------------------------------------------------------- ajustes (admin)
create or replace function public.camp_config_guardar(p jsonb) returns public.camp_config
language plpgsql security definer set search_path to 'public' as $$
declare g public.camp_config;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  update public.camp_config set
    senal_tipo = coalesce(nullif(p->>'senal_tipo', ''), senal_tipo),
    senal_valor = coalesce(nullif(p->>'senal_valor', '')::numeric, senal_valor),
    senal_dias_pago = coalesce(nullif(p->>'senal_dias_pago', '')::int, senal_dias_pago),
    saldo_dias_antes = coalesce(nullif(p->>'saldo_dias_antes', '')::int, saldo_dias_antes),
    validez_dias = coalesce(nullif(p->>'validez_dias', '')::int, validez_dias),
    impuestos = coalesce(p->'impuestos', impuestos),
    impuesto_defecto = coalesce(nullif(p->>'impuesto_defecto', '')::numeric, impuesto_defecto),
    nota_impuestos_en = case when p ? 'nota_impuestos_en' then nullif(btrim(p->>'nota_impuestos_en'), '') else nota_impuestos_en end,
    nota_impuestos_es = case when p ? 'nota_impuestos_es' then nullif(btrim(p->>'nota_impuestos_es'), '') else nota_impuestos_es end,
    formas_pago_en = coalesce(nullif(btrim(p->>'formas_pago_en'), ''), formas_pago_en),
    formas_pago_es = coalesce(nullif(btrim(p->>'formas_pago_es'), ''), formas_pago_es),
    emisor = case when jsonb_typeof(p->'emisor') = 'object' then emisor || (p->'emisor') else emisor end,
    correo_avisos = case when p ? 'correo_avisos' then nullif(btrim(p->>'correo_avisos'), '') else correo_avisos end,
    revisado = coalesce((p->>'revisado')::boolean, revisado),
    actualizado_en = now(), actualizado_por = auth.uid()
  where id = 1 returning * into g;
  if g.senal_tipo = 'porcentaje' and g.senal_valor > 100 then raise exception 'La señal no puede pasar del 100 %%.'; end if;
  return g;
end $$;

create or replace function public.camp_condiciones_guardar(p_texto_en text, p_texto_es text, p_nota text default null) returns public.camp_condiciones
language plpgsql security definer set search_path to 'public' as $$
declare c public.camp_condiciones;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if btrim(coalesce(p_texto_en, '')) = '' or btrim(coalesce(p_texto_es, '')) = '' then raise exception 'Faltan los textos.'; end if;
  update public.camp_condiciones set texto_en = p_texto_en, texto_es = p_texto_es, nota = nullif(btrim(coalesce(p_nota, '')), ''),
         actualizado_en = now() where estado = 'borrador' returning * into c;
  if c.version is null then
    insert into public.camp_condiciones (version, estado, texto_en, texto_es, nota)
    values ((select coalesce(max(version), 0) + 1 from public.camp_condiciones), 'borrador', p_texto_en, p_texto_es,
            nullif(btrim(coalesce(p_nota, '')), '')) returning * into c;
  end if;
  return c;
end $$;

create or replace function public.camp_condiciones_publicar() returns public.camp_condiciones
language plpgsql security definer set search_path to 'public' as $$
declare c public.camp_condiciones;
begin
  if not public.es_admin() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into c from public.camp_condiciones where estado = 'borrador';
  if c.version is null then raise exception 'No hay borrador que publicar.'; end if;
  update public.camp_condiciones set estado = 'archivada' where estado = 'publicada';
  update public.camp_condiciones set estado = 'publicada', publicada_en = now() where version = c.version returning * into c;
  return c;
end $$;

-- ------------------------------------------- borrador v1 de las condiciones
-- {senal} {senal_dias} {saldo_dias} {validez_dias} se rellenan con los ajustes al mostrarlas.
-- BORRADOR pendiente de asesoría: las cifras de cancelación son una propuesta.
insert into public.camp_condiciones (version, estado, creado_por, nota, texto_en, texto_es) values (1, 'borrador', null,
'Borrador inicial (29-oct-2026). Pendiente de revisar por el club y por la asesoría: escala de cancelación (60 días / plazo del saldo), seguros exigidos y protección de datos.',
$en$## 1. Who we are
These booking conditions apply to the training camps organised by Club Atletismo Apolana (NIF G-03845500), C/ Hondón de las Nieves 4 (Estadio Joaquín Villar), 03005 Alicante, Spain ("the Club"), for clubs, teams, organisations and groups ("the Client").

## 2. Requests and availability
- Sending a request does not create a booking. Facilities, time slots and services are always subject to availability.
- The time slots shown on our website are indicative. The final schedule is the one stated in the accepted proposal.
- Facilities not owned by the Club, such as the Estadio Joaquín Villar (a municipal facility), are used in accordance with the availability and rules set by their owner.

## 3. Proposal and acceptance
- Each proposal is tailor-made and valid until the date stated on it (by default, {validez_dias} days).
- The Client accepts a proposal online through its link or in writing. Accepting a proposal means accepting these conditions in the version stated on it.

## 4. Confirmation and payments
- The booking is confirmed when (a) the Client has accepted the proposal, (b) the deposit has been received and verified, and (c) the Club has confirmed availability in writing.
- Deposit: {senal} of the total, payable within {senal_dias} days of the payment request.
- Balance: the remaining amount must be paid no later than {saldo_dias} days before the arrival date, or by the date stated on the proposal.
- Payments are made by card through a secure payment link (Stripe), or by bank transfer when agreed. Any bank charges are borne by the Client.
- If the balance is not paid on time, the Club may cancel the booking and section 6 will apply.

## 5. Changes
- Changes to dates, number of participants or services must be requested in writing. They are subject to availability and may change the price; the Club will send an updated proposal.
- A reduction in the number of participants notified less than {saldo_dias} days before arrival does not reduce the price, unless the service affected can still be cancelled at no cost to the Club.

## 6. Cancellation by the Client
Cancellations must be notified in writing. The following applies:
- More than 60 days before arrival: the deposit is refunded, less any non-refundable costs already incurred with third parties on the Client's behalf (with supporting documents).
- Between 60 and {saldo_dias} days before arrival: the deposit is retained.
- Less than {saldo_dias} days before arrival, or no-show: the amounts paid are not refunded, except for services the Club can still cancel at no cost.
- Services not used during the camp (sessions not attended, early departure) are not refunded.

## 7. Cancellation or changes by the Club
If the Club cannot provide a confirmed service for reasons attributable to it, it will offer an equivalent alternative or refund the amount corresponding to the service not provided. The Club is not liable for other costs (flights, travel or accommodation booked directly by the Client), except where the law provides otherwise.

## 8. Force majeure
Neither party is liable for failing to perform due to circumstances beyond its reasonable control, such as extreme weather, closure of facilities by the authorities, health emergencies, strikes or natural disasters. In that case the parties will try to reschedule; if that is not possible, the Club will refund the amounts paid for services not provided, less non-recoverable costs already incurred.

## 9. Use of the facilities, sports and safety rules
- Participants must follow the rules of each facility, the instructions of the Club's staff and of the facility staff, and all safety rules, particularly in throwing events and strength training.
- The Client's coaches and staff are responsible for supervising their athletes at all times.
- The Club may refuse access to, or remove, anyone whose behaviour puts people or facilities at risk.

## 10. Damage
The Client is responsible for any damage caused by its participants to facilities, equipment or third parties, beyond normal wear and tear.

## 11. Insurance and health
- All participants must have valid medical and accident insurance covering sports practice in Spain, and the Client must have civil liability insurance where applicable. Participants entitled to it should also carry their EHIC/GHIC card.
- The Client declares that the participants are fit to train and will inform the Club of any relevant health condition.

## 12. Services provided by third parties
Transport, accommodation, meals, physiotherapy and other services may be provided by third parties. The Club arranges them on the Client's behalf and will help with any incident, but each provider is responsible for its own service under its own conditions.

## 13. Minors
Groups that include minors must travel with responsible adults from the Client, who are in charge of them throughout the camp. The Client guarantees that it holds the authorisations required from parents or guardians.

## 14. Photos and videos
The Club will only take photos or videos of the sessions for its own communication channels with the Client's consent. The Client may ask for specific participants not to be photographed.

## 15. Personal data
The Club processes the data provided to manage the request and the camp (pre-contractual and contractual basis) and keeps them for as long as the law requires. They are only shared with the providers needed for the services requested. You can exercise your rights of access, rectification, erasure, objection, restriction and portability by writing to the Club. More information in the privacy policy at atletismoapolana.com.

## 16. Applicable law
These conditions are governed by Spanish law. Any dispute will be submitted to the courts of Alicante, without prejudice to mandatory consumer protection rules where applicable. If the English and Spanish versions differ, the Spanish version prevails.$en$,
$es$## 1. Quiénes somos
Estas condiciones se aplican a las concentraciones deportivas que organiza el Club Atletismo Apolana (NIF G-03845500), C/ Hondón de las Nieves 4 (Estadio Joaquín Villar), 03005 Alicante, España («el Club»), para clubes, equipos, entidades y grupos («el Cliente»).

## 2. Solicitudes y disponibilidad
- Enviar una solicitud no supone una reserva. Las instalaciones, los horarios y los servicios están siempre sujetos a disponibilidad.
- Los horarios que aparecen en la web son orientativos. El horario definitivo es el que figura en el presupuesto aceptado.
- Las instalaciones que no son del Club, como el Estadio Joaquín Villar (instalación municipal), se usan según la disponibilidad y las normas que fije su titular.

## 3. Presupuesto y aceptación
- Cada presupuesto es personalizado y es válido hasta la fecha que indica (por defecto, {validez_dias} días).
- El Cliente acepta el presupuesto desde su enlace o por escrito. Aceptarlo supone aceptar estas condiciones en la versión que figura en él.

## 4. Confirmación y pagos
- La reserva queda confirmada cuando (a) el Cliente ha aceptado el presupuesto, (b) se ha recibido y comprobado el pago de la señal y (c) el Club ha confirmado la disponibilidad por escrito.
- Señal: {senal} del total, a pagar en un plazo de {senal_dias} días desde que se solicita el pago.
- Resto: el importe pendiente se paga como muy tarde {saldo_dias} días antes de la fecha de llegada, o en la fecha que indique el presupuesto.
- Los pagos se hacen con tarjeta mediante un enlace de pago seguro (Stripe) o por transferencia bancaria si se acuerda. Las comisiones bancarias, si las hay, corren a cargo del Cliente.
- Si el resto no se paga a tiempo, el Club puede cancelar la reserva y se aplicará el apartado 6.

## 5. Modificaciones
- Los cambios de fechas, de número de participantes o de servicios se piden por escrito. Están sujetos a disponibilidad y pueden cambiar el precio; el Club enviará un presupuesto actualizado.
- Una reducción del número de participantes comunicada con menos de {saldo_dias} días de antelación no reduce el precio, salvo que el servicio afectado se pueda cancelar todavía sin coste para el Club.

## 6. Cancelación por parte del Cliente
Las cancelaciones se comunican por escrito. Se aplica lo siguiente:
- Más de 60 días antes de la llegada: se devuelve la señal, descontando los gastos no reembolsables ya realizados con terceros por cuenta del Cliente (con justificante).
- Entre 60 y {saldo_dias} días antes de la llegada: se retiene la señal.
- Menos de {saldo_dias} días antes de la llegada, o no presentarse: no se devuelven los importes pagados, salvo los servicios que el Club pueda cancelar todavía sin coste.
- Los servicios no utilizados durante la concentración (sesiones a las que no se asiste, salida anticipada) no se devuelven.

## 7. Cancelación o cambios por parte del Club
Si el Club no puede prestar un servicio confirmado por causas que le sean imputables, ofrecerá una alternativa equivalente o devolverá el importe del servicio no prestado. El Club no responde de otros gastos (vuelos, viajes o alojamientos contratados directamente por el Cliente), salvo que la ley disponga otra cosa.

## 8. Fuerza mayor
Ninguna de las partes responde de un incumplimiento debido a circunstancias ajenas a su control razonable, como fenómenos meteorológicos extremos, el cierre de instalaciones por las autoridades, emergencias sanitarias, huelgas o catástrofes naturales. En ese caso las partes intentarán buscar nuevas fechas; si no es posible, el Club devolverá lo pagado por los servicios no prestados, descontando los gastos ya realizados que no se puedan recuperar.

## 9. Uso de las instalaciones y normas deportivas y de seguridad
- Los participantes deben cumplir las normas de cada instalación, las indicaciones del personal del Club y de la instalación, y todas las normas de seguridad, en especial en lanzamientos y en el entrenamiento de fuerza.
- Los entrenadores y el personal del Cliente son responsables de supervisar a sus deportistas en todo momento.
- El Club puede denegar el acceso o pedir que abandone la instalación a cualquier persona cuyo comportamiento ponga en riesgo a las personas o las instalaciones.

## 10. Daños
El Cliente responde de los daños que sus participantes causen en las instalaciones, el material o a terceros, más allá del desgaste normal por el uso.

## 11. Seguros y salud
- Todos los participantes deben tener un seguro médico y de accidentes en vigor que cubra la práctica deportiva en España, y el Cliente un seguro de responsabilidad civil cuando proceda. Quienes tengan derecho a ella deben llevar también su tarjeta sanitaria europea (EHIC/GHIC).
- El Cliente declara que los participantes están en condiciones de entrenar y comunicará al Club cualquier circunstancia de salud relevante.

## 12. Servicios prestados por terceros
El transporte, el alojamiento, las comidas, la fisioterapia y otros servicios pueden prestarlos terceros. El Club los gestiona por cuenta del Cliente y le ayudará ante cualquier incidencia, pero cada proveedor responde de su propio servicio según sus condiciones.

## 13. Menores
Los grupos con menores deben viajar acompañados de adultos responsables del Cliente, que se hacen cargo de ellos durante toda la concentración. El Cliente garantiza que cuenta con las autorizaciones necesarias de padres, madres o tutores.

## 14. Fotos y vídeos
El Club solo tomará fotos o vídeos de las sesiones para sus propios canales de comunicación con el consentimiento del Cliente. El Cliente puede pedir que no se fotografíe a determinados participantes.

## 15. Datos personales
El Club trata los datos facilitados para gestionar la solicitud y la concentración (base precontractual y contractual) y los conserva durante el tiempo que exige la ley. Solo se comunican a los proveedores necesarios para los servicios solicitados. Puedes ejercer tus derechos de acceso, rectificación, supresión, oposición, limitación y portabilidad escribiendo al Club. Más información en la política de privacidad de atletismoapolana.com.

## 16. Ley aplicable
Estas condiciones se rigen por la ley española. Cualquier controversia se someterá a los juzgados de Alicante, sin perjuicio de las normas imperativas de protección de los consumidores cuando sean de aplicación. Si las versiones en inglés y en castellano no coinciden, prevalece la versión en castellano.$es$);

-- ----------------------------------------------------------------- permisos
alter table public.camp_config enable row level security;
alter table public.camp_contadores enable row level security;
alter table public.camp_solicitudes enable row level security;
alter table public.camp_registro enable row level security;
alter table public.camp_tareas enable row level security;
alter table public.camp_archivos enable row level security;
alter table public.camp_presupuestos enable row level security;
alter table public.camp_pagos enable row level security;
alter table public.camp_condiciones enable row level security;
alter table public.camp_galeria enable row level security;

revoke all on public.camp_config, public.camp_contadores, public.camp_solicitudes, public.camp_registro, public.camp_tareas,
  public.camp_archivos, public.camp_presupuestos, public.camp_pagos, public.camp_condiciones, public.camp_galeria,
  public.camp_pagos_v from public, anon, authenticated;

grant select on public.camp_config, public.camp_condiciones, public.camp_pagos, public.camp_pagos_v to authenticated;
grant select, insert, update on public.camp_solicitudes to authenticated;
grant select, insert, update, delete on public.camp_registro, public.camp_tareas, public.camp_archivos, public.camp_galeria to authenticated;
grant select on public.camp_presupuestos to authenticated;
grant select on public.camp_galeria to anon;

create policy "camp: admin" on public.camp_config for select to authenticated using ((select public.es_admin()));
create policy "camp: admin" on public.camp_solicitudes for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy "camp: admin" on public.camp_registro for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy "camp: admin" on public.camp_tareas for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy "camp: admin" on public.camp_archivos for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy "camp: admin" on public.camp_presupuestos for select to authenticated using ((select public.es_admin()));
create policy "camp: admin" on public.camp_pagos for select to authenticated using ((select public.es_admin()));
create policy "camp: admin" on public.camp_condiciones for select to authenticated using ((select public.es_admin()));
create policy "camp: admin" on public.camp_galeria for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy "camp: galería visible" on public.camp_galeria for select to anon, authenticated using (visible);

-- Funciones: las del panel, a authenticated (comprueban es_admin dentro); las
-- de la página pública, solo a la clave de servicio; las condiciones, a todos.
revoke execute on function
  public.camp_nuevo_codigo(), public.camp_avanzar(uuid, text), public.camp_tarea_auto(uuid, text, text, date),
  public.camp_condiciones_vigente(), public.camp_condiciones_publicas(), public.camp_calcular(jsonb, text, numeric),
  public.camp_presupuesto_guardar(jsonb), public.camp_presupuesto_enviado(uuid, text),
  public.camp_presupuesto_aceptado(public.camp_presupuestos, text, text), public.camp_presupuesto_marcar(uuid, text, text),
  public.camp_pago_crear(uuid, text, numeric, date, text), public.camp_pago_enviado(uuid, text), public.camp_revisar(uuid),
  public.camp_disponibilidad(uuid, boolean, text), public.camp_pago_manual(uuid, text, date, text),
  public.camp_pago_anular(uuid, text), public.camp_cancelar(uuid, text), public.camp_solicitud_crear(jsonb),
  public.camp_propuesta_publica(text), public.camp_propuesta_aceptar(text, text), public.camp_pago_publico(text),
  public.camp_config_guardar(jsonb), public.camp_condiciones_guardar(text, text, text), public.camp_condiciones_publicar()
  from public, anon, authenticated;
grant execute on function
  public.camp_calcular(jsonb, text, numeric), public.camp_presupuesto_guardar(jsonb), public.camp_presupuesto_enviado(uuid, text),
  public.camp_presupuesto_marcar(uuid, text, text), public.camp_pago_crear(uuid, text, numeric, date, text),
  public.camp_pago_enviado(uuid, text), public.camp_disponibilidad(uuid, boolean, text), public.camp_pago_manual(uuid, text, date, text),
  public.camp_pago_anular(uuid, text), public.camp_cancelar(uuid, text), public.camp_config_guardar(jsonb),
  public.camp_condiciones_guardar(text, text, text), public.camp_condiciones_publicar()
  to authenticated;
grant execute on function public.camp_condiciones_publicas() to anon, authenticated;
grant execute on function public.camp_solicitud_crear(jsonb), public.camp_propuesta_publica(text),
  public.camp_propuesta_aceptar(text, text), public.camp_pago_publico(text) to service_role;

-- ----------------------------------------------------------------- buckets
insert into storage.buckets (id, name, public, file_size_limit)
values ('training-camps', 'training-camps', false, 26214400)
on conflict (id) do nothing;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('training-camps-galeria', 'training-camps-galeria', true, 52428800,
        array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime'])
on conflict (id) do nothing;

create policy "training-camps: solo admin" on storage.objects for all to authenticated
  using (bucket_id in ('training-camps','training-camps-galeria') and (select public.es_admin()))
  with check (bucket_id in ('training-camps','training-camps-galeria') and (select public.es_admin()));
create policy "training-camps: candado lectura" on storage.objects as restrictive for select to public
  using (bucket_id <> 'training-camps' or (select public.es_admin()));
create policy "training-camps: candado subida" on storage.objects as restrictive for insert to public
  with check (bucket_id not in ('training-camps','training-camps-galeria') or (select public.es_admin()));
create policy "training-camps: candado cambio" on storage.objects as restrictive for update to public
  using (bucket_id not in ('training-camps','training-camps-galeria') or (select public.es_admin()));
create policy "training-camps: candado borrado" on storage.objects as restrictive for delete to public
  using (bucket_id not in ('training-camps','training-camps-galeria') or (select public.es_admin()));

commit;
