-- ============================================================
-- 106 · Que se pueda guardar
-- ------------------------------------------------------------
-- EL FALLO, EN UNA FRASE
-- Ni el atleta podía guardar lo que había entrenado, ni el
-- entrenador podía guardar un entrenamiento. Las dos cosas
-- fallaban con el mismo error y ninguna pantalla lo decía en voz
-- alta: solo «no me deja guardar».
--
-- QUÉ PASABA DE VERDAD
-- En esta base las funciones NACEN CERRADAS: la migración 090 puso
-- un disparador de DDL que, a cada función nueva, le quita el
-- permiso de ejecución a `anon` y a `authenticated`. Es una buena
-- regla y no se toca.
--
-- Con esa regla puesta, TODOS los disparadores de esta base se
-- declaran `security definer` —el del Cubo, el de los recibos, el
-- de los horarios de grupo, el de los retos, todos— para que lo
-- que llaman por dentro se ejecute con los permisos de quien creó
-- la función y no con los de quien está guardando.
--
-- Los dos disparadores de la migración 103 son los ÚNICOS que se
-- quedaron sin esa palabra:
--
--     apo_registros_estado()      → llama a apo_series_previstas()
--                                   y a apo_series_hechas()
--     apo_sesiones_ids_de_fila()  → llama a apo_bloques_con_id()
--
-- Y ahí está el detalle que lo hacía invisible: Postgres NO
-- comprueba el permiso de la función de un disparador —la ejecuta
-- porque está enganchada a la tabla—, pero SÍ comprueba el de
-- cualquier función que esa función llame por dentro. Así que los
-- dos arrancaban bien y se estrellaban en su primera línea útil:
--
--     ERROR: permission denied for function apo_series_previstas
--     CONTEXT: PL/pgSQL function apo_registros_estado() line 7
--
-- POR QUÉ NO SALTÓ ANTES
-- Porque con el usuario de administración funciona: administración
-- se salta esto entero. Todas las pruebas se habían hecho por ahí.
-- El fallo solo existía para las personas que van a usarlo —los
-- atletas y los entrenadores—, que es exactamente el fallo que no
-- se ve si no se prueba guardando de verdad.
--
-- ============================================================
-- LO QUE SE HACE
-- ------------------------------------------------------------
-- 1 · Los dos disparadores pasan a `security definer` con su
--     `search_path` clavado, como los otros ocho de esta base. Se
--     arregla poniéndolos en la norma de la casa, no repartiendo
--     permisos sueltos: las tres funciones de ayuda siguen
--     cerradas y nadie puede llamarlas desde fuera.
--
--     ⚠️ `security definer` SIN `set search_path` es un agujero:
--     quien pueda crear un esquema podría colar sus propias
--     funciones. Los tres lo llevan.
--
--     Y que quede dicho: esto NO se salta el permiso de la tabla.
--     Para que el disparador llegue a ejecutarse, el INSERT o el
--     UPDATE ya ha tenido que pasar por su política. Lo único que
--     cambia es con qué permisos corre lo de dentro.
--
-- 2 · `apo_series_previstas` pasa además a `security definer` por
--     una razón propia, aparte de los permisos: LEE `sesiones`, y
--     leyéndola como quien guarda, el recuento depende de quién
--     mire. Un entrenamiento despublicado deja de verse para el
--     atleta, el recuento le saldría 0 y su día pasaría a
--     «completo» sin que él haya hecho nada. La migración 103
--     decía que esto se calcula en la base «para que todas las
--     pantallas cuenten igual»; así cuentan igual de verdad.
--
-- 3 · Una comprobación al final que REVIENTA si algún disparador
--     que NO sea `security definer` llama a una función cerrada.
--     Es lo que habría cazado esto el primer día, y lo que lo
--     cazará la próxima vez.
--
-- IDEMPOTENTE: todo es `create or replace`. No borra nada y no
-- cambia ni una línea de lo que hacen las funciones.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · EL RECUENTO DE SERIES PREVISTAS, IGUAL PARA TODOS
-- ------------------------------------------------------------
-- La cuenta es la misma de la migración 103, palabra por palabra.
-- Lo único que cambia es con qué permisos se ejecuta.
create or replace function public.apo_series_previstas(p_sesion uuid)
returns integer
language sql
stable
security definer
set search_path to 'public'
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
  'del atleta. SECURITY DEFINER a propósito (migración 106): si leyera `sesiones` '
  'como quien guarda, el recuento cambiaría según quién mire, y un entrenamiento '
  'despublicado convertiría en «completo» un día que se quedó a medias.';

