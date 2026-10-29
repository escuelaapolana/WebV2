-- ===========================================================================
-- 472 · Tests y marcas (1ª parte): temporada, catálogo, objetivos, resultados,
--       protocolos y RM
-- ---------------------------------------------------------------------------
-- Se amplía lo que ya hay; no se crea un segundo registro de nada:
--   1) temporadas_planificacion: el ciclo del club (2026/27, 2027/28,
--      2028/29) con fechas configurables. NO es el año federativo.
--   2) categorias_federativas + categoria_federativa(fnac, fecha): la regla
--      de la RFEA por temporada federativa (año natural). 2026 verificada en
--      la circular 181/2025 y 2025 en la 161/2024 (anexo 2). Otro año sin circular =
--      «provisional» (misma regla desplazada) y se dice. La categoría de un
--      resultado se guarda aparte, con su origen; lo existente no se toca.
--   3) Catálogo de pruebas: el de siempre (pruebas) con distancia y
--      condiciones aplicables, pruebas_alias y pruebas_correspondencias
--      (texto original → prueba propuesta / confirmada / ambigua). Ningún
--      texto existente se reescribe; las condiciones (altura de valla, peso
--      del implemento) van aparte, explícitas.
--   4) atleta_objetivos: único registro de objetivos. Por temporada de
--      planificación (temporada_id), con prueba del catálogo y condiciones.
--      El atleta ve los suyos y propone (tipo 'atleta') con
--      mis_objetivos_proponer; una propuesta nunca sustituye al acordado.
--      marcas_atleta ya no admite marcas nuevas de tipo «objetivo» (hoy hay 0).
--   5) marcas_atleta = resultados: competición, entreno/test o estimado
--      (contexto), prueba del catálogo, condiciones, método, viento, fuente
--      (acta), autor, categoría con su origen, huella de importación (no se
--      duplica), versión e historial de correcciones.
--   6) test_protocolos (clave + versión) y, en test_resultados, protocolo,
--      intentos con su estado (válido / nulo / incompleto; lo ausente no es
--      cero), versión e historial.
--   7) rm_atleta: variante, recorrido, lateralidad, medido o estimado (con
--      fórmula y datos), versión e historial.
-- Los parciales reales y el modelo de parciales objetivo van en la 473.
-- ===========================================================================
begin;

-- 1 · Temporadas de planificación ------------------------------------------------
create table public.temporadas_planificacion (
  id             uuid primary key default gen_random_uuid(),
  nombre         text not null unique,
  inicio         date not null,
  fin            date not null,
  orden          int  not null,
  nota           text,
  actualizado_por uuid,
  actualizado_en timestamptz not null default now(),
  check (fin > inicio)
);
insert into public.temporadas_planificacion (nombre, inicio, fin, orden, nota) values
  ('2026/27', '2026-09-01', '2027-08-31', 1, 'Fechas por confirmar'),
  ('2027/28', '2027-09-01', '2028-08-31', 2, 'Fechas por confirmar'),
  ('2028/29', '2028-09-01', '2029-08-31', 3, 'Fechas por confirmar');

-- 2 · Categorías federativas -----------------------------------------------------
create table public.categorias_federativas (
  temporada      int  not null,              -- temporada federativa = año natural (1-ene a 31-dic)
  categoria      text not null,
  nacidos_desde  int,
  nacidos_hasta  int,
  edad_desde     int,                        -- Máster: desde el día en que cumple esa edad
  orden          int  not null,
  fuente         text not null,
  verificada     boolean not null default true,
  primary key (temporada, categoria)
);
insert into public.categorias_federativas (temporada, categoria, nacidos_desde, nacidos_hasta, edad_desde, orden, fuente) values
  (2026, 'Máster', null, null, 35,   0, 'RFEA circular 181/2025, anexo 2 (temporada 2026: 1-ene a 31-dic). Se puede renunciar a la categoría máster.'),
  (2026, 'Sénior', null, 2003, null, 1, 'RFEA circular 181/2025, anexo 2'),
  (2026, 'Sub-23', 2004, 2006, null, 2, 'RFEA circular 181/2025, anexo 2'),
  (2026, 'Sub-20', 2007, 2008, null, 3, 'RFEA circular 181/2025, anexo 2'),
  (2026, 'Sub-18', 2009, 2010, null, 4, 'RFEA circular 181/2025, anexo 2'),
  (2026, 'Sub-16', 2011, 2012, null, 5, 'RFEA circular 181/2025, anexo 2'),
  (2026, 'Sub-14', 2013, 2014, null, 6, 'RFEA circular 181/2025, anexo 2'),
  (2026, 'Sub-12', 2015, 2016, null, 7, 'RFEA circular 181/2025, anexo 2'),
  (2026, 'Sub-10', 2017, 2018, null, 8, 'RFEA circular 181/2025, anexo 2'),
  (2026, 'Sub-8',  2019, null, null, 9, 'RFEA circular 181/2025, anexo 2'),
  (2025, 'Máster', null, null, 35,   0, 'RFEA circular 161/2024, anexo 2 (temporada 2025: 1-ene a 31-dic). Se puede renunciar a la categoría máster.'),
  (2025, 'Sénior', null, 2002, null, 1, 'RFEA circular 161/2024, anexo 2'),
  (2025, 'Sub-23', 2003, 2005, null, 2, 'RFEA circular 161/2024, anexo 2'),
  (2025, 'Sub-20', 2006, 2007, null, 3, 'RFEA circular 161/2024, anexo 2'),
  (2025, 'Sub-18', 2008, 2009, null, 4, 'RFEA circular 161/2024, anexo 2'),
  (2025, 'Sub-16', 2010, 2011, null, 5, 'RFEA circular 161/2024, anexo 2'),
  (2025, 'Sub-14', 2012, 2013, null, 6, 'RFEA circular 161/2024, anexo 2'),
  (2025, 'Sub-12', 2014, 2015, null, 7, 'RFEA circular 161/2024, anexo 2'),
  (2025, 'Sub-10', 2016, 2017, null, 8, 'RFEA circular 161/2024, anexo 2'),
  (2025, 'Sub-8',  2018, null, null, 9, 'RFEA circular 161/2024, anexo 2');

