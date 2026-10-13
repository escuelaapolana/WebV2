-- ============================================================
-- 350 · Natación: que Mario (gestor de natación, SIN ser admin)
--       pueda hacer TODO el ciclo de un nadador él solo.
-- ------------------------------------------------------------
-- Lo que fallaba (probado como Mario, en ROLLBACK, 13-oct-2026):
--   · Alta de alguien que YA tiene ficha (caso Ian Javier Guevara):
--     Mario no puede LEER `atletas` (ninguna regla de acceso le deja),
--     así que no la encuentra; «Nuevo nadador» sin DNI creaba una
--     ficha DUPLICADA, y el «Añadir» de cada franja metía filas
--     sueltas (sin ficha ni código) → «no se agrupa».
--   · Baja: solo apagaba inscripciones; el código de acceso seguía
--     vivo y la ficha seguía «activo» (caso Mounir).
--   · Datos de contacto de la familia: no los podía ver ni cambiar.
--   · La DIRECCIÓN de la ficha (natacion_set_direccion) y rellenar el
--     correo del tutor al reutilizar una ficha REVENTABAN con «Esto de la
--     ficha no lo lleva el entrenador: direccion…»: el guardián
--     atletas_cambios_del_entrenador() solo deja pasar a admin/dinero/
--     escuela. Ahora deja pasar también lo que hacen ESTAS funciones de
--     natación (marca local de la transacción, que el navegador no puede
--     poner: solo la ponen funciones SECURITY DEFINER de aquí).
--
-- Criterio: MÍNIMO PRIVILEGIO. No se abre `atletas` a Mario: todo va
-- por funciones SECURITY DEFINER que comprueban soy_gestor_natacion()
-- y, cuando tocan una ficha, que esa ficha sea de NATACIÓN
-- (natacion_es_nadador). Nada de dinero (mandatos/cuotas) ni de otras
-- secciones.
--
-- Funciones nuevas:
--   natacion_es_nadador(atleta)               → ¿ficha de natación?
--   natacion_buscar_fichas(texto)             → buscador de fichas del club
--                                               (datos mínimos, correo enmascarado)
--   natacion_alta_desde_ficha(...)            → código + franjas sobre la ficha
--                                               existente (+ adopta filas sueltas)
--   natacion_dar_baja(acceso, atleta)         → baja completa de natación
--   natacion_contacto_de(atleta)              → leer contacto (solo nadadores)
--   natacion_guardar_contacto(...)            → corregir contacto (solo nadadores)
-- Cambios:
--   natacion_crear_nadador   → sin DNI, reutiliza ficha por nombre + nacimiento
--   natacion_enlazar_ficha   → mismo permiso que el resto (gestor de natación)
--   natacion_set/get_direccion → solo fichas de natación (antes: cualquiera)
--   atletas_cambios_del_entrenador → deja pasar las funciones de natación
-- ============================================================

-- ---------- guardián de la ficha: deja pasar las funciones de natación ----------
-- Igual que antes + UNA condición: `apolana.via_natacion` = '1'. Esa marca
-- solo la ponen (set_config local a la transacción) las funciones de abajo,
-- que ya comprueban que quien llama gestiona natación y que la ficha es de
-- un nadador, y que solo tocan columnas concretas (contacto, dirección,
-- estado de baja/alta). El navegador no puede ponerla: set_config no está
-- expuesto por la API y cada petición es su propia transacción.
create or replace function public.atletas_cambios_del_entrenador()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  permitidas text[] := array[
    'grupo_id', 'dias_entreno', 'hace_gym', 'tiene_fisio', 'dia_fisio',
    'especialidades', 'pruebas_principales', 'pruebas_secundarias',
    'perfil_velocista', 'pierna_ataque', 'pasos_entre_vallas',
    'estado', 'fecha_prueba_fin',
    'observaciones', 'contexto_entrenador',
    'updated_at'
  ];
  viejo jsonb := to_jsonb(old);
  nuevo jsonb := to_jsonb(new);
  c text;
  cambiadas text[];
