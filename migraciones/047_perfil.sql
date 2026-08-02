-- ============================================================
-- 047 · MI PERFIL · identidad de cada persona del club
-- ------------------------------------------------------------
-- QUÉ RESUELVE (encargo del dueño):
--   «No veo desde dónde cambiar mi foto de perfil y tal.»
--   Hoy no hay ningún sitio donde una persona gestione lo suyo, y
--   la tabla `perfiles` no tiene ni foto ni apodo. Esta migración
--   pone los tres datos que faltaban y el sitio donde vive la foto.
--
-- QUÉ AÑADE:
--   1) Tres columnas en public.perfiles:
--        foto_ruta      · ruta del archivo dentro del bucket privado
--                         (NO la URL: la URL se firma al mostrarla).
--        nombre_publico · cómo quiere que le llamen. Vacío = su nombre.
--        perfil_visible · si otros socios pueden ver su ficha.
--   2) Un bucket PRIVADO «fotos-perfil»: cada persona manda sobre su
--      carpeta (su id de usuario) y nadie más puede escribir en ella.
--   3) Una función para leer la ficha visible de otra persona sin
--      exponer teléfono ni correo.
--
-- QUÉ **NO** TOCA (a propósito):
--   · El disparador `trg_perfiles_protege_rol` (migración 037), que
--     impide que nadie se cambie el rol, la sección, el correo o el
--     estado de su propio perfil. Es una protección de seguridad y
--     se queda tal cual: las columnas nuevas pasan por él sin
--     problema, porque el disparador solo restaura id, email, rol,
--     seccion y activo.
--   · Las políticas de `perfiles`: ya existe «escritura_propia»
--     (UPDATE con auth.uid() = id), que es justo lo que hace falta.
--     Al no tener WITH CHECK propio, PostgreSQL reutiliza el USING
--     como comprobación, así que tampoco se puede mover una fila a
--     otro dueño. Comprobado con psql antes de escribir esto.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/047_perfil.sql
-- (Es idempotente: se puede relanzar sin romper nada.)
-- ============================================================


-- =====================================================================
-- 1 · LOS TRES DATOS QUE FALTABAN EN `perfiles`
-- =====================================================================

begin;

alter table public.perfiles add column if not exists foto_ruta      text;
alter table public.perfiles add column if not exists nombre_publico text;
alter table public.perfiles add column if not exists perfil_visible boolean not null default true;

comment on column public.perfiles.foto_ruta is
  'Ruta del archivo dentro del bucket privado «fotos-perfil», p. ej. "<id de usuario>/perfil-1785.jpg". No se guarda la URL: es privada y se firma al mostrarla.';
comment on column public.perfiles.nombre_publico is
  'Cómo quiere que le llamen (apodo). Si está vacío se usa el nombre real.';
comment on column public.perfiles.perfil_visible is
  'Si otros socios pueden ver su ficha (nombre o apodo, foto, medallas y retos). Nunca afecta a datos de contacto, pagos ni marcas.';

-- El apodo, con medida razonable, para que no entre un texto entero.
-- Se añade solo si no estaba (para poder relanzar la migración).
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'public.perfiles'::regclass
       and conname  = 'perfiles_nombre_publico_check'
  ) then
    alter table public.perfiles
      add constraint perfiles_nombre_publico_check
      check (nombre_publico is null
             or (char_length(btrim(nombre_publico)) between 2 and 40));
  end if;
end $$;

commit;


-- =====================================================================
-- 2 · DÓNDE VIVEN LAS FOTOS · bucket PRIVADO «fotos-perfil»
-- ---------------------------------------------------------------------
-- Privado a propósito: una foto de un menor no puede quedar colgando
-- de una URL pública que cualquiera pueda adivinar o reenviar. Para
-- verla, la web pide una URL firmada que caduca sola.
--
-- La carpeta de cada persona es su id de usuario:
--     <id de usuario>/perfil-<marca de tiempo>.jpg
-- Esa primera carpeta es la que mandan las políticas, igual que ya se
-- hace en «liga-justificantes» (migración 046).
--
-- Límite de 5 MB y solo imágenes: la web además reduce la foto a
-- 512×512 antes de subirla, así que en la práctica pesan pocos KB;
-- el límite es la red de seguridad por si alguien salta la web.
-- =====================================================================

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos-perfil', 'fotos-perfil', false, 5242880,
        array['image/jpeg','image/png','image/webp','image/heic','image/heif'])
on conflict (id) do update
  set public             = false,
      file_size_limit    = 5242880,
      allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic','image/heif'];

-- Subir: solo dentro de MI carpeta.
drop policy if exists "foto perfil la sube su dueno" on storage.objects;
create policy "foto perfil la sube su dueno" on storage.objects
for insert to authenticated
with check (bucket_id = 'fotos-perfil'
            and (storage.foldername(name))[1] = auth.uid()::text);

-- Reemplazar: solo mi propia foto, y sin poder sacarla de mi carpeta.
drop policy if exists "foto perfil la cambia su dueno" on storage.objects;
create policy "foto perfil la cambia su dueno" on storage.objects
for update to authenticated
using (bucket_id = 'fotos-perfil'
       and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'fotos-perfil'
            and (storage.foldername(name))[1] = auth.uid()::text);

-- Quitar: solo mi propia foto.
drop policy if exists "foto perfil la borra su dueno" on storage.objects;
create policy "foto perfil la borra su dueno" on storage.objects
for delete to authenticated
using (bucket_id = 'fotos-perfil'
       and (storage.foldername(name))[1] = auth.uid()::text);

