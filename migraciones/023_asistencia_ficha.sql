-- ============================================================
-- 023 · Pasar lista y ficha del atleta (zona del entrenador)
-- ============================================================
--
-- POR QUÉ ASÍ (decisión sobre la tabla `asistencia`)
-- --------------------------------------------------
-- `asistencia` colgaba de `entrenamientos`, una tabla antigua que
-- está VACÍA (0 filas) y que ya no se usa: la planificación real
-- vive en `sesiones` (microciclos, bloques, publicada…).
--
-- Se ha descartado crear una fila en `entrenamientos` al vuelo:
-- duplicaría el concepto de sesión en una tabla muerta y dejaría
-- filas huérfanas los días en que el grupo entrena sin sesión
-- planificada.
--
-- En su lugar `asistencia` gana:
--   · `fecha`     → la clave real de pasar lista (un atleta, un día).
--   · `sesion_id` → enlace OPCIONAL a la sesión planificada de ese día.
--   · `grupo_id`  → el grupo con el que se pasó lista.
-- Así se puede pasar lista aunque no haya sesión planificada, y la
-- lista se corrige después reescribiendo la misma fila (UNIQUE por
-- atleta y fecha, igual que hace `ausencias`).
--
-- «Sin marcar» = no hay fila. «Ausente» = fila con presente=false.
--
-- Además se le da al entrenador el permiso mínimo de UPDATE sobre
-- SUS atletas (no lo tenía) para las acciones de la ficha: cambiar
-- de grupo, confirmar el alta tras la prueba, marcar lesión y dar
-- de baja. Un disparador limita qué columnas puede tocar.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1 · ASISTENCIA sobre las sesiones reales
-- ------------------------------------------------------------
alter table public.asistencia
  add column if not exists sesion_id      uuid references public.sesiones(id) on delete set null,
  add column if not exists fecha          date,
  add column if not exists grupo_id       uuid references public.grupos(id),
  add column if not exists registrado_por uuid references public.perfiles(id),
  add column if not exists updated_at     timestamptz default now();

-- Filas antiguas (si las hubiera): se les copia la fecha del entrenamiento.
update public.asistencia a
   set fecha = e.fecha, grupo_id = e.grupo_id
  from public.entrenamientos e
 where a.entrenamiento_id = e.id and a.fecha is null;

-- El atleta es obligatorio: sin él la fila no significa nada.
alter table public.asistencia alter column atleta_id set not null;
alter table public.asistencia alter column presente  set default false;

-- Una marca por atleta y día. Es la clave con la que se pasa lista
-- y con la que se corrige después (permite el UPSERT desde el portal).
-- Va como RESTRICCIÓN y no como índice parcial: un índice parcial no
-- vale para «on conflict». Las filas antiguas con fecha nula no
-- estorban, porque en SQL dos nulos no chocan entre sí.
drop index if exists public.asistencia_atleta_fecha_unico;
alter table public.asistencia drop constraint if exists asistencia_atleta_fecha_unico;
alter table public.asistencia add constraint asistencia_atleta_fecha_unico unique (atleta_id, fecha);
create index if not exists asistencia_fecha_idx  on public.asistencia (fecha);
create index if not exists asistencia_sesion_idx on public.asistencia (sesion_id);
create index if not exists asistencia_grupo_idx  on public.asistencia (grupo_id);

-- Una fila tiene que apuntar a un día o al entrenamiento antiguo.
alter table public.asistencia drop constraint if exists asistencia_origen_check;
alter table public.asistencia add constraint asistencia_origen_check
  check (fecha is not null or entrenamiento_id is not null);

-- La FK vieja se mantiene por compatibilidad, pero ya no es obligatoria.
alter table public.asistencia alter column entrenamiento_id drop not null;

-- ------------------------------------------------------------
-- 2 · RLS de asistencia
-- ------------------------------------------------------------
-- Ya existían:
--   · «admin gestiona todo»       (ALL)    → es_admin()
--   · «ver datos de mis atletas»  (SELECT) → atleta_id in mis_atletas()
--     que da LECTURA al entrenador, al atleta y a su familia.
-- Faltaba la ESCRITURA del entrenador. soy_staff_de_atleta() ya
-- devuelve true para el admin o para el entrenador de ESE atleta.
alter table public.asistencia enable row level security;

