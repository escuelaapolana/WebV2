-- ============================================================
-- 059 · «SE PONE SOLO» · las dos automatizaciones, de verdad
-- ------------------------------------------------------------
-- QUÉ RESUELVE
--   El panel enseñaba un bloque «Se pone solo» que era solo un
--   contador: contaba cuántas sesiones DEBERÍA haber y no publicaba
--   ninguna. Alguien las metía a mano, una a una, cada semana.
--
--   Aquí se monta lo que faltaba:
--
--   1) ENTRENAMIENTOS FIJOS · SE PUBLICAN SOLOS
--      Los grupos con horario fijo aparecen en el calendario cada
--      semana sin que nadie los toque. No hay nada que decidir: el
--      horario ya está escrito en la ficha del grupo.
--
--   2) CARRERAS DE LA LIGA · SE PROPONEN, NO SE PUBLICAN SOLAS
--      Cuando un socio comunica una prueba, se queda esperando un
--      clic. Una prueba comunicada puede estar mal escrita o ser de
--      otro club: eso lo mira una persona.
--
--   3) «SOLO LO MÍO» · cada persona ve lo suyo
--      Un campo de áreas por persona (`perfiles.areas`) para que el
--      interruptor de la bandeja del panel reparta de verdad.
--
--   ⚠️ LO QUE NUNCA SE PUBLICA SOLO
--      Noticias, fotos y cualquier cosa con nombre de un menor.
--      La automatización llega hasta donde no hay que decidir nada.
--      Esta migración NO toca noticias, ni la biblioteca de fotos,
--      ni nada que lleve el nombre de una persona.
--
-- CÓMO SE PARA TODO
--      update public.automatizaciones_ajustes
--         set valor = 'no' where clave = 'entrenos_activo';
--   A partir de ahí el generador no escribe nada. Lo ya publicado
--   se queda (no se borra al apagar: apagar no es deshacer).
--
-- ⚠️ PERMISOS · SUPABASE REGALA PERMISOS EN LO NUEVO
--   Supabase concede por defecto TODO a `anon` y `authenticated`
--   sobre cualquier tabla o función nueva de `public`. Por eso al
--   final se hace REVOKE ALL explícito y se concede solo lo justo.
--   Comprobado con psql simulando los tres roles.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/059_automatizaciones.sql
-- (Es idempotente: se puede relanzar sin duplicar ni romper nada.)
-- ============================================================


-- =====================================================================
-- 1 · AJUSTES · el interruptor general y la ventana de días
-- =====================================================================
create table if not exists public.automatizaciones_ajustes (
  clave       text primary key,
  valor       text not null,
  updated_at  timestamptz not null default now()
);

comment on table public.automatizaciones_ajustes is
  'Interruptores de «Se pone solo». entrenos_activo: si/no. semanas_vista: cuántas semanas se publican por adelantado.';

insert into public.automatizaciones_ajustes (clave, valor) values
  ('entrenos_activo', 'si'),
  ('semanas_vista',   '6')
on conflict (clave) do nothing;

create or replace function public.automatizacion_ajuste(p_clave text, p_por_defecto text default null)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select valor from public.automatizaciones_ajustes where clave = p_clave), p_por_defecto);
$$;


-- =====================================================================
-- 2 · LEER EL HORARIO QUE YA ESTÁ ESCRITO
-- ---------------------------------------------------------------------
-- El horario de cada grupo vive como TEXTO en `grupos.horario`:
--   «Martes y jueves 20:00-21:15 · Salida desde el Parque Municipal»
--   «Miércoles 19:00 (cuestas) y sábados 08:00 (salida larga) · Ermita»
-- Ese texto NO se toca: lo lee la web pública (/horarios/) y lo escribe
-- el panel. Lo que se añade es una lectura estructurada AL LADO, para
-- poder generar sesiones con ella.
--
-- El criterio de interpretación es EL MISMO que ya usa /horarios/:
-- se recorren los trozos del texto en orden, se van acumulando días y,
-- en cuanto aparece una hora, esos días se cierran con esa hora.
-- =====================================================================

-- Quita tildes SIN cambiar la longitud (hace falta para poder recortar
-- el texto original con las posiciones halladas en el texto normalizado).
create or replace function public.apo_sin_tildes(t text)
returns text
language sql
immutable
parallel safe
as $$
  select translate(coalesce(t, ''),
    'áàäâéèëêíìïîóòöôúùüûñçÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑÇ',
    'aaaaeeeeiiiioooouuuuncAAAAEEEEIIIIOOOOUUUUNC');
$$;

-- Día de la semana en numeración ISO: lunes = 1 … domingo = 7.
create or replace function public.apo_dia_indice(p text)
returns smallint
language sql
immutable
parallel safe
as $$
  select case left(lower(public.apo_sin_tildes(coalesce(p, ''))), 3)
    when 'lun' then 1 when 'mar' then 2 when 'mie' then 3 when 'jue' then 4
    when 'vie' then 5 when 'sab' then 6 when 'dom' then 7 else 0 end::smallint;
$$;

