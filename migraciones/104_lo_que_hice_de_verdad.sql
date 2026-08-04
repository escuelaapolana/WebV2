-- ============================================================
-- 104 · Lo que hice de verdad: el cambio de ejercicio, el % de RM
--       y poder corregir lo apuntado sin que se pierda el rastro
-- ------------------------------------------------------------
-- DE DÓNDE SALE ESTO
-- El dueño del club entrenó con la app y pasaron tres cosas el
-- mismo día. Ninguna es teórica.
--
-- 1) El entrenamiento decía sentadilla hack, press banca y jalón
--    al pecho. Él hizo sentadillas normales, flexiones y
--    dominadas, porque no tenía esas máquinas. La app guardó
--    «jalón al pecho». EL DATO ERA FALSO. Y si mañana quiere ver
--    su progresión en dominadas, no hay nada que ver.
--
-- 2) En la fila ponía «80 % RM» y el atleta no sabía cuántos
--    kilos son ESOS 80 % para él. En pista eso ya está resuelto
--    («al 85 % son 44,8 s, desde tu 38,1 de mayo»); en pesas no.
--
-- 3) Un chaval tecleó mal un peso de hace dos semanas y no había
--    forma de arreglarlo: el feedback de días pasados no se podía
--    tocar.
--
-- ============================================================
-- PARTE 1 · «LO CAMBIÉ POR OTRA COSA»
-- ------------------------------------------------------------
-- NO HACE FALTA TABLA NI COLUMNA. Lo que el atleta apunta de cada
-- ejercicio ya vive dentro de `registros_sesion.tiempos_reales`
-- (migración 103), una entrada por fila del entrenamiento. Se le
-- añade un campo más DENTRO, que es lo barato:
--
--   { "<uuid de la fila>": {
--       "fila_id":      "<el mismo uuid>",
--       "ejercicio":    "Jalón al pecho",     <-- lo que MANDÓ el entrenador
--       "cambiado_por": "Dominadas",          <-- lo que HIZO el atleta
--       "medida":       "peso_reps",
--       "series":  [...],
--       "tiempos": [...]
--     } }
--
-- POR QUÉ EL NOMBRE MANDADO SE QUEDA
-- Porque son dos datos distintos y los dos hacen falta. El
-- entrenador tiene que ver que puso jalón y salieron dominadas
-- —eso le dice que en esa sala no hay polea, y quizá que la
-- próxima semana planifique otra cosa—. Y el atleta tiene que ver
-- en su historial DOMINADAS, que es lo que hizo. Si se pisara el
-- nombre, se perdería la mitad de la información y además se
-- rompería la comprobación de la migración 103, que usa el nombre
-- guardado para no colgarle a un ejercicio los kilos de otro.
--
-- SE ESCRIBE A MANO Y YA ESTÁ
-- El club lo dijo con esas palabras: nada de banco de ejercicios,
-- nada de listas por grupo muscular. Un campo de texto y fuera.
-- Un desplegable de 200 ejercicios se maneja fatal de pie, entre
-- serie y serie, con una mano y sudando; y el día que el atleta
-- haga algo que no está en la lista, se queda sin poder decirlo.
--
-- EL EJERCICIO SIGUE CONTANDO COMO HECHO
-- Cambiarlo no es no hacerlo. Las series llevan su ✓ igual, así
-- que `apo_series_hechas` y el estado del día no cambian ni una
-- línea. Aquí no hay nada nuevo que contar.
--
-- ============================================================
-- PARTE 2 · EL PORCENTAJE DE PESO SALE DE LA REPETICIÓN MÁXIMA
-- ------------------------------------------------------------
-- La tabla `rm_atleta` existía desde el principio y estaba VACÍA:
-- nadie tenía forma de meter nada en ella. Aquí se le da uso.
--
-- ⚠️ EN PESAS SE MULTIPLICA. EN PISTA SE DIVIDE. NO ES LO MISMO.
--   · Pista: el porcentaje es de ESFUERZO. Correr al 85 % es ir
--     MÁS LENTO que tu mejor marca: 38,1 s al 85 % son 44,8 s.
--     Se divide (38,1 / 0,85).
--   · Pesas: el porcentaje es de CARGA. El 85 % de un RM de 80 kg
--     son 68 kg, MENOS peso. Se multiplica (80 × 0,85).
-- Si se hace al revés el número sale razonable —80 / 0,85 = 94 kg,
-- que parece un peso de gimnasio perfectamente normal— y está
-- mal. Alguien se pondría 94 kg creyendo que hace el 85 %. Por eso
-- esto va escrito aquí y en el código, con estas palabras.
--
-- SE GUARDA EL HISTORIAL DE TESTS, NO SOLO EL ÚLTIMO
-- Una fila por test (atleta, ejercicio, peso, fecha). El RM que
-- vale hoy es el del test más reciente, y los anteriores se
-- quedan: la progresión de la sentadilla de un atleta a lo largo
-- de la temporada es justo lo que el club quiere poder mirar. Y
-- corregir un RM mal tecleado es editar SU fila, no perder las
-- otras.
--
-- SI NO HAY RM, NO SALE NADA
-- Nunca un número estimado a partir de las repeticiones ni de
-- nada parecido. Un peso inventado en un ejercicio de fuerza es
-- una lesión esperando a pasar.
--
-- ============================================================
-- PARTE 3 · CORREGIR, DEJANDO RASTRO CUANDO TOCA
-- ------------------------------------------------------------
-- El club: «que se pueda corregir, eso es importantísimo».
--
-- Y con criterio, que es lo que pidió:
--   · Lo del MISMO DÍA se corrige sin más. Es lo que está
--     pasando ahora mismo; nadie tiene que enterarse de que has
--     escrito 60 y luego 65.
--   · Lo de HACE SEMANAS también se puede corregir, pero se nota
--     y se sabe cuándo. Un dato de hace un mes que cambia sin
--     dejar rastro es peor que uno equivocado: el equipo técnico
--     tomó decisiones mirando el número de antes.
--
-- LO DECIDE LA BASE, NO LA PANTALLA. Si lo marcara la pantalla,
-- bastaría con guardar desde otro sitio (o con que alguien se
-- olvidara de ponerlo el día que monte otra pantalla) para que la
-- corrección pasara sin rastro. El disparador lo pone siempre.
--
-- Y SOLO SI DE VERDAD CAMBIA ALGO: abrir el entrenamiento de hace
-- un mes y volver a darle a guardar sin tocar nada no es una
-- corrección, y marcarlo como tal sería mentir en la dirección
-- contraria.
--
-- ============================================================
-- IDEMPOTENTE
-- Se puede lanzar las veces que haga falta: columnas «if not
-- exists», funciones «create or replace», políticas que se tiran
-- antes de crearse y ningún borrado de datos en ninguna parte.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · QUIÉN ES EL ENTRENADOR DE ESTE ATLETA
-- ------------------------------------------------------------
-- Hacía falta una respuesta a esta pregunta y no había ninguna
-- limpia. `mis_atletas_entreno()` no sirve para esto: ahí dentro
-- está TAMBIÉN el propio atleta (por `perfil_id`), y usarla para
-- decidir quién puede fijar un RM o escribir un comentario de
-- entrenador dejaría que el atleta se los pusiera él mismo.
--
-- Vale por las dos vías por las que alguien lleva a un atleta: el
-- entrenador puesto en su ficha, y el que lleva su grupo. En el
-- club conviven las dos y ninguna sobra.
create or replace function public.soy_entrenador_de(p_atleta uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1
      from public.atletas a
      left join public.grupos g on g.id = a.grupo_id
     where a.id = p_atleta
       and (a.entrenador_id = public.mi_perfil_id()
            or g.entrenador_id = public.mi_perfil_id())
  );
