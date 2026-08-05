-- ============================================================
-- 139 · Repartir a los niños entre los grupos
-- ------------------------------------------------------------
-- PARA QUÉ ES ESTO
-- En septiembre entran unas cuatrocientas familias y hay que
-- repartir a los niños entre los dieciocho grupos de la escuela.
-- Hoy se hace ficha por ficha: abrir a un niño, cambiarle el
-- grupo, guardar y volver. Con cuatrocientos no se acaba nunca, y
-- lo peor no son los clics: es que así NO SE VE EL CONJUNTO, que
-- es justo lo que hace falta para decidir dónde va cada uno.
--
-- La pantalla nueva (admin/repartir/) enseña todos los grupos con
-- sus niños a la vez y deja moverlos. Esta migración le pone
-- debajo las dos únicas cosas que no puede resolver ella sola:
--
--   1 · LEER el reparto entero de una vez, con los hermanos y los
--       amigos ya cruzados. Son tres tablas distintas y cruzarlas
--       desde el navegador serían cuatrocientas consultas.
--   2 · MOVER a varios niños a la vez, en una sola operación que
--       o entra entera o no entra. Sin esto, un corte de conexión
--       a mitad de mover a seis hermanos deja a tres colocados y
--       tres en el aire, y nadie sabe cuáles.
--
-- ------------------------------------------------------------
-- LA DECISIÓN DE FONDO: MOVER NO ES LO MISMO QUE AÑADIR
-- Desde la 116 un niño puede estar en varios grupos a la vez: la
-- escuela de primera hora y el Cubo, o dos horas el mismo día. Eso
-- obliga a contestar una pregunta que antes no existía: cuando en
-- el tablero arrastras a alguien que está en dos sitios, ¿qué se
-- le quita?
--
-- La respuesta que se ha tomado: SE LE QUITA EL GRUPO DEL QUE LO
-- SACAS, Y NADA MÁS. Por eso mover lleva siempre dos datos —de
-- dónde sale y adónde va— y no solo el destino. El niño que está
-- en Azul 1 y en el Cubo, arrastrado de Azul 1 a Azul 2, se queda
-- en Azul 2 y en el Cubo. El Cubo no se entera.
--
-- Es lo contrario de lo que hace la ficha, que solo sabe de una
-- casilla y al cambiarla se lleva por delante lo que hubiera. Y es
-- lo que se espera al arrastrar: sacas una tarjeta de una columna
-- y la sueltas en otra; las columnas que no estás mirando no se
-- tocan.
--
-- El que manda (`atletas.grupo_id`, el «grupo principal») viaja
-- con el niño: si el grupo del que sale era el suyo principal, el
-- de destino pasa a serlo. Si venía de la columna «Sin grupo» y no
-- tenía ninguno, el destino pasa a ser el principal. Y si ya tenía
-- un principal en otro sitio, ese sigue mandando: entrar en un
-- grupo nuevo no es motivo para cambiarle cuál es el suyo de
-- siempre.
--
-- ------------------------------------------------------------
-- LAS PLAZAS AVISAN, NO IMPIDEN
-- Aquí no hay ni una comprobación de plazas, y es a propósito. Los
-- grupos tienen dieciocho, y el club decidió que si hace falta
-- meter al diecinueve a mano se pueda. La pantalla lo pinta en
-- rojo —«19/18»— y deja soltar igual. Poner el freno en la base
-- sería desdecir esa decisión desde abajo, donde no se ve.
--
-- ------------------------------------------------------------
-- QUIÉN ENTRA AQUÍ, HOY
-- Solo administración. No es la respuesta final —está por decidir
-- si coordinación debe poder repartir su sección y nada más—, es
-- la respuesta prudente mientras se decide: administración ya
-- podía hacer esto mismo ficha por ficha, así que la pantalla no
-- le da ningún poder que no tuviera; solo se lo hace llevadero.
--
-- Todo el permiso está en UNA función, `apo_puede_repartir()`,
-- para que el día que se decida ampliarlo se toque una línea y no
-- tres funciones.
--
-- IDEMPOTENTE. No borra ni una ficha ni cambia ni un dato: solo
-- crea funciones.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · QUIÉN PUEDE REPARTIR
-- ------------------------------------------------------------
-- Una sola puerta para las dos funciones de abajo: la que lee el
-- tablero y la que mueve. Si algún día entra coordinación, entra
-- por aquí y por ningún otro sitio.
--
-- Tesorería y contabilidad NO entran, aunque el panel les abra la
-- puerta de /admin/: repartir críos entre grupos no es dinero.
-- Un entrenador tampoco: la ficha ya le deja mover a los suyos a
-- un grupo que dirija él (migración 130), y eso es lo suyo; esta
-- pantalla es la del conjunto, y el conjunto no es de nadie en
-- particular.
create or replace function public.apo_puede_repartir()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.es_admin();
$$;

