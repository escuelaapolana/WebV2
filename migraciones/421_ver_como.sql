-- 421 · Panel · «Ver como…» DE VERDAD (solo mirar)
-- ------------------------------------------------------------------------
-- Andrés quiere ver la app TAL COMO LA VE UNA PERSONA concreta (Joan Pellín
-- entrenador de Azul 2, una familia, un atleta de la Academia, Mario…) sin
-- cambiar de cuenta ni de papel. El portal (assets/js/portal-auth.js) entra en
-- «modo ver como» con ?como=<perfil_id>, pinta la app con el perfil de esa
-- persona y BLOQUEA en el navegador todo lo que escribe (insert/update/upsert/
-- delete, RPC que escriben, subir ficheros, funciones Edge, contraseña).
--
-- Esta migración pone tres piezas en la base, las tres SOLO para un admin de
-- verdad (por su papel concedido, no por el que lleva puesto ahora):
--
--   · soy_admin_de_verdad()                 → ¿esta cuenta tiene el papel admin
--                                              (rol o roles), aunque ahora vaya
--                                              «como entrenador»? es_admin() mira
--                                              coalesce(rol_activo, rol) y daría false.
--   · ver_como_perfil(p_id)                 → la ficha de la persona (lo que el
--                                              portal le pasa a la pantalla) y si
--                                              el admin está ahora como admin
--                                              (si no, la RLS le deja leer menos).
--   · ver_como_leer(p_perfil, p_fn, p_args) → llama a UNA función de LECTURA de
--                                              la lista de abajo COMO SI la
--                                              llamara esa persona: cambia, solo
--                                              dentro de esta llamada, el correo y
--                                              el id del JWT (request.jwt.claims),
--                                              así auth.uid(), auth.jwt(),
--                                              mi_perfil_id(), es_admin(),
--                                              mis_secciones_responsable()… dan los
--                                              de la persona. Arregla la limitación
--                                              de las RPC «mías» (natacion_mis_plazas,
--                                              mi_cuota_entreno, mis_mundos…).
--
-- Por qué es seguro:
--   1) Solo admin de verdad (soy_admin_de_verdad), y el admin ya puede leer
--      casi todo con «admin gestiona todo».
--   2) Solo funciones de una LISTA CERRADA y que además sean STABLE/IMMUTABLE.
--      Fuera, a propósito, lo privado entre dos personas (mis_conversaciones,
--      mis_contactos_mensajes: la RLS de mensajes_directos no deja ni al admin)
--      y lo de la contraseña (tengo_contrasena).
--   3) Antes de llamar se pone la transacción en SOLO LECTURA
--      (transaction_read_only = on): aunque una función de la lista llamara por
--      dentro a otra que escribe, la base lo rechaza.
--   4) El cambio del JWT y el «solo lectura» son SET LOCAL dentro de una función
--      con SET search_path: Postgres los deshace al salir de ella (y además
--      PostgREST abre una transacción por petición).
--
-- Si se crea una RPC de lectura nueva que se use en el portal, hay que
-- añadirla aquí (c_permitidas) Y en LECTURA_COMO de portal-auth.js; mientras
-- no esté, en «ver como» esa parte sale como «no disponible».
-- ------------------------------------------------------------------------
begin;

-- 1 · ¿Admin de verdad? (por el papel concedido, no el activo)
create or replace function public.soy_admin_de_verdad()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles p
     where p.email = (auth.jwt() ->> 'email')
       and coalesce(p.activo, true)
       and (p.rol = 'admin' or 'admin' = any(coalesce(p.roles, array[p.rol])))
  );
$$;

revoke execute on function public.soy_admin_de_verdad() from public, anon;
grant execute on function public.soy_admin_de_verdad() to authenticated, service_role;

