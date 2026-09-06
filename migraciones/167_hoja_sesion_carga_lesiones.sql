-- ============================================================
-- 167 · LA HOJA DE LA SESIÓN, AFINADA PARA CARGA Y LESIONES
-- ------------------------------------------------------------
-- SIN APLICAR. La revisa y la aplica el dueño. Es idempotente:
-- se puede lanzar las veces que haga falta.
--
--   psql "$SUPABASE_DB_URL" -f migraciones/167_hoja_sesion_carga_lesiones.sql
--   (o con el atajo del repo: .secrets/psql.sh -f migraciones/167_...sql)
--
-- QUÉ HACE Y POR QUÉ
-- El formulario «¿Cómo fue?» de la sesión se reescribe (FORMULARIO 2 ·
-- SESIÓN) para que sirva de verdad al seguimiento de carga y a la
-- prevención de lesiones del grupo de rendimiento:
--
--   · el atleta DECLARA si la sesión se hizo (Hecha · A medias · No
--     hecha) en vez de deducirlo del recuento de series;
--   · la molestia pasa de texto libre a NÚMERO (0-10) + zona, para que
--     una alerta pueda mirarla;
--   · se apunta la duración real (prerrellenada con la planificada),
--     la superficie y el momento del día.
--
-- LO QUE YA EXISTÍA en `registros_sesion` y NO se toca aquí:
--   rpe, sensacion_general, como_me_siento, molestias (texto),
--   notas_atleta, horas_sueno, peso_kg, tiempos_reales,
--   estado, series_hechas, series_previstas, motivo_no_hecho,
--   nota_no_hecho, corregido_en, corregido_veces.
--   (`sesiones.duracion_min` = duración PLANIFICADA, migración 034;
--    se sigue usando para prerrellenar. La de aquí es la REAL.)
--
-- LO QUE AÑADE esta migración (todo `if not exists`):
--   completado_pct, molestia_sesion, molestia_localizacion,
--   superficie, momento, duracion_min y estado_manual.
--
-- POR QUÉ `estado_manual`
-- Hasta hoy `estado` (completo/a_medias/no_hecho) NO se preguntaba: lo
-- deducía el disparador `apo_registros_estado` contando las series con
-- ✓ (migración 103/104). El formulario nuevo SÍ lo pregunta. Para que
-- lo que el atleta declara no lo pise el disparador —y a la vez la hoja
-- de siempre, la que marca series, siga deduciéndolo como hasta ahora—
-- se añade un interruptor por fila: si `estado_manual` es true, manda
-- lo que dijo el atleta; si no, se deduce igual que siempre. Así ningún
-- registro antiguo cambia de lectura.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · LAS COLUMNAS NUEVAS
-- ------------------------------------------------------------
alter table public.registros_sesion add column if not exists completado_pct       integer;
alter table public.registros_sesion add column if not exists molestia_sesion       integer;
alter table public.registros_sesion add column if not exists molestia_localizacion text;
alter table public.registros_sesion add column if not exists superficie            text;
alter table public.registros_sesion add column if not exists momento               text;
alter table public.registros_sesion add column if not exists duracion_min          integer;
alter table public.registros_sesion add column if not exists estado_manual         boolean not null default false;

comment on column public.registros_sesion.completado_pct is
  'Cuánto de la sesión se hizo, en % (0-100). Solo tiene sentido cuando el atleta '
  'declara «A medias»; en «Hecha» y «No hecha» va a null.';
comment on column public.registros_sesion.molestia_sesion is
  'Molestia o dolor DURANTE/DESPUÉS de esta sesión, 0 (ninguna) a 10 (máxima). '
  'Número a propósito, no texto: una alerta de carga/lesión necesita compararlo.';
comment on column public.registros_sesion.molestia_localizacion is
  'Zona de la molestia (isquio, sóleo/gemelo, rodilla…). Solo se guarda si '
  'molestia_sesion > 0. Desplegable cerrado para que las alertas agrupen bien.';
comment on column public.registros_sesion.superficie is
  'Dónde se entrenó (pista, hierba, asfalto…). Opcional. Ayuda a leer la carga: '
  'el asfalto no castiga igual que la hierba.';
