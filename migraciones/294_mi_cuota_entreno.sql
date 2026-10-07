-- 294 · Que el atleta vea SU cuota de entreno pendiente desde el portal
-- Las cuotas de entreno (SEPA trimestral) solo se podían domiciliar por el
-- ENLACE DEL CORREO: en la app no salía NADA, así que quien no abría el correo
-- se quedaba «sin domiciliar» sin enterarse. Esta RPC deja que cada persona
-- (o la familia) vea su cuota pendiente para poder domiciliarla desde el Inicio.
-- La tabla cuotas_entreno tiene RLS solo admin/staff; esto es la vía del propio.

create or replace function public.mi_cuota_entreno()
returns table(token text, importe_cent int, concepto text, suscripcion_estado text)
language sql stable security definer set search_path to 'public'
as $$
  select ce.token, ce.importe_cent, ce.concepto, ce.suscripcion_estado
  from public.cuotas_entreno ce
  where ce.perfil_id = public.mi_perfil_id()
    and ce.cobro_abierto
    and coalesce(ce.suscripcion_estado, '') <> 'activa'
  order by ce.created_at desc
  limit 1;
$$;

grant execute on function public.mi_cuota_entreno() to authenticated;
