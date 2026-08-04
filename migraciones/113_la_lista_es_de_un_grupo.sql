-- ============================================================
-- 113 · Pasar lista de un grupo no puede borrar la de otro
-- ------------------------------------------------------------
-- EL FALLO, EN UNA FRASE
-- Un chaval que entrena con dos grupos el mismo día solo puede
-- estar en la lista de UNO: el segundo entrenador que pasa lista
-- se lleva por delante lo que puso el primero, y ninguno de los
-- dos lo ve.
--
-- CÓMO PASABA, PASO A PASO
-- La asistencia se guardaba con una sola llave: atleta + día. El
-- grupo se apuntaba al lado, como un dato más, sin formar parte de
-- la llave. Y las dos pantallas que pasan lista —el panel de campo
-- y el portal del entrenador— guardaban así:
--
--   · para marcar:    «esta persona, este día» → sustituye
--   · para desmarcar: «esta persona, este día» → borra
--
-- Ninguna de las dos nombraba el grupo. Así que si un crío hace la
-- escuela a primera hora y fuerza a segunda —o atletismo y natación
-- el mismo día, que también pasa—, el entrenador de la segunda hora
-- pisaba la marca de la primera al guardar, y si lo desmarcaba
-- borraba la fila entera, la del otro grupo incluida.
--
-- Comprobado contra la base antes de arreglar nada, con datos de
-- usar y tirar: una fila del grupo de PRIMERA hora se convertía
-- sola en fila del grupo de SEGUNDA al pasar la segunda lista —la
-- asistencia de primera hora, desaparecida—, y un solo «desmarcar»
-- dejaba el día a cero para los dos grupos.
--
-- CUÁNTO DAÑO HABÍA
-- Ninguno, y conviene decirlo: la tabla `asistencia` está vacía. No
-- se ha pasado lista todavía ni una vez, así que no se ha perdido
-- nada de nadie. Se arregla ahora precisamente por eso: en cuanto
-- empiece el curso, esto pasa la primera semana.
--
-- ------------------------------------------------------------
-- POR QUÉ SE ARREGLA AQUÍ Y NO SOLO EN LAS PANTALLAS
-- Se podría añadir «y del grupo tal» a las dos pantallas y listo.
-- Pero la llave de la tabla seguiría diciendo «una persona, un día,
-- una sola fila», y entonces la base RECHAZARÍA la segunda lista en
-- vez de guardarla: el problema cambiaría de cara, no se iría. La
-- llave tiene que decir la verdad de cómo entrena el club: una
-- persona puede estar en dos listas el mismo día si entrena dos
-- veces, y son dos cosas distintas.
--
-- Y el borrado se saca de las pantallas y se mete aquí, en una sola
-- operación que solo sabe borrar dentro de SU grupo. Con eso, la
-- séptima pantalla que alguien monte para pasar lista no podrá
-- repetir el fallo aunque se le olvide el grupo: no tendrá con qué.
--
-- LA REGLA, DICHA CORTA
-- Cada lista es de un grupo y de un día. De los suyos dice todo; de
-- los de otro grupo no dice nada, y por eso no les pasa nada.
--
-- LO QUE ESTA MIGRACIÓN NO HACE
-- No borra ni una fila y no cambia ninguna marca guardada. Cambia
-- la llave (a mejor: acepta lo que antes rechazaba) y añade la
-- manera correcta de pasar lista.
--
-- ⚠️ ESTO Y LAS PANTALLAS VAN JUNTOS
-- Al ensanchar la llave, el atajo que usaban las dos pantallas para
-- guardar («chocan por atleta y fecha») deja de existir. Las dos
-- tienen que estar ya llamando a `apo_pasar_lista` cuando esto se
-- aplique, o pasar lista dará error hasta que se suban.
--
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · EL GRUPO ENTRA EN LA LLAVE
-- ------------------------------------------------------------
-- Antes: «una persona, un día». Ahora: «una persona, un día, un
-- grupo». Se ensancha, no se estrecha: todo lo que cabía antes
-- sigue cabiendo, así que no hay filas que se solapen ni que haya
-- que tirar. (Comprobado además fila a fila antes de tocar nada.)
--
-- `nulls not distinct` es la parte fina: hay filas antiguas que se
-- apuntaron sin grupo, de cuando la asistencia colgaba de un
-- entrenamiento concreto. Sin esto, Postgres entiende que dos
-- «sin grupo» son cosas distintas y dejaría meter la misma persona
-- el mismo día tantas veces como se le diera a guardar.
do $$
begin
  if exists (select 1 from pg_constraint where conname = 'asistencia_atleta_fecha_unico') then
    alter table public.asistencia drop constraint asistencia_atleta_fecha_unico;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'asistencia_atleta_fecha_grupo_unico') then
    alter table public.asistencia
      add constraint asistencia_atleta_fecha_grupo_unico
      unique nulls not distinct (atleta_id, fecha, grupo_id);
  end if;
