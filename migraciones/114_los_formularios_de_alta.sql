-- ============================================================
-- 114 · Los formularios de alta: escuela, socio, renovación y SEPA
-- ------------------------------------------------------------
-- QUÉ FALTABA
-- La web sabía decir «me interesa» y nada más. La tabla
-- `solicitudes_inscripcion` guarda cuatro campos —nombre, qué te
-- interesa, cómo nos conociste y un comentario— y sirve para que
-- alguien del club llame por teléfono. Apuntarse de verdad seguía
-- pasando por Google Forms, por papel o por WhatsApp.
--
-- En septiembre se apuntan unas 400 familias. Esto es donde se
-- guardará lo que rellenen.
--
-- ------------------------------------------------------------
-- LO MÁS IMPORTANTE DE ESTE ARCHIVO, DICHO ANTES QUE NADA
-- Aquí dentro hay datos de niños, DNI, números de cuenta y
-- autorizaciones de imagen. El club responde de ellos ante la ley.
-- Así que estas tablas NACEN CERRADAS, y se cierran de una forma
-- que conviene entender porque no es la de siempre:
--
--   · NADIE sin cuenta puede leer nada. Ni una fila, ni un correo,
--     ni saber si alguien ya se apuntó.
--   · NADIE sin cuenta puede escribir DIRECTAMENTE en las tablas
--     tampoco. Ni siquiera «insertar». Esto es distinto de cómo
--     está hecha la preinscripción de hoy, que sí deja insertar a
--     cualquiera.
--   · Se entra por una sola puerta: las funciones `enviar_*` de
--     más abajo. Esa puerta comprueba lo que le dan, cuenta cuántas
--     veces se ha usado en la última hora y solo entonces guarda.
--
-- POR QUÉ ASÍ Y NO CON UN «CUALQUIERA PUEDE INSERTAR»
-- Porque un permiso de insertar a secas no sabe decir que no. Si
-- alguien se aburre una tarde y manda mil altas falsas con un
-- programa, la tabla se las traga todas y el club se queda con mil
-- familias inventadas que hay que revisar a mano en la semana en la
-- que se apunta media escuela. La función sí sabe decir que no.
--
-- QUIÉN LEE QUÉ, EN UNA LÍNEA
--   · Altas de escuela y de socio  →  administración y tesorería.
--   · Órdenes de domiciliación     →  administración y tesorería, y
--                                     nadie más. Ahí hay cuentas.
--   · Renovaciones                 →  administración y tesorería.
--   · Entrenadores y atletas       →  nada de todo esto.
--
-- Se ha comprobado poniéndose los papeles de cada uno, no leyendo
-- las reglas y dando por hecho que hacen lo que dicen.
--
-- ------------------------------------------------------------
-- LO QUE ESTA MIGRACIÓN NO HACE
-- No borra nada. No toca `solicitudes_inscripcion` ni la página
-- /inscripcion/, que se quedan como están: son la puerta de «que me
-- llamen», y eso sigue haciendo falta para quien no se decide.
-- No crea ni un atleta: un alta es una SOLICITUD que alguien del
-- club revisa. Convertirla en atleta es un paso aparte y a mano.
-- No sube ni un archivo a ningún sitio: en estos formularios no se
-- pide ninguna foto ni ningún DNI escaneado (eso es de federarse,
-- que es otro trámite).
-- ============================================================


-- ============================================================
-- 0 · HERRAMIENTAS PEQUEÑAS
-- ============================================================

-- ------------------------------------------------------------
-- La temporada en la que estamos, escrita como la escribe el club
-- («2026-27»). El curso arranca en verano, así que de julio en
-- adelante ya se cuenta la temporada nueva: quien se apunta el 20 de
-- agosto se apunta para el curso que empieza en septiembre, no para
-- el que acaba de terminar.
-- ------------------------------------------------------------
create or replace function public.temporada_actual()
returns text
language sql
stable
set search_path to 'public'
as $$
  select case
           when extract(month from current_date) >= 7
             then extract(year from current_date)::int || '-' ||
                  right((extract(year from current_date)::int + 1)::text, 2)
           else (extract(year from current_date)::int - 1)::text || '-' ||
                  right(extract(year from current_date)::text, 2)
         end;
$$;

comment on function public.temporada_actual() is
  'La temporada del club en curso, «2026-27». De julio en adelante ya cuenta la siguiente.';


-- ------------------------------------------------------------
-- De dónde viene la petición. Supabase deja los encabezados HTTP a
-- mano en `request.headers`; ahí está la IP real de quien rellena
-- (la de la base sería siempre la misma y no valdría para nada).
--
-- Se usa para dos cosas y solo dos:
--   1. Poner freno a quien mande cien altas seguidas.
--   2. Guardarla junto a la firma del SEPA, que sin fecha, hora,
--      IP y navegador la firma es un dibujo y no vale.
--
-- Si el encabezado no viene (por ejemplo cuando esto se llama desde
-- psql para probar), devuelve vacío y no rompe nada.
-- ------------------------------------------------------------
create or replace function public.ip_peticion()
returns text
language plpgsql
stable
set search_path to 'public'
as $$
declare
  v_cabeceras text;
  v_ip        text;
begin
  begin
    v_cabeceras := current_setting('request.headers', true);
  exception when others then
    return '';
  end;
  if v_cabeceras is null or v_cabeceras = '' then
    return '';
  end if;
  -- x-forwarded-for puede traer varias IP separadas por comas: la
  -- primera es la de quien rellena, las demás son de por dónde pasó.
  v_ip := split_part(coalesce(v_cabeceras::json ->> 'x-forwarded-for', ''), ',', 1);
  return left(btrim(coalesce(v_ip, '')), 60);
exception when others then
  return '';
end;
$$;

create or replace function public.navegador_peticion()
returns text
language plpgsql
stable
set search_path to 'public'
as $$
declare
  v_cabeceras text;
begin
  begin
    v_cabeceras := current_setting('request.headers', true);
  exception when others then
    return '';
  end;
  if v_cabeceras is null or v_cabeceras = '' then
    return '';
  end if;
  return left(coalesce(v_cabeceras::json ->> 'user-agent', ''), 300);
exception when others then
  return '';
end;
$$;


-- ------------------------------------------------------------
-- Limpiar un texto que llega de fuera: quitarle los espacios de los
-- lados, cortarlo si viene absurdamente largo y devolver nulo si no
-- queda nada. Que nadie pueda meter una novela en el campo del
-- nombre y llenar la base.
-- ------------------------------------------------------------
create or replace function public.texto_de_fuera(p_valor text, p_max int default 200)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select nullif(left(btrim(coalesce(p_valor, '')), greatest(p_max, 1)), '');
$$;


-- ------------------------------------------------------------
-- Un código corto para que la familia pueda decir por teléfono
-- «tengo el ESC-2627-K4P9» sin cantar su correo ni el nombre del
-- niño. No se usan ni O ni I ni 0 ni 1: por teléfono se confunden.
-- ------------------------------------------------------------
create or replace function public.referencia_corta(p_prefijo text)
returns text
language sql
volatile
set search_path to 'public'
as $$
  select upper(p_prefijo) || '-' ||
         right(split_part(public.temporada_actual(), '-', 1), 2) ||
         split_part(public.temporada_actual(), '-', 2) || '-' ||
         string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                           1 + floor(random() * 32)::int, 1), '')
    from generate_series(1, 4);
