-- 526 · Natación · Cuotas: recibos sin pagar en la fila de cada nadador
-- ---------------------------------------------------------------------------
-- Mario (9-nov-2026): no veía quién debe octubre y noviembre ni podía reenviar
-- los recibos sueltos (los /pagar/?t=). Lista para quien ya lleva las cuotas
-- (natacion_cuotas_puede). No incluye la ropa (va aparte, cobro parado).
-- Alma Reyes: su noviembre va por SportMember → la domiciliación empieza en
-- diciembre, para que el enlace no cobre noviembre otra vez.
-- ---------------------------------------------------------------------------
begin;

create or replace function public.natacion_recibos_pendientes()
returns table (atleta_id uuid, pago_id uuid, concepto text, periodo text, importe numeric, vencimiento date, avisado date, enlace text)
language plpgsql stable security definer
set search_path to 'public'
as $$
#variable_conflict use_column
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede ver los recibos.' using errcode = '42501';
  end if;
  return query
  select p.atleta_id, p.id, p.concepto, p.periodo, p.importe, p.fecha_vencimiento,
         (p.aviso_pago_en at time zone 'Europe/Madrid')::date,
         'https://atletismoapolana.com/pagar/?t=' || p.token_pago
    from public.pagos p
   where not p.anulado and p.estado in ('pendiente', 'impagado') and p.token_pago is not null
     and p.concepto ~* 'nataci' and p.concepto !~* '^(equipación|ropa) de natación'
     and exists (select 1 from public.natacion_accesos na where na.atleta_id = p.atleta_id)
   order by p.periodo;
end;
$$;
revoke all on function public.natacion_recibos_pendientes() from public, anon;
grant execute on function public.natacion_recibos_pendientes() to authenticated, service_role;

set local apolana.autor = 'claude';
update public.cuotas_entreno set inicio = date '2026-12-01'
 where id = '60d8bd35-8cdb-4c33-b5cc-9a671410b365' and suscripcion_estado = 'pendiente';

commit;
