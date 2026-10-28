-- 465 · Natación: la ROPA la gestiona también Loren (stock, entregas, pagos y precios)
-- ---------------------------------------------------------------------------
-- Mario (28-oct-2026): «tengo un pedido de bañadores recibido por albarán y
-- quiero controlar entregas, pagos, tallas que quedan… si sobran tallas, que
-- puedan adquirirlas por la tienda». Andrés: Loren (J. Lorenzo Martos) gestiona
-- la ropa de la Escuela y del Máster con Mario: pedidos, entregas, stock y
-- precios. NO es un mundo nuevo: va dentro de Natación y de Escuela de natación.
--
--   · Permiso nuevo `natacion_ropa_puede()`: admin, gestores de natación
--     (como antes) o quien tenga la sección 'ropa-natacion' en
--     responsable_seccion (Loren). Las RPC del pedido de equipación (mig 436)
--     pasan a usarlo: Loren ve y mueve los pedidos de las familias.
--   · `mis_mundos()`: 'ropa-natacion' abre Natación y Escuela de natación y
--     añade la marca 'solo-ropa' si no tiene más natación: la barra le enseña
--     solo las pantallas de ropa (assets/js/mundos.js).
--   · Tabla `natacion_ropa_stock`: lo que ha llegado por albarán (una fila por
--     artículo/talla/persona, con cantidad), a quién va, si ha pagado y si se le
--     ha entregado. Lo que está LIBRE (sin persona ni familia) sale en el
--     formulario de equipación como «ya disponible» y su talla se añade a las
--     del artículo para que se pueda pedir.
--   · Catálogo: Loren y Mario cambian precio, tallas y si sale en el
--     formulario de los artículos de natación (seccion = 'natacion'). Los del
--     club (parka, mochila) se ven pero su precio es el de la tienda.
--   · Datos: el albarán P 2026-91 de Mad Wave (13-jul) leído de la hoja de
--     Loren; lo dudoso va marcado «revisar» con la nota. Catálogo Joma de
--     SNSport APAGADO (precio de la hoja + 7 % redondeado, por si se factura
--     por Ítaka) hasta que Mario/Loren lo den por bueno.
-- ---------------------------------------------------------------------------
begin;

-- ---------- permiso ----------
create or replace function public.natacion_ropa_puede()
returns boolean
language sql stable security definer
set search_path to 'public'
as $$
  select public.es_admin() or exists (
    select 1
      from public.responsable_seccion rs
      join public.perfiles p on p.id = rs.perfil_id
     where p.email = (auth.jwt() ->> 'email')
       and coalesce(p.activo, true)
       and ((rs.seccion in ('natacion', 'escuela-natacion') and coalesce(rs.gestor, true))
            or rs.seccion = 'ropa-natacion')
  );
$$;
revoke all on function public.natacion_ropa_puede() from public, anon;
grant execute on function public.natacion_ropa_puede() to authenticated, service_role;

-- Las RPC del pedido de equipación (436/443/445) con el permiso de ropa.
do $$
declare f text; d text;
begin
  foreach f in array array['natacion_equip_listar', 'natacion_equip_nuevo_set', 'natacion_equip_estado_set', 'natacion_equip_preparar']
  loop
    select pg_get_functiondef(p.oid) into d from pg_proc p where p.proname = f and p.pronamespace = 'public'::regnamespace;
    if d is null or position('natacion_cuotas_puede()' in d) = 0 then raise exception 'No encuentro el permiso en %', f; end if;
    d := replace(d, 'natacion_cuotas_puede()', 'natacion_ropa_puede()');
    d := replace(d, 'Solo quien lleva la natación.', 'Solo quien lleva la natación o su ropa.');
    execute d;
  end loop;
end $$;
alter policy "equip textos gestor" on public.natacion_equip_textos
  using ((select public.natacion_ropa_puede())) with check ((select public.natacion_ropa_puede()));

