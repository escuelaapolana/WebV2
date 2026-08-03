-- =====================================================================
-- 086 · LAS FOTOS DE LAS PROPUESTAS DE INSTAGRAM TIENEN SU PROPIO SITIO
-- ---------------------------------------------------------------------
-- QUÉ PASABA
-- Cuando un socio proponía un post («Proponer un post», portal/redes/),
-- sus fotos se subían al cubo «imagenes», que es el de las fotos de la
-- web del club. Ese cubo estaba abierto a cualquiera con cuenta, y eso
-- significaba que cualquier persona con cuenta podía renombrar o borrar
-- las fotos del club: en una prueba se renombraron 30 archivos.
--
-- Al cerrarlo (solo escribe administración) se arregló aquel agujero,
-- pero se rompió esta pantalla: un atleta que proponía un post recibía
-- un «no hemos podido subir la foto» que además echaba la culpa a su
-- conexión cuando era cosa de permisos.
--
-- QUÉ SE HACE AQUÍ
-- Las propuestas dejan de vivir en el cubo del club y pasan a tener el
-- suyo: «propuestas-redes». Es PRIVADO —en una propuesta pueden salir
-- menores— y funciona igual que «fotos-perfil» (047) y
-- «liga-justificantes» (046), que ya estaban bien resueltos:
--
--     propuestas-redes/<id de usuario>/<archivo>
--
-- Esa primera carpeta es la que manda:
--   · SUBIR y CAMBIAR: solo dentro de MI carpeta. Nadie toca lo de otro.
--   · VER: quien lo subió y el equipo del club (es_staff), que tiene que
--     poder mirar la propuesta para decidir si se publica.
--   · BORRAR: quien lo subió y administración (es_admin), igual que el
--     resto del club desde la 064 («borrar es cosa de admin»).
--
-- Y sigue sin publicarse nada solo: la propuesta se guarda en
-- `peticiones_redes` en estado «pendiente» y el post lo sube el club a
-- mano desde la cuenta de Instagram.
--
-- Idempotente: se puede lanzar las veces que haga falta.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1 · EL CUBO
-- ---------------------------------------------------------------------
-- Privado. 15 MB por archivo: la pantalla ya avisa a partir de 10 MB,
-- y el límite es la red de seguridad por si alguien salta la web.
-- Solo imágenes; los móviles de Apple mandan HEIC.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('propuestas-redes', 'propuestas-redes', false, 15728640,
        array['image/jpeg','image/png','image/webp','image/heic','image/heif'])
on conflict (id) do update
  set public             = false,
      file_size_limit    = 15728640,
      allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic','image/heif'];


-- ---------------------------------------------------------------------
-- 2 · QUIÉN PUEDE QUÉ (políticas normales)
-- ---------------------------------------------------------------------

-- Subir: solo dentro de MI carpeta.
drop policy if exists "propuesta redes la sube su autor" on storage.objects;
create policy "propuesta redes la sube su autor" on storage.objects
for insert to authenticated
with check (bucket_id = 'propuestas-redes'
            and (storage.foldername(name))[1] = auth.uid()::text);

-- Reemplazar: solo lo mío, y sin poder sacarlo de mi carpeta.
-- El club NO entra aquí a propósito: renombrar archivos ajenos fue
-- justamente el agujero que se cerró en el cubo «imagenes».
drop policy if exists "propuesta redes la cambia su autor" on storage.objects;
create policy "propuesta redes la cambia su autor" on storage.objects
for update to authenticated
using (bucket_id = 'propuestas-redes'
       and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'propuestas-redes'
            and (storage.foldername(name))[1] = auth.uid()::text);

-- Ver: quien la subió y el equipo del club, que tiene que revisarla.
-- Un socio NO ve las propuestas de otro socio.
drop policy if exists "propuesta redes la ven su autor y el club" on storage.objects;
create policy "propuesta redes la ven su autor y el club" on storage.objects
for select to authenticated
using (bucket_id = 'propuestas-redes'
       and (public.es_staff()
            or (storage.foldername(name))[1] = auth.uid()::text));

-- Borrar: quien la subió (por si se equivoca de foto) y administración.
drop policy if exists "propuesta redes la borran su autor y admin" on storage.objects;
create policy "propuesta redes la borran su autor y admin" on storage.objects
for delete to authenticated
using (bucket_id = 'propuestas-redes'
       and (public.es_admin()
            or (storage.foldername(name))[1] = auth.uid()::text));


-- ---------------------------------------------------------------------
-- 3 · EL CANDADO DE VERDAD (políticas «restrictive»)
-- ---------------------------------------------------------------------
-- OJO, esto es lo importante y ya nos ha mordido seis veces: en el
-- Storage conviven políticas escritas para otros cubos que se quedaron
-- SIN filtrar por cubo. Las políticas normales se SUMAN (basta que una
-- diga que sí), así que una política suelta puede abrir este cubo sin
-- que nadie lo note.
--
-- Estas otras son «restrictive»: se cumplen SIEMPRE, se multiplican en
-- vez de sumarse. Fuera de «propuestas-redes» la condición es cierta,
-- así que no cambian absolutamente nada en el resto del club; dentro,
-- mandan ellas por encima de cualquier política presente o futura.
--
-- Van a `public` (no a `authenticated`) para que alcancen también a
-- quien entra sin cuenta.

