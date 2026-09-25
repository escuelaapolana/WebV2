-- 225 · Acceso de familias por CÓDIGO + baja puntual por día (natación)
--
-- Cada nadador/a tiene un CÓDIGO (llave tipo magic-link). Con él, la familia
-- ve su plaza y avisa de que un día no vendrá — sin cuenta y sin exponer datos
-- de nadie más. Las tablas base siguen privadas (RLS); el acceso de la familia
-- es SOLO a través de funciones `security definer` que acotan todo al código.

-- ---------------------------------------------------------------------------
-- Un acceso (código) por nadador/a
-- ---------------------------------------------------------------------------
create table if not exists public.natacion_accesos (
  id         uuid primary key default gen_random_uuid(),
  codigo     text unique not null,
  nombre     text not null,
  atleta_id  uuid references public.atletas(id) on delete set null,
  activo     boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.natacion_inscripciones
  add column if not exists acceso_id uuid references public.natacion_accesos(id) on delete set null;
create index if not exists natacion_inscripciones_acceso on public.natacion_inscripciones(acceso_id);

-- ---------------------------------------------------------------------------
-- Bajas puntuales (un día que no viene)
-- ---------------------------------------------------------------------------
create table if not exists public.natacion_ausencias (
  id         uuid primary key default gen_random_uuid(),
  acceso_id  uuid not null references public.natacion_accesos(id) on delete cascade,
  franja_id  uuid references public.natacion_franjas(id) on delete cascade,
  fecha      date not null,
  origen     text not null default 'familia',
  created_at timestamptz not null default now(),
  unique (acceso_id, franja_id, fecha)
);
create index if not exists natacion_ausencias_fecha on public.natacion_ausencias(fecha);

-- ---------------------------------------------------------------------------
-- RLS · las tablas son privadas (staff/responsable). La familia entra por función.
-- ---------------------------------------------------------------------------
alter table public.natacion_accesos   enable row level security;
alter table public.natacion_ausencias enable row level security;

drop policy if exists "natacion accesos staff" on public.natacion_accesos;
create policy "natacion accesos staff" on public.natacion_accesos for all to authenticated
  using      (public.es_admin() or public.es_staff() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))
  with check (public.es_admin() or public.es_staff() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'));

drop policy if exists "natacion ausencias staff" on public.natacion_ausencias;
create policy "natacion ausencias staff" on public.natacion_ausencias for all to authenticated
  using      (public.es_admin() or public.es_staff() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))
  with check (public.es_admin() or public.es_staff() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'));

-- ---------------------------------------------------------------------------
-- FUNCIÓN · ver mi plaza por código (pública, acotada al código)
-- ---------------------------------------------------------------------------
create or replace function public.natacion_mi_plaza(p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_acc public.natacion_accesos; v jsonb;
begin
  select * into v_acc from public.natacion_accesos where codigo = p_codigo and activo;
  if not found then return null; end if;
  select jsonb_build_object(
    'nombre', v_acc.nombre,
    'franjas', coalesce((
      select jsonb_agg(jsonb_build_object(
        'franja_id', f.id, 'dia', f.dia, 'hora', to_char(f.hora,'HH24:MI'),
        'grupo', f.grupo, 'calle', i.calle, 'nivel', i.nivel) order by f.dia, f.hora)
      from public.natacion_inscripciones i
      join public.natacion_franjas f on f.id = i.franja_id
      where i.acceso_id = v_acc.id and i.activa), '[]'::jsonb),
    'ausencias', coalesce((
      select jsonb_agg(jsonb_build_object('franja_id', a.franja_id, 'fecha', a.fecha) order by a.fecha)
      from public.natacion_ausencias a
      where a.acceso_id = v_acc.id and a.fecha >= current_date), '[]'::jsonb)
  ) into v;
  return v;
end $$;

-- ---------------------------------------------------------------------------
-- FUNCIÓN · avisar de que un día no viene
-- ---------------------------------------------------------------------------
create or replace function public.natacion_marcar_ausencia(p_codigo text, p_franja uuid, p_fecha date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_acc uuid;
begin
  select id into v_acc from public.natacion_accesos where codigo = p_codigo and activo;
  if v_acc is null then return jsonb_build_object('ok', false, 'error', 'codigo'); end if;
  if p_fecha < current_date then return jsonb_build_object('ok', false, 'error', 'fecha'); end if;
  if not exists (select 1 from public.natacion_inscripciones where acceso_id = v_acc and franja_id = p_franja and activa) then
    return jsonb_build_object('ok', false, 'error', 'franja');
  end if;
  insert into public.natacion_ausencias(acceso_id, franja_id, fecha)
    values (v_acc, p_franja, p_fecha)
    on conflict (acceso_id, franja_id, fecha) do nothing;
  return jsonb_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------------
-- FUNCIÓN · deshacer (sí que va a venir)
-- ---------------------------------------------------------------------------
create or replace function public.natacion_quitar_ausencia(p_codigo text, p_franja uuid, p_fecha date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_acc uuid;
begin
  select id into v_acc from public.natacion_accesos where codigo = p_codigo and activo;
  if v_acc is null then return jsonb_build_object('ok', false, 'error', 'codigo'); end if;
  delete from public.natacion_ausencias where acceso_id = v_acc and franja_id = p_franja and fecha = p_fecha;
  return jsonb_build_object('ok', true);
end $$;

grant execute on function public.natacion_mi_plaza(text)                  to anon, authenticated;
grant execute on function public.natacion_marcar_ausencia(text, uuid, date) to anon, authenticated;
grant execute on function public.natacion_quitar_ausencia(text, uuid, date) to anon, authenticated;
