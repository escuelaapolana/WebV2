-- 521 · Natación · Ropa: pedir el pago a quien se lleva una prenda del stock
-- ---------------------------------------------------------------------------
-- Andrés (5-nov-2026): se están repartiendo bañadores (albarán Mad Wave) y se
-- cobra por Bizum a Mario sin que la app pida nada. «Mario tiene que poder
-- marcar a quién le da la ropa para que pague, y cómo hacerlo».
--
--   · natacion_ropa_stock.pago_id → un recibo en `pagos` con token, que se paga
--     con tarjeta en /pagar/?t= (Edge natacion-mes-pagar, Stripe Apolana; la
--     misma vía que la equipación).
--   · RPC natacion_ropa_stock_cobro(p_id): crea (o devuelve) ese enlace para la
--     fila; necesita «Para quién» y un precio.
--   · Al pagarse el recibo (webhook → pagos.estado='pagado') la fila se marca
--     sola como pagada con tarjeta.
--   · Si se marca «Ha pagado» a mano (Bizum/efectivo) o se deja libre, el
--     recibo pendiente se ANULA, para que el enlace ya no cobre.
--   · listar devuelve el enlace, su estado y un teléfono (el de la familia del
--     nadador con ese nombre) para el WhatsApp.
-- ---------------------------------------------------------------------------
begin;

alter table public.natacion_ropa_stock
  add column if not exists pago_id uuid references public.pagos(id) on delete set null;

