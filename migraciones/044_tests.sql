-- =====================================================================
-- 044_tests.sql  ·  BATERÍA DE TESTS FÍSICOS
-- =====================================================================
-- Para qué sirve:
--
--   El club mide tres o cuatro veces al año lo mismo en todos los
--   grupos: velocidad, saltos y reactividad. Hasta ahora eso vivía en
--   hojas de cálculo sueltas, así que no se podía comparar una toma con
--   la anterior ni ver cómo va un atleta a lo largo del año.
--
--   Aquí se guardan las dos cosas que hacen falta:
--     1) la BATERÍA (test_baterias): el día que se pasan los tests, con
--        qué grupo y en qué condiciones (sede, temperatura y viento).
--        Las condiciones se apuntan UNA VEZ por batería, no por atleta.
--     2) el RESULTADO (test_resultados): una fila por atleta y test,
--        con todos los intentos, el mejor y —si es RSI— el formato de
--        la serie (6 o 10 saltos).
--
-- LOS SIETE TESTS Y SUS UNIDADES
--   30 m lanzado   segundos (s)     2 decimales   mejor de 2
--   30 m parado    segundos (s)     2 decimales   mejor de 2
--   150 m          segundos (s)     2 decimales   1 intento
--   CMJ            centímetros(cm)  1 decimal     mejor de 3
--   SJ             centímetros(cm)  1 decimal     mejor de 3
--   Abalakov       centímetros(cm)  1 decimal     mejor de 3
--   RSI            índice           2 decimales   serie de 6 o de 10
--
--   En los tres primeros MENOS es mejor; en los saltos y en el RSI,
--   MÁS es mejor.
--
--   El RSI no se compara entre formatos distintos: una serie de 6 y una
--   de 10 son dos pruebas diferentes, por eso el formato se guarda con
--   el resultado y las pantallas nunca los mezclan.
--
-- LO QUE NO SE GUARDA AQUÍ (se calcula al mostrarlo, nunca se teclea):
--   Índice elástico   (CMJ − SJ) / SJ        en %
--   Uso de brazos     (ABK − CMJ) / CMJ      en %
--   Velocidad máxima  30 / t lanzado         en m/s
--
-- QUIÉN VE QUÉ
--   · Administración y equipo técnico: crean, editan y ven todo.
--   · Un atleta (o su familia): SOLO lee sus propios resultados.
--   · Sin cuenta (anónimo): no ve absolutamente nada.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/044_tests.sql
-- Se puede volver a lanzar las veces que haga falta: no rompe nada.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. LA BATERÍA · un día de tests con sus condiciones
-- ---------------------------------------------------------------------
create table if not exists public.test_baterias (
  id          uuid primary key default gen_random_uuid(),
  fecha       date not null default current_date,
  grupo_id    uuid references public.grupos(id) on delete set null,
  sede        text,
  temperatura numeric(4,1),
  viento      numeric(4,1),
  notas       text,
  creado_por  uuid references public.perfiles(id),
  created_at  timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'test_baterias_temperatura_check') then
    alter table public.test_baterias add constraint test_baterias_temperatura_check
      check (temperatura is null or (temperatura >= -20 and temperatura <= 55));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'test_baterias_viento_check') then
    alter table public.test_baterias add constraint test_baterias_viento_check
      check (viento is null or (viento >= -15 and viento <= 15));
  end if;
end $$;

create index if not exists idx_test_baterias_fecha on public.test_baterias (fecha desc);
create index if not exists idx_test_baterias_grupo on public.test_baterias (grupo_id, fecha desc);

comment on table  public.test_baterias is
  'Un día de batería de tests físicos: fecha, grupo y condiciones de la sesión. Las condiciones se apuntan una sola vez, no por atleta.';
comment on column public.test_baterias.sede        is 'Dónde se pasa la batería (pista, gimnasio, El Cubo…).';
comment on column public.test_baterias.temperatura is 'Grados centígrados. Afecta a los tiempos: por eso se guarda.';
comment on column public.test_baterias.viento      is 'Metros por segundo. Positivo = a favor, negativo = en contra.';


