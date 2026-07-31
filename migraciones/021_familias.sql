-- ============================================================
-- 021 · ZONA DE FAMILIAS: avisar de una falta + nota para la familia
-- ------------------------------------------------------------
-- Lo que resuelve, según la maqueta del portal de familias (5d):
--
--   1) "Avisar falta"  -> tabla public.ausencias
--      La familia (o el propio atleta) avisa de que un día NO va
--      a entrenar, con la fecha y el motivo.
--
--   2) "Cómo va Pau"   -> tabla public.notas_familia
--      La nota que el entrenador COMPARTE con la familia.
--
-- MUY IMPORTANTE sobre las notas:
--   public.notas_atleta (migración 009) es la libreta PRIVADA del
--   equipo técnico y la familia NO puede verla jamás. Aquí NO se
--   toca esa tabla ni se le añade ninguna policy. Las notas que sí
--   ve la familia viven en una tabla NUEVA y distinta,
--   public.notas_familia, para que no haya forma de confundirlas.
--
-- Por qué NO se reutiliza public.asistencia:
--   asistencia(entrenamiento_id, atleta_id, presente) cuelga de la
--   tabla "entrenamientos" (que el portal no usa: el plan vive en
--   "sesiones"), no tiene motivo, no guarda quién avisa ni cuándo,
--   y es la lista que pasa el entrenador el día del entreno. Son
--   dos cosas distintas: el aviso lo da la familia ANTES, la lista
--   la pasa el entrenador DESPUÉS. Se dejan separadas.
-- ============================================================


-- ------------------------------------------------------------
-- 1) AUSENCIAS · "no va a ir a entrenar"
-- ------------------------------------------------------------
create table if not exists public.ausencias (
  id uuid primary key default gen_random_uuid(),
  atleta_id uuid not null references public.atletas(id) on delete cascade,
  fecha date not null,
  motivo text,
  sesion_id uuid references public.sesiones(id) on delete set null,
  avisado_por uuid references public.perfiles(id),
  avisado_por_nombre text,
  created_at timestamptz default now()
);

-- Un solo aviso por atleta y día (si vuelve a avisar, se actualiza el motivo)
create unique index if not exists ausencias_atleta_fecha_unico
  on public.ausencias (atleta_id, fecha);
create index if not exists ausencias_fecha_idx on public.ausencias (fecha);

comment on table public.ausencias is 'Avisos de falta a un entrenamiento. Los da la familia (o el atleta) por adelantado desde el portal.';
comment on column public.ausencias.sesion_id is 'Sesión concreta a la que no va, si el aviso sale de una sesión publicada. Puede ir vacío.';
comment on column public.ausencias.avisado_por is 'Perfil que dio el aviso. Lo rellena solo un trigger.';
comment on column public.ausencias.avisado_por_nombre is 'Nombre de quien avisó, guardado aquí porque el staff no puede leer la tabla perfiles de otras personas.';


-- ------------------------------------------------------------
-- 2) NOTAS COMPARTIDAS CON LA FAMILIA · "cómo va Pau"
-- ------------------------------------------------------------
create table if not exists public.notas_familia (
  id uuid primary key default gen_random_uuid(),
  atleta_id uuid not null references public.atletas(id) on delete cascade,
  autor_id uuid references public.perfiles(id),
  autor_nombre text,
  fecha date not null default current_date,
  texto text not null,
  visible boolean not null default true,
  created_at timestamptz default now()
);

create index if not exists notas_familia_atleta_idx on public.notas_familia (atleta_id, fecha desc);

comment on table public.notas_familia is 'Notas del entrenador ESCRITAS PARA LA FAMILIA. Son públicas para la familia del atleta. No confundir con notas_atleta, que es privada del equipo técnico.';
comment on column public.notas_familia.visible is 'Si se pone en false, la nota deja de verse en el portal sin borrarla.';


-- ------------------------------------------------------------
-- 3) TRIGGERS: firmar quién avisa y quién escribe
--    (la familia no puede leer la tabla perfiles del entrenador,
--     por eso el nombre se guarda en la propia fila)
-- ------------------------------------------------------------
create or replace function public.ausencias_firma()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.avisado_por is null then
    new.avisado_por := public.mi_perfil_id();
  end if;
  if coalesce(new.avisado_por_nombre, '') = '' then
    select nullif(trim(coalesce(p.nombre,'') || ' ' || coalesce(p.apellidos,'')), '')
      into new.avisado_por_nombre
      from public.perfiles p where p.id = new.avisado_por;
  end if;
  return new;
end;
$$;

