-- 497 · Academia · DATOS FICTICIOS para probar Análisis del atleta (solo grupo PRUEBA, solo Álex)
-- Repetible: identificadores fijos y «on conflict do nothing». Nada real se toca.
--   · 3 sesiones «2×(250+150)» anteriores (7, 14 y 21 oct) con tiempos, RPE y comentario
--     del atleta; el 21 también con toma del entrenador (método manual).
--   · 4 marcas de 200 m de 2026 (una con viento +2,6 y una manual de entreno) para ver
--     qué entra y qué queda aparte.
--   · Modelo de parciales para 22,20: PROPUESTA de ChatGPT, sin aprobar.
--   · 2 decisiones: una con revisión próxima y otra con la revisión vencida.
do $$
declare g uuid := '9fefd649-2fa2-4036-a4c0-dffe29a7bdee'; alex uuid := 'c3ad0e7a-4319-44dc-8375-79f41b56558c';
        yo uuid := 'c5c2958a-2ba0-4f8f-aaaf-8a796bd22eec'; p200 uuid := '9cf838e4-2535-4513-9394-156bba0553e4';
        obj uuid := 'e937fb25-47aa-47d3-a560-a5fcfd4112e5';
        d date; sid uuid; f1 text; f2 text; i int; t jsonb; rpe int; nota text; fn date;