$$;


-- ============================================================
-- 1 · EL FRENO · cuántas veces se ha usado el formulario
-- ------------------------------------------------------------
-- Una tabla de usar y tirar donde se apunta cada envío: de qué tipo
-- era y de qué IP venía. No lleva ni un dato de nadie: ni nombres,
-- ni correos, ni teléfonos. Solo sirve para contar.
--
-- Se limpia sola: cada envío borra lo que tenga más de un día.
--
-- Nadie la lee desde la web. Tiene las reglas activadas y NINGUNA
-- regla escrita, que es la forma de decir «por aquí no pasa nadie».
-- Solo la tocan las funciones de más abajo, que corren con los
-- papeles del dueño de la base.
-- ============================================================
create table if not exists public.altas_intentos (
  id         bigserial primary key,
  tipo       text not null,
  ip         text,
  creado_en  timestamptz not null default now()
);

create index if not exists idx_altas_intentos_ip
  on public.altas_intentos (ip, creado_en desc);
create index if not exists idx_altas_intentos_tipo
  on public.altas_intentos (tipo, creado_en desc);

alter table public.altas_intentos enable row level security;


-- ------------------------------------------------------------
-- ¿Se puede seguir, o este ya se ha pasado de la raya?
--
-- Dos frenos a la vez, porque protegen de cosas distintas:
--
--   · POR IP (12 en una hora). Frena a quien le da al botón de
--     enviar veinte veces porque no está seguro de que haya
--     funcionado, y frena a un programa tonto. Doce es de sobra
--     para una familia con tres hijos que además se equivoca dos
--     veces: cada hijo NO cuenta como un envío, el formulario de
--     los hermanos es uno solo.
--
--   · GLOBAL (150 en una hora, de todo el club). Es el interruptor
--     de emergencia: si de golpe entran más de ciento cincuenta
--     altas en una hora, o el club ha salido en el telediario o
--     alguien está jugando. En septiembre el día más fuerte no
--     llega ni de lejos, así que no molesta a nadie real.
--
-- El intento se apunta SIEMPRE, se le deje pasar o no. Si solo se
-- apuntaran los que pasan, el que se pasa de la raya nunca sumaría
-- y podría seguir intentándolo eternamente.
-- ------------------------------------------------------------
create or replace function public.altas_hay_sitio(p_tipo text)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_ip     text := public.ip_peticion();
  v_mismo  int;
  v_todos  int;
begin
  delete from public.altas_intentos where creado_en < now() - interval '1 day';

  select count(*) into v_mismo
    from public.altas_intentos
   where v_ip <> ''
     and ip = v_ip
     and creado_en > now() - interval '1 hour';

  select count(*) into v_todos
    from public.altas_intentos
   where creado_en > now() - interval '1 hour';

  insert into public.altas_intentos (tipo, ip) values (p_tipo, nullif(v_ip, ''));

  return v_mismo < 12 and v_todos < 150;
end;
$$;


-- ============================================================
-- 2 · ALTAS DE LA ESCUELA
-- ------------------------------------------------------------
-- Un alta es UNA FAMILIA. Lo que se rellena una vez —quién paga,
-- dónde vive, cómo se le localiza, las normas— vive en
-- `altas_escuela`. Lo que se repite por cada hijo —su nombre, su
-- fecha, su grupo, sus alergias, su permiso de imagen y su talla—
-- vive en `altas_escuela_ninos`, una fila por niño.
--
-- Están separadas porque el permiso de imagen puede ser distinto
-- para cada hijo: una madre puede decir que sí para el mayor y que
-- no para la pequeña, y eso hay que poder guardarlo. Si todo
-- estuviera en una fila, el segundo hijo no cabría.
-- ============================================================

create table if not exists public.altas_escuela (
  id           uuid primary key default gen_random_uuid(),

  -- El código que se le enseña a la familia al terminar.
  referencia   text not null unique,
  temporada    text not null default public.temporada_actual(),

  -- QUIÉN LO RELLENA (padre, madre o tutor)
  tutor_nombre    text not null,
  tutor_dni       text,
  tutor_email     text not null,
  tutor_telefono  text not null,
  direccion       text,
  cp              text,
  localidad       text,

  -- Quién puede recoger al niño además de quien firma. Texto libre
  -- a propósito: en la vida real es «su abuela Pilar y la madre de
  -- Marcos», y una lista de campos no lo recoge.
  quien_recoge    text,

  como_nos_conocio text,

  -- EL BANCO. Opcional en la inscripción, y con intención: quien no
  -- lo quiere dar deja un hueco, y un hueco se lista y se reclama.
  -- Un cero inventado pasaría por bueno hasta que rebote el recibo
  -- en octubre. La orden de domiciliación es otro trámite y va en
  -- `mandatos_sepa`: esto de aquí es un dato, aquello es un
  -- documento firmado.
  iban            text,

  -- 'un-pago' o 'dos-pagos'. Es de la familia, no de cada hijo:
  -- sale un solo recibo por todos.
  forma_pago      text,

  -- LAS NORMAS. Se guarda que las aceptó y además, literal, el
  -- texto que se le enseñó al aceptarlas. Si el club cambia mañana
  -- la redacción, lo que esta familia aceptó sigue siendo lo que
  -- leyó, no lo que pone hoy la web.
  acepta_normas   boolean not null default false,
  texto_normas    text,

  -- POR DÓNDE ENTRÓ Y CUÁNDO. Va con la aceptación de las normas,
  -- por lo mismo que va con la firma del SEPA.
  ip              text,
  navegador       text,

  -- LO QUE HACE EL CLUB DESPUÉS
  estado        text not null default 'pendiente',
  revisada_por  uuid references public.perfiles(id),
  revisada_en   timestamptz,
  nota_club     text,

  created_at    timestamptz not null default now(),

  constraint altas_escuela_estado_chk
    check (estado in ('pendiente', 'revisada', 'rechazada')),
  constraint altas_escuela_forma_pago_chk
    check (forma_pago is null or forma_pago in ('un-pago', 'dos-pagos'))
);

create index if not exists idx_altas_escuela_estado
  on public.altas_escuela (estado, created_at desc);
create index if not exists idx_altas_escuela_email
  on public.altas_escuela (lower(tutor_email), created_at desc);
create index if not exists idx_altas_escuela_temporada
  on public.altas_escuela (temporada, created_at desc);