end $$;

comment on constraint asistencia_atleta_fecha_grupo_unico on public.asistencia is
  'Una marca por persona, día y grupo. El grupo está en la llave porque hay '
  'quien entrena dos veces el mismo día con dos grupos distintos, y esas son '
  'dos asistencias, no una que se pisa a la otra.';

-- ------------------------------------------------------------
-- 2 · PASAR LA LISTA DE UN GRUPO, Y SOLO DE ESE
-- ------------------------------------------------------------
-- Lo que llama la pantalla. Recibe el grupo, el día y las marcas de
-- ESA lista:
--
--   { "<id del atleta>": true }   vino
--   { "<id del atleta>": false }  no vino
--   { "<id del atleta>": null }   quítale la marca (el entrenador
--                                 la deja en blanco otra vez)
--
-- De quien no venga en la lista no se dice nada, y por eso no le
-- pasa nada: ni a los de otro grupo, ni a los del mismo grupo que
-- el entrenador todavía no ha tocado.
--
-- ⚠️ `security definer` NO ES OPCIONAL (ver migraciones 090 y 106):
-- en esta base las funciones nacen cerradas, y sin esto la
-- comprobación de permisos de dentro no podría ni ejecutarse. El
-- `search_path` clavado va con ello: un `security definer` sin él
-- es un agujero.
--
-- Y como corre con los permisos del dueño, se salta las reglas de
-- acceso de la tabla. Por eso las comprueba ella misma, y con la
-- MISMA puerta que la tabla: quien no podría pasarle lista a esa
-- persona por la vía normal, tampoco puede por aquí.
create or replace function public.apo_pasar_lista(
  p_grupo  uuid,
  p_fecha  date,
  p_marcas jsonb,
  p_sesion uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_clave  text;
  v_valor  jsonb;
  v_atleta uuid;
  v_out    jsonb := '{}'::jsonb;
begin
  if p_grupo is null or p_fecha is null then
    raise exception 'Falta el grupo o el día de la lista';
  end if;
  if p_marcas is null or jsonb_typeof(p_marcas) <> 'object' then
    raise exception 'Las marcas tienen que venir como una lista de atletas';
  end if;
  if not exists (select 1 from public.grupos g where g.id = p_grupo) then
    raise exception 'Ese grupo no existe';
  end if;

  for v_clave, v_valor in select key, value from jsonb_each(p_marcas) loop
    -- Un id mal formado se para aquí y no a mitad de la lista, para que el
    -- entrenador no se quede con media lista guardada y media no.
    begin
      v_atleta := v_clave::uuid;
    exception when others then
      raise exception 'Ese no es un atleta: %', v_clave;
    end;

    if not public.soy_staff_de_atleta(v_atleta) then
      raise exception 'No puedes pasarle lista a este atleta';
    end if;

    -- La asistencia no está atada a la ficha del atleta (no hay clave ajena en
    -- esa columna, viene de antiguo), así que un id equivocado dejaría una
    -- marca colgando de nadie que nunca se limpiaría. Se comprueba aquí.
    if not exists (select 1 from public.atletas a where a.id = v_atleta) then
      raise exception 'Ese atleta no existe';
    end if;

    if v_valor is null or jsonb_typeof(v_valor) = 'null' then
      -- Quitar la marca. El grupo va en el `where` SIEMPRE: es lo único que
      -- impide llevarse por delante la lista que puso el otro entrenador.
      delete from public.asistencia a
       where a.atleta_id = v_atleta
         and a.fecha     = p_fecha
         and a.grupo_id  = p_grupo;
    else
      if jsonb_typeof(v_valor) <> 'boolean' then
        raise exception 'Una marca solo puede ser vino, no vino, o nada';
      end if;
      insert into public.asistencia (atleta_id, fecha, grupo_id, sesion_id, presente)
      values (v_atleta, p_fecha, p_grupo, p_sesion, (v_valor)::boolean)
      on conflict (atleta_id, fecha, grupo_id) do update
         set presente  = excluded.presente,
             -- Si esta pantalla no sabe de qué entrenamiento va (el panel de
             -- campo no lo sabe), se deja el que ya estuviera apuntado en vez
             -- de vaciarlo.
             sesion_id = coalesce(excluded.sesion_id, public.asistencia.sesion_id);
      v_out := jsonb_set(v_out, array[v_clave], to_jsonb((v_valor)::boolean), true);
    end if;
  end loop;

  -- Se devuelve la lista de ESE grupo y ESE día tal como queda guardada, para
  -- que la pantalla enseñe lo que hay en la base y no lo que ella creía.
  select coalesce(jsonb_object_agg(a.atleta_id::text, a.presente), '{}'::jsonb)
    into v_out
    from public.asistencia a
   where a.fecha = p_fecha and a.grupo_id = p_grupo;

  return v_out;
end;
$$;

comment on function public.apo_pasar_lista(uuid, date, jsonb, uuid) is
  'Pasa la lista de UN grupo en UN día. Solo toca las marcas de ese grupo: la '
  'lista que otro entrenador puso al mismo chaval en otro grupo el mismo día se '
  'queda intacta. Existe porque las dos pantallas que pasan lista guardaban y '
  'borraban por «atleta y fecha», sin nombrar el grupo, y se pisaban.';

-- ⚠️ EL PERMISO NO VIENE SOLO: en esta base las funciones nacen
-- cerradas (migración 090). Sin este grant, el entrenador recibiría
-- un error al guardar en vez de su lista.
revoke execute on function public.apo_pasar_lista(uuid, date, jsonb, uuid) from public, anon;
grant  execute on function public.apo_pasar_lista(uuid, date, jsonb, uuid) to authenticated;

-- ------------------------------------------------------------
-- 3 · BORRAR ASISTENCIA, SOLO POR AQUÍ
-- ------------------------------------------------------------
-- Esta es la parte que hace que el fallo no pueda volver. Marcar de
-- más se corrige en dos toques; borrar la lista de otro grupo no se
-- corrige, porque nadie se entera. Así que el borrado deja de estar
-- al alcance de las pantallas: solo lo hace la función de arriba,
-- que no sabe borrar fuera de su grupo.
--
-- Leer, marcar y corregir se siguen haciendo con normalidad. Y si
-- algún día hace falta limpiar asistencia a mano, se hace desde la
-- base, que es donde tiene que doler un poco.
revoke delete on table public.asistencia from authenticated;

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- la llave ya lleva el grupo dentro
--   select conname, pg_get_constraintdef(oid) from pg_constraint
--    where conrelid = 'public.asistencia'::regclass and contype = 'u';
--
--   -- la función existe y solo la puede llamar quien tiene cuenta
--   select proname, proacl from pg_proc where proname = 'apo_pasar_lista';
--
--   -- las pantallas ya no pueden borrar asistencia por su cuenta
--   select has_table_privilege('authenticated', 'public.asistencia', 'delete');
-- ------------------------------------------------------------
