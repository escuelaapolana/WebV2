-- ============================================================
-- 111 · Apuntar un ejercicio no puede borrar los de al lado
-- ------------------------------------------------------------
-- EL FALLO, EN UNA FRASE
-- Un atleta apuntaba su entrenamiento y luego se le borraba solo.
-- Sin error, sin aviso: la pantalla decía «Guardado» y los kilos,
-- el «lo cambié por» y el RIR ya no estaban.
--
-- CÓMO PASABA, PASO A PASO
-- Todo lo que el atleta apunta de un día vive en UNA sola casilla:
-- `registros_sesion.tiempos_reales`, con una entrada por ejercicio
-- (migración 103). Esa casilla la escriben DOS pantallas distintas:
--
--   · el portal del atleta, que pinta el entrenamiento entero
--   · las calles de la piscina, que pinta SOLO los largos de su calle
--
-- Las dos guardaban igual: montaban la casilla entera desde cero con
-- lo que ellas tenían en pantalla y la mandaban de una pieza. Y una
-- casilla entera mandada de una pieza no «añade»: SUSTITUYE. Así que
-- el nadador que apuntaba sus tiempos en el borde de la piscina
-- borraba, sin enterarse, las pesas que había apuntado esa misma
-- tarde. Y si entraba en las calles y le daba a guardar sin escribir
-- nada, se llevaba por delante el día completo.
--
-- Comprobado contra la base antes de arreglar nada: un registro con
-- diez series apuntadas (crol, media sentadilla a 60 kg y «jalón al
-- pecho → lo cambié por dominadas», con su RIR) se quedaba en cuatro
-- series de crol, y el día pasaba de «completo» a «a medias». Con el
-- guardado vacío, en «no hecho» y la casilla a cero.
--
-- ------------------------------------------------------------
-- POR QUÉ SE ARREGLA AQUÍ Y NO SOLO EN LA PANTALLA
-- Se podría hacer que la pantalla lea lo guardado, le pegue lo suyo y
-- lo devuelva todo junto. Sirve, pero deja dos puertas abiertas:
--
--   1. Entre leer y escribir pasa un segundo. Si el atleta guarda
--      desde el móvil a pie de piscina y desde casa a la vez —o dos
--      veces seguidas con mala cobertura—, el segundo guardado
--      escribe encima de lo que no llegó a leer. Vuelve el mismo
--      fallo, más raro y más difícil de ver.
--   2. Es una regla que hay que recordar. El día que alguien monte la
--      séptima pantalla que apunta ejercicios, se le olvidará, y nadie
--      se enterará hasta meses después, mirando un historial vacío.
--
-- Poniéndolo aquí, la mezcla la hace la base en una sola operación y
-- no hay hueco entre leer y escribir. Y sobre todo: una pantalla NO
-- PUEDE ya borrar un ejercicio que no ha pintado, aunque quiera.
--
-- LA REGLA, DICHA CORTA
-- Cada pantalla manda SOLO los ejercicios que enseña. De esos manda
-- todo (si los cambia, se cambian; si los vacía, desaparecen). De los
-- demás no dice nada, y por eso no les pasa nada.
--
-- LO QUE ESTA MIGRACIÓN NO HACE
-- No borra nada, no cambia ninguna columna y no toca ni un registro
-- guardado. Solo añade la manera correcta de apuntar. Lo ya perdido
-- antes de hoy no se puede recuperar desde aquí: no quedó copia.
--
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LA MEZCLA: lo que había, más lo que trae la pantalla
-- ------------------------------------------------------------
-- Recorre solo los ejercicios que vienen en `p_cambios`:
--   · si traen contenido, ese ejercicio queda como dice la pantalla
--   · si vienen en blanco (null), ese ejercicio se quita, porque es
--     el atleta borrando lo que había apuntado y tiene derecho
--   · los que no vienen ni se miran
--
-- Va aparte y `immutable` para poder usarla dentro del guardado de
-- abajo sin que la base la ejecute dos veces.
create or replace function public.apo_tiempos_mezclados(p_actual jsonb, p_cambios jsonb)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_out   jsonb;
  v_clave text;
  v_valor jsonb;
begin
  v_out := coalesce(p_actual, '{}'::jsonb);
  -- Un registro antiguo podría tener ahí algo que no sea un objeto.
  -- Antes que romper el guardado del atleta, se empieza de cero.
  if jsonb_typeof(v_out) <> 'object' then
    v_out := '{}'::jsonb;
  end if;

  if p_cambios is null or jsonb_typeof(p_cambios) <> 'object' then
    return v_out;
  end if;

  for v_clave, v_valor in select key, value from jsonb_each(p_cambios) loop
    if v_valor is null or jsonb_typeof(v_valor) = 'null' then
      v_out := v_out - v_clave;
    else
      v_out := jsonb_set(v_out, array[v_clave], v_valor, true);
    end if;
  end loop;

  return v_out;
end;
$$;

comment on function public.apo_tiempos_mezclados(jsonb, jsonb) is
  'Mete en lo que el atleta ya tenía apuntado los ejercicios que trae una '
  'pantalla, sin tocar los demás. Es lo que evita que apuntar los largos de la '
  'piscina borre los kilos del gimnasio del mismo día.';

