-- ===========================================================================
-- 476 · Calendario público, identidad de competiciones, catálogo y prioridades
-- ---------------------------------------------------------------------------
--   1) Calendario: una competición cancelada o aplazada se queda en la web con su
--      etiqueta; «aplazada» puede no tener aún nueva fecha (fecha_por_confirmar).
--      Lo público (nombre, fecha, sede, estado, organizador, referencia oficial)
--      queda en el historial de la competición. Lo de Academia (participación,
--      pruebas, prioridad, propósito, notas) no se publica: va en competicion_atleta
--      y competicion_plan, que no son de lectura pública.
--   2) Permisos del calendario común: los mismos de siempre (administración y
--      comunicación). Academia no los amplía. Para probar, Academia puede crear
--      competiciones de PRUEBA (es_prueba), que no se ven en la web.
--   3) Identidad: el id es la identidad. Nombre y fecha solo sirven para avisar de
--      un posible duplicado; la sede, el organizador o la referencia oficial
--      deciden. Una misma referencia oficial no se repite.
--   4) Resultados: importar otra vez la misma huella con otros datos ya no devuelve
--      «repetido» a ciegas: avisa de que el acta ha cambiado para corregirlo (con
--      historial) sobre el mismo resultado.
--   5) Catálogo: 80 m lisos, 500 m y 600 m como pruebas propias (sin suponer en qué
--      categorías valen). Las seis ambiguas siguen pendientes.
--   6) Prioridades A/B/C con el texto propuesto; los recuentos de «próximas» y de
--      retos no cuentan canceladas ni pruebas, y sí lo «realizado».
-- ===========================================================================
begin;

-- 1 · Calendario ------------------------------------------------------------------------------
alter table public.competiciones
  add column fecha_por_confirmar boolean not null default false,
  add column organizador         text,
  add column referencia_oficial  text,
  add column es_prueba           boolean not null default false;
alter table public.competiciones add constraint competiciones_fecha_por_confirmar_check
  check (not fecha_por_confirmar or estado = 'aplazada');
create unique index competiciones_referencia_unica on public.competiciones (lower(btrim(referencia_oficial)))
  where referencia_oficial is not null and btrim(referencia_oficial) <> '';
comment on column public.competiciones.fecha_por_confirmar is 'Aplazada sin nueva fecha: fecha_inicio conserva la original y la web dice «nueva fecha por confirmar».';
comment on column public.competiciones.es_prueba is 'Competición ficticia para probar Academia: no se ve en la web ni cuenta en ningún recuento.';

create or replace function public.competiciones_historial() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if (old.nombre, coalesce(old.sede,''), old.fecha_inicio, old.fecha_fin, old.estado, old.fecha_por_confirmar, coalesce(old.organizador,''), coalesce(old.referencia_oficial,''))
     is distinct from (new.nombre, coalesce(new.sede,''), new.fecha_inicio, new.fecha_fin, new.estado, new.fecha_por_confirmar, coalesce(new.organizador,''), coalesce(new.referencia_oficial,'')) then
    new.historial := old.historial || jsonb_build_array(jsonb_build_object(
      'nombre', old.nombre, 'sede', old.sede, 'fecha_inicio', old.fecha_inicio, 'fecha_fin', old.fecha_fin, 'estado', old.estado,
      'fecha_por_confirmar', old.fecha_por_confirmar, 'organizador', old.organizador, 'referencia_oficial', old.referencia_oficial,
      'cambiado_en', now(), 'cambiado_por', public.mi_perfil_id(), 'motivo', nullif(current_setting('apolana.motivo', true), '')));
    new.version := old.version + 1; new.actualizado_en := now(); new.actualizado_por := public.mi_perfil_id();
  end if;
  return new;
end $$;

-- Lo de prueba no se ve en la web.
drop policy "lectura publica" on public.competiciones;
create policy "lectura publica" on public.competiciones for select using (not es_prueba);
create policy "competiciones de prueba: equipo técnico" on public.competiciones for select to authenticated
  using (es_prueba and (select public.puede_catalogo_tests()));

-- 2 · Permisos del calendario común: los de siempre ---------------------------------------------
create or replace function public.puedo_editar_calendario() returns boolean
language sql stable security definer set search_path to 'public' as $$
  select public.soy_admin_de_verdad() or public.es_responsable_liga();
