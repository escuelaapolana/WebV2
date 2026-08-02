-- ============================================================
-- 052 · CÓMO SE PAGA · los datos de pago del club, en la base
-- ------------------------------------------------------------
-- QUÉ RESUELVE (encargo del dueño, textual):
--   «En el portal se ven los recibos pendientes pero no se dice
--    cómo ni dónde pagar.»
--
--   Hasta hoy, quien entraba en su zona veía "Recibo pendiente ·
--   124,00 €" y ahí se acababa la información: ni el método, ni
--   cuándo se pasa, ni a qué cuenta se transfiere lo que no es la
--   cuota (licencia federativa, ropa…), ni a quién preguntar si
--   el recibo vuelve devuelto.
--
-- CÓMO QUEDA:
--   Una fila por cuenta del club. Hoy son dos:
--     · 'escuela' → escuela de atletismo (domiciliación en dos pagos)
--     · 'club'    → socios y adultos      (domiciliación en un pago)
--   El panel («Cobros → Cómo se paga») rellena y edita esas filas, y
--   las zonas de pagos del portal (atleta, familia y socio) pintan un
--   bloque «Cómo se paga» con lo que haya aquí.
--
-- ⚠️ POR QUÉ ESTA TABLA NACE VACÍA Y NO SE PRECARGA
--   El repositorio de código de la web es PÚBLICO. Un número de
--   cuenta escrito en un HTML, en un JS o en un `insert` de esta
--   migración quedaría publicado para cualquiera, para siempre y con
--   histórico en Git. Por eso:
--     · esta migración NO trae ni un solo dato real: solo el molde;
--     · los datos los carga el club por psql o desde el panel;
--     · la web nunca los lleva escritos: los pide a esta tabla.
--   Si algún día alguien va a pegar un IBAN en un archivo del
--   repositorio: no. Va aquí.
--
-- QUIÉN ENTRA (lo importante de todo el archivo):
--   · Lectura → SOLO usuarios con sesión iniciada (`authenticated`).
--     El visitante anónimo (`anon`) NO puede leer nada de esta tabla.
--     Doble candado, porque uno solo se puede escapar:
--       1) no se le concede el permiso SELECT al rol `anon`, y
--          además se le revoca de forma explícita (Supabase reparte
--          permisos por defecto a `anon` en el esquema public, así
--          que revocar no sobra: hace falta);
--       2) no existe ninguna política de RLS que deje leer a `anon`.
--   · Escritura → solo administración, es_admin(); el mismo candado
--     que tienen contenido_secciones, imagenes_web o colaboradores.
--
-- Idempotente: se puede relanzar sin perder lo que el club haya
--   cargado (no borra filas ni pisa columnas ya existentes).
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/052_info_pagos.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LA TABLA
-- ------------------------------------------------------------
create table if not exists public.info_pagos (
  -- Qué cuenta es. Texto corto y estable porque la web pregunta por él:
  -- 'escuela' (escuela de atletismo) y 'club' (socios y adultos).
  clave                  text primary key,

  -- Cómo se llama esta cuenta para quien la lee, p. ej. «Escuela de
  -- atletismo» o «Club · socios y adultos». Es lo que titula el bloque.
  titulo                 text not null,

  -- --- Los datos bancarios: SOLO viven aquí, nunca en el repositorio ---
  -- A nombre de quién está la cuenta (hoy, «Club Atletismo Apolana»).
  titular                text,
  -- El número de cuenta. NULL mientras el club no lo cargue.
  iban                   text,
  -- Banco o caja, por si a alguien le ayuda a reconocer el cargo en su extracto.
  banco                  text,

  -- --- Cómo y cuándo se cobra la cuota ---
  -- El método en cristiano: «Domiciliación bancaria», «Transferencia»…
  metodo                 text,
  -- Cuándo se pasan los recibos, explicado como se lo contarías a una
  -- familia: «En dos pagos: uno en octubre y otro en diciembre», o
  -- «Un solo pago al año». Nada de jerga contable.
  cuando                 text,

  -- --- Los pagos que NO son la cuota (licencia, ropa, bonos…) ---
  -- Qué se paga por transferencia o tarjeta y cómo. Texto libre.
  otros_pagos            text,
  -- Frase corta que encabeza los ejemplos de concepto.
  concepto_transferencia text,
  -- Qué escribir en el concepto de la transferencia. NO es un texto
  -- fijo: depende de para qué sea el pago. Se guarda como una lista,
  -- UN EJEMPLO POR LÍNEA, tal cual hay que copiarlo. Por ejemplo, una
  -- línea por cada cosa que se cobre aparte (licencia, bono, ropa…),
  -- cada una con la pinta de «Concepto · nombre de la persona».
  -- El panel lo edita en una caja de texto normal y la web lo pinta
  -- como una lista con su botón de copiar.
  ejemplos_concepto      text,

  -- --- Recibo devuelto ---
  -- Qué pasa si el banco devuelve el recibo. El circuito del club es:
  -- se avisa a la persona, se pregunta qué ha podido pasar, y de ahí
  -- salen dos caminos: volver a pasar el recibo o pagarlo por
  -- transferencia. Este texto se enseña SOLO a quien tiene un recibo
  -- impagado o devuelto, y con tono de «no pasa nada, hay solución».
  texto_devuelto         text,

  -- --- A quién preguntar ---
  -- La cadena de contacto para dudas de pagos, tal y como funciona el
  -- club, en dos escalones y con el pie de la web como red:
  --   1º  contacto_*     → quien lleva los pagos (la contable).
  --   2º  contacto_alt_* → el responsable de la sección o, para
  --                        cualquier cosa, el presidente del club.
  --   3º  si los dos escalones están vacíos, el portal enseña el
  --        contacto general del club que YA está publicado en la web
  --        (assets/js/datos.js). Así nunca hace falta inventarse un
  --        teléfono ni escribirlo a fuego en el código.
  contacto_nombre        text,
  contacto_tel           text,
  contacto_email         text,
  contacto_alt_nombre    text,
  contacto_alt_tel       text,
  contacto_alt_email     text,

  -- Cualquier otra aclaración que el club quiera añadir al bloque.
  nota                   text,

  -- Orden en que salen cuando se enseñan las dos cuentas a la vez.
  orden                  integer not null default 0,
  -- Desactivar en vez de borrar: deja de salir en el portal sin perder los datos.
  activo                 boolean not null default true,
  updated_at             timestamptz not null default now()
);