comment on column public.registros_sesion.momento is
  'Cuándo, para quien entrena dos veces al día: única · mañana · tarde.';
comment on column public.registros_sesion.duracion_min is
  'Duración REAL de la sesión en minutos (0-240). En la pantalla se prerrellena '
  'con la planificada (`sesiones.duracion_min`); el atleta solo la cambia si fue '
  'distinta. Distinta de la planificada a propósito: una cosa es lo que se mandó '
  'y otra lo que se hizo.';
comment on column public.registros_sesion.estado_manual is
  'true = el `estado` lo declaró el atleta a mano (formulario nuevo de sesión) y '
  'el disparador lo respeta. false = se deduce del recuento de series, como '
  'siempre. Nace en false: ningún registro antiguo cambia de lectura.';

-- ------------------------------------------------------------
-- 2 · LOS TOPES (checks), cada uno idempotente
-- ------------------------------------------------------------
alter table public.registros_sesion drop constraint if exists registros_sesion_completado_pct_check;
alter table public.registros_sesion add  constraint registros_sesion_completado_pct_check
  check (completado_pct is null or (completado_pct between 0 and 100));

alter table public.registros_sesion drop constraint if exists registros_sesion_molestia_sesion_check;
alter table public.registros_sesion add  constraint registros_sesion_molestia_sesion_check
  check (molestia_sesion is null or (molestia_sesion between 0 and 10));

alter table public.registros_sesion drop constraint if exists registros_sesion_molestia_loc_check;
alter table public.registros_sesion add  constraint registros_sesion_molestia_loc_check
  check (molestia_localizacion is null or molestia_localizacion in
    ('ninguna','isquio','soleo_gemelo','rodilla','lumbar','cadera','tobillo','aductor','pie','otra'));

alter table public.registros_sesion drop constraint if exists registros_sesion_superficie_check;
alter table public.registros_sesion add  constraint registros_sesion_superficie_check
  check (superficie is null or superficie in
    ('pista','hierba','asfalto','tierra','gimnasio','mixta','otra'));

alter table public.registros_sesion drop constraint if exists registros_sesion_momento_check;
alter table public.registros_sesion add  constraint registros_sesion_momento_check
  check (momento is null or momento in ('unica','manana','tarde'));

alter table public.registros_sesion drop constraint if exists registros_sesion_duracion_min_check;
alter table public.registros_sesion add  constraint registros_sesion_duracion_min_check
  check (duracion_min is null or (duracion_min between 0 and 240));

-- El motivo de «no hecha / a medias» se amplía de tres a siete valores.
-- Los tres de antes (tiempo · molestia · otro, migración 103) siguen
-- siendo válidos, así que ninguna fila existente incumple el tope nuevo.
alter table public.registros_sesion drop constraint if exists registros_sesion_motivo_check;
alter table public.registros_sesion add  constraint registros_sesion_motivo_check
  check (motivo_no_hecho is null or motivo_no_hecho in
    ('tiempo','molestia','enfermedad','viaje','instalacion','cansancio','otro'));

