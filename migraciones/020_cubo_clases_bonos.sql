-- ============================================================
-- 020 · EL CUBO · CLASES DIRIGIDAS Y BONOS POR USOS
-- ------------------------------------------------------------
-- Qué resuelve (maqueta "Clases abiertas y bono de El Cubo", 11a):
--   1) El club publica las clases de El Cubo (fecha, hora, monitor,
--      plazas). Doce plazas por clase, 55 minutos.
--   2) El socio ve las clases abiertas, se apunta o se desapunta.
--      Si la clase está llena entra en LISTA DE ESPERA.
--   3) Los bonos van por USOS (10 o 20), no por euros: apuntarse
--      gasta un uso y cancelar con más de 3 horas lo devuelve.
--
-- POR QUÉ NO SE REUTILIZA "bono_movimientos":
--   Ese bono (migración 012) es el bono ANUAL de competiciones y va
--   en EUROS (importe numeric, saldo = suma de importes). El de El
--   Cubo va en USOS enteros, caduca, se compra por paquetes y va
--   atado a una clase concreta. Mezclarlos obligaría a que un mismo
--   saldo signifique dos cosas distintas, así que son tablas aparte.
--   Sí se reutilizan: atletas, perfiles y los ayudantes de seguridad
--   es_admin(), mi_perfil_id() y mis_atletas().
--
-- CONTROL DE PLAZAS: lo decide la BASE DE DATOS, no el navegador.
--   Un disparador (trigger) bloquea la clase con un cerrojo, cuenta
--   las reservas vivas y decide si la fila entra como 'reservada' o
--   como 'lista_espera'. Dé igual quién y desde dónde inserte: si
--   hay 12 plazas y 12 reservas, la siguiente entra en espera.
-- ============================================================

-- ------------------------------------------------------------
-- 1) CLASES
-- ------------------------------------------------------------
create table if not exists public.cubo_clases (
  id            uuid primary key default gen_random_uuid(),
  fecha         date not null,
  hora_inicio   time not null,
  hora_fin      time,
  titulo        text not null,
  monitor_id    uuid references public.perfiles(id),
  monitor_nombre text,                       -- por si el monitor no tiene cuenta
  plazas        integer not null default 12 check (plazas > 0),
  notas         text,
  activa        boolean not null default true,
  creado_por    uuid references public.perfiles(id),
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

create index if not exists idx_cubo_clases_fecha on public.cubo_clases (fecha, hora_inicio);

comment on table public.cubo_clases is 'Clases dirigidas de El Cubo. plazas = aforo (12 por defecto).';
comment on column public.cubo_clases.monitor_nombre is 'Nombre del monitor cuando no tiene perfil en la app.';

-- ------------------------------------------------------------
-- 2) BONOS POR USOS
-- ------------------------------------------------------------
create table if not exists public.cubo_bonos (
  id            uuid primary key default gen_random_uuid(),
  atleta_id     uuid not null references public.atletas(id) on delete cascade,
  usos_totales  integer not null check (usos_totales > 0),
  precio        numeric(8,2),
  fecha_compra  date not null default current_date,
  caducidad     date,
  activo        boolean not null default true,
  notas         text,
  creado_por    uuid references public.perfiles(id),
  created_at    timestamptz default now()
);

create index if not exists idx_cubo_bonos_atleta on public.cubo_bonos (atleta_id);

comment on table public.cubo_bonos is 'Bonos de El Cubo por USOS (10 o 20). El saldo sale de cubo_movimientos.';

-- ------------------------------------------------------------
-- 3) RESERVAS
-- ------------------------------------------------------------
create table if not exists public.cubo_reservas (
  id            uuid primary key default gen_random_uuid(),
  clase_id      uuid not null references public.cubo_clases(id) on delete cascade,
  atleta_id     uuid not null references public.atletas(id) on delete cascade,
  estado        text not null default 'reservada',
  created_at    timestamptz default now(),
  updated_at    timestamptz default now(),
  constraint cubo_reservas_unica unique (clase_id, atleta_id)
);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'cubo_reservas_estado_check') then
    alter table public.cubo_reservas
      add constraint cubo_reservas_estado_check
      check (estado in ('reservada','lista_espera','cancelada','asistida','no_asistida'));
  end if;
end $$;