create or replace function public.categoria_federativa(p_fnac date, p_fecha date) returns jsonb
language plpgsql stable set search_path to 'public' as $$
declare v_t int; v_base int; v_desf int; v_nac int; v_cat text; v_ver boolean; v_fuente text;
begin
  if p_fnac is null then return jsonb_build_object('categoria', null, 'motivo', 'Sin fecha de nacimiento'); end if;
  if p_fecha is null then return jsonb_build_object('categoria', null, 'motivo', 'Sin fecha'); end if;
  v_t := extract(year from p_fecha)::int;
  if exists (select 1 from public.categorias_federativas where temporada = v_t) then v_base := v_t;
  else select temporada into v_base from public.categorias_federativas where verificada
       order by abs(temporada - v_t), temporada desc limit 1;
  end if;
  if v_base is null then return jsonb_build_object('categoria', null, 'motivo', 'Sin regla cargada'); end if;
  v_desf := v_t - v_base;
  v_nac := extract(year from p_fnac)::int - v_desf;
  select bool_and(verificada), min(fuente) into v_ver, v_fuente from public.categorias_federativas where temporada = v_base;
  -- Máster: por edad cumplida ese día (no por el año).
  select categoria into v_cat from public.categorias_federativas
   where temporada = v_base and edad_desde is not null and p_fecha >= (p_fnac + make_interval(years => edad_desde))::date
   order by edad_desde desc limit 1;
  if v_cat is null then
    select categoria into v_cat from public.categorias_federativas
     where temporada = v_base and edad_desde is null
       and (nacidos_desde is null or v_nac >= nacidos_desde) and (nacidos_hasta is null or v_nac <= nacidos_hasta)
     order by orden limit 1;
  end if;
  return jsonb_build_object('categoria', v_cat, 'temporada_federativa', v_t, 'regla', v_base,
    'verificada', (v_desf = 0 and coalesce(v_ver, false)),
    'motivo', case when v_desf = 0 then v_fuente else 'Provisional: regla de ' || v_base || ' desplazada ' || v_desf || ' año(s); falta la circular de ' || v_t end);
end $$;

-- 3 · Catálogo de pruebas: distancia, condiciones, alias y correspondencias ------------
alter table public.pruebas
  add column distancia_m numeric,
  add column condiciones text[] not null default '{}';

create or replace function public.prueba_normalizar(t text) returns text
language sql immutable set search_path to 'public' as $$
  select regexp_replace(
           regexp_replace(
             regexp_replace(
               translate(lower(btrim(coalesce(t,''))), 'áéíóúüàèìòùâêîôûç', 'aeiouuaeiouaeiouc'),
               '(\d)\.(\d)', '\1\2', 'g'),
             '(metros|metro|mts|mt)', 'm', 'g'),
           '[\s\-_]+', '', 'g');
$$;

update public.pruebas set distancia_m = case
    when nombre = 'Milla' then 1609.344
    when nombre = 'Media maratón' then 21097.5
    when nombre = 'Maratón' then 42195
    else (regexp_match(public.prueba_normalizar(nombre), '^(\d+)m'))[1]::numeric end
  where ambito = 'atletismo' and disciplina in ('velocidad','vallas','medio fondo','fondo','marcha');
update public.pruebas set condiciones = '{altura_valla_m,separacion_m,distancia_primera_m,distancia_final_m}' where ambito = 'atletismo' and disciplina = 'vallas';
update public.pruebas set condiciones = '{altura_obstaculo_m}' where nombre = '3.000 m obstáculos';
update public.pruebas set condiciones = '{peso_kg}' where ambito = 'atletismo' and disciplina = 'lanzamiento';

create table public.pruebas_alias (
  id          uuid primary key default gen_random_uuid(),
  alias       text not null,
  alias_norm  text not null unique,
  prueba_id   uuid not null references public.pruebas(id) on delete cascade,
  condiciones jsonb not null default '{}',
  creado_por  uuid,
  creado_en   timestamptz not null default now()
);

create table public.pruebas_correspondencias (
  id           uuid primary key default gen_random_uuid(),
  texto        text not null,                -- el texto original (uno de los vistos)
  texto_norm   text not null unique,
  origenes     text[] not null default '{}', -- perfil, marcas, objetivos, competiciones
  apariciones  int not null default 0,
  estado       text not null check (estado in ('exacta','propuesta','ambigua','sin_catalogo','confirmada','descartada')),
  prueba_id    uuid references public.pruebas(id) on delete set null,
  condiciones  jsonb not null default '{}',
  candidatos   uuid[] not null default '{}',
  motivo       text,
  revisado_por uuid,
  revisado_en  timestamptz,
  actualizado_en timestamptz not null default now()
);

-- Qué prueba del catálogo es un texto. No escribe nada: solo propone.
create or replace function public.prueba_resolver(p_texto text) returns jsonb
language plpgsql stable set search_path to 'public' as $$
declare t text := btrim(coalesce(p_texto,'')); n text; c text; m text[]; cond jsonb := '{}'; v uuid; cand uuid[]; d numeric; v_pid uuid; v_cond jsonb;
begin
  if t = '' then return jsonb_build_object('estado','sin_catalogo','motivo','Vacío'); end if;
  -- La altura de la valla entre paréntesis («60 m vallas (0,991)») es una condición, no otra prueba.
  m := regexp_match(t, '^(.*[^\s(])\s*\(\s*([0-9]+[.,][0-9]+)\s*\)\s*$');
  if m is not null then t := m[1]; cond := jsonb_build_object('altura_valla_m', replace(m[2], ',', '.')::numeric); end if;
  n := public.prueba_normalizar(t);
  select id into v from public.pruebas where ambito = 'atletismo' and public.prueba_normalizar(nombre) = n limit 1;
  if v is not null then return jsonb_build_object('estado','exacta','prueba_id',v,'condiciones',cond); end if;
  select prueba_id, condiciones into v_pid, v_cond from public.pruebas_alias where alias_norm = n;
  if v_pid is not null then return jsonb_build_object('estado','confirmada','prueba_id',v_pid,'condiciones',v_cond || cond,'motivo','Alias confirmado'); end if;
  select prueba_id, condiciones into v_pid, v_cond from public.pruebas_correspondencias where texto_norm = n and estado = 'confirmada';
  if v_pid is not null then return jsonb_build_object('estado','confirmada','prueba_id',v_pid,'condiciones',v_cond || cond,'motivo','Correspondencia confirmada'); end if;
  c := n;
  if c ~ '^\d+m?(mv|v|vallas|mvallas)$' then                         -- 400mv, 400 vallas, 110v
    d := (regexp_match(c, '^(\d+)'))[1]::numeric;
    select array_agg(id) into cand from public.pruebas where ambito='atletismo' and disciplina='vallas' and distancia_m = d;
  elsif c ~ '^\d+m?(l|lisos|mlisos)$' then                            -- 400 lisos, 400m lisos
    d := (regexp_match(c, '^(\d+)'))[1]::numeric;
    select array_agg(id) into cand from public.pruebas where ambito='atletismo' and disciplina in ('velocidad','medio fondo','fondo') and distancia_m = d;
  elsif c ~ '^\d+m?$' then                                            -- «60», «400»: puede ser lisos o vallas
    d := (regexp_match(c, '^(\d+)'))[1]::numeric;
    select array_agg(id) into cand from public.pruebas where ambito='atletismo' and distancia_m = d;
  elsif c ~ '^\d+m?(mobstaculos|obstaculos)$' then
    d := (regexp_match(c, '^(\d+)'))[1]::numeric;
    select array_agg(id) into cand from public.pruebas where ambito='atletismo' and nombre ilike '%obstáculos%' and distancia_m = d;
  elsif c ~ '^\d+m?(mmarcha|marcha)$' then
    d := (regexp_match(c, '^(\d+)'))[1]::numeric;
    select array_agg(id) into cand from public.pruebas where ambito='atletismo' and disciplina='marcha' and distancia_m = d;
  elsif c in ('marcha') then
    select array_agg(id) into cand from public.pruebas where ambito='atletismo' and disciplina='marcha';
  elsif c in ('obstaculos') then
    select array_agg(id) into cand from public.pruebas where ambito='atletismo' and nombre ilike '%obstáculos%';
  elsif c in ('vallas','v') then
    select array_agg(id) into cand from public.pruebas where ambito='atletismo' and disciplina='vallas';
  elsif c in ('altura','longitud','triple','pertiga','peso','disco','jabalina','martillo') then
    select array_agg(id) into cand from public.pruebas where ambito='atletismo' and public.prueba_normalizar(nombre) like '%' || c || '%';
  end if;
  cand := coalesce(cand, '{}');
  if cardinality(cand) = 1 then return jsonb_build_object('estado','propuesta','prueba_id',cand[1],'condiciones',cond,'candidatos',to_jsonb(cand),'motivo','Una sola prueba posible: falta confirmarla'); end if;
  if cardinality(cand) > 1 then return jsonb_build_object('estado','ambigua','condiciones',cond,'candidatos',to_jsonb(cand),'motivo','Puede ser más de una prueba: hay que elegir'); end if;
  return jsonb_build_object('estado','sin_catalogo','condiciones',cond,'motivo','No está en el catálogo');