-- ---------- crear / devolver el enlace de pago ----------
create or replace function public.natacion_ropa_stock_cobro(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare v public.natacion_ropa_stock%rowtype; v_p public.pagos%rowtype; v_tok text; v_pago uuid; v_imp numeric;
begin
  if not public.natacion_ropa_puede() then raise exception 'Solo quien lleva la ropa de natación.' using errcode = '42501'; end if;
  select * into v from public.natacion_ropa_stock where id = p_id for update;
  if not found then raise exception 'No encuentro esa fila.' using errcode = 'P0001'; end if;
  if v.familia_id is not null then raise exception 'Esto va con su pedido de equipación: lo paga allí.' using errcode = 'P0001'; end if;
  if nullif(btrim(coalesce(v.persona, '')), '') is null then raise exception 'Pon primero «Para quién» y guarda.' using errcode = 'P0001'; end if;
  if coalesce(v.precio, 0) <= 0 or v.pago_metodo = 'regalo' then raise exception 'Pon primero el precio y guarda.' using errcode = 'P0001'; end if;
  if v.pagado_en is not null then raise exception 'Ya está pagado.' using errcode = 'P0001'; end if;

  if v.pago_id is not null then
    select * into v_p from public.pagos where id = v.pago_id;
    if found and not v_p.anulado and v_p.estado = 'pendiente' then
      return jsonb_build_object('ok', true, 'importe', v_p.importe,
        'enlace', 'https://atletismoapolana.com/pagar/?t=' || v_p.token_pago);
    end if;
  end if;

  v_imp := round(v.precio * greatest(1, v.cantidad), 2);
  v_tok := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into public.pagos (concepto, importe, estado, fecha_vencimiento, metodo, periodo, notas, token_pago, aviso_pago_en)
  values ('Ropa de natación · ' || v.articulo || coalesce(' talla ' || v.talla, '') ||
            case when v.cantidad > 1 then ' ×' || v.cantidad else '' end || ' · ' || initcap(lower(v.persona)),
          v_imp, 'pendiente', (now() at time zone 'Europe/Madrid')::date + 7, 'tarjeta',
          to_char(now() at time zone 'Europe/Madrid', 'YYYY-MM'), 'Natación · ropa del stock (mig 521)', v_tok, now())
  returning id into v_pago;
  update public.natacion_ropa_stock set pago_id = v_pago, updated_at = now() where id = v.id;
  return jsonb_build_object('ok', true, 'importe', v_imp, 'enlace', 'https://atletismoapolana.com/pagar/?t=' || v_tok);
end;
$$;
revoke all on function public.natacion_ropa_stock_cobro(uuid) from public, anon;
grant execute on function public.natacion_ropa_stock_cobro(uuid) to authenticated, service_role;

-- ---------- recibo pagado → fila pagada ----------
create or replace function public._natacion_ropa_pago_pagado()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.estado = 'pagado' and coalesce(old.estado, '') <> 'pagado' then
    update public.natacion_ropa_stock
       set pagado_en = coalesce(pagado_en, new.fecha_pago, (now() at time zone 'Europe/Madrid')::date),
           pago_metodo = coalesce(pago_metodo, 'tarjeta'), updated_at = now()
     where pago_id = new.id and pagado_en is null;
  end if;
  return new;
end;
$$;
drop trigger if exists natacion_ropa_pago_pagado_t on public.pagos;
create trigger natacion_ropa_pago_pagado_t after update of estado on public.pagos
  for each row when (new.estado = 'pagado') execute function public._natacion_ropa_pago_pagado();

-- ---------- pagado a mano o libre → anular el recibo pendiente ----------
create or replace function public._natacion_ropa_stock_anula_pago()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_motivo text;
begin
  if old.pago_id is null then return new; end if;
  if new.persona is null and new.familia_id is null then
    v_motivo := 'La prenda ha quedado libre en el stock';
  elsif new.pagado_en is not null and old.pagado_en is null and coalesce(new.pago_metodo, '') <> 'tarjeta' then
    v_motivo := 'Pagado en mano (' || coalesce(new.pago_metodo, 'sin método') || ')';
  elsif coalesce(new.precio, 0) <> coalesce(old.precio, 0) or coalesce(new.cantidad, 1) <> coalesce(old.cantidad, 1)
        or coalesce(new.persona, '') <> coalesce(old.persona, '') then
    v_motivo := 'Cambió el precio o la persona: hay que pedir el pago otra vez';
  end if;
  if v_motivo is not null then
    update public.pagos set anulado = true, anulado_motivo = v_motivo, anulado_en = now()
     where id = old.pago_id and estado = 'pendiente' and not anulado;
    if found or new.persona is null then new.pago_id := null; end if;
  end if;
  return new;
end;
$$;
drop trigger if exists natacion_ropa_stock_anula_pago_t on public.natacion_ropa_stock;
create trigger natacion_ropa_stock_anula_pago_t before update on public.natacion_ropa_stock
  for each row execute function public._natacion_ropa_stock_anula_pago();

-- ---------- listar: + enlace, estado del recibo y teléfono ----------
create or replace function public.natacion_ropa_stock_listar()
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
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
        'nota', s.nota, 'revisar', s.revisar, 'created_at', s.created_at,
        'pago_enlace', case when pp.id is not null and not pp.anulado and pp.estado = 'pendiente'
                            then 'https://atletismoapolana.com/pagar/?t=' || pp.token_pago end,
        'pago_creado', pp.created_at,
        'telefono', tel.telefono)
        order by s.lote, s.articulo, public._natacion_ropa_orden_talla(s.talla), s.persona nulls last)
        from public.natacion_ropa_stock s
        left join public.productos pr on pr.id = s.producto_id
        left join public.natacion_equip_familias f on f.id = s.familia_id
        left join public.pagos p on p.id = f.pago_id
        left join public.pagos pp on pp.id = s.pago_id
        left join lateral (
          select ff.telefono from public.natacion_equip_nadadores n
            join public.natacion_equip_familias ff on ff.id = n.familia_id
           where s.persona is not null and nullif(btrim(ff.telefono), '') is not null
             and lower(n.nombre) like lower(btrim(s.persona)) || '%'
           order by length(n.nombre) limit 1) tel on true), '[]'),
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
$function$;

-- ---------- datos: lo pagado por Bizum a Mario cuenta como pagado ----------
set local apolana.autor = 'claude';
update public.natacion_ropa_stock
   set precio = 40, pagado_en = date '2026-10-28', pago_metodo = 'bizum', updated_at = now()
 where lote = 'Albarán P 2026-91 · Mad Wave' and pagado_en is null
   and persona in ('Elena Nogueroles', 'Lidia Sánchez') and nota ilike '%bizzum%';

commit;
