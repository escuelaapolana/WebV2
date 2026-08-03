-- ============================================================
-- 098 · LA ESCUELA YA TIENE HORA Y SITIO
-- ------------------------------------------------------------
-- QUÉ FALTABA
--
-- La migración 097 desdobló la escuela en dieciocho grupos y les puso los
-- días, que era lo único que constaba entonces. La hora y la sede se
-- quedaron en blanco a propósito: una hora puesta a ojo manda a una
-- familia a la pista cuando no toca.
--
-- Ahora constan, y no de oídas. Están escritas en dos sitios que el club
-- usa todos los días:
--
--   · En el formulario de inscripción a la escuela, como opciones que
--     marca la familia: «Lunes/miércoles 17:30 a 18:30 (nacidos entre
--     2023 y 2015, ambos inclusive)» y la misma de martes y jueves.
--   · En el correo de confirmación que se le manda después: «nacidos
--     entre 2023 y 2015 (ambos inclusive): lunes y miércoles o martes y
--     jueves de 17:30 a 18:30», en el Estadio de Atletismo Joaquín
--     Villar.
--
-- El tramo 2023-2015 es EXACTAMENTE el de los nueve colores (rojo 1 es
-- el de 2023 y verde 3 el de 2015), así que la misma hora vale para los
-- dieciocho. No hay que repartir nada ni suponer nada.
--
-- CON EL MISMO FORMATO QUE LOS DE PISTA, que ya lo tienen bien:
-- «Lunes y miércoles 17:30-18:30 · Estadio Joaquín Villar». Ese formato
-- no es decorativo: de ese texto salen solas las franjas de
-- `grupo_horarios` (día, hora de inicio, hora de fin y sitio), y de ahí
-- el cuadro de horarios de la web y los entrenos que se generan en el
-- calendario. Escrito de otra manera, se queda como un texto suelto que
-- no alimenta nada.
--
-- LO QUE SIGUE SIN CONSTAR NO SE TOCA: la hora del «Grupo recreativo» de
-- segunda hora y quién lleva cada grupo. Eso lo pone el club.
--
-- Y CÓMO SE ENTRA. El correo del club añade un detalle que el primer día
-- se agradece: se entra por el parking de la Escuela Infantil
-- Montessori. Eso no es el horario de ningún grupo —es igual para los
-- dieciocho— así que meterlo en la tarjeta de cada uno sería repetirlo
-- dieciocho veces y cargar lo que se lee de un vistazo. Va una sola vez,
-- debajo de los grupos, y para eso se le hace sitio en la ficha de la
-- sección.
--
-- Idempotente: la hora solo se escribe donde está en blanco, así que
-- volver a pasarla no pisa nada de lo que haya corregido el club.
-- ============================================================


-- ------------------------------------------------------------
-- 1 · LA HORA Y LA SEDE DE LOS DIECIOCHO
-- ------------------------------------------------------------
-- Cada grupo hereda el texto de su turno. Solo se rellena si está
-- vacío: si el club ya le ha escrito un horario a alguno, manda el suyo.
update public.grupos
   set horario = case turno
                   when 'lunes-miercoles' then 'Lunes y miércoles 17:30-18:30 · Estadio Joaquín Villar'
                   when 'martes-jueves'   then 'Martes y jueves 17:30-18:30 · Estadio Joaquín Villar'
                 end
 where seccion = 'escuela'
   and turno in ('lunes-miercoles', 'martes-jueves')
   and coalesce(btrim(horario), '') = '';

-- Las franjas de `grupo_horarios` las rellena sola la base al guardar el
-- texto (disparador `trg_grupos_resincroniza`). No hay que escribirlas
-- aquí, y hacerlo a mano acabaría en dos versiones del mismo dato.


-- ------------------------------------------------------------
-- 2 · UN SITIO PARA DECIR CÓMO SE ENTRA
-- ------------------------------------------------------------
-- Ninguna de las casillas que ya había sirve para esto sin mentir sobre
-- lo que es. «Horarios» significa otra cosa (y en la portada significa
-- una tercera). «Qué incluye» es lo que trae la cuota. «Servicios» es lo
-- que el club hace por el atleta. Cómo se llega a la puerta no es nada
-- de eso, así que tiene casilla propia y se llama por su nombre.
alter table public.contenido_secciones
  add column if not exists acceso text;

comment on column public.contenido_secciones.acceso is
  'Cómo se llega y por dónde se entra a la sede de la sección. Sale como una línea debajo de los grupos. Vacío, no aparece nada.';

-- Solo se escribe si está en blanco, como todo lo demás aquí.
update public.contenido_secciones
   set acceso = 'Se entra por el parking de la Escuela Infantil Montessori.'
 where seccion = 'escuela'
   and coalesce(btrim(acceso), '') = '';


-- ------------------------------------------------------------
-- 3 · EL RESUMEN VIEJO DE HORARIOS, QUE DECÍA OTRA HORA
-- ------------------------------------------------------------
-- En la ficha de la sección había escrito «Lun/Mie o Mar/Jue 17:00-19:00h».
-- No sale en la web (esa casilla ya no se pinta en las páginas de
-- sección), pero sí la ve quien entra a Panel → Páginas, y ahí una hora
-- vieja se copia y se manda por correo. Se corrige con la buena y con
-- las mismas palabras que usa el club.
--
-- Solo si sigue diciendo exactamente lo que decía: si alguien ya lo ha
-- cambiado, se respeta lo suyo.
update public.contenido_secciones
   set horarios = 'Lunes y miércoles o martes y jueves, de 17:30 a 18:30'
 where seccion  = 'escuela'
   and horarios = 'Lun/Mie o Mar/Jue 17:00-19:00h';