end $$;

-- Recorre los textos que se usan (perfil, marcas, objetivos, competiciones) y deja su
-- propuesta. Lo confirmado o descartado por una persona no se toca.
create or replace function public.pruebas_correspondencias_actualizar() returns int
language plpgsql security definer set search_path to 'public' as $$
declare r record; x jsonb; k int := 0;
begin
  for r in
    with t as (
      select btrim(unnest(pruebas_principales || coalesce(pruebas_secundarias, '{}'))) texto, 'perfil' origen from public.atletas
      union all select btrim(prueba), 'marcas' from public.marcas_atleta
      union all select btrim(prueba), 'objetivos' from public.atleta_objetivos
      union all select btrim(prueba), 'competiciones' from public.competicion_atleta where prueba is not null
    )
    select public.prueba_normalizar(regexp_replace(texto, '\s*\([0-9.,\s]+\)\s*$', '')) n, min(texto) texto,
           array_agg(distinct origen) origenes, count(*) ap
      from t where coalesce(texto,'') <> '' group by 1
  loop
    x := public.prueba_resolver(r.texto);
    insert into public.pruebas_correspondencias as pc (texto, texto_norm, origenes, apariciones, estado, prueba_id, condiciones, candidatos, motivo)
    values (r.texto, r.n, r.origenes, r.ap, x->>'estado', nullif(x->>'prueba_id','')::uuid, '{}',
            coalesce(array(select jsonb_array_elements_text(coalesce(x->'candidatos','[]'::jsonb))::uuid), '{}'), x->>'motivo')
    on conflict (texto_norm) do update set
      origenes = excluded.origenes, apariciones = excluded.apariciones, actualizado_en = now(),
      estado     = case when pc.estado in ('confirmada','descartada') then pc.estado else excluded.estado end,
      prueba_id  = case when pc.estado in ('confirmada','descartada') then pc.prueba_id else excluded.prueba_id end,
      candidatos = case when pc.estado in ('confirmada','descartada') then pc.candidatos else excluded.candidatos end,
      motivo     = case when pc.estado in ('confirmada','descartada') then pc.motivo else excluded.motivo end;
    k := k + 1;
  end loop;
  return k;
end $$;

-- Quién gestiona catálogo, protocolos y correspondencias: el equipo técnico por sus papeles
-- (no por la vista activa) o quien entrena un grupo de Academia.
create or replace function public.puede_catalogo_tests() returns boolean
language sql stable security definer set search_path to 'public' as $$
  select public.soy_admin_de_verdad() or public.tengo_rol('entrenador') or public.tengo_rol('coordinador')
      or exists (select 1 from public.academia_grupos ag join public.grupos g on g.id = ag.grupo_id where g.entrenador_id = public.mi_perfil_id());
$$;

-- Una persona confirma (y, si quiere, lo deja como alias) o descarta. No reescribe textos.
create or replace function public.prueba_correspondencia_resolver(p_id uuid, p_prueba uuid, p_descartar boolean default false, p_alias boolean default true) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare pc public.pruebas_correspondencias%rowtype;
begin
  if not public.puede_catalogo_tests() then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into pc from public.pruebas_correspondencias where id = p_id for update;
  if pc.id is null then raise exception 'No existe esa correspondencia.'; end if;
  if p_descartar then
    update public.pruebas_correspondencias set estado = 'descartada', revisado_por = public.mi_perfil_id(), revisado_en = now() where id = p_id;
    return jsonb_build_object('ok', true, 'estado', 'descartada');
  end if;
  if p_prueba is null or not exists (select 1 from public.pruebas where id = p_prueba) then raise exception 'Elige una prueba del catálogo.'; end if;
  update public.pruebas_correspondencias set estado = 'confirmada', prueba_id = p_prueba, revisado_por = public.mi_perfil_id(), revisado_en = now(),
         motivo = 'Confirmada por una persona' where id = p_id;
  if p_alias and pc.estado <> 'exacta' then
    insert into public.pruebas_alias (alias, alias_norm, prueba_id, creado_por) values (pc.texto, pc.texto_norm, p_prueba, public.mi_perfil_id())
    on conflict (alias_norm) do update set prueba_id = excluded.prueba_id;
  end if;
  return jsonb_build_object('ok', true, 'estado', 'confirmada');
end $$;

