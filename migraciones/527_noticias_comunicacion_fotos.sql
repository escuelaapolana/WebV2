-- Noticias: quien lleva comunicación puede subir las fotos y guardar
-- ---------------------------------------------------------------------------
-- Mario (9-nov-2026): al publicar la noticia de los controles de la escuela de
-- natación, «No se pudo subir: new row violates row-level security policy».
-- El bucket `imagenes` solo dejaba escribir a admin, y la tabla `noticias` a
-- admin y a junta EN SU VISTA ACTIVA (es_junta mira rol_activo). Autorizado
-- por Andrés el 9-nov-2026.
--
--   · noticias_puede(): admin, junta (aunque tenga otra vista activa) o
--     responsable de la sección 'comunicacion'.
--   · Bucket imagenes: pueden SUBIR solo dentro de la carpeta noticias/.
--     No pueden borrar ni sustituir, ni tocar el resto de imágenes de la web.
--   · Tabla noticias: pueden crear, editar y borrar.
-- ---------------------------------------------------------------------------
begin;

create or replace function public.noticias_puede()
returns boolean
language sql stable security definer
set search_path to 'public'
as $$
  select public.es_admin() or exists (
    select 1 from public.perfiles p
     where p.email = (auth.jwt() ->> 'email')
       and coalesce(p.activo, true)
       and (p.rol = 'junta' or p.rol_activo = 'junta' or 'junta' = any(coalesce(p.roles, '{}'))
            or exists (select 1 from public.responsable_seccion rs
                        where rs.perfil_id = p.id and rs.seccion = 'comunicacion'))
  );
$$;
revoke all on function public.noticias_puede() from public, anon;
grant execute on function public.noticias_puede() to authenticated, service_role;

drop policy if exists "comunicacion sube fotos de noticias" on storage.objects;
create policy "comunicacion sube fotos de noticias" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'imagenes' and (storage.foldername(name))[1] = 'noticias' and (select public.noticias_puede()));

drop policy if exists "comunicacion gestiona noticias" on public.noticias;
create policy "comunicacion gestiona noticias" on public.noticias
  for all to authenticated
  using ((select public.noticias_puede()))
  with check ((select public.noticias_puede()));

commit;