create or replace function public.apo_dia_nombre(p smallint)
returns text
language sql
immutable
parallel safe
as $$
  select (array['lunes','martes','miércoles','jueves','viernes','sábado','domingo'])[greatest(1, least(7, coalesce(p, 1)))];
$$;

-- «9:30» o «9.30» → 09:30. Devuelve NULL si no es una hora de verdad.
create or replace function public.apo_hora(p text)
returns time
language plpgsql
immutable
parallel safe
as $$
declare
  trozos text[];
  h int; m int;
begin
  trozos := string_to_array(replace(coalesce(p, ''), '.', ':'), ':');
  if array_length(trozos, 1) < 2 then return null; end if;
  h := trozos[1]::int;
  m := trozos[2]::int;
  if h > 23 or m > 59 then return null; end if;
  return make_time(h, m, 0);
exception when others then
  return null;
end;
$$;

-- El sitio: lo que va después del «·». Si acaba en paréntesis, ese
-- matiz («controles en sábado») se deja fuera del nombre del sitio.
create or replace function public.horario_lugar(p_texto text)
returns text
language sql
immutable
parallel safe
as $$
  with partes as (
    select case when position('·' in coalesce(p_texto, '')) = 0 then null
                else btrim(substr(p_texto, position('·' in p_texto) + 1)) end as lugar
  )
  select nullif(btrim(coalesce(substring(lugar from '^(.*?)\s*\([^)]*\)\s*$'), lugar)), '')
  from partes;
$$;

-- El matiz entre paréntesis del sitio, si lo hay.
create or replace function public.horario_matiz(p_texto text)
returns text
language sql
immutable
parallel safe
as $$
  with partes as (
    select case when position('·' in coalesce(p_texto, '')) = 0 then null
                else btrim(substr(p_texto, position('·' in p_texto) + 1)) end as lugar
  )
  select nullif(btrim(coalesce(substring(lugar from '^.*?\s*\(([^)]*)\)\s*$'), '')), '')
  from partes;
$$;

-- El corazón: de un texto de horario salen sus franjas.
create or replace function public.horario_franjas(p_texto text)
returns table (dia smallint, hora_inicio time, hora_fin time, nota text)
language plpgsql
immutable
parallel safe
as $$
declare
  c_dia   constant text := 'lunes|martes|miercoles|jueves|viernes|sabados?|domingos?';
  c_pat   constant text :=
      '\mde\s+(?:' || 'lunes|martes|miercoles|jueves|viernes|sabados?|domingos?' || ')\s+a\s+(?:' ||
        'lunes|martes|miercoles|jueves|viernes|sabados?|domingos?' || ')\M'
   || '|\m(?:' || 'lunes|martes|miercoles|jueves|viernes|sabados?|domingos?' || '|lun|mar|mie|jue|vie|sab|dom)\M'
   || '|\d{1,2}[:.]\d{2}\s*(?:[-–—]|a)\s*\d{1,2}[:.]\d{2}'
   || '|\d{1,2}[:.]\d{2}';
  v_original  text;
  v_plano     text;
  v_toks      jsonb := '[]'::jsonb;
  v_tok       text;
  v_ini       int;
  v_fin       int;
  i           int := 1;
  v_a         smallint;
  v_b         smallint;
  v_dias      int[];
  v_k         smallint;
  v_horas     text[];
  v_pend      int[] := '{}';
  v_franjas   jsonb := '[]'::jsonb;
  t           jsonb;
  v_hasta     int;
  v_nota      text;
  d           int;
