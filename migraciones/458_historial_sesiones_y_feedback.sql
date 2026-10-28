-- 458 · Historial de sesiones y de feedback (fase 1 de «planificación + feedback
-- + seguimiento en Supabase»)
-- ---------------------------------------------------------------------------
-- Andrés (28-oct-2026). Hasta hoy una sesión se editaba encima (sin copia), el
-- registro del atleta apuntaba a la sesión VIVA (si el plan cambiaba, cambiaba
-- lo que «había respondido»), los tiempos se ataban a filas que podían dejar de
-- existir, una corrección del feedback solo sumaba 1 a `corregido_veces` y
-- borrar una sesión borraba su feedback en cascada.
--
-- Ahora:
--   1) `sesiones_versiones`: cada alta, cambio, archivo o borrado de una sesión
--      deja una versión inmutable (la fila entera, con su número, fecha y autor).
--   2) Cada registro del atleta guarda `sesion_version_id`: la versión que
--      respondió. Se fija al crearlo y no cambia aunque el plan se edite luego.
--      Sus tiempos (claves = id de fila) siguen casando con las filas de esa
--      versión aunque después se cambien o quiten ejercicios.
--   3) `registros_sesion_versiones`: cada corrección (o borrado) del feedback
--      guarda los valores ANTERIORES y qué campos cambiaron.
--   4) Una sesión con registros no se borra: se ARCHIVA (sale de la
--      planificación, no se publica, y su feedback se queda). La clave ajena
--      pasa de CASCADE a RESTRICT como red de seguridad.
--   5) Datos antiguos: cada sesión recibe una versión «inicial» (como estaba
--      hoy) y cada registro antiguo se enlaza a ella con `version_garantia`
--      'sin_garantia' o 'sobrescrita' (+ nota). No se reconstruye nada que no
--      se guardó.
--   6) Permisos como hasta ahora: admin todo; el entrenador, las de sus grupos;
--      el atleta, solo lo suyo. Nadie escribe a mano en el historial.
--   7) La purga de 6 años borra también las correcciones guardadas y el
--      generador de entrenos fijos ignora las sesiones archivadas.
-- Copia previa: schema `respaldo` (en la base) + .secrets/backups/ (local).
-- ---------------------------------------------------------------------------
begin;

-- 0 · Copia de seguridad dentro de la base (no expuesta a la API)
create schema if not exists respaldo;
revoke all on schema respaldo from public, anon, authenticated;
create table respaldo.sesiones_20261028 as select * from public.sesiones;
create table respaldo.registros_sesion_20261028 as select * from public.registros_sesion;
revoke all on all tables in schema respaldo from public, anon, authenticated;

-- 1 · Versiones de sesión ----------------------------------------------------
create table public.sesiones_versiones (
  id              uuid primary key default gen_random_uuid(),
  sesion_id       uuid not null,        -- sin clave ajena: sobrevive al borrado
  version         int  not null,
  evento          text not null check (evento in ('inicial','creada','editada','archivada','restaurada','borrada')),
  datos           jsonb not null,       -- la fila entera de la sesión en esta versión
  grupo_id        uuid,                 -- copias para permisos y búsquedas
  fecha           date,
  vigente_desde   timestamptz not null default now(),
  vigente_hasta   timestamptz,          -- null = versión actual
  autor_perfil_id uuid,                 -- quién (perfil), si fue desde la app
  via             text not null,        -- 'app' · 'generador' · 'sistema' · lo que diga apolana.autor
  nota            text,
  unique (sesion_id, version)
);
create index sesiones_versiones_sesion on public.sesiones_versiones (sesion_id, version desc);
create index sesiones_versiones_grupo on public.sesiones_versiones (grupo_id, fecha);

-- 2 · Archivar en vez de borrar ---------------------------------------------
alter table public.sesiones
  add column archivada_en   timestamptz,
  add column archivada_por  uuid,
  add column archivo_motivo text;

