-- 199 · Cobro del Cubo por persona (no global)
-- Andrés tiene el cobro cerrado a propósito hasta estar seguro de que la
-- opción de pagar le sale SOLO a quien debe. Antes era un interruptor global
-- (cubo_config.cobro_abierto). Ahora cada alta tiene el suyo: por defecto
-- CERRADO; el club lo abre a quien decida (los de prueba y quien no toca se
-- quedan sin ver «Pagar la cuota»). Esto NO cobra nada por sí solo: solo
-- decide a quién le aparece el botón de pago (que es autoservicio con tarjeta).
alter table public.cubo_altas
  add column if not exists cobro_abierto boolean not null default false;

comment on column public.cubo_altas.cobro_abierto is
  'Si true, a esta persona le aparece «Pagar la cuota» en su portal. Por defecto false (de prueba / aún no le toca). Lo abre el club por persona.';
