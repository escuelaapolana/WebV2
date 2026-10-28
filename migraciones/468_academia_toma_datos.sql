-- ===========================================================================
-- 468 · Academia · datos tomados por el entrenador (registro rápido en pista)
-- ---------------------------------------------------------------------------
-- Autorizado por Andrés (28-oct). Lo que el entrenador apunta en pista es SUYO
-- y va aparte de lo que responde el atleta (registros_sesion), que no se toca.
--   · academia_toma_datos: un dato por fila. Identificado por atleta, sesión,
--     VERSIÓN de la sesión y FILA del plan (su id, nunca el nombre ni la
--     posición), más alcance (repetición, serie, fila, bloque o sesión), serie,
--     repetición, parte («250», «150»), tramo («total», «entrada»…), magnitud
--     y lado. Texto original siempre; número y unidad solo si es inequívoco.
--   · Apuntar NO completa nada: el estado (realizado / parcial / no realizado)
--     es un dato más, con su alcance explícito. Sin dato = sin fila.
--   · Trabajo adicional y sustituciones sin inventar filas del plan.
--   · Historial de cada cambio, versión por dato (dos pantallas no se pisan) e
--     id generado en la pantalla (un reintento no duplica).
--   · academia_discrepancias: cuando el atleta y el entrenador dan valores
--     distintos para la misma repetición, tramo y magnitud, quién decide qué
--     valor es la referencia, cuándo, y sin borrar ninguno de los dos.
--   · Las sesiones con datos del entrenador no se borran: se archivan (como
--     con los registros del atleta).
-- Solo se escribe por las funciones de abajo; leer y escribir exige
-- academia_puede() del grupo de la sesión.
-- ===========================================================================
begin;

-- 1 · Los datos ------------------------------------------------------------------
create table public.academia_toma_datos (
  id                  uuid primary key default gen_random_uuid(),
  sesion_id           uuid not null references public.sesiones(id) on delete restrict,
  sesion_version      integer not null,
  atleta_id           uuid not null references public.atletas(id) on delete cascade,
  fila_id             text,          -- id de la fila del plan; null = trabajo adicional o dato de la sesión
  bloque              text,          -- etiqueta del bloque, solo para leer: NO se vincula por ella
  alcance             text not null check (alcance in ('repeticion','serie','fila','bloque','sesion')),
  serie               integer check (serie between 1 and 99),
  repeticion          integer check (repeticion between 1 and 99),
  parte               text check (parte is null or length(parte) <= 40),
  tramo               text not null default 'total' check (length(tramo) between 1 and 40),
  magnitud            text not null check (magnitud in ('tiempo','carga','repeticiones','distancia','estado','sustitucion','nota')),
  valor_texto         text check (valor_texto is null or length(valor_texto) <= 300),
  valor_num           numeric,
  unidad              text check (unidad in ('s','kg','reps','m')),
  ambiguo             boolean not null default false,
  metodo              text check (metodo in ('manual','fotocelulas','electronico_competicion','video','otro','no_consta')),
  carga_modo          text check (carga_modo in ('total','por_mancuerna')),
  lado                text check (lado in ('izquierdo','derecho')),
  estado              text check (estado in ('realizado','parcial','no_realizado')),
  ejercicio_realizado text check (ejercicio_realizado is null or length(ejercicio_realizado) <= 160),
  adicional           boolean not null default false,
  nota                text check (nota is null or length(nota) <= 500),
  version             integer not null default 1,
  autor_perfil_id     uuid,
  creado_en           timestamptz not null default now(),
  actualizado_por     uuid,
  actualizado_en      timestamptz not null default now(),
  anulado_en          timestamptz,
  anulado_por         uuid,
  check (adicional or fila_id is not null or alcance = 'sesion'),
  check (magnitud <> 'estado' or estado is not null),
  check (magnitud <> 'tiempo' or metodo is not null),
  check (magnitud not in ('tiempo','carga','repeticiones','distancia') or valor_texto is not null),
  check (magnitud <> 'sustitucion' or ejercicio_realizado is not null),
  check (not adicional or ejercicio_realizado is not null)
);
-- Una «casilla» = un dato vigente. Dos pantallas no crean dos.
create unique index academia_toma_una_casilla on public.academia_toma_datos
  (sesion_id, atleta_id, coalesce(fila_id,''), alcance, coalesce(serie,0), coalesce(repeticion,0), tramo, magnitud, coalesce(lado,''))
  where anulado_en is null and not adicional;
