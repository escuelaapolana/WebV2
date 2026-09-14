-- 183 · Test drop jump (cajón + salto) y limpieza de claves
-- ------------------------------------------------------------
-- Se quita '30_parado' (lo mismo que desde tacos) y 'test_10_5'
-- (medía lo mismo que el RSI), y se añade 'drop_jump'. El drop jump
-- guarda por intento un par {cajon, salto} en `intentos`, y `mejor`
-- es el mejor salto (cm). Sin datos previos que migrar.
-- ============================================================
begin;
alter table public.test_resultados drop constraint if exists test_resultados_test_check;
alter table public.test_resultados add constraint test_resultados_test_check
  check (test = any (array[
    '30_lanzado','150m','cmj','sj','abalakov','rsi',
    '10m','30m_tacos','60m','300m','1000m','salto_horizontal','balon_medicinal','drop_jump'
  ]));
commit;
