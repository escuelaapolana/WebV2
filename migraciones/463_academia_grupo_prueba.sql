-- 463 · Academia · GRUPO DE PRUEBA con atletas FICTICIOS (para validar Semana y Hoy,
-- y para la primera prueba de conexión con ChatGPT). Sin datos reales ni de salud real.
-- ---------------------------------------------------------------------------
-- · Grupo «Academia AC98 · PRUEBA», DESACTIVADO (no sale en la web pública), con el
--   mismo entrenador que Academia. Marcado es_prueba en academia_grupos.
-- · 6 atletas ficticios («… Ficticio (prueba)»), sin cuenta ni datos personales.
-- · Semana del 26-oct al 1-nov-2026 con los casos de validación: doble sesión,
--   ausencia que conserva lo previsto, ejecución parcial, feedback nuevo y revisado,
--   sesión cambiada tras responder, publicada con revisión pendiente, grupo de trabajo
--   compartido con ritmos individuales, borradores, descansos y día sin planificar.
-- Para borrarlo todo: delete from grupos where nombre = 'Academia AC98 · PRUEBA'
-- (antes, sus registros y atletas; ver el final de este fichero).
-- ---------------------------------------------------------------------------
begin;
select set_config('apolana.autor', 'datos de prueba (mig 463)', true);

create or replace function pg_temp.fila(t text) returns jsonb language sql as $$ select jsonb_build_object('ejercicio', t) $$;
create or replace function pg_temp.bloques(cal text, pp text[]) returns jsonb language sql as $$
  select jsonb_build_array(
    jsonb_build_object('etiqueta','Calentamiento','lista','guion','solo_marcar',true,'filas', jsonb_build_array(pg_temp.fila(cal))),
    jsonb_build_object('etiqueta','Parte principal','lista','guion','solo_marcar',true,
      'filas', (select jsonb_agg(pg_temp.fila(x)) from unnest(pp) x)))
$$;

do $$
declare
  g uuid; coach uuid := 'c5c2958a-2ba0-4f8f-aaaf-8a796bd22eec';
  alex uuid; bruno uuid; cesar uuid; dani uuid; elias uuid; hugo uuid;
  s uuid; s2 uuid; gt uuid; v int;
  ritmo jsonb;