-- 4 · Objetivos: un único registro, por temporada de planificación --------------------
-- (atleta_objetivos tiene 0 filas: se cambia la clave sin reclasificar nada)
alter table public.atleta_objetivos
  add column temporada_id uuid references public.temporadas_planificacion(id),
  add column prueba_id    uuid references public.pruebas(id),
  add column condiciones_det jsonb not null default '{}',
  add column procedencia  text not null default 'ficha' check (procedencia in ('ficha','mis_marcas','migrada')),
  add column propuesto_por uuid;
alter table public.atleta_objetivos alter column temporada_id set not null;
alter table public.atleta_objetivos drop constraint if exists atleta_objetivos_atleta_id_prueba_temporada_tipo_key;
create unique index atleta_objetivos_unico on public.atleta_objetivos (atleta_id, prueba, temporada_id, tipo);
comment on column public.atleta_objetivos.tipo is 'acordado = objetivo acordado por el entrenador; atleta = propuesta del atleta (nunca sustituye al acordado)';
comment on column public.atleta_objetivos.condiciones_det is 'Condiciones explícitas de esa temporada: altura_valla_m, peso_kg… (las del catálogo de la prueba)';

-- El atleta (o su familia) ve sus objetivos: acordados y propuestas.
create policy "objetivos: el atleta ve los suyos" on public.atleta_objetivos for select to authenticated
  using (atleta_id in (select public.mis_atletas()));

create or replace function public.academia_objetivo_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare o public.atleta_objetivos%rowtype; v_id uuid := nullif(p->>'id','')::uuid; v_mag text; v_p jsonb; v_tem public.temporadas_planificacion%rowtype;
        v_prueba uuid := nullif(p->>'prueba_id','')::uuid; v_txt text := btrim(coalesce(p->>'prueba',''));
begin
  if v_prueba is null and v_txt <> '' then
    v_prueba := nullif(public.prueba_resolver(v_txt)->>'prueba_id','')::uuid;
    if (public.prueba_resolver(v_txt)->>'estado') not in ('exacta','confirmada') then v_prueba := null; end if;
  end if;
  if v_txt = '' and v_prueba is not null then select nombre into v_txt from public.pruebas where id = v_prueba; end if;
  select case pr.unidad when 'tiempo' then 'tiempo' when 'distancia' then 'distancia' else null end into v_mag from public.pruebas pr where pr.id = v_prueba;
  v_p := case when v_mag is null then jsonb_build_object('num', null) else public.academia_leer_valor(p->>'objetivo_texto', v_mag) end;
  if v_id is null then
    if not public.academia_puede_atleta(nullif(p->>'atleta_id','')::uuid) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
    select * into v_tem from public.temporadas_planificacion where id = nullif(p->>'temporada_id','')::uuid;
    if v_tem.id is null then raise exception 'Elige la temporada de planificación.'; end if;
    if p->>'tipo' not in ('acordado','atleta') then raise exception 'Tipo de objetivo no válido.'; end if;
    select * into o from public.atleta_objetivos where atleta_id = (p->>'atleta_id')::uuid and prueba = v_txt and temporada_id = v_tem.id and tipo = p->>'tipo';
    if o.id is not null then
      return jsonb_build_object('ok', false, 'conflicto', 'ya_existe', 'mensaje', 'Ya hay un objetivo de ese tipo para esa prueba y temporada (otra pantalla).', 'objetivo', to_jsonb(o));
    end if;
    insert into public.atleta_objetivos (atleta_id, prueba, prueba_id, temporada, temporada_id, tipo, objetivo_texto, objetivo_num, unidad, ref_marca_id, ref_texto, ref_fecha,
                                         ref_condiciones, competicion_id, fecha_referencia, condiciones, condiciones_det, estado, nota, procedencia, propuesto_por, autor_perfil_id)
    values ((p->>'atleta_id')::uuid, v_txt, v_prueba, v_tem.nombre, v_tem.id, p->>'tipo', nullif(btrim(coalesce(p->>'objetivo_texto','')),''),
            (v_p->>'num')::numeric, v_p->>'unidad', nullif(p->>'ref_marca_id','')::uuid, nullif(btrim(coalesce(p->>'ref_texto','')),''),
            nullif(p->>'ref_fecha','')::date, nullif(btrim(coalesce(p->>'ref_condiciones','')),''), nullif(p->>'competicion_id','')::uuid,
            nullif(p->>'fecha_referencia','')::date, nullif(btrim(coalesce(p->>'condiciones','')),''), coalesce(p->'condiciones_det','{}'::jsonb),
            coalesce(nullif(p->>'estado',''),'vigente'), nullif(btrim(coalesce(p->>'nota','')),''), 'ficha',
            case when p->>'tipo' = 'atleta' then public.mi_perfil_id() end, public.mi_perfil_id())
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
    condiciones_det = coalesce(p->'condiciones_det', condiciones_det), prueba_id = coalesce(v_prueba, prueba_id),
    estado = coalesce(nullif(p->>'estado',''), estado), nota = nullif(btrim(coalesce(p->>'nota','')),''), actualizado_por = public.mi_perfil_id()
  where id = o.id returning * into o;
  return jsonb_build_object('ok', true, 'objetivo', to_jsonb(o));
end $$;