begin
  new.updated_at := now();

  if (auth.jwt() ->> 'email') is null
     or public.es_admin()
     or public.ve_dinero()
     or public.es_escuela()
     or coalesce(current_setting('apolana.via_natacion', true), '') = '1' then
    return new;
  end if;

  foreach c in array permitidas loop
    viejo := viejo - c;
    nuevo := nuevo - c;
  end loop;

  select array_agg(k order by k) into cambiadas
    from jsonb_object_keys(nuevo) k
   where (nuevo -> k) is distinct from (viejo -> k);

  if cambiadas is not null then
    raise exception
      'Esto de la ficha no lo lleva el entrenador: %. Lo cambia administración; si hay que corregirlo, avisa al club.',
      array_to_string(cambiadas, ', ');
  end if;

  if new.grupo_id is distinct from old.grupo_id and new.grupo_id is not null then
    if not exists (select 1 from public.grupos g
                    where g.id = new.grupo_id and g.entrenador_id = public.mi_perfil_id()) then
      raise exception 'Solo puedes mover al atleta a un grupo que dirijas tú. Para pasarlo a otro entrenador, avisa a administración.';
    end if;
  end if;

  return new;
end; $function$;

-- ---------- helper: ¿esta ficha es (o fue) de natación? ----------
create or replace function public.natacion_es_nadador(p_atleta uuid)
returns boolean
language sql stable security definer
set search_path to 'public'
as $$
  select p_atleta is not null and (
    exists (select 1 from public.natacion_accesos where atleta_id = p_atleta)
    or exists (select 1 from public.natacion_inscripciones where atleta_id = p_atleta)
  );
$$;

-- ---------- buscador de fichas existentes ----------
-- Devuelve lo MÍNIMO para reconocer a la persona: nombre, año de
-- nacimiento, el correo enmascarado (m***@gmail.com) y si ya está en
-- natación. Nada de DNI, teléfonos ni direcciones.
create or replace function public.natacion_buscar_fichas(p_texto text)
returns table(atleta_id uuid, nombre text, anio int, correo text, tiene_correo boolean,
              en_natacion boolean, acceso_activo boolean, codigo text, estado text, donde text)
language plpgsql stable security definer
set search_path to 'public'
as $$
declare
  v_q text := lower(public.unaccent(btrim(coalesce(p_texto, ''))));
  v_palabras text[];
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Solo quien gestiona natación puede buscar fichas.' using errcode = '42501';
  end if;
  if length(v_q) < 3 then
    return;   -- con menos de 3 letras no se busca (evita listar el club entero)
  end if;
  v_palabras := array_remove(regexp_split_to_array(v_q, '\s+'), '');

  return query
  with c as (
    select a.*,
           lower(public.unaccent(btrim(a.nombre || ' ' || coalesce(a.apellidos, '')))) as nn,
           coalesce(nullif(btrim(a.email_tutor), ''), nullif(btrim(a.email), '')) as mail
    from public.atletas a
    where a.anonimizado_en is null
  )
  select c.id,
         btrim(c.nombre || ' ' || coalesce(c.apellidos, '')),
         extract(year from c.fecha_nacimiento)::int,
         case when c.mail is null then null
              else left(c.mail, 1) || '***@' || split_part(c.mail, '@', 2) end,
         c.mail is not null,
         public.natacion_es_nadador(c.id),
         exists (select 1 from public.natacion_accesos x where x.atleta_id = c.id and x.activo),
         (select x.codigo from public.natacion_accesos x where x.atleta_id = c.id and x.activo limit 1),
         c.estado,
         case
           when public.natacion_es_nadador(c.id) then 'Natación'
           when c.tipo_membresia = 'escuela' or 'escuela' = any(coalesce(c.secciones, '{}')) then 'Escuela de atletismo'
           when c.tipo_membresia = 'cubo' then 'El Cubo'
           when c.tipo_membresia = 'socio' or c.numero_socio is not null then 'Socio'
           when c.origen like 'escuela-natacion%' or c.origen like 'sportmember%' then 'Importado de natación'
           else coalesce(array_to_string(c.secciones, ', '), 'Club')
         end
  from c
  where not exists (select 1 from unnest(v_palabras) w where position(w in c.nn) = 0)
  order by public.natacion_es_nadador(c.id) desc, c.nn
  limit 12;
