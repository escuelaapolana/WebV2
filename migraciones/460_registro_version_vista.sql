-- 460 · El registro se ata a la versión que el atleta VIO, no a la última
-- ---------------------------------------------------------------------------
-- Cierre de la fase 1 (Andrés, 28-oct-2026). Caso: el atleta abre la sesión
-- (versión 1), el entrenador la cambia (versión 2) y el atleta envía después su
-- feedback. Con la mig 458 el registro se ataba a la versión vigente AL ENVIAR
-- (la 2), que no es la que vio. Ahora:
--   · `sesiones.version`: número de versión de la fila (lo lleva la app al
--     pintar la sesión). Lo pone un disparador y coincide con sesiones_versiones.
--   · La app manda `version_vista` (guardado normal) o `p_version`
--     (apo_apuntar_ejercicios). El registro se ata a ESA versión: 'exacta'.
--     Si respondió una versión que ya no era la vigente, queda una nota.
--   · Si la app no dice qué versión vio (pantalla vieja en caché, otro camino),
--     se ata a la vigente al enviar con 'vigente_al_enviar': no se afirma que
--     fuera la que vio.
-- ---------------------------------------------------------------------------
begin;

-- 1 · Número de versión en la propia sesión ---------------------------------
alter table public.sesiones add column version integer not null default 1;
update public.sesiones s set version = v.maxv
  from (select sesion_id, max(version) maxv from public.sesiones_versiones group by sesion_id) v
 where v.sesion_id = s.id and s.version is distinct from v.maxv;

create or replace function public.sesiones_numerar_version() returns trigger
language plpgsql set search_path to 'public' as $$
begin
  if tg_op = 'INSERT' then
    new.version := 1;
  elsif (to_jsonb(new) - array['updated_at','auto_tocada','version'])
        = (to_jsonb(old) - array['updated_at','auto_tocada','version']) then
    new.version := old.version;          -- sin cambios de verdad: misma versión
  else
    new.version := old.version + 1;
  end if;
  return new;
end $$;
-- «zz»: el último de los BEFORE, para ver la fila ya como queda (ids de fila, etc.)
create trigger trg_sesiones_zz_numero before insert or update on public.sesiones
  for each row execute function public.sesiones_numerar_version();

create or replace function public.sesiones_versionar() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  v_id   uuid;
  v_fila jsonb;
  v_ev   text;
  v_n    int;
begin
  if tg_op = 'DELETE' then
    v_id := old.id; v_fila := to_jsonb(old); v_ev := 'borrada';
    select coalesce(max(version), 0) + 1 into v_n from public.sesiones_versiones where sesion_id = v_id;
  else
    v_id := new.id; v_fila := to_jsonb(new); v_n := new.version;
    if tg_op = 'INSERT' then
      v_ev := 'creada';
    else
      if new.version = old.version then return null; end if;   -- no hubo versión nueva
      v_ev := case when new.archivada_en is not null and old.archivada_en is null then 'archivada'
                   when new.archivada_en is null and old.archivada_en is not null then 'restaurada'
                   else 'editada' end;
    end if;
  end if;
  update public.sesiones_versiones set vigente_hasta = now() where sesion_id = v_id and vigente_hasta is null;
  insert into public.sesiones_versiones (sesion_id, version, evento, datos, grupo_id, fecha, autor_perfil_id, via, vigente_hasta)
  values (v_id, v_n, v_ev, v_fila, (v_fila->>'grupo_id')::uuid, (v_fila->>'fecha')::date,
          public.mi_perfil_id(), public._historial_via(), case when tg_op = 'DELETE' then now() end);
  return null;
end $$;

-- 2 · El registro dice qué versión vio el atleta -------------------------------
alter table public.registros_sesion add column version_vista integer;
alter table public.registros_sesion drop constraint registros_sesion_version_garantia_check;
alter table public.registros_sesion add constraint registros_sesion_version_garantia_check
  check (version_garantia in ('exacta','vigente_al_enviar','sin_garantia','sobrescrita'));

create or replace function public.registros_fijar_version() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  v_vista  public.sesiones_versiones%rowtype;
  v_actual public.sesiones_versiones%rowtype;
