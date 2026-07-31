-- ============================================================
-- 025 · CALENDARIO DEL CLUB · VER TODO Y APUNTARSE
-- ------------------------------------------------------------
-- Qué resuelve (maqueta 4c «Calendario»):
--   Un único calendario mensual donde el socio ve TODO lo que pasa
--   en el club —entrenamientos de los grupos, clases de El Cubo,
--   competiciones y eventos— y donde, cuando la actividad lo
--   permite, se apunta desde ahí mismo.
--
-- QUÉ **NO** SE TOCA (ya existe y se reutiliza tal cual):
--   · El Cubo (migración 020): cubo_clases, cubo_reservas, bonos
--     por usos y las funciones cubo_apuntarme() / cubo_desapuntarme().
--     El calendario llama a esas funciones: las reglas de plazas,
--     lista de espera y descuento del bono siguen viviendo en un
--     único sitio.
--   · Competiciones (migración 012): competicion_atleta, el bono en
--     euros (bono_saldo) y competicion_abierta(). El calendario
--     enseña el estado y lleva a /portal/competiciones/ para elegir
--     prueba, que es donde está esa lógica.
--   · Eventos: se muestran, pero apuntarse a un evento lo sigue
--     gestionando el club (no hay política de alta para el socio).
--
-- QUÉ FALTABA Y SE AÑADE AQUÍ (lo mínimo imprescindible):
--   1) Los ENTRENAMIENTOS (`sesiones`) no tenían forma de decir
--      «a esto se puede apuntar quien quiera», ni cuántas plazas
--      hay, ni a qué secciones está abierto. Cuatro columnas.
--   2) No había dónde guardar quién se apunta a un entrenamiento:
--      tabla `sesion_inscripciones`.
--   3) Un socio sólo podía LEER las sesiones de su propio grupo, así
--      que el calendario se quedaba medio vacío. Vista
--      `sesiones_agenda`: enseña qué pasa (día, hora, título, grupo,
--      sitio) SIN enseñar el contenido del entrenamiento
--      (`bloques`, `nota_razonamiento`), que sigue siendo privado.
--
-- QUIÉN DECIDE SI TE PUEDES APUNTAR: la BASE DE DATOS.
--   Un disparador echa el cerrojo sobre la sesión, cuenta los
--   apuntados y comprueba fecha, sección y plazas. Da igual desde
--   dónde se intente: si está cerrada, completa o no es para tu
--   sección, la fila no entra.
-- ============================================================

-- ------------------------------------------------------------
-- 1) ENTRENAMIENTOS: ABIERTOS, PLAZAS, A QUIÉN Y DÓNDE
-- ------------------------------------------------------------
alter table public.sesiones
  add column if not exists abierta_inscripcion boolean not null default false,
  add column if not exists plazas              integer,
  add column if not exists abierta_a           text[],
  add column if not exists hora                time,
  add column if not exists lugar               text;

comment on column public.sesiones.abierta_inscripcion is
  'true = cualquiera del club (dentro de abierta_a) puede apuntarse desde el calendario. false = es el entreno de su grupo y punto.';
comment on column public.sesiones.plazas is
  'Aforo cuando la sesión está abierta. NULL = sin límite de plazas.';
comment on column public.sesiones.abierta_a is
  'Secciones admitidas (mismos valores que grupos.seccion). NULL = abierta a todo el club. Sirve para excluir: a un entreno de la escuela no se apunta cualquiera.';
comment on column public.sesiones.hora is
  'Hora de inicio, para ordenar el panel del día del calendario.';
comment on column public.sesiones.lugar is
  'Instalación o punto de quedada (Pista Joaquín Villar, Playa San Juan…).';

-- Coherencia: si hay aforo, que sea un número con sentido.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'sesiones_plazas_check') then
    alter table public.sesiones add constraint sesiones_plazas_check check (plazas is null or plazas > 0);
  end if;