end $$;

-- ---------- alta sobre una ficha que YA existe ----------
-- Crea (o reactiva) su código de acceso, la inscribe en las franjas y,
-- si se le pasan, ADOPTA filas sueltas (inscripciones sin ficha que se
-- metieron a mano escribiendo el nombre). Si la ficha estaba de baja,
-- la vuelve a poner activa. Si no tiene correo y se le da uno, lo
-- guarda (solo rellena huecos, nunca pisa).
create or replace function public.natacion_alta_desde_ficha(
  p_atleta  uuid,
  p_franjas uuid[] default '{}',
  p_nivel   text   default null,
  p_calle   text   default 'C1',
  p_tipo    text   default 'Escuela',
  p_email   text   default null,
  p_adoptar uuid[] default '{}'
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_a       public.atletas%rowtype;
  v_tipo    text := case when p_tipo = 'Máster' then 'Máster' else 'Escuela' end;
  v_nommay  text;
  v_email   text := lower(btrim(coalesce(p_email, '')));
  v_acceso  uuid;
  v_codigo  text;
  v_franja  uuid;
  v_calle   text := coalesce(nullif(btrim(coalesce(p_calle, '')), ''), 'C1');
  v_ins     int := 0;
  v_adopt   int := 0;
  v_tiene   boolean := false;
  v_token   text;
  v_react   boolean := false;
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Solo quien gestiona natación puede dar altas.' using errcode = '42501';
  end if;
  select * into v_a from public.atletas where id = p_atleta and anonimizado_en is null;
  if not found then
    raise exception 'No encuentro esa ficha. Búscala otra vez o da de alta a la persona como nueva.';
  end if;
  if p_nivel is not null and p_nivel not in ('Iniciación', 'Desarrollo', 'Perfeccionamiento') then
    raise exception 'Nivel no válido: %', p_nivel;
  end if;
  if v_email <> '' and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Ese correo no parece válido: %', v_email;
  end if;

  v_nommay := upper(btrim(v_a.nombre || ' ' || coalesce(v_a.apellidos, '')));
  perform set_config('apolana.via_natacion', '1', true);

  -- correo: solo rellena el hueco (escuela → tutor; máster → el suyo)
  if v_email <> '' then
    if v_tipo = 'Máster' then
      update public.atletas set email = v_email, updated_at = now()
       where id = p_atleta and nullif(btrim(coalesce(email, '')), '') is null;
    else
      update public.atletas set email_tutor = v_email, updated_at = now()
       where id = p_atleta and nullif(btrim(coalesce(email_tutor, '')), '') is null;
    end if;
  end if;
  -- el correo que manda es el que quede en la ficha
  select lower(nullif(btrim(case when v_tipo = 'Máster' then email else email_tutor end), ''))
    into v_email from public.atletas where id = p_atleta;

  -- si estaba de baja, vuelve
  if v_a.estado = 'baja' then
    update public.atletas set estado = 'activo', updated_at = now() where id = p_atleta;  -- fecha_baja la limpia atletas_sella_baja
    v_react := true;
  end if;
  perform set_config('apolana.via_natacion', '', true);

  -- código: el activo; si no, reactivar el último; si no, uno nuevo
  select id, codigo into v_acceso, v_codigo
    from public.natacion_accesos where atleta_id = p_atleta and activo
    order by created_at desc limit 1;
  if v_acceso is null then
    select id, codigo into v_acceso, v_codigo
      from public.natacion_accesos where atleta_id = p_atleta
      order by created_at desc limit 1;
    if v_acceso is not null then
      update public.natacion_accesos set activo = true where id = v_acceso;
    end if;
  end if;
  if v_acceso is null then
    loop
      v_codigo := upper(substr(md5(random()::text), 1, 8));
      exit when not exists (select 1 from public.natacion_accesos where codigo = v_codigo);
    end loop;
    insert into public.natacion_accesos (codigo, nombre, atleta_id, activo)
    values (v_codigo, v_nommay, p_atleta, true)
    returning id into v_acceso;
  end if;

  -- adoptar filas sueltas (solo las que NO tienen ya otra ficha/código)
  if coalesce(array_length(p_adoptar, 1), 0) > 0 then
    update public.natacion_inscripciones
       set atleta_id = p_atleta, acceso_id = v_acceso, nombre = v_nommay, updated_at = now()
     where id = any(p_adoptar)
       and (atleta_id is null or atleta_id = p_atleta)
       and (acceso_id is null or acceso_id = v_acceso);
    get diagnostics v_adopt = row_count;
  end if;
  -- y cualquier fila suya que estuviera sin código
  update public.natacion_inscripciones set acceso_id = v_acceso
   where atleta_id = p_atleta and acceso_id is null;

  -- inscribir en las franjas pedidas (sin duplicar las activas)
  foreach v_franja in array coalesce(p_franjas, '{}') loop
    if v_franja is not null and not exists (
         select 1 from public.natacion_inscripciones
          where franja_id = v_franja and activa and (atleta_id = p_atleta or acceso_id = v_acceso)) then
      insert into public.natacion_inscripciones
        (franja_id, nombre, tipo, nivel, calle, acceso_id, atleta_id, activa)
      values (v_franja, v_nommay, v_tipo, p_nivel, v_calle, v_acceso, p_atleta, true);
      v_ins := v_ins + 1;
    end if;
  end loop;

  -- invitación lista si la familia aún no tiene cuenta
  if v_email is not null then
    v_tiene := exists (select 1 from public.perfiles where lower(email) = v_email);
    if not v_tiene then
      select token into v_token from public.familia_invitaciones
       where lower(email_tutor) = v_email and usado_en is null and caduca_en > now()
       order by creado_en desc limit 1;
      if v_token is null then
        loop
          v_token := replace(gen_random_uuid()::text, '-', '');
          exit when not exists (select 1 from public.familia_invitaciones where token = v_token);
        end loop;
        insert into public.familia_invitaciones (token, email_tutor, nota)
        values (v_token, v_email,
                'alta desde ficha ' || (case when v_tipo = 'Máster' then 'máster' else 'escuela natación' end)
                || ' ' || to_char(now(), 'YYYY-MM-DD'));
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'atleta_id', p_atleta, 'acceso_id', v_acceso, 'codigo', v_codigo,
    'inscripciones', v_ins, 'enlazadas', v_adopt, 'reactivada', v_react,
    'email_tutor', v_email, 'ya_tiene_cuenta', v_tiene, 'token', v_token,
    'publico', case when v_tipo = 'Máster' then 'master' else 'familia' end
  );
