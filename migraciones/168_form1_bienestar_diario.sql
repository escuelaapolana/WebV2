-- ============================================================
-- 168 · FORMULARIO 1 · BIENESTAR (diario, ANTES de entrenar)
-- ------------------------------------------------------------
-- QUÉ HACE Y POR QUÉ
--
-- La FASE 2 del feedback separa dos cosas que antes iban mezcladas:
--   · el formulario de SESIÓN (cómo fue el entreno) → registros_sesion,
--     migración 167. NO se toca aquí.
--   · el formulario de BIENESTAR (cómo amaneces, una vez al día, antes
--     de entrenar) → esta tabla, `bienestar_diario`, creada en la 148.
--
-- La tabla ya existe (migración 148, cuestionario Hooper 1-7 + semáforo)
-- pero está VACÍA y ningún formulario la usa todavía, así que se puede
-- alinear a la especificación nueva sin migrar ni perder datos.
--
-- CAMBIOS RESPECTO A LA 148:
--   1. Las subescalas pasan de 1-7 a 1-5. La escala de 5 puntos es la que
--      pide la especificación del formulario nuevo y la que ve el atleta.
--   2. Se añaden cuatro columnas: `motivacion` (1-5), `molestia` (0-10),
--      `molestia_localizacion` (lista cerrada, la MISMA que registros_sesion
--      en la 167) y `peso_kg` (opcional).
--   3. `animo`, `dolor_semaforo` y `dolor_zona` de la 148 NO entran en el
--      formulario nuevo, pero se DEJAN tal cual: son nulables, no estorban,
--      y tirarlas sería destructivo sin necesidad. Quedan a null.
--   4. El comentario libre del formulario se guarda en la columna `nota`
--      que ya existía (no se crea `comentario`: sería una columna gemela).
--
-- ⚠️ LA DIRECCIÓN DE LAS ESCALAS ES SAGRADA. El índice de bienestar INVIERTE
--    fatiga, dolor_muscular y estrés y SUMA directas sueño y motivación. Por
--    eso los datos se guardan así, en crudo, en la dirección de la spec:
--      sueno_calidad  1 muy mala      → 5 muy buena     (directa)
--      fatiga         1 nada          → 5 muchísima     (inversa en el índice)
--      dolor_muscular 1 nada          → 5 mucho         (inversa en el índice)
--      estres         1 nada          → 5 mucho         (inversa en el índice)
--      motivacion     1 ninguna       → 5 mucha         (directa)
--    El cálculo del índice vive donde toque (vista del entrenador); aquí
--    solo se garantiza que el DATO entra en la dirección correcta.
--
-- NO APLICAR a mano: la revisa y la aplica Andrés.
--   bash .secrets/psql.sh -f migraciones/168_form1_bienestar_diario.sql
-- Idempotente: se puede volver a lanzar sin romper nada.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · SUBESCALAS HOOPER: DE 1-7 A 1-5
-- ------------------------------------------------------------
-- La tabla está vacía, así que estrechar el rango no invalida ninguna
-- fila. Cada constraint se borra y se vuelve a poner (idempotente).
alter table public.bienestar_diario
  drop constraint if exists bienestar_diario_sueno_calidad_check;
alter table public.bienestar_diario
  add  constraint bienestar_diario_sueno_calidad_check
  check (sueno_calidad is null or (sueno_calidad between 1 and 5));

alter table public.bienestar_diario
  drop constraint if exists bienestar_diario_fatiga_check;
alter table public.bienestar_diario
  add  constraint bienestar_diario_fatiga_check
  check (fatiga is null or (fatiga between 1 and 5));

alter table public.bienestar_diario
  drop constraint if exists bienestar_diario_dolor_muscular_check;
alter table public.bienestar_diario
  add  constraint bienestar_diario_dolor_muscular_check
  check (dolor_muscular is null or (dolor_muscular between 1 and 5));

alter table public.bienestar_diario
  drop constraint if exists bienestar_diario_estres_check;
alter table public.bienestar_diario
  add  constraint bienestar_diario_estres_check
  check (estres is null or (estres between 1 and 5));

