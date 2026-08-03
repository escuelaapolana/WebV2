-- ============================================================
-- 089 · «QUÉ TRAER» · el sexto bloque de la ficha de sección
-- ------------------------------------------------------------
-- QUÉ RESUELVE, EN CRISTIANO
--
-- Las ocho páginas de sección son la misma ficha de siete bloques:
-- foto, para quién es, días y sede, precio con la cuota, quién
-- entrena, QUÉ TRAER y botón de prueba.
--
-- El sexto no existía. En `contenido_secciones` hay un campo para la
-- lista de «qué incluye» (`puntos_destacados`), pero ninguno para la
-- otra lista, la que de verdad pregunta una familia antes del primer
-- día: qué me llevo. Gorro y gafas en natación, zapatillas de clavos
-- en pista, agua y frontal en las salidas de montaña.
--
-- Así que la web no lo podía enseñar y el club no lo podía escribir.
-- Esta migración crea el campo y ya está: una línea por cosa, igual
-- que «Puntos destacados», y editable en Panel → Páginas.
--
-- MIENTRAS ESTÉ VACÍO NO SE VE NADA. La página no enseña un recuadro
-- en blanco ni un «pendiente»: el bloque entero desaparece hasta que
-- alguien del club escriba algo. Es el mismo trato que el resto de la
-- ficha: si el dato no está, no se inventa y no se disimula.
--
-- SEGURIDAD: no hace falta tocar permisos. `contenido_secciones` ya
-- tiene lectura pública (es el texto de las páginas, que se lee sin
-- cuenta) y escritura solo de administración. Una columna nueva hereda
-- las políticas de la tabla.
-- ============================================================

ALTER TABLE public.contenido_secciones
  ADD COLUMN IF NOT EXISTS que_traer text;

COMMENT ON COLUMN public.contenido_secciones.que_traer IS
  'Qué tiene que traer quien viene a probar. Una cosa por línea. Vacío = el bloque no sale en la web.';
