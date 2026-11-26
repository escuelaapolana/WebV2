-- 545 · Natación: al ACTIVAR la cuota se pagan también los recibos pendientes
-- ---------------------------------------------------------------------------
-- Andrés (26-nov-2026): «si alguien debe octubre y noviembre, ¿cómo hacemos
-- para que pague todo de una?» → que paguen lo pendiente con el mismo enlace.
--   · entreno-pagar (natación) añade a la pasarela de la cuota cada recibo de
--     natación sin pagar como precio único («Recibo pendiente · …») y guarda
--     sus ids en la suscripción (metadata.recibos).
--   · cubo-webhook, al cobrarse esa primera factura, llama a esta función:
--     marca PAGADOS esos recibos (con su número) y devuelve lo que suman, que
--     se descuenta de la fila de la cuota para no contar el dinero dos veces.
-- Idempotente: solo toca recibos aún pendientes (invoice.paid y
-- invoice.payment_succeeded llegan los dos).
-- ---------------------------------------------------------------------------
begin;

create or replace function public.natacion_recibos_cobrados_stripe(
  p_ids uuid[], p_factura text, p_fecha date, p_metodo text default 'tarjeta')
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_n     int;
  v_total numeric;
begin
  if p_ids is null or cardinality(p_ids) = 0 then return jsonb_build_object('marcados', 0); end if;
  with u as (
    update public.pagos p
       set estado = 'pagado', fecha_pago = coalesce(p_fecha, (now() at time zone 'Europe/Madrid')::date),
           metodo = case when p_metodo in ('tarjeta', 'domiciliado') then p_metodo else 'tarjeta' end,
           notas = coalesce(nullif(p.notas, ''), '') || ' · Cobrado al activar la cuota (stripe-recibo:' || coalesce(p_factura, '?') || ')'
     where p.id = any(p_ids) and not p.anulado and p.estado in ('pendiente', 'impagado')
       and coalesce(p.notas, '') not like 'stripe:%'
       and p.concepto ~* 'nataci'
    returning p.importe)
  select count(*), coalesce(sum(importe), 0) into v_n, v_total from u;
  return jsonb_build_object('marcados', v_n, 'importe', v_total);
end;
$$;
revoke all on function public.natacion_recibos_cobrados_stripe(uuid[], text, date, text) from public, anon, authenticated;
grant execute on function public.natacion_recibos_cobrados_stripe(uuid[], text, date, text) to service_role;

commit;