create index if not exists idx_cubo_reservas_clase on public.cubo_reservas (clase_id, estado);
create index if not exists idx_cubo_reservas_atleta on public.cubo_reservas (atleta_id);

comment on table public.cubo_reservas is 'Una fila por clase + atleta. Estados: reservada / lista_espera / cancelada / asistida / no_asistida.';

-- ------------------------------------------------------------
-- 4) MOVIMIENTOS DEL BONO (usos, no euros)
--    usos > 0 = alta o devolución · usos < 0 = consumo
-- ------------------------------------------------------------
create table if not exists public.cubo_movimientos (
  id          uuid primary key default gen_random_uuid(),
  bono_id     uuid not null references public.cubo_bonos(id) on delete cascade,
  atleta_id   uuid not null references public.atletas(id) on delete cascade,
  tipo        text not null check (tipo in ('alta','consumo','devolucion','ajuste')),
  usos        integer not null check (usos <> 0),
  concepto    text not null,
  clase_id    uuid references public.cubo_clases(id) on delete set null,
  reserva_id  uuid references public.cubo_reservas(id) on delete set null,
  fecha       timestamptz not null default now(),
  creado_por  uuid references public.perfiles(id),
  created_at  timestamptz default now()
);

create index if not exists idx_cubo_mov_bono on public.cubo_movimientos (bono_id);
create index if not exists idx_cubo_mov_atleta on public.cubo_movimientos (atleta_id, fecha desc);

-- Un consumo y una devolución como mucho por reserva (evita duplicados)
create unique index if not exists cubo_mov_consumo_unico
  on public.cubo_movimientos (reserva_id) where tipo = 'consumo' and reserva_id is not null;
create unique index if not exists cubo_mov_devolucion_unica
  on public.cubo_movimientos (reserva_id) where tipo = 'devolucion' and reserva_id is not null;

comment on table public.cubo_movimientos is 'Movimientos de USOS del bono de El Cubo: alta (+N), consumo (-1), devolución (+1), ajuste.';

-- ------------------------------------------------------------
-- 5) AYUDANTES
-- ------------------------------------------------------------

-- ¿Puedo gestionar El Cubo? (admin, coordinador o entrenador)
create or replace function public.cubo_es_gestor()
returns boolean
language sql stable security definer set search_path to 'public'
as $function$
  select public.es_admin() or exists (
    select 1 from public.perfiles p
    where p.email = (auth.jwt() ->> 'email')
      and p.rol in ('admin','coordinador','entrenador')
  );
$function$;

-- Usos que le quedan a un atleta (bonos activos y sin caducar)
create or replace function public.cubo_usos_disponibles(p_atleta uuid)
returns integer
language sql stable security definer set search_path to 'public'
as $function$
  select coalesce(sum(m.usos), 0)::int
  from public.cubo_movimientos m
  join public.cubo_bonos b on b.id = m.bono_id
  where m.atleta_id = p_atleta
    and b.activo
    and (b.caducidad is null or b.caducidad >= current_date);
$function$;

-- Bono del que hay que descontar: el que caduca antes y todavía tiene usos
create or replace function public.cubo_bono_a_usar(p_atleta uuid)
returns uuid
language sql stable security definer set search_path to 'public'
as $function$
  select b.id
  from public.cubo_bonos b
  where b.atleta_id = p_atleta
    and b.activo
    and (b.caducidad is null or b.caducidad >= current_date)
    and coalesce((select sum(m.usos) from public.cubo_movimientos m where m.bono_id = b.id), 0) > 0
  order by b.caducidad asc nulls last, b.fecha_compra asc
  limit 1;
$function$;

-- Plazas libres de una clase (cuenta TODAS las reservas, no solo las mías)
create or replace function public.cubo_plazas_libres(p_clase uuid)
returns integer
language sql stable security definer set search_path to 'public'
as $function$
  select greatest(0, c.plazas - (
    select count(*) from public.cubo_reservas r
    where r.clase_id = c.id and r.estado in ('reservada','asistida','no_asistida')
  ))::int
  from public.cubo_clases c where c.id = p_clase;
$function$;

grant execute on function public.cubo_es_gestor() to authenticated;
grant execute on function public.cubo_usos_disponibles(uuid) to authenticated;
grant execute on function public.cubo_bono_a_usar(uuid) to authenticated;
grant execute on function public.cubo_plazas_libres(uuid) to authenticated;

