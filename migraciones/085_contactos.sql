-- ============================================================
-- 085 · QUIÉN LLEVA QUÉ · las personas de contacto, en la base
-- ------------------------------------------------------------
-- QUÉ RESUELVE (encargo del dueño):
--   «Los teléfonos, los correos y los responsables están escritos a
--    mano dentro de las páginas. El mismo teléfono aparece en tres
--    sitios distintos, y el día que cambie un responsable hay que
--    buscarlos por el código y siempre se queda alguno viejo.»
--
--   Hoy el teléfono de Mario está escrito tres veces (dos en
--   /escuela-natacion/ y una en /natacion/), el de Andrés dos veces
--   en /competicion/, y el cargo de cada miembro de la junta otra vez
--   en /club/. Cambiar a un responsable eran seis ediciones de HTML.
--
-- CÓMO QUEDA:
--   Una fila por persona. La web pregunta por ella de dos maneras:
--     · por su clave  ('mario')     → la junta directiva de /club/
--     · por su sección ('natacion') → «el responsable de natación»,
--       sin que la página tenga que saber quién es hoy.
--   El panel («Club → Personas de contacto») las edita.
--
-- ============================================================
-- ⚠️ LO MÁS IMPORTANTE DE ESTE ARCHIVO · TELÉFONOS PERSONALES
-- ------------------------------------------------------------
--   Estos son móviles y correos PERSONALES, y van en una web pública
--   que Google indexa. Por eso cada persona tiene DOS interruptores
--   independientes:
--
--       publicar_telefono     publicar_email
--
--   Y el interruptor NO es cosa del JavaScript de la página: si lo
--   fuera, bastaría con abrir la consola del navegador para leer el
--   móvil de cualquiera. Lo tapa LA BASE DE DATOS:
--
--     · La tabla `contactos` NO la puede leer el visitante anónimo.
--       Ni una fila, ni una columna.
--     · Lo público es la vista `contactos_publicos`, que devuelve el
--       teléfono SOLO si publicar_telefono está puesto, y el correo
--       SOLO si publicar_email está puesto. Si no, devuelve nulo:
--       el dato no sale de la base, así que no hay nada que espiar.
--
--   Por defecto se ha dejado publicado EXACTAMENTE lo que ya estaba
--   publicado en la web el día de este cambio, ni un dato más
--   (ver el apartado 5). Quitar uno es ahora un clic, y antes era
--   buscar por seis archivos.
--
-- ⚠️ NINGÚN DATO PERSONAL SE ESCRIBE EN ESTE ARCHIVO
--   Ni un teléfono, ni un correo. Este repositorio es PÚBLICO: lo que
--   se escribe aquí queda a la vista de cualquiera y en el histórico
--   de Git para siempre. El interruptor `publicar_telefono` protege
--   la WEB; no protege este archivo.
--   Por eso esta migración trae el molde, los nombres y los cargos
--   (que ya salen en la junta directiva de /club/), pero los datos de
--   contacto van derechos a la base, por el mismo camino que los IBAN
--   de `info_pagos` (migración 052). Ver el apartado 7.
--
-- Idempotente: se puede relanzar sin pisar lo que el club haya
--   editado desde el panel (la siembra es `do nothing`).
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/085_contactos.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LA TABLA
-- ------------------------------------------------------------
create table if not exists public.contactos (
  -- Quién es, en corto y estable, porque la web pregunta por él:
  -- 'adrian', 'mario', 'andres', 'isabel'. No se cambia nunca aunque
  -- la persona cambie de cargo: es la etiqueta del hueco.
  clave              text primary key,

  -- El nombre completo, como sale en la junta directiva de /club/.
  nombre             text not null,

  -- El nombre como se dice de pasada en una línea de contacto
  -- («Mario Clavero · su teléfono»). Si está vacío se usa el largo.
  nombre_corto       text,

  -- El cargo en una palabra, que es lo que cabe debajo de la foto en
  -- la junta directiva: «Presidente», «Secretario», «Tesorero».
  cargo              text,

  -- El cargo entero, tal y como lo cuenta el club cuando hay sitio:
  -- «Tesorero · coordinador de la escuela · responsable de pista».
  cargo_detalle      text,

  -- --- Las dos vías de contacto, cada una con su interruptor ---
  telefono           text,
  email              text,

  -- ⚠️ Los interruptores de privacidad. Apagados de fábrica: si
  -- alguien da de alta a una persona nueva y se olvida de mirar esto,
  -- lo que pasa es que su móvil NO sale. El fallo seguro es callar.
  publicar_telefono  boolean not null default false,
  publicar_email     boolean not null default false,

  -- De qué sección es, para que la página no tenga que saberse el
  -- nombre: /natacion/ pide 'natacion' y /competicion/ pide 'pista'.
  -- Hoy se usan:
  --   'natacion'       · natación de adultos y escuela de natación
  --   'pista'          · atletismo en pista y competición
  --   'running'        · La Tribu, Madre Tierra y Kilómetro Cero
  --   'escuela'        · escuela de atletismo
  --   'club'           · presidencia, lo que no es de una sección
  --   'administracion' · socios, cuotas y papeleo
  -- Vacío = esta persona no es de ninguna sección en concreto.
  seccion            text,

  -- ¿Es QUIEN RESPONDE de esa sección? Una sección tiene un solo
  -- responsable, pero puede tener más gente dentro: los entrenadores
  -- de running son de 'running' y no son responsables de la sección.
  -- Cuando una página pide «el de natación» a secas, se le da a éste.
  es_responsable     boolean not null default false,

  -- Quién es, contado en un párrafo: la trayectoria que el club
  -- enseña en la ficha de un entrenador. Vacío en casi todas las
  -- filas; solo lo usan las fichas que llevan presentación.
  descripcion        text,

  -- Los números que el club enseña en la ficha, UNO POR LÍNEA y con
  -- la forma «Etiqueta: valor», tal cual hay que leerlos:
  --     +400: atletas entrenados
  --     +20 años: como atleta federado
  --     2010: entrenador desde
  -- Se guarda como texto libre a propósito: así el club corrige el
  -- número Y la etiqueta desde el panel, sin tocar código. Es lo que
  -- permite arreglar un «Entrenador desde» que debería decir
  -- «Entrenadora desde» sin que haga falta un programador.
  datos              text,

  -- Orden en que salen cuando se enseñan varias juntas.
  orden              integer not null default 0,
  -- Apagar en vez de borrar: deja de salir en la web sin perder nada.
  activo             boolean not null default true,
  updated_at         timestamptz not null default now()
);

