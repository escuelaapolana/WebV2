-- ============================================================
-- 061 · Seguridad de los archivos (cubos de Storage)
-- ------------------------------------------------------------
-- Tres reglas antiguas daban permiso "a quien tenga sesión" sin
-- decir en qué cubo, así que valían para todos: cualquier atleta
-- con cuenta podía renombrar, sustituir o borrar las fotos del
-- club, las de las noticias y las de los atletas.
--
-- Y la lectura pública incluía `fotos-atletas`, que es privado:
-- la primera foto de un menor que se subiera ahí habría quedado
-- accesible desde Internet, sin contraseña.
--
-- A partir de aquí:
--   · fotos del club, tienda y noticias  → las gestiona administración
--   · fotos de atletas                   → solo el equipo técnico, y
--                                          no se ven sin cuenta
--   · fotos de perfil y justificantes    → como estaban (cada uno
--                                          solo toca lo suyo)
-- Idempotente: se puede volver a lanzar sin romper nada.
-- ============================================================

-- 1 · La lectura sin cuenta deja de alcanzar las fotos de atletas
drop policy if exists "Lectura publica imagenes" on storage.objects;
create policy "Lectura publica imagenes"
  on storage.objects for select to public
  using (bucket_id in ('imagenes-club', 'productos-tienda',
                       'Imagenes-club', 'Productos-tienda'));

-- 2 · Las fotos de atletas, solo para el equipo del club
drop policy if exists "Fotos de atletas solo equipo" on storage.objects;
create policy "Fotos de atletas solo equipo"
  on storage.objects for select to authenticated
  using (bucket_id in ('fotos-atletas', 'Fotos-atletas') and public.es_staff());

-- 3 · Fuera las tres reglas sin filtro de cubo
drop policy if exists "Autenticado actualiza imagenes" on storage.objects;
drop policy if exists "Autenticado borra imagenes"     on storage.objects;
drop policy if exists "Autenticado sube imagenes"      on storage.objects;

-- 4 · Y las de noticias, que pedían solo "tener sesión"
drop policy if exists "Admin sube fotos noticias"      on storage.objects;
drop policy if exists "Admin borra fotos noticias"     on storage.objects;
drop policy if exists "Admin actualiza fotos noticias" on storage.objects;

-- 5 · Las imágenes de la web las gestiona solo administración
drop policy if exists "Admin gestiona imagenes web" on storage.objects;
create policy "Admin gestiona imagenes web"
  on storage.objects for all to authenticated
  using      (bucket_id in ('imagenes', 'imagenes-club', 'productos-tienda',
                            'noticias', 'Imagenes-club', 'Productos-tienda')
              and public.es_admin())
  with check (bucket_id in ('imagenes', 'imagenes-club', 'productos-tienda',
                            'noticias', 'Imagenes-club', 'Productos-tienda')
              and public.es_admin());

-- 6 · Las fotos de atletas las sube y quita el equipo técnico
drop policy if exists "Equipo gestiona fotos de atletas" on storage.objects;
create policy "Equipo gestiona fotos de atletas"
  on storage.objects for all to authenticated
  using      (bucket_id in ('fotos-atletas', 'Fotos-atletas') and public.es_staff())
  with check (bucket_id in ('fotos-atletas', 'Fotos-atletas') and public.es_staff());