-- ------------------------------------------------------------
-- 2 · APUNTAR UNOS EJERCICIOS, Y SOLO ESOS
-- ------------------------------------------------------------
-- Lo que llama la pantalla. Recibe la sesión, el atleta y SOLO los
-- ejercicios que esa pantalla enseña. Todo lo demás de la fila —cómo
-- se sintió, el RPE, las molestias, las horas de sueño, el peso, el
-- motivo de lo que no hizo— se queda exactamente como estaba: esta
-- función no las nombra siquiera.
--
-- ⚠️ `security definer` NO ES OPCIONAL (ver migraciones 090 y 106): en
-- esta base las funciones nacen cerradas, y sin esto la comprobación
-- de permisos de dentro no podría ni ejecutarse. El `search_path`
-- clavado va con ello: un `security definer` sin él es un agujero.
--
-- Y como corre con los permisos del dueño, se salta las reglas de
-- acceso de la tabla. Por eso las comprueba ella misma, y con las
-- MISMAS puertas que la tabla: quien no podría escribir ahí por la vía
-- normal, tampoco puede por aquí.
create or replace function public.apo_apuntar_ejercicios(
  p_sesion     uuid,
  p_atleta     uuid,
  p_ejercicios jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_existe boolean;
  v_fila   public.registros_sesion%rowtype;
begin
  if p_sesion is null or p_atleta is null then
    raise exception 'Falta la sesión o el atleta';
  end if;
  if p_ejercicios is null or jsonb_typeof(p_ejercicios) <> 'object' then
    raise exception 'Lo que se apunta tiene que venir como una lista de ejercicios';
  end if;

  select exists (
    select 1 from public.registros_sesion
     where sesion_id = p_sesion and atleta_id = p_atleta
  ) into v_existe;

  -- Las mismas dos puertas que las reglas de la tabla: crear el
  -- registro del día lo puede hacer también un padre o madre; tocar
  -- uno que ya existe, solo el atleta o su entrenador.
  if v_existe then
    if not (public.es_admin() or p_atleta in (select public.mis_atletas_entreno())) then
      raise exception 'No puedes apuntar el entrenamiento de este atleta';
    end if;
  else
    if not (public.es_admin() or p_atleta in (select public.mis_atletas())) then
      raise exception 'No puedes apuntar el entrenamiento de este atleta';
    end if;
  end if;

  -- En una sola operación: si no hay fila se crea, y si la hay se le
  -- mezcla lo que trae la pantalla. Sin hueco entre leer y escribir,
  -- que es donde se colaba el fallo cuando se guardaba dos veces a la
  -- vez desde dos sitios.
  insert into public.registros_sesion (sesion_id, atleta_id, tiempos_reales)
  values (p_sesion, p_atleta, public.apo_tiempos_mezclados('{}'::jsonb, p_ejercicios))
  on conflict (sesion_id, atleta_id) do update
     set tiempos_reales = public.apo_tiempos_mezclados(
           public.registros_sesion.tiempos_reales, p_ejercicios)
  returning * into v_fila;

  -- Se devuelve lo que ha calculado la base (migración 103) para que la
  -- pantalla enseñe el estado del día tal cual queda guardado, sin
  -- echar sus propias cuentas y acabar diciendo otra cosa.
  return jsonb_build_object(
    'id',               v_fila.id,
    'estado',           v_fila.estado,
    'series_hechas',    v_fila.series_hechas,
    'series_previstas', v_fila.series_previstas,
    'tiempos_reales',   v_fila.tiempos_reales
  );
end;
$$;

comment on function public.apo_apuntar_ejercicios(uuid, uuid, jsonb) is
  'Apunta lo que un atleta ha hecho en UNOS ejercicios concretos, sin tocar los '
  'demás ni el resto de su parte del día. Cada pantalla manda solo los ejercicios '
  'que enseña; un ejercicio en blanco (null) se borra, y del que no viene no se '
  'toca nada. Existe porque las calles de la piscina, al guardar los tiempos, '
  'borraban los kilos y el «lo cambié por» del gimnasio del mismo día.';

-- ⚠️ EL PERMISO NO VIENE SOLO: en esta base las funciones nacen
-- cerradas (migración 090). Sin este grant, el atleta recibiría un
-- error al guardar en vez de su pantalla.
revoke execute on function public.apo_apuntar_ejercicios(uuid, uuid, jsonb) from public, anon;
grant  execute on function public.apo_apuntar_ejercicios(uuid, uuid, jsonb) to authenticated;

-- La mezcla es una pieza de dentro: solo la llama la función de
-- arriba, que corre como su dueño y no necesita este permiso.
revoke execute on function public.apo_tiempos_mezclados(jsonb, jsonb) from public, anon, authenticated;

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- la función existe y solo la puede llamar quien tiene cuenta
--   select proname, proacl from pg_proc
--    where proname in ('apo_apuntar_ejercicios','apo_tiempos_mezclados');
--
--   -- la mezcla respeta lo que no viene, cambia lo que viene y borra
--   -- lo que viene en blanco (debe dar {"b": 2, "c": 9})
--   select public.apo_tiempos_mezclados(
--            '{"a": 1, "b": 2}'::jsonb,
--            '{"a": null, "c": 9}'::jsonb);
-- ------------------------------------------------------------
