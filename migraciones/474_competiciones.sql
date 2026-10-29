-- ===========================================================================
-- 474 · Competiciones del grupo y pendientes de configuración
-- ---------------------------------------------------------------------------
--   1) Temporadas de planificación: provisionales hasta que alguien las
--      confirme, con historial. Cambiar sus fechas no reasigna nada: los
--      objetivos guardan su temporada y los resultados, su fecha.
--   2) Catálogo: decisiones caso a caso (un uso concreto de un texto en un
--      perfil, una marca, un objetivo o una inscripción). Lo ambiguo no admite
--      una equivalencia global; tampoco un texto con usos que ya se han
--      decidido distinto. El texto original no se toca nunca.
--   3) Protocolos: tipo de formulario (carrera, salto, lanzamiento, fuerza,
--      otro) y «completo» solo cuando una persona lo marca y no le falta nada
--      para comparar. Nada se asigna a resultados antiguos.
--   4) Competiciones (el calendario y las inscripciones de siempre):
--      · la competición guarda su estado (programada, aplazada, cancelada) y
--        el historial de fechas y sede;
--      · competicion_plan: prioridad A/B/C (significado configurable en
--        competicion_prioridades) y propósito, por atleta y competición;
--      · competicion_atleta (una fila por prueba): previsto, pendiente de
--        confirmar, confirmado/inscrito, realizado, no participó, cancelado;
--        horario si se conoce; nada se borra desde Academia;
--      · marcas_atleta enlaza con la inscripción y separa resultado oficial y
--        tiempo tomado por el entrenador.
--   5) Mínimas: prueba, categoría, condiciones, campeonato, validez, fuente y
--      fecha de comprobación; «pendiente» si no están publicadas.
-- ===========================================================================
begin;

-- 1 · Temporadas: provisionales y con historial ---------------------------------------------
alter table public.temporadas_planificacion
  add column confirmada boolean not null default false,
  add column version    int not null default 1,
  add column historial  jsonb not null default '[]';

create or replace function public.temporadas_historial() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if (old.inicio, old.fin, old.confirmada, coalesce(old.nota,'')) is distinct from (new.inicio, new.fin, new.confirmada, coalesce(new.nota,'')) then
    new.historial := old.historial || jsonb_build_array(jsonb_build_object(
      'inicio', old.inicio, 'fin', old.fin, 'confirmada', old.confirmada, 'nota', old.nota,
      'cambiado_en', now(), 'cambiado_por', public.mi_perfil_id(), 'motivo', nullif(current_setting('apolana.motivo', true), '')));
    new.version := old.version + 1; new.actualizado_en := now(); new.actualizado_por := public.mi_perfil_id();
  end if;
  return new;
end $$;
create trigger trg_temporadas_historial before update on public.temporadas_planificacion
  for each row execute function public.temporadas_historial();
alter table public.temporadas_planificacion add constraint temporadas_fechas_check check (fin > inicio);

-- 2 · Catálogo: decisiones caso a caso -------------------------------------------------------
create table public.pruebas_correspondencia_usos (
  id           uuid primary key default gen_random_uuid(),
  texto_norm   text not null,
  origen       text not null check (origen in ('perfil','marcas','objetivos','competiciones')),
  registro_id  uuid not null,              -- perfil: la ficha del atleta; si no, la fila de su tabla
  atleta_id    uuid references public.atletas(id) on delete cascade,
  decision     text not null check (decision in ('prueba','no_es_prueba')),
  prueba_ids   uuid[] not null default '{}',
  condiciones  jsonb not null default '{}',
  nota         text,
  version      int not null default 1,
  revisado_por uuid,
  revisado_en  timestamptz not null default now(),
  historial    jsonb not null default '[]',
  unique (origen, registro_id, texto_norm),
  check (decision = 'no_es_prueba' or cardinality(prueba_ids) >= 1),
  check (decision = 'prueba' or cardinality(prueba_ids) = 0),
  check (origen = 'perfil' or cardinality(prueba_ids) <= 1)   -- «100 y 200» en un perfil son dos pruebas
);
create index pruebas_correspondencia_usos_atleta on public.pruebas_correspondencia_usos (atleta_id);
comment on table public.pruebas_correspondencia_usos is 'Qué prueba es un texto en un uso concreto. No cambia el texto original; en marcas, objetivos e inscripciones también rellena su prueba_id.';

-- Dónde aparece un texto (ya normalizado), con la decisión de cada uso.
create or replace function public.prueba_correspondencia_usos(p_texto_norm text) returns jsonb
language plpgsql stable security definer set search_path to 'public' as $$
declare v jsonb;
begin
  if not public.puede_catalogo_tests() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  with t as (
    select 'perfil'::text origen, a.id registro_id, a.id atleta_id, x.texto, x.campo, null::uuid prueba_id, null::date fecha, null::text valor
      from public.atletas a,
           lateral (select btrim(u) texto, 'principal' campo from unnest(a.pruebas_principales) u
                    union all select btrim(u), 'secundaria' from unnest(coalesce(a.pruebas_secundarias, '{}')) u) x
    union all select 'marcas', m.id, m.atleta_id, btrim(m.prueba), coalesce(m.contexto, m.tipo), m.prueba_id, m.fecha, m.tiempo_display from public.marcas_atleta m
    union all select 'objetivos', o.id, o.atleta_id, btrim(o.prueba), o.tipo, o.prueba_id, null, o.objetivo_texto from public.atleta_objetivos o
    union all select 'competiciones', c.id, c.atleta_id, btrim(c.prueba), c.estado, c.prueba_id, k.fecha_inicio, k.nombre
      from public.competicion_atleta c left join public.competiciones k on k.id = c.competicion_id where c.prueba is not null
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'origen', t.origen, 'registro_id', t.registro_id, 'atleta_id', t.atleta_id, 'texto', t.texto, 'campo', t.campo,
           'prueba_id', t.prueba_id, 'fecha', t.fecha, 'valor', t.valor, 'grupo', g.nombre,
           'atleta', case when public.soy_admin_de_verdad() or public.academia_puede_atleta(t.atleta_id) or public.soy_entrenador_de(t.atleta_id)
                          then coalesce(nullif(btrim(coalesce(a.nombre,'') || ' ' || coalesce(a.apellidos,'')), ''), '(sin nombre)') end,
           'decision', case when u.id is not null then jsonb_build_object('id', u.id, 'decision', u.decision, 'prueba_ids', u.prueba_ids, 'condiciones', u.condiciones,
                                                                          'nota', u.nota, 'version', u.version, 'revisado_en', u.revisado_en, 'historial', u.historial) end)
         order by t.origen, a.nombre, t.fecha), '[]'::jsonb) into v
    from t left join public.atletas a on a.id = t.atleta_id
           left join public.grupos g on g.id = a.grupo_id
           left join public.pruebas_correspondencia_usos u on u.origen = t.origen and u.registro_id = t.registro_id and u.texto_norm = p_texto_norm
   where coalesce(t.texto, '') <> ''
     and public.prueba_normalizar(regexp_replace(t.texto, '\s*\([0-9.,\s]+\)\s*$', '')) = p_texto_norm;
  return v;
