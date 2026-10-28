-- ===========================================================================
-- 467 · Academia · Semana / Planificar (primera entrega)
-- ---------------------------------------------------------------------------
-- Encima de 462-464, sin tocar lo que ya funciona:
--   1) sesiones_nota_privada: la nota privada de cada sesión, en una tabla
--      aparte que el atleta no puede leer. (La «nota» de la sesión,
--      nota_razonamiento, SÍ la ve el atleta en su app: son las
--      instrucciones para él.)
--   2) academia_publicar(items): publica EXACTAMENTE las versiones revisadas.
--      Si una sola ha cambiado desde que se revisó, no se publica ninguna.
--   3) academia_copiar(...): copia la planificación de unos días a otros,
--      para los atletas elegidos, como BORRADOR y con identificadores nuevos.
--      Nunca copia feedback, asistencia, ejecución ni revisiones. Primero se
--      simula (qué se crearía y qué se salta por solaparse) y luego se hace.
--      Repetir la misma copia no duplica nada: lo ya copiado se solapa.
--   4) academia_aplicar(...): lleva los campos elegidos de una sesión a las
--      del mismo día de otros atletas. Cada atleta conserva su sesión (y, si
--      se pide, sus ritmos y observaciones fila a fila). Borrador → versión
--      nueva; publicada → revisión pendiente; sin sesión → borrador nuevo.
--      También se simula antes y se aplica todo o nada.
--   5) La conexión de prueba (academia_api): «nota_entrenador» se guardaba en
--      nota_razonamiento, que ve el atleta. Ahora va a la nota privada, y las
--      instrucciones para el atleta tienen su propio campo
--      («instrucciones_atleta»). Sigue limitada al grupo de PRUEBA.
-- ===========================================================================
begin;

-- 1 · Nota privada de la sesión ------------------------------------------------
create table public.sesiones_nota_privada (
  sesion_id       uuid primary key references public.sesiones(id) on delete cascade,
  nota            text not null check (length(nota) between 1 and 2000),
  actualizado_por uuid,
  actualizado_en  timestamptz not null default now()
);
create or replace function public.sesiones_nota_privada_firma() returns trigger
language plpgsql set search_path to 'public' as $$
begin
  new.actualizado_en := now();
  new.actualizado_por := coalesce(public.mi_perfil_id(), new.actualizado_por);
  return new;
end $$;
create trigger trg_sesiones_nota_privada_firma before insert or update on public.sesiones_nota_privada
  for each row execute function public.sesiones_nota_privada_firma();
alter table public.sesiones_nota_privada enable row level security;
revoke all on public.sesiones_nota_privada from public, anon, authenticated;
grant select, insert, update, delete on public.sesiones_nota_privada to authenticated;
grant all on public.sesiones_nota_privada to service_role;
create policy "academia: nota privada de la sesión" on public.sesiones_nota_privada for all to authenticated
  using (exists (select 1 from public.sesiones s where s.id = sesion_id and public.academia_puede(s.grupo_id)))
  with check (exists (select 1 from public.sesiones s where s.id = sesion_id and public.academia_puede(s.grupo_id)));

-- Utilidades -------------------------------------------------------------------
-- Bloques sin los ids de fila: al insertarlos, la base les pone ids NUEVOS
-- (apo_bloques_con_id). Así una copia nunca comparte identidad con el original.
create or replace function public.academia_bloques_sin_ids(p jsonb) returns jsonb
language sql immutable set search_path to 'public' as $$
  select coalesce(jsonb_agg(case when jsonb_typeof(b->'filas') = 'array'
           then b || jsonb_build_object('filas', (select coalesce(jsonb_agg(case when jsonb_typeof(f) = 'object' then f - 'id' else f end), '[]'::jsonb)
                                                  from jsonb_array_elements(b->'filas') f))
           else b end), '[]'::jsonb)
    from jsonb_array_elements(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) b
$$;
-- Dos sesiones del mismo atleta el mismo día chocan salvo que una sea de
-- mañana y la otra de tarde. «Sin especificar» choca con todo: no se sabe.
create or replace function public.academia_momentos_chocan(a text, b text) returns boolean
language sql immutable as $$
  select not (coalesce(a,'unica') in ('manana','tarde') and coalesce(b,'unica') in ('manana','tarde') and a <> b)