comment on table public.contactos is
  'Las personas de contacto del club: quién es, su cargo, de qué sección responde y cómo se le localiza. DATOS PERSONALES: la web pública NO lee esta tabla, lee la vista contactos_publicos, que tapa el teléfono y el correo de quien no los tenga marcados como publicables.';
comment on column public.contactos.publicar_telefono is
  'Si está apagado, contactos_publicos devuelve NULL en el teléfono: el móvil no sale de la base de datos.';
comment on column public.contactos.publicar_email is
  'Si está apagado, contactos_publicos devuelve NULL en el correo.';
comment on column public.contactos.seccion is
  'De qué sección es responsable. Es como la web pide «el responsable de natación» sin saberse el nombre.';

-- Columnas por si la tabla ya existía de una pasada anterior.
alter table public.contactos add column if not exists nombre_corto      text;
alter table public.contactos add column if not exists cargo             text;
alter table public.contactos add column if not exists cargo_detalle     text;
alter table public.contactos add column if not exists telefono          text;
alter table public.contactos add column if not exists email             text;
alter table public.contactos add column if not exists publicar_telefono boolean not null default false;
alter table public.contactos add column if not exists publicar_email    boolean not null default false;
alter table public.contactos add column if not exists seccion           text;
alter table public.contactos add column if not exists es_responsable    boolean not null default false;
alter table public.contactos add column if not exists descripcion       text;
alter table public.contactos add column if not exists datos             text;
alter table public.contactos add column if not exists orden             integer not null default 0;
alter table public.contactos add column if not exists activo            boolean not null default true;
alter table public.contactos add column if not exists updated_at        timestamptz not null default now();

-- Una sección tiene UN responsable. Si mañana se le pasa el mando de
-- natación a otra persona, este índice obliga a quitárselo a Mario
-- primero, en vez de dejar dos y que la web elija al azar.
-- Ojo a la condición: limita los RESPONSABLES, no la gente. Una
-- sección puede tener todos los entrenadores que haga falta.
drop index if exists public.contactos_seccion_unica_idx;
create unique index if not exists contactos_responsable_unico_idx
  on public.contactos (seccion)
  where seccion is not null and activo and es_responsable;