-- 2 · La ficha de la persona que se quiere mirar
create or replace function public.ver_como_perfil(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v jsonb;
begin
  if not public.soy_admin_de_verdad() then
    return jsonb_build_object('ok', false, 'motivo', 'no_admin');
  end if;
  select jsonb_build_object(
           'id', p.id, 'nombre', p.nombre, 'apellidos', p.apellidos, 'email', p.email,
           'rol', p.rol, 'roles', p.roles, 'rol_activo', p.rol_activo,
           'seccion', p.seccion, 'foto_ruta', p.foto_ruta, 'activo', p.activo)
    into v
    from public.perfiles p
   where p.id = p_id;
  if v is null then
    return jsonb_build_object('ok', false, 'motivo', 'no_existe');
  end if;
  return jsonb_build_object('ok', true, 'perfil', v, 'admin_activo', public.es_admin());
end;
$$;

revoke execute on function public.ver_como_perfil(uuid) from public, anon;
grant execute on function public.ver_como_perfil(uuid) to authenticated, service_role;

-- 3 · Leer COMO la persona (solo funciones de lectura de la lista)
create or replace function public.ver_como_leer(p_perfil uuid, p_fn text, p_args jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
volatile          -- usa set_config; por dentro, la transacción va en solo lectura
security definer
set search_path = public
as $$
declare
  v_orig text;
  c_permitidas constant text[] := array[
    'apo_faltas_avisadas', 'atleta_pide_bienestar', 'atletas_sin_etiqueta', 'atletas_sin_etiqueta_cuantos',
    'biblioteca_usos', 'buscador_personas_resumen', 'calendario_club', 'cobro_asistente_datos',
    'cobro_asistente_personas', 'comunicacion_resumen', 'conf_lista', 'conf_resumen',
    'contacto_familia_atleta', 'cubo_es_gestor', 'cubo_mis_ausencias', 'dia_cancelado',
    'dinero_bandeja', 'dinero_destinatarios', 'dinero_quien_soy', 'es_admin', 'es_escuela',
    'es_responsable_liga', 'es_staff', 'excepciones_rango', 'general_resumen', 'general_secciones',
    'juego_es_menor', 'mi_cuota_entreno', 'mi_perfil_id', 'mis_avisos', 'mis_mundos', 'mis_papeles',
    'mis_secciones_responsable', 'mis_solicitudes_sin_contestar', 'mundo_stats', 'natacion_acceso_de',
    'natacion_alta_cuota', 'natacion_alta_ficha_faltan', 'natacion_alta_franjas',
    'natacion_aviso_destinatarios', 'natacion_aviso_franjas', 'natacion_buscar_fichas',
    'natacion_contacto_de', 'natacion_cuotas_listar', 'natacion_cuotas_puede', 'natacion_dia_cancelado',
    'natacion_espera_mias', 'natacion_huecos', 'natacion_lista_dia', 'natacion_master_disponibles',
    'natacion_master_estado', 'natacion_mis_plazas', 'natacion_reservas_dia', 'pagos_disponible',
    'pagos_resumen', 'papeles_pendientes', 'pedidos_admin_listar', 'perfil_socios_encendido',
    'retos_progreso_atleta', 'retos_propios_historial', 'retos_propios_progreso', 'sesion_solicitudes',
    'soy_gestor_natacion', 'soy_responsable'
  ];
  v_email      text;
  v_args       jsonb := coalesce(p_args, '{}'::jsonb);
  v_oid        oid;
  v_retset     boolean;
  v_nargs      integer;
  v_nombres    text[];
  v_modos      "char"[];
  v_todos      oid[];
  v_entrada    oidvector;
  v_lista      text := '';
  v_nom        text;
  v_tipo       oid;
  v_modo       "char";
  v_es_array   boolean;
  v_expr       text;
  v_sql        text;
  v_res        jsonb;
  v_claims     jsonb;
  i            integer;
begin
  if not public.soy_admin_de_verdad() then
    raise exception 'ver_como: solo para administración' using errcode = '42501';
  end if;
  if p_fn is null or not (p_fn = any(c_permitidas)) then
    raise exception 'ver_como: «%» no se puede leer en «ver como»', p_fn using errcode = '42501';
  end if;
  if jsonb_typeof(v_args) <> 'object' then
    raise exception 'ver_como: argumentos no válidos' using errcode = '22023';
  end if;

  select p.email into v_email from public.perfiles p where p.id = p_perfil;
  if v_email is null then
    raise exception 'ver_como: no existe esa persona' using errcode = 'P0002';
  end if;

  -- La versión de la función que encaja con los argumentos que llegan (todas
  -- las claves son argumentos suyos); si hay varias, la de menos argumentos.
  select p.oid, p.proretset, p.pronargs, p.proargnames, p.proargmodes, p.proallargtypes, p.proargtypes
    into v_oid, v_retset, v_nargs, v_nombres, v_modos, v_todos, v_entrada
    from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and p.proname = p_fn
     and p.provolatile in ('s', 'i')
     and not exists (
       select 1 from jsonb_object_keys(v_args) k
        where not (k = any(coalesce(p.proargnames, '{}'::text[]))))
   order by p.pronargs
   limit 1;
  if v_oid is null then
    raise exception 'ver_como: «%» no encaja con esos argumentos', p_fn using errcode = '42883';
  end if;

  -- Argumentos por nombre (p_x => valor), solo los que llegan: el resto, su
  -- valor por defecto. Con su tipo: listas (uuid[], text[]…) desde un array JSON.
  if v_nombres is not null then
    for i in 1 .. coalesce(array_length(v_nombres, 1), 0) loop
      v_nom := v_nombres[i];
      if v_modos is null then
        v_modo := 'i';
        v_tipo := v_entrada[i - 1];          -- oidvector va desde 0
      else
        v_modo := v_modos[i];
        v_tipo := v_todos[i];
      end if;
      continue when v_modo not in ('i', 'b') or v_nom is null or v_nom = '' or not (v_args ? v_nom);

      select (t.typcategory = 'A') into v_es_array from pg_type t where t.oid = v_tipo;
      if v_tipo in ('jsonb'::regtype, 'json'::regtype) then
        v_expr := format('($1 -> %L)::%s', v_nom, format_type(v_tipo, null));
      elsif v_es_array then
        v_expr := format('(case when jsonb_typeof($1 -> %1$L) = ''array'' then array(select jsonb_array_elements_text($1 -> %1$L)) end)::%2$s',
                         v_nom, format_type(v_tipo, null));
      else
        v_expr := format('($1 ->> %L)::%s', v_nom, format_type(v_tipo, null));
      end if;
      v_lista := v_lista || case when v_lista = '' then '' else ', ' end || format('%I => %s', v_nom, v_expr);
    end loop;
  end if;

  -- Desde aquí, SOLO LECTURA y con la identidad de la persona. Las dos cosas
  -- son locales: Postgres las deshace al salir de esta función.
  v_claims := coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb)
              || jsonb_build_object('sub', p_perfil::text, 'email', v_email, 'role', 'authenticated');
  v_orig := current_setting('request.jwt.claims', true);   -- para devolverlo al terminar
  perform set_config('request.jwt.claims', v_claims::text, true);
  perform set_config('request.jwt.claim', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.email', '', true);
  perform set_config('transaction_read_only', 'on', true);

  -- Mismo «dibujo» que devolvería PostgREST: lista para las que devuelven
  -- varias filas; el valor (o el objeto) para las demás.
  v_sql := format('select %s from public.%I(%s) as t',
                  case when v_retset then 'coalesce(jsonb_agg(to_jsonb(t)), ''[]''::jsonb)' else 'to_jsonb(t)' end,
                  p_fn, v_lista);
  execute v_sql using v_args into v_res;
  -- Se vuelve a ser el admin: el resto de la transacción no sigue «como» la persona.
  perform set_config('request.jwt.claims', coalesce(v_orig, ''), true);
  return v_res;
end;
$$;

revoke execute on function public.ver_como_leer(uuid, text, jsonb) from public, anon;
grant execute on function public.ver_como_leer(uuid, text, jsonb) to authenticated, service_role;

commit;

-- Comprobación rápida con psql, haciéndose pasar por un admin SOLO en la transacción:
--   begin;
--   select set_config('request.jwt.claims', '{"email":"<correo de un admin>","role":"authenticated"}', true);
--   select public.soy_admin_de_verdad();
--   select public.ver_como_perfil('<perfil_id>');
--   select public.ver_como_leer('<perfil_id>', 'mi_perfil_id', '{}');          -- debe dar ese id
--   select public.ver_como_leer('<perfil_id>', 'natacion_mis_plazas', '{}');
--   select public.ver_como_leer('<perfil_id>', 'dia_cancelado', '{"p_fecha":"2026-10-21","p_seccion":"escuela"}');
--   select public.ver_como_leer('<perfil_id>', 'mis_conversaciones', '{}');    -- debe FALLAR (no está en la lista)
--   rollback;
-- OJO a comprobar al aplicar: que ver_como_leer NO falla al salir (al deshacer
-- el transaction_read_only local). Si fallara, quitar esa línea: la lista
-- cerrada de funciones STABLE ya impide escribir.