$$;
create or replace function public.academia_dia_semana(d date) returns text
language sql immutable as $$
  select (array['lunes','martes','miércoles','jueves','viernes','sábado','domingo'])[extract(isodow from d)::int]
$$;

-- 2 · Publicar exactamente lo revisado -------------------------------------------
-- p_items: [{sesion_id, version}] con la versión que se ha revisado.
create or replace function public.academia_publicar(p_items jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare it jsonb; s public.sesiones%rowtype; v_conf jsonb := '[]'::jsonb; v_ok jsonb := '[]'::jsonb; v_n int; v_vr int;
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'No hay nada que publicar.'; end if;
  if jsonb_array_length(p_items) > 200 then raise exception 'Como mucho 200 sesiones de una vez.'; end if;
  for it in select * from jsonb_array_elements(p_items) loop
    select * into s from public.sesiones where id = nullif(it->>'sesion_id','')::uuid for update;
    v_vr := nullif(it->>'version','')::int;
    if s.id is null then
      v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', it->>'sesion_id', 'motivo', 'Ya no existe.'));
      continue;
    end if;
    if not public.academia_puede(s.grupo_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
    if s.archivada_en is not null then
      v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'motivo', 'Está archivada.'));
    elsif s.publicada then
      v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'motivo', 'Ya estaba publicada (versión ' || s.version || ').'));
    elsif v_vr is null or s.version <> v_vr then
      v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'version_actual', s.version, 'version_revisada', v_vr,
                  'motivo', 'Cambió después de revisarla: ahora es la versión ' || s.version || coalesce(' y revisaste la ' || v_vr, '') || '.'));
    end if;
  end loop;
  if jsonb_array_length(v_conf) > 0 then
    return jsonb_build_object('ok', false, 'conflictos', v_conf,
      'mensaje', 'No se ha publicado nada: alguna sesión no es la versión que revisaste. Vuelve a revisarlas.');
  end if;
  for it in select * from jsonb_array_elements(p_items) loop
    v_vr := (it->>'version')::int;
    update public.sesiones set publicada = true
     where id = (it->>'sesion_id')::uuid and version = v_vr and not publicada
    returning * into s;
    get diagnostics v_n = row_count;
    if v_n <> 1 then raise exception 'Cambio simultáneo al publicar: no se ha publicado nada. Vuelve a intentarlo.'; end if;
    v_ok := v_ok || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'version_revisada', v_vr, 'version_publicada', s.version,
      'coincide', public.academia_huella(to_jsonb(s)) =
                  (select public.academia_huella(v.datos) from public.sesiones_versiones v where v.sesion_id = s.id and v.version = v_vr)));
  end loop;
  if exists (select 1 from jsonb_array_elements(v_ok) x where not coalesce((x->>'coincide')::boolean, false)) then
    raise exception 'La versión publicada no coincide con la revisada: no se ha publicado nada.';
  end if;
  return jsonb_build_object('ok', true, 'publicadas', v_ok);
end $$;

-- 3 · Copiar planificación --------------------------------------------------------
-- Copia las sesiones de p_desde..p_hasta (solo los días ISO p_dias, si se dan)
-- a partir de p_destino (se respeta la distancia entre días), para p_atletas.
create or replace function public.academia_copiar(p_grupo uuid, p_desde date, p_hasta date, p_destino date,
                                                  p_atletas uuid[], p_dias int[] default null, p_simular boolean default true)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_off   int;
  s       public.sesiones%rowtype;
  x       public.sesiones%rowtype;
  v_at    uuid;
  v_ok    uuid[];
  v_dest  date;
  v_crear jsonb := '[]'::jsonb;
  v_saltar jsonb := '[]'::jsonb;
  v_hechas jsonb := '[]'::jsonb;
  it      jsonb;
  v_id    uuid;