end $$;

-- Decide un uso. p = {texto_norm, origen, registro_id, decision prueba|no_es_prueba, prueba_ids[], condiciones, nota, version_base}
create or replace function public.prueba_correspondencia_uso_resolver(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare v_n text := p->>'texto_norm'; v_or text := p->>'origen'; v_reg uuid := nullif(p->>'registro_id','')::uuid; v_dec text := p->>'decision';
        v_ids uuid[]; v_at uuid; v_txt text; v_pid uuid; u public.pruebas_correspondencia_usos%rowtype; v_ant uuid;
begin
  if not public.puede_catalogo_tests() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if v_dec not in ('prueba','no_es_prueba') then raise exception 'Decisión no válida.'; end if;
  v_ids := coalesce(array(select jsonb_array_elements_text(coalesce(p->'prueba_ids','[]'::jsonb))::uuid), '{}');
  if v_dec = 'no_es_prueba' then v_ids := '{}'; end if;
  if v_dec = 'prueba' and cardinality(v_ids) = 0 then raise exception 'Elige la prueba del catálogo.'; end if;
  if exists (select 1 from unnest(v_ids) x where not exists (select 1 from public.pruebas where id = x)) then raise exception 'Esa prueba no está en el catálogo.'; end if;
  if v_or <> 'perfil' and cardinality(v_ids) > 1 then raise exception 'Un resultado, un objetivo o una inscripción son de una sola prueba.'; end if;
  -- El uso tiene que existir y su texto tiene que ser ese.
  if v_or = 'perfil' then
    select id into v_at from public.atletas a where a.id = v_reg
       and exists (select 1 from unnest(a.pruebas_principales || coalesce(a.pruebas_secundarias,'{}')) x
                    where public.prueba_normalizar(regexp_replace(btrim(x), '\s*\([0-9.,\s]+\)\s*$', '')) = v_n);
  elsif v_or = 'marcas' then select atleta_id, prueba, prueba_id into v_at, v_txt, v_pid from public.marcas_atleta where id = v_reg;
  elsif v_or = 'objetivos' then select atleta_id, prueba, prueba_id into v_at, v_txt, v_pid from public.atleta_objetivos where id = v_reg;
  elsif v_or = 'competiciones' then select atleta_id, prueba, prueba_id into v_at, v_txt, v_pid from public.competicion_atleta where id = v_reg;
  else raise exception 'Origen no válido.'; end if;
  if v_at is null or (v_or <> 'perfil' and public.prueba_normalizar(regexp_replace(btrim(v_txt), '\s*\([0-9.,\s]+\)\s*$', '')) <> v_n) then
    raise exception 'Ese uso ya no existe o su texto ha cambiado: vuelve a abrir la lista.';
  end if;
  select * into u from public.pruebas_correspondencia_usos where origen = v_or and registro_id = v_reg and texto_norm = v_n for update;
  if u.id is not null and nullif(p->>'version_base','')::int is distinct from u.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla ha decidido este uso: vuelve a abrir la lista. No se ha pisado nada.');
  end if;
  -- La prueba que pusimos antes (si la pusimos) es la única que se puede cambiar en el registro.
  v_ant := case when u.id is not null and u.decision = 'prueba' then u.prueba_ids[1] end;
  if v_or <> 'perfil' and v_pid is not null and v_pid is distinct from v_ant and v_pid is distinct from v_ids[1] then
    raise exception 'Ese registro ya tiene otra prueba asignada: corrígelo desde su pantalla.';
  end if;
  perform set_config('apolana.motivo', 'Catálogo: decidido caso a caso («' || v_n || '»)', true);
  if v_or = 'marcas' then update public.marcas_atleta set prueba_id = v_ids[1] where id = v_reg and prueba_id is distinct from v_ids[1];
  elsif v_or = 'objetivos' then update public.atleta_objetivos set prueba_id = v_ids[1] where id = v_reg and prueba_id is distinct from v_ids[1];
  elsif v_or = 'competiciones' then update public.competicion_atleta set prueba_id = v_ids[1] where id = v_reg and prueba_id is distinct from v_ids[1];
  end if;
  if u.id is null then
    insert into public.pruebas_correspondencia_usos (texto_norm, origen, registro_id, atleta_id, decision, prueba_ids, condiciones, nota, revisado_por)
    values (v_n, v_or, v_reg, v_at, v_dec, v_ids, coalesce(p->'condiciones','{}'::jsonb), nullif(btrim(coalesce(p->>'nota','')),''), public.mi_perfil_id())
    returning * into u;
  else
    update public.pruebas_correspondencia_usos
       set historial = historial || jsonb_build_array(jsonb_build_object('decision', decision, 'prueba_ids', prueba_ids, 'condiciones', condiciones, 'nota', nota,
                                                                        'revisado_por', revisado_por, 'revisado_en', revisado_en)),
           decision = v_dec, prueba_ids = v_ids, condiciones = coalesce(p->'condiciones','{}'::jsonb), nota = nullif(btrim(coalesce(p->>'nota','')),''),
           version = version + 1, revisado_por = public.mi_perfil_id(), revisado_en = now()
     where id = u.id returning * into u;
  end if;
  return jsonb_build_object('ok', true, 'uso', to_jsonb(u));
end $$;

-- La equivalencia global (alias) no vale para lo ambiguo ni si algún uso ya se decidió distinto.
create or replace function public.prueba_correspondencia_resolver(p_id uuid, p_prueba uuid, p_descartar boolean default false, p_alias boolean default true)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare pc public.pruebas_correspondencias%rowtype;
begin
  if not public.puede_catalogo_tests() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into pc from public.pruebas_correspondencias where id = p_id for update;
  if pc.id is null then raise exception 'No existe esa correspondencia.'; end if;
  if pc.estado = 'ambigua' then
    raise exception '«%» puede significar pruebas distintas: decide cada uso por separado.', pc.texto;
  end if;
  if p_descartar then
    if exists (select 1 from public.pruebas_correspondencia_usos where texto_norm = pc.texto_norm and decision = 'prueba') then
      raise exception 'Algún uso de «%» ya se decidió como prueba: decide los demás por separado.', pc.texto;
    end if;
    update public.pruebas_correspondencias set estado = 'descartada', revisado_por = public.mi_perfil_id(), revisado_en = now() where id = p_id;
    return jsonb_build_object('ok', true, 'estado', 'descartada');
  end if;
  if p_prueba is null or not exists (select 1 from public.pruebas where id = p_prueba) then raise exception 'Elige una prueba del catálogo.'; end if;
  if exists (select 1 from public.pruebas_correspondencia_usos where texto_norm = pc.texto_norm and (decision <> 'prueba' or prueba_ids <> array[p_prueba])) then
    raise exception 'Algún uso de «%» ya se decidió de otra manera: no se aplica a todos. Decide los demás por separado.', pc.texto;
  end if;
  update public.pruebas_correspondencias set estado = 'confirmada', prueba_id = p_prueba, revisado_por = public.mi_perfil_id(), revisado_en = now(),
         motivo = 'Confirmada por una persona para todos sus usos' where id = p_id;
  if p_alias and pc.estado <> 'exacta' then
    insert into public.pruebas_alias (alias, alias_norm, prueba_id, creado_por) values (pc.texto, pc.texto_norm, p_prueba, public.mi_perfil_id())
    on conflict (alias_norm) do update set prueba_id = excluded.prueba_id;
  end if;
  return jsonb_build_object('ok', true, 'estado', 'confirmada');
end $$;

-- 3 · Protocolos: tipo de formulario y «completo» ------------------------------------------
alter table public.test_protocolos
  add column tipo text check (tipo in ('carrera','salto','lanzamiento','fuerza','otro')),
  add column completo boolean not null default false,
  add column completo_por uuid,
  add column completo_en timestamptz;
comment on column public.test_protocolos.tipo is 'Qué formulario le toca. Solo decide qué campos se piden; no rellena ninguno.';
-- El tipo de formulario de los 14 esqueletos sale de lo que miden (se puede cambiar). Su contenido sigue vacío.
update public.test_protocolos set tipo = case
  when magnitud = 'tiempo' then 'carrera'
  when clave in ('abalakov','cmj','sj','drop_jump','rsi','salto_horizontal') then 'salto'
  when clave = 'balon_medicinal' then 'lanzamiento'
  when magnitud in ('carga','repeticiones') then 'fuerza'
  else 'otro' end;

-- Lo que le falta a un protocolo para poder comparar sus resultados (lo mismo que enseña la pantalla).
create or replace function public.protocolo_faltan(p public.test_protocolos) returns text[]
language sql immutable as $$
  select array_remove(array[
    case when p.tipo is null then 'tipo de test' end,
    -- carrera
    case when p.tipo = 'carrera' and p.salida is null then 'salida' end,
    case when p.tipo = 'carrera' and (p.tramo_desde_m is null or p.tramo_hasta_m is null) then 'tramo medido' end,
    case when p.tipo = 'carrera' and p.salida = 'lanzada' and p.distancia_entrada_m is null then 'distancia de entrada' end,
    case when p.tipo = 'carrera' and nullif(p.inicio_crono,'') is null then 'inicio del cronometraje' end,
    case when p.tipo = 'carrera' and nullif(p.fin_crono,'') is null then 'final del cronometraje' end,
    case when p.tipo in ('carrera','salto') and nullif(p.especificos->>'sistema_medida','') is null then 'sistema de medida' end,
    case when p.tipo in ('carrera','salto','lanzamiento') and nullif(p.superficie,'') is null then 'superficie' end,
    case when p.tipo in ('carrera','salto') and nullif(p.calzado,'') is null then 'calzado' end,
    -- salto
    case when p.tipo = 'salto' and nullif(p.especificos->>'variante','') is null then 'cómo es el salto' end,
    case when p.tipo = 'salto' and nullif(p.especificos->>'brazos','') is null then 'brazos' end,
    case when p.tipo = 'salto' and nullif(p.especificos->>'calculo','') is null then 'qué se calcula' end,
    case when p.tipo = 'salto' and nullif(p.especificos->>'caida','') is null then 'si hay caída desde cajón' end,
    case when p.tipo = 'salto' and p.especificos->>'caida' = 'si' and nullif(p.especificos->>'cajon_cm','') is null then 'altura del cajón' end,
    -- lanzamiento
    case when p.tipo = 'lanzamiento' and nullif(p.especificos->>'implemento_kg','') is null then 'peso del implemento' end,
    case when p.tipo = 'lanzamiento' and nullif(p.especificos->>'posicion','') is null then 'posición y técnica' end,
    case when p.tipo = 'lanzamiento' and nullif(p.especificos->>'medicion','') is null then 'desde dónde se mide' end,
    -- fuerza
    case when p.tipo = 'fuerza' and nullif(p.especificos->>'ejercicio','') is null then 'ejercicio' end,
    case when p.tipo = 'fuerza' and nullif(p.especificos->>'variante','') is null then 'variante' end,
    case when p.tipo = 'fuerza' and nullif(p.especificos->>'recorrido','') is null then 'recorrido' end,
    case when p.tipo = 'fuerza' and nullif(p.especificos->>'lateralidad','') is null then 'uni o bilateral' end,
    case when p.tipo = 'fuerza' and nullif(p.especificos->>'criterio_valida','') is null then 'criterio de repetición válida' end,
    case when p.tipo = 'fuerza' and nullif(p.especificos->>'material','') is null then 'material' end,
    -- otro
    case when p.tipo = 'otro' and nullif(p.descripcion,'') is null then 'descripción' end
  ], null);
$$;

create or replace function public.test_protocolos_completo() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if new.completo and cardinality(public.protocolo_faltan(new)) > 0 then
    raise exception 'Aún falta: %. Sin eso no se puede marcar como completo.', array_to_string(public.protocolo_faltan(new), ', ');
  end if;
  if new.completo and (tg_op = 'INSERT' or not old.completo) then new.completo_por := public.mi_perfil_id(); new.completo_en := now(); end if;
  if not new.completo then new.completo_por := null; new.completo_en := null; end if;
  return new;
end $$;
create trigger trg_test_protocolos_completo before insert or update on public.test_protocolos
  for each row execute function public.test_protocolos_completo();

-- 4 · Competiciones ------------------------------------------------------------------------
alter table public.competiciones
  add column estado text not null default 'programada' check (estado in ('programada','aplazada','cancelada')),
  add column version int not null default 1,
  add column historial jsonb not null default '[]',
  add column actualizado_por uuid,
  add column actualizado_en timestamptz;

create or replace function public.competiciones_historial() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if (old.nombre, coalesce(old.sede,''), old.fecha_inicio, old.fecha_fin, old.estado) is distinct from (new.nombre, coalesce(new.sede,''), new.fecha_inicio, new.fecha_fin, new.estado) then
    new.historial := old.historial || jsonb_build_array(jsonb_build_object(
      'nombre', old.nombre, 'sede', old.sede, 'fecha_inicio', old.fecha_inicio, 'fecha_fin', old.fecha_fin, 'estado', old.estado,
      'cambiado_en', now(), 'cambiado_por', public.mi_perfil_id(), 'motivo', nullif(current_setting('apolana.motivo', true), '')));
    new.version := old.version + 1; new.actualizado_en := now(); new.actualizado_por := public.mi_perfil_id();
  end if;
  return new;
end $$;
create trigger trg_competiciones_historial before update on public.competiciones
  for each row execute function public.competiciones_historial();

-- Prioridad A/B/C: su significado se ve y se cambia.
create table public.competicion_prioridades (
  clave           text primary key check (clave in ('A','B','C')),
  nombre          text not null,
  significado     text not null,
  orden           int not null,
  actualizado_por uuid,
  actualizado_en  timestamptz not null default now()
);
insert into public.competicion_prioridades (clave, nombre, significado, orden) values
  ('A', 'Principal',  'Propuesta inicial (edítala): la competición en la que se quiere llegar en la mejor forma.', 1),
  ('B', 'Importante', 'Propuesta inicial (edítala): cuenta y se prepara, sin ajustar toda la planificación a ella.', 2),
  ('C', 'Control',    'Propuesta inicial (edítala): se compite dentro del entrenamiento normal.', 3);

-- Prioridad y propósito de cada atleta en cada competición.
create table public.competicion_plan (
  id              uuid primary key default gen_random_uuid(),
  competicion_id  uuid not null references public.competiciones(id) on delete cascade,
  atleta_id       uuid not null references public.atletas(id) on delete cascade,
  prioridad       text references public.competicion_prioridades(clave),
  proposito       text check (proposito in ('campeonato_objetivo','control','aprendizaje','otro')),
  proposito_texto text,
  nota            text,
  version         int not null default 1,
  creado_por      uuid default public.mi_perfil_id(),
  creado_en       timestamptz not null default now(),
  actualizado_por uuid,
  actualizado_en  timestamptz,
  unique (competicion_id, atleta_id),
  check (proposito is distinct from 'otro' or nullif(btrim(proposito_texto), '') is not null)
);
create index competicion_plan_atleta on public.competicion_plan (atleta_id);
create trigger trg_competicion_plan_versionar before update or delete on public.competicion_plan
  for each row execute function public.resultados_versionar();

-- La prioridad vivía en la inscripción de cada prueba (mig 471, sin usar: 0 filas): pasa al plan.
-- La columna se queda (sin uso) para no romper la ficha publicada antes de este cambio.
comment on column public.competicion_atleta.prioridad is 'Sin uso desde la mig 474: la prioridad de cada atleta está en competicion_plan. Se conserva para no romper pantallas antiguas.';
alter table public.competicion_atleta drop constraint competicion_atleta_estado_check;
alter table public.competicion_atleta add constraint competicion_atleta_estado_check
  check (estado in ('previsto','apuntado','confirmada','realizado','no_participado','cancelada'));
alter table public.competicion_atleta
  add column dia             date,
  add column hora            time,
  add column hora_fin        time,
  add column motivo          text,
  add column version         int not null default 1,
  add column creado_por      uuid,
  add column actualizado_por uuid,
  add column actualizado_en  timestamptz;
comment on column public.competicion_atleta.estado is 'previsto (intención) · apuntado (pendiente de confirmar) · confirmada (confirmado/inscrito) · realizado · no_participado · cancelada';
create trigger trg_competicion_atleta_versionar before update or delete on public.competicion_atleta
  for each row execute function public.resultados_versionar();
grant select (dia, hora, hora_fin, motivo, version, creado_por, actualizado_por, actualizado_en) on public.competicion_atleta to authenticated;

alter table public.resultados_historial drop constraint resultados_historial_tabla_check;
alter table public.resultados_historial add constraint resultados_historial_tabla_check
  check (tabla in ('marcas_atleta','test_resultados','rm_atleta','resultado_parciales','objetivo_parciales','competicion_atleta','competicion_plan'));

-- Resultado de una competición: enlazado a la inscripción; oficial o tomado por el entrenador.
alter table public.marcas_atleta
  add column participacion_id uuid references public.competicion_atleta(id) on delete set null,
  add column oficial boolean,
  add column ronda text check (ronda in ('serie','semifinal','final','unica','otra'));
comment on column public.marcas_atleta.oficial is 'true = resultado oficial (acta); false = tiempo tomado por el entrenador u otro no oficial; null = no consta';
create index marcas_atleta_participacion on public.marcas_atleta (participacion_id);
create unique index marcas_atleta_oficial_unico on public.marcas_atleta (participacion_id, coalesce(ronda, 'unica'))
  where oficial and participacion_id is not null;

-- 5 · Mínimas ------------------------------------------------------------------------------
create table public.minimas (
  id                  uuid primary key default gen_random_uuid(),
  campeonato          text not null,
  competicion_id      uuid references public.competiciones(id) on delete set null,
  temporada_federativa int not null,
  prueba_id           uuid not null references public.pruebas(id),
  categoria           text not null,
  sexo                text check (sexo in ('hombre','mujer')),
  condiciones         jsonb not null default '{}',
  estado              text not null check (estado in ('publicada','pendiente','no_exige')),
  valor               numeric,
  valor_texto         text,
  validez_desde       date,
  validez_hasta       date,
  criterio            text,
  fuente_url          text,
  fuente_texto        text,
  comprobada_en       date,
  nota                text,
  version             int not null default 1,
  autor_perfil_id     uuid,
  creado_en           timestamptz not null default now(),
  actualizado_por     uuid,
  actualizado_en      timestamptz not null default now(),
  historial           jsonb not null default '[]',
  check (estado = 'pendiente' or (comprobada_en is not null and (nullif(btrim(fuente_url),'') is not null or nullif(btrim(fuente_texto),'') is not null))),
  check (estado <> 'publicada' or valor is not null),
  check (estado = 'publicada' or valor is null),
  check (validez_hasta is null or validez_desde is null or validez_hasta >= validez_desde)
);
comment on table public.minimas is 'Mínimas oficiales. «pendiente» = aún no publicadas: no se reutilizan las de otro año. Una marca suficiente no es estar clasificado.';
create unique index minimas_unica on public.minimas (campeonato, temporada_federativa, prueba_id, categoria, coalesce(sexo, ''), condiciones);
create index minimas_competicion on public.minimas (competicion_id);
create trigger trg_minimas_historial before insert or update on public.minimas
  for each row execute function public.academia_ficha_historial();

create or replace function public.minima_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare m public.minimas%rowtype; v_id uuid := nullif(p->>'id','')::uuid; v_pr public.pruebas%rowtype; v_lee jsonb; v_num numeric;
begin
  if not public.puede_catalogo_tests() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into v_pr from public.pruebas where id = nullif(p->>'prueba_id','')::uuid;
  if v_pr.id is null then raise exception 'Elige la prueba del catálogo.'; end if;
  if nullif(btrim(coalesce(p->>'campeonato','')),'') is null or nullif(btrim(coalesce(p->>'categoria','')),'') is null then raise exception 'Faltan el campeonato o la categoría.'; end if;
  if coalesce(p->>'estado','') not in ('publicada','pendiente','no_exige') then raise exception 'Estado no válido.'; end if;
  if nullif(p->>'temporada_federativa','') is null then raise exception 'Falta el año de la temporada federativa.'; end if;
  if p->>'estado' <> 'pendiente' and (nullif(p->>'comprobada_en','') is null or (nullif(btrim(coalesce(p->>'fuente_url','')),'') is null and nullif(btrim(coalesce(p->>'fuente_texto','')),'') is null)) then
    return jsonb_build_object('ok', false, 'conflicto', 'fuente', 'mensaje', 'Una mínima publicada (o la que dice que no se exige) necesita su fuente oficial y la fecha en que se comprobó. Si aún no está publicada, guárdala como «pendiente».');
  end if;
  if p->>'estado' = 'publicada' then
    v_lee := public.academia_leer_valor(p->>'valor_texto', case when v_pr.unidad = 'tiempo' then 'tiempo' else 'distancia' end);
    v_num := (v_lee->>'num')::numeric;
    if v_num is null then return jsonb_build_object('ok', false, 'conflicto', 'valor', 'mensaje', coalesce(v_lee->>'motivo','No se entiende la marca') || '.'); end if;
  end if;
  if v_id is not null then
    select * into m from public.minimas where id = v_id for update;
    if m.id is null then raise exception 'Esa mínima no existe.'; end if;
    if nullif(p->>'version_base','')::int is distinct from m.version then
      return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla ha cambiado esta mínima: vuelve a abrirla. No se ha pisado nada.');
    end if;
    update public.minimas set campeonato = btrim(p->>'campeonato'), competicion_id = nullif(p->>'competicion_id','')::uuid,
           temporada_federativa = (p->>'temporada_federativa')::int, prueba_id = v_pr.id, categoria = btrim(p->>'categoria'), sexo = nullif(p->>'sexo',''),
           condiciones = coalesce(p->'condiciones','{}'::jsonb), estado = p->>'estado', valor = v_num, valor_texto = case when v_num is not null then btrim(p->>'valor_texto') end,
           validez_desde = nullif(p->>'validez_desde','')::date, validez_hasta = nullif(p->>'validez_hasta','')::date,
           criterio = nullif(btrim(coalesce(p->>'criterio','')),''), fuente_url = nullif(btrim(coalesce(p->>'fuente_url','')),''),
           fuente_texto = nullif(btrim(coalesce(p->>'fuente_texto','')),''), comprobada_en = nullif(p->>'comprobada_en','')::date, nota = nullif(btrim(coalesce(p->>'nota','')),'')
     where id = v_id returning * into m;
  else
    insert into public.minimas (campeonato, competicion_id, temporada_federativa, prueba_id, categoria, sexo, condiciones, estado, valor, valor_texto,
                                validez_desde, validez_hasta, criterio, fuente_url, fuente_texto, comprobada_en, nota)
    values (btrim(p->>'campeonato'), nullif(p->>'competicion_id','')::uuid, (p->>'temporada_federativa')::int, v_pr.id, btrim(p->>'categoria'), nullif(p->>'sexo',''),
            coalesce(p->'condiciones','{}'::jsonb), p->>'estado', v_num, case when v_num is not null then btrim(p->>'valor_texto') end,
            nullif(p->>'validez_desde','')::date, nullif(p->>'validez_hasta','')::date, nullif(btrim(coalesce(p->>'criterio','')),''),
            nullif(btrim(coalesce(p->>'fuente_url','')),''), nullif(btrim(coalesce(p->>'fuente_texto','')),''), nullif(p->>'comprobada_en','')::date,
            nullif(btrim(coalesce(p->>'nota','')),''))
    on conflict do nothing returning * into m;
    if m.id is null then
      return jsonb_build_object('ok', false, 'conflicto', 'repetida', 'mensaje', 'Ya hay una mínima para ese campeonato, temporada, prueba, categoría y condiciones: ábrela y corrígela.');
    end if;
  end if;
  return jsonb_build_object('ok', true, 'minima', to_jsonb(m));
end $$;

-- Crear o cambiar una competición del calendario desde Academia (con historial). Crear dos
-- veces la misma (mismo nombre y fecha) no la duplica.
create or replace function public.academia_competicion_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare c public.competiciones%rowtype; v_id uuid := nullif(p->>'id','')::uuid;
begin
  -- El calendario es el del club (y se ve en la web): lo cambian administración, comunicación y quien entrena un grupo de Academia.
  if not (public.soy_admin_de_verdad() or public.es_responsable_liga()
          or exists (select 1 from public.academia_grupos ag join public.grupos g on g.id = ag.grupo_id where g.entrenador_id = public.mi_perfil_id())) then
    raise exception 'Sin permiso.' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p->>'nombre','')),'') is null or nullif(p->>'fecha_inicio','') is null then raise exception 'Faltan el nombre o la fecha.'; end if;
  if nullif(p->>'fecha_fin','')::date < (p->>'fecha_inicio')::date then raise exception 'La fecha de fin es anterior a la de inicio.'; end if;
  if coalesce(p->>'estado','programada') not in ('programada','aplazada','cancelada') then raise exception 'Estado no válido.'; end if;
  perform set_config('apolana.motivo', coalesce(p->>'motivo', ''), true);
  if v_id is null then
    select * into c from public.competiciones
     where fecha_inicio = (p->>'fecha_inicio')::date and public.prueba_normalizar(nombre) = public.prueba_normalizar(p->>'nombre') limit 1;
    if c.id is not null then return jsonb_build_object('ok', true, 'repetida', true, 'competicion', to_jsonb(c)); end if;
    insert into public.competiciones (nombre, sede, fecha_inicio, fecha_fin, ambito, estado, notas, creado_por)
    values (btrim(p->>'nombre'), nullif(btrim(coalesce(p->>'sede','')),''), (p->>'fecha_inicio')::date, nullif(p->>'fecha_fin','')::date,
            coalesce(nullif(p->>'ambito',''), 'pista'), coalesce(nullif(p->>'estado',''), 'programada'), nullif(btrim(coalesce(p->>'notas','')),''), public.mi_perfil_id())
    returning * into c;
    return jsonb_build_object('ok', true, 'competicion', to_jsonb(c));
  end if;
  select * into c from public.competiciones where id = v_id for update;
  if c.id is null then raise exception 'Esa competición no existe.'; end if;
  if nullif(p->>'version_base','')::int is distinct from c.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla ha cambiado esta competición: vuelve a abrirla. No se ha pisado nada.', 'competicion', to_jsonb(c));
  end if;
  update public.competiciones set nombre = btrim(p->>'nombre'), sede = nullif(btrim(coalesce(p->>'sede','')),''), fecha_inicio = (p->>'fecha_inicio')::date,
         fecha_fin = nullif(p->>'fecha_fin','')::date, estado = coalesce(nullif(p->>'estado',''), estado)
   where id = v_id returning * into c;
  return jsonb_build_object('ok', true, 'competicion', to_jsonb(c));