-- ------------------------------------------------------------
-- 2 · EL DISPARADOR DEL REGISTRO DEL ATLETA
-- ------------------------------------------------------------
-- Cuerpo idéntico al de la migración 104 (el estado del día y el
-- rastro de las correcciones). Lo único nuevo son las dos líneas
-- de `security definer` y `set search_path`.
create or replace function public.apo_registros_estado()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_prev  integer;
  v_hech  integer;
  v_fecha date;
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
  if new.estado = 'completo' then
    new.motivo_no_hecho := null;
    new.nota_no_hecho   := null;
  end if;

  -- Solo en UPDATE: la primera vez que se apunta un entrenamiento
  -- no es una corrección aunque se apunte tarde. Apuntar el jueves
  -- lo del martes es justo lo que queremos que la gente haga.
  if TG_OP = 'UPDATE' then
    select s.fecha into v_fecha from public.sesiones s where s.id = new.sesion_id;

    -- La fecha de HOY en la hora de aquí, no en UTC. El servidor va
    -- en UTC: sin esto, guardar a las 00:30 de la madrugada del
    -- martes contaría como corrección del entrenamiento del lunes,
    -- que es exactamente el que se acaba de hacer.
    if v_fecha is not null
       and v_fecha < (now() at time zone 'Europe/Madrid')::date
       and (   new.tiempos_reales    is distinct from old.tiempos_reales
            or new.sensacion_general is distinct from old.sensacion_general
            or new.rpe               is distinct from old.rpe
            or new.como_me_siento    is distinct from old.como_me_siento
            or new.molestias         is distinct from old.molestias
            or new.notas_atleta      is distinct from old.notas_atleta
            or new.horas_sueno       is distinct from old.horas_sueno
            or new.peso_kg           is distinct from old.peso_kg
            or new.motivo_no_hecho   is distinct from old.motivo_no_hecho
            or new.nota_no_hecho     is distinct from old.nota_no_hecho)
    then
      new.corregido_en    := now();
      new.corregido_veces := coalesce(old.corregido_veces, 0) + 1;
    else
      -- Guardar sin cambiar nada no es corregir: el rastro de antes
      -- se queda como estaba y no se inventa uno nuevo.
      --
      -- Y de paso, EL RASTRO NO SE PUEDE BORRAR DESDE FUERA: quien
      -- mande un `corregido_en = null` se encuentra con el valor de
      -- antes puesto otra vez. Un rastro que se puede quitar no es
      -- un rastro.
      new.corregido_en    := old.corregido_en;
      new.corregido_veces := coalesce(old.corregido_veces, 0);
    end if;
  end if;

  return new;
end;
$$;

comment on function public.apo_registros_estado() is
  'Deduce si el entrenamiento se hizo entero, a medias o nada contando las series '
  'con ✓ (migración 103) y deja el rastro cuando se corrige lo apuntado de un día '
  'ya pasado (migración 104). SECURITY DEFINER desde la 106: sin eso, las funciones '
  'que llama por dentro estaban cerradas para el atleta y NO SE PODÍA GUARDAR.';

-- ------------------------------------------------------------
-- 3 · EL DISPARADOR DEL ENTRENAMIENTO
-- ------------------------------------------------------------
-- Cuerpo idéntico al de la migración 103. Mismo arreglo: sin esto,
-- el entrenador no podía guardar un entrenamiento.
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

comment on function public.apo_sesiones_ids_de_fila() is
  'Le pone su id a cada fila del entrenamiento al guardar (migración 103). '
  'SECURITY DEFINER desde la 106: sin eso, `apo_bloques_con_id` estaba cerrada '
  'para el entrenador y NO SE PODÍA GUARDAR UN ENTRENAMIENTO.';