-- ---------------------------------------------------------------------
-- 2. EL RESULTADO · un atleta, un test
-- ---------------------------------------------------------------------
create table if not exists public.test_resultados (
  id          uuid primary key default gen_random_uuid(),
  bateria_id  uuid not null references public.test_baterias(id) on delete cascade,
  atleta_id   uuid not null references public.atletas(id) on delete cascade,
  test        text not null,
  intentos    jsonb not null default '[]'::jsonb,
  mejor       numeric,
  formato_rsi int,
  no_asiste   boolean not null default false,
  created_at  timestamptz not null default now()
);

do $$
begin
  -- Los siete tests, y solo esos siete.
  if not exists (select 1 from pg_constraint where conname = 'test_resultados_test_check') then
    alter table public.test_resultados add constraint test_resultados_test_check
      check (test in ('30_lanzado','30_parado','150m','cmj','sj','abalakov','rsi'));
  end if;

  -- El formato de la serie es del RSI y de nadie más: 6 o 10 saltos.
  if not exists (select 1 from pg_constraint where conname = 'test_resultados_formato_rsi_check') then
    alter table public.test_resultados add constraint test_resultados_formato_rsi_check
      check (
        (test =  'rsi' and formato_rsi in (6,10)) or
        (test <> 'rsi' and formato_rsi is null)
      );
  end if;

  -- «No asiste» es distinto de «sin dato»: si no ha venido, no hay
  -- intentos ni marca que valgan.
  if not exists (select 1 from pg_constraint where conname = 'test_resultados_no_asiste_check') then
    alter table public.test_resultados add constraint test_resultados_no_asiste_check
      check (no_asiste is false or (mejor is null and intentos = '[]'::jsonb));
  end if;

  -- Los intentos son siempre una lista.
  if not exists (select 1 from pg_constraint where conname = 'test_resultados_intentos_check') then
    alter table public.test_resultados add constraint test_resultados_intentos_check
      check (jsonb_typeof(intentos) = 'array');
  end if;

  -- Un atleta tiene UNA fila por test en cada batería: si se corrige un
  -- valor se reescribe la misma fila, no se apila una nueva.
  if not exists (select 1 from pg_constraint where conname = 'test_resultados_unico') then
    alter table public.test_resultados add constraint test_resultados_unico
      unique (bateria_id, atleta_id, test);
  end if;
end $$;

create index if not exists idx_test_resultados_bateria on public.test_resultados (bateria_id);
create index if not exists idx_test_resultados_atleta  on public.test_resultados (atleta_id);
-- La evolución de un atleta en un test concreto es la consulta más
-- frecuente de la web, y este índice es el que la hace instantánea.
create index if not exists idx_test_resultados_atleta_test on public.test_resultados (atleta_id, test);

comment on table  public.test_resultados is
  'Resultado de un atleta en un test dentro de una batería. Una fila por atleta y test.';
comment on column public.test_resultados.test is
  '30_lanzado / 30_parado / 150m (segundos, menos es mejor) · cmj / sj / abalakov (centímetros, más es mejor) · rsi (índice, más es mejor).';
comment on column public.test_resultados.intentos is
  'Lista de los intentos tal y como se han tomado, en orden. En el RSI es la serie completa de saltos.';
comment on column public.test_resultados.mejor is
  'El valor que cuenta. En tiempos, el intento más bajo; en saltos, el más alto; en el RSI, la media de la serie descartando el peor salto.';
comment on column public.test_resultados.formato_rsi is
  'Saltos de la serie de RSI: 6 o 10. Una serie de 6 y una de 10 NO se comparan entre sí.';
comment on column public.test_resultados.no_asiste is
  'El atleta no vino a pasar el test. No es lo mismo que no tener dato todavía.';


