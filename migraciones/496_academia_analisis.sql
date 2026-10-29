-- 496 · Academia · Análisis del atleta (v1, solo grupos de prueba en pantalla)
-- Definiciones: docs/definiciones-analisis-atleta.md
--   1) Modelo de parciales: origen (entrenador / propuesta de ChatGPT / otro),
--      limitaciones y APROBACIÓN (quién, cuándo, qué versión). Solo un modelo
--      aprobado está «vigente»; editarlo lo devuelve a propuesta. Para aprobar,
--      los tramos tienen que cuadrar (objetivo_parciales_comprobar).
--   2) «Revisión cercana» configurable por grupo (21 días por defecto).
-- Nada de esto toca atleta_objetivos ni los entrenamientos.

-- 1 · Modelo de parciales ---------------------------------------------------------------
alter table public.objetivo_parciales
  add column origen text not null default 'entrenador' check (origen in ('entrenador','chatgpt','otro')),
  add column limitaciones text,
  add column aprobado_por uuid,
  add column aprobado_en timestamptz,
  add column aprobado_version int;
alter table public.objetivo_parciales drop constraint objetivo_parciales_estado_check;
alter table public.objetivo_parciales add constraint objetivo_parciales_estado_check
  check (estado in ('borrador','propuesta','vigente','descartado'));
-- Un modelo «vigente» que nadie aprobó pasa a propuesta (no había ninguno al escribir esto).
update public.objetivo_parciales set estado = 'propuesta' where estado = 'vigente' and aprobado_en is null;
alter table public.objetivo_parciales add constraint objetivo_parciales_vigente_aprobado
  check (estado <> 'vigente' or (aprobado_en is not null and aprobado_por is not null and aprobado_version = version));
comment on column public.objetivo_parciales.origen is 'Quién lo preparó: el entrenador, una propuesta de ChatGPT u otro. Una propuesta nunca es vigente sin aprobación.';
comment on column public.objetivo_parciales.aprobado_version is 'Versión que se aprobó. Si el modelo cambia, deja de estar aprobado.';

-- ¿Cuadran los tramos? Principales = los que no están dentro de otro: seguidos desde 0 y
-- sumando el total. Cada subdivisión (tramos dentro de un principal) cubre su tramo
-- entero y suma su tiempo. Tolerancia: 0,005 s.
create or replace function public.objetivo_parciales_comprobar(p_tramos jsonb, p_total numeric) returns jsonb
language plpgsql immutable set search_path to 'public' as $$
declare v_pr jsonb := '[]'; v_msg text[] := '{}'; x jsonb; y jsonb; v_fin numeric := 0; v_suma numeric := 0;
        v_sub jsonb; v_sfin numeric; v_ssuma numeric; v_dentro boolean;
