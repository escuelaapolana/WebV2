-- 173 · Panel de admin para los pedidos de la tienda
-- ------------------------------------------------------------
-- La tienda ya cobra (migración 172): cada compra deja un `pedidos`
-- con sus `pedido_items` y, si se pagó, `pagado_en`. Faltaba la
-- pantalla del club para VERLOS y moverlos por su ciclo de
-- preparación. Estas dos RPC son la base de esa pantalla
-- (portal/pedidos/). Ambas SOLO para admin (es_admin()).
--
--   1) pedidos_admin_listar(): devuelve todos los pedidos con su
--      contacto, sus artículos (nombre·talla·cantidad·precio), el
--      importe, la referencia de pago y si está cobrado. Ordena los
--      cobrados primero (lo que hay que preparar) y los sin pagar al
--      final. Es de solo lectura.
--   2) pedido_admin_estado(): mueve un pedido por su ciclo
--      (pendiente→preparando→listo→entregado, o cancelado). Al marcar
--      «entregado» sella la fecha de entrega si no la tenía.
--
-- El COBRO no se toca aquí: «pagado» lo pone el webhook (pagado_en).
-- Esto es solo el ciclo de preparación, que lo lleva el club a mano.
-- ============================================================

begin;

-- 1 · Listar los pedidos (solo admin)
create or replace function public.pedidos_admin_listar()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_out jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede ver los pedidos.' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(fila order by sin_pagar, creado desc), '[]'::jsonb)
    into v_out
  from (
    select
      (ped.pagado_en is null) as sin_pagar,
      ped.created_at          as creado,
      jsonb_build_object(
        'id',            ped.id,
        'estado',        ped.estado,
        'total',         ped.total,
        'created_at',    ped.created_at,
        'pagado_en',     ped.pagado_en,
        'fecha_entrega', ped.fecha_entrega,
        'notas',         ped.notas,
        'contacto',      coalesce(ped.contacto, '{}'::jsonb),
        'es_socio',      ped.perfil_id is not null,
        'socio_nombre',  nullif(trim(concat_ws(' ', per.nombre, per.apellidos)), ''),
        'referencia',    pg.referencia,
        'pago_estado',   pg.estado,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'producto',        pr.nombre,
            'talla',           it.talla,
            'cantidad',        it.cantidad,
            'precio_unitario', it.precio_unitario
          ) order by pr.nombre)
          from public.pedido_items it
          join public.productos pr on pr.id = it.producto_id
          where it.pedido_id = ped.id
        ), '[]'::jsonb)
      ) as fila
    from public.pedidos ped
    left join public.perfiles     per on per.id = ped.perfil_id
    left join public.pagos_online pg  on pg.id  = ped.pago_online_id
  ) t;

  return v_out;
end;
$function$;

-- 2 · Mover un pedido por su ciclo de preparación (solo admin)
create or replace function public.pedido_admin_estado(p_id uuid, p_estado text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v public.pedidos;
begin
  if not public.es_admin() then
    raise exception 'Solo el club puede cambiar el estado de un pedido.' using errcode = '42501';
  end if;
  if p_estado not in ('pendiente','preparando','listo','entregado','cancelado') then
    raise exception 'Estado no válido: %', p_estado using errcode = 'P0001';
  end if;

  update public.pedidos
     set estado        = p_estado,
         fecha_entrega = case when p_estado = 'entregado'
                              then coalesce(fecha_entrega, current_date)
                              else fecha_entrega end
   where id = p_id
   returning * into v;

  if not found then
    raise exception 'Ese pedido ya no está.' using errcode = 'P0001';
  end if;

  return jsonb_build_object('ok', true, 'id', v.id, 'estado', v.estado);
end;
$function$;

-- Solo personas con sesión (los admin lo son); nada para anon.
grant execute on function public.pedidos_admin_listar() to authenticated;
grant execute on function public.pedido_admin_estado(uuid, text) to authenticated;

commit;