drop policy if exists "propuestas-redes: solo el autor sube" on storage.objects;
create policy "propuestas-redes: solo el autor sube" on storage.objects
as restrictive for insert to public
with check (bucket_id <> 'propuestas-redes'
            or (auth.uid() is not null
                and (storage.foldername(name))[1] = auth.uid()::text));

drop policy if exists "propuestas-redes: solo el autor cambia" on storage.objects;
create policy "propuestas-redes: solo el autor cambia" on storage.objects
as restrictive for update to public
using (bucket_id <> 'propuestas-redes'
       or (auth.uid() is not null
           and (storage.foldername(name))[1] = auth.uid()::text))
with check (bucket_id <> 'propuestas-redes'
            or (auth.uid() is not null
                and (storage.foldername(name))[1] = auth.uid()::text));

drop policy if exists "propuestas-redes: borra el autor o admin" on storage.objects;
create policy "propuestas-redes: borra el autor o admin" on storage.objects
as restrictive for delete to public
using (bucket_id <> 'propuestas-redes'
       or (auth.uid() is not null
           and (public.es_admin()
                or (storage.foldername(name))[1] = auth.uid()::text)));

drop policy if exists "propuestas-redes: la ven el autor y el club" on storage.objects;
create policy "propuestas-redes: la ven el autor y el club" on storage.objects
as restrictive for select to public
using (bucket_id <> 'propuestas-redes'
       or (auth.uid() is not null
           and (public.es_staff()
                or (storage.foldername(name))[1] = auth.uid()::text)));

commit;


-- =====================================================================
-- 4 · LOS PERMISOS DE VERDAD, NO SOLO LAS POLÍTICAS
-- ---------------------------------------------------------------------
-- Las políticas solo valen si las reglas de acceso (RLS) están
-- encendidas en storage.objects. Si alguna vez se apagaran, los
-- permisos que Supabase reparte de serie (anon y authenticated tienen
-- todo sobre storage.objects) dejarían el cubo abierto de par en par.
-- Así que aquí se comprueba y se para la migración si no lo están.
--
-- Nota apuntada para la próxima revisión de seguridad: esos permisos
-- de tabla sobre `storage.objects` los concedió `supabase_storage_admin`
-- y `postgres` no puede retirarlos (el REVOKE se acepta pero no hace
-- nada). Incluyen TRUNCATE para `anon`, que se salta el RLS igual que
-- pasaba en `public` antes de la 074. No es cosa de este cubo —afecta a
-- todo el Storage— y hay que hacerlo desde el panel de Supabase con el
-- usuario del Storage.
-- =====================================================================

do $$
begin
  if not (select relrowsecurity from pg_class where oid = 'storage.objects'::regclass) then
    raise exception 'storage.objects tiene las reglas de acceso (RLS) APAGADAS: el cubo quedaria abierto';
  end if;
end $$;


-- =====================================================================
-- 5 · COMPROBACIONES HECHAS (simulando papeles, todo con ROLLBACK)
-- ---------------------------------------------------------------------
-- Con un atleta, otro atleta, un entrenador, administración, el dueño
-- del club actuando como atleta y alguien sin cuenta:
--
--   · el atleta sube en SU carpeta ....................... 1 fila
--   · el atleta sube en la carpeta de otro ............... cortado por RLS
--   · el atleta solo ve lo suyo ......................... 1 de 2 archivos
--   · el atleta renombra lo de otro ..................... 0 filas
--   · el atleta borra lo suyo sí, lo de otro no
--   · el entrenador ve las dos propuestas (para revisarlas)
--   · el entrenador NO renombra ni borra lo de un socio
--   · administración ve todo y puede limpiar
--   · el dueño con rol_activo='atleta' sube lo suyo y no ve lo ajeno
--   · sin cuenta: no ve, no sube, no borra
--   · y el cubo «imagenes» sigue cerrado a quien no es administración
--
-- Se lanza así:
--
--   begin;
--     set local role authenticated;
--     set local request.jwt.claims to
--       '{"sub":"<id de usuario>","email":"<correo>","role":"authenticated"}';
--     insert into storage.objects (bucket_id, name, owner)
--     values ('propuestas-redes','<id de usuario>/foto.jpg','<id de usuario>');
--     select name from storage.objects where bucket_id='propuestas-redes';
--     update storage.objects set name='<id de usuario>/robada.jpg'
--      where name='<id de otro>/foto.jpg';       -- UPDATE 0
--   rollback;
--
-- ⚠️ El borrado no se puede probar con un DELETE a pelo: Supabase tiene
-- un disparador (protect_objects_delete, BEFORE DELETE FOR EACH
-- STATEMENT) que corta cualquier borrado hecho desde SQL y obliga a
-- pasar por la API del Storage. Se comprueba evaluando la condición
-- exacta de la política con cada papel puesto:
--
--   select auth.uid() is not null
--      and (public.es_admin()
--           or (storage.foldername('<ruta>'))[1] = auth.uid()::text);
-- =====================================================================

-- --- Comprobación rápida al lanzar la migración ----------------------
select 'cubo propuestas-redes' as que, id, public as publico, file_size_limit as limite
  from storage.buckets where id = 'propuestas-redes';

select 'politicas del cubo' as que,
       count(*) filter (where polpermissive)     as normales,
       count(*) filter (where not polpermissive) as candados
  from pg_policy
 where polrelid = 'storage.objects'::regclass
   and polname like '%propuesta%redes%';