-- 3 · El registro recuerda la versión que respondió ---------------------------
alter table public.registros_sesion
  add column sesion_version_id uuid references public.sesiones_versiones(id) on delete restrict,
  add column version_garantia  text check (version_garantia in ('exacta','sin_garantia','sobrescrita')),
  add column version_nota      text;
create index registros_sesion_version on public.registros_sesion (sesion_version_id);

-- 4 · Correcciones del feedback -------------------------------------------------
create table public.registros_sesion_versiones (
  id                uuid primary key default gen_random_uuid(),
  registro_id       uuid not null,      -- sin clave ajena: sobrevive al borrado
  atleta_id         uuid not null,      -- para permisos y para la purga
  sesion_id         uuid,
  sesion_version_id uuid,
  n                 int  not null,      -- 1ª, 2ª… versión anterior de este registro
  evento            text not null check (evento in ('correccion','borrado')),
  datos             jsonb not null,     -- el registro tal como estaba ANTES del cambio
  cambios           text[],             -- campos que cambiaron
  autor_perfil_id   uuid,
  via               text not null,
  creada_en         timestamptz not null default now(),
  unique (registro_id, n)
);
create index registros_sesion_versiones_reg on public.registros_sesion_versiones (registro_id, n desc);
create index registros_sesion_versiones_atleta on public.registros_sesion_versiones (atleta_id);

-- 5 · Datos que ya existían (sin inventar historia) -----------------------------
insert into public.sesiones_versiones (sesion_id, version, evento, datos, grupo_id, fecha, vigente_desde, via, nota)
select s.id, 1, 'inicial', to_jsonb(s), s.grupo_id, s.fecha, now(), 'migracion 458',
       'Estado de la sesión al activar el historial (28-oct-2026). Las versiones anteriores no se guardaron.'
  from public.sesiones s;

with filas as (
  select s.id sesion_id, array_agg(f->>'id') ids
    from public.sesiones s,
         jsonb_array_elements(case when jsonb_typeof(s.bloques) = 'array' then s.bloques else '[]'::jsonb end) b,
         jsonb_array_elements(case when jsonb_typeof(b->'filas') = 'array' then b->'filas' else '[]'::jsonb end) f
   group by s.id),
calc as (
  select r.id,
         v.id as version_id,
         (s.updated_at > r.created_at + interval '1 minute') as editada_despues,
         (select count(*) from jsonb_object_keys(case when jsonb_typeof(r.tiempos_reales) = 'object' then r.tiempos_reales else '{}'::jsonb end) k
           where k ~ '^[0-9a-f-]{36}$' and not (k = any(coalesce(fl.ids, '{}')))) as huerfanos,
         coalesce(r.corregido_veces, 0) as corr
    from public.registros_sesion r
    join public.sesiones s on s.id = r.sesion_id
    join public.sesiones_versiones v on v.sesion_id = s.id and v.version = 1
    left join filas fl on fl.sesion_id = s.id)
update public.registros_sesion r
   set sesion_version_id = c.version_id,
       version_garantia  = case when c.editada_despues or c.huerfanos > 0 then 'sobrescrita' else 'sin_garantia' end,
       version_nota      = 'Registro anterior al historial (28-oct-2026): se enlaza con la sesión tal como estaba ese día.'
         || case when c.editada_despues or c.huerfanos > 0
                 then ' La sesión se cambió después de este registro: el plan que respondió el atleta no se conservó.'
                 else ' No se puede garantizar que fuera exactamente el plan que vio el atleta.' end
         || case when c.huerfanos > 0 then ' ' || c.huerfanos || ' tiempo(s) apuntan a filas que ya no están en el plan guardado.' else '' end
         || case when c.corr > 0 then ' Corregido ' || c.corr || ' vez/veces antes del historial: los valores anteriores no se guardaron.' else '' end
  from calc c
 where c.id = r.id;

-- 6 · Disparadores ---------------------------------------------------------
create or replace function public._historial_via() returns text
language sql stable set search_path to 'public' as $$
  select case
    when nullif(current_setting('apolana.autor', true), '') is not null then current_setting('apolana.autor', true)
    when coalesce(current_setting('apolana.generador', true), '') = 'si' then 'generador'
    when (auth.jwt() ->> 'email') is not null then 'app'
    else 'sistema' end;
