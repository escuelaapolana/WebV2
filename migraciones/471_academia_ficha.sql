-- ===========================================================================
-- 471 · Academia · Ficha del atleta (lo que faltaba en la base)
-- ---------------------------------------------------------------------------
-- Se reutiliza lo que ya hay (atletas, marcas_atleta, test_resultados,
-- rm_atleta, competiciones, lesiones_atleta, ausencias, notas_atleta,
-- sesiones y registros). Solo se añade lo que no existía, sin copiar nada:
--   1) atleta_perfil_cambios: historial del PERFIL DEPORTIVO (pruebas,
--      especialidad, disponibilidad habitual, contexto…). Lo escribe un
--      disparador en atletas: valor anterior y nuevo, de quién (atleta,
--      entrenador, administración), cuándo y por qué (apolana.motivo) y, si
--      viene de una decisión, cuál (apolana.decision). El perfil efectivo
--      sigue siendo el de atletas; aquí queda de dónde viene.
--   2) atleta_decisiones: decisiones del entrenador que NO son lesiones
--      (perfil, disponibilidad temporal, planificación, competición), con
--      ámbito, motivo, inicio, revisión y fin, estado e historial. Las
--      restricciones de salud siguen viviendo SOLO en lesiones_atleta: la
--      ficha las enseña desde allí (nada se mantiene en dos sitios).
--   3) atleta_objetivos: por prueba y temporada, el objetivo del atleta y el
--      acordado con el entrenador (por separado), con su marca de referencia
--      (fecha y condiciones), competición o fecha de referencia, condiciones
--      de esa temporada (categoría, altura de vallas, implemento), estado e
--      historial. Nada se rellena solo.
--   4) competicion_atleta.prioridad (A/B/C): la prioridad de esa competición
--      para ese atleta. Sin ella, la ficha dice «sin registrar».
-- Escribir: solo por las funciones de abajo; leer y escribir exige poder
-- sobre el atleta (Academia o su entrenador).
-- ===========================================================================
begin;

-- Poder sobre un atleta: Academia (por su grupo o sus grupos) o su entrenador.
create or replace function public.academia_puede_atleta(p_atleta uuid) returns boolean
language sql stable security definer set search_path to 'public' as $$
  select public.soy_staff_de_atleta(p_atleta)
      or exists (select 1 from public.atletas a where a.id = p_atleta and a.grupo_id is not null and public.academia_puede(a.grupo_id))
      or exists (select 1 from public.atleta_grupos ag where ag.atleta_id = p_atleta and public.academia_puede(ag.grupo_id));
$$;

-- 1 · Historial del perfil deportivo ---------------------------------------------
create table public.atleta_perfil_cambios (
  id              bigserial primary key,
  atleta_id       uuid not null references public.atletas(id) on delete cascade,
  campo           text not null,
  valor_anterior  jsonb,
  valor_nuevo     jsonb,
  origen          text not null check (origen in ('atleta','entrenador','administracion','sistema')),
  motivo          text,
  decision_id     uuid,
  autor_perfil_id uuid,
  cambiado_en     timestamptz not null default now()
);
create index atleta_perfil_cambios_atleta on public.atleta_perfil_cambios (atleta_id, cambiado_en desc);

create or replace function public.atletas_perfil_historial() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare
  campos text[] := array['pruebas_principales','pruebas_secundarias','especialidades','perfil_velocista','pierna_ataque',
                         'pasos_entre_vallas','dias_entreno','hace_gym','tiene_fisio','dia_fisio','categoria',
                         'contexto_atleta','contexto_entrenador'];
  c text; yo uuid := public.mi_perfil_id(); v_origen text; v_dec uuid;