create index academia_toma_sesion on public.academia_toma_datos (sesion_id, atleta_id);

create table public.academia_toma_datos_historial (
  id           bigserial primary key,
  dato_id      uuid not null,
  version      integer not null,
  accion       text not null check (accion in ('cambio','anulado')),
  datos        jsonb not null,           -- el dato TAL COMO ERA antes del cambio
  cambiado_por uuid,
  cambiado_en  timestamptz not null default now()
);
create index academia_toma_historial_dato on public.academia_toma_datos_historial (dato_id, version);

create or replace function public.academia_toma_antes() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if tg_op = 'INSERT' then
    -- La versión del plan sobre la que se toma el dato la pone la base.
    select s.version into new.sesion_version from public.sesiones s where s.id = new.sesion_id;
    new.version := 1;
    new.autor_perfil_id := coalesce(public.mi_perfil_id(), new.autor_perfil_id);
    new.creado_en := now(); new.actualizado_en := now(); new.actualizado_por := new.autor_perfil_id;
    return new;
  end if;
  -- Lo que identifica el dato no cambia nunca: se anula y se apunta otro.
  if (new.sesion_id, new.sesion_version, new.atleta_id, coalesce(new.fila_id,''), new.alcance, coalesce(new.serie,0),
      coalesce(new.repeticion,0), new.tramo, new.magnitud, coalesce(new.lado,''), new.adicional, coalesce(new.autor_perfil_id::text,''), new.creado_en)
     is distinct from
     (old.sesion_id, old.sesion_version, old.atleta_id, coalesce(old.fila_id,''), old.alcance, coalesce(old.serie,0),
      coalesce(old.repeticion,0), old.tramo, old.magnitud, coalesce(old.lado,''), old.adicional, coalesce(old.autor_perfil_id::text,''), old.creado_en) then
    raise exception 'Lo que identifica un dato no se cambia: anúlalo y apunta otro.';
  end if;
  if old.anulado_en is not null then raise exception 'Ese dato está anulado.'; end if;
  insert into public.academia_toma_datos_historial (dato_id, version, accion, datos, cambiado_por)
  values (old.id, old.version, case when new.anulado_en is not null then 'anulado' else 'cambio' end, to_jsonb(old), public.mi_perfil_id());
  new.version := old.version + 1;
  new.actualizado_en := now();
  new.actualizado_por := public.mi_perfil_id();
  return new;
end $$;
create trigger trg_academia_toma_antes before insert or update on public.academia_toma_datos
  for each row execute function public.academia_toma_antes();