-- ---------- mundos: la ropa abre Natación y Escuela de natación ----------
create or replace function public.mis_mundos()
 returns text[]
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select case
    when public.es_admin() or public.soy_admin_de_verdad()
      then array['general','natacion','escuela-nat','cubo','pista','academia','escuela-atl','running','comunicacion']
    else coalesce((
      select array_agg(distinct w order by w)
      from (
        select case sec
          when 'natacion'          then 'natacion'
          when 'escuela-natacion'  then 'escuela-nat'
          when 'cubo'              then 'cubo'
          when 'pista'             then 'pista'
          when 'competicion'       then 'pista'
          when 'escuela'           then 'escuela-atl'
          when 'escuela-atletismo' then 'escuela-atl'
          when 'running'           then 'running'
          when 'comunicacion'      then 'comunicacion'
          else null
        end as w
        from public.mis_secciones_responsable() as sec
        union
        -- (mig 465) la ropa de natación entra por los dos mundos de natación…
        select unnest(array['natacion', 'escuela-nat']) where 'ropa-natacion' in (select public.mis_secciones_responsable())
        union
        -- …y si no lleva nada más de natación, la barra le enseña solo la ropa.
        select 'solo-ropa' where 'ropa-natacion' in (select public.mis_secciones_responsable())
                             and not exists (select 1 from public.mis_secciones_responsable() s where s in ('natacion', 'escuela-natacion'))
        union
        -- (mig 462) el entrenador de un grupo de Academia ve su mundo
        select 'academia' where exists (select 1 from public.academia_grupos ag join public.grupos g on g.id = ag.grupo_id
                                         where g.entrenador_id = public.mi_perfil_id())
      ) m
      where w is not null
    ), '{}'::text[])
  end
$function$;