comment on column public.bienestar_diario.sueno_calidad is
  'Calidad del sueño, 1 (muy mala) a 5 (muy buena). DIRECTA en el índice.';
comment on column public.bienestar_diario.fatiga is
  'Fatiga, 1 (nada) a 5 (muchísima). El índice la INVIERTE.';
comment on column public.bienestar_diario.dolor_muscular is
  'Dolor muscular, 1 (nada) a 5 (mucho). El índice lo INVIERTE.';
comment on column public.bienestar_diario.estres is
  'Estrés, 1 (nada) a 5 (mucho). El índice lo INVIERTE.';

-- `animo` (1-7 en la 148) NO entra en el formulario nuevo. Se deja como
-- está, nulable: no se escribe, no estorba. No se toca su check.

-- ------------------------------------------------------------
-- 2 · COLUMNAS NUEVAS
-- ------------------------------------------------------------
alter table public.bienestar_diario add column if not exists motivacion            smallint;
alter table public.bienestar_diario add column if not exists molestia              smallint;
alter table public.bienestar_diario add column if not exists molestia_localizacion text;
alter table public.bienestar_diario add column if not exists peso_kg               numeric(5,1);

comment on column public.bienestar_diario.motivacion is
  'Motivación / ganas de entrenar, 1 (ninguna) a 5 (mucha). DIRECTA en el índice.';
comment on column public.bienestar_diario.molestia is
  'Molestia o dolor AL AMANECER, 0 (nada) a 10 (máxima). Número, no texto: '
  'una alerta de carga/lesión necesita compararlo. Distinta de la molestia de '
  'la SESIÓN (registros_sesion.molestia_sesion): esto es antes de entrenar.';
comment on column public.bienestar_diario.molestia_localizacion is
  'Zona de la molestia. Lista cerrada, la MISMA que registros_sesion (167), '
  'para que las alertas agrupen igual en las dos hojas.';
comment on column public.bienestar_diario.peso_kg is
  'Peso en kg (opcional). Decimal, una cifra tras la coma.';

-- ------------------------------------------------------------
-- 3 · LOS TOPES (checks) DE LAS COLUMNAS NUEVAS · cada uno idempotente
-- ------------------------------------------------------------
alter table public.bienestar_diario drop constraint if exists bienestar_diario_motivacion_check;
alter table public.bienestar_diario add  constraint bienestar_diario_motivacion_check
  check (motivacion is null or (motivacion between 1 and 5));

alter table public.bienestar_diario drop constraint if exists bienestar_diario_molestia_check;
alter table public.bienestar_diario add  constraint bienestar_diario_molestia_check
  check (molestia is null or (molestia between 0 and 10));

-- Misma lista cerrada que registros_sesion_molestia_loc_check (167).
alter table public.bienestar_diario drop constraint if exists bienestar_diario_molestia_loc_check;
alter table public.bienestar_diario add  constraint bienestar_diario_molestia_loc_check
  check (molestia_localizacion is null or molestia_localizacion in
    ('ninguna','isquio','soleo_gemelo','rodilla','lumbar','cadera','tobillo','aductor','pie','otra'));

alter table public.bienestar_diario drop constraint if exists bienestar_diario_peso_kg_check;
alter table public.bienestar_diario add  constraint bienestar_diario_peso_kg_check
  check (peso_kg is null or (peso_kg > 0 and peso_kg < 300));

-- ------------------------------------------------------------
-- Nada que tocar en permisos ni RLS: la 148 ya dejó
--   · grant select, insert, update a authenticated
--   · insert/update gated por atleta_pide_bienestar() (solo grupos Pro)
--   · lectura solo del atleta y su entrenador
--   · unique (atleta_id, fecha) → upsert por atleta y día
--   · trigger updated_at
-- El formulario nuevo usa todo eso tal cual.
-- ------------------------------------------------------------

commit;

-- --- Comprobación rápida (opcional) ---------------------------------
-- select column_name, data_type from information_schema.columns
--   where table_name='bienestar_diario' order by ordinal_position;