-- 2 · Leer lo escrito: texto original siempre; número solo si es inequívoco --------
-- Tiempo: 34,52 · 34.52 · 34,5 s · 1:28,5 · 1:02:30 · 34″52 · 1′28″5. Carga: 62,5 · 62,5 kg.
-- Repeticiones: 8. Distancia: 30 · 30 m. Lo demás queda como texto y «ambiguo».
create or replace function public.academia_leer_valor(p_texto text, p_magnitud text) returns jsonb
language plpgsql immutable set search_path to 'public' as $$
declare t text := btrim(regexp_replace(coalesce(p_texto,''), '\s+', ' ', 'g')); m text[]; n numeric; u text;
begin
  if t = '' or p_magnitud not in ('tiempo','carga','repeticiones','distancia') then
    return jsonb_build_object('num', null, 'unidad', null, 'ambiguo', false);
  end if;
  if p_magnitud = 'tiempo' then
    u := 's';
    t := regexp_replace(t, '\s*(s|seg|segundos)$', '', 'i');
    if t ~ '^\d{1,3}([.,]\d{1,3})?(″|"|'''')?$' then
      n := replace(regexp_replace(t, '(″|"|'''')$', ''), ',', '.')::numeric;
    elsif t ~ '^\d{1,3}(″|"|'''')\d{1,3}$' then                       -- 34″52
      m := regexp_match(t, '^(\d{1,3})(?:″|"|'''')(\d{1,3})$');
      n := (m[1] || '.' || m[2])::numeric;
    elsif t ~ '^\d{1,3}:\d{2}([.,]\d{1,3})?$' then                     -- 1:28,5
      m := regexp_match(t, '^(\d{1,3}):(\d{2})(?:[.,](\d{1,3}))?$');
      if m[2]::int >= 60 then return jsonb_build_object('num', null, 'unidad', u, 'ambiguo', true, 'motivo', 'Los segundos pasan de 59'); end if;
      n := m[1]::numeric * 60 + (m[2] || coalesce('.' || m[3], ''))::numeric;
    elsif t ~ '^\d{1,2}:\d{2}:\d{2}([.,]\d{1,3})?$' then               -- 1:02:30
      m := regexp_match(t, '^(\d{1,2}):(\d{2}):(\d{2})(?:[.,](\d{1,3}))?$');
      if m[2]::int >= 60 or m[3]::int >= 60 then return jsonb_build_object('num', null, 'unidad', u, 'ambiguo', true, 'motivo', 'Minutos o segundos pasan de 59'); end if;
      n := m[1]::numeric * 3600 + m[2]::numeric * 60 + (m[3] || coalesce('.' || m[4], ''))::numeric;
    elsif t ~ '^\d{1,2}(′|'')\d{2}((″|"|'''')\d{0,3})?$' then           -- 1′28″5
      m := regexp_match(t, '^(\d{1,2})(?:′|'')(\d{2})(?:(?:″|"|'''')(\d{0,3}))?$');
      if m[2]::int >= 60 then return jsonb_build_object('num', null, 'unidad', u, 'ambiguo', true, 'motivo', 'Los segundos pasan de 59'); end if;
      n := m[1]::numeric * 60 + (m[2] || case when coalesce(m[3],'') <> '' then '.' || m[3] else '' end)::numeric;
    else
      return jsonb_build_object('num', null, 'unidad', u, 'ambiguo', true, 'motivo', 'No se entiende como tiempo');
    end if;
  elsif p_magnitud = 'carga' then
    u := 'kg';
    t := regexp_replace(t, '\s*kg$', '', 'i');
    if t ~ '^\d{1,3}([.,]\d{1,2})?$' then n := replace(t, ',', '.')::numeric;
    else return jsonb_build_object('num', null, 'unidad', u, 'ambiguo', true, 'motivo', 'No se entiende como kg'); end if;
  elsif p_magnitud = 'repeticiones' then
    u := 'reps';
    if t ~ '^\d{1,3}$' then n := t::numeric;
    else return jsonb_build_object('num', null, 'unidad', u, 'ambiguo', true, 'motivo', 'No es un número de repeticiones'); end if;
  else
    u := 'm';
    t := regexp_replace(t, '\s*m$', '', 'i');
    if t ~ '^\d{1,5}([.,]\d{1,2})?$' then n := replace(t, ',', '.')::numeric;
    else return jsonb_build_object('num', null, 'unidad', u, 'ambiguo', true, 'motivo', 'No se entiende como metros'); end if;
  end if;
  return jsonb_build_object('num', n, 'unidad', u, 'ambiguo', false);
end $$;

