-- 548 · Natación → «Pagos»: todos los recibos de natación (lo cobrado y lo pendiente)
-- ---------------------------------------------------------------------------
-- Andrés (26-nov-2026): «lo mejor será crear algo de pagos dentro de natación,
-- una sección de dinero», como «Pagos generados» de SportMember. Devuelve cada
-- recibo de natación no anulado de quien es (o fue) nadador, con su sección,
-- su forma de pago y, si está pendiente, el enlace para pagarlo. La pantalla
-- portal/natacion-pagos filtra por mes, estado, sección y forma.
-- Fuera: equipación y ropa (tienen su pantalla).
-- ---------------------------------------------------------------------------
begin;

create or replace function public.natacion_pagos_listar()
returns table (id uuid, atleta_id uuid, nadador text, tipo text, concepto text, periodo text, importe numeric,
               estado text, metodo text, vence date, pagado_el date, numero_recibo text, enlace text,
               transferencia boolean, creado date)
language plpgsql stable security definer
set search_path to 'public'
as $$
#variable_conflict use_column
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede ver los pagos.' using errcode = '42501';
  end if;
  return query
  select p.id, p.atleta_id,
         initcap(btrim(coalesce(a.nombre, '') || ' ' || coalesce(a.apellidos, ''))),
         (select x.tipo from public.natacion_inscripciones x where x.atleta_id = p.atleta_id order by x.activa desc, x.created_at desc limit 1),
         p.concepto, p.periodo, p.importe, p.estado, p.metodo, p.fecha_vencimiento, p.fecha_pago, p.numero_recibo,
         case when p.estado <> 'pagado' and p.token_pago is not null then 'https://atletismoapolana.com/pagar/?t=' || p.token_pago end,
         coalesce(q.transferencia, false),
         (p.created_at at time zone 'Europe/Madrid')::date
    from public.pagos p
    join public.atletas a on a.id = p.atleta_id
    left join public.cuotas_entreno q on q.id = p.cuota_entreno_id
   where not p.anulado
     and p.concepto ~* 'nataci' and p.concepto !~* '^(equipación|ropa)'
     and exists (select 1 from public.natacion_accesos na where na.atleta_id = p.atleta_id)
   order by coalesce(p.periodo, to_char(p.created_at, 'YYYY-MM')) desc, a.nombre;
end;
$$;
revoke all on function public.natacion_pagos_listar() from public, anon;
grant execute on function public.natacion_pagos_listar() to authenticated, service_role;

commit;