-- ---------------------------------------------------------------------
-- 3. AYUDANTE DE PERMISOS
-- ---------------------------------------------------------------------
-- ¿Puedo ver esta batería? La ve el equipo técnico y la administración,
-- y también el atleta (o su familia) si dentro hay algún resultado suyo:
-- sin esto no podría ver ni la fecha ni las condiciones de sus propias
-- marcas.
create or replace function public.veo_bateria(p_bateria uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select public.es_staff() or exists (
    select 1 from public.test_resultados r
    where r.bateria_id = p_bateria
      and r.atleta_id in (select public.mis_atletas())
  );
$function$;

grant execute on function public.veo_bateria(uuid) to authenticated;


-- ---------------------------------------------------------------------
-- 4. REGLAS DE SEGURIDAD (RLS)
-- ---------------------------------------------------------------------
-- Todas las reglas son «to authenticated»: quien no ha entrado con su
-- cuenta no ve ni una fila.
--
-- es_staff() es admin + coordinación + entrenadores; incluye por tanto
-- los casos que cubre soy_staff_de_atleta() (admin o el entrenador de
-- ese atleta) y además deja que un entrenador pase la batería de un
-- grupo que ese día no es el suyo, que es lo que pasa en la pista.

alter table public.test_baterias   enable row level security;
alter table public.test_resultados enable row level security;

-- --- 4.1 Baterías ----------------------------------------------------
drop policy if exists "tests bateria lectura" on public.test_baterias;
create policy "tests bateria lectura" on public.test_baterias
for select to authenticated
using (veo_bateria(id));

drop policy if exists "tests bateria alta del equipo" on public.test_baterias;
create policy "tests bateria alta del equipo" on public.test_baterias
for insert to authenticated
with check (es_staff());

drop policy if exists "tests bateria cambia el equipo" on public.test_baterias;
create policy "tests bateria cambia el equipo" on public.test_baterias
for update to authenticated
using (es_staff())
with check (es_staff());

drop policy if exists "tests bateria borra el equipo" on public.test_baterias;
create policy "tests bateria borra el equipo" on public.test_baterias
for delete to authenticated
using (es_staff());

-- --- 4.2 Resultados --------------------------------------------------
-- Lectura: el equipo técnico ve todo (lo necesita para la comparativa
-- por categoría) y el atleta o su familia ven solo lo suyo.
drop policy if exists "tests resultado lectura" on public.test_resultados;
create policy "tests resultado lectura" on public.test_resultados
for select to authenticated
using (es_staff() or atleta_id in (select mis_atletas()));

drop policy if exists "tests resultado alta del equipo" on public.test_resultados;
create policy "tests resultado alta del equipo" on public.test_resultados
for insert to authenticated
with check (es_staff());

drop policy if exists "tests resultado cambia el equipo" on public.test_resultados;
create policy "tests resultado cambia el equipo" on public.test_resultados
for update to authenticated
using (es_staff())
with check (es_staff());

drop policy if exists "tests resultado borra el equipo" on public.test_resultados;
create policy "tests resultado borra el equipo" on public.test_resultados
for delete to authenticated
using (es_staff());

commit;


-- =====================================================================
-- 5. DATOS DE EJEMPLO (INVENTADOS) PARA VER LAS PANTALLAS CON CONTENIDO
-- ---------------------------------------------------------------------
-- Sin baterías pasadas la web de comparativas está en blanco y no se
-- puede comprobar que funciona. Aquí se siembran cuatro baterías del
-- curso para los grupos que ya tienen atletas.
--
-- Todo lo sembrado lleva identificador «dddddddd-0044-», igual que el
-- resto de datos de demostración del proyecto. Se puede volver a lanzar
-- cuando se quiera: primero borra lo de la vez anterior.
--
-- Para quitarlo del todo y quedarse solo con los datos reales:
--   delete from test_baterias where id::text like 'dddddddd-0044-%';
-- (los resultados se van solos, cuelgan de la batería).
-- =====================================================================

begin;

delete from public.test_baterias where id::text like 'dddddddd-0044-%';

-- --- 5.1 Cuatro baterías repartidas por el curso ---------------------
with grupos_con_gente as (
  select g.id, g.nombre,
         row_number() over (order by count(a.id) desc, g.nombre) as n
    from public.grupos g
    join public.atletas a on a.grupo_id = g.id and coalesce(a.estado,'activo') <> 'baja'
   where coalesce(g.activo, true)
   group by g.id, g.nombre
  having count(a.id) >= 3
   limit 6
),
momentos (k, meses_atras, sede, temp, viento) as (
  values (1, 11, 'Pista municipal', 24.5,  0.4),
         (2,  8, 'Pista municipal', 12.0, -1.2),
         (3,  4, 'Pista municipal', 18.5,  0.9),
         (4,  0, 'Pista municipal', 27.0,  1.6)
)
insert into public.test_baterias (id, fecha, grupo_id, sede, temperatura, viento, notas)
select ('dddddddd-0044-4000-8000-' || lpad((g.n * 10 + m.k)::text, 12, '0'))::uuid,
       (current_date - (m.meses_atras * 30))::date,
       g.id,
       m.sede,
       m.temp,
       m.viento,
       'Batería de ejemplo · ' || g.nombre
  from grupos_con_gente g cross join momentos m;

-- --- 5.2 Los resultados de cada atleta -------------------------------
-- Cómo se inventan: cada atleta tiene un nivel de partida que sale de
-- su identificador (siempre el mismo, no cambia de una vez a otra) y va
-- mejorando poco a poco batería tras batería, con algo de ruido para que
-- no salga una línea perfecta. Uno de cada catorce no asiste.
with bat as (
  -- 0, 1, 2, 3: en qué momento del curso va cada batería de ese grupo
  select b.id, b.fecha, b.grupo_id,
         dense_rank() over (partition by b.grupo_id order by b.fecha) - 1 as paso
    from public.test_baterias b
   where b.id::text like 'dddddddd-0044-%'
),
base as (
  select b.id as bateria_id, b.fecha, a.id as atleta_id, b.paso,
         mod(('x' || substr(md5(a.id::text || 'nivel'), 1, 6))::bit(24)::int, 100) as nivel,
         mod(('x' || substr(md5(a.id::text || b.id::text || 'ruido'), 1, 6))::bit(24)::int, 100) as ruido,
         mod(('x' || substr(md5(a.id::text || b.id::text || 'falta'), 1, 6))::bit(24)::int, 14)  as falta,
         case when mod(('x' || substr(md5(a.id::text || 'rsi'), 1, 6))::bit(24)::int, 3) = 0 then 10 else 6 end as formato
    from bat b
    join public.atletas a on a.grupo_id = b.grupo_id and coalesce(a.estado,'activo') <> 'baja'
),
valores as (
  select base.*,
         -- 30 m lanzado: entre 3.05 s y 3.70 s, bajando ~0.06 s por batería
         round((3.05 + nivel * 0.0065 - paso * 0.06 + (ruido % 7 - 3) * 0.012)::numeric, 2) as v_lanz,
         -- 30 m parado: entre 4.10 s y 4.90 s
         round((4.10 + nivel * 0.0080 - paso * 0.07 + (ruido % 5 - 2) * 0.015)::numeric, 2) as v_par,
         -- 150 m: entre 18.2 s y 22.0 s
         round((18.2 + nivel * 0.0380 - paso * 0.22 + (ruido % 9 - 4) * 0.040)::numeric, 2) as v_150,
         -- CMJ: entre 27 cm y 44 cm, subiendo ~1.3 cm por batería
         round((27.0 + nivel * 0.170 + paso * 1.30 + (ruido % 7 - 3) * 0.30)::numeric, 1) as v_cmj,
         -- SJ: siempre por debajo del CMJ (de ahí sale el índice elástico)
         round((24.0 + nivel * 0.155 + paso * 1.05 + (ruido % 5 - 2) * 0.30)::numeric, 1) as v_sj,
         -- Abalakov: siempre por encima del CMJ (de ahí sale el uso de brazos)
         round((30.5 + nivel * 0.185 + paso * 1.45 + (ruido % 7 - 3) * 0.30)::numeric, 1) as v_abk,
         -- RSI: entre 1.20 y 2.30
         round((1.20 + nivel * 0.0105 + paso * 0.055 + (ruido % 5 - 2) * 0.020)::numeric, 2) as v_rsi
    from base
),
filas as (
  -- Tiempos: dos intentos (o uno en el 150), y el mejor es el más bajo.
  select bateria_id, atleta_id, '30_lanzado' as test,
         to_jsonb(array[ round(v_lanz + 0.06, 2), v_lanz ]) as intentos,
         v_lanz as mejor, null::int as formato_rsi, (falta = 0) as no_asiste
    from valores
  union all
  select bateria_id, atleta_id, '30_parado',
         to_jsonb(array[ v_par, round(v_par + 0.05, 2) ]), v_par, null, (falta = 0) from valores
  union all
  select bateria_id, atleta_id, '150m',
         to_jsonb(array[ v_150 ]), v_150, null, (falta = 0) from valores
  -- Saltos: tres intentos, y el mejor es el más alto.
  union all
  select bateria_id, atleta_id, 'cmj',
         to_jsonb(array[ round(v_cmj - 1.4, 1), v_cmj, round(v_cmj - 0.6, 1) ]), v_cmj, null, (falta = 0) from valores
  union all
  select bateria_id, atleta_id, 'sj',
         to_jsonb(array[ round(v_sj - 1.1, 1), round(v_sj - 0.5, 1), v_sj ]), v_sj, null, (falta = 0) from valores
  union all
  select bateria_id, atleta_id, 'abalakov',
         to_jsonb(array[ v_abk, round(v_abk - 1.7, 1), round(v_abk - 0.9, 1) ]), v_abk, null, (falta = 0) from valores
  -- RSI: la serie entera, y el valor es la media descartando el peor salto.
  union all
  select bateria_id, atleta_id, 'rsi',
         to_jsonb((
           select array_agg(round((v_rsi + (mod(('x'||substr(md5(atleta_id::text||bateria_id::text||s::text),1,6))::bit(24)::int, 21) - 10) * 0.012)::numeric, 2) order by s)
             from generate_series(1, formato) s
         )),
         v_rsi, formato, (falta = 0)
    from valores
)
insert into public.test_resultados (bateria_id, atleta_id, test, intentos, mejor, formato_rsi, no_asiste)
select bateria_id, atleta_id, test,
       case when no_asiste then '[]'::jsonb else intentos end,
       case when no_asiste then null else mejor end,
       formato_rsi,
       no_asiste
  from filas
on conflict (bateria_id, atleta_id, test) do nothing;

-- El RSI real de la serie es la media descartando el peor salto: se
-- recalcula aquí para que el dato guardado y el que enseña la pantalla
-- sean exactamente el mismo número.
update public.test_resultados r
   set mejor = c.media
  from (
    select r2.id,
           round(avg(x.v), 2) as media
      from public.test_resultados r2
      join lateral (
        select (e.value)::numeric as v,
               row_number() over (order by (e.value)::numeric) as peor
          from jsonb_array_elements(r2.intentos) e
      ) x on x.peor > 1
     where r2.test = 'rsi' and r2.no_asiste = false
       and r2.bateria_id in (select id from public.test_baterias where id::text like 'dddddddd-0044-%')
     group by r2.id
  ) c
 where r.id = c.id;

commit;


-- --- Comprobación rápida ---------------------------------------------
select 'baterías de ejemplo'   as que, count(*) from public.test_baterias   where id::text like 'dddddddd-0044-%'
union all
select 'resultados de ejemplo',       count(*) from public.test_resultados  where bateria_id::text like 'dddddddd-0044-%';