-- ------------------------------------------------------------
-- 6) CONSUMIR Y DEVOLVER USOS
-- ------------------------------------------------------------

-- Descuenta un uso por una reserva. Si no hay bono con usos:
--   p_obligatorio = true  -> da error (el atleta no puede apuntarse)
--   p_obligatorio = false -> no hace nada (el club pasa lista igual)
create or replace function public.cubo_consumir_uso(p_reserva uuid, p_obligatorio boolean default true)
returns void
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_res    public.cubo_reservas;
  v_clase  public.cubo_clases;
  v_bono   uuid;
begin
  select * into v_res from public.cubo_reservas where id = p_reserva;
  if not found then return; end if;

  -- ¿ya se descontó por esta reserva?
  if exists (select 1 from public.cubo_movimientos
             where reserva_id = p_reserva and tipo = 'consumo') then
    return;
  end if;

  select * into v_clase from public.cubo_clases where id = v_res.clase_id;
  v_bono := public.cubo_bono_a_usar(v_res.atleta_id);

  if v_bono is null then
    if p_obligatorio then
      raise exception 'No te quedan usos en el bono de El Cubo.'
        using errcode = 'P0001';
    end if;
    return;
  end if;

  insert into public.cubo_movimientos (bono_id, atleta_id, tipo, usos, concepto, clase_id, reserva_id, fecha)
  values (v_bono, v_res.atleta_id, 'consumo', -1,
          coalesce(v_clase.titulo, 'Clase de El Cubo'),
          v_res.clase_id, p_reserva,
          coalesce(v_clase.fecha + v_clase.hora_inicio, now()));
end;
$function$;

-- Devuelve el uso de una reserva (solo si antes se descontó)
create or replace function public.cubo_devolver_uso(p_reserva uuid, p_concepto text default 'Cancelada a tiempo')
returns void
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_cons public.cubo_movimientos;
begin
  select * into v_cons from public.cubo_movimientos
   where reserva_id = p_reserva and tipo = 'consumo';
  if not found then return; end if;

  if exists (select 1 from public.cubo_movimientos
             where reserva_id = p_reserva and tipo = 'devolucion') then
    return;
  end if;

  insert into public.cubo_movimientos (bono_id, atleta_id, tipo, usos, concepto, clase_id, reserva_id, fecha)
  values (v_cons.bono_id, v_cons.atleta_id, 'devolucion', 1, p_concepto,
          v_cons.clase_id, p_reserva, now());
end;
$function$;

-- ------------------------------------------------------------
-- 7) DISPARADORES · aquí vive el control de plazas
-- ------------------------------------------------------------

-- 7.1 Antes de guardar: cerrojo por clase, contar y decidir el estado.
create or replace function public.cubo_reservas_control()
returns trigger
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_clase   public.cubo_clases;
  v_ocupadas integer;
begin
  if TG_OP = 'INSERT' or NEW.estado is distinct from OLD.estado then
    if NEW.estado in ('reservada','lista_espera') then

      -- Cerrojo por clase: dos personas a la vez no pueden coger la misma plaza.
      perform pg_advisory_xact_lock(hashtextextended(NEW.clase_id::text, 0));

      select * into v_clase from public.cubo_clases where id = NEW.clase_id;
      if not found then
        raise exception 'Esa clase de El Cubo no existe.' using errcode = 'P0001';
      end if;
      if not v_clase.activa then
        raise exception 'Esa clase de El Cubo no está abierta.' using errcode = 'P0001';
      end if;

      select count(*) into v_ocupadas
      from public.cubo_reservas r
      where r.clase_id = NEW.clase_id
        and r.estado in ('reservada','asistida','no_asistida')
        and r.id <> NEW.id;

      if v_ocupadas >= v_clase.plazas then
        NEW.estado := 'lista_espera';
      else
        NEW.estado := 'reservada';
      end if;
    end if;
  end if;

  NEW.updated_at := now();
  return NEW;
end;
$function$;

drop trigger if exists trg_cubo_reservas_control on public.cubo_reservas;
create trigger trg_cubo_reservas_control
  before insert or update on public.cubo_reservas
  for each row execute function public.cubo_reservas_control();

