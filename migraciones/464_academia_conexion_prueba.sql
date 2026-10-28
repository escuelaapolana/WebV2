-- =====================================================================
-- 464 · Academia: conexión de PRUEBA con ChatGPT + seguimiento por atleta
--       + feedback que vuelve a «pendiente» si cambia después de revisarlo.
--
-- 28-oct-2026 · Autorizado por Andrés: crear las tablas y la función de la
-- conexión con acceso SOLO al grupo PRUEBA (datos ficticios). Sin datos
-- reales y sin publicación en la Academia real: la API rechaza cualquier
-- grupo que no esté marcado es_prueba en academia_grupos, aunque la clave
-- lo incluyera (§D, academia_api_grupos).
--
-- A. registros_sesion.revision_anterior_*: si el atleta modifica su feedback
--    después de revisado, vuelve a pendiente y queda quién revisó lo anterior
--    (además del historial completo en registros_sesion_versiones).
-- B. academia_seguimiento: por atleta, feedback del atleta (por defecto) ·
--    registro del entrenador · feedback no requerido. No excluye a nadie ni
--    borra nada. La elección de cada persona la hace Andrés.
-- C. academia_registros_entrenador: lo que registra el ENTRENADOR (declaración
--    u observación suya). No es el feedback del atleta: sin RPE ni sensaciones.
-- D. API para ChatGPT (servidor MCP en la Edge academia-mcp): claves con hash,
--    envíos idempotentes, registro de llamadas y operaciones en una sola
--    función (academia_api) que solo puede ejecutar service_role.
-- =====================================================================
begin;

-- ---------------------------------------------------------------------
-- A. Feedback cambiado después de revisarlo
-- ---------------------------------------------------------------------
alter table public.registros_sesion
  add column if not exists revision_anterior_en  timestamptz,
  add column if not exists revision_anterior_por uuid;
comment on column public.registros_sesion.revision_anterior_en is
  'Cuándo se revisó la versión ANTERIOR de este registro, si el atleta lo cambió después (entonces vuelve a pendiente). El historial completo está en registros_sesion_versiones.';
comment on column public.registros_sesion.revision_anterior_por is
  'Quién revisó la versión anterior del registro (perfil).';

create or replace function public.registros_proteger_revision() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  -- 1) El atleta cambia lo que contó después de que se revisara: vuelve a
  --    «pendiente de revisar» y se guarda quién revisó la versión anterior.
  if old.revisado_en is not null
     and new.revisado_en is not distinct from old.revisado_en
     and new.revisado_por is not distinct from old.revisado_por
     and (   new.tiempos_reales        is distinct from old.tiempos_reales
          or new.sensacion_general     is distinct from old.sensacion_general
          or new.rpe                   is distinct from old.rpe
          or new.como_me_siento        is distinct from old.como_me_siento
          or new.molestias             is distinct from old.molestias
          or new.notas_atleta          is distinct from old.notas_atleta
          or new.horas_sueno           is distinct from old.horas_sueno
          or new.peso_kg               is distinct from old.peso_kg
          or new.motivo_no_hecho       is distinct from old.motivo_no_hecho
          or new.nota_no_hecho         is distinct from old.nota_no_hecho
          or new.estado                is distinct from old.estado
          or new.completado_pct        is distinct from old.completado_pct
          or new.molestia_sesion       is distinct from old.molestia_sesion
          or new.molestia_localizacion is distinct from old.molestia_localizacion
          or new.superficie            is distinct from old.superficie
          or new.momento               is distinct from old.momento
          or new.duracion_min          is distinct from old.duracion_min
          or new.marcas_texto          is distinct from old.marcas_texto) then
    new.revision_anterior_en  := old.revisado_en;
    new.revision_anterior_por := old.revisado_por;
    new.revisado_en  := null;
    new.revisado_por := null;
    return new;
  end if;
  -- 2) Solo el entrenador del atleta o un admin marcan «revisado».
  if (new.revisado_en is distinct from old.revisado_en or new.revisado_por is distinct from old.revisado_por)
     and not (public.es_admin() or public.soy_admin_de_verdad() or public.soy_entrenador_de(new.atleta_id)
              or (auth.jwt() ->> 'email') is null) then
    new.revisado_en := old.revisado_en; new.revisado_por := old.revisado_por;
  end if;
  -- 3) El rastro de la revisión anterior no se toca desde la app.
  if (new.revision_anterior_en is distinct from old.revision_anterior_en
      or new.revision_anterior_por is distinct from old.revision_anterior_por)
     and (auth.jwt() ->> 'email') is not null then
    new.revision_anterior_en := old.revision_anterior_en; new.revision_anterior_por := old.revision_anterior_por;
  end if;
  return new;
end $$;

-- El historial de correcciones no cuenta como «cambio» marcar o desmarcar revisado.
create or replace function public.registros_guardar_anterior() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  v_cambios text[];
  v_n       int;
begin
  if coalesce(current_setting('apolana.purga', true), '') = '1' then
    return null;
  end if;
  if tg_op = 'UPDATE' then
    select array_agg(k order by k) into v_cambios
      from jsonb_each(to_jsonb(new)) n(k, val)
     where k not in ('corregido_en','corregido_veces','revisado_en','revisado_por','revision_anterior_en','revision_anterior_por')
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

-- ---------------------------------------------------------------------
-- B. Seguimiento por atleta
-- ---------------------------------------------------------------------
create table if not exists public.academia_seguimiento (
  atleta_id    uuid primary key references public.atletas(id) on delete cascade,
  grupo_id     uuid not null references public.grupos(id) on delete cascade,
  modo         text not null default 'feedback_atleta'
               check (modo in ('feedback_atleta','registro_entrenador','no_requerido')),
  cambiado_por uuid,
  cambiado_en  timestamptz not null default now()
);
comment on table public.academia_seguimiento is
  'Cómo se sigue a cada atleta de Academia: feedback_atleta (por defecto, sin fila) · registro_entrenador (lo registra el entrenador) · no_requerido. No excluye a nadie ni borra datos.';