begin
  if not public.academia_puede(p_grupo) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if p_desde is null or p_hasta is null or p_destino is null or p_hasta < p_desde then raise exception 'Fechas no válidas.'; end if;
  if p_hasta - p_desde > 13 then raise exception 'Como mucho dos semanas de una vez.'; end if;
  if p_atletas is null or cardinality(p_atletas) = 0 then raise exception 'Elige al menos un atleta.'; end if;
  v_off := p_destino - p_desde;
  if v_off = 0 then raise exception 'El destino es el mismo que el origen.'; end if;

  -- 1) Qué se copiaría, contra lo que YA hay en el destino.
  for s in
    select * from public.sesiones o
     where o.grupo_id = p_grupo and o.fecha between p_desde and p_hasta and o.archivada_en is null
       and o.clase_dia in ('entreno','descanso')
       and (p_dias is null or extract(isodow from o.fecha)::int = any (p_dias))
       -- una sesión ya sustituida por otra no se copia (se copia la que la sustituye)
       and not exists (select 1 from public.sesiones r where r.sustituye_a = o.id and r.archivada_en is null)
     order by o.fecha, o.momento
  loop
    v_dest := s.fecha + v_off;
    v_ok := '{}';
    foreach v_at in array (case when s.atletas_ids is null or cardinality(s.atletas_ids) = 0
                                then p_atletas
                                else array(select u from unnest(s.atletas_ids) u where u = any (p_atletas)) end) loop
      select * into x from public.sesiones e
       where e.grupo_id = p_grupo and e.fecha = v_dest and e.archivada_en is null
         and (e.atletas_ids is null or v_at = any (e.atletas_ids))
         and public.academia_momentos_chocan(e.momento, s.momento)
       order by e.created_at limit 1;
      if x.id is not null then
        v_saltar := v_saltar || jsonb_build_array(jsonb_build_object('origen', s.id, 'atleta_id', v_at, 'fecha', v_dest,
                      'titulo', coalesce(s.titulo, case when s.clase_dia = 'descanso' then 'Descanso' end),
                      'motivo', 'Ya tiene «' || coalesce(x.titulo, case when x.clase_dia = 'descanso' then 'Descanso' else 'una sesión' end) || '» ese día'
                                || case when x.momento in ('manana','tarde') then ' (' || case x.momento when 'manana' then 'mañana' else 'tarde' end || ')' else '' end
                                || case when x.publicada then ', publicada' else ', en borrador' end || '.',
                      'existente', x.id));
      else
        v_ok := v_ok || v_at;
      end if;
    end loop;
    if cardinality(v_ok) > 0 then
      v_crear := v_crear || jsonb_build_array(jsonb_build_object('origen', s.id, 'fecha', v_dest, 'atletas', to_jsonb(v_ok),
                   'titulo', coalesce(s.titulo, case when s.clase_dia = 'descanso' then 'Descanso' end), 'momento', s.momento,
                   'clase_dia', s.clase_dia, 'publicada_origen', s.publicada));
    end if;
  end loop;

  if p_simular then
    return jsonb_build_object('ok', true, 'simulado', true, 'desplazamiento_dias', v_off, 'crear', v_crear, 'saltar', v_saltar);
  end if;

  -- 2) Hacerlo: solo planificación, en borrador y con identificadores nuevos.
  for it in select * from jsonb_array_elements(v_crear) loop
    select * into s from public.sesiones where id = (it->>'origen')::uuid;
    insert into public.sesiones (grupo_id, fecha, dia_semana, atletas_ids, titulo, tipo, rol, deporte, deporte_2, papel_dia,
                                 nota_razonamiento, bloques, publicada, creado_por, hora, lugar, duracion_min, clase_dia, momento,
                                 objetivo, exigencia, exigencia_neuro, exigencia_meta, generado_por_ia)
    values (s.grupo_id, (it->>'fecha')::date, public.academia_dia_semana((it->>'fecha')::date),
            -- para los atletas elegidos (una sesión «de todo el grupo» pasa a ir a ellos)
            array(select (j #>> '{}')::uuid from jsonb_array_elements(it->'atletas') j),
            s.titulo, s.tipo, s.rol, s.deporte, s.deporte_2, s.papel_dia,
            s.nota_razonamiento, public.academia_bloques_sin_ids(s.bloques), false, public.mi_perfil_id(), s.hora, s.lugar, s.duracion_min,
            s.clase_dia, s.momento, s.objetivo, s.exigencia, s.exigencia_neuro, s.exigencia_meta, false)
    returning id into v_id;
    insert into public.sesiones_nota_privada (sesion_id, nota, actualizado_por)
      select v_id, n.nota, public.mi_perfil_id() from public.sesiones_nota_privada n where n.sesion_id = s.id;
    v_hechas := v_hechas || jsonb_build_array(it || jsonb_build_object('sesion_id', v_id));
  end loop;
  return jsonb_build_object('ok', true, 'simulado', false, 'desplazamiento_dias', v_off, 'creadas', v_hechas, 'saltar', v_saltar);
end $$;

-- 4 · Aplicar campos de una sesión a las de otros atletas -----------------------------
-- p_campos: titulo · objetivo · exigencia (las tres) · momento · instrucciones
--           (nota_razonamiento) · nota_privada.
-- p_bloques: etiquetas de los bloques de la sesión de origen que se llevan.
-- p_esperado: {atleta_id: {sesion_id, version}} de la simulación. Si algo ha
--             cambiado desde entonces, no se aplica nada.
create or replace function public.academia_aplicar(p_origen uuid, p_atletas uuid[], p_campos text[], p_bloques text[],
                                                   p_conservar boolean default true, p_simular boolean default true,
                                                   p_esperado jsonb default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  s0   public.sesiones%rowtype;
  t    public.sesiones%rowtype;
  v_at uuid;
  v_n  int;
  v_res jsonb := '[]'::jsonb;
  v_c   jsonb;          -- cambios de columnas de sesiones
  v_bl  jsonb;
  v_b0  jsonb;
  v_bt  jsonb;
  v_i   int;
  v_j   int;
  v_f   jsonb;
  v_ft  jsonb;
  v_filas jsonb;
  v_nota0 text;
  v_notat text;
  v_np  boolean;        -- ¿cambia la nota privada?
  v_acc text;
  v_mot text;
  it    jsonb;
  v_id  uuid;
  v_conf jsonb := '[]'::jsonb;
  v_campos_ok text[] := array['titulo','objetivo','exigencia','momento','instrucciones','nota_privada'];
begin
  select * into s0 from public.sesiones where id = p_origen;
  if s0.id is null then raise exception 'La sesión de origen no existe.'; end if;
  if not public.academia_puede(s0.grupo_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if p_atletas is null or cardinality(p_atletas) = 0 then raise exception 'Elige al menos un atleta.'; end if;
  if coalesce(cardinality(p_campos),0) = 0 and coalesce(cardinality(p_bloques),0) = 0 then raise exception 'Elige qué se aplica.'; end if;
  if exists (select 1 from unnest(coalesce(p_campos,'{}')) c where c <> all (v_campos_ok)) then raise exception 'Campo no reconocido.'; end if;
  select n.nota into v_nota0 from public.sesiones_nota_privada n where n.sesion_id = s0.id;

  foreach v_at in array p_atletas loop
    v_acc := null; v_mot := null; v_c := '{}'::jsonb; v_np := false;
    if v_at = any (coalesce(s0.atletas_ids,'{}')) then
      v_res := v_res || jsonb_build_array(jsonb_build_object('atleta_id', v_at, 'accion', 'saltar', 'motivo', 'Es la sesión de origen.'));
      continue;
    end if;
    if not exists (select 1 from public.atletas a where a.id = v_at and a.grupo_id = s0.grupo_id) then
      v_res := v_res || jsonb_build_array(jsonb_build_object('atleta_id', v_at, 'accion', 'saltar', 'motivo', 'No es de este grupo.'));
      continue;
    end if;
    -- Su sesión de ese día: la de la misma franja; si no, la única que choque.
    t := null;
    select * into t from public.sesiones e
     where e.grupo_id = s0.grupo_id and e.fecha = s0.fecha and e.archivada_en is null and e.atletas_ids = array[v_at]
       and e.momento = s0.momento order by e.created_at limit 1;
    if t.id is null then
      select count(*) into v_n from public.sesiones e
       where e.grupo_id = s0.grupo_id and e.fecha = s0.fecha and e.archivada_en is null and v_at = any (e.atletas_ids)
         and public.academia_momentos_chocan(e.momento, s0.momento);
      if v_n > 1 then
        v_res := v_res || jsonb_build_array(jsonb_build_object('atleta_id', v_at, 'accion', 'saltar',
                    'motivo', 'Tiene varias sesiones ese día y ninguna es de la misma franja: hazlo a mano.'));
        continue;
      elsif v_n = 1 then
        select * into t from public.sesiones e
         where e.grupo_id = s0.grupo_id and e.fecha = s0.fecha and e.archivada_en is null and v_at = any (e.atletas_ids)
           and public.academia_momentos_chocan(e.momento, s0.momento) limit 1;
        if cardinality(t.atletas_ids) <> 1 then
          v_res := v_res || jsonb_build_array(jsonb_build_object('atleta_id', v_at, 'accion', 'saltar', 'sesion_id', t.id,
                      'motivo', 'Su sesión de ese día es compartida con otros atletas: cámbiala a mano.'));
          continue;
        end if;
      end if;
    end if;

    -- Columnas que se llevan
    if 'titulo' = any (p_campos) and t.titulo is distinct from s0.titulo then v_c := v_c || jsonb_build_object('titulo', s0.titulo); end if;
    if 'objetivo' = any (p_campos) and t.objetivo is distinct from s0.objetivo then v_c := v_c || jsonb_build_object('objetivo', s0.objetivo); end if;
    if 'exigencia' = any (p_campos) and (t.exigencia, t.exigencia_neuro, t.exigencia_meta) is distinct from (s0.exigencia, s0.exigencia_neuro, s0.exigencia_meta) then
      v_c := v_c || jsonb_build_object('exigencia', s0.exigencia, 'exigencia_neuro', s0.exigencia_neuro, 'exigencia_meta', s0.exigencia_meta);
    end if;
    if 'momento' = any (p_campos) and t.id is not null and t.momento is distinct from s0.momento then
      v_c := v_c || jsonb_build_object('momento', s0.momento, 'hora', s0.hora);
    end if;
    if 'instrucciones' = any (p_campos) and t.nota_razonamiento is distinct from s0.nota_razonamiento then
      v_c := v_c || jsonb_build_object('nota_razonamiento', s0.nota_razonamiento);
    end if;
    -- Bloques: se sustituye el bloque con la misma etiqueta (o se añade);
    -- los demás bloques de su sesión no se tocan.
    if coalesce(cardinality(p_bloques),0) > 0 then
      v_bl := coalesce(case when jsonb_typeof(t.bloques) = 'array' then t.bloques end, '[]'::jsonb);
      for v_b0 in select b from jsonb_array_elements(coalesce(s0.bloques,'[]'::jsonb)) b where (b->>'etiqueta') = any (p_bloques) loop
        v_j := null;
        for v_i in 0 .. jsonb_array_length(v_bl) - 1 loop
          if v_j is null and coalesce(v_bl->v_i->>'etiqueta','') = coalesce(v_b0->>'etiqueta','') then v_j := v_i; end if;
        end loop;
        v_bt := case when v_j is null then null else v_bl->v_j end;
        v_filas := '[]'::jsonb;
        for v_i in 0 .. coalesce(jsonb_array_length(v_b0->'filas'),0) - 1 loop
          v_f := v_b0->'filas'->v_i;
          if jsonb_typeof(v_f) = 'object' then
            v_f := v_f - 'id';
            v_ft := case when v_bt is not null then v_bt->'filas'->v_i end;
            if v_ft is not null and jsonb_typeof(v_ft) = 'object' then
              -- su fila en esa posición conserva su identidad (lo que apuntó sigue pegado)
              if v_ft ? 'id' then v_f := v_f || jsonb_build_object('id', v_ft->'id'); end if;
              if p_conservar then
                if coalesce(v_ft->>'ritmo','') <> '' then v_f := v_f || jsonb_build_object('ritmo', v_ft->'ritmo'); end if;
                if coalesce(v_ft->>'observaciones','') <> '' then v_f := v_f || jsonb_build_object('observaciones', v_ft->'observaciones'); end if;
              end if;
            end if;
          end if;
          v_filas := v_filas || jsonb_build_array(v_f);
        end loop;
        v_b0 := v_b0 || jsonb_build_object('filas', v_filas);
        if v_j is null then v_bl := v_bl || jsonb_build_array(v_b0);
        else v_bl := jsonb_set(v_bl, array[v_j::text], v_b0);
        end if;
      end loop;
      if t.id is null or public.academia_huella(jsonb_build_object('bloques', v_bl)) <> public.academia_huella(jsonb_build_object('bloques', t.bloques)) then
        v_c := v_c || jsonb_build_object('bloques', v_bl);
      end if;
    end if;
    if 'nota_privada' = any (p_campos) then
      select n.nota into v_notat from public.sesiones_nota_privada n where n.sesion_id = t.id;
      v_np := v_notat is distinct from v_nota0;
    end if;

    if t.id is null then
      if not (v_c ? 'bloques' or v_c ? 'titulo') then
        v_acc := 'saltar'; v_mot := 'No tiene sesión ese día: para crearle una, lleva al menos el título o algún bloque.';
      else v_acc := 'crear'; end if;
    elsif v_c = '{}'::jsonb and not v_np then v_acc := 'sin_cambios';
    elsif t.publicada and exists (select 1 from public.sesiones_revisiones r where r.sesion_id = t.id and r.estado = 'pendiente') then
      v_acc := 'saltar'; v_mot := 'Ya tiene una revisión pendiente: aplícala o descártala antes.';
    elsif t.publicada and v_c = '{}'::jsonb then v_acc := 'nota_privada';
    elsif t.publicada then v_acc := 'revision';
    else v_acc := 'actualizar'; end if;

    v_res := v_res || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('atleta_id', v_at, 'accion', v_acc, 'motivo', v_mot,
               'sesion_id', t.id, 'version', t.version, 'publicada', t.publicada, 'cambios', v_c, 'nota_privada', v_np)));
  end loop;

  if p_simular then
    return jsonb_build_object('ok', true, 'simulado', true, 'origen', s0.id, 'version_origen', s0.version, 'atletas', v_res);
  end if;

  -- ¿Ha cambiado algo desde la simulación? Entonces no se aplica nada.
  if p_esperado is not null then
    for it in select * from jsonb_array_elements(v_res) loop
      if (p_esperado->(it->>'atleta_id')) is null then continue; end if;
      if coalesce(p_esperado->(it->>'atleta_id')->>'sesion_id','') is distinct from coalesce(it->>'sesion_id','')
         or coalesce(p_esperado->(it->>'atleta_id')->>'version','') is distinct from coalesce(it->>'version','')
         or coalesce(p_esperado->(it->>'atleta_id')->>'accion','') is distinct from coalesce(it->>'accion','') then
        v_conf := v_conf || jsonb_build_array(jsonb_build_object('atleta_id', it->>'atleta_id'));
      end if;
    end loop;
    if jsonb_array_length(v_conf) > 0 then
      return jsonb_build_object('ok', false, 'conflictos', v_conf,
        'mensaje', 'Alguna sesión ha cambiado desde que lo revisaste: no se ha aplicado nada. Vuelve a mirarlo.');
    end if;
  end if;

  for it in select * from jsonb_array_elements(v_res) loop
    v_c := coalesce(it->'cambios', '{}'::jsonb);
    if it->>'accion' = 'crear' then
      insert into public.sesiones (grupo_id, fecha, dia_semana, atletas_ids, titulo, tipo, rol, deporte, deporte_2, papel_dia,
                                   nota_razonamiento, bloques, publicada, creado_por, hora, lugar, duracion_min, clase_dia, momento,
                                   objetivo, exigencia, exigencia_neuro, exigencia_meta, generado_por_ia)
      values (s0.grupo_id, s0.fecha, public.academia_dia_semana(s0.fecha), array[(it->>'atleta_id')::uuid],
              coalesce(v_c->>'titulo', s0.titulo), s0.tipo, s0.rol, s0.deporte, s0.deporte_2, s0.papel_dia,
              case when v_c ? 'nota_razonamiento' then v_c->>'nota_razonamiento' end,
              public.academia_bloques_sin_ids(coalesce(v_c->'bloques', '[]'::jsonb)), false, public.mi_perfil_id(),
              s0.hora, s0.lugar, null, s0.clase_dia, s0.momento,
              case when v_c ? 'objetivo' then v_c->>'objetivo' end,
              case when v_c ? 'exigencia' then v_c->>'exigencia' end,
              case when v_c ? 'exigencia' then v_c->>'exigencia_neuro' end,
              case when v_c ? 'exigencia' then v_c->>'exigencia_meta' end, false)
      returning id into v_id;
    elsif it->>'accion' = 'actualizar' then
      v_id := (it->>'sesion_id')::uuid;
      update public.sesiones set
        titulo            = case when v_c ? 'titulo' then v_c->>'titulo' else titulo end,
        objetivo          = case when v_c ? 'objetivo' then v_c->>'objetivo' else objetivo end,
        exigencia         = case when v_c ? 'exigencia' then v_c->>'exigencia' else exigencia end,
        exigencia_neuro   = case when v_c ? 'exigencia' then v_c->>'exigencia_neuro' else exigencia_neuro end,
        exigencia_meta    = case when v_c ? 'exigencia' then v_c->>'exigencia_meta' else exigencia_meta end,
        momento           = case when v_c ? 'momento' then v_c->>'momento' else momento end,
        hora              = case when v_c ? 'momento' then (v_c->>'hora')::time else hora end,
        nota_razonamiento = case when v_c ? 'nota_razonamiento' then v_c->>'nota_razonamiento' else nota_razonamiento end,
        bloques           = case when v_c ? 'bloques' then v_c->'bloques' else bloques end
      where id = v_id and version = (it->>'version')::int and not publicada;
      get diagnostics v_n = row_count;
      if v_n <> 1 and v_c <> '{}'::jsonb then raise exception 'Cambio simultáneo: no se ha aplicado nada. Vuelve a intentarlo.'; end if;
    elsif it->>'accion' = 'revision' then
      v_id := (it->>'sesion_id')::uuid;
      if (select version from public.sesiones where id = v_id) <> (it->>'version')::int then
        raise exception 'Cambio simultáneo: no se ha aplicado nada. Vuelve a intentarlo.';
      end if;
      insert into public.sesiones_revisiones (sesion_id, version_base, propuesta, motivo, autor_perfil_id, via)
      values (v_id, (it->>'version')::int, v_c, 'Aplicado desde la sesión de otro atleta', public.mi_perfil_id(), public._historial_via());
    elsif it->>'accion' = 'nota_privada' then
      v_id := (it->>'sesion_id')::uuid;
    else
      continue;
    end if;
    if coalesce((it->>'nota_privada')::boolean, false) then
      if v_nota0 is null then delete from public.sesiones_nota_privada where sesion_id = v_id;
      else
        insert into public.sesiones_nota_privada (sesion_id, nota, actualizado_por) values (v_id, v_nota0, public.mi_perfil_id())
        on conflict (sesion_id) do update set nota = excluded.nota;
      end if;
    end if;
  end loop;
  return jsonb_build_object('ok', true, 'simulado', false, 'atletas', v_res);
end $$;

revoke all on function public.academia_publicar(jsonb),
  public.academia_copiar(uuid, date, date, date, uuid[], int[], boolean),
  public.academia_aplicar(uuid, uuid[], text[], text[], boolean, boolean, jsonb) from public, anon;
grant execute on function public.academia_publicar(jsonb),
  public.academia_copiar(uuid, date, date, date, uuid[], int[], boolean),
  public.academia_aplicar(uuid, uuid[], text[], text[], boolean, boolean, jsonb) to authenticated, service_role;

-- 5 · Conexión de prueba: la nota privada, privada de verdad ---------------------------
-- (cuerpos de 464 con los cambios marcados «(467)»)
-- Guarda (o quita, con '') la nota privada de una sesión desde la conexión.
create or replace function public.academia_api_nota(p_sesion uuid, p_nota text, p_autor uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
begin
  if nullif(trim(coalesce(p_nota,'')), '') is null then
    delete from public.sesiones_nota_privada where sesion_id = p_sesion;
  else
    insert into public.sesiones_nota_privada (sesion_id, nota, actualizado_por) values (p_sesion, trim(p_nota), p_autor)
    on conflict (sesion_id) do update set nota = excluded.nota, actualizado_por = excluded.actualizado_por;
  end if;
end $$;

create or replace function public.academia_api_sesion_json(s public.sesiones) returns jsonb
language sql stable security definer set search_path to 'public' as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'sesion_id', s.id, 'version', s.version, 'huella', public.academia_huella(to_jsonb(s)),
    'fecha', s.fecha, 'momento', s.momento, 'hora', to_char(s.hora, 'HH24:MI'), 'duracion_min', s.duracion_min,
    'atleta_ids', to_jsonb(s.atletas_ids), 'tipo_dia', s.clase_dia,
    'estado_publicacion', case when s.publicada then 'publicada' else 'borrador' end,
    'titulo', s.titulo, 'objetivo', s.objetivo,
    -- (467) lo que lee el atleta y lo que es solo del entrenador, separados
    'instrucciones_atleta', s.nota_razonamiento,
    'nota_entrenador', (select n.nota from public.sesiones_nota_privada n where n.sesion_id = s.id),
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
  -- (467) Las instrucciones las ve el atleta en su app (nota_razonamiento).
  if p ? 'instrucciones_atleta' then o := o || jsonb_build_object('nota_razonamiento', nullif(trim(coalesce(p->>'instrucciones_atleta','')), '')); end if;
  -- (467) La nota del entrenador es PRIVADA: va a sesiones_nota_privada. Antes iba a
  -- nota_razonamiento, que sí ve el atleta. '' = quitarla.
  if p ? 'nota_entrenador' then
    v := nullif(trim(coalesce(p->>'nota_entrenador','')), '');
    if length(v) > 2000 then raise exception 'nota_entrenador: máximo 2000 caracteres'; end if;
    o := o || jsonb_build_object('nota_privada', coalesce(v, ''));
  end if;
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
  v_np     text;   -- (467) nota privada
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
          'No inventar la clasificación de una sesión ni calcular volúmenes: eso aún no está definido.',
          'instrucciones_atleta lo lee el atleta en su app; nota_entrenador es privada (solo entrenadores).'));

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
            v_items := v_items || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('accion', 'sin_cambios', 'sesion_id', s.id, 'clave_cliente', v_cc,
                          'version', s.version, 'huella', public.academia_huella(to_jsonb(s)),
                          'estado_publicacion', case when s.publicada then 'publicada' else 'borrador' end,
                          'nota_privada', v_campos->'nota_privada')));
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
            if v_nuevo ? 'nota_privada' then perform public.academia_api_nota(s.id, v_nuevo->>'nota_privada', k.creada_por); end if;
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
            if v_campos ? 'nota_privada' then perform public.academia_api_nota(s.id, v_campos->>'nota_privada', k.creada_por); end if;
            v_conf := v_conf || jsonb_build_array(jsonb_build_object('accion', 'actualizada', 'clave_cliente', it->>'clave_cliente',
                         'sesion_id', s.id, 'version', s.version, 'huella', public.academia_huella(to_jsonb(s)), 'estado_publicacion', 'borrador'));
          else
            if it ? 'nota_privada' then
              perform public.academia_api_nota((it->>'sesion_id')::uuid, it->>'nota_privada', k.creada_por);
              it := (it - 'nota_privada') || jsonb_build_object('nota_privada', 'guardada (no cambia la versión: el atleta no la ve)');
            end if;
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
      v_np := v_campos->>'nota_privada'; v_campos := v_campos - 'nota_privada';
      if s.archivada_en is not null then
        v_res := jsonb_build_object('ok', false, 'error', 'archivada', 'mensaje', 'La sesión está archivada.');
      elsif not s.publicada then
        v_res := jsonb_build_object('ok', false, 'error', 'es_borrador', 'mensaje', 'Es un borrador: cámbiala con guardar_borradores (sesion_id + version_base).');
      elsif v_vb is null or v_vb <> s.version then
        v_res := jsonb_build_object('ok', false, 'error', 'conflicto_version',
          'mensaje', 'Cambio concurrente: la sesión va por la versión ' || s.version || coalesce(' y la propuesta parte de la ' || v_vb, '') || '. Vuelve a leerla.',
          'version_actual', s.version, 'huella_actual', public.academia_huella(to_jsonb(s)));
      elsif v_np is not null and (v_campos = '{}'::jsonb or public.academia_huella(to_jsonb(s) || v_campos) = public.academia_huella(to_jsonb(s))) then
        perform public.academia_api_nota(s.id, v_np, k.creada_por);
        v_res := jsonb_build_object('ok', true, 'sesion_id', s.id, 'version', s.version,
          'nota', 'Solo cambiaba la nota privada del entrenador: guardada sin revisión (el atleta no la ve).');
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
        if v_np is not null then perform public.academia_api_nota(s.id, v_np, k.creada_por); end if;
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

revoke all on function public.academia_api_nota(uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.academia_api(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.academia_api(text, text, jsonb) to service_role;
revoke all on function public.academia_api_sesion_json(public.sesiones) from public, anon, authenticated;
revoke all on function public.academia_api_campos(jsonb) from public, anon, authenticated;

commit;