$$;

comment on function public.soy_entrenador_de(uuid) is
  'Si quien está mirando es el entrenador de ese atleta, por su ficha o por su '
  'grupo. Distinta de mis_atletas_entreno(), que incluye al propio atleta: para '
  'decidir quién FIJA un RM o ESCRIBE un comentario de entrenador, el atleta no '
  'cuenta.';

-- ⚠️ EL PERMISO DE EJECUCIÓN NO ES OPCIONAL Y NO VIENE SOLO.
-- En esta base las funciones NACEN CERRADAS (migración 090): un
-- disparador les quita el permiso a todo el mundo nada más
-- crearlas. Las condiciones de una política de seguridad se
-- evalúan con el permiso de quien consulta, así que sin este
-- grant la política no falla «cerrando de más»: PETA, y el atleta
-- ve un error en vez de su pantalla.
grant execute on function public.soy_entrenador_de(uuid) to authenticated;

-- ------------------------------------------------------------
-- 2 · LA REPETICIÓN MÁXIMA DE CADA ATLETA
-- ------------------------------------------------------------
-- La tabla ya existía. Se le pone lo que le faltaba para poder
-- usarse: una fecha por defecto, saber quién la apuntó, y que no
-- se dupliquen dos tests del mismo ejercicio el mismo día.
alter table public.rm_atleta alter column fecha_test set default current_date;
alter table public.rm_atleta add column if not exists anotado_por uuid references public.perfiles(id);
alter table public.rm_atleta add column if not exists nota text;