alter table public.academia_seguimiento enable row level security;
create policy "academia gestiona el seguimiento" on public.academia_seguimiento for all to authenticated
  using (public.academia_puede(grupo_id))
  with check (public.academia_puede(grupo_id)
              and exists (select 1 from public.atletas a where a.id = atleta_id and a.grupo_id = academia_seguimiento.grupo_id));
grant select, insert, update, delete on public.academia_seguimiento to authenticated;

create or replace function public.academia_seguimiento_firma() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  new.cambiado_por := public.mi_perfil_id();
  new.cambiado_en  := now();
  return new;
end $$;
create trigger trg_academia_seguimiento_firma before insert or update on public.academia_seguimiento
  for each row execute function public.academia_seguimiento_firma();

-- ---------------------------------------------------------------------
-- C. Registro del entrenador (declaración u observación suya)
-- ---------------------------------------------------------------------
create table if not exists public.academia_registros_entrenador (
  id              uuid primary key default gen_random_uuid(),
  sesion_id       uuid not null references public.sesiones(id) on delete restrict,
  atleta_id       uuid not null references public.atletas(id) on delete cascade,
  estado          text not null check (estado in ('completo','a_medias','no_hecho')),
  completado_pct  integer check (completado_pct is null or completado_pct between 0 and 100),
  nota            text check (nota is null or length(nota) <= 1000),
  sesion_version  integer not null,
  autor_perfil_id uuid,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  unique (sesion_id, atleta_id)
);
comment on table public.academia_registros_entrenador is
  'Lo que REGISTRA EL ENTRENADOR de una sesión (fuente: declaración/observación del entrenador). No es el feedback del atleta: no lleva RPE ni sensaciones, y no se mezcla con registros_sesion.';
alter table public.academia_registros_entrenador enable row level security;
create policy "academia gestiona registros del entrenador" on public.academia_registros_entrenador for all to authenticated
  using (exists (select 1 from public.sesiones s where s.id = sesion_id and public.academia_puede(s.grupo_id)))
  with check (exists (select 1 from public.sesiones s where s.id = sesion_id and public.academia_puede(s.grupo_id)
                      and atleta_id = any (s.atletas_ids)));
grant select, insert, update, delete on public.academia_registros_entrenador to authenticated;

create or replace function public.academia_registro_entrenador_firma() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  -- Queda atado a la versión de la sesión que había al registrarlo.
  select s.version into new.sesion_version from public.sesiones s where s.id = new.sesion_id;
  new.autor_perfil_id := coalesce(public.mi_perfil_id(), new.autor_perfil_id);
  new.actualizado_en  := now();
  if tg_op = 'INSERT' then new.creado_en := now(); end if;
  if new.estado <> 'a_medias' then new.completado_pct := null; end if;
  return new;
end $$;
create trigger trg_academia_registro_entrenador_firma before insert or update on public.academia_registros_entrenador
  for each row execute function public.academia_registro_entrenador_firma();

-- ---------------------------------------------------------------------
-- D. Conexión de prueba con ChatGPT
-- ---------------------------------------------------------------------
create table if not exists public.api_claves (
  id            uuid primary key default gen_random_uuid(),
  nombre        text not null,
  hash          text not null unique check (hash ~ '^[0-9a-f]{64}$'),   -- sha256 de la clave; la clave no se guarda
  grupos        uuid[] not null,
  permisos      text[] not null default '{leer}',
  creada_por    uuid,
  creada_en     timestamptz not null default now(),
  revocada_en   timestamptz,
  ultimo_uso_en timestamptz
);
comment on table public.api_claves is
  'Claves de la API de Academia (conexión con ChatGPT). Solo se guarda el sha256. Permisos: leer · borradores · revisiones · publicar_prueba. Mientras dure la prueba, la API solo deja tocar grupos es_prueba aunque la clave diga otra cosa.';
create table if not exists public.api_envios (
  clave_id        uuid not null references public.api_claves(id) on delete cascade,
  envio_id        text not null check (length(envio_id) between 1 and 100),
  operacion       text not null,
  peticion_huella text not null,
  respuesta       jsonb not null,
  creado_en       timestamptz not null default now(),
  primary key (clave_id, envio_id)
);
comment on table public.api_envios is
  'Envíos ya procesados (idempotencia): repetir el mismo envio_id con lo mismo devuelve la respuesta guardada y no repite nada.';
create table if not exists public.api_registro (
  id        bigserial primary key,
  clave_id  uuid references public.api_claves(id) on delete set null,
  operacion text,
  ok        boolean,
  detalle   text,
  creado_en timestamptz not null default now()
);
create table if not exists public.api_sesiones_cliente (
  clave_id      uuid not null references public.api_claves(id) on delete cascade,
  clave_cliente text not null check (length(clave_cliente) between 1 and 80),
  sesion_id     uuid not null references public.sesiones(id) on delete cascade,
  creado_en     timestamptz not null default now(),
  primary key (clave_id, clave_cliente)
);
comment on table public.api_sesiones_cliente is
  'Identificador estable que pone ChatGPT a cada sesión nueva (clave_cliente) → la sesión creada. Reenviarla no la duplica.';
alter table public.api_claves enable row level security;
alter table public.api_envios enable row level security;
alter table public.api_registro enable row level security;
alter table public.api_sesiones_cliente enable row level security;
revoke all on public.api_claves, public.api_envios, public.api_registro, public.api_sesiones_cliente from anon, authenticated;
revoke all on sequence public.api_registro_id_seq from anon, authenticated;

