-- ===========================================================================
-- 473 · Tests y marcas (2ª parte): parciales reales, modelo de parciales
--       objetivo y tramos identificados en el registro del atleta
-- ---------------------------------------------------------------------------
--   1) resultado_parciales: tiempos por tramo de UN resultado (marca o test) y
--      de UN intento: desde–hasta en metros, si es tramo (consecutivo) o paso
--      (acumulado desde el inicio del cronometraje), método e inicio del
--      cronometraje. Solo lo medido: nada se deduce ni se mezclan intentos.
--      Las sumas y diferencias se ven en pantalla, no se guardan.
--   2) objetivo_parciales: el MODELO objetivo (no son mediciones) de un objetivo
--      acordado: total, tramos y subdivisiones, fundamento, quién y cuándo, con
--      versión e historial. Sin coeficientes ni proyecciones: lo escribe una
--      persona.
--   3) registros_sesion.tramos_atleta: el atleta puede identificar sus tiempos
--      por fila, serie, repetición y tramo (desde–hasta), igual que la toma del
--      entrenador. Así se comparan dato a dato, nunca por posición.
--   4) Las fechas de las temporadas las cambia administración por sus papeles
--      (no por la vista activa).
-- ===========================================================================
begin;

-- 1 · Parciales reales -------------------------------------------------------------------
create table public.resultado_parciales (
  id                uuid primary key default gen_random_uuid(),
  atleta_id         uuid not null references public.atletas(id) on delete cascade,
  marca_id          uuid references public.marcas_atleta(id) on delete cascade,
  test_resultado_id uuid references public.test_resultados(id) on delete cascade,
  intento           int  not null default 1 check (intento >= 1),
  desde_m           numeric not null check (desde_m >= 0),
  hasta_m           numeric not null,
  medida            text not null check (medida in ('tramo','paso')),
  tiempo_s          numeric not null check (tiempo_s > 0),
  metodo            text check (metodo in ('manual','fotocelulas','electronico_competicion','video','otro','no_consta')),
  inicio_crono      text,
  nota              text,
  version           int not null default 1,
  creado_por        uuid default public.mi_perfil_id(),
  creado_en         timestamptz not null default now(),
  actualizado_por   uuid,
  actualizado_en    timestamptz,
  check (hasta_m > desde_m),
  check (num_nonnulls(marca_id, test_resultado_id) = 1)
);
create unique index resultado_parciales_unico on public.resultado_parciales
  (coalesce(marca_id, test_resultado_id), intento, desde_m, hasta_m, medida);
create index resultado_parciales_atleta on public.resultado_parciales (atleta_id);

alter table public.resultados_historial drop constraint resultados_historial_tabla_check;
alter table public.resultados_historial add constraint resultados_historial_tabla_check
  check (tabla in ('marcas_atleta','test_resultados','rm_atleta','resultado_parciales','objetivo_parciales'));
create trigger trg_resultado_parciales_versionar before update or delete on public.resultado_parciales
  for each row execute function public.resultados_versionar();

-- Guarda el conjunto de parciales de un resultado e intento. Comprueba que nadie lo
-- haya cambiado desde que se abrió (base = ids y versiones vistas).
create or replace function public.parciales_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare v_marca uuid := nullif(p->>'marca_id','')::uuid; v_test uuid := nullif(p->>'test_resultado_id','')::uuid; v_int int := coalesce(nullif(p->>'intento','')::int, 1);
        v_at uuid; v_ahora jsonb; v_base jsonb := coalesce(p->'base', '[]'::jsonb); x jsonb; n int := 0;
begin
  if num_nonnulls(v_marca, v_test) <> 1 then raise exception 'Indica el resultado (marca o test).'; end if;
  if v_marca is not null then select atleta_id into v_at from public.marcas_atleta where id = v_marca;
  else select atleta_id into v_at from public.test_resultados where id = v_test; end if;
  if v_at is null then raise exception 'Ese resultado no existe.'; end if;
  if not public.puede_resultados(v_at) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'version', version) order by id), '[]'::jsonb) into v_ahora
    from public.resultado_parciales where coalesce(marca_id, test_resultado_id) = coalesce(v_marca, v_test) and intento = v_int;
  if v_ahora <> (select coalesce(jsonb_agg(e order by e->>'id'), '[]'::jsonb) from jsonb_array_elements(v_base) e) then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla ha cambiado estos parciales: vuelve a abrirlos. No se ha pisado nada.');
  end if;
  perform set_config('apolana.motivo', coalesce(p->>'motivo', ''), true);
  delete from public.resultado_parciales where coalesce(marca_id, test_resultado_id) = coalesce(v_marca, v_test) and intento = v_int;
  for x in select * from jsonb_array_elements(coalesce(p->'parciales', '[]'::jsonb)) loop
    insert into public.resultado_parciales (atleta_id, marca_id, test_resultado_id, intento, desde_m, hasta_m, medida, tiempo_s, metodo, inicio_crono, nota)
    values (v_at, v_marca, v_test, v_int, (x->>'desde_m')::numeric, (x->>'hasta_m')::numeric, x->>'medida', (x->>'tiempo_s')::numeric,
            nullif(x->>'metodo',''), nullif(btrim(coalesce(x->>'inicio_crono','')),''), nullif(btrim(coalesce(x->>'nota','')),''));
    n := n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'guardados', n);
end $$;