end $$;

-- Participación de un atleta en una competición: su plan (prioridad y propósito) y sus pruebas.
-- p = {competicion_id, atleta_id, plan:{prioridad, proposito, proposito_texto, nota, version_base}?,
--      pruebas:[{id?, prueba_id, condiciones, dia, hora, hora_fin, estado, motivo, observaciones, version_base}], motivo}
-- Nada se borra: quitar una prueba es cancelarla (con motivo) y queda en el historial.
create or replace function public.competicion_participacion_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare v_comp uuid := nullif(p->>'competicion_id','')::uuid; v_at uuid := nullif(p->>'atleta_id','')::uuid;
        pl public.competicion_plan%rowtype; ca public.competicion_atleta%rowtype; x jsonb; v_pr public.pruebas%rowtype; v_alt numeric; v_txt text; n int := 0;
begin
  if v_at is null or not public.puede_resultados(v_at) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if not exists (select 1 from public.competiciones where id = v_comp) then raise exception 'Esa competición no existe.'; end if;
  -- Primero se comprueba todo; después se escribe.
  if p ? 'plan' and jsonb_typeof(p->'plan') = 'object' then
    select * into pl from public.competicion_plan where competicion_id = v_comp and atleta_id = v_at for update;
    if pl.id is not null and nullif(p->'plan'->>'version_base','')::int is distinct from pl.version then
      return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla ha cambiado la prioridad o el propósito: vuelve a abrirlo. No se ha pisado nada.');
    end if;
    if p->'plan'->>'proposito' = 'otro' and nullif(btrim(coalesce(p->'plan'->>'proposito_texto','')),'') is null then raise exception 'Escribe el propósito.'; end if;
  end if;
  for x in select * from jsonb_array_elements(coalesce(p->'pruebas','[]'::jsonb)) loop
    if coalesce(x->>'estado','previsto') not in ('previsto','apuntado','confirmada','realizado','no_participado','cancelada') then raise exception 'Estado no válido.'; end if;
    if x->>'estado' in ('no_participado','cancelada') and nullif(btrim(coalesce(x->>'motivo','')),'') is null then raise exception 'Escribe el motivo (no participó o cancelada).'; end if;
    if nullif(x->>'hora_fin','') is not null and nullif(x->>'hora','') is not null and (x->>'hora_fin')::time <= (x->>'hora')::time then raise exception 'La hora de fin tiene que ser posterior a la de inicio.'; end if;
    if nullif(x->>'id','') is not null then
      select * into ca from public.competicion_atleta where id = (x->>'id')::uuid for update;
      if ca.id is null or ca.competicion_id <> v_comp or ca.atleta_id <> v_at then raise exception 'Esa inscripción no es de este atleta y competición.'; end if;
      if nullif(x->>'version_base','')::int is distinct from ca.version then
        return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla ha cambiado la prueba «' || ca.prueba || '»: vuelve a abrirlo. No se ha pisado nada.');
      end if;
    elsif not exists (select 1 from public.pruebas where id = nullif(x->>'prueba_id','')::uuid) then raise exception 'Elige la prueba del catálogo.';
    end if;
  end loop;
  perform set_config('apolana.motivo', coalesce(p->>'motivo', ''), true);
  if p ? 'plan' and jsonb_typeof(p->'plan') = 'object' then
    if pl.id is null then
      insert into public.competicion_plan (competicion_id, atleta_id, prioridad, proposito, proposito_texto, nota)
      values (v_comp, v_at, nullif(p->'plan'->>'prioridad',''), nullif(p->'plan'->>'proposito',''), nullif(btrim(coalesce(p->'plan'->>'proposito_texto','')),''),
              nullif(btrim(coalesce(p->'plan'->>'nota','')),''));
    else
      update public.competicion_plan set prioridad = nullif(p->'plan'->>'prioridad',''), proposito = nullif(p->'plan'->>'proposito',''),
             proposito_texto = nullif(btrim(coalesce(p->'plan'->>'proposito_texto','')),''), nota = nullif(btrim(coalesce(p->'plan'->>'nota','')),'')
       where id = pl.id;
    end if;
  end if;
  for x in select * from jsonb_array_elements(coalesce(p->'pruebas','[]'::jsonb)) loop
    if nullif(x->>'id','') is not null then
      -- Si cambian las condiciones (p. ej. la altura de la valla), su nombre las acompaña: «60 m vallas (0,991)».
      select * into ca from public.competicion_atleta where id = (x->>'id')::uuid;
      v_txt := ca.prueba;
      if x ? 'condiciones' and ca.prueba_id is not null and coalesce(x->'condiciones','{}'::jsonb) <> ca.condiciones then
        select * into v_pr from public.pruebas where id = ca.prueba_id;
        v_alt := nullif(x->'condiciones'->>'altura_valla_m','')::numeric;
        v_txt := v_pr.nombre || case when v_alt is not null then ' (' || replace(to_char(v_alt, 'FM0.000'), '.', ',') || ')' else '' end;
        if exists (select 1 from public.competicion_atleta where competicion_id = v_comp and atleta_id = v_at and prueba = v_txt and id <> ca.id) then
          raise exception 'Ya tiene «%» en esta competición.', v_txt;
        end if;
      end if;
      update public.competicion_atleta set prueba = v_txt, estado = coalesce(nullif(x->>'estado',''), estado), condiciones = coalesce(x->'condiciones', condiciones),
             dia = nullif(x->>'dia','')::date, hora = nullif(x->>'hora','')::time, hora_fin = nullif(x->>'hora_fin','')::time,
             motivo = nullif(btrim(coalesce(x->>'motivo','')),''), observaciones = nullif(btrim(coalesce(x->>'observaciones','')),''),
             confirmada_en = case when x->>'estado' = 'confirmada' and estado <> 'confirmada' then now() else confirmada_en end
       where id = (x->>'id')::uuid;
    else
      select * into v_pr from public.pruebas where id = (x->>'prueba_id')::uuid;
      v_alt := nullif(x->'condiciones'->>'altura_valla_m','')::numeric;
      v_txt := v_pr.nombre || case when v_alt is not null then ' (' || replace(to_char(v_alt, 'FM0.000'), '.', ',') || ')' else '' end;
      if exists (select 1 from public.competicion_atleta where competicion_id = v_comp and atleta_id = v_at and prueba = v_txt) then
        raise exception 'Ya tiene «%» en esta competición: cambia esa fila en vez de añadir otra.', v_txt;
      end if;
      insert into public.competicion_atleta (competicion_id, atleta_id, prueba, prueba_id, condiciones, estado, dia, hora, hora_fin, motivo, observaciones, creado_por, confirmada_en)
      values (v_comp, v_at, v_txt, v_pr.id, coalesce(x->'condiciones','{}'::jsonb), coalesce(nullif(x->>'estado',''),'previsto'),
              nullif(x->>'dia','')::date, nullif(x->>'hora','')::time, nullif(x->>'hora_fin','')::time, nullif(btrim(coalesce(x->>'motivo','')),''),
              nullif(btrim(coalesce(x->>'observaciones','')),''), public.mi_perfil_id(), case when x->>'estado' = 'confirmada' then now() end);
    end if;
    n := n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'pruebas', n);
