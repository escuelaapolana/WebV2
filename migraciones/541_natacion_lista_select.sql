-- 541 · natacion_lista se puede LEER (26-nov-2026)
-- La tabla nació (mig 301) con su policy de lectura para admin y responsables
-- de natación, pero sin GRANT SELECT a authenticated: cualquier lectura directa
-- fallaba sin ruido. Por eso «Asistencia por meses» (ficha del nadador y
-- portal/natacion-historial) y la asistencia de la ficha administrativa solo
-- enseñaban los días que NO vino (las ausencias sí se leen). La policy sigue
-- igual: solo admin y responsables de natación/escuela de natación ven filas.
-- La escritura sigue SOLO por el RPC natacion_pasar_lista.
grant select on public.natacion_lista to authenticated;