create table if not exists public.altas_escuela_ninos (
  id        uuid primary key default gen_random_uuid(),
  alta_id   uuid not null references public.altas_escuela(id) on delete cascade,
  orden     int  not null default 1,

  nombre            text not null,
  fecha_nacimiento  date not null,

  -- La tarjeta sanitaria. Se pide para las licencias y para una
  -- urgencia en la pista, y eso se le dice en el propio campo.
  sip               text,

  -- Lo ÚNICO que elige la familia del horario: los días. La franja
  -- la da el año de nacimiento y no se pregunta.
  turno             text,

  -- El grupo que le salió al poner la fecha. Se guardan las dos
  -- cosas a propósito: el enlace al grupo real, para las listas del
  -- entrenador; y el nombre tal y como se le enseñó, congelado,
  -- para que dentro de un año se sepa qué le dijimos aunque el
  -- club haya movido los grupos.
  grupo_id          uuid references public.grupos(id),
  grupo_nombre      text,

  alergias          text,

  -- EL PERMISO DE IMAGEN. Sin valor por defecto y a propósito: no
  -- se puede dar por hecho ni que sí ni que no. Si esta columna
  -- está vacía es que no contestó, y entonces es que NO.
  permiso_imagen     boolean,
  -- Para qué se pidió el permiso, con los apartados del papel del
  -- club: 'web', 'redes', 'mensajeria', 'medios'.
  permiso_imagen_ambitos text[],
  -- Y la pregunta literal que se le hizo, por lo mismo que con las
  -- normas: un consentimiento vale por lo que se preguntó.
  texto_imagen       text,

  talla_camiseta    text,
  talla_sudadera    text,

  -- Cuando alguien del club convierte el alta en atleta de verdad,
  -- se apunta aquí a quién dio lugar. Hasta entonces, vacío.
  atleta_id         uuid references public.atletas(id) on delete set null,

  created_at timestamptz not null default now(),

  constraint altas_escuela_ninos_turno_chk
    check (turno is null or turno in ('lunes-miercoles', 'martes-jueves'))
);

create index if not exists idx_altas_escuela_ninos_alta
  on public.altas_escuela_ninos (alta_id, orden);
create index if not exists idx_altas_escuela_ninos_grupo
  on public.altas_escuela_ninos (grupo_id);


-- ============================================================
-- 3 · ALTAS DE SOCIO
-- ------------------------------------------------------------
-- Ser socio queda en nombre, DNI, nacimiento, dirección, contacto y
-- sección. Aquí NO hay foto de carné, ni DNI escaneado por las dos
-- caras, ni peso, ni estatura, ni nacionalidad, ni lugar de
-- nacimiento. Eso no son datos para ser socio: son para federarse,
-- que es otro trámite y solo para quien lo necesita.
--
-- Cada campo de menos es un dato que el club no tiene que custodiar
-- y una oportunidad menos de que alguien cierre la pestaña.
-- ============================================================
create table if not exists public.altas_socio (
  id          uuid primary key default gen_random_uuid(),
  referencia  text not null unique,
  temporada   text not null default public.temporada_actual(),

  nombre            text not null,
  apellidos         text,
  dni               text not null,
  fecha_nacimiento  date,
  sexo              text,

  direccion   text,
  cp          text,
  localidad   text,
  provincia   text,

  email       text not null,
  telefono    text not null,

  -- En qué se apunta: 'atletismo', 'montana', 'triatlon', 'natacion'.
  secciones   text[],

  acepta_normas boolean not null default false,
  texto_normas  text,

  permiso_imagen         boolean,
  permiso_imagen_ambitos text[],
  texto_imagen           text,

  -- Las dos condiciones que hoy están escondidas en una página y
  -- que se le enseñan en el resumen ANTES de terminar: que en
  -- montaña y triatlón hay que federarse, y que en diciembre se
  -- cobran cinco décimos de lotería o 15 € de donación. Se guarda
  -- el texto que se le enseñó, para que nadie pueda decir que no se
  -- lo dijeron. Una sorpresa de 15 € en diciembre cuesta más que
  -- decirlo en agosto.
  texto_condiciones text,

  ip          text,
  navegador   text,

  estado        text not null default 'pendiente',
  revisada_por  uuid references public.perfiles(id),
  revisada_en   timestamptz,
  nota_club     text,
  perfil_id     uuid references public.perfiles(id) on delete set null,

  created_at  timestamptz not null default now(),

  constraint altas_socio_estado_chk
    check (estado in ('pendiente', 'revisada', 'rechazada')),
  constraint altas_socio_sexo_chk
    check (sexo is null or sexo in ('hombre', 'mujer', 'otro')),
  constraint altas_socio_secciones_chk
    check (secciones is null or
           secciones <@ array['atletismo', 'montana', 'triatlon', 'natacion'])
);

create index if not exists idx_altas_socio_estado
  on public.altas_socio (estado, created_at desc);
create index if not exists idx_altas_socio_email
  on public.altas_socio (lower(email), created_at desc);


-- ============================================================
-- 4 · LAS ÓRDENES DE DOMICILIACIÓN (SEPA)
-- ------------------------------------------------------------
-- ESTA ES LA TABLA MÁS DELICADA DE LA BASE. Aquí hay números de
-- cuenta y firmas. La leen administración y tesorería, y nadie más:
-- ni entrenadores, ni coordinadores, ni la junta.
--
-- QUÉ SE GUARDA CON LA FIRMA Y POR QUÉ
-- Una firma hecha con el dedo, sola, no es nada: es un dibujo. Lo
-- que la convierte en una orden que el banco puede defender es lo
-- que va a su lado:
--   · la fecha y la hora exactas
--   · desde qué IP y con qué navegador se firmó
--   · y EL TEXTO DEL MANDATO TAL Y COMO SE MOSTRÓ EN LA PANTALLA
--
-- Ese último es el que se olvida siempre. Si el club cambia mañana
-- la redacción del mandato, hay que poder demostrar qué firmó esta
-- persona, no qué pone hoy la web.
--
-- EL PDF VA DESPUÉS, NO ANTES. Nadie descarga, imprime, firma y
-- escanea: se firma en pantalla y el club genera luego el PDF con
-- la firma dentro y se lo manda al titular. `pdf_url` está vacío
-- hasta que eso exista.
-- ============================================================
create table if not exists public.mandatos_sepa (
  id          uuid primary key default gen_random_uuid(),

  -- La referencia única del mandato, que es la que va en el fichero
  -- que se le manda al banco.
  referencia  text not null unique,

  -- De dónde vino: de un alta de escuela, de un alta de socio, o
  -- porque alguien que ya está dentro lo firmó desde su portal.
  origen           text not null,
  alta_escuela_id  uuid references public.altas_escuela(id) on delete set null,
  alta_socio_id    uuid references public.altas_socio(id)   on delete set null,
  atleta_id        uuid references public.atletas(id)       on delete set null,
  perfil_id        uuid references public.perfiles(id)      on delete set null,

  -- EL DEUDOR. Quien firma tiene que ser el titular de la cuenta;
  -- casi nunca es el niño, y por eso el titular se pide aparte.
  titular     text not null,
  iban        text not null,
  bic         text,
  direccion   text,
  cp          text,
  localidad   text,
  pais        text not null default 'España',

  -- 'recurrente' (lo normal: cada temporada) o 'unico'.
  tipo_pago   text not null default 'recurrente',

  -- LA FIRMA Y SU CONTEXTO
  lugar_firma    text not null default 'Alicante',
  firmado_en     timestamptz not null default now(),
  firma_png      text not null,
  texto_mandato  text not null,
  cif_acreedor   text not null,
  identificador_acreedor text,
  ip             text,
  navegador      text,

  estado    text not null default 'firmado',
  pdf_url   text,
  nota_club text,

  created_at timestamptz not null default now(),

  constraint mandatos_sepa_origen_chk
    check (origen in ('alta-escuela', 'alta-socio', 'portal')),
  constraint mandatos_sepa_tipo_pago_chk
    check (tipo_pago in ('recurrente', 'unico')),
  constraint mandatos_sepa_estado_chk
    check (estado in ('firmado', 'enviado-al-banco', 'anulado')),
  -- Un IBAN tiene 24 caracteres en España y empieza por ES. Se
  -- comprueba aquí además de en la pantalla: la pantalla se la
  -- puede saltar cualquiera, la base no.
  constraint mandatos_sepa_iban_chk
    check (iban ~ '^[A-Z]{2}[0-9A-Z]{13,32}$')
);