$$;
comment on function public.puedo_editar_calendario() is 'Quién cambia el calendario común (el de la web): administración y comunicación, como en sus políticas. Academia no lo amplía.';

create or replace function public._academia_entrena() returns boolean
language sql stable security definer set search_path to 'public' as $$
  select public.soy_admin_de_verdad()
      or exists (select 1 from public.academia_grupos ag join public.grupos g on g.id = ag.grupo_id where g.entrenador_id = public.mi_perfil_id());
$$;

-- 3 · Guardar una competición desde Academia -----------------------------------------------------
-- p = {id?, version_base, nombre, sede, fecha_inicio, fecha_fin, estado, fecha_por_confirmar, organizador,
--      referencia_oficial, es_prueba (solo al crear), confirmar_distinta, motivo}
create or replace function public.academia_competicion_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare c public.competiciones%rowtype; v_id uuid := nullif(p->>'id','')::uuid; v_prueba boolean; v_ref text; v_fpc boolean; v_est text; cand jsonb;
begin
  if v_id is not null then select * into c from public.competiciones where id = v_id for update;
    if c.id is null then raise exception 'Esa competición no existe.'; end if;
    v_prueba := c.es_prueba;                             -- no se cambia: ni se publica una de prueba ni se esconde una real
  else v_prueba := coalesce((p->>'es_prueba')::boolean, false); end if;
  if not (case when v_prueba then public._academia_entrena() else public.puedo_editar_calendario() end) then
    raise exception '%', case when v_prueba then 'Sin permiso.' else 'El calendario de la web lo cambian administración y comunicación.' end using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p->>'nombre','')),'') is null or nullif(p->>'fecha_inicio','') is null then raise exception 'Faltan el nombre o la fecha.'; end if;
  if nullif(p->>'fecha_fin','')::date < (p->>'fecha_inicio')::date then raise exception 'La fecha de fin es anterior a la de inicio.'; end if;
  v_est := coalesce(nullif(p->>'estado',''), 'programada');
  if v_est not in ('programada','aplazada','cancelada') then raise exception 'Estado no válido.'; end if;
  v_fpc := v_est = 'aplazada' and coalesce((p->>'fecha_por_confirmar')::boolean, false);
  v_ref := nullif(btrim(coalesce(p->>'referencia_oficial','')),'');
  perform set_config('apolana.motivo', coalesce(p->>'motivo', ''), true);
  if v_id is null then
    -- La referencia oficial identifica: si ya está, es la misma competición.
    if v_ref is not null then
      select * into c from public.competiciones where lower(btrim(referencia_oficial)) = lower(v_ref);
      if c.id is not null then return jsonb_build_object('ok', false, 'conflicto', 'misma_referencia', 'competicion', to_jsonb(c),
        'mensaje', 'Ya está en el calendario con esa referencia oficial: «' || c.nombre || '».'); end if;
    end if;
    -- Nombre y fecha solo avisan: pueden ser competiciones distintas (otra sede, otra jornada).
    if not coalesce((p->>'confirmar_distinta')::boolean, false) then
      select jsonb_agg(jsonb_build_object('id', k.id, 'nombre', k.nombre, 'sede', k.sede, 'fecha_inicio', k.fecha_inicio, 'fecha_fin', k.fecha_fin,
                                          'organizador', k.organizador, 'referencia_oficial', k.referencia_oficial, 'estado', k.estado))
        into cand from public.competiciones k
       where k.es_prueba = v_prueba and public.prueba_normalizar(k.nombre) = public.prueba_normalizar(p->>'nombre')
         and k.fecha_inicio <= coalesce(nullif(p->>'fecha_fin','')::date, (p->>'fecha_inicio')::date)
         and coalesce(k.fecha_fin, k.fecha_inicio) >= (p->>'fecha_inicio')::date;
      if cand is not null then return jsonb_build_object('ok', false, 'conflicto', 'posible_duplicado', 'candidatos', cand,
        'mensaje', 'Ya hay una competición con ese nombre en esas fechas. ¿Es la misma? Si es otra (otra sede u otra jornada), créala igualmente.'); end if;
    end if;
    insert into public.competiciones (nombre, sede, fecha_inicio, fecha_fin, ambito, estado, fecha_por_confirmar, organizador, referencia_oficial, es_prueba, notas, creado_por)
    values (btrim(p->>'nombre'), nullif(btrim(coalesce(p->>'sede','')),''), (p->>'fecha_inicio')::date, nullif(p->>'fecha_fin','')::date,
            coalesce(nullif(p->>'ambito',''), 'pista'), v_est, v_fpc, nullif(btrim(coalesce(p->>'organizador','')),''), v_ref, v_prueba,
            nullif(btrim(coalesce(p->>'notas','')),''), public.mi_perfil_id())
    returning * into c;
    return jsonb_build_object('ok', true, 'competicion', to_jsonb(c));
  end if;
  if nullif(p->>'version_base','')::int is distinct from c.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla ha cambiado esta competición: vuelve a abrirla. No se ha pisado nada.', 'competicion', to_jsonb(c));
  end if;
  if v_ref is not null and exists (select 1 from public.competiciones where lower(btrim(referencia_oficial)) = lower(v_ref) and id <> c.id) then
    raise exception 'Esa referencia oficial ya es de otra competición.';
  end if;
  update public.competiciones set nombre = btrim(p->>'nombre'), sede = nullif(btrim(coalesce(p->>'sede','')),''), fecha_inicio = (p->>'fecha_inicio')::date,
         fecha_fin = nullif(p->>'fecha_fin','')::date, estado = v_est, fecha_por_confirmar = v_fpc,
         organizador = nullif(btrim(coalesce(p->>'organizador','')),''), referencia_oficial = v_ref
   where id = v_id returning * into c;
  return jsonb_build_object('ok', true, 'competicion', to_jsonb(c));