begin
  if tg_op = 'INSERT' or new.sesion_id is distinct from old.sesion_id then
    select * into v_actual from public.sesiones_versiones
     where sesion_id = new.sesion_id and vigente_hasta is null order by version desc limit 1;
    if new.version_vista is not null then
      select * into v_vista from public.sesiones_versiones
       where sesion_id = new.sesion_id and version = new.version_vista;
    end if;
    if v_vista.id is not null then
      new.sesion_version_id := v_vista.id;
      new.version_garantia  := 'exacta';
      new.version_nota := case when v_actual.id is not null and v_actual.version <> v_vista.version
        then 'Respondió la versión ' || v_vista.version || ', que era la que tenía en pantalla; al enviarlo la sesión ya iba por la versión ' || v_actual.version || '.'
        end;
    else
      new.sesion_version_id := v_actual.id;
      new.version_garantia  := case when v_actual.id is null then 'sin_garantia' else 'vigente_al_enviar' end;
      new.version_nota := 'La app no indicó qué versión vio el atleta: se enlaza con la vigente al enviarlo.';
    end if;
  else
    -- una edición posterior NO cambia la versión respondida
    new.sesion_version_id := old.sesion_version_id;
    new.version_garantia  := old.version_garantia;
    new.version_nota      := old.version_nota;
    new.version_vista     := old.version_vista;
  end if;
  return new;
end $$;

-- 3 · apuntar ejercicios recibe la versión vista -------------------------------
drop function if exists public.apo_apuntar_ejercicios(uuid, uuid, jsonb);
CREATE OR REPLACE FUNCTION public.apo_apuntar_ejercicios(p_sesion uuid, p_atleta uuid, p_ejercicios jsonb, p_version integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_existe boolean;
  v_fila   public.registros_sesion%rowtype;
begin
  if p_sesion is null or p_atleta is null then
    raise exception 'Falta la sesión o el atleta';
  end if;
  if p_ejercicios is null or jsonb_typeof(p_ejercicios) <> 'object' then
    raise exception 'Lo que se apunta tiene que venir como una lista de ejercicios';
  end if;

  select exists (
    select 1 from public.registros_sesion
     where sesion_id = p_sesion and atleta_id = p_atleta
  ) into v_existe;

  -- Las mismas dos puertas que las reglas de la tabla: crear el
  -- registro del día lo puede hacer también un padre o madre; tocar
  -- uno que ya existe, solo el atleta o su entrenador.
  if v_existe then
    if not (public.es_admin() or p_atleta in (select public.mis_atletas_entreno())) then
      raise exception 'No puedes apuntar el entrenamiento de este atleta';
    end if;
  else
    if not (public.es_admin() or p_atleta in (select public.mis_atletas())) then
      raise exception 'No puedes apuntar el entrenamiento de este atleta';
    end if;
  end if;

  -- En una sola operación: si no hay fila se crea, y si la hay se le
  -- mezcla lo que trae la pantalla. Sin hueco entre leer y escribir,
  -- que es donde se colaba el fallo cuando se guardaba dos veces a la
  -- vez desde dos sitios.
  -- (mig 460) p_version = la versión de la sesión que el atleta tenía en pantalla
  insert into public.registros_sesion (sesion_id, atleta_id, tiempos_reales, version_vista)
  values (p_sesion, p_atleta, public.apo_tiempos_mezclados('{}'::jsonb, p_ejercicios), p_version)
  on conflict (sesion_id, atleta_id) do update
     set tiempos_reales = public.apo_tiempos_mezclados(
           public.registros_sesion.tiempos_reales, p_ejercicios)
  returning * into v_fila;

  -- Se devuelve lo que ha calculado la base (migración 103) para que la
  -- pantalla enseñe el estado del día tal cual queda guardado, sin
  -- echar sus propias cuentas y acabar diciendo otra cosa.
  return jsonb_build_object(
    'id',               v_fila.id,
    'estado',           v_fila.estado,
    'series_hechas',    v_fila.series_hechas,
    'series_previstas', v_fila.series_previstas,
    'tiempos_reales',   v_fila.tiempos_reales
  );
end;
$function$;
revoke all on function public.apo_apuntar_ejercicios(uuid, uuid, jsonb, integer) from public, anon;
grant execute on function public.apo_apuntar_ejercicios(uuid, uuid, jsonb, integer) to authenticated, service_role;

comment on column public.sesiones.version is 'Nº de versión vigente (mig 460). Coincide con sesiones_versiones.version; la app lo manda como version_vista al responder.';
comment on column public.registros_sesion.version_vista is 'Versión de la sesión que el atleta tenía en pantalla al responder (mig 460).';

commit;