begin
  if coalesce(btrim(p_texto), '') = '' then return; end if;

  -- Solo la parte del «cuándo»: lo de después del «·» es el sitio.
  v_original := case when position('·' in p_texto) = 0 then p_texto
                     else substr(p_texto, 1, position('·' in p_texto) - 1) end;
  v_plano := lower(public.apo_sin_tildes(v_original));

  -- --- 1) trocear el texto, guardando dónde empieza y acaba cada trozo ---
  loop
    v_ini := regexp_instr(v_plano, c_pat, 1, i, 0);
    exit when v_ini is null or v_ini = 0;
    v_fin := regexp_instr(v_plano, c_pat, 1, i, 1);
    v_tok := regexp_substr(v_plano, c_pat, 1, i);

    if v_tok ~ '^de\s' then
      -- «de lunes a viernes»: se abre el abanico de días
      v_a := public.apo_dia_indice(regexp_substr(v_tok, c_dia, 1, 1));
      v_b := public.apo_dia_indice(regexp_substr(v_tok, c_dia, 1, 2));
      v_dias := '{}';
      if v_a > 0 and v_b > 0 then
        v_k := v_a;
        loop
          v_dias := v_dias || v_k::int;
          exit when v_k = v_b or array_length(v_dias, 1) > 7;
          v_k := (case when v_k = 7 then 1 else v_k + 1 end)::smallint;
        end loop;
      end if;
      v_toks := v_toks || jsonb_build_object('t', 'dias', 'dias', to_jsonb(v_dias), 'ini', v_ini, 'fin', v_fin);

    elsif v_tok ~ '^\d' then
      v_horas := regexp_split_to_array(v_tok, '\s*(?:[-–—]|a)\s*');
      v_toks := v_toks || jsonb_build_object(
        't', 'hora',
        'h1', public.apo_hora(v_horas[1])::text,
        'h2', case when array_length(v_horas, 1) > 1 then public.apo_hora(v_horas[2])::text else null end,
        'ini', v_ini, 'fin', v_fin);

    else
      v_a := public.apo_dia_indice(v_tok);
      if v_a > 0 then
        v_toks := v_toks || jsonb_build_object('t', 'dias', 'dias', to_jsonb(array[v_a::int]), 'ini', v_ini, 'fin', v_fin);
      end if;
    end if;

    i := i + 1;
    exit when i > 60;   -- freno de mano: ningún horario real tiene 60 trozos
  end loop;

  -- --- 2) los días se van acumulando hasta que aparece una hora ---
  for i in 0 .. jsonb_array_length(v_toks) - 1 loop
    t := v_toks -> i;

    if t ->> 't' = 'dias' then
      for d in select value::int from jsonb_array_elements_text(t -> 'dias') loop
        if not (d = any(v_pend)) then v_pend := v_pend || d; end if;
      end loop;

    else
      if (t ->> 'h1') is null then
        v_pend := '{}';
      else
        v_hasta := case when i + 1 < jsonb_array_length(v_toks)
                        then ((v_toks -> (i + 1)) ->> 'ini')::int
                        else length(v_original) + 1 end;
        v_nota := substring(
          substr(v_original, (t ->> 'fin')::int, greatest(0, v_hasta - (t ->> 'fin')::int))
          from '^[^()]*\(([^)]*)\)');
        v_franjas := v_franjas || jsonb_build_object(
          'dias', to_jsonb(v_pend),
          'h1', t ->> 'h1',
          'h2', t ->> 'h2',
          'nota', btrim(coalesce(v_nota, '')));
        v_pend := '{}';
      end if;
    end if;
  end loop;

  -- Días sueltos al final con una sola franja: son de esa franja.
  if array_length(v_pend, 1) > 0 and jsonb_array_length(v_franjas) = 1 then
    v_franjas := jsonb_build_array(jsonb_set(
      v_franjas -> 0, '{dias}',
      to_jsonb((select array_agg(distinct x) from (
        select value::int as x from jsonb_array_elements_text((v_franjas -> 0) -> 'dias')
        union select unnest(v_pend)) z))));
  end if;

  -- --- 3) una fila por día y franja ---
  return query
    select d2.dia::smallint,
           (f ->> 'h1')::time,
           (f ->> 'h2')::time,
           nullif(f ->> 'nota', '')
    from jsonb_array_elements(v_franjas) f
    cross join lateral (select value::int as dia from jsonb_array_elements_text(f -> 'dias')) d2
    where (f ->> 'h1') is not null and d2.dia between 1 and 7;
end;
$$;

comment on function public.horario_franjas(text) is
  'Interpreta el texto libre de grupos.horario con el mismo criterio que la página /horarios/. No modifica nada.';