end $$;

-- 4 · Resultados: corregir cuando cambia el acta ---------------------------------------------------
create or replace function public.resultado_guardar(p jsonb)
 returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare m public.marcas_atleta%rowtype; v_id uuid := nullif(p->>'id','')::uuid; v_at uuid := nullif(p->>'atleta_id','')::uuid;
        v_pr public.pruebas%rowtype; v_txt text; v_lee jsonb; v_cat jsonb; v_fn date; v_alt numeric; v_fecha date;
        v_par public.competicion_atleta%rowtype; v_comp uuid; v_of boolean; v_ronda text;
begin
  if v_id is not null then select * into m from public.marcas_atleta where id = v_id for update; v_at := m.atleta_id; end if;
  if v_at is null or not public.puede_resultados(v_at) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if v_id is not null and m.id is null then raise exception 'Ese resultado no existe.'; end if;
  -- Importar dos veces lo mismo no lo duplica (se mira más abajo, ya leído el valor).
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
    return jsonb_build_object('ok', false, 'conflicto', 'oficial', 'mensaje', 'Ya hay un resultado oficial de esa ronda en esta inscripción: corrígelo (queda en el historial).',
      'resultado', (select to_jsonb(x) from public.marcas_atleta x where x.participacion_id = v_par.id and x.oficial and coalesce(x.ronda,'unica') = coalesce(v_ronda,'unica') and x.id is distinct from v_id limit 1));
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
  -- Misma huella: si trae lo mismo, no se duplica; si el acta ha cambiado, se avisa y se corrige
  -- sobre el mismo resultado (con su historial), nunca se crea otro.
  if v_id is null and nullif(p->>'huella','') is not null then
    select * into m from public.marcas_atleta where huella = p->>'huella';
    if m.id is not null then
      if m.tiempo_segundos = (v_lee->>'num')::numeric and m.fecha is not distinct from v_fecha and m.prueba_id is not distinct from v_pr.id
         and m.viento is not distinct from nullif(p->>'viento','')::numeric and coalesce(m.condiciones,'{}') = coalesce(p->'condiciones','{}'::jsonb) then
        return jsonb_build_object('ok', true, 'repetido', true, 'resultado', to_jsonb(m));
      end if;
      return jsonb_build_object('ok', false, 'conflicto', 'acta_distinta', 'resultado', to_jsonb(m),
        'mensaje', 'Ya estaba importado con otros datos (' || coalesce(m.tiempo_display, m.tiempo_segundos::text) || ' el ' || coalesce(to_char(m.fecha, 'DD/MM/YYYY'), 'sin fecha') ||
                   '). Si el acta ha cambiado, corrígelo: queda en el historial.');
    end if;
  end if;
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