-- La web pide siempre «los activos, por orden».
create index if not exists contactos_activo_orden_idx
  on public.contactos (activo, orden);

-- La fecha de última edición se pone sola (la misma función que usan
-- info_pagos, plantillas_email y peticiones_redes).
drop trigger if exists contactos_updated_at on public.contactos;
create trigger contactos_updated_at
  before update on public.contactos
  for each row execute function public.handle_updated_at();

-- ------------------------------------------------------------
-- 2 · CANDADO (RLS) SOBRE LA TABLA · aquí no entra el anónimo
-- ------------------------------------------------------------
alter table public.contactos enable row level security;

-- Por si quedara alguna política de una pasada anterior.
drop policy if exists "lectura publica contactos"      on public.contactos;
drop policy if exists "lectura contactos con sesion"   on public.contactos;
drop policy if exists "admin gestiona contactos"       on public.contactos;

-- LECTURA de la tabla CRUDA (con teléfonos sin tapar) · solo con
-- sesión iniciada. Fíjate en el «to authenticated»: sin él, la
-- política valdría también para el visitante anónimo.
create policy "lectura contactos con sesion"
  on public.contactos
  for select
  to authenticated
  using (true);

-- ESCRITURA · solo administración, es_admin(); el mismo candado que
-- tienen info_pagos, contenido_secciones, imagenes_web o colaboradores.
create policy "admin gestiona contactos"
  on public.contactos
  for all
  to authenticated
  using (es_admin())
  with check (es_admin());

-- Permisos de tabla (la otra mitad del candado, la que no es RLS).
-- ⚠️ Supabase concede permisos de serie a `anon` sobre las tablas
-- nuevas del esquema public: revocar NO sobra, hace falta.
revoke all on public.contactos from anon;
revoke all on public.contactos from public;
grant select, insert, update, delete on public.contactos to authenticated;

-- ------------------------------------------------------------
-- 3 · LA VISTA PÚBLICA · lo único que ve la web
-- ------------------------------------------------------------
-- Es la que hace de verdad el trabajo de privacidad. Los `case`
-- no son un adorno: si el interruptor está apagado, la columna sale
-- NULA de la base de datos, así que por mucho que alguien abra la
-- consola del navegador no hay nada que leer.
--
-- Mismo patrón que `entrenadores_publicos` (migración 043) y
-- `records_club_publico` (078): vista curada a propósito, con
-- security_invoker = false, y SELECT para anon y authenticated.
-- Se tira y se rehace en vez de `create or replace`: reemplazar una
-- vista solo deja AÑADIR columnas al final, y aquí se han metido
-- algunas por en medio. Así la migración se puede relanzar siempre.
drop view if exists public.contactos_publicos;
create view public.contactos_publicos as
  select c.clave,
         c.nombre,
         coalesce(nullif(btrim(c.nombre_corto), ''), c.nombre) as nombre_corto,
         c.cargo,
         c.cargo_detalle,
         c.seccion,
         c.es_responsable,
         c.descripcion,
         c.datos,
         c.orden,
         case when c.publicar_telefono then nullif(btrim(c.telefono), '') end as telefono,
         case when c.publicar_email    then nullif(btrim(c.email),    '') end as email
    from public.contactos c
   where c.activo;

comment on view public.contactos_publicos is
  'Lo único de `contactos` que puede leer la web pública. Tapa el teléfono y el correo de quien no los tenga marcados como publicables: los devuelve nulos, no los devuelve escondidos.';

-- Vista curada a propósito (SECURITY DEFINER): enseña solo lo que se
-- puede enseñar, así que puede leerla cualquiera que visite la web.
alter view public.contactos_publicos set (security_invoker = false);

revoke all on public.contactos_publicos from public;
grant select on public.contactos_publicos to anon, authenticated;

commit;