create index if not exists idx_mandatos_sepa_alta_escuela
  on public.mandatos_sepa (alta_escuela_id);
create index if not exists idx_mandatos_sepa_estado
  on public.mandatos_sepa (estado, firmado_en desc);


-- ------------------------------------------------------------
-- EL TEXTO DEL MANDATO, que lo pone el club y no la web
--
-- El texto legal de la orden de domiciliación, con el identificador
-- de acreedor, tiene que darlo el gestor o el banco del club: va
-- LITERAL en la pantalla y no se puede redactar por aproximación.
--
-- Así que vive aquí, en una fila que se edita desde el panel, y no
-- escrito a mano dentro de la página. Y mientras esté vacío o
-- inactivo, la pantalla de firmar NO deja firmar: enseña que
-- todavía no está y ofrece hacerlo por teléfono. Es preferible eso
-- a recoger firmas sobre un texto inventado, que no valdrían.
-- ------------------------------------------------------------
create table if not exists public.sepa_mandato_texto (
  id          uuid primary key default gen_random_uuid(),
  version     text not null,
  texto       text not null,
  cif_acreedor text not null,
  identificador_acreedor text,
  acreedor_nombre    text not null default 'Club Atletismo Apolana',
  acreedor_direccion text,
  activo      boolean not null default false,
  creado_por  uuid references public.perfiles(id),
  created_at  timestamptz not null default now()
);

-- Solo puede haber un texto activo a la vez: si hubiera dos, nadie
-- sabría cuál se firmó.
create unique index if not exists ux_sepa_mandato_texto_activo
  on public.sepa_mandato_texto ((activo)) where activo;


-- ============================================================
-- 5 · RENOVACIONES
-- ------------------------------------------------------------
-- Renovar no es rellenar: es confirmar. Hoy una familia que renueva
-- por tercer año vuelve a escribir el nombre, los apellidos, el
-- sexo, el DNI y la fecha de nacimiento de su hijo, que el club ya
-- tiene apuntados. Eso desaparece.
--
-- CÓMO SE ENTRA SIN CUENTA
-- El club genera un enlace por niño y se lo manda a la familia. El
-- enlace lleva un código largo e imposible de adivinar.
--
-- DEL CÓDIGO NO SE GUARDA EL CÓDIGO, sino su huella (sha256). Si
-- algún día alguien se llevara esta tabla entera, no se llevaría ni
-- un enlace que funcione: de una huella no se saca el código.
-- Es lo mismo que se hace con las contraseñas y por lo mismo.
--
-- Y caducan. Un enlace de renovación de hace tres años no tiene por
-- qué seguir abriendo la ficha de un menor.
-- ============================================================
create table if not exists public.renovaciones (
  id          uuid primary key default gen_random_uuid(),
  temporada   text not null default public.temporada_actual(),
  atleta_id   uuid not null references public.atletas(id) on delete cascade,

  token_hash  text not null unique,
  caduca_en   timestamptz not null default (now() + interval '90 days'),

  -- LO QUE CONTESTA LA FAMILIA. Tres respuestas y una salida.
  respondida_en   timestamptz,
  sigue           boolean,       -- «este año no sigue» tiene que estar y verse
  motivo_no_sigue text,
  turno           text,
  talla_camiseta  text,
  talla_sudadera  text,
  forma_pago      text,
  -- «Algo ha cambiado»: un teléfono o una dirección nuevos. Es lo
  -- único que se mueve de un año para otro.
  cambios         text,

  ip        text,
  navegador text,

  creado_por uuid references public.perfiles(id),
  created_at timestamptz not null default now(),

  constraint renovaciones_turno_chk
    check (turno is null or turno in ('lunes-miercoles', 'martes-jueves')),
  constraint renovaciones_forma_pago_chk
    check (forma_pago is null or forma_pago in ('un-pago', 'dos-pagos')),
  constraint renovaciones_una_por_temporada
    unique (temporada, atleta_id)
);

create index if not exists idx_renovaciones_temporada
  on public.renovaciones (temporada, respondida_en);


-- ============================================================
-- 6 · LAS REGLAS · quién ve qué
-- ------------------------------------------------------------
-- Se activan en todas las tablas y se escriben una por una. Lo que
-- no está escrito aquí, no se puede hacer: ese es el punto de
-- partida de las reglas de Postgres y por eso las tablas nacen
-- cerradas sin tener que cerrarlas.
--
-- Fíjate en lo que NO hay: ninguna regla para `anon` (quien no ha
-- entrado) y ninguna regla de «authenticated con true» (cualquiera
-- que tenga cuenta). Un formulario público escribe por la puerta de
-- las funciones y no lee nada.
-- ============================================================

alter table public.altas_escuela       enable row level security;
alter table public.altas_escuela_ninos enable row level security;
alter table public.altas_socio         enable row level security;
alter table public.mandatos_sepa       enable row level security;
alter table public.sepa_mandato_texto  enable row level security;
alter table public.renovaciones        enable row level security;

-- ---- Altas de escuela: administración y tesorería ----
drop policy if exists "admin gestiona altas escuela" on public.altas_escuela;
create policy "admin gestiona altas escuela" on public.altas_escuela
  for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

drop policy if exists "tesoreria gestiona altas escuela" on public.altas_escuela;
create policy "tesoreria gestiona altas escuela" on public.altas_escuela
  for all to authenticated
  using (public.es_tesoreria()) with check (public.es_tesoreria());

drop policy if exists "admin gestiona ninos del alta" on public.altas_escuela_ninos;
create policy "admin gestiona ninos del alta" on public.altas_escuela_ninos
  for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

drop policy if exists "tesoreria gestiona ninos del alta" on public.altas_escuela_ninos;
create policy "tesoreria gestiona ninos del alta" on public.altas_escuela_ninos
  for all to authenticated
  using (public.es_tesoreria()) with check (public.es_tesoreria());

-- ---- Altas de socio: administración y tesorería ----
drop policy if exists "admin gestiona altas socio" on public.altas_socio;
create policy "admin gestiona altas socio" on public.altas_socio
  for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

drop policy if exists "tesoreria gestiona altas socio" on public.altas_socio;
create policy "tesoreria gestiona altas socio" on public.altas_socio
  for all to authenticated
  using (public.es_tesoreria()) with check (public.es_tesoreria());