-- =====================================================================
-- 3 · EL HORARIO ESTRUCTURADO · public.grupo_horarios
-- ---------------------------------------------------------------------
-- Una fila por día y hora de cada grupo. Sale sola del texto, pero se
-- puede ajustar a mano desde el panel (por ejemplo, apagar la salida a
-- la playa de «Aguas abiertas» en invierno sin tocar el texto).
-- =====================================================================
create table if not exists public.grupo_horarios (
  id                    uuid primary key default gen_random_uuid(),
  grupo_id              uuid not null references public.grupos(id) on delete cascade,
  dia_semana            smallint not null check (dia_semana between 1 and 7),
  hora_inicio           time not null,
  hora_fin              time,
  lugar                 text,
  nota                  text,
  origen                text not null default 'texto' check (origen in ('texto', 'mano')),
  activo                boolean not null default true,
  apagado_a_mano        boolean not null default false,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create unique index if not exists ux_grupo_horarios_franja
  on public.grupo_horarios (grupo_id, dia_semana, hora_inicio);
create index if not exists idx_grupo_horarios_grupo
  on public.grupo_horarios (grupo_id) where activo;

comment on table public.grupo_horarios is
  'Horario fijo de cada grupo, día a día. Sale del texto de grupos.horario, que NO se toca.';
comment on column public.grupo_horarios.apagado_a_mano is
  'Si alguien apaga esta franja desde el panel, volver a guardar el horario del grupo no la reactiva.';


-- =====================================================================
-- 4 · EXCEPCIONES · festivos y cierres de instalación
-- ---------------------------------------------------------------------
-- Se marcan UNA VEZ y afectan a todos los grupos que ese día usan esa
-- instalación. Sin `lugar`, afecta a todo el club (un festivo).
-- =====================================================================
create table if not exists public.calendario_excepciones (
  id           uuid primary key default gen_random_uuid(),
  fecha        date not null,
  fecha_fin    date,
  tipo         text not null default 'festivo' check (tipo in ('festivo', 'cierre')),
  motivo       text not null check (btrim(motivo) <> ''),
  lugar        text,        -- null = todas las instalaciones
  seccion      text,        -- null = todas las secciones
  grupo_id     uuid references public.grupos(id) on delete cascade,
  activa       boolean not null default true,
  creado_por   uuid references public.perfiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  constraint calendario_excepciones_rango check (fecha_fin is null or fecha_fin >= fecha)
);

create index if not exists idx_excepciones_fecha
  on public.calendario_excepciones (fecha) where activa;

comment on table public.calendario_excepciones is
  'Festivos y cierres de instalación. Se marcan una vez; el generador de entrenos los respeta.';

-- ¿Está tapado ese día, para ese grupo, en ese sitio?
create or replace function public.hay_excepcion(p_fecha date, p_grupo uuid, p_seccion text, p_lugar text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.calendario_excepciones e
    where e.activa
      and p_fecha between e.fecha and coalesce(e.fecha_fin, e.fecha)
      and (e.grupo_id is null or e.grupo_id = p_grupo)
      and (e.seccion  is null or e.seccion  = p_seccion)
      and (e.lugar    is null or
           lower(public.apo_sin_tildes(coalesce(p_lugar, ''))) like
           '%' || lower(public.apo_sin_tildes(e.lugar)) || '%')
  );
$$;


-- =====================================================================
-- 5 · MARCAR QUÉ SESIÓN ES AUTOMÁTICA
-- ---------------------------------------------------------------------
-- Esto es lo imprescindible: sin ello la automatización pisa el trabajo
-- de la gente.
--   · auto_generada → la ha puesto el sistema, no una persona.
--   · auto_tocada   → una persona la ha editado. Deja de regenerarse
--                     y se respeta lo que puso.
-- =====================================================================
alter table public.sesiones
  add column if not exists auto_horario_id uuid references public.grupo_horarios(id) on delete set null,
  add column if not exists auto_generada   boolean not null default false,
  add column if not exists auto_tocada     boolean not null default false;

comment on column public.sesiones.auto_generada is
  'true = la ha publicado «Se pone solo». Las de una persona nunca se tocan.';
comment on column public.sesiones.auto_tocada is
  'true = alguien la ha editado a mano. A partir de ahí no se regenera nunca más.';

-- Idempotencia de verdad: una sesión por franja y día, y ni una más.
create unique index if not exists ux_sesiones_auto
  on public.sesiones (auto_horario_id, fecha) where auto_generada;

-- Cuando una persona edita una sesión generada, se marca como suya.
create or replace function public.sesiones_marca_tocada()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('apolana.generador', true), '') = 'si' then
    return new;
  end if;
  if coalesce(old.auto_generada, false) and not coalesce(old.auto_tocada, false) then
    if (new.fecha, new.hora, new.lugar, new.titulo, new.tipo, new.grupo_id,
        new.publicada, new.duracion_min, new.bloques, new.plazas,
        new.abierta_inscripcion, new.atletas_ids)
       is distinct from
       (old.fecha, old.hora, old.lugar, old.titulo, old.tipo, old.grupo_id,
        old.publicada, old.duracion_min, old.bloques, old.plazas,
        old.abierta_inscripcion, old.atletas_ids)
    then
      new.auto_tocada := true;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sesiones_marca_tocada on public.sesiones;
create trigger trg_sesiones_marca_tocada
  before update on public.sesiones
  for each row execute function public.sesiones_marca_tocada();

-- Si alguien borra a mano una sesión generada, no vuelve a aparecer.
create table if not exists public.entrenos_auto_borrados (
  horario_id  uuid not null references public.grupo_horarios(id) on delete cascade,
  fecha       date not null,
  borrado_por uuid references public.perfiles(id) on delete set null,
  borrado_en  timestamptz not null default now(),
  primary key (horario_id, fecha)
);

comment on table public.entrenos_auto_borrados is
  'Días que alguien ha quitado a mano. El generador no los vuelve a poner.';

create or replace function public.sesiones_apunta_borrado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('apolana.generador', true), '') = 'si' then
    return old;
  end if;
  if coalesce(old.auto_generada, false) and old.auto_horario_id is not null then
    insert into public.entrenos_auto_borrados (horario_id, fecha, borrado_por)
    values (old.auto_horario_id, old.fecha, public.mi_perfil_id())
    on conflict (horario_id, fecha) do nothing;
  end if;
  return old;
end;
$$;

drop trigger if exists trg_sesiones_apunta_borrado on public.sesiones;
create trigger trg_sesiones_apunta_borrado
  before delete on public.sesiones
  for each row execute function public.sesiones_apunta_borrado();


