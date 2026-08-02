-- ============================================================
-- 051 · COLABORADORES · editables desde el panel, con logo
-- ------------------------------------------------------------
-- QUÉ RESUELVE (encargo del dueño, textual):
--   «Los colaboradores quiero poder editarlos y añadir foto de logo.
--    O elegir si nombre y logo, o solo logo.»
--
--   Hasta ahora los cuatro colaboradores estaban escritos a mano
--   dentro de assets/js/datos.js, como una lista de nombres sueltos.
--   Para añadir uno, quitarlo o cambiarle el nombre había que tocar
--   código, y no admitían logo de ninguna manera.
--
-- CÓMO QUEDA:
--   Una fila por colaborador. El club los añade, edita, ordena,
--   activa/desactiva y les sube el logo desde «Colaboradores» del
--   panel. La web (pie de página y bloque de la portada) los lee de
--   aquí y respeta la columna `mostrar`:
--     · 'logo'   → solo el logo (el nombre queda como texto alternativo)
--     · 'nombre' → solo el nombre, como hasta hoy
--     · 'ambos'  → logo y nombre juntos
--
-- LOS LOGOS:
--   Archivos del bucket público «imagenes» (el mismo de la biblioteca
--   de fotos), en su propia carpeta «colaboradores/». Se guardan dos
--   cosas: `logo_url` (la dirección pública, que es lo que pinta la
--   web) y `logo_ruta` (la ruta dentro del bucket, para poder borrar
--   el archivo cuando se quita el logo). El candado del Storage ya
--   existente («admin sube imagenes») cubre esa carpeta sin tocar nada.
--
-- RESPALDO (lo importante): si esta consulta falla, no hay internet o
--   la tabla está vacía, la web sigue pintando los colaboradores de
--   datos.js como hasta ahora. El pie nunca se queda cojo.
--
-- QUIÉN ENTRA:
--   · Lectura → TODOS, incluido el visitante sin cuenta (`anon`): la
--     web pública necesita leer esta tabla para pintar el pie.
--   · Escritura → solo administración, es_admin(); el mismo candado
--     que tienen contenido_secciones e imagenes_web.
--
-- Idempotente: se puede relanzar sin duplicar filas ni pisar lo que el
--   club haya cambiado (la precarga solo entra si la tabla está vacía).
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/051_colaboradores.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LA TABLA
-- ------------------------------------------------------------
create table if not exists public.colaboradores (
  id         uuid primary key default gen_random_uuid(),
  -- Nombre del colaborador. Obligatorio siempre, aunque se enseñe solo
  -- el logo: hace de texto alternativo para quien no ve la imagen.
  nombre     text not null,
  -- Dirección pública del logo dentro del bucket «imagenes».
  -- NULL = todavía no tiene logo (se enseña el nombre).
  logo_url   text,
  -- Ruta del archivo dentro del bucket, p. ej. 'colaboradores/1785-x.png'.
  -- Solo sirve para poder borrar el archivo al quitar o cambiar el logo.
  logo_ruta  text,
  -- Su página web, si la tiene. El nombre o el logo se vuelven enlace.
  enlace     text,
  -- Cómo se enseña en la web: solo el logo, solo el nombre, o los dos.
  mostrar    text not null default 'ambos'
             check (mostrar in ('logo', 'nombre', 'ambos')),
  -- Orden en que salen (de menor a mayor). Se cambia con las flechas del panel.
  orden      integer not null default 0,
  -- Desactivar en vez de borrar: deja de salir en la web pero no se pierde.
  activo     boolean not null default true,
  updated_at timestamptz not null default now()
);

comment on table public.colaboradores is
  'Entidades que colaboran con el club. Salen en el pie de la web y en el bloque de la portada; la columna «mostrar» decide si se ve el logo, el nombre o los dos.';

-- Columnas por si la tabla ya existía de una pasada anterior.
alter table public.colaboradores add column if not exists logo_url   text;
alter table public.colaboradores add column if not exists logo_ruta  text;
alter table public.colaboradores add column if not exists enlace     text;
alter table public.colaboradores add column if not exists mostrar    text not null default 'ambos';
alter table public.colaboradores add column if not exists orden      integer not null default 0;
alter table public.colaboradores add column if not exists activo     boolean not null default true;
alter table public.colaboradores add column if not exists updated_at timestamptz not null default now();

-- El CHECK, aparte, para que relanzar la migración no falle si ya estaba.
alter table public.colaboradores drop constraint if exists colaboradores_mostrar_check;
alter table public.colaboradores add  constraint colaboradores_mostrar_check
  check (mostrar in ('logo', 'nombre', 'ambos'));

-- La web pide siempre «los activos, por orden»: este índice es justo eso.
create index if not exists colaboradores_activo_orden_idx
  on public.colaboradores (activo, orden);

-- ------------------------------------------------------------
-- 2 · CANDADO (RLS) · mismo patrón que contenido_secciones
-- ------------------------------------------------------------
alter table public.colaboradores enable row level security;

-- Lectura para todo el mundo (la web pública la necesita sin sesión).
drop policy if exists "lectura publica colaboradores" on public.colaboradores;
create policy "lectura publica colaboradores"
  on public.colaboradores
  for select
  using (true);

-- Gestión: solo administración.
drop policy if exists "admin gestiona colaboradores" on public.colaboradores;
create policy "admin gestiona colaboradores"
  on public.colaboradores
  for all
  to authenticated
  using (es_admin())
  with check (es_admin());

grant select on public.colaboradores to anon, authenticated;
grant insert, update, delete on public.colaboradores to authenticated;

commit;

-- ============================================================
-- 3 · PRECARGA · los cuatro que ya salían en la web
-- ------------------------------------------------------------
-- Entran SIN logo y con mostrar='nombre', para que la web se vea
-- exactamente igual que hasta hoy hasta que el club suba los logos.
-- Solo se cargan si la tabla está vacía: así, relanzar la migración no
-- resucita a uno que el club haya borrado a propósito.
-- ============================================================
insert into public.colaboradores (nombre, mostrar, orden)
select * from (values
  ('Deportes Alicante',        'nombre', 1),
  ('Comunitat Esport',         'nombre', 2),
  ('Diputación de Alicante',   'nombre', 3),
  ('Vithas',                   'nombre', 4)
) as v(nombre, mostrar, orden)
where not exists (select 1 from public.colaboradores);

-- --- Comprobación rápida ---------------------------------------------
select nombre, mostrar, orden, activo, (logo_url is not null) as tiene_logo
  from public.colaboradores
 order by orden, nombre;
