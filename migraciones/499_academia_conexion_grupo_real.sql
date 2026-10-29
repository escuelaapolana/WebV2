-- 499 · Academia · Conexión de ChatGPT abierta a Academia AC98 REAL, con permisos acotados.
-- Encargo de Andrés (29-oct-2026): que ChatGPT pueda subir la planificación al grupo real.
--   · academia_api_habilitados: qué clave puede qué en un grupo REAL, uno a uno y por
--     escrito. Solo se habilita la clave activa («ChatGPT · Mac de Andrés») en
--     Academia AC98 con leer · borradores · revisiones · publicar. Ningún otro grupo.
--   · academia_api_grupos: grupos de prueba de la clave (como antes) + los habilitados.
--   · academia_api_puede(clave, grupo, permiso): el permiso se comprueba POR GRUPO en
--     cada escritura. publicar_prueba sigue valiendo SOLO en grupos de prueba.
--   · Publicar en el grupo real en dos pasos: preparar_publicacion (no publica: código
--     de 30 min atado a versión y huella) y publicar (código + palabras literales de
--     Andrés que lo incluyen; se publica exactamente lo autorizado y queda registrado).
--   · Sigue sin existir ninguna operación de borrar sesiones ni de tocar feedback.

create table public.academia_api_habilitados (
  clave_id      uuid not null references public.api_claves(id) on delete cascade,
  grupo_id      uuid not null references public.grupos(id) on delete cascade,
  permisos      text[] not null check (permisos <@ array['leer','borradores','revisiones','publicar'] and 'leer' = any (permisos)),
  habilitado_por uuid,
  habilitado_en timestamptz not null default now(),
  motivo        text not null,
  primary key (clave_id, grupo_id)
);
comment on table public.academia_api_habilitados is 'Grupos REALES que una clave de la conexión de ChatGPT puede usar, con sus permisos. Solo se añaden con autorización expresa de Andrés.';
alter table public.academia_api_habilitados enable row level security;
revoke all on public.academia_api_habilitados from public, anon, authenticated;

create table public.academia_api_autorizaciones (
  id            uuid primary key default gen_random_uuid(),
  clave_id      uuid not null references public.api_claves(id) on delete cascade,
  codigo        text not null check (codigo ~ '^[0-9A-F]{6}$'),
  sesiones      jsonb not null check (jsonb_typeof(sesiones) = 'array'),
  creada_en     timestamptz not null default now(),
  caduca_en     timestamptz not null,
  usada_en      timestamptz,
  autorizacion_texto text,
  resultado     jsonb,
  unique (clave_id, codigo)
);
comment on table public.academia_api_autorizaciones is 'Publicaciones preparadas por la conexión (versión y huella exactas) y la autorización literal de Andrés con la que se publicaron.';
alter table public.academia_api_autorizaciones enable row level security;
revoke all on public.academia_api_autorizaciones from public, anon, authenticated;

create or replace function public.academia_api_grupos(p_clave public.api_claves)
 returns uuid[] language sql stable security definer set search_path to 'public'
as $$
  select coalesce(array_agg(distinct g), '{}') from (
    select ag.grupo_id as g from public.academia_grupos ag where ag.es_prueba and ag.grupo_id = any (p_clave.grupos)
    union
    select h.grupo_id from public.academia_api_habilitados h join public.academia_grupos ag on ag.grupo_id = h.grupo_id
     where h.clave_id = p_clave.id and 'leer' = any (h.permisos)
  ) x;
$$;

create or replace function public.academia_api_puede(p_clave public.api_claves, p_grupo uuid, p_permiso text)
 returns boolean language sql stable security definer set search_path to 'public'
as $$
  select case
    when exists (select 1 from public.academia_grupos ag where ag.grupo_id = p_grupo and ag.es_prueba) then
      p_grupo = any (p_clave.grupos) and p_permiso <> 'publicar' and p_permiso = any (p_clave.permisos)
    else exists (select 1 from public.academia_api_habilitados h join public.academia_grupos ag on ag.grupo_id = h.grupo_id
                  where h.clave_id = p_clave.id and h.grupo_id = p_grupo and p_permiso = any (h.permisos))
  end;
