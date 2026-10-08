-- 301 · Pasar lista obligatorio (natación)
-- Mario: que los monitores confirmen por cada franja/día que han pasado lista,
-- con un botón rápido «todos presentes» cuando no falta nadie. Queda registrado
-- quién y cuándo (es condicionante para valorar nóminas).
-- Natación va por FRANJA + DÍA (no por sesiones), así que la lista se guarda así.

create table if not exists public.natacion_lista (
  id              uuid primary key default gen_random_uuid(),
  franja_id       uuid not null references public.natacion_franjas(id) on delete cascade,
  fecha           date not null,
  pasada_por      uuid references public.perfiles(id),
  pasada_en       timestamptz not null default now(),
  todos_presentes boolean not null default false,
  no_vienen       int not null default 0,
  unique (franja_id, fecha)
);

alter table public.natacion_lista enable row level security;

-- Lectura: admin y cualquier responsable/monitor de natación (para el control).
drop policy if exists "natacion_lista lectura" on public.natacion_lista;
create policy "natacion_lista lectura" on public.natacion_lista for select
  using (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'));
-- La escritura va SOLO por el RPC (security definer); no hay policy de insert/update.

-- Pasar lista de una franja en un día (o re-confirmarla).
create or replace function public.natacion_pasar_lista(
  p_franja uuid, p_fecha date, p_todos_presentes boolean default false, p_no_vienen int default 0
) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare v_perfil uuid; v_nombre text; v_en timestamptz;
begin
  if not (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion')) then
    raise exception 'Sin permiso para pasar lista de natación.' using errcode = '42501';
  end if;
  if p_franja is null or p_fecha is null then
    raise exception 'Falta la franja o la fecha.';
  end if;
  v_perfil := public.mi_perfil_id();
  insert into public.natacion_lista (franja_id, fecha, pasada_por, pasada_en, todos_presentes, no_vienen)
  values (p_franja, p_fecha, v_perfil, now(), coalesce(p_todos_presentes, false), greatest(coalesce(p_no_vienen, 0), 0))
  on conflict (franja_id, fecha) do update
    set pasada_por = excluded.pasada_por, pasada_en = excluded.pasada_en,
        todos_presentes = excluded.todos_presentes, no_vienen = excluded.no_vienen
  returning pasada_en into v_en;
  select btrim(coalesce(nombre, '') || ' ' || coalesce(apellidos, '')) into v_nombre
    from public.perfiles where id = v_perfil;
  return jsonb_build_object('ok', true, 'pasada_en', v_en, 'pasada_por', nullif(v_nombre, ''));
end $$;

-- Estado de la lista por día: TODAS las franjas de ese día del calendario, con
-- si se pasó lista, quién y cuándo. Sirve para la pantalla del monitor y para
-- el control. Devuelve vacío si quien pregunta no es de natación.
create or replace function public.natacion_lista_dia(p_fecha date)
returns table(
  franja_id uuid, dia int, hora time, grupo text, monitores text,
  pasada boolean, pasada_por text, pasada_en timestamptz, todos_presentes boolean, no_vienen int
)
language sql stable security definer set search_path to 'public' as $$
  select f.id, f.dia, f.hora, f.grupo, f.monitores,
         (nl.id is not null) as pasada,
         nullif(btrim(coalesce(p.nombre, '') || ' ' || coalesce(p.apellidos, '')), '') as pasada_por,
         nl.pasada_en, coalesce(nl.todos_presentes, false), coalesce(nl.no_vienen, 0)
  from public.natacion_franjas f
  left join public.natacion_lista nl on nl.franja_id = f.id and nl.fecha = p_fecha
  left join public.perfiles p on p.id = nl.pasada_por
  where coalesce(f.activa, true)
    and f.dia = extract(isodow from p_fecha)::int
    and (public.es_admin() or public.soy_responsable('natacion') or public.soy_responsable('escuela-natacion'))
  order by f.hora, f.grupo;
$$;

grant execute on function public.natacion_pasar_lista(uuid, date, boolean, int) to authenticated;
grant execute on function public.natacion_lista_dia(date) to authenticated;