begin
  v_origen := case when yo is null then 'sistema'
                   when yo = new.perfil_id or yo = new.perfil_padre_id then 'atleta'
                   when public.soy_staff_de_atleta(new.id) and not public.es_admin() then 'entrenador'
                   when exists (select 1 from public.grupos g where g.entrenador_id = yo and (g.id = new.grupo_id or g.id in (select ag.grupo_id from public.atleta_grupos ag where ag.atleta_id = new.id))) then 'entrenador'
                   else 'administracion' end;
  begin v_dec := nullif(current_setting('apolana.decision', true), '')::uuid; exception when others then v_dec := null; end;
  foreach c in array campos loop
    if (to_jsonb(new) -> c) is distinct from (to_jsonb(old) -> c) then
      insert into public.atleta_perfil_cambios (atleta_id, campo, valor_anterior, valor_nuevo, origen, motivo, decision_id, autor_perfil_id)
      values (new.id, c, to_jsonb(old) -> c, to_jsonb(new) -> c, v_origen,
              nullif(current_setting('apolana.motivo', true), ''), v_dec, yo);
    end if;
  end loop;
  return null;
end $$;
create trigger trg_atletas_perfil_historial after update on public.atletas
  for each row execute function public.atletas_perfil_historial();

-- 2 · Decisiones (no de salud: esas, en lesiones_atleta) ---------------------------
create table public.atleta_decisiones (
  id              uuid primary key default gen_random_uuid(),
  atleta_id       uuid not null references public.atletas(id) on delete cascade,
  ambito          text not null check (ambito in ('perfil','disponibilidad','planificacion','competicion','otro')),
  decision        text not null check (length(decision) between 1 and 300),
  motivo          text check (motivo is null or length(motivo) <= 500),
  inicio          date not null default current_date,
  revision        date,
  fin             date,
  estado          text not null default 'vigente' check (estado in ('vigente','finalizada','anulada')),
  origen          text not null default 'entrenador' check (origen in ('entrenador','atleta')),
  revisada_en     timestamptz,
  revisada_por    uuid,
  nota_revision   text check (nota_revision is null or length(nota_revision) <= 500),
  version         integer not null default 1,
  autor_perfil_id uuid,
  creado_en       timestamptz not null default now(),
  actualizado_por uuid,
  actualizado_en  timestamptz not null default now(),
  historial       jsonb not null default '[]'::jsonb,
  check (fin is null or fin >= inicio)
);
create index atleta_decisiones_atleta on public.atleta_decisiones (atleta_id, estado, inicio desc);

-- 3 · Objetivos por prueba y temporada -------------------------------------------------
create table public.atleta_objetivos (
  id               uuid primary key default gen_random_uuid(),
  atleta_id        uuid not null references public.atletas(id) on delete cascade,
  prueba           text not null check (length(prueba) between 1 and 80),
  temporada        text not null check (length(temporada) between 1 and 20),
  tipo             text not null check (tipo in ('atleta','acordado')),
  objetivo_texto   text check (objetivo_texto is null or length(objetivo_texto) <= 60),
  objetivo_num     numeric,
  unidad           text,
  ref_marca_id     uuid references public.marcas_atleta(id) on delete set null,
  ref_texto        text check (ref_texto is null or length(ref_texto) <= 60),
  ref_fecha        date,
  ref_condiciones  text check (ref_condiciones is null or length(ref_condiciones) <= 200),
  competicion_id   uuid references public.competiciones(id) on delete set null,
  fecha_referencia date,
  condiciones      text check (condiciones is null or length(condiciones) <= 200),
  estado           text not null default 'vigente' check (estado in ('vigente','conseguido','no_conseguido','descartado')),
  nota             text check (nota is null or length(nota) <= 500),
  version          integer not null default 1,
  autor_perfil_id  uuid,
  creado_en        timestamptz not null default now(),
  actualizado_por  uuid,
  actualizado_en   timestamptz not null default now(),
  historial        jsonb not null default '[]'::jsonb,
  unique (atleta_id, prueba, temporada, tipo)
);

-- Historial de decisiones y objetivos: lo de antes se guarda al cambiar.
create or replace function public.academia_ficha_historial() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if tg_op = 'INSERT' then
    new.version := 1; new.autor_perfil_id := coalesce(public.mi_perfil_id(), new.autor_perfil_id);
    new.creado_en := now(); new.actualizado_en := now(); new.actualizado_por := new.autor_perfil_id; new.historial := '[]'::jsonb;
    return new;
  end if;
  new.historial := old.historial || jsonb_build_array((to_jsonb(old) - 'historial') || jsonb_build_object('reemplazado_en', now(), 'reemplazado_por', public.mi_perfil_id()));
  new.version := old.version + 1; new.actualizado_en := now(); new.actualizado_por := public.mi_perfil_id();
  new.creado_en := old.creado_en; new.autor_perfil_id := old.autor_perfil_id;
  return new;