comment on function public.apo_puede_repartir() is
  'Quién puede usar la pantalla de repartir la escuela. Hoy solo administración. '
  'Está en una función suelta para que ampliarlo —si el club decide que coordinación '
  'reparta su sección— sea cambiar una línea y no tres funciones.';

-- ------------------------------------------------------------
-- 2 · EL TABLERO ENTERO, DE UNA VEZ
-- ------------------------------------------------------------
-- Devuelve los grupos de la escuela con turno y todos los niños
-- que hay que repartir, cada uno con lo que la pantalla necesita
-- para avisar: en qué grupos está, quiénes son sus hermanos y con
-- quién pidió la familia que entrenara.
--
-- POR QUÉ VA JUNTO Y NO EN CUATRO CONSULTAS
-- Los hermanos salen de cruzar dos cosas (los que comparten padre
-- o madre en la ficha y los que vinieron apuntados en el mismo
-- alta) y los amigos viven en la tabla de las altas, que el
-- navegador tendría que consultar niño a niño. Cuatrocientos niños
-- son cuatrocientas idas y venidas; así es una.
--
-- QUIÉN SALE EN EL TABLERO
-- Un niño es «de la escuela» si se cumple cualquiera de estas:
--   · está en uno de los grupos de escuela con turno;
--   · entró por un alta de escuela;
--   · su ficha dice que es de escuela;
--   · nació en los años que cubre la escuela y no está en ningún
--     grupo — este último es el que hace que un niño al que sacas
--     del grupo siga en el tablero, en la columna «Sin grupo», en
--     vez de desaparecer como si lo hubieras borrado.
create or replace function public.apo_reparto_escuela()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_out jsonb;
begin
  if not public.apo_puede_repartir() then
    raise exception 'Esta pantalla es de administración.';
  end if;

  with grupos_escuela as (
    -- Los dieciocho: sección escuela y con turno. Los grupos de
    -- escuela sin turno (el de competición, los apagados de antes)
    -- no son columnas del tablero.
    select g.id, g.nombre, g.turno, g.plazas, g.horario,
           g.nacidos_desde, g.nacidos_hasta, g.entrenador_id
      from public.grupos g
     where g.seccion = 'escuela' and g.turno is not null
  ),
  anios as (
    select min(nacidos_desde) as desde, max(nacidos_hasta) as hasta
      from grupos_escuela
  ),
  universo as (
    select a.id, a.nombre, a.apellidos, a.sexo, a.fecha_nacimiento,
           a.grupo_id, a.perfil_padre_id
      from public.atletas a
     where coalesce(a.estado, 'activo') <> 'baja'
       and (
         exists (select 1 from grupos_escuela g
                  where g.id = a.grupo_id
                     or exists (select 1 from public.atleta_grupos ag
                                 where ag.atleta_id = a.id and ag.grupo_id = g.id))
         or exists (select 1 from public.altas_escuela_ninos n where n.atleta_id = a.id)
         or a.tipo_membresia = 'escuela'
         or (a.fecha_nacimiento is not null
             and a.grupo_id is null
             and extract(year from a.fecha_nacimiento)
                 between (select desde from anios) and (select hasta from anios)
             and not exists (select 1 from public.atleta_grupos ag where ag.atleta_id = a.id))
       )
  ),
  -- Los grupos de cada niño, de los que son columna del tablero.
  -- Se suma la casilla vieja de la ficha porque, mientras las dos
  -- convivan, la respuesta completa es la suma (migración 116).
  suyos as (
    select u.id as atleta_id, ag.grupo_id, bool_or(ag.principal) as principal
      from universo u
      join public.atleta_grupos ag on ag.atleta_id = u.id
     group by 1, 2
    union
    select u.id, u.grupo_id, true
      from universo u
     where u.grupo_id is not null
       and not exists (select 1 from public.atleta_grupos ag
                        where ag.atleta_id = u.id and ag.grupo_id = u.grupo_id)
  ),
  -- Hermanos. Dos maneras de saberlo, las dos valen: comparten
  -- padre o madre en la ficha, o los apuntaron en la misma alta.
  -- Se agrupa por una clave en vez de cruzar todos con todos:
  -- con cuatrocientos niños, cruzar todos con todos son ciento
  -- sesenta mil comparaciones para nada.
  claves as (
    select u.id as atleta_id, 'padre:' || u.perfil_padre_id::text as clave
      from universo u where u.perfil_padre_id is not null
    union all
    select n.atleta_id, 'alta:' || n.alta_id::text
      from public.altas_escuela_ninos n
     where n.atleta_id in (select id from universo)
  ),
  hermanos as (
    select distinct c1.atleta_id, c2.atleta_id as hermano_id
      from claves c1
      join claves c2 on c2.clave = c1.clave and c2.atleta_id <> c1.atleta_id
  ),
  -- «Con quién le gustaría estar», tal y como lo escribió la
  -- familia al apuntarse. Si hay varias altas del mismo niño manda
  -- la última: es la que refleja lo que pidió este año.
  amigos as (
    select distinct on (n.atleta_id) n.atleta_id, n.amigos, n.turno
      from public.altas_escuela_ninos n
     where n.atleta_id in (select id from universo)
     order by n.atleta_id, n.created_at desc
  )
  select jsonb_build_object(
    'grupos', (
      select coalesce(jsonb_agg(jsonb_build_object(
                'id', g.id,
                'nombre', g.nombre,
                'turno', g.turno,
                'plazas', g.plazas,
                'horario', g.horario,
                'desde', g.nacidos_desde,
                'hasta', g.nacidos_hasta,
                'entrenador', (select p.nombre from public.perfiles p where p.id = g.entrenador_id)
              ) order by g.nombre, g.turno), '[]'::jsonb)
        from grupos_escuela g
    ),
    'ninos', (
      select coalesce(jsonb_agg(jsonb_build_object(
                'id', u.id,
                'nombre', u.nombre,
                'apellidos', coalesce(u.apellidos, ''),
                'sexo', u.sexo,
                'anio', extract(year from u.fecha_nacimiento)::int,
                'grupos', (select coalesce(jsonb_agg(s.grupo_id), '[]'::jsonb)
                             from suyos s where s.atleta_id = u.id),
                'principal', (select s.grupo_id from suyos s
                               where s.atleta_id = u.id and s.principal limit 1),
                'hermanos', (select coalesce(jsonb_agg(h.hermano_id), '[]'::jsonb)
                               from hermanos h where h.atleta_id = u.id),
                'amigos', (select coalesce(to_jsonb(am.amigos), '[]'::jsonb)
                             from amigos am where am.atleta_id = u.id),
                'turno_pedido', (select am.turno from amigos am where am.atleta_id = u.id)
              ) order by u.nombre, u.apellidos), '[]'::jsonb)
        from universo u
    )
  ) into v_out;

  return v_out;