-- ============================================================
-- 4 · LAS PERSONAS DE HOY · SIN SUS TELÉFONOS NI SUS CORREOS
-- ------------------------------------------------------------
-- ⚠️ AQUÍ NO HAY NI UN TELÉFONO NI UN CORREO, Y ES LA REGLA DE LA CASA
--   Este repositorio es PÚBLICO. Un móvil escrito en una migración
--   está tan a la vista en GitHub como uno escrito en una página, y
--   además queda en el histórico de Git para siempre. El interruptor
--   `publicar_telefono` protege la WEB, no este archivo.
--   Así que los datos de contacto van derechos a la base, por el
--   mismo camino que los IBAN de `info_pagos` (migración 052): se
--   cargan una vez a mano o desde el panel, y no pasan por aquí.
--
--   Lo que sí puede estar escrito: el nombre, el cargo y la sección.
--   Eso ya sale hoy en la junta directiva de /club/ y no es un dato
--   de contacto.
--
-- `do nothing`: si la fila ya existe, esta migración NO la pisa, así
-- que relanzarla nunca borra el teléfono que el club haya cargado.
-- ============================================================
insert into public.contactos
  (clave, nombre, nombre_corto, cargo, cargo_detalle,
   publicar_telefono, publicar_email, seccion, es_responsable, orden)
values
  -- publicar_* = lo que estaba publicado en la web el día del cambio,
  -- ni un dato más. El valor en sí se carga aparte (ver apartado 7).
  ('adrian', 'Adrián Onandía Bieco', 'Adrián Onandía',
   'Presidente', 'Presidente. Creador de la escuela',
   true, false, 'club', true, 1),

  ('andres', 'Andrés Clavero Giménez', 'Andrés Clavero',
   'Tesorero', 'Tesorero · coordinador de la escuela · responsable de atletismo en pista',
   true, false, 'pista', true, 2),

  ('mario', 'Mario Clavero', 'Mario Clavero',
   'Secretario', 'Secretario · responsable de la sección de Natación',
   true, true, 'natacion', true, 3),

  ('isabel', 'Isabel Fuentes Bernal', 'Isabel Fuentes',
   'Contable', 'Contable. Lleva socios y adultos',
   true, true, 'administracion', true, 4)
on conflict (clave) do nothing;

-- Los cuatro de arriba son quien responde de su sección. Se marca
-- aparte porque la columna nació después que las filas.
update public.contactos
   set es_responsable = true
 where clave in ('adrian', 'andres', 'mario', 'isabel')
   and seccion is not null
   and not es_responsable;

-- ------------------------------------------------------------
-- 4b · LOS ENTRENADORES DE RUNNING
-- ------------------------------------------------------------
-- Son de la sección 'running' pero NO son responsables de ella: por
-- eso `es_responsable` va en false y por eso caben los dos.
--
-- ⚠️ SUS TELÉFONOS NO ESTÁN EN ESTE ARCHIVO, Y ES A PROPÓSITO
--   Dos motivos distintos, y los dos importan:
--
--   1) No se publican en la WEB. Se pidió darlos por publicados
--      «porque ya están». Se comprobó, y no lo estaban: no aparecían
--      en /running/ (que hoy no tiene fichas de entrenador) ni en
--      ninguna otra página. Venían de una captura de una versión
--      antigua. Publicarlos no sería «dejarlo como está»: sería sacar
--      dos móviles personales a una web que Google indexa, sin que
--      nadie del club lo haya decidido hoy. Por eso nacen apagados.
--
--   2) No se escriben en este ARCHIVO. Este repositorio es público:
--      cualquiera lee lo que hay aquí, esté apagado en la web o no.
--      Un número escrito en una migración está tan a la vista como
--      uno escrito en una página. Así que van derechos a la base, por
--      el mismo camino que los IBAN: se meten una vez a mano y no
--      pasan por aquí. Estas dos filas nacen SIN teléfono.
--
-- Los números están guardados en la base y encenderlos es un clic en
-- el panel. Esa decisión le toca al club, no a esta migración.
insert into public.contactos
  (clave, nombre, nombre_corto, cargo, cargo_detalle,
   telefono, publicar_telefono, publicar_email,
   seccion, es_responsable, descripcion, datos, orden)
