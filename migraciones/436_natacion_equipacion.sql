-- 436 · Natación: pedido de EQUIPACIÓN 2026/27 (tienda oculta, un enlace por familia)
-- ---------------------------------------------------------------------------
-- Andrés/Mario (22-oct-2026). Cada familia de natación (agrupada por correo:
-- el del tutor en escuela, el propio en máster) recibe un enlace
-- /natacion/equipacion/?t=… donde, por cada nadador:
--   · camiseta oficial y gorro: GRATIS para todos (talla o «no lo necesito»);
--   · sudadera: GRATIS si es NUEVO; a las renovaciones también les sale, pero
--     a su precio (el de «Sudadera del club», 35 €) si la eligen;
--   · bañadores (de pago, con «me comprometo a la compra») y extras de la
--     tienda (productos con equipacion_natacion = true).
-- Al enviar ven «Tu cesta» con lo que pagarán CUANDO LLEGUE la ropa. Mario lo
-- marca «llegado» y se crea un RECIBO en `pagos` con enlace /pagar/?t=… (el de
-- la mig 431: se paga con tarjeta sin cuenta; el webhook lo deja pagado), o
-- paga en la oficina. Después «entregado».
-- «Nuevo» se propone con la fecha del alta en la app (después de la
-- importación de SportMember del 25-sep) y Mario lo corrige en su panel.
-- Todo por RPC SECURITY DEFINER: las tablas no se leen directamente.
-- ---------------------------------------------------------------------------
begin;

alter table public.productos add column if not exists equipacion_natacion boolean not null default false;
grant select (equipacion_natacion) on public.productos to anon, authenticated;
grant insert (equipacion_natacion), update (equipacion_natacion) on public.productos to authenticated;
comment on column public.productos.equipacion_natacion is '436 · Sale en el pedido de equipación de natación (bañadores y extras).';
update public.productos set equipacion_natacion = true
 where nombre in ('Mochila con zapatillero', 'Parka del club', 'Chaqueta de chándal');

create table if not exists public.natacion_equip_familias (
  id              uuid primary key default gen_random_uuid(),
  temporada       text not null default '2026/27',
  email           text not null,
  contacto        text,
  telefono        text,
  token           text not null unique,
  estado          text not null default 'pendiente'
                  check (estado in ('pendiente', 'pedido', 'llegado', 'pagado', 'entregado')),
  total           numeric(8,2) not null default 0,
  compromiso      boolean not null default false,
  pago_id         uuid references public.pagos(id) on delete set null,
  avisado_en      timestamptz,
  recordado_en    timestamptz,
  respondido_en   timestamptz,
  llegado_en      timestamptz,
  entregado_en    timestamptz,
  created_at      timestamptz not null default now(),
  unique (temporada, email)
);
create table if not exists public.natacion_equip_nadadores (
  id          uuid primary key default gen_random_uuid(),
  familia_id  uuid not null references public.natacion_equip_familias(id) on delete cascade,
  atleta_id   uuid references public.atletas(id) on delete set null,
  nombre      text not null,
  tipo        text,
  nuevo       boolean not null default false,
  unique (familia_id, atleta_id)
);
create table if not exists public.natacion_equip_lineas (
  id              uuid primary key default gen_random_uuid(),
  familia_id      uuid not null references public.natacion_equip_familias(id) on delete cascade,
  nadador_id      uuid references public.natacion_equip_nadadores(id) on delete cascade,
  articulo        text not null check (articulo in ('camiseta', 'gorro', 'sudadera', 'producto')),
  producto_id     uuid references public.productos(id) on delete set null,
  nombre          text not null,
  talla           text,
  cantidad        integer not null default 1 check (cantidad between 1 and 10),
  precio_unitario numeric(8,2) not null default 0
);
create index if not exists natacion_equip_lineas_familia on public.natacion_equip_lineas (familia_id);
alter table public.natacion_equip_familias  enable row level security;
alter table public.natacion_equip_nadadores enable row level security;
alter table public.natacion_equip_lineas    enable row level security;
revoke all on public.natacion_equip_familias, public.natacion_equip_nadadores, public.natacion_equip_lineas from anon, authenticated;

create or replace function public._natacion_equip_tallas() returns text[]
language sql immutable as $$ select array['4','6','8','10','12','14','XS','S','M','L','XL','XXL'] $$;