-- ---------- stock ----------
create table if not exists public.natacion_ropa_stock (
  id           uuid primary key default gen_random_uuid(),
  lote         text not null,                       -- «Albarán P 2026-91 · Mad Wave»
  producto_id  uuid references public.productos(id) on delete set null,
  articulo     text not null,
  talla        text,
  cantidad     integer not null default 1 check (cantidad between 1 and 500),
  coste        numeric(8,2),                        -- lo que costó cada unidad (IVA incl.)
  precio       numeric(8,2),                        -- lo que paga quien se lo lleva
  persona      text,                                -- a quién va (texto libre)
  familia_id   uuid references public.natacion_equip_familias(id) on delete set null,  -- reservado a un pedido del formulario
  pagado_en    date,
  pago_metodo  text check (pago_metodo in ('efectivo', 'tarjeta', 'transferencia', 'bizum', 'regalo')),
  entregado_en date,
  nota         text,
  revisar      boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists natacion_ropa_stock_producto on public.natacion_ropa_stock (producto_id, talla);
alter table public.natacion_ropa_stock enable row level security;
revoke all on public.natacion_ropa_stock from anon, authenticated;
comment on table public.natacion_ropa_stock is '465 · Ropa de natación recibida (albaranes): a quién va, pagado y entregado. Libre = sin persona ni familia (sale en el formulario de equipación). Solo por RPC.';

-- Orden de tallas para enseñarlas.
create or replace function public._natacion_ropa_orden_talla(p text) returns int
language sql immutable as $$
  select coalesce(array_position(array['4','6','8','10','12','14','XXS','XS','S','M','L','XL','XXL','3XL','4XL','5XL','ÚNICA'], upper(coalesce(p, ''))), 99)
$$;

-- Las tallas que quedan libres se añaden a las del artículo (para poder pedirlas en el formulario). Nunca quita.
create or replace function public._natacion_ropa_tallas_sync()
returns void
language sql security definer
set search_path to 'public'
as $$
  update public.productos pr
     set tallas_disponibles = (select array_agg(t order by public._natacion_ropa_orden_talla(t), t)
                                 from (select unnest(coalesce(pr.tallas_disponibles, '{}')) as t
                                       union
                                       select s.talla from public.natacion_ropa_stock s
                                        where s.producto_id = pr.id and s.talla is not null and s.talla <> ''
                                          and s.persona is null and s.familia_id is null) x)
   where exists (select 1 from public.natacion_ropa_stock s
                  where s.producto_id = pr.id and s.talla is not null and s.talla <> ''
                    and s.persona is null and s.familia_id is null
                    and not (s.talla = any (coalesce(pr.tallas_disponibles, '{}'))));
$$;
revoke all on function public._natacion_ropa_tallas_sync() from public, anon, authenticated;

create or replace function public.natacion_ropa_stock_listar()
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $$
begin
  if not public.natacion_ropa_puede() then raise exception 'Solo quien lleva la ropa de natación.' using errcode = '42501'; end if;
  return jsonb_build_object(
    'stock', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'lote', s.lote, 'producto_id', s.producto_id, 'producto', pr.nombre, 'articulo', s.articulo, 'talla', s.talla,
        'cantidad', s.cantidad, 'coste', s.coste, 'precio', s.precio, 'persona', s.persona,
        'familia_id', s.familia_id, 'familia', f.contacto, 'familia_estado', f.estado,
        'familia_pagado', coalesce(p.estado = 'pagado', false) or f.estado in ('pagado', 'entregado'),
        'pagado_en', s.pagado_en, 'pago_metodo', s.pago_metodo, 'entregado_en', s.entregado_en,
        'nota', s.nota, 'revisar', s.revisar, 'created_at', s.created_at)
        order by s.lote, s.articulo, public._natacion_ropa_orden_talla(s.talla), s.persona nulls last)
        from public.natacion_ropa_stock s
        left join public.productos pr on pr.id = s.producto_id
        left join public.natacion_equip_familias f on f.id = s.familia_id
        left join public.pagos p on p.id = f.pago_id), '[]'),
    -- Pedidos del formulario que se podrían servir con lo que está libre (mismo artículo y talla).
    'pedidos', coalesce((
      select jsonb_agg(jsonb_build_object('familia_id', f.id, 'familia', f.contacto, 'nadador', n.nombre,
                                          'producto_id', l.producto_id, 'talla', l.talla, 'cantidad', l.cantidad))
        from public.natacion_equip_lineas l
        join public.natacion_equip_familias f on f.id = l.familia_id
        left join public.natacion_equip_nadadores n on n.id = l.nadador_id
       where l.articulo = 'producto' and f.email not like 'prueba-%'
         and exists (select 1 from public.natacion_ropa_stock s where s.producto_id = l.producto_id and s.talla = l.talla
                        and s.persona is null and s.familia_id is null)), '[]'),
    'productos', coalesce((
      select jsonb_agg(jsonb_build_object('id', pr.id, 'nombre', pr.nombre, 'precio', pr.precio, 'tallas', pr.tallas_disponibles)
                       order by coalesce(pr.categoria, '') = 'banador' desc, pr.orden nulls last, pr.nombre)
        from public.productos pr where pr.equipacion_natacion or pr.seccion = 'natacion'), '[]'));
end;
$$;
revoke all on function public.natacion_ropa_stock_listar() from public, anon;
grant execute on function public.natacion_ropa_stock_listar() to authenticated, service_role;

