-- ============================================================
-- 013 · HISTÓRICO DE LA ESCUELA · Club Atletismo Apolana
-- ------------------------------------------------------------
-- Una fila por TEMPORADA y PROGRAMA:
--   programa = 'escuela'   → la escuela del club
--   programa = 'municipal' → la escuela municipal (otro programa,
--                            conviven en la misma temporada)
--
-- Todos los números pueden ser NULL: en el Excel original hay
-- muchos huecos ("-") y NO es lo mismo "cero" que "no lo sabemos".
-- Los gráficos del panel se saltan los NULL en vez de pintar un 0.
--
-- Lectura: pública (son datos agregados, sin dato personal).
-- Escritura: solo administración (es_admin()).
-- ============================================================

create table if not exists public.escuela_historico (
  id uuid primary key default gen_random_uuid(),

  temporada text not null,                      -- '2013', '2020.21', '2025.26'…
  programa  text not null default 'escuela',    -- 'escuela' | 'municipal'

  -- Captación e inscripciones
  apuntados_total   integer,   -- total de apuntados en la temporada
  vinieron_a_probar integer,   -- vinieron a la clase de prueba
  se_quedaron       integer,   -- de los que probaron, cuántos se quedaron
  pct_inscripciones numeric,   -- % de conversión prueba → inscripción
  hermanos          integer,   -- apuntados que son hermanos de otro atleta
  nuevos            integer,
  renovacion        integer,

  -- Reparto por categoría
  sub6   integer,
  sub8   integer,
  sub10  integer,
  sub12  integer,
  sub14  integer,
  sub16  integer,
  sub18  integer,

  -- Vías de captación ("¿cómo nos conociste?")
  capt_amigos   integer,
  capt_whatsapp integer,
  capt_facebook integer,
  capt_hermano  integer,
  capt_campus   integer,

  -- Turnos y sexo
  turno_lx integer,   -- lunes y miércoles
  turno_mj integer,   -- martes y jueves
  chicos   integer,
  chicas   integer,

  nota text,

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Una sola fila por temporada + programa (permite recargar sin duplicar).
create unique index if not exists escuela_historico_temp_prog_key
  on public.escuela_historico (temporada, programa);

create index if not exists escuela_historico_programa_idx
  on public.escuela_historico (programa);

-- Solo dos programas posibles (idempotente: si ya existe, no hace nada).
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'escuela_historico_programa_chk'
  ) then
    alter table public.escuela_historico
      add constraint escuela_historico_programa_chk
      check (programa in ('escuela', 'municipal'));
  end if;
end $$;

-- ------------------------------------------------------------
-- RLS: todo el mundo puede leer; solo admin escribe.
-- ------------------------------------------------------------
alter table public.escuela_historico enable row level security;

drop policy if exists "historico lectura publica" on public.escuela_historico;
create policy "historico lectura publica" on public.escuela_historico
  for select using (true);

drop policy if exists "admin gestiona historico" on public.escuela_historico;
create policy "admin gestiona historico" on public.escuela_historico
  for all to authenticated
  using (public.es_admin())
  with check (public.es_admin());

