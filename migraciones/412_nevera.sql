-- 412 · NEVERA de bebidas de la instalación (pago con QR)
-- ---------------------------------------------------------------------------
-- El club ha puesto una nevera abierta («confiamos en la gente»). Se paga con
-- el datáfono (aparte, no pasa por aquí) o con un QR pegado en la nevera que
-- lleva a /nevera/: eliges bebidas y pagas con tarjeta / Apple Pay / Google Pay.
--
-- El dinero va a la cuenta de Stripe de ÍTAKA (como la ropa): lo cobra la Edge
-- `nevera-pagar` con STRIPE_SECRET_KEY, y lo confirma el webhook de siempre
-- (`pago-webhook` → pagos_confirmar → pagos_aplicar_efecto, rama 'nevera').
--
--   · nevera_productos   catálogo (lo ve cualquiera; solo admin lo cambia).
--   · nevera_ventas      cada compra (solo admin la lee).
--   · nevera_venta_iniciar(items)   crea venta + pagos_online. PRECIOS DE LA BASE.
--   · nevera_venta_estado(ref)      para la pantalla «Pagado ✓» (nada personal).
--   · pagos_aplicar_efecto          + rama 'nevera' (marca la venta pagada).
--   · nevera_admin_ventas(desde, hasta)  para el panel admin/nevera.
-- ---------------------------------------------------------------------------

-- 1 · Catálogo -------------------------------------------------------------
create table if not exists public.nevera_productos (
  id          uuid primary key default gen_random_uuid(),
  nombre      text not null check (length(trim(nombre)) between 1 and 60),
  detalle     text check (detalle is null or length(detalle) <= 60),
  precio_cent integer not null check (precio_cent between 10 and 5000),
  color       text not null default '#2E4256' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  orden       integer not null default 0,
  activo      boolean not null default true,
  creado_en   timestamptz not null default now()
);

alter table public.nevera_productos enable row level security;

drop policy if exists "nevera productos se ven" on public.nevera_productos;
create policy "nevera productos se ven" on public.nevera_productos
  for select to anon, authenticated
  using (activo or (select public.es_admin()));

drop policy if exists "nevera productos los cambia admin" on public.nevera_productos;
create policy "nevera productos los cambia admin" on public.nevera_productos
  for all to authenticated
  using ((select public.es_admin()))
  with check ((select public.es_admin()));

grant select on public.nevera_productos to anon, authenticated;
grant insert, update, delete on public.nevera_productos to authenticated;

-- Productos iniciales (foto del datáfono, Andrés 20-oct-2026). Solo si está vacía.
insert into public.nevera_productos (nombre, detalle, precio_cent, color, orden)
select * from (values
  ('Agua',                     '50 cl',  100, '#3B85C0', 10),
  ('Agua',                     '1,5 L',  150, '#2F6FA8', 20),
  ('Coca-Cola',                '33 cl',  150, '#D3202A', 30),
  ('Coca-Cola sin cafeína',    '33 cl',  150, '#B8860B', 40),
  ('Coca-Cola Zero',           '33 cl',  150, '#1F1F1F', 50),
  ('Aquarius naranja',         '33 cl',  180, '#E8772E', 60),
  ('Aquarius limón',           '33 cl',  180, '#C9B200', 70)
) as v(nombre, detalle, precio_cent, color, orden)
where not exists (select 1 from public.nevera_productos);

-- 2 · Ventas ---------------------------------------------------------------
create table if not exists public.nevera_ventas (
  id             uuid primary key default gen_random_uuid(),
  referencia     text not null unique,
  items          jsonb not null,           -- [{producto_id,nombre,cantidad,precio_cent}]
  unidades       integer not null check (unidades between 1 and 30),
  total_cent     integer not null check (total_cent > 0),
  estado         text not null default 'pendiente'
                   check (estado in ('pendiente','pagada','cancelada')),
  pago_online_id uuid references public.pagos_online(id) on delete set null,
  creado_en      timestamptz not null default now(),
  pagado_en      timestamptz
);
create index if not exists nevera_ventas_pagado_idx on public.nevera_ventas (pagado_en desc) where estado = 'pagada';
create index if not exists nevera_ventas_creado_idx on public.nevera_ventas (creado_en desc);

alter table public.nevera_ventas enable row level security;

drop policy if exists "nevera ventas las ve admin" on public.nevera_ventas;
create policy "nevera ventas las ve admin" on public.nevera_ventas
  for select to authenticated
  using ((select public.es_admin()));

revoke all on public.nevera_ventas from anon;
grant select on public.nevera_ventas to authenticated;

-- 3 · pagos_online admite el tipo 'nevera' ---------------------------------
alter table public.pagos_online drop constraint if exists pagos_online_tipo_check;
alter table public.pagos_online add constraint pagos_online_tipo_check
  check (tipo = any (array['bono','licencia','ropa','otro','alta_socio','recibo','nevera']));

