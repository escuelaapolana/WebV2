-- 184 · Cobro de la cuota de El Cubo (suscripción con tarjeta · Stripe Apolana)
-- ------------------------------------------------------------
-- Guarda la suscripción de cada persona del Cubo (cliente y suscripción
-- de Stripe, estado y fechas de cobro) sobre su fila de `cubo_altas`, que
-- ya lleva perfil_id/atleta_id y el precio_mes. Y abre una política para
-- que CADA persona pueda ver SU propia alta (hasta ahora solo el admin),
-- que es lo que necesita el portal para enseñarle su cuota y el botón.
--
-- El Stripe es el de APOLANA (distinto del de Ítaka de la tienda): las
-- funciones usan variables propias `STRIPE_*_APOLANA`.
-- ============================================================
begin;

alter table public.cubo_altas
  add column if not exists stripe_customer_id     text,
  add column if not exists stripe_subscription_id text,
  add column if not exists suscripcion_estado     text
    check (suscripcion_estado is null or suscripcion_estado in ('activa','impago','cancelada')),
  add column if not exists ultimo_cobro   timestamptz,
  add column if not exists proximo_cobro  timestamptz;

-- Cada persona ve SU propia alta (además del admin, que ya la veía).
drop policy if exists cubo_altas_propia_lee on public.cubo_altas;
create policy cubo_altas_propia_lee on public.cubo_altas
  for select using (perfil_id = public.mi_perfil_id());

-- Sin este permiso de tabla, la RLS no llega a filtrar: el usuario logueado
-- (rol `authenticated`) no podía leer NADA de cubo_altas y el portal decía
-- «no vemos tu alta». La política de arriba ya limita a su propia fila.
grant select on public.cubo_altas to authenticated;

commit;