end $$;

-- ------------------------------------------------------------
-- 2) QUIÉN SE APUNTA A UN ENTRENAMIENTO
-- ------------------------------------------------------------
create table if not exists public.sesion_inscripciones (
  id         uuid primary key default gen_random_uuid(),
  sesion_id  uuid not null references public.sesiones(id) on delete cascade,
  atleta_id  uuid not null references public.atletas(id)  on delete cascade,
  created_at timestamptz default now(),
  constraint sesion_inscripciones_unica unique (sesion_id, atleta_id)
);

create index if not exists idx_sesion_inscripciones_sesion on public.sesion_inscripciones (sesion_id);
create index if not exists idx_sesion_inscripciones_atleta on public.sesion_inscripciones (atleta_id);

comment on table public.sesion_inscripciones is
  'Apuntados a un entrenamiento abierto del calendario. No gasta bono: los entrenos van con la cuota. El bono por usos es de El Cubo (cubo_reservas).';

-- ------------------------------------------------------------
-- 3) ¿ESTÁ ABIERTA ESTA SESIÓN PARA ESTE ATLETA?
--    Una sola función con la regla completa, para que la usen
--    tanto la política de seguridad como el disparador.
-- ------------------------------------------------------------
create or replace function public.sesion_abierta_para(p_sesion uuid, p_atleta uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.sesiones s
    left join public.atletas a on a.id = p_atleta
    left join public.grupos  g on g.id = a.grupo_id
    where s.id = p_sesion
      and coalesce(s.publicada, false)
      and coalesce(s.abierta_inscripcion, false)
      and s.fecha >= current_date
      and (s.abierta_a is null or g.seccion = any (s.abierta_a))
  );
$$;

comment on function public.sesion_abierta_para(uuid, uuid) is
  'true si la sesión está publicada, abierta, no ha pasado y la sección del atleta entra. Las plazas las mira el disparador, que necesita cerrojo.';

grant execute on function public.sesion_abierta_para(uuid, uuid) to authenticated;

-- ------------------------------------------------------------
-- 4) DISPARADOR: FECHA, SECCIÓN Y PLAZAS
-- ------------------------------------------------------------
create or replace function public.sesion_inscripciones_control()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sesion   public.sesiones;
  v_seccion  text;
  v_apuntados integer;
begin
  -- Cerrojo por sesión: dos personas a la vez no cogen la misma plaza.
  perform pg_advisory_xact_lock(hashtextextended(NEW.sesion_id::text, 0));

  select * into v_sesion from public.sesiones where id = NEW.sesion_id;
  if not found then
    raise exception 'Ese entrenamiento ya no existe.' using errcode = 'P0001';
  end if;

  if not coalesce(v_sesion.publicada, false) or not coalesce(v_sesion.abierta_inscripcion, false) then
    raise exception 'Ese entrenamiento no está abierto para apuntarse.' using errcode = 'P0001';
  end if;

  if v_sesion.fecha < current_date then
    raise exception 'Ese entrenamiento ya ha pasado.' using errcode = 'P0001';
  end if;

  if v_sesion.abierta_a is not null then
    select g.seccion into v_seccion
    from public.atletas a left join public.grupos g on g.id = a.grupo_id
    where a.id = NEW.atleta_id;

    if v_seccion is null or not (v_seccion = any (v_sesion.abierta_a)) then
      raise exception 'Ese entrenamiento es solo para: %.', array_to_string(v_sesion.abierta_a, ', ')
        using errcode = 'P0001';
    end if;
  end if;

  if v_sesion.plazas is not null then
    select count(*) into v_apuntados
    from public.sesion_inscripciones i
    where i.sesion_id = NEW.sesion_id
      and i.id <> NEW.id;

    if v_apuntados >= v_sesion.plazas then
      raise exception 'Ese entrenamiento está completo: ya no quedan plazas.'
        using errcode = 'P0001';
    end if;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_sesion_inscripciones_control on public.sesion_inscripciones;
