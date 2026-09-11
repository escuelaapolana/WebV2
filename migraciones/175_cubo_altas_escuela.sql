-- 175 · El Cubo · precio en dos tramos (familia de la escuela / de fuera)
-- ------------------------------------------------------------
-- El precio del Cubo depende de si quien se apunta es FAMILIA DE LA
-- ESCUELA del club o viene de FUERA:
--       1 día/sem   2 días/sem
--   escuela   20 €       30 €
--   fuera     30 €       40 €
--
-- La verdad de «es de la escuela» la comprueba el club al aprobar el alta
-- (tiene la lista de la escuela). Aquí solo se guarda lo que declara la
-- persona y el precio que le corresponde según eso; el club lo confirma.
-- ============================================================

begin;

alter table public.cubo_altas
  add column if not exists es_escuela boolean not null default false;

create or replace function public.cubo_alta_crear(p jsonb)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_slot     text := trim(coalesce(p ->> 'slot', ''));
  v_dias     int  := coalesce((p ->> 'dias')::int, 0);
  v_escuela  boolean := coalesce((p ->> 'escuela')::boolean, false);
  v_hijo     text := left(trim(coalesce(p ->> 'hijo', '')), 160);
  v_horario  text;
  v_precio   int;
  v_id       uuid;
begin
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

  -- Precio en dos tramos según escuela / fuera.
  v_precio := case
    when v_escuela and v_dias = 1 then 20
    when v_escuela and v_dias = 2 then 30
    when not v_escuela and v_dias = 1 then 30
    else 40 end;

  if trim(coalesce(p ->> 'nombre', '')) = '' or trim(coalesce(p ->> 'apellidos', '')) = '' then
    raise exception 'Faltan el nombre y los apellidos.' using errcode = 'P0001';
  end if;
  if trim(coalesce(p ->> 'telefono', '')) = '' then
    raise exception 'Hace falta un teléfono de contacto.' using errcode = 'P0001';
  end if;
  -- Si dice ser de la escuela, tiene que decir de qué hijo/a (lo que el club comprueba).
  if v_escuela and v_hijo = '' then
    raise exception 'Para la cuota de familia de la escuela, dinos el nombre de tu hijo/a.' using errcode = 'P0001';
  end if;

  insert into public.cubo_altas (nombre, apellidos, dni, telefono, hijo, direccion, horario, dias, precio_mes, nota, es_escuela)
  values (
    left(trim(p ->> 'nombre'), 120),
    left(trim(p ->> 'apellidos'), 120),
    left(trim(coalesce(p ->> 'dni', '')), 30),
    left(trim(p ->> 'telefono'), 40),
    v_hijo,
    left(trim(coalesce(p ->> 'direccion', '')), 240),
    v_horario, v_dias, v_precio,
    left(trim(coalesce(p ->> 'nota', '')), 400),
    v_escuela
  )
  returning id into v_id;

  return v_id;
end;
$function$;

grant execute on function public.cubo_alta_crear(jsonb) to anon, authenticated;

commit;
