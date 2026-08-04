-- ============================================================
-- 103 · Lo que NO se hizo, y con qué unidad se apunta lo que sí
-- ------------------------------------------------------------
-- EL PROBLEMA, EN UNA FRASE
-- Un atleta podía contar cómo le fue el entrenamiento, pero no
-- podía decir «esto no lo hice». Ni el entrenamiento entero ni un
-- ejercicio suelto. Lo único a su alcance era escribirlo en la
-- nota libre y esperar que alguien la leyera.
--
-- POR QUÉ IMPORTA MÁS DE LO QUE PARECE
-- El historial del atleta dice «41 días entrenados». Si de esos 41
-- hay ocho en los que solo se hizo la mitad, ese número miente, y
-- miente HACIA ARRIBA, que es la peor dirección: parece que el
-- chaval entrenó más de lo que entrenó. Y para el entrenador
-- cambia la lectura: si alguien lleva tres semanas saltándose
-- siempre el core, eso es un dato, no un descuido.
--
-- MARCAR SÍ, BORRAR NO
-- El atleta no puede quitar un ejercicio ni un entrenamiento. Si
-- borrase, se perdería justo la información que el club quiere:
-- que ese ejercicio estaba puesto y no se hizo. Aquí no hay nada
-- que borre; solo cosas que se marcan.
--
-- ============================================================
-- PARTE 1 · CÓMO SE SEÑALA «EL EJERCICIO 4 DEL BLOQUE 2» SIN QUE
--           SE ROMPA CUANDO EL ENTRENADOR EDITE EL ENTRENAMIENTO
-- ------------------------------------------------------------
-- Hasta hoy los tiempos por serie se guardaban con una llave de
-- POSICIÓN: `b1f3` quiere decir «bloque 1, fila 3». Y la posición
-- se mueve. Si el entrenador mete un ejercicio nuevo en medio, el
-- que era `b1f3` pasa a ser `b1f4`, y todo lo que el atleta apuntó
-- se desplaza una fila. A partir de ese momento el historial
-- MIENTE sin que nadie lo note: los kilos de la sentadilla
-- aparecen colgando de las dominadas.
--
-- Con los tiempos ya era malo. Con «esto no lo hice» sería peor,
-- porque una marca desplazada acusa a un ejercicio que sí se hizo.
--
-- LA SOLUCIÓN: cada fila de `sesiones.bloques` lleva desde ahora
-- su propio `id`, un uuid que se le pone UNA vez y no cambia
-- nunca. El atleta apunta contra ese id, no contra la posición.
-- El entrenador puede reordenar los bloques, meter ejercicios en
-- medio o quitar otros: lo que el atleta marcó sigue pegado a su
-- ejercicio.
--
-- SE PONE EN LA BASE, NO EN LA PANTALLA, y a propósito: hay SEIS
-- sitios que escriben `bloques` (el planificador, el importador de
-- texto, el de hoja de cálculo, el duplicador de semanas, el
-- generador automático y la pantalla de calles). Si el id se
-- pusiera en cada uno, el día que alguien añada el séptimo se
-- quedaría sin ponerlo y nadie se enteraría hasta meses después.
-- El disparador lo pone siempre, escriba quien escriba.
--
-- LO QUE EL DISPARADOR NO PUEDE ARREGLAR SOLO
-- Si una pantalla REHACE la fila desde cero al guardar (leer los
-- campos del formulario y armar un objeto nuevo), el id se pierde
-- por el camino y el disparador le pone uno nuevo, creyendo que es
-- una fila nueva. Eso pasaba en el editor del entrenador, y se ha
-- arreglado allí: la fila arrastra su id en el formulario. Queda
-- dicho aquí porque es la trampa en la que volvería a caer
-- cualquiera que monte otro editor de entrenamientos.
--
-- Y UNA HONESTIDAD MÁS: el id sobrevive a que muevan la fila, pero
-- no puede saber si el entrenador ha cambiado el EJERCICIO de esa
-- fila (borrar «Sentadilla» y escribir «Press banca» encima). Por
-- eso lo que el atleta guarda lleva también el NOMBRE del
-- ejercicio: si algún día el nombre guardado y el de la fila no
-- coinciden, la pantalla enseña lo que el atleta apuntó tal cual,
-- sin colgárselo al ejercicio nuevo.
--
-- ============================================================
-- PARTE 2 · QUÉ SE GUARDA CUANDO SE MARCA
-- ------------------------------------------------------------
-- No hace falta tabla nueva. `registros_sesion.tiempos_reales` ya
-- es jsonb y ya guarda una entrada por ejercicio con la lista de
-- lo que se hizo en cada serie. Se le añaden campos DENTRO, que es
-- lo barato, y no se quita ninguno de los que ya están.
--
-- LA FORMA DE ANTES (que se sigue escribiendo y se sigue leyendo):
--
--   { "b1f3": { "ejercicio": "6 × 400",
--               "tiempos": ["68.2", "67.9", ""] } }
--
-- LA FORMA DE AHORA:
--
--   { "<uuid de la fila>": {
--       "fila_id":   "<el mismo uuid>",
--       "ejercicio": "Media sentadilla",
--       "medida":    "peso_reps" | "tiempo" | "distancia",
--       "unidad":    "kg" | "m" | "km" | null,
--       "series": [
--          { "hecha": true,  "peso": 60, "reps": 11 },
--          { "hecha": true,  "peso": 60, "reps": 10 },
--          { "hecha": false }                          <-- esta NO se hizo
--       ],
--       "tiempos": ["60 kg × 11", "60 kg × 10", ""]    <-- el campo de siempre
--     } }
--
-- POR QUÉ SE SIGUE ESCRIBIENDO `tiempos`
-- Hay cuatro pantallas que lo leen (el feedback del entrenador, la
-- carga, las calles de la piscina y los retos). Si se dejara de
-- escribir, esas cuatro se quedarían en blanco el mismo día del
-- despliegue. Se escribe la línea ya montada y legible («60 kg ×
-- 11»), así que aunque una pantalla vieja no entienda `series`,
-- enseña algo cierto en vez de nada.
--
-- LA SERIE SIN ✓ ES LA QUE NO SE HIZO
-- No hay un botón aparte de «no hecho». Se marca lo que se hace,
-- que es el gesto natural a pie de máquina, y lo que queda sin
-- marcar se lee solo. Un botón de «no lo hice» obligaría a tocar
-- dos veces para decir lo mismo.
--
-- ============================================================
-- PARTE 3 · LA UNIDAD, QUE ES LO QUE HACE QUE UN NÚMERO SEA UN DATO
-- ------------------------------------------------------------
-- «200» no es un dato: no se sabe si son metros, segundos o kilos.
-- Dentro de seis meses, el historial entero se vuelve inservible.
--
-- La unidad la pone el sistema, no el atleta: sale del deporte del
-- entrenamiento (migración 102) y de lo que el entrenador escribió
-- en la fila. En fuerza son kilos y repeticiones; en natación,
-- metros y tiempo; en atletismo, tiempo, y la distancia se puede
-- decir en metros o en kilómetros porque un rodaje se dice «10 km»
-- y no «10.000 m».
--
-- REGLA QUE MANDA SOBRE TODO LO DEMÁS: lo que escribe el
-- entrenador se enseña TAL COMO LO ESCRIBIÓ. El sistema añade
-- claridad, no reinterpreta. Nada de convertir kilómetros a metros
-- por detrás, que es donde salen los errores de mil; y nada de
-- promediar un rango («45-60 s») para enseñar un número que no
-- dijo nadie («53"»).
--
-- Esa parte no es SQL: vive en assets/js/descansos.js, que es el
-- sitio donde las cinco pantallas se ponen de acuerdo en cómo se
-- escriben las cosas. Queda apuntado aquí para que quien lea esta
-- migración sepa dónde mirar.
--
-- ============================================================
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta: las columnas se crean
-- si faltan, las funciones se reemplazan, y el relleno de ids solo
-- toca las filas que todavía no lo tienen.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · EL ID ESTABLE DE CADA FILA
-- ------------------------------------------------------------
-- Recorre `bloques` y le pone `id` a cada fila que no lo tenga.
-- A las que ya lo tienen no las toca: ese id es la única cuerda
-- que une lo que el atleta apuntó con el ejercicio al que lo
-- apuntó, y cambiarlo sería perderlo.
create or replace function public.apo_bloques_con_id(p_bloques jsonb)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_bloques jsonb;
  v_bloque  jsonb;
  v_fila    jsonb;
  v_filas   jsonb;
  v_salida  jsonb := '[]'::jsonb;
begin
  if p_bloques is null or jsonb_typeof(p_bloques) <> 'array' then
    return p_bloques;
  end if;

  for v_bloque in select * from jsonb_array_elements(p_bloques) loop
    v_filas := '[]'::jsonb;

    if jsonb_typeof(v_bloque -> 'filas') = 'array' then
      for v_fila in select * from jsonb_array_elements(v_bloque -> 'filas') loop
        -- Solo se pone si falta. Una fila vacía («{}») también lo
        -- lleva: hoy no es nada, pero mañana el entrenador escribe
        -- un ejercicio encima y ya viene con su identidad puesta.
        if jsonb_typeof(v_fila) = 'object'
           and (v_fila -> 'id' is null or v_fila ->> 'id' = '') then
          v_fila := v_fila || jsonb_build_object('id', gen_random_uuid()::text);
        end if;
        v_filas := v_filas || jsonb_build_array(v_fila);
      end loop;
      v_bloque := v_bloque || jsonb_build_object('filas', v_filas);
    end if;

    v_salida := v_salida || jsonb_build_array(v_bloque);
  end loop;

  return v_salida;
end;
$$;

comment on function public.apo_bloques_con_id(jsonb) is
  'Le pone a cada fila de `sesiones.bloques` un id propio que no cambia nunca, '
  'para que lo que el atleta apunta (tiempos, kilos, y las series que no hizo) '
  'siga pegado a SU ejercicio aunque el entrenador reordene el entrenamiento o '
  'meta otro ejercicio en medio. Nunca pisa un id que ya esté puesto.';

-- El disparador: se pone escriba quien escriba, porque hay seis
-- pantallas que guardan `bloques` y ninguna debería tener que
-- acordarse de esto.
-- ⚠️ `security definer` NO ES OPCIONAL, y esta migración se entregó sin
-- ello: `apo_bloques_con_id` nace cerrada (migración 090), y sin esta
-- línea el entrenador NO PODÍA GUARDAR UN ENTRENAMIENTO. Se corrigió en
-- la migración 106, y se arregla también aquí para que volver a lanzar
-- este fichero no vuelva a romperlo. El `search_path` clavado va con
-- ello: un `security definer` sin él es un agujero.
create or replace function public.apo_sesiones_ids_de_fila()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  new.bloques := public.apo_bloques_con_id(new.bloques);
  return new;
end;
$$;

drop trigger if exists trg_sesiones_ids_de_fila on public.sesiones;
create trigger trg_sesiones_ids_de_fila
  before insert or update on public.sesiones
  for each row execute function public.apo_sesiones_ids_de_fila();

-- Relleno de lo que ya está guardado. `is distinct from` evita
-- reescribir las que ya venían completas: sin eso, una segunda
-- pasada tocaría las 356 filas para dejarlas igual.
update public.sesiones
   set bloques = public.apo_bloques_con_id(bloques)
 where bloques is not null
   and public.apo_bloques_con_id(bloques) is distinct from bloques;

-- ------------------------------------------------------------
-- 2 · CUÁNTO SE HIZO DE VERDAD
-- ------------------------------------------------------------
-- Estas columnas NO son un dato nuevo que alguien tenga que
-- rellenar: son el recuento de lo que ya está en `tiempos_reales`,
-- sacado por la base para que las pantallas no tengan que abrir el
-- jsonb cada vez que quieran saber si un día se hizo entero.
--
-- Y sobre todo: para que el resumen del historial pueda decir la
-- verdad sin hacer 41 cuentas por atleta.
alter table public.registros_sesion add column if not exists series_previstas integer;
alter table public.registros_sesion add column if not exists series_hechas    integer;
alter table public.registros_sesion add column if not exists estado           text;
alter table public.registros_sesion add column if not exists motivo_no_hecho  text;
alter table public.registros_sesion add column if not exists nota_no_hecho    text;

comment on column public.registros_sesion.series_previstas is
  'Cuántas series mandaba el entrenador ese día, contadas sobre `sesiones.bloques` '
  'en el momento de guardar. Es una foto: si el entrenador edita el entrenamiento '
  'después, esta cifra sigue diciendo contra qué se comparó lo que el atleta hizo '
  '(migración 099: el historial no se reescribe).';
comment on column public.registros_sesion.series_hechas is
  'Cuántas de esas series marcó el atleta como hechas. La serie sin marcar es la '
  'que no se hizo: no hay botón de «no lo hice», se marca lo que se hace.';
comment on column public.registros_sesion.estado is
  'completo · a_medias · no_hecho. No se pregunta al atleta: se deduce del '
  'recuento, que es lo que evita preguntar dos veces lo mismo.';
comment on column public.registros_sesion.motivo_no_hecho is
  'Por qué se quedó a medias: «tiempo» (no dio tiempo), «molestia» (algo dolía) u '
  '«otro». Se pregunta UNA vez al terminar, no ejercicio por ejercicio, que sería '
  'insoportable. Cuando es «molestia» el atleta escribe qué le molestaba en el '
  'campo `molestias` de siempre, que ya existe y ya lo mira el equipo técnico: no '
  'se duplica esa información en dos sitios.';
comment on column public.registros_sesion.nota_no_hecho is
  'Lo que el atleta quiera añadir sobre lo que no hizo, si le apetece. Opcional '
  'siempre: obligar a explicarse es la forma más rápida de que deje de marcarlo.';

alter table public.registros_sesion drop constraint if exists registros_sesion_estado_check;
alter table public.registros_sesion add  constraint registros_sesion_estado_check
  check (estado is null or estado in ('completo', 'a_medias', 'no_hecho'));

alter table public.registros_sesion drop constraint if exists registros_sesion_motivo_check;
alter table public.registros_sesion add  constraint registros_sesion_motivo_check
  check (motivo_no_hecho is null or motivo_no_hecho in ('tiempo', 'molestia', 'otro'));

-- ------------------------------------------------------------
-- 3 · EL RECUENTO, HECHO EN LA BASE
-- ------------------------------------------------------------
-- Cuántas series manda un entrenamiento. Se cuenta igual que lo
-- pinta la pantalla del atleta: una fila con `series` entre 1 y 30
-- enseña esa cantidad de huecos. Un «series: 100» sería un error
-- de tecleo y no se cuenta, igual que la pantalla tampoco pintaría
-- cien recuadros.
create or replace function public.apo_series_previstas(p_sesion uuid)
returns integer
language sql
stable
as $$
  select coalesce(sum(n), 0)::integer
    from (
      select nullif(regexp_replace(coalesce(f ->> 'series', ''), '\D', '', 'g'), '')::integer as n
        from public.sesiones s,
             jsonb_array_elements(s.bloques) b,
             jsonb_array_elements(b -> 'filas') f
       where s.id = p_sesion
         and jsonb_typeof(s.bloques) = 'array'
         and jsonb_typeof(b -> 'filas') = 'array'
    ) t
   where n between 1 and 30;
$$;

comment on function public.apo_series_previstas(uuid) is
  'Cuántas series mandaba un entrenamiento, contadas como las pinta la pantalla '
  'del atleta. Sirve para saber si un día se hizo entero sin creerse lo que diga '
  'el que guarda.';

-- Cuántas marcó el atleta. Cuenta los `hecha: true` de la forma
-- nueva y, para los registros de antes de esta migración, da por
-- hecha toda serie que tenga algo escrito: si alguien apuntó su
-- tiempo, es que la hizo.
create or replace function public.apo_series_hechas(p_tiempos jsonb)
returns integer
language plpgsql
immutable
as $$
declare
  v_ej    jsonb;
  v_serie jsonb;
  v_txt   jsonb;
  v_n     integer := 0;
begin
  if p_tiempos is null or jsonb_typeof(p_tiempos) <> 'object' then
    return 0;
  end if;

  for v_ej in select value from jsonb_each(p_tiempos) loop
    if jsonb_typeof(v_ej) <> 'object' then
      continue;
    end if;

    if jsonb_typeof(v_ej -> 'series') = 'array' then
      -- Forma nueva: manda el ✓, y solo el ✓.
      for v_serie in select * from jsonb_array_elements(v_ej -> 'series') loop
        if jsonb_typeof(v_serie) = 'object' and (v_serie ->> 'hecha') = 'true' then
          v_n := v_n + 1;
        end if;
      end loop;
    elsif jsonb_typeof(v_ej -> 'tiempos') = 'array' then
      -- Forma vieja: no hay ✓, pero un tiempo escrito es una serie
      -- hecha. Así los registros de antes no aparecen de golpe como
      -- entrenamientos a medias, que sería una mentira nueva.
      for v_txt in select * from jsonb_array_elements(v_ej -> 'tiempos') loop
        if jsonb_typeof(v_txt) = 'string' and btrim(v_txt #>> '{}') <> '' then
          v_n := v_n + 1;
        end if;
      end loop;
    end if;
  end loop;

  return v_n;
end;
$$;

comment on function public.apo_series_hechas(jsonb) is
  'Cuenta las series marcadas como hechas dentro de `registros_sesion.tiempos_reales`. '
  'Entiende la forma nueva (el ✓ por serie) y la vieja (una serie con tiempo escrito '
  'es una serie hecha), para que lo guardado antes no pase a leerse como «a medias».';

-- El disparador que las mantiene al día. Se calcula en la base a
-- propósito: si lo calculara la pantalla, cada pantalla contaría a
-- su manera y el mismo día saldría completo en una y a medias en
-- otra.
-- ⚠️ Lo mismo que arriba: sin `security definer`, `apo_series_previstas`
-- y `apo_series_hechas` están cerradas para el atleta y NO SE PODÍA
-- GUARDAR lo entrenado. Explicado entero en la migración 106.
create or replace function public.apo_registros_estado()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_prev integer;
  v_hech integer;
begin
  v_prev := coalesce(public.apo_series_previstas(new.sesion_id), 0);
  v_hech := coalesce(public.apo_series_hechas(new.tiempos_reales), 0);

  new.series_previstas := v_prev;
  new.series_hechas    := least(v_hech, greatest(v_prev, v_hech));

  if v_prev = 0 then
    -- Un día sin series que marcar (un rodaje, una competición, un
    -- día de descanso): si el atleta ha contado cómo le fue, ese
    -- día está completo. No hay nada que se pueda quedar a medias.
    new.estado := 'completo';
  elsif v_hech = 0 then
    new.estado := 'no_hecho';
  elsif v_hech >= v_prev then
    new.estado := 'completo';
  else
    new.estado := 'a_medias';
  end if;

  -- El motivo solo tiene sentido si de verdad quedó algo sin hacer.
  -- Si el atleta vuelve y lo completa, el motivo se cae solo: dejarlo
  -- puesto sería que el entrenador siguiera leyendo «le molestaba» en
  -- un día que acabó entero.
  if new.estado = 'completo' then
    new.motivo_no_hecho := null;
    new.nota_no_hecho   := null;
  end if;

  return new;
end;
$$;

comment on function public.apo_registros_estado() is
  'Deduce si el entrenamiento se hizo entero, a medias o nada, contando las series '
  'marcadas. No se le pregunta al atleta: preguntarlo aparte sería preguntar dos '
  'veces lo mismo, y la respuesta podría no cuadrar con lo que marcó.';

drop trigger if exists trg_registros_estado on public.registros_sesion;
create trigger trg_registros_estado
  before insert or update on public.registros_sesion
  for each row execute function public.apo_registros_estado();

-- Poner al día lo que ya está guardado. Todos los registros de
-- antes se quedan en «completo» salvo que se vea que faltan
-- series, que es lo honrado: nadie les dio la oportunidad de decir
-- que no lo hicieron, así que no se les puede acusar de nada.
update public.registros_sesion
   set tiempos_reales = tiempos_reales
 where estado is null;

-- ------------------------------------------------------------
-- 4 · UN ÍNDICE PARA LA PREGUNTA DEL HISTORIAL
-- ------------------------------------------------------------
-- «De mis 41 días, ¿cuántos se quedaron a medias?» se pregunta por
-- atleta y por estado, y se pregunta cada vez que alguien abre su
-- historial.
create index if not exists idx_registros_atleta_estado
  on public.registros_sesion (atleta_id, estado);

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- ninguna fila debe quedarse sin id
--   select count(*) from sesiones s,
--          jsonb_array_elements(s.bloques) b,
--          jsonb_array_elements(b->'filas') f
--    where f->>'id' is null;
--
--   -- y ningún id puede estar repetido dentro del mismo entrenamiento
--   select s.id, f->>'id', count(*)
--     from sesiones s,
--          jsonb_array_elements(s.bloques) b,
--          jsonb_array_elements(b->'filas') f
--    group by 1,2 having count(*) > 1;
--
--   -- el reparto de estados (los de antes deben salir casi todos completos)
--   select estado, count(*) from registros_sesion group by 1;
--
--   -- los días a medias, con cuánto se hizo de cada uno
--   select r.created_at::date, r.series_hechas, r.series_previstas, r.motivo_no_hecho
--     from registros_sesion r where r.estado = 'a_medias' order by 1 desc;
-- ------------------------------------------------------------