-- Huella del CONTENIDO de una sesión (sin ids de fila ni publicación): sirve
-- para comprobar que se publica exactamente la versión revisada.
create or replace function public.academia_huella(d jsonb) returns text
language sql immutable set search_path to 'public' as $$
  select md5(jsonb_strip_nulls(jsonb_build_object(
    'fecha', d->'fecha', 'atletas_ids', d->'atletas_ids', 'clase_dia', d->'clase_dia',
    'momento', d->'momento', 'hora', d->'hora', 'duracion_min', d->'duracion_min',
    'titulo', d->'titulo', 'objetivo', d->'objetivo',
    'exigencia', d->'exigencia', 'exigencia_neuro', d->'exigencia_neuro', 'exigencia_meta', d->'exigencia_meta',
    'nota_razonamiento', d->'nota_razonamiento',
    'bloques', (select coalesce(jsonb_agg(
                  case when jsonb_typeof(b->'filas') = 'array'
                       then b || jsonb_build_object('filas', (select coalesce(jsonb_agg(case when jsonb_typeof(f) = 'object' then f - 'id' else f end), '[]'::jsonb)
                                                               from jsonb_array_elements(b->'filas') f))
                       else b end), '[]'::jsonb)
                from jsonb_array_elements(case when jsonb_typeof(d->'bloques') = 'array' then d->'bloques' else '[]'::jsonb end) b)
  ))::text)
$$;

-- Grupos que la clave puede tocar: los suyos Y marcados como prueba.
create or replace function public.academia_api_grupos(p_clave public.api_claves) returns uuid[]
language sql stable security definer set search_path to 'public' as $$
  select coalesce(array_agg(ag.grupo_id), '{}')
    from public.academia_grupos ag
   where ag.es_prueba and ag.grupo_id = any (p_clave.grupos)
$$;

-- Bloques que llegan de ChatGPT → forma de la app (guion, solo marcar).
-- Acepta filas como texto o como {ejercicio, detalle}.
create or replace function public.academia_api_bloques(p jsonb) returns jsonb
language plpgsql immutable set search_path to 'public' as $$
declare v_out jsonb := '[]'::jsonb; b jsonb; f jsonb; v_filas jsonb;
begin
  if p is null or jsonb_typeof(p) <> 'array' then raise exception 'bloques debe ser una lista'; end if;
  for b in select * from jsonb_array_elements(p) loop
    if jsonb_typeof(b) <> 'object' then raise exception 'cada bloque es {etiqueta, filas}'; end if;
    v_filas := '[]'::jsonb;
    for f in select * from jsonb_array_elements(coalesce(b->'filas', '[]'::jsonb)) loop
      if jsonb_typeof(f) = 'string' then
        if length(trim(f #>> '{}')) > 0 then v_filas := v_filas || jsonb_build_array(jsonb_build_object('ejercicio', trim(f #>> '{}'))); end if;
      elsif jsonb_typeof(f) = 'object' and length(trim(coalesce(f->>'ejercicio',''))) > 0 then
        v_filas := v_filas || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
          'ejercicio', trim(f->>'ejercicio'), 'detalle', nullif(trim(coalesce(f->>'detalle','')), ''))));
      end if;
    end loop;
    if jsonb_array_length(v_filas) = 0 then continue; end if;
    v_out := v_out || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'etiqueta', coalesce(nullif(trim(coalesce(b->>'etiqueta','')), ''), 'Sesión'),
      'lista', 'guion', 'solo_marcar', true, 'filas', v_filas,
      'nota_pie', nullif(trim(coalesce(b->>'nota','')), ''))));
  end loop;
  if jsonb_array_length(v_out) = 0 then raise exception 'la sesión no tiene contenido'; end if;
  return v_out;
end $$;

-- Vista de una sesión para ChatGPT: plan y estado, SIN datos de salud
-- (ni molestias, ni comentarios del atleta, ni motivos de ausencia).
create or replace function public.academia_api_sesion_json(s public.sesiones) returns jsonb
language sql stable security definer set search_path to 'public' as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'sesion_id', s.id, 'version', s.version, 'huella', public.academia_huella(to_jsonb(s)),
    'fecha', s.fecha, 'momento', s.momento, 'hora', to_char(s.hora, 'HH24:MI'), 'duracion_min', s.duracion_min,
    'atleta_ids', to_jsonb(s.atletas_ids), 'tipo_dia', s.clase_dia,
    'estado_publicacion', case when s.publicada then 'publicada' else 'borrador' end,
    'titulo', s.titulo, 'objetivo', s.objetivo,
    'exigencia', jsonb_strip_nulls(jsonb_build_object('global', s.exigencia, 'neuromuscular', s.exigencia_neuro, 'metabolica', s.exigencia_meta)),
    'bloques', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                    'etiqueta', b->>'etiqueta',
                    'filas', (select coalesce(jsonb_agg(case when jsonb_typeof(f) = 'object'
                                   then concat_ws(' — ', f->>'ejercicio', nullif(f->>'detalle','')) else f #>> '{}' end), '[]'::jsonb)
                                from jsonb_array_elements(coalesce(b->'filas','[]'::jsonb)) f),
                    'nota', b->>'nota_pie'))), '[]'::jsonb)
                from jsonb_array_elements(coalesce(s.bloques, '[]'::jsonb)) b),
    'sustituye_a', s.sustituye_a,
    'revision_pendiente', (select jsonb_build_object('revision_id', r.id, 'version_base', r.version_base, 'motivo', r.motivo, 'via', r.via)
                             from public.sesiones_revisiones r where r.sesion_id = s.id and r.estado = 'pendiente' order by r.creada_en desc limit 1),
    'registros', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                     'atleta_id', r.atleta_id, 'fuente', 'atleta',
                     'estado', case r.estado when 'completo' then 'realizada' when 'a_medias' then 'parcial' when 'no_hecho' then 'no_realizada' end,
                     'completado_pct', r.completado_pct, 'rpe', r.rpe, 'duracion_min', r.duracion_min,
                     'version_respondida', r.version_vista, 'revisado', r.revisado_en is not null))), '[]'::jsonb)
                    from public.registros_sesion r where r.sesion_id = s.id)
                 || (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                     'atleta_id', e.atleta_id, 'fuente', 'entrenador',
                     'estado', case e.estado when 'completo' then 'realizada' when 'a_medias' then 'parcial' when 'no_hecho' then 'no_realizada' end,
                     'completado_pct', e.completado_pct, 'version_registrada', e.sesion_version))), '[]'::jsonb)
                    from public.academia_registros_entrenador e where e.sesion_id = s.id)
  ))