-- 4 · Iniciar una venta (lo llama la Edge nevera-pagar con service_role) ----
create or replace function public.nevera_venta_iniciar(p_items jsonb)
returns jsonb
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_cfg    public.pagos_config;
  v_item   jsonb;
  v_prod   public.nevera_productos;
  v_cant   integer;
  v_ids    uuid[] := array[]::uuid[];
  v_lineas jsonb := '[]'::jsonb;
  v_total  integer := 0;
  v_n      integer := 0;
  v_ref    text;
  v_pago   public.pagos_online;
  v_venta  uuid;
begin
  -- Freno por IP a las llamadas directas (la Edge llama con service_role).
  if coalesce(auth.role(), '') <> 'service_role' then
    perform public.anti_spam('nevera_venta', 15, interval '10 minutes');
  end if;

  select * into v_cfg from public.pagos_config where id = 1;
  if not found or not v_cfg.activo then
    raise exception 'El pago con tarjeta no está activado ahora mismo.' using errcode = 'P0001';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'No has elegido ninguna bebida.' using errcode = 'P0001';
  end if;
  if jsonb_array_length(p_items) > 20 then
    raise exception 'Demasiadas líneas.' using errcode = 'P0001';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    begin
      v_cant := (v_item ->> 'cantidad')::int;
    exception when others then
      raise exception 'Cantidad no válida.' using errcode = 'P0001';
    end;
    if v_cant is null or v_cant < 1 or v_cant > 20 then
      raise exception 'Cantidad no válida (de 1 a 20 por bebida).' using errcode = 'P0001';
    end if;

    begin
      select * into v_prod from public.nevera_productos
       where id = (v_item ->> 'producto_id')::uuid and activo;
    exception when others then
      raise exception 'Bebida no válida.' using errcode = 'P0001';
    end;
    if not found then
      raise exception 'Una de las bebidas ya no está disponible. Recarga la página.' using errcode = 'P0001';
    end if;
    if v_prod.id = any(v_ids) then
      raise exception 'Bebida repetida en la lista.' using errcode = 'P0001';
    end if;
    v_ids := v_ids || v_prod.id;

    v_lineas := v_lineas || jsonb_build_array(jsonb_build_object(
      'producto_id', v_prod.id,
      'nombre',      v_prod.nombre || coalesce(' ' || nullif(v_prod.detalle, ''), ''),
      'cantidad',    v_cant,
      'precio_cent', v_prod.precio_cent));
    v_total := v_total + v_prod.precio_cent * v_cant;
    v_n := v_n + v_cant;
  end loop;

  if v_n > 30 then
    raise exception 'Como mucho 30 bebidas por pago.' using errcode = 'P0001';
  end if;
  if v_total <= 0 then
    raise exception 'El total no es válido.' using errcode = 'P0001';
  end if;

  v_ref := 'NEV-' || to_char(now() at time zone 'Europe/Madrid', 'YYMMDD') || '-' ||
           upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  insert into public.pagos_online (referencia, concepto, tipo, importe_centimos, metadatos)
  values (v_ref,
          'Nevera Apolana · ' || v_n || case when v_n = 1 then ' bebida' else ' bebidas' end,
          'nevera', v_total,
          jsonb_build_object('origen', 'nevera', 'unidades', v_n))
  returning * into v_pago;

  insert into public.nevera_ventas (referencia, items, unidades, total_cent, pago_online_id)
  values (v_ref, v_lineas, v_n, v_total, v_pago.id)
  returning id into v_venta;

  update public.pagos_online
     set metadatos = metadatos || jsonb_build_object('venta_id', v_venta)
   where id = v_pago.id;

  return jsonb_build_object(
    'referencia',       v_ref,
    'importe_centimos', v_total,
    'moneda',           v_pago.moneda,
    'concepto',         v_pago.concepto,
    'unidades',         v_n,
    'items',            v_lineas);
end;
$function$;

revoke all on function public.nevera_venta_iniciar(jsonb) from public;
grant execute on function public.nevera_venta_iniciar(jsonb) to anon, authenticated, service_role;

-- 5 · Estado de una venta, para la pantalla «Pagado ✓» ----------------------
-- Solo lo que se ve en la pantalla: qué, cuánto, cuándo. Nada de nadie.
create or replace function public.nevera_venta_estado(p_ref text)
returns jsonb
language sql stable security definer set search_path to 'public'
as $function$
  select case when v.id is null then jsonb_build_object('estado', 'no_existe')
  else jsonb_build_object(
    'referencia', v.referencia,
    'estado', case
                when v.estado = 'pagada' then 'pagada'
                when po.estado = 'pagado' then 'pagada'
                when po.estado = 'reembolsado' then 'devuelta'
                when po.estado in ('cancelado','fallido') or v.estado = 'cancelada' then 'cancelada'
                else 'pendiente' end,
    'items',      v.items,
    'unidades',   v.unidades,
    'total_cent', v.total_cent,
    'creado_en',  v.creado_en,
    'pagado_en',  coalesce(v.pagado_en, po.pagado_en)) end
  from (select 1) uno
  left join public.nevera_ventas v on v.referencia = p_ref
  left join public.pagos_online po on po.id = v.pago_online_id;
