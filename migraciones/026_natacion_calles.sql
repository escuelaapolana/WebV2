-- ============================================================
-- 026 · Natación por calles (tablero de calles del entrenador)
-- ============================================================
--
-- POR QUÉ ASÍ (decisión sobre el modelo)
-- --------------------------------------
-- El entrenador de natación reparte a su gente en las calles de la
-- piscina y cada calle hace un trabajo distinto dentro de la MISMA
-- sesión. Eso es exactamente lo que ya hacen las planificaciones de
-- pista con los subgrupos («VALLISTAS — Rafa y Adri» / «LISOS —
-- Rubén y Dante»): un bloque dirigido a unos atletas concretos.
--
-- Por eso NO se crea ninguna tabla nueva. Una calle = un bloque de
-- `sesiones.bloques`, con dos claves añadidas:
--
--   {
--     "etiqueta": "Calle 1",              ← nombre visible de la calle
--     "matiz":    "Rápidos",              ← matiz opcional (ya existía)
--     "calle":    1,                      ← NUEVO · número de calle (1..8)
--     "atletas":  ["uuid", "uuid"],       ← NUEVO · quién nada en esa calle
--     "filas":    [ { ejercicio, series, distancia, ritmo, descanso,
--                     material: ["Palas","Aletas"], observaciones, … } ]
--   }
--
-- Es RETROCOMPATIBLE: no se renombra ni se quita ninguna clave. Un
-- bloque SIN `calle` sigue siendo un bloque normal (calentamiento
-- común, trabajo de todos), y las pantallas que ya leen `bloques`
-- (zona del atleta, editor del entrenador) siguen funcionando igual.
--
-- Lo único que se guarda fuera del jsonb es cuántas calles tiene la
-- sesión, porque hace falta aunque alguna calle esté vacía:
--   · `sesiones.calles` (2..8, nulo = sesión que no es por calles).
--
-- Y se admite `tipo = 'natacion'` en `sesiones`, que hasta ahora no
-- existía (solo pista, gym, continuo, activación, competición y
-- descanso). El check se reescribe conservando los valores que ya
-- tuviera, para no pisar otros cambios.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · Cuántas calles tiene la sesión
-- ------------------------------------------------------------
alter table public.sesiones
  add column if not exists calles smallint;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.sesiones'::regclass and conname = 'sesiones_calles_check'
  ) then
    alter table public.sesiones
      add constraint sesiones_calles_check check (calles is null or (calles between 1 and 8));
  end if;
end $$;

comment on column public.sesiones.calles is
  'Natación: cuántas calles de piscina se usan ese día (1..8). Nulo = sesión normal, sin calles. El reparto vive en bloques[].calle y bloques[].atletas.';

comment on column public.sesiones.bloques is
  'Bloques de la sesión. Cada bloque: {etiqueta, matiz, filas[]}. En natación puede llevar además "calle" (número) y "atletas" (ids de atletas de esa calle); un bloque sin "calle" es trabajo común.';

-- ------------------------------------------------------------
-- 2 · `tipo = natacion` admitido (sin pisar otros valores)
-- ------------------------------------------------------------
do $$
declare def text;
begin
  select pg_get_constraintdef(oid) into def
    from pg_constraint
   where conrelid = 'public.sesiones'::regclass and conname = 'sesiones_tipo_check';

  if def is not null and position('''natacion''' in def) = 0 then
    alter table public.sesiones drop constraint sesiones_tipo_check;
    execute 'alter table public.sesiones add constraint sesiones_tipo_check ' ||
            replace(def, 'ARRAY[', 'ARRAY[''natacion''::text, ');
  end if;
end $$;

-- ------------------------------------------------------------
-- 3 · El entrenador puede LEER los atletas de sus grupos
-- ------------------------------------------------------------
-- Hasta ahora un entrenador solo veía a los atletas con
-- `atletas.entrenador_id = él`. Para repartir un grupo por calles
-- necesita ver a TODO el grupo que tiene asignado, aunque la ficha
-- de alguien no tenga puesto el entrenador. Es un permiso de solo
-- lectura y se suma a los que ya hay (no sustituye a ninguno):
-- el grupo ya es suyo (`grupos.entrenador_id = él`).
do $$
begin
  if not exists (
    select 1 from pg_policy
    where polrelid = 'public.atletas'::regclass
      and polname = 'entrenador ve atletas de sus grupos'
  ) then
    create policy "entrenador ve atletas de sus grupos"
      on public.atletas for select to authenticated
      using (
        grupo_id in (select id from public.grupos where entrenador_id = mi_perfil_id())
      );
  end if;
end $$;

commit;

-- ============================================================
-- COMPROBACIÓN RÁPIDA (opcional, no hace falta ejecutarla)
-- ============================================================
-- select id, fecha, tipo, calles,
--        jsonb_path_query_array(bloques, '$[*].calle') as calles_usadas
--   from sesiones where calles is not null order by fecha desc;