-- =====================================================================
-- 6 · DEL TEXTO A LAS FRANJAS · sincronizar un grupo
-- =====================================================================
create or replace function public.sincronizar_horarios_grupo(p_grupo uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  g       record;
  v_lugar text;
  n       int := 0;
begin
  select * into g from public.grupos where id = p_grupo;
  if not found then return 0; end if;

  -- El Cubo va por clases sueltas (tabla `cubo_clases`), no por horario
  -- fijo: su texto dice «de lunes a viernes de 09:00 a 21:00», que es el
  -- horario de apertura de la sala, no un entrenamiento.
  if coalesce(g.seccion, '') = 'cubo' or coalesce(g.activo, true) = false then
    update public.grupo_horarios
       set activo = false, updated_at = now()
     where grupo_id = p_grupo and origen = 'texto' and activo;
    return 0;
  end if;

  v_lugar := public.horario_lugar(g.horario);

  insert into public.grupo_horarios
        (grupo_id, dia_semana, hora_inicio, hora_fin, lugar, nota, origen, activo)
  select p_grupo, f.dia, f.hora_inicio, f.hora_fin, v_lugar, f.nota, 'texto', true
    from public.horario_franjas(g.horario) f
   where f.hora_inicio is not null
  on conflict (grupo_id, dia_semana, hora_inicio) do update
    set hora_fin   = excluded.hora_fin,
        lugar      = excluded.lugar,
        nota       = excluded.nota,
        activo     = case when grupo_horarios.apagado_a_mano then grupo_horarios.activo else true end,
        updated_at = now();

  get diagnostics n = row_count;

  -- Las franjas que el texto ya no dice se apagan (no se borran: puede
  -- haber sesiones pasadas colgando de ellas y esas no se tocan nunca).
  update public.grupo_horarios h
     set activo = false, updated_at = now()
   where h.grupo_id = p_grupo
     and h.origen = 'texto'
     and h.activo
     and not exists (
       select 1 from public.horario_franjas(g.horario) f
        where f.dia = h.dia_semana and f.hora_inicio = h.hora_inicio);

  return n;
end;
$$;

create or replace function public.sincronizar_horarios_todos()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare r record; n int := 0;
begin
  if auth.uid() is not null and not public.es_admin() then
    raise exception 'Solo el administrador puede rehacer los horarios';
  end if;
  for r in select id from public.grupos loop
    perform public.sincronizar_horarios_grupo(r.id);
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- Cambiar el horario de un grupo rehace sus franjas al momento.
create or replace function public.grupos_resincroniza_horario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT'
     or new.horario is distinct from old.horario
     or new.seccion is distinct from old.seccion
     or coalesce(new.activo, true) is distinct from coalesce(old.activo, true) then
    perform public.sincronizar_horarios_grupo(new.id);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_grupos_resincroniza on public.grupos;
create trigger trg_grupos_resincroniza
  after insert or update of horario, seccion, activo on public.grupos
  for each row execute function public.grupos_resincroniza_horario();


-- =====================================================================
-- 7 · EL GENERADOR · publica las sesiones por adelantado
-- ---------------------------------------------------------------------
-- REGLAS, EN ORDEN. Las tres primeras son las que protegen el trabajo
-- de la gente y no se negocian:
--
--   1. Nunca toca una sesión que ha creado una persona.
--   2. Si una sesión generada la ha editado alguien (auto_tocada), se
--      queda tal cual y no se vuelve a generar.
--   3. Si un día del grupo ya tiene una sesión hecha a mano, ese día
--      no se toca.
--   4. Festivos y cierres: ese día no se publica nada.
--   5. Lo que alguien borró a mano no vuelve.
--   6. Nunca borra ni cambia nada del pasado.
--   7. Nunca borra una sesión con asistencia pasada o gente apuntada.
--
-- Con `p_simular = true` no escribe nada: solo dice cuánto haría.
-- =====================================================================
create or replace function public.generar_entrenos_fijos(
  p_desde   date    default null,
  p_hasta   date    default null,
  p_grupo   uuid    default null,
  p_simular boolean default false,
  p_forzar  boolean default false
)
returns table (
  creadas       integer,
  actualizadas  integer,
  borradas      integer,
  intactas      integer,
  saltadas      integer,
  desde         date,
  hasta         date,
  simulado      boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_desde   date;
  v_hasta   date;
  v_semanas int;
  v_crea    int := 0;
  v_act     int := 0;
  v_bor     int := 0;
  v_int     int := 0;
  v_salt    int := 0;
begin
  if auth.uid() is not null and not public.es_admin() then
    raise exception 'Solo el administrador puede publicar los entrenos fijos';
  end if;

  if not p_forzar and coalesce(public.automatizacion_ajuste('entrenos_activo', 'si'), 'si') <> 'si' then
    return query select 0, 0, 0, 0, 0, current_date, current_date, true;
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
  get diagnostics v_salt = row_count;

  -- Regla 3 · si una persona ya ha puesto algo ese día para ese grupo
  delete from _apo_plan p
   where exists (select 1 from public.sesiones s
                  where s.grupo_id = p.grupo_id and s.fecha = p.fecha
                    and not coalesce(s.auto_generada, false));

  -- Regla 5 · lo que alguien quitó a mano no vuelve
  delete from _apo_plan p
   where exists (select 1 from public.entrenos_auto_borrados b
                  where b.horario_id = p.horario_id and b.fecha = p.fecha);

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

  if p_simular then
    drop table if exists _apo_plan;
    return query select v_crea, v_act, v_bor, v_int, v_salt, v_desde, v_hasta, true;
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

  drop table if exists _apo_plan;
  return query select v_crea, v_act, v_bor, v_int, v_salt, v_desde, v_hasta, false;
end;
$$;

comment on function public.generar_entrenos_fijos(date, date, uuid, boolean, boolean) is
  'Publica en el calendario los entrenos fijos de los grupos. Idempotente. Nunca toca lo que ha hecho una persona.';

-- Volver a poner un día que alguien había quitado.
create or replace function public.entreno_auto_restaurar(p_horario uuid, p_fecha date)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.es_admin() then
    raise exception 'Solo el administrador puede restaurar entrenos';
  end if;
  delete from public.entrenos_auto_borrados where horario_id = p_horario and fecha = p_fecha;
  return found;
end;
$$;


-- =====================================================================
-- 8 · CARRERAS DE LA LIGA · se proponen, no se publican solas
-- ---------------------------------------------------------------------
-- La diferencia con los entrenos es a propósito: un entreno no tiene
-- nada que decidir; una prueba comunicada por un socio puede estar mal
-- escrita o ser de otro club. Por eso aquí hace falta un clic.
-- =====================================================================
alter table public.liga_propuestas_prueba
  add column if not exists competicion_id uuid references public.competiciones(id) on delete set null,
  add column if not exists publicada_en   timestamptz;

create or replace function public.liga_publicar_propuesta(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  p       record;
  v_comp  uuid;
  v_ambito text;
begin
  if auth.uid() is not null and not public.es_staff() then
    raise exception 'Solo el equipo del club puede publicar carreras';
  end if;

  select * into p from public.liga_propuestas_prueba where id = p_id;
  if not found then raise exception 'Esa carrera propuesta ya no está'; end if;
  if p.estado = 'descartada' then raise exception 'Esa carrera está descartada'; end if;
  if p.fecha is null then
    raise exception 'La carrera no tiene fecha. Ponle fecha antes de publicarla.';
  end if;

  -- Ya publicada: no se duplica (se puede pulsar dos veces sin miedo).
  if p.competicion_id is not null
     and exists (select 1 from public.competiciones c where c.id = p.competicion_id) then
    return p.competicion_id;
  end if;

  v_ambito := case when lower(coalesce(p.disciplina, '')) like '%nataci%'
                     or lower(coalesce(p.disciplina, '')) like '%aguas%'
                     or lower(coalesce(p.disciplina, '')) like '%travesia%'
                   then 'natacion' else 'atletismo' end;

  -- Si ya existe una competición con ese nombre y ese día, se reutiliza.
  select c.id into v_comp
    from public.competiciones c
   where c.fecha_inicio = p.fecha
     and lower(public.apo_sin_tildes(btrim(c.nombre))) = lower(public.apo_sin_tildes(btrim(p.nombre)))
   limit 1;

  if v_comp is null then
    insert into public.competiciones
          (nombre, sede, fecha_inicio, ambito, circular_url, notas, creado_por, inscripcion_abierta)
    values (btrim(p.nombre),
            nullif(btrim(coalesce(p.lugar, '')), ''),
            p.fecha,
            v_ambito,
            nullif(btrim(coalesce(p.enlace, '')), ''),
            'Carrera de la Liga comunicada por un socio del club.',
            public.mi_perfil_id(),
            false)
    returning id into v_comp;
  end if;

  update public.liga_propuestas_prueba
     set estado = 'aceptada', competicion_id = v_comp, publicada_en = now()
   where id = p_id;

  return v_comp;
end;
$$;

-- «Publicar las N de golpe». Las que no tienen fecha se quedan como
-- están: sin fecha no hay dónde ponerlas en el calendario.
create or replace function public.liga_publicar_pendientes()
returns table (publicadas integer, sin_fecha integer)
language plpgsql
security definer
set search_path = public
as $$
declare r record; n int := 0; s int := 0;
begin
  if auth.uid() is not null and not public.es_staff() then
    raise exception 'Solo el equipo del club puede publicar carreras';
  end if;
  for r in select id, fecha from public.liga_propuestas_prueba
            where estado = 'pendiente' order by fecha nulls last, created_at loop
    if r.fecha is null then s := s + 1; continue; end if;
    perform public.liga_publicar_propuesta(r.id);
    n := n + 1;
  end loop;
  return query select n, s;
end;
$$;


-- =====================================================================
-- 9 · «SOLO LO MÍO» · un campo de áreas por persona
-- ---------------------------------------------------------------------
-- Isabel no tiene que ver lesiones; Adrián no tiene que ver recibos
-- devueltos. Sin este campo, el interruptor se escondía con los admin
-- porque no había forma de saber qué le toca a cada quien.
-- Vacío o nulo = le toca todo (es lo de antes).
-- =====================================================================
alter table public.perfiles
  add column if not exists areas text[];

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'perfiles_areas_check') then
    alter table public.perfiles
      add constraint perfiles_areas_check
      check (areas is null or areas <@ array['personas','dinero','web','liga','club']::text[]);
  end if;
end $$;

comment on column public.perfiles.areas is
  'Qué le toca a esta persona en la bandeja del panel: personas, dinero, web, liga, club. Nulo = todo.';

-- Las áreas las reparte el club, no cada uno para sí.
create or replace function public.perfiles_protege_areas()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.es_admin() then
    new.areas := old.areas;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_perfiles_protege_areas on public.perfiles;
create trigger trg_perfiles_protege_areas
  before update on public.perfiles
  for each row execute function public.perfiles_protege_areas();


-- =====================================================================
-- 10 · EL RESUMEN QUE LEE EL PANEL
-- =====================================================================
create or replace function public.automatizacion_resumen()
returns table (
  activo              boolean,
  semanas_vista       integer,
  grupos_con_horario  integer,
  franjas_activas     integer,
  sesiones_semana     integer,
  publicadas_futuras  integer,
  tocadas             integer,
  quitadas_a_mano     integer,
  excepciones_proximas integer,
  ultima_publicada    date,
  propuestas_liga     integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(public.automatizacion_ajuste('entrenos_activo','si'),'si') = 'si',
    coalesce(nullif(public.automatizacion_ajuste('semanas_vista','6'),'')::int, 6),
    (select count(distinct h.grupo_id)::int from public.grupo_horarios h
      join public.grupos g on g.id = h.grupo_id
     where h.activo and coalesce(g.activo,true) and coalesce(g.seccion,'') <> 'cubo'),
    (select count(*)::int from public.grupo_horarios h
      join public.grupos g on g.id = h.grupo_id
     where h.activo and coalesce(g.activo,true) and coalesce(g.seccion,'') <> 'cubo'),
    (select count(*)::int from public.grupo_horarios h
      join public.grupos g on g.id = h.grupo_id
     where h.activo and coalesce(g.activo,true) and coalesce(g.seccion,'') <> 'cubo'),
    (select count(*)::int from public.sesiones s
      where s.auto_generada and s.fecha >= current_date),
    (select count(*)::int from public.sesiones s
      where s.auto_generada and s.auto_tocada and s.fecha >= current_date),
    (select count(*)::int from public.entrenos_auto_borrados b where b.fecha >= current_date),
    (select count(*)::int from public.calendario_excepciones e
      where e.activa and coalesce(e.fecha_fin, e.fecha) >= current_date),
    (select max(s.fecha) from public.sesiones s where s.auto_generada),
    (select count(*)::int from public.liga_propuestas_prueba where estado = 'pendiente');
$$;

-- Lo que se va a publicar, día a día: para poder mirarlo antes.
create or replace function public.entrenos_previstos(p_desde date default null, p_hasta date default null)
returns table (
  fecha       date,
  hora        time,
  grupo       text,
  seccion     text,
  lugar       text,
  estado      text
)
language sql
stable
security definer
set search_path = public
as $$
  with rango as (
    select coalesce(p_desde, current_date) as d1,
           coalesce(p_hasta, current_date + 13) as d2
  )
  select gs.d::date,
         h.hora_inicio,
         g.nombre,
         g.seccion,
         nullif(coalesce(h.lugar,''), ''),
         case
           when public.hay_excepcion(gs.d::date, g.id, g.seccion, coalesce(h.lugar,'')) then 'excepcion'
           when exists (select 1 from public.sesiones s
                         where s.auto_horario_id = h.id and s.fecha = gs.d::date and s.auto_tocada) then 'tocada'
           when exists (select 1 from public.entrenos_auto_borrados b
                         where b.horario_id = h.id and b.fecha = gs.d::date) then 'quitada'
           when exists (select 1 from public.sesiones s
                         where s.grupo_id = g.id and s.fecha = gs.d::date and not coalesce(s.auto_generada,false)) then 'a_mano'
           when exists (select 1 from public.sesiones s
                         where s.auto_horario_id = h.id and s.fecha = gs.d::date) then 'publicada'
           else 'pendiente'
         end
    from public.grupo_horarios h
    join public.grupos g on g.id = h.grupo_id
    cross join rango r
    cross join lateral generate_series(r.d1::timestamp, r.d2::timestamp, interval '1 day') as gs(d)
   where h.activo and coalesce(g.activo,true) and coalesce(g.seccion,'') <> 'cubo'
     and extract(isodow from gs.d)::int = h.dia_semana
   order by 1, 2, 3;
$$;


-- =====================================================================
-- 11 · RLS · quién ve y quién escribe
-- =====================================================================
alter table public.automatizaciones_ajustes  enable row level security;
alter table public.grupo_horarios            enable row level security;
alter table public.calendario_excepciones    enable row level security;
alter table public.entrenos_auto_borrados    enable row level security;

drop policy if exists "ajustes lee el equipo"        on public.automatizaciones_ajustes;
drop policy if exists "ajustes gestiona el admin"    on public.automatizaciones_ajustes;
create policy "ajustes lee el equipo" on public.automatizaciones_ajustes
  for select to authenticated using (public.es_staff());
create policy "ajustes gestiona el admin" on public.automatizaciones_ajustes
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "horarios lee el equipo"       on public.grupo_horarios;
drop policy if exists "horarios gestiona el admin"   on public.grupo_horarios;
create policy "horarios lee el equipo" on public.grupo_horarios
  for select to authenticated using (public.es_staff());
create policy "horarios gestiona el admin" on public.grupo_horarios
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "excepciones lee el equipo"     on public.calendario_excepciones;
drop policy if exists "excepciones gestiona el admin" on public.calendario_excepciones;
create policy "excepciones lee el equipo" on public.calendario_excepciones
  for select to authenticated using (public.es_staff());
create policy "excepciones gestiona el admin" on public.calendario_excepciones
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "borrados lee el equipo"       on public.entrenos_auto_borrados;
drop policy if exists "borrados gestiona el admin"   on public.entrenos_auto_borrados;
create policy "borrados lee el equipo" on public.entrenos_auto_borrados
  for select to authenticated using (public.es_staff());
create policy "borrados gestiona el admin" on public.entrenos_auto_borrados
  for all to authenticated using (public.es_admin()) with check (public.es_admin());


-- =====================================================================
-- 12 · PERMISOS · Supabase regala; aquí se quita y se da lo justo
-- ---------------------------------------------------------------------
-- No basta con las políticas: hay que mirar los GRANT de verdad.
-- Un anónimo no tiene nada que hacer en ninguna de estas tablas: los
-- horarios ya los ve en /horarios/ (que lee `grupos.horario`) y los
-- entrenos publicados en la vista curada `sesiones_agenda`.
-- =====================================================================
revoke all on public.automatizaciones_ajustes from anon, authenticated;
revoke all on public.grupo_horarios           from anon, authenticated;
revoke all on public.calendario_excepciones   from anon, authenticated;
revoke all on public.entrenos_auto_borrados   from anon, authenticated;

grant select                         on public.automatizaciones_ajustes to authenticated;
grant select, insert, update         on public.grupo_horarios           to authenticated;
grant select, insert, update, delete on public.calendario_excepciones   to authenticated;
grant select, delete                 on public.entrenos_auto_borrados   to authenticated;
grant update                         on public.automatizaciones_ajustes to authenticated;

-- Funciones: ninguna abierta al público sin cuenta.
revoke all on function public.apo_sin_tildes(text)                                   from public, anon, authenticated;
revoke all on function public.apo_dia_indice(text)                                   from public, anon, authenticated;
revoke all on function public.apo_dia_nombre(smallint)                               from public, anon, authenticated;
revoke all on function public.apo_hora(text)                                         from public, anon, authenticated;
revoke all on function public.horario_lugar(text)                                    from public, anon, authenticated;
revoke all on function public.horario_matiz(text)                                    from public, anon, authenticated;
revoke all on function public.horario_franjas(text)                                  from public, anon, authenticated;
revoke all on function public.hay_excepcion(date, uuid, text, text)                  from public, anon, authenticated;
revoke all on function public.automatizacion_ajuste(text, text)                      from public, anon, authenticated;
revoke all on function public.sincronizar_horarios_grupo(uuid)                       from public, anon, authenticated;
revoke all on function public.sincronizar_horarios_todos()                           from public, anon, authenticated;
revoke all on function public.generar_entrenos_fijos(date, date, uuid, boolean, boolean) from public, anon, authenticated;
revoke all on function public.entreno_auto_restaurar(uuid, date)                     from public, anon, authenticated;
revoke all on function public.liga_publicar_propuesta(uuid)                          from public, anon, authenticated;
revoke all on function public.liga_publicar_pendientes()                             from public, anon, authenticated;
revoke all on function public.automatizacion_resumen()                               from public, anon, authenticated;
revoke all on function public.entrenos_previstos(date, date)                          from public, anon, authenticated;

-- Solo lo que el panel necesita llamar desde el navegador, y con cuenta.
grant execute on function public.sincronizar_horarios_todos()                           to authenticated;
grant execute on function public.generar_entrenos_fijos(date, date, uuid, boolean, boolean) to authenticated;
grant execute on function public.entreno_auto_restaurar(uuid, date)                     to authenticated;
grant execute on function public.liga_publicar_propuesta(uuid)                          to authenticated;
grant execute on function public.liga_publicar_pendientes()                             to authenticated;
grant execute on function public.automatizacion_resumen()                               to authenticated;
grant execute on function public.entrenos_previstos(date, date)                          to authenticated;
-- (cada una comprueba por dentro es_admin() o es_staff(): el GRANT solo
--  abre la puerta, quien decide es la función.)


-- =====================================================================
-- 13 · PRIMERA LECTURA DE LOS HORARIOS QUE YA HAY
-- ---------------------------------------------------------------------
-- Esto NO publica nada: solo pasa el texto de cada grupo a franjas.
-- Publicar es un botón del panel (o `select public.generar_entrenos_fijos()`).
-- =====================================================================
select public.sincronizar_horarios_todos();
