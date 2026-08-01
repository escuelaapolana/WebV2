-- =====================================================================
-- 903_datos_demo_equilibrado.sql  ·  EQUILIBRAR LOS DATOS DE DEMOSTRACIÓN
-- =====================================================================
-- Las secciones pequeñas se veían vacías al enseñar la web. Este archivo
-- las iguala con el resto:
--
--   · Escuela de natación: de 4 a 14 alumnos y 7 sesiones publicadas.
--   · Triatlón: de 4 a 16 atletas y 9 sesiones (agua, bici y pista).
--   · Natación (Iniciación, Tecnificación, Máster y Aguas abiertas):
--     cada grupo pasa de 3 sesiones a unas 10 en las tres semanas
--     visibles, para que ninguno quede por debajo de Perfeccionamiento.
--   · Montaña: de 9 a 14 atletas y cinco sesiones más.
--   · El Cubo NO se toca: son clases sueltas con bono, a las que van
--     atletas de todas las secciones (63 personas distintas reservan).
--     Los 3 atletas del grupo «El Cubo» son los que SOLO hacen El Cubo,
--     así que el número correcto es ese y no hay nada que inflar.
--
-- Todo lleva identificadores nuevos con el prefijo «dddddddd-» en tramos
-- libres, para que 901_borrar_datos_demo.sql lo quite todo de una vez:
--   dddddddd-0041-…  atletas nuevos
--   dddddddd-0042-…  sesiones nuevas
--   dddddddd-0043-…  marcas nuevas
--   dddddddd-0044-…  pagos nuevos
--
-- Es idempotente: se puede lanzar las veces que haga falta.
--
-- Cómo se lanza:  bash .secrets/psql.sh -f migraciones/903_datos_demo_equilibrado.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. ATLETAS NUEVOS (27)
-- ---------------------------------------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
values
  -- ---- Escuela de natación (10 niños) ----
  ('dddddddd-0041-4000-8000-000000000001','Vega','Bellver Micó','Vega B.','2018-03-12','Escuela iniciación','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres'], null, false,'Empezó en enero. Ya mete la cabeza sin tabla.'),
  ('dddddddd-0041-4000-8000-000000000002','Hugo','Talens Ripoll','Hugo T.','2018-11-05','Escuela iniciación','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres'], null, false, null),
  ('dddddddd-0041-4000-8000-000000000003','Emma','Ferrándiz Soler','Emma','2019-02-21','Escuela iniciación','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres'], null, false,'La más pequeña del grupo. Siempre con churro o tabla.'),
  ('dddddddd-0041-4000-8000-000000000004','Álvaro','Sempere Gadea','Álvaro S.','2017-06-18','Sub-12','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres','50 m espalda'], null, false, null),
  ('dddddddd-0041-4000-8000-000000000005','Daniela','Camps Vidal','Dani C.','2017-10-30','Sub-12','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres'], null, false, null),
  ('dddddddd-0041-4000-8000-000000000006','Iker','Ruiz Belda','Iker','2016-04-09','Sub-12','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres','50 m espalda'], null, false,'Nada bien pero se cansa pronto. Trabajar el aguante.'),
  ('dddddddd-0041-4000-8000-000000000007','Julia','Navarro Pastor','Julia N.','2016-09-25','Sub-12','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres'], null, false, null),
  ('dddddddd-0041-4000-8000-000000000008','Marc','Estruch Llorca','Marc E.','2015-01-14','Sub-14','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres','50 m braza'], null, false,'Listo para pasar al grupo de Iniciación en septiembre.'),
  ('dddddddd-0041-4000-8000-000000000009','Alba','Ferri Molina','Alba','2015-08-07','Sub-14','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres','50 m espalda'], null, false, null),
  ('dddddddd-0041-4000-8000-000000000010','Pau','Sanchis Ortuño','Pau','2015-03-22','Sub-14','prueba','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres'], null, false,'Dos semanas de prueba. Viene del colegio con su hermana.'),
  -- ---- Triatlón (12 adultos) ----
  ('dddddddd-0041-4000-8000-000000000011','Iván','Bordera Sellés','Iván','1994-02-11','Absoluto','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['1.500 m libres','10.000 m'],'T-25060', true,'El más fuerte en bici. Le falta pie tras la transición.'),
  ('dddddddd-0041-4000-8000-000000000012','Marta','Gisbert Andreu','Marta G.','1998-07-26','Absoluto','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['800 m libres','10.000 m'],'T-25061', true, null),
  ('dddddddd-0041-4000-8000-000000000013','Fran','Llorca Server','Fran','1990-05-03','Máster','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['400 m libres','Media maratón'],'T-25062', false,'Viene del ciclismo. Corrige la brazada en cada sesión de agua.'),
  ('dddddddd-0041-4000-8000-000000000014','Patricia','Server Micó','Patri','2003-01-19','Sub-23','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['400 m libres','5.000 m'],'T-25063', true, null),
  ('dddddddd-0041-4000-8000-000000000015','Andreu','Mora Bataller','Andreu','1996-09-14','Absoluto','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['1.500 m libres','5.000 m'],'T-25064', true,'Nadador de origen. Tira del grupo en la calle 1.'),
  ('dddddddd-0041-4000-8000-000000000016','Silvia','Ortuño Cano','Silvia','1985-03-28','Máster','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['800 m libres','Media maratón'],'T-25065', false, null),
  ('dddddddd-0041-4000-8000-000000000017','Joan','Sempere Llinares','Joan','2002-11-07','Sub-23','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['1.500 m libres','10.000 m'],'T-25066', true,'Primera temporada en distancia olímpica.'),
  ('dddddddd-0041-4000-8000-000000000018','Elisa','Ramos Tortosa','Elisa','1991-06-22','Absoluto','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['400 m libres','10.000 m'],'T-25067', true, null),
  ('dddddddd-0041-4000-8000-000000000019','Óscar','Bernabeu Grau','Óscar','1978-10-16','Máster','lesionado','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['400 m libres','Media maratón'],'T-25068', false,'Tendinitis en el tibial. De momento solo agua y bici suave.'),
  ('dddddddd-0041-4000-8000-000000000020','Nuria','Alcaraz Puig','Nuria A.','1999-04-05','Absoluto','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['800 m libres','5.000 m'],'T-25069', true, null),
  ('dddddddd-0041-4000-8000-000000000021','Christian','Botella Serra','Christian','1993-12-09','Absoluto','prueba','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['400 m libres','10.000 m'], null, true,'Un mes de prueba. Viene del running.'),
  ('dddddddd-0041-4000-8000-000000000022','Amparo','Gil Tormo','Amparo','1982-08-30','Máster','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['800 m libres','Media maratón'],'T-25070', false, null),
  -- ---- Montaña (5 adultos) ----
  ('dddddddd-0041-4000-8000-000000000023','Salva','Doménech Alcaraz','Salva','1983-04-17','Máster','activo','dddddddd-0002-4000-8000-000000000011','dddddddd-0001-4000-8000-000000000009', array['Maratón'],'M-25023', false,'Objetivo: los 100 km del Camí dels Pelegrins.'),
  ('dddddddd-0041-4000-8000-000000000024','Carmen','Beneito Ríos','Carmen B.','1994-10-02','Absoluto','activo','dddddddd-0002-4000-8000-000000000011','dddddddd-0001-4000-8000-000000000009', array['Media maratón'],'M-25024', true, null),
  ('dddddddd-0041-4000-8000-000000000025','Jorge','Peidró Vilaplana','Jorge','1988-01-25','Absoluto','activo','dddddddd-0002-4000-8000-000000000011','dddddddd-0001-4000-8000-000000000009', array['Maratón','Media maratón'],'M-25025', true,'Muy bueno bajando, le cuesta el ritmo en llano.'),
  ('dddddddd-0041-4000-8000-000000000026','Rocío','Mataix Sanjuán','Rocío','1979-07-11','Máster','lesionado','dddddddd-0002-4000-8000-000000000011','dddddddd-0001-4000-8000-000000000009', array['Media maratón'],'M-25026', false,'Esguince de tobillo en la última salida. Vuelve en dos semanas.'),
  ('dddddddd-0041-4000-8000-000000000027','Ximo','Alberola Cortés','Ximo','1997-05-29','Absoluto','activo','dddddddd-0002-4000-8000-000000000011','dddddddd-0001-4000-8000-000000000009', array['Maratón','10.000 m'],'M-25027', true, null)
on conflict (id) do update set
  nombre = excluded.nombre, apellidos = excluded.apellidos, nombre_corto = excluded.nombre_corto,
  fecha_nacimiento = excluded.fecha_nacimiento, categoria = excluded.categoria, estado = excluded.estado,
  grupo_id = excluded.grupo_id, entrenador_id = excluded.entrenador_id,
  especialidades = excluded.especialidades, licencia = excluded.licencia,
  hace_gym = excluded.hace_gym, observaciones = excluded.observaciones;

-- Días de entreno, para que la ficha se vea completa.
update atletas set dias_entreno = array['martes','jueves']
  where grupo_id = 'dddddddd-0002-4000-8000-000000000009';
update atletas set dias_entreno = array['martes','jueves','sábado']
  where grupo_id = 'dddddddd-0002-4000-8000-000000000010';
update atletas set dias_entreno = array['miércoles','sábado']
  where grupo_id = 'dddddddd-0002-4000-8000-000000000011';

-- ---------------------------------------------------------------------
-- 2. SESIONES · ESCUELA DE NATACIÓN (7)
-- ---------------------------------------------------------------------
-- Martes y jueves de 17:30 a 18:15, con una mañana de sábado para las
-- familias. Tres calles por nivel: los mayores, los medianos y los peques.
-- Material de tabla y aletas, series de 25 m y mucha técnica, que es lo
-- que toca a estas edades.
insert into sesiones (id, grupo_id, fecha, dia_semana, tipo, rol, titulo, nota_razonamiento,
                      hora, lugar, calles, duracion_min, publicada, creado_por, bloques)
values
  ('dddddddd-0042-4000-8000-000000000001','dddddddd-0002-4000-8000-000000000009','2026-07-21','martes','natacion','secundaria',
   'Flotación, pies y crol con tabla',
   'Primer día de la semana. Se empieza siempre por la posición del cuerpo: si flotan bien, todo lo demás sale solo.',
   '17:30','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Entrada al agua y juego de burbujas","series":"1","distancia":"5 min","material":["Sin material"],"observaciones":"Mojarse la cara y la nuca antes de nada."},
       {"ejercicio":"Nado suave a elección","series":"2","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los mayores","atletas":["dddddddd-0003-4000-8000-000000000046","dddddddd-0041-4000-8000-000000000008","dddddddd-0041-4000-8000-000000000009","dddddddd-0041-4000-8000-000000000010"],"filas":[
       {"ejercicio":"Crol con tabla","series":"6","distancia":"25 m","descanso":"20 s","material":["Tabla"],"observaciones":"La mano entra delante del hombro, no cruzada."},
       {"ejercicio":"Pies de lado con aletas","series":"4","distancia":"25 m","descanso":"20 s","material":["Tabla","Aletas"]},
       {"ejercicio":"Crol completo","series":"4","distancia":"50 m","descanso":"30 s","material":["Sin material"],"observaciones":"Nacho V. y Marc E. abren la calle."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0003-4000-8000-000000000047","dddddddd-0003-4000-8000-000000000048","dddddddd-0041-4000-8000-000000000004","dddddddd-0041-4000-8000-000000000005","dddddddd-0041-4000-8000-000000000006","dddddddd-0041-4000-8000-000000000007"],"filas":[
       {"ejercicio":"Pies de crol con tabla","series":"8","distancia":"25 m","descanso":"25 s","material":["Tabla"],"observaciones":"Pierna larga, que salga el pie a la superficie."},
       {"ejercicio":"Espalda con tabla en la tripa","series":"4","distancia":"25 m","descanso":"25 s","material":["Tabla"],"observaciones":"Iker: sin sacar la cabeza, la oreja en el agua."},
       {"ejercicio":"Crol respirando cada tres","series":"4","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Los peques","atletas":["dddddddd-0003-4000-8000-000000000049","dddddddd-0041-4000-8000-000000000001","dddddddd-0041-4000-8000-000000000002","dddddddd-0041-4000-8000-000000000003"],"filas":[
       {"ejercicio":"Flotación de espaldas","series":"6","distancia":"10 m","descanso":"30 s","material":["Churro"],"observaciones":"Emma con churro hasta que se suelte sola."},
       {"ejercicio":"Pies con tabla y aletas","series":"6","distancia":"12 m","descanso":"30 s","material":["Tabla","Aletas"]},
       {"ejercicio":"Deslizamiento desde la pared","series":"6","distancia":"8 m","descanso":"30 s","material":["Sin material"],"observaciones":"Brazos estirados y la cabeza dentro."}]},
     {"etiqueta":"Juego final","matiz":"Todos","filas":[
       {"ejercicio":"Recoger aros del fondo","series":"1","distancia":"5 min","material":["Sin material"],"observaciones":"Se acaba siempre jugando."}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000002','dddddddd-0002-4000-8000-000000000009','2026-07-23','jueves','natacion','secundaria',
   'Respiración lateral y espalda',
   'La respiración es lo que más les cuesta. Se trabaja de lado, con tabla y con series muy cortas para que no se agobien.',
   '17:30','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave a elección","series":"1","distancia":"75 m","material":["Sin material"]},
       {"ejercicio":"Soltar el aire por la nariz en la pared","series":"10","distancia":"1 vez","descanso":"10 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los mayores","atletas":["dddddddd-0003-4000-8000-000000000046","dddddddd-0041-4000-8000-000000000008","dddddddd-0041-4000-8000-000000000009","dddddddd-0041-4000-8000-000000000010"],"filas":[
       {"ejercicio":"Crol respirando cada tres","series":"6","distancia":"25 m","descanso":"20 s","material":["Sin material"],"observaciones":"Alba, respira a los dos lados aunque cueste."},
       {"ejercicio":"Espalda continua","series":"4","distancia":"25 m","descanso":"25 s","material":["Sin material"]},
       {"ejercicio":"Crol suave","series":"2","distancia":"75 m","descanso":"40 s","material":["Sin material"],"observaciones":"Sin pararse en la pared."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0003-4000-8000-000000000047","dddddddd-0003-4000-8000-000000000048","dddddddd-0041-4000-8000-000000000004","dddddddd-0041-4000-8000-000000000005","dddddddd-0041-4000-8000-000000000006","dddddddd-0041-4000-8000-000000000007"],"filas":[
       {"ejercicio":"Pies de lado con tabla, tres brazadas y giro","series":"8","distancia":"25 m","descanso":"25 s","material":["Tabla"],"observaciones":"Julia N. y Dani C.: la oreja pegada al brazo."},
       {"ejercicio":"Espalda con aletas","series":"6","distancia":"25 m","descanso":"25 s","material":["Aletas"]},
       {"ejercicio":"Crol completo","series":"4","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Los peques","atletas":["dddddddd-0003-4000-8000-000000000049","dddddddd-0041-4000-8000-000000000001","dddddddd-0041-4000-8000-000000000002","dddddddd-0041-4000-8000-000000000003"],"filas":[
       {"ejercicio":"Burbujas y sacar la cara de lado","series":"10","distancia":"1 vez","descanso":"15 s","material":["Sin material"]},
       {"ejercicio":"Pies de espalda con churro","series":"6","distancia":"12 m","descanso":"30 s","material":["Churro"],"observaciones":"Hugo T. ya casi no lo necesita."},
       {"ejercicio":"Saltos desde el borde y volver a la escalera","series":"5","distancia":"1 vez","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Juego final","matiz":"Todos","filas":[
       {"ejercicio":"Carrera de tablas por parejas","series":"1","distancia":"5 min","material":["Tabla"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000003','dddddddd-0002-4000-8000-000000000009','2026-07-28','martes','natacion','secundaria',
   'Aletas y batido de pies',
   'Día de aletas. Con ellas notan lo que es avanzar de verdad y aguantan más metros sin darse cuenta.',
   '17:30','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave a elección","series":"1","distancia":"100 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los mayores","atletas":["dddddddd-0003-4000-8000-000000000046","dddddddd-0041-4000-8000-000000000008","dddddddd-0041-4000-8000-000000000009","dddddddd-0041-4000-8000-000000000010"],"filas":[
       {"ejercicio":"Pies de crol con aletas","series":"8","distancia":"25 m","descanso":"20 s","material":["Aletas","Tabla"]},
       {"ejercicio":"Ondulación de espaldas","series":"6","distancia":"15 m","descanso":"25 s","material":["Aletas"],"observaciones":"Como una ola, desde la tripa."},
       {"ejercicio":"Crol con aletas","series":"4","distancia":"50 m","descanso":"30 s","material":["Aletas"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0003-4000-8000-000000000047","dddddddd-0003-4000-8000-000000000048","dddddddd-0041-4000-8000-000000000004","dddddddd-0041-4000-8000-000000000005","dddddddd-0041-4000-8000-000000000006","dddddddd-0041-4000-8000-000000000007"],"filas":[
       {"ejercicio":"Pies con aletas y tabla","series":"8","distancia":"25 m","descanso":"25 s","material":["Aletas","Tabla"],"observaciones":"Sin doblar la rodilla, que la patada sale de la cadera."},
       {"ejercicio":"Crol con aletas","series":"6","distancia":"25 m","descanso":"25 s","material":["Aletas"]},
       {"ejercicio":"Espalda sin material","series":"4","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Los peques","atletas":["dddddddd-0003-4000-8000-000000000049","dddddddd-0041-4000-8000-000000000001","dddddddd-0041-4000-8000-000000000002","dddddddd-0041-4000-8000-000000000003"],"filas":[
       {"ejercicio":"Pies con aletas y tabla","series":"8","distancia":"12 m","descanso":"30 s","material":["Aletas","Tabla"],"observaciones":"Las aletas les dan mucha confianza. Aprovecharlo."},
       {"ejercicio":"Deslizar con aletas y cara dentro","series":"6","distancia":"10 m","descanso":"30 s","material":["Aletas"]},
       {"ejercicio":"Flotación de espaldas sin churro","series":"4","distancia":"10 s","descanso":"30 s","material":["Sin material"],"observaciones":"Vega B. ya aguanta sola diez segundos."}]},
     {"etiqueta":"Juego final","matiz":"Todos","filas":[
       {"ejercicio":"Relevo de aletas por calles","series":"1","distancia":"5 min","material":["Aletas"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000004','dddddddd-0002-4000-8000-000000000009','2026-07-30','jueves','natacion','secundaria',
   'Viraje sencillo y salto desde el borde',
   'Tocar la pared, girar y empujar. Sin voltereta todavía: primero que no pierdan el sitio ni traguen agua.',
   '17:30','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave a elección","series":"1","distancia":"100 m","material":["Sin material"]},
       {"ejercicio":"Pies con tabla","series":"4","distancia":"25 m","descanso":"20 s","material":["Tabla"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los mayores","atletas":["dddddddd-0003-4000-8000-000000000046","dddddddd-0041-4000-8000-000000000008","dddddddd-0041-4000-8000-000000000009","dddddddd-0041-4000-8000-000000000010"],"filas":[
       {"ejercicio":"Viraje de crol con toque de mano","series":"10","distancia":"15 m","descanso":"25 s","material":["Sin material"],"observaciones":"Se pierde más tiempo en la pared que nadando."},
       {"ejercicio":"Salida desde el borde y deslizar","series":"6","distancia":"10 m","descanso":"30 s","material":["Sin material"]},
       {"ejercicio":"Crol con viraje","series":"4","distancia":"50 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0003-4000-8000-000000000047","dddddddd-0003-4000-8000-000000000048","dddddddd-0041-4000-8000-000000000004","dddddddd-0041-4000-8000-000000000005","dddddddd-0041-4000-8000-000000000006","dddddddd-0041-4000-8000-000000000007"],"filas":[
       {"ejercicio":"Viraje sencillo, tocar y empujar","series":"10","distancia":"12 m","descanso":"25 s","material":["Sin material"],"observaciones":"Álvaro S.: empujar con los dos pies a la vez."},
       {"ejercicio":"Salto desde el borde de pie","series":"6","distancia":"1 vez","descanso":"30 s","material":["Sin material"]},
       {"ejercicio":"Crol de 50 con viraje","series":"4","distancia":"50 m","descanso":"35 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Los peques","atletas":["dddddddd-0003-4000-8000-000000000049","dddddddd-0041-4000-8000-000000000001","dddddddd-0041-4000-8000-000000000002","dddddddd-0041-4000-8000-000000000003"],"filas":[
       {"ejercicio":"Sentarse en el borde y dejarse caer","series":"8","distancia":"1 vez","descanso":"30 s","material":["Sin material"],"observaciones":"Emma con la monitora al lado."},
       {"ejercicio":"Empujar de la pared y deslizar","series":"8","distancia":"8 m","descanso":"25 s","material":["Sin material"]},
       {"ejercicio":"Pies con tabla","series":"6","distancia":"12 m","descanso":"30 s","material":["Tabla"]}]},
     {"etiqueta":"Juego final","matiz":"Todos","filas":[
       {"ejercicio":"El rey del viraje","series":"1","distancia":"5 min","material":["Sin material"],"observaciones":"Concurso por calles, gana quien menos se para."}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000005','dddddddd-0002-4000-8000-000000000009','2026-08-04','martes','natacion','secundaria',
   'Brazada de crol por partes',
   'Se corta la brazada en trozos: entrada, tirón y salida de la mano. Un trozo por serie, para que se fijen en uno solo.',
   '17:30','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave a elección","series":"1","distancia":"100 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los mayores","atletas":["dddddddd-0003-4000-8000-000000000046","dddddddd-0041-4000-8000-000000000008","dddddddd-0041-4000-8000-000000000009","dddddddd-0041-4000-8000-000000000010"],"filas":[
       {"ejercicio":"Puntos muertos","series":"6","distancia":"25 m","descanso":"20 s","material":["Sin material"],"observaciones":"Esperar a que la mano toque la otra antes de tirar."},
       {"ejercicio":"Arrastrar el pulgar por el costado","series":"6","distancia":"25 m","descanso":"20 s","material":["Sin material"]},
       {"ejercicio":"Crol completo","series":"4","distancia":"50 m","descanso":"30 s","material":["Sin material"],"observaciones":"Juntar los dos ejercicios anteriores."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0003-4000-8000-000000000047","dddddddd-0003-4000-8000-000000000048","dddddddd-0041-4000-8000-000000000004","dddddddd-0041-4000-8000-000000000005","dddddddd-0041-4000-8000-000000000006","dddddddd-0041-4000-8000-000000000007"],"filas":[
       {"ejercicio":"Un brazo solo, el otro estirado","series":"8","distancia":"25 m","descanso":"25 s","material":["Tabla"],"observaciones":"Cuatro con el derecho y cuatro con el izquierdo."},
       {"ejercicio":"Puntos muertos","series":"6","distancia":"25 m","descanso":"25 s","material":["Sin material"]},
       {"ejercicio":"Crol completo","series":"4","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Los peques","atletas":["dddddddd-0003-4000-8000-000000000049","dddddddd-0041-4000-8000-000000000001","dddddddd-0041-4000-8000-000000000002","dddddddd-0041-4000-8000-000000000003"],"filas":[
       {"ejercicio":"Brazos de crol andando por el poco fondo","series":"6","distancia":"10 m","descanso":"25 s","material":["Sin material"]},
       {"ejercicio":"Pies con tabla y cara dentro","series":"8","distancia":"12 m","descanso":"25 s","material":["Tabla"]},
       {"ejercicio":"Deslizar y dar tres brazadas","series":"6","distancia":"10 m","descanso":"30 s","material":["Sin material"],"observaciones":"Lola ya encadena tres sin levantar la cabeza."}]},
     {"etiqueta":"Juego final","matiz":"Todos","filas":[
       {"ejercicio":"Pesca de aros por equipos","series":"1","distancia":"5 min","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000006','dddddddd-0002-4000-8000-000000000009','2026-08-06','jueves','natacion','calidad_fuerte',
   'Control de 50 m y juegos',
   'Una vez al mes se cronometra un 50 suelto. No es competición: es para que vean que mejoran y para colocarlos por calles en septiembre.',
   '17:30','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave a elección","series":"1","distancia":"100 m","material":["Sin material"]},
       {"ejercicio":"Progresivos","series":"4","distancia":"25 m","descanso":"30 s","material":["Sin material"],"observaciones":"Empezar suave y acabar rápido."}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los mayores","atletas":["dddddddd-0003-4000-8000-000000000046","dddddddd-0041-4000-8000-000000000008","dddddddd-0041-4000-8000-000000000009","dddddddd-0041-4000-8000-000000000010"],"filas":[
       {"ejercicio":"Control de 50 libres","series":"1","distancia":"50 m","descanso":"5 min","material":["Sin material"],"ritmo":"máximo","observaciones":"Nacho V.: bajar de 39 s · Marc E.: bajar de 42 s · Alba: bajar de 44 s"},
       {"ejercicio":"Nado suave entre intentos","series":"1","distancia":"100 m","material":["Sin material"]},
       {"ejercicio":"Segundo intento de 50 libres","series":"1","distancia":"50 m","material":["Sin material"],"ritmo":"máximo","observaciones":"Se apunta el mejor de los dos."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0003-4000-8000-000000000047","dddddddd-0003-4000-8000-000000000048","dddddddd-0041-4000-8000-000000000004","dddddddd-0041-4000-8000-000000000005","dddddddd-0041-4000-8000-000000000006","dddddddd-0041-4000-8000-000000000007"],"filas":[
       {"ejercicio":"Control de 50 libres","series":"1","distancia":"50 m","descanso":"5 min","material":["Sin material"],"ritmo":"máximo","observaciones":"Iker: bajar de 47 s · Aitana: bajar de 48 s · Julia N.: bajar de 52 s"},
       {"ejercicio":"Control de 25 espalda","series":"1","distancia":"25 m","descanso":"3 min","material":["Sin material"],"ritmo":"máximo"},
       {"ejercicio":"Nado suave","series":"1","distancia":"100 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Los peques","atletas":["dddddddd-0003-4000-8000-000000000049","dddddddd-0041-4000-8000-000000000001","dddddddd-0041-4000-8000-000000000002","dddddddd-0041-4000-8000-000000000003"],"filas":[
       {"ejercicio":"Control de 12 m sin material","series":"2","distancia":"12 m","descanso":"2 min","material":["Sin material"],"observaciones":"Sin cronómetro delante, solo se anota si lo hacen entero."},
       {"ejercicio":"Pies con tabla","series":"6","distancia":"12 m","descanso":"30 s","material":["Tabla"]}]},
     {"etiqueta":"Juego final","matiz":"Todos","filas":[
       {"ejercicio":"Relevos mixtos por calles","series":"1","distancia":"8 min","material":["Tabla"],"observaciones":"Se mezclan las calles para que jueguen todos juntos."}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000007','dddddddd-0002-4000-8000-000000000009','2026-08-08','sábado','natacion','secundaria',
   'Mañana de familias en la piscina',
   'Sábado abierto: los padres se meten al agua con ellos. Se enseña lo aprendido en el trimestre y se acaba con juegos.',
   '10:00','Piscina cubierta municipal',3,60,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado libre con la familia","series":"1","distancia":"10 min","material":["Sin material"],"observaciones":"Los padres pueden entrar al agua con gorro."}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los mayores","atletas":["dddddddd-0003-4000-8000-000000000046","dddddddd-0041-4000-8000-000000000008","dddddddd-0041-4000-8000-000000000009","dddddddd-0041-4000-8000-000000000010"],"filas":[
       {"ejercicio":"Demostración de los cuatro estilos","series":"1","distancia":"4 x 25 m","descanso":"30 s","material":["Sin material"]},
       {"ejercicio":"Relevo 4 x 25 contra las familias","series":"1","distancia":"100 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0003-4000-8000-000000000047","dddddddd-0003-4000-8000-000000000048","dddddddd-0041-4000-8000-000000000004","dddddddd-0041-4000-8000-000000000005","dddddddd-0041-4000-8000-000000000006","dddddddd-0041-4000-8000-000000000007"],"filas":[
       {"ejercicio":"Crol y espalda de 25","series":"4","distancia":"25 m","descanso":"40 s","material":["Sin material"]},
       {"ejercicio":"Relevo con tabla","series":"1","distancia":"4 x 25 m","material":["Tabla"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Los peques","atletas":["dddddddd-0003-4000-8000-000000000049","dddddddd-0041-4000-8000-000000000001","dddddddd-0041-4000-8000-000000000002","dddddddd-0041-4000-8000-000000000003"],"filas":[
       {"ejercicio":"Deslizar hasta los brazos de papá o mamá","series":"8","distancia":"6 m","descanso":"30 s","material":["Sin material"]},
       {"ejercicio":"Pies con tabla y aletas","series":"6","distancia":"12 m","descanso":"30 s","material":["Tabla","Aletas"]}]},
     {"etiqueta":"Fiesta final","matiz":"Todos","filas":[
       {"ejercicio":"Castillo de churros y carrera de colchonetas","series":"1","distancia":"15 min","material":["Churro"],"observaciones":"Se entrega el diploma del trimestre al salir."}]}]'::jsonb)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 3. SESIONES · TRIATLÓN (9)
-- ---------------------------------------------------------------------
-- Las tres disciplinas repartidas por la semana: martes agua (por calles),
-- jueves o viernes pista, y sábado la salida larga de bici con transición.
insert into sesiones (id, grupo_id, fecha, dia_semana, tipo, rol, titulo, nota_razonamiento,
                      hora, lugar, calles, duracion_min, publicada, creado_por, bloques)
values
  ('dddddddd-0042-4000-8000-000000000008','dddddddd-0002-4000-8000-000000000010','2026-07-21','martes','natacion','secundaria',
   'Piscina por calles · técnica y series de 100',
   'El agua es donde más se pierde en un triatlón y donde menos se entrena. Un martes de cada dos se dedica a técnica pura.',
   '19:00','Piscina cubierta municipal',3,75,true,'dddddddd-0001-4000-8000-000000000008',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]},
       {"ejercicio":"Técnica de brazada","series":"8","distancia":"25 m","descanso":"15 s","material":["Sin material"],"observaciones":"Un largo de puntos muertos y otro de brazada completa."}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los rápidos en el agua","atletas":["dddddddd-0003-4000-8000-000000000050","dddddddd-0003-4000-8000-000000000052","dddddddd-0041-4000-8000-000000000011","dddddddd-0041-4000-8000-000000000015","dddddddd-0041-4000-8000-000000000017"],"filas":[
       {"ejercicio":"100 a ritmo de 1.500","series":"10","distancia":"100 m","descanso":"15 s","material":["Sin material"],"ritmo":"ritmo de 1.500","observaciones":"Andreu: 1:18-1:20 · Sergio P.: 1:20-1:22 · Guille: 1:22-1:24"},
       {"ejercicio":"Series con palas","series":"4","distancia":"100 m","descanso":"20 s","material":["Palas","Pull-buoy"]},
       {"ejercicio":"Nado suave","series":"1","distancia":"200 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Grupo medio","atletas":["dddddddd-0003-4000-8000-000000000051","dddddddd-0041-4000-8000-000000000012","dddddddd-0041-4000-8000-000000000014","dddddddd-0041-4000-8000-000000000018","dddddddd-0041-4000-8000-000000000020","dddddddd-0041-4000-8000-000000000021"],"filas":[
       {"ejercicio":"100 a ritmo de 1.500","series":"8","distancia":"100 m","descanso":"20 s","material":["Sin material"],"ritmo":"ritmo de 1.500","observaciones":"Patri: 1:28-1:30 · Ana: 1:32-1:34 · Christian: 1:38-1:42"},
       {"ejercicio":"Series con pull-buoy","series":"4","distancia":"100 m","descanso":"25 s","material":["Pull-buoy"],"observaciones":"Solo brazos, la cadera arriba."},
       {"ejercicio":"Nado suave","series":"1","distancia":"200 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Técnica y vuelta tras lesión","atletas":["dddddddd-0003-4000-8000-000000000053","dddddddd-0041-4000-8000-000000000013","dddddddd-0041-4000-8000-000000000016","dddddddd-0041-4000-8000-000000000019","dddddddd-0041-4000-8000-000000000022"],"filas":[
       {"ejercicio":"Puntos muertos y arrastre de pulgar","series":"10","distancia":"50 m","descanso":"20 s","material":["Sin material"],"observaciones":"Fran: la mano entra delante del hombro, no cruzada."},
       {"ejercicio":"Pies con tabla","series":"6","distancia":"50 m","descanso":"25 s","material":["Tabla","Aletas"],"observaciones":"Nerea y Óscar: sin forzar el tobillo."},
       {"ejercicio":"Nado continuo","series":"1","distancia":"400 m","material":["Sin material"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000009','dddddddd-0002-4000-8000-000000000010','2026-07-24','viernes','pista','calidad_fuerte',
   'Series de 1.000 en pista',
   'La sesión de calidad de la semana a pie. En pista se ve el ritmo real, que en asfalto se engaña uno solo.',
   '19:30','Pista municipal de atletismo',null,80,true,'dddddddd-0001-4000-8000-000000000008',
   '[{"etiqueta":"Parte inicial","filas":[
       {"ejercicio":"Trote suave","series":"1","distancia":"15 min","calzado":"Zapatillas","ritmo":"cómodo"},
       {"ejercicio":"Técnica de carrera","series":"3","distancia":"40 m","descanso":"vuelta andando","calzado":"Zapatillas","observaciones":"Skipping, talones y zancada saltada."},
       {"ejercicio":"Progresivos","series":"3","distancia":"80 m","descanso":"1 min 30 s","calzado":"Zapatillas"}]},
     {"etiqueta":"Parte principal","matiz":"Ritmo de 10 km","filas":[
       {"ejercicio":"1.000 m a ritmo","series":"5","distancia":"1.000 m","descanso":"2 min trotando","calzado":"Zapatillas","ritmo":"ritmo de 10 km","observaciones":"Iván: 3:35-3:38 · Andreu: 3:40-3:43 · Joan: 3:45-3:48 · Patri: 3:55-4:00 · Marta G.: 4:05-4:10"},
       {"ejercicio":"Últimos 200 m de cada serie","series":"5","distancia":"200 m","calzado":"Zapatillas","observaciones":"Acabar cada serie más rápido de lo que se empieza."}]},
     {"etiqueta":"Adaptado","matiz":"Vuelta tras lesión","filas":[
       {"ejercicio":"Rodaje suave en hierba","series":"1","distancia":"25 min","calzado":"Zapatillas","ritmo":"cómodo","observaciones":"Óscar: nada de series todavía. Si molesta, se para."}]},
     {"etiqueta":"Vuelta a la calma","filas":[
       {"ejercicio":"Trote suave","series":"1","distancia":"10 min","calzado":"Zapatillas"},
       {"ejercicio":"Estiramientos","series":"1","distancia":"8 min"}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000010','dddddddd-0002-4000-8000-000000000010','2026-07-25','sábado','continuo','calidad_fuerte',
   'Rodaje largo en bici con transición a pie',
   'La salida larga del sábado. Se sale en grupo, se rueda cómodo y al bajar de la bici se corren veinte minutos con las piernas cargadas.',
   '08:30','Salida desde el pabellón',null,180,true,'dddddddd-0001-4000-8000-000000000008',
   '[{"etiqueta":"Bici","filas":[
       {"ejercicio":"Continuo en llano","series":"1","distancia":"60 min en bici","ritmo":"cómodo","observaciones":"Cadencia alta, relevos cada dos kilómetros."},
       {"ejercicio":"Subida al puerto","series":"1","distancia":"25 min en bici","ritmo":"fuerte","observaciones":"Cada uno a su ritmo, se espera arriba."},
       {"ejercicio":"Vuelta suave","series":"1","distancia":"40 min en bici","ritmo":"suave"}]},
     {"etiqueta":"Transición","matiz":"Bici a pie","filas":[
       {"ejercicio":"Cambio de zapatillas y salir corriendo","series":"1","distancia":"1 vez","observaciones":"Cronometrada. Menos de 60 segundos desde que se baja."},
       {"ejercicio":"Carrera con piernas cargadas","series":"1","distancia":"20 min","calzado":"Zapatillas","ritmo":"ritmo de media","observaciones":"Iván: 4:05 min/km · Joan: 4:10 min/km · Ana: 4:50 min/km · Amparo: 5:10 min/km"}]},
     {"etiqueta":"Vuelta a la calma","filas":[
       {"ejercicio":"Estiramientos y reposición","series":"1","distancia":"10 min","observaciones":"Beber antes de subir al coche, que en agosto pega el sol."}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000011','dddddddd-0002-4000-8000-000000000010','2026-07-28','martes','natacion','calidad_fuerte',
   'Series de 200 y salidas en grupo',
   'Se nada apretado en un espacio pequeño, como en la boya de una prueba. Toca acostumbrarse al contacto sin ponerse nervioso.',
   '19:00','Piscina cubierta municipal',3,75,true,'dddddddd-0001-4000-8000-000000000008',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]},
       {"ejercicio":"Progresivos","series":"4","distancia":"50 m","descanso":"20 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los rápidos en el agua","atletas":["dddddddd-0003-4000-8000-000000000050","dddddddd-0003-4000-8000-000000000052","dddddddd-0041-4000-8000-000000000011","dddddddd-0041-4000-8000-000000000015","dddddddd-0041-4000-8000-000000000017"],"filas":[
       {"ejercicio":"200 a ritmo de prueba","series":"6","distancia":"200 m","descanso":"20 s","material":["Sin material"],"ritmo":"ritmo de 1.500","observaciones":"Andreu: 2:38-2:42 · Iván: 2:44-2:48 · Guille: 2:48-2:52"},
       {"ejercicio":"Salida en grupo desde la pared","series":"4","distancia":"50 m","descanso":"1 min","material":["Sin material"],"observaciones":"Salen los cinco a la vez, sin ceder la calle."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Grupo medio","atletas":["dddddddd-0003-4000-8000-000000000051","dddddddd-0041-4000-8000-000000000012","dddddddd-0041-4000-8000-000000000014","dddddddd-0041-4000-8000-000000000018","dddddddd-0041-4000-8000-000000000020","dddddddd-0041-4000-8000-000000000021"],"filas":[
       {"ejercicio":"200 a ritmo de prueba","series":"5","distancia":"200 m","descanso":"25 s","material":["Sin material"],"ritmo":"ritmo de 1.500","observaciones":"Patri: 3:00-3:04 · Nuria A.: 3:06-3:10 · Elisa: 3:12-3:16"},
       {"ejercicio":"Nadar pegado a los pies del de delante","series":"6","distancia":"50 m","descanso":"30 s","material":["Sin material"],"observaciones":"Se rota el primero cada serie."}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Técnica y vuelta tras lesión","atletas":["dddddddd-0003-4000-8000-000000000053","dddddddd-0041-4000-8000-000000000013","dddddddd-0041-4000-8000-000000000016","dddddddd-0041-4000-8000-000000000019","dddddddd-0041-4000-8000-000000000022"],"filas":[
       {"ejercicio":"200 cómodos","series":"4","distancia":"200 m","descanso":"30 s","material":["Sin material"],"ritmo":"cómodo","observaciones":"Fran: contar brazadas por largo, que no suban de 20."},
       {"ejercicio":"Nado con la cabeza fuera cada seis brazadas","series":"6","distancia":"50 m","descanso":"25 s","material":["Sin material"],"observaciones":"Es como se busca la boya en aguas abiertas."}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Espalda suave","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000012','dddddddd-0002-4000-8000-000000000010','2026-07-30','jueves','pista','calidad_fuerte',
   'Series de 400 a ritmo de 10 km',
   'Series más cortas que el viernes pasado, para tocar un ritmo algo más alegre sin dejar las piernas para el sábado.',
   '19:30','Pista municipal de atletismo',null,75,true,'dddddddd-0001-4000-8000-000000000008',
   '[{"etiqueta":"Parte inicial","filas":[
       {"ejercicio":"Trote suave","series":"1","distancia":"12 min","calzado":"Zapatillas"},
       {"ejercicio":"Movilidad de cadera y tobillo","series":"1","distancia":"6 min"},
       {"ejercicio":"Progresivos","series":"4","distancia":"60 m","descanso":"1 min","calzado":"Zapatillas"}]},
     {"etiqueta":"Parte principal","matiz":"Ritmo alegre","filas":[
       {"ejercicio":"400 m","series":"8","distancia":"400 m","descanso":"1 min 15 s","calzado":"Zapatillas","ritmo":"ritmo de 10 km","observaciones":"Iván: 1:22-1:24 · Joan: 1:26-1:28 · Nuria A.: 1:34-1:36 · Silvia: 1:44-1:48"},
       {"ejercicio":"Últimos 100 m de la octava","series":"1","distancia":"100 m","calzado":"Zapatillas","ritmo":"fuerte","observaciones":"Solo si se han hecho las siete anteriores clavadas."}]},
     {"etiqueta":"Adaptado","matiz":"Sin impacto","filas":[
       {"ejercicio":"Bici estática o elíptica","series":"1","distancia":"40 min","ritmo":"cómodo","observaciones":"Óscar y Nerea, mientras el resto hace pista."}]},
     {"etiqueta":"Vuelta a la calma","filas":[
       {"ejercicio":"Trote suave","series":"1","distancia":"8 min","calzado":"Zapatillas"},
       {"ejercicio":"Estiramientos de isquiotibial y gemelo","series":"1","distancia":"8 min"}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000013','dddddddd-0002-4000-8000-000000000010','2026-08-01','sábado','continuo','secundaria',
   'Bici por el puerto y veinte minutos de carrera',
   'Semana de más volumen. La bici es larga pero cómoda, y la carrera de después solo sirve para acostumbrar a las piernas.',
   '08:30','Salida desde el pabellón',null,195,true,'dddddddd-0001-4000-8000-000000000008',
   '[{"etiqueta":"Bici","filas":[
       {"ejercicio":"Aproximación en llano","series":"1","distancia":"45 min en bici","ritmo":"suave","observaciones":"En grupo cerrado, sin tirones."},
       {"ejercicio":"Puerto largo","series":"2","distancia":"20 min en bici","descanso":"bajada suave","ritmo":"ritmo de prueba","observaciones":"Iván tira arriba, Fran marca el ritmo abajo."},
       {"ejercicio":"Vuelta a casa","series":"1","distancia":"45 min en bici","ritmo":"suave"}]},
     {"etiqueta":"Transición","matiz":"Bici a pie","filas":[
       {"ejercicio":"Cambio rápido y salir corriendo","series":"1","distancia":"1 vez"},
       {"ejercicio":"Carrera cómoda","series":"1","distancia":"20 min","calzado":"Zapatillas","ritmo":"cómodo","observaciones":"Que nadie se pique. Es rodaje, no serie."}]},
     {"etiqueta":"Vuelta a la calma","filas":[
       {"ejercicio":"Estiramientos y almuerzo en el club","series":"1","distancia":"15 min","observaciones":"Se aprovecha para hablar del calendario de septiembre."}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000014','dddddddd-0002-4000-8000-000000000010','2026-08-04','martes','natacion','secundaria',
   'Simulacro de aguas abiertas en piscina',
   'Sin pared, sin corcheras de referencia y nadando pegados. Es la manera de ensayar la salida de una prueba sin ir a la playa.',
   '19:00','Piscina cubierta municipal',3,75,true,'dddddddd-0001-4000-8000-000000000008',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]},
       {"ejercicio":"Levantar la cabeza cada seis brazadas","series":"6","distancia":"50 m","descanso":"20 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los rápidos en el agua","atletas":["dddddddd-0003-4000-8000-000000000050","dddddddd-0003-4000-8000-000000000052","dddddddd-0041-4000-8000-000000000011","dddddddd-0041-4000-8000-000000000015","dddddddd-0041-4000-8000-000000000017"],"filas":[
       {"ejercicio":"Salida en bloque de cinco","series":"6","distancia":"100 m","descanso":"1 min","material":["Sin material"],"ritmo":"fuerte","observaciones":"Los primeros 25 al máximo, como en la salida real."},
       {"ejercicio":"Continuo pegados en fila","series":"1","distancia":"800 m","material":["Sin material"],"ritmo":"ritmo de prueba","observaciones":"Se rota el primero cada 100."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Grupo medio","atletas":["dddddddd-0003-4000-8000-000000000051","dddddddd-0041-4000-8000-000000000012","dddddddd-0041-4000-8000-000000000014","dddddddd-0041-4000-8000-000000000018","dddddddd-0041-4000-8000-000000000020","dddddddd-0041-4000-8000-000000000021"],"filas":[
       {"ejercicio":"Salida en bloque","series":"5","distancia":"100 m","descanso":"1 min 15 s","material":["Sin material"],"ritmo":"fuerte","observaciones":"Christian: no salir a tope, que luego no llega."},
       {"ejercicio":"Continuo pegados en fila","series":"1","distancia":"600 m","material":["Sin material"],"ritmo":"ritmo de prueba"}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Técnica y vuelta tras lesión","atletas":["dddddddd-0003-4000-8000-000000000053","dddddddd-0041-4000-8000-000000000013","dddddddd-0041-4000-8000-000000000016","dddddddd-0041-4000-8000-000000000019","dddddddd-0041-4000-8000-000000000022"],"filas":[
       {"ejercicio":"Orientación con la cabeza fuera","series":"8","distancia":"50 m","descanso":"25 s","material":["Sin material"],"observaciones":"Mirar un punto fijo de la pared del fondo."},
       {"ejercicio":"Continuo cómodo","series":"1","distancia":"600 m","material":["Pull-buoy"],"ritmo":"cómodo"}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000015','dddddddd-0002-4000-8000-000000000010','2026-08-07','viernes','pista','calidad_fuerte',
   'Test de 3.000 en pista',
   'Test de control de agosto. Sirve para ajustar los ritmos de aquí a septiembre, así que se hace descansado y con la pista para nosotros.',
   '19:30','Pista municipal de atletismo',null,70,true,'dddddddd-0001-4000-8000-000000000008',
   '[{"etiqueta":"Parte inicial","filas":[
       {"ejercicio":"Trote suave","series":"1","distancia":"15 min","calzado":"Zapatillas"},
       {"ejercicio":"Técnica de carrera","series":"3","distancia":"40 m","descanso":"vuelta andando","calzado":"Zapatillas"},
       {"ejercicio":"Progresivos","series":"4","distancia":"100 m","descanso":"1 min 30 s","calzado":"Zapatillas"}]},
     {"etiqueta":"Test","matiz":"3.000 m cronometrados","filas":[
       {"ejercicio":"3.000 m","series":"1","distancia":"3.000 m","calzado":"Zapatillas","ritmo":"máximo","observaciones":"Objetivos: Iván bajar de 10:30 · Joan de 10:50 · Andreu de 10:45 · Patri de 11:40 · Marta G. de 12:20"},
       {"ejercicio":"Parciales cada 400","series":"1","distancia":"7 x 400 m","observaciones":"Se cantan los parciales desde la meta para que no se disparen."}]},
     {"etiqueta":"Adaptado","matiz":"Sin test","filas":[
       {"ejercicio":"Rodaje suave","series":"1","distancia":"30 min","calzado":"Zapatillas","ritmo":"cómodo","observaciones":"Óscar y Nerea. Ya harán el test en septiembre."}]},
     {"etiqueta":"Vuelta a la calma","filas":[
       {"ejercicio":"Trote muy suave","series":"1","distancia":"12 min","calzado":"Zapatillas"},
       {"ejercicio":"Estiramientos","series":"1","distancia":"8 min"}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000016','dddddddd-0002-4000-8000-000000000010','2026-08-08','sábado','continuo','calidad_fuerte',
   'Simulacro de triatlón corto',
   'Ensayo general de distancia sprint: 750 de agua, 20 km de bici y 5 km a pie, con las dos transiciones montadas como en carrera.',
   '08:30','Playa del Postiguet y carretera de la Albufereta',null,150,true,'dddddddd-0001-4000-8000-000000000008',
   '[{"etiqueta":"Natación","matiz":"750 m en mar abierto","filas":[
       {"ejercicio":"Calentamiento en el agua","series":"1","distancia":"200 m","material":["Sin material"]},
       {"ejercicio":"Salida desde la arena y vuelta a las boyas","series":"1","distancia":"750 m","material":["Sin material"],"ritmo":"ritmo de prueba","observaciones":"Salida en bloque a la señal. Dos boyas y salida a la arena."}]},
     {"etiqueta":"Transición 1","matiz":"Agua a bici","filas":[
       {"ejercicio":"Carrera hasta la bici, casco y salida","series":"1","distancia":"1 vez","observaciones":"Cronometrada. El casco se abrocha antes de tocar la bici."}]},
     {"etiqueta":"Ciclismo","matiz":"20 km","filas":[
       {"ejercicio":"Circuito de ida y vuelta","series":"1","distancia":"20 km en bici","ritmo":"ritmo de prueba","observaciones":"Sin rueda, cada uno solo. Se respeta el tráfico."}]},
     {"etiqueta":"Transición 2","matiz":"Bici a pie","filas":[
       {"ejercicio":"Dejar bici, cambio de zapatillas y salir","series":"1","distancia":"1 vez"}]},
     {"etiqueta":"Carrera","matiz":"5 km","filas":[
       {"ejercicio":"5 km por el paseo","series":"1","distancia":"5 km","calzado":"Zapatillas","ritmo":"máximo","observaciones":"Iván: bajar de 18:00 · Joan: de 18:40 · Ana: de 22:30 · Amparo: de 25:00"}]},
     {"etiqueta":"Vuelta a la calma","filas":[
       {"ejercicio":"Baño suave y estiramientos","series":"1","distancia":"15 min","observaciones":"Se comentan los tiempos de transición al acabar."}]}]'::jsonb)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 4. SESIONES · NATACIÓN · INICIACIÓN (7)
-- ---------------------------------------------------------------------
-- Con estas siete el grupo llega a 10 sesiones en las tres semanas
-- visibles, igual que el resto de grupos de natación.
insert into sesiones (id, grupo_id, fecha, dia_semana, tipo, rol, titulo, nota_razonamiento,
                      hora, lugar, calles, duracion_min, publicada, creado_por, bloques)
values
  ('dddddddd-0042-4000-8000-000000000017','dddddddd-0021-4000-8000-000000000007','2026-07-21','martes','natacion','secundaria',
   'Pies y posición del cuerpo',
   'Se empieza la semana por abajo: si las piernas se hunden, la brazada no sirve de nada.',
   '18:15','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"200 m","material":["Sin material"]},
       {"ejercicio":"Pies con tabla","series":"6","distancia":"25 m","descanso":"20 s","material":["Tabla"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los que ya hacen 400","atletas":["dddddddd-0023-4000-8000-000000000046","dddddddd-0023-4000-8000-000000000048","dddddddd-0023-4000-8000-000000000051"],"filas":[
       {"ejercicio":"Pies de lado con aletas","series":"8","distancia":"25 m","descanso":"20 s","material":["Aletas","Tabla"]},
       {"ejercicio":"Crol continuo","series":"1","distancia":"400 m","material":["Sin material"],"ritmo":"cómodo","observaciones":"Sin pararse en la pared."},
       {"ejercicio":"Series de 50","series":"4","distancia":"50 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0023-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000052"],"filas":[
       {"ejercicio":"Pies de espalda con tabla en la tripa","series":"8","distancia":"25 m","descanso":"25 s","material":["Tabla"],"observaciones":"Lucía: la oreja dentro del agua."},
       {"ejercicio":"Crol de 50","series":"6","distancia":"50 m","descanso":"30 s","material":["Sin material"]},
       {"ejercicio":"Espalda suave","series":"4","distancia":"25 m","descanso":"25 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Aprendiendo el viraje","atletas":["dddddddd-0023-4000-8000-000000000047","dddddddd-0023-4000-8000-000000000049","dddddddd-0023-4000-8000-000000000050"],"filas":[
       {"ejercicio":"Pies con tabla y aletas","series":"8","distancia":"25 m","descanso":"25 s","material":["Tabla","Aletas"]},
       {"ejercicio":"Deslizamiento desde la pared","series":"8","distancia":"10 m","descanso":"25 s","material":["Sin material"],"observaciones":"Abril: sin miedo a meter la cabeza."},
       {"ejercicio":"Crol de 25","series":"6","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"100 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000018','dddddddd-0021-4000-8000-000000000007','2026-07-24','viernes','natacion','secundaria',
   'Espalda y coordinación',
   'Sesión de espalda, que es el estilo que menos practican por su cuenta y el que más les ordena el cuerpo.',
   '18:15','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"200 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los que ya hacen 400","atletas":["dddddddd-0023-4000-8000-000000000046","dddddddd-0023-4000-8000-000000000048","dddddddd-0023-4000-8000-000000000051"],"filas":[
       {"ejercicio":"Espalda con un brazo","series":"8","distancia":"25 m","descanso":"20 s","material":["Sin material"],"observaciones":"Cuatro con cada brazo, el otro pegado al cuerpo."},
       {"ejercicio":"Espalda completa","series":"6","distancia":"50 m","descanso":"30 s","material":["Sin material"]},
       {"ejercicio":"Crol suave","series":"1","distancia":"200 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0023-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000052"],"filas":[
       {"ejercicio":"Espalda con aletas","series":"8","distancia":"25 m","descanso":"25 s","material":["Aletas"]},
       {"ejercicio":"Espalda sin material","series":"6","distancia":"25 m","descanso":"25 s","material":["Sin material"],"observaciones":"Martina: el brazo sale con el pulgar y entra con el meñique."},
       {"ejercicio":"Crol de 50","series":"4","distancia":"50 m","descanso":"35 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Aprendiendo el viraje","atletas":["dddddddd-0023-4000-8000-000000000047","dddddddd-0023-4000-8000-000000000049","dddddddd-0023-4000-8000-000000000050"],"filas":[
       {"ejercicio":"Pies de espalda con tabla","series":"8","distancia":"25 m","descanso":"25 s","material":["Tabla"]},
       {"ejercicio":"Espalda con aletas","series":"6","distancia":"25 m","descanso":"25 s","material":["Aletas"],"observaciones":"Thiago: es su primera semana de espalda, sin prisa."},
       {"ejercicio":"Crol de 25","series":"6","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"100 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000019','dddddddd-0021-4000-8000-000000000007','2026-07-28','martes','natacion','calidad_fuerte',
   'Series de 50 y respiración',
   'Primera sesión algo más exigente de la semana. Series cortas con descanso largo, para que puedan nadar rápido sin ahogarse.',
   '18:15','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"200 m","material":["Sin material"]},
       {"ejercicio":"Progresivos","series":"4","distancia":"25 m","descanso":"25 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los que ya hacen 400","atletas":["dddddddd-0023-4000-8000-000000000046","dddddddd-0023-4000-8000-000000000048","dddddddd-0023-4000-8000-000000000051"],"filas":[
       {"ejercicio":"50 fuertes","series":"8","distancia":"50 m","descanso":"45 s","material":["Sin material"],"ritmo":"fuerte","observaciones":"Bruno: 42-44 s · Izan: 44-46 s · Carmen: 46-48 s"},
       {"ejercicio":"Nado suave entre series","series":"1","distancia":"100 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0023-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000052"],"filas":[
       {"ejercicio":"50 fuertes","series":"6","distancia":"50 m","descanso":"1 min","material":["Sin material"],"ritmo":"fuerte","observaciones":"Leo: 50-52 s · Martina: 52-54 s · Lucía: 56-58 s"},
       {"ejercicio":"25 respirando cada tres","series":"6","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Aprendiendo el viraje","atletas":["dddddddd-0023-4000-8000-000000000047","dddddddd-0023-4000-8000-000000000049","dddddddd-0023-4000-8000-000000000050"],"filas":[
       {"ejercicio":"25 fuertes","series":"8","distancia":"25 m","descanso":"45 s","material":["Sin material"],"ritmo":"fuerte"},
       {"ejercicio":"Pies con tabla","series":"6","distancia":"25 m","descanso":"25 s","material":["Tabla"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Espalda suave","series":"1","distancia":"100 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000020','dddddddd-0021-4000-8000-000000000007','2026-07-31','viernes','natacion','secundaria',
   'Virajes y salidas desde el borde',
   'Media sesión dedicada a la pared. En 400 m hay quince virajes: ahí se gana más que nadando más fuerte.',
   '18:15','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"200 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los que ya hacen 400","atletas":["dddddddd-0023-4000-8000-000000000046","dddddddd-0023-4000-8000-000000000048","dddddddd-0023-4000-8000-000000000051"],"filas":[
       {"ejercicio":"Voltereta desde media piscina","series":"10","distancia":"25 m","descanso":"25 s","material":["Sin material"],"observaciones":"Entrar rápido y salir con el cuerpo estirado."},
       {"ejercicio":"Salida desde el poyete","series":"6","distancia":"15 m","descanso":"40 s","material":["Sin material"]},
       {"ejercicio":"Crol de 100 con dos virajes","series":"4","distancia":"100 m","descanso":"40 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0023-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000052"],"filas":[
       {"ejercicio":"Voltereta con ayuda de la corchera","series":"10","distancia":"15 m","descanso":"25 s","material":["Sin material"],"observaciones":"Leo ya la hace sin tragar agua."},
       {"ejercicio":"Salida sentado en el borde","series":"6","distancia":"12 m","descanso":"35 s","material":["Sin material"]},
       {"ejercicio":"Crol de 50 con viraje","series":"4","distancia":"50 m","descanso":"35 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Aprendiendo el viraje","atletas":["dddddddd-0023-4000-8000-000000000047","dddddddd-0023-4000-8000-000000000049","dddddddd-0023-4000-8000-000000000050"],"filas":[
       {"ejercicio":"Viraje sencillo, tocar y empujar","series":"12","distancia":"12 m","descanso":"25 s","material":["Sin material"]},
       {"ejercicio":"Deslizar desde la pared con aletas","series":"8","distancia":"12 m","descanso":"25 s","material":["Aletas"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"100 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000021','dddddddd-0021-4000-8000-000000000007','2026-08-01','sábado','natacion','descarga',
   'Sábado de juegos y relevos',
   'Sesión de agosto para que no se les haga pesado el verano. Se trabaja igual, pero jugando.',
   '10:00','Piscina cubierta municipal',3,60,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado libre","series":"1","distancia":"150 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los que ya hacen 400","atletas":["dddddddd-0023-4000-8000-000000000046","dddddddd-0023-4000-8000-000000000048","dddddddd-0023-4000-8000-000000000051"],"filas":[
       {"ejercicio":"Relevo 4 x 25 por equipos","series":"4","distancia":"25 m","descanso":"1 min","material":["Sin material"]},
       {"ejercicio":"Continuo cómodo","series":"1","distancia":"300 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0023-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000052"],"filas":[
       {"ejercicio":"Relevo con tabla","series":"4","distancia":"25 m","descanso":"1 min","material":["Tabla"]},
       {"ejercicio":"Continuo cómodo","series":"1","distancia":"200 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Aprendiendo el viraje","atletas":["dddddddd-0023-4000-8000-000000000047","dddddddd-0023-4000-8000-000000000049","dddddddd-0023-4000-8000-000000000050"],"filas":[
       {"ejercicio":"Relevo con aletas","series":"4","distancia":"25 m","descanso":"1 min","material":["Aletas"]},
       {"ejercicio":"Pesca de aros del fondo","series":"1","distancia":"8 min","material":["Sin material"]}]},
     {"etiqueta":"Juego final","matiz":"Todos","filas":[
       {"ejercicio":"Waterpolo adaptado","series":"1","distancia":"15 min","material":["Sin material"],"observaciones":"Se mezclan las tres calles."}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000022','dddddddd-0021-4000-8000-000000000007','2026-08-06','jueves','natacion','secundaria',
   'Aletas, palas pequeñas y crol',
   'Material para notar el agarre del agua. Las palas son las pequeñas: con las grandes a esta edad se cargan los hombros.',
   '18:15','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"200 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los que ya hacen 400","atletas":["dddddddd-0023-4000-8000-000000000046","dddddddd-0023-4000-8000-000000000048","dddddddd-0023-4000-8000-000000000051"],"filas":[
       {"ejercicio":"Crol con palas","series":"8","distancia":"50 m","descanso":"25 s","material":["Palas"],"observaciones":"Palas pequeñas. Si duele el hombro, se quitan."},
       {"ejercicio":"Crol con aletas","series":"6","distancia":"50 m","descanso":"25 s","material":["Aletas"]},
       {"ejercicio":"Crol sin material","series":"4","distancia":"50 m","descanso":"30 s","material":["Sin material"],"observaciones":"Mantener la sensación de agarre sin las palas."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0023-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000052"],"filas":[
       {"ejercicio":"Crol con palas","series":"6","distancia":"25 m","descanso":"25 s","material":["Palas"]},
       {"ejercicio":"Espalda con aletas","series":"6","distancia":"25 m","descanso":"25 s","material":["Aletas"]},
       {"ejercicio":"Crol sin material","series":"4","distancia":"50 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Aprendiendo el viraje","atletas":["dddddddd-0023-4000-8000-000000000047","dddddddd-0023-4000-8000-000000000049","dddddddd-0023-4000-8000-000000000050"],"filas":[
       {"ejercicio":"Pies con aletas y tabla","series":"8","distancia":"25 m","descanso":"25 s","material":["Aletas","Tabla"]},
       {"ejercicio":"Crol con aletas","series":"6","distancia":"25 m","descanso":"25 s","material":["Aletas"],"observaciones":"Noa: aprovecha las aletas para respirar de lado sin pararse."}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"100 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000023','dddddddd-0021-4000-8000-000000000007','2026-08-07','viernes','natacion','calidad_fuerte',
   'Control de 200 m',
   'Control de agosto. Sirve para repartir las calles de septiembre y para que vean lo que han mejorado desde mayo.',
   '18:15','Piscina cubierta municipal',3,45,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"200 m","material":["Sin material"]},
       {"ejercicio":"Progresivos","series":"4","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los que ya hacen 400","atletas":["dddddddd-0023-4000-8000-000000000046","dddddddd-0023-4000-8000-000000000048","dddddddd-0023-4000-8000-000000000051"],"filas":[
       {"ejercicio":"Control de 200 libres","series":"1","distancia":"200 m","descanso":"6 min","material":["Sin material"],"ritmo":"máximo","observaciones":"Bruno: bajar de 3:12 · Izan: de 3:18 · Carmen: de 3:26"},
       {"ejercicio":"Nado suave","series":"1","distancia":"200 m","material":["Sin material"]},
       {"ejercicio":"50 sueltos","series":"2","distancia":"50 m","descanso":"1 min","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Crol y espalda","atletas":["dddddddd-0023-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000052"],"filas":[
       {"ejercicio":"Control de 200 libres","series":"1","distancia":"200 m","descanso":"6 min","material":["Sin material"],"ritmo":"máximo","observaciones":"Leo: bajar de 3:40 · Martina: de 3:46 · Lucía: de 4:00"},
       {"ejercicio":"Nado suave","series":"1","distancia":"150 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Aprendiendo el viraje","atletas":["dddddddd-0023-4000-8000-000000000047","dddddddd-0023-4000-8000-000000000049","dddddddd-0023-4000-8000-000000000050"],"filas":[
       {"ejercicio":"Control de 100 libres","series":"1","distancia":"100 m","descanso":"5 min","material":["Sin material"],"ritmo":"máximo","observaciones":"Los 200 se dejan para octubre."},
       {"ejercicio":"Nado suave con tabla","series":"1","distancia":"150 m","material":["Tabla"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Espalda suave","series":"1","distancia":"100 m","material":["Sin material"]}]}]'::jsonb)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 5. SESIONES · NATACIÓN · TECNIFICACIÓN (8)
-- ---------------------------------------------------------------------
-- Lunes, miércoles y viernes de 19:15 a 20:30, más un control el sábado.
insert into sesiones (id, grupo_id, fecha, dia_semana, tipo, rol, titulo, nota_razonamiento,
                      hora, lugar, calles, duracion_min, publicada, creado_por, bloques)
values
  ('dddddddd-0042-4000-8000-000000000024','dddddddd-0021-4000-8000-000000000008','2026-07-20','lunes','natacion','secundaria',
   'Aeróbico de 2.500 m por calles',
   'Lunes de volumen cómodo. Se acumulan metros sin apretar, que la calidad llega el miércoles.',
   '19:15','Piscina cubierta municipal',3,75,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]},
       {"ejercicio":"Técnica por estilos","series":"8","distancia":"25 m","descanso":"15 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Crol","atletas":["dddddddd-0023-4000-8000-000000000054","dddddddd-0023-4000-8000-000000000058","dddddddd-0023-4000-8000-000000000059"],"filas":[
       {"ejercicio":"400 continuos","series":"3","distancia":"400 m","descanso":"40 s","material":["Sin material"],"ritmo":"cómodo","observaciones":"Samu: 5:35-5:40 · Marc: 5:45-5:50 · Clau: 6:00-6:05"},
       {"ejercicio":"100 con palas y pull-buoy","series":"6","distancia":"100 m","descanso":"20 s","material":["Palas","Pull-buoy"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Espalda y estilos","atletas":["dddddddd-0023-4000-8000-000000000055","dddddddd-0023-4000-8000-000000000060","dddddddd-0023-4000-8000-000000000062"],"filas":[
       {"ejercicio":"300 alternando crol y espalda","series":"4","distancia":"300 m","descanso":"40 s","material":["Sin material"],"ritmo":"cómodo"},
       {"ejercicio":"Pies de espalda con aletas","series":"6","distancia":"50 m","descanso":"25 s","material":["Aletas"],"observaciones":"Aleix: solo pies mientras cuida el hombro."}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Braza y mariposa","atletas":["dddddddd-0023-4000-8000-000000000056","dddddddd-0023-4000-8000-000000000057","dddddddd-0023-4000-8000-000000000061"],"filas":[
       {"ejercicio":"200 de braza suave","series":"5","distancia":"200 m","descanso":"35 s","material":["Sin material"],"ritmo":"cómodo"},
       {"ejercicio":"Mariposa de 25 con aletas","series":"8","distancia":"25 m","descanso":"25 s","material":["Aletas"],"observaciones":"Greta: dos brazadas y deslizar, sin forzar la espalda."}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000025','dddddddd-0021-4000-8000-000000000008','2026-07-22','miércoles','natacion','calidad_fuerte',
   'Series de 100 al ritmo de 200',
   'La sesión fuerte de la semana. Series a ritmo de competición de 200, con descanso corto para que no se escapen.',
   '19:15','Piscina cubierta municipal',3,75,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]},
       {"ejercicio":"Progresivos","series":"6","distancia":"50 m","descanso":"20 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Crol","atletas":["dddddddd-0023-4000-8000-000000000054","dddddddd-0023-4000-8000-000000000058","dddddddd-0023-4000-8000-000000000059"],"filas":[
       {"ejercicio":"100 al ritmo de 200","series":"10","distancia":"100 m","descanso":"1 min","material":["Sin material"],"ritmo":"ritmo de 200","observaciones":"Marc: 1:06-1:08 · Samu: 1:05-1:07 · Clau: 1:10-1:12"},
       {"ejercicio":"25 lanzados","series":"4","distancia":"25 m","descanso":"45 s","material":["Sin material"],"ritmo":"máximo"}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Espalda y estilos","atletas":["dddddddd-0023-4000-8000-000000000055","dddddddd-0023-4000-8000-000000000060","dddddddd-0023-4000-8000-000000000062"],"filas":[
       {"ejercicio":"100 espalda al ritmo de 200","series":"8","distancia":"100 m","descanso":"1 min 10 s","material":["Sin material"],"ritmo":"ritmo de 200","observaciones":"Ainara: 1:16-1:18 · Nil: 1:14-1:16"},
       {"ejercicio":"50 de estilos","series":"4","distancia":"50 m","descanso":"50 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Braza y mariposa","atletas":["dddddddd-0023-4000-8000-000000000056","dddddddd-0023-4000-8000-000000000057","dddddddd-0023-4000-8000-000000000061"],"filas":[
       {"ejercicio":"100 braza al ritmo de 200","series":"8","distancia":"100 m","descanso":"1 min 15 s","material":["Sin material"],"ritmo":"ritmo de 200","observaciones":"Álvaro: 1:26-1:28 · Julia: mariposa, 1:22-1:24"},
       {"ejercicio":"Virajes de braza y mariposa","series":"8","distancia":"25 m","descanso":"30 s","material":["Sin material"],"observaciones":"Tocar con las dos manos a la vez."}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"300 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000026','dddddddd-0021-4000-8000-000000000008','2026-07-24','viernes','natacion','secundaria',
   'Piernas, material y técnica',
   'Después del miércoles fuerte, viernes de piernas y material. Los brazos descansan y las piernas trabajan.',
   '19:15','Piscina cubierta municipal',3,75,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Crol","atletas":["dddddddd-0023-4000-8000-000000000054","dddddddd-0023-4000-8000-000000000058","dddddddd-0023-4000-8000-000000000059"],"filas":[
       {"ejercicio":"Pies con tabla","series":"10","distancia":"50 m","descanso":"25 s","material":["Tabla"]},
       {"ejercicio":"Pies de lado con aletas","series":"6","distancia":"50 m","descanso":"25 s","material":["Aletas"]},
       {"ejercicio":"Crol continuo","series":"1","distancia":"600 m","material":["Sin material"],"ritmo":"cómodo"}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Espalda y estilos","atletas":["dddddddd-0023-4000-8000-000000000055","dddddddd-0023-4000-8000-000000000060","dddddddd-0023-4000-8000-000000000062"],"filas":[
       {"ejercicio":"Pies de espalda con tabla en la tripa","series":"10","distancia":"50 m","descanso":"25 s","material":["Tabla"]},
       {"ejercicio":"Ondulación con aletas","series":"8","distancia":"25 m","descanso":"25 s","material":["Aletas"]},
       {"ejercicio":"Espalda continua","series":"1","distancia":"400 m","material":["Sin material"],"ritmo":"cómodo"}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Braza y mariposa","atletas":["dddddddd-0023-4000-8000-000000000056","dddddddd-0023-4000-8000-000000000057","dddddddd-0023-4000-8000-000000000061"],"filas":[
       {"ejercicio":"Pies de braza con tabla","series":"10","distancia":"25 m","descanso":"25 s","material":["Tabla"],"observaciones":"Talones al culo y abrir con el empeine hacia fuera."},
       {"ejercicio":"Ondulación de mariposa con aletas","series":"8","distancia":"25 m","descanso":"25 s","material":["Aletas"]},
       {"ejercicio":"Braza continua","series":"1","distancia":"400 m","material":["Sin material"],"ritmo":"cómodo"}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000027','dddddddd-0021-4000-8000-000000000008','2026-07-27','lunes','natacion','secundaria',
   'Los cuatro estilos, 200 por 200',
   'Semana nueva. Se repasan los cuatro estilos en bloques de 200 para no perder la mariposa ni la braza durante el verano.',
   '19:15','Piscina cubierta municipal',3,75,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]},
       {"ejercicio":"Técnica por estilos","series":"8","distancia":"25 m","descanso":"15 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Crol","atletas":["dddddddd-0023-4000-8000-000000000054","dddddddd-0023-4000-8000-000000000058","dddddddd-0023-4000-8000-000000000059"],"filas":[
       {"ejercicio":"200 de cada estilo","series":"4","distancia":"200 m","descanso":"40 s","material":["Sin material"],"observaciones":"Orden de estilos: mariposa suave, espalda, braza y crol."},
       {"ejercicio":"100 de estilos completos","series":"4","distancia":"100 m","descanso":"45 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Espalda y estilos","atletas":["dddddddd-0023-4000-8000-000000000055","dddddddd-0023-4000-8000-000000000060","dddddddd-0023-4000-8000-000000000062"],"filas":[
       {"ejercicio":"200 de cada estilo","series":"4","distancia":"200 m","descanso":"45 s","material":["Sin material"],"observaciones":"Nil: cuidar el paso de espalda a braza, que pierde el viraje."},
       {"ejercicio":"100 de estilos completos","series":"4","distancia":"100 m","descanso":"50 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Braza y mariposa","atletas":["dddddddd-0023-4000-8000-000000000056","dddddddd-0023-4000-8000-000000000057","dddddddd-0023-4000-8000-000000000061"],"filas":[
       {"ejercicio":"200 de braza y 200 de mariposa por partes","series":"4","distancia":"200 m","descanso":"50 s","material":["Sin material"]},
       {"ejercicio":"50 de mariposa con aletas","series":"6","distancia":"50 m","descanso":"40 s","material":["Aletas"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000028','dddddddd-0021-4000-8000-000000000008','2026-07-29','miércoles','natacion','calidad_fuerte',
   'Velocidad corta y salidas',
   'Poco volumen y mucha chispa. Descansos largos de verdad, que si no dejan de ser series de velocidad.',
   '19:15','Piscina cubierta municipal',3,70,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]},
       {"ejercicio":"Progresivos","series":"6","distancia":"25 m","descanso":"25 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Crol","atletas":["dddddddd-0023-4000-8000-000000000054","dddddddd-0023-4000-8000-000000000058","dddddddd-0023-4000-8000-000000000059"],"filas":[
       {"ejercicio":"25 desde salida","series":"8","distancia":"25 m","descanso":"1 min 30 s","material":["Sin material"],"ritmo":"máximo","observaciones":"Marc: 12,8-13,0 · Clau: 14,2-14,5"},
       {"ejercicio":"50 desde salida","series":"4","distancia":"50 m","descanso":"2 min","material":["Sin material"],"ritmo":"máximo"}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Espalda y estilos","atletas":["dddddddd-0023-4000-8000-000000000055","dddddddd-0023-4000-8000-000000000060","dddddddd-0023-4000-8000-000000000062"],"filas":[
       {"ejercicio":"25 de espalda desde el agua","series":"8","distancia":"25 m","descanso":"1 min 30 s","material":["Sin material"],"ritmo":"máximo"},
       {"ejercicio":"Salida de espalda y ondulación","series":"6","distancia":"15 m","descanso":"1 min","material":["Sin material"],"observaciones":"Aleix: solo salidas, sin series completas."}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Braza y mariposa","atletas":["dddddddd-0023-4000-8000-000000000056","dddddddd-0023-4000-8000-000000000057","dddddddd-0023-4000-8000-000000000061"],"filas":[
       {"ejercicio":"25 de braza desde salida","series":"8","distancia":"25 m","descanso":"1 min 30 s","material":["Sin material"],"ritmo":"máximo","observaciones":"Álvaro: la brazada subacuática entera antes de sacar la cabeza."},
       {"ejercicio":"25 de mariposa","series":"4","distancia":"25 m","descanso":"1 min 30 s","material":["Sin material"],"ritmo":"máximo"}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"300 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000029','dddddddd-0021-4000-8000-000000000008','2026-08-03','lunes','natacion','secundaria',
   'Aeróbico con palas y pull-buoy',
   'Vuelta al volumen tras el fin de semana. Material para trabajar el agarre sin cargar demasiado los hombros.',
   '19:15','Piscina cubierta municipal',3,75,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Crol","atletas":["dddddddd-0023-4000-8000-000000000054","dddddddd-0023-4000-8000-000000000058","dddddddd-0023-4000-8000-000000000059"],"filas":[
       {"ejercicio":"200 con palas y pull-buoy","series":"6","distancia":"200 m","descanso":"30 s","material":["Palas","Pull-buoy"],"ritmo":"cómodo"},
       {"ejercicio":"100 sin material","series":"4","distancia":"100 m","descanso":"30 s","material":["Sin material"],"observaciones":"Sin perder la sensación de las palas."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Espalda y estilos","atletas":["dddddddd-0023-4000-8000-000000000055","dddddddd-0023-4000-8000-000000000060","dddddddd-0023-4000-8000-000000000062"],"filas":[
       {"ejercicio":"200 alternando espalda y crol","series":"5","distancia":"200 m","descanso":"35 s","material":["Pull-buoy"],"ritmo":"cómodo"},
       {"ejercicio":"100 de estilos","series":"4","distancia":"100 m","descanso":"40 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Braza y mariposa","atletas":["dddddddd-0023-4000-8000-000000000056","dddddddd-0023-4000-8000-000000000057","dddddddd-0023-4000-8000-000000000061"],"filas":[
       {"ejercicio":"200 de braza con pull-buoy","series":"5","distancia":"200 m","descanso":"40 s","material":["Pull-buoy"],"observaciones":"Solo brazos, para no cansar la rodilla."},
       {"ejercicio":"50 de mariposa con aletas","series":"6","distancia":"50 m","descanso":"35 s","material":["Aletas"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000030','dddddddd-0021-4000-8000-000000000008','2026-08-05','miércoles','natacion','calidad_fuerte',
   'Series rotas de 100',
   'Series rotas: se nada el 100 en dos trozos de 50 con diez segundos de descanso, para tocar un ritmo que aún no se aguanta seguido.',
   '19:15','Piscina cubierta municipal',3,75,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]},
       {"ejercicio":"Progresivos","series":"6","distancia":"50 m","descanso":"20 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Crol","atletas":["dddddddd-0023-4000-8000-000000000054","dddddddd-0023-4000-8000-000000000058","dddddddd-0023-4000-8000-000000000059"],"filas":[
       {"ejercicio":"100 rotos en 2 x 50","series":"8","distancia":"100 m","descanso":"1 min 30 s","material":["Sin material"],"ritmo":"ritmo de 100","observaciones":"Diez segundos entre los dos 50. Marc: 30,5 por 50 · Samu: 30,0 · Clau: 32,5"},
       {"ejercicio":"100 continuo de control","series":"1","distancia":"100 m","descanso":"3 min","material":["Sin material"],"ritmo":"máximo"}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Espalda y estilos","atletas":["dddddddd-0023-4000-8000-000000000055","dddddddd-0023-4000-8000-000000000060","dddddddd-0023-4000-8000-000000000062"],"filas":[
       {"ejercicio":"100 de espalda rotos en 2 x 50","series":"6","distancia":"100 m","descanso":"1 min 30 s","material":["Sin material"],"ritmo":"ritmo de 100"},
       {"ejercicio":"100 de estilos","series":"2","distancia":"100 m","descanso":"2 min","material":["Sin material"],"ritmo":"fuerte"}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Braza y mariposa","atletas":["dddddddd-0023-4000-8000-000000000056","dddddddd-0023-4000-8000-000000000057","dddddddd-0023-4000-8000-000000000061"],"filas":[
       {"ejercicio":"100 de braza rotos en 2 x 50","series":"6","distancia":"100 m","descanso":"1 min 40 s","material":["Sin material"],"ritmo":"ritmo de 100","observaciones":"Álvaro: 40,5 por 50 · Greta: crol, 34,0"},
       {"ejercicio":"50 de mariposa","series":"4","distancia":"50 m","descanso":"1 min","material":["Sin material"],"ritmo":"fuerte","observaciones":"Julia lleva la serie."}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"300 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000031','dddddddd-0021-4000-8000-000000000008','2026-08-08','sábado','natacion','competicion',
   'Control de 100 y 200 cronometrado',
   'Control de agosto con jueces y calle libre, como en una jornada de verdad. Sirve para las mínimas de octubre.',
   '10:00','Piscina cubierta municipal',3,90,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"600 m","material":["Sin material"]},
       {"ejercicio":"Progresivos y salidas","series":"6","distancia":"25 m","descanso":"1 min","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Crol","atletas":["dddddddd-0023-4000-8000-000000000054","dddddddd-0023-4000-8000-000000000058","dddddddd-0023-4000-8000-000000000059"],"filas":[
       {"ejercicio":"100 libres cronometrado","series":"1","distancia":"100 m","descanso":"20 min","material":["Sin material"],"ritmo":"máximo","observaciones":"Marc: bajar de 1:02 · Samu: de 1:01 · Clau: de 1:07"},
       {"ejercicio":"200 libres cronometrado","series":"1","distancia":"200 m","material":["Sin material"],"ritmo":"máximo","observaciones":"Samu es el que más opciones tiene de mínima."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Espalda y estilos","atletas":["dddddddd-0023-4000-8000-000000000055","dddddddd-0023-4000-8000-000000000060","dddddddd-0023-4000-8000-000000000062"],"filas":[
       {"ejercicio":"100 espalda cronometrado","series":"1","distancia":"100 m","descanso":"20 min","material":["Sin material"],"ritmo":"máximo","observaciones":"Ainara: bajar de 1:12 · Nil: de 1:10"},
       {"ejercicio":"200 estilos cronometrado","series":"1","distancia":"200 m","material":["Sin material"],"ritmo":"máximo","observaciones":"Aleix no compite: hace de juez de virajes."}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Braza y mariposa","atletas":["dddddddd-0023-4000-8000-000000000056","dddddddd-0023-4000-8000-000000000057","dddddddd-0023-4000-8000-000000000061"],"filas":[
       {"ejercicio":"100 braza cronometrado","series":"1","distancia":"100 m","descanso":"20 min","material":["Sin material"],"ritmo":"máximo","observaciones":"Álvaro: bajar de 1:22"},
       {"ejercicio":"100 mariposa cronometrado","series":"1","distancia":"100 m","material":["Sin material"],"ritmo":"máximo","observaciones":"Julia: bajar de 1:14 · Greta hace 100 libres."}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"400 m","material":["Sin material"],"observaciones":"Se comentan los tiempos en el vestuario."}]}]'::jsonb)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 6. SESIONES · NATACIÓN · MÁSTER (7)
-- ---------------------------------------------------------------------
-- Lunes, miércoles y viernes a las 21:00, y un sábado de travesía corta
-- con la gente de aguas abiertas.
insert into sesiones (id, grupo_id, fecha, dia_semana, tipo, rol, titulo, nota_razonamiento,
                      hora, lugar, calles, duracion_min, publicada, creado_por, bloques)
values
  ('dddddddd-0042-4000-8000-000000000032','dddddddd-0021-4000-8000-000000000009','2026-07-20','lunes','natacion','secundaria',
   'Vuelta a la rutina · aeróbico suave',
   'Lunes de reenganche. Nada exigente: se trata de volver a coger el agua después del fin de semana.',
   '21:00','Piscina cubierta municipal',3,60,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]},
       {"ejercicio":"Movilidad de hombro en la pared","series":"1","distancia":"3 min","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los más rápidos","atletas":["dddddddd-0023-4000-8000-000000000063","dddddddd-0023-4000-8000-000000000066","dddddddd-0023-4000-8000-000000000068"],"filas":[
       {"ejercicio":"200 continuos","series":"6","distancia":"200 m","descanso":"30 s","material":["Sin material"],"ritmo":"cómodo","observaciones":"Ramón: 3:05-3:10 · Sonia: 3:15-3:20 · Yoli: 3:20-3:25"},
       {"ejercicio":"50 progresivos","series":"4","distancia":"50 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Ritmo medio","atletas":["dddddddd-0023-4000-8000-000000000064","dddddddd-0023-4000-8000-000000000070","dddddddd-0023-4000-8000-000000000067"],"filas":[
       {"ejercicio":"150 continuos","series":"6","distancia":"150 m","descanso":"35 s","material":["Sin material"],"ritmo":"cómodo"},
       {"ejercicio":"50 de espalda","series":"4","distancia":"50 m","descanso":"35 s","material":["Sin material"],"observaciones":"Marisa lleva la calle en espalda."}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Técnica y braza","atletas":["dddddddd-0023-4000-8000-000000000065","dddddddd-0023-4000-8000-000000000069"],"filas":[
       {"ejercicio":"100 de braza suave","series":"6","distancia":"100 m","descanso":"40 s","material":["Sin material"]},
       {"ejercicio":"Pies con tabla","series":"6","distancia":"25 m","descanso":"25 s","material":["Tabla"],"observaciones":"Ángel: sin apretar el hombro, es la primera semana de vuelta."}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000033','dddddddd-0021-4000-8000-000000000009','2026-07-22','miércoles','natacion','secundaria',
   'Series de 100 cómodas y técnica de viraje',
   'A esta edad el viraje es donde más se gana y donde menos se arriesga. Media sesión de pared.',
   '21:00','Piscina cubierta municipal',3,60,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los más rápidos","atletas":["dddddddd-0023-4000-8000-000000000063","dddddddd-0023-4000-8000-000000000066","dddddddd-0023-4000-8000-000000000068"],"filas":[
       {"ejercicio":"100 cómodos","series":"10","distancia":"100 m","descanso":"25 s","material":["Sin material"],"ritmo":"cómodo"},
       {"ejercicio":"Voltereta desde media piscina","series":"8","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Ritmo medio","atletas":["dddddddd-0023-4000-8000-000000000064","dddddddd-0023-4000-8000-000000000070","dddddddd-0023-4000-8000-000000000067"],"filas":[
       {"ejercicio":"100 cómodos","series":"8","distancia":"100 m","descanso":"30 s","material":["Sin material"],"ritmo":"cómodo","observaciones":"Vicent: 1:52-1:56 · Inma: 1:55-2:00"},
       {"ejercicio":"Viraje de crol con toque","series":"8","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Técnica y braza","atletas":["dddddddd-0023-4000-8000-000000000065","dddddddd-0023-4000-8000-000000000069"],"filas":[
       {"ejercicio":"100 de braza","series":"6","distancia":"100 m","descanso":"40 s","material":["Sin material"],"observaciones":"Jose: brazada corta y patada larga, no al revés."},
       {"ejercicio":"Viraje de braza con las dos manos","series":"8","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Espalda suave","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000034','dddddddd-0021-4000-8000-000000000009','2026-07-27','lunes','natacion','secundaria',
   'Piernas y brazos por separado',
   'Sesión partida: primero solo piernas con tabla y luego solo brazos con pull-buoy. Cansa menos y ordena mucho la técnica.',
   '21:00','Piscina cubierta municipal',3,60,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los más rápidos","atletas":["dddddddd-0023-4000-8000-000000000063","dddddddd-0023-4000-8000-000000000066","dddddddd-0023-4000-8000-000000000068"],"filas":[
       {"ejercicio":"Pies con tabla","series":"8","distancia":"50 m","descanso":"25 s","material":["Tabla"]},
       {"ejercicio":"Brazos con pull-buoy y palas","series":"8","distancia":"50 m","descanso":"25 s","material":["Pull-buoy","Palas"]},
       {"ejercicio":"Crol completo","series":"4","distancia":"100 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Ritmo medio","atletas":["dddddddd-0023-4000-8000-000000000064","dddddddd-0023-4000-8000-000000000070","dddddddd-0023-4000-8000-000000000067"],"filas":[
       {"ejercicio":"Pies con tabla","series":"8","distancia":"25 m","descanso":"25 s","material":["Tabla"]},
       {"ejercicio":"Brazos con pull-buoy","series":"8","distancia":"50 m","descanso":"30 s","material":["Pull-buoy"]},
       {"ejercicio":"Crol completo","series":"4","distancia":"50 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Técnica y braza","atletas":["dddddddd-0023-4000-8000-000000000065","dddddddd-0023-4000-8000-000000000069"],"filas":[
       {"ejercicio":"Pies de braza con tabla","series":"8","distancia":"25 m","descanso":"30 s","material":["Tabla"]},
       {"ejercicio":"Brazos de braza con pull-buoy","series":"6","distancia":"50 m","descanso":"35 s","material":["Pull-buoy"],"observaciones":"Ángel ya puede tirar de brazos sin molestias."}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000035','dddddddd-0021-4000-8000-000000000009','2026-07-31','viernes','natacion','calidad_fuerte',
   'Progresivos de 50 y estilos',
   'El único día algo fuerte de la semana. Progresivos, que suben pulsaciones sin machacar, y un poco de cada estilo.',
   '21:00','Piscina cubierta municipal',3,60,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]},
       {"ejercicio":"Técnica por estilos","series":"8","distancia":"25 m","descanso":"20 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los más rápidos","atletas":["dddddddd-0023-4000-8000-000000000063","dddddddd-0023-4000-8000-000000000066","dddddddd-0023-4000-8000-000000000068"],"filas":[
       {"ejercicio":"50 progresivos","series":"12","distancia":"50 m","descanso":"30 s","material":["Sin material"],"observaciones":"De cuatro en cuatro: suave, medio y fuerte."},
       {"ejercicio":"100 de estilos","series":"2","distancia":"100 m","descanso":"1 min","material":["Sin material"],"observaciones":"Yoli lleva la serie de estilos."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Ritmo medio","atletas":["dddddddd-0023-4000-8000-000000000064","dddddddd-0023-4000-8000-000000000070","dddddddd-0023-4000-8000-000000000067"],"filas":[
       {"ejercicio":"50 progresivos","series":"10","distancia":"50 m","descanso":"35 s","material":["Sin material"]},
       {"ejercicio":"50 de espalda y 50 de crol","series":"4","distancia":"100 m","descanso":"45 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Técnica y braza","atletas":["dddddddd-0023-4000-8000-000000000065","dddddddd-0023-4000-8000-000000000069"],"filas":[
       {"ejercicio":"50 de braza progresivos","series":"8","distancia":"50 m","descanso":"40 s","material":["Sin material"]},
       {"ejercicio":"25 de braza fuertes","series":"6","distancia":"25 m","descanso":"45 s","material":["Sin material"],"ritmo":"fuerte","observaciones":"Jose se prepara el 50 braza del máster de septiembre."}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000036','dddddddd-0021-4000-8000-000000000009','2026-08-03','lunes','natacion','secundaria',
   'Continuo de 1.500 por ritmos',
   'Un continuo largo partido en tres ritmos. Para los máster es la sesión que más se parece a una travesía.',
   '21:00','Piscina cubierta municipal',3,60,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los más rápidos","atletas":["dddddddd-0023-4000-8000-000000000063","dddddddd-0023-4000-8000-000000000066","dddddddd-0023-4000-8000-000000000068"],"filas":[
       {"ejercicio":"Continuo de 1.500 en tres tramos","series":"1","distancia":"1.500 m","material":["Sin material"],"observaciones":"500 suave, 500 medio y 500 fuerte, sin parar entre tramos."},
       {"ejercicio":"Suave","series":"1","distancia":"200 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Ritmo medio","atletas":["dddddddd-0023-4000-8000-000000000064","dddddddd-0023-4000-8000-000000000070","dddddddd-0023-4000-8000-000000000067"],"filas":[
       {"ejercicio":"Continuo de 1.200 en tres tramos","series":"1","distancia":"1.200 m","material":["Sin material"],"observaciones":"400 suave, 400 medio y 400 fuerte."},
       {"ejercicio":"Suave","series":"1","distancia":"200 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Técnica y braza","atletas":["dddddddd-0023-4000-8000-000000000065","dddddddd-0023-4000-8000-000000000069"],"filas":[
       {"ejercicio":"Continuo alternando braza y crol","series":"1","distancia":"800 m","material":["Sin material"],"ritmo":"cómodo","observaciones":"100 de cada, sin parar."},
       {"ejercicio":"Pies con tabla","series":"6","distancia":"25 m","descanso":"30 s","material":["Tabla"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Espalda suave","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000037','dddddddd-0021-4000-8000-000000000009','2026-08-07','viernes','natacion','calidad_fuerte',
   'Velocidad corta y descanso largo',
   'Series de 25 y 50 con mucho descanso. Es la manera de trabajar rápido a partir de los cuarenta sin acabar destrozado.',
   '21:00','Piscina cubierta municipal',3,60,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]},
       {"ejercicio":"Progresivos","series":"4","distancia":"25 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los más rápidos","atletas":["dddddddd-0023-4000-8000-000000000063","dddddddd-0023-4000-8000-000000000066","dddddddd-0023-4000-8000-000000000068"],"filas":[
       {"ejercicio":"25 fuertes","series":"8","distancia":"25 m","descanso":"1 min","material":["Sin material"],"ritmo":"fuerte","observaciones":"Ramón: 16,5-17,0"},
       {"ejercicio":"50 fuertes","series":"4","distancia":"50 m","descanso":"1 min 30 s","material":["Sin material"],"ritmo":"fuerte"}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Ritmo medio","atletas":["dddddddd-0023-4000-8000-000000000064","dddddddd-0023-4000-8000-000000000070","dddddddd-0023-4000-8000-000000000067"],"filas":[
       {"ejercicio":"25 fuertes","series":"8","distancia":"25 m","descanso":"1 min","material":["Sin material"],"ritmo":"fuerte"},
       {"ejercicio":"50 progresivos","series":"4","distancia":"50 m","descanso":"1 min","material":["Sin material"],"observaciones":"Vicent aprovecha para tocar la mariposa en el primer largo."}]},
     {"etiqueta":"Calle 3","calle":3,"matiz":"Técnica y braza","atletas":["dddddddd-0023-4000-8000-000000000065","dddddddd-0023-4000-8000-000000000069"],"filas":[
       {"ejercicio":"25 de braza fuertes","series":"8","distancia":"25 m","descanso":"1 min 15 s","material":["Sin material"],"ritmo":"fuerte"},
       {"ejercicio":"Salida y brazada subacuática","series":"6","distancia":"15 m","descanso":"1 min","material":["Sin material"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"300 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000038','dddddddd-0021-4000-8000-000000000009','2026-08-08','sábado','natacion','secundaria',
   'Sábado de travesía corta en la playa',
   'Una vez al mes se sale al mar con la gente de aguas abiertas. Cambia el ambiente y se agradece en agosto.',
   '09:00','Playa del Postiguet',2,75,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Antes de entrar","matiz":"Todos","filas":[
       {"ejercicio":"Charla de seguridad y reconocimiento de boyas","series":"1","distancia":"10 min","observaciones":"Nadie se mete solo. Gorro naranja obligatorio."}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Los más rápidos","atletas":["dddddddd-0023-4000-8000-000000000063","dddddddd-0023-4000-8000-000000000066","dddddddd-0023-4000-8000-000000000068"],"filas":[
       {"ejercicio":"Travesía paralela a la orilla","series":"1","distancia":"1.500 m","material":["Sin material"],"ritmo":"cómodo","observaciones":"Ramón abre y Sonia cierra el grupo."},
       {"ejercicio":"Salidas y entradas desde la arena","series":"4","distancia":"50 m","descanso":"1 min","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Ritmo medio y braza","atletas":["dddddddd-0023-4000-8000-000000000064","dddddddd-0023-4000-8000-000000000070","dddddddd-0023-4000-8000-000000000067","dddddddd-0023-4000-8000-000000000065","dddddddd-0023-4000-8000-000000000069"],"filas":[
       {"ejercicio":"Travesía entre boyas","series":"1","distancia":"1.000 m","material":["Sin material"],"ritmo":"cómodo","observaciones":"Se puede parar en la boya. Ángel va con la monitora al lado."},
       {"ejercicio":"Orientación levantando la cabeza","series":"6","distancia":"50 m","descanso":"1 min","material":["Sin material"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Estiramientos en la arena y almuerzo","series":"1","distancia":"20 min"}]}]'::jsonb)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 7. SESIONES · AGUAS ABIERTAS (7)
-- ---------------------------------------------------------------------
-- Entre semana piscina a las 21:00 y los domingos playa a las 09:00.
insert into sesiones (id, grupo_id, fecha, dia_semana, tipo, rol, titulo, nota_razonamiento,
                      hora, lugar, calles, duracion_min, publicada, creado_por, bloques)
values
  ('dddddddd-0042-4000-8000-000000000039','dddddddd-0021-4000-8000-000000000010','2026-07-22','miércoles','natacion','secundaria',
   'Piscina · series largas sin pared',
   'En travesía no hay pared de la que empujar. Se hacen series largas y se prohíbe la voltereta para que se parezca al mar.',
   '21:00','Piscina cubierta municipal',2,75,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Ritmo de travesía","atletas":["dddddddd-0023-4000-8000-000000000071","dddddddd-0023-4000-8000-000000000075","dddddddd-0023-4000-8000-000000000074"],"filas":[
       {"ejercicio":"800 continuos sin voltereta","series":"2","distancia":"800 m","descanso":"1 min","material":["Sin material"],"ritmo":"ritmo de travesía","observaciones":"Borja: 11:20-11:40 · Kevin: 11:40-12:00 · Ari: 12:00-12:20"},
       {"ejercicio":"200 con palas","series":"3","distancia":"200 m","descanso":"30 s","material":["Palas","Pull-buoy"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Continuo cómodo","atletas":["dddddddd-0023-4000-8000-000000000072","dddddddd-0023-4000-8000-000000000073","dddddddd-0023-4000-8000-000000000076"],"filas":[
       {"ejercicio":"600 continuos sin voltereta","series":"2","distancia":"600 m","descanso":"1 min 15 s","material":["Sin material"],"ritmo":"cómodo"},
       {"ejercicio":"200 con pull-buoy","series":"3","distancia":"200 m","descanso":"40 s","material":["Pull-buoy"],"observaciones":"Miri: contar brazadas, que se le abre el codo al cansarse."}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000040','dddddddd-0021-4000-8000-000000000010','2026-07-24','viernes','natacion','secundaria',
   'Piscina · nado a ciegas y orientación',
   'Se nada con los ojos cerrados unos cuantos largos para ver quién se va de lado. En el mar eso son metros de más.',
   '21:00','Piscina cubierta municipal',2,60,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Ritmo de travesía","atletas":["dddddddd-0023-4000-8000-000000000071","dddddddd-0023-4000-8000-000000000075","dddddddd-0023-4000-8000-000000000074"],"filas":[
       {"ejercicio":"50 con los ojos cerrados","series":"8","distancia":"50 m","descanso":"30 s","material":["Sin material"],"observaciones":"Borja se va a la derecha: brazada izquierda más larga."},
       {"ejercicio":"100 levantando la cabeza cada seis","series":"6","distancia":"100 m","descanso":"25 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Continuo cómodo","atletas":["dddddddd-0023-4000-8000-000000000072","dddddddd-0023-4000-8000-000000000073","dddddddd-0023-4000-8000-000000000076"],"filas":[
       {"ejercicio":"50 con los ojos cerrados","series":"6","distancia":"50 m","descanso":"35 s","material":["Sin material"]},
       {"ejercicio":"100 levantando la cabeza cada ocho","series":"6","distancia":"100 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000041','dddddddd-0021-4000-8000-000000000010','2026-07-26','domingo','natacion','secundaria',
   'Playa · continuo de 2.000 m y boyas',
   'Domingo de mar con poco oleaje. Continuo cómodo tocando las dos boyas, sin cronómetro.',
   '09:00','Playa del Postiguet',2,75,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Antes de entrar","matiz":"Todos","filas":[
       {"ejercicio":"Reconocimiento de boyas y bandera","series":"1","distancia":"10 min","observaciones":"Bandera amarilla. Nadie sale del cordón de boyas."}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Ritmo de travesía","atletas":["dddddddd-0023-4000-8000-000000000071","dddddddd-0023-4000-8000-000000000075","dddddddd-0023-4000-8000-000000000074"],"filas":[
       {"ejercicio":"Continuo entre boyas","series":"1","distancia":"2.000 m","material":["Sin material"],"ritmo":"ritmo de travesía"},
       {"ejercicio":"Salidas desde la arena","series":"4","distancia":"100 m","descanso":"1 min 30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Continuo cómodo","atletas":["dddddddd-0023-4000-8000-000000000072","dddddddd-0023-4000-8000-000000000073","dddddddd-0023-4000-8000-000000000076"],"filas":[
       {"ejercicio":"Continuo entre boyas","series":"1","distancia":"1.500 m","material":["Sin material"],"ritmo":"cómodo","observaciones":"Se puede parar en la boya a coger aire."},
       {"ejercicio":"Salidas desde la arena","series":"3","distancia":"75 m","descanso":"2 min","material":["Sin material"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Estiramientos en la arena","series":"1","distancia":"10 min"}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000042','dddddddd-0021-4000-8000-000000000010','2026-07-29','miércoles','natacion','calidad_fuerte',
   'Piscina · series de 400 con palas',
   'Series largas a ritmo de travesía. Con palas para ganar agarre, que en el mar es lo que sostiene el ritmo.',
   '21:00','Piscina cubierta municipal',2,75,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]},
       {"ejercicio":"Progresivos","series":"4","distancia":"50 m","descanso":"20 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Ritmo de travesía","atletas":["dddddddd-0023-4000-8000-000000000071","dddddddd-0023-4000-8000-000000000075","dddddddd-0023-4000-8000-000000000074"],"filas":[
       {"ejercicio":"400 a ritmo","series":"5","distancia":"400 m","descanso":"45 s","material":["Palas","Pull-buoy"],"ritmo":"ritmo de travesía","observaciones":"Borja: 5:25-5:30 · Kevin: 5:30-5:35 · Ari: 5:45-5:50"},
       {"ejercicio":"100 suaves","series":"2","distancia":"100 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Continuo cómodo","atletas":["dddddddd-0023-4000-8000-000000000072","dddddddd-0023-4000-8000-000000000073","dddddddd-0023-4000-8000-000000000076"],"filas":[
       {"ejercicio":"400 a ritmo","series":"4","distancia":"400 m","descanso":"1 min","material":["Palas","Pull-buoy"],"ritmo":"cómodo","observaciones":"Sebas: 6:10-6:20 · Laura: 6:00-6:10"},
       {"ejercicio":"100 suaves","series":"2","distancia":"100 m","descanso":"40 s","material":["Sin material"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Espalda suave","series":"1","distancia":"200 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000043','dddddddd-0021-4000-8000-000000000010','2026-08-02','domingo','natacion','secundaria',
   'Playa · salidas desde la arena y pies del de delante',
   'Lo que decide una travesía popular son los primeros doscientos metros y saber ir a rueda. Hoy solo se trabaja eso.',
   '09:00','Playa del Postiguet',2,80,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Antes de entrar","matiz":"Todos","filas":[
       {"ejercicio":"Calentamiento en la arena y entrada suave","series":"1","distancia":"10 min"}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Ritmo de travesía","atletas":["dddddddd-0023-4000-8000-000000000071","dddddddd-0023-4000-8000-000000000075","dddddddd-0023-4000-8000-000000000074"],"filas":[
       {"ejercicio":"Salida en bloque desde la arena","series":"6","distancia":"150 m","descanso":"2 min","material":["Sin material"],"ritmo":"fuerte","observaciones":"Se entra corriendo y con saltos hasta que cubra."},
       {"ejercicio":"Nadar a los pies del de delante","series":"4","distancia":"200 m","descanso":"1 min","material":["Sin material"],"observaciones":"Se rota el primero en cada serie."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Continuo cómodo","atletas":["dddddddd-0023-4000-8000-000000000072","dddddddd-0023-4000-8000-000000000073","dddddddd-0023-4000-8000-000000000076"],"filas":[
       {"ejercicio":"Salida en bloque desde la arena","series":"4","distancia":"100 m","descanso":"2 min 30 s","material":["Sin material"],"ritmo":"fuerte"},
       {"ejercicio":"Nadar a los pies del de delante","series":"3","distancia":"200 m","descanso":"1 min 30 s","material":["Sin material"],"observaciones":"Miri va siempre en medio, que aún se agobia con el contacto."}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave paralelo a la orilla","series":"1","distancia":"400 m","material":["Sin material"]}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000044','dddddddd-0021-4000-8000-000000000010','2026-08-05','miércoles','natacion','secundaria',
   'Piscina · cambios de ritmo largos',
   'Última sesión de piscina antes de la travesía del domingo. Cambios de ritmo dentro de series largas, sin llegar a fondo.',
   '21:00','Piscina cubierta municipal',2,75,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Calentamiento","matiz":"Todos","filas":[
       {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Ritmo de travesía","atletas":["dddddddd-0023-4000-8000-000000000071","dddddddd-0023-4000-8000-000000000075","dddddddd-0023-4000-8000-000000000074"],"filas":[
       {"ejercicio":"300 con cambio cada 100","series":"5","distancia":"300 m","descanso":"40 s","material":["Sin material"],"observaciones":"100 suave, 100 medio y 100 fuerte dentro de cada serie."},
       {"ejercicio":"100 suaves","series":"2","distancia":"100 m","descanso":"30 s","material":["Sin material"]}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Continuo cómodo","atletas":["dddddddd-0023-4000-8000-000000000072","dddddddd-0023-4000-8000-000000000073","dddddddd-0023-4000-8000-000000000076"],"filas":[
       {"ejercicio":"200 con cambio cada 50","series":"6","distancia":"200 m","descanso":"45 s","material":["Sin material"]},
       {"ejercicio":"100 suaves","series":"2","distancia":"100 m","descanso":"40 s","material":["Sin material"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Suave a elección","series":"1","distancia":"200 m","material":["Sin material"],"observaciones":"El domingo se sale a las 09:00 desde el chiringuito."}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000045','dddddddd-0021-4000-8000-000000000010','2026-08-09','domingo','natacion','calidad_fuerte',
   'Playa · travesía de 3.500 m',
   'Simulacro de la travesía de septiembre, con la distancia entera y la salida desde la arena. Se cronometra por tramos.',
   '09:00','Playa del Postiguet',2,90,true,'dddddddd-0001-4000-8000-000000000007',
   '[{"etiqueta":"Antes de entrar","matiz":"Todos","filas":[
       {"ejercicio":"Reconocimiento del recorrido","series":"1","distancia":"10 min","observaciones":"Cuatro boyas. Kayak de apoyo en la boya lejana."}]},
     {"etiqueta":"Calle 1","calle":1,"matiz":"Ritmo de travesía","atletas":["dddddddd-0023-4000-8000-000000000071","dddddddd-0023-4000-8000-000000000075","dddddddd-0023-4000-8000-000000000074"],"filas":[
       {"ejercicio":"Travesía completa","series":"1","distancia":"3.500 m","material":["Sin material"],"ritmo":"ritmo de prueba","observaciones":"Borja: bajar de 50 min · Kevin: de 52 min · Ari: de 55 min"},
       {"ejercicio":"Últimos 300 m a tope","series":"1","distancia":"300 m","material":["Sin material"],"ritmo":"máximo","observaciones":"Se entra corriendo por la arena hasta el arco."}]},
     {"etiqueta":"Calle 2","calle":2,"matiz":"Continuo cómodo","atletas":["dddddddd-0023-4000-8000-000000000072","dddddddd-0023-4000-8000-000000000073","dddddddd-0023-4000-8000-000000000076"],"filas":[
       {"ejercicio":"Travesía adaptada","series":"1","distancia":"2.500 m","material":["Sin material"],"ritmo":"cómodo","observaciones":"Laura y Sebas van juntos. Miri hace 2.000 y sale por la segunda boya."},
       {"ejercicio":"Salida final por la arena","series":"1","distancia":"150 m","material":["Sin material"]}]},
     {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
       {"ejercicio":"Estiramientos y almuerzo en el chiringuito","series":"1","distancia":"25 min"}]}]'::jsonb)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 8. SESIONES · MONTAÑA (3) Y VERTICAL APOLANA (2)
-- ---------------------------------------------------------------------
insert into sesiones (id, grupo_id, fecha, dia_semana, tipo, rol, titulo, nota_razonamiento,
                      hora, lugar, calles, duracion_min, publicada, creado_por, bloques)
values
  ('dddddddd-0042-4000-8000-000000000046','dddddddd-0002-4000-8000-000000000011','2026-07-22','miércoles','continuo','calidad_fuerte',
   'Cuestas en la subida a la Ermita',
   'Entre semana toca desnivel corto. Se sube fuerte y se baja andando, que la bajada es la que destroza las piernas.',
   '19:00','Subida a la Ermita',null,75,true,'dddddddd-0001-4000-8000-000000000009',
   '[{"etiqueta":"Parte inicial","filas":[
       {"ejercicio":"Trote suave en llano","series":"1","distancia":"15 min","calzado":"Zapatillas","ritmo":"cómodo"},
       {"ejercicio":"Movilidad de tobillo y cadera","series":"1","distancia":"6 min"}]},
     {"etiqueta":"Parte principal","matiz":"Desnivel","filas":[
       {"ejercicio":"Subida fuerte","series":"6","distancia":"400 m de subida","descanso":"bajada andando","calzado":"Zapatillas","ritmo":"fuerte","observaciones":"Salva y Jorge abren · Vicent y Toni a su ritmo · Carmen B. cierra"},
       {"ejercicio":"Subida caminando rápido con bastones","series":"2","distancia":"600 m de subida","descanso":"bajada suave","observaciones":"Es lo que se hará de verdad en las rampas duras de carrera."}]},
     {"etiqueta":"Vuelta a la calma","filas":[
       {"ejercicio":"Trote suave de bajada","series":"1","distancia":"10 min","calzado":"Zapatillas"},
       {"ejercicio":"Estiramientos de cuádriceps y gemelo","series":"1","distancia":"8 min"}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000047','dddddddd-0002-4000-8000-000000000011','2026-08-01','sábado','continuo','calidad_fuerte',
   'Salida larga por la Sierra de Mariola',
   'La tirada larga del mes. Tres horas por sendero, con avituallamiento en la fuente y sin prisa por el ritmo.',
   '08:00','Punto de encuentro en la Ermita',null,190,true,'dddddddd-0001-4000-8000-000000000009',
   '[{"etiqueta":"Parte principal","filas":[
       {"ejercicio":"Carrera y caminata por sendero","series":"1","distancia":"24 km","calzado":"Zapatillas","ritmo":"por sensaciones","observaciones":"1.100 m de desnivel positivo. Se camina todo lo que pase del 15 por ciento."},
       {"ejercicio":"Parada de avituallamiento en la fuente","series":"1","distancia":"10 min","observaciones":"Llevar agua para dos horas y algo de comer."}]},
     {"etiqueta":"Bajada técnica","matiz":"Los que quieran","filas":[
       {"ejercicio":"Descenso por el barranco","series":"1","distancia":"3 km","calzado":"Zapatillas","observaciones":"Jorge va delante enseñando dónde pisar. Rocío no baja: se lleva el tobillo con cuidado."}]},
     {"etiqueta":"Vuelta a la calma","filas":[
       {"ejercicio":"Estiramientos y almuerzo","series":"1","distancia":"20 min"}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000048','dddddddd-0002-4000-8000-000000000011','2026-08-05','miércoles','continuo','secundaria',
   'Rodaje suave y técnica de bajada',
   'Después de la tirada del sábado toca soltar piernas. Se aprovecha para trabajar la bajada, que es pura técnica.',
   '19:00','Subida a la Ermita',null,70,true,'dddddddd-0001-4000-8000-000000000009',
   '[{"etiqueta":"Parte inicial","filas":[
       {"ejercicio":"Trote suave","series":"1","distancia":"20 min","calzado":"Zapatillas","ritmo":"cómodo"}]},
     {"etiqueta":"Parte principal","matiz":"Bajada","filas":[
       {"ejercicio":"Descensos por sendero","series":"5","distancia":"500 m de bajada","descanso":"subida andando","calzado":"Zapatillas","observaciones":"Pasos cortos, mirada lejos y brazos abiertos."},
       {"ejercicio":"Bajada con cambios de dirección","series":"3","distancia":"200 m","descanso":"2 min","calzado":"Zapatillas","observaciones":"Ximo y Lidia, que son los que peor bajan."}]},
     {"etiqueta":"Vuelta a la calma","filas":[
       {"ejercicio":"Trote muy suave","series":"1","distancia":"8 min","calzado":"Zapatillas"},
       {"ejercicio":"Estiramientos","series":"1","distancia":"8 min"}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000049','dddddddd-0021-4000-8000-000000000014','2026-07-30','jueves','continuo','calidad_fuerte',
   'Series de desnivel en el Barranc',
   'Series largas cuesta arriba a ritmo de carrera de montaña. Es la sesión que más se parece a competir.',
   '19:00','Barranc del Cint',null,85,true,'dddddddd-0001-4000-8000-000000000009',
   '[{"etiqueta":"Parte inicial","filas":[
       {"ejercicio":"Trote de aproximación","series":"1","distancia":"18 min","calzado":"Zapatillas","ritmo":"cómodo"},
       {"ejercicio":"Progresivos en cuesta","series":"4","distancia":"60 m","descanso":"bajada andando","calzado":"Zapatillas"}]},
     {"etiqueta":"Parte principal","matiz":"Ritmo de carrera","filas":[
       {"ejercicio":"Subida continua","series":"4","distancia":"8 min de subida","descanso":"bajada trotando","calzado":"Zapatillas","ritmo":"ritmo de carrera","observaciones":"Cristo y Quique abren · Rober y Aure a su ritmo · Tania y Ángela cierran"},
       {"ejercicio":"Último minuto de cada serie","series":"4","distancia":"1 min","calzado":"Zapatillas","ritmo":"fuerte","observaciones":"Acabar la subida más fuerte de lo que se empieza."}]},
     {"etiqueta":"Vuelta a la calma","filas":[
       {"ejercicio":"Trote suave de vuelta","series":"1","distancia":"12 min","calzado":"Zapatillas"},
       {"ejercicio":"Estiramientos","series":"1","distancia":"8 min"}]}]'::jsonb),

  ('dddddddd-0042-4000-8000-000000000050','dddddddd-0021-4000-8000-000000000014','2026-08-02','domingo','continuo','calidad_fuerte',
   'Salida larga al Montcabrer',
   'Tirada larga de domingo con la cima como objetivo. Se sale pronto para evitar el calor de agosto.',
   '08:30','Parque Natural de la Font Roja',null,210,true,'dddddddd-0001-4000-8000-000000000009',
   '[{"etiqueta":"Parte principal","filas":[
       {"ejercicio":"Subida al Montcabrer","series":"1","distancia":"14 km","calzado":"Zapatillas","ritmo":"por sensaciones","observaciones":"1.000 m de desnivel positivo. Se camina en las rampas más duras."},
       {"ejercicio":"Parada en la cima","series":"1","distancia":"15 min","observaciones":"Foto de grupo y a reponer."},
       {"ejercicio":"Bajada por la cara norte","series":"1","distancia":"12 km","calzado":"Zapatillas","ritmo":"cómodo","observaciones":"Nadie baja solo. Se espera en cada cruce."}]},
     {"etiqueta":"Vuelta a la calma","filas":[
       {"ejercicio":"Estiramientos y almuerzo en el santuario","series":"1","distancia":"25 min"}]}]'::jsonb)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 9. HORARIOS DE LOS GRUPOS
-- ---------------------------------------------------------------------
-- El calendario ahora tiene más días de los que decía la ficha del grupo.
-- Se ajusta el texto para que cuadre con lo que se ve publicado.
update grupos set horario = 'Martes, jueves y viernes 18:15-19:00 · Piscina cubierta (algún sábado por la mañana)'
 where id = 'dddddddd-0021-4000-8000-000000000007';
update grupos set horario = 'Lunes, miércoles y viernes 19:15-20:30 · Piscina cubierta (controles en sábado)'
 where id = 'dddddddd-0021-4000-8000-000000000008';
update grupos set horario = 'Lunes, miércoles y viernes 21:00-22:00 · Piscina cubierta (un sábado al mes, playa)'
 where id = 'dddddddd-0021-4000-8000-000000000009';
update grupos set horario = 'Miércoles y viernes 21:00 (piscina) y domingos 09:00 (playa, de mayo a septiembre)'
 where id = 'dddddddd-0021-4000-8000-000000000010';
update grupos set horario = 'Martes 19:00 (piscina), jueves o viernes 19:30 (pista) y sábados 08:30 (bici y carrera)'
 where id = 'dddddddd-0002-4000-8000-000000000010';
update grupos set horario = 'Miércoles 19:00 (cuestas) y sábados 08:00 (salida larga) · Punto de encuentro en la Ermita'
 where id = 'dddddddd-0002-4000-8000-000000000011';
update grupos set horario = 'Martes y jueves 17:30-18:15 · Piscina cubierta (una mañana de familias al mes)'
 where id = 'dddddddd-0002-4000-8000-000000000009';

-- ---------------------------------------------------------------------
-- 10. MARCAS DE LOS ATLETAS NUEVOS (45)
-- ---------------------------------------------------------------------
-- Los niños de la escuela de natación no compiten todavía: sus marcas
-- son de los controles de entreno. Los de triatlón y montaña sí llevan
-- marcas de competición.
insert into marcas_atleta (id, atleta_id, prueba, tipo, tiempo_segundos, tiempo_display, fecha, sede, contexto)
values
  -- ---- Escuela de natación ----
  ('dddddddd-0043-4000-8000-000000000001','dddddddd-0041-4000-8000-000000000004','50 m libres','mmp',51.60,'51.60','2026-06-16','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000002','dddddddd-0041-4000-8000-000000000004','50 m espalda','mmp',58.90,'58.90','2026-06-16','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000003','dddddddd-0041-4000-8000-000000000005','50 m libres','mmp',53.20,'53.20','2026-06-16','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000004','dddddddd-0041-4000-8000-000000000006','50 m libres','mmp',47.10,'47.10','2026-06-16','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000005','dddddddd-0041-4000-8000-000000000006','50 m espalda','mmp',55.40,'55.40','2026-06-16','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000006','dddddddd-0041-4000-8000-000000000007','50 m libres','mmp',52.40,'52.40','2026-06-16','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000007','dddddddd-0041-4000-8000-000000000008','50 m libres','temporada',44.30,'44.30','2026-03-10','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000008','dddddddd-0041-4000-8000-000000000008','50 m libres','mmp',41.50,'41.50','2026-06-16','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000009','dddddddd-0041-4000-8000-000000000009','50 m libres','mmp',43.80,'43.80','2026-06-16','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000010','dddddddd-0041-4000-8000-000000000010','50 m libres','mmp',45.90,'45.90','2026-06-16','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000011','dddddddd-0041-4000-8000-000000000001','50 m libres','mmp',68.50,'1:08.50','2026-06-16','Piscina cubierta municipal','entreno'),
  -- ---- Triatlón ----
  ('dddddddd-0043-4000-8000-000000000012','dddddddd-0041-4000-8000-000000000011','1.500 m libres','mmp',1330.00,'22:10.00','2026-05-13','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000013','dddddddd-0041-4000-8000-000000000011','10.000 m','mmp',2090.00,'34:50.00','2026-06-14','Alicante','competicion'),
  ('dddddddd-0043-4000-8000-000000000014','dddddddd-0041-4000-8000-000000000012','800 m libres','mmp',740.00,'12:20.00','2026-05-13','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000015','dddddddd-0041-4000-8000-000000000012','10.000 m','mmp',2530.00,'42:10.00','2026-06-14','Alicante','competicion'),
  ('dddddddd-0043-4000-8000-000000000016','dddddddd-0041-4000-8000-000000000013','400 m libres','mmp',380.00,'6:20.00','2026-05-13','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000017','dddddddd-0041-4000-8000-000000000013','Media maratón','mmp',5920.00,'1:38:40','2026-03-08','Elche','competicion'),
  ('dddddddd-0043-4000-8000-000000000018','dddddddd-0041-4000-8000-000000000014','400 m libres','mmp',322.50,'5:22.50','2026-05-13','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000019','dddddddd-0041-4000-8000-000000000014','5.000 m','mmp',1150.00,'19:10.00','2026-04-11','Petrer','competicion'),
  ('dddddddd-0043-4000-8000-000000000020','dddddddd-0041-4000-8000-000000000015','1.500 m libres','mmp',1195.00,'19:55.00','2026-05-13','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000021','dddddddd-0041-4000-8000-000000000015','5.000 m','mmp',1025.00,'17:05.00','2026-04-11','Petrer','competicion'),
  ('dddddddd-0043-4000-8000-000000000022','dddddddd-0041-4000-8000-000000000016','800 m libres','mmp',820.00,'13:40.00','2026-05-13','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000023','dddddddd-0041-4000-8000-000000000016','Media maratón','mmp',6750.00,'1:52:30','2026-03-08','Elche','competicion'),
  ('dddddddd-0043-4000-8000-000000000024','dddddddd-0041-4000-8000-000000000017','1.500 m libres','mmp',1230.00,'20:30.00','2026-05-13','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000025','dddddddd-0041-4000-8000-000000000017','10.000 m','mmp',2180.00,'36:20.00','2026-06-14','Alicante','competicion'),
  ('dddddddd-0043-4000-8000-000000000026','dddddddd-0041-4000-8000-000000000018','400 m libres','mmp',348.00,'5:48.00','2026-05-13','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000027','dddddddd-0041-4000-8000-000000000018','10.000 m','mmp',2670.00,'44:30.00','2026-06-14','Alicante','competicion'),
  ('dddddddd-0043-4000-8000-000000000028','dddddddd-0041-4000-8000-000000000019','400 m libres','mmp',365.00,'6:05.00','2026-05-13','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000029','dddddddd-0041-4000-8000-000000000019','Media maratón','mmp',6320.00,'1:45:20','2026-03-08','Elche','competicion'),
  ('dddddddd-0043-4000-8000-000000000030','dddddddd-0041-4000-8000-000000000020','800 m libres','mmp',700.00,'11:40.00','2026-05-13','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000031','dddddddd-0041-4000-8000-000000000020','5.000 m','mmp',1240.00,'20:40.00','2026-04-11','Petrer','competicion'),
  ('dddddddd-0043-4000-8000-000000000032','dddddddd-0041-4000-8000-000000000021','400 m libres','mmp',400.00,'6:40.00','2026-07-15','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000033','dddddddd-0041-4000-8000-000000000021','10.000 m','mmp',2460.00,'41:00.00','2026-06-14','Alicante','competicion'),
  ('dddddddd-0043-4000-8000-000000000034','dddddddd-0041-4000-8000-000000000022','800 m libres','mmp',860.00,'14:20.00','2026-05-13','Piscina cubierta municipal','entreno'),
  ('dddddddd-0043-4000-8000-000000000035','dddddddd-0041-4000-8000-000000000022','Media maratón','mmp',7275.00,'2:01:15','2026-03-08','Elche','competicion'),
  -- ---- Montaña ----
  ('dddddddd-0043-4000-8000-000000000036','dddddddd-0041-4000-8000-000000000023','Maratón','mmp',12160.00,'3:22:40','2025-12-07','Valencia','competicion'),
  ('dddddddd-0043-4000-8000-000000000037','dddddddd-0041-4000-8000-000000000024','Media maratón','mmp',6490.00,'1:48:10','2026-05-10','Alicante','competicion'),
  ('dddddddd-0043-4000-8000-000000000038','dddddddd-0041-4000-8000-000000000025','Maratón','mmp',11330.00,'3:08:50','2025-12-07','Valencia','competicion'),
  ('dddddddd-0043-4000-8000-000000000039','dddddddd-0041-4000-8000-000000000025','Media maratón','mmp',5380.00,'1:29:40','2026-05-10','Alicante','competicion'),
  ('dddddddd-0043-4000-8000-000000000040','dddddddd-0041-4000-8000-000000000026','Media maratón','mmp',7100.00,'1:58:20','2026-05-10','Alicante','competicion'),
  ('dddddddd-0043-4000-8000-000000000041','dddddddd-0041-4000-8000-000000000027','Maratón','mmp',13290.00,'3:41:30','2025-12-07','Valencia','competicion'),
  ('dddddddd-0043-4000-8000-000000000042','dddddddd-0041-4000-8000-000000000027','10.000 m','mmp',2355.00,'39:15.00','2026-06-14','Alicante','competicion'),
  -- ---- Objetivos de temporada ----
  ('dddddddd-0043-4000-8000-000000000043','dddddddd-0041-4000-8000-000000000011','10.000 m','objetivo',2040.00,'34:00.00','2026-09-27','Objetivo de temporada',null),
  ('dddddddd-0043-4000-8000-000000000044','dddddddd-0041-4000-8000-000000000023','Maratón','objetivo',11700.00,'3:15:00','2026-12-06','Objetivo de temporada',null),
  ('dddddddd-0043-4000-8000-000000000045','dddddddd-0041-4000-8000-000000000008','50 m libres','objetivo',39.00,'39.00','2026-10-17','Objetivo de temporada',null)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 11. PAGOS DE LOS ATLETAS NUEVOS (47)
-- ---------------------------------------------------------------------
-- El número de recibo lo pone la propia base de datos al guardar un
-- pago en estado «pagado», así que aquí no se escribe. Por eso el
-- insert lleva un «where not exists»: si el pago ya está, ni se intenta
-- y no se gasta un número de recibo de más.
insert into pagos (id, atleta_id, concepto, importe, estado, fecha_vencimiento, fecha_pago, metodo, periodo, cuenta)
select v.id, v.atleta_id, v.concepto, v.importe, v.estado, v.venc, v.pago, v.metodo, v.periodo, v.cuenta
from (values
  -- ---- Escuela de natación · trimestre abril-junio ----
  ('dddddddd-0044-4000-8000-000000000001'::uuid,'dddddddd-0041-4000-8000-000000000001'::uuid,'Cuota trimestral abril-junio 2026',90.00::numeric,'pagado','2026-04-05'::date,'2026-04-07'::date,'domiciliado','2026-04','escuela'),
  ('dddddddd-0044-4000-8000-000000000002'::uuid,'dddddddd-0041-4000-8000-000000000002'::uuid,'Cuota trimestral abril-junio 2026',90.00::numeric,'pagado','2026-04-05'::date,'2026-04-07'::date,'domiciliado','2026-04','escuela'),
  ('dddddddd-0044-4000-8000-000000000003'::uuid,'dddddddd-0041-4000-8000-000000000004'::uuid,'Cuota trimestral abril-junio 2026',90.00::numeric,'pagado','2026-04-05'::date,'2026-04-09'::date,'transferencia','2026-04','escuela'),
  ('dddddddd-0044-4000-8000-000000000004'::uuid,'dddddddd-0041-4000-8000-000000000006'::uuid,'Cuota trimestral abril-junio 2026',90.00::numeric,'pagado','2026-04-05'::date,'2026-04-07'::date,'domiciliado','2026-04','escuela'),
  ('dddddddd-0044-4000-8000-000000000005'::uuid,'dddddddd-0041-4000-8000-000000000008'::uuid,'Cuota trimestral abril-junio 2026',90.00::numeric,'pagado','2026-04-05'::date,'2026-04-07'::date,'domiciliado','2026-04','escuela'),
  ('dddddddd-0044-4000-8000-000000000006'::uuid,'dddddddd-0041-4000-8000-000000000009'::uuid,'Cuota trimestral abril-junio 2026',90.00::numeric,'pagado','2026-04-05'::date,'2026-04-14'::date,'efectivo','2026-04','escuela'),
  -- ---- Escuela de natación · trimestre julio-septiembre ----
  ('dddddddd-0044-4000-8000-000000000007'::uuid,'dddddddd-0041-4000-8000-000000000001'::uuid,'Cuota trimestral julio-septiembre 2026',90.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','escuela'),
  ('dddddddd-0044-4000-8000-000000000008'::uuid,'dddddddd-0041-4000-8000-000000000002'::uuid,'Cuota trimestral julio-septiembre 2026',90.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','escuela'),
  ('dddddddd-0044-4000-8000-000000000009'::uuid,'dddddddd-0041-4000-8000-000000000003'::uuid,'Cuota trimestral julio-septiembre 2026',90.00::numeric,'pagado','2026-07-05'::date,'2026-07-10'::date,'transferencia','2026-07','escuela'),
  ('dddddddd-0044-4000-8000-000000000010'::uuid,'dddddddd-0041-4000-8000-000000000004'::uuid,'Cuota trimestral julio-septiembre 2026',90.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','escuela'),
  ('dddddddd-0044-4000-8000-000000000011'::uuid,'dddddddd-0041-4000-8000-000000000005'::uuid,'Cuota trimestral julio-septiembre 2026',90.00::numeric,'pendiente','2026-07-05'::date,null::date,null,'2026-07','escuela'),
  ('dddddddd-0044-4000-8000-000000000012'::uuid,'dddddddd-0041-4000-8000-000000000006'::uuid,'Cuota trimestral julio-septiembre 2026',90.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','escuela'),
  ('dddddddd-0044-4000-8000-000000000013'::uuid,'dddddddd-0041-4000-8000-000000000007'::uuid,'Cuota trimestral julio-septiembre 2026',90.00::numeric,'impagado','2026-07-05'::date,null::date,'domiciliado','2026-07','escuela'),
  ('dddddddd-0044-4000-8000-000000000014'::uuid,'dddddddd-0041-4000-8000-000000000008'::uuid,'Cuota trimestral julio-septiembre 2026',90.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','escuela'),
  ('dddddddd-0044-4000-8000-000000000015'::uuid,'dddddddd-0041-4000-8000-000000000009'::uuid,'Cuota trimestral julio-septiembre 2026',90.00::numeric,'pagado','2026-07-05'::date,'2026-07-13'::date,'efectivo','2026-07','escuela'),
  ('dddddddd-0044-4000-8000-000000000016'::uuid,'dddddddd-0041-4000-8000-000000000010'::uuid,'Cuota trimestral julio-septiembre 2026',90.00::numeric,'pendiente','2026-08-05'::date,null::date,null,'2026-08','escuela'),
  -- ---- Triatlón · licencia federativa ----
  ('dddddddd-0044-4000-8000-000000000017'::uuid,'dddddddd-0041-4000-8000-000000000011'::uuid,'Licencia federativa temporada 2026',45.00::numeric,'pagado','2026-01-15'::date,'2026-01-16'::date,'transferencia','2026-01','club'),
  ('dddddddd-0044-4000-8000-000000000018'::uuid,'dddddddd-0041-4000-8000-000000000012'::uuid,'Licencia federativa temporada 2026',45.00::numeric,'pagado','2026-01-15'::date,'2026-01-16'::date,'transferencia','2026-01','club'),
  ('dddddddd-0044-4000-8000-000000000019'::uuid,'dddddddd-0041-4000-8000-000000000013'::uuid,'Licencia federativa temporada 2026',45.00::numeric,'pagado','2026-01-15'::date,'2026-01-18'::date,'tarjeta','2026-01','club'),
  ('dddddddd-0044-4000-8000-000000000020'::uuid,'dddddddd-0041-4000-8000-000000000014'::uuid,'Licencia federativa temporada 2026',45.00::numeric,'pagado','2026-01-15'::date,'2026-01-16'::date,'transferencia','2026-01','club'),
  ('dddddddd-0044-4000-8000-000000000021'::uuid,'dddddddd-0041-4000-8000-000000000015'::uuid,'Licencia federativa temporada 2026',45.00::numeric,'pagado','2026-01-15'::date,'2026-01-16'::date,'transferencia','2026-01','club'),
  ('dddddddd-0044-4000-8000-000000000022'::uuid,'dddddddd-0041-4000-8000-000000000016'::uuid,'Licencia federativa temporada 2026',45.00::numeric,'pagado','2026-01-15'::date,'2026-01-20'::date,'efectivo','2026-01','club'),
  ('dddddddd-0044-4000-8000-000000000023'::uuid,'dddddddd-0041-4000-8000-000000000017'::uuid,'Licencia federativa temporada 2026',45.00::numeric,'pagado','2026-01-15'::date,'2026-01-16'::date,'transferencia','2026-01','club'),
  ('dddddddd-0044-4000-8000-000000000024'::uuid,'dddddddd-0041-4000-8000-000000000018'::uuid,'Licencia federativa temporada 2026',45.00::numeric,'pagado','2026-01-15'::date,'2026-01-16'::date,'transferencia','2026-01','club'),
  ('dddddddd-0044-4000-8000-000000000025'::uuid,'dddddddd-0041-4000-8000-000000000019'::uuid,'Licencia federativa temporada 2026',45.00::numeric,'pagado','2026-01-15'::date,'2026-01-17'::date,'tarjeta','2026-01','club'),
  ('dddddddd-0044-4000-8000-000000000026'::uuid,'dddddddd-0041-4000-8000-000000000020'::uuid,'Licencia federativa temporada 2026',45.00::numeric,'pagado','2026-01-15'::date,'2026-01-16'::date,'transferencia','2026-01','club'),
  ('dddddddd-0044-4000-8000-000000000027'::uuid,'dddddddd-0041-4000-8000-000000000022'::uuid,'Licencia federativa temporada 2026',45.00::numeric,'pagado','2026-01-15'::date,'2026-01-22'::date,'efectivo','2026-01','club'),
  -- ---- Triatlón · trimestre julio-septiembre ----
  ('dddddddd-0044-4000-8000-000000000028'::uuid,'dddddddd-0041-4000-8000-000000000011'::uuid,'Cuota trimestral julio-septiembre 2026',120.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000029'::uuid,'dddddddd-0041-4000-8000-000000000012'::uuid,'Cuota trimestral julio-septiembre 2026',120.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000030'::uuid,'dddddddd-0041-4000-8000-000000000013'::uuid,'Cuota trimestral julio-septiembre 2026',120.00::numeric,'pagado','2026-07-05'::date,'2026-07-09'::date,'transferencia','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000031'::uuid,'dddddddd-0041-4000-8000-000000000014'::uuid,'Cuota trimestral julio-septiembre 2026',120.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000032'::uuid,'dddddddd-0041-4000-8000-000000000015'::uuid,'Cuota trimestral julio-septiembre 2026',120.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000033'::uuid,'dddddddd-0041-4000-8000-000000000016'::uuid,'Cuota trimestral julio-septiembre 2026',120.00::numeric,'pendiente','2026-07-05'::date,null::date,null,'2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000034'::uuid,'dddddddd-0041-4000-8000-000000000017'::uuid,'Cuota trimestral julio-septiembre 2026',120.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000035'::uuid,'dddddddd-0041-4000-8000-000000000018'::uuid,'Cuota trimestral julio-septiembre 2026',120.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000036'::uuid,'dddddddd-0041-4000-8000-000000000019'::uuid,'Cuota trimestral julio-septiembre 2026',120.00::numeric,'impagado','2026-07-05'::date,null::date,'domiciliado','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000037'::uuid,'dddddddd-0041-4000-8000-000000000020'::uuid,'Cuota trimestral julio-septiembre 2026',120.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000038'::uuid,'dddddddd-0041-4000-8000-000000000021'::uuid,'Cuota de prueba · un mes',40.00::numeric,'pagado','2026-07-20'::date,'2026-07-20'::date,'efectivo','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000039'::uuid,'dddddddd-0041-4000-8000-000000000022'::uuid,'Cuota trimestral julio-septiembre 2026',120.00::numeric,'pendiente','2026-07-05'::date,null::date,null,'2026-07','club'),
  -- ---- Montaña ----
  ('dddddddd-0044-4000-8000-000000000040'::uuid,'dddddddd-0041-4000-8000-000000000023'::uuid,'Cuota trimestral abril-junio 2026',75.00::numeric,'pagado','2026-04-05'::date,'2026-04-07'::date,'domiciliado','2026-04','club'),
  ('dddddddd-0044-4000-8000-000000000041'::uuid,'dddddddd-0041-4000-8000-000000000025'::uuid,'Cuota trimestral abril-junio 2026',75.00::numeric,'pagado','2026-04-05'::date,'2026-04-07'::date,'domiciliado','2026-04','club'),
  ('dddddddd-0044-4000-8000-000000000042'::uuid,'dddddddd-0041-4000-8000-000000000027'::uuid,'Cuota trimestral abril-junio 2026',75.00::numeric,'pagado','2026-04-05'::date,'2026-04-11'::date,'transferencia','2026-04','club'),
  ('dddddddd-0044-4000-8000-000000000043'::uuid,'dddddddd-0041-4000-8000-000000000023'::uuid,'Cuota trimestral julio-septiembre 2026',75.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000044'::uuid,'dddddddd-0041-4000-8000-000000000024'::uuid,'Cuota trimestral julio-septiembre 2026',75.00::numeric,'pagado','2026-07-05'::date,'2026-07-07'::date,'domiciliado','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000045'::uuid,'dddddddd-0041-4000-8000-000000000025'::uuid,'Cuota trimestral julio-septiembre 2026',75.00::numeric,'pagado','2026-07-05'::date,'2026-07-12'::date,'transferencia','2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000046'::uuid,'dddddddd-0041-4000-8000-000000000026'::uuid,'Cuota trimestral julio-septiembre 2026',75.00::numeric,'pendiente','2026-07-05'::date,null::date,null,'2026-07','club'),
  ('dddddddd-0044-4000-8000-000000000047'::uuid,'dddddddd-0041-4000-8000-000000000027'::uuid,'Cuota trimestral julio-septiembre 2026',75.00::numeric,'impagado','2026-07-05'::date,null::date,'domiciliado','2026-07','club')
) as v(id, atleta_id, concepto, importe, estado, venc, pago, metodo, periodo, cuenta)
where not exists (select 1 from pagos p where p.id = v.id);

commit;

-- =====================================================================
-- Comprobación rápida de cómo queda cada sección
-- =====================================================================
select g.seccion,
       count(distinct g.id)                                   as grupos,
       count(distinct a.id)                                   as atletas,
       count(distinct s.id) filter (where s.publicada
             and s.fecha between '2026-07-20' and '2026-08-09') as sesiones_3_semanas
  from grupos g
  left join atletas  a on a.grupo_id = g.id
  left join sesiones s on s.grupo_id = g.id
 group by g.seccion
 order by g.seccion;
