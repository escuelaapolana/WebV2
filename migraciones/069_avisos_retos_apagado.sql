-- ============================================================
-- 069 · Los avisos de retos nacen apagados
-- ------------------------------------------------------------
-- El diseñador fija en la maqueta 44b qué avisos vienen puestos
-- de serie y cuáles no:
--
--   Cambios en mi entreno .... activado
--   Competiciones ............ activado
--   Pagos .................... activado
--   Noticias del club ........ apagado
--   Mis retos ................ APAGADO
--
-- «Mis retos» estaba con `default true` en la tabla y, además,
-- `avisos_quiere()` respondía que sí cuando la persona no tenía
-- fila todavía. O sea: quien no abriera nunca la pantalla de
-- avisos recibiría notificaciones de retos sin haberlas pedido.
-- Justo lo contrario de lo que dice el diseño, y de la idea de
-- que los retos son algo personal y silencioso.
--
-- Idempotente.
-- ============================================================

alter table public.avisos_preferencias
  alter column retos set default false;

-- Y a quien ya tuviera fila se le deja apagado también: nadie ha
-- podido elegir que sí todavía, porque la pantalla acaba de salir.
update public.avisos_preferencias set retos = false where retos is true;