-- Ver: cualquiera que haya entrado con su cuenta, para que la foto
-- salga en las fichas y listados del portal. Un anónimo, nada.
drop policy if exists "foto perfil la ve quien tiene sesion" on storage.objects;
create policy "foto perfil la ve quien tiene sesion" on storage.objects
for select to authenticated
using (bucket_id = 'fotos-perfil');


-- ---------------------------------------------------------------------
-- CANDADO DE VERDAD (políticas «restrictive»)
-- ---------------------------------------------------------------------
-- OJO, esto es importante y se descubrió probando: en el Storage hay
-- políticas viejas («Autenticado borra imagenes», «Autenticado
-- actualiza imagenes») que se escribieron para los buckets de fotos del
-- club pero se quedaron SIN filtrar por bucket: dicen solo «si has
-- entrado, puedes». Como los permisos normales se suman (basta que UNO
-- diga que sí), esas políticas dejaban a cualquier persona con cuenta
-- borrar o mover archivos de CUALQUIER bucket, incluido el nuestro.
-- Comprobado con psql: un entrenador borraba la foto del administrador.
--
-- Estas políticas «restrictive» son distintas: se cumplen SIEMPRE, se
-- multiplican en vez de sumarse. Fuera del bucket «fotos-perfil» no
-- cambian absolutamente nada (la condición es cierta), así que no tocan
-- ninguna otra pantalla del club; dentro de él mandan ellas.
--
-- (Las políticas viejas siguen sueltas para el resto de buckets: está
--  apuntado para revisarlo aparte, porque afecta a más sitios.)

drop policy if exists "fotos-perfil: solo el dueno sube"    on storage.objects;
create policy "fotos-perfil: solo el dueno sube" on storage.objects
as restrictive for insert to public
with check (bucket_id <> 'fotos-perfil'
            or (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "fotos-perfil: solo el dueno cambia"  on storage.objects;
create policy "fotos-perfil: solo el dueno cambia" on storage.objects
as restrictive for update to public
using (bucket_id <> 'fotos-perfil'
       or (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id <> 'fotos-perfil'
            or (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "fotos-perfil: solo el dueno borra"   on storage.objects;
create policy "fotos-perfil: solo el dueno borra" on storage.objects
as restrictive for delete to public
using (bucket_id <> 'fotos-perfil'
       or (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "fotos-perfil: sin cuenta no se ve"   on storage.objects;
create policy "fotos-perfil: sin cuenta no se ve" on storage.objects
as restrictive for select to public
using (bucket_id <> 'fotos-perfil'
       or auth.uid() is not null);

commit;


-- =====================================================================
-- 3 · VER LA FICHA DE OTRO SOCIO SIN VER SUS DATOS DE CONTACTO
-- ---------------------------------------------------------------------
-- `perfiles` sigue cerrada: cada persona solo lee SU fila (y el equipo
-- técnico, la del resto del equipo técnico). Eso está bien y no se
-- toca. Pero el interruptor «que otros socios puedan ver mi perfil»
-- tiene que servir para algo, así que aquí hay una puerta estrecha:
-- devuelve SOLO el nombre a mostrar y la foto de quien lo ha
-- permitido. Ni correo, ni teléfono, ni rol, ni sección.
-- =====================================================================

create or replace function public.perfiles_visibles()
returns table (
  id             uuid,
  nombre_mostrar text,
  foto_ruta      text
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id,
         coalesce(nullif(btrim(p.nombre_publico), ''), p.nombre) as nombre_mostrar,
         p.foto_ruta
    from public.perfiles p
   where p.perfil_visible
     and coalesce(p.activo, true)
     and auth.uid() is not null;
$$;

comment on function public.perfiles_visibles() is
  'Ficha mínima (nombre a mostrar y foto) de quienes han dejado su perfil visible. No expone correo, teléfono, rol ni sección.';

revoke all on function public.perfiles_visibles() from public;
revoke all on function public.perfiles_visibles() from anon;
grant execute on function public.perfiles_visibles() to authenticated;


-- =====================================================================
-- 4 · COMPROBACIONES (se lanzan a mano, siempre con ROLLBACK)
-- ---------------------------------------------------------------------
-- Con un atleta de prueba, ha de poder cambiar apodo, foto, teléfono y
-- visibilidad, y NO ha de poder cambiarse el rol ni tocar la fila de
-- otra persona:
--
-- begin;
--   set local role authenticated;
--   set local request.jwt.claims to
--     '{"sub":"<id del atleta>","email":"atleta2@apolana.test","role":"authenticated"}';
--   update public.perfiles
--      set nombre_publico='Chuchi', foto_ruta='<id>/perfil-1.jpg',
--          telefono='600111222', perfil_visible=false
--    where id='<id del atleta>';            -- 1 fila
--   update public.perfiles set rol='admin' where id='<id del atleta>';
--   select rol from public.perfiles where id='<id del atleta>';  -- sigue 'atleta'
--   update public.perfiles set nombre_publico='x' where id='<id de otra persona>';
--                                            -- UPDATE 0
-- rollback;
-- =====================================================================

-- --- Comprobación rápida al lanzar la migración ----------------------
select 'columnas nuevas en perfiles' as que,
       count(*) as total
  from information_schema.columns
 where table_schema = 'public' and table_name = 'perfiles'
   and column_name in ('foto_ruta', 'nombre_publico', 'perfil_visible');

select 'bucket fotos-perfil' as que, id, public as publico, file_size_limit
  from storage.buckets where id = 'fotos-perfil';

select 'politicas del bucket' as que, count(*) as total
  from pg_policy
 where polrelid = 'storage.objects'::regclass
   and polname like 'foto perfil%';