begin
  if p_tramos is null or jsonb_typeof(p_tramos) <> 'array' or jsonb_array_length(p_tramos) = 0 then
    return jsonb_build_object('cuadra', false, 'mensajes', jsonb_build_array('Sin tramos.'));
  end if;
  for x in select e from jsonb_array_elements(p_tramos) e order by (e->>'desde_m')::numeric, (e->>'hasta_m')::numeric desc loop
    if (x->>'tiempo_s') is null then v_msg := v_msg || ('Tramo ' || (x->>'desde_m') || '–' || (x->>'hasta_m') || ' m sin tiempo.'); end if;
    v_dentro := exists (select 1 from jsonb_array_elements(p_tramos) e
                         where (e->>'desde_m')::numeric <= (x->>'desde_m')::numeric and (e->>'hasta_m')::numeric >= (x->>'hasta_m')::numeric
                           and not ((e->>'desde_m')::numeric = (x->>'desde_m')::numeric and (e->>'hasta_m')::numeric = (x->>'hasta_m')::numeric));
    if not v_dentro then v_pr := v_pr || jsonb_build_array(x); end if;
  end loop;
  for x in select e from jsonb_array_elements(v_pr) e order by (e->>'desde_m')::numeric loop
    if (x->>'desde_m')::numeric <> v_fin then
      v_msg := v_msg || ('Los tramos no son seguidos: falta de ' || v_fin || ' a ' || (x->>'desde_m') || ' m.');
    end if;
    v_fin := (x->>'hasta_m')::numeric;
    v_suma := v_suma + coalesce((x->>'tiempo_s')::numeric, 0);
    -- su subdivisión, si tiene
    select coalesce(jsonb_agg(e order by (e->>'desde_m')::numeric), '[]') into v_sub from jsonb_array_elements(p_tramos) e
     where (e->>'desde_m')::numeric >= (x->>'desde_m')::numeric and (e->>'hasta_m')::numeric <= (x->>'hasta_m')::numeric
       and not ((e->>'desde_m')::numeric = (x->>'desde_m')::numeric and (e->>'hasta_m')::numeric = (x->>'hasta_m')::numeric);
    if jsonb_array_length(v_sub) > 0 then
      v_sfin := (x->>'desde_m')::numeric; v_ssuma := 0;
      for y in select e from jsonb_array_elements(v_sub) e loop
        if (y->>'desde_m')::numeric <> v_sfin then v_msg := v_msg || ('La subdivisión de ' || (x->>'desde_m') || '–' || (x->>'hasta_m') || ' no es seguida.'); end if;
        v_sfin := (y->>'hasta_m')::numeric; v_ssuma := v_ssuma + coalesce((y->>'tiempo_s')::numeric, 0);
      end loop;
      if v_sfin <> (x->>'hasta_m')::numeric then v_msg := v_msg || ('La subdivisión de ' || (x->>'desde_m') || '–' || (x->>'hasta_m') || ' no llega al final del tramo.'); end if;
      if abs(v_ssuma - coalesce((x->>'tiempo_s')::numeric, 0)) > 0.005 then
        v_msg := v_msg || ('La subdivisión de ' || (x->>'desde_m') || '–' || (x->>'hasta_m') || ' suma ' || replace(round(v_ssuma, 2)::text, '.', ',') || ' y el tramo dice ' || replace(x->>'tiempo_s', '.', ',') || '.');
      end if;
    end if;
  end loop;
  if p_total is null then v_msg := v_msg || 'Falta el tiempo total.'::text;
  elsif abs(v_suma - p_total) > 0.005 then v_msg := v_msg || ('Los tramos suman ' || replace(round(v_suma, 2)::text, '.', ',') || ' y el total es ' || replace(p_total::text, '.', ',') || '.');
  end if;
  return jsonb_build_object('cuadra', cardinality(v_msg) = 0, 'suma', round(v_suma, 2), 'hasta_m', v_fin, 'mensajes', to_jsonb(v_msg));
end $$;