$$;

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
  else
    v_id := new.id; v_fila := to_jsonb(new);
    if tg_op = 'INSERT' then
      v_ev := 'creada';
    else
      -- solo marcas internas (updated_at, auto_tocada) → no es una versión nueva
      if (to_jsonb(new) - array['updated_at','auto_tocada']) = (to_jsonb(old) - array['updated_at','auto_tocada']) then
        return null;
      end if;
      v_ev := case when new.archivada_en is not null and old.archivada_en is null then 'archivada'
                   when new.archivada_en is null and old.archivada_en is not null then 'restaurada'
                   else 'editada' end;
    end if;
  end if;
  update public.sesiones_versiones set vigente_hasta = now() where sesion_id = v_id and vigente_hasta is null;
  select coalesce(max(version), 0) + 1 into v_n from public.sesiones_versiones where sesion_id = v_id;
  insert into public.sesiones_versiones (sesion_id, version, evento, datos, grupo_id, fecha, autor_perfil_id, via, vigente_hasta)
  values (v_id, v_n, v_ev, v_fila, (v_fila->>'grupo_id')::uuid, (v_fila->>'fecha')::date,
          public.mi_perfil_id(), public._historial_via(), case when tg_op = 'DELETE' then now() end);
  return null;
end $$;

create or replace function public.sesiones_archivar_si_hay_registros() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  -- Borrado definitivo a propósito (desde la base, sabiendo lo que se hace).
  if coalesce(current_setting('apolana.borrado_definitivo', true), '') = '1' then
    return old;
  end if;
  if exists (select 1 from public.registros_sesion r where r.sesion_id = old.id) then
    if old.archivada_en is null then
      update public.sesiones
         set archivada_en = now(), archivada_por = public.mi_perfil_id(), publicada = false,
             archivo_motivo = coalesce(nullif(current_setting('apolana.motivo', true), ''),
                                       'Se quiso borrar y tenía registros de atletas: se archiva para no perderlos')
       where id = old.id;
    end if;
    return null;   -- no se borra: queda archivada con su feedback
  end if;
  return old;
end $$;

create or replace function public.registros_fijar_version() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if tg_op = 'INSERT' or new.sesion_id is distinct from old.sesion_id then
    select v.id into new.sesion_version_id
      from public.sesiones_versiones v
     where v.sesion_id = new.sesion_id and v.vigente_hasta is null
     order by v.version desc limit 1;
    new.version_garantia := case when new.sesion_version_id is null then 'sin_garantia' else 'exacta' end;
    new.version_nota := null;
  else
    -- una edición posterior NO cambia la versión respondida
    new.sesion_version_id := old.sesion_version_id;
    new.version_garantia  := old.version_garantia;
    new.version_nota      := old.version_nota;
  end if;
  return new;
end $$;

create or replace function public.registros_guardar_anterior() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  v_cambios text[];
  v_n       int;
begin
  if coalesce(current_setting('apolana.purga', true), '') = '1' then
    return null;   -- la purga de 6 años no deja copia
  end if;
  if tg_op = 'UPDATE' then
    select array_agg(k order by k) into v_cambios
      from jsonb_each(to_jsonb(new)) n(k, val)
     where k not in ('corregido_en','corregido_veces')
       and val is distinct from (to_jsonb(old) -> k);
    if v_cambios is null then return null; end if;
  end if;
  select coalesce(max(n), 0) + 1 into v_n from public.registros_sesion_versiones where registro_id = old.id;
  insert into public.registros_sesion_versiones
    (registro_id, atleta_id, sesion_id, sesion_version_id, n, evento, datos, cambios, autor_perfil_id, via)
  values (old.id, old.atleta_id, old.sesion_id, old.sesion_version_id, v_n,
          case when tg_op = 'DELETE' then 'borrado' else 'correccion' end,
          to_jsonb(old), v_cambios, public.mi_perfil_id(), public._historial_via());
  return null;
end $$;