drop policy if exists "staff pasa lista"       on public.asistencia;
drop policy if exists "staff corrige la lista" on public.asistencia;
drop policy if exists "staff borra de la lista" on public.asistencia;

create policy "staff pasa lista" on public.asistencia
  for insert to authenticated
  with check (public.soy_staff_de_atleta(atleta_id));

create policy "staff corrige la lista" on public.asistencia
  for update to authenticated
  using      (public.soy_staff_de_atleta(atleta_id))
  with check (public.soy_staff_de_atleta(atleta_id));

create policy "staff borra de la lista" on public.asistencia
  for delete to authenticated
  using (public.soy_staff_de_atleta(atleta_id));

-- Firma automática de quién pasó la lista y cuándo.
create or replace function public.asistencia_firma()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  new.registrado_por := coalesce(new.registrado_por, public.mi_perfil_id());
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists asistencia_firma_trg on public.asistencia;
create trigger asistencia_firma_trg
  before insert or update on public.asistencia
  for each row execute function public.asistencia_firma();

-- ------------------------------------------------------------
-- 3 · El entrenador puede gestionar a SUS atletas
-- ------------------------------------------------------------
-- Antes solo tenía SELECT («ver mis atletas»). Sin esto no puede
-- cambiar de grupo, confirmar el alta, marcar lesión ni dar de baja.
drop policy if exists "entrenador gestiona sus atletas" on public.atletas;
create policy "entrenador gestiona sus atletas" on public.atletas
  for update to authenticated
  using      (entrenador_id = public.mi_perfil_id())
  with check (entrenador_id = public.mi_perfil_id());

-- RLS no distingue columnas: este disparador acota qué puede tocar
-- el entrenador. El admin no se ve afectado.
create or replace function public.atletas_cambios_del_entrenador()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  permitidas text[] := array['grupo_id','estado','fecha_prueba_fin','observaciones','contexto_entrenador','updated_at'];
  viejo jsonb := to_jsonb(old);
  nuevo jsonb := to_jsonb(new);
  c text;
begin
  new.updated_at := now();

  if public.es_admin() then
    return new;
  end if;

  -- Fuera de las columnas permitidas, nada puede cambiar.
  foreach c in array permitidas loop
    viejo := viejo - c;
    nuevo := nuevo - c;
  end loop;
  if viejo is distinct from nuevo then
    raise exception 'Un entrenador solo puede cambiar el grupo, el estado, el fin de la prueba y las observaciones de sus atletas.';
  end if;

  -- Y solo puede moverlo a un grupo que dirija él (o sacarlo de grupo).
  if new.grupo_id is distinct from old.grupo_id and new.grupo_id is not null then
    if not exists (
      select 1 from public.grupos g
       where g.id = new.grupo_id and g.entrenador_id = public.mi_perfil_id()
    ) then
      raise exception 'Solo puedes mover al atleta a un grupo que dirijas tú. Para pasarlo a otro entrenador, avisa a administración.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists atletas_cambios_entrenador_trg on public.atletas;
create trigger atletas_cambios_entrenador_trg
  before update on public.atletas
  for each row execute function public.atletas_cambios_del_entrenador();

-- ------------------------------------------------------------
-- 4 · Contacto de la familia (para «Escribir a la familia»)
-- ------------------------------------------------------------
-- `perfiles` solo deja leer el perfil propio, así que el entrenador
-- no puede sacar el correo del padre/madre con un select normal.
-- Esta función devuelve SOLO el contacto del atleta que el
-- entrenador tiene a su cargo, y nada más.
create or replace function public.contacto_familia_atleta(p_atleta uuid)
returns table (perfil_id uuid, nombre text, apellidos text, email text, telefono text, rol text, es_el_propio_atleta boolean)
language sql
stable
security definer
set search_path to 'public'
as $$
  select p.id, p.nombre, p.apellidos, p.email, p.telefono, p.rol,
         (a.perfil_padre_id is null) as es_el_propio_atleta
    from public.atletas a
    join public.perfiles p on p.id = coalesce(a.perfil_padre_id, a.perfil_id)
   where a.id = p_atleta
     and public.soy_staff_de_atleta(p_atleta);
$$;

revoke all on function public.contacto_familia_atleta(uuid) from public, anon;
grant execute on function public.contacto_familia_atleta(uuid) to authenticated;

commit;
