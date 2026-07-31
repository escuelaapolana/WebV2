-- ============================================================
-- 016 · DOCUMENTOS DEL CLUB (descargables)
-- ------------------------------------------------------------
-- Estatutos, normativa interna, reglamento, protocolos,
-- autorizaciones, circulares... El archivo vive en el bucket
-- público "imagenes", carpeta "documentos/". Aquí guardamos la
-- ficha (título, descripción, categoría, enlace y tamaño).
--
-- Visibilidad:
--   'publico' -> lo ve cualquiera, también sin iniciar sesión.
--   'socios'  -> solo lo ven usuarios que han iniciado sesión.
-- Escribir (crear/editar/borrar) solo puede el admin.
-- ============================================================

create table if not exists public.documentos (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  descripcion text,
  categoria text,
  archivo_url text not null,
  nombre_archivo text,
  tipo_mime text,
  tamano_bytes bigint,
  visibilidad text not null default 'publico'
    check (visibilidad in ('publico','socios')),
  orden int default 0,
  activo boolean default true,
  created_at timestamptz default now(),
  creado_por uuid
);

create index if not exists documentos_categoria_idx  on public.documentos(categoria);
create index if not exists documentos_orden_idx      on public.documentos(orden);
create index if not exists documentos_visibilidad_idx on public.documentos(visibilidad);

alter table public.documentos enable row level security;

grant select on public.documentos to anon, authenticated;
grant insert, update, delete on public.documentos to authenticated;

-- ---- LECTURA -------------------------------------------------
-- Sin login (anon): solo los documentos públicos.
drop policy if exists "publico lee documentos publicos" on public.documentos;
create policy "publico lee documentos publicos" on public.documentos
for select to anon
using (visibilidad = 'publico');

-- Con login (authenticated): públicos + los de socios.
drop policy if exists "socios leen documentos" on public.documentos;
create policy "socios leen documentos" on public.documentos
for select to authenticated
using (visibilidad in ('publico','socios'));

-- ---- ESCRITURA ----------------------------------------------
-- Crear / editar / borrar: solo el admin del club.
drop policy if exists "admin gestiona documentos" on public.documentos;
create policy "admin gestiona documentos" on public.documentos
for all to authenticated
using (public.es_admin())
with check (public.es_admin());
