-- Datos de demostración: un grupo, el atleta de prueba dentro, y una sesión publicada de hoy.
-- Idempotente (ids fijos). Solo para probar cómo se ve el entreno en la zona del atleta.

insert into public.grupos (id, nombre, seccion, horario, descripcion, activo)
values ('11111111-1111-4111-8111-111111111111', 'Velocidad · Sub-20', 'competicion',
        'Mar y Jue 18:00-20:00 · Estadio Joaquín Villar', 'Grupo de velocidad, salidas y series cortas', true)
on conflict (id) do nothing;

update public.atletas set grupo_id = '11111111-1111-4111-8111-111111111111'
where nombre = 'prueba 2';

insert into public.sesiones (id, fecha, dia_semana, tipo, rol, titulo, nota_razonamiento, bloques, publicada, grupo_id, generado_por_ia)
values (
  '22222222-2222-4222-8222-222222222222',
  '2026-07-31', 'viernes', 'pista', 'calidad_fuerte',
  'Velocidad · salidas y series cortas',
  'Sesión de calidad: prioriza la técnica de salida y la velocidad máxima. Descansos completos para mantener la calidad en cada serie.',
  '[
    {"etiqueta":"Calentamiento","filas":[
      {"ejercicio":"Carrera continua suave","detalle":"10 min"},
      {"ejercicio":"Drills de frecuencia","series":"2","distancia":"30 m"},
      {"ejercicio":"Skipping bajo","series":"2","distancia":"20 m"}
    ]},
    {"etiqueta":"Parte principal","filas":[
      {"ejercicio":"Salidas desde tacos","series":"5","distancia":"20 m","descanso":"2 min"},
      {"ejercicio":"Voladoras","series":"4","distancia":"60 m","ritmo":"90-95%","descanso":"4 min"},
      {"ejercicio":"Series de potencia lactácida","series":"3","distancia":"120 m","ritmo":"fuerte","descanso":"6 min"}
    ]},
    {"etiqueta":"Vuelta a la calma","filas":[
      {"ejercicio":"Trote suave","detalle":"8 min"},
      {"ejercicio":"Estiramientos","detalle":"6 min"}
    ]}
  ]'::jsonb,
  true, '11111111-1111-4111-8111-111111111111', false
)
on conflict (id) do update set bloques = excluded.bloques, fecha = excluded.fecha,
  titulo = excluded.titulo, nota_razonamiento = excluded.nota_razonamiento, publicada = true;
