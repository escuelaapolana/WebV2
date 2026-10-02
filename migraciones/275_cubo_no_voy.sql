-- 275_cubo_no_voy.sql
-- El Cubo · «No voy» a una sesión concreta (que la gente avise sola de que no
-- va a venir un día). Hasta ahora NO existía (ni para la fuerza gratis ni para
-- los de pago): tenían que escribir por WhatsApp y lo cancelaba el club a mano.
--
-- Se guarda por PERSONA (perfil) + grupo + fecha. La lista de Claudia cruza por
-- perfil_id + fecha para marcar a quien avisó. Reutilizable para los dos:
-- fuerza gratis (cubo_prueba) y cuota (cubo_altas) comparten perfil_id.

begin;

create table if not exists public.cubo_ausencias (
  id         uuid primary key default gen_random_uuid(),
  perfil_id  uuid not null references public.perfiles(id) on delete cascade,
  grupo_id   uuid references public.grupos(id) on delete cascade,
  fecha      date not null,
  creado_en  timestamptz not null default now(),
  unique (perfil_id, grupo_id, fecha)
);
create index if not exists cubo_ausencias_fecha_idx on public.cubo_ausencias (fecha);
create index if not exists cubo_ausencias_perfil_idx on public.cubo_ausencias (perfil_id);

alter table public.cubo_ausencias enable row level security;
-- Cada quien ve/gestiona las suyas; el staff del Cubo (Claudia/admin) ve todas.
drop policy if exists cubo_ausencias_propias on public.cubo_ausencias;
create policy cubo_ausencias_propias on public.cubo_ausencias
  for select using (perfil_id = public.mi_perfil_id() or public.es_cubo_lista() or public.es_admin());

-- Escrituras solo por las RPC (SECURITY DEFINER). Nada directo.
revoke all on public.cubo_ausencias from anon, authenticated;
grant select on public.cubo_ausencias to authenticated;

-- Marcar «no voy» a una sesión (grupo + fecha). Solo futuras.
create or replace function public.cubo_no_voy(p_grupo uuid, p_fecha date)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_perfil uuid := public.mi_perfil_id();
begin
  if v_perfil is null then
    raise exception 'Entra en tu cuenta para avisar.' using errcode = '42501';
  end if;
  if p_fecha is null or p_fecha < current_date then
    raise exception 'Esa fecha ya ha pasado.' using errcode = 'P0001';
  end if;
  insert into public.cubo_ausencias (perfil_id, grupo_id, fecha)
  values (v_perfil, p_grupo, p_fecha)
  on conflict (perfil_id, grupo_id, fecha) do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

-- Deshacer («sí voy»).
create or replace function public.cubo_si_voy(p_grupo uuid, p_fecha date)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_perfil uuid := public.mi_perfil_id();
begin
  if v_perfil is null then
    raise exception 'Entra en tu cuenta.' using errcode = '42501';
  end if;
  delete from public.cubo_ausencias
   where perfil_id = v_perfil and fecha = p_fecha
     and coalesce(grupo_id, '00000000-0000-0000-0000-000000000000'::uuid)
         = coalesce(p_grupo, '00000000-0000-0000-0000-000000000000'::uuid);
  return jsonb_build_object('ok', true);
end;
$$;

-- Mis ausencias futuras (para pintar el estado en el portal).
create or replace function public.cubo_mis_ausencias()
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $$
  select coalesce(jsonb_agg(jsonb_build_object('grupo_id', grupo_id, 'fecha', fecha) order by fecha), '[]'::jsonb)
  from public.cubo_ausencias
  where perfil_id = public.mi_perfil_id() and fecha >= current_date;
$$;

revoke all on function public.cubo_no_voy(uuid, date) from public, anon;
revoke all on function public.cubo_si_voy(uuid, date) from public, anon;
grant execute on function public.cubo_no_voy(uuid, date) to authenticated;
grant execute on function public.cubo_si_voy(uuid, date) to authenticated;
grant execute on function public.cubo_mis_ausencias() to authenticated;

commit;