create trigger trg_sesiones_a_archivar before delete on public.sesiones
  for each row execute function public.sesiones_archivar_si_hay_registros();
create trigger trg_sesiones_z_versiones after insert or update or delete on public.sesiones
  for each row execute function public.sesiones_versionar();
create trigger trg_registros_a_version before insert or update on public.registros_sesion
  for each row execute function public.registros_fijar_version();
create trigger trg_registros_z_anterior after update or delete on public.registros_sesion
  for each row execute function public.registros_guardar_anterior();

-- 7 · Red de seguridad: borrar una sesión ya NO arrastra su feedback ----------
alter table public.registros_sesion drop constraint registros_sesion_sesion_id_fkey;
alter table public.registros_sesion add constraint registros_sesion_sesion_id_fkey
  foreign key (sesion_id) references public.sesiones(id) on delete restrict;

-- 8 · Permisos: leer como hasta ahora; escribir solo los disparadores ---------
alter table public.sesiones_versiones enable row level security;
alter table public.registros_sesion_versiones enable row level security;
revoke all on public.sesiones_versiones, public.registros_sesion_versiones from public, anon, authenticated;
grant select on public.sesiones_versiones, public.registros_sesion_versiones to authenticated;
grant all on public.sesiones_versiones, public.registros_sesion_versiones to service_role;

create policy "admin ve todo el historial" on public.sesiones_versiones
  for select to authenticated using ((select public.es_admin()));
create policy "entrenador ve el historial de sus grupos" on public.sesiones_versiones
  for select to authenticated using (grupo_id in (select g.id from public.grupos g where g.entrenador_id = (select public.mi_perfil_id())));
create policy "atleta ve la versión que respondió" on public.sesiones_versiones
  for select to authenticated using (exists (select 1 from public.registros_sesion r where r.sesion_version_id = sesiones_versiones.id));
create policy "atleta ve el historial de lo que se apuntó él" on public.sesiones_versiones
  for select to authenticated using ((datos->>'origen') = 'atleta' and (datos->>'creado_por')::uuid = (select public.mi_perfil_id()));

create policy "admin ve todas las correcciones" on public.registros_sesion_versiones
  for select to authenticated using ((select public.es_admin()));
create policy "correcciones de los registros que puedo ver" on public.registros_sesion_versiones
  for select to authenticated using (atleta_id in (select public.mis_atletas_entreno()));

revoke all on function public.sesiones_versionar(), public.sesiones_archivar_si_hay_registros(),
  public.registros_fijar_version(), public.registros_guardar_anterior() from public, anon, authenticated;
revoke all on function public._historial_via() from public, anon;
grant execute on function public._historial_via() to authenticated, service_role;

-- 9 · Purga de 6 años y generador de entrenos fijos -----------------------------
CREATE OR REPLACE FUNCTION public.purga_6anios_ejecutar()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  c public.atletas;
  n_total int := 0;
  d jsonb;