-- El atleta propone (o retira) su objetivo desde «Mis marcas». Solo el suyo y solo de tipo propuesta.
create or replace function public.mis_objetivos_proponer(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare o public.atleta_objetivos%rowtype; v_id uuid := nullif(p->>'id','')::uuid; v_at uuid := nullif(p->>'atleta_id','')::uuid;
        v_tem public.temporadas_planificacion%rowtype; v_prueba uuid := nullif(p->>'prueba_id','')::uuid; v_txt text; v_mag text; v_p jsonb;
begin
  if v_id is not null then
    select * into o from public.atleta_objetivos where id = v_id for update;
    if o.id is null then raise exception 'Ese objetivo no existe.'; end if;
    v_at := o.atleta_id;
    if o.tipo <> 'atleta' then raise exception 'El objetivo acordado lo cambia tu entrenador.' using errcode = '42501'; end if;
  end if;
  -- Solo el propio atleta o su familia: el entrenador no rellena la propuesta como si fuera del atleta.
  if v_at is null or not exists (select 1 from public.atletas a where a.id = v_at and public.mi_perfil_id() in (a.perfil_id, a.perfil_padre_id)) then
    raise exception 'Sin permiso.' using errcode = '42501';
  end if;
  if v_prueba is null and v_id is null then raise exception 'Elige la prueba.'; end if;
  if v_prueba is not null then select nombre, case unidad when 'tiempo' then 'tiempo' when 'distancia' then 'distancia' end into v_txt, v_mag from public.pruebas where id = v_prueba; end if;
  if v_id is null then
    select * into v_tem from public.temporadas_planificacion where id = nullif(p->>'temporada_id','')::uuid;
    if v_tem.id is null then raise exception 'Elige la temporada.'; end if;
    select * into o from public.atleta_objetivos where atleta_id = v_at and prueba = v_txt and temporada_id = v_tem.id and tipo = 'atleta';
    if o.id is not null then return jsonb_build_object('ok', false, 'conflicto', 'ya_existe', 'mensaje', 'Ya tienes una propuesta para esa prueba y temporada.', 'objetivo', to_jsonb(o)); end if;
    v_p := case when v_mag is null then jsonb_build_object('num', null) else public.academia_leer_valor(p->>'objetivo_texto', v_mag) end;
    insert into public.atleta_objetivos (atleta_id, prueba, prueba_id, temporada, temporada_id, tipo, objetivo_texto, objetivo_num, unidad, condiciones_det, nota, procedencia, propuesto_por, autor_perfil_id)
    values (v_at, v_txt, v_prueba, v_tem.nombre, v_tem.id, 'atleta', nullif(btrim(coalesce(p->>'objetivo_texto','')),''), (v_p->>'num')::numeric, v_p->>'unidad',
            coalesce(p->'condiciones_det','{}'::jsonb), nullif(btrim(coalesce(p->>'nota','')),''), 'mis_marcas', public.mi_perfil_id(), public.mi_perfil_id())
    returning * into o;
    return jsonb_build_object('ok', true, 'objetivo', to_jsonb(o));
  end if;
  if nullif(p->>'version_base','')::int is distinct from o.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Ha cambiado desde que lo abriste: vuelve a abrirlo.', 'objetivo', to_jsonb(o));
  end if;
  select case unidad when 'tiempo' then 'tiempo' when 'distancia' then 'distancia' end into v_mag from public.pruebas where id = o.prueba_id;
  v_p := case when v_mag is null then jsonb_build_object('num', null) else public.academia_leer_valor(p->>'objetivo_texto', v_mag) end;
  update public.atleta_objetivos set
    objetivo_texto = coalesce(nullif(btrim(coalesce(p->>'objetivo_texto','')),''), objetivo_texto), objetivo_num = coalesce((v_p->>'num')::numeric, objetivo_num),
    estado = case when (p->>'retirar')::boolean then 'descartado' else estado end,
    nota = coalesce(nullif(btrim(coalesce(p->>'nota','')),''), nota), actualizado_por = public.mi_perfil_id()
  where id = o.id returning * into o;
  return jsonb_build_object('ok', true, 'objetivo', to_jsonb(o));
end $$;

-- marcas_atleta ya no recibe objetivos nuevos (los antiguos, si los hubiera, se ven y se migran aparte).
create or replace function public.marcas_atleta_sin_objetivo() returns trigger
language plpgsql set search_path to 'public' as $$
begin
  if new.tipo = 'objetivo' and (tg_op = 'INSERT' or old.tipo is distinct from 'objetivo') then
    raise exception 'Los objetivos ya no se guardan como marcas: se proponen en «Mis objetivos».' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger trg_marcas_atleta_sin_objetivo before insert or update on public.marcas_atleta
  for each row execute function public.marcas_atleta_sin_objetivo();

-- 5 · Resultados (marcas_atleta) ----------------------------------------------------
alter table public.marcas_atleta drop constraint marcas_atleta_contexto_check;
alter table public.marcas_atleta add constraint marcas_atleta_contexto_check
  check (contexto is null or contexto in ('competicion','entreno','estimado'));
alter table public.marcas_atleta
  add column prueba_id       uuid references public.pruebas(id),
  add column condiciones     jsonb not null default '{}',
  add column metodo          text check (metodo in ('manual','fotocelulas','electronico_competicion','video','otro','no_consta')),
  add column viento          numeric check (viento between -20 and 20),
  add column unidad          text check (unidad in ('s','m','puntos')),
  add column fuente_url      text,
  add column fuente_texto    text,
  add column competicion_id  uuid references public.competiciones(id) on delete set null,
  add column categoria       text,
  add column categoria_origen text check (categoria_origen in ('calculada','acta','manual')),
  add column estimacion      jsonb,
  add column huella          text,
  add column nota            text,
  add column creado_por      uuid default public.mi_perfil_id(),
  add column version         int not null default 1,
  add column actualizado_por uuid,
  add column actualizado_en  timestamptz;
alter table public.marcas_atleta add constraint marcas_atleta_estimado_con_datos
  check (contexto is distinct from 'estimado' or estimacion is not null);
create unique index marcas_atleta_huella on public.marcas_atleta (huella) where huella is not null;
comment on column public.marcas_atleta.contexto is 'competicion = marca de competición; entreno = test o entrenamiento; estimado = resultado estimado (con estimacion)';
comment on column public.marcas_atleta.prueba is 'Texto original de la prueba (se conserva). La prueba del catálogo va en prueba_id o en pruebas_correspondencias.';

-- 6 · Protocolos de test --------------------------------------------------------------
create table public.test_protocolos (
  id                  uuid primary key default gen_random_uuid(),
  clave               text not null,           -- el test (cmj, 30m_tacos…); la versión distingue el procedimiento
  version             int  not null default 1,
  nombre              text not null,
  magnitud            text not null check (magnitud in ('tiempo','distancia','altura','indice','carga','repeticiones','otro')),
  unidad              text,
  menos_es_mejor      boolean not null default false,
  salida              text check (salida in ('tacos','de_pie','agachado','lanzada','no_aplica')),
  distancia_entrada_m numeric,
  tramo_desde_m       numeric,
  tramo_hasta_m       numeric,
  inicio_crono        text,
  fin_crono           text,
  superficie          text,
  calzado             text,
  recuperacion        text,
  orden_intentos      text,
  intentos_previstos  int,
  especificos         jsonb not null default '{}',  -- salto, fuerza, vallas, lanzamiento
  descripcion         text,
  activo              boolean not null default true,
  creado_por          uuid,
  creado_en           timestamptz not null default now(),
  unique (clave, version)
);
-- Los tests que ya existen, como esqueleto: nombre y unidad. El resto queda «no consta» hasta que alguien lo complete.
insert into public.test_protocolos (clave, nombre, magnitud, unidad, menos_es_mejor, descripcion) values
  ('30_lanzado','30 m lanzado','tiempo','s',true,'Por completar'),
  ('150m','150 m lanzado','tiempo','s',true,'Por completar'),
  ('cmj','CMJ','altura','cm',false,'Por completar'),
  ('sj','SJ','altura','cm',false,'Por completar'),
  ('abalakov','Abalakov','altura','cm',false,'Por completar'),
  ('rsi','Test RSI 10 pogos','indice',null,false,'Por completar'),
  ('10m','10 m salida de tacos','tiempo','s',true,'Por completar'),
  ('30m_tacos','30 m desde tacos','tiempo','s',true,'Por completar'),
  ('60m','60 m lanzado','tiempo','s',true,'Por completar'),
  ('300m','300 m','tiempo','s',true,'Por completar'),
  ('1000m','1000 m','tiempo','s',true,'Por completar'),
  ('salto_horizontal','Salto horizontal','distancia','m',false,'Por completar'),
  ('balon_medicinal','Balón medicinal','distancia','m',false,'Por completar'),
  ('drop_jump','Drop jump','altura','cm',false,'Por completar');

alter table public.test_resultados drop constraint test_resultados_test_check;
alter table public.test_resultados
  add column protocolo_id     uuid references public.test_protocolos(id),
  add column intentos_detalle jsonb check (intentos_detalle is null or jsonb_typeof(intentos_detalle) = 'array'),
  add column metodo           text check (metodo in ('manual','fotocelulas','electronico_competicion','video','plataforma','app','otro','no_consta')),
  add column condiciones      jsonb not null default '{}',
  add column nota             text,
  add column version          int not null default 1,
  add column actualizado_por  uuid,
  add column actualizado_en   timestamptz;
-- El test tiene que existir como protocolo (los 14 de siempre ya están).
create or replace function public.test_resultados_test_valido() returns trigger
language plpgsql set search_path to 'public' as $$
begin
  if not exists (select 1 from public.test_protocolos where clave = new.test) then
    raise exception 'Ese test no tiene protocolo: créalo antes.' using errcode = 'P0001';
  end if;
  if new.protocolo_id is not null and not exists (select 1 from public.test_protocolos where id = new.protocolo_id and clave = new.test) then
    raise exception 'El protocolo no es de ese test.' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger trg_test_resultados_test_valido before insert or update on public.test_resultados
  for each row execute function public.test_resultados_test_valido();

-- 7 · RM ------------------------------------------------------------------------------
alter table public.rm_atleta
  add column variante         text,
  add column recorrido        text,
  add column lateralidad      text check (lateralidad in ('bilateral','unilateral')),
  add column lado             text check (lado in ('izquierda','derecha')),
  add column metodo           text check (metodo in ('medido','estimado')),
  add column formula          text,
  add column datos_estimacion jsonb,
  add column version          int not null default 1,
  add column actualizado_por  uuid,
  add column actualizado_en   timestamptz;
alter table public.rm_atleta add constraint rm_atleta_estimado_con_formula
  check (metodo is distinct from 'estimado' or (formula is not null and datos_estimacion is not null));
drop index public.rm_atleta_unico_por_dia;
create unique index rm_atleta_unico_por_dia on public.rm_atleta
  (atleta_id, lower(btrim(ejercicio)), lower(btrim(coalesce(variante,''))), coalesce(lateralidad,''), coalesce(lado,''), coalesce(metodo,''), fecha_test);

-- 8 · Versión e historial de correcciones (marcas, tests, RM) ------------------------------
create table public.resultados_historial (
  id          bigserial primary key,
  tabla       text not null check (tabla in ('marcas_atleta','test_resultados','rm_atleta')),
  registro_id uuid not null,
  atleta_id   uuid not null,
  version     int,
  accion      text not null check (accion in ('cambio','borrado')),
  datos       jsonb not null,
  motivo      text,
  cambiado_por uuid,
  cambiado_en timestamptz not null default now()
);
create index resultados_historial_reg on public.resultados_historial (tabla, registro_id, cambiado_en);

create or replace function public.resultados_versionar() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  insert into public.resultados_historial (tabla, registro_id, atleta_id, version, accion, datos, motivo, cambiado_por)
  values (tg_table_name, old.id, old.atleta_id, old.version, case when tg_op = 'DELETE' then 'borrado' else 'cambio' end,
          to_jsonb(old), nullif(current_setting('apolana.motivo', true), ''), public.mi_perfil_id());
  if tg_op = 'DELETE' then return old; end if;
  new.version := old.version + 1;
  new.actualizado_en := now();
  new.actualizado_por := public.mi_perfil_id();
  return new;
end $$;
create trigger trg_marcas_atleta_versionar before update or delete on public.marcas_atleta
  for each row execute function public.resultados_versionar();
create trigger trg_test_resultados_versionar before update or delete on public.test_resultados
  for each row execute function public.resultados_versionar();
create trigger trg_rm_atleta_versionar before update or delete on public.rm_atleta
  for each row execute function public.resultados_versionar();

-- 9 · Guardar desde Academia (con candado de versión y sin duplicar importaciones) --------
create or replace function public.puede_resultados(p_atleta uuid) returns boolean
language sql stable security definer set search_path to 'public' as $$
  select public.academia_puede_atleta(p_atleta) or public.soy_entrenador_de(p_atleta) or (select public.es_admin());
$$;

create or replace function public.resultado_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare m public.marcas_atleta%rowtype; v_id uuid := nullif(p->>'id','')::uuid; v_at uuid := nullif(p->>'atleta_id','')::uuid;
        v_pr public.pruebas%rowtype; v_txt text; v_lee jsonb; v_cat jsonb; v_fn date; v_alt numeric; v_fecha date;
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
                                      fuente_url, fuente_texto, competicion_id, categoria, categoria_origen, estimacion, huella, nota, creado_por)
    values (v_at, v_txt, v_pr.id, nullif(p->>'tipo',''), (v_lee->>'num')::numeric, btrim(p->>'valor_texto'), coalesce(v_lee->>'unidad', case v_pr.unidad when 'puntos' then 'puntos' end),
            v_fecha, nullif(btrim(coalesce(p->>'sede','')),''), nullif(p->>'contexto',''), coalesce(p->'condiciones','{}'::jsonb), nullif(p->>'metodo',''),
            nullif(p->>'viento','')::numeric, nullif(btrim(coalesce(p->>'fuente_url','')),''), nullif(btrim(coalesce(p->>'fuente_texto','')),''),
            nullif(p->>'competicion_id','')::uuid,
            coalesce(nullif(p->>'categoria',''), v_cat->>'categoria'),
            case when nullif(p->>'categoria','') is not null then coalesce(nullif(p->>'categoria_origen',''),'manual') when v_cat->>'categoria' is not null then 'calculada' end,
            case when p->>'contexto' = 'estimado' then p->'estimacion' end, nullif(p->>'huella',''), nullif(btrim(coalesce(p->>'nota','')),''), public.mi_perfil_id())
    returning * into m;
    return jsonb_build_object('ok', true, 'resultado', to_jsonb(m), 'categoria', v_cat);
  end if;
  perform set_config('apolana.motivo', coalesce(p->>'motivo', ''), true);
  update public.marcas_atleta set prueba = v_txt, prueba_id = v_pr.id, tipo = nullif(p->>'tipo',''), tiempo_segundos = (v_lee->>'num')::numeric,
         tiempo_display = btrim(p->>'valor_texto'), unidad = coalesce(v_lee->>'unidad', unidad), fecha = v_fecha, sede = nullif(btrim(coalesce(p->>'sede','')),''),
         contexto = nullif(p->>'contexto',''), condiciones = coalesce(p->'condiciones','{}'::jsonb), metodo = nullif(p->>'metodo',''), viento = nullif(p->>'viento','')::numeric,
         fuente_url = nullif(btrim(coalesce(p->>'fuente_url','')),''), fuente_texto = nullif(btrim(coalesce(p->>'fuente_texto','')),''),
         competicion_id = nullif(p->>'competicion_id','')::uuid,
         categoria = coalesce(nullif(p->>'categoria',''), case when categoria_origen = 'calculada' or categoria is null then v_cat->>'categoria' else categoria end),
         categoria_origen = case when nullif(p->>'categoria','') is not null then coalesce(nullif(p->>'categoria_origen',''),'manual')
                                 when categoria_origen = 'calculada' or categoria is null then case when v_cat->>'categoria' is not null then 'calculada' end else categoria_origen end,
         estimacion = case when p->>'contexto' = 'estimado' then p->'estimacion' end, nota = nullif(btrim(coalesce(p->>'nota','')),'')
   where id = m.id returning * into m;
  return jsonb_build_object('ok', true, 'resultado', to_jsonb(m), 'categoria', v_cat);
