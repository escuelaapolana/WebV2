-- 210 · Ficha completa del monitor / entrenador
-- El alta de monitor (entrenador/alta) solo creaba la cuenta (nombre, correo,
-- contraseña). Ahora recoge una FICHA con sus datos: fecha de nacimiento, DNI,
-- dirección y sexo. Son datos sensibles, así que NO van en 'perfiles' (un
-- entrenador puede leer los perfiles del equipo técnico y vería el DNI de los
-- demás). Van en tabla APARTE: solo el admin y el propio monitor ven su ficha.
-- El teléfono sigue en el perfil, que es un dato de contacto normal.
create table if not exists public.entrenador_ficha (
  perfil_id uuid primary key references public.perfiles(id) on delete cascade,
  fecha_nacimiento date,
  dni text,
  sexo text,
  direccion text,
  cp text,
  localidad text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.entrenador_ficha enable row level security;

-- El admin gestiona todas las fichas.
drop policy if exists entrenador_ficha_admin on public.entrenador_ficha;
create policy entrenador_ficha_admin on public.entrenador_ficha for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

-- El propio monitor ve y edita su ficha (y solo la suya).
drop policy if exists entrenador_ficha_propia on public.entrenador_ficha;
create policy entrenador_ficha_propia on public.entrenador_ficha for all to authenticated
  using (perfil_id = public.mi_perfil_id()) with check (perfil_id = public.mi_perfil_id());

grant select, insert, update on public.entrenador_ficha to authenticated;