end $$;

-- ---------- baja COMPLETA de natación ----------
-- Apaga todas sus franjas, su código de acceso, sus reservas de abono
-- futuras y su lista de espera. La FICHA solo se
-- pone «de baja» si no está en nada más del club (otra sección, socio,
-- Cubo…): dar de baja de natación no es echar a nadie del club.
create or replace function public.natacion_dar_baja(p_acceso uuid default null, p_atleta uuid default null)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_atleta uuid := p_atleta;
  v_ins int := 0; v_acc int := 0; v_res int := 0; v_esp int := 0;
  v_ficha boolean := false; v_sigue text := null;
  v_a public.atletas%rowtype;
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Solo quien gestiona natación puede dar bajas.' using errcode = '42501';
  end if;
  if p_acceso is null and p_atleta is null then
    raise exception 'Falta saber a quién dar de baja.';
  end if;
  if v_atleta is null then
    select atleta_id into v_atleta from public.natacion_accesos where id = p_acceso;
  end if;
  -- código viejo sin ficha (importados): la ficha sale de sus inscripciones
  if v_atleta is null and p_acceso is not null then
    select atleta_id into v_atleta from public.natacion_inscripciones
     where acceso_id = p_acceso and atleta_id is not null
     order by updated_at desc limit 1;
    if v_atleta is not null then
      update public.natacion_accesos set atleta_id = v_atleta where id = p_acceso and atleta_id is null;
    end if;
  end if;

  update public.natacion_inscripciones set activa = false, updated_at = now()
   where activa and ((p_acceso is not null and acceso_id = p_acceso)
                  or (v_atleta is not null and atleta_id = v_atleta));
  get diagnostics v_ins = row_count;

  -- reservas de abono futuras: se cancelan (ya no va a venir)
  with c as (
    update public.natacion_reservas set estado = 'cancelada'
     where estado = 'reservada' and fecha >= current_date
       and acceso_id in (select id from public.natacion_accesos
                          where id = p_acceso or (v_atleta is not null and atleta_id = v_atleta))
    returning acceso_id)
  select count(*) into v_res from c;

  update public.natacion_accesos set activo = false
   where activo and (id = p_acceso or (v_atleta is not null and atleta_id = v_atleta));
  get diagnostics v_acc = row_count;

  if v_atleta is not null then
    update public.natacion_lista_espera set activa = false where activa and atleta_id = v_atleta;
    get diagnostics v_esp = row_count;

    select * into v_a from public.atletas where id = v_atleta;
    if found then
      if v_a.grupo_id is not null
         or exists (select 1 from public.atleta_grupos g where g.atleta_id = v_atleta)
         or v_a.tipo_membresia is not null
         or v_a.numero_socio is not null
         or coalesce(array_length(array_remove(array_remove(coalesce(v_a.secciones, '{}'), 'natacion'), 'escuela-natacion'), 1), 0) > 0 then
        v_sigue := coalesce(v_a.tipo_membresia, array_to_string(v_a.secciones, ', '), 'otra sección');
      elsif v_a.estado is distinct from 'baja' then
    perform set_config('apolana.via_natacion', '1', true);
        update public.atletas set estado = 'baja', updated_at = now() where id = v_atleta;  -- fecha_baja la sella atletas_sella_baja
    perform set_config('apolana.via_natacion', '', true);
        v_ficha := true;
      end if;
    end if;
  end if;

  return jsonb_build_object('ok', true, 'franjas', v_ins, 'codigos', v_acc,
    'reservas', v_res, 'espera', v_esp, 'ficha_de_baja', v_ficha, 'sigue_en', v_sigue);
