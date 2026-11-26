-- 547 · Natación: HISTORIAL DE PAGOS de un nadador (lo pagado y lo pendiente)
-- ---------------------------------------------------------------------------
-- Andrés (26-nov-2026): «quiero algún sitio donde ver el histórico de pagos: lo
-- que ha pagado un atleta y los pendientes». Administración ya lo tiene en
-- Informes → «Pagos de una persona»; esto lo pone en Natación → Cuotas (para
-- Mario), dentro de la fila del nadador. Todos sus recibos no anulados.
-- ---------------------------------------------------------------------------
begin;

create or replace function public.natacion_pagos_de(p_atleta uuid)
returns table (id uuid, concepto text, periodo text, importe numeric, estado text, metodo text,
               vence date, pagado_el date, numero_recibo text, enlace text)
language plpgsql stable security definer
set search_path to 'public'
as $$
#variable_conflict use_column
begin
  if not public.natacion_cuotas_puede() then
    raise exception 'Solo quien lleva la natación puede ver los pagos.' using errcode = '42501';
  end if;
  if not public._natacion_es_nadador(p_atleta) then
    raise exception 'Esa persona no es de natación.' using errcode = '42501';
  end if;
  return query
  select p.id, p.concepto, p.periodo, p.importe, p.estado, p.metodo, p.fecha_vencimiento, p.fecha_pago, p.numero_recibo,
         case when p.estado <> 'pagado' and p.token_pago is not null then 'https://atletismoapolana.com/pagar/?t=' || p.token_pago end
    from public.pagos p
   where p.atleta_id = p_atleta and not p.anulado
   order by coalesce(p.fecha_pago, p.fecha_vencimiento, p.created_at::date) desc, p.created_at desc;
end;
$$;
revoke all on function public.natacion_pagos_de(uuid) from public, anon;
grant execute on function public.natacion_pagos_de(uuid) to authenticated, service_role;

commit;
