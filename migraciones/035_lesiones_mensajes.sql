-- ============================================================
-- 035 · LESIONES Y DISPONIBILIDAD  +  MENSAJES DIRECTOS
-- ------------------------------------------------------------
-- 1) Completa la tabla `lesiones_atleta` (existía pero no se
--    usaba en ninguna pantalla) para poder llevar el historial
--    de lesiones y la disponibilidad de cada atleta.
-- 2) Crea `mensajes_directos`: conversación privada entre el
--    entrenador y sus atletas o sus familias, dentro del portal.
--
-- OJO: `lesiones_atleta` guarda DATOS DE SALUD. Las reglas de
-- acceso son estrictas: solo el propio atleta, su familia, su
-- entrenador y administración. La coordinación NO entra aquí.
-- ============================================================


-- ============================================================
-- 1 · LESIONES
-- ============================================================

alter table public.lesiones_atleta add column if not exists tipo text;
alter table public.lesiones_atleta add column if not exists disponibilidad text;
alter table public.lesiones_atleta add column if not exists fecha_alta date;
alter table public.lesiones_atleta add column if not exists tratamiento text;
alter table public.lesiones_atleta add column if not exists notas text;
alter table public.lesiones_atleta add column if not exists origen text;
alter table public.lesiones_atleta add column if not exists creado_por uuid;

-- valores por defecto para lo que ya existiera
update public.lesiones_atleta set disponibilidad = 'tocado' where disponibilidad is null;
update public.lesiones_atleta set origen = 'entrenador' where origen is null;