begin
  -- Candado de seguridad: si hay alguien con sesión, tiene que ser admin.
  -- Si no hay sesión (el programador automático), se deja pasar.
  if auth.uid() is not null and not public.es_admin() then
    raise exception 'Solo el club puede lanzar la purga de datos.' using errcode = '42501';
  end if;

  -- (mig 458) Durante la purga, los disparadores del historial no guardan nada.
  perform set_config('apolana.purga', '1', true);

  for c in select * from public.purga_6anios_candidatos() loop
    d := '{}'::jsonb;

    -- ---- Se BORRA lo sensible (salud, notas, partes de entreno) ----
    with x as (delete from public.bienestar_diario   where atleta_id = c.id returning 1) select d || jsonb_build_object('bienestar_diario',   count(*)) into d from x;
    with x as (delete from public.lesiones_atleta     where atleta_id = c.id returning 1) select d || jsonb_build_object('lesiones_atleta',     count(*)) into d from x;
    with x as (delete from public.notas_atleta        where atleta_id = c.id returning 1) select d || jsonb_build_object('notas_atleta',        count(*)) into d from x;
    with x as (delete from public.notas_familia       where atleta_id = c.id returning 1) select d || jsonb_build_object('notas_familia',       count(*)) into d from x;
    with x as (delete from public.entrevista_inicial  where atleta_id = c.id returning 1) select d || jsonb_build_object('entrevista_inicial',  count(*)) into d from x;
    with x as (delete from public.registros_sesion    where atleta_id = c.id returning 1) select d || jsonb_build_object('registros_sesion',    count(*)) into d from x;
    -- (mig 458) y las versiones anteriores de sus registros (correcciones)
    with x as (delete from public.registros_sesion_versiones where atleta_id = c.id returning 1) select d || jsonb_build_object('registros_sesion_versiones', count(*)) into d from x;

    -- ---- Se ANONIMIZA la ficha: fuera lo personal, se queda el nombre
    --      y los atributos deportivos (para que el récord siga leyéndose) ----
    update public.atletas set
      dni = null, sexo = null, email = null, telefono = null,
      fecha_nacimiento = null, licencia = null,
      nombre_tutor = null, email_tutor = null, telefono_tutor = null,
      perfil_padre_id = null,
      observaciones = null, contexto_entrenador = null, contexto_atleta = null,
      cuota_nota = null,
      anonimizado_en = now()
    where id = c.id;

    -- ---- El registro del formulario de alta guarda OTRA copia del DNI
    --      y la dirección: se limpia también ----
    update public.altas_socio set
      dni = null, direccion = null, email = null, telefono = null,
      fecha_nacimiento = null, cp = null, localidad = null, provincia = null,
      nombre = null, apellidos = null
    where atleta_id = c.id;
    update public.altas_escuela_ninos set
      dni = null, fecha_nacimiento = null
    where atleta_id = c.id;

    -- ---- La cuenta (perfil): se desactiva y se le quita el contacto.
    --      Se conserva el nombre para que el histórico deportivo lea ----
    if c.perfil_id is not null then
      update public.perfiles set
        email = null, telefono = null,
        activo = false, rol_activo = false
      where id = c.perfil_id;

      -- La cuenta de acceso (correo real de login): se inutiliza.
      begin
        update auth.users set
          email = 'anon+' || c.perfil_id || '@apolana.invalid',
          phone = null,
          raw_user_meta_data = '{}'::jsonb
        where id = c.perfil_id;
      exception when others then
        -- Si el sistema de cuentas se resiste, se sigue: la ficha ya
        -- quedó anonimizada y esto se puede rematar a mano.
        d := d || jsonb_build_object('aviso_cuenta', 'no se pudo inutilizar el login');
      end;
    end if;

    -- ---- Rastro (sin datos personales) ----
    insert into public.datos_anonimizados (atleta_id, perfil_id, fecha_baja, detalle)
    values (c.id, c.perfil_id, c.fecha_baja, d);

    n_total := n_total + 1;
  end loop;

  return jsonb_build_object('ok', true, 'anonimizados', n_total, 'cuando', now());
end;
$function$;

