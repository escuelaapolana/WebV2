-- 216 · Cobro del alta de socio por Stripe (adeudo SEPA)
--
-- El alta de socio pasa a cobrarse por Stripe (SEPA de Apolana): al enviar el
-- formulario, la persona paga el importe de alta y el club lo da por bueno cuando
-- Stripe confirma el mandato. Aquí solo se añaden los campos de estado de pago y
-- el importe configurable; el edge `socio-pagar` y el webhook hacen el resto.
--
-- IMPORTE AHORA (hasta el 1-dic): 35 € a todos (prorrateo del resto de temporada).
-- El 125/110 con descuento familiar es del pago de diciembre, que lleva Isa aparte.

-- Estado de pago del alta (por defecto 'pendiente' → la RPC enviar_alta_socio no
-- hay que tocarla: las altas nuevas nacen pendientes de pago).
alter table altas_socio
  add column if not exists pago_estado        text        not null default 'pendiente',  -- pendiente | pagado | fallido
  add column if not exists stripe_session_id  text,
  add column if not exists stripe_pago_ref    text,
  add column if not exists pagado_en          timestamptz,
  -- Familiar de 1ª línea >18 que ya es socio: paga igual ahora, pero el club (Isa)
  -- lo comprueba para el pago de diciembre. Solo informativo.
  add column if not exists es_familiar        boolean     not null default false,
  add column if not exists familiar_nota      text;

-- Importe del alta (en céntimos), editable sin tocar código. 3500 = 35 €.
alter table pagos_config
  add column if not exists precio_alta_socio_cent integer not null default 3500;

update pagos_config set precio_alta_socio_cent = 3500 where id = 1 and precio_alta_socio_cent is null;