end $$;

-- resultado_guardar: además enlaza con la inscripción, separa oficial / no oficial y la ronda.
create or replace function public.resultado_guardar(p jsonb)
 returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare m public.marcas_atleta%rowtype; v_id uuid := nullif(p->>'id','')::uuid; v_at uuid := nullif(p->>'atleta_id','')::uuid;
        v_pr public.pruebas%rowtype; v_txt text; v_lee jsonb; v_cat jsonb; v_fn date; v_alt numeric; v_fecha date;
        v_par public.competicion_atleta%rowtype; v_comp uuid; v_of boolean; v_ronda text;
begin
  if v_id is not null then select * into m from public.marcas_atleta where id = v_id for update; v_at := m.atleta_id; end if;
  if v_at is null or not public.puede_resultados(v_at) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if v_id is not null and m.id is null then raise exception 'Ese resultado no existe.'; end if;
  -- Importar dos veces lo mismo no lo duplica.
  if v_id is null and nullif(p->>'huella','') is not null then
    select * into m from public.marcas_atleta where huella = p->>'huella';
    if m.id is not null then return jsonb_build_object('ok', true, 'repetido', true, 'resultado', to_jsonb(m)); end if;
  end if;
  if v_id is not null and nullif(p->>'version_base','')::int is distinct from m.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla lo ha cambiado: vuelve a abrirlo.', 'resultado', to_jsonb(m));
  end if;
  -- La inscripción, si la hay, manda en la competición. Al corregir, lo que no se manda se conserva.
  v_comp := case when p ? 'competicion_id' or v_id is null then nullif(p->>'competicion_id','')::uuid else m.competicion_id end;
  if (p ? 'participacion_id' or v_id is null) and nullif(p->>'participacion_id','') is not null then
    select * into v_par from public.competicion_atleta where id = (p->>'participacion_id')::uuid;
  elsif v_id is not null and not (p ? 'participacion_id') and m.participacion_id is not null then
    select * into v_par from public.competicion_atleta where id = m.participacion_id;
  end if;
  if v_par.id is not null then
    if v_par.atleta_id <> v_at then raise exception 'Esa inscripción no es de este atleta.'; end if;
    v_comp := v_par.competicion_id;
  elsif nullif(p->>'participacion_id','') is not null then raise exception 'Esa inscripción no existe.';
  end if;
  v_of := case when p ? 'oficial' then case when jsonb_typeof(p->'oficial') = 'boolean' then (p->>'oficial')::boolean end
               when v_id is not null then m.oficial end;
  v_ronda := case when p ? 'ronda' or v_id is null then nullif(p->>'ronda','') else m.ronda end;
  if v_of and v_par.id is not null and exists (select 1 from public.marcas_atleta x where x.participacion_id = v_par.id and x.oficial
                                                   and coalesce(x.ronda,'unica') = coalesce(v_ronda,'unica') and x.id is distinct from v_id) then
    return jsonb_build_object('ok', false, 'conflicto', 'oficial', 'mensaje', 'Ya hay un resultado oficial de esa ronda en esta inscripción: ábrelo y corrígelo (queda en el historial).');
  end if;
  select * into v_pr from public.pruebas where id = nullif(p->>'prueba_id','')::uuid;
  if v_pr.id is null and v_id is null then raise exception 'Elige la prueba del catálogo.'; end if;
  if v_pr.id is null then select * into v_pr from public.pruebas where id = m.prueba_id; end if;
  v_alt := nullif(p->'condiciones'->>'altura_valla_m','')::numeric;
  -- El texto conserva la costumbre de Récords: «60 m vallas (0,991)».
  v_txt := coalesce(nullif(btrim(coalesce(p->>'prueba','')),''), v_pr.nombre || case when v_alt is not null then ' (' || replace(to_char(v_alt, 'FM0.000'), '.', ',') || ')' else '' end);
  v_lee := case v_pr.unidad when 'tiempo' then public.academia_leer_valor(p->>'valor_texto', 'tiempo')
                            when 'distancia' then public.academia_leer_valor(p->>'valor_texto', 'distancia')
                            else jsonb_build_object('num', nullif(regexp_replace(coalesce(p->>'valor_texto',''), '\D', '', 'g'),'')::numeric, 'unidad', 'puntos') end;
  if p->>'contexto' = 'estimado' and (p->'estimacion' is null or jsonb_typeof(p->'estimacion') <> 'object') then
    return jsonb_build_object('ok', false, 'conflicto', 'estimacion', 'mensaje', 'Un resultado estimado necesita cómo se estimó: fórmula o método y datos usados.');
  end if;
  if (v_lee->>'num') is null then
    return jsonb_build_object('ok', false, 'conflicto', 'valor', 'mensaje', coalesce(v_lee->>'motivo', 'No se entiende el valor') || '.');
  end if;
  v_fecha := nullif(p->>'fecha','')::date;
  select fecha_nacimiento into v_fn from public.atletas where id = v_at;
  v_cat := public.categoria_federativa(v_fn, v_fecha);
  if v_id is null then
    insert into public.marcas_atleta (atleta_id, prueba, prueba_id, tipo, tiempo_segundos, tiempo_display, unidad, fecha, sede, contexto, condiciones, metodo, viento,
                                      fuente_url, fuente_texto, competicion_id, participacion_id, oficial, ronda, categoria, categoria_origen, estimacion, huella, nota, creado_por)
    values (v_at, v_txt, v_pr.id, nullif(p->>'tipo',''), (v_lee->>'num')::numeric, btrim(p->>'valor_texto'), coalesce(v_lee->>'unidad', case v_pr.unidad when 'puntos' then 'puntos' end),
            v_fecha, nullif(btrim(coalesce(p->>'sede','')),''), nullif(p->>'contexto',''), coalesce(p->'condiciones','{}'::jsonb), nullif(p->>'metodo',''),
            nullif(p->>'viento','')::numeric, nullif(btrim(coalesce(p->>'fuente_url','')),''), nullif(btrim(coalesce(p->>'fuente_texto','')),''),
            v_comp, v_par.id, v_of, v_ronda,
            coalesce(nullif(p->>'categoria',''), v_cat->>'categoria'),
            case when nullif(p->>'categoria','') is not null then coalesce(nullif(p->>'categoria_origen',''),'manual') when v_cat->>'categoria' is not null then 'calculada' end,
            case when p->>'contexto' = 'estimado' then p->'estimacion' end, nullif(p->>'huella',''), nullif(btrim(coalesce(p->>'nota','')),''), public.mi_perfil_id())
    returning * into m;
  else
    perform set_config('apolana.motivo', coalesce(p->>'motivo', ''), true);
    update public.marcas_atleta set prueba = v_txt, prueba_id = v_pr.id, tipo = nullif(p->>'tipo',''), tiempo_segundos = (v_lee->>'num')::numeric,
           tiempo_display = btrim(p->>'valor_texto'), unidad = coalesce(v_lee->>'unidad', unidad), fecha = v_fecha, sede = nullif(btrim(coalesce(p->>'sede','')),''),
           contexto = nullif(p->>'contexto',''), condiciones = coalesce(p->'condiciones','{}'::jsonb), metodo = nullif(p->>'metodo',''), viento = nullif(p->>'viento','')::numeric,
           fuente_url = nullif(btrim(coalesce(p->>'fuente_url','')),''), fuente_texto = nullif(btrim(coalesce(p->>'fuente_texto','')),''),
           competicion_id = v_comp, participacion_id = v_par.id, oficial = v_of, ronda = v_ronda,
           categoria = coalesce(nullif(p->>'categoria',''), case when categoria_origen = 'calculada' or categoria is null then v_cat->>'categoria' else categoria end),
           categoria_origen = case when nullif(p->>'categoria','') is not null then coalesce(nullif(p->>'categoria_origen',''),'manual')
                                   when categoria_origen = 'calculada' or categoria is null then case when v_cat->>'categoria' is not null then 'calculada' end else categoria_origen end,
           estimacion = case when p->>'contexto' = 'estimado' then p->'estimacion' end, nota = nullif(btrim(coalesce(p->>'nota','')),'')
     where id = m.id returning * into m;
  end if;
  -- Solo si se pide expresamente: la inscripción pasa a «realizado».
  if v_par.id is not null and coalesce((p->>'marcar_realizado')::boolean, false) and v_par.estado <> 'realizado' then
    perform set_config('apolana.motivo', 'Resultado registrado', true);
    update public.competicion_atleta set estado = 'realizado' where id = v_par.id;
  end if;
  return jsonb_build_object('ok', true, 'resultado', to_jsonb(m), 'categoria', v_cat);
