-- ============================================================
-- 065 · «SE PONE SOLO» · contadores honrados y red de seguridad
-- ------------------------------------------------------------
-- QUÉ SE ARREGLA
--
-- 1) EL CONTADOR MENTÍA. `generar_entrenos_fijos` devolvía siempre
--    `saltadas = 0`, aunque se hubiera saltado medio calendario. El
--    fallo: `get diagnostics ... row_count` se leía SOLO después del
--    primer borrado (el de festivos) y nunca después del segundo (los
--    días que ya tienen sesión puesta por una persona).
--
--    En la semana del 2 al 9 de agosto eso significaba: crea 24
--    sesiones, se salta 42 día-grupo porque ya había trabajo hecho a
--    mano — y decía «saltadas: 0». Parecía que la regla no se estaba
--    cumpliendo. Se estaba cumpliendo; lo que fallaba era el parte.
--
--    Ahora se cuentan por separado y con su nombre:
--      · saltadas_festivo  → festivos y cierres de instalación
--      · saltadas_persona  → días que ya tienen sesión de una persona
--      · saltadas_quitadas → días que alguien quitó a mano
--
-- 2) RED DE SEGURIDAD DENTRO DE LA PROPIA FUNCIÓN. Esto va a escribir
--    en el calendario real sin que nadie lo mire, así que tiene que
--    ser INCAPAZ de duplicar. Antes de escribir una sola fila calcula
--    cómo quedaría el calendario y comprueba dos cosas:
--
--      a) que ninguna sesión automática caiga el mismo día que una
--         puesta por una persona, para el mismo grupo;
--      b) que ningún grupo acabe con más sesiones automáticas un día
--         de las que dice su propio horario para ese día.
--
--    Si algo no cuadra, NO ESCRIBE NADA y avisa. En simulación el
--    aviso sale en la columna `aviso`; al publicar de verdad corta con
--    un error, que es lo único que no se puede pasar por alto.
--
-- ⚠️ GRUPOS CON DOS ENTRENOS EL MISMO DÍA
--    No es un duplicado: es un horario con dos franjas ese día (por
--    ejemplo, mañana y tarde). Por eso el listón de la comprobación (b)
--    no es «uno por día», sino «tantos como franjas activas tenga ese
--    grupo ese día de la semana». Hoy no hay ninguno así —lo impide
--    además el índice único (grupo, día, hora)—, pero el día que lo
--    haya funcionará solo, sin tomarlo por un error.
--
-- ⚠️ LOS DUPLICADOS QUE YA HABÍA NO SON COSA DE ESTO
--    En los datos de hoy hay 4 días con dos sesiones para «Velocidad ·
--    Sub-20», y las ocho las puso una persona (vienen de dos
--    microciclos que se solapan). El generador ni las creó ni las
--    puede tocar. La red de seguridad mira SOLO lo que genera él: si
--    se bloqueara por lo que ya había, no publicaría nunca y encima
--    culparía al sistema de un solape de planificación.
--    Para verlos hay `public.entrenos_duplicados()`.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/065_automatizaciones_arreglo.sql
-- (Idempotente. No escribe ni una sesión: solo cambia funciones.)
-- ============================================================