$function$;

revoke all on function public.nevera_venta_estado(text) from public;
grant execute on function public.nevera_venta_estado(text) to anon, authenticated, service_role;

-- 6 · pagos_aplicar_efecto con la rama 'nevera' -----------------------------
create or replace function public.pagos_aplicar_efecto(p_pago uuid)
 returns text
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_pago public.pagos_online;
  v_usos integer;
  v_dias integer;
  v_bono uuid;
begin
  select * into v_pago from public.pagos_online where id = p_pago for update;
  if not found then return 'no-existe'; end if;
  if v_pago.estado <> 'pagado' then return 'no-pagado'; end if;
  if v_pago.aplicado_en is not null then return 'ya-aplicado'; end if;

  if v_pago.tipo = 'bono' then
    v_usos := nullif(v_pago.metadatos ->> 'usos', '')::int;
    v_dias := nullif(v_pago.metadatos ->> 'caducidad_dias', '')::int;
    if v_pago.atleta_id is null or v_usos is null or v_usos <= 0 then
      update public.pagos_online
         set metadatos = metadatos || jsonb_build_object('aviso', 'Pago cobrado sin datos para dar el bono; revisar a mano.')
       where id = p_pago;
      return 'sin-datos';
    end if;
    insert into public.cubo_bonos (atleta_id, usos_totales, precio, fecha_compra, caducidad, activo, notas, pago_online_id)
    values (v_pago.atleta_id, v_usos, round(v_pago.importe_centimos::numeric / 100, 2), current_date,
            case when v_dias is not null then current_date + v_dias else null end,
            true, 'Pagado con tarjeta · ' || v_pago.referencia, v_pago.id)
    on conflict (pago_online_id) where pago_online_id is not null do nothing
    returning id into v_bono;
    if v_bono is null then
      update public.pagos_online set aplicado_en = coalesce(aplicado_en, now()) where id = p_pago;
      return 'ya-aplicado';
    end if;

  elsif v_pago.tipo = 'ropa' then
    update public.pedidos
       set pagado_en = coalesce(pagado_en, now())
     where pago_online_id = v_pago.id;

  elsif v_pago.tipo = 'nevera' then
    -- 412 · La bebida de la nevera queda pagada (idempotente).
    update public.nevera_ventas
       set estado    = 'pagada',
           pagado_en = coalesce(pagado_en, v_pago.pagado_en, now())
     where pago_online_id = v_pago.id
       and estado <> 'pagada';

  elsif v_pago.tipo = 'alta_socio' then
    -- (311) también la fecha REAL del cobro; la de la firma va aparte.
    update public.altas_socio
       set pago_estado = 'pagado',
           pagado_en   = coalesce(pagado_en, v_pago.pagado_en, now())
     where id = (v_pago.metadatos ->> 'alta_id')::uuid;

  elsif v_pago.tipo = 'recibo' then
    -- El recibo del libro de cobros queda pagado con tarjeta.
    update public.pagos
       set estado     = 'pagado',
           fecha_pago = coalesce(fecha_pago, current_date),
           metodo     = 'tarjeta'
     where id = (v_pago.metadatos ->> 'pago_id')::uuid
       and anulado = false
       and estado <> 'pagado';
  end if;

  update public.pagos_online set aplicado_en = now() where id = p_pago;
  return 'aplicado';
end;
$function$;

-- 7 · Panel: ventas de un periodo (solo admin) ------------------------------
create or replace function public.nevera_admin_ventas(p_desde timestamptz, p_hasta timestamptz default now())
returns jsonb
language plpgsql stable security definer set search_path to 'public'
as $function$
begin
  if not (select public.es_admin()) then
    raise exception 'Solo el club puede ver las ventas de la nevera.' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'referencia', v.referencia,
             'items',      v.items,
             'unidades',   v.unidades,
             'total_cent', v.total_cent,
             'estado',     case when po.estado = 'reembolsado' then 'devuelta' else v.estado end,
             'creado_en',  v.creado_en,
             'pagado_en',  v.pagado_en) order by v.pagado_en desc)
      from public.nevera_ventas v
      left join public.pagos_online po on po.id = v.pago_online_id
     where v.estado = 'pagada'
       and v.pagado_en >= p_desde and v.pagado_en < p_hasta), '[]'::jsonb);
end;
$function$;

revoke all on function public.nevera_admin_ventas(timestamptz, timestamptz) from public, anon;
grant execute on function public.nevera_admin_ventas(timestamptz, timestamptz) to authenticated;