-- Alta o cambio de una fila. p_id null = alta. Con p_datos.separar = n (menor que la
-- cantidad) se separan n unidades en una fila nueva y los cambios van a esa fila.
-- Campos: lote, producto_id, articulo, talla, cantidad, coste, precio, persona,
-- familia_id, pagado (bool) + pago_metodo, entregado (bool), nota, revisar, libre (bool).
create or replace function public.natacion_ropa_stock_guardar(p_id uuid, p_datos jsonb)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v public.natacion_ropa_stock%rowtype; v_id uuid; v_sep int; d jsonb := coalesce(p_datos, '{}');
begin
  if not public.natacion_ropa_puede() then raise exception 'Solo quien lleva la ropa de natación.' using errcode = '42501'; end if;

  if p_id is null then
    if nullif(btrim(coalesce(d ->> 'articulo', '')), '') is null and nullif(d ->> 'producto_id', '') is null then
      raise exception 'Falta el artículo.' using errcode = 'P0001';
    end if;
    insert into public.natacion_ropa_stock (lote, producto_id, articulo, talla, cantidad, coste, precio)
    values (coalesce(nullif(btrim(d ->> 'lote'), ''), 'Sin albarán'),
            nullif(d ->> 'producto_id', '')::uuid,
            coalesce(nullif(btrim(d ->> 'articulo'), ''), (select nombre from public.productos where id = nullif(d ->> 'producto_id', '')::uuid)),
            nullif(upper(btrim(coalesce(d ->> 'talla', ''))), ''),
            greatest(1, coalesce((d ->> 'cantidad')::int, 1)),
            nullif(d ->> 'coste', '')::numeric,
            coalesce(nullif(d ->> 'precio', '')::numeric, (select precio from public.productos where id = nullif(d ->> 'producto_id', '')::uuid)))
    returning id into v_id;
  else
    select * into v from public.natacion_ropa_stock where id = p_id for update;
    if not found then raise exception 'No encuentro esa fila.' using errcode = 'P0001'; end if;
    v_id := v.id;
    v_sep := nullif(d ->> 'separar', '')::int;
    if v_sep is not null and v_sep >= 1 and v_sep < v.cantidad then
      update public.natacion_ropa_stock set cantidad = cantidad - v_sep, updated_at = now() where id = v.id;
      insert into public.natacion_ropa_stock (lote, producto_id, articulo, talla, cantidad, coste, precio, nota)
      values (v.lote, v.producto_id, v.articulo, v.talla, v_sep, v.coste, v.precio, null)
      returning id into v_id;
    end if;
  end if;

  update public.natacion_ropa_stock s set
    lote        = case when d ? 'lote' then coalesce(nullif(btrim(d ->> 'lote'), ''), s.lote) else s.lote end,
    articulo    = case when d ? 'articulo' then coalesce(nullif(btrim(d ->> 'articulo'), ''), s.articulo) else s.articulo end,
    producto_id = case when d ? 'producto_id' then nullif(d ->> 'producto_id', '')::uuid else s.producto_id end,
    talla       = case when d ? 'talla' then nullif(upper(btrim(coalesce(d ->> 'talla', ''))), '') else s.talla end,
    cantidad    = case when d ? 'cantidad' and p_id is not null and (d ->> 'separar') is null then greatest(1, (d ->> 'cantidad')::int) else s.cantidad end,
    coste       = case when d ? 'coste' then nullif(d ->> 'coste', '')::numeric else s.coste end,
    precio      = case when d ? 'precio' then nullif(d ->> 'precio', '')::numeric else s.precio end,
    persona     = case when coalesce((d ->> 'libre')::boolean, false) then null
                       when d ? 'persona' then nullif(btrim(d ->> 'persona'), '') else s.persona end,
    familia_id  = case when coalesce((d ->> 'libre')::boolean, false) then null
                       when d ? 'familia_id' then nullif(d ->> 'familia_id', '')::uuid else s.familia_id end,
    pagado_en   = case when d ? 'pagado' then case when (d ->> 'pagado')::boolean then coalesce(s.pagado_en, (now() at time zone 'Europe/Madrid')::date) end
                       when coalesce((d ->> 'libre')::boolean, false) then null else s.pagado_en end,
    pago_metodo = case when d ? 'pagado' then case when (d ->> 'pagado')::boolean then coalesce(nullif(d ->> 'pago_metodo', ''), s.pago_metodo) end
                       when coalesce((d ->> 'libre')::boolean, false) then null else s.pago_metodo end,
    entregado_en = case when d ? 'entregado' then case when (d ->> 'entregado')::boolean then coalesce(s.entregado_en, (now() at time zone 'Europe/Madrid')::date) end
                        when coalesce((d ->> 'libre')::boolean, false) then null else s.entregado_en end,
    nota        = case when d ? 'nota' then nullif(btrim(d ->> 'nota'), '') else s.nota end,
    revisar     = case when d ? 'revisar' then coalesce((d ->> 'revisar')::boolean, false) else s.revisar end,
    updated_at  = now()
   where s.id = v_id;

  perform public._natacion_ropa_tallas_sync();
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;
revoke all on function public.natacion_ropa_stock_guardar(uuid, jsonb) from public, anon;
grant execute on function public.natacion_ropa_stock_guardar(uuid, jsonb) to authenticated, service_role;

