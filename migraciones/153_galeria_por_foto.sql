-- 153 · Galería web dirigida foto a foto
--
-- Cambia el modelo de la galería: en vez de «huecos» fijos, cada foto de
-- la biblioteca puede marcarse para salir en la galería pública, y la
-- página /galeria enseña todas las marcadas con filtros por sección,
-- acontecimiento y fecha.
--
-- · en_galeria: el interruptor «Mostrar en la galería web» del panel.
-- · galeria_publica: vista de SOLO las fotos marcadas Y ya publicadas (con
--   copia en el bucket público «imagenes»), con las columnas justas que la
--   web necesita. Se concede lectura al rol anónimo: así el visitante ve
--   la galería sin abrir la biblioteca entera (que sigue siendo interna).

alter table public.biblioteca_fotos
  add column if not exists en_galeria boolean not null default false;

create index if not exists biblioteca_fotos_en_galeria_idx
  on public.biblioteca_fotos (en_galeria) where en_galeria;

-- Vista pública: solo lo marcado y publicado, y solo columnas seguras.
-- Corre con privilegios del dueño (definer), así el visitante anónimo la
-- lee sin necesidad de tocar la RLS de biblioteca_fotos.
create or replace view public.galeria_publica as
  select id, titulo, categoria, grupo, fecha_foto, publicada_ruta, created_at
  from public.biblioteca_fotos
  where en_galeria = true
    and publicada_ruta is not null;

grant select on public.galeria_publica to anon, authenticated;