end $$;

create or replace function public.test_resultado_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare t public.test_resultados%rowtype; v_at uuid := nullif(p->>'atleta_id','')::uuid; v_pro public.test_protocolos%rowtype; v_bat uuid := nullif(p->>'bateria_id','')::uuid;
        v_int jsonb := coalesce(p->'intentos_detalle', '[]'::jsonb); v_val jsonb; v_mejor numeric; x jsonb;
begin
  if v_at is null or not public.puede_resultados(v_at) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select * into v_pro from public.test_protocolos where id = nullif(p->>'protocolo_id','')::uuid;
  if v_pro.id is null then raise exception 'Elige el protocolo.'; end if;
  -- Cada intento: valor (o nada), válido / nulo / incompleto. Lo que falta NO es cero.
  for x in select * from jsonb_array_elements(v_int) loop
    if coalesce(x->>'estado','') not in ('valido','nulo','incompleto') then raise exception 'Cada intento es válido, nulo o incompleto.'; end if;
    if x->>'estado' = 'valido' and nullif(x->>'valor','') is null then raise exception 'Un intento válido necesita su valor.'; end if;
  end loop;
  select coalesce(jsonb_agg((e->>'valor')::numeric order by (e->>'n')::int), '[]'::jsonb) into v_val
    from jsonb_array_elements(v_int) e where e->>'estado' = 'valido';
  select case when v_pro.menos_es_mejor then min(v::numeric) else max(v::numeric) end into v_mejor from jsonb_array_elements_text(v_val) v;
  if v_bat is null then
    select id into v_bat from public.test_baterias where fecha = (p->>'fecha')::date and grupo_id is not distinct from nullif(p->>'grupo_id','')::uuid
       and coalesce(sede,'') = coalesce(nullif(btrim(coalesce(p->>'sede','')),''),'') order by created_at limit 1;
    if v_bat is null then
      insert into public.test_baterias (fecha, grupo_id, sede, temperatura, viento, notas, creado_por)
      values ((p->>'fecha')::date, nullif(p->>'grupo_id','')::uuid, nullif(btrim(coalesce(p->>'sede','')),''), nullif(p->>'temperatura','')::numeric,
              nullif(p->>'viento','')::numeric, nullif(btrim(coalesce(p->>'notas_bateria','')),''), public.mi_perfil_id()) returning id into v_bat;
    end if;
  end if;
  select * into t from public.test_resultados where bateria_id = v_bat and atleta_id = v_at and test = v_pro.clave for update;
  if t.id is null then
    insert into public.test_resultados (bateria_id, atleta_id, test, protocolo_id, intentos, intentos_detalle, mejor, formato_rsi, no_asiste, metodo, condiciones, nota)
    values (v_bat, v_at, v_pro.clave, v_pro.id, case when (p->>'no_asiste')::boolean then '[]'::jsonb else v_val end, v_int,
            case when (p->>'no_asiste')::boolean then null else v_mejor end, nullif(p->>'formato_rsi','')::int, coalesce((p->>'no_asiste')::boolean, false),
            nullif(p->>'metodo',''), coalesce(p->'condiciones','{}'::jsonb), nullif(btrim(coalesce(p->>'nota','')),''))
    returning * into t;
    return jsonb_build_object('ok', true, 'resultado', to_jsonb(t));
  end if;
  if nullif(p->>'version_base','')::int is distinct from t.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Ya hay un resultado de ese test, ese día, para este atleta (otra pantalla): ábrelo y corrígelo.', 'resultado', to_jsonb(t));
  end if;
  perform set_config('apolana.motivo', coalesce(p->>'motivo', ''), true);
  update public.test_resultados set protocolo_id = v_pro.id, intentos = case when (p->>'no_asiste')::boolean then '[]'::jsonb else v_val end, intentos_detalle = v_int,
         mejor = case when (p->>'no_asiste')::boolean then null else v_mejor end, formato_rsi = nullif(p->>'formato_rsi','')::int,
         no_asiste = coalesce((p->>'no_asiste')::boolean, false), metodo = nullif(p->>'metodo',''), condiciones = coalesce(p->'condiciones','{}'::jsonb),
         nota = nullif(btrim(coalesce(p->>'nota','')),'')
   where id = t.id returning * into t;
  return jsonb_build_object('ok', true, 'resultado', to_jsonb(t));