-- ------------------------------------------------------------
-- 4 · EL DISPARADOR DEL COMENTARIO DEL ENTRENADOR
-- ------------------------------------------------------------
-- Este no llamaba a nada, así que no estaba roto. Se pone en la
-- misma norma que los demás para que dentro de un año nadie tenga
-- que averiguar por qué había uno distinto.
create or replace function public.apo_feedback_editado()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  -- Solo cuenta como edición si cambia el texto y si ya no estamos
  -- en el día en que se escribió. Poner la coma que faltaba diez
  -- minutos después no es rectificar.
  if new.comentario is distinct from old.comentario
     and (old.created_at at time zone 'Europe/Madrid')::date
         < (now() at time zone 'Europe/Madrid')::date then
    new.editado_en := now();
  else
    new.editado_en := old.editado_en;
  end if;
  -- Ni la firma ni la fecha original se mueven al editar: quien lo
  -- escribió lo escribió, y cuándo lo dijo por primera vez importa.
  new.entrenador_id := old.entrenador_id;
  new.created_at    := old.created_at;
  new.registro_id   := old.registro_id;
  return new;
end;
$$;

commit;

-- ------------------------------------------------------------
-- 5 · LA RED PARA LA PRÓXIMA VEZ
-- ------------------------------------------------------------
-- Recorre TODOS los disparadores de todas las tablas y falla si
-- alguno que NO sea `security definer` llama por dentro a una
-- función que `authenticated` no puede ejecutar. Esa combinación
-- —y solo esa— es la que hace que no se pueda guardar.
--
-- Los `security definer` no se miran: lo de dentro corre con los
-- permisos de quien creó la función, y ahí no hay nada que
-- comprobar. Por eso el Cubo, los recibos o los horarios de grupo
-- no salen aquí aunque llamen a funciones cerradas: están bien.
--
-- Va FUERA de la transacción a propósito: si algo estuviera mal,
-- el arreglo de arriba ya se ha aplicado igual y el aviso se lee.
do $$
declare
  v_falta text;
begin
  select string_agg(distinct f.disparador || ' → ' || f.nombre, ', ')
    into v_falta
    from (
      select p.proname as disparador, m[1] as nombre
        from pg_trigger t
        join pg_class c on c.oid = t.tgrelid
        join pg_proc  p on p.oid = t.tgfoid,
             lateral regexp_matches(pg_get_functiondef(p.oid), 'public\.([a-z0-9_]+)\s*\(', 'g') m
       where not t.tgisinternal
         and c.relnamespace = 'public'::regnamespace
         and not p.prosecdef            -- los security definer están a salvo
         and m[1] <> p.proname
    ) f
    join pg_proc pf on pf.proname = f.nombre
                   and pf.pronamespace = 'public'::regnamespace
   where not has_function_privilege('authenticated', pf.oid, 'EXECUTE');

  if v_falta is not null then
    raise exception
      'NO SE VA A PODER GUARDAR. Estos disparadores no son «security definer» y llaman por '
      'dentro a funciones que «authenticated» no puede ejecutar: %. O se declara el disparador '
      '«security definer set search_path to ''public''» (que es lo que hace el resto de esta '
      'base), o se le da «grant execute» a la función. Ver migración 090: las funciones nacen '
      'cerradas.', v_falta;
  end if;

  raise notice 'Comprobado: ningún disparador se queda sin poder llamar a lo que necesita.';
end $$;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- los diez disparadores de la base, todos en «security definer»
--   select p.proname, p.prosecdef from pg_trigger t
--     join pg_proc p on p.oid = t.tgfoid
--    where not t.tgisinternal and p.proname like 'apo\_%';
--
--   -- y la prueba de verdad, que es la única que vale: guardar
--   -- haciéndose pasar por un atleta y por un entrenador
--   --   set local role authenticated;
--   --   set local request.jwt.claims = '{"email":"…"}';
--   --   insert into registros_sesion … on conflict … do update …;
--   --   update sesiones set titulo = titulo where id = …;
-- ------------------------------------------------------------