$$;
revoke execute on function public.academia_api_grupos(public.api_claves), public.academia_api_puede(public.api_claves, uuid, text) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.academia_api(p_hash text, p_operacion text, p_args jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_escribe boolean := p_operacion in ('guardar_borradores','proponer_revision','publicar_prueba','publicar');
  -- (499) grupos reales habilitados expresamente: permisos por grupo
  v_aut    public.academia_api_autorizaciones%rowtype;
  v_cod    text;
  v_ses    jsonb;
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
     or (p_operacion = 'publicar_prueba' and not ('publicar_prueba' = any (k.permisos)))
     or (p_operacion in ('preparar_publicacion','publicar') and not exists (
           select 1 from public.academia_api_habilitados h where h.clave_id = k.id and 'publicar' = any (h.permisos))) then
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
        'grupos', (select coalesce(jsonb_agg(jsonb_build_object('grupo_id', g.id, 'nombre', g.nombre,
                        'datos_ficticios', coalesce(ag.es_prueba, false),
                        'permisos', to_jsonb(array(select p from unnest(array['leer','borradores','revisiones','publicar_prueba','publicar']) p
                                                    where public.academia_api_puede(k, g.id, p))),
                        'habilitado', (select jsonb_build_object('desde', h.habilitado_en, 'motivo', h.motivo)
                                         from public.academia_api_habilitados h where h.clave_id = k.id and h.grupo_id = g.id))
                      order by coalesce(ag.es_prueba, false), g.nombre), '[]'::jsonb)
                     from public.grupos g left join public.academia_grupos ag on ag.grupo_id = g.id where g.id = any (v_grupos)),
        'reglas', jsonb_build_array(
          'Solo los grupos de esta lista. «datos_ficticios: false» = grupo REAL (Academia AC98): sus atletas ven lo que se publique. En las lecturas no hay datos de salud.',
          'Nunca se borra una sesión ni se toca el feedback de los atletas: esta conexión no puede.',
          'Guardar borradores solo cuando el usuario lo pida expresamente (esa petición es la autorización).',
          'Cada sesión nueva lleva una clave_cliente estable; cada petición de escritura, un envio_id nuevo.',
          'Para cambiar un borrador: sesion_id + version_base. Si la versión no coincide, hay un cambio concurrente: vuelve a leer.',
          'Una sesión publicada no se toca: se propone una revisión (queda pendiente para el entrenador).',
          'Grupo de PRUEBA: publicar_prueba solo si el usuario lo pide, con la version y la huella exactas que se revisaron.',
          'Grupo REAL: publicar en dos pasos. 1) preparar_publicacion con las versiones y huellas revisadas: devuelve un resumen y un código. 2) Enseña el resumen y pide a Andrés que autorice escribiendo ese código; solo entonces publicar con el código y sus palabras literales. Sin su autorización expresa, no se publica.',
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
          if v_grupo is null or not public.academia_api_puede(k, v_grupo, 'borradores') then raise exception 'grupo_no_permitido'; end if;
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
          if not public.academia_api_puede(k, s.grupo_id, 'borradores') then raise exception 'grupo_no_permitido'; end if;
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
      if not public.academia_api_puede(k, s.grupo_id, 'revisiones') then raise exception 'grupo_no_permitido'; end if;
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
        if not public.academia_api_puede(k, s.grupo_id, 'publicar_prueba') then
          v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'conflicto', 'grupo_real',
                       'mensaje', 'No es del grupo de PRUEBA: en el grupo real se publica con preparar_publicacion + publicar y la autorización expresa de Andrés.'));
          continue;
        end if;
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

    -- ---------------- (499) preparar_publicacion · grupo real ----------------
    -- No publica nada: comprueba versión y huella de cada sesión y deja un código de
    -- autorización (30 min) atado a esas versiones y huellas exactas.
    elsif p_operacion = 'preparar_publicacion' then
      if jsonb_typeof(a->'sesiones') <> 'array' or jsonb_array_length(a->'sesiones') = 0 then raise exception 'sesiones: lista vacía'; end if;
      if jsonb_array_length(a->'sesiones') > 60 then raise exception 'sesiones: máximo 60 por publicación'; end if;
      v_ses := '[]'::jsonb;
      for it in select * from jsonb_array_elements(a->'sesiones') loop
        select * into s from public.sesiones where id = nullif(it->>'sesion_id','')::uuid;
        if s.id is null or not (s.grupo_id = any (v_grupos)) then raise exception 'sesion_no_encontrada'; end if;
        if not public.academia_api_puede(k, s.grupo_id, 'publicar') then
          v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'conflicto', 'sin_permiso_publicar',
                       'mensaje', 'En este grupo la clave no puede publicar (en PRUEBA se usa publicar_prueba).'));
        elsif s.publicada then
          v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'conflicto', 'ya_publicada', 'version_actual', s.version));
        elsif s.archivada_en is not null then
          v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'conflicto', 'archivada'));
        elsif nullif(it->>'version','')::int is distinct from s.version or coalesce(it->>'huella','') <> public.academia_huella(to_jsonb(s)) then
          v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'conflicto', 'no_es_la_version_revisada',
                       'version_revisada', it->'version', 'huella_revisada', it->'huella',
                       'version_actual', s.version, 'huella_actual', public.academia_huella(to_jsonb(s))));
        elsif v_ses @> jsonb_build_array(jsonb_build_object('sesion_id', s.id::text)) then
          v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'conflicto', 'repetida'));
        else
          v_ses := v_ses || jsonb_build_array(jsonb_build_object('sesion_id', s.id::text, 'version', s.version, 'huella', public.academia_huella(to_jsonb(s)),
                      'fecha', s.fecha, 'momento', s.momento, 'titulo', s.titulo,
                      'atletas', (select coalesce(jsonb_agg(coalesce(nullif(at.nombre_corto,''), at.nombre) order by at.nombre), '[]'::jsonb)
                                    from public.atletas at where at.id = any (s.atletas_ids))));
        end if;
      end loop;
      if jsonb_array_length(v_conf) > 0 then
        v_res := jsonb_build_object('ok', false, 'error', 'conflictos', 'mensaje', 'No se ha preparado nada: alguna sesión no es la versión revisada o no se puede publicar.', 'conflictos', v_conf);
      else
        v_cod := upper(substr(md5(random()::text || clock_timestamp()::text || k.id::text), 1, 6));
        insert into public.academia_api_autorizaciones (clave_id, codigo, sesiones, caduca_en)
        values (k.id, v_cod, v_ses, now() + interval '30 minutes') returning * into v_aut;
        v_res := jsonb_build_object('ok', true, 'codigo', v_cod, 'caduca', to_char(v_aut.caduca_en at time zone 'Europe/Madrid', 'DD-MM-YYYY HH24:MI'),
          'sesiones', v_ses,
          'nota', 'NO se ha publicado nada. Enseña a Andrés este resumen (fecha, atleta, título, versión) y pídele que autorice escribiendo el código ' || v_cod ||
                  '. Solo con su autorización expresa, llama a publicar con ese código y sus palabras literales. Si cambias algo, hay que preparar otra vez.');
      end if;

    -- ---------------- (499) publicar · grupo real, con autorización expresa ----------------
    elsif p_operacion = 'publicar' then
      v_cod := upper(nullif(trim(coalesce(a->>'codigo','')), ''));
      if v_cod is null then raise exception 'falta el código de autorización (lo da preparar_publicacion)'; end if;
      if nullif(trim(coalesce(a->>'autorizacion_texto','')), '') is null then raise exception 'falta autorizacion_texto: las palabras literales de Andrés autorizando la publicación'; end if;
      if position(v_cod in upper(a->>'autorizacion_texto')) = 0 then
        raise exception 'la autorización de Andrés tiene que incluir el código %', v_cod;
      end if;
      select * into v_aut from public.academia_api_autorizaciones where clave_id = k.id and codigo = v_cod for update;
      if v_aut.id is null then
        v_res := jsonb_build_object('ok', false, 'error', 'codigo_no_valido', 'mensaje', 'Ese código no existe para esta clave. Prepara la publicación otra vez.');
      elsif v_aut.usada_en is not null then
        v_res := jsonb_build_object('ok', false, 'error', 'codigo_usado', 'mensaje', 'Ese código ya se usó el ' || to_char(v_aut.usada_en at time zone 'Europe/Madrid', 'DD-MM-YYYY HH24:MI') || '.');
      elsif v_aut.caduca_en < now() then
        v_res := jsonb_build_object('ok', false, 'error', 'codigo_caducado', 'mensaje', 'El código caducó (30 minutos). Prepara la publicación otra vez.');
      else
        -- Las sesiones salen del código, no de la petición: se publica exactamente lo autorizado.
        for it in select * from jsonb_array_elements(v_aut.sesiones) loop
          select * into s from public.sesiones where id = (it->>'sesion_id')::uuid for update;
          if s.id is null or not public.academia_api_puede(k, s.grupo_id, 'publicar') then raise exception 'sesion_no_encontrada'; end if;
          if s.publicada or s.archivada_en is not null or s.version <> (it->>'version')::int or public.academia_huella(to_jsonb(s)) <> it->>'huella' then
            v_conf := v_conf || jsonb_build_array(jsonb_build_object('sesion_id', s.id, 'conflicto', 'cambio_desde_la_autorizacion',
                         'version_autorizada', it->'version', 'version_actual', s.version, 'publicada', s.publicada,
                         'huella_autorizada', it->'huella', 'huella_actual', public.academia_huella(to_jsonb(s))));
          end if;
        end loop;
        if jsonb_array_length(v_conf) > 0 then
          v_res := jsonb_build_object('ok', false, 'error', 'conflictos', 'mensaje', 'No se ha publicado nada: algo cambió desde que Andrés lo autorizó. Hay que preparar y autorizar otra vez.', 'conflictos', v_conf);
        else
          perform set_config('apolana.motivo', left('Publicado por ChatGPT con autorización de Andrés (código ' || v_cod || '): ' || (a->>'autorizacion_texto'), 300), true);
          for it in select * from jsonb_array_elements(v_aut.sesiones) loop
            update public.sesiones set publicada = true
             where id = (it->>'sesion_id')::uuid and version = (it->>'version')::int and not publicada
            returning * into s;
            get diagnostics v_n = row_count;
            if v_n <> 1 then raise exception 'concurrente'; end if;
            v_conf := v_conf || jsonb_build_array(jsonb_build_object(
              'sesion_id', s.id, 'fecha', s.fecha, 'titulo', s.titulo, 'version_autorizada', (it->>'version')::int, 'version_publicada', s.version,
              'huella_autorizada', it->>'huella',
              'huella_publicada', (select public.academia_huella(v.datos) from public.sesiones_versiones v where v.sesion_id = s.id and v.version = s.version),
              'coincide', (select public.academia_huella(v.datos) from public.sesiones_versiones v where v.sesion_id = s.id and v.version = s.version) = it->>'huella'));
          end loop;
          if exists (select 1 from jsonb_array_elements(v_conf) x where not (x->>'coincide')::boolean) then
            raise exception 'la versión publicada no coincide con la autorizada';
          end if;
          update public.academia_api_autorizaciones set usada_en = now(), autorizacion_texto = left(a->>'autorizacion_texto', 500), resultado = v_conf where id = v_aut.id;
          v_res := jsonb_build_object('ok', true, 'publicadas', v_conf,
            'nota', 'Publicadas en el grupo REAL: los atletas ya las ven. Cada una es exactamente la versión autorizada (misma huella). La autorización queda registrada.');
        end if;
      end if;

    else
      v_res := jsonb_build_object('ok', false, 'error', 'operacion_desconocida', 'mensaje', 'Operación no reconocida: ' || coalesce(p_operacion, '—'));
    end if;
  exception when others then
    v_res := jsonb_build_object('ok', false,
      'error', case when sqlerrm = 'concurrente' then 'conflicto_version'
                    when sqlerrm in ('grupo_no_permitido','sesion_no_encontrada') then sqlerrm else 'datos_no_validos' end,
      'mensaje', case when sqlerrm = 'concurrente' then 'Cambio concurrente mientras se guardaba: no se ha guardado nada. Vuelve a leer.'
                      when sqlerrm = 'grupo_no_permitido' then 'Ese grupo no está permitido para esta clave o para esta operación (mira «estado»).'
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
end $function$;

revoke execute on function public.academia_api(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.academia_api(text, text, jsonb) to service_role;

-- Habilitación: SOLO la clave activa en Academia AC98 (grupo real).
insert into public.academia_api_habilitados (clave_id, grupo_id, permisos, habilitado_por, motivo)
select k.id, 'c288b979-cd00-4abb-96da-30fa997ef297', array['leer','borradores','revisiones','publicar'], 'c5c2958a-2ba0-4f8f-aaaf-8a796bd22eec',
       'Andrés, 29-oct-2026: que ChatGPT suba la planificación de Academia AC98 (leer, borradores, revisiones; publicar solo con su autorización expresa)'
  from public.api_claves k
 where k.id = '3f398432-d47a-4fe5-91ae-b9f9628ed37c' and k.revocada_en is null
on conflict (clave_id, grupo_id) do nothing;