-- Guardar: como antes, más origen y limitaciones. Nunca deja un modelo «vigente»: si
-- estaba aprobado y cambia, vuelve a propuesta y pierde la aprobación.
create or replace function public.objetivo_parciales_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare o public.objetivo_parciales%rowtype; v_obj public.atleta_objetivos%rowtype; x jsonb; v_est text; v_or text;
begin
  select * into v_obj from public.atleta_objetivos where id = nullif(p->>'objetivo_id','')::uuid;
  if v_obj.id is null then raise exception 'Ese objetivo no existe.'; end if;
  if v_obj.tipo <> 'acordado' then raise exception 'El modelo de parciales va con el objetivo acordado.'; end if;
  if not public.academia_puede_atleta(v_obj.atleta_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  for x in select * from jsonb_array_elements(coalesce(p->'tramos','[]'::jsonb)) loop
    if (x->>'desde_m') is null or (x->>'hasta_m') is null or (x->>'hasta_m')::numeric <= (x->>'desde_m')::numeric then raise exception 'Cada tramo necesita desde y hasta (hasta mayor).'; end if;
    if (x->>'tiempo_s') is not null and (x->>'tiempo_s')::numeric <= 0 then raise exception 'Un tiempo de tramo tiene que ser positivo.'; end if;
  end loop;
  v_est := coalesce(nullif(p->>'estado',''), 'propuesta');
  if v_est = 'vigente' then v_est := 'propuesta'; end if;   -- vigente solo al aprobar
  if v_est not in ('borrador','propuesta','descartado') then raise exception 'Estado no válido.'; end if;
  v_or := coalesce(nullif(p->>'origen',''), 'entrenador');
  select * into o from public.objetivo_parciales where objetivo_id = v_obj.id for update;
  if o.id is null then
    insert into public.objetivo_parciales (atleta_id, objetivo_id, tiempo_total_s, tramos, fundamento, limitaciones, origen, estado, autor_perfil_id)
    values (v_obj.atleta_id, v_obj.id, nullif(p->>'tiempo_total_s','')::numeric, coalesce(p->'tramos','[]'::jsonb), nullif(btrim(coalesce(p->>'fundamento','')),''),
            nullif(btrim(coalesce(p->>'limitaciones','')),''), v_or, v_est, public.mi_perfil_id())
    returning * into o;
    return jsonb_build_object('ok', true, 'modelo', to_jsonb(o), 'comprobacion', public.objetivo_parciales_comprobar(o.tramos, o.tiempo_total_s));
  end if;
  if nullif(p->>'version_base','')::int is distinct from o.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla ha cambiado este modelo: vuelve a abrirlo. No se ha pisado nada.', 'modelo', to_jsonb(o));
  end if;
  update public.objetivo_parciales set tiempo_total_s = nullif(p->>'tiempo_total_s','')::numeric, tramos = coalesce(p->'tramos','[]'::jsonb),
         fundamento = nullif(btrim(coalesce(p->>'fundamento','')),''), limitaciones = nullif(btrim(coalesce(p->>'limitaciones','')),''),
         origen = v_or, estado = v_est, aprobado_por = null, aprobado_en = null, aprobado_version = null,
         actualizado_por = public.mi_perfil_id()
   where id = o.id returning * into o;
  return jsonb_build_object('ok', true, 'modelo', to_jsonb(o), 'comprobacion', public.objetivo_parciales_comprobar(o.tramos, o.tiempo_total_s));
end $$;

-- Aprobar: solo administración de verdad (Andrés), la versión que se está viendo y con
-- los tramos cuadrando. No toca el objetivo acordado.
create or replace function public.objetivo_parciales_aprobar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare o public.objetivo_parciales%rowtype; v_c jsonb;
begin
  if not public.soy_admin_de_verdad() then raise exception 'Solo administración puede aprobar un modelo de parciales.' using errcode = '42501'; end if;
  select * into o from public.objetivo_parciales where id = nullif(p->>'id','')::uuid for update;
  if o.id is null then raise exception 'Ese modelo no existe.'; end if;
  if not public.academia_puede_atleta(o.atleta_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  if nullif(p->>'version_base','')::int is distinct from o.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'El modelo ha cambiado desde que lo abriste: vuelve a abrirlo antes de aprobarlo.', 'modelo', to_jsonb(o));
  end if;
  v_c := public.objetivo_parciales_comprobar(o.tramos, o.tiempo_total_s);
  if not (v_c->>'cuadra')::boolean then
    return jsonb_build_object('ok', false, 'conflicto', 'no_cuadra', 'mensaje', 'No se puede aprobar: ' || array_to_string(array(select jsonb_array_elements_text(v_c->'mensajes')), ' '), 'comprobacion', v_c);
  end if;
  perform set_config('apolana.motivo', coalesce(p->>'motivo', 'aprobado'), true);
  update public.objetivo_parciales set estado = 'vigente', aprobado_por = public.mi_perfil_id(), aprobado_en = now(), aprobado_version = version + 1,
         actualizado_por = public.mi_perfil_id()
   where id = o.id returning * into o;
  return jsonb_build_object('ok', true, 'modelo', to_jsonb(o));
end $$;

revoke execute on function public.objetivo_parciales_comprobar(jsonb, numeric), public.objetivo_parciales_aprobar(jsonb) from public, anon;
grant execute on function public.objetivo_parciales_comprobar(jsonb, numeric), public.objetivo_parciales_aprobar(jsonb) to authenticated, service_role;

-- 2 · Revisión cercana por grupo -------------------------------------------------------
alter table public.academia_grupos add column revision_cercana_dias int not null default 21 check (revision_cercana_dias between 1 and 120);
comment on column public.academia_grupos.revision_cercana_dias is 'Criterio organizativo: una revisión de decisión a menos de estos días sale como «próxima revisión». No cierra nada.';

drop function public.academia_mis_grupos();
create function public.academia_mis_grupos()
 returns table(grupo_id uuid, nombre text, es_prueba boolean, feedback_hora_limite time without time zone, feedback_dias integer, revision_cercana_dias integer)
 language sql stable security definer set search_path to 'public'
as $$
  select ag.grupo_id, g.nombre, ag.es_prueba, ag.feedback_hora_limite, ag.feedback_dias, ag.revision_cercana_dias
    from public.academia_grupos ag join public.grupos g on g.id = ag.grupo_id
   where public.academia_puede(ag.grupo_id)
   order by ag.es_prueba, g.nombre;
$$;
revoke execute on function public.academia_mis_grupos() from public, anon;
grant execute on function public.academia_mis_grupos() to authenticated, service_role;
