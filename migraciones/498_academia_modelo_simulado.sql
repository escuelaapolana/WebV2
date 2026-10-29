-- 498 · Academia · Análisis: el modelo de parciales ficticio se etiqueta como lo que es.
-- «PRUEBA: origen ChatGPT simulado» (chatgpt_simulado) solo se admite en grupos de
-- prueba; el modelo de la mig 497 pasa a ese origen (sigue sin aprobar). Una propuesta
-- real de ChatGPT, cuando llegue por su conexión, será «chatgpt».
alter table public.objetivo_parciales drop constraint objetivo_parciales_origen_check;
alter table public.objetivo_parciales add constraint objetivo_parciales_origen_check
  check (origen in ('entrenador','chatgpt','chatgpt_simulado','otro'));

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
  -- «ChatGPT simulado» solo existe para probar: nunca en un grupo real.
  if v_or = 'chatgpt_simulado' and not exists (select 1 from public.atletas at join public.academia_grupos ag on ag.grupo_id = at.grupo_id
                                                where at.id = v_obj.atleta_id and ag.es_prueba) then
    raise exception 'El origen «ChatGPT simulado» solo vale en grupos de prueba.';
  end if;
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


do $$ begin
  perform set_config('apolana.autor', 'datos ficticios PRUEBA (mig 498)', true);
  perform set_config('apolana.motivo', 'etiqueta: PRUEBA, origen ChatGPT simulado', true);
  update public.objetivo_parciales o set origen = 'chatgpt_simulado'
   where o.origen = 'chatgpt' and o.estado <> 'vigente'
     and o.atleta_id in (select at.id from public.atletas at join public.academia_grupos ag on ag.grupo_id = at.grupo_id where ag.es_prueba)
     and o.fundamento like 'PROPUESTA FICTICIA (PRUEBA)%';
end $$;