-- 5 · Catálogo: 80 m lisos, 500 m y 600 m (en qué categorías valen lo dicen la normativa y las mínimas)
update public.pruebas set orden = orden + 1 where ambito = 'atletismo' and disciplina = 'velocidad' and orden >= 11;
insert into public.pruebas (nombre, disciplina, ambito, unidad, mas_es_mejor, orden, activa, distancia_m) values
  ('80 m lisos', 'velocidad',   'atletismo', 'tiempo', false, 11, true, 80),
  ('500 m',      'velocidad',   'atletismo', 'tiempo', false, 17, true, 500),
  ('600 m',      'medio fondo', 'atletismo', 'tiempo', false, 29, true, 600);
select public.pruebas_correspondencias_actualizar();

-- 6 · Prioridades: la propuesta, visible y editable -----------------------------------------------
update public.competicion_prioridades set nombre = 'Objetivo principal', significado = 'Competición objetivo principal.' where clave = 'A';
update public.competicion_prioridades set nombre = 'Importante',         significado = 'Competición importante de preparación o evaluación.' where clave = 'B';
update public.competicion_prioridades set nombre = 'Control',            significado = 'Control o participación de preparación.' where clave = 'C';

-- Recuentos: sin canceladas ni pruebas; lo realizado cuenta en los retos.
CREATE OR REPLACE FUNCTION public.comunicacion_resumen()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when not (public.es_admin() or public.es_staff() or public.soy_responsable('comunicacion')) then '{}'::jsonb
  else jsonb_build_object(
    'liga_validar',      (select count(*) from liga_participaciones where estado = 'pendiente'),
    'competis_proximas', (select count(*) from competiciones where fecha_inicio >= current_date and estado <> 'cancelada' and not es_prueba),
    'competis_insc',     (select count(*) from competiciones where inscripcion_abierta is true and estado <> 'cancelada' and not es_prueba),
    'redes',             (select count(*) from peticiones_redes where coalesce(estado,'nueva') not in ('publicada','rechazada','hecha','resuelta','descartada'))
  ) end
$function$;