-- 7.2 Después de guardar: mover el bono (gastar o devolver el uso).
create or replace function public.cubo_reservas_bono()
returns trigger
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_clase public.cubo_clases;
  v_inicio timestamptz;
begin
  select * into v_clase from public.cubo_clases where id = NEW.clase_id;
  v_inicio := (v_clase.fecha + v_clase.hora_inicio);

  if TG_OP = 'INSERT' then
    if NEW.estado = 'reservada' then
      perform public.cubo_consumir_uso(NEW.id, true);
    end if;
    return NEW;
  end if;

  -- De la lista de espera a plaza confirmada: se gasta el uso
  if NEW.estado = 'reservada' and OLD.estado is distinct from 'reservada' then
    perform public.cubo_consumir_uso(NEW.id, true);
  end if;

  -- Pasar lista: si por lo que sea no se había descontado, se descuenta ahora
  if NEW.estado = 'asistida' and OLD.estado is distinct from 'asistida' then
    perform public.cubo_consumir_uso(NEW.id, false);
  end if;

  -- Se borra de la clase: se devuelve el uso si cancela con más de 3 horas
  if NEW.estado = 'cancelada' and OLD.estado in ('reservada','asistida') then
    if v_inicio is null or now() < (v_inicio - interval '3 hours') then
      perform public.cubo_devolver_uso(NEW.id, 'Cancelada a tiempo');
    end if;
  end if;

  return NEW;
end;
$function$;

drop trigger if exists trg_cubo_reservas_bono on public.cubo_reservas;
create trigger trg_cubo_reservas_bono
  after insert or update on public.cubo_reservas
  for each row execute function public.cubo_reservas_bono();

-- 7.3 Al quedar una plaza libre, entra el primero de la lista de espera.
create or replace function public.cubo_reservas_promocion()
returns trigger
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_clase  uuid;
  v_libre  boolean := false;
  v_inicio timestamptz;
  v_sig    uuid;
begin
  -- si ya venimos de otro disparador, no encadenar más
  if pg_trigger_depth() > 1 then return null; end if;

  if TG_OP = 'DELETE' then
    v_clase := OLD.clase_id;
    v_libre := OLD.estado in ('reservada','asistida','no_asistida');
  else
    v_clase := NEW.clase_id;
    v_libre := OLD.estado in ('reservada','asistida','no_asistida')
           and NEW.estado not in ('reservada','asistida','no_asistida');
  end if;

  if not v_libre then return null; end if;

  -- una clase que ya ha empezado no reparte plazas
  select (c.fecha + c.hora_inicio) into v_inicio from public.cubo_clases c where c.id = v_clase;
  if v_inicio is null or v_inicio <= now() then return null; end if;

  if public.cubo_plazas_libres(v_clase) <= 0 then return null; end if;

  select r.id into v_sig
  from public.cubo_reservas r
  where r.clase_id = v_clase
    and r.estado = 'lista_espera'
    and public.cubo_usos_disponibles(r.atleta_id) > 0
  order by r.created_at asc
  limit 1;

  if v_sig is not null then
    update public.cubo_reservas set estado = 'reservada' where id = v_sig;
  end if;

  return null;
end;
$function$;

drop trigger if exists trg_cubo_reservas_promocion on public.cubo_reservas;
create trigger trg_cubo_reservas_promocion
  after update or delete on public.cubo_reservas
  for each row execute function public.cubo_reservas_promocion();

-- 7.4 Al dar de alta un bono, su movimiento de alta (+N usos)
create or replace function public.cubo_bonos_alta()
returns trigger
language plpgsql security definer set search_path to 'public'
as $function$
begin
  insert into public.cubo_movimientos (bono_id, atleta_id, tipo, usos, concepto, fecha, creado_por)
  values (NEW.id, NEW.atleta_id, 'alta', NEW.usos_totales,
          'Bono de ' || NEW.usos_totales || ' usos',
          coalesce(NEW.fecha_compra::timestamptz, now()), NEW.creado_por);
  return null;
end;
$function$;

drop trigger if exists trg_cubo_bonos_alta on public.cubo_bonos;
create trigger trg_cubo_bonos_alta
  after insert on public.cubo_bonos
  for each row execute function public.cubo_bonos_alta();

