-- ============================================================
-- 386 · Seguridad y limpieza de la base (revisión 15-oct, aprobada)
-- ------------------------------------------------------------
-- 1) cuotas_entreno: solo admin y quien ve el dinero (tesorería /
--    contabilidad). Antes también cualquier staff (entrenador, junta,
--    coordinador). La pantalla admin/cuotas-entreno solo la abren admin,
--    tesorería/contabilidad/junta y escuela; el portal no la lee. Las RPC
--    de Dinero que la usan son SECURITY DEFINER (no les afecta).
-- 2) purga_6anios_preview(): SECURITY DEFINER que listaba fichas de baja a
--    cualquiera con sesión. Nadie la llama desde el navegador → fuera
--    EXECUTE para public/anon/authenticated (service_role y postgres sí).
-- 3) marcar_cambio_clave(text): solo la llama la Edge acceso-enlace con la
--    clave service_role → fuera EXECUTE para public/anon/authenticated.
-- 4) Freno anti-spam (public.anti_spam, por IP) en alta_entrenador,
--    tienda_pago_iniciar y tienda_pedido_efectivo, igual que en
--    liga_comunicar_prueba / natacion_marcar_ausencia. OJO: solo a las
--    llamadas DIRECTAS (anon/authenticated con la clave pública). Las Edge
--    Functions (entrenador-alta, tienda-pagar) llaman con service_role y la
--    IP que vería la base sería la de Supabase, la misma para todos: frenarlas
--    aquí sería un tope global. (Igual criterio que la 192: lo que pasa por
--    Edge se frena en la Edge, que ve la IP real.) Nada más cambia: mismas
--    respuestas.
-- 5) Privilegios por defecto: las funciones NUEVAS que cree postgres en
--    public ya no nacen ejecutables por PUBLIC (=anon); solo authenticated y
--    service_role. Una RPC pensada para visitantes tendrá que llevar su
--    `grant execute … to anon` explícito. No toca las funciones existentes.
-- 6) Políticas TO public (incluyen a anon) que llaman a funciones sin
--    EXECUTE para anon → «permission denied for function» a los visitantes.
--    Son todas de usuarios con sesión (escuela, bienestar del atleta,
--    natación, sesiones del atleta) → TO authenticated.
-- 7) Políticas viejas / duplicadas de admin. Cada DROP comprueba antes que
--    sigue existiendo «admin gestiona todo» (ALL, TO authenticated,
--    es_admin() en USING y WITH CHECK) en esa tabla; si no, se para.
--    Nota: las «Admin acceso total - …» miraban perfiles.rol='admin' y
--    p.id = auth.uid() (sin rol_activo ni activo). Con es_admin() manda el
--    papel ACTIVO: un admin que se pone «atleta» con el interruptor deja de
--    ver pagos/pedidos/productos/eventos de todos mientras está así, que es
--    lo que ya pasaba en el resto de tablas.
-- 8) Índices: fuera 3 duplicados (cubiertos por un UNIQUE con las mismas
--    columnas) y nuevos índices en claves foráneas usadas en RLS/joins.
-- ============================================================

begin;

-- ---------- 1 · cuotas_entreno ----------
alter policy "admin gestiona cuotas entreno" on public.cuotas_entreno
  using      ((select public.es_admin()) or (select public.ve_dinero()))
  with check ((select public.es_admin()) or (select public.ve_dinero()));

-- ---------- 2 · purga_6anios_preview ----------
revoke execute on function public.purga_6anios_preview() from public, anon, authenticated;
grant  execute on function public.purga_6anios_preview() to service_role;

-- ---------- 3 · marcar_cambio_clave ----------
revoke execute on function public.marcar_cambio_clave(text) from public, anon, authenticated;
grant  execute on function public.marcar_cambio_clave(text) to service_role;

