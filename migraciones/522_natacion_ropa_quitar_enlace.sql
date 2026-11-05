-- 522 · Natación · Ropa: quitar el enlace de pago cuando ya no hace falta
-- ---------------------------------------------------------------------------
-- En 521 el enlace pendiente se «anulaba», pero pagos_protege solo deja anular
-- recibos con número (anular_recibo). Un enlace pendiente no tiene número: se
-- BORRA (lo permite pagos_protege). Antes (BEFORE) se suelta la fila del
-- recibo; después (AFTER) se borra el recibo pendiente y sin número.
-- ---------------------------------------------------------------------------
begin;

create or replace function public._natacion_ropa_stock_anula_pago()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if old.pago_id is null or new.pago_id is distinct from old.pago_id then return new; end if;
  if not exists (select 1 from public.pagos where id = old.pago_id and estado = 'pendiente' and not anulado) then return new; end if;
  if (new.persona is null and new.familia_id is null)
     or (new.pagado_en is not null and old.pagado_en is null)
     or coalesce(new.precio, 0) <> coalesce(old.precio, 0)
     or coalesce(new.cantidad, 1) <> coalesce(old.cantidad, 1)
     or coalesce(new.persona, '') <> coalesce(old.persona, '') then
    new.pago_id := null;
  end if;
  return new;
end;
$$;

create or replace function public._natacion_ropa_stock_borra_enlace()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  delete from public.pagos
   where id = old.pago_id and estado = 'pendiente' and not anulado and numero_recibo is null
     and notas = 'Natación · ropa del stock (mig 521)';
  return null;
end;
$$;
drop trigger if exists natacion_ropa_stock_borra_enlace_t on public.natacion_ropa_stock;
create trigger natacion_ropa_stock_borra_enlace_t after update on public.natacion_ropa_stock
  for each row when (old.pago_id is not null and new.pago_id is null)
  execute function public._natacion_ropa_stock_borra_enlace();

commit;