-- Familias y nadadores a partir de los accesos de natación activos. Idempotente:
-- si aparece un nadador nuevo, se añade a su familia (o se crea la familia).
create or replace function public.natacion_equip_preparar()
returns integer
language plpgsql security definer
set search_path to 'public'
as $$
declare v_n int := 0; r record; v_fam uuid;
begin
  if not (public.natacion_cuotas_puede() or coalesce(auth.role(), '') = 'service_role' or current_user = 'postgres') then
    raise exception 'Solo quien lleva la natación.' using errcode = '42501';
  end if;
  for r in
    select distinct on (a.id) a.id as atleta_id,
           btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')) as nombre,
           public._natacion_tipo_de(a.id) as tipo,
           (min(na.created_at) over (partition by a.id) > timestamptz '2026-09-26 00:00+02') as nuevo,
           lower(case when public._natacion_tipo_de(a.id) = 'Escuela'
                      then coalesce(nullif(btrim(a.email_tutor), ''), nullif(btrim(a.email), ''),
                                    (select nullif(btrim(pf.email), '') from public.perfiles pf where pf.id = coalesce(a.perfil_padre_id, a.perfil_id)))
                      else coalesce(nullif(btrim(a.email), ''), nullif(btrim(a.email_tutor), ''),
                                    (select nullif(btrim(pf.email), '') from public.perfiles pf where pf.id = coalesce(a.perfil_id, a.perfil_padre_id))) end) as email,
           case when public._natacion_tipo_de(a.id) = 'Escuela'
                then coalesce(nullif(btrim(a.nombre_tutor), ''), btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')))
                else btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, '')) end as contacto,
           case when public._natacion_tipo_de(a.id) = 'Escuela'
                then coalesce(nullif(btrim(a.telefono_tutor), ''), nullif(btrim(a.telefono), ''))
                else coalesce(nullif(btrim(a.telefono), ''), nullif(btrim(a.telefono_tutor), '')) end as telefono
      from public.natacion_accesos na
      join public.atletas a on a.id = na.atleta_id
     where na.activo and coalesce(a.estado, 'activo') <> 'baja' and a.anonimizado_en is null
       and coalesce(a.nombre, '') not like '%(duplicado)%'
     order by a.id
  loop
    continue when r.email is null;
    insert into public.natacion_equip_familias (email, contacto, telefono, token)
    values (r.email, r.contacto, r.telefono, replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''))
    on conflict (temporada, email) do nothing;
    select id into v_fam from public.natacion_equip_familias where temporada = '2026/27' and email = r.email;
    insert into public.natacion_equip_nadadores (familia_id, atleta_id, nombre, tipo, nuevo)
    values (v_fam, r.atleta_id, r.nombre, r.tipo, r.nuevo)
    on conflict (familia_id, atleta_id) do nothing;
    if found then v_n := v_n + 1; end if;
  end loop;
  return v_n;
end;
$$;
revoke all on function public.natacion_equip_preparar() from public, anon;
grant execute on function public.natacion_equip_preparar() to authenticated, service_role;

-- Precio de la sudadera para las renovaciones (el de la tienda, aunque no esté a la venta allí).
create or replace function public._natacion_equip_precio_sudadera() returns numeric
language sql stable security definer set search_path to 'public' as $$
  select coalesce((select precio from public.productos where nombre = 'Sudadera del club' limit 1), 35)
$$;