create or replace function public.natacion_ropa_stock_borrar(p_id uuid)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
begin
  if not public.natacion_ropa_puede() then raise exception 'Solo quien lleva la ropa de natación.' using errcode = '42501'; end if;
  delete from public.natacion_ropa_stock where id = p_id;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.natacion_ropa_stock_borrar(uuid) from public, anon;
grant execute on function public.natacion_ropa_stock_borrar(uuid) to authenticated, service_role;

-- ---------- catálogo y precios ----------
create or replace function public.natacion_ropa_productos()
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $$
begin
  if not public.natacion_ropa_puede() then raise exception 'Solo quien lleva la ropa de natación.' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', pr.id, 'nombre', pr.nombre, 'descripcion', pr.descripcion, 'precio', pr.precio,
                                        'categoria', pr.categoria, 'tallas', pr.tallas_disponibles, 'imagen', pr.imagen_url,
                                        'activo', pr.activo, 'formulario', pr.equipacion_natacion, 'seccion', pr.seccion,
                                        'editable', pr.seccion = 'natacion')
                     order by pr.seccion <> 'natacion', coalesce(pr.categoria, '') = 'banador' desc, pr.orden nulls last, pr.nombre)
      from public.productos pr
     where pr.seccion = 'natacion' or pr.equipacion_natacion), '[]');
end;
$$;
revoke all on function public.natacion_ropa_productos() from public, anon;
grant execute on function public.natacion_ropa_productos() to authenticated, service_role;

-- Solo los artículos de natación (seccion = 'natacion'): los del club llevan el precio de la tienda.
-- p_datos: nombre, descripcion, precio, tallas (array de texto), activo (en el formulario).
create or replace function public.natacion_ropa_producto_guardar(p_id uuid, p_datos jsonb)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare d jsonb := coalesce(p_datos, '{}'); v_t text[];
begin
  if not public.natacion_ropa_puede() then raise exception 'Solo quien lleva la ropa de natación.' using errcode = '42501'; end if;
  if not exists (select 1 from public.productos where id = p_id and seccion = 'natacion') then
    raise exception 'Ese artículo es de la tienda del club: su precio se cambia allí.' using errcode = 'P0001';
  end if;
  if d ? 'precio' and (nullif(d ->> 'precio', '') is null or (d ->> 'precio')::numeric < 0 or (d ->> 'precio')::numeric > 999) then
    raise exception 'Precio no válido.' using errcode = 'P0001';
  end if;
  if d ? 'tallas' then
    select coalesce(array_agg(t order by public._natacion_ropa_orden_talla(t), t), '{}') into v_t
      from (select distinct nullif(upper(btrim(x)), '') as t from jsonb_array_elements_text(d -> 'tallas') x) y where t is not null;
  end if;
  update public.productos set
    nombre             = case when d ? 'nombre' and nullif(btrim(d ->> 'nombre'), '') is not null then btrim(d ->> 'nombre') else nombre end,
    descripcion        = case when d ? 'descripcion' then nullif(btrim(d ->> 'descripcion'), '') else descripcion end,
    precio             = case when d ? 'precio' then round((d ->> 'precio')::numeric, 2) else precio end,
    tallas_disponibles = case when d ? 'tallas' then v_t else tallas_disponibles end,
    activo             = case when d ? 'activo' then coalesce((d ->> 'activo')::boolean, activo) else activo end,
    equipacion_natacion = true
   where id = p_id;
  perform public._natacion_ropa_tallas_sync();
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.natacion_ropa_producto_guardar(uuid, jsonb) from public, anon;
grant execute on function public.natacion_ropa_producto_guardar(uuid, jsonb) to authenticated, service_role;

-- ---------- formulario: lo que ya está disponible ----------
do $$
declare d text;
begin
  select pg_get_functiondef('public.natacion_equip_publica(text)'::regprocedure) into d;
  if position('''banador'', coalesce(pr.categoria, '''') = ''banador'')' in d) = 0 then raise exception 'natacion_equip_publica ha cambiado'; end if;
  d := replace(d, '''banador'', coalesce(pr.categoria, '''') = ''banador'')',
    '''banador'', coalesce(pr.categoria, '''') = ''banador'',
                                                                ''en_stock'', coalesce((select jsonb_agg(distinct s.talla) from public.natacion_ropa_stock s
                                                                                         where s.producto_id = pr.id and s.talla is not null
                                                                                           and s.persona is null and s.familia_id is null), ''[]''))');
  execute d;