-- ------------------------------------------------------------
-- 8) LO QUE LLAMA LA APP (apuntarse / desapuntarse)
--    Devuelven el estado resultante: 'reservada' o 'lista_espera'.
-- ------------------------------------------------------------
create or replace function public.cubo_apuntarme(p_clase uuid, p_atleta uuid)
returns text
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_clase  public.cubo_clases;
  v_estado text;
  v_id     uuid;
begin
  if not (p_atleta in (select public.mis_atletas()) or public.cubo_es_gestor()) then
    raise exception 'No puedes apuntar a ese atleta.' using errcode = 'P0001';
  end if;

  select * into v_clase from public.cubo_clases where id = p_clase;
  if not found or not v_clase.activa then
    raise exception 'Esa clase de El Cubo no está abierta.' using errcode = 'P0001';
  end if;
  if (v_clase.fecha + v_clase.hora_inicio) < now() then
    raise exception 'Esa clase ya ha empezado.' using errcode = 'P0001';
  end if;

  select id, estado into v_id, v_estado
  from public.cubo_reservas where clase_id = p_clase and atleta_id = p_atleta;

  if v_id is null then
    insert into public.cubo_reservas (clase_id, atleta_id, estado)
    values (p_clase, p_atleta, 'reservada')
    returning id, estado into v_id, v_estado;
  elsif v_estado in ('reservada','lista_espera') then
    return v_estado;                       -- ya estaba apuntado
  else
    update public.cubo_reservas set estado = 'reservada'
     where id = v_id returning estado into v_estado;
  end if;

  return v_estado;
end;
$function$;

create or replace function public.cubo_desapuntarme(p_clase uuid, p_atleta uuid)
returns text
language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_id uuid;
begin
  if not (p_atleta in (select public.mis_atletas()) or public.cubo_es_gestor()) then
    raise exception 'No puedes desapuntar a ese atleta.' using errcode = 'P0001';
  end if;

  select id into v_id from public.cubo_reservas
   where clase_id = p_clase and atleta_id = p_atleta
     and estado in ('reservada','lista_espera');
  if v_id is null then return 'cancelada'; end if;

  update public.cubo_reservas set estado = 'cancelada' where id = v_id;
  return 'cancelada';
end;
$function$;

grant execute on function public.cubo_apuntarme(uuid, uuid) to authenticated;
grant execute on function public.cubo_desapuntarme(uuid, uuid) to authenticated;

-- ------------------------------------------------------------
-- 9) VISTAS
-- ------------------------------------------------------------

-- 9.1 Las clases con su monitor y su ocupación. A propósito NO lleva
--     security_invoker: así cualquier socio ve "8 de 12 plazas" y el
--     nombre del monitor SIN ver quién está apuntado y sin necesitar
--     permiso de lectura sobre la tabla de perfiles.
drop view if exists public.cubo_clases_ocupacion cascade;
create view public.cubo_clases_ocupacion as
  select c.id as clase_id,
         c.fecha,
         c.hora_inicio,
         c.hora_fin,
         c.titulo,
         c.notas,
         c.activa,
         c.plazas,
         coalesce(nullif(trim(p.nombre || ' ' || coalesce(p.apellidos,'')), ''), c.monitor_nombre) as monitor,
         count(*) filter (where r.estado in ('reservada','asistida','no_asistida'))::int as ocupadas,
         count(*) filter (where r.estado = 'lista_espera')::int                          as en_espera,
         greatest(0, c.plazas - count(*) filter (where r.estado in ('reservada','asistida','no_asistida')))::int as libres
  from public.cubo_clases c
  left join public.perfiles p on p.id = c.monitor_id
  left join public.cubo_reservas r on r.clase_id = c.id
  group by c.id, p.nombre, p.apellidos;

grant select on public.cubo_clases_ocupacion to authenticated, anon;

-- 9.2 Saldo de cada bono (respeta RLS: cada uno ve el suyo)
create or replace view public.cubo_bono_saldo as
  select b.id as bono_id,
         b.atleta_id,
         b.usos_totales,
         b.precio,
         b.fecha_compra,
         b.caducidad,
         b.activo,
         coalesce(sum(m.usos) filter (where m.usos < 0), 0)::int * -1 as usos_gastados,
         coalesce(sum(m.usos), 0)::int                               as usos_disponibles,
         (b.caducidad is not null and b.caducidad < current_date)     as caducado
  from public.cubo_bonos b
  left join public.cubo_movimientos m on m.bono_id = b.id
  group by b.id;