values
  ('nicolas', 'Nicolás Tucci', 'Nicolás Tucci',
   'Entrenador', 'Entrenador de La Tribu Apolana · grupo A, nivel avanzado',
   null, false, false,          -- el teléfono se mete a mano en la base
   'running', false,
   'Atleta federado con licencia nacional desde 2003 y entrenador desde 2009. '
   'Especialista en fondo y medio fondo, con formación oficial de primer y segundo '
   'nivel de la Federación de Atletismo. Más de 15 años de experiencia; ha formado a '
   'más de 400 atletas, desarrollando programas de entrenamiento orientados a la mejora.',
   E'+400: atletas entrenados\n+20 años: como atleta federado\n2010: entrenador desde',
   5),

  ('claudia', 'Claudia Otero', 'Claudia Otero',
   'Entrenadora', 'Entrenadora de Madre Tierra Apolana · grupo B, iniciación',
   null, false, false,          -- el teléfono se mete a mano en la base
   'running', false,
   'Entrenadora de atletismo especializada en medio fondo y fondo. Ex atleta federada, '
   'con amplia trayectoria en el ámbito deportivo y formativo dentro de la disciplina. '
   'Más de 25 años de experiencia; ha trabajado en la formación de atletas de todos los '
   'niveles, desde iniciación hasta alto rendimiento, aplicando una metodología '
   'orientada al desarrollo.',
   -- «Entrenadora desde», en femenino: en la web vieja ponía
   -- «Entrenador desde» y el club pidió corregirlo. Al ser un dato y
   -- no código, se arregla desde el panel el día que haga falta.
   E'+400: atletas entrenados\n+30 años: como atleta federada\n2010: entrenadora desde',
   6)
on conflict (clave) do nothing;

-- ============================================================
-- 5 · LO QUE ESTABA PUBLICADO EL DÍA DE ESTE CAMBIO
-- ------------------------------------------------------------
-- Se deja tal cual estaba, para no destapar ni tapar nada sin querer:
--
--   Adrián  · teléfono SÍ (es el número de la escuela) · correo NO
--   Andrés  · teléfono SÍ (/competicion/)              · correo NO
--   Mario   · teléfono SÍ · correo SÍ (/escuela-natacion/)
--   Isabel  · teléfono SÍ · correo SÍ (/contacto/)
--
-- A partir de aquí lo decide el club desde el panel, sin tocar código.
--
-- 6 · LO QUE NO VA EN ESTA TABLA
-- ------------------------------------------------------------
-- Los datos bancarios NO se duplican aquí. Siguen en `info_pagos`
-- (migración 052) y por una razón de fondo: `info_pagos` solo la
-- pueden leer los usuarios con SESIÓN INICIADA, y `contactos_publicos`
-- la lee cualquier visitante. Son dos audiencias distintas y dos
-- candados distintos; juntarlas obligaría a aflojar uno de los dos.
--
-- `info_pagos` tiene además sus propias columnas de contacto
-- (contacto_nombre / contacto_tel / contacto_email): son «a quién
-- preguntar por un recibo», y se enseñan solo dentro del portal. Se
-- han dejado como estaban: el panel de Cobros las edita ahí y esta
-- pantalla no se mete. Si algún día se quieren unificar, el camino
-- es que info_pagos guarde una `clave` de esta tabla en vez del
-- nombre suelto; hoy no se ha hecho para no tocar el panel de Cobros.
-- ============================================================

-- ============================================================
-- 7 · CÓMO SE CARGAN LOS TELÉFONOS Y LOS CORREOS
-- ------------------------------------------------------------
-- No están en este archivo a propósito (ver la cabecera). Se cargan
-- de una de estas dos maneras:
--
--   a) desde el panel: Club → «Personas de contacto» → Editar; o
--   b) por psql, en local, escribiendo el valor real en el momento:
--
--      update public.contactos
--         set telefono = '…', email = '…'
--       where clave = 'mario';
--
-- Mientras estén vacíos no pasa nada malo: las páginas siguen
-- enseñando lo que llevan escrito de respaldo en su HTML, así que
-- ningún visitante ve un hueco en blanco.
-- ============================================================

-- --- Comprobación 1: qué hay y qué se publica ----------------------
select clave, nombre, cargo, seccion, es_responsable, orden, activo,
       publicar_telefono, publicar_email
  from public.contactos
 order by orden, clave;

-- --- Comprobación 2: lo que ve de verdad un visitante --------------
-- Los entrenadores de running deben salir SIN teléfono.
select clave, nombre_corto, cargo, seccion, es_responsable, telefono, email
  from public.contactos_publicos
 order by orden, clave;

-- --- Comprobación 3: quién puede leer qué --------------------------
-- En `contactos` NO debe aparecer «anon». En `contactos_publicos` sí,
-- pero solo con SELECT.
select table_name, grantee, privilege_type
  from information_schema.role_table_grants
 where table_schema = 'public'
   and table_name in ('contactos', 'contactos_publicos')
   and grantee in ('anon', 'authenticated', 'public')
 order by table_name, grantee, privilege_type;
