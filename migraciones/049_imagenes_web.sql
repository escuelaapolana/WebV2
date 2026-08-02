-- ============================================================
-- 049 · FOTOS DE LA WEB · todos los huecos de imagen, editables desde el panel
-- ------------------------------------------------------------
-- QUÉ RESUELVE (encargo del dueño, textual):
--   «Desde la edición de páginas desde admin no puedo cambiar la foto
--    de la página principal. Bueno, ni el texto.»
--   «Quiero poder editar toooodas las fotos.»
--
--   Hasta ahora solo se podía cambiar la foto de CABECERA de las 14
--   secciones (tabla contenido_secciones). El resto de fotos de la web
--   —la foto grande de la portada, el mosaico, la tira de Instagram,
--   los retratos de la junta, las sedes, la galería…— estaban escritas
--   a mano dentro de cada archivo HTML. Y la PORTADA no existía como
--   página editable, así que ni su foto ni sus textos se podían tocar.
--
-- CÓMO QUEDA:
--   1) Tabla nueva `imagenes_web`: una fila por HUECO de foto de la web.
--      El HTML marca cada hueco con data-img="clave" y el ayudante
--      assets/js/imagenes-web.js sustituye la foto si aquí hay una.
--   2) Fila nueva 'home' en `contenido_secciones`: los TEXTOS de la
--      portada (etiqueta, titular, frase, botones y cifras) pasan a ser
--      editables desde «Páginas» igual que los de cualquier sección.
--
-- RESPALDO (lo importante): si una fila no tiene `url`, o la consulta
--   falla, o no hay internet, la web se queda con la foto que ya trae
--   el HTML. Nunca se ve un hueco vacío. Por eso todas las filas nacen
--   con url = null y con `respaldo` apuntando a la foto de siempre.
--
-- QUIÉN ENTRA:
--   · Lectura → TODOS, incluido el visitante sin cuenta (`anon`): la web
--     pública necesita leer esta tabla para pintar sus fotos.
--   · Escritura → solo administración, es_admin(); el mismo candado que
--     ya tiene contenido_secciones, porque se editan en la misma pantalla.
--
-- Idempotente: se puede relanzar sin duplicar ni pisar lo ya elegido.
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/049_imagenes_web.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LA TABLA
-- ------------------------------------------------------------
create table if not exists public.imagenes_web (
  -- Identifica el hueco dentro de la web, p. ej. 'home.hero' o
  -- 'club.junta.mario'. Es lo que se escribe en el HTML: data-img="clave".
  clave      text primary key,
  -- Página a la que pertenece, en legible ('Portada', 'El club'…).
  -- Solo sirve para agrupar la lista del panel.
  pagina     text not null,
  -- Nombre del hueco tal y como lo lee una persona en el panel,
  -- p. ej. «Foto grande de la portada».
  titulo     text not null,
  -- Foto elegida desde el panel (URL pública del bucket «imagenes»).
  -- NULL = no se ha tocado, la web usa la foto del HTML (respaldo).
  url        text,
  -- Qué parte de la foto se ve, en el mismo formato que
  -- contenido_secciones.imagen_encuadre: '50% 30%'.
  encuadre   text,
  -- Cuánto se acerca la foto (1 = sin acercar). Igual que imagen_zoom.
  zoom       numeric,
  -- Texto alternativo para quien no ve la imagen. NULL = se deja el del HTML.
  alt        text,
  -- Foto que trae el HTML de serie, relativa a la raíz de la web
  -- ('assets/img/hero.jpg'). No la usa la web (ya está en el HTML): sirve
  -- para que el panel enseñe una miniatura de lo que hay ahora mismo.
  respaldo   text,
  -- Orden dentro de su página, para que la lista del panel salga como la web.
  orden      integer not null default 0,
  updated_at timestamptz not null default now()
);

comment on table public.imagenes_web is
  'Un hueco de foto de la web por fila. El HTML lo marca con data-img="clave"; si aquí hay url, se sustituye, y si no se queda la foto del HTML.';

create index if not exists imagenes_web_pagina_idx on public.imagenes_web (pagina, orden);

-- Columnas por si la tabla ya existía de una pasada anterior.
alter table public.imagenes_web add column if not exists respaldo text;
alter table public.imagenes_web add column if not exists alt      text;
alter table public.imagenes_web add column if not exists orden    integer not null default 0;