end $$;

insert into public.salud_rpc_front (nombre, en_publica) values
  ('natacion_ropa_puede', false), ('natacion_ropa_stock_listar', false), ('natacion_ropa_stock_guardar', false),
  ('natacion_ropa_stock_borrar', false), ('natacion_ropa_productos', false), ('natacion_ropa_producto_guardar', false)
on conflict (nombre) do nothing;

-- ---------- datos: albarán P 2026-91 (Mad Wave, 13-jul-2026) ----------
-- Coste = precio del albarán + 21 % IVA. Personas leídas de la hoja de Loren
-- (en rojo = cambios posteriores; tachado = ya no). «P» se lee como «pagado»
-- pero NO se marca: lo confirma Loren.
insert into public.natacion_ropa_stock (lote, producto_id, articulo, talla, cantidad, coste, precio, persona, nota, revisar)
select 'Albarán P 2026-91 · Mad Wave', (select id from public.productos where nombre = x.prod), x.art, x.talla, x.cant, x.coste, x.precio, x.persona, x.nota, x.revisar
  from (values
    ('Bañador jammer', 'Jammer', 'S', 1, 40.73, 41.00, 'Javier Vidal', 'En la hoja, S tiene 2 unidades y 3 nombres: Javier Vidal, Mario Clavero y Andrés Macías (en rojo, «41 € P»). ¿Quién se queda cada una?', true),
    ('Bañador jammer', 'Jammer', 'S', 1, 40.73, 41.00, 'Mario Clavero', 'Ver la otra S: Andrés Macías también aparece aquí.', true),
    ('Bañador jammer', 'Jammer', 'M', 1, 40.73, 41.00, 'Pascual Pastor', null, false),
    ('Bañador jammer', 'Jammer', 'XL', 1, 40.73, 41.00, null, 'Era de Dylan Santiago (baja).', false),
    ('Bañador niña tirante fino', 'Tirante fino (TFDS)', 'S', 1, 39.69, 40.00, 'Nuria Sahagún', null, false),
    ('Bañador niña tirante fino', 'Tirante fino (TFDS)', 'S', 1, 39.69, 40.00, null, 'Era de «¿Carolina?» (tachado en la hoja).', false),
    ('Bañador niña tirante fino', 'Tirante fino (TFDS)', 'M', 1, 39.69, 40.00, 'Lidia Sánchez', null, false),
    ('Bañador niña tirante fino', 'Tirante fino (TFDS)', 'M', 1, 39.69, 40.00, 'Angela Ubach', null, false),
    ('Bañador niña tirante fino', 'Tirante fino (TFDS)', 'M', 1, 39.69, 40.00, 'Cristina Dolera', 'Carolina López aparecía también en M, tachada.', false),
    ('Bañador niña tirante fino', 'Tirante fino (TFDS)', 'L', 1, 39.69, 40.00, 'María Alejandra Aranda', null, false),
    ('Bikini', 'Bikini (BIQ)', 'S', 1, 39.69, 40.00, 'Maribel García', null, false),
    ('Bañador niña tirante ancho', 'Tirante ancho (TADSN)', 'M', 1, 39.69, 40.00, 'Elena Nogueroles', 'En la hoja tenía «40 € P» y está tachado: ¿ha pagado?', true),
    ('Bañador niña tirante ancho', 'Tirante ancho (TADSN)', 'L', 1, 39.69, 40.00, 'Cristina Juan', 'Antes era de Cristina Marucho (tachada). El apellido está incompleto en la hoja («Cristina Juan de…»).', true),
    ('Bañador niña tirante ancho', 'Tirante ancho (TADSN)', 'XL', 1, 39.69, 40.00, 'Ana Santos', null, false),
    ('Bañador niño (slip)', 'Slip (SM)', null, 1, 27.70, 29.00, null, 'El albarán trae 1 slip. En la hoja: M para Marcin Lyp (tachado, «29 € P») y XL para Pedro Garcinuño / Fernando Rodríguez (en rojo, «29 € P»). Falta la talla y de quién es.', true),
    (null, 'Gorro de silicona Mad Wave (2 colores)', null, 60, 6.41, null, null, 'Albarán: 2 colores, misma pantalla por lado. ¿Son para la equipación o se venden?', true),
    (null, 'Softshell Mad Wave', 'M', 1, 45.00, null, 'Mario', 'En la hoja: «Sudadera M · Mario».', false)
  ) as x(prod, art, talla, cant, coste, precio, persona, nota, revisar)
 where not exists (select 1 from public.natacion_ropa_stock where lote = 'Albarán P 2026-91 · Mad Wave');