alter table public.lesiones_atleta alter column disponibilidad set default 'tocado';
alter table public.lesiones_atleta alter column origen set default 'entrenador';
alter table public.lesiones_atleta alter column atleta_id set not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'lesiones_atleta_tipo_check') then
    alter table public.lesiones_atleta add constraint lesiones_atleta_tipo_check
      check (tipo is null or tipo in ('muscular','articular','osea','tendinosa','sobrecarga','otra'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'lesiones_atleta_disponibilidad_check') then
    alter table public.lesiones_atleta add constraint lesiones_atleta_disponibilidad_check
      check (disponibilidad in ('disponible','tocado','baja'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'lesiones_atleta_origen_check') then
    alter table public.lesiones_atleta add constraint lesiones_atleta_origen_check
      check (origen in ('entrenador','atleta'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'lesiones_atleta_creado_por_fkey') then
    alter table public.lesiones_atleta add constraint lesiones_atleta_creado_por_fkey
      foreign key (creado_por) references public.perfiles(id);
  end if;
end $$;

create index if not exists idx_lesiones_atleta on public.lesiones_atleta (atleta_id);
create index if not exists idx_lesiones_abiertas on public.lesiones_atleta (atleta_id) where resuelta is not true;

comment on table  public.lesiones_atleta   is 'Historial de lesiones y molestias. Dato de salud: acceso restringido (atleta, familia, su entrenador y administración). No es un historial médico.';
comment on column public.lesiones_atleta.zona           is 'Zona del cuerpo (desplegable cerrado en la pantalla): isquiotibiales, gemelo, sóleo, aductores, cuádriceps, tobillo, rodilla, cadera, espalda, hombro, pie, tibia/periostio, otra.';
comment on column public.lesiones_atleta.tipo           is 'muscular / articular / osea / tendinosa / sobrecarga / otra';
comment on column public.lesiones_atleta.severidad      is 'leve / moderada / grave';
comment on column public.lesiones_atleta.disponibilidad is 'Cómo afecta al entrenamiento: disponible / tocado / baja';
comment on column public.lesiones_atleta.fecha_revision is 'Fecha prevista de vuelta.';
comment on column public.lesiones_atleta.fecha_alta     is 'Fecha real del alta (vuelta a entrenar sin restricción).';
comment on column public.lesiones_atleta.restriccion    is 'Qué puede y qué no puede hacer mientras dura.';
comment on column public.lesiones_atleta.origen         is 'entrenador = registrada por el equipo técnico; atleta = aviso de molestia del propio atleta.';

alter table public.lesiones_atleta enable row level security;

-- --- Reglas de acceso (estrictas) ---------------------------
-- Lectura: el propio atleta, su familia y su entrenador
-- (mis_atletas() cubre los tres) + administración (es_admin()).
drop policy if exists "ver datos de mis atletas" on public.lesiones_atleta;
drop policy if exists "lesiones lectura restringida" on public.lesiones_atleta;
create policy "lesiones lectura restringida" on public.lesiones_atleta
for select to authenticated
using (es_admin() or atleta_id in (select mis_atletas()));

-- Escritura del equipo técnico: solo el entrenador del atleta (o admin).
drop policy if exists "lesiones alta del equipo tecnico" on public.lesiones_atleta;
create policy "lesiones alta del equipo tecnico" on public.lesiones_atleta
for insert to authenticated
with check (soy_staff_de_atleta(atleta_id));

drop policy if exists "lesiones cambia el equipo tecnico" on public.lesiones_atleta;
create policy "lesiones cambia el equipo tecnico" on public.lesiones_atleta
for update to authenticated
using (soy_staff_de_atleta(atleta_id))
with check (soy_staff_de_atleta(atleta_id));

drop policy if exists "lesiones borra el equipo tecnico" on public.lesiones_atleta;
create policy "lesiones borra el equipo tecnico" on public.lesiones_atleta
for delete to authenticated
using (soy_staff_de_atleta(atleta_id));

-- El atleta (o su familia) puede AVISAR de una molestia, nada más:
-- crea la fila marcada como origen='atleta' y sin resolver.
-- No puede editar ni borrar el historial.
drop policy if exists "atleta avisa de una molestia" on public.lesiones_atleta;
create policy "atleta avisa de una molestia" on public.lesiones_atleta
for insert to authenticated
with check (
  atleta_id in (select mis_atletas())
  and origen = 'atleta'
  and coalesce(resuelta, false) = false
  and disponibilidad in ('disponible','tocado')
);


-- ============================================================
-- 2 · MENSAJES DIRECTOS
-- ------------------------------------------------------------
-- No confundir con:
--   `mensajes`       → buzón de contacto de la web pública
--   `notas_atleta`   → notas privadas del equipo técnico
--   `notas_familia`  → notas visibles para la familia
-- Esto es una conversación de ida y vuelta dentro del portal.
-- ============================================================

create table if not exists public.mensajes_directos (
  id          uuid primary key default gen_random_uuid(),
  de_perfil   uuid not null references public.perfiles(id) on delete cascade,
  para_perfil uuid not null references public.perfiles(id) on delete cascade,
  atleta_id   uuid references public.atletas(id) on delete set null,
  texto       text not null check (length(btrim(texto)) between 1 and 4000),
  leido       boolean not null default false,
  created_at  timestamptz not null default now(),
  constraint mensajes_directos_no_a_uno_mismo check (de_perfil <> para_perfil)
);

create index if not exists idx_md_para on public.mensajes_directos (para_perfil, leido);
create index if not exists idx_md_de on public.mensajes_directos (de_perfil);
create index if not exists idx_md_fecha on public.mensajes_directos (created_at desc);

comment on table public.mensajes_directos is 'Mensajería privada dentro del portal (entrenador <-> atleta o familia). Solo la ven los dos participantes. No envía correos ni avisos al móvil.';

-- ¿Puedo escribir a esta persona?
create or replace function public.puedo_hablar_con(p_otro uuid)
returns boolean
language sql stable security definer set search_path to 'public'
as $$
  select p_otro is not null
     and public.mi_perfil_id() is not null
     and p_otro <> public.mi_perfil_id()
     and (
       -- soy el entrenador de un atleta: hablo con él y con su familia
       exists (select 1 from public.atletas a
                where a.entrenador_id = public.mi_perfil_id()
                  and (a.perfil_id = p_otro or a.perfil_padre_id = p_otro))
       -- soy atleta o familia: hablo con el entrenador del atleta
    or exists (select 1 from public.atletas a
                where (a.perfil_id = public.mi_perfil_id() or a.perfil_padre_id = public.mi_perfil_id())
                  and a.entrenador_id = p_otro)
       -- administración habla con cualquiera, y cualquiera con administración
    or public.es_admin()
    or exists (select 1 from public.perfiles p where p.id = p_otro and p.rol = 'admin' and p.activo)
     );
$$;

alter table public.mensajes_directos enable row level security;

-- Cada uno ve SOLO las conversaciones en las que participa.
-- (Administración tampoco lee conversaciones ajenas.)
drop policy if exists "solo los dos que hablan" on public.mensajes_directos;
create policy "solo los dos que hablan" on public.mensajes_directos
for select to authenticated
using (de_perfil = mi_perfil_id() or para_perfil = mi_perfil_id());

-- Escribo yo, y solo a quien tengo permitido.
drop policy if exists "escribo yo a quien puedo" on public.mensajes_directos;
create policy "escribo yo a quien puedo" on public.mensajes_directos
for insert to authenticated
with check (de_perfil = mi_perfil_id() and puedo_hablar_con(para_perfil));

-- Puedo retirar un mensaje que he escrito yo.
drop policy if exists "retiro lo que he escrito" on public.mensajes_directos;
create policy "retiro lo que he escrito" on public.mensajes_directos
for delete to authenticated
using (de_perfil = mi_perfil_id());

-- No hay política de UPDATE a propósito: marcar como leído se hace
-- con la función marcar_leidos(), así nadie puede editar el texto.


-- --- Funciones de apoyo para la pantalla --------------------

-- Con quién puedo hablar (con el nombre, que los perfiles ajenos
-- no son legibles directamente).
create or replace function public.mis_contactos_mensajes()
returns table (
  perfil_id uuid, nombre text, apellidos text, rol text, relacion text,
  atleta_id uuid, atleta_nombre text, grupo_id uuid, grupo_nombre text
)
language sql stable security definer set search_path to 'public'
as $$
  with yo as (select public.mi_perfil_id() as id, public.es_admin() as admin)
  -- soy entrenador: mis atletas y sus familias
  select p.id, p.nombre, p.apellidos, p.rol,
         case when a.perfil_id = p.id then 'atleta' else 'familia' end,
         a.id, btrim(coalesce(a.nombre,'') || ' ' || coalesce(a.apellidos,'')),
         g.id, g.nombre
    from public.atletas a
    join public.perfiles p on (p.id = a.perfil_id or p.id = a.perfil_padre_id)
    left join public.grupos g on g.id = a.grupo_id
   where a.entrenador_id = (select id from yo)
     and p.activo and p.id <> (select id from yo)
  union
  -- soy atleta o familia: el entrenador de cada ficha
  select p.id, p.nombre, p.apellidos, p.rol, 'entrenador',
         a.id, btrim(coalesce(a.nombre,'') || ' ' || coalesce(a.apellidos,'')),
         g.id, g.nombre
    from public.atletas a
    join public.perfiles p on p.id = a.entrenador_id
    left join public.grupos g on g.id = a.grupo_id
   where (a.perfil_id = (select id from yo) or a.perfil_padre_id = (select id from yo))
     and p.activo and p.id <> (select id from yo)
  union
  -- administración del club
  select p.id, p.nombre, p.apellidos, p.rol, 'administración',
         null::uuid, null::text, null::uuid, null::text
    from public.perfiles p
   where p.rol = 'admin' and p.activo
     and p.id <> (select id from yo)
     and (select id from yo) is not null
     and not (select admin from yo)
  union
  -- si soy administración, con todo el club
  select p.id, p.nombre, p.apellidos, p.rol, 'club',
         null::uuid, null::text, null::uuid, null::text
    from public.perfiles p
   where (select admin from yo) and p.activo and p.id <> (select id from yo);
$$;

-- Mis conversaciones, con el último mensaje y los no leídos.
create or replace function public.mis_conversaciones()
returns table (
  otro uuid, nombre text, apellidos text, rol text,
  ultimo_texto text, ultimo_at timestamptz, ultimo_mio boolean,
  no_leidos integer, total integer
)
language sql stable security definer set search_path to 'public'
as $$
  with yo as (select public.mi_perfil_id() as id),
  m as (
    select case when d.de_perfil = (select id from yo) then d.para_perfil else d.de_perfil end as otro,
           d.texto, d.created_at, d.de_perfil, d.para_perfil, d.leido
      from public.mensajes_directos d
     where (select id from yo) is not null
       and (d.de_perfil = (select id from yo) or d.para_perfil = (select id from yo))
  ),
  agg as (
    select m.otro,
           count(*)::int as total,
           count(*) filter (where m.para_perfil = (select id from yo) and not m.leido)::int as no_leidos,
           max(m.created_at) as ultimo_at
      from m group by m.otro
  )
  select agg.otro, p.nombre, p.apellidos, p.rol,
         u.texto, agg.ultimo_at, (u.de_perfil = (select id from yo)),
         agg.no_leidos, agg.total
    from agg
    join public.perfiles p on p.id = agg.otro
    join lateral (
      select m2.texto, m2.de_perfil from m m2
       where m2.otro = agg.otro order by m2.created_at desc limit 1
    ) u on true
   order by agg.ultimo_at desc;
$$;

-- Marcar como leídos los mensajes que me ha escrito alguien.
create or replace function public.marcar_leidos(p_otro uuid)
returns integer
language plpgsql volatile security definer set search_path to 'public'
as $$
declare n integer;
begin
  update public.mensajes_directos
     set leido = true
   where para_perfil = public.mi_perfil_id()
     and de_perfil = p_otro
     and leido is not true;
  get diagnostics n = row_count;
  return n;
end;
$$;

grant execute on function public.puedo_hablar_con(uuid) to authenticated;
grant execute on function public.mis_contactos_mensajes() to authenticated;
grant execute on function public.mis_conversaciones() to authenticated;
grant execute on function public.marcar_leidos(uuid) to authenticated;