end $$;

create or replace function public.rm_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare r public.rm_atleta%rowtype; v_id uuid := nullif(p->>'id','')::uuid; v_at uuid := nullif(p->>'atleta_id','')::uuid; v_kg numeric;
begin
  if v_id is not null then select * into r from public.rm_atleta where id = v_id for update; v_at := r.atleta_id; end if;
  if v_at is null or not public.puede_resultados(v_at) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  v_kg := replace(nullif(btrim(coalesce(p->>'peso_kg','')),''), ',', '.')::numeric;
  if v_kg is null or v_kg <= 0 or v_kg > 500 then raise exception 'Pon los kilos (entre 1 y 500).'; end if;
  if p->>'metodo' = 'estimado' and (nullif(btrim(coalesce(p->>'formula','')),'') is null or p->'datos_estimacion' is null) then
    raise exception 'Un RM estimado necesita la fórmula y los datos usados.';
  end if;
  if v_id is null then
    insert into public.rm_atleta (atleta_id, ejercicio, variante, recorrido, lateralidad, lado, metodo, formula, datos_estimacion, peso_kg, fecha_test, nota, anotado_por)
    values (v_at, btrim(p->>'ejercicio'), nullif(btrim(coalesce(p->>'variante','')),''), nullif(btrim(coalesce(p->>'recorrido','')),''), nullif(p->>'lateralidad',''),
            nullif(p->>'lado',''), nullif(p->>'metodo',''), nullif(btrim(coalesce(p->>'formula','')),''), case when p->>'metodo' = 'estimado' then p->'datos_estimacion' end,
            v_kg, (p->>'fecha_test')::date, nullif(btrim(coalesce(p->>'nota','')),''), public.mi_perfil_id())
    returning * into r;
    return jsonb_build_object('ok', true, 'rm', to_jsonb(r));
  end if;
  if nullif(p->>'version_base','')::int is distinct from r.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla lo ha cambiado: vuelve a abrirlo.', 'rm', to_jsonb(r));
  end if;
  perform set_config('apolana.motivo', coalesce(p->>'motivo', ''), true);
  update public.rm_atleta set ejercicio = btrim(p->>'ejercicio'), variante = nullif(btrim(coalesce(p->>'variante','')),''), recorrido = nullif(btrim(coalesce(p->>'recorrido','')),''),
         lateralidad = nullif(p->>'lateralidad',''), lado = nullif(p->>'lado',''), metodo = nullif(p->>'metodo',''), formula = nullif(btrim(coalesce(p->>'formula','')),''),
         datos_estimacion = case when p->>'metodo' = 'estimado' then p->'datos_estimacion' end, peso_kg = v_kg, fecha_test = (p->>'fecha_test')::date,
         nota = nullif(btrim(coalesce(p->>'nota','')),'')
   where id = r.id returning * into r;
  return jsonb_build_object('ok', true, 'rm', to_jsonb(r));