comment on table public.info_pagos is
  'Cómo se paga en el club, por cuenta (escuela / club): método, cuándo se pasan los recibos, datos bancarios para lo que no es la cuota, qué hacer si un recibo vuelve devuelto y a quién preguntar. DATOS SENSIBLES: solo los leen los usuarios con sesión iniciada; NUNCA se escriben en el repositorio de la web.';
comment on column public.info_pagos.iban is
  'Número de cuenta. Vive solo aquí: el repositorio de la web es público y no puede contenerlo.';
comment on column public.info_pagos.ejemplos_concepto is
  'Qué poner en el concepto de la transferencia, un ejemplo por línea, tal cual hay que copiarlo.';

-- Columnas por si la tabla ya existía de una pasada anterior.
alter table public.info_pagos add column if not exists titular                text;
alter table public.info_pagos add column if not exists iban                   text;
alter table public.info_pagos add column if not exists banco                  text;
alter table public.info_pagos add column if not exists metodo                 text;
alter table public.info_pagos add column if not exists cuando                 text;
alter table public.info_pagos add column if not exists otros_pagos            text;
alter table public.info_pagos add column if not exists concepto_transferencia text;
alter table public.info_pagos add column if not exists ejemplos_concepto      text;
alter table public.info_pagos add column if not exists texto_devuelto         text;
alter table public.info_pagos add column if not exists contacto_nombre        text;
alter table public.info_pagos add column if not exists contacto_tel           text;
alter table public.info_pagos add column if not exists contacto_email         text;
alter table public.info_pagos add column if not exists contacto_alt_nombre    text;
alter table public.info_pagos add column if not exists contacto_alt_tel       text;
alter table public.info_pagos add column if not exists contacto_alt_email     text;
alter table public.info_pagos add column if not exists nota                   text;
alter table public.info_pagos add column if not exists orden                  integer not null default 0;
alter table public.info_pagos add column if not exists activo                 boolean not null default true;
alter table public.info_pagos add column if not exists updated_at             timestamptz not null default now();