begin
  if not exists (select 1 from public.academia_grupos where grupo_id = g and es_prueba) then raise exception 'El grupo no es de prueba'; end if;
  if not exists (select 1 from public.atletas where id = alex and grupo_id = g) then raise exception 'Álex no está en PRUEBA'; end if;
  perform set_config('apolana.autor', 'datos ficticios PRUEBA (mig 497)', true);

  -- Sesiones comparables
  for i in 1..3 loop
    d   := (array['2026-10-07','2026-10-14','2026-10-21'])[i]::date;
    sid := (array['a4a10000-0000-4000-8000-000000000007','a4a10000-0000-4000-8000-000000000014','a4a10000-0000-4000-8000-000000000021'])[i]::uuid;
    f1  := 'a4a1f100-0000-4000-8000-0000000000' || lpad(extract(day from d)::text, 2, '0');
    f2  := 'a4a1f200-0000-4000-8000-0000000000' || lpad(extract(day from d)::text, 2, '0');
    insert into public.sesiones (id, grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_meta, tipo, deporte, papel_dia, publicada, bloques)
    values (sid, g, array[alex], d, case when i = 2 then 'Ritmo 400 (2×250+150)' else '2×(250+150)' end, 'Ritmo 400', 'alta', 'alta', 'pista', 'atletismo', 'carga', true,
      jsonb_build_array(
        jsonb_build_object('etiqueta','Calentamiento','lista','guion','solo_marcar',true,'filas', jsonb_build_array(jsonb_build_object('id', 'a4a1f000-0000-4000-8000-0000000000' || lpad(extract(day from d)::text, 2, '0'), 'ejercicio','15′ CC + técnica'))),
        jsonb_build_object('etiqueta','Parte principal','lista','guion','solo_marcar',true,'filas', jsonb_build_array(
          jsonb_build_object('id', f1, 'ejercicio','Bloque 1/2: 250 (34-35″) + 150 (19,5-20,5″) // 4′ y 8′ Z'),
          jsonb_build_object('id', f2, 'ejercicio','Bloque 2/2: 250 (34-35″) + 150 (19,5-20,5″) // 4′ y 8′ Z')))))
    on conflict (id) do nothing;
    t := case i
      when 1 then jsonb_build_object(f1, jsonb_build_object('medida','tiempo','series', jsonb_build_array(jsonb_build_object('tiempo','34,8','hecha',true), jsonb_build_object('tiempo','20,4','hecha',true))),
                                     f2, jsonb_build_object('medida','tiempo','series', jsonb_build_array(jsonb_build_object('tiempo','35,1','hecha',true), jsonb_build_object('tiempo','20,6','hecha',true))))
      when 2 then jsonb_build_object(f1, jsonb_build_object('medida','tiempo','series', jsonb_build_array(jsonb_build_object('tiempo','34,6','hecha',true), jsonb_build_object('tiempo','20,3','hecha',true))),
                                     f2, jsonb_build_object('medida','tiempo','series', jsonb_build_array(jsonb_build_object('tiempo','34,9','hecha',true), jsonb_build_object('tiempo','20,6','hecha',true))))
      else        jsonb_build_object(f1, jsonb_build_object('medida','tiempo','series', jsonb_build_array(jsonb_build_object('tiempo','34,4','hecha',true), jsonb_build_object('tiempo','20,2','hecha',true))),
                                     f2, jsonb_build_object('medida','tiempo','series', jsonb_build_array(jsonb_build_object('tiempo','34,9','hecha',true), jsonb_build_object('tiempo','20,5','hecha',true)))) end;
    rpe  := 8;
    nota := (array['Piernas cargadas del sábado','Bien','Bien, el segundo 250 costó'])[i];
    if not exists (select 1 from public.registros_sesion where sesion_id = sid and atleta_id = alex) then
      insert into public.registros_sesion (sesion_id, atleta_id, estado, rpe, tiempos_reales, notas_atleta, superficie, version_garantia, version_vista, created_at)
      values (sid, alex, 'completo', rpe, t, nota, 'pista', 'vigente_al_enviar', 1, (d + time '20:30')::timestamptz);
    end if;
  end loop;
  -- El 21, el entrenador también cronometró (manual) los dos 250.
  if not exists (select 1 from public.academia_toma_datos where sesion_id = 'a4a10000-0000-4000-8000-000000000021') then
    insert into public.academia_toma_datos (sesion_id, sesion_version, atleta_id, fila_id, alcance, serie, repeticion, magnitud, valor_texto, valor_num, unidad, metodo, estado, autor_perfil_id)
    values ('a4a10000-0000-4000-8000-000000000021', 1, alex, 'a4a1f100-0000-4000-8000-000000000021', 'repeticion', null, 1, 'tiempo', '34,5', 34.5, 's', 'manual', 'realizado', yo),
           ('a4a10000-0000-4000-8000-000000000021', 1, alex, 'a4a1f200-0000-4000-8000-000000000021', 'repeticion', null, 1, 'tiempo', '35,0', 35.0, 's', 'manual', 'realizado', yo);
  end if;

  -- Marcas de 200 m de la temporada (ficticias)
  select fecha_nacimiento into fn from public.atletas where id = alex;
  insert into public.marcas_atleta (atleta_id, prueba, prueba_id, tiempo_segundos, tiempo_display, unidad, fecha, sede, contexto, condiciones, metodo, viento, oficial, ronda,
                                    categoria, categoria_origen, huella, creado_por)
  select alex, '200 m lisos', p200, x.v, x.txt, 's', x.f, x.sede, x.ctx, '{}'::jsonb, x.met, x.vi, x.of, x.ro,
         public.categoria_federativa(fn, x.f)->>'categoria', 'calculada', x.h, yo
    from (values (22.95, '22,95', '2026-06-14'::date, 'Pista ficticia (PRUEBA)', 'competicion', 'electronico_competicion', 0.4,  true,  'final', 'prueba-analisis-1'),
                 (22.78, '22,78', '2026-07-12'::date, 'Pista ficticia (PRUEBA)', 'competicion', 'electronico_competicion', -0.6, true,  'final', 'prueba-analisis-2'),
                 (22.84, '22,84', '2026-09-20'::date, 'Pista ficticia (PRUEBA)', 'competicion', 'electronico_competicion', 2.6,  true,  'final', 'prueba-analisis-3'),
                 (22.1,  '22,1',  '2026-10-03'::date, 'Pista ficticia (PRUEBA)', 'entreno',     'manual',                  null, false, null,    'prueba-analisis-4')) x(v, txt, f, sede, ctx, met, vi, of, ro, h)
   where not exists (select 1 from public.marcas_atleta m where m.huella = x.h);

  -- Modelo de parciales: propuesta de ChatGPT, sin aprobar (lo aprueba Andrés)
  insert into public.objetivo_parciales (atleta_id, objetivo_id, tiempo_total_s, tramos, fundamento, limitaciones, origen, estado, autor_perfil_id)
  values (alex, obj, 22.20,
          '[{"desde_m":0,"hasta_m":50,"tiempo_s":5.95},{"desde_m":50,"hasta_m":100,"tiempo_s":5.35},{"desde_m":100,"hasta_m":150,"tiempo_s":5.40},{"desde_m":150,"hasta_m":200,"tiempo_s":5.50}]',
          'PROPUESTA FICTICIA (PRUEBA): reparto en 4 tramos de 50 m para 22,20, con la salida más lenta y el tercer tramo cerca del segundo.',
          'Sin fuente externa ni datos del atleta: sirve solo para probar la pantalla. No es un objetivo acordado.', 'chatgpt', 'propuesta', yo)
  on conflict (objetivo_id) do nothing;

  -- Decisiones del entrenador (ficticias)
  insert into public.atleta_decisiones (id, atleta_id, ambito, decision, motivo, inicio, revision, estado, origen, autor_perfil_id)
  values ('a4a1dec0-0000-4000-8000-000000000001', alex, 'planificacion', 'Mantener 2 sesiones de aceleración por semana hasta el control del 5 dic',
          'Priorizar la salida antes del primer control (ficticio, PRUEBA)', '2026-10-12', '2026-11-12', 'vigente', 'entrenador', yo),
         ('a4a1dec0-0000-4000-8000-000000000002', alex, 'planificacion', 'Sin clavos en series de más de 150 m',
          'Probar las series largas con zapatillas antes de pista cubierta (ficticio, PRUEBA)', '2026-10-01', '2026-10-26', 'vigente', 'entrenador', yo)
  on conflict (id) do nothing;
end $$;