-- ---- Los mandatos SEPA: aquí hay cuentas bancarias ----
-- Las mismas dos puertas que las cuentas del club en la migración
-- 110, y por la misma razón: tener cuenta en la web no es lo mismo
-- que tener por qué ver el número de cuenta de una familia.
drop policy if exists "admin gestiona mandatos" on public.mandatos_sepa;
create policy "admin gestiona mandatos" on public.mandatos_sepa
  for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

drop policy if exists "tesoreria gestiona mandatos" on public.mandatos_sepa;
create policy "tesoreria gestiona mandatos" on public.mandatos_sepa
  for all to authenticated
  using (public.es_tesoreria()) with check (public.es_tesoreria());

-- ---- El texto del mandato ----
-- Este sí lo lee todo el mundo, y tiene que ser así: es el texto
-- legal que hay que ENSEÑAR a quien va a firmar, antes de que
-- firme. Un mandato que no puedes leer antes de firmarlo no vale.
-- No lleva ni un dato de nadie: es el texto del club.
drop policy if exists "cualquiera lee el mandato activo" on public.sepa_mandato_texto;
create policy "cualquiera lee el mandato activo" on public.sepa_mandato_texto
  for select using (activo);

drop policy if exists "admin gestiona el texto del mandato" on public.sepa_mandato_texto;
create policy "admin gestiona el texto del mandato" on public.sepa_mandato_texto
  for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

-- ---- Renovaciones ----
drop policy if exists "admin gestiona renovaciones" on public.renovaciones;
create policy "admin gestiona renovaciones" on public.renovaciones
  for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

drop policy if exists "tesoreria gestiona renovaciones" on public.renovaciones;
create policy "tesoreria gestiona renovaciones" on public.renovaciones
  for all to authenticated
  using (public.es_tesoreria()) with check (public.es_tesoreria());


-- ------------------------------------------------------------
-- LOS PERMISOS DE TABLA · el candado de antes del candado
--
-- Las reglas de arriba deciden QUÉ FILAS ve cada uno. Pero antes de
-- llegar a las reglas hay una puerta anterior: el permiso de tocar
-- la tabla siquiera. Se reparte igual que en `info_pagos`, la tabla
-- de las cuentas del club:
--
--   · a `authenticated` (quien ha entrado con su cuenta) se le da
--     el permiso, y son las reglas de arriba las que deciden si ve
--     algo o cero. Sin este permiso, ni administración vería nada.
--
--   · a `anon` (quien no ha entrado) NO SE LE DA NADA. Ni leer, ni
--     escribir. Así, aunque un día alguien escribiera por error una
--     regla demasiado abierta, seguiría sin poder pasar: son dos
--     cerraduras distintas y hay que abrir las dos.
--
-- La única excepción es el texto del mandato, que hay que poder
-- leer antes de firmarlo aunque no tengas cuenta.
-- ------------------------------------------------------------
grant select, insert, update, delete on public.altas_escuela       to authenticated;
grant select, insert, update, delete on public.altas_escuela_ninos to authenticated;
grant select, insert, update, delete on public.altas_socio         to authenticated;
grant select, insert, update, delete on public.mandatos_sepa       to authenticated;
grant select, insert, update, delete on public.sepa_mandato_texto  to authenticated;
grant select, insert, update, delete on public.renovaciones        to authenticated;

grant select on public.sepa_mandato_texto to anon;

grant all on public.altas_escuela, public.altas_escuela_ninos, public.altas_socio,
             public.mandatos_sepa, public.sepa_mandato_texto, public.renovaciones,
             public.altas_intentos
  to service_role;
grant usage, select on sequence public.altas_intentos_id_seq to service_role;

-- Y a `altas_intentos`, la de contar, no se le da a nadie: solo la
-- tocan las funciones de aquí abajo.


-- ============================================================
-- 7 · LA PUERTA · las funciones que sí puede llamar la web
-- ------------------------------------------------------------
-- Todas hacen lo mismo por dentro y en este orden:
--   1. mirar el freno (¿va este a la centésima alta de la hora?)
--   2. comprobar lo que llega (¿hay nombre? ¿hay correo? ¿hay niño?)
--   3. mirar si esto ya se guardó hace un minuto (el doble clic)
--   4. guardar
--   5. devolver el código y NADA MÁS
--
-- Ese «y nada más» es importante. No devuelven si el correo ya
-- existía, ni cuántas altas hay, ni el identificador interno de
-- nada. Quien rellena un alta no puede enterarse de las altas de
-- nadie, ni averiguar si un correo está apuntado probando correos.
-- ============================================================

