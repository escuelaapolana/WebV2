-- ============================================================
-- 169 · Formulario de alta de socio: los campos que faltaban
-- ------------------------------------------------------------
-- El formulario oficial (Google) pedía más datos que el nuestro:
-- nacionalidad, lugar de nacimiento (ciudad/provincia/país), peso,
-- estatura y las tallas de ropa. Se añaden a `altas_socio` y a la
-- función `enviar_alta_socio`, sin tocar nada de lo que ya había.
--
-- NO se añade el IBAN aquí a propósito: la domiciliación se firma
-- aparte (firmar_mandato_sepa), después de que el club revise el
-- alta. Pedir el IBAN en el formulario público sería peor.
-- Las FOTOS (DNI, carnet) van en otra pasada: necesitan almacén
-- seguro con permisos.
-- ============================================================

alter table public.altas_socio
  add column if not exists nacionalidad          text,
  add column if not exists ciudad_nacimiento     text,
  add column if not exists provincia_nacimiento  text,
  add column if not exists pais_nacimiento       text,
  add column if not exists peso                  text,
  add column if not exists estatura              text,
  add column if not exists talla_camiseta        text,
  add column if not exists talla_pantalon        text,
  add column if not exists talla_calcetin        text;

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
    peso, estatura, talla_camiseta, talla_pantalon, talla_calcetin
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
    public.texto_de_fuera(p ->> 'talla_calcetin', 12)
  );

  return jsonb_build_object('ok', true, 'referencia', v_ref);
end;
$$;
