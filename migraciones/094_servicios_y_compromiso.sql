-- ============================================================
-- 094 · «SERVICIOS» y «A QUÉ TE COMPROMETES» · los dos bloques
--       que le faltaban a la ficha de sección
-- ------------------------------------------------------------
-- QUÉ RESUELVE, EN CRISTIANO
--
-- Un grupo de competición no es una cuota más cara: es un trato con
-- dos mitades, y hasta hoy la web no contaba ninguna de las dos.
--
--   · Lo que pone el CLUB: planificación individual, acompañamiento
--     a las competiciones, las inscripciones, el gimnasio, la
--     equipación. Es lo que explica que esa sección cueste lo que
--     cuesta, y no estaba escrito en ningún sitio de la web.
--   · Lo que pone el ATLETA: venir, competir con el club, cuidarse,
--     estar. Tampoco estaba, y es justo lo que diferencia un grupo
--     de competición de un gimnasio.
--
-- En `contenido_secciones` había hueco para «qué incluye»
-- (`puntos_destacados`, la lista corta) y para «qué traer»
-- (`que_traer`, migración 089), pero no para estas dos. Así que el
-- club no lo podía escribir y la web no lo podía enseñar.
--
-- Esta migración abre los dos huecos y ya está: una cosa por línea,
-- igual que las otras dos listas, y editables en Panel → Páginas.
--
-- SON DE LAS OCHO SECCIONES, NO SOLO DE COMPETICIÓN. Las dos casillas
-- salen en todas las páginas del panel. Hoy solo competición tiene
-- algo que decir; el día que montaña quiera contar sus servicios, ya
-- tiene dónde escribirlos sin tocar código.
--
-- MIENTRAS ESTÉN VACÍAS NO SE VE NADA. Ni recuadro en blanco ni
-- «pendiente»: el bloque entero desaparece hasta que alguien del club
-- escriba algo. Es el mismo trato que el resto de la ficha.
--
-- ⚠️ LOS COMPROMISOS NACEN VACÍOS A PROPÓSITO
--   La página de competición de hoy no dice en ninguna parte a qué se
--   compromete un atleta, así que aquí no hay nada que copiar. Y unos
--   compromisos inventados serían peor que el hueco: la gente los
--   leería como si fueran las normas del club. Los escribe el club en
--   el panel, y hasta entonces el bloque no existe.
--
-- SEGURIDAD: no hace falta tocar permisos. `contenido_secciones` ya
-- tiene lectura pública (es el texto de las páginas, que se lee sin
-- cuenta) y escritura solo de administración. Una columna nueva hereda
-- las políticas de la tabla.
--
-- Idempotente: se puede relanzar sin perder nada. Ninguna de las tres
-- partes pisa lo que el club haya escrito desde el panel.
-- Cómo se lanza:
--   bash .secrets/psql.sh -f migraciones/094_servicios_y_compromiso.sql
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LOS DOS HUECOS NUEVOS
-- ------------------------------------------------------------
alter table public.contenido_secciones
  add column if not exists servicios   text,
  add column if not exists compromisos text;

comment on column public.contenido_secciones.servicios is
  'Lo que el club pone de su parte en esta sección: planificación, '
  'acompañamiento a competiciones, inscripciones, material… Una cosa '
  'por línea. Vacío = el bloque no sale en la web.';

comment on column public.contenido_secciones.compromisos is
  'Lo que el club espera de quien entrena en esta sección: asistencia, '
  'competir con el club, cuidarse, actitud… Una cosa por línea. '
  'Vacío = el bloque no sale en la web.';

-- ------------------------------------------------------------
-- 2 · LOS SERVICIOS DE COMPETICIÓN, RESCATADOS DE LA PÁGINA
-- ------------------------------------------------------------
-- Estas seis líneas no son un invento: son exactamente lo que la
-- página /competicion/ enseñaba escrito a mano en su HTML, en el
-- recuadro «Qué incluye». Al unificar la página con la plantilla ese
-- HTML se va, y con él se iría este texto. Así que se guarda donde le
-- toca: en la base, para que el club lo pueda cambiar sin tocar
-- código.
--
-- Solo se escribe si la casilla está vacía: si alguien del club ya la
-- ha rellenado desde el panel, manda lo suyo.
update public.contenido_secciones
   set servicios = $txt$Planificación individualizada por prueba
Entrenadores titulados por la RFEA
Pista del Estadio Joaquín Villar
Gimnasio y container funcional
Inscripción y acompañamiento a competiciones
Equipación oficial del club$txt$
 where seccion = 'competicion'
   and coalesce(btrim(servicios), '') = '';

-- ------------------------------------------------------------
-- 3 · DOS CASILLAS VIEJAS DE COMPETICIÓN QUE AHORA SÍ SE VERÍAN
-- ------------------------------------------------------------
-- POR QUÉ HAY QUE TOCARLAS AHORA Y NO ANTES:
-- la página vieja de competición solo leía de la base el título, el
-- antetítulo, la frase y la foto. Todo lo demás lo llevaba escrito.
-- Con la plantilla, la página lee además `puntos_destacados` (que
-- sale como «Qué incluye») y `precio` (la letra pequeña debajo de los
-- precios). Y en esas dos casillas sigue lo que sembró la migración
-- 011 hace temporadas:
--
--   · `puntos_destacados` = «Para quién / Grupos / Cuota / Prueba /
--     Responsable», que no es una lista de lo que incluye: es el
--     resumen viejo de la cabecera. Hoy ese resumen lo hace sola la
--     tarjeta «De un vistazo», con los grupos y el precio de verdad
--     sacados de la base. Dejarlo sería enseñar dos veces lo mismo, y
--     una de las dos con una cuota congelada de hace dos temporadas
--     y un teléfono suelto bajo el rótulo «Qué incluye».
--   · `precio` = «desde 40 €/mes + socio», un precio escrito a mano
--     que quedaría justo debajo de la tabla de precios de verdad. Si
--     mañana cambia la tarifa, la nota seguiría diciendo 40.
--
-- Se vacían las dos, y SOLO si siguen tal cual las dejó la 011: si el
-- club ha escrito ahí cualquier otra cosa desde el panel, no se toca
-- nada. Vaciarlas no borra información: los cuatro datos que decían
-- (grupos, cuota, prueba y responsable) los pinta hoy la propia
-- página leyéndolos de `grupos`, `tarifas_vigentes` y `contactos_
-- publicos`, que es de donde tienen que salir.
update public.contenido_secciones
   set puntos_destacados = null
 where seccion = 'competicion'
   and puntos_destacados like 'Para quién: federados y populares%';

update public.contenido_secciones
   set precio = null
 where seccion = 'competicion'
   and btrim(precio) = 'desde 40 €/mes + socio';

commit;

-- ============================================================
-- COMPROBACIÓN A MANO (después de lanzarla)
-- ------------------------------------------------------------
-- 1 · Qué tiene escrito cada sección en los dos bloques nuevos.
--     Lo normal hoy: competición con seis servicios y ningún
--     compromiso; las otras siete, a cero en las dos. Los ceros no
--     son un fallo: son bloques que todavía no salen en la web.
select seccion,
       coalesce(array_length(string_to_array(btrim(servicios),   E'\n'), 1), 0) as servicios,
       coalesce(array_length(string_to_array(btrim(compromisos), E'\n'), 1), 0) as compromisos
  from public.contenido_secciones
 order by seccion;

-- 2 · Que en competición no quede ningún precio escrito a mano.
--     Las dos casillas deben salir vacías.
select seccion, precio, puntos_destacados
  from public.contenido_secciones
 where seccion = 'competicion';
