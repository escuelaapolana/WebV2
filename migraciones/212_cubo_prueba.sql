-- 212 · Altas de la PRUEBA GRATIS del Cubo (fuerza, octubre)
-- El presidente ofrece 3 turnos GRATIS de fuerza en el Cubo (viernes, sábado,
-- domingo). La gente se apunta por un formulario público (sin pago). Estas
-- altas van SEPARADAS de las del Cubo de pago (cubo_altas): son gratis y
-- temporales, y sirven para ver cuánta gente hay en cada turno (si un turno
-- tiene poca gente, se cancela; si hay de sobra, se amplía).
create table if not exists public.cubo_prueba (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  apellidos text,
  telefono text,
  email text,
  turnos text[] not null default '{}',      -- 'viernes' | 'sabado' | 'domingo'
  quien text,                                -- 'socio' | 'escuela' | 'otro'
  hijo text,                                 -- nombre del hijo/a si es familia de la escuela
  alternativa text,                          -- otro horario (de esos 3 días) que le venga mejor
  perfil_id uuid,
  atleta_id uuid,
  lista_espera boolean not null default false,
  estado text not null default 'apuntado',   -- apuntado | cancelado
  created_at timestamptz not null default now()
);
create index if not exists cubo_prueba_turnos_idx on public.cubo_prueba using gin (turnos);

alter table public.cubo_prueba enable row level security;

-- El admin y quien pasa lista del Cubo (Claudia) ven las altas.
drop policy if exists cubo_prueba_gestion on public.cubo_prueba;
create policy cubo_prueba_gestion on public.cubo_prueba for all to authenticated
  using (public.es_admin() or public.es_cubo_lista()) with check (public.es_admin() or public.es_cubo_lista());

-- Cada persona ve su propia alta.
drop policy if exists cubo_prueba_propia on public.cubo_prueba;
create policy cubo_prueba_propia on public.cubo_prueba for select to authenticated
  using (perfil_id = public.mi_perfil_id());

grant select, insert, update on public.cubo_prueba to authenticated;
