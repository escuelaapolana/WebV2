-- ============================================================
-- 170 · Alta de socio: fotos del DNI y foto de carnet
-- ------------------------------------------------------------
-- El presidente dio el visto bueno (protección de datos) para pedir,
-- como en el formulario oficial: foto tipo carnet + DNI/NIE por las
-- dos caras. Son datos MUY sensibles, así que:
--
--  · Bucket PRIVADO «altas-documentos».
--  · Subida ANÓNIMA (quien se da de alta no tiene cuenta), pero
--    SOLO subir: no puede volver a leer lo que sube.
--  · Lectura únicamente para administración (es_admin()), y con un
--    candado RESTRICTIVE, para que ninguna política suelta de otro
--    bucket deje colarse a nadie (mismo problema que se arregló con
--    «fotos-perfil», migración 047).
--  · Límite 10 MB y solo imágenes o PDF.
--
-- En la tabla se guarda la RUTA dentro del bucket, nunca una URL
-- pública: para verla, admin firma un enlace temporal.
-- ============================================================

-- 1 · El bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('altas-documentos', 'altas-documentos', false, 10485760,
        array['image/jpeg','image/png','image/webp','image/heic','image/heif','application/pdf'])
on conflict (id) do update
  set public             = false,
      file_size_limit    = 10485760,
      allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic','image/heif','application/pdf'];

-- 2 · Subir: cualquiera (también sin cuenta), pero solo a este bucket.
--     No hay política de SELECT para público/anónimo: se sube a ciegas.
drop policy if exists "altas-doc: subir el alta" on storage.objects;
create policy "altas-doc: subir el alta" on storage.objects
for insert to public
with check (bucket_id = 'altas-documentos');

-- 3 · Leer / gestionar: solo administración.
drop policy if exists "altas-doc: solo admin lee" on storage.objects;
create policy "altas-doc: solo admin lee" on storage.objects
for select to authenticated
using (bucket_id = 'altas-documentos' and public.es_admin());

drop policy if exists "altas-doc: solo admin gestiona" on storage.objects;
create policy "altas-doc: solo admin gestiona" on storage.objects
for all to authenticated
using      (bucket_id = 'altas-documentos' and public.es_admin())
with check (bucket_id = 'altas-documentos' and public.es_admin());

-- 4 · CANDADO (restrictive): dentro de «altas-documentos», leer/cambiar/
--     borrar exige ser admin SIEMPRE, pase lo que pase con otras
--     políticas sueltas. Fuera de este bucket no cambia nada.
drop policy if exists "altas-doc: candado lectura" on storage.objects;
create policy "altas-doc: candado lectura" on storage.objects
as restrictive for select to public
using (bucket_id <> 'altas-documentos' or public.es_admin());

drop policy if exists "altas-doc: candado cambio" on storage.objects;
create policy "altas-doc: candado cambio" on storage.objects
as restrictive for update to public
using (bucket_id <> 'altas-documentos' or public.es_admin());

drop policy if exists "altas-doc: candado borrado" on storage.objects;
create policy "altas-doc: candado borrado" on storage.objects
as restrictive for delete to public
using (bucket_id <> 'altas-documentos' or public.es_admin());

-- 5 · Las rutas en la ficha del alta
alter table public.altas_socio
  add column if not exists foto_carnet  text,
  add column if not exists dni_anverso  text,
  add column if not exists dni_reverso  text;