end $$;
create trigger trg_atleta_decisiones_historial before insert or update on public.atleta_decisiones
  for each row execute function public.academia_ficha_historial();
create trigger trg_atleta_objetivos_historial before insert or update on public.atleta_objetivos
  for each row execute function public.academia_ficha_historial();

-- 4 · Prioridad de la competición para el atleta -----------------------------------------
alter table public.competicion_atleta add column prioridad text check (prioridad in ('A','B','C'));
grant select (prioridad), insert (prioridad), update (prioridad) on public.competicion_atleta to authenticated;

-- 5 · Funciones para escribir ----------------------------------------------------------
-- Cambiar el perfil deportivo con su motivo (y, si se quiere, la decisión que lo explica).
create or replace function public.academia_perfil_cambiar(p_atleta uuid, p_cambios jsonb, p_motivo text, p_decision jsonb default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  ok text[] := array['pruebas_principales','pruebas_secundarias','especialidades','perfil_velocista','pierna_ataque','pasos_entre_vallas',
                     'dias_entreno','hace_gym','tiene_fisio','dia_fisio','contexto_entrenador'];
  k text; v_dec uuid; a public.atletas%rowtype;
begin
  if not public.academia_puede_atleta(p_atleta) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if nullif(btrim(coalesce(p_motivo,'')), '') is null then raise exception 'Di por qué cambia (queda en el historial).'; end if;
  for k in select jsonb_object_keys(coalesce(p_cambios,'{}'::jsonb)) loop
    if k <> all (ok) then raise exception 'Eso no se cambia desde aquí: %', k; end if;
  end loop;
  select * into a from public.atletas where id = p_atleta for update;
  if a.id is null then raise exception 'Ese atleta no existe.'; end if;
  if p_decision is not null then
    insert into public.atleta_decisiones (atleta_id, ambito, decision, motivo, inicio, revision, fin)
    values (p_atleta, 'perfil', p_decision->>'decision', btrim(p_motivo), coalesce(nullif(p_decision->>'inicio','')::date, current_date),
            nullif(p_decision->>'revision','')::date, nullif(p_decision->>'fin','')::date)
    returning id into v_dec;
    perform set_config('apolana.decision', v_dec::text, true);
  end if;
  perform set_config('apolana.motivo', left(btrim(p_motivo), 500), true);
  update public.atletas set
    pruebas_principales = case when p_cambios ? 'pruebas_principales' then array(select jsonb_array_elements_text(p_cambios->'pruebas_principales')) else pruebas_principales end,
    pruebas_secundarias = case when p_cambios ? 'pruebas_secundarias' then array(select jsonb_array_elements_text(p_cambios->'pruebas_secundarias')) else pruebas_secundarias end,
    especialidades      = case when p_cambios ? 'especialidades' then array(select jsonb_array_elements_text(p_cambios->'especialidades')) else especialidades end,
    dias_entreno        = case when p_cambios ? 'dias_entreno' then array(select jsonb_array_elements_text(p_cambios->'dias_entreno')) else dias_entreno end,
    perfil_velocista    = case when p_cambios ? 'perfil_velocista' then nullif(p_cambios->>'perfil_velocista','') else perfil_velocista end,
    pierna_ataque       = case when p_cambios ? 'pierna_ataque' then nullif(p_cambios->>'pierna_ataque','') else pierna_ataque end,
    pasos_entre_vallas  = case when p_cambios ? 'pasos_entre_vallas' then nullif(p_cambios->>'pasos_entre_vallas','')::int else pasos_entre_vallas end,
    hace_gym            = case when p_cambios ? 'hace_gym' then (p_cambios->>'hace_gym')::boolean else hace_gym end,
    tiene_fisio         = case when p_cambios ? 'tiene_fisio' then (p_cambios->>'tiene_fisio')::boolean else tiene_fisio end,
    dia_fisio           = case when p_cambios ? 'dia_fisio' then nullif(p_cambios->>'dia_fisio','') else dia_fisio end,
    contexto_entrenador = case when p_cambios ? 'contexto_entrenador' then nullif(p_cambios->>'contexto_entrenador','') else contexto_entrenador end
  where id = p_atleta;
  perform set_config('apolana.decision', '', true);
  perform set_config('apolana.motivo', '', true);
  return jsonb_build_object('ok', true, 'decision_id', v_dec);
end $$;

-- Una decisión: alta, cambio (con su versión) o cerrarla. Nunca de salud.
create or replace function public.academia_decision_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare d public.atleta_decisiones%rowtype; v_id uuid := nullif(p->>'id','')::uuid;
begin
  if v_id is null then
    if not public.academia_puede_atleta(nullif(p->>'atleta_id','')::uuid) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
    insert into public.atleta_decisiones (atleta_id, ambito, decision, motivo, inicio, revision, fin, origen)
    values ((p->>'atleta_id')::uuid, p->>'ambito', btrim(p->>'decision'), nullif(btrim(coalesce(p->>'motivo','')),''),
            coalesce(nullif(p->>'inicio','')::date, current_date), nullif(p->>'revision','')::date, nullif(p->>'fin','')::date,
            coalesce(nullif(p->>'origen',''), 'entrenador'))
    returning * into d;
    return jsonb_build_object('ok', true, 'decision', to_jsonb(d));
  end if;
  select * into d from public.atleta_decisiones where id = v_id for update;
  if d.id is null then raise exception 'Esa decisión no existe.'; end if;
  if not public.academia_puede_atleta(d.atleta_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if nullif(p->>'version_base','')::int is distinct from d.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla la ha cambiado: vuelve a abrirla.', 'decision', to_jsonb(d));
  end if;
  update public.atleta_decisiones set
    decision = coalesce(nullif(btrim(coalesce(p->>'decision','')),''), decision),
    motivo   = case when p ? 'motivo' then nullif(btrim(coalesce(p->>'motivo','')),'') else motivo end,
    revision = case when p ? 'revision' then nullif(p->>'revision','')::date else revision end,
    fin      = case when p ? 'fin' then nullif(p->>'fin','')::date else fin end,
    estado   = coalesce(nullif(p->>'estado',''), estado),
    revisada_en   = case when p ? 'nota_revision' then now() else revisada_en end,
    revisada_por  = case when p ? 'nota_revision' then public.mi_perfil_id() else revisada_por end,
    nota_revision = case when p ? 'nota_revision' then nullif(btrim(coalesce(p->>'nota_revision','')),'') else nota_revision end
  where id = d.id returning * into d;
  return jsonb_build_object('ok', true, 'decision', to_jsonb(d));
end $$;

-- Un objetivo (por prueba, temporada y tipo): alta o cambio con su versión.
create or replace function public.academia_objetivo_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare o public.atleta_objetivos%rowtype; v_id uuid := nullif(p->>'id','')::uuid; v_mag text; v_p jsonb; v_un text;
begin
  -- Tiempo o distancia según la prueba; los puntos (pruebas combinadas) se quedan como texto.
  select case pr.unidad when 'tiempo' then 'tiempo' when 'distancia' then 'distancia' else null end, pr.unidad
    into v_mag, v_un from public.pruebas pr where pr.nombre = p->>'prueba' limit 1;
  v_p := case when v_mag is null then jsonb_build_object('num', null) else public.academia_leer_valor(p->>'objetivo_texto', v_mag) end;
  if v_id is null then
    if not public.academia_puede_atleta(nullif(p->>'atleta_id','')::uuid) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
    select * into o from public.atleta_objetivos where atleta_id = (p->>'atleta_id')::uuid and prueba = p->>'prueba' and temporada = p->>'temporada' and tipo = p->>'tipo';
    if o.id is not null then
      return jsonb_build_object('ok', false, 'conflicto', 'ya_existe', 'mensaje', 'Ya hay un objetivo de ese tipo para esa prueba y temporada (otra pantalla).', 'objetivo', to_jsonb(o));
    end if;
    insert into public.atleta_objetivos (atleta_id, prueba, temporada, tipo, objetivo_texto, objetivo_num, unidad, ref_marca_id, ref_texto, ref_fecha,
                                         ref_condiciones, competicion_id, fecha_referencia, condiciones, estado, nota)
    values ((p->>'atleta_id')::uuid, btrim(p->>'prueba'), btrim(p->>'temporada'), p->>'tipo', nullif(btrim(coalesce(p->>'objetivo_texto','')),''),
            (v_p->>'num')::numeric, v_p->>'unidad', nullif(p->>'ref_marca_id','')::uuid, nullif(btrim(coalesce(p->>'ref_texto','')),''),
            nullif(p->>'ref_fecha','')::date, nullif(btrim(coalesce(p->>'ref_condiciones','')),''), nullif(p->>'competicion_id','')::uuid,
            nullif(p->>'fecha_referencia','')::date, nullif(btrim(coalesce(p->>'condiciones','')),''), coalesce(nullif(p->>'estado',''),'vigente'),
            nullif(btrim(coalesce(p->>'nota','')),''))
    returning * into o;
    return jsonb_build_object('ok', true, 'objetivo', to_jsonb(o));
  end if;
  select * into o from public.atleta_objetivos where id = v_id for update;
  if o.id is null then raise exception 'Ese objetivo no existe.'; end if;
  if not public.academia_puede_atleta(o.atleta_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if nullif(p->>'version_base','')::int is distinct from o.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla lo ha cambiado: vuelve a abrirlo.', 'objetivo', to_jsonb(o));
  end if;
  update public.atleta_objetivos set
    objetivo_texto = nullif(btrim(coalesce(p->>'objetivo_texto','')),''), objetivo_num = (v_p->>'num')::numeric, unidad = v_p->>'unidad',
    ref_marca_id = nullif(p->>'ref_marca_id','')::uuid, ref_texto = nullif(btrim(coalesce(p->>'ref_texto','')),''), ref_fecha = nullif(p->>'ref_fecha','')::date,
    ref_condiciones = nullif(btrim(coalesce(p->>'ref_condiciones','')),''), competicion_id = nullif(p->>'competicion_id','')::uuid,
    fecha_referencia = nullif(p->>'fecha_referencia','')::date, condiciones = nullif(btrim(coalesce(p->>'condiciones','')),''),
    estado = coalesce(nullif(p->>'estado',''), estado), nota = nullif(btrim(coalesce(p->>'nota','')),'')
  where id = o.id returning * into o;
  return jsonb_build_object('ok', true, 'objetivo', to_jsonb(o));
end $$;

-- 6 · Permisos ---------------------------------------------------------------------------
alter table public.atleta_perfil_cambios enable row level security;
alter table public.atleta_decisiones enable row level security;
alter table public.atleta_objetivos enable row level security;
revoke all on public.atleta_perfil_cambios, public.atleta_decisiones, public.atleta_objetivos from public, anon, authenticated;
grant select on public.atleta_perfil_cambios, public.atleta_decisiones, public.atleta_objetivos to authenticated;
grant all on public.atleta_perfil_cambios, public.atleta_decisiones, public.atleta_objetivos to service_role;
grant usage, select on sequence public.atleta_perfil_cambios_id_seq to service_role;
create policy "ficha: historial del perfil" on public.atleta_perfil_cambios for select to authenticated using (public.academia_puede_atleta(atleta_id));
create policy "ficha: decisiones" on public.atleta_decisiones for select to authenticated using (public.academia_puede_atleta(atleta_id));
create policy "ficha: objetivos" on public.atleta_objetivos for select to authenticated using (public.academia_puede_atleta(atleta_id));

revoke all on function public.academia_puede_atleta(uuid), public.academia_perfil_cambiar(uuid, jsonb, text, jsonb),
  public.academia_decision_guardar(jsonb), public.academia_objetivo_guardar(jsonb), public.atletas_perfil_historial(),
  public.academia_ficha_historial() from public, anon;
grant execute on function public.academia_puede_atleta(uuid), public.academia_perfil_cambiar(uuid, jsonb, text, jsonb),
  public.academia_decision_guardar(jsonb), public.academia_objetivo_guardar(jsonb) to authenticated, service_role;

commit;