comment on table public.rm_atleta is
  'La repetición máxima (RM) de un atleta en un ejercicio: el peso que levantó '
  'una vez, y cuándo. Es de donde salen los kilos cuando el entrenamiento dice '
  '«80 % RM». Una fila por test: el que vale hoy es el más reciente y los '
  'anteriores se quedan, porque la progresión de la sentadilla a lo largo de la '
  'temporada es justo lo que el club quiere mirar.';
comment on column public.rm_atleta.peso_kg is
  'Kilos que levantó UNA vez. De aquí sale el peso del día: el 85 % de 80 kg son '
  '68 kg. SE MULTIPLICA. En pista el porcentaje se divide porque allí es de '
  'esfuerzo, aquí es de carga, y confundirlos da números creíbles y falsos.';
comment on column public.rm_atleta.fecha_test is
  'Cuándo se midió. Va SIEMPRE a la vista junto al peso calculado: un RM de hace '
  'ocho meses ya no es el de ahora, y quien lo lee tiene que poder darse cuenta.';
comment on column public.rm_atleta.anotado_por is
  'Qué entrenador lo apuntó. Un RM no lo decide el atleta.';
comment on column public.rm_atleta.nota is
  'Opcional: «con cinturón», «medido en el test de octubre». Lo que haga falta '
  'para que dentro de seis meses el número siga significando lo mismo.';

-- Dos tests del mismo ejercicio el mismo día son un doble clic,
-- no dos tests. El índice normaliza el nombre (minúsculas y sin
-- espacios de sobra) porque «Sentadilla» y «sentadilla » son el
-- mismo ejercicio para cualquiera que lo lea.
create unique index if not exists rm_atleta_unico_por_dia
  on public.rm_atleta (atleta_id, lower(btrim(ejercicio)), fecha_test);

-- La pregunta que se hace de verdad: «¿cuál es el RM de ESTE
-- atleta en ESTE ejercicio?», y se hace una vez por ejercicio
-- cada vez que alguien abre un entrenamiento de pesas.
create index if not exists idx_rm_atleta_ejercicio
  on public.rm_atleta (atleta_id, lower(btrim(ejercicio)), fecha_test desc);

-- --- permisos ---
-- LEER: el atleta lo suyo, y su entrenador. Antes la política
-- usaba `mis_atletas()`, que incluye a las FAMILIAS. El club
-- decidió que las familias quedan fuera del entrenamiento
-- (migración 100) y un RM es entrenamiento del todo: es el peso
-- máximo que levanta un chaval de quince años, y no es asunto de
-- la conversación que el club tiene con su familia. Se cambia a
-- `mis_atletas_entreno()`, que es la misma lista sin las
-- familias.
drop policy if exists "ver datos de mis atletas" on public.rm_atleta;
create policy "ver datos de mis atletas" on public.rm_atleta
  for select to authenticated
  using (atleta_id in (select public.mis_atletas_entreno()));