end $$;

-- ---------- contacto de la familia (solo nadadores) ----------
create or replace function public.natacion_contacto_de(p_atleta uuid)
returns table(nombre text, apellidos text, fecha_nacimiento date,
              email text, telefono text, nombre_tutor text, email_tutor text,
              telefono_tutor text, direccion text, familia_con_cuenta boolean)
language sql stable security definer
set search_path to 'public'
as $$
  select a.nombre, a.apellidos, a.fecha_nacimiento, a.email, a.telefono,
         a.nombre_tutor, a.email_tutor, a.telefono_tutor, a.direccion,
         (a.perfil_padre_id is not null or a.perfil_id is not null
          or exists (select 1 from public.perfiles p
                      where lower(p.email) = lower(coalesce(nullif(btrim(a.email_tutor), ''), nullif(btrim(a.email), '')))))
  from public.atletas a
  where a.id = p_atleta
    and (public.es_admin() or (public.soy_gestor_natacion() and public.natacion_es_nadador(p_atleta)));
$$;

-- null = no tocar · '' = borrar
create or replace function public.natacion_guardar_contacto(
  p_atleta uuid,
  p_email text default null, p_telefono text default null,
  p_nombre_tutor text default null, p_email_tutor text default null,
  p_telefono_tutor text default null, p_direccion text default null
) returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v_mail_re text := '^[^@\s]+@[^@\s]+\.[^@\s]+$';
begin
  if not (public.es_admin() or (public.soy_gestor_natacion() and public.natacion_es_nadador(p_atleta))) then
    raise exception 'Solo puedes cambiar los datos de nadadores de natación.' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_email, '')), '') is not null and btrim(p_email) !~ v_mail_re then
    raise exception 'El correo del nadador no parece válido.';
  end if;
  if nullif(btrim(coalesce(p_email_tutor, '')), '') is not null and btrim(p_email_tutor) !~ v_mail_re then
    raise exception 'El correo del tutor no parece válido.';
  end if;
  perform set_config('apolana.via_natacion', '1', true);
  update public.atletas set
    email          = case when p_email is null then email else nullif(lower(btrim(p_email)), '') end,
    telefono       = case when p_telefono is null then telefono else nullif(btrim(p_telefono), '') end,
    nombre_tutor   = case when p_nombre_tutor is null then nombre_tutor else nullif(btrim(p_nombre_tutor), '') end,
    email_tutor    = case when p_email_tutor is null then email_tutor else nullif(lower(btrim(p_email_tutor)), '') end,
    telefono_tutor = case when p_telefono_tutor is null then telefono_tutor else nullif(btrim(p_telefono_tutor), '') end,
    direccion      = case when p_direccion is null then direccion else nullif(btrim(p_direccion), '') end,
    updated_at     = now()
  where id = p_atleta;
  perform set_config('apolana.via_natacion', '', true);
  return jsonb_build_object('ok', found);