-- ------------------------------------------------------------
-- 2 · CANDADO (RLS) · mismo patrón que contenido_secciones
-- ------------------------------------------------------------
alter table public.imagenes_web enable row level security;

-- Lectura para todo el mundo (la web pública la necesita sin sesión).
drop policy if exists "lectura publica imagenes_web" on public.imagenes_web;
create policy "lectura publica imagenes_web"
  on public.imagenes_web
  for select
  using (true);

-- Gestión: solo administración.
drop policy if exists "admin gestiona imagenes_web" on public.imagenes_web;
create policy "admin gestiona imagenes_web"
  on public.imagenes_web
  for all
  to authenticated
  using (es_admin())
  with check (es_admin());

grant select on public.imagenes_web to anon, authenticated;
grant insert, update, delete on public.imagenes_web to authenticated;

commit;

-- ============================================================
-- 3 · LOS HUECOS · una fila por foto editable de la web
-- ------------------------------------------------------------
-- «on conflict do update» solo refresca el nombre legible, la página, el
-- orden y el respaldo: NUNCA pisa la foto que el club haya elegido ya.
-- ============================================================
insert into public.imagenes_web (clave, pagina, titulo, respaldo, orden) values

  -- ---------- PORTADA (index.html) ----------
  ('home.hero',              'Portada', 'Foto grande de la portada',                  'assets/img/hero.jpg',                1),
  ('home.publico.escuela',   'Portada', 'Tarjeta «Para mi hijo o hija»',              'assets/img/escuela.jpg',             2),
  ('home.publico.adultos',   'Portada', 'Tarjeta «Para mí»',                          'assets/img/adultos.jpg',             3),
  ('home.mosaico.1',         'Portada', 'Mosaico «Así vivimos el deporte» · foto 1',  'assets/img/galeria-1.jpg',           4),
  ('home.mosaico.2',         'Portada', 'Mosaico «Así vivimos el deporte» · foto 2',  'assets/img/galeria-2.jpg',           5),
  ('home.mosaico.3',         'Portada', 'Mosaico «Así vivimos el deporte» · foto 3',  'assets/img/escuela.jpg',             6),
  ('home.mosaico.4',         'Portada', 'Mosaico «Así vivimos el deporte» · foto 4',  'assets/img/galeria-3.jpg',           7),
  ('home.mosaico.5',         'Portada', 'Mosaico «Así vivimos el deporte» · foto 5',  'assets/img/galeria-4.jpg',           8),
  ('home.instagram.1',       'Portada', 'Tira de Instagram · foto 1',                 'assets/img/ig-1.jpg',                9),
  ('home.instagram.2',       'Portada', 'Tira de Instagram · foto 2',                 'assets/img/ig-2.jpg',               10),
  ('home.instagram.3',       'Portada', 'Tira de Instagram · foto 3',                 'assets/img/running-claudia.jpg',    11),
  ('home.instagram.4',       'Portada', 'Tira de Instagram · foto 4',                 'assets/img/competicion-andres.jpg', 12),
  ('home.instagram.5',       'Portada', 'Tira de Instagram · foto 5',                 'assets/img/ig-3.jpg',               13),
  ('home.instagram.6',       'Portada', 'Tira de Instagram · foto 6',                 'assets/img/ig-4.jpg',               14),

  -- ---------- EL CLUB (club/index.html) ----------
  ('club.foto',              'El club', 'Foto grande de «El club»',                   'assets/img/adultos.jpg',             1),
  ('club.junta.adrian',      'El club', 'Junta · Adrián Onandía (presidente)',        'assets/img/junta-adrian.jpg',        2),
  ('club.junta.mario',       'El club', 'Junta · Mario Clavero (secretario)',         'assets/img/junta-mario.jpg',         3),
  ('club.junta.andres',      'El club', 'Junta · Andrés Clavero (tesorero)',          'assets/img/junta-andres.jpg',        4),
  ('club.junta.irene',       'El club', 'Junta · Irene Ferriz (vocal)',               'assets/img/junta-irene.jpg',         5),
  ('club.junta.maribel',     'El club', 'Junta · Maribel García (vocal)',             'assets/img/junta-maribel.jpg',       6),
  ('club.junta.mateo',       'El club', 'Junta · Mateo Brian (vocal)',                'assets/img/junta-mateo.jpg',         7),
  ('club.junta.almudena',    'El club', 'Junta · Almudena Coral (vocal)',             'assets/img/junta-almudena.jpg',      8),

  -- ---------- HISTORIA (club/historia/) ----------
  ('club.historia.1',        'Historia del club', 'Archivo fotográfico · foto 1',     'assets/img/galeria-1.jpg',           1),
  ('club.historia.2',        'Historia del club', 'Archivo fotográfico · foto 2',     'assets/img/galeria-2.jpg',           2),
  ('club.historia.3',        'Historia del club', 'Archivo fotográfico · foto 3',     'assets/img/galeria-3.jpg',           3),
  ('club.historia.4',        'Historia del club', 'Archivo fotográfico · foto 4',     'assets/img/galeria-4.jpg',           4),
  ('club.historia.5',        'Historia del club', 'Archivo fotográfico · foto 5',     'assets/img/escuela.jpg',             5),
  ('club.historia.6',        'Historia del club', 'Archivo fotográfico · foto 6',     'assets/img/escuela-galeria-2.jpg',   6),
  ('club.historia.7',        'Historia del club', 'Archivo fotográfico · foto 7',     'assets/img/ig-1.jpg',                7),
  ('club.historia.8',        'Historia del club', 'Archivo fotográfico · foto 8',     'assets/img/ig-2.jpg',                8),
  ('club.historia.9',        'Historia del club', 'Archivo fotográfico · foto 9',     'assets/img/ig-3.jpg',                9),
  ('club.historia.10',       'Historia del club', 'Archivo fotográfico · foto 10',    'assets/img/ig-4.jpg',               10),
  ('club.historia.11',       'Historia del club', 'Archivo fotográfico · foto 11',    'assets/img/running-claudia.jpg',    11),
  ('club.historia.12',       'Historia del club', 'Archivo fotográfico · foto 12',    'assets/img/campus-itaka.jpg',       12),

  -- ---------- INSTALACIONES ----------
  ('instalaciones.estadio',      'Instalaciones', 'Estadio Joaquín Villar',           'assets/img/instalaciones-estadio.jpg',      1),
  ('instalaciones.cubo',         'Instalaciones', 'El Cubo',                          'assets/img/instalaciones-cubo.jpg',         2),
  ('instalaciones.monte-tossal', 'Instalaciones', 'Piscina Monte Tossal',             'assets/img/instalaciones-monte-tossal.jpg', 3),

  -- ---------- GALERÍA ----------
  ('galeria.1',  'Galería', 'Galería · foto 1',  'assets/img/galeria-3.jpg',              1),
  ('galeria.2',  'Galería', 'Galería · foto 2',  'assets/img/galeria-1.jpg',              2),
  ('galeria.3',  'Galería', 'Galería · foto 3',  'assets/img/competicion-andres.jpg',     3),
  ('galeria.4',  'Galería', 'Galería · foto 4',  'assets/img/galeria-2.jpg',              4),
  ('galeria.5',  'Galería', 'Galería · foto 5',  'assets/img/running-claudia.jpg',        5),
  ('galeria.6',  'Galería', 'Galería · foto 6',  'assets/img/running-nicolas.jpg',        6),
  ('galeria.7',  'Galería', 'Galería · foto 7',  'assets/img/galeria-4.jpg',              7),
  ('galeria.8',  'Galería', 'Galería · foto 8',  'assets/img/natacion-hero.jpg',          8),
  ('galeria.9',  'Galería', 'Galería · foto 9',  'assets/img/triatlon-hero.jpg',          9),
  ('galeria.10', 'Galería', 'Galería · foto 10', 'assets/img/instalaciones-estadio.jpg', 10),
  ('galeria.11', 'Galería', 'Galería · foto 11', 'assets/img/cubo-hero.jpg',             11),
  ('galeria.12', 'Galería', 'Galería · foto 12', 'assets/img/escuela-galeria-1.jpg',     12),
  ('galeria.13', 'Galería', 'Galería · foto 13', 'assets/img/escuela-galeria-2.jpg',     13),
  ('galeria.14', 'Galería', 'Galería · foto 14', 'assets/img/ig-2.jpg',                  14),
  ('galeria.15', 'Galería', 'Galería · foto 15', 'assets/img/campus-itaka.jpg',          15),
  ('galeria.16', 'Galería', 'Galería · foto 16', 'assets/img/ig-3.jpg',                  16),

  -- ---------- ESCUELAS (la página que las reúne) ----------
  ('escuelas.atletismo', 'Escuelas', 'Tarjeta «Escuela de atletismo»',           'assets/img/escuela-hero.jpg',           1),
  ('escuelas.natacion',  'Escuelas', 'Tarjeta «Escuela de natación»',            'assets/img/escuela-natacion-hero.jpg',  2),
  ('escuelas.municipal', 'Escuelas', 'Tarjeta «Escuela municipal de atletismo»', 'assets/img/escuela-municipal-hero.jpg', 3),
  ('escuelas.campus',    'Escuelas', 'Tarjeta «Campus de verano»',               'assets/img/campus-hero.jpg',            4),

  -- ---------- ESCUELA DE ATLETISMO ----------
  ('escuela.galeria.1', 'Escuela de atletismo', 'Galería de la escuela · foto 1', 'assets/img/escuela-galeria-1.jpg', 1),
  ('escuela.galeria.2', 'Escuela de atletismo', 'Galería de la escuela · foto 2', 'assets/img/escuela-galeria-2.jpg', 2),

  -- ---------- RUNNING ----------
  ('running.entrenador.madre-tierra', 'Running', 'Retrato de la entrenadora de Madre Tierra', 'assets/img/running-claudia.jpg', 1),
  ('running.entrenador.la-tribu',     'Running', 'Retrato del entrenador de La Tribu',        'assets/img/running-nicolas.jpg', 2),

  -- ---------- ATLETISMO EN PISTA ----------
  ('competicion.foto', 'Atletismo en pista', 'Foto del bloque de competición', 'assets/img/competicion-andres.jpg', 1),

  -- ---------- CAMPUS DE VERANO ----------
  ('campus.cartel', 'Campus de verano', 'Cartel del campus (también es el archivo que se descarga)', 'assets/img/campus-cartel.jpg', 1),
  ('campus.gestor', 'Campus de verano', 'Logo de quien gestiona el campus',                          'assets/img/campus-itaka.jpg',  2),

  -- ---------- FAMILIAS ----------
  ('familias.foto', 'Familias', 'Foto grande de «Familias»', 'assets/img/familias-hero.jpg', 1),

  -- ---------- HAZTE SOCIO ----------
  ('socio.foto', 'Hazte socio', 'Foto ancha de «Hazte socio»', 'assets/img/socio-hero.jpg', 1)