-- ESCRIBIR: solo su entrenador. Un RM no se lo pone el atleta a
-- sí mismo; si pudiera, el «80 % RM» del entrenamiento dejaría de
-- querer decir nada.
drop policy if exists "entrenador fija el rm" on public.rm_atleta;
create policy "entrenador fija el rm" on public.rm_atleta
  for all to authenticated
  using (public.soy_entrenador_de(atleta_id))
  with check (public.soy_entrenador_de(atleta_id));

-- ------------------------------------------------------------
-- 3 · EL RASTRO DE LAS CORRECCIONES
-- ------------------------------------------------------------
alter table public.registros_sesion add column if not exists corregido_en    timestamptz;
alter table public.registros_sesion add column if not exists corregido_veces integer not null default 0;

comment on column public.registros_sesion.corregido_en is
  'Cuándo se tocó por última vez lo apuntado de un día YA PASADO. Lo del mismo '
  'día no cuenta: corregir sobre la marcha es escribir, no rectificar. Va a la '
  'vista en la pantalla del atleta y en la del entrenador, porque un dato de hace '
  'un mes que cambia sin que se note es peor que uno equivocado.';
comment on column public.registros_sesion.corregido_veces is
  'Cuántas veces. Dos correcciones de un mismo día pasado se leen distinto que '
  'una, y sin este número la fecha sola no lo dice.';

-- ------------------------------------------------------------
-- 4 · EL DISPARADOR, AMPLIADO
-- ------------------------------------------------------------
-- Es el mismo de la migración 103 (deduce completo / a_medias /
-- no_hecho contando las series con ✓) con el rastro de las
-- correcciones añadido al final. Se reemplaza entero porque en
-- Postgres una función se sustituye completa; la parte de arriba
-- es idéntica a la de 103 a propósito, para que quien compare las
-- dos vea que solo se ha añadido, no cambiado.
-- ⚠️ `security definer` con el `search_path` clavado: sin eso, las dos
-- funciones que llama aquí abajo están cerradas para el atleta
-- (migración 090, las funciones nacen cerradas) y NO SE PUEDE GUARDAR.
-- Está contado entero en la migración 106; va también aquí para que
-- volver a lanzar este fichero no deshaga el arreglo.
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

  -- ---------- lo nuevo de la 104 ----------
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
  'con ✓ (migración 103) y, desde la 104, deja el rastro cuando se corrige lo '
  'apuntado de un día YA PASADO. Lo del mismo día se corrige sin rastro: sobre la '
  'marcha se está escribiendo, no rectificando.';

-- El disparador es el mismo de siempre; se vuelve a crear por si
-- esta migración se lanza en una base donde no estuviera.
drop trigger if exists trg_registros_estado on public.registros_sesion;
create trigger trg_registros_estado
  before insert or update on public.registros_sesion
  for each row execute function public.apo_registros_estado();

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- la tabla de RM ya admite filas y no deja duplicados del mismo día
--   \d rm_atleta
--
--   -- nadie sale marcado como corregido de golpe (aún no se ha corregido nada)
--   select count(*) from registros_sesion where corregido_en is not null;
--
--   -- un ejercicio cambiado se lee así dentro de lo apuntado
--   select r.id, e.value->>'ejercicio' as mandado, e.value->>'cambiado_por' as hecho
--     from registros_sesion r, jsonb_each(r.tiempos_reales) e
--    where e.value->>'cambiado_por' is not null;
--
--   -- el RM que vale hoy de cada atleta y ejercicio
--   select distinct on (atleta_id, lower(btrim(ejercicio)))
--          atleta_id, ejercicio, peso_kg, fecha_test
--     from rm_atleta
--    order by atleta_id, lower(btrim(ejercicio)), fecha_test desc;
-- ------------------------------------------------------------
