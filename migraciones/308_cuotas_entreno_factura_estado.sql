-- 308 · Estado del cobro del periodo actual en cada cuota de entreno
-- Para que el panel muestre, FIJO en cada tarjeta, si la cuota del periodo
-- (p.ej. octubre) está cobrada / en proceso / pendiente / falló, sin tener que
-- volver a preguntar a Stripe cada vez. Lo rellena entreno-resync al pulsarlo.
alter table public.cuotas_entreno add column if not exists factura_cobro text;
alter table public.cuotas_entreno add column if not exists factura_fecha timestamptz;