-- 3 · Guardar (alta, cambio o anulación), dato a dato ------------------------------
-- p_datos: [{id, version_base?, sesion_id, atleta_id, fila_id, bloque, alcance, serie,
--            repeticion, parte, tramo, magnitud, valor_texto, metodo, carga_modo,
--            lado, estado, ejercicio_realizado, adicional, nota, anular?}]
-- · id lo genera la pantalla: si un alta llega dos veces, la segunda devuelve
--   lo guardado (no duplica).
-- · Para cambiar hace falta version_base: si otra pantalla lo ha cambiado,
--   conflicto y no se pisa (se devuelve lo que hay ahora).
-- · Si otra pantalla ya creó esa misma casilla, conflicto «otra_pantalla».
create or replace function public.academia_toma_guardar(p_datos jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare
  it jsonb; d public.academia_toma_datos%rowtype; x public.academia_toma_datos%rowtype; s public.sesiones%rowtype;
  v_id uuid; v_vb int; v_p jsonb; v_out jsonb := '[]'::jsonb; v_mag text; v_aid uuid; v_fila text;
begin
  if jsonb_typeof(p_datos) <> 'array' or jsonb_array_length(p_datos) = 0 then raise exception 'No hay datos que guardar.'; end if;
  if jsonb_array_length(p_datos) > 300 then raise exception 'Como mucho 300 datos de una vez.'; end if;
  for it in select * from jsonb_array_elements(p_datos) loop
    v_id := nullif(it->>'id','')::uuid;
    if v_id is null then raise exception 'Cada dato necesita su id (lo pone la pantalla, para poder reintentar sin duplicar).'; end if;
    d := null;
    select * into d from public.academia_toma_datos where id = v_id for update;
    if d.id is not null then
      select * into s from public.sesiones where id = d.sesion_id;
      if not public.academia_puede(s.grupo_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
      v_vb := nullif(it->>'version_base','')::int;
      if v_vb is null then
        -- Reintento de un alta que ya había llegado: no se duplica.
        v_out := v_out || jsonb_build_array(jsonb_build_object('id', d.id, 'ok', true, 'repetido', true, 'dato', to_jsonb(d)));
        continue;
      end if;
      if d.anulado_en is not null then
        v_out := v_out || jsonb_build_array(jsonb_build_object('id', d.id, 'ok', false, 'conflicto', 'anulado',
                   'mensaje', 'Ese dato ya se había borrado en otra pantalla.', 'dato', to_jsonb(d)));
        continue;
      end if;
      if v_vb <> d.version then
        v_out := v_out || jsonb_build_array(jsonb_build_object('id', d.id, 'ok', false, 'conflicto', 'version',
                   'mensaje', 'Otra pantalla lo ha cambiado: no se ha pisado.', 'dato', to_jsonb(d)));
        continue;
      end if;
      if coalesce((it->>'anular')::boolean, false) then
        update public.academia_toma_datos set anulado_en = now(), anulado_por = public.mi_perfil_id() where id = d.id returning * into d;
      else
        v_p := public.academia_leer_valor(it->>'valor_texto', d.magnitud);
        update public.academia_toma_datos set
          valor_texto = nullif(btrim(coalesce(it->>'valor_texto','')), ''),
          valor_num = (v_p->>'num')::numeric, unidad = v_p->>'unidad', ambiguo = coalesce((v_p->>'ambiguo')::boolean, false),
          metodo = case when d.magnitud = 'tiempo' then coalesce(nullif(it->>'metodo',''), d.metodo, 'no_consta') else null end,
          carga_modo = case when d.magnitud = 'carga' then nullif(it->>'carga_modo','') else null end,
          estado = nullif(it->>'estado',''),
          ejercicio_realizado = nullif(btrim(coalesce(it->>'ejercicio_realizado','')), ''),
          parte = nullif(btrim(coalesce(it->>'parte','')), ''),
          nota = nullif(btrim(coalesce(it->>'nota','')), '')
        where id = d.id returning * into d;
      end if;
      v_out := v_out || jsonb_build_array(jsonb_build_object('id', d.id, 'ok', true, 'dato', to_jsonb(d)));
      continue;
    end if;

    -- Alta
    select * into s from public.sesiones where id = nullif(it->>'sesion_id','')::uuid;
    if s.id is null then raise exception 'Esa sesión no existe.'; end if;
    if not public.academia_puede(s.grupo_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
    v_aid := nullif(it->>'atleta_id','')::uuid;
    if v_aid is null or not (v_aid = any (coalesce(s.atletas_ids, array(select a.id from public.atletas a where a.grupo_id = s.grupo_id)))) then
      raise exception 'Ese atleta no está en esa sesión.';
    end if;
    v_mag := it->>'magnitud';
    v_fila := nullif(it->>'fila_id','');
    if v_fila is not null and not exists (
         select 1 from jsonb_array_elements(coalesce(s.bloques,'[]'::jsonb)) b, jsonb_array_elements(coalesce(b->'filas','[]'::jsonb)) f where f->>'id' = v_fila)
       and not exists (
         select 1 from public.sesiones_versiones v, jsonb_array_elements(coalesce(v.datos->'bloques','[]'::jsonb)) b, jsonb_array_elements(coalesce(b->'filas','[]'::jsonb)) f
          where v.sesion_id = s.id and f->>'id' = v_fila) then
      raise exception 'Esa fila no está en el plan de esta sesión.';
    end if;
    if not coalesce((it->>'adicional')::boolean, false) then
      select * into x from public.academia_toma_datos t
       where t.sesion_id = s.id and t.atleta_id = v_aid and coalesce(t.fila_id,'') = coalesce(v_fila,'') and t.alcance = it->>'alcance'
         and coalesce(t.serie,0) = coalesce(nullif(it->>'serie','')::int,0) and coalesce(t.repeticion,0) = coalesce(nullif(it->>'repeticion','')::int,0)
         and t.tramo = coalesce(nullif(btrim(coalesce(it->>'tramo','')),''),'total') and t.magnitud = v_mag
         and coalesce(t.lado,'') = coalesce(nullif(it->>'lado',''),'') and t.anulado_en is null and not t.adicional;
      if x.id is not null then
        v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'ok', false, 'conflicto', 'otra_pantalla',
                   'mensaje', 'Otra pantalla ya apuntó este dato: no se ha pisado.', 'dato', to_jsonb(x)));
        x := null;
        continue;
      end if;
    end if;
    v_p := public.academia_leer_valor(it->>'valor_texto', v_mag);
    insert into public.academia_toma_datos (id, sesion_id, sesion_version, atleta_id, fila_id, bloque, alcance, serie, repeticion, parte, tramo,
      magnitud, valor_texto, valor_num, unidad, ambiguo, metodo, carga_modo, lado, estado, ejercicio_realizado, adicional, nota)
    values (v_id, s.id, s.version, v_aid, v_fila, nullif(it->>'bloque',''), it->>'alcance', nullif(it->>'serie','')::int, nullif(it->>'repeticion','')::int,
      nullif(btrim(coalesce(it->>'parte','')),''), coalesce(nullif(btrim(coalesce(it->>'tramo','')),''),'total'),
      v_mag, nullif(btrim(coalesce(it->>'valor_texto','')),''), (v_p->>'num')::numeric, v_p->>'unidad', coalesce((v_p->>'ambiguo')::boolean,false),
      case when v_mag = 'tiempo' then coalesce(nullif(it->>'metodo',''),'no_consta') end,
      case when v_mag = 'carga' then nullif(it->>'carga_modo','') end, nullif(it->>'lado',''), nullif(it->>'estado',''),
      nullif(btrim(coalesce(it->>'ejercicio_realizado','')),''), coalesce((it->>'adicional')::boolean,false), nullif(btrim(coalesce(it->>'nota','')),''))
    returning * into d;
    v_out := v_out || jsonb_build_array(jsonb_build_object('id', d.id, 'ok', true, 'dato', to_jsonb(d)));
  end loop;
  return jsonb_build_object('ok', true, 'resultados', v_out);
end $$;

-- 4 · Discrepancias atleta / entrenador: se decide la referencia sin borrar nada -----
create table public.academia_discrepancias (
  id                uuid primary key default gen_random_uuid(),
  dato_id           uuid not null references public.academia_toma_datos(id) on delete cascade,
  sesion_id         uuid not null,
  atleta_id         uuid not null,
  fila_id           text,
  serie             integer,
  valor_entrenador  text not null,     -- tal como estaban al decidir
  valor_atleta      text not null,
  referencia        text not null check (referencia in ('entrenador','atleta')),
  nota              text check (nota is null or length(nota) <= 300),
  resuelto_por      uuid,
  resuelto_en       timestamptz not null default now()
);
create index academia_discrepancias_dato on public.academia_discrepancias (dato_id, resuelto_en desc);

create or replace function public.academia_discrepancia_resolver(p_dato uuid, p_valor_atleta text, p_referencia text, p_nota text default null)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare d public.academia_toma_datos%rowtype; s public.sesiones%rowtype; v_id uuid;
begin
  select * into d from public.academia_toma_datos where id = p_dato;
  if d.id is null or d.anulado_en is not null then raise exception 'Ese dato ya no existe.'; end if;
  select * into s from public.sesiones where id = d.sesion_id;
  if not public.academia_puede(s.grupo_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if p_referencia not in ('entrenador','atleta') then raise exception 'La referencia es el valor del entrenador o el del atleta.'; end if;
  if nullif(btrim(coalesce(p_valor_atleta,'')),'') is null then raise exception 'Falta el valor del atleta.'; end if;
  insert into public.academia_discrepancias (dato_id, sesion_id, atleta_id, fila_id, serie, valor_entrenador, valor_atleta, referencia, nota, resuelto_por)
  values (d.id, d.sesion_id, d.atleta_id, d.fila_id, d.serie, d.valor_texto, btrim(p_valor_atleta), p_referencia, nullif(btrim(coalesce(p_nota,'')),''), public.mi_perfil_id())
  returning id into v_id;
  return v_id;
end $$;

-- 5 · Una sesión con datos del entrenador no se borra: se archiva ------------------
create or replace function public.sesiones_archivar_si_hay_registros()
 returns trigger language plpgsql security definer set search_path to 'public' as $function$
begin
  -- Borrado definitivo a propósito (desde la base, sabiendo lo que se hace).
  if coalesce(current_setting('apolana.borrado_definitivo', true), '') = '1' then
    return old;
  end if;
  -- (468) También los datos que apuntó el entrenador (los suyos y su registro).
  if exists (select 1 from public.registros_sesion r where r.sesion_id = old.id)
     or exists (select 1 from public.academia_toma_datos t where t.sesion_id = old.id)
     or exists (select 1 from public.academia_registros_entrenador e where e.sesion_id = old.id) then
    if old.archivada_en is null then
      update public.sesiones
         set archivada_en = now(), archivada_por = public.mi_perfil_id(), publicada = false,
             archivo_motivo = coalesce(nullif(current_setting('apolana.motivo', true), ''),
                                       'Se quiso borrar y tenía registros: se archiva para no perderlos')
       where id = old.id;
    end if;
    return null;   -- no se borra: queda archivada con lo registrado
  end if;
  return old;
end $function$;

-- 6 · Permisos: leer con academia_puede; escribir solo con las funciones -----------
alter table public.academia_toma_datos enable row level security;
alter table public.academia_toma_datos_historial enable row level security;
alter table public.academia_discrepancias enable row level security;
revoke all on public.academia_toma_datos, public.academia_toma_datos_historial, public.academia_discrepancias from public, anon, authenticated;
grant select on public.academia_toma_datos, public.academia_toma_datos_historial, public.academia_discrepancias to authenticated;
grant all on public.academia_toma_datos, public.academia_toma_datos_historial, public.academia_discrepancias to service_role;
grant usage, select on sequence public.academia_toma_datos_historial_id_seq to service_role;
create policy "academia ve los datos tomados" on public.academia_toma_datos for select to authenticated
  using (exists (select 1 from public.sesiones s where s.id = sesion_id and public.academia_puede(s.grupo_id)));
create policy "academia ve el historial de los datos" on public.academia_toma_datos_historial for select to authenticated
  using (exists (select 1 from public.academia_toma_datos t join public.sesiones s on s.id = t.sesion_id
                 where t.id = dato_id and public.academia_puede(s.grupo_id)));
create policy "academia ve las discrepancias" on public.academia_discrepancias for select to authenticated
  using (exists (select 1 from public.sesiones s where s.id = sesion_id and public.academia_puede(s.grupo_id)));

revoke all on function public.academia_toma_guardar(jsonb), public.academia_discrepancia_resolver(uuid, text, text, text),
  public.academia_toma_antes() from public, anon;
grant execute on function public.academia_toma_guardar(jsonb), public.academia_discrepancia_resolver(uuid, text, text, text) to authenticated, service_role;
grant execute on function public.academia_leer_valor(text, text) to authenticated, service_role;

commit;