-- 2 · Modelo de parciales objetivo ---------------------------------------------------------
create table public.objetivo_parciales (
  id              uuid primary key default gen_random_uuid(),
  atleta_id       uuid not null references public.atletas(id) on delete cascade,
  objetivo_id     uuid not null unique references public.atleta_objetivos(id) on delete cascade,
  tiempo_total_s  numeric check (tiempo_total_s > 0),
  tramos          jsonb not null default '[]' check (jsonb_typeof(tramos) = 'array'),  -- [{desde_m, hasta_m, tiempo_s}]
  fundamento      text,
  estado          text not null default 'borrador' check (estado in ('borrador','vigente','descartado')),
  version         int not null default 1,
  autor_perfil_id uuid,
  creado_en       timestamptz not null default now(),
  actualizado_por uuid,
  actualizado_en  timestamptz not null default now(),
  historial       jsonb not null default '[]'
);
comment on table public.objetivo_parciales is 'Modelo objetivo de parciales (no son mediciones). Las sumas y diferencias se calculan en pantalla.';
create trigger trg_objetivo_parciales_historial before insert or update on public.objetivo_parciales
  for each row execute function public.academia_ficha_historial();

create or replace function public.objetivo_parciales_guardar(p jsonb) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare o public.objetivo_parciales%rowtype; v_obj public.atleta_objetivos%rowtype; x jsonb;
begin
  select * into v_obj from public.atleta_objetivos where id = nullif(p->>'objetivo_id','')::uuid;
  if v_obj.id is null then raise exception 'Ese objetivo no existe.'; end if;
  if v_obj.tipo <> 'acordado' then raise exception 'El modelo de parciales va con el objetivo acordado.'; end if;
  if not public.academia_puede_atleta(v_obj.atleta_id) then raise exception 'Sin permiso.' using errcode = '42501'; end if;
  for x in select * from jsonb_array_elements(coalesce(p->'tramos','[]'::jsonb)) loop
    if (x->>'desde_m') is null or (x->>'hasta_m') is null or (x->>'hasta_m')::numeric <= (x->>'desde_m')::numeric then raise exception 'Cada tramo necesita desde y hasta (hasta mayor).'; end if;
    if (x->>'tiempo_s') is not null and (x->>'tiempo_s')::numeric <= 0 then raise exception 'Un tiempo de tramo tiene que ser positivo.'; end if;
  end loop;
  select * into o from public.objetivo_parciales where objetivo_id = v_obj.id for update;
  if o.id is null then
    insert into public.objetivo_parciales (atleta_id, objetivo_id, tiempo_total_s, tramos, fundamento, estado, autor_perfil_id)
    values (v_obj.atleta_id, v_obj.id, nullif(p->>'tiempo_total_s','')::numeric, coalesce(p->'tramos','[]'::jsonb), nullif(btrim(coalesce(p->>'fundamento','')),''),
            coalesce(nullif(p->>'estado',''),'borrador'), public.mi_perfil_id())
    returning * into o;
    return jsonb_build_object('ok', true, 'modelo', to_jsonb(o));
  end if;
  if nullif(p->>'version_base','')::int is distinct from o.version then
    return jsonb_build_object('ok', false, 'conflicto', 'version', 'mensaje', 'Otra pantalla ha cambiado este modelo: vuelve a abrirlo. No se ha pisado nada.', 'modelo', to_jsonb(o));
  end if;
  update public.objetivo_parciales set tiempo_total_s = nullif(p->>'tiempo_total_s','')::numeric, tramos = coalesce(p->'tramos','[]'::jsonb),
         fundamento = nullif(btrim(coalesce(p->>'fundamento','')),''), estado = coalesce(nullif(p->>'estado',''), estado), actualizado_por = public.mi_perfil_id()
   where id = o.id returning * into o;
  return jsonb_build_object('ok', true, 'modelo', to_jsonb(o));
end $$;

-- 3 · Tramos identificados en el registro del atleta ---------------------------------------
alter table public.registros_sesion add column tramos_atleta jsonb check (tramos_atleta is null or jsonb_typeof(tramos_atleta) = 'array');
comment on column public.registros_sesion.tramos_atleta is
  'Tiempos que el atleta identifica: [{fila_id, serie, repeticion, desde_m, hasta_m, tramo, medida tramo|paso, valor_texto, metodo}]. Misma identidad que academia_toma_datos.';

-- 4 · Temporadas: por papeles, no por la vista activa ------------------------------------------
drop policy "temporadas: las fechas las cambia administración" on public.temporadas_planificacion;
create policy "temporadas: las fechas las cambia administración" on public.temporadas_planificacion for update to authenticated
  using ((select public.soy_admin_de_verdad())) with check ((select public.soy_admin_de_verdad()));

-- Permisos
alter table public.resultado_parciales enable row level security;
alter table public.objetivo_parciales enable row level security;
revoke all on public.resultado_parciales, public.objetivo_parciales from public, anon, authenticated;
grant select on public.resultado_parciales, public.objetivo_parciales to authenticated;
create policy "parciales: quien puede ver al atleta" on public.resultado_parciales for select to authenticated
  using (public.puede_resultados(atleta_id) or atleta_id in (select public.mis_atletas()));
create policy "modelo de parciales: Academia y el propio atleta" on public.objetivo_parciales for select to authenticated
  using (public.academia_puede_atleta(atleta_id) or atleta_id in (select public.mis_atletas()));
revoke execute on function public.parciales_guardar(jsonb), public.objetivo_parciales_guardar(jsonb) from public, anon;
grant execute on function public.parciales_guardar(jsonb), public.objetivo_parciales_guardar(jsonb) to authenticated;

commit;
