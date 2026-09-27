-- 244_natacion_reservas_abono.sql
-- Reservas/abono de natación (encargo de Mario): los FIJOS tienen su plaza por
-- defecto; si un fijo se da de baja un día (natacion_ausencias), su plaza queda
-- libre; quien tenga «clases de abono pendientes» puede reservar una franja si
-- hay hueco (descuenta 1 clase). Tablas nuevas, no toca lo existente.

create table if not exists public.natacion_abonos (
  id uuid primary key default gen_random_uuid(),
  acceso_id uuid unique references public.natacion_accesos(id) on delete cascade,
  nombre text,
  saldo integer not null default 0,     -- clases de abono pendientes
  notas text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.natacion_reservas (
  id uuid primary key default gen_random_uuid(),
  franja_id uuid not null references public.natacion_franjas(id) on delete cascade,
  fecha date not null,
  acceso_id uuid references public.natacion_accesos(id) on delete set null,
  nombre text,
  calle text,
  estado text not null default 'reservada',   -- reservada | cancelada
  creada_en timestamptz default now(),
  creada_por uuid
);
create index if not exists natacion_reservas_franja_fecha on public.natacion_reservas(franja_id, fecha);

alter table public.natacion_abonos   enable row level security;
alter table public.natacion_reservas enable row level security;

drop policy if exists "abonos los lleva natacion" on public.natacion_abonos;
create policy "abonos los lleva natacion" on public.natacion_abonos for all to authenticated
  using (public.es_admin() or public.es_staff() or public.soy_responsable('natacion'))
  with check (public.es_admin() or public.es_staff() or public.soy_responsable('natacion'));

drop policy if exists "reservas las lleva natacion" on public.natacion_reservas;
create policy "reservas las lleva natacion" on public.natacion_reservas for all to authenticated
  using (public.es_admin() or public.es_staff() or public.soy_responsable('natacion'))
  with check (public.es_admin() or public.es_staff() or public.soy_responsable('natacion'));

-- Huecos por franja para una fecha: cupo − (fijos − bajas ese día) − reservas.
-- cupo = suma de cupos por calle si está puesto; si no, calles × 8 (por defecto).
create or replace function public.natacion_huecos(p_fecha date)
returns table(franja_id uuid, dia smallint, hora time, grupo text, cupo int, fijos int, bajas int, reservas int, huecos int)
language sql stable security definer set search_path = public as $$
  select f.id, f.dia, f.hora, f.grupo,
    coalesce(nullif((select sum((v)::int) from jsonb_each_text(f.cupos) e(k,v)),0), coalesce(f.calles,3)*8) as cupo,
    (select count(*) from natacion_inscripciones i where i.franja_id=f.id and i.activa)::int as fijos,
    (select count(*) from natacion_ausencias a where a.franja_id=f.id and a.fecha=p_fecha)::int as bajas,
    (select count(*) from natacion_reservas r where r.franja_id=f.id and r.fecha=p_fecha and r.estado='reservada')::int as reservas,
    (coalesce(nullif((select sum((v)::int) from jsonb_each_text(f.cupos) e(k,v)),0), coalesce(f.calles,3)*8)
      - ((select count(*) from natacion_inscripciones i where i.franja_id=f.id and i.activa)
         - (select count(*) from natacion_ausencias a where a.franja_id=f.id and a.fecha=p_fecha))
      - (select count(*) from natacion_reservas r where r.franja_id=f.id and r.fecha=p_fecha and r.estado='reservada'))::int as huecos
  from natacion_franjas f
  where (public.es_admin() or public.es_staff() or public.soy_responsable('natacion'))
    and coalesce(f.activa,true) and f.dia = extract(isodow from p_fecha)::smallint
  order by f.hora;
$$;

-- Reservar una franja para una persona con abono (descuenta 1 clase).
create or replace function public.natacion_reservar(p_franja uuid, p_fecha date, p_acceso_id uuid, p_calle text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_saldo int; v_huecos int; v_nombre text;
begin
  if not (public.es_admin() or public.es_staff() or public.soy_responsable('natacion')) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.'); end if;
  select saldo, nombre into v_saldo, v_nombre from natacion_abonos where acceso_id = p_acceso_id;
  if v_saldo is null then return jsonb_build_object('ok', false, 'msg', 'Esa persona no tiene abono. Dale clases primero.'); end if;
  if v_saldo <= 0 then return jsonb_build_object('ok', false, 'msg', 'No le quedan clases de abono.'); end if;
  select huecos into v_huecos from public.natacion_huecos(p_fecha) where franja_id = p_franja;
  if v_huecos is null then return jsonb_build_object('ok', false, 'msg', 'Esa franja no existe ese día.'); end if;
  if v_huecos <= 0 then return jsonb_build_object('ok', false, 'msg', 'No hay hueco en esa franja ese día.'); end if;
  insert into natacion_reservas(franja_id, fecha, acceso_id, nombre, calle, creada_por)
    values (p_franja, p_fecha, p_acceso_id, coalesce(v_nombre, (select nombre from natacion_accesos where id = p_acceso_id)), p_calle, public.mi_perfil_id());
  update natacion_abonos set saldo = saldo - 1, updated_at = now() where acceso_id = p_acceso_id;
  return jsonb_build_object('ok', true, 'msg', 'Reserva hecha. Le queda(n) ' || (v_saldo - 1) || ' clase(s).');
end $$;

-- Cancelar una reserva (devuelve la clase al abono).
create or replace function public.natacion_cancelar_reserva(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_acc uuid; v_est text;
begin
  if not (public.es_admin() or public.es_staff() or public.soy_responsable('natacion')) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.'); end if;
  select acceso_id, estado into v_acc, v_est from natacion_reservas where id = p_id;
  if v_est is null then return jsonb_build_object('ok', false, 'msg', 'No existe.'); end if;
  if v_est <> 'reservada' then return jsonb_build_object('ok', false, 'msg', 'Ya no está activa.'); end if;
  update natacion_reservas set estado = 'cancelada' where id = p_id;
  if v_acc is not null then update natacion_abonos set saldo = saldo + 1, updated_at = now() where acceso_id = v_acc; end if;
  return jsonb_build_object('ok', true, 'msg', 'Reserva cancelada y clase devuelta.');
end $$;

-- Poner/ajustar el saldo de abono de una persona.
create or replace function public.natacion_abono_set(p_acceso_id uuid, p_saldo int, p_nombre text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not (public.es_admin() or public.es_staff() or public.soy_responsable('natacion')) then
    return jsonb_build_object('ok', false, 'msg', 'Sin permiso.'); end if;
  insert into natacion_abonos(acceso_id, nombre, saldo)
    values (p_acceso_id, p_nombre, greatest(coalesce(p_saldo,0),0))
    on conflict (acceso_id) do update set saldo = greatest(coalesce(excluded.saldo,0),0),
      nombre = coalesce(excluded.nombre, natacion_abonos.nombre), updated_at = now();
  return jsonb_build_object('ok', true, 'msg', 'Abono actualizado.');
end $$;

-- El front (rol authenticated) necesita el GRANT de tabla para leer; la RLS de
-- arriba filtra las filas (solo admin/staff/responsable de natación). Las
-- escrituras van por las funciones SECURITY DEFINER de abajo.
grant select on public.natacion_abonos   to authenticated;
grant select on public.natacion_reservas to authenticated;

grant execute on function public.natacion_huecos(date)            to authenticated, service_role;
grant execute on function public.natacion_reservar(uuid,date,uuid,text) to authenticated, service_role;
grant execute on function public.natacion_cancelar_reserva(uuid)  to authenticated, service_role;
grant execute on function public.natacion_abono_set(uuid,int,text) to authenticated, service_role;