-- La web pide siempre «las activas, por orden»: este índice es justo eso.
create index if not exists info_pagos_activo_orden_idx
  on public.info_pagos (activo, orden);

-- La fecha de última edición se pone sola (misma función que usan
-- plantillas_email y peticiones_redes).
drop trigger if exists info_pagos_updated_at on public.info_pagos;
create trigger info_pagos_updated_at
  before update on public.info_pagos
  for each row execute function public.handle_updated_at();

-- ------------------------------------------------------------
-- 2 · CANDADO (RLS) · aquí sí que no se puede aflojar
-- ------------------------------------------------------------
alter table public.info_pagos enable row level security;

-- Por si quedara una política vieja con nombre parecido de otra pasada.
drop policy if exists "lectura publica info_pagos"    on public.info_pagos;
drop policy if exists "lectura info_pagos con sesion" on public.info_pagos;
drop policy if exists "admin gestiona info_pagos"     on public.info_pagos;

-- LECTURA · solo con sesión iniciada. Fíjate en el «to authenticated»:
-- sin él, la política valdría también para el visitante anónimo.
create policy "lectura info_pagos con sesion"
  on public.info_pagos
  for select
  to authenticated
  using (true);

-- ESCRITURA · solo administración.
create policy "admin gestiona info_pagos"
  on public.info_pagos
  for all
  to authenticated
  using (es_admin())
  with check (es_admin());

-- Permisos de tabla (la otra mitad del candado, la que no es RLS).
-- Supabase concede permisos por defecto a `anon` sobre las tablas
-- nuevas del esquema public: por eso hay que revocárselos a mano.
revoke all on public.info_pagos from anon;
revoke all on public.info_pagos from public;
grant select, insert, update, delete on public.info_pagos to authenticated;

commit;

-- ============================================================
-- 3 · SIN PRECARGA · la tabla nace VACÍA, y es a propósito
-- ------------------------------------------------------------
-- Aquí NO va ningún insert. Ni de prueba, ni de ejemplo, ni
-- «para que se vea algo»: en cuanto un número de cuenta entra en
-- este archivo, queda publicado en el repositorio público y en el
-- histórico de Git para siempre.
--
-- Los datos se cargan de una de estas dos maneras:
--   a) desde el panel: Cobros → «Cómo se paga» → Rellenar; o
--   b) por psql, en local, con una orden como esta (los valores
--      reales los escribe el club en el momento, nunca aquí):
--
--      insert into public.info_pagos (clave, titulo, titular, iban, orden)
--      values ('escuela', 'Escuela de atletismo', '…', '…', 1)
--      on conflict (clave) do update set
--        titulo = excluded.titulo, titular = excluded.titular,
--        iban = excluded.iban, updated_at = now();
--
-- Mientras la tabla esté vacía, el portal simplemente no pinta el
-- bloque «Cómo se paga»: no enseña nada a medias.
-- ============================================================

-- --- Comprobación rápida: molde y candado, sin enseñar el IBAN -------
select clave, titulo, orden, activo,
       (iban is not null) as tiene_cuenta,
       (contacto_tel is not null or contacto_email is not null
        or contacto_alt_tel is not null or contacto_alt_email is not null) as tiene_contacto
  from public.info_pagos
 order by orden, clave;

-- Quién puede leer la tabla (aquí NO debe aparecer «anon»).
select grantee, privilege_type
  from information_schema.role_table_grants
 where table_schema = 'public' and table_name = 'info_pagos'
 order by grantee, privilege_type;
