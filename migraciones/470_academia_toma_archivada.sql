-- ===========================================================================
-- 470 · Academia · registro rápido: archivada o sin permiso, dato a dato
-- ---------------------------------------------------------------------------
-- Al recuperar datos pendientes de un aparato puede que la sesión se haya
-- archivado o que ya no haya permiso. En vez de fallar todo el envío, cada dato
-- vuelve con su motivo («archivada», «sin_permiso», «no_existe») y NO se guarda:
-- la pantalla lo conserva y lo explica. Nada se fuerza. El resto, como en 469.
-- ===========================================================================
begin;

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
      -- (470) Sin permiso o sesión archivada: se dice dato a dato y no se guarda (lo pendiente se conserva).
      if not public.academia_puede(s.grupo_id) then
        v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'ok', false, 'conflicto', 'sin_permiso', 'mensaje', 'Ya no tienes permiso sobre esa sesión.'));
        continue;
      end if;
      if s.archivada_en is not null then
        v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'ok', false, 'conflicto', 'archivada', 'archivada_en', s.archivada_en,
                   'mensaje', 'La sesión se archivó: no se guarda nada en ella.'));
        continue;
      end if;
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

    -- (469) Borrar algo que nunca llegó a guardarse: no hay nada que borrar.
    if coalesce((it->>'anular')::boolean, false) then
      v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'ok', true, 'no_existia', true, 'dato', jsonb_build_object('id', v_id, 'anulado_en', now())));
      continue;
    end if;

    -- Alta
    s := null;
    select * into s from public.sesiones where id = nullif(it->>'sesion_id','')::uuid;
    if s.id is null then
      v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'ok', false, 'conflicto', 'no_existe', 'mensaje', 'Esa sesión ya no existe.'));
      continue;
    end if;
    if not public.academia_puede(s.grupo_id) then
      v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'ok', false, 'conflicto', 'sin_permiso', 'mensaje', 'Ya no tienes permiso sobre esa sesión.'));
      continue;
    end if;
    if s.archivada_en is not null then
      v_out := v_out || jsonb_build_array(jsonb_build_object('id', v_id, 'ok', false, 'conflicto', 'archivada', 'archivada_en', s.archivada_en,
                 'mensaje', 'La sesión se archivó: no se guarda nada en ella.'));
      continue;
    end if;
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

revoke all on function public.academia_toma_guardar(jsonb) from public, anon;
grant execute on function public.academia_toma_guardar(jsonb) to authenticated, service_role;

commit;