CREATE OR REPLACE FUNCTION public.mundo_stats(p_world text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case
    when not (public.es_admin() or public.es_staff() or (p_world = any(public.mis_mundos()))) then '[]'::jsonb
    when p_world = 'cubo' then jsonb_build_array(
      jsonb_build_object('n', (select count(*) from atletas where tipo_membresia='cubo'), 'l','integrantes'),
      jsonb_build_object('n', (select count(*) from grupos where seccion='cubo'),          'l','grupos'),
      jsonb_build_object('n', (select count(*) from cubo_prueba),                          'l','a prueba') )
    when p_world = 'pista' then jsonb_build_array(
      jsonb_build_object('n', (select count(*) from atletas where 'atletismo' = any(secciones)), 'l','atletas'),
      jsonb_build_object('n', (select count(*) from grupos where seccion='competicion'),         'l','grupos'),
      jsonb_build_object('n', (select count(*) from competiciones where fecha_inicio >= current_date and estado <> 'cancelada' and not es_prueba), 'l','próximas carreras') )
    when p_world = 'escuela-atl' then jsonb_build_array(
      jsonb_build_object('n', (select count(*) from grupos where seccion='escuela'), 'l','grupos'),
      jsonb_build_object('n', (select count(*) from altas_escuela where coalesce(estado,'nueva') not in ('rechazada','revisada','aprobada','baja')), 'l','altas nuevas') )
    when p_world = 'escuela-nat' then jsonb_build_array(
      jsonb_build_object('n', (select count(distinct coalesce(acceso_id::text, nombre)) from natacion_inscripciones where activa and tipo='Escuela'), 'l','niños/as'),
      jsonb_build_object('n', (select count(*) from natacion_franjas where coalesce(activa,true) and grupo ilike '%escuela%'), 'l','franjas'),
      jsonb_build_object('n', public._natacion_pct_ocupado('escuela-natacion'), 'l','plazas ocupadas') )
    when p_world = 'natacion' then jsonb_build_array(
      jsonb_build_object('n', public._natacion_pct_ocupado('natacion'), 'l','plazas ocupadas') )
    when p_world = 'running' then jsonb_build_array(
      jsonb_build_object('n', (select count(*) from grupos where seccion='running'), 'l','grupos') )
    else '[]'::jsonb
  end
$function$;

CREATE OR REPLACE FUNCTION public.juego_metrica(p_metrica text, p_desde date, p_hasta date)
 RETURNS TABLE(atleta_id uuid, valor numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
begin
  if p_metrica = 'asistencias' then
    -- Días con la casilla de «presente» marcada.
    return query
      select s.atleta_id, count(*)::numeric
        from public.asistencia s
       where s.presente is true and s.fecha between p_desde and p_hasta
       group by s.atleta_id;

  elsif p_metrica = 'racha_asistencias' then
    -- La tira más larga de asistencias seguidas: se numeran los días y se
    -- agrupan los que van pegados sin ninguna falta en medio.
    return query
      with dias as (
        select s.atleta_id as aid, s.fecha, s.presente,
               row_number() over (partition by s.atleta_id order by s.fecha)
             - row_number() over (partition by s.atleta_id, s.presente order by s.fecha) as bloque
          from public.asistencia s
         where s.fecha between p_desde and p_hasta
      ), rachas as (
        select d.aid, count(*)::numeric as largo
          from dias d where d.presente is true
         group by d.aid, d.bloque
      )
      select r.aid, max(r.largo) from rachas r group by r.aid;

  elsif p_metrica = 'entrenos_registrados' then
    -- Entrenos en los que el atleta mandó sus sensaciones.
    return query
      select r.atleta_id, count(*)::numeric
        from public.registros_sesion r
        join public.sesiones s on s.id = r.sesion_id
       where s.fecha between p_desde and p_hasta
       group by r.atleta_id;

  elsif p_metrica = 'cubo_clases' then
    -- Clases de El Cubo a las que se fue de verdad.
    return query
      select v.atleta_id, count(*)::numeric
        from public.cubo_reservas v
        join public.cubo_clases c on c.id = v.clase_id
       where v.estado = 'asistida' and c.fecha between p_desde and p_hasta
       group by v.atleta_id;

  elsif p_metrica = 'competiciones' then
    -- Competiciones distintas con la inscripción confirmada o ya realizada (mig 474), sin las canceladas ni las de prueba.
    return query
      select ca.atleta_id, count(distinct ca.competicion_id)::numeric
        from public.competicion_atleta ca
        join public.competiciones c on c.id = ca.competicion_id
       where ca.estado in ('confirmada','realizado') and c.estado <> 'cancelada' and not c.es_prueba and c.fecha_inicio between p_desde and p_hasta
       group by ca.atleta_id;

  elsif p_metrica = 'marcas' then
    -- Marcas nuevas apuntadas. Los «objetivo» son deseos, no marcas hechas.
    return query
      select m.atleta_id, count(*)::numeric
        from public.marcas_atleta m
       where coalesce(m.tipo,'') <> 'objetivo' and m.fecha between p_desde and p_hasta
       group by m.atleta_id;

  elsif p_metrica = 'mejores_personales' then
    return query
      select m.atleta_id, count(*)::numeric
        from public.marcas_atleta m
       where m.tipo = 'mmp' and m.fecha between p_desde and p_hasta
       group by m.atleta_id;

  elsif p_metrica = 'tests' then
    -- Baterías de tests distintas en las que sí se participó.
    return query
      select t.atleta_id, count(distinct t.bateria_id)::numeric
        from public.test_resultados t
        join public.test_baterias b on b.id = t.bateria_id
       where t.no_asiste is false and b.fecha between p_desde and p_hasta
       group by t.atleta_id;

  -- --- Solo para medallas -------------------------------------------
  elsif p_metrica = 'retos_completados' then
    return query
      select l.atleta_id, count(*)::numeric
        from public.reto_logros l
       where l.completado_en::date between p_desde and p_hasta
       group by l.atleta_id;

  elsif p_metrica = 'puntos' then
    return query
      select pj.atleta_id, pj.puntos::numeric
        from public.perfil_juego pj
       where pj.puntos > 0;
  end if;
  return;
end;
$function$;

CREATE OR REPLACE FUNCTION public.competicion_abierta(p_comp uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.competiciones c
    where c.id = p_comp
      and coalesce(c.inscripcion_abierta, false)
      and c.estado <> 'cancelada'
      and (c.fecha_limite_interna is null or c.fecha_limite_interna > now())
  );
$function$;

revoke execute on function public.puedo_editar_calendario(), public._academia_entrena() from public, anon;
grant execute on function public.puedo_editar_calendario(), public._academia_entrena() to authenticated;

commit;
