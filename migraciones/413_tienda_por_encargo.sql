-- 413 · Tienda de ropa POR ENCARGO (Andrés, 20-oct-2026)
-- ---------------------------------------------------------------------------
-- «La ropa quiero que sea bajo pedido: me la piden y luego pagan arriba en la
-- oficina con tarjeta o efectivo.»
--
-- Desde la 296 la tienda ya no cobraba online (pagos_config.tienda_pago_online
-- = false → `tienda_pedido_efectivo`). Ahora se deja ATADO:
--   · La Edge `tienda-pagar` ya no abre pasarela nunca (ver su cabecera).
--   · `tienda_pago_iniciar` deja de poder llamarse desde el navegador
--     (solo service_role, que ya no la usa; la salud diaria solo la prueba si
--     alguien volviera a poner tienda_pago_online = true).
--   · pedidos.pago_metodo: cómo se pagó en la oficina ('tarjeta' | 'efectivo';
--     'online' para los antiguos pagados con Stripe). El panel admin/pedidos lo
--     marca al entregar y pone pagado_en.
-- ---------------------------------------------------------------------------

update public.pagos_config set tienda_pago_online = false where id = 1;

revoke execute on function public.tienda_pago_iniciar(jsonb, jsonb, uuid, jsonb) from anon, authenticated, public;

alter table public.pedidos
  add column if not exists pago_metodo text
  check (pago_metodo is null or pago_metodo in ('tarjeta','efectivo','online'));

-- Los que ya entraron pagados por Stripe, con su etiqueta.
update public.pedidos set pago_metodo = 'online'
 where pago_metodo is null and pagado_en is not null and pago_online_id is not null;

comment on column public.pedidos.pago_metodo is
  '413 · Cómo se pagó: tarjeta/efectivo en la oficina, u online (antiguos con Stripe). Lo marca admin/pedidos.';