-- ------------------------------------------------------------
-- ENVIAR UN ALTA DE ESCUELA
--
-- Recibe un solo paquete con la familia y la lista de hijos, porque
-- o se guarda todo o no se guarda nada: media familia apuntada es
-- peor que ninguna.
--
-- EL DOBLE CLIC. Si a la misma familia (mismo correo) con el mismo
-- primer hijo le llega un alta dentro de la misma hora, NO se
-- guarda otra: se le devuelve la que ya hay. Así el botón se puede
-- pulsar dos veces, se puede recargar la página con el móvil en el
-- bolsillo y el club no se encuentra a Lucía apuntada tres veces.
-- ------------------------------------------------------------
create or replace function public.enviar_alta_escuela(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_email     text := lower(public.texto_de_fuera(p ->> 'tutor_email', 160));
  v_ninos     jsonb := coalesce(p -> 'ninos', '[]'::jsonb);
  v_nino      jsonb;
  v_alta_id   uuid;
  v_ref       text;
  v_i         int := 0;
  v_primero   text;
  v_ya        uuid;
  v_segundos  int := coalesce((p ->> 'segundos')::int, 0);
begin
  -- El cepo para robots: un campo escondido que una persona no ve y
  -- por tanto nunca rellena, y el tiempo que se ha tardado. Nadie
  -- apunta a un hijo en seis segundos. Se contesta que sí para no
  -- enseñarle al robot dónde está la trampa, pero no se guarda.
  if public.texto_de_fuera(p ->> 'apellido_de_soltera', 100) is not null
     or v_segundos < 6 then
    return jsonb_build_object('ok', true, 'referencia', public.referencia_corta('ESC'));
  end if;

  if not public.altas_hay_sitio('escuela') then
    return jsonb_build_object('ok', false, 'motivo', 'demasiados',
      'mensaje', 'Ahora mismo no podemos recoger más altas. Prueba dentro de un rato o llámanos.');
  end if;

  if v_email is null or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return jsonb_build_object('ok', false, 'motivo', 'correo',
      'mensaje', 'Ese correo no parece bien escrito. Revísalo, por favor.');
  end if;

  if jsonb_array_length(v_ninos) = 0 or jsonb_array_length(v_ninos) > 6 then
    return jsonb_build_object('ok', false, 'motivo', 'ninos',
      'mensaje', 'Falta el niño o la niña que se apunta.');
  end if;

  if public.texto_de_fuera(p ->> 'tutor_nombre', 120) is null
     or public.texto_de_fuera(p ->> 'tutor_telefono', 30) is null then
    return jsonb_build_object('ok', false, 'motivo', 'familia',
      'mensaje', 'Faltan el nombre y el teléfono de quien apunta.');
  end if;

  if coalesce((p ->> 'acepta_normas')::boolean, false) is not true then
    return jsonb_build_object('ok', false, 'motivo', 'normas',
      'mensaje', 'Hay que aceptar las normas del club para poder apuntarse.');
  end if;

  v_primero := lower(public.texto_de_fuera(v_ninos -> 0 ->> 'nombre', 120));

  -- ¿Esto ya lo hemos recibido hace un momento?
  select a.id into v_ya
    from public.altas_escuela a
    join public.altas_escuela_ninos n on n.alta_id = a.id and n.orden = 1
   where lower(a.tutor_email) = v_email
     and lower(n.nombre) = v_primero
     and a.created_at > now() - interval '1 hour'
   limit 1;

  if v_ya is not null then
    return jsonb_build_object('ok', true, 'repetida', true,
      'referencia', (select referencia from public.altas_escuela where id = v_ya));
  end if;

  v_ref := public.referencia_corta('ESC');

  insert into public.altas_escuela (
    referencia, tutor_nombre, tutor_dni, tutor_email, tutor_telefono,
    direccion, cp, localidad, quien_recoge, como_nos_conocio,
    iban, forma_pago, acepta_normas, texto_normas, ip, navegador
  ) values (
    v_ref,
    public.texto_de_fuera(p ->> 'tutor_nombre', 120),
    public.texto_de_fuera(p ->> 'tutor_dni', 20),
    v_email,
    public.texto_de_fuera(p ->> 'tutor_telefono', 30),
    public.texto_de_fuera(p ->> 'direccion', 200),
    public.texto_de_fuera(p ->> 'cp', 10),
    public.texto_de_fuera(p ->> 'localidad', 80),
    public.texto_de_fuera(p ->> 'quien_recoge', 400),
    public.texto_de_fuera(p ->> 'como_nos_conocio', 60),
    upper(replace(coalesce(public.texto_de_fuera(p ->> 'iban', 40), ''), ' ', '')),
    public.texto_de_fuera(p ->> 'forma_pago', 20),
    true,
    public.texto_de_fuera(p ->> 'texto_normas', 2000),
    public.ip_peticion(),
    public.navegador_peticion()
  ) returning id into v_alta_id;

  -- Si el IBAN venía vacío queda vacío, no una cadena de nada.
  update public.altas_escuela set iban = nullif(iban, '') where id = v_alta_id;

  for v_nino in select * from jsonb_array_elements(v_ninos) loop
    v_i := v_i + 1;
    insert into public.altas_escuela_ninos (
      alta_id, orden, nombre, fecha_nacimiento, sip, turno,
      grupo_id, grupo_nombre, alergias,
      permiso_imagen, permiso_imagen_ambitos, texto_imagen,
      talla_camiseta, talla_sudadera
    ) values (
      v_alta_id, v_i,
      public.texto_de_fuera(v_nino ->> 'nombre', 120),
      (v_nino ->> 'fecha_nacimiento')::date,
      public.texto_de_fuera(v_nino ->> 'sip', 30),
      public.texto_de_fuera(v_nino ->> 'turno', 20),
      -- El grupo NO se cree lo que diga el navegador: se busca en la
      -- base por el año de nacimiento y los días, que es de donde
      -- sale de verdad. Si el navegador mandara otro, se ignora.
      (select g.id from public.grupos g
        where g.seccion = 'escuela' and g.activo
          and g.turno = public.texto_de_fuera(v_nino ->> 'turno', 20)
          and extract(year from (v_nino ->> 'fecha_nacimiento')::date)::int
              between coalesce(g.nacidos_desde, 0) and coalesce(g.nacidos_hasta, 9999)
        limit 1),
      (select g.nombre from public.grupos g
        where g.seccion = 'escuela' and g.activo
          and g.turno = public.texto_de_fuera(v_nino ->> 'turno', 20)
          and extract(year from (v_nino ->> 'fecha_nacimiento')::date)::int
              between coalesce(g.nacidos_desde, 0) and coalesce(g.nacidos_hasta, 9999)
        limit 1),
      public.texto_de_fuera(v_nino ->> 'alergias', 600),
      (v_nino ->> 'permiso_imagen')::boolean,
      case when v_nino ? 'permiso_imagen_ambitos'
           then array(select jsonb_array_elements_text(v_nino -> 'permiso_imagen_ambitos'))
           else null end,
      public.texto_de_fuera(v_nino ->> 'texto_imagen', 600),
      public.texto_de_fuera(v_nino ->> 'talla_camiseta', 10),
      public.texto_de_fuera(v_nino ->> 'talla_sudadera', 10)
    );
  end loop;

  return jsonb_build_object('ok', true, 'referencia', v_ref);
end;
$$;


-- ------------------------------------------------------------
-- ENVIAR UN ALTA DE SOCIO
-- Lo mismo, sin niño y sin permisos por hijo.
-- ------------------------------------------------------------
create or replace function public.enviar_alta_socio(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_email text := lower(public.texto_de_fuera(p ->> 'email', 160));
  v_dni   text := upper(public.texto_de_fuera(p ->> 'dni', 20));
  v_ref   text;
  v_ya    uuid;
  v_segundos int := coalesce((p ->> 'segundos')::int, 0);
begin
  if public.texto_de_fuera(p ->> 'apellido_de_soltera', 100) is not null
     or v_segundos < 6 then
    return jsonb_build_object('ok', true, 'referencia', public.referencia_corta('SOC'));
  end if;

  if not public.altas_hay_sitio('socio') then
    return jsonb_build_object('ok', false, 'motivo', 'demasiados',
      'mensaje', 'Ahora mismo no podemos recoger más altas. Prueba dentro de un rato o llámanos.');
  end if;

  if v_email is null or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return jsonb_build_object('ok', false, 'motivo', 'correo',
      'mensaje', 'Ese correo no parece bien escrito. Revísalo, por favor.');
  end if;

  if public.texto_de_fuera(p ->> 'nombre', 120) is null or v_dni is null
     or public.texto_de_fuera(p ->> 'telefono', 30) is null then
    return jsonb_build_object('ok', false, 'motivo', 'faltan',
      'mensaje', 'Faltan el nombre, el DNI o el teléfono.');
  end if;

  if coalesce((p ->> 'acepta_normas')::boolean, false) is not true then
    return jsonb_build_object('ok', false, 'motivo', 'normas',
      'mensaje', 'Hay que aceptar las normas del club para hacerse socio.');
  end if;

  select id into v_ya from public.altas_socio
   where lower(email) = v_email and upper(dni) = v_dni
     and created_at > now() - interval '1 hour'
   limit 1;

  if v_ya is not null then
    return jsonb_build_object('ok', true, 'repetida', true,
      'referencia', (select referencia from public.altas_socio where id = v_ya));
  end if;

  v_ref := public.referencia_corta('SOC');

  insert into public.altas_socio (
    referencia, nombre, apellidos, dni, fecha_nacimiento, sexo,
    direccion, cp, localidad, provincia, email, telefono, secciones,
    acepta_normas, texto_normas,
    permiso_imagen, permiso_imagen_ambitos, texto_imagen,
    texto_condiciones, ip, navegador
  ) values (
    v_ref,
    public.texto_de_fuera(p ->> 'nombre', 120),
    public.texto_de_fuera(p ->> 'apellidos', 120),
    v_dni,
    nullif(p ->> 'fecha_nacimiento', '')::date,
    public.texto_de_fuera(p ->> 'sexo', 10),
    public.texto_de_fuera(p ->> 'direccion', 200),
    public.texto_de_fuera(p ->> 'cp', 10),
    public.texto_de_fuera(p ->> 'localidad', 80),
    public.texto_de_fuera(p ->> 'provincia', 80),
    v_email,
    public.texto_de_fuera(p ->> 'telefono', 30),
    case when p ? 'secciones'
         then array(select jsonb_array_elements_text(p -> 'secciones'))
         else null end,
    true,
    public.texto_de_fuera(p ->> 'texto_normas', 2000),
    (p ->> 'permiso_imagen')::boolean,
    case when p ? 'permiso_imagen_ambitos'
         then array(select jsonb_array_elements_text(p -> 'permiso_imagen_ambitos'))
         else null end,
    public.texto_de_fuera(p ->> 'texto_imagen', 600),
    public.texto_de_fuera(p ->> 'texto_condiciones', 2000),
    public.ip_peticion(),
    public.navegador_peticion()
  );

  return jsonb_build_object('ok', true, 'referencia', v_ref);
end;
$$;


-- ------------------------------------------------------------
-- FIRMAR UNA ORDEN DE DOMICILIACIÓN
--
-- No firma si el club no ha puesto todavía el texto legal del
-- mandato. Es a propósito: una firma sobre un texto que nos hemos
-- inventado no vale para nada y encima da la falsa sensación de que
-- el trámite está hecho.
--
-- Y se guarda el texto que se le enseñó, sacado de la base en este
-- mismo momento; NO el que mande el navegador, que podría ser
-- cualquier cosa.
-- ------------------------------------------------------------
create or replace function public.firmar_mandato_sepa(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_iban  text := upper(replace(coalesce(p ->> 'iban', ''), ' ', ''));
  v_texto public.sepa_mandato_texto%rowtype;
  v_firma text := coalesce(p ->> 'firma_png', '');
  v_ref   text;
  v_segundos int := coalesce((p ->> 'segundos')::int, 0);
begin
  if public.texto_de_fuera(p ->> 'apellido_de_soltera', 100) is not null
     or v_segundos < 6 then
    return jsonb_build_object('ok', true, 'referencia', public.referencia_corta('SEPA'));
  end if;

  if not public.altas_hay_sitio('sepa') then
    return jsonb_build_object('ok', false, 'motivo', 'demasiados',
      'mensaje', 'Ahora mismo no podemos recoger más órdenes. Prueba dentro de un rato.');
  end if;

  select * into v_texto from public.sepa_mandato_texto where activo limit 1;
  if v_texto.id is null then
    return jsonb_build_object('ok', false, 'motivo', 'sin-texto',
      'mensaje', 'Todavía no se puede firmar aquí. Escríbenos y lo hacemos contigo.');
  end if;

  if v_iban !~ '^[A-Z]{2}[0-9A-Z]{13,32}$' then
    return jsonb_build_object('ok', false, 'motivo', 'iban',
      'mensaje', 'Revisa el número de cuenta: un IBAN español son 24 caracteres y empieza por ES.');
  end if;

  if public.texto_de_fuera(p ->> 'titular', 140) is null then
    return jsonb_build_object('ok', false, 'motivo', 'titular',
      'mensaje', 'Falta el nombre del titular de la cuenta.');
  end if;

  -- Una firma de verdad ocupa. Si llega algo diminuto es que se
  -- pulsó «firmar» sin dibujar nada.
  if v_firma !~ '^data:image/png;base64,' or length(v_firma) < 800 then
    return jsonb_build_object('ok', false, 'motivo', 'firma',
      'mensaje', 'Falta la firma. Dibújala con el dedo en el recuadro.');
  end if;
  if length(v_firma) > 400000 then
    return jsonb_build_object('ok', false, 'motivo', 'firma',
      'mensaje', 'La firma no se ha podido guardar. Bórrala y vuelve a intentarlo.');
  end if;

  v_ref := public.referencia_corta('SEPA');

  insert into public.mandatos_sepa (
    referencia, origen, alta_escuela_id, alta_socio_id,
    titular, iban, direccion, cp, localidad, tipo_pago,
    lugar_firma, firma_png, texto_mandato,
    cif_acreedor, identificador_acreedor, ip, navegador
  ) values (
    v_ref,
    coalesce(public.texto_de_fuera(p ->> 'origen', 20), 'portal'),
    nullif(p ->> 'alta_escuela_id', '')::uuid,
    nullif(p ->> 'alta_socio_id', '')::uuid,
    public.texto_de_fuera(p ->> 'titular', 140),
    v_iban,
    public.texto_de_fuera(p ->> 'direccion', 200),
    public.texto_de_fuera(p ->> 'cp', 10),
    public.texto_de_fuera(p ->> 'localidad', 80),
    coalesce(public.texto_de_fuera(p ->> 'tipo_pago', 20), 'recurrente'),
    coalesce(public.texto_de_fuera(p ->> 'lugar_firma', 60), 'Alicante'),
    v_firma,
    v_texto.texto,            -- el de la base, no el del navegador
    v_texto.cif_acreedor,
    v_texto.identificador_acreedor,
    public.ip_peticion(),
    public.navegador_peticion()
  );

  return jsonb_build_object('ok', true, 'referencia', v_ref);
end;
$$;


-- ------------------------------------------------------------
-- ABRIR UN ENLACE DE RENOVACIÓN
--
-- Esta es la única función de todas que LEE. Y lee lo justo: el
-- nombre del niño, su grupo, sus días y lo que llevó el año pasado.
-- Ni el DNI, ni el SIP, ni el teléfono, ni la dirección, ni nada de
-- la familia.
--
-- CONTRA EL QUE PRUEBE CÓDIGOS. El freno cuenta también los
-- intentos de abrir un enlace, así que probar códigos al azar se
-- corta en doce por hora. Y como el código son 32 caracteres al
-- azar, doce intentos por hora no llegan a ningún sitio ni en mil
-- años.
--
-- (Se escribe `extensions.digest` con el nombre del cajón delante
-- porque estas funciones tienen fijado a dónde pueden mirar, y las
-- de cifrado viven en otro cajón. Si no se dice, no las encuentra.)
--
-- La respuesta es la misma cuando el código no existe, cuando ha
-- caducado y cuando ya se contestó: «este enlace ya no vale». Así
-- no se puede averiguar cuáles existen y cuáles no.
-- ------------------------------------------------------------
create or replace function public.renovacion_ver(p_token text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_hash text := encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');
  v_r    public.renovaciones%rowtype;
  v_a    public.atletas%rowtype;
  v_g    public.grupos%rowtype;
  v_ant  public.renovaciones%rowtype;
begin
  if not public.altas_hay_sitio('renovacion-ver') then
    return jsonb_build_object('ok', false, 'motivo', 'demasiados');
  end if;

  select * into v_r from public.renovaciones
   where token_hash = v_hash and caduca_en > now() and respondida_en is null;

  if v_r.id is null then
    return jsonb_build_object('ok', false, 'motivo', 'no-vale');
  end if;

  select * into v_a from public.atletas where id = v_r.atleta_id;
  select * into v_g from public.grupos  where id = v_a.grupo_id;

  -- Lo que llevó el año pasado, si lo sabemos. El club ya lo sabe:
  -- que se note, en vez de volver a preguntarlo.
  select * into v_ant from public.renovaciones
   where atleta_id = v_r.atleta_id and respondida_en is not null
   order by respondida_en desc limit 1;

  return jsonb_build_object(
    'ok', true,
    'temporada', v_r.temporada,
    'nombre', trim(coalesce(v_a.nombre, '') || ' ' || coalesce(v_a.apellidos, '')),
    'nombre_corto', coalesce(v_a.nombre_corto, v_a.nombre),
    'ano_nacimiento', extract(year from v_a.fecha_nacimiento)::int,
    'grupo', v_g.nombre,
    'grupo_horario', v_g.horario,
    'turno', v_g.turno,
    'talla_camiseta', v_ant.talla_camiseta,
    'talla_sudadera', v_ant.talla_sudadera,
    'forma_pago', v_ant.forma_pago
  );
end;
$$;


-- ------------------------------------------------------------
-- CONTESTAR UNA RENOVACIÓN
-- Tres respuestas y una salida. «Este año no sigue» se guarda igual
-- de bien que un sí: si no, la baja llega por WhatsApp en octubre,
-- o no llega.
-- ------------------------------------------------------------
create or replace function public.renovacion_responder(p_token text, p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_hash text := encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');
  v_id   uuid;
begin
  if not public.altas_hay_sitio('renovacion') then
    return jsonb_build_object('ok', false, 'motivo', 'demasiados',
      'mensaje', 'Ahora mismo no podemos recogerlo. Prueba dentro de un rato.');
  end if;

  select id into v_id from public.renovaciones
   where token_hash = v_hash and caduca_en > now() and respondida_en is null;

  if v_id is null then
    return jsonb_build_object('ok', false, 'motivo', 'no-vale',
      'mensaje', 'Este enlace ya no vale. Escríbenos y te mandamos otro.');
  end if;

  update public.renovaciones set
    respondida_en   = now(),
    sigue           = coalesce((p ->> 'sigue')::boolean, true),
    motivo_no_sigue = public.texto_de_fuera(p ->> 'motivo_no_sigue', 500),
    turno           = public.texto_de_fuera(p ->> 'turno', 20),
    talla_camiseta  = public.texto_de_fuera(p ->> 'talla_camiseta', 10),
    talla_sudadera  = public.texto_de_fuera(p ->> 'talla_sudadera', 10),
    forma_pago      = public.texto_de_fuera(p ->> 'forma_pago', 20),
    cambios         = public.texto_de_fuera(p ->> 'cambios', 600),
    ip              = public.ip_peticion(),
    navegador       = public.navegador_peticion()
  where id = v_id;

  return jsonb_build_object('ok', true);
end;
$$;


-- ------------------------------------------------------------
-- CREAR LOS ENLACES DE RENOVACIÓN (esto lo hace el club, no la web)
--
-- Devuelve el código EN CLARO una sola vez, aquí y ahora, para que
-- quien lo llama pueda montar el enlace y mandarlo. Después ya no
-- se puede recuperar: en la tabla solo queda la huella. Si se
-- pierde, se genera otro.
-- ------------------------------------------------------------
create or replace function public.renovacion_crear(p_atleta_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_token text;
  v_id    uuid;
begin
  if not (public.es_admin() or public.es_tesoreria()) then
    raise exception 'Solo administración puede crear enlaces de renovación';
  end if;

  v_token := encode(extensions.gen_random_bytes(24), 'hex');

  insert into public.renovaciones (atleta_id, token_hash, creado_por)
  values (p_atleta_id,
          encode(extensions.digest(v_token, 'sha256'), 'hex'),
          (select id from public.perfiles where email = (auth.jwt() ->> 'email')))
  on conflict (temporada, atleta_id) do update
    set token_hash = excluded.token_hash,
        caduca_en  = now() + interval '90 days'
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id, 'token', v_token);
end;
$$;


-- ============================================================
-- 8 · QUIÉN PUEDE LLAMAR A CADA PUERTA
-- ------------------------------------------------------------
-- Por defecto Postgres deja llamar a una función a todo el mundo,
-- así que primero se le quita el permiso a todos y luego se le da a
-- quien toca. Si no se hace en este orden, `revoke` después no
-- sirve de nada.
--
-- Ojo con `altas_hay_sitio`, `ip_peticion` y las demás de dentro:
-- NO se le dan a nadie. Se usan desde las otras funciones, que
-- corren con los papeles del dueño, y desde fuera no se llaman.
-- ============================================================
revoke all on function public.enviar_alta_escuela(jsonb)      from public;
revoke all on function public.enviar_alta_socio(jsonb)        from public;
revoke all on function public.firmar_mandato_sepa(jsonb)      from public;
revoke all on function public.renovacion_ver(text)            from public;
revoke all on function public.renovacion_responder(text, jsonb) from public;
revoke all on function public.renovacion_crear(uuid)          from public;
revoke all on function public.altas_hay_sitio(text)           from public;
revoke all on function public.ip_peticion()                   from public;
revoke all on function public.navegador_peticion()            from public;

grant execute on function public.enviar_alta_escuela(jsonb)      to anon, authenticated;
grant execute on function public.enviar_alta_socio(jsonb)        to anon, authenticated;
grant execute on function public.firmar_mandato_sepa(jsonb)      to anon, authenticated;
grant execute on function public.renovacion_ver(text)            to anon, authenticated;
grant execute on function public.renovacion_responder(text, jsonb) to anon, authenticated;
grant execute on function public.renovacion_crear(uuid)          to authenticated;
grant execute on function public.temporada_actual()              to anon, authenticated;


-- ============================================================
-- 9 · UNA NOTA PARA QUIEN VENGA DESPUÉS
-- ------------------------------------------------------------
-- Lo que falta y NO se ha inventado aquí:
--
--   · EL TEXTO LEGAL DEL MANDATO SEPA, con el identificador de
--     acreedor. Va en `sepa_mandato_texto` y lo tiene que dar el
--     gestor o el banco. Mientras no esté, la pantalla de firmar lo
--     dice y ofrece hacerlo por teléfono.
--
--   · CONVERTIR UN ALTA EN ATLETA. A propósito no se hace sola: un
--     alta es una solicitud y alguien del club tiene que mirarla.
--     Cuando exista el botón en el panel, rellenará `atleta_id` en
--     `altas_escuela_ninos`.
--
--   · EL AVISO AL PANEL cuando entra un alta. La tabla `avisos` ya
--     existe; hace falta decidir a quién le llega, que es una
--     persona con nombre y no «al club».
--
--   · EL PDF de la orden firmada y el correo de confirmación. Se
--     generan fuera de la base.
-- ============================================================
