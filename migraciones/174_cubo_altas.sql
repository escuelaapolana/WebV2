-- 174 · Altas de El Cubo (formulario público de apuntarse)
-- ------------------------------------------------------------
-- La gente que entrena en El Cubo (vuelven del año pasado) se apunta
-- desde un formulario PÚBLICO: nombre, apellidos, DNI, teléfono, nombre
-- del hijo (si es de la escuela), dirección y el horario elegido. NO se
-- pide tarjeta aquí: el pago (suscripción mensual) se hace después, del
-- 21 en adelante, desde su cuenta.
--
--   1) Tabla `cubo_altas`: guarda cada solicitud como 'pendiente'. El
--      club la ve y la aprueba desde el admin de El Cubo (crear la
--      cuenta cubo-atleta y meterla en su grupo/horario va aparte).
--   2) cubo_alta_crear(): la crea desde la web SIN sesión (anon). El
--      PRECIO y el texto del horario los pone el servidor a partir de
--      un código, no el navegador. SECURITY DEFINER.
--
-- Privacidad: DNI y dirección son datos personales → RLS puesta, y solo
-- un administrador puede leer la tabla. El alta entra por la función.
-- ============================================================

begin;

create table if not exists public.cubo_altas (
  id          uuid primary key default gen_random_uuid(),
  nombre      text not null,
  apellidos   text not null,
  dni         text,
  telefono    text not null,
  hijo        text,                    -- nombre del hijo si es de la escuela
  direccion   text,
  horario     text not null,           -- texto canónico del turno elegido
  dias        smallint not null check (dias in (1, 2)),
  precio_mes  integer not null,        -- 20 (1 día) · 30 (2 días)
  nota        text,                    -- p. ej. «vengo solo el martes»
  estado      text not null default 'pendiente' check (estado in ('pendiente','aprobada','rechazada')),
  created_at  timestamptz not null default now()
);

alter table public.cubo_altas enable row level security;

-- Solo el club (admin) lee las altas. El insert entra por la función.
drop policy if exists cubo_altas_admin_lee on public.cubo_altas;
create policy cubo_altas_admin_lee on public.cubo_altas
  for select using (public.es_admin());

-- Crear un alta desde la web (sin sesión). El precio lo pone el servidor.
create or replace function public.cubo_alta_crear(p jsonb)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_slot   text := trim(coalesce(p ->> 'slot', ''));
  v_dias   int  := coalesce((p ->> 'dias')::int, 0);
  v_horario text;
  v_precio  int;
  v_id     uuid;
  corta    text;
begin
  -- Turno elegido (código → texto canónico). Solo estos tres valen.
  v_horario := case v_slot
    when 'lx-1730'  then 'Lunes y miércoles · 17:30–18:30'
    when 'mj-1730'  then 'Martes y jueves · 17:30–18:30'
    when 'lx-1845'  then 'Lunes y miércoles · 18:45–19:45'
    else null end;
  if v_horario is null then
    raise exception 'Elige un horario de la lista.' using errcode = 'P0001';
  end if;

  if v_dias not in (1, 2) then
    raise exception 'Indica si vienes uno o dos días por semana.' using errcode = 'P0001';
  end if;
  v_precio := case v_dias when 1 then 20 else 30 end;

  if trim(coalesce(p ->> 'nombre', '')) = '' or trim(coalesce(p ->> 'apellidos', '')) = '' then
    raise exception 'Faltan el nombre y los apellidos.' using errcode = 'P0001';
  end if;
  if trim(coalesce(p ->> 'telefono', '')) = '' then
    raise exception 'Hace falta un teléfono de contacto.' using errcode = 'P0001';
  end if;

  insert into public.cubo_altas (nombre, apellidos, dni, telefono, hijo, direccion, horario, dias, precio_mes, nota)
  values (
    left(trim(p ->> 'nombre'), 120),
    left(trim(p ->> 'apellidos'), 120),
    left(trim(coalesce(p ->> 'dni', '')), 30),
    left(trim(p ->> 'telefono'), 40),
    left(trim(coalesce(p ->> 'hijo', '')), 160),
    left(trim(coalesce(p ->> 'direccion', '')), 240),
    v_horario, v_dias, v_precio,
    left(trim(coalesce(p ->> 'nota', '')), 400)
  )
  returning id into v_id;

  return v_id;
end;
$function$;

grant execute on function public.cubo_alta_crear(jsonb) to anon, authenticated;

commit;