-- Lo que ve la familia con su enlace.
create or replace function public.natacion_equip_publica(p_token text)
returns jsonb
language sql stable security definer
set search_path to 'public'
as $$
  select jsonb_build_object(
    'contacto', initcap(lower(split_part(btrim(coalesce(f.contacto, '')), ' ', 1))),
    'estado', f.estado, 'total', f.total, 'compromiso', f.compromiso,
    'respondido', f.respondido_en is not null,
    'pago_enlace', case when p.token_pago is not null and p.estado <> 'pagado' and not p.anulado
                        then 'https://atletismoapolana.com/pagar/?t=' || p.token_pago end,
    'pagado', coalesce(p.estado = 'pagado', false) or f.estado in ('pagado', 'entregado'),
    'precio_sudadera', public._natacion_equip_precio_sudadera(),
    'tallas', to_jsonb(public._natacion_equip_tallas()),
    'nadadores', coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'nombre', initcap(lower(n.nombre)), 'tipo', n.tipo, 'nuevo', n.nuevo)
                                            order by n.nombre)
                             from public.natacion_equip_nadadores n where n.familia_id = f.id), '[]'),
    'lineas', coalesce((select jsonb_agg(jsonb_build_object('nadador_id', l.nadador_id, 'articulo', l.articulo, 'producto_id', l.producto_id,
                                                             'nombre', l.nombre, 'talla', l.talla, 'cantidad', l.cantidad, 'precio', l.precio_unitario))
                          from public.natacion_equip_lineas l where l.familia_id = f.id), '[]'),
    'productos', coalesce((select jsonb_agg(jsonb_build_object('id', pr.id, 'nombre', pr.nombre, 'precio', pr.precio,
                                                                'tallas', pr.tallas_disponibles, 'imagen', pr.imagen_url,
                                                                'banador', coalesce(pr.categoria, '') = 'banador')
                                             order by coalesce(pr.categoria, '') = 'banador' desc, pr.orden nulls last, pr.nombre)
                             from public.productos pr where pr.equipacion_natacion and pr.activo), '[]'))
    from public.natacion_equip_familias f
    left join public.pagos p on p.id = f.pago_id
   where length(coalesce(p_token, '')) >= 40 and f.token = p_token
   limit 1;
$$;
revoke all on function public.natacion_equip_publica(text) from public;
grant execute on function public.natacion_equip_publica(text) to anon, authenticated, service_role;

-- Guardar lo que pide la familia (se puede cambiar hasta que Mario marque «llegado»).
-- p_datos = { nadadores: [{id, camiseta: 'M'|null, gorro: bool, sudadera: 'M'|null}],
--             extras: [{producto_id, talla, cantidad, nadador_id?}], compromiso: bool }
create or replace function public.natacion_equip_guardar(p_token text, p_datos jsonb)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_f public.natacion_equip_familias%rowtype;
  v_n public.natacion_equip_nadadores%rowtype;
  x jsonb; v_t text; v_pr public.productos%rowtype; v_cant int; v_hay_ban boolean := false; v_total numeric := 0;
  v_tallas text[] := public._natacion_equip_tallas();
begin
  select * into v_f from public.natacion_equip_familias where length(coalesce(p_token, '')) >= 40 and token = p_token for update;
  if not found then raise exception 'Este enlace no es válido.' using errcode = 'P0001'; end if;
  if v_f.estado not in ('pendiente', 'pedido') then
    raise exception 'El pedido ya se ha hecho y no se puede cambiar. Si necesitas algo, escríbenos.' using errcode = 'P0001';
  end if;

  delete from public.natacion_equip_lineas where familia_id = v_f.id;

  for x in select * from jsonb_array_elements(coalesce(p_datos -> 'nadadores', '[]'))
  loop
    select * into v_n from public.natacion_equip_nadadores where id = (x ->> 'id')::uuid and familia_id = v_f.id;
    continue when not found;
    v_t := nullif(btrim(coalesce(x ->> 'camiseta', '')), '');
    if v_t is not null then
      if not (v_t = any(v_tallas)) then raise exception 'Talla de camiseta no válida.' using errcode = 'P0001'; end if;
      insert into public.natacion_equip_lineas (familia_id, nadador_id, articulo, nombre, talla, precio_unitario)
      values (v_f.id, v_n.id, 'camiseta', 'Camiseta oficial del club', v_t, 0);
    end if;
    if coalesce((x ->> 'gorro')::boolean, false) then
      insert into public.natacion_equip_lineas (familia_id, nadador_id, articulo, nombre, talla, precio_unitario)
      values (v_f.id, v_n.id, 'gorro', 'Gorro de natación', null, 0);
    end if;
    v_t := nullif(btrim(coalesce(x ->> 'sudadera', '')), '');
    if v_t is not null then
      if not (v_t = any(v_tallas)) then raise exception 'Talla de sudadera no válida.' using errcode = 'P0001'; end if;
      insert into public.natacion_equip_lineas (familia_id, nadador_id, articulo, nombre, talla, precio_unitario)
      values (v_f.id, v_n.id, 'sudadera', 'Chaqueta del club', v_t,
              case when v_n.nuevo then 0 else public._natacion_equip_precio_sudadera() end);
    end if;
  end loop;

  for x in select * from jsonb_array_elements(coalesce(p_datos -> 'extras', '[]'))
  loop
    select * into v_pr from public.productos where id = (x ->> 'producto_id')::uuid and equipacion_natacion and activo;
    if not found then raise exception 'Uno de los artículos ya no está disponible. Recarga la página.' using errcode = 'P0001'; end if;
    v_t := nullif(btrim(coalesce(x ->> 'talla', '')), '');
    if coalesce(array_length(v_pr.tallas_disponibles, 1), 0) > 0 and not (coalesce(v_t, '') = any(v_pr.tallas_disponibles)) then
      raise exception 'Talla no válida para %.', v_pr.nombre using errcode = 'P0001';
    end if;
    v_cant := greatest(1, least(10, coalesce((x ->> 'cantidad')::int, 1)));
    if coalesce(v_pr.categoria, '') = 'banador' then v_hay_ban := true; end if;
    insert into public.natacion_equip_lineas (familia_id, nadador_id, articulo, producto_id, nombre, talla, cantidad, precio_unitario)
    values (v_f.id,
            (select n.id from public.natacion_equip_nadadores n where n.id = nullif(x ->> 'nadador_id', '')::uuid and n.familia_id = v_f.id),
            'producto', v_pr.id, v_pr.nombre, v_t, v_cant, coalesce(v_pr.precio, 0));
  end loop;

  if v_hay_ban and not coalesce((p_datos ->> 'compromiso')::boolean, false) then
    raise exception 'Para encargar bañadores hay que marcar el compromiso de compra.' using errcode = 'P0001';
  end if;

  select coalesce(sum(cantidad * precio_unitario), 0) into v_total from public.natacion_equip_lineas where familia_id = v_f.id;
  update public.natacion_equip_familias
     set estado = 'pedido', total = v_total, compromiso = coalesce((p_datos ->> 'compromiso')::boolean, false), respondido_en = now()
   where id = v_f.id;
  return jsonb_build_object('ok', true, 'total', v_total);