end $$;

-- ---------- dirección: solo fichas de natación (antes cualquiera) ----------
create or replace function public.natacion_set_direccion(p_atleta uuid, p_direccion text)
returns boolean
language plpgsql security definer
set search_path to 'public'
as $$
begin
  if not (public.es_admin() or (public.soy_gestor_natacion() and public.natacion_es_nadador(p_atleta))) then
    raise exception 'Solo puedes cambiar la ficha de nadadores de natación.' using errcode = '42501';
  end if;
  if p_atleta is null then return false; end if;
  perform set_config('apolana.via_natacion', '1', true);
  update public.atletas
     set direccion = nullif(btrim(coalesce(p_direccion, '')), ''), updated_at = now()
   where id = p_atleta;
  perform set_config('apolana.via_natacion', '', true);
  return found;
end $$;

create or replace function public.natacion_get_direccion(p_atleta uuid)
returns text
language sql stable security definer
set search_path to 'public'
as $$
  select a.direccion from public.atletas a
  where a.id = p_atleta
    and (public.es_admin()
         or ((public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))
             and public.natacion_es_nadador(p_atleta)));
$$;

-- ---------- enlazar ficha suelta: mismo permiso que todo natación ----------
create or replace function public.natacion_enlazar_ficha(p_inscripcion uuid)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v_atleta uuid; v_nombre text; v_acceso uuid; v_codigo text;
begin
  if not public.soy_gestor_natacion() then
    return jsonb_build_object('ok', false, 'msg', 'Solo quien gestiona natación puede hacer esto.'); end if;

  select atleta_id, nombre into v_atleta, v_nombre
    from public.natacion_inscripciones where id = p_inscripcion;
  if not found then return jsonb_build_object('ok', false, 'msg', 'Ficha no encontrada.'); end if;

  if v_atleta is not null then
    select id into v_acceso from public.natacion_accesos
      where atleta_id = v_atleta and activo limit 1;
  end if;

  if v_acceso is null then
    loop
      v_codigo := upper(substr(md5(random()::text), 1, 8));
      exit when not exists (select 1 from public.natacion_accesos where codigo = v_codigo);
    end loop;
    insert into public.natacion_accesos (codigo, nombre, atleta_id, activo)
    values (v_codigo, upper(coalesce(nullif(btrim(v_nombre), ''), '(sin nombre)')), v_atleta, true)
    returning id into v_acceso;
  end if;

  if v_atleta is not null then
    update public.natacion_inscripciones set acceso_id = v_acceso
     where atleta_id = v_atleta and acceso_id is null;
  else
    update public.natacion_inscripciones set acceso_id = v_acceso
     where id = p_inscripcion and acceso_id is null;
  end if;

  return jsonb_build_object('ok', true);
end $$;