CREATE OR REPLACE FUNCTION public.generar_entrenos_fijos(p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date, p_grupo uuid DEFAULT NULL::uuid, p_simular boolean DEFAULT false, p_forzar boolean DEFAULT false)
 RETURNS TABLE(creadas integer, actualizadas integer, borradas integer, intactas integer, saltadas_festivo integer, saltadas_persona integer, saltadas_quitadas integer, desde date, hasta date, simulado boolean, aviso text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_desde   date;
  v_hasta   date;
  v_semanas int;
  v_crea    int := 0;
  v_act     int := 0;
  v_bor     int := 0;
  v_int     int := 0;
  v_s_fest  int := 0;
  v_s_pers  int := 0;
  v_s_quit  int := 0;
  v_pisadas int := 0;
  v_dobles  int := 0;
  v_aviso   text := null;
begin
  if auth.uid() is not null and not public.es_admin() then
    raise exception 'Solo el administrador puede publicar los entrenos fijos';
  end if;

  if not p_forzar and coalesce(public.automatizacion_ajuste('entrenos_activo', 'si'), 'si') <> 'si' then
    return query select 0, 0, 0, 0, 0, 0, 0, current_date, current_date, true,
                        'Está parado: no se publica nada nuevo.'::text;
    return;
  end if;

  v_semanas := greatest(1, least(26, coalesce(nullif(public.automatizacion_ajuste('semanas_vista', '6'), '')::int, 6)));
  v_desde := coalesce(p_desde, current_date);
  v_hasta := coalesce(p_hasta, current_date + (v_semanas * 7));
  if v_hasta < v_desde then v_hasta := v_desde; end if;
  -- El pasado no se toca jamás, ni para crear.
  if v_desde < current_date then v_desde := current_date; end if;

  perform set_config('apolana.generador', 'si', true);

  drop table if exists _apo_plan;
  drop table if exists _apo_final;

  create temp table _apo_plan on commit drop as
  select h.id                                   as horario_id,
         g.id                                   as grupo_id,
         g.nombre                               as grupo,
         g.seccion                              as seccion,
         gs.dia::date                           as fecha,
         h.hora_inicio,
         h.hora_fin,
         coalesce(h.lugar, '')                  as lugar,
         h.nota
    from public.grupo_horarios h
    join public.grupos g on g.id = h.grupo_id
    cross join lateral generate_series(v_desde::timestamp, v_hasta::timestamp, interval '1 day') as gs(dia)
   where h.activo
     and coalesce(g.activo, true)
     and coalesce(g.seccion, '') <> 'cubo'
     and (p_grupo is null or g.id = p_grupo)
     and extract(isodow from gs.dia)::int = h.dia_semana
     -- Freno: una «franja» de más de cinco horas no es un entrenamiento,
     -- es el horario de apertura de una instalación.
     and (h.hora_fin is null or (h.hora_fin - h.hora_inicio) <= interval '5 hours');

  -- Regla 4 · festivos y cierres
  delete from _apo_plan p
   where public.hay_excepcion(p.fecha, p.grupo_id, p.seccion, p.lugar);
  get diagnostics v_s_fest = row_count;

  -- Regla 3 · si una persona ya ha puesto algo ese día para ese grupo,
  -- ese día NO se toca. Se compara por grupo y día, nunca por hora: una
  -- sesión de planificación suele ir sin hora, y por hora no cruzaría.
  delete from _apo_plan p
   where exists (select 1 from public.sesiones s
                  where s.grupo_id = p.grupo_id and s.fecha = p.fecha
                    and not coalesce(s.auto_generada, false)
                    and s.archivada_en is null);   -- (mig 458) archivada no cuenta
  get diagnostics v_s_pers = row_count;

  -- Regla 5 · lo que alguien quitó a mano no vuelve
  delete from _apo_plan p
   where exists (select 1 from public.entrenos_auto_borrados b
                  where b.horario_id = p.horario_id and b.fecha = p.fecha);
  get diagnostics v_s_quit = row_count;

  -- Regla 2 · las que alguien ha editado se quedan como están
  select count(*) into v_int
    from public.sesiones s
   where s.auto_generada and s.auto_tocada
     and s.fecha between v_desde and v_hasta
     and (p_grupo is null or s.grupo_id = p_grupo);

  select count(*) into v_crea
    from _apo_plan p
   where not exists (select 1 from public.sesiones s
                      where s.auto_horario_id = p.horario_id and s.fecha = p.fecha
                        and s.auto_generada);

  select count(*) into v_act
    from _apo_plan p
    join public.sesiones s on s.auto_horario_id = p.horario_id and s.fecha = p.fecha
   where s.auto_generada and not s.auto_tocada
     and (s.hora, s.lugar, s.titulo, coalesce(s.publicada, false))
         is distinct from
         (p.hora_inicio,
          nullif(p.lugar, ''),
          p.grupo || case when p.nota is not null then ' · ' || p.nota else '' end,
          true);

  select count(*) into v_bor
    from public.sesiones s
   where s.auto_generada and not s.auto_tocada
     and s.fecha between v_desde and v_hasta
     and (p_grupo is null or s.grupo_id = p_grupo)
     and not exists (select 1 from _apo_plan p
                      where p.horario_id = s.auto_horario_id and p.fecha = s.fecha)
     and not exists (select 1 from public.asistencia a where a.sesion_id = s.id)
     and not exists (select 1 from public.sesion_inscripciones si where si.sesion_id = s.id);

  -- ===================================================================
  -- RED DE SEGURIDAD · cómo quedaría el calendario, ANTES de escribir
  -- -------------------------------------------------------------------
  -- La proyección son las sesiones automáticas que habría al terminar:
  -- las del plan (se creen o se pongan al día) más las que sobreviven
  -- al borrado porque alguien las tocó o porque tienen gente apuntada
  -- o asistencia pasada.
  -- ===================================================================
  create temp table _apo_final on commit drop as
    select p.grupo_id, p.fecha from _apo_plan p
    union all
    select s.grupo_id, s.fecha
      from public.sesiones s
     where s.auto_generada
       and s.fecha between v_desde and v_hasta
       and (p_grupo is null or s.grupo_id = p_grupo)
       and not exists (select 1 from _apo_plan p
                        where p.horario_id = s.auto_horario_id and p.fecha = s.fecha)
       and (s.auto_tocada
            or exists (select 1 from public.asistencia a where a.sesion_id = s.id)
            or exists (select 1 from public.sesion_inscripciones si where si.sesion_id = s.id));

  -- (a) ninguna automática puede caer el mismo día que una de una persona
  select count(*) into v_pisadas
    from _apo_final f
   where exists (select 1 from public.sesiones m
                  where m.grupo_id = f.grupo_id and m.fecha = f.fecha
                    and not coalesce(m.auto_generada, false));

  -- (b) ningún grupo con más automáticas ese día que franjas tiene su
  --     horario ese día de la semana (dos franjas = dos entrenos, y eso
  --     es correcto: no es un duplicado)
  select count(*) into v_dobles from (
    select f.grupo_id, f.fecha
      from _apo_final f
     group by f.grupo_id, f.fecha
    having count(*) > (select count(*) from public.grupo_horarios h
                        where h.grupo_id = f.grupo_id and h.activo
                          and h.dia_semana = extract(isodow from f.fecha)::int)
  ) t;

  if v_pisadas > 0 or v_dobles > 0 then
    v_aviso := 'No se ha publicado nada. ' ||
      case when v_pisadas > 0
           then v_pisadas || ' sesión(es) automática(s) caerían el mismo día que una puesta por una persona. '
           else '' end ||
      case when v_dobles > 0
           then v_dobles || ' grupo(s) acabarían con más entrenos un día de los que dice su horario. '
           else '' end ||
      'Míralo en «Días con dos entrenos» antes de volver a intentarlo.';
  end if;

  if p_simular or v_aviso is not null then
    drop table if exists _apo_plan;
    drop table if exists _apo_final;
    perform set_config('apolana.generador', 'no', true);
    if v_aviso is not null and not p_simular then
      -- Al publicar de verdad no vale con devolver un aviso: quien llama
      -- puede no mirarlo. Se corta, y así no se escribe ni una fila.
      raise exception '%', v_aviso;
    end if;
    return query select v_crea, v_act, v_bor, v_int, v_s_fest, v_s_pers, v_s_quit,
                        v_desde, v_hasta, true, v_aviso;
    return;
  end if;

  -- --- alta de lo que falta ---
  insert into public.sesiones
        (fecha, dia_semana, tipo, titulo, hora, lugar, duracion_min,
         grupo_id, publicada, bloques, creado_por,
         auto_horario_id, auto_generada, auto_tocada)
  select p.fecha,
         public.apo_dia_nombre(extract(isodow from p.fecha)::smallint),
         case
           when p.seccion in ('natacion', 'escuela-natacion') then 'natacion'
           when p.seccion in ('competicion', 'escuela')        then 'pista'
           else 'continuo'
         end,
         p.grupo || case when p.nota is not null then ' · ' || p.nota else '' end,
         p.hora_inicio,
         nullif(p.lugar, ''),
         case when p.hora_fin is not null and p.hora_fin > p.hora_inicio
              then extract(epoch from (p.hora_fin - p.hora_inicio))::int / 60 end,
         p.grupo_id,
         true,
         '[]'::jsonb,
         null,                 -- nadie: lo pone el sistema
         p.horario_id, true, false
    from _apo_plan p
   where not exists (select 1 from public.sesiones s
                      where s.auto_horario_id = p.horario_id and s.fecha = p.fecha
                        and s.auto_generada);

  -- --- rehacer las que siguen siendo del sistema ---
  update public.sesiones s
     set hora         = p.hora_inicio,
         lugar        = nullif(p.lugar, ''),
         titulo       = p.grupo || case when p.nota is not null then ' · ' || p.nota else '' end,
         duracion_min = case when p.hora_fin is not null and p.hora_fin > p.hora_inicio
                             then extract(epoch from (p.hora_fin - p.hora_inicio))::int / 60 end,
         dia_semana   = public.apo_dia_nombre(extract(isodow from p.fecha)::smallint),
         publicada    = true,
         updated_at   = now()
    from _apo_plan p
   where s.auto_horario_id = p.horario_id
     and s.fecha = p.fecha
     and s.auto_generada
     and not s.auto_tocada;

  -- --- quitar lo que ya no toca (solo futuro, solo del sistema, solo
  --     si no hay nadie apuntado ni asistencia pasada) ---
  delete from public.sesiones s
   where s.auto_generada and not s.auto_tocada
     and s.fecha between v_desde and v_hasta
     and (p_grupo is null or s.grupo_id = p_grupo)
     and not exists (select 1 from _apo_plan p
                      where p.horario_id = s.auto_horario_id and p.fecha = s.fecha)
     and not exists (select 1 from public.asistencia a where a.sesion_id = s.id)
     and not exists (select 1 from public.sesion_inscripciones si where si.sesion_id = s.id);

  -- --- y se vuelve a mirar sobre lo escrito, por si acaso ---
  -- Cinturón y tirantes: la comprobación de antes iba sobre la proyección;
  -- esta va sobre lo que ha quedado de verdad. Si algo se hubiera colado,
  -- el error deshace todo lo que ha escrito esta función.
  select count(*) into v_pisadas
    from public.sesiones a
   where a.auto_generada and a.fecha between v_desde and v_hasta
     and (p_grupo is null or a.grupo_id = p_grupo)
     and exists (select 1 from public.sesiones m
                  where m.grupo_id = a.grupo_id and m.fecha = a.fecha
                    and not coalesce(m.auto_generada, false)
                    and m.archivada_en is null);   -- (mig 458)

  select count(*) into v_dobles from (
    select s.grupo_id, s.fecha
      from public.sesiones s
     where s.auto_generada and s.fecha between v_desde and v_hasta
       and (p_grupo is null or s.grupo_id = p_grupo)
     group by s.grupo_id, s.fecha
    having count(*) > (select count(*) from public.grupo_horarios h
                        where h.grupo_id = s.grupo_id and h.activo
                          and h.dia_semana = extract(isodow from s.fecha)::int)
  ) t;

  if v_pisadas > 0 or v_dobles > 0 then
    raise exception 'Se ha deshecho la publicación: habrían quedado % sesión(es) automática(s) pisando el trabajo de una persona y % grupo(s) con más entrenos de los que dice su horario.',
      v_pisadas, v_dobles;
  end if;

  drop table if exists _apo_plan;
  drop table if exists _apo_final;
  -- Se baja la bandera enseguida: si en la misma transacción alguien
  -- edita una sesión después de generar, esa edición SÍ tiene que
  -- marcarse como suya. Sin esto, el generador la pisaría a la vuelta.
  perform set_config('apolana.generador', 'no', true);
  return query select v_crea, v_act, v_bor, v_int, v_s_fest, v_s_pers, v_s_quit,
                      v_desde, v_hasta, false, null::text;
end;
$function$;

commit;