$$;

-- Normaliza lo que manda ChatGPT para una sesión (nueva o cambios).
-- Devuelve las columnas como jsonb con los mismos tipos que to_jsonb(sesiones).
create or replace function public.academia_api_campos(p jsonb) returns jsonb
language plpgsql stable set search_path to 'public' as $$
declare o jsonb := '{}'::jsonb; v text; ex jsonb;
begin
  if p ? 'titulo' then
    v := trim(coalesce(p->>'titulo',''));
    if v = '' or length(v) > 120 then raise exception 'titulo vacío o demasiado largo'; end if;
    o := o || jsonb_build_object('titulo', v);
  end if;
  if p ? 'objetivo' then
    v := nullif(trim(coalesce(p->>'objetivo','')), '');
    if length(v) > 80 then raise exception 'objetivo: máximo 80 caracteres'; end if;
    o := o || jsonb_build_object('objetivo', v);
  end if;
  ex := case when jsonb_typeof(p->'exigencia') = 'object' then p->'exigencia' else null end;
  if ex is not null then
    if ex ? 'global' then o := o || jsonb_build_object('exigencia', nullif(ex->>'global','')); end if;
    if ex ? 'neuromuscular' then o := o || jsonb_build_object('exigencia_neuro', nullif(ex->>'neuromuscular','')); end if;
    if ex ? 'metabolica' then o := o || jsonb_build_object('exigencia_meta', nullif(ex->>'metabolica','')); end if;
  elsif p ? 'exigencia' then
    o := o || jsonb_build_object('exigencia', nullif(p->>'exigencia',''));
  end if;
  if exists (select 1 from jsonb_each_text(o) e where e.key like 'exigencia%' and e.value is not null and e.value not in ('baja','media','alta')) then
    raise exception 'exigencia: baja, media o alta';
  end if;
  if p ? 'momento' then
    v := coalesce(nullif(p->>'momento',''), 'unica');
    if v not in ('unica','manana','tarde','sin_especificar') then raise exception 'momento: unica, manana, tarde o sin_especificar'; end if;
    o := o || jsonb_build_object('momento', v);
  end if;
  if p ? 'hora' then o := o || jsonb_build_object('hora', to_jsonb((nullif(p->>'hora',''))::time)); end if;
  if p ? 'duracion_min' then o := o || jsonb_build_object('duracion_min', to_jsonb((nullif(p->>'duracion_min',''))::int)); end if;
  if p ? 'tipo_dia' then
    v := coalesce(nullif(p->>'tipo_dia',''), 'entreno');
    if v not in ('entreno','descanso') then raise exception 'tipo_dia: entreno o descanso'; end if;
    o := o || jsonb_build_object('clase_dia', v);
  end if;
  if p ? 'nota_entrenador' then o := o || jsonb_build_object('nota_razonamiento', nullif(trim(coalesce(p->>'nota_entrenador','')), '')); end if;
  if p ? 'bloques' then o := o || jsonb_build_object('bloques', public.academia_api_bloques(p->'bloques')); end if;
  return o;
end $$;

