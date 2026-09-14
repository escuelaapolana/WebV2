-- 181 · Ampliar los tests permitidos en test_resultados
-- ------------------------------------------------------------
-- La batería de «Mis tests» pasa de 7 a 15 pruebas (velocidad corta,
-- fondo corto, salto horizontal, balón medicinal, test 10/5). El
-- catálogo del front ya las tiene; aquí se abre el CHECK para que la
-- base deje guardarlas.
-- ============================================================
begin;
alter table public.test_resultados drop constraint if exists test_resultados_test_check;
alter table public.test_resultados add constraint test_resultados_test_check
  check (test = any (array[
    '30_lanzado','30_parado','150m','cmj','sj','abalakov','rsi',
    '10m','30m_tacos','60m','300m','1000m','salto_horizontal','balon_medicinal','test_10_5'
  ]));
commit;
