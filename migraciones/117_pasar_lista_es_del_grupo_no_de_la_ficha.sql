-- ============================================================
-- 117 · Pasar lista es cosa del grupo; lo demás, de la ficha
-- ------------------------------------------------------------
-- LO QUE FALLA, EN UNA FRASE
-- Desde la 116 un chaval puede entrenar en dos grupos, y el
-- entrenador del segundo ya lo VE en su lista. Pero al marcar que
-- ha venido, la base le dice que no. El segundo grupo queda de
-- adorno: se ve la lista y no se puede pasar.
--
-- POR QUÉ PASABA
-- Todo lo que se escribe sobre una persona pasaba por la misma
-- puerta, `soy_staff_de_atleta`, que dice:
--
--   «o eres administración, o eres el entrenador ESCRITO EN SU FICHA»
--
-- Esa es la puerta correcta para casi todo. Pero para la lista de
-- asistencia no: la lista no es de una ficha, es de un grupo y de
-- un día. Quien dirige ese grupo ese día es quien sabe si el
-- chaval ha venido, lo diga o no su ficha.
--
-- ------------------------------------------------------------
-- LA REGLA NUEVA, Y SOLO PARA LA LISTA
-- Se añade una segunda puerta, `puedo_pasar_lista(atleta, grupo)`,
-- que se abre también cuando se cumplen LAS DOS cosas a la vez:
--
--   · el grupo de esa lista es un grupo que dirijo yo, y
--   · esa persona entrena de verdad en ese grupo
--
-- Las dos, no una. Con solo la primera, un entrenador podría
-- apuntar en la lista de su grupo a cualquiera del club; con solo
-- la segunda, cualquier entrenador podría marcar en la lista de
-- otro. Juntas dicen lo justo: en MI lista, a los MÍOS.
--
-- ⚠️ ESTO NO ES «AMPLIAR soy_staff_de_atleta»
-- La función de siempre no se toca ni una coma. Lo que se cambia,
-- una por una, son las reglas de la tabla `asistencia` y la
-- función de pasar lista. Todo lo demás sigue pidiendo ser el
-- entrenador de la ficha, y se queda así a propósito:
--
--   · notas del atleta (las de comportamiento) — ni siquiera
--     colgaban de esta puerta: tienen la suya, más estrecha
--   · lesiones del atleta
--   · notas para la familia
--   · el contacto (teléfono y correo) de la familia
--   · apuntar a alguien en un grupo (eso es administración)
--   · inscripciones a competiciones, bonos, perfil de juego
--   · avisos de falta de la familia
--
-- Lo que se escribe sobre un menor lo escribe quien lo lleva, no
-- quien coincide con él una tarde por semana. Marcar que ha
-- venido no es escribir sobre él: es decir quién estaba en la
-- pista, que es justo lo que ve el que estaba delante.
--
-- ------------------------------------------------------------
-- Y VER LA LISTA, NO SOLO MARCARLA
-- Poder marcar sin poder leer lo marcado no sirve de nada: el
-- entrenador vuelve al día siguiente, la lista le sale en blanco y
-- vuelve a pasarla entera. Así que la regla de LEER asistencia se
-- abre por la misma puerta y con el mismo alcance: las marcas de
-- MI grupo, y ninguna otra. Las de ese mismo chaval con el otro
-- entrenador siguen sin verse.
--
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta. No borra ni una marca.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LA PUERTA NUEVA
-- ------------------------------------------------------------
-- Empieza por la de siempre: quien podía, sigue pudiendo, y por
-- las mismas razones. Lo que se añade después es el caso del
-- entrenador del grupo, y va atado a ESE grupo.
--
-- `p_grupo` puede venir vacío: hay marcas antiguas apuntadas antes
-- de que el grupo entrara en la llave (migración 113). Esas se
-- quedan como estaban, con la puerta de siempre y nada más: sin
-- saber de qué grupo eran, no hay manera de decir quién lo dirigía.
--
-- ⚠️ `security definer` con `search_path` clavado (migraciones 090
-- y 106). Sin ello no podría mirar los grupos por debajo de las
-- reglas de acceso, y una regla que se llama a sí misma no acaba.
create or replace function public.puedo_pasar_lista(p_atleta uuid, p_grupo uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.soy_staff_de_atleta(p_atleta)
      or (
        p_grupo is not null
        and exists (
          select 1 from public.grupos g
           where g.id = p_grupo
             and g.entrenador_id = public.mi_perfil_id()
        )
        and p_grupo in (select public.grupos_del_atleta(p_atleta))
      );
$$;

comment on function public.puedo_pasar_lista(uuid, uuid) is
  'Si puedo marcar la asistencia de esta persona EN ESTE GRUPO. Vale la puerta '
  'de siempre (administración o el entrenador de su ficha) y además el '
  'entrenador del grupo, siempre que la persona entrene de verdad en él. Es '
  'solo para la lista: escribir notas, lesiones o el contacto de la familia '
  'sigue pidiendo ser el entrenador de la ficha.';

-- ⚠️ EL PERMISO NO VIENE SOLO (migración 090): en esta base las
-- funciones nacen cerradas. Sin el grant, las reglas que la llaman
-- fallarían y nadie podría pasar lista.
revoke execute on function public.puedo_pasar_lista(uuid, uuid) from public, anon;
grant  execute on function public.puedo_pasar_lista(uuid, uuid) to authenticated;

-- ------------------------------------------------------------
-- 2 · LAS REGLAS DE LA LISTA, UNA A UNA
-- ------------------------------------------------------------
-- Se nombran las cuatro a mano en vez de tocar la función común:
-- así se ve de un vistazo qué es lo que se ha abierto, y lo que no
-- aparece aquí es que no se ha tocado.

-- Leer. Sin esto, marcar no serviría: la lista saldría en blanco
-- al día siguiente y habría que pasarla dos veces.
drop policy if exists "ver datos de mis atletas" on public.asistencia;
create policy "ver datos de mis atletas"
  on public.asistencia for select to authenticated
  using (
    atleta_id in (select public.mis_atletas())
    or public.puedo_pasar_lista(atleta_id, grupo_id)
  );

-- Marcar.
drop policy if exists "staff pasa lista" on public.asistencia;
create policy "staff pasa lista"
  on public.asistencia for insert to authenticated
  with check (public.puedo_pasar_lista(atleta_id, grupo_id));

-- Corregir una marca ya puesta.
drop policy if exists "staff corrige la lista" on public.asistencia;
create policy "staff corrige la lista"
  on public.asistencia for update to authenticated
  using      (public.puedo_pasar_lista(atleta_id, grupo_id))
  with check (public.puedo_pasar_lista(atleta_id, grupo_id));

-- Borrar. Esta regla hoy no la usa nadie: desde la migración 113
-- las pantallas no pueden borrar asistencia por su cuenta, y el
-- único borrado pasa por `apo_pasar_lista`. Se deja dicha igual
-- que las otras tres para que, el día que alguien devuelva ese
-- permiso, no se cuele una regla distinta sin querer.
drop policy if exists "staff borra de la lista" on public.asistencia;
create policy "staff borra de la lista"
  on public.asistencia for delete to authenticated
  using (public.puedo_pasar_lista(atleta_id, grupo_id));

-- ------------------------------------------------------------
-- 3 · Y LA FUNCIÓN QUE USAN LAS PANTALLAS
-- ------------------------------------------------------------
-- `apo_pasar_lista` (migración 113) corre con los permisos del
-- dueño, así que se salta las reglas de la tabla y tiene que
-- comprobar ella misma. Comprobaba con la puerta de siempre, y por
-- eso el entrenador del segundo grupo recibía «no puedes pasarle
-- lista» justo después de ver a ese chaval en su propia lista.
--
-- Se vuelve a escribir entera —es la manera de cambiarla— pero lo
-- único que cambia es la línea que comprueba el permiso, y el
-- mensaje de error, que ahora dice también en qué grupo.
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

    -- LA LÍNEA QUE CAMBIA. Antes bastaba con no ser el entrenador de la
    -- ficha para que esto cortara, aunque el chaval estuviera en tu propio
    -- grupo y lo tuvieras delante. Ahora también abre el ser entrenador de
    -- ESTE grupo, y solo si esa persona entrena de verdad en él.
    if not public.puedo_pasar_lista(v_atleta, p_grupo) then
      raise exception 'No puedes pasarle lista a este atleta en este grupo';
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
  'queda intacta. La puede usar quien dirige ese grupo, aunque no sea el '
  'entrenador escrito en la ficha del atleta: la lista es del grupo.';

revoke execute on function public.apo_pasar_lista(uuid, date, jsonb, uuid) from public, anon;
grant  execute on function public.apo_pasar_lista(uuid, date, jsonb, uuid) to authenticated;

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- solo la asistencia ha cambiado de puerta; el resto sigue igual
--   select tablename, policyname from pg_policies
--    where schemaname = 'public'
--      and coalesce(qual,'') || coalesce(with_check,'') ilike '%puedo_pasar_lista%';
--   -- tienen que salir cuatro, y las cuatro de `asistencia`
--
--   -- y con los papeles puestos, en una transacción que se deshace:
--   begin; set local role authenticated;
--     set local request.jwt.claims to '{"email":"…","role":"authenticated"}';
--     select apo_pasar_lista('<grupo>', current_date, '{"<atleta>": true}'::jsonb);
--   rollback;
-- ------------------------------------------------------------
