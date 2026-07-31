-- ============================================================
-- 015 · PLANTILLAS DE SEMANA (microciclo reutilizable)
-- ------------------------------------------------------------
-- Guarda una semana completa (hasta 7 sesiones con sus bloques)
-- con un nombre, para volver a aplicarla a cualquier grupo y
-- cualquier fecha de inicio con un par de clics.
--
-- ¿Por qué una tabla nueva y no plantillas_microciclo?
--   · plantillas_microciclo exige `fase` NOT NULL y guarda una
--     "estructura" pensada para otra cosa.
--   · plantillas_bloque guarda UN bloque suelto, no una semana.
--   · Además ambas solo tienen policy de admin: un entrenador no
--     puede ni leerlas ni escribirlas. Se dejan intactas.
--
-- Formato de `datos` (jsonb):
--   {
--     "sesiones": [
--       { "offset_dia": 0,            -- 0 = lunes … 6 = domingo
--         "dia_semana": "lunes",
--         "tipo": "pista",            -- valores del CHECK de sesiones
--         "rol": "calidad_fuerte",
--         "titulo": "Series 6x150",
--         "nota_razonamiento": "…",
--         "bloques": [ { "etiqueta": "…", "filas": [ … ] } ] }
--     ]
--   }
-- `bloques` mantiene EXACTAMENTE la misma forma que sesiones.bloques,
-- que es la que lee la zona del atleta. No cambiar.
-- ============================================================

-- Helper: ¿soy parte del equipo técnico? (SECURITY DEFINER para poder
-- consultar perfiles desde dentro de una policy sin chocar con su RLS)
create or replace function public.es_staff()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and p.rol in ('admin','coordinador','entrenador')
  );
$$;

create table if not exists public.plantillas_semana (
  id          uuid primary key default gen_random_uuid(),
  nombre      text not null,
  creado_por  uuid references public.perfiles(id),
  datos       jsonb not null default '{}'::jsonb,
  created_at  timestamp with time zone default now()
);

create index if not exists idx_plantillas_semana_autor
  on public.plantillas_semana (creado_por);

alter table public.plantillas_semana enable row level security;

-- 1) La dirección del club gestiona todo
drop policy if exists "admin gestiona plantillas de semana" on public.plantillas_semana;
create policy "admin gestiona plantillas de semana" on public.plantillas_semana
for all to authenticated
using (public.es_admin())
with check (public.es_admin());

-- 2) El autor gestiona (edita/borra) las suyas
drop policy if exists "autor gestiona sus plantillas de semana" on public.plantillas_semana;
create policy "autor gestiona sus plantillas de semana" on public.plantillas_semana
for all to authenticated
using (creado_por = public.mi_perfil_id())
with check (creado_por = public.mi_perfil_id());

-- 3) Todo el equipo técnico puede LEER las plantillas (se comparten
--    entre entrenadores: 7 grupos con estructuras parecidas)
drop policy if exists "equipo tecnico lee plantillas de semana" on public.plantillas_semana;
create policy "equipo tecnico lee plantillas de semana" on public.plantillas_semana
for select to authenticated
using (public.es_staff());