end;
$$;
revoke all on function public.natacion_equip_guardar(text, jsonb) from public;
grant execute on function public.natacion_equip_guardar(text, jsonb) to anon, authenticated, service_role;

-- Panel de Mario: todas las familias con sus nadadores y su cesta.
create or replace function public.natacion_equip_listar()
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $$
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación.' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', f.id, 'email', f.email, 'contacto', f.contacto, 'telefono', f.telefono, 'estado', f.estado, 'total', f.total,
      'enlace', 'https://atletismoapolana.com/natacion/equipacion/?t=' || f.token,
      'avisado_en', f.avisado_en, 'respondido_en', f.respondido_en, 'llegado_en', f.llegado_en, 'entregado_en', f.entregado_en,
      'pago_estado', p.estado, 'pago_enlace', case when p.token_pago is not null then 'https://atletismoapolana.com/pagar/?t=' || p.token_pago end,
      'nadadores', coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'nombre', n.nombre, 'tipo', n.tipo, 'nuevo', n.nuevo) order by n.nombre)
                               from public.natacion_equip_nadadores n where n.familia_id = f.id), '[]'),
      'lineas', coalesce((select jsonb_agg(jsonb_build_object('nadador_id', l.nadador_id, 'articulo', l.articulo, 'nombre', l.nombre,
                                                               'talla', l.talla, 'cantidad', l.cantidad, 'precio', l.precio_unitario))
                            from public.natacion_equip_lineas l where l.familia_id = f.id), '[]')
    ) order by lower(coalesce(f.contacto, f.email)))
      from public.natacion_equip_familias f
      left join public.pagos p on p.id = f.pago_id
     where f.temporada = '2026/27' and f.email not like 'prueba-%'), '[]');   -- la familia de prueba no sale
end;
$$;
revoke all on function public.natacion_equip_listar() from public, anon;
grant execute on function public.natacion_equip_listar() to authenticated, service_role;

-- Mario corrige si un nadador es nuevo (la sudadera cambia de precio si ya había pedido).
create or replace function public.natacion_equip_nuevo_set(p_nadador uuid, p_nuevo boolean)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v_fam uuid; v_total numeric;
begin
  if not public.natacion_cuotas_puede() then raise exception 'Solo quien lleva la natación.' using errcode = '42501'; end if;
  update public.natacion_equip_nadadores set nuevo = coalesce(p_nuevo, false) where id = p_nadador returning familia_id into v_fam;
  if v_fam is null then raise exception 'No encuentro ese nadador.'; end if;
  if exists (select 1 from public.natacion_equip_familias where id = v_fam and estado in ('pendiente', 'pedido')) then
    update public.natacion_equip_lineas set precio_unitario = case when p_nuevo then 0 else public._natacion_equip_precio_sudadera() end
     where nadador_id = p_nadador and articulo = 'sudadera';
    select coalesce(sum(cantidad * precio_unitario), 0) into v_total from public.natacion_equip_lineas where familia_id = v_fam;
    update public.natacion_equip_familias set total = v_total where id = v_fam;
  end if;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.natacion_equip_nuevo_set(uuid, boolean) from public, anon;
