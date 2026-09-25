-- 223 · Distribución de natación por franja y calle (para Mario)
--
-- Modela lo que Mario mantiene en su hoja: FRANJAS horarias (día+hora, grupo,
-- calles disponibles, monitores) y las INSCRIPCIONES de cada nadador en su
-- calle y nivel. Sirve de base para: ver la distribución (Mario/staff), publicar
-- VACANTES por franja/nivel en la web (semáforo), y —más adelante— acceso de
-- familias y baja puntual por día.
--
-- PRIVACIDAD: hay MENORES (Escuela). Las tablas son PRIVADAS (solo admin/staff y
-- el responsable de natación). Los NOMBRES nunca se sirven en la web; lo público
-- será solo el semáforo agregado (se añade en su fase, con una vista/So security
-- definer). Por eso los datos (nombres) NO van en migraciones del repo (público),
-- se cargan por SQL directo.

-- ---------------------------------------------------------------------------
-- FRANJAS
-- ---------------------------------------------------------------------------
create table if not exists public.natacion_franjas (
  id            uuid primary key default gen_random_uuid(),
  dia           smallint not null check (dia between 1 and 7),   -- 1=Lunes … 6=Sábado
  hora          time     not null,
  orden         smallint not null default 0,                     -- para ordenar en la UI
  grupo         text     not null,                               -- 'Escuela', 'Máster', 'Escuela + Máster'…
  espacios      text,                                            -- 'C1 + C2 + C3 (25 m)', 'C1 (25 m) + vaso 12,5 m'…
  calles        smallint not null default 1,                     -- nº de calles de 25 m
  tiene_vaso    boolean  not null default false,                 -- vaso técnico de 12,5 m
  monitores     text,                                            -- 'Lorena + Leo' (interno)
  -- Semáforo de admisión (lo decide Mario): verde=admitir, ambar=consultar, rojo=cerrado
  semaforo      text check (semaforo in ('verde','ambar','rojo')),
  admite_niveles text[] not null default '{}',                   -- {'Iniciación','Desarrollo','Perfeccionamiento'}
  criterio      text,                                            -- texto de Mario para nuevas altas
  activa        boolean  not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (dia, hora)
);

comment on table public.natacion_franjas is
  'Franjas horarias de natación (día+hora) con sus calles, monitores y semáforo de admisión. Base del cuadro de vacantes.';

-- ---------------------------------------------------------------------------
-- INSCRIPCIONES (un nadador en una franja, con su calle y nivel)
-- ---------------------------------------------------------------------------
create table if not exists public.natacion_inscripciones (
  id            uuid primary key default gen_random_uuid(),
  franja_id     uuid not null references public.natacion_franjas(id) on delete cascade,
  calle         text not null,                                   -- 'C1','C2','C3','Vaso'
  nombre        text not null,                                   -- nombre y apellidos (texto; menores incluidos)
  tipo          text not null check (tipo in ('Escuela','Máster')),
  nivel         text check (nivel in ('Iniciación','Desarrollo','Perfeccionamiento')),
  perfil_id     uuid references public.perfiles(id) on delete set null,  -- cuenta del portal, si tiene
  atleta_id     uuid references public.atletas(id)  on delete set null,  -- ficha en el padrón del club, si es socio/atleta
  observaciones text,
  activa        boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists natacion_inscripciones_franja on public.natacion_inscripciones(franja_id);
create index if not exists natacion_inscripciones_perfil on public.natacion_inscripciones(perfil_id);
create index if not exists natacion_inscripciones_atleta on public.natacion_inscripciones(atleta_id);

comment on table public.natacion_inscripciones is
  'Nadadores por franja y calle, con su nivel. PRIVADO (hay menores): solo admin/staff/responsable de natación. Los nombres nunca se publican.';

-- ---------------------------------------------------------------------------
-- RLS · privado: admin, staff, o responsable de natación / escuela de natación
-- ---------------------------------------------------------------------------
alter table public.natacion_franjas       enable row level security;
alter table public.natacion_inscripciones enable row level security;

drop policy if exists "natacion franjas staff" on public.natacion_franjas;
create policy "natacion franjas staff" on public.natacion_franjas for all to authenticated
  using      (public.es_admin() or public.es_staff() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))
  with check (public.es_admin() or public.es_staff() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'));

drop policy if exists "natacion inscripciones staff" on public.natacion_inscripciones;
create policy "natacion inscripciones staff" on public.natacion_inscripciones for all to authenticated
  using      (public.es_admin() or public.es_staff() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))
  with check (public.es_admin() or public.es_staff() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'));