-- ---------- alta nueva: sin DNI, no duplicar por nombre + nacimiento ----------
create or replace function public.natacion_crear_nadador(p_nombre text, p_apellidos text DEFAULT NULL::text, p_dni text DEFAULT NULL::text, p_fecha_nac date DEFAULT NULL::date, p_email_tutor text DEFAULT NULL::text, p_nombre_tutor text DEFAULT NULL::text, p_telefono_tutor text DEFAULT NULL::text, p_franjas uuid[] DEFAULT '{}'::uuid[], p_nivel text DEFAULT NULL::text, p_calle text DEFAULT 'C1'::text, p_tipo text DEFAULT 'Escuela'::text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_atleta   uuid;
  v_acceso   uuid;
  v_codigo   text;
  v_token    text;
  v_tiene    boolean;
  v_email    text := lower(btrim(coalesce(p_email_tutor, '')));
  v_nombref  text := btrim(coalesce(p_nombre, '') || ' ' || coalesce(p_apellidos, ''));
  v_nommay   text := upper(v_nombref);
  v_dni      text := nullif(btrim(coalesce(p_dni, '')), '');
  v_franja   uuid;
  v_calle    text := coalesce(nullif(btrim(coalesce(p_calle, '')), ''), 'C1');
  v_ins      int := 0;
begin
  if not public.soy_gestor_natacion() then
    raise exception 'Solo quien gestiona natación puede dar de alta nadadores.'
      using errcode = '42501';
  end if;

  if btrim(coalesce(p_nombre, '')) = '' then
    raise exception 'Falta el nombre del nadador.';
  end if;
  if v_email = '' or position('@' in v_email) = 0 then
    raise exception 'Falta un correo válido (es lo que ata la cuenta: del tutor en escuela, del propio nadador en máster).';
  end if;
  if p_nivel is not null and p_nivel not in ('Iniciación', 'Desarrollo', 'Perfeccionamiento') then
    raise exception 'Nivel no válido: %', p_nivel;
  end if;

  -- 1) ficha: reutilizar por DNI; si no hay DNI, por nombre completo +
  --    fecha de nacimiento (sin acentos ni mayúsculas). Si no, crear.
  if v_dni is not null then
    select id into v_atleta from public.atletas where upper(dni) = upper(v_dni) limit 1;
  end if;
  if v_atleta is null and p_fecha_nac is not null then
    select id into v_atleta from public.atletas
     where anonimizado_en is null and fecha_nacimiento = p_fecha_nac
       and lower(public.unaccent(btrim(nombre || ' ' || coalesce(apellidos, ''))))
           = lower(public.unaccent(v_nombref))
     order by created_at limit 1;
  end if;

  perform set_config('apolana.via_natacion', '1', true);
  if v_atleta is null then
    if p_tipo = 'Máster' then
      insert into public.atletas (nombre, apellidos, dni, fecha_nacimiento, email, telefono, estado)
      values (btrim(p_nombre), nullif(btrim(coalesce(p_apellidos, '')), ''), v_dni, p_fecha_nac,
              v_email, nullif(btrim(coalesce(p_telefono_tutor, '')), ''), 'activo')
      returning id into v_atleta;
    else
      insert into public.atletas (nombre, apellidos, dni, fecha_nacimiento,
                                  email_tutor, nombre_tutor, telefono_tutor, estado)
      values (btrim(p_nombre), nullif(btrim(coalesce(p_apellidos, '')), ''), v_dni, p_fecha_nac,
              v_email, nullif(btrim(coalesce(p_nombre_tutor, '')), ''),
              nullif(btrim(coalesce(p_telefono_tutor, '')), ''), 'activo')
      returning id into v_atleta;
    end if;
  else
    if p_tipo = 'Máster' then
      update public.atletas set
        apellidos        = coalesce(apellidos, nullif(btrim(coalesce(p_apellidos, '')), '')),
        dni              = coalesce(dni, v_dni),
        fecha_nacimiento = coalesce(fecha_nacimiento, p_fecha_nac),
        email            = coalesce(nullif(btrim(coalesce(email, '')), ''), v_email),
        telefono         = coalesce(nullif(btrim(coalesce(telefono, '')), ''), nullif(btrim(coalesce(p_telefono_tutor, '')), '')),
        estado           = case when estado = 'baja' then 'activo' else estado end,
        updated_at       = now()
      where id = v_atleta;
    else
      update public.atletas set
        apellidos        = coalesce(apellidos, nullif(btrim(coalesce(p_apellidos, '')), '')),
        dni              = coalesce(dni, v_dni),
        fecha_nacimiento = coalesce(fecha_nacimiento, p_fecha_nac),
        email_tutor      = coalesce(nullif(btrim(coalesce(email_tutor, '')), ''), v_email),
        nombre_tutor     = coalesce(nullif(btrim(coalesce(nombre_tutor, '')), ''), nullif(btrim(coalesce(p_nombre_tutor, '')), '')),
        telefono_tutor   = coalesce(nullif(btrim(coalesce(telefono_tutor, '')), ''), nullif(btrim(coalesce(p_telefono_tutor, '')), '')),
        estado           = case when estado = 'baja' then 'activo' else estado end,
        updated_at       = now()
      where id = v_atleta;
    end if;
  end if;
  perform set_config('apolana.via_natacion', '', true);

  -- 2) código: el activo; si no, reactivar el último; si no, uno nuevo
  select id, codigo into v_acceso, v_codigo
  from public.natacion_accesos where atleta_id = v_atleta and activo limit 1;
  if v_acceso is null then
    select id, codigo into v_acceso, v_codigo
      from public.natacion_accesos where atleta_id = v_atleta order by created_at desc limit 1;
    if v_acceso is not null then
      update public.natacion_accesos set activo = true where id = v_acceso;
    end if;
  end if;
  if v_acceso is null then
    loop
      v_codigo := upper(substr(md5(random()::text), 1, 8));
      exit when not exists (select 1 from public.natacion_accesos where codigo = v_codigo);
    end loop;
    insert into public.natacion_accesos (codigo, nombre, atleta_id, activo)
    values (v_codigo, v_nommay, v_atleta, true)
    returning id into v_acceso;
  end if;

  -- 3) una inscripción por franja (sin duplicar las activas)
  foreach v_franja in array coalesce(p_franjas, '{}') loop
    if v_franja is not null
       and not exists (select 1 from public.natacion_inscripciones
                       where franja_id = v_franja and atleta_id = v_atleta and activa) then
      insert into public.natacion_inscripciones
        (franja_id, nombre, tipo, nivel, calle, acceso_id, atleta_id, activa)
      values (v_franja, v_nommay, coalesce(nullif(p_tipo, ''), 'Escuela'),
              p_nivel, v_calle, v_acceso, v_atleta, true);
      v_ins := v_ins + 1;
    end if;
  end loop;

  -- 4) ¿la familia ya tiene cuenta? si no, dejar token listo
  v_tiene := exists (select 1 from public.perfiles where lower(email) = v_email);
  if not v_tiene then
    select token into v_token from public.familia_invitaciones
    where lower(email_tutor) = v_email and usado_en is null and caduca_en > now()
    order by creado_en desc limit 1;
    if v_token is null then
      loop
        v_token := replace(gen_random_uuid()::text, '-', '');
        exit when not exists (select 1 from public.familia_invitaciones where token = v_token);
      end loop;
      insert into public.familia_invitaciones (token, email_tutor, nota)
      values (v_token, v_email,
              'alta ' || (case when p_tipo = 'Máster' then 'máster' else 'escuela natación' end)
              || ' ' || to_char(now(), 'YYYY-MM-DD'));
    end if;
  end if;

  return jsonb_build_object(
    'atleta_id',     v_atleta,
    'acceso_id',     v_acceso,
    'codigo',        v_codigo,
    'inscripciones', v_ins,
    'ya_tiene_cuenta', v_tiene,
    'email_tutor',   v_email,
    'token',         v_token
  );
end;
$function$;

-- ---------- permisos de ejecución ----------
revoke all on function public.natacion_buscar_fichas(text) from public, anon;
revoke all on function public.natacion_alta_desde_ficha(uuid, uuid[], text, text, text, text, uuid[]) from public, anon;
revoke all on function public.natacion_dar_baja(uuid, uuid) from public, anon;
revoke all on function public.natacion_contacto_de(uuid) from public, anon;
revoke all on function public.natacion_guardar_contacto(uuid, text, text, text, text, text, text) from public, anon;
grant execute on function public.natacion_es_nadador(uuid) to authenticated;
grant execute on function public.natacion_buscar_fichas(text) to authenticated;
grant execute on function public.natacion_alta_desde_ficha(uuid, uuid[], text, text, text, text, uuid[]) to authenticated;
grant execute on function public.natacion_dar_baja(uuid, uuid) to authenticated;
grant execute on function public.natacion_contacto_de(uuid) to authenticated;
grant execute on function public.natacion_guardar_contacto(uuid, text, text, text, text, text, text) to authenticated;
