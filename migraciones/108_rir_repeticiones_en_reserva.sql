-- ============================================================
-- 108 · RIR · las repeticiones que te quedaban
-- ------------------------------------------------------------
-- DE DÓNDE SALE
-- El dueño del club, mirando su propia planificación: «lo de RIR
-- es importante». Y luego, precisando: «RIR en cada ejercicio, no
-- al final de la sesión».
--
-- El RIR es CÓMO ESTE CLUB REGULA LA FUERZA. Su programa de ocho
-- semanas lo lleva de eje: semana 1 a RIR 3-4, semanas 2-6 la
-- mayoría a RIR 1-3, semana 7 sin fallo en los básicos, semana 8
-- vuelta a RIR 3-4. Hasta hoy eso vivía dentro del texto de las
-- observaciones, mezclado con todo lo demás.
--
-- ============================================================
-- NO ES EL RPE, Y NO SE PUEDEN MEZCLAR
-- ------------------------------------------------------------
--   · `registros_sesion.rpe` (1-10) dice LO DURO QUE SE HIZO. Es
--     una impresión del día entero y ya existía.
--   · El RIR dice CUÁNTAS REPETICIONES TE QUEDABAN al acabar la
--     serie. Es de CADA EJERCICIO y se apunta mientras se hace.
--
-- Por eso el RIR NO se pregunta al terminar el entrenamiento. Una
-- pregunta del tipo «¿cómo has ido de RIR hoy?» sería otra vez el
-- RPE con otro nombre, y encima borraría lo único que lo hace
-- útil: que en sentadilla te quedaras a 4 y en press banca
-- llegaras a 0 son dos datos distintos y los dos importan.
--
-- ⚠️ Y VA AL REVÉS QUE EL ESFUERZO: más RIR es MÁS SUAVE (te
-- sobraban repeticiones); RIR 0 es el fallo. Quien lea estos
-- números creyendo que más es más duro los entenderá al revés, y
-- son números pequeños que no chirrían.
--
-- ============================================================
-- POR QUÉ ESTA MIGRACIÓN NO CREA NI UNA COLUMNA
-- ------------------------------------------------------------
-- Porque no hace falta ninguna, y añadirla por costumbre sería
-- peor. Las dos mitades del RIR caben donde ya vive lo suyo:
--
-- 1 · EL OBJETIVO que pone el entrenador va en la fila del
--     entrenamiento, dentro de `sesiones.bloques`, que es jsonb:
--
--       { "ejercicio": "Press banca", "series": "4",
--         "distancia": "8 rep", "carga": "80% RM",
--         "rir": "2-3" }                    <-- lo nuevo
--
--     Al lado de `carga` a propósito: las dos dicen con cuánta
--     intensidad se hace ESE ejercicio.
--
-- 2 · EL REAL que apunta el atleta va en cada serie, dentro de
--     `registros_sesion.tiempos_reales`, que también es jsonb:
--
--       { "<uuid de la fila>": {
--           "ejercicio":    "Press banca",
--           "rir_objetivo": "RIR 2-3",      <-- lo que se le pidió
--           "medida":       "peso_reps",
--           "series":  [ {"hecha":true,"peso":"60","reps":"11","rir":"2"} ],
--           "tiempos": [ "60 kg × 11 rep · RIR 2" ]
--         } }
--
--     `rir_objetivo` se guarda con lo apuntado y no se lee de la
--     sesión al vuelo, y eso es deliberado: es la FOTO de lo que
--     se le pidió aquel día. Si el entrenador cambia el objetivo
--     de esa fila la semana que viene, lo que el atleta leyó el
--     martes no se reescribe (migración 099, el historial no se
--     reescribe).
--
-- Lo que sí hace esta migración es DEJARLO ESCRITO en los
-- comentarios de las dos tablas. En un jsonb no hay esquema que
-- mirar: si la forma del dato no está contada en algún sitio, el
-- siguiente que llegue tiene que deducirla leyendo JavaScript.
--
-- ============================================================
-- LO QUE NO SE HACE, Y ES A PROPÓSITO
-- ------------------------------------------------------------
-- NADA DE PROGRESIÓN AUTOMÁTICA. El programa del club dice cosas
-- como «al alcanzar el máximo de repeticiones en todas las
-- series, subir 2-5 % de peso», y es tentador convertir eso en
-- una regla. No se hace: el club no lo ha pedido, y decidir por
-- un entrenador cuánto peso le sube a alguien es meterse donde no
-- nos llaman. El dato queda ahí; que lo lea él y decida.
--
-- Tampoco se valida el RIR en la base. Un atleta puede apuntar un
-- 7 donde se le pidió 2: eso no es un error de datos, es
-- información —se quedó muy corto— y la pantalla del entrenador
-- lo marca para que lo vea. Rechazarlo sería perderlo.
--
-- IDEMPOTENTE: son solo comentarios. No toca datos ni estructura.
-- ============================================================

begin;

comment on column public.sesiones.bloques is
  'Los bloques del entrenamiento, en jsonb. Cada fila lleva: `id` (uuid estable, '
  'migración 103), `ejercicio`, `series`, `distancia`, `ritmo`, `carga` («80% RM»), '
  '`rir` (repeticiones en reserva objetivo: «2», «2-3», «sin fallo» — migración 108), '
  '`rec` (recuperación normalizada), `descanso` (el texto de siempre), `desnivel_m`, '
  '`calzado`, `material`, `detalle` y `observaciones`. '
  'El RIR va POR EJERCICIO, nunca por sesión: en un mismo día conviven «RIR 2-3» en '
  'un ejercicio y «sin fallo» en otro.';

comment on column public.registros_sesion.tiempos_reales is
  'Lo que el atleta apuntó, en jsonb, con una entrada por ejercicio y la llave del '
  '`id` de su fila (migración 103). Dentro: `ejercicio` (lo que mandó el entrenador), '
  '`cambiado_por` (lo que hizo de verdad, migración 104), `rir_objetivo` (el RIR que '
  'se le pidió aquel día, migración 108), `anadido_por_atleta` (lo que hizo de más y '
  'nadie le puso, migración 107), `medida`, `unidad`, `series` (una por serie, con '
  '`hecha` y los campos `peso`/`reps`/`rir`/`tiempo`/`distancia`) y `tiempos` (la '
  'línea ya montada y legible, «60 kg × 11 rep · RIR 2», que leen las pantallas que '
  'no entienden `series`). '
  'OJO CON EL RIR: más RIR es MÁS SUAVE; RIR 0 es el fallo. Y no es el `rpe` de esta '
  'misma tabla, que es la impresión del día entero del 1 al 10.';

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- qué ejercicios llevan RIR objetivo puesto
--   select f->>'ejercicio' as ejercicio, f->>'rir' as rir, count(*)
--     from sesiones s, jsonb_array_elements(s.bloques) b,
--          jsonb_array_elements(b->'filas') f
--    where f->>'rir' is not null group by 1,2 order by 3 desc;
--
--   -- objetivo contra lo que apuntó cada uno, serie a serie
--   select r.atleta_id, e.value->>'ejercicio' as ejercicio,
--          e.value->>'rir_objetivo' as objetivo, s->>'rir' as hizo
--     from registros_sesion r, jsonb_each(r.tiempos_reales) e,
--          jsonb_array_elements(e.value->'series') s
--    where e.value->>'rir_objetivo' is not null and s->>'rir' is not null;
-- ------------------------------------------------------------