end;
$$;

comment on function public.apo_reparto_escuela() is
  'Todo lo que enseña la pantalla de repartir la escuela, de una vez: los grupos con '
  'turno y los niños que hay que colocar, cada uno con sus grupos, sus hermanos y los '
  'amigos que pidió la familia. Va junto porque cruzarlo desde el navegador serían '
  'cuatrocientas consultas.';

-- ------------------------------------------------------------
-- 3 · MOVER, DE UNO EN UNO O DE SEIS EN SEIS
-- ------------------------------------------------------------
-- `p_origen` es la columna de la que sale la tarjeta y `p_destino`
-- aquella en la que se suelta. Cualquiera de los dos puede ir
-- vacío:
--   · origen vacío  = venía de «Sin grupo»;
--   · destino vacío = se le saca del grupo y vuelve a «Sin grupo».
--
-- Y esa simetría es lo que hace que DESHACER sea gratis: deshacer
-- un movimiento es el mismo movimiento con el origen y el destino
-- cambiados de sitio. No hace falta guardar historial en ninguna
-- parte.
create or replace function public.apo_repartir_escuela(
  p_atletas uuid[],
  p_origen  uuid default null,
  p_destino uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_atletas uuid[] := coalesce(p_atletas, array[]::uuid[]);
  v_x       uuid;
  v_manda   boolean;
  v_hechos  int := 0;
begin
  if not public.apo_puede_repartir() then
    raise exception 'Esta pantalla es de administración.';
  end if;

  if array_length(v_atletas, 1) is null then
    raise exception 'No has dicho a quién mover';
  end if;

  if p_origen is null and p_destino is null then
    raise exception 'Hay que decir de dónde sale o adónde va';
  end if;

  -- Ni el origen ni el destino pueden ser un grupo que no sea del
  -- tablero. Sin esto, esta función sería una puerta trasera para
  -- meter a un niño de seis años en el grupo de competición.
  if p_destino is not null and not exists (
       select 1 from public.grupos g
        where g.id = p_destino and g.seccion = 'escuela' and g.turno is not null) then
    raise exception 'Ese no es un grupo de la escuela';
  end if;
  if p_origen is not null and not exists (
       select 1 from public.grupos g
        where g.id = p_origen and g.seccion = 'escuela' and g.turno is not null) then
    raise exception 'Ese no es un grupo de la escuela';
  end if;

  -- Soltar la tarjeta donde ya estaba no es un movimiento.
  if p_origen is not distinct from p_destino then
    return jsonb_build_object('movidos', 0, 'origen', p_origen, 'destino', p_destino);
  end if;

  foreach v_x in array v_atletas loop
    if not exists (select 1 from public.atletas a where a.id = v_x) then
      raise exception 'Ese niño no existe: %', v_x;
    end if;

    -- ¿El grupo de destino pasa a ser el suyo principal? Sí en dos
    -- casos: si lo era el de origen (el que manda viaja con él), o
    -- si no tenía ninguno. Si ya tenía otro principal en otro
    -- sitio, ese sigue mandando.
    if p_origen is not null then
      v_manda := exists (select 1 from public.atleta_grupos ag
                          where ag.atleta_id = v_x and ag.grupo_id = p_origen and ag.principal);
    else
      v_manda := false;
    end if;
    if not v_manda then
      v_manda := not exists (select 1 from public.atleta_grupos ag
                              where ag.atleta_id = v_x and ag.principal);
    end if;

    -- Primero se le quita el de origen y después se le pone el de
    -- destino, en este orden: la base no consiente dos principales
    -- a la vez ni por un instante.
    if p_origen is not null then
      delete from public.atleta_grupos ag
       where ag.atleta_id = v_x and ag.grupo_id = p_origen;
    end if;

    if p_destino is not null then
      insert into public.atleta_grupos (atleta_id, grupo_id, principal)
      values (v_x, p_destino, v_manda)
      on conflict (atleta_id, grupo_id) do update
         set principal = public.atleta_grupos.principal or excluded.principal;
    end if;

    v_hechos := v_hechos + 1;
  end loop;

  return jsonb_build_object(
    'movidos', v_hechos,
    'origen',  p_origen,
    'destino', p_destino,
    'atletas', to_jsonb(v_atletas)
  );
end;
$$;

comment on function public.apo_repartir_escuela(uuid[], uuid, uuid) is
  'Mueve a uno o a varios niños de un grupo de la escuela a otro, de una vez. Le quita '
  'el grupo del que sale y nada más: quien esté además en el Cubo sigue en el Cubo. '
  'Con el origen y el destino cambiados de sitio, deshace el movimiento.';

-- ⚠️ EL PERMISO NO VIENE SOLO (migración 090): en esta base las
-- funciones nacen cerradas. Sin el grant, la pantalla se encuentra
-- un «no existe esa función» y no hay manera de adivinar por qué.
revoke execute on function public.apo_puede_repartir()                     from public, anon;
revoke execute on function public.apo_reparto_escuela()                    from public, anon;
revoke execute on function public.apo_repartir_escuela(uuid[], uuid, uuid) from public, anon;
grant  execute on function public.apo_puede_repartir()                     to authenticated;
grant  execute on function public.apo_reparto_escuela()                    to authenticated;
grant  execute on function public.apo_repartir_escuela(uuid[], uuid, uuid) to authenticated;

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
-- ------------------------------------------------------------
-- 1 · Los dieciocho grupos de la escuela, con sus dieciocho plazas
--     y el año que le toca a cada nivel.
select nombre, turno, plazas, nacidos_desde
  from public.grupos
 where seccion = 'escuela' and turno is not null
 order by nombre, turno;

-- 2 · Cuántos niños hay que repartir y cuántos están ya colocados.
--     (Hay que lanzarlo con una sesión de administración; sin ella
--     la función contesta que la pantalla no es suya, que es
--     justamente lo que tiene que hacer.)
select jsonb_array_length(apo_reparto_escuela() -> 'ninos') as ninos,
       jsonb_array_length(apo_reparto_escuela() -> 'grupos') as grupos;

-- 3 · Que nadie tiene dos grupos principales. Esto no puede salir
--     ni una fila, ni antes ni después de repartir.
select atleta_id, count(*)
  from public.atleta_grupos
 where principal
 group by 1 having count(*) > 1;