-- =====================================================================
-- 1 · UN INFORME DE DUPLICADOS, PARA PODER MIRARLOS
-- ---------------------------------------------------------------------
-- Dice, para cada grupo y día con más sesiones de las que toca, cuántas
-- hay, cuántas debería haber y de quién son. `de_personas` significa
-- que el solape lo hizo alguien planificando, no la automatización.
-- =====================================================================
create or replace function public.entrenos_duplicados(
  p_desde date default null,
  p_hasta date default null
)
returns table (
  grupo        text,
  fecha        date,
  cuantas      integer,
  deberia      integer,
  automaticas  integer,
  de_personas  integer,
  detalle      text
)
language sql
stable
security definer
set search_path = public
as $$
  with rango as (
    select coalesce(p_desde, current_date)      as d1,
           coalesce(p_hasta, current_date + 41) as d2
  )
  select g.nombre,
         s.fecha,
         count(*)::int,
         greatest(1, (select count(*)::int from public.grupo_horarios h
                       where h.grupo_id = s.grupo_id and h.activo
                         and h.dia_semana = extract(isodow from s.fecha)::int)),
         count(*) filter (where s.auto_generada)::int,
         count(*) filter (where not coalesce(s.auto_generada, false))::int,
         string_agg(coalesce(to_char(s.hora, 'HH24:MI'), 'sin hora') || ' · ' ||
                    coalesce(s.titulo, 'sin título'), ' · ' order by s.hora nulls last)
    from public.sesiones s
    join public.grupos g on g.id = s.grupo_id
    cross join rango r
   where (auth.uid() is null or public.es_staff())
     and s.fecha between r.d1 and r.d2
   group by g.nombre, s.grupo_id, s.fecha
  having count(*) > greatest(1, (select count(*)::int from public.grupo_horarios h
                                  where h.grupo_id = s.grupo_id and h.activo
                                    and h.dia_semana = extract(isodow from s.fecha)::int))
   order by s.fecha, g.nombre;
$$;

comment on function public.entrenos_duplicados(date, date) is
  'Días con más sesiones de las que dice el horario del grupo. Mira también las que puso una persona, para poder distinguir de quién es el solape.';


-- =====================================================================
-- 2 · EL GENERADOR, CON EL PARTE BIEN DADO Y CON FRENO
-- ---------------------------------------------------------------------
-- Cambia lo que devuelve, así que hay que tirar la anterior primero.
-- =====================================================================
drop function if exists public.generar_entrenos_fijos(date, date, uuid, boolean, boolean);