alter view public.cubo_bono_saldo set (security_invoker = on);
grant select on public.cubo_bono_saldo to authenticated;

-- ------------------------------------------------------------
-- 10) REGLAS DE SEGURIDAD (RLS)
-- ------------------------------------------------------------

-- 10.1 Clases: las ve cualquiera que haya entrado; las gestiona el club
alter table public.cubo_clases enable row level security;

drop policy if exists "ver clases del cubo" on public.cubo_clases;
create policy "ver clases del cubo" on public.cubo_clases
  for select to authenticated using (true);

drop policy if exists "gestor gestiona clases" on public.cubo_clases;
create policy "gestor gestiona clases" on public.cubo_clases
  for all to authenticated
  using (public.cubo_es_gestor()) with check (public.cubo_es_gestor());

-- 10.2 Bonos: el atleta VE el suyo y nada más; solo el club los crea/edita
alter table public.cubo_bonos enable row level security;

drop policy if exists "ver mi bono del cubo" on public.cubo_bonos;
create policy "ver mi bono del cubo" on public.cubo_bonos
  for select to authenticated
  using (atleta_id in (select public.mis_atletas()) or public.cubo_es_gestor());

drop policy if exists "gestor gestiona bonos del cubo" on public.cubo_bonos;
create policy "gestor gestiona bonos del cubo" on public.cubo_bonos
  for all to authenticated
  using (public.cubo_es_gestor()) with check (public.cubo_es_gestor());

-- 10.3 Reservas: cada uno las suyas; el club, todas
alter table public.cubo_reservas enable row level security;

drop policy if exists "ver mis reservas del cubo" on public.cubo_reservas;
create policy "ver mis reservas del cubo" on public.cubo_reservas
  for select to authenticated
  using (atleta_id in (select public.mis_atletas()) or public.cubo_es_gestor());

drop policy if exists "apuntarme al cubo" on public.cubo_reservas;
create policy "apuntarme al cubo" on public.cubo_reservas
  for insert to authenticated
  with check (atleta_id in (select public.mis_atletas())
              and estado in ('reservada','lista_espera'));

drop policy if exists "cambiar mi reserva del cubo" on public.cubo_reservas;
create policy "cambiar mi reserva del cubo" on public.cubo_reservas
  for update to authenticated
  using (atleta_id in (select public.mis_atletas())
         and estado in ('reservada','lista_espera'))
  with check (atleta_id in (select public.mis_atletas())
              and estado in ('reservada','lista_espera','cancelada'));

drop policy if exists "borrar mi reserva del cubo" on public.cubo_reservas;
create policy "borrar mi reserva del cubo" on public.cubo_reservas
  for delete to authenticated
  using (atleta_id in (select public.mis_atletas())
         and estado in ('reservada','lista_espera'));

drop policy if exists "gestor gestiona reservas del cubo" on public.cubo_reservas;
create policy "gestor gestiona reservas del cubo" on public.cubo_reservas
  for all to authenticated
  using (public.cubo_es_gestor()) with check (public.cubo_es_gestor());

-- 10.4 Movimientos: el atleta solo LEE los suyos. Escribir, solo el club
--      (o los disparadores, que van con permisos propios).
alter table public.cubo_movimientos enable row level security;

drop policy if exists "ver mis movimientos del cubo" on public.cubo_movimientos;
create policy "ver mis movimientos del cubo" on public.cubo_movimientos
  for select to authenticated
  using (atleta_id in (select public.mis_atletas()) or public.cubo_es_gestor());

drop policy if exists "gestor mueve el bono del cubo" on public.cubo_movimientos;
create policy "gestor mueve el bono del cubo" on public.cubo_movimientos
  for all to authenticated
  using (public.cubo_es_gestor()) with check (public.cubo_es_gestor());

-- ------------------------------------------------------------
-- 11) PERMISOS DE TABLA
-- ------------------------------------------------------------
grant select, insert, update, delete on public.cubo_clases      to authenticated;
grant select, insert, update, delete on public.cubo_bonos       to authenticated;
grant select, insert, update, delete on public.cubo_reservas    to authenticated;
grant select, insert, update, delete on public.cubo_movimientos to authenticated;
grant select on public.cubo_clases to anon;