on conflict (clave) do update set
  pagina   = excluded.pagina,
  titulo   = excluded.titulo,
  respaldo = excluded.respaldo,
  orden    = excluded.orden;

-- ============================================================
-- 4 · LA PORTADA, EDITABLE COMO UNA SECCIÓN MÁS
-- ------------------------------------------------------------
-- La portada no estaba en contenido_secciones, por eso no se podían
-- cambiar sus textos. Se añade con el código 'home'. Las columnas
-- genéricas se aprovechan así (el panel las enseña con estos nombres):
--   dirigido_a        → etiqueta pequeña de arriba
--   titulo            → titular grande
--   descripcion       → frase de debajo del titular
--   horarios          → texto del botón principal
--   grupos            → texto del enlace de al lado
--   puntos_destacados → las tres cifras, una por línea: «420 · Atletas»
-- La FOTO de la portada no va aquí: es el hueco 'home.hero' de
-- imagenes_web, para que todas las fotos se cambien en el mismo sitio.
-- ============================================================
insert into public.contenido_secciones
  (seccion, titulo, dirigido_a, descripcion, grupos, horarios, puntos_destacados)
values
  ('home',
   'Aquí siempre hay alguien entrenando',
   'Club de atletismo · Alicante · desde 1988',
   'Atletismo, running, triatlón, natación y montaña. De los 3 años a la alta competición.',
   'Conocer el club',
   'Prueba 4 días gratis',
   E'420 · Atletas\n175 · Socios\n38 · Años')
on conflict (seccion) do nothing;

-- --- Comprobación rápida ---------------------------------------------
select pagina, count(*) as huecos, count(url) as con_foto_propia
  from public.imagenes_web
 group by pagina
 order by min(clave);

select 'portada en contenido_secciones' as que, count(*) as filas
  from public.contenido_secciones where seccion = 'home';