create trigger trg_sesion_inscripciones_control
  before insert on public.sesion_inscripciones
  for each row execute function public.sesion_inscripciones_control();

-- ------------------------------------------------------------
-- 5) SEGURIDAD DE LA TABLA
-- ------------------------------------------------------------
alter table public.sesion_inscripciones enable row level security;

drop policy if exists "admin gestiona apuntados"        on public.sesion_inscripciones;
drop policy if exists "staff gestiona apuntados"        on public.sesion_inscripciones;
drop policy if exists "ver mis apuntados"               on public.sesion_inscripciones;
drop policy if exists "apuntarme a un entreno abierto"  on public.sesion_inscripciones;
drop policy if exists "quitarme de un entreno"          on public.sesion_inscripciones;

create policy "admin gestiona apuntados" on public.sesion_inscripciones
  for all to authenticated
  using (public.es_admin()) with check (public.es_admin());

create policy "staff gestiona apuntados" on public.sesion_inscripciones
  for all to authenticated
  using (public.soy_staff_de_atleta(atleta_id))
  with check (public.soy_staff_de_atleta(atleta_id));

create policy "ver mis apuntados" on public.sesion_inscripciones
  for select to authenticated
  using (atleta_id in (select public.mis_atletas()));

-- Sólo para MIS atletas y sólo si la sesión está realmente abierta
-- para ese atleta. Las plazas las remata el disparador.
create policy "apuntarme a un entreno abierto" on public.sesion_inscripciones
  for insert to authenticated
  with check (
    atleta_id in (select public.mis_atletas())
    and public.sesion_abierta_para(sesion_id, atleta_id)
  );

create policy "quitarme de un entreno" on public.sesion_inscripciones
  for delete to authenticated
  using (
    atleta_id in (select public.mis_atletas())
    and exists (select 1 from public.sesiones s where s.id = sesion_id and s.fecha >= current_date)
  );

grant select, insert, delete on public.sesion_inscripciones to authenticated;

-- ------------------------------------------------------------
-- 6) LA AGENDA DEL CLUB
--    Vista sin `security_invoker`: se ejecuta con los permisos de
--    quien la creó, así que cualquiera del club ve QUÉ pasa cada
--    día (igual que ya pasa con cubo_clases_ocupacion). Lo que NO
--    sale aquí es el contenido del entrenamiento: `bloques` y
--    `nota_razonamiento` se quedan en la tabla, protegidos por su
--    propia política.
--    Las sesiones individuales (atletas_ids) sólo aparecen si están
--    abiertas: si no, son el plan personal de alguien.
-- ------------------------------------------------------------
drop view if exists public.sesiones_agenda;
create view public.sesiones_agenda as
select
  s.id                                   as sesion_id,
  s.fecha,
  s.hora,
  s.titulo,
  s.tipo,
  s.rol,
  s.lugar,
  s.grupo_id,
  g.nombre                               as grupo,
  g.seccion,
  coalesce(s.abierta_inscripcion, false) as abierta_inscripcion,
  s.abierta_a,
  s.plazas,
  (select count(*) from public.sesion_inscripciones i where i.sesion_id = s.id)::int as apuntados,
  case
    when s.plazas is null then null
    else greatest(0, s.plazas - (select count(*) from public.sesion_inscripciones i where i.sesion_id = s.id))::int
  end                                    as libres
from public.sesiones s
left join public.grupos g on g.id = s.grupo_id
where coalesce(s.publicada, false)
  and (s.atletas_ids is null or coalesce(s.abierta_inscripcion, false));

comment on view public.sesiones_agenda is
  'Qué entrena cada grupo cada día, para el calendario del club. Sin el contenido del entrenamiento.';

grant select on public.sesiones_agenda to authenticated;

-- ============================================================
-- FIN 025
-- ============================================================