begin
  insert into public.grupos (nombre, seccion, entrenador_id, activo, descripcion)
  values ('Academia AC98 · PRUEBA', 'competicion', coach, false, 'Grupo ficticio para probar el mundo Academia y la conexión con ChatGPT. No es real.')
  returning id into g;
  insert into public.academia_grupos (grupo_id, es_prueba) values (g, true);

  insert into public.atletas (nombre, apellidos, grupo_id, entrenador_id, estado, pruebas_principales, origen)
  values ('Álex', 'Ficticio (prueba)', g, coach, 'activo', array['100','200'], 'prueba') returning id into alex;
  insert into public.atletas (nombre, apellidos, grupo_id, entrenador_id, estado, pruebas_principales, origen)
  values ('Bruno', 'Ficticio (prueba)', g, coach, 'activo', array['200','400'], 'prueba') returning id into bruno;
  insert into public.atletas (nombre, apellidos, grupo_id, entrenador_id, estado, pruebas_principales, origen)
  values ('César', 'Ficticio (prueba)', g, coach, 'activo', array['110 vallas'], 'prueba') returning id into cesar;
  insert into public.atletas (nombre, apellidos, grupo_id, entrenador_id, estado, pruebas_principales, origen)
  values ('Dani', 'Ficticio (prueba)', g, coach, 'activo', array['100','200'], 'prueba') returning id into dani;
  insert into public.atletas (nombre, apellidos, grupo_id, entrenador_id, estado, pruebas_principales, origen)
  values ('Elías', 'Ficticio (prueba)', g, coach, 'activo', array['400 vallas'], 'prueba') returning id into elias;
  insert into public.atletas (nombre, apellidos, grupo_id, entrenador_id, estado, pruebas_principales, origen)
  values ('Hugo', 'Ficticio (prueba)', g, coach, 'activo', array['800','1500'], 'prueba') returning id into hugo;

  -- ===== Lunes 26: salidas + trineo; Dani AUSENTE (estudios) pero la sesión se conserva
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_neuro, tipo, deporte, papel_dia, publicada, bloques)
  select g, array[a], '2026-10-26', 'Salidas + trineo + 30 + 40', 'Aceleración', 'alta', 'alta', 'pista', 'atletismo', 'carga', true,
         pg_temp.bloques('10′ CC + movilidad + técnica', array['2x20 m salidas // 3′ Z','Bloque 1/3 a 3/3: 20 m trineo + 20 m libre // 90″ dentro y 3′ entre bloques Z','2x30 m al 90-95% // 3-4′ C'])
    from unnest(array[alex, bruno, cesar, dani, elias]) a;
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_meta, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[hugo], '2026-10-26', 'Arrastres + 4×150 + 25′ CC', 'Aceleración + aeróbico', 'media', 'media', 'pista', 'atletismo', 'carga', true,
          pg_temp.bloques('10′ CC', array['3x(30 m arrastre + 60 m libre) // 2′ y 4′ Z','4x150 m al 85-90% // 4′ Z','25′ CC cómoda RPE 3-4 Z']));
  select id into s from public.sesiones where atletas_ids = array[dani] and fecha = '2026-10-26';
  insert into public.ausencias (atleta_id, fecha, sesion_id, motivo, motivo_tipo, nota, avisado_por_nombre)
  values (dani, '2026-10-26', s, 'Examen', 'estudios', 'Avisó el día anterior', 'Dani (ficticio)');

  -- ===== Martes 27: fuerza; Hugo DOBLE (mañana + tarde); Elías descansa
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_neuro, tipo, deporte, papel_dia, publicada, bloques)
  select g, array[a], '2026-10-27', 'Fuerza-potencia', 'Fuerza-potencia', 'media', 'alta', 'pista', 'atletismo', 'carga', true,
         pg_temp.bloques('8′ movilidad + aproximación', array['Media cargada 3x3 al 60-65% RM // 2′','Media sentadilla + saltos al cajón 3x(3+2) al 75-80% RM // 3′','Transferencia: 2x60 al 80% // 3′ Z'])
    from unnest(array[alex, bruno, cesar, dani]) a;
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, clase_dia, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[elias], '2026-10-27', 'Descanso', 'descanso', 'pista', 'atletismo', 'descanso', true,
          '[{"etiqueta":"Sesión","lista":"guion","solo_marcar":true,"filas":[{"ejercicio":"Descanso"}]}]');
  insert into public.sesiones (grupo_id, atletas_ids, fecha, hora, momento, titulo, objetivo, exigencia, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[hugo], '2026-10-27', '09:00', 'manana', '45′ CC', 'Aeróbico', 'baja', 'continuo', 'atletismo', 'recuperacion', true,
          '[{"etiqueta":"Parte principal","lista":"guion","solo_marcar":true,"filas":[{"ejercicio":"45′ CC a 4:55-5:15/km Z"}]}]');
  insert into public.sesiones (grupo_id, atletas_ids, fecha, hora, momento, titulo, objetivo, exigencia, exigencia_neuro, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[hugo], '2026-10-27', '18:00', 'tarde', 'Fuerza-potencia', 'Fuerza-potencia', 'media', 'media', 'pista', 'atletismo', 'carga', true,
          pg_temp.bloques('8′ movilidad', array['Media cargada 3x3 al 60-65% RM // 2′','RDL unilateral + salto 2x(5+2) // 2′','3x60 al 80% // 3′ Z']));

  -- ===== Miércoles 28: «Ritmo 400» compartido con ritmos individuales; Bruno y Hugo aparte
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_neuro, exigencia_meta, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[alex], '2026-10-28', '2×(250+150)', 'Ritmo 400', 'alta', 'media', 'alta', 'pista', 'atletismo', 'carga', true,
          pg_temp.bloques('15′ CC + técnica', array['Bloque 1/2: 250 (34-35″) + 150 (19,5-20,5″) // 4′ y 8′ Z','Bloque 2/2: 250 (34-35″) + 150 (19,5-20,5″) // 4′ y 8′ Z']));
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_neuro, exigencia_meta, tipo, deporte, papel_dia, publicada, bloques)
  select g, array[a], '2026-10-28', '2×(250+150)', 'Ritmo 400', 'alta', 'media', 'alta', 'pista', 'atletismo', 'carga', true,
         pg_temp.bloques('15′ CC + técnica', array['Bloque 1/2: 250 (37-38″) + 150 (21,5-22,5″) // 4′ y 8′ Z','Bloque 2/2: 250 (37-38″) + 150 (21,5-22,5″) // 4′ y 8′ Z'])
    from unnest(array[cesar, dani, elias]) a;
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_meta, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[bruno], '2026-10-28', '2×(200+150+100)', 'Resistencia a la velocidad', 'alta', 'alta', 'pista', 'atletismo', 'carga', true,
          pg_temp.bloques('15′ CC + técnica', array['Bloque 1/2: 200 + 150 + 100 // 3′ y 8′ Z','Bloque 2/2: 200 + 150 + 100 // 3′ y 8′ Z']));
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_meta, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[hugo], '2026-10-28', '5×1000', 'Intervalos', 'alta', 'alta', 'pista', 'atletismo', 'carga', true,
          pg_temp.bloques('15′ CC', array['5x1000 en 3:25-3:30 // 2′ trote suave Z','10′ CC suave Z']));
  insert into public.grupos_trabajo (grupo_id, fecha, nombre, orden, nota, creado_por)
  values (g, '2026-10-28', 'Ritmo 400', 1, 'Mismo trabajo; tiempos individuales', coach) returning id into gt;
  insert into public.grupos_trabajo_miembros (grupo_trabajo_id, sesion_id, orden)
  select gt, se.id, row_number() over () from public.sesiones se
   where se.grupo_id = g and se.fecha = '2026-10-28' and se.objetivo = 'Ritmo 400';

  -- ===== Jueves 29: publicadas; César con REVISIÓN PENDIENTE; Hugo doble
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, tipo, deporte, papel_dia, publicada, bloques)
  select g, array[a], '2026-10-29', 'Preventivo + 15′ CC', 'Preventivos', 'baja', 'pista', 'atletismo', 'recuperacion', true,
         pg_temp.bloques('Movilidad', array['Core y preventivos de isquio','15′ CC suave Z'])
    from unnest(array[alex, bruno, dani, elias]) a;
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_neuro, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[cesar], '2026-10-29', 'Vallas', 'Técnica de vallas', 'media', 'media', 'pista', 'atletismo', 'carga', true,
          pg_temp.bloques('10′ CC + movilidad de vallas', array['2x primera valla // 3′ Z','2x dos vallas // 4′ Z','2x tres vallas // 5′ C']))
  returning id, version into s2, v;
  insert into public.sesiones (grupo_id, atletas_ids, fecha, hora, momento, titulo, objetivo, exigencia, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[hugo], '2026-10-29', '09:00', 'manana', '40′ CC', 'Aeróbico', 'baja', 'continuo', 'atletismo', 'recuperacion', true,
          '[{"etiqueta":"Parte principal","lista":"guion","solo_marcar":true,"filas":[{"ejercicio":"40′ CC Z"}]}]');
  insert into public.sesiones (grupo_id, atletas_ids, fecha, hora, momento, titulo, objetivo, exigencia, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[hugo], '2026-10-29', '18:00', 'tarde', 'GYM tren superior', 'Fuerza complementaria', 'baja', 'pista', 'atletismo', 'carga', true,
          '[{"etiqueta":"Parte principal","lista":"guion","solo_marcar":true,"filas":[{"ejercicio":"Tren superior 3x8 RIR 3"}]}]');
  insert into public.sesiones_revisiones (sesion_id, version_base, propuesta, motivo, autor_perfil_id, via)
  values (s2, v, jsonb_build_object('bloques', pg_temp.bloques('10′ CC + movilidad de vallas',
           array['2x primera valla a 0,991 m, 1.ª a 13,72 m // 3′ Z','2x dos vallas a 0,991 m, separación 9,14 m // 4′ Z','2x tres vallas a 0,991 m, separación 9,14 m // 5′ C'])),
         'Concretar altura y separación de las vallas', coach, 'datos de prueba (mig 463)');

  -- ===== Viernes 30: BORRADORES (notación explícita de lanzados)
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_neuro, tipo, deporte, papel_dia, publicada, bloques)
  select g, array[a], '2026-10-30', 'Lanzados + 6×150', 'Velocidad + resistencia', 'alta', 'alta', 'pista', 'atletismo', 'carga', false,
         pg_temp.bloques('15′ CC + técnica', array['3x30 lanzados, entrada 20 m + tramo 30 m // 6′ C','6x150 al 85% // 3′ Z'])
    from unnest(array[alex, bruno, cesar, dani, elias]) a;
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, exigencia_meta, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[hugo], '2026-10-30', '3×(500+200)', 'Ritmo 800', 'alta', 'alta', 'pista', 'atletismo', 'carga', false,
          pg_temp.bloques('15′ CC', array['Bloque 1/3 a 3/3: 500 (1:28-1:30) + 200 (31-32″) // 2′ y 5′ Z']));

  -- ===== Sábado 31: descanso (Hugo rodaje en borrador). Domingo 1: sin planificar.
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, clase_dia, tipo, deporte, papel_dia, publicada, bloques)
  select g, array[a], '2026-10-31', 'Descanso', 'descanso', 'pista', 'atletismo', 'descanso', true,
         '[{"etiqueta":"Sesión","lista":"guion","solo_marcar":true,"filas":[{"ejercicio":"Descanso"}]}]'::jsonb
    from unnest(array[alex, bruno, cesar, dani, elias]) a;
  insert into public.sesiones (grupo_id, atletas_ids, fecha, titulo, objetivo, exigencia, tipo, deporte, papel_dia, publicada, bloques)
  values (g, array[hugo], '2026-10-31', '50–55′ CC', 'Aeróbico', 'baja', 'continuo', 'atletismo', 'recuperacion', false,
          '[{"etiqueta":"Parte principal","lista":"guion","solo_marcar":true,"filas":[{"ejercicio":"50-55′ CC Z"}]}]');

  -- ===== Registros (feedback ficticio, con la versión que veían)
  -- Lunes
  insert into public.registros_sesion (sesion_id, atleta_id, estado, rpe, duracion_min, notas_atleta, version_vista, created_at, revisado_en, revisado_por)
  select se.id, se.atletas_ids[1], 'completo', x.rpe, 80, x.nota, 1, '2026-10-26 20:30+01', '2026-10-27 09:00+01', coach
    from public.sesiones se join (values (alex, 7, 'Bien'), (bruno, 6, 'Bien, trineo pesado'), (hugo, 5, 'Cómodo')) x(a, rpe, nota)
      on se.atletas_ids[1] = x.a where se.grupo_id = g and se.fecha = '2026-10-26';
  insert into public.registros_sesion (sesion_id, atleta_id, estado, rpe, duracion_min, notas_atleta, version_vista, created_at)
  select se.id, elias, 'completo', 8, 85, 'Me costó la última salida', 1, '2026-10-26 21:10+01'
    from public.sesiones se where se.grupo_id = g and se.fecha = '2026-10-26' and se.atletas_ids[1] = elias;
  -- (César, lunes: SIN registro → «feedback pendiente»; Dani: ausente)
  -- (estado_manual = true: si no, el disparador recalcula el estado y lo deja en «completo»)
  -- Martes: Álex feedback NUEVO; Bruno revisado y luego CAMBIA el plan; Dani PARCIAL con molestia; Hugo doble hecha
  insert into public.registros_sesion (sesion_id, atleta_id, estado, rpe, duracion_min, notas_atleta, version_vista, created_at)
  select se.id, alex, 'completo', 7, 70, 'La media cargada muy bien', 1, '2026-10-27 20:05+01'
    from public.sesiones se where se.grupo_id = g and se.fecha = '2026-10-27' and se.atletas_ids[1] = alex;
  insert into public.registros_sesion (sesion_id, atleta_id, estado, rpe, duracion_min, notas_atleta, version_vista, created_at, revisado_en, revisado_por)
  select se.id, bruno, 'completo', 6, 65, 'Bien', 1, '2026-10-27 19:40+01', '2026-10-28 08:30+01', coach
    from public.sesiones se where se.grupo_id = g and se.fecha = '2026-10-27' and se.atletas_ids[1] = bruno;
  insert into public.registros_sesion (sesion_id, atleta_id, estado, estado_manual, completado_pct, rpe, duracion_min, molestia_sesion, molestia_localizacion, notas_atleta, version_vista, created_at)
  select se.id, dani, 'a_medias', true, 70, 7, 50, 4, 'soleo_gemelo', 'Paré la transferencia por el gemelo', 1, '2026-10-27 20:40+01'
    from public.sesiones se where se.grupo_id = g and se.fecha = '2026-10-27' and se.atletas_ids[1] = dani;
  insert into public.registros_sesion (sesion_id, atleta_id, estado, rpe, duracion_min, version_vista, momento, created_at, revisado_en, revisado_por)
  select se.id, hugo, 'completo', case when se.momento = 'manana' then 3 else 6 end, case when se.momento = 'manana' then 45 else 60 end, 1, se.momento,
         '2026-10-27 21:00+01', '2026-10-28 08:30+01', coach
    from public.sesiones se where se.grupo_id = g and se.fecha = '2026-10-27' and se.atletas_ids[1] = hugo;
  -- El entrenador cambia la sesión del martes de Bruno DESPUÉS de que respondiera (respondió la versión 1)
  update public.sesiones
     set bloques = pg_temp.bloques('8′ movilidad + aproximación', array['Cargada completa 4x3 al 60-65% RM // 2′','Media sentadilla + saltos al cajón 3x(3+2) al 75-80% RM // 3′','Transferencia: 2x60 al 80% // 3′ Z'])
   where grupo_id = g and fecha = '2026-10-27' and atletas_ids[1] = bruno;
end $$;

commit;

-- Para borrar el grupo de prueba entero (cuando ya no haga falta):
--   begin;
--   select set_config('apolana.borrado_definitivo','1',true);
--   delete from registros_sesion where atleta_id in (select id from atletas where grupo_id = (select id from grupos where nombre='Academia AC98 · PRUEBA'));
--   delete from sesiones where grupo_id = (select id from grupos where nombre='Academia AC98 · PRUEBA');
--   delete from ausencias where atleta_id in (select id from atletas where grupo_id = (select id from grupos where nombre='Academia AC98 · PRUEBA'));
--   delete from atletas where grupo_id = (select id from grupos where nombre='Academia AC98 · PRUEBA');
--   delete from grupos where nombre = 'Academia AC98 · PRUEBA';
--   commit;