create function public.generar_entrenos_fijos(
  p_desde   date    default null,
  p_hasta   date    default null,
  p_grupo   uuid    default null,
  p_simular boolean default false,
  p_forzar  boolean default false
)
returns table (
  creadas            integer,
  actualizadas       integer,
  borradas           integer,
  intactas           integer,
  saltadas_festivo   integer,
  saltadas_persona   integer,
  saltadas_quitadas  integer,
  desde              date,
  hasta              date,
  simulado           boolean,
  aviso              text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_desde   date;
  v_hasta   date;
  v_semanas int;
  v_crea    int := 0;
  v_act     int := 0;
  v_bor     int := 0;
  v_int     int := 0;
  v_s_fest  int := 0;
  v_s_pers  int := 0;
  v_s_quit  int := 0;
  v_pisadas int := 0;
  v_dobles  int := 0;
  v_aviso   text := null;
begin
  if auth.uid() is not null and not public.es_admin() then
    raise exception 'Solo el administrador puede publicar los entrenos fijos';
  end if;

  if not p_forzar and coalesce(public.automatizacion_ajuste('entrenos_activo', 'si'), 'si') <> 'si' then
    return query select 0, 0, 0, 0, 0, 0, 0, current_date, current_date, true,
                        'Está parado: no se publica nada nuevo.'::text;
    return;
  end if;

  v_semanas := greatest(1, least(26, coalesce(nullif(public.automatizacion_ajuste('semanas_vista', '6'), '')::int, 6)));
  v_desde := coalesce(p_desde, current_date);
  v_hasta := coalesce(p_hasta, current_date + (v_semanas * 7));
  if v_hasta < v_desde then v_hasta := v_desde; end if;
  -- El pasado no se toca jamás, ni para crear.
  if v_desde < current_date then v_desde := current_date; end if;

  perform set_config('apolana.generador', 'si', true);

  drop table if exists _apo_plan;
  drop table if exists _apo_final;

  create temp table _apo_plan on commit drop as
  select h.id                                   as horario_id,
         g.id                                   as grupo_id,
         g.nombre                               as grupo,
         g.seccion                              as seccion,
         gs.dia::date                           as fecha,
         h.hora_inicio,
         h.hora_fin,
         coalesce(h.lugar, '')                  as lugar,
         h.nota
    from public.grupo_horarios h
    join public.grupos g on g.id = h.grupo_id
    cross join lateral generate_series(v_desde::timestamp, v_hasta::timestamp, interval '1 day') as gs(dia)
   where h.activo
     and coalesce(g.activo, true)
     and coalesce(g.seccion, '') <> 'cubo'
     and (p_grupo is null or g.id = p_grupo)
     and extract(isodow from gs.dia)::int = h.dia_semana
     -- Freno: una «franja» de más de cinco horas no es un entrenamiento,
     -- es el horario de apertura de una instalación.
     and (h.hora_fin is null or (h.hora_fin - h.hora_inicio) <= interval '5 hours');

  -- Regla 4 · festivos y cierres
  delete from _apo_plan p
   where public.hay_excepcion(p.fecha, p.grupo_id, p.seccion, p.lugar);
  get diagnostics v_s_fest = row_count;

  -- Regla 3 · si una persona ya ha puesto algo ese día para ese grupo,
  -- ese día NO se toca. Se compara por grupo y día, nunca por hora: una
  -- sesión de planificación suele ir sin hora, y por hora no cruzaría.
  delete from _apo_plan p
   where exists (select 1 from public.sesiones s
                  where s.grupo_id = p.grupo_id and s.fecha = p.fecha
                    and not coalesce(s.auto_generada, false));
  get diagnostics v_s_pers = row_count;

  -- Regla 5 · lo que alguien quitó a mano no vuelve
  delete from _apo_plan p
   where exists (select 1 from public.entrenos_auto_borrados b
                  where b.horario_id = p.horario_id and b.fecha = p.fecha);
  get diagnostics v_s_quit = row_count;

  -- Regla 2 · las que alguien ha editado se quedan como están
  select count(*) into v_int
    from public.sesiones s
   where s.auto_generada and s.auto_tocada
     and s.fecha between v_desde and v_hasta
     and (p_grupo is null or s.grupo_id = p_grupo);

  select count(*) into v_crea
    from _apo_plan p
   where not exists (select 1 from public.sesiones s
                      where s.auto_horario_id = p.horario_id and s.fecha = p.fecha
                        and s.auto_generada);

  select count(*) into v_act
    from _apo_plan p
    join public.sesiones s on s.auto_horario_id = p.horario_id and s.fecha = p.fecha
   where s.auto_generada and not s.auto_tocada
     and (s.hora, s.lugar, s.titulo, coalesce(s.publicada, false))
         is distinct from
         (p.hora_inicio,
          nullif(p.lugar, ''),
          p.grupo || case when p.nota is not null then ' · ' || p.nota else '' end,
          true);

  select count(*) into v_bor
    from public.sesiones s
   where s.auto_generada and not s.auto_tocada
     and s.fecha between v_desde and v_hasta
     and (p_grupo is null or s.grupo_id = p_grupo)
     and not exists (select 1 from _apo_plan p
                      where p.horario_id = s.auto_horario_id and p.fecha = s.fecha)
     and not exists (select 1 from public.asistencia a where a.sesion_id = s.id)
     and not exists (select 1 from public.sesion_inscripciones si where si.sesion_id = s.id);

  -- ===================================================================
  -- RED DE SEGURIDAD · cómo quedaría el calendario, ANTES de escribir
  -- -------------------------------------------------------------------
  -- La proyección son las sesiones automáticas que habría al terminar:
  -- las del plan (se creen o se pongan al día) más las que sobreviven
  -- al borrado porque alguien las tocó o porque tienen gente apuntada
  -- o asistencia pasada.
  -- ===================================================================
  create temp table _apo_final on commit drop as
    select p.grupo_id, p.fecha from _apo_plan p
    union all
    select s.grupo_id, s.fecha
      from public.sesiones s
     where s.auto_generada
       and s.fecha between v_desde and v_hasta
       and (p_grupo is null or s.grupo_id = p_grupo)
       and not exists (select 1 from _apo_plan p
                        where p.horario_id = s.auto_horario_id and p.fecha = s.fecha)
       and (s.auto_tocada
            or exists (select 1 from public.asistencia a where a.sesion_id = s.id)
            or exists (select 1 from public.sesion_inscripciones si where si.sesion_id = s.id));

  -- (a) ninguna automática puede caer el mismo día que una de una persona
  select count(*) into v_pisadas
    from _apo_final f
   where exists (select 1 from public.sesiones m
                  where m.grupo_id = f.grupo_id and m.fecha = f.fecha
                    and not coalesce(m.auto_generada, false));

  -- (b) ningún grupo con más automáticas ese día que franjas tiene su
  --     horario ese día de la semana (dos franjas = dos entrenos, y eso
  --     es correcto: no es un duplicado)
  select count(*) into v_dobles from (
    select f.grupo_id, f.fecha
      from _apo_final f
     group by f.grupo_id, f.fecha
    having count(*) > (select count(*) from public.grupo_horarios h
                        where h.grupo_id = f.grupo_id and h.activo
                          and h.dia_semana = extract(isodow from f.fecha)::int)
  ) t;

  if v_pisadas > 0 or v_dobles > 0 then
    v_aviso := 'No se ha publicado nada. ' ||
      case when v_pisadas > 0
           then v_pisadas || ' sesión(es) automática(s) caerían el mismo día que una puesta por una persona. '
           else '' end ||
      case when v_dobles > 0
           then v_dobles || ' grupo(s) acabarían con más entrenos un día de los que dice su horario. '
           else '' end ||
      'Míralo en «Días con dos entrenos» antes de volver a intentarlo.';
  end if;

  if p_simular or v_aviso is not null then
    drop table if exists _apo_plan;
    drop table if exists _apo_final;
    perform set_config('apolana.generador', 'no', true);
    if v_aviso is not null and not p_simular then
      -- Al publicar de verdad no vale con devolver un aviso: quien llama
      -- puede no mirarlo. Se corta, y así no se escribe ni una fila.
      raise exception '%', v_aviso;
    end if;
    return query select v_crea, v_act, v_bor, v_int, v_s_fest, v_s_pers, v_s_quit,
                        v_desde, v_hasta, true, v_aviso;
    return;
  end if;

  -- --- alta de lo que falta ---
  insert into public.sesiones
        (fecha, dia_semana, tipo, titulo, hora, lugar, duracion_min,
         grupo_id, publicada, bloques, creado_por,
         auto_horario_id, auto_generada, auto_tocada)
  select p.fecha,
         public.apo_dia_nombre(extract(isodow from p.fecha)::smallint),
         case
           when p.seccion in ('natacion', 'escuela-natacion') then 'natacion'
           when p.seccion in ('competicion', 'escuela')        then 'pista'
           else 'continuo'
         end,
         p.grupo || case when p.nota is not null then ' · ' || p.nota else '' end,
         p.hora_inicio,
         nullif(p.lugar, ''),
         case when p.hora_fin is not null and p.hora_fin > p.hora_inicio
              then extract(epoch from (p.hora_fin - p.hora_inicio))::int / 60 end,
         p.grupo_id,
         true,
         '[]'::jsonb,
         null,                 -- nadie: lo pone el sistema
         p.horario_id, true, false
    from _apo_plan p
   where not exists (select 1 from public.sesiones s
                      where s.auto_horario_id = p.horario_id and s.fecha = p.fecha
                        and s.auto_generada);

  -- --- rehacer las que siguen siendo del sistema ---
  update public.sesiones s
     set hora         = p.hora_inicio,
         lugar        = nullif(p.lugar, ''),
         titulo       = p.grupo || case when p.nota is not null then ' · ' || p.nota else '' end,
         duracion_min = case when p.hora_fin is not null and p.hora_fin > p.hora_inicio
                             then extract(epoch from (p.hora_fin - p.hora_inicio))::int / 60 end,
         dia_semana   = public.apo_dia_nombre(extract(isodow from p.fecha)::smallint),
         publicada    = true,
         updated_at   = now()
    from _apo_plan p
   where s.auto_horario_id = p.horario_id
     and s.fecha = p.fecha
     and s.auto_generada
     and not s.auto_tocada;

  -- --- quitar lo que ya no toca (solo futuro, solo del sistema, solo
  --     si no hay nadie apuntado ni asistencia pasada) ---
  delete from public.sesiones s
   where s.auto_generada and not s.auto_tocada
     and s.fecha between v_desde and v_hasta
     and (p_grupo is null or s.grupo_id = p_grupo)
     and not exists (select 1 from _apo_plan p
                      where p.horario_id = s.auto_horario_id and p.fecha = s.fecha)
     and not exists (select 1 from public.asistencia a where a.sesion_id = s.id)
     and not exists (select 1 from public.sesion_inscripciones si where si.sesion_id = s.id);

  -- --- y se vuelve a mirar sobre lo escrito, por si acaso ---
  -- Cinturón y tirantes: la comprobación de antes iba sobre la proyección;
  -- esta va sobre lo que ha quedado de verdad. Si algo se hubiera colado,
  -- el error deshace todo lo que ha escrito esta función.
  select count(*) into v_pisadas
    from public.sesiones a
   where a.auto_generada and a.fecha between v_desde and v_hasta
     and (p_grupo is null or a.grupo_id = p_grupo)
     and exists (select 1 from public.sesiones m
                  where m.grupo_id = a.grupo_id and m.fecha = a.fecha
                    and not coalesce(m.auto_generada, false));

  select count(*) into v_dobles from (
    select s.grupo_id, s.fecha
      from public.sesiones s
     where s.auto_generada and s.fecha between v_desde and v_hasta
       and (p_grupo is null or s.grupo_id = p_grupo)
     group by s.grupo_id, s.fecha
    having count(*) > (select count(*) from public.grupo_horarios h
                        where h.grupo_id = s.grupo_id and h.activo
                          and h.dia_semana = extract(isodow from s.fecha)::int)
  ) t;

  if v_pisadas > 0 or v_dobles > 0 then
    raise exception 'Se ha deshecho la publicación: habrían quedado % sesión(es) automática(s) pisando el trabajo de una persona y % grupo(s) con más entrenos de los que dice su horario.',
      v_pisadas, v_dobles;
  end if;

  drop table if exists _apo_plan;
  drop table if exists _apo_final;
  -- Se baja la bandera enseguida: si en la misma transacción alguien
  -- edita una sesión después de generar, esa edición SÍ tiene que
  -- marcarse como suya. Sin esto, el generador la pisaría a la vuelta.
  perform set_config('apolana.generador', 'no', true);
  return query select v_crea, v_act, v_bor, v_int, v_s_fest, v_s_pers, v_s_quit,
                      v_desde, v_hasta, false, null::text;
end;
$$;

comment on function public.generar_entrenos_fijos(date, date, uuid, boolean, boolean) is
  'Publica en el calendario los entrenos fijos. Idempotente. Nunca toca lo que ha hecho una persona, y no escribe nada si el resultado fuese a duplicar.';


-- =====================================================================
-- 3 · PERMISOS · Supabase regala permisos en lo nuevo
-- ---------------------------------------------------------------------
-- La función se ha vuelto a crear, así que nace otra vez con los
-- permisos por defecto de Supabase. Hay que quitarlos a mano.
-- =====================================================================
revoke all on function public.generar_entrenos_fijos(date, date, uuid, boolean, boolean) from public, anon, authenticated;
revoke all on function public.entrenos_duplicados(date, date)                            from public, anon, authenticated;

grant execute on function public.generar_entrenos_fijos(date, date, uuid, boolean, boolean) to authenticated;
grant execute on function public.entrenos_duplicados(date, date)                            to authenticated;