drop trigger if exists ausencias_firma_trg on public.ausencias;
create trigger ausencias_firma_trg
before insert or update on public.ausencias
for each row execute function public.ausencias_firma();


create or replace function public.notas_familia_firma()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.autor_id is null then
    new.autor_id := public.mi_perfil_id();
  end if;
  if coalesce(new.autor_nombre, '') = '' then
    select nullif(trim(coalesce(p.nombre,'') || ' ' || coalesce(p.apellidos,'')), '')
      into new.autor_nombre
      from public.perfiles p where p.id = new.autor_id;
  end if;
  return new;
end;
$$;

drop trigger if exists notas_familia_firma_trg on public.notas_familia;
create trigger notas_familia_firma_trg
before insert or update on public.notas_familia
for each row execute function public.notas_familia_firma();


-- ------------------------------------------------------------
-- 4) PERMISOS (RLS)
-- ------------------------------------------------------------
alter table public.ausencias enable row level security;
alter table public.notas_familia enable row level security;

-- ---- AUSENCIAS ----

-- Ver: la familia/atleta ve las de SUS atletas; el entrenador de ese
-- atleta también entra por mis_atletas() (incluye entrenador_id).
drop policy if exists "ver ausencias de mis atletas" on public.ausencias;
create policy "ver ausencias de mis atletas" on public.ausencias
for select to authenticated
using (
  public.es_admin()
  or atleta_id in (select public.mis_atletas())
);

-- Avisar: solo de SUS atletas, firmando con su propio perfil y sin
-- avisar de días que ya pasaron.
drop policy if exists "familia avisa de una falta" on public.ausencias;
create policy "familia avisa de una falta" on public.ausencias
for insert to authenticated
with check (
  atleta_id in (select public.mis_atletas())
  and avisado_por = public.mi_perfil_id()
  and fecha >= current_date
);

-- Corregir el motivo de un aviso propio que todavía no ha pasado.
drop policy if exists "familia corrige su aviso" on public.ausencias;
create policy "familia corrige su aviso" on public.ausencias
for update to authenticated
using (
  atleta_id in (select public.mis_atletas())
  and avisado_por = public.mi_perfil_id()
  and fecha >= current_date
)
with check (
  atleta_id in (select public.mis_atletas())
  and avisado_por = public.mi_perfil_id()
  and fecha >= current_date
);

-- Retirar un aviso propio (al final sí va a ir), mientras no haya pasado.
drop policy if exists "familia retira su aviso" on public.ausencias;
create policy "familia retira su aviso" on public.ausencias
for delete to authenticated
using (
  atleta_id in (select public.mis_atletas())
  and avisado_por = public.mi_perfil_id()
  and fecha >= current_date
);

-- El staff del atleta (su entrenador o un admin) gestiona sin límite de fecha.
drop policy if exists "staff gestiona ausencias" on public.ausencias;
create policy "staff gestiona ausencias" on public.ausencias
for all to authenticated
using (public.soy_staff_de_atleta(atleta_id))
with check (public.soy_staff_de_atleta(atleta_id));


-- ---- NOTAS PARA LA FAMILIA ----

-- Ver: el staff del atleta siempre; la familia/atleta solo las visibles.
drop policy if exists "familia lee las notas compartidas" on public.notas_familia;
create policy "familia lee las notas compartidas" on public.notas_familia
for select to authenticated
using (
  public.soy_staff_de_atleta(atleta_id)
  or (visible and atleta_id in (select public.mis_atletas()))
);

-- Escribir, corregir y borrar: SOLO el staff de ese atleta.
drop policy if exists "staff escribe notas para la familia" on public.notas_familia;
create policy "staff escribe notas para la familia" on public.notas_familia
for insert to authenticated
with check (public.soy_staff_de_atleta(atleta_id));

drop policy if exists "staff corrige notas para la familia" on public.notas_familia;
create policy "staff corrige notas para la familia" on public.notas_familia
for update to authenticated
using (public.soy_staff_de_atleta(atleta_id))
with check (public.soy_staff_de_atleta(atleta_id));

drop policy if exists "staff borra notas para la familia" on public.notas_familia;
create policy "staff borra notas para la familia" on public.notas_familia
for delete to authenticated
using (public.soy_staff_de_atleta(atleta_id));


-- ------------------------------------------------------------
-- 5) Cómo escribe el entrenador una nota para la familia
--    (mientras no exista el botón en el panel del entrenador)
-- ------------------------------------------------------------
--   insert into public.notas_familia (atleta_id, texto)
--   values ('<id del atleta>', 'Muy bien en los relevos, empieza a controlar el ritmo…');
--
--   La firma y la fecha se rellenan solas.
-- ============================================================
