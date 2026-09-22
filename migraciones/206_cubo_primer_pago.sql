-- ============================================================
-- 206 · El Cubo · «primer pago» por persona
-- ------------------------------------------------------------
-- El club decide, persona a persona, cuánto paga la PRIMERA vez al
-- activar su cuota (p. ej. 10 € de entrada de septiembre, que empezaron
-- a entrenar el día 21 y no es mes completo). Ese primer pago se cobra
-- al activar (y de paso guarda la tarjeta). A partir de ahí, la cuota
-- entera se cobra sola el día 5 de cada mes.
--   · null  → se usa el valor por defecto (1000 = 10 €) en la función.
--   · Importe en CÉNTIMOS, como el resto de importes de Stripe.
-- ============================================================

alter table public.cubo_altas
  add column if not exists primer_pago_cent integer;

comment on column public.cubo_altas.primer_pago_cent is
  'Importe (céntimos) del primer pago al activar la cuota; lo pone el club por persona. null = por defecto 10 €.';