end $function$;

-- Permisos ---------------------------------------------------------------------------------
alter table public.pruebas_correspondencia_usos enable row level security;
alter table public.competicion_prioridades enable row level security;
alter table public.competicion_plan enable row level security;
alter table public.minimas enable row level security;
revoke all on public.pruebas_correspondencia_usos, public.competicion_prioridades, public.competicion_plan, public.minimas from public, anon, authenticated;
grant select on public.pruebas_correspondencia_usos, public.competicion_prioridades, public.competicion_plan, public.minimas to authenticated;
grant update (nombre, significado, actualizado_por, actualizado_en) on public.competicion_prioridades to authenticated;
create policy "usos del catálogo: equipo técnico" on public.pruebas_correspondencia_usos for select to authenticated using ((select public.puede_catalogo_tests()));
create policy "prioridades: lectura" on public.competicion_prioridades for select to authenticated using (true);
create policy "prioridades: las cambia el equipo técnico" on public.competicion_prioridades for update to authenticated
  using ((select public.puede_catalogo_tests())) with check ((select public.puede_catalogo_tests()));
create policy "plan de competición: quien lleva al atleta" on public.competicion_plan for select to authenticated using (public.puede_resultados(atleta_id));
create policy "mínimas: lectura" on public.minimas for select to authenticated using (true);

revoke execute on function public.prueba_correspondencia_usos(text), public.prueba_correspondencia_uso_resolver(jsonb), public.minima_guardar(jsonb),
  public.academia_competicion_guardar(jsonb), public.competicion_participacion_guardar(jsonb), public.protocolo_faltan(public.test_protocolos) from public, anon;
grant execute on function public.prueba_correspondencia_usos(text), public.prueba_correspondencia_uso_resolver(jsonb), public.minima_guardar(jsonb),
  public.academia_competicion_guardar(jsonb), public.competicion_participacion_guardar(jsonb), public.protocolo_faltan(public.test_protocolos) to authenticated;

commit;