-- ---------- 4 · anti-spam ----------
CREATE OR REPLACE FUNCTION public.alta_entrenador(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_email     text := lower(public.texto_de_fuera(p ->> 'email', 160));
  v_nombre    text := public.texto_de_fuera(p ->> 'nombre', 120);
  v_apellidos text := coalesce(public.texto_de_fuera(p ->> 'apellidos', 120), '');
  v_segundos  int  := coalesce((p ->> 'segundos')::int, 0);
begin
  if public.texto_de_fuera(p ->> 'apellido_de_soltera', 100) is not null
     or v_segundos < 5 then
    return jsonb_build_object('ok', true, 'ya', 'nuevo');
  end if;
  -- 386 · Freno por IP a las llamadas directas (la Edge entrenador-alta
  -- llama con service_role: ahí la IP sería la de Supabase, no la del visitante).
  if coalesce(auth.role(), '') <> 'service_role' then
    perform public.anti_spam('alta_entrenador', 5, interval '1 hour');
  end if;
  if v_email is null or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return jsonb_build_object('ok', false, 'motivo', 'correo',
      'mensaje', 'Ese correo no parece bien escrito. Revísalo, por favor.');
  end if;
  if v_nombre is null then
    return jsonb_build_object('ok', false, 'motivo', 'nombre', 'mensaje', 'Pon tu nombre.');
  end if;
  if exists (select 1 from public.perfiles where lower(email) = v_email) then
    return jsonb_build_object('ok', true, 'ya', 'perfil');
  end if;
  if exists (select 1 from public.invitaciones_equipo where email = v_email and usado_en is null) then
    return jsonb_build_object('ok', true, 'ya', 'invitado');
  end if;
  -- Antes: rol 'entrenador' (staff) directo. Ahora 'pendiente': la cuenta se
  -- crea SIN permisos de staff hasta que un admin la apruebe (le pone el rol
  -- 'entrenador' desde admin/entrenadores).
  insert into public.invitaciones_equipo (email, nombre, apellidos, rol, roles)
  values (v_email, v_nombre, v_apellidos, 'pendiente', array['pendiente']);
  return jsonb_build_object('ok', true, 'ya', 'nuevo');
end;
$function$;

CREATE OR REPLACE FUNCTION public.tienda_pago_iniciar(p_items jsonb, p_contacto jsonb DEFAULT '{}'::jsonb, p_perfil uuid DEFAULT NULL::uuid, p_metadatos jsonb DEFAULT '{}'::jsonb)
 RETURNS pagos_online
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_cfg      public.pagos_config;
  v_item     jsonb;
  v_prod     public.productos;
  v_talla    text;
  v_cant     integer;
  v_total    numeric := 0;
  v_n        integer := 0;
  v_pedido   uuid;
  v_ref      text;
  v_pago     public.pagos_online;
  v_concepto text;
begin
  -- 386 · Freno por IP a las llamadas directas (la Edge tienda-pagar llama con
  -- service_role: ahí la IP sería la de Supabase, no la del comprador).
  if coalesce(auth.role(), '') <> 'service_role' then
    perform public.anti_spam('tienda_pago', 10, interval '10 minutes');
  end if;

  select * into v_cfg from public.pagos_config where id = 1;
  if not found or not v_cfg.activo then
    raise exception 'El pago con tarjeta todavía no está activado.' using errcode = 'P0001';
  end if;

  -- SEGURIDAD: no fiarse del p_perfil del cliente. Se ata al perfil de la sesión
  -- (mi_perfil_id() = null si es invitado, y entonces el pedido va sin perfil, con
  -- los datos de contacto). Solo un admin puede crear a nombre de otro.
  if not public.es_admin() then
    p_perfil := public.mi_perfil_id();
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'El carrito está vacío.' using errcode = 'P0001';
  end if;

  insert into public.pedidos (perfil_id, estado, total, contacto)
  values (p_perfil, 'pendiente', 0, coalesce(p_contacto, '{}'::jsonb))
  returning id into v_pedido;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_talla := trim(coalesce(v_item ->> 'talla', ''));
    v_cant  := greatest(1, least(10, coalesce((v_item ->> 'cantidad')::int, 1)));

    select * into v_prod from public.productos
      where id = (v_item ->> 'producto_id')::uuid and activo;
    if not found then
      raise exception 'Uno de los productos ya no está disponible.' using errcode = 'P0001';
    end if;
    if v_prod.precio is null or v_prod.precio <= 0 then
      raise exception 'Un producto no tiene precio.' using errcode = 'P0001';
    end if;

    if v_prod.tallas_disponibles is not null and array_length(v_prod.tallas_disponibles, 1) > 0 then
      if v_talla = '' or not (v_talla = any(v_prod.tallas_disponibles)) then
        raise exception 'Talla no válida para %.', v_prod.nombre using errcode = 'P0001';
      end if;
      if v_prod.tallas_agotadas is not null and v_talla = any(v_prod.tallas_agotadas) then
        raise exception '% en talla % está agotado.', v_prod.nombre, v_talla using errcode = 'P0001';
      end if;
    else
      v_talla := nullif(v_talla, '');
    end if;

    insert into public.pedido_items (pedido_id, producto_id, talla, cantidad, precio_unitario)
    values (v_pedido, v_prod.id, v_talla, v_cant, v_prod.precio);

    v_total := v_total + v_prod.precio * v_cant;
    v_n := v_n + v_cant;
  end loop;

  if v_total <= 0 then
    raise exception 'El total del pedido no es válido.' using errcode = 'P0001';
  end if;

  update public.pedidos set total = v_total where id = v_pedido;

  v_concepto := 'Pedido de tienda · ' || v_n || case when v_n = 1 then ' artículo' else ' artículos' end;

  v_ref := 'APO-' || to_char(now(), 'YYMMDD') || '-' ||
           upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  insert into public.pagos_online
    (referencia, perfil_id, concepto, tipo, importe_centimos, metadatos)
  values
    (v_ref, p_perfil, v_concepto, 'ropa', round(v_total * 100)::int,
     coalesce(p_metadatos, '{}'::jsonb) || jsonb_build_object('pedido_id', v_pedido, 'articulos', v_n))
  returning * into v_pago;

  update public.pedidos set pago_online_id = v_pago.id where id = v_pedido;

  return v_pago;
end;
$function$;

CREATE OR REPLACE FUNCTION public.tienda_pedido_efectivo(p_items jsonb, p_contacto jsonb DEFAULT '{}'::jsonb, p_perfil uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item   jsonb;
  v_prod   public.productos;
  v_talla  text;
  v_cant   integer;
  v_n      integer := 0;
  v_pedido uuid;
  v_total  numeric;
begin
  -- 386 · Freno por IP a las llamadas directas (la Edge tienda-pagar llama con
  -- service_role: ahí la IP sería la de Supabase, no la del comprador).
  if coalesce(auth.role(), '') <> 'service_role' then
    perform public.anti_spam('tienda_efectivo', 10, interval '10 minutes');
  end if;
  -- Al perfil de la sesión (invitado = sin perfil, con datos de contacto).
  if not public.es_admin() then
    p_perfil := public.mi_perfil_id();
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'El carrito está vacío.' using errcode = 'P0001';
  end if;

  insert into public.pedidos (perfil_id, estado, total, contacto, notas)
  values (p_perfil, 'pendiente', 0, coalesce(p_contacto, '{}'::jsonb), 'Pago en efectivo al recoger')
  returning id into v_pedido;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_talla := trim(coalesce(v_item ->> 'talla', ''));
    v_cant  := greatest(1, least(10, coalesce((v_item ->> 'cantidad')::int, 1)));
    select * into v_prod from public.productos
      where id = (v_item ->> 'producto_id')::uuid and activo;
    if not found then
      raise exception 'Uno de los productos ya no está disponible.' using errcode = 'P0001';
    end if;
    if v_prod.precio is null or v_prod.precio <= 0 then
      raise exception 'Un producto no tiene precio.' using errcode = 'P0001';
    end if;
    if v_prod.tallas_disponibles is not null and array_length(v_prod.tallas_disponibles, 1) > 0 then
      if v_talla = '' or not (v_talla = any(v_prod.tallas_disponibles)) then
        raise exception 'Talla no válida para %.', v_prod.nombre using errcode = 'P0001';
      end if;
      if v_prod.tallas_agotadas is not null and v_talla = any(v_prod.tallas_agotadas) then
        raise exception '% en talla % está agotado.', v_prod.nombre, v_talla using errcode = 'P0001';
      end if;
    else
      v_talla := nullif(v_talla, '');
    end if;
    insert into public.pedido_items (pedido_id, producto_id, talla, cantidad, precio_unitario)
    values (v_pedido, v_prod.id, v_talla, v_cant, v_prod.precio);
    v_n := v_n + v_cant;
  end loop;

  select total into v_total from public.pedidos where id = v_pedido;   -- lo fija el trigger
  return jsonb_build_object('ok', true, 'pedido_id', v_pedido, 'total', coalesce(v_total,0), 'n', v_n);
end;
$function$;

-- ---------- 6 · Políticas de usuarios con sesión: TO authenticated ----------
alter policy "escuela pasa lista a sus ninos"        on public.asistencia       to authenticated;
alter policy "escuela reparte a sus ninos"           on public.atleta_grupos    to authenticated;
alter policy "escuela borra a sus ninos"             on public.atletas          to authenticated;
alter policy "escuela corrige a sus ninos"           on public.atletas          to authenticated;
alter policy "escuela da de alta a un nino"          on public.atletas          to authenticated;
alter policy "escuela ve a sus ninos"                on public.atletas          to authenticated;
alter policy "escuela ve las faltas de sus ninos"    on public.ausencias        to authenticated;
alter policy "atleta y su entrenador leen bienestar" on public.bienestar_diario to authenticated;
alter policy "el atleta corrige su bienestar"        on public.bienestar_diario to authenticated;
alter policy "el atleta escribe su bienestar"        on public.bienestar_diario to authenticated;
alter policy "escuela gestiona sus horarios"         on public.grupo_horarios   to authenticated;
alter policy "escuela gestiona sus grupos"           on public.grupos           to authenticated;
alter policy "natacion_lista lectura"                on public.natacion_lista   to authenticated;
alter policy "el atleta apunta lo suyo"              on public.sesiones         to authenticated;
alter policy "el atleta corrige lo suyo"             on public.sesiones         to authenticated;

-- ---------- 7 · Políticas viejas / duplicadas de admin ----------
-- Candado: en cada tabla tiene que seguir «admin gestiona todo» = ALL,
-- TO authenticated, es_admin() en USING y en WITH CHECK.
do $$
declare t text; ok boolean;
begin
  foreach t in array array['pagos','pedidos','productos','eventos','noticias',
                           'contenido_secciones','perfiles','solicitudes_inscripcion'] loop
    select exists (
      select 1 from pg_policies
       where schemaname = 'public' and tablename = t
         and policyname = 'admin gestiona todo'
         and cmd = 'ALL' and permissive = 'PERMISSIVE'
         and roles = '{authenticated}'
         and replace(replace(qual, '( SELECT es_admin() AS es_admin)', 'es_admin()'), ' ', '') = 'es_admin()'
         and replace(replace(with_check, '( SELECT es_admin() AS es_admin)', 'es_admin()'), ' ', '') = 'es_admin()'
    ) into ok;
    if not ok then
      raise exception '386: en % no está «admin gestiona todo» con es_admin(); no se borra nada', t;
    end if;
  end loop;
end $$;

drop policy if exists "Admin acceso total - pagos"     on public.pagos;
drop policy if exists "Admin acceso total - pedidos"   on public.pedidos;
drop policy if exists "Admin acceso total - productos" on public.productos;
drop policy if exists "Admin acceso total - eventos"   on public.eventos;

drop policy if exists "admin gestiona" on public.noticias;
drop policy if exists "admin gestiona" on public.productos;
drop policy if exists "admin gestiona" on public.eventos;
drop policy if exists "admin gestiona" on public.contenido_secciones;

drop policy if exists "admin_gestiona_perfiles"    on public.perfiles;
drop policy if exists "admin gestiona solicitudes" on public.solicitudes_inscripcion;

-- ---------- 8 · Índices ----------
-- Duplicados: cada uno tiene un UNIQUE con las mismas columnas (solo cambia
-- el orden ASC/DESC de la última, que un btree recorre en los dos sentidos).
drop index if exists public.idx_rm_atleta_ejercicio;     -- = rm_atleta_unico_por_dia (atleta_id, lower(btrim(ejercicio)), fecha_test)
drop index if exists public.ix_bienestar_atleta_fecha;   -- = bienestar_diario_atleta_id_fecha_key (atleta_id, fecha)
drop index if exists public.idx_cuotas_entreno_token;    -- = cuotas_entreno_token_key (token)

-- Claves foráneas sin índice que se usan en reglas de acceso y joins.
create index if not exists idx_grupos_entrenador_id          on public.grupos (entrenador_id);
create index if not exists idx_natacion_accesos_atleta_id    on public.natacion_accesos (atleta_id);
create index if not exists idx_natacion_reservas_acceso_id   on public.natacion_reservas (acceso_id);
create index if not exists idx_mensajes_directos_atleta_id   on public.mensajes_directos (atleta_id);

-- ---------- 5 · Privilegios por defecto (al final: no toca lo existente) ----------
alter default privileges for role postgres in schema public revoke execute on functions from public;
alter default privileges for role postgres in schema public grant  execute on functions to authenticated, service_role;

commit;
