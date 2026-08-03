-- ============================================================
-- 090 · LAS PRUEBAS DE CADA GRUPO · que la pista se lea como pista
-- ------------------------------------------------------------
-- QUÉ RESUELVE, EN CRISTIANO
--
-- En la ficha de sección, cada grupo se presenta con su nombre, sus
-- días y una frase de qué se hace. Eso vale para running o para
-- montaña, donde el grupo se explica solo. En pista no: «Velocidad A»
-- no le dice nada a quien no es del mundillo, y lo que de verdad
-- distingue a un grupo de otro son las pruebas que se entrenan —
-- 60 m, 100 m, vallas, peso, longitud, cross.
--
-- Esa lista no existía en ninguna parte de la base. Estaba escrita a
-- mano en la página de competición, que es justo lo que se está
-- quitando de todas las secciones: el día que un grupo cambia de
-- pruebas, nadie se acuerda de tocar el HTML.
--
-- Aquí se crea el campo. Una prueba por línea, o separadas por barra
-- vertical: se pintan como pastillas debajo de la descripción del
-- grupo, con el mismo `.chip` que ya usa el resto de la web.
--
-- MIENTRAS ESTÉ VACÍO NO SE VE NADA. Ni pastillas de ejemplo ni un
-- hueco esperando. Hoy está vacío en los treinta y tantos grupos, así
-- que esta migración no cambia una sola pantalla; en cuanto alguien
-- del club escriba «60 m · 100 m · vallas» en Panel → Grupos, sale.
--
-- NO ES SOLO PARA COMPETICIÓN. Sirve igual para natación («crol,
-- espalda, virajes») o para montaña («cuestas, técnica de bajada»).
-- Es el campo que le faltaba a la ficha para describir un grupo sin
-- escribir un párrafo.
--
-- SEGURIDAD: no hace falta tocar permisos. `grupos` ya tiene lectura
-- pública (son los horarios que se enseñan sin cuenta) y escritura
-- solo de administración. Una columna nueva hereda las políticas.
-- ============================================================

ALTER TABLE public.grupos
  ADD COLUMN IF NOT EXISTS pruebas text;

COMMENT ON COLUMN public.grupos.pruebas IS
  'Las pruebas o contenidos que entrena el grupo. Una por línea (o separadas por |). Se pintan como pastillas. Vacío = no salen.';