grant execute on function public.natacion_equip_nuevo_set(uuid, boolean) to authenticated, service_role;

-- Mario cambia el estado. «llegado» con algo que pagar crea el RECIBO con su
-- enlace de pago (/pagar/); «pagado» = pagado en la oficina; «entregado».
create or replace function public.natacion_equip_estado_set(p_familia uuid, p_estado text, p_metodo text default null)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v_f public.natacion_equip_familias%rowtype; v_tok text; v_pago uuid; v_atleta uuid; v_nombres text;
begin
  if not public.natacion_cuotas_puede() then raise exception 'Solo quien lleva la natación.' using errcode = '42501'; end if;
  if p_estado not in ('pedido', 'llegado', 'pagado', 'entregado') then raise exception 'Estado no válido.'; end if;
  select * into v_f from public.natacion_equip_familias where id = p_familia for update;
  if not found then raise exception 'No encuentro esa familia.'; end if;

  if p_estado = 'llegado' then
    if v_f.total > 0 and v_f.pago_id is null then
      select n.atleta_id, string_agg(split_part(n.nombre, ' ', 1), ', ' order by n.nombre)
        into v_atleta, v_nombres
        from public.natacion_equip_nadadores n where n.familia_id = v_f.id group by n.familia_id, n.atleta_id order by 1 limit 1;
      select string_agg(initcap(lower(split_part(n.nombre, ' ', 1))), ', ' order by n.nombre) into v_nombres
        from public.natacion_equip_nadadores n where n.familia_id = v_f.id;
      v_tok := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
      insert into public.pagos (atleta_id, concepto, importe, estado, fecha_vencimiento, metodo, periodo, notas, token_pago, aviso_pago_en)
      values (v_atleta, 'Equipación de natación 2026/27 · ' || coalesce(v_nombres, ''), v_f.total, 'pendiente',
              (now() at time zone 'Europe/Madrid')::date + 7, 'tarjeta', to_char(now() at time zone 'Europe/Madrid', 'YYYY-MM'),
              'Natación · equipación 2026/27 (mig 436)', v_tok, now())
      returning id into v_pago;
      update public.natacion_equip_familias set pago_id = v_pago where id = v_f.id;
    end if;
    update public.natacion_equip_familias set estado = 'llegado', llegado_en = coalesce(llegado_en, now()) where id = v_f.id;
  elsif p_estado = 'pagado' then
    if v_f.pago_id is not null then
      update public.pagos set estado = 'pagado', fecha_pago = coalesce(fecha_pago, current_date),
             metodo = case when p_metodo in ('efectivo', 'tarjeta') then p_metodo else coalesce(metodo, 'tarjeta') end
       where id = v_f.pago_id and estado <> 'pagado' and not anulado;
    end if;
    update public.natacion_equip_familias set estado = 'pagado' where id = v_f.id;
  elsif p_estado = 'entregado' then
    update public.natacion_equip_familias set estado = 'entregado', entregado_en = now() where id = v_f.id;
  else
    update public.natacion_equip_familias set estado = 'pedido' where id = v_f.id;
  end if;
  return (select jsonb_build_object('ok', true, 'estado', f.estado,
            'pago_enlace', case when p.token_pago is not null then 'https://atletismoapolana.com/pagar/?t=' || p.token_pago end)
            from public.natacion_equip_familias f left join public.pagos p on p.id = f.pago_id where f.id = v_f.id);
end;
$$;
revoke all on function public.natacion_equip_estado_set(uuid, text, text) from public, anon;
grant execute on function public.natacion_equip_estado_set(uuid, text, text) to authenticated, service_role;

insert into public.salud_rpc_front (nombre, en_publica) values
  ('natacion_equip_publica', true), ('natacion_equip_guardar', true), ('natacion_equip_listar', false),
  ('natacion_equip_nuevo_set', false), ('natacion_equip_estado_set', false), ('natacion_equip_preparar', false)
on conflict (nombre) do nothing;

select public.natacion_equip_preparar();
commit;