end $$;

-- 10 · Permisos ---------------------------------------------------------------------------
alter table public.temporadas_planificacion enable row level security;
alter table public.categorias_federativas enable row level security;
alter table public.pruebas_alias enable row level security;
alter table public.pruebas_correspondencias enable row level security;
alter table public.test_protocolos enable row level security;
alter table public.resultados_historial enable row level security;
revoke all on public.temporadas_planificacion, public.categorias_federativas, public.pruebas_alias, public.pruebas_correspondencias,
              public.test_protocolos, public.resultados_historial from public, anon, authenticated;
grant select on public.temporadas_planificacion, public.categorias_federativas, public.pruebas_alias, public.pruebas_correspondencias,
               public.test_protocolos, public.resultados_historial to authenticated;
grant insert, update on public.temporadas_planificacion, public.test_protocolos to authenticated;
create policy "temporadas: lectura" on public.temporadas_planificacion for select to authenticated using (true);
create policy "temporadas: las fechas las cambia administración" on public.temporadas_planificacion for update to authenticated
  using ((select public.es_admin())) with check ((select public.es_admin()));
create policy "categorías: lectura" on public.categorias_federativas for select to authenticated using (true);
create policy "alias: lectura" on public.pruebas_alias for select to authenticated using (true);
create policy "correspondencias: el equipo técnico" on public.pruebas_correspondencias for select to authenticated using ((select public.puede_catalogo_tests()));
create policy "protocolos: lectura" on public.test_protocolos for select to authenticated using (true);
create policy "protocolos: alta del equipo técnico" on public.test_protocolos for insert to authenticated with check ((select public.puede_catalogo_tests()));
-- Un protocolo con resultados no se reescribe: se crea otra versión. Sin resultados, se puede completar.
create policy "protocolos: completar si no tiene resultados" on public.test_protocolos for update to authenticated
  using ((select public.puede_catalogo_tests()) and not exists (select 1 from public.test_resultados tr where tr.protocolo_id = test_protocolos.id))
  with check ((select public.puede_catalogo_tests()));
create policy "historial: quien puede ver al atleta" on public.resultados_historial for select to authenticated
  using (public.puede_resultados(atleta_id) or atleta_id in (select public.mis_atletas()));

-- Columnas nuevas de competicion_atleta (tiene permisos por columna)
alter table public.competicion_atleta add column prueba_id uuid references public.pruebas(id), add column condiciones jsonb not null default '{}';
grant select (prueba_id, condiciones), insert (prueba_id, condiciones), update (prueba_id, condiciones) on public.competicion_atleta to authenticated;

revoke execute on function public.categoria_federativa(date, date), public.prueba_normalizar(text), public.prueba_resolver(text),
  public.pruebas_correspondencias_actualizar(), public.prueba_correspondencia_resolver(uuid, uuid, boolean, boolean),
  public.academia_objetivo_guardar(jsonb), public.mis_objetivos_proponer(jsonb), public.resultado_guardar(jsonb),
  public.test_resultado_guardar(jsonb), public.rm_guardar(jsonb), public.puede_resultados(uuid), public.puede_catalogo_tests(),
  public.marcas_atleta_sin_objetivo(), public.test_resultados_test_valido(), public.resultados_versionar() from public, anon;
grant execute on function public.categoria_federativa(date, date), public.prueba_normalizar(text), public.prueba_resolver(text),
  public.pruebas_correspondencias_actualizar(), public.prueba_correspondencia_resolver(uuid, uuid, boolean, boolean),
  public.academia_objetivo_guardar(jsonb), public.mis_objetivos_proponer(jsonb), public.resultado_guardar(jsonb),
  public.test_resultado_guardar(jsonb), public.rm_guardar(jsonb), public.puede_resultados(uuid), public.puede_catalogo_tests() to authenticated;

-- Primera pasada de correspondencias (solo propone; no cambia ningún texto).
select public.pruebas_correspondencias_actualizar();

commit;