create or replace function public.academia_api(p_hash text, p_operacion text, p_args jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare
  k        public.api_claves%rowtype;
  a        jsonb := coalesce(p_args, '{}'::jsonb);
  v_grupos uuid[];
  v_grupo  uuid;
  v_res    jsonb;
  v_envio  text;
  v_huella text;
  v_prev   public.api_envios%rowtype;
  v_hoy    date := (now() at time zone 'Europe/Madrid')::date;
  v_desde  date; v_hasta date;
  s        public.sesiones%rowtype;
  it       jsonb;
  v_items  jsonb := '[]'::jsonb;
  v_conf   jsonb := '[]'::jsonb;
  v_campos jsonb; v_nuevo jsonb; v_id uuid; v_atleta uuid; v_fecha date; v_cc text; v_vb int;
  v_n      int;
  v_escribe boolean := p_operacion in ('guardar_borradores','proponer_revision','publicar_prueba');
begin
  select * into k from public.api_claves where hash = lower(coalesce(p_hash,'')) and revocada_en is null;
  if k.id is null then
    return jsonb_build_object('ok', false, 'error', 'clave_no_valida', 'mensaje', 'La clave no es válida o está revocada.');
  end if;
  update public.api_claves set ultimo_uso_en = now() where id = k.id;
  perform set_config('apolana.autor', left('chatgpt · ' || k.nombre, 120), true);
  v_grupos := public.academia_api_grupos(k);

  -- Permiso por operación
  if (p_operacion in ('estado','leer_semana','leer_sesion','consultar_borradores') and not ('leer' = any (k.permisos)))
     or (p_operacion = 'guardar_borradores' and not ('borradores' = any (k.permisos)))
     or (p_operacion = 'proponer_revision' and not ('revisiones' = any (k.permisos)))
     or (p_operacion = 'publicar_prueba' and not ('publicar_prueba' = any (k.permisos))) then
    v_res := jsonb_build_object('ok', false, 'error', 'sin_permiso', 'mensaje', 'Esta clave no tiene permiso para ' || p_operacion || '.');
    insert into public.api_registro (clave_id, operacion, ok, detalle) values (k.id, p_operacion, false, 'sin_permiso');
    return v_res;
  end if;

  -- Idempotencia de las escrituras: mismo envio_id + mismo contenido = misma respuesta, sin repetir nada.
  if v_escribe then
    v_envio := nullif(trim(coalesce(a->>'envio_id','')), '');
    if v_envio is null then
      return jsonb_build_object('ok', false, 'error', 'falta_envio_id', 'mensaje', 'Las escrituras necesitan un envio_id único por petición (reutilízalo solo para reintentar exactamente lo mismo).');
    end if;
    v_huella := md5((a - 'envio_id')::text);
    select * into v_prev from public.api_envios where clave_id = k.id and envio_id = v_envio;
    if v_prev.clave_id is not null then
      if v_prev.operacion = p_operacion and v_prev.peticion_huella = v_huella then
        insert into public.api_registro (clave_id, operacion, ok, detalle) values (k.id, p_operacion, true, 'repetido ' || v_envio);
        return v_prev.respuesta || jsonb_build_object('repetido', true,
          'nota', 'Este envío ya se había procesado el ' || to_char(v_prev.creado_en at time zone 'Europe/Madrid', 'DD-MM-YYYY HH24:MI') || ': no se ha repetido nada.');
      end if;
      return jsonb_build_object('ok', false, 'error', 'envio_id_reutilizado',
        'mensaje', 'Ese envio_id ya se usó con otro contenido. Usa un envio_id nuevo para una petición distinta.');
    end if;
  end if;

  begin
    -- ---------------- estado ----------------
    if p_operacion = 'estado' then
      v_res := jsonb_build_object('ok', true, 'clave', k.nombre, 'permisos', to_jsonb(k.permisos), 'hoy', v_hoy,
        'grupos', (select coalesce(jsonb_agg(jsonb_build_object('grupo_id', g.id, 'nombre', g.nombre, 'datos_ficticios', true)), '[]'::jsonb)
                     from public.grupos g where g.id = any (v_grupos)),
        'reglas', jsonb_build_array(
          'Prueba con datos ficticios: solo grupos marcados de prueba. Nada de datos reales ni de salud.',
          'Guardar borradores solo cuando el usuario lo pida expresamente (esa petición es la autorización).',
          'Cada sesión nueva lleva una clave_cliente estable; cada petición de escritura, un envio_id nuevo.',
          'Para cambiar un borrador: sesion_id + version_base. Si la versión no coincide, hay un cambio concurrente: vuelve a leer.',
          'Una sesión publicada no se toca: se propone una revisión (queda pendiente para el entrenador).',
          'Publicar solo si el usuario lo pide, pasando la version y la huella exactas que se revisaron.',
          'No inventar la clasificación de una sesión ni calcular volúmenes: eso aún no está definido.'));

    -- ---------------- leer_semana ----------------
    elsif p_operacion = 'leer_semana' then
      v_grupo := coalesce(nullif(a->>'grupo_id','')::uuid, case when array_length(v_grupos,1) = 1 then v_grupos[1] end);
      if v_grupo is null or not (v_grupo = any (v_grupos)) then raise exception 'grupo_no_permitido'; end if;
      v_fecha := coalesce(nullif(a->>'fecha','')::date, v_hoy);
      v_desde := v_fecha - (extract(isodow from v_fecha)::int - 1);
      v_hasta := v_desde + 6;
      v_res := jsonb_build_object('ok', true,
        'grupo', (select jsonb_build_object('grupo_id', g.id, 'nombre', g.nombre) from public.grupos g where g.id = v_grupo),
        'semana', jsonb_build_object('desde', v_desde, 'hasta', v_hasta),
        'atletas', (select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                        'atleta_id', at.id, 'nombre', coalesce(nullif(at.nombre_corto,''), at.nombre),
                        'pruebas', to_jsonb(at.pruebas_principales),
                        'seguimiento', coalesce((select sg.modo from public.academia_seguimiento sg where sg.atleta_id = at.id), 'feedback_atleta')))
                      order by at.nombre), '[]'::jsonb)
                      from public.atletas at where at.grupo_id = v_grupo and coalesce(at.estado, 'activo') = 'activo'),
        'sesiones', (select coalesce(jsonb_agg(public.academia_api_sesion_json(x) order by x.fecha, x.momento, x.hora), '[]'::jsonb)
                       from public.sesiones x where x.grupo_id = v_grupo and x.archivada_en is null and x.fecha between v_desde and v_hasta),
        'ausencias', (select coalesce(jsonb_agg(jsonb_build_object('atleta_id', au.atleta_id, 'fecha', au.fecha, 'sesion_id', au.sesion_id)), '[]'::jsonb)
                        from public.ausencias au join public.atletas at on at.id = au.atleta_id
                       where at.grupo_id = v_grupo and au.fecha between v_desde and v_hasta));

    -- ---------------- leer_sesion ----------------
    elsif p_operacion = 'leer_sesion' then
      select * into s from public.sesiones where id = nullif(a->>'sesion_id','')::uuid;
      if s.id is null or not (s.grupo_id = any (v_grupos)) then raise exception 'sesion_no_encontrada'; end if;
      v_res := jsonb_build_object('ok', true, 'sesion', public.academia_api_sesion_json(s),
        'archivada', s.archivada_en is not null,
        'versiones', (select coalesce(jsonb_agg(jsonb_build_object('version', v.version, 'evento', v.evento,
                          'desde', v.vigente_desde, 'via', v.via, 'huella', public.academia_huella(v.datos),
                          'publicada', coalesce((v.datos->>'publicada')::boolean, false)) order by v.version), '[]'::jsonb)
                        from public.sesiones_versiones v where v.sesion_id = s.id),
        'revisiones', (select coalesce(jsonb_agg(jsonb_build_object('revision_id', r.id, 'version_base', r.version_base,
                          'estado', r.estado, 'motivo', r.motivo, 'via', r.via, 'creada_en', r.creada_en, 'resultado', r.resultado)
                          order by r.creada_en), '[]'::jsonb)
                        from public.sesiones_revisiones r where r.sesion_id = s.id));

    -- ---------------- consultar_borradores ----------------
    elsif p_operacion = 'consultar_borradores' then
      v_grupo := coalesce(nullif(a->>'grupo_id','')::uuid, case when array_length(v_grupos,1) = 1 then v_grupos[1] end);
      if v_grupo is null or not (v_grupo = any (v_grupos)) then raise exception 'grupo_no_permitido'; end if;
      v_desde := coalesce(nullif(a->>'desde','')::date, v_hoy - 7);
      v_hasta := coalesce(nullif(a->>'hasta','')::date, v_hoy + 28);
      v_res := jsonb_build_object('ok', true, 'desde', v_desde, 'hasta', v_hasta,
        'borradores', (select coalesce(jsonb_agg(public.academia_api_sesion_json(x)
                          || jsonb_strip_nulls(jsonb_build_object('clave_cliente', (select c.clave_cliente from public.api_sesiones_cliente c where c.sesion_id = x.id and c.clave_id = k.id)))
                          order by x.fecha, x.momento), '[]'::jsonb)
                         from public.sesiones x where x.grupo_id = v_grupo and not x.publicada and x.archivada_en is null
                          and x.fecha between v_desde and v_hasta));

    -- ---------------- guardar_borradores ----------------
    elsif p_operacion = 'guardar_borradores' then
      if jsonb_typeof(a->'sesiones') <> 'array' or jsonb_array_length(a->'sesiones') = 0 then raise exception 'sesiones: lista vacía'; end if;
      if jsonb_array_length(a->'sesiones') > 60 then raise exception 'sesiones: máximo 60 por envío'; end if;
      -- 1) Validar TODO antes de escribir nada.
      for it in select * from jsonb_array_elements(a->'sesiones') loop
        v_cc := nullif(trim(coalesce(it->>'clave_cliente','')), '');
        v_id := nullif(it->>'sesion_id','')::uuid;
        v_vb := nullif(it->>'version_base','')::int;
        if v_id is null and v_cc is not null then
          select c.sesion_id into v_id from public.api_sesiones_cliente c where c.clave_id = k.id and c.clave_cliente = v_cc;
        end if;
        v_campos := public.academia_api_campos(it);
        if v_id is null then
          -- Sesión NUEVA
          if v_cc is null then raise exception 'cada sesión nueva necesita clave_cliente'; end if;
          v_grupo := coalesce(nullif(it->>'grupo_id','')::uuid, case when array_length(v_grupos,1) = 1 then v_grupos[1] end);
          if v_grupo is null or not (v_grupo = any (v_grupos)) then raise exception 'grupo_no_permitido'; end if;
          v_atleta := nullif(it->>'atleta_id','')::uuid;
          if v_atleta is null or not exists (select 1 from public.atletas at where at.id = v_atleta and at.grupo_id = v_grupo) then
            raise exception 'atleta_id no pertenece al grupo (clave_cliente %)', v_cc;
          end if;
          v_fecha := nullif(it->>'fecha','')::date;
          if v_fecha is null then raise exception 'falta fecha (clave_cliente %)', v_cc; end if;
          if not (v_campos ? 'titulo') then raise exception 'falta titulo (clave_cliente %)', v_cc; end if;
          if not (v_campos ? 'bloques') then raise exception 'faltan bloques (clave_cliente %)', v_cc; end if;
          v_nuevo := jsonb_build_object('clase_dia', 'entreno', 'momento', 'unica') || v_campos
                     || jsonb_build_object('fecha', to_jsonb(v_fecha), 'atletas_ids', to_jsonb(array[v_atleta]), 'grupo_id', v_grupo);
          v_items := v_items || jsonb_build_array(jsonb_build_object('accion', 'crear', 'clave_cliente', v_cc, 'datos', v_nuevo));
        else
          select * into s from public.sesiones where id = v_id;
          if s.id is null or not (s.grupo_id = any (v_grupos)) then raise exception 'sesion_no_encontrada'; end if;
          if s.archivada_en is not null then
            v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'clave_cliente', v_cc, 'conflicto', 'archivada'));
            continue;
          end if;
          if (nullif(it->>'fecha','') is not null and (it->>'fecha')::date <> s.fecha)
             or (nullif(it->>'atleta_id','') is not null and not ((it->>'atleta_id')::uuid = any (s.atletas_ids))) then
            v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'clave_cliente', v_cc, 'conflicto', 'otra_fecha_o_atleta',
                         'mensaje', 'Esa sesión es de otro día u otro atleta. Moverla o cambiar de atleta es SUSTITUIR, no revisar: crea otra con clave_cliente nueva.'));
            continue;
          end if;
          v_nuevo := to_jsonb(s) || v_campos;
          if public.academia_huella(v_nuevo) = public.academia_huella(to_jsonb(s)) then
            v_items := v_items || jsonb_build_array(jsonb_build_object('accion', 'sin_cambios', 'sesion_id', s.id, 'clave_cliente', v_cc,
                          'version', s.version, 'huella', public.academia_huella(to_jsonb(s)),
                          'estado_publicacion', case when s.publicada then 'publicada' else 'borrador' end));
          elsif s.publicada then
            v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'clave_cliente', v_cc, 'conflicto', 'publicada',
                         'mensaje', 'Está publicada: no se cambia. Usa proponer_revision.', 'version_actual', s.version));
          elsif v_vb is null then
            v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'clave_cliente', v_cc, 'conflicto', 'ya_existe',
                         'mensaje', 'Ya existe y su contenido es distinto. Para cambiarla, manda version_base con la versión que leíste.',
                         'version_actual', s.version, 'huella_actual', public.academia_huella(to_jsonb(s))));
          elsif v_vb <> s.version then
            v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'clave_cliente', v_cc, 'conflicto', 'version',
                         'mensaje', 'Cambio concurrente: la sesión va por la versión ' || s.version || ' y tu cambio parte de la ' || v_vb || '. Vuelve a leerla.',
                         'version_actual', s.version, 'huella_actual', public.academia_huella(to_jsonb(s))));
          else
            v_items := v_items || jsonb_build_array(jsonb_build_object('accion', 'actualizar', 'sesion_id', s.id, 'clave_cliente', v_cc,
                          'version_base', v_vb, 'campos', v_campos));
          end if;
        end if;
      end loop;
      if jsonb_array_length(v_conf) > 0 then
        v_res := jsonb_build_object('ok', false, 'error', 'conflictos', 'mensaje', 'No se ha guardado nada: hay conflictos.', 'conflictos', v_conf);
      else
        -- 2) Escribir.
        v_conf := '[]'::jsonb;
        for it in select * from jsonb_array_elements(v_items) loop
          if it->>'accion' = 'crear' then
            v_nuevo := it->'datos';
            insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_neuro, exigencia_meta,
                                         clase_dia, momento, hora, duracion_min, nota_razonamiento, bloques, publicada,
                                         tipo, deporte, generado_por_ia, creado_por)
            values ((v_nuevo->>'grupo_id')::uuid, array[(v_nuevo->'atletas_ids'->>0)::uuid], (v_nuevo->>'fecha')::date,
                    v_nuevo->>'titulo', v_nuevo->>'objetivo', v_nuevo->>'exigencia', v_nuevo->>'exigencia_neuro', v_nuevo->>'exigencia_meta',
                    v_nuevo->>'clase_dia', v_nuevo->>'momento', (v_nuevo->>'hora')::time, (v_nuevo->>'duracion_min')::int,
                    v_nuevo->>'nota_razonamiento', v_nuevo->'bloques', false,
                    case when v_nuevo->>'clase_dia' = 'descanso' then 'descanso' else 'pista' end, 'atletismo', true, k.creada_por)
            returning * into s;
            insert into public.api_sesiones_cliente (clave_id, clave_cliente, sesion_id) values (k.id, it->>'clave_cliente', s.id);
            v_conf := v_conf || jsonb_build_array(jsonb_build_object('accion', 'creada', 'clave_cliente', it->>'clave_cliente',
                         'sesion_id', s.id, 'version', s.version, 'huella', public.academia_huella(to_jsonb(s)), 'estado_publicacion', 'borrador'));
          elsif it->>'accion' = 'actualizar' then
            v_campos := it->'campos';
            update public.sesiones set
              titulo            = case when v_campos ? 'titulo' then v_campos->>'titulo' else titulo end,
              objetivo          = case when v_campos ? 'objetivo' then v_campos->>'objetivo' else objetivo end,
              exigencia         = case when v_campos ? 'exigencia' then v_campos->>'exigencia' else exigencia end,
              exigencia_neuro   = case when v_campos ? 'exigencia_neuro' then v_campos->>'exigencia_neuro' else exigencia_neuro end,
              exigencia_meta    = case when v_campos ? 'exigencia_meta' then v_campos->>'exigencia_meta' else exigencia_meta end,
              clase_dia         = case when v_campos ? 'clase_dia' then v_campos->>'clase_dia' else clase_dia end,
              momento           = case when v_campos ? 'momento' then v_campos->>'momento' else momento end,
              hora              = case when v_campos ? 'hora' then (v_campos->>'hora')::time else hora end,
              duracion_min      = case when v_campos ? 'duracion_min' then (v_campos->>'duracion_min')::int else duracion_min end,
              nota_razonamiento = case when v_campos ? 'nota_razonamiento' then v_campos->>'nota_razonamiento' else nota_razonamiento end,
              bloques           = case when v_campos ? 'bloques' then v_campos->'bloques' else bloques end
            where id = (it->>'sesion_id')::uuid and version = (it->>'version_base')::int and not publicada
            returning * into s;
            get diagnostics v_n = row_count;
            if v_n <> 1 then raise exception 'concurrente'; end if;
            v_conf := v_conf || jsonb_build_array(jsonb_build_object('accion', 'actualizada', 'clave_cliente', it->>'clave_cliente',
                         'sesion_id', s.id, 'version', s.version, 'huella', public.academia_huella(to_jsonb(s)), 'estado_publicacion', 'borrador'));
          else
            v_conf := v_conf || jsonb_build_array(it);
          end if;
        end loop;
        v_res := jsonb_build_object('ok', true, 'resultados', v_conf,
          'nota', 'Guardado como BORRADOR: los atletas no lo ven hasta que se publique.');
      end if;

    -- ---------------- proponer_revision ----------------
    elsif p_operacion = 'proponer_revision' then
      select * into s from public.sesiones where id = nullif(a->>'sesion_id','')::uuid;
      if s.id is null or not (s.grupo_id = any (v_grupos)) then raise exception 'sesion_no_encontrada'; end if;
      v_vb := nullif(a->>'version_base','')::int;
      v_campos := public.academia_api_campos(coalesce(a->'cambios', '{}'::jsonb));
      if s.archivada_en is not null then
        v_res := jsonb_build_object('ok', false, 'error', 'archivada', 'mensaje', 'La sesión está archivada.');
      elsif not s.publicada then
        v_res := jsonb_build_object('ok', false, 'error', 'es_borrador', 'mensaje', 'Es un borrador: cámbiala con guardar_borradores (sesion_id + version_base).');
      elsif v_vb is null or v_vb <> s.version then
        v_res := jsonb_build_object('ok', false, 'error', 'conflicto_version',
          'mensaje', 'Cambio concurrente: la sesión va por la versión ' || s.version || coalesce(' y la propuesta parte de la ' || v_vb, '') || '. Vuelve a leerla.',
          'version_actual', s.version, 'huella_actual', public.academia_huella(to_jsonb(s)));
      elsif v_campos = '{}'::jsonb or public.academia_huella(to_jsonb(s) || v_campos) = public.academia_huella(to_jsonb(s)) then
        v_res := jsonb_build_object('ok', false, 'error', 'sin_cambios', 'mensaje', 'La propuesta no cambia nada de la sesión.');
      elsif exists (select 1 from public.sesiones_revisiones r where r.sesion_id = s.id and r.estado = 'pendiente') then
        v_res := jsonb_build_object('ok', false, 'error', 'ya_hay_revision_pendiente',
          'mensaje', 'Ya hay una revisión pendiente de esta sesión: el entrenador tiene que aplicarla o descartarla antes.',
          'revision_id', (select r.id from public.sesiones_revisiones r where r.sesion_id = s.id and r.estado = 'pendiente' limit 1));
      else
        insert into public.sesiones_revisiones (sesion_id, version_base, propuesta, motivo, autor_perfil_id, via)
        values (s.id, s.version, v_campos, left(nullif(trim(coalesce(a->>'motivo','')), ''), 300), k.creada_por, 'chatgpt')
        returning id into v_id;
        v_res := jsonb_build_object('ok', true, 'revision_id', v_id, 'sesion_id', s.id, 'version_base', s.version,
          'huella_propuesta', public.academia_huella(to_jsonb(s) || v_campos),
          'nota', 'Revisión PENDIENTE: el entrenador la aplica (pasará a la versión ' || (s.version + 1) || ') o la descarta desde el panel.');
      end if;

    -- ---------------- publicar_prueba ----------------
    elsif p_operacion = 'publicar_prueba' then
      if jsonb_typeof(a->'sesiones') <> 'array' or jsonb_array_length(a->'sesiones') = 0 then raise exception 'sesiones: lista vacía'; end if;
      for it in select * from jsonb_array_elements(a->'sesiones') loop
        select * into s from public.sesiones where id = nullif(it->>'sesion_id','')::uuid for update;
        if s.id is null or not (s.grupo_id = any (v_grupos)) then raise exception 'sesion_no_encontrada'; end if;
        if s.publicada then
          v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'conflicto', 'ya_publicada', 'version_actual', s.version));
        elsif s.archivada_en is not null then
          v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'conflicto', 'archivada'));
        elsif nullif(it->>'version','')::int is distinct from s.version
              or coalesce(it->>'huella','') <> public.academia_huella(to_jsonb(s)) then
          v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'conflicto', 'no_es_la_version_revisada',
                       'mensaje', 'La sesión no coincide con la versión revisada: no se publica.',
                       'version_revisada', it->'version', 'huella_revisada', it->'huella',
                       'version_actual', s.version, 'huella_actual', public.academia_huella(to_jsonb(s))));
        end if;
      end loop;
      if jsonb_array_length(v_conf) > 0 then
        v_res := jsonb_build_object('ok', false, 'error', 'conflictos', 'mensaje', 'No se ha publicado nada.', 'conflictos', v_conf);
      else
        for it in select * from jsonb_array_elements(a->'sesiones') loop
          update public.sesiones set publicada = true
           where id = (it->>'sesion_id')::uuid and version = (it->>'version')::int and not publicada
          returning * into s;
          get diagnostics v_n = row_count;
          if v_n <> 1 then raise exception 'concurrente'; end if;
          -- Comprobación de punta a punta: la versión que queda guardada en el
          -- historial al publicar tiene exactamente el contenido revisado.
          v_conf := v_conf || jsonb_build_array(jsonb_build_object(
            'sesion_id', s.id, 'version_revisada', (it->>'version')::int, 'version_publicada', s.version,
            'huella_revisada', it->>'huella',
            'huella_publicada', (select public.academia_huella(v.datos) from public.sesiones_versiones v where v.sesion_id = s.id and v.version = s.version),
            'coincide', (select public.academia_huella(v.datos) from public.sesiones_versiones v where v.sesion_id = s.id and v.version = s.version) = it->>'huella'));
        end loop;
        if exists (select 1 from jsonb_array_elements(v_conf) x where not (x->>'coincide')::boolean) then
          raise exception 'la versión publicada no coincide con la revisada';
        end if;
        v_res := jsonb_build_object('ok', true, 'publicadas', v_conf,
          'nota', 'Publicadas en el grupo de PRUEBA. Cada una es exactamente la versión revisada (misma huella).');
      end if;

    else
      v_res := jsonb_build_object('ok', false, 'error', 'operacion_desconocida', 'mensaje', 'Operación no reconocida: ' || coalesce(p_operacion, '—'));
    end if;
  exception when others then
    v_res := jsonb_build_object('ok', false,
      'error', case when sqlerrm = 'concurrente' then 'conflicto_version'
                    when sqlerrm in ('grupo_no_permitido','sesion_no_encontrada') then sqlerrm else 'datos_no_validos' end,
      'mensaje', case when sqlerrm = 'concurrente' then 'Cambio concurrente mientras se guardaba: no se ha guardado nada. Vuelve a leer.'
                      when sqlerrm = 'grupo_no_permitido' then 'Ese grupo no está permitido (en esta prueba, solo el grupo de PRUEBA).'
                      when sqlerrm = 'sesion_no_encontrada' then 'No existe esa sesión en los grupos permitidos.'
                      else sqlerrm end);
  end;

  if v_escribe and coalesce((v_res->>'ok')::boolean, false) then
    insert into public.api_envios (clave_id, envio_id, operacion, peticion_huella, respuesta)
    values (k.id, v_envio, p_operacion, v_huella, v_res);
  end if;
  insert into public.api_registro (clave_id, operacion, ok, detalle)
  values (k.id, p_operacion, coalesce((v_res->>'ok')::boolean, false), left(coalesce(v_res->>'error', v_envio, ''), 200));
  return v_res;
end $$;

revoke all on function public.academia_api(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.academia_api(text, text, jsonb) to service_role;
revoke all on function public.academia_api_grupos(public.api_claves) from public, anon, authenticated;
revoke all on function public.academia_api_sesion_json(public.sesiones) from public, anon, authenticated;
revoke all on function public.academia_api_campos(jsonb) from public, anon, authenticated;
revoke all on function public.academia_api_bloques(jsonb) from public, anon, authenticated;

commit;

-- La clave de ChatGPT NO se crea aquí: la genera Andrés en su Mac con
-- herramientas/academia-mcp-activar.sh (queda en el Llavero; aquí solo su sha256).
-- Revocar una clave:  update api_claves set revocada_en = now() where nombre = '…';