-- ------------------------------------------------------------
-- 3 · EL DISPARADOR, QUE AHORA RESPETA LO DECLARADO
-- ------------------------------------------------------------
-- Es el de la migración 104 (deduce estado del recuento y deja rastro
-- al corregir un día pasado) con UNA rama nueva: si `estado_manual` es
-- true, se queda con el `estado` que trae el atleta en vez de deducirlo.
-- Todo lo demás es idéntico a propósito, para que quien compare vea que
-- solo se ha añadido, no cambiado.
-- ⚠️ `security definer` con el `search_path` clavado: sin eso las dos
-- funciones que llama nacen cerradas para el atleta (migración 090) y
-- NO SE PUEDE GUARDAR. Contado entero en la migración 106.
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

  -- El recuento de series se sigue guardando SIEMPRE: aunque el atleta
  -- declare el estado a mano, saber cuántas series marcó no estorba y
  -- lo leen otras pantallas.
  new.series_previstas := v_prev;
  new.series_hechas    := least(v_hech, greatest(v_prev, v_hech));

  if coalesce(new.estado_manual, false) and new.estado is not null then
    -- --------- lo nuevo de la 167 ---------
    -- Lo declara el atleta (formulario de sesión): se respeta. Solo se
    -- limpia lo que no pega con «hecha entera».
    if new.estado = 'completo' then
      new.completado_pct  := null;
      new.motivo_no_hecho := null;
      new.nota_no_hecho   := null;
    end if;
  else
    -- --------- comportamiento de siempre (103/104) ---------
    -- Se deduce del recuento. También cae aquí un guardado manual que
    -- por lo que sea llegue sin estado: mejor deducir algo que dejarlo
    -- en blanco.
    if v_prev = 0 then
      new.estado := 'completo';
    elsif v_hech = 0 then
      new.estado := 'no_hecho';
    elsif v_hech >= v_prev then
      new.estado := 'completo';
    else
      new.estado := 'a_medias';
    end if;

    if new.estado = 'completo' then
      new.motivo_no_hecho := null;
      new.nota_no_hecho   := null;
    end if;
  end if;

  -- ---------- el rastro de las correcciones (migración 104) ----------
  -- Solo en UPDATE, y solo para un día YA PASADO. Se añaden a la lista
  -- los campos nuevos: corregir la duración o la molestia de un día de
  -- hace un mes también es corregir.
  if TG_OP = 'UPDATE' then
    select s.fecha into v_fecha from public.sesiones s where s.id = new.sesion_id;

    if v_fecha is not null
       and v_fecha < (now() at time zone 'Europe/Madrid')::date
       and (   new.tiempos_reales       is distinct from old.tiempos_reales
            or new.sensacion_general    is distinct from old.sensacion_general
            or new.rpe                  is distinct from old.rpe
            or new.como_me_siento       is distinct from old.como_me_siento
            or new.molestias            is distinct from old.molestias
            or new.notas_atleta         is distinct from old.notas_atleta
            or new.horas_sueno          is distinct from old.horas_sueno
            or new.peso_kg              is distinct from old.peso_kg
            or new.motivo_no_hecho      is distinct from old.motivo_no_hecho
            or new.nota_no_hecho        is distinct from old.nota_no_hecho
            or new.estado               is distinct from old.estado
            or new.completado_pct       is distinct from old.completado_pct
            or new.molestia_sesion      is distinct from old.molestia_sesion
            or new.molestia_localizacion is distinct from old.molestia_localizacion
            or new.superficie           is distinct from old.superficie
            or new.momento              is distinct from old.momento
            or new.duracion_min         is distinct from old.duracion_min)
    then
      new.corregido_en    := now();
      new.corregido_veces := coalesce(old.corregido_veces, 0) + 1;
    else
      new.corregido_en    := old.corregido_en;
      new.corregido_veces := coalesce(old.corregido_veces, 0);
    end if;
  end if;

  return new;
end;
$$;

comment on function public.apo_registros_estado() is
  'Fija el estado del día (completo/a_medias/no_hecho). Si `estado_manual` es '
  'true, respeta lo que declaró el atleta en el formulario de sesión (migración '
  '167); si no, lo deduce del recuento de series (103/104). Siempre guarda el '
  'recuento y, al corregir un día pasado, deja el rastro (104).';

drop trigger if exists trg_registros_estado on public.registros_sesion;
create trigger trg_registros_estado
  before insert or update on public.registros_sesion
  for each row execute function public.apo_registros_estado();

commit;

-- ------------------------------------------------------------
-- CÓMO COMPROBAR QUE HA IDO BIEN
--
--   -- las columnas nuevas están y con su tope
--   \d+ registros_sesion
--
--   -- un registro manual guarda lo que se declara (no lo deduce)
--   --   update registros_sesion
--   --      set estado_manual = true, estado = 'a_medias', completado_pct = 60
--   --    where id = '...'::uuid;
--   --   select estado, completado_pct, series_hechas from registros_sesion where id = '...';
--   --   -- estado debe seguir siendo 'a_medias' aunque las series digan otra cosa
--
--   -- ningún registro antiguo cambia: todos siguen con estado_manual = false
--   select estado_manual, count(*) from registros_sesion group by 1;
-- ------------------------------------------------------------