select public._natacion_ropa_tallas_sync();

-- ---------- catálogo Joma (SNSport, Loren): APAGADO hasta que lo den por bueno ----------
-- Precio = el de la hoja de SNSport + 7 % (facturación por Ítaka), redondeado al euro.
-- Los cortos .331 (marino) no traen precio en la hoja: el mismo que el .700.
insert into public.productos (nombre, descripcion, precio, categoria, tallas_disponibles, stock, activo, imagen_url, tallas_agotadas, orden, seccion, equipacion_natacion)
select x.nombre, x.descr, x.precio, 'ropa', x.tallas, 0, false, x.img, '{}', x.ord, 'natacion', true
  from (values
    ('Camiseta Joma · chico',         'Joma · ref. 102223.700 · SNSport 14,95 €', 16, '{XS,S,M,L,XL,XXL}'::text[], 'natacion-joma-camiseta-chico.jpg', 20),
    ('Camiseta Joma · chica',         'Joma · ref. 901398.700 · SNSport 14,95 €', 16, '{XS,S,M,L,XL}'::text[],     'natacion-joma-camiseta-chica.jpg', 21),
    ('Tirantes Joma · chico',         'Joma · ref. 102222.700 · SNSport 16,25 €', 17, '{XS,S,M,L,XL,XXL}'::text[], 'natacion-joma-tirantes-chico.jpg', 22),
    ('Tirantes Joma · chica',         'Joma · ref. 901396.700 · SNSport 16,25 €', 17, '{XS,S,M,L,XL}'::text[],     'natacion-joma-tirantes-chica.jpg', 23),
    ('Pantalón corto Joma · chico',   'Joma · ref. 100438 (.700 azul / .331 marino) · SNSport 14,75 €', 16, '{XS,S,M,L,XL,XXL}'::text[], 'natacion-joma-corto-chico.jpg', 24),
    ('Pantalón corto Joma · chica',   'Joma · ref. 900250 (.700 azul / .331 marino) · SNSport 11,75 €', 13, '{XS,S,M,L,XL}'::text[],     'natacion-joma-corto-chica.jpg', 25),
    ('Pantalón largo Joma',           'Joma · ref. 100761.331 · SNSport 19,00 €', 20, '{XS,S,M,L,XL,XXL}'::text[], 'natacion-joma-pantalon-largo.jpg', 26),
    ('Mallas largas Joma · chica',    'Joma · ref. 900447.300 · SNSport 24,95 €', 27, '{XS,S,M,L,XL}'::text[],     'natacion-joma-mallas-largas.jpg', 27),
    ('Mallas pirata Joma · chica',    'Joma · ref. 900448.300 · SNSport 18,75 €', 20, '{XS,S,M,L,XL}'::text[],     'natacion-joma-mallas-pirata.jpg', 28)
  ) as x(nombre, descr, precio, tallas, img, ord)
 where not exists (select 1 from public.productos p where p.nombre = x.nombre);

-- ---------- Loren: la ropa de natación ----------
insert into public.responsable_seccion (perfil_id, seccion, gestor)
select id, 'ropa-natacion', true from public.perfiles where lower(email) = 'lorenisa86@gmail.com'
on conflict (perfil_id, seccion) do nothing;

commit;
