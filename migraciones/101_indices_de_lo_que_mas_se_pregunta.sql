-- ============================================================
-- 101 · Dos índices: los de lo que más se pregunta
-- ------------------------------------------------------------
-- QUÉ ES UN ÍNDICE, EN CRISTIANO
-- El índice de un libro. Sin él, para saber en qué página habla de
-- «Apolana» hay que pasar el libro entero, hoja por hoja. Con él, se
-- va directo. La base hace lo mismo: sin índice, para encontrar una
-- fila recorre TODA la tabla.
--
-- No se ponen a mansalva. Cada índice hay que mantenerlo al día cada
-- vez que se escribe algo, así que uno de más hace las altas y las
-- modificaciones un poco más lentas y ocupa sitio. Solo se pone donde
-- la base está pasando el libro entero muchas veces al día.
--
-- ------------------------------------------------------------
-- 1 · `perfiles` por correo · EL IMPORTANTE
-- ------------------------------------------------------------
-- Cada vez que alguien pide CUALQUIER cosa a la base estando dentro de
-- su cuenta, lo primero que hace la base es preguntarse «¿y tú quién
-- eres?». Y lo pregunta así, buscando por el correo:
--
--     select id from perfiles where email = (el correo de quien pregunta)
--
-- No es una consulta de una pantalla suelta: está DENTRO de las reglas
-- de seguridad. Las funciones `mi_perfil_id()`, `es_admin()`,
-- `es_staff()`, `es_tesoreria()`, `es_junta()` y compañía buscan todas
-- por ahí, y esas funciones se llaman en casi todas las reglas de casi
-- todas las tablas. Abrir la ficha de un hijo son quince consultas, y
-- cada una vuelve a preguntar quién eres.
--
-- Lo que llevaba contado la base cuando se escribió esto:
--
--     perfiles ... 714.350 recorridos completos · 7.401.341 filas leídas
--
-- Y `perfiles` solo tenía un índice: el de la clave, por `id`. Por
-- correo, ninguno.
--
-- AVISO PARA QUIEN LO COMPRUEBE HOY Y NO VEA NINGUNA MEJORA
-- Hoy hay 15 perfiles. Con 15 filas la base seguirá recorriendo la
-- tabla entera aunque el índice esté puesto, y hace bien: leer 15
-- filas de un tirón es más rápido que consultar el índice y luego ir a
-- buscarlas. Esto NO es un índice inútil: es un índice puesto a
-- tiempo. En cuanto el club llegue a las 200 o 300 familias, la misma
-- consulta pasa a leer 300 filas en vez de 15 —veinte veces más, y
-- multiplicado por los millones de veces que se hace— y ese día la
-- base empieza a usarlo sola, sin tocar nada.
--
-- SE HA MIRADO SI DEBÍA SER ÚNICO Y SE HA DEJADO NORMAL
-- El código da por hecho que un correo = una cuenta = una fila. Un
-- índice único lo obligaría además de acelerarlo. Pero eso cambia cómo
-- se comporta la base al escribir (un alta duplicada pasaría de colarse
-- a dar error), y eso es una decisión del club, no de un índice. Queda
-- anotado; aquí solo se acelera la lectura.
--
-- ------------------------------------------------------------
-- 2 · `sesiones` por grupo y fecha
-- ------------------------------------------------------------
-- La otra pregunta que recorre la tabla entera es «¿qué entrenamientos
-- tiene este grupo de aquí en adelante?». La hace la ficha del hijo en
-- la zona de familia (a través de la vista `sesiones_agenda`), el
-- calendario y las pantallas del entrenador, y también las propias
-- reglas de seguridad de `sesiones`, que filtran por `grupo_id`.
--
--     sesiones ... 631 recorridos completos · 163.505 filas leídas
--                  (258 filas leídas por consulta, de 361 que hay:
--                   se lee la tabla casi entera para quedarse con
--                   los entrenamientos de UN grupo)
--
-- `sesiones` ya tenía índice por fecha y por microciclo, pero ninguno
-- por grupo, que es por donde se pregunta siempre. Va por los dos
-- campos y en este orden —primero el grupo, después la fecha— porque
-- así vale para las dos formas de preguntar: «los de este grupo» y
-- «los de este grupo a partir de tal día». Al revés no valdría para la
-- primera.
--
-- Esto sigue haciendo falta después de la migración 100 (las familias
-- ya no ven el contenido del entrenamiento): lo que se cerró es QUÉ
-- campos se leen, no la búsqueda. El calendario del hijo sale igual de
-- `sesiones_agenda`, y esa vista sigue preguntando por grupo y fecha.
--
-- ------------------------------------------------------------
-- LO QUE SE HA MIRADO Y SE HA DEJADO COMO ESTÁ
-- ------------------------------------------------------------
-- Se han repasado las estadísticas reales de la base
-- (`pg_stat_user_tables` y `pg_stat_user_indexes`), no una corazonada:
--
--   · `grupos` (47 filas), `avisos` (6), `imagenes_web` (74),
--     `cubo_clases` (55): se recorren enteras muchas veces, pero son
--     tan pequeñas que un índice sería más trabajo que provecho. La
--     base las lee de un bocado y ya está.
--   · `atletas`, `pagos`, `marcas_atleta`, `registros_sesion`,
--     `cubo_movimientos`, `cubo_reservas`, `test_resultados`: ya
--     tienen índices por donde se las pregunta, y se ve que los usan.
--   · Hay bastantes índices que no se han usado NUNCA (pantallas que
--     casi no se abren todavía). No se tocan: son de tablas que aún no
--     tienen datos de verdad, y borrarlos ahora sería adivinar.
--
-- Total: dos índices. Ni uno más.
--
-- Todo el archivo se puede volver a pasar las veces que haga falta.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · Quién eres, por tu correo
-- ------------------------------------------------------------
create index if not exists idx_perfiles_email
  on public.perfiles (email);

comment on index public.idx_perfiles_email is
  'La pregunta «¿quién eres?» por correo. La hacen mi_perfil_id(), es_admin(), es_staff() y demás, y esas van dentro de las reglas de casi todas las tablas: es la consulta más repetida del sistema.';

-- ------------------------------------------------------------
-- 2 · Los entrenamientos de un grupo, de una fecha en adelante
-- ------------------------------------------------------------
create index if not exists idx_sesiones_grupo_fecha
  on public.sesiones (grupo_id, fecha);

comment on index public.idx_sesiones_grupo_fecha is
  'Los entrenamientos de un grupo, sueltos o de una fecha en adelante. Lo piden la ficha del hijo (vista sesiones_agenda), el calendario, las pantallas del entrenador y las propias reglas de sesiones.';

commit;

-- Se le dice a la base que vuelva a mirar cómo son estas dos tablas,
-- para que tenga en cuenta los índices nuevos desde ya y no cuando le
-- toque el repaso automático.
analyze public.perfiles;
analyze public.sesiones;
