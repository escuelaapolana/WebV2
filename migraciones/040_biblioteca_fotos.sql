-- ============================================================
-- 040 · BIBLIOTECA DE FOTOS · metadatos de las imágenes del club
-- ------------------------------------------------------------
-- QUÉ RESUELVE (encargo del dueño):
--   Hasta ahora la biblioteca subía las fotos al bucket público
--   «imagenes», carpeta «biblioteca/», y las listaba sin más. El
--   Storage solo guarda el NOMBRE del archivo: no hay forma de
--   decir «esta es de la escuela», «esta de montaña», ni de marcar
--   favoritas, ni de buscar sin repasar la biblioteca entera.
--
--   Esta tabla guarda esos DATOS de cada foto (categoría, título,
--   favorita, quién la subió y cuándo) apuntando a su ruta en el
--   Storage. El archivo en sí sigue viviendo en el bucket; aquí solo
--   están sus etiquetas para poder filtrar y buscar.
--
-- CÓMO SE RELACIONA CON EL STORAGE:
--   La columna «ruta» es la ruta completa dentro del bucket, tal cual
--   la usa el panel, p. ej. 'biblioteca/1785-foto.jpg'. Es única: una
--   fila por archivo. La URL pública se compone en el navegador con
--   sb.storage.from('imagenes').getPublicUrl(ruta).
--
-- QUIÉN ENTRA:
--   · Gestión (crear, editar, borrar) → solo administración, es_admin().
--   · Lectura → cualquiera con sesión (authenticated): el panel la usa
--     con la sesión del administrador o coordinador para elegir fotos.
--   El bucket «imagenes» ya es público, así que las fotos en sí se ven
--   sin sesión; lo que se protege aquí son sus etiquetas.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/040_biblioteca_fotos.sql
-- ============================================================

begin;

create table if not exists public.biblioteca_fotos (
  id         uuid primary key default gen_random_uuid(),
  -- Ruta completa dentro del bucket «imagenes», p. ej. 'biblioteca/1785-foto.jpg'.
  -- Única: cada archivo tiene una sola ficha.
  ruta       text not null unique,
  -- Nombre del archivo (para mostrarlo y buscarlo).
  nombre     text,
  -- Título legible que le pone la persona, para encontrarla mejor.
  titulo     text,
  -- Sección del club a la que pertenece la foto ('montana', 'escuela'…).
  -- Vacío = «Sin categoría».
  categoria  text,
  -- Marcada como favorita para volver a encontrarla rápido.
  favorita   boolean not null default false,
  -- Qué perfil la subió (id de public.perfiles vía mi_perfil_id()).
  subida_por uuid,
  -- Cuándo se metió en la biblioteca. Sirve para ordenar por fecha.
  created_at timestamptz not null default now()
);

comment on table public.biblioteca_fotos is
  'Etiquetas de las fotos del bucket «imagenes/biblioteca»: categoría, título, favorita. No guarda el archivo, solo apunta a su ruta.';

-- Índices para los filtros del panel (por categoría, por favoritas y por fecha).
create index if not exists biblioteca_fotos_categoria_idx on public.biblioteca_fotos (categoria);
create index if not exists biblioteca_fotos_favorita_idx  on public.biblioteca_fotos (favorita);
create index if not exists biblioteca_fotos_creada_idx    on public.biblioteca_fotos (created_at desc);

-- ------------------------------------------------------------
-- Candado (RLS)
-- ------------------------------------------------------------
alter table public.biblioteca_fotos enable row level security;

-- Gestión completa: solo administración.
drop policy if exists "admin gestiona biblioteca_fotos" on public.biblioteca_fotos;
create policy "admin gestiona biblioteca_fotos"
  on public.biblioteca_fotos
  for all
  to authenticated
  using (es_admin())
  with check (es_admin());

-- Lectura: cualquiera con sesión (para poder elegir fotos desde el panel).
drop policy if exists "con sesion lee biblioteca_fotos" on public.biblioteca_fotos;
create policy "con sesion lee biblioteca_fotos"
  on public.biblioteca_fotos
  for select
  to authenticated
  using (true);

commit;

-- ------------------------------------------------------------
-- BACKFILL · no perder las fotos que YA están subidas
-- ------------------------------------------------------------
-- Crea una ficha por cada archivo que ya existe en el Storage bajo
-- 'biblioteca/'. Quedan con categoría vacía = «Sin categoría» y con la
-- fecha real en que se subieron, para que el orden por fecha sea fiel.
-- «on conflict do nothing» para poder relanzar la migración sin duplicar.
insert into public.biblioteca_fotos (ruta, nombre, created_at)
select o.name,
       o.name,
       coalesce(o.created_at, now())
  from storage.objects o
 where o.bucket_id = 'imagenes'
   and o.name like 'biblioteca/%'
   and o.name <> 'biblioteca/.emptyFolderPlaceholder'
on conflict (ruta) do nothing;

-- --- Comprobación rápida ---------------------------------------------
select 'fichas en biblioteca_fotos' as que, count(*) as total from public.biblioteca_fotos;