-- 6 · La función guarda también las rutas (todo lo anterior + fotos)
create or replace function public.enviar_alta_socio(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_email text := lower(public.texto_de_fuera(p ->> 'email', 160));
  v_dni   text := upper(public.texto_de_fuera(p ->> 'dni', 20));
  v_ref   text;
  v_ya    uuid;
  v_segundos int := coalesce((p ->> 'segundos')::int, 0);
begin
  if public.texto_de_fuera(p ->> 'apellido_de_soltera', 100) is not null
     or v_segundos < 6 then
    return jsonb_build_object('ok', true, 'referencia', public.referencia_corta('SOC'));
  end if;

  if not public.altas_hay_sitio('socio') then
    return jsonb_build_object('ok', false, 'motivo', 'demasiados',
      'mensaje', 'Ahora mismo no podemos recoger más altas. Prueba dentro de un rato o llámanos.');
  end if;

  if v_email is null or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return jsonb_build_object('ok', false, 'motivo', 'correo',
      'mensaje', 'Ese correo no parece bien escrito. Revísalo, por favor.');
  end if;

  if public.texto_de_fuera(p ->> 'nombre', 120) is null or v_dni is null
     or public.texto_de_fuera(p ->> 'telefono', 30) is null then
    return jsonb_build_object('ok', false, 'motivo', 'faltan',
      'mensaje', 'Faltan el nombre, el DNI o el teléfono.');
  end if;

  if coalesce((p ->> 'acepta_normas')::boolean, false) is not true then
    return jsonb_build_object('ok', false, 'motivo', 'normas',
      'mensaje', 'Hay que aceptar las normas del club para hacerse socio.');
  end if;

  select id into v_ya from public.altas_socio
   where lower(email) = v_email and upper(dni) = v_dni
     and created_at > now() - interval '1 hour'
   limit 1;

  if v_ya is not null then
    return jsonb_build_object('ok', true, 'repetida', true,
      'referencia', (select referencia from public.altas_socio where id = v_ya));
  end if;

  v_ref := public.referencia_corta('SOC');

  insert into public.altas_socio (
    referencia, nombre, apellidos, dni, fecha_nacimiento, sexo,
    direccion, cp, localidad, provincia, email, telefono, secciones,
    acepta_normas, texto_normas,
    permiso_imagen, permiso_imagen_ambitos, texto_imagen,
    texto_condiciones, ip, navegador,
    nacionalidad, ciudad_nacimiento, provincia_nacimiento, pais_nacimiento,
    peso, estatura, talla_camiseta, talla_pantalon, talla_calcetin,
    foto_carnet, dni_anverso, dni_reverso
  ) values (
    v_ref,
    public.texto_de_fuera(p ->> 'nombre', 120),
    public.texto_de_fuera(p ->> 'apellidos', 120),
    v_dni,
    nullif(p ->> 'fecha_nacimiento', '')::date,
    public.texto_de_fuera(p ->> 'sexo', 10),
    public.texto_de_fuera(p ->> 'direccion', 200),
    public.texto_de_fuera(p ->> 'cp', 10),
    public.texto_de_fuera(p ->> 'localidad', 80),
    public.texto_de_fuera(p ->> 'provincia', 80),
    v_email,
    public.texto_de_fuera(p ->> 'telefono', 30),
    case when p ? 'secciones'
         then array(select jsonb_array_elements_text(p -> 'secciones'))
         else null end,
    true,
    public.texto_de_fuera(p ->> 'texto_normas', 2000),
    (p ->> 'permiso_imagen')::boolean,
    case when p ? 'permiso_imagen_ambitos'
         then array(select jsonb_array_elements_text(p -> 'permiso_imagen_ambitos'))
         else null end,
    public.texto_de_fuera(p ->> 'texto_imagen', 600),
    public.texto_de_fuera(p ->> 'texto_condiciones', 2000),
    public.ip_peticion(),
    public.navegador_peticion(),
    public.texto_de_fuera(p ->> 'nacionalidad', 60),
    public.texto_de_fuera(p ->> 'ciudad_nacimiento', 80),
    public.texto_de_fuera(p ->> 'provincia_nacimiento', 80),
    public.texto_de_fuera(p ->> 'pais_nacimiento', 80),
    public.texto_de_fuera(p ->> 'peso', 20),
    public.texto_de_fuera(p ->> 'estatura', 20),
    public.texto_de_fuera(p ->> 'talla_camiseta', 12),
    public.texto_de_fuera(p ->> 'talla_pantalon', 12),
    public.texto_de_fuera(p ->> 'talla_calcetin', 12),
    public.texto_de_fuera(p ->> 'foto_carnet', 300),
    public.texto_de_fuera(p ->> 'dni_anverso', 300),
    public.texto_de_fuera(p ->> 'dni_reverso', 300)
  );

  return jsonb_build_object('ok', true, 'referencia', v_ref);
end;
$$;