-- ============================================================
-- DATOS (Excel del club · "Estadística general escuela")
-- Idempotente: se puede volver a ejecutar tantas veces como haga falta.
-- ============================================================
insert into public.escuela_historico (
  temporada, programa,
  apuntados_total, vinieron_a_probar, se_quedaron, pct_inscripciones,
  hermanos, nuevos, renovacion,
  sub6, sub8, sub10, sub12, sub14, sub16, sub18,
  capt_amigos, capt_whatsapp, capt_facebook, capt_hermano, capt_campus,
  turno_lx, turno_mj, chicos, chicas, nota
) values
  -- ---------------- ESCUELA ----------------
  ('2013',    'escuela', 109,  20, null,  null, null, null, null,  3, 13, 17, 13, 23, 24,  8, null, null, null, null, null, null, null, null, null, null),
  ('2014',    'escuela', 149,  35, null,  null, null, null, null, 19, 23, 34, 18, 25, 17, 13, null, null, null, null, null, null, null, null, null, null),
  ('2015',    'escuela', 258,  72, null,  null, null, null, null, 47, 31, 33, 44, 23, 21,  3, null, null, null, null, null, null, null, null, null, null),
  ('2016',    'escuela', 276,  85, null,  null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null),
  ('2017',    'escuela', 324,  95, null,  null, null, null, null, 64, 69, 50, 46, 45, 26, 20, null, null, null, null, null,  94,  84, null, null, null),
  ('2018',    'escuela', 319, 111, null,  null, null, null, null, 38, 65, 65, 41, 55, 38, 15, null, null, null, null, null, 144, 107, null, null, null),
  ('2019',    'escuela', 380, 109, null,  null, null,  165, 215, 52, 71, 82, 64, 51, 41, 16,  118,   17,   10,    0,    9,  95,  58, null, null, null),
  ('2020.21', 'escuela', 429, 235,  226, 96.17,  120,  233, 196, 94, 69, 89, 56, 45, 56, 14,  131,   20,   18,   16,   32, 203, 193, null, null, 'Temporada COVID'),
  ('2021.22', 'escuela', 448, 287,  196, 68.29,  123,  209, 239, 55, 34, 30, 33, 24, 17,  5,  131,   20,   26,   18,   13, 199, 208,  119,   92, null),
  ('2022.23', 'escuela', 395, 211,  156, 73.93,  110,  155, 240, 58, 56, 80, 59, 65, 51, 23,   95,   27,   24,   20,   11, 222, 173,  123,   89, null),
  ('2023.24', 'escuela', 371, 237,  180, 75.95,   68,  180, 168, 82, 68, 66, 58, 35, 42,  9,  129,   12,   26,   68,   10, 200, 163,  124,   78, null),
  ('2024.25', 'escuela', 357, 259,  181, 69.88,   67,  181, 176, 89, 53, 55, 53, 32, 38, 32,  128,   17,   10,   18,   20, 195, 162,  187,   85, null),
  ('2025.26', 'escuela', 333, 225,  149, 66.22,   40,  151, 182, 53, 57, 66, 33, 50, 33, 41,  108,   19,    8,   18,    9, 174, 159,  189,  144, null),

  -- ---------------- ESCUELA MUNICIPAL ----------------
  ('2021.22', 'municipal', 36,  10, null, null, null,   36, null,  0, 12, 10,  5,  2,  0,  0, null, null, null, null, null, 17, 19, null, null, null),
  ('2023.24', 'municipal', 55, null, null, null,   23, null, null, 18, 17, 23, null, null,  0, null, null, null, null, null, null, 25, 30,   34,   11, 'En el Excel el 23 de sub10 aparece en la columna sub12'),
  ('2024.25', 'municipal', 50, null, null, null,   14, null, null,  0, 16, 14, 13,  4,  6,  2, null, null, null, null, null, 20, 30,   34,   16, null),
  ('2025.26', 'municipal', 50, null, null, null,   10, null, null,  0, 13, 15, 13,  5,  4,  0, null, null, null, null, null, 25, 25,   29,   21, null)
on conflict (temporada, programa) do update set
  apuntados_total   = excluded.apuntados_total,
  vinieron_a_probar = excluded.vinieron_a_probar,
  se_quedaron       = excluded.se_quedaron,
  pct_inscripciones = excluded.pct_inscripciones,
  hermanos          = excluded.hermanos,
  nuevos            = excluded.nuevos,
  renovacion        = excluded.renovacion,
  sub6  = excluded.sub6,
  sub8  = excluded.sub8,
  sub10 = excluded.sub10,
  sub12 = excluded.sub12,
  sub14 = excluded.sub14,
  sub16 = excluded.sub16,
  sub18 = excluded.sub18,
  capt_amigos   = excluded.capt_amigos,
  capt_whatsapp = excluded.capt_whatsapp,
  capt_facebook = excluded.capt_facebook,
  capt_hermano  = excluded.capt_hermano,
  capt_campus   = excluded.capt_campus,
  turno_lx = excluded.turno_lx,
  turno_mj = excluded.turno_mj,
  chicos   = excluded.chicos,
  chicas   = excluded.chicas,
  nota     = excluded.nota,
  updated_at = now();
