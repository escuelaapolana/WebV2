-- =====================================================================
-- 900_datos_demo.sql  ·  DATOS DE DEMOSTRACIÓN DEL CLUB (FICTICIOS)
-- =====================================================================
-- Para qué sirve: dejar la base de datos llena de un club inventado pero
-- realista (grupos, entrenadores, atletas, entrenamientos, marcas, pagos,
-- competiciones, avisos, El Cubo…) para poder probar la web de verdad.
--
-- TODO lo que crea este archivo lleva un identificador que empieza por
-- «dddddddd-». Nada más. Por eso se puede borrar de un golpe con
-- 901_borrar_datos_demo.sql sin tocar los datos reales del club.
--
-- Se puede lanzar las veces que haga falta: si ya está, no duplica nada.
--
-- Cómo se lanza:   bash .secrets/psql.sh -f migraciones/900_datos_demo.sql
-- Cómo se borra:   bash .secrets/psql.sh -f migraciones/901_borrar_datos_demo.sql
--
-- Fecha de referencia de los entrenamientos: 31 de julio de 2026.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. ENTRENADORES FICTICIOS
-- ---------------------------------------------------------------------
-- La tabla de perfiles cuelga de las cuentas de acceso, así que hay que
-- crear antes la cuenta. Se crean SIN contraseña y SIN forma de entrar:
-- son fichas de entrenador, no usuarios que puedan iniciar sesión.
insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
values
  ('dddddddd-0001-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','marta.ibanez@demo.apolana.test', now(), now()),
  ('dddddddd-0001-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','sergio.delgado@demo.apolana.test', now(), now()),
  ('dddddddd-0001-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','nuria.castano@demo.apolana.test', now(), now()),
  ('dddddddd-0001-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','alvaro.penalver@demo.apolana.test', now(), now()),
  ('dddddddd-0001-4000-8000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','cristina.herrero@demo.apolana.test', now(), now()),
  ('dddddddd-0001-4000-8000-000000000006','00000000-0000-0000-0000-000000000000','authenticated','authenticated','javier.montes@demo.apolana.test', now(), now()),
  ('dddddddd-0001-4000-8000-000000000007','00000000-0000-0000-0000-000000000000','authenticated','authenticated','lucia.sanchis@demo.apolana.test', now(), now()),
  ('dddddddd-0001-4000-8000-000000000008','00000000-0000-0000-0000-000000000000','authenticated','authenticated','ruben.ortega@demo.apolana.test', now(), now()),
  ('dddddddd-0001-4000-8000-000000000009','00000000-0000-0000-0000-000000000000','authenticated','authenticated','elena.vidal@demo.apolana.test', now(), now()),
  ('dddddddd-0001-4000-8000-000000000010','00000000-0000-0000-0000-000000000000','authenticated','authenticated','diego.marin@demo.apolana.test', now(), now())
on conflict (id) do nothing;

-- El alta de la cuenta crea una ficha de perfil en blanco: aquí se completa.
insert into perfiles (id, nombre, apellidos, email, telefono, rol, seccion, activo)
values
  ('dddddddd-0001-4000-8000-000000000001','Marta','Ibáñez Ruiz','marta.ibanez@demo.apolana.test','600 100 001','entrenador','competicion', true),
  ('dddddddd-0001-4000-8000-000000000002','Sergio','Delgado Marín','sergio.delgado@demo.apolana.test','600 100 002','entrenador','competicion', true),
  ('dddddddd-0001-4000-8000-000000000003','Nuria','Castaño Vega','nuria.castano@demo.apolana.test','600 100 003','entrenador','competicion', true),
  ('dddddddd-0001-4000-8000-000000000004','Álvaro','Peñalver Gil','alvaro.penalver@demo.apolana.test','600 100 004','entrenador','running', true),
  ('dddddddd-0001-4000-8000-000000000005','Cristina','Herrero Lozano','cristina.herrero@demo.apolana.test','600 100 005','entrenador','running', true),
  ('dddddddd-0001-4000-8000-000000000006','Javier','Montes Aranda','javier.montes@demo.apolana.test','600 100 006','entrenador','escuela', true),
  ('dddddddd-0001-4000-8000-000000000007','Lucía','Sanchís Moreno','lucia.sanchis@demo.apolana.test','600 100 007','entrenador','natacion', true),
  ('dddddddd-0001-4000-8000-000000000008','Rubén','Ortega Salas','ruben.ortega@demo.apolana.test','600 100 008','entrenador','triatlon', true),
  ('dddddddd-0001-4000-8000-000000000009','Elena','Vidal Campos','elena.vidal@demo.apolana.test','600 100 009','entrenador','running', true),
  ('dddddddd-0001-4000-8000-000000000010','Diego','Marín Ferrer','diego.marin@demo.apolana.test','600 100 010','entrenador','gimnasio', true)
on conflict (id) do update set
  nombre = excluded.nombre, apellidos = excluded.apellidos, email = excluded.email,
  telefono = excluded.telefono, rol = excluded.rol, seccion = excluded.seccion, activo = true;

-- ---------------------------------------------------------------------
-- 2. GRUPOS DE TODAS LAS SECCIONES
-- ---------------------------------------------------------------------
insert into grupos (id, nombre, seccion, entrenador_id, horario, descripcion, activo)
values
  ('dddddddd-0002-4000-8000-000000000001','Velocidad A','competicion','dddddddd-0001-4000-8000-000000000001','Lunes, martes, jueves y viernes 19:00-21:00 · Estadio Joaquín Villar','Grupo de rendimiento de velocidad y vallas, de Sub-18 en adelante. Trabajo de pista, gimnasio y competición federada.', true),
  ('dddddddd-0002-4000-8000-000000000002','Velocidad B','competicion','dddddddd-0001-4000-8000-000000000002','Martes y jueves 18:30-20:00 · Estadio Joaquín Villar','Grupo de formación en velocidad y vallas para Sub-16 y Sub-18. Mucha técnica y trabajo multilateral.', true),
  ('dddddddd-0002-4000-8000-000000000003','Fondo y medio fondo','competicion','dddddddd-0001-4000-8000-000000000003','Lunes, miércoles y viernes 19:30-21:00 · Pista y Pantano','Del 800 al 10.000. Series en pista, rodajes largos y cross en invierno.', true),
  ('dddddddd-0002-4000-8000-000000000004','La Tribu','running','dddddddd-0001-4000-8000-000000000004','Martes y jueves 20:00-21:15 · Salida desde el Parque Municipal','Grupo de running popular para adultos que ya corren de forma habitual. Preparación de 10K, media y maratón.', true),
  ('dddddddd-0002-4000-8000-000000000005','Madre Tierra','running','dddddddd-0001-4000-8000-000000000005','Miércoles 19:00-20:15 y sábados 09:30 · Vía Verde','Grupo de running femenino, ambiente tranquilo y ritmos cómodos. Iniciación y vuelta a la carrera.', true),
  ('dddddddd-0002-4000-8000-000000000006','Escuela Grupo 1','escuela','dddddddd-0001-4000-8000-000000000006','Martes y jueves 17:30-18:45 · Pista municipal','Escuela de atletismo para Sub-12 y Sub-14. Iniciación a las carreras, saltos y lanzamientos.', true),
  ('dddddddd-0002-4000-8000-000000000007','Escuela Grupo 2','escuela','dddddddd-0001-4000-8000-000000000006','Martes y jueves 17:00-18:00 · Pista municipal','Los más pequeños de la escuela. Juego, coordinación y descubrir el atletismo.', true),
  ('dddddddd-0002-4000-8000-000000000008','Natación · Perfeccionamiento','natacion','dddddddd-0001-4000-8000-000000000007','Lunes, miércoles y viernes 18:00-19:15 · Piscina cubierta','Nadadores que ya dominan los cuatro estilos y quieren competir. Trabajo por calles y por series.', true),
  ('dddddddd-0002-4000-8000-000000000009','Escuela de natación','escuela-natacion','dddddddd-0001-4000-8000-000000000007','Martes y jueves 17:30-18:15 · Piscina cubierta','Aprender a nadar y perder el miedo al agua. Grupos reducidos por nivel.', true),
  ('dddddddd-0002-4000-8000-000000000010','Triatlón','triatlon','dddddddd-0001-4000-8000-000000000008','Miércoles 19:00 (piscina) y sábados 08:30 (bici y carrera)','Sección de triatlón: natación, ciclismo y carrera a pie, con transiciones y competición por equipos.', true),
  ('dddddddd-0002-4000-8000-000000000011','Montaña','montana','dddddddd-0001-4000-8000-000000000009','Sábados 08:00 · Punto de encuentro en la Ermita','Trail y montaña. Salidas largas de fin de semana y trabajo de cuestas entre semana.', true),
  ('dddddddd-0002-4000-8000-000000000012','El Cubo','cubo','dddddddd-0001-4000-8000-000000000010','De lunes a viernes, clases de 09:00 a 21:00 · El Cubo','Sala de entrenamiento funcional del club. Clases con plaza limitada y reserva por bonos.', true)
on conflict (id) do update set
  nombre = excluded.nombre, seccion = excluded.seccion, entrenador_id = excluded.entrenador_id,
  horario = excluded.horario, descripcion = excluded.descripcion, activo = true;

-- ---------------------------------------------------------------------
-- 3. ATLETAS (59)
-- ---------------------------------------------------------------------
-- La categoría va según el año de nacimiento (criterio RFEA de la web).
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
values
  -- ---- Velocidad A ----
  ('dddddddd-0003-4000-8000-000000000001','Rafael','Nieto Sanchís','Rafa','2007-03-14','Sub-23','activo','dddddddd-0002-4000-8000-000000000001','dddddddd-0001-4000-8000-000000000001', array['400 m vallas','400 m lisos'],'A-24001', true,'Referencia del grupo en 400 mv. Ataca con la izquierda.'),
  ('dddddddd-0003-4000-8000-000000000002','Adrián','Molina Casals','Adri','2008-05-22','Sub-20','activo','dddddddd-0002-4000-8000-000000000001','dddddddd-0001-4000-8000-000000000001', array['400 m vallas','300 m lisos'],'A-24002', true,'Trabaja el paso a 15 zancadas entre vallas.'),
  ('dddddddd-0003-4000-8000-000000000003','Rubén','Tomás Bautista','Rubén','2008-11-02','Sub-20','activo','dddddddd-0002-4000-8000-000000000001','dddddddd-0001-4000-8000-000000000001', array['400 m lisos','200 m lisos'],'A-24003', true, null),
  ('dddddddd-0003-4000-8000-000000000004','Dante','Ferrándiz Roca','Dante','2009-01-30','Sub-20','activo','dddddddd-0002-4000-8000-000000000001','dddddddd-0001-4000-8000-000000000001', array['400 m lisos','800 m'],'A-24004', true,'Viene del medio fondo, aún le falta velocidad de salida.'),
  ('dddddddd-0003-4000-8000-000000000005','Claudia','Bermejo Ortiz','Claudia','2006-06-11','Sub-23','activo','dddddddd-0002-4000-8000-000000000001','dddddddd-0001-4000-8000-000000000001', array['100 m lisos','200 m lisos'],'A-24005', true, null),
  ('dddddddd-0003-4000-8000-000000000006','Marina','Escudero Peláez','Marina','2010-04-08','Sub-18','activo','dddddddd-0002-4000-8000-000000000001','dddddddd-0001-4000-8000-000000000001', array['60 m lisos','100 m lisos','Salto de longitud'],'A-24006', true,'Multidisciplina: velocidad y longitud.'),
  ('dddddddd-0003-4000-8000-000000000007','Iván','Redondo Cabezas','Iván','2004-09-19','Absoluto','lesionado','dddddddd-0002-4000-8000-000000000001','dddddddd-0001-4000-8000-000000000001', array['100 m lisos','Salto de longitud'],'A-24007', true,'Elongación en el isquiotibial derecho. En readaptación.'),
  ('dddddddd-0003-4000-8000-000000000008','Paula','Quintana Vives','Paula','2011-02-17','Sub-18','prueba','dddddddd-0002-4000-8000-000000000001','dddddddd-0001-4000-8000-000000000001', array['100 m lisos','Salto de longitud'], null, true,'Viene de la escuela municipal, un mes de prueba.'),
  -- ---- Velocidad B ----
  ('dddddddd-0003-4000-8000-000000000009','Héctor','Salvador Nadal','Héctor','2011-07-05','Sub-18','activo','dddddddd-0002-4000-8000-000000000002','dddddddd-0001-4000-8000-000000000002', array['110 m vallas','100 m lisos'],'A-24009', true,'Multidisciplina: vallas y velocidad.'),
  ('dddddddd-0003-4000-8000-000000000010','Lucía','Arribas Cuenca','Lucía','2012-03-21','Sub-16','activo','dddddddd-0002-4000-8000-000000000002','dddddddd-0001-4000-8000-000000000002', array['100 m vallas','60 m vallas'],'A-24010', false, null),
  ('dddddddd-0003-4000-8000-000000000011','Mario','Peiró Estévez','Mario','2012-10-09','Sub-16','activo','dddddddd-0002-4000-8000-000000000002','dddddddd-0001-4000-8000-000000000002', array['60 m vallas','60 m lisos'],'A-24011', false,'Multidisciplina: vallas y velocidad corta.'),
  ('dddddddd-0003-4000-8000-000000000012','Sara','Company Bailón','Sara','2013-05-30','Sub-16','activo','dddddddd-0002-4000-8000-000000000002','dddddddd-0001-4000-8000-000000000002', array['60 m lisos','Salto de longitud'],'A-24012', false,'Multidisciplina: velocidad y longitud.'),
  ('dddddddd-0003-4000-8000-000000000013','Gonzalo','Serrano Iglesias','Gonzalo','2010-12-12','Sub-18','activo','dddddddd-0002-4000-8000-000000000002','dddddddd-0001-4000-8000-000000000002', array['110 m vallas','Salto de altura'],'A-24013', true,'Multidisciplina: vallas y altura.'),
  ('dddddddd-0003-4000-8000-000000000014','Alba','Redó Montalbán','Alba','2011-09-25','Sub-18','activo','dddddddd-0002-4000-8000-000000000002','dddddddd-0001-4000-8000-000000000002', array['300 m lisos','400 m lisos'],'A-24014', true, null),
  ('dddddddd-0003-4000-8000-000000000015','Nicolás','Barreda Fuster','Nico','2013-01-18','Sub-16','prueba','dddddddd-0002-4000-8000-000000000002','dddddddd-0001-4000-8000-000000000002', array['60 m lisos'], null, false,'Dos semanas de prueba. Viene del fútbol.'),
  -- ---- Fondo y medio fondo ----
  ('dddddddd-0003-4000-8000-000000000016','Elena','Pardo Villaescusa','Elena','2005-04-02','Sub-23','activo','dddddddd-0002-4000-8000-000000000003','dddddddd-0001-4000-8000-000000000003', array['1.500 m','800 m'],'A-24016', true, null),
  ('dddddddd-0003-4000-8000-000000000017','Jorge','Alcántara Ripoll','Jorge','2003-08-14','Absoluto','activo','dddddddd-0002-4000-8000-000000000003','dddddddd-0001-4000-8000-000000000003', array['5.000 m','3.000 m obstáculos'],'A-24017', true,'Multidisciplina: fondo y obstáculos.'),
  ('dddddddd-0003-4000-8000-000000000018','Marta','Cebrián Lillo','Marta','2007-02-26','Sub-23','activo','dddddddd-0002-4000-8000-000000000003','dddddddd-0001-4000-8000-000000000003', array['800 m','1.500 m'],'A-24018', true, null),
  ('dddddddd-0003-4000-8000-000000000019','Álvaro','Ferrer Bonet','Álvaro','2009-06-07','Sub-20','activo','dddddddd-0002-4000-8000-000000000003','dddddddd-0001-4000-8000-000000000003', array['3.000 m','1.500 m'],'A-24019', false, null),
  ('dddddddd-0003-4000-8000-000000000020','Noelia','Gascó Tordera','Noelia','2010-10-21','Sub-18','activo','dddddddd-0002-4000-8000-000000000003','dddddddd-0001-4000-8000-000000000003', array['1.000 m','800 m'],'A-24020', false, null),
  ('dddddddd-0003-4000-8000-000000000021','Óscar','Villalba Peris','Óscar','1998-05-16','Absoluto','activo','dddddddd-0002-4000-8000-000000000003','dddddddd-0001-4000-8000-000000000003', array['10.000 m','Media maratón'],'A-24021', true, null),
  -- ---- La Tribu (running) ----
  ('dddddddd-0003-4000-8000-000000000022','Fernando','Belmonte Cases','Fernando','1985-03-09','Máster','activo','dddddddd-0002-4000-8000-000000000004','dddddddd-0001-4000-8000-000000000004', array['Media maratón','10.000 m'],'A-24022', false, null),
  ('dddddddd-0003-4000-8000-000000000023','Rosa María','Aguilar Tébar','Rosa','1979-11-27','Máster','activo','dddddddd-0002-4000-8000-000000000004','dddddddd-0001-4000-8000-000000000004', array['Maratón','Media maratón'],'A-24023', false,'Prepara el maratón de Valencia.'),
  ('dddddddd-0003-4000-8000-000000000024','Ignacio','Pastor Quiles','Nacho','1990-07-13','Máster','activo','dddddddd-0002-4000-8000-000000000004','dddddddd-0001-4000-8000-000000000004', array['10.000 m','5.000 m'],'A-24024', true, null),
  ('dddddddd-0003-4000-8000-000000000025','Beatriz','Solano Merino','Bea','1994-01-05','Absoluto','activo','dddddddd-0002-4000-8000-000000000004','dddddddd-0001-4000-8000-000000000004', array['Media maratón'],'A-24025', false, null),
  ('dddddddd-0003-4000-8000-000000000026','David','Chulvi Ferrando','David','1988-09-02','Máster','baja','dddddddd-0002-4000-8000-000000000004','dddddddd-0001-4000-8000-000000000004', array['Maratón'],'A-24026', false,'Baja voluntaria por traslado de trabajo.'),
  -- ---- Madre Tierra (running) ----
  ('dddddddd-0003-4000-8000-000000000027','Amparo','Tarazona Gimeno','Amparo','1976-06-18','Máster','activo','dddddddd-0002-4000-8000-000000000005','dddddddd-0001-4000-8000-000000000005', array['10.000 m'],'A-24027', false, null),
  ('dddddddd-0003-4000-8000-000000000028','Silvia','Renau Cardona','Silvia','1983-02-11','Máster','activo','dddddddd-0002-4000-8000-000000000005','dddddddd-0001-4000-8000-000000000005', array['Media maratón','10.000 m'],'A-24028', false, null),
  ('dddddddd-0003-4000-8000-000000000029','Pilar','Monzó Ballester','Pilar','1991-12-03','Máster','activo','dddddddd-0002-4000-8000-000000000005','dddddddd-0001-4000-8000-000000000005', array['5.000 m'],'A-24029', false, null),
  ('dddddddd-0003-4000-8000-000000000030','Teresa','Andrés Vilaplana','Tere','1996-08-24','Absoluto','activo','dddddddd-0002-4000-8000-000000000005','dddddddd-0001-4000-8000-000000000005', array['10.000 m'],'A-24030', false, null),
  ('dddddddd-0003-4000-8000-000000000031','Encarna','Doménech Piera','Encarna','1970-04-30','Máster','activo','dddddddd-0002-4000-8000-000000000005','dddddddd-0001-4000-8000-000000000005', array['5.000 m'],'A-24031', false,'Vuelve a correr tras dos años parada.'),
  -- ---- Escuela Grupo 1 ----
  ('dddddddd-0003-4000-8000-000000000032','Hugo','Balaguer Sempere','Hugo','2014-05-19','Sub-14','activo','dddddddd-0002-4000-8000-000000000006','dddddddd-0001-4000-8000-000000000006', array['60 m lisos','Salto de longitud'],'A-24032', false,'Multidisciplina: velocidad y longitud.'),
  ('dddddddd-0003-4000-8000-000000000033','Vega','Ibarra Cantó','Vega','2015-03-08','Sub-14','activo','dddddddd-0002-4000-8000-000000000006','dddddddd-0001-4000-8000-000000000006', array['60 m lisos','Lanzamiento de peso'],'A-24033', false,'Multidisciplina: velocidad y peso.'),
  ('dddddddd-0003-4000-8000-000000000034','Álex','Company Ferrís','Álex','2016-07-22','Sub-12','activo','dddddddd-0002-4000-8000-000000000006','dddddddd-0001-4000-8000-000000000006', array['60 m lisos'],'A-24034', false, null),
  ('dddddddd-0003-4000-8000-000000000035','Candela','Ripollés Nadal','Candela','2016-11-14','Sub-12','activo','dddddddd-0002-4000-8000-000000000006','dddddddd-0001-4000-8000-000000000006', array['60 m lisos','Salto de longitud'],'A-24035', false, null),
  ('dddddddd-0003-4000-8000-000000000036','Bruno','Sanchis Camps','Bruno','2014-09-30','Sub-14','prueba','dddddddd-0002-4000-8000-000000000006','dddddddd-0001-4000-8000-000000000006', array['1.000 m'], null, false,'Prueba hasta final de mes.'),
  -- ---- Escuela Grupo 2 ----
  ('dddddddd-0003-4000-8000-000000000037','Martina','Escrivá Bou','Martina','2018-02-05','Escuela iniciación','activo','dddddddd-0002-4000-8000-000000000007','dddddddd-0001-4000-8000-000000000006', array['60 m lisos'],'A-24037', false, null),
  ('dddddddd-0003-4000-8000-000000000038','Leo','Fabra Marzal','Leo','2018-10-11','Escuela iniciación','activo','dddddddd-0002-4000-8000-000000000007','dddddddd-0001-4000-8000-000000000006', array['60 m lisos'],'A-24038', false, null),
  ('dddddddd-0003-4000-8000-000000000039','Jimena','Ortí Server','Jimena','2017-04-27','Sub-12','activo','dddddddd-0002-4000-8000-000000000007','dddddddd-0001-4000-8000-000000000006', array['60 m lisos'],'A-24039', false, null),
  ('dddddddd-0003-4000-8000-000000000040','Marcos','Guillem Aparici','Marcos','2019-01-16','Escuela iniciación','activo','dddddddd-0002-4000-8000-000000000007','dddddddd-0001-4000-8000-000000000006', array['60 m lisos'],'A-24040', false, null),
  ('dddddddd-0003-4000-8000-000000000041','Daniela','Rovira Espí','Dani','2017-08-03','Sub-12','prueba','dddddddd-0002-4000-8000-000000000007','dddddddd-0001-4000-8000-000000000006', array['60 m lisos'], null, false,'Primera semana, viene con una amiga.'),
  -- ---- Natación · Perfeccionamiento ----
  ('dddddddd-0003-4000-8000-000000000042','Alejandro','Bosch Peiró','Álex B.','2009-03-25','Sub-20','activo','dddddddd-0002-4000-8000-000000000008','dddddddd-0001-4000-8000-000000000007', array['100 m libres','200 m libres'],'N-24042', true, null),
  ('dddddddd-0003-4000-8000-000000000043','Irene','Llopis Grau','Irene','2010-06-14','Sub-18','activo','dddddddd-0002-4000-8000-000000000008','dddddddd-0001-4000-8000-000000000007', array['100 m espalda','200 m estilos'],'N-24043', false,'Multidisciplina: espalda y estilos.'),
  ('dddddddd-0003-4000-8000-000000000044','Pablo','Ferré Sanjuán','Pablo','2011-11-29','Sub-18','activo','dddddddd-0002-4000-8000-000000000008','dddddddd-0001-4000-8000-000000000007', array['50 m libres','100 m mariposa'],'N-24044', false,'Multidisciplina: libre corto y mariposa.'),
  ('dddddddd-0003-4000-8000-000000000045','Carla','Sanahuja Rius','Carla','2012-08-06','Sub-16','activo','dddddddd-0002-4000-8000-000000000008','dddddddd-0001-4000-8000-000000000007', array['100 m braza','200 m braza'],'N-24045', false, null),
  -- ---- Escuela de natación ----
  ('dddddddd-0003-4000-8000-000000000046','Nacho','Verdú Alabau','Nacho V.','2015-05-12','Sub-14','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres'], null, false, null),
  ('dddddddd-0003-4000-8000-000000000047','Aitana','Peris Colomer','Aitana','2016-02-23','Sub-12','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres','50 m espalda'], null, false, null),
  ('dddddddd-0003-4000-8000-000000000048','Gael','Marí Escoto','Gael','2017-09-04','Sub-12','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres'], null, false, null),
  ('dddddddd-0003-4000-8000-000000000049','Lola','Benavent Tur','Lola','2018-06-30','Escuela iniciación','activo','dddddddd-0002-4000-8000-000000000009','dddddddd-0001-4000-8000-000000000007', array['50 m libres'], null, false, null),
  -- ---- Triatlón ----
  ('dddddddd-0003-4000-8000-000000000050','Guillermo','Nebot Sancho','Guille','1993-10-08','Absoluto','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['400 m libres','10.000 m'],'T-24050', true,'Multidisciplina: natación y carrera a pie.'),
  ('dddddddd-0003-4000-8000-000000000051','Ana Belén','Tomás Ibáñez','Ana','1989-04-21','Máster','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['800 m libres','Media maratón'],'T-24051', true, null),
  ('dddddddd-0003-4000-8000-000000000052','Sergio','Palanca Vidal','Sergio P.','2000-12-15','Absoluto','activo','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['1.500 m libres','5.000 m'],'T-24052', true, null),
  ('dddddddd-0003-4000-8000-000000000053','Nerea','Fuentes Ávila','Nerea','1997-07-19','Absoluto','lesionado','dddddddd-0002-4000-8000-000000000010','dddddddd-0001-4000-8000-000000000008', array['400 m libres','10.000 m'],'T-24053', true,'Fascitis plantar. De momento solo nada y bici.'),
  -- ---- Montaña ----
  ('dddddddd-0003-4000-8000-000000000054','Vicente','Cardells Piera','Vicent','1981-01-24','Máster','activo','dddddddd-0002-4000-8000-000000000011','dddddddd-0001-4000-8000-000000000009', array['Maratón'],'M-24054', false, null),
  ('dddddddd-0003-4000-8000-000000000055','Lidia','Espinosa Roldán','Lidia','1992-05-06','Absoluto','activo','dddddddd-0002-4000-8000-000000000011','dddddddd-0001-4000-8000-000000000009', array['Media maratón'],'M-24055', false, null),
  ('dddddddd-0003-4000-8000-000000000056','Toni','Marzo Beltrán','Toni','1975-09-13','Máster','activo','dddddddd-0002-4000-8000-000000000011','dddddddd-0001-4000-8000-000000000009', array['Maratón'],'M-24056', false, null),
  -- ---- El Cubo ----
  ('dddddddd-0003-4000-8000-000000000057','Raquel','Ivars Signes','Raquel','1987-03-17','Máster','activo','dddddddd-0002-4000-8000-000000000012','dddddddd-0001-4000-8000-000000000010', null, null, true,'Solo clases de El Cubo, con bono de 10 usos.'),
  ('dddddddd-0003-4000-8000-000000000058','Borja','Sendra Talens','Borja','1995-11-08','Absoluto','activo','dddddddd-0002-4000-8000-000000000012','dddddddd-0001-4000-8000-000000000010', null, null, true, null),
  ('dddddddd-0003-4000-8000-000000000059','Mónica','Segarra Ausina','Mónica','2002-02-14','Absoluto','activo','dddddddd-0002-4000-8000-000000000012','dddddddd-0001-4000-8000-000000000010', null, null, true, null)
on conflict (id) do update set
  nombre = excluded.nombre, apellidos = excluded.apellidos, nombre_corto = excluded.nombre_corto,
  fecha_nacimiento = excluded.fecha_nacimiento, categoria = excluded.categoria, estado = excluded.estado,
  grupo_id = excluded.grupo_id, entrenador_id = excluded.entrenador_id,
  especialidades = excluded.especialidades, licencia = excluded.licencia,
  hace_gym = excluded.hace_gym, observaciones = excluded.observaciones;

-- Días de entreno, para que la ficha del atleta se vea completa.
update atletas set dias_entreno = array['lunes','martes','jueves','viernes']
  where grupo_id = 'dddddddd-0002-4000-8000-000000000001';
update atletas set dias_entreno = array['martes','jueves']
  where grupo_id in ('dddddddd-0002-4000-8000-000000000002','dddddddd-0002-4000-8000-000000000004',
                     'dddddddd-0002-4000-8000-000000000006','dddddddd-0002-4000-8000-000000000007',
                     'dddddddd-0002-4000-8000-000000000009');
update atletas set dias_entreno = array['lunes','miércoles','viernes']
  where grupo_id in ('dddddddd-0002-4000-8000-000000000003','dddddddd-0002-4000-8000-000000000008');

-- =====================================================================
-- 4. SESIONES DE ENTRENAMIENTO
-- =====================================================================
-- Cubren la semana pasada (20-26 jul), esta (27 jul-2 ago) y la que viene
-- (3-9 ago de 2026), con todos los tipos y el formato real del club:
-- bloques con etiqueta y matiz, y filas con ejercicio, series, distancia,
-- ritmo, descanso, calzado, carga, material y observaciones por atleta.
-- ---------------------------------------------------------------------
insert into sesiones (id, grupo_id, fecha, dia_semana, tipo, rol, titulo, nota_razonamiento, bloques, publicada, creado_por, atletas_ids)
values

-- ======== VELOCIDAD A · semana pasada (20-26 julio) ========
('dddddddd-0004-4000-8000-000000000001','dddddddd-0002-4000-8000-000000000001','2026-07-20','lunes','pista','calidad_fuerte',
 'Velocidad máxima · la sesión de calidad de la semana',
 'Llegamos frescos del fin de semana. Volumen mínimo y calidad absoluta: recuperaciones completas, sin correr con fatiga. Si una serie sale lenta, se para.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"10 min","calzado":"Zapatillas","observaciones":"Muy suave, solo entrar en calor"},
    {"ejercicio":"Movilidad articular","series":"1","distancia":"8 min","calzado":"Zapatillas"},
    {"ejercicio":"Ejercicios de técnica de carrera","series":"2","distancia":"30 m","descanso":"vuelta andando","calzado":"Zapatillas","observaciones":"Skipping, talones y elevación de rodillas"},
    {"ejercicio":"Progresivos","series":"3","distancia":"60 m","descanso":"2 min","calzado":"Clavos"}
  ]},
  {"etiqueta":"Velocidad máxima","matiz":"Calidad pura","filas":[
    {"ejercicio":"Salidas desde tacos","series":"4","distancia":"30 m","descanso":"4 min","calzado":"Clavos","observaciones":"Máxima aceleración. Recuperación completa entre series"},
    {"ejercicio":"Voladoras","series":"3","distancia":"40 m","ritmo":"95-100%","descanso":"6 min","calzado":"Clavos","observaciones":"Claudia: 4.6-4.8 s · Marina: 4.9-5.1 s · Rubén: 4.4-4.6 s"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"8 min","calzado":"Zapatillas"},
    {"ejercicio":"Estiramientos estáticos","series":"1","distancia":"6 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000002','dddddddd-0002-4000-8000-000000000001','2026-07-21','martes','gym','secundaria',
 'Fuerza máxima y potenciación',
 'Al día siguiente de la calidad, cargamos fuerte en sala. Movimientos rápidos y sin llegar al fallo: buscamos tensión, no cansancio.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Movilidad articular","series":"1","distancia":"8 min","calzado":"Zapatillas de gimnasio"},
    {"ejercicio":"Puente de glúteo","series":"2","distancia":"12 rep","carga":"peso corporal"}
  ]},
  {"etiqueta":"Fuerza / potencia","matiz":"Barra rápida","filas":[
    {"ejercicio":"Cargada","series":"4","distancia":"3 rep","carga":"80% RM","descanso":"3 min","observaciones":"Movida rapidísimo. Sin llegar a fallo"},
    {"ejercicio":"Media sentadilla","series":"4","distancia":"4 rep","carga":"85% RM","descanso":"3 min"},
    {"ejercicio":"Hip thrust","series":"3","distancia":"6 rep","carga":"75% RM","descanso":"2 min"}
  ]},
  {"etiqueta":"Tren superior y core","filas":[
    {"ejercicio":"Dominadas","series":"3","distancia":"6 rep","descanso":"2 min"},
    {"ejercicio":"Plancha con disco","series":"3","distancia":"40 s","carga":"10 kg"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Foam roller cuádriceps","series":"1","distancia":"5 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000003','dddddddd-0002-4000-8000-000000000001','2026-07-22','miércoles','descanso', null,
 'Descanso',
 'Día libre. Si acaso, un paseo y estiramientos en casa. El miércoles es para asimilar el lunes y el martes.',
 $j$[]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000004','dddddddd-0002-4000-8000-000000000001','2026-07-23','jueves','pista','secundaria',
 'Series de 150 · resistencia a la velocidad',
 'Segunda sesión de calidad de la semana, más larga y con menos recuperación. Aquí no buscamos velocidad punta, buscamos aguantarla.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"12 min","calzado":"Zapatillas"},
    {"ejercicio":"Drills de frecuencia","series":"2","distancia":"30 m","calzado":"Zapatillas"},
    {"ejercicio":"Progresivos","series":"3","distancia":"80 m","calzado":"Clavos"}
  ]},
  {"etiqueta":"Resistencia a la velocidad","matiz":"Series largas","filas":[
    {"ejercicio":"Series a ritmo","series":"5","distancia":"150 m","ritmo":"90-92%","descanso":"6 min","calzado":"Clavos","observaciones":"Rubén: 17.5-18.0 s · Dante: 18.0-18.5 s · Claudia: 19.5-20.0 s"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"10 min","calzado":"Zapatillas"},
    {"ejercicio":"Estiramiento de isquios","series":"1","distancia":"5 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000005','dddddddd-0002-4000-8000-000000000001','2026-07-24','viernes','continuo','descarga',
 'Rodaje suave y movilidad',
 'Descarga de piernas después de dos días fuertes. Suave de verdad: si al acabar no te apetece repetirlo, has ido demasiado rápido.',
 $j$[
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"25 min","ritmo":"muy cómodo","calzado":"Zapatillas","observaciones":"Se tiene que poder hablar todo el rato"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Movilidad post-sesión","series":"1","distancia":"10 min"},
    {"ejercicio":"Foam roller isquios","series":"1","distancia":"6 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000006','dddddddd-0002-4000-8000-000000000001','2026-07-24','viernes','pista','secundaria',
 'Trabajo específico de 400 mv · Rafa y Adri',
 'Sesión aparte solo para los dos vallistas de 400. El resto del grupo hace el rodaje suave.',
 $j$[
  {"etiqueta":"VALLISTAS","matiz":"Rafa y Adri","filas":[
    {"ejercicio":"Ritmo entre vallas","series":"4","distancia":"5 vallas","descanso":"4 min","calzado":"Clavos","observaciones":"Rafa: 13 zancadas · Adri: 15 zancadas hasta la 5"},
    {"ejercicio":"Serie completa de vallas","series":"2","distancia":"300 m con vallas","descanso":"8 min","calzado":"Clavos","observaciones":"Rafa: 40-42 s · Adri: 43-45 s"},
    {"ejercicio":"Vallas laterales","series":"2","distancia":"6 vallas","descanso":"3 min","calzado":"Zapatillas","observaciones":"Con las dos piernas, para no perder la de salida"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"8 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001',
 array['dddddddd-0003-4000-8000-000000000001','dddddddd-0003-4000-8000-000000000002']::uuid[]),

('dddddddd-0004-4000-8000-000000000007','dddddddd-0002-4000-8000-000000000001','2026-07-25','sábado','competicion','competicion',
 'Control federativo de velocidad · Alicante',
 'Control de 100 y 200 para ver por dónde andamos antes del autonómico. Calentamiento largo y sin nervios: es un control, no una final.',
 $j$[
  {"etiqueta":"Calentamiento de competición","filas":[
    {"ejercicio":"Calentamiento de competición","series":"1","distancia":"35 min","calzado":"Zapatillas","observaciones":"Empezar 50 min antes de la salida"},
    {"ejercicio":"Salida de competición","series":"3","distancia":"20 m","descanso":"3 min","calzado":"Clavos"}
  ]},
  {"etiqueta":"Competición","filas":[
    {"ejercicio":"Simulacro de competición","series":"1","distancia":"100 m","calzado":"Clavos","observaciones":"Claudia y Marina en la serie de las 19:10"},
    {"ejercicio":"Simulacro de competición","series":"1","distancia":"200 m","calzado":"Clavos","observaciones":"Rubén y Dante en la serie de las 20:05"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Vuelta a la calma post-competición","series":"1","distancia":"12 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

-- ======== VELOCIDAD A · esta semana (27 julio - 2 agosto) ========
('dddddddd-0004-4000-8000-000000000008','dddddddd-0002-4000-8000-000000000001','2026-07-27','lunes','pista','calidad_fuerte',
 'Aceleración y salidas',
 'Empezamos la semana del autonómico. Trabajo corto y muy explosivo para despertar el sistema nervioso sin dejar piernas.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"10 min","calzado":"Zapatillas"},
    {"ejercicio":"Ejercicios de cadera","series":"2","distancia":"20 m","calzado":"Zapatillas"},
    {"ejercicio":"Progresivos","series":"3","distancia":"60 m","calzado":"Clavos"}
  ]},
  {"etiqueta":"Aceleración","matiz":"Salidas de tacos","filas":[
    {"ejercicio":"Salidas desde tacos","series":"5","distancia":"20 m","descanso":"3 min","calzado":"Clavos","observaciones":"Primer apoyo debajo de la cadera. Sin levantar la cabeza"},
    {"ejercicio":"Aceleraciones","series":"3","distancia":"50 m","ritmo":"95%","descanso":"5 min","calzado":"Clavos","observaciones":"Marina: 6.5-6.7 s · Paula: 6.9-7.1 s"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"8 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000009','dddddddd-0002-4000-8000-000000000001','2026-07-28','martes','gym','secundaria',
 'Fuerza-potencia · última carga fuerte',
 'Última sesión con carga alta antes del sábado. A partir de aquí bajamos volumen y mantenemos la chispa.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Movilidad articular","series":"1","distancia":"8 min"},
    {"ejercicio":"Banda de glúteo","series":"2","distancia":"15 rep"}
  ]},
  {"etiqueta":"Fuerza / potencia","filas":[
    {"ejercicio":"Cargada desde rodillas","series":"4","distancia":"3 rep","carga":"75% RM","descanso":"3 min"},
    {"ejercicio":"Sentadilla búlgara","series":"3","distancia":"6 rep por pierna","carga":"40 kg","descanso":"2 min"},
    {"ejercicio":"Saltos al cajón","series":"4","distancia":"4 rep","descanso":"2 min","observaciones":"Caer suave. Cajón alto pero sin forzar"}
  ]},
  {"etiqueta":"Transferencia","matiz":"Mínima","filas":[
    {"ejercicio":"Lanzamiento de balón medicinal","series":"3","distancia":"5 rep","carga":"4 kg"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000010','dddddddd-0002-4000-8000-000000000001','2026-07-30','jueves','pista','calidad_fuerte',
 'Ritmo de 300 · vallistas y lisos',
 'Cada subgrupo hace lo suyo dentro de la misma sesión. Los tiempos son ORIENTATIVOS: si el primero sale muy por debajo, se ajusta el segundo.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"12 min","calzado":"Zapatillas"},
    {"ejercicio":"ABC de vallas","series":"2","distancia":"25 m","calzado":"Zapatillas"},
    {"ejercicio":"Progresivos","series":"3","distancia":"80 m","calzado":"Clavos"}
  ]},
  {"etiqueta":"VALLISTAS","matiz":"Rafa y Adri","filas":[
    {"ejercicio":"Serie completa de vallas","series":"2","distancia":"300 m con vallas","descanso":"8 min","calzado":"Clavos","observaciones":"Rafa: 40-42 s · Adri: 43-45 s"},
    {"ejercicio":"Serie completa de vallas","series":"2","distancia":"250 m con vallas","descanso":"7 min","calzado":"Clavos","observaciones":"Rafa: 33-34 s · Adri: 36-38 s · Según sensaciones"}
  ]},
  {"etiqueta":"LISOS","matiz":"Rubén y Dante","filas":[
    {"ejercicio":"Series a ritmo","series":"2","distancia":"300 m","descanso":"8 min","calzado":"Clavos","observaciones":"Rubén: 36-37 s · Dante: 37-38 s"},
    {"ejercicio":"Series a ritmo","series":"2","distancia":"200 m","descanso":"6 min","calzado":"Clavos","observaciones":"Rubén: 23.0-23.5 s · Dante: 23.5-24.0 s"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"10 min","calzado":"Zapatillas"},
    {"ejercicio":"Estiramientos estáticos","series":"1","distancia":"8 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000011','dddddddd-0002-4000-8000-000000000001','2026-07-31','viernes','activacion','activacion',
 'Activación previa a competición',
 'Muy corto. Solo para que el cuerpo se acuerde mañana de a qué velocidad va. En cuanto notes chispa, se acaba la sesión.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"8 min","calzado":"Zapatillas"},
    {"ejercicio":"Movilidad articular","series":"1","distancia":"6 min"}
  ]},
  {"etiqueta":"Potenciación neural","matiz":"Sin fatiga","filas":[
    {"ejercicio":"Progresivo corto","series":"3","distancia":"50 m","descanso":"3 min","calzado":"Clavos","observaciones":"Subir hasta el 90% y soltar"},
    {"ejercicio":"Salidas desde tacos","series":"2","distancia":"15 m","descanso":"3 min","calzado":"Clavos","observaciones":"Solo la reacción, no hay que llegar a nada"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Estiramiento de psoas","series":"1","distancia":"5 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000012','dddddddd-0002-4000-8000-000000000001','2026-08-01','sábado','competicion','competicion',
 'Campeonato Autonómico Sub-18 y Sub-20 · Castellón',
 'El día grande de la primera parte del verano. Horario: 400 mv semifinal 18:40 · 200 m final 19:50 · 100 m final 21:15.',
 $j$[
  {"etiqueta":"Antes de competir","filas":[
    {"ejercicio":"Calentamiento de competición","series":"1","distancia":"40 min","calzado":"Zapatillas","observaciones":"Empezar 55 min antes de cada prueba"},
    {"ejercicio":"Entradas en meta","series":"2","distancia":"30 m","calzado":"Clavos"}
  ]},
  {"etiqueta":"Competición","filas":[
    {"ejercicio":"Simulacro de competición","series":"1","distancia":"400 m vallas","calzado":"Clavos","observaciones":"Rafa y Adri · semifinal 18:40"},
    {"ejercicio":"Simulacro de competición","series":"1","distancia":"200 m","calzado":"Clavos","observaciones":"Rubén, Dante y Claudia · final 19:50"},
    {"ejercicio":"Simulacro de competición","series":"1","distancia":"100 m","calzado":"Clavos","observaciones":"Marina y Paula · final 21:15"}
  ]},
  {"etiqueta":"Después","filas":[
    {"ejercicio":"Vuelta a la calma post-competición","series":"1","distancia":"15 min","calzado":"Zapatillas"},
    {"ejercicio":"Estiramientos estáticos","series":"1","distancia":"10 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

-- ======== VELOCIDAD A · semana que viene (3-9 agosto) ========
('dddddddd-0004-4000-8000-000000000013','dddddddd-0002-4000-8000-000000000001','2026-08-03','lunes','pista','descarga',
 'Descarga post-competición',
 'Después del autonómico toca soltar piernas. Nada de intensidad: trote, técnica muy suave y a casa.',
 $j$[
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"20 min","ritmo":"cómodo","calzado":"Zapatillas"},
    {"ejercicio":"Ejercicios de técnica de carrera","series":"2","distancia":"20 m","calzado":"Zapatillas","observaciones":"Muy suave, solo para recordar la mecánica"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Foam roller","series":"1","distancia":"10 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000014','dddddddd-0002-4000-8000-000000000001','2026-08-04','martes','gym','secundaria',
 'Transferencia y core',
 'Volvemos a la sala con cargas medias. La idea es recuperar el tono, no batir marcas en sentadilla.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Movilidad articular","series":"1","distancia":"8 min"}
  ]},
  {"etiqueta":"Fuerza","filas":[
    {"ejercicio":"Media sentadilla","series":"3","distancia":"6 rep","carga":"70% RM","descanso":"2 min"},
    {"ejercicio":"Peso muerto rumano","series":"3","distancia":"8 rep","carga":"60% RM","descanso":"2 min"},
    {"ejercicio":"Nordic curl","series":"3","distancia":"5 rep","observaciones":"Bajada de 4 segundos"}
  ]},
  {"etiqueta":"Core","filas":[
    {"ejercicio":"Pallof press","series":"3","distancia":"10 rep por lado","carga":"15 kg"},
    {"ejercicio":"Plancha lateral","series":"3","distancia":"30 s por lado"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000015','dddddddd-0002-4000-8000-000000000001','2026-08-05','miércoles','gym','secundaria',
 'Readaptación · trabajo individual',
 'Sesión aparte para Iván mientras acaba de recuperarse del isquiotibial. Nada de carrera todavía.',
 $j$[
  {"etiqueta":"Readaptación","matiz":"Solo isquiotibial","filas":[
    {"ejercicio":"Isométricos isquiotibiales","series":"4","distancia":"20 s","descanso":"1 min","observaciones":"Sin dolor. Si molesta, se para"},
    {"ejercicio":"Excéntricos isquiotibiales","series":"3","distancia":"6 rep","carga":"peso corporal","descanso":"2 min"},
    {"ejercicio":"Bicicleta estática suave","series":"1","distancia":"15 min","observaciones":"Resistencia baja, cadencia alta"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Estiramiento de isquios","series":"1","distancia":"8 min","observaciones":"Suave, sin buscar rango"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001',
 array['dddddddd-0003-4000-8000-000000000007']::uuid[]),

('dddddddd-0004-4000-8000-000000000016','dddddddd-0002-4000-8000-000000000001','2026-08-06','jueves','pista','calidad_fuerte',
 'Velocidad lanzada',
 'Volvemos a la calidad. Series lanzadas para tocar velocidad punta sin el desgaste de la salida de tacos.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"12 min","calzado":"Zapatillas"},
    {"ejercicio":"Drills de frecuencia","series":"2","distancia":"30 m","calzado":"Zapatillas"},
    {"ejercicio":"Progresivos","series":"4","distancia":"60 m","calzado":"Clavos"}
  ]},
  {"etiqueta":"Velocidad máxima","matiz":"Lanzada","filas":[
    {"ejercicio":"Salidas lanzadas","series":"4","distancia":"30 m con 20 m de lanzamiento","ritmo":"98%","descanso":"6 min","calzado":"Clavos","observaciones":"Rubén: 2.9-3.0 s · Claudia: 3.2-3.3 s · Marina: 3.3-3.4 s"},
    {"ejercicio":"Contrastes velocidad-recuperación","series":"2","distancia":"60 m","descanso":"8 min","calzado":"Clavos"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"10 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000017','dddddddd-0002-4000-8000-000000000001','2026-08-07','viernes','pista','ultimo_toque_48h',
 'Último toque · 2x120',
 'Sesión corta 48 horas antes del control del domingo. Dos series buenas y se acaba.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"10 min","calzado":"Zapatillas"},
    {"ejercicio":"Progresivos","series":"3","distancia":"60 m","calzado":"Clavos"}
  ]},
  {"etiqueta":"Último toque","matiz":"Dos series y fuera","filas":[
    {"ejercicio":"Series a ritmo","series":"2","distancia":"120 m","ritmo":"92%","descanso":"8 min","calzado":"Clavos","observaciones":"Rubén: 13.2-13.5 s · Dante: 13.6-13.9 s"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Estiramientos estáticos","series":"1","distancia":"8 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

('dddddddd-0004-4000-8000-000000000018','dddddddd-0002-4000-8000-000000000001','2026-08-09','domingo','descanso', null,
 'Descanso completo',
 'Domingo libre. Descansar también es entrenar.',
 $j$[]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000001', null),

-- ======== VELOCIDAD B ========
('dddddddd-0004-4000-8000-000000000019','dddddddd-0002-4000-8000-000000000002','2026-07-21','martes','pista','calidad_fuerte',
 'Vallas · ritmo entre vallas',
 'Con los pequeños lo importante es el ritmo, no la altura de la valla. Bajamos alturas y acortamos distancias hasta que el paso salga solo.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"10 min","calzado":"Zapatillas"},
    {"ejercicio":"ABC de vallas","series":"3","distancia":"20 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Técnica de vallas","matiz":"Altura reducida","filas":[
    {"ejercicio":"Paso de valla individual","series":"6","distancia":"1 valla","descanso":"1 min","calzado":"Clavos","observaciones":"Pierna de ataque recta, brazo contrario largo"},
    {"ejercicio":"3 pasos entre vallas","series":"5","distancia":"4 vallas","descanso":"3 min","calzado":"Clavos","observaciones":"Lucía: 3 pasos cómodos · Mario: probar a 3, si no llega, a 4"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"8 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000002', null),

('dddddddd-0004-4000-8000-000000000020','dddddddd-0002-4000-8000-000000000002','2026-07-23','jueves','pista','secundaria',
 'Velocidad corta y multisaltos',
 'Sesión variada: velocidad muy corta y saltos. A estas edades interesa más el salto y la coordinación que la serie larga.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Carioca","series":"2","distancia":"20 m","calzado":"Zapatillas"},
    {"ejercicio":"Coordinación con escalera","series":"4","distancia":"10 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Velocidad","filas":[
    {"ejercicio":"Aceleraciones","series":"6","distancia":"30 m","descanso":"2 min","calzado":"Clavos","observaciones":"Salida de pie, muy relajados"}
  ]},
  {"etiqueta":"Multisaltos","matiz":"Poco volumen","filas":[
    {"ejercicio":"Multisaltos horizontales","series":"4","distancia":"5 saltos","descanso":"2 min","calzado":"Zapatillas"},
    {"ejercicio":"Saltos con vallas","series":"3","distancia":"5 vallas bajas","descanso":"2 min","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Estiramientos estáticos","series":"1","distancia":"6 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000002', null),

('dddddddd-0004-4000-8000-000000000021','dddddddd-0002-4000-8000-000000000002','2026-07-28','martes','pista','calidad_fuerte',
 'Vallas · buscar los 5 pasos',
 'Hoy probamos a alargar el paso entre vallas. Si alguien no llega, se acerca la valla, no se fuerza la zancada.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"10 min","calzado":"Zapatillas"},
    {"ejercicio":"Minibarreras","series":"3","distancia":"6 barreras","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Técnica de vallas","filas":[
    {"ejercicio":"5 pasos entre vallas","series":"5","distancia":"4 vallas","descanso":"3 min","calzado":"Clavos","observaciones":"Héctor: 5 pasos · Gonzalo: 5 pasos · Lucía: 3 pasos, distancia corta"},
    {"ejercicio":"Entrada a valla","series":"4","distancia":"1 valla desde salida","descanso":"2 min","calzado":"Clavos"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"8 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000002', null),

('dddddddd-0004-4000-8000-000000000022','dddddddd-0002-4000-8000-000000000002','2026-07-30','jueves','gym','secundaria',
 'Fuerza general de vallistas',
 'Fuerza con el propio peso y poco material. A esta edad no tocamos barra pesada: técnica y control.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Movilidad articular","series":"1","distancia":"8 min"}
  ]},
  {"etiqueta":"Fuerza general","filas":[
    {"ejercicio":"Sentadilla monopodal","series":"3","distancia":"8 rep por pierna","carga":"peso corporal"},
    {"ejercicio":"Zancadas con carga","series":"3","distancia":"10 rep","carga":"10 kg"},
    {"ejercicio":"Elevaciones de talón","series":"3","distancia":"15 rep"}
  ]},
  {"etiqueta":"Core","filas":[
    {"ejercicio":"Planchas","series":"3","distancia":"30 s"},
    {"ejercicio":"Dead bug","series":"3","distancia":"10 rep"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000002', null),

('dddddddd-0004-4000-8000-000000000023','dddddddd-0002-4000-8000-000000000002','2026-08-04','martes','pista','calidad_fuerte',
 'Series sobre vallas',
 'Primera sesión con la serie completa. Se trata de mantener el ritmo hasta la última valla, aunque haya que bajar la velocidad.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"10 min","calzado":"Zapatillas"},
    {"ejercicio":"ABC de vallas","series":"2","distancia":"20 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Serie de vallas","filas":[
    {"ejercicio":"Series sobre vallas","series":"4","distancia":"6 vallas","descanso":"4 min","calzado":"Clavos","observaciones":"Héctor: 9.6-9.9 s · Lucía: 10.2-10.5 s · Mario: 10.6-11.0 s"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"8 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000002', null),

('dddddddd-0004-4000-8000-000000000024','dddddddd-0002-4000-8000-000000000002','2026-08-06','jueves','pista','descarga',
 'Descarga · técnica y tobilleos',
 'Sesión corta y ligera. Toca cuidar el tobillo y el pie, que es lo que más sufre con las vallas.',
 $j$[
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Tobilleos","series":"4","distancia":"20 m","calzado":"Zapatillas"},
    {"ejercicio":"Skipping bajo","series":"4","distancia":"20 m","calzado":"Zapatillas"},
    {"ejercicio":"Progresivos","series":"3","distancia":"50 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Preventivo","filas":[
    {"ejercicio":"Propiocepción tobillo","series":"3","distancia":"45 s por pie"},
    {"ejercicio":"Trabajo de gemelo","series":"3","distancia":"15 rep"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000002', null),

-- ======== FONDO Y MEDIO FONDO ========
('dddddddd-0004-4000-8000-000000000025','dddddddd-0002-4000-8000-000000000003','2026-07-20','lunes','continuo','secundaria',
 'Rodaje largo de 70 minutos',
 'Base de la semana. Ritmo cómodo de principio a fin, sin acelerar la última parte aunque apetezca.',
 $j$[
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"70 min","ritmo":"4:45-5:00 min/km","calzado":"Zapatillas","observaciones":"Óscar y Jorge pueden ir a 4:20 · Noelia se queda en 55 min"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Estiramientos estáticos","series":"1","distancia":"8 min"},
    {"ejercicio":"Foam roller","series":"1","distancia":"6 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000003', null),

('dddddddd-0004-4000-8000-000000000026','dddddddd-0002-4000-8000-000000000003','2026-07-22','miércoles','pista','calidad_fuerte',
 'Series 6x1.000 en umbral',
 'Sesión clave de la semana. No es ir al máximo: es encontrar ese ritmo que se puede sostener y no soltarlo.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"15 min","calzado":"Zapatillas"},
    {"ejercicio":"Ejercicios de técnica de carrera","series":"2","distancia":"30 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Series en umbral","matiz":"Ritmo controlado","filas":[
    {"ejercicio":"Carrera en umbral","series":"6","distancia":"1.000 m","ritmo":"90%","descanso":"2 min trote","calzado":"Zapatillas","observaciones":"Jorge: 3:05-3:08 · Álvaro: 3:12-3:15 · Elena: 3:25-3:30 · Marta: 3:28-3:32"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"12 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000003', null),

('dddddddd-0004-4000-8000-000000000027','dddddddd-0002-4000-8000-000000000003','2026-07-27','lunes','continuo','secundaria',
 'Rodaje de 60 minutos con progresivos',
 'Rodaje normal y seis progresivos al final para que las piernas no se queden dormidas.',
 $j$[
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"60 min","ritmo":"cómodo","calzado":"Zapatillas"},
    {"ejercicio":"Progresivos","series":"6","distancia":"100 m","descanso":"vuelta andando","calzado":"Zapatillas","observaciones":"Subir sin llegar a esprintar"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000003', null),

('dddddddd-0004-4000-8000-000000000028','dddddddd-0002-4000-8000-000000000003','2026-07-29','miércoles','pista','calidad_fuerte',
 '12x400 a ritmo de 3.000',
 'Series cortas y bastantes. La primera y la última tienen que ir al mismo tiempo: ese es el examen.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"15 min","calzado":"Zapatillas"},
    {"ejercicio":"Progresivos","series":"3","distancia":"80 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Series","matiz":"Ritmo de 3.000","filas":[
    {"ejercicio":"Series aeróbicas","series":"12","distancia":"400 m","descanso":"1 min","calzado":"Clavos","observaciones":"Jorge: 68-70 s · Álvaro: 71-73 s · Elena: 76-78 s · Noelia: 80-82 s (hace 8)"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"12 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000003', null),

('dddddddd-0004-4000-8000-000000000029','dddddddd-0002-4000-8000-000000000003','2026-08-01','sábado','competicion','competicion',
 'Milla urbana de Villena',
 'Carrera corta y rápida en el centro del pueblo. Salir con los primeros y aguantar: el que se descuelga en los primeros 400 ya no vuelve.',
 $j$[
  {"etiqueta":"Antes de correr","filas":[
    {"ejercicio":"Calentamiento de competición","series":"1","distancia":"25 min","calzado":"Zapatillas"},
    {"ejercicio":"Progresivos","series":"4","distancia":"80 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Carrera","filas":[
    {"ejercicio":"Simulacro de competición","series":"1","distancia":"1 milla","calzado":"Zapatillas","observaciones":"Elena y Marta en la serie femenina de las 20:30 · Álvaro y Jorge a las 21:00"}
  ]},
  {"etiqueta":"Después","filas":[
    {"ejercicio":"Vuelta a la calma post-competición","series":"1","distancia":"15 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000003', null),

('dddddddd-0004-4000-8000-000000000030','dddddddd-0002-4000-8000-000000000003','2026-08-05','miércoles','continuo','calidad_fuerte',
 'Fartlek de 8x3 minutos',
 'Cambios de ritmo por el camino del pantano, sin mirar el reloj más que para los tiempos. Se trata de jugar con las sensaciones.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"15 min","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Fartlek","matiz":"Por sensaciones","filas":[
    {"ejercicio":"Fartlek","series":"8","distancia":"3 min fuerte","descanso":"2 min suave","calzado":"Zapatillas","observaciones":"Fuerte es ritmo de 10K, no de 1.500"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"10 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000003', null),

-- ======== LA TRIBU (running) ========
('dddddddd-0004-4000-8000-000000000031','dddddddd-0002-4000-8000-000000000004','2026-07-21','martes','continuo','secundaria',
 'Rodaje de grupo · 50 minutos',
 'Salida conjunta desde el parque. Vamos todos juntos y el que quiera apretar, que lo haga en los últimos 10 minutos.',
 $j$[
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"50 min","ritmo":"5:15-5:40 min/km","calzado":"Zapatillas","observaciones":"Fernando y Nacho pueden ir a 4:50 · Rosa a 5:45"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Estiramientos estáticos","series":"1","distancia":"8 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000004', null),

('dddddddd-0004-4000-8000-000000000032','dddddddd-0002-4000-8000-000000000004','2026-07-30','jueves','continuo','calidad_fuerte',
 'Series de 5x1.000 en el parque',
 'La sesión fuerte de la semana. El circuito del parque mide justo 1.000 m, así que no hace falta reloj: de farola a farola.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"15 min","calzado":"Zapatillas"},
    {"ejercicio":"Movilidad articular","series":"1","distancia":"6 min"}
  ]},
  {"etiqueta":"Series","filas":[
    {"ejercicio":"Series a ritmo","series":"5","distancia":"1.000 m","ritmo":"ritmo de 10K","descanso":"2 min andando","calzado":"Zapatillas","observaciones":"Fernando: 3:45-3:50 · Nacho: 3:50-3:55 · Bea: 4:20-4:25 · Rosa: 4:35-4:40"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote de vuelta a la calma","series":"1","distancia":"10 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000004', null),

('dddddddd-0004-4000-8000-000000000033','dddddddd-0002-4000-8000-000000000004','2026-08-04','martes','continuo','secundaria',
 'Rodaje suave y cuestas cortas',
 'Rodaje tranquilo y al final ocho cuestas de la calle del cementerio. Subir fuerte, bajar andando.',
 $j$[
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"35 min","ritmo":"cómodo","calzado":"Zapatillas"},
    {"ejercicio":"Carrera en cuesta arriba","series":"8","distancia":"80 m","descanso":"bajada andando","calzado":"Zapatillas","observaciones":"Braceo corto y rápido"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Estiramiento de gemelo","series":"1","distancia":"6 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000004', null),

-- ======== MADRE TIERRA (running) ========
('dddddddd-0004-4000-8000-000000000034','dddddddd-0002-4000-8000-000000000005','2026-07-29','miércoles','continuo','secundaria',
 'Rodaje de 40 minutos y core',
 'Salida por la vía verde, sin prisa. Terminamos con diez minutos de core en la explanada.',
 $j$[
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"40 min","ritmo":"6:00-6:30 min/km","calzado":"Zapatillas","observaciones":"Encarna alterna 5 min corriendo y 1 min andando"}
  ]},
  {"etiqueta":"Core","filas":[
    {"ejercicio":"Planchas","series":"3","distancia":"30 s"},
    {"ejercicio":"Puente de glúteo","series":"3","distancia":"12 rep"},
    {"ejercicio":"Russian twist","series":"3","distancia":"20 rep"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000005', null),

('dddddddd-0004-4000-8000-000000000035','dddddddd-0002-4000-8000-000000000005','2026-08-05','miércoles','activacion','activacion',
 'Rodaje suave y movilidad',
 'Semana tranquila. Corremos poco y dedicamos un buen rato a la movilidad de cadera, que es lo que más se nos resiste.',
 $j$[
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"30 min","ritmo":"muy cómodo","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Movilidad","filas":[
    {"ejercicio":"Ejercicios de cadera","series":"2","distancia":"20 m"},
    {"ejercicio":"Stretching global activo","series":"1","distancia":"12 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000005', null),

-- ======== ESCUELA GRUPO 1 ========
('dddddddd-0004-4000-8000-000000000036','dddddddd-0002-4000-8000-000000000006','2026-07-28','martes','pista','secundaria',
 'Juegos de velocidad y coordinación',
 'Con los peques todo en forma de juego. Relevos, persecuciones y escalera de coordinación. Que acaben con ganas de volver el jueves.',
 $j$[
  {"etiqueta":"Calentamiento jugando","filas":[
    {"ejercicio":"Carioca","series":"3","distancia":"15 m","calzado":"Zapatillas"},
    {"ejercicio":"Coordinación con escalera","series":"5","distancia":"8 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Velocidad","matiz":"En forma de juego","filas":[
    {"ejercicio":"Aceleraciones","series":"6","distancia":"20 m","descanso":"1 min","calzado":"Zapatillas","observaciones":"Por parejas, el que pierde vuelve andando"},
    {"ejercicio":"Frecuencia de pasos","series":"4","distancia":"10 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Juego final","filas":[
    {"ejercicio":"Zancadas","series":"3","distancia":"20 m","calzado":"Zapatillas","observaciones":"Relevos por equipos"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000006', null),

('dddddddd-0004-4000-8000-000000000037','dddddddd-0002-4000-8000-000000000006','2026-07-30','jueves','pista','secundaria',
 'Iniciación al salto de longitud',
 'Primer día de foso de la temporada. Nos centramos en la batida, no en cuánto se salta.',
 $j$[
  {"etiqueta":"Calentamiento","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"8 min","calzado":"Zapatillas"},
    {"ejercicio":"Elevación de rodillas","series":"3","distancia":"15 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Salto de longitud","matiz":"Aprender a batir","filas":[
    {"ejercicio":"Batida de longitud","series":"6","distancia":"6 pasos de carrera","descanso":"1 min","calzado":"Zapatillas","observaciones":"Pisar la tabla sin mirarla"},
    {"ejercicio":"Aproximación completa longitud","series":"4","distancia":"10 pasos","descanso":"2 min","calzado":"Zapatillas","observaciones":"Hugo y Candela ya llegan bien a la tabla"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Estiramientos estáticos","series":"1","distancia":"5 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000006', null),

('dddddddd-0004-4000-8000-000000000038','dddddddd-0002-4000-8000-000000000006','2026-08-04','martes','pista','secundaria',
 'Minivallas y relevos',
 'Primer contacto con las vallas bajas. Se pasan andando primero y luego corriendo, sin miedo.',
 $j$[
  {"etiqueta":"Calentamiento","filas":[
    {"ejercicio":"Movilidad articular","series":"1","distancia":"6 min"},
    {"ejercicio":"Kicks frontales","series":"3","distancia":"15 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Minivallas","filas":[
    {"ejercicio":"Minibarreras","series":"6","distancia":"5 barreras","descanso":"1 min","calzado":"Zapatillas"},
    {"ejercicio":"Barreras bajas técnica","series":"4","distancia":"4 vallas","descanso":"2 min","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Juego final","filas":[
    {"ejercicio":"Aceleraciones","series":"4","distancia":"20 m","calzado":"Zapatillas","observaciones":"Relevos con testigo"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000006', null),

-- ======== NATACIÓN · PERFECCIONAMIENTO ========
('dddddddd-0004-4000-8000-000000000039','dddddddd-0002-4000-8000-000000000008','2026-07-27','lunes','pista','calidad_fuerte',
 'Series de 100 a ritmo de 200',
 'Calle 1 los de libre, calle 2 espalda y estilos, calle 3 braza. Cada uno con su material y su ritmo.',
 $j$[
  {"etiqueta":"Calentamiento","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"400 m","observaciones":"Suave, alternando estilos"},
    {"ejercicio":"Series a ritmo","series":"8","distancia":"50 m","descanso":"20 s","material":["Tabla"],"observaciones":"Solo piernas"}
  ]},
  {"etiqueta":"CALLE 1","matiz":"Libre · Álex y Pablo","filas":[
    {"ejercicio":"Series a ritmo","series":"8","distancia":"100 m","ritmo":"ritmo de 200","descanso":"30 s","material":["Sin material"],"observaciones":"Álex: 1:04-1:06 · Pablo: 1:08-1:10"}
  ]},
  {"etiqueta":"CALLE 2","matiz":"Espalda y estilos · Irene","filas":[
    {"ejercicio":"Series a ritmo","series":"6","distancia":"100 m","descanso":"30 s","material":["Palas","Pull-buoy"],"observaciones":"Irene: 1:14-1:16 en espalda"}
  ]},
  {"etiqueta":"CALLE 3","matiz":"Braza · Carla","filas":[
    {"ejercicio":"Series a ritmo","series":"6","distancia":"100 m","descanso":"35 s","material":["Sin material"],"observaciones":"Carla: 1:26-1:29"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Natación recuperación","series":"1","distancia":"200 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000007', null),

('dddddddd-0004-4000-8000-000000000040','dddddddd-0002-4000-8000-000000000008','2026-07-29','miércoles','continuo','secundaria',
 'Aeróbico de 2.500 m con material',
 'Día de volumen. Poco descanso y muchos metros, cambiando de material para no aburrirse.',
 $j$[
  {"etiqueta":"Calentamiento","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"300 m","material":["Sin material"]}
  ]},
  {"etiqueta":"Parte principal","matiz":"Aeróbico","filas":[
    {"ejercicio":"Series aeróbicas","series":"4","distancia":"200 m","descanso":"20 s","material":["Pull-buoy","Palas"]},
    {"ejercicio":"Series aeróbicas","series":"8","distancia":"75 m","descanso":"15 s","material":["Aletas"]},
    {"ejercicio":"Series aeróbicas","series":"6","distancia":"100 m","descanso":"20 s","material":["Tabla"],"observaciones":"Solo piernas, sin parar"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Natación recuperación","series":"1","distancia":"200 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000007', null),

('dddddddd-0004-4000-8000-000000000041','dddddddd-0002-4000-8000-000000000008','2026-07-31','viernes','activacion','activacion',
 'Toque de velocidad y salidas',
 'Sesión corta de viernes. Salidas desde el poyete y algún 25 fuerte para acabar la semana con buenas sensaciones.',
 $j$[
  {"etiqueta":"Calentamiento","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"300 m","material":["Sin material"]}
  ]},
  {"etiqueta":"Velocidad","matiz":"Poco volumen","filas":[
    {"ejercicio":"Salida de competición","series":"6","distancia":"15 m","descanso":"1 min","observaciones":"Entrada limpia, sin abrir las piernas"},
    {"ejercicio":"Series descendentes","series":"6","distancia":"25 m","descanso":"45 s","material":["Sin material"],"observaciones":"Pablo: por debajo de 12 s · Álex: por debajo de 12.5 s"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Natación recuperación","series":"1","distancia":"200 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000007', null),

('dddddddd-0004-4000-8000-000000000042','dddddddd-0002-4000-8000-000000000008','2026-08-04','martes','pista','calidad_fuerte',
 '8x50 fuerte con palas',
 'Sesión corta pero exigente. Con palas se gana sensación de agarre, pero si duele el hombro se quitan y punto.',
 $j$[
  {"etiqueta":"Calentamiento","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"400 m","material":["Sin material"]},
    {"ejercicio":"Series a ritmo","series":"4","distancia":"50 m","descanso":"20 s","material":["Aletas"]}
  ]},
  {"etiqueta":"Parte principal","matiz":"Calidad","filas":[
    {"ejercicio":"Series descendentes","series":"8","distancia":"50 m","ritmo":"al 95%","descanso":"1 min","material":["Palas"],"observaciones":"Álex: 27-28 s · Pablo: 26-27 s · Irene: 30-31 s · Carla: 33-34 s"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Natación recuperación","series":"1","distancia":"300 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000007', null),

-- ======== TRIATLÓN ========
('dddddddd-0004-4000-8000-000000000043','dddddddd-0002-4000-8000-000000000010','2026-07-22','miércoles','continuo','secundaria',
 'Bici y transición a pie',
 'Salida en bici y al bajar, cinco minutos corriendo. Las primeras zancadas van a ir raras: de eso se trata.',
 $j$[
  {"etiqueta":"Bici","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"60 min en bici","ritmo":"cómodo","observaciones":"Cadencia alta, sin plato grande"}
  ]},
  {"etiqueta":"Transición","matiz":"Bici a pie","filas":[
    {"ejercicio":"Continuo suave","series":"3","distancia":"5 min corriendo","descanso":"3 min en bici","calzado":"Zapatillas","observaciones":"Guille: 4:10 min/km · Ana: 4:45 min/km"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Estiramiento de cuádriceps","series":"1","distancia":"8 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000008', null),

('dddddddd-0004-4000-8000-000000000044','dddddddd-0002-4000-8000-000000000010','2026-08-06','jueves','continuo','calidad_fuerte',
 'Series en bici y carrera',
 'Sesión larga de calidad. Nerea hace solo la parte de bici y natación mientras se recupera del pie.',
 $j$[
  {"etiqueta":"Bici","filas":[
    {"ejercicio":"Series a ritmo","series":"6","distancia":"4 min fuerte","descanso":"3 min suave","observaciones":"En la subida del puerto pequeño"}
  ]},
  {"etiqueta":"Carrera","filas":[
    {"ejercicio":"Series a ritmo","series":"4","distancia":"1.000 m","descanso":"2 min","calzado":"Zapatillas","observaciones":"Guille: 3:35-3:40 · Sergio: 3:30-3:35 · Ana: 4:10-4:15"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Natación recuperación","series":"1","distancia":"400 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000008', null),

-- ======== MONTAÑA ========
('dddddddd-0004-4000-8000-000000000045','dddddddd-0002-4000-8000-000000000011','2026-07-25','sábado','continuo','calidad_fuerte',
 'Subida al Maigmó · 18 km',
 'Tirada larga con 900 metros de desnivel. Se sube andando fuerte donde haga falta: en montaña no pasa nada por caminar.',
 $j$[
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Carrera en cuesta arriba","series":"1","distancia":"18 km","ritmo":"por sensaciones","calzado":"Zapatillas","observaciones":"Llevar agua para 2 horas y medias. Vicent y Toni abren, Lidia cierra"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Estiramientos estáticos","series":"1","distancia":"10 min"},
    {"ejercicio":"Foam roller cuádriceps","series":"1","distancia":"8 min","observaciones":"En casa, que la bajada pasa factura"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000009', null),

('dddddddd-0004-4000-8000-000000000046','dddddddd-0002-4000-8000-000000000011','2026-08-08','sábado','continuo','secundaria',
 'Tirada larga por la Font Roja',
 'Ritmo tranquilo por sombra. Semana de menos desnivel para dejar descansar las piernas antes de la carrera de septiembre.',
 $j$[
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Continuo suave","series":"1","distancia":"14 km","ritmo":"muy cómodo","calzado":"Zapatillas","observaciones":"Sin mirar el reloj en las subidas"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Stretching global activo","series":"1","distancia":"10 min"}
  ]}
 ]$j$::jsonb, true,'dddddddd-0001-4000-8000-000000000009', null)

on conflict (id) do update set
  grupo_id = excluded.grupo_id, fecha = excluded.fecha, dia_semana = excluded.dia_semana,
  tipo = excluded.tipo, rol = excluded.rol, titulo = excluded.titulo,
  nota_razonamiento = excluded.nota_razonamiento, bloques = excluded.bloques,
  publicada = true, creado_por = excluded.creado_por, atletas_ids = excluded.atletas_ids;

-- =====================================================================
-- 5. MARCAS DE LOS ATLETAS
-- =====================================================================
-- Varias por atleta y prueba a lo largo de la temporada, con progresión.
-- En las pruebas de distancia (longitud, peso…) el número son metros.
-- ---------------------------------------------------------------------
insert into marcas_atleta (id, atleta_id, prueba, tipo, tiempo_segundos, tiempo_display, fecha, sede, contexto)
select ('dddddddd-0005-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.atleta, t.prueba, t.tipo, t.seg, t.disp, t.fecha, t.sede, t.ctx
from (values
  -- Rafa Nieto · 400 m vallas (progresión) y 400 m lisos
  (1,  'dddddddd-0003-4000-8000-000000000001'::uuid, '400 m vallas', null::text, 56.90::numeric, '56.90', date '2026-02-21', 'Alicante', 'entreno'),
  (2,  'dddddddd-0003-4000-8000-000000000001', '400 m vallas', null, 55.80, '55.80', '2026-04-18', 'Elche', 'competicion'),
  (3,  'dddddddd-0003-4000-8000-000000000001', '400 m vallas', null, 54.60, '54.60', '2026-06-06', 'Valencia', 'competicion'),
  (4,  'dddddddd-0003-4000-8000-000000000001', '400 m vallas', 'mmp', 53.85, '53.85', '2026-07-25', 'Alicante', 'competicion'),
  (5,  'dddddddd-0003-4000-8000-000000000001', '400 m lisos', 'mmp', 49.70, '49.70', '2026-05-16', 'Alicante', 'competicion'),
  -- Adrián Molina
  (6,  'dddddddd-0003-4000-8000-000000000002', '400 m vallas', null, 60.20, '1:00.20', '2026-03-14', 'Alicante', 'competicion'),
  (7,  'dddddddd-0003-4000-8000-000000000002', '400 m vallas', null, 58.40, '58.40', '2026-05-16', 'Alicante', 'competicion'),
  (8,  'dddddddd-0003-4000-8000-000000000002', '400 m vallas', 'mmp', 57.10, '57.10', '2026-07-25', 'Alicante', 'competicion'),
  (9,  'dddddddd-0003-4000-8000-000000000002', '300 m lisos', null, 37.20, '37.20', '2026-06-20', 'Petrer', 'entreno'),
  -- Rubén Tomás
  (10, 'dddddddd-0003-4000-8000-000000000003', '400 m lisos', null, 51.40, '51.40', '2026-03-08', 'Castellón', 'competicion'),
  (11, 'dddddddd-0003-4000-8000-000000000003', '400 m lisos', null, 50.55, '50.55', '2026-05-16', 'Alicante', 'competicion'),
  (12, 'dddddddd-0003-4000-8000-000000000003', '400 m lisos', 'mmp', 49.92, '49.92', '2026-07-25', 'Alicante', 'competicion'),
  (13, 'dddddddd-0003-4000-8000-000000000003', '200 m lisos', 'mmp', 22.48, '22.48', '2026-06-06', 'Valencia', 'competicion'),
  -- Dante Ferrándiz
  (14, 'dddddddd-0003-4000-8000-000000000004', '400 m lisos', null, 52.80, '52.80', '2026-04-18', 'Elche', 'competicion'),
  (15, 'dddddddd-0003-4000-8000-000000000004', '400 m lisos', 'mmp', 51.30, '51.30', '2026-07-25', 'Alicante', 'competicion'),
  (16, 'dddddddd-0003-4000-8000-000000000004', '800 m', 'mmp', 118.60, '1:58.60', '2026-05-30', 'Valencia', 'competicion'),
  -- Claudia Bermejo
  (17, 'dddddddd-0003-4000-8000-000000000005', '100 m lisos', null, 12.45, '12.45', '2026-03-14', 'Alicante', 'competicion'),
  (18, 'dddddddd-0003-4000-8000-000000000005', '100 m lisos', null, 12.28, '12.28', '2026-05-16', 'Alicante', 'competicion'),
  (19, 'dddddddd-0003-4000-8000-000000000005', '100 m lisos', 'mmp', 12.09, '12.09', '2026-07-25', 'Alicante', 'competicion'),
  (20, 'dddddddd-0003-4000-8000-000000000005', '200 m lisos', 'mmp', 25.14, '25.14', '2026-06-06', 'Valencia', 'competicion'),
  -- Marina Escudero · velocidad y longitud
  (21, 'dddddddd-0003-4000-8000-000000000006', '100 m lisos', null, 13.10, '13.10', '2026-03-14', 'Alicante', 'competicion'),
  (22, 'dddddddd-0003-4000-8000-000000000006', '100 m lisos', 'mmp', 12.72, '12.72', '2026-06-20', 'Elche', 'competicion'),
  (23, 'dddddddd-0003-4000-8000-000000000006', '60 m lisos', 'mmp', 7.92, '7.92', '2026-02-07', 'Valencia', 'competicion'),
  (24, 'dddddddd-0003-4000-8000-000000000006', 'Salto de longitud', null, 5.18, '5.18', '2026-04-18', 'Elche', 'competicion'),
  (25, 'dddddddd-0003-4000-8000-000000000006', 'Salto de longitud', 'mmp', 5.46, '5.46', '2026-07-25', 'Alicante', 'competicion'),
  -- Iván Redondo (lesionado, marcas de antes)
  (26, 'dddddddd-0003-4000-8000-000000000007', '100 m lisos', 'mmp', 10.98, '10.98', '2026-05-16', 'Alicante', 'competicion'),
  (27, 'dddddddd-0003-4000-8000-000000000007', 'Salto de longitud', 'mmp', 6.94, '6.94', '2026-04-18', 'Elche', 'competicion'),
  -- Paula Quintana (a prueba)
  (28, 'dddddddd-0003-4000-8000-000000000008', '100 m lisos', null, 13.85, '13.85', '2026-07-20', 'Petrer', 'entreno'),
  (29, 'dddddddd-0003-4000-8000-000000000008', 'Salto de longitud', null, 4.42, '4.42', '2026-07-23', 'Petrer', 'entreno'),
  -- Héctor Salvador · vallas
  (30, 'dddddddd-0003-4000-8000-000000000009', '110 m vallas', null, 16.80, '16.80', '2026-04-18', 'Elche', 'competicion'),
  (31, 'dddddddd-0003-4000-8000-000000000009', '110 m vallas', 'mmp', 15.94, '15.94', '2026-06-20', 'Elche', 'competicion'),
  (32, 'dddddddd-0003-4000-8000-000000000009', '100 m lisos', 'mmp', 11.72, '11.72', '2026-05-16', 'Alicante', 'competicion'),
  -- Lucía Arribas
  (33, 'dddddddd-0003-4000-8000-000000000010', '100 m vallas', null, 16.40, '16.40', '2026-04-18', 'Elche', 'competicion'),
  (34, 'dddddddd-0003-4000-8000-000000000010', '100 m vallas', 'mmp', 15.60, '15.60', '2026-06-20', 'Elche', 'competicion'),
  (35, 'dddddddd-0003-4000-8000-000000000010', '60 m vallas', 'mmp', 9.42, '9.42', '2026-02-07', 'Valencia', 'competicion'),
  -- Mario Peiró
  (36, 'dddddddd-0003-4000-8000-000000000011', '60 m vallas', null, 10.10, '10.10', '2026-02-07', 'Valencia', 'competicion'),
  (37, 'dddddddd-0003-4000-8000-000000000011', '60 m vallas', 'mmp', 9.78, '9.78', '2026-06-20', 'Elche', 'entreno'),
  (38, 'dddddddd-0003-4000-8000-000000000011', '60 m lisos', 'mmp', 8.24, '8.24', '2026-02-07', 'Valencia', 'competicion'),
  -- Sara Company · velocidad y longitud
  (39, 'dddddddd-0003-4000-8000-000000000012', '60 m lisos', null, 8.90, '8.90', '2026-02-07', 'Valencia', 'competicion'),
  (40, 'dddddddd-0003-4000-8000-000000000012', '60 m lisos', 'mmp', 8.62, '8.62', '2026-06-20', 'Elche', 'competicion'),
  (41, 'dddddddd-0003-4000-8000-000000000012', 'Salto de longitud', null, 4.28, '4.28', '2026-04-18', 'Elche', 'competicion'),
  (42, 'dddddddd-0003-4000-8000-000000000012', 'Salto de longitud', 'mmp', 4.61, '4.61', '2026-06-20', 'Elche', 'competicion'),
  -- Gonzalo Serrano · vallas y altura
  (43, 'dddddddd-0003-4000-8000-000000000013', '110 m vallas', 'mmp', 16.42, '16.42', '2026-06-20', 'Elche', 'competicion'),
  (44, 'dddddddd-0003-4000-8000-000000000013', 'Salto de altura', null, 1.65, '1.65', '2026-04-18', 'Elche', 'competicion'),
  (45, 'dddddddd-0003-4000-8000-000000000013', 'Salto de altura', 'mmp', 1.76, '1.76', '2026-07-25', 'Alicante', 'competicion'),
  -- Alba Redó
  (46, 'dddddddd-0003-4000-8000-000000000014', '300 m lisos', null, 43.20, '43.20', '2026-04-18', 'Elche', 'competicion'),
  (47, 'dddddddd-0003-4000-8000-000000000014', '300 m lisos', 'mmp', 41.85, '41.85', '2026-06-20', 'Elche', 'competicion'),
  (48, 'dddddddd-0003-4000-8000-000000000014', '400 m lisos', 'mmp', 58.90, '58.90', '2026-05-30', 'Valencia', 'competicion'),
  -- Elena Pardo · medio fondo
  (49, 'dddddddd-0003-4000-8000-000000000016', '1.500 m', null, 288.40, '4:48.40', '2026-03-14', 'Alicante', 'competicion'),
  (50, 'dddddddd-0003-4000-8000-000000000016', '1.500 m', null, 283.10, '4:43.10', '2026-05-16', 'Alicante', 'competicion'),
  (51, 'dddddddd-0003-4000-8000-000000000016', '1.500 m', 'mmp', 277.60, '4:37.60', '2026-06-27', 'Valencia', 'competicion'),
  (52, 'dddddddd-0003-4000-8000-000000000016', '800 m', 'mmp', 130.20, '2:10.20', '2026-05-30', 'Valencia', 'competicion'),
  -- Jorge Alcántara
  (53, 'dddddddd-0003-4000-8000-000000000017', '5.000 m', null, 928.00, '15:28.00', '2026-04-11', 'Valencia', 'competicion'),
  (54, 'dddddddd-0003-4000-8000-000000000017', '5.000 m', 'mmp', 909.50, '15:09.50', '2026-06-27', 'Valencia', 'competicion'),
  (55, 'dddddddd-0003-4000-8000-000000000017', '3.000 m obstáculos', 'mmp', 578.30, '9:38.30', '2026-06-06', 'Castellón', 'competicion'),
  -- Marta Cebrián
  (56, 'dddddddd-0003-4000-8000-000000000018', '800 m', null, 138.90, '2:18.90', '2026-03-14', 'Alicante', 'competicion'),
  (57, 'dddddddd-0003-4000-8000-000000000018', '800 m', 'mmp', 134.40, '2:14.40', '2026-06-27', 'Valencia', 'competicion'),
  (58, 'dddddddd-0003-4000-8000-000000000018', '1.500 m', 'mmp', 285.90, '4:45.90', '2026-05-16', 'Alicante', 'competicion'),
  -- Álvaro Ferrer
  (59, 'dddddddd-0003-4000-8000-000000000019', '3.000 m', null, 545.20, '9:05.20', '2026-04-11', 'Valencia', 'competicion'),
  (60, 'dddddddd-0003-4000-8000-000000000019', '3.000 m', 'mmp', 531.80, '8:51.80', '2026-06-27', 'Valencia', 'competicion'),
  (61, 'dddddddd-0003-4000-8000-000000000019', '1.500 m', 'mmp', 248.70, '4:08.70', '2026-05-30', 'Valencia', 'competicion'),
  -- Noelia Gascó
  (62, 'dddddddd-0003-4000-8000-000000000020', '1.000 m', null, 195.40, '3:15.40', '2026-04-18', 'Elche', 'competicion'),
  (63, 'dddddddd-0003-4000-8000-000000000020', '1.000 m', 'mmp', 188.90, '3:08.90', '2026-06-20', 'Elche', 'competicion'),
  (64, 'dddddddd-0003-4000-8000-000000000020', '800 m', 'mmp', 148.20, '2:28.20', '2026-05-30', 'Valencia', 'competicion'),
  -- Óscar Villalba
  (65, 'dddddddd-0003-4000-8000-000000000021', '10.000 m', null, 1998.00, '33:18.00', '2026-02-15', 'Elche', 'competicion'),
  (66, 'dddddddd-0003-4000-8000-000000000021', '10.000 m', 'mmp', 1954.00, '32:34.00', '2026-06-14', 'Alicante', 'competicion'),
  (67, 'dddddddd-0003-4000-8000-000000000021', 'Media maratón', 'mmp', 4362.00, '1:12:42', '2026-03-01', 'Santa Pola', 'competicion'),
  -- Fernando Belmonte (La Tribu)
  (68, 'dddddddd-0003-4000-8000-000000000022', 'Media maratón', null, 5220.00, '1:27:00', '2026-01-25', 'Santa Pola', 'competicion'),
  (69, 'dddddddd-0003-4000-8000-000000000022', 'Media maratón', 'mmp', 5085.00, '1:24:45', '2026-05-10', 'Alicante', 'competicion'),
  (70, 'dddddddd-0003-4000-8000-000000000022', '10.000 m', 'mmp', 2310.00, '38:30.00', '2026-06-14', 'Alicante', 'competicion'),
  -- Rosa María Aguilar
  (71, 'dddddddd-0003-4000-8000-000000000023', 'Maratón', null, 13500.00, '3:45:00', '2025-12-07', 'Valencia', 'competicion'),
  (72, 'dddddddd-0003-4000-8000-000000000023', 'Media maratón', 'mmp', 6300.00, '1:45:00', '2026-05-10', 'Alicante', 'competicion'),
  -- Ignacio Pastor
  (73, 'dddddddd-0003-4000-8000-000000000024', '10.000 m', null, 2415.00, '40:15.00', '2026-02-15', 'Elche', 'competicion'),
  (74, 'dddddddd-0003-4000-8000-000000000024', '10.000 m', 'mmp', 2352.00, '39:12.00', '2026-06-14', 'Alicante', 'competicion'),
  (75, 'dddddddd-0003-4000-8000-000000000024', '5.000 m', 'mmp', 1128.00, '18:48.00', '2026-04-11', 'Petrer', 'competicion'),
  -- Beatriz Solano
  (76, 'dddddddd-0003-4000-8000-000000000025', 'Media maratón', null, 6540.00, '1:49:00', '2026-01-25', 'Santa Pola', 'competicion'),
  (77, 'dddddddd-0003-4000-8000-000000000025', 'Media maratón', 'mmp', 6270.00, '1:44:30', '2026-05-10', 'Alicante', 'competicion'),
  -- Amparo Tarazona y Silvia Renau (Madre Tierra)
  (78, 'dddddddd-0003-4000-8000-000000000027', '10.000 m', null, 3300.00, '55:00.00', '2026-02-15', 'Elche', 'competicion'),
  (79, 'dddddddd-0003-4000-8000-000000000027', '10.000 m', 'mmp', 3162.00, '52:42.00', '2026-06-14', 'Alicante', 'competicion'),
  (80, 'dddddddd-0003-4000-8000-000000000028', '10.000 m', 'mmp', 2880.00, '48:00.00', '2026-06-14', 'Alicante', 'competicion'),
  (81, 'dddddddd-0003-4000-8000-000000000028', 'Media maratón', 'mmp', 6480.00, '1:48:00', '2026-05-10', 'Alicante', 'competicion'),
  (82, 'dddddddd-0003-4000-8000-000000000030', '10.000 m', 'mmp', 3018.00, '50:18.00', '2026-06-14', 'Alicante', 'competicion'),
  -- Escuela: Hugo, Vega, Álex, Candela
  (83, 'dddddddd-0003-4000-8000-000000000032', '60 m lisos', null, 9.40, '9.40', '2026-03-14', 'Petrer', 'competicion'),
  (84, 'dddddddd-0003-4000-8000-000000000032', '60 m lisos', 'mmp', 9.05, '9.05', '2026-06-13', 'Petrer', 'competicion'),
  (85, 'dddddddd-0003-4000-8000-000000000032', 'Salto de longitud', 'mmp', 4.05, '4.05', '2026-06-13', 'Petrer', 'competicion'),
  (86, 'dddddddd-0003-4000-8000-000000000033', '60 m lisos', 'mmp', 9.62, '9.62', '2026-06-13', 'Petrer', 'competicion'),
  (87, 'dddddddd-0003-4000-8000-000000000033', 'Lanzamiento de peso', null, 6.80, '6.80', '2026-03-14', 'Petrer', 'competicion'),
  (88, 'dddddddd-0003-4000-8000-000000000033', 'Lanzamiento de peso', 'mmp', 7.62, '7.62', '2026-06-13', 'Petrer', 'competicion'),
  (89, 'dddddddd-0003-4000-8000-000000000034', '60 m lisos', 'mmp', 10.15, '10.15', '2026-06-13', 'Petrer', 'competicion'),
  (90, 'dddddddd-0003-4000-8000-000000000035', '60 m lisos', 'mmp', 10.40, '10.40', '2026-06-13', 'Petrer', 'competicion'),
  (91, 'dddddddd-0003-4000-8000-000000000035', 'Salto de longitud', 'mmp', 3.28, '3.28', '2026-06-13', 'Petrer', 'competicion'),
  -- Natación: Alejandro, Irene, Pablo, Carla
  (92, 'dddddddd-0003-4000-8000-000000000042', '100 m libres', null, 58.90, '58.90', '2026-02-28', 'Elda', 'competicion'),
  (93, 'dddddddd-0003-4000-8000-000000000042', '100 m libres', null, 57.60, '57.60', '2026-04-25', 'Alicante', 'competicion'),
  (94, 'dddddddd-0003-4000-8000-000000000042', '100 m libres', 'mmp', 56.42, '56.42', '2026-06-13', 'Valencia', 'competicion'),
  (95, 'dddddddd-0003-4000-8000-000000000042', '200 m libres', 'mmp', 124.80, '2:04.80', '2026-06-13', 'Valencia', 'competicion'),
  (96, 'dddddddd-0003-4000-8000-000000000043', '100 m espalda', null, 74.20, '1:14.20', '2026-02-28', 'Elda', 'competicion'),
  (97, 'dddddddd-0003-4000-8000-000000000043', '100 m espalda', 'mmp', 71.35, '1:11.35', '2026-06-13', 'Valencia', 'competicion'),
  (98, 'dddddddd-0003-4000-8000-000000000043', '200 m estilos', 'mmp', 158.90, '2:38.90', '2026-04-25', 'Alicante', 'competicion'),
  (99, 'dddddddd-0003-4000-8000-000000000044', '50 m libres', null, 27.40, '27.40', '2026-02-28', 'Elda', 'competicion'),
  (100,'dddddddd-0003-4000-8000-000000000044', '50 m libres', 'mmp', 26.28, '26.28', '2026-06-13', 'Valencia', 'competicion'),
  (101,'dddddddd-0003-4000-8000-000000000044', '100 m mariposa', 'mmp', 63.70, '1:03.70', '2026-04-25', 'Alicante', 'competicion'),
  (102,'dddddddd-0003-4000-8000-000000000045', '100 m braza', null, 88.60, '1:28.60', '2026-02-28', 'Elda', 'competicion'),
  (103,'dddddddd-0003-4000-8000-000000000045', '100 m braza', 'mmp', 85.10, '1:25.10', '2026-06-13', 'Valencia', 'competicion'),
  (104,'dddddddd-0003-4000-8000-000000000045', '200 m braza', 'mmp', 184.20, '3:04.20', '2026-04-25', 'Alicante', 'competicion'),
  (105,'dddddddd-0003-4000-8000-000000000046', '50 m libres', 'mmp', 33.80, '33.80', '2026-06-13', 'Elda', 'competicion'),
  (106,'dddddddd-0003-4000-8000-000000000047', '50 m libres', 'mmp', 39.20, '39.20', '2026-06-13', 'Elda', 'competicion'),
  -- Triatlón
  (107,'dddddddd-0003-4000-8000-000000000050', '400 m libres', 'mmp', 292.40, '4:52.40', '2026-04-25', 'Alicante', 'entreno'),
  (108,'dddddddd-0003-4000-8000-000000000050', '10.000 m', 'mmp', 2280.00, '38:00.00', '2026-06-14', 'Alicante', 'competicion'),
  (109,'dddddddd-0003-4000-8000-000000000051', '800 m libres', 'mmp', 660.00, '11:00.00', '2026-04-25', 'Alicante', 'entreno'),
  (110,'dddddddd-0003-4000-8000-000000000052', '1.500 m libres', 'mmp', 1245.00, '20:45.00', '2026-05-09', 'Alicante', 'entreno'),
  (111,'dddddddd-0003-4000-8000-000000000052', '5.000 m', 'mmp', 1050.00, '17:30.00', '2026-04-11', 'Petrer', 'competicion'),
  -- Montaña
  (112,'dddddddd-0003-4000-8000-000000000054', 'Maratón', 'mmp', 12900.00, '3:35:00', '2025-12-07', 'Valencia', 'competicion'),
  (113,'dddddddd-0003-4000-8000-000000000055', 'Media maratón', 'mmp', 6000.00, '1:40:00', '2026-05-10', 'Alicante', 'competicion'),
  (114,'dddddddd-0003-4000-8000-000000000056', 'Maratón', 'mmp', 14100.00, '3:55:00', '2025-12-07', 'Valencia', 'competicion'),
  -- Objetivos de temporada (tipo objetivo)
  (115,'dddddddd-0003-4000-8000-000000000001', '400 m vallas', 'objetivo', 53.00, '53.00', '2026-09-05', 'Objetivo de temporada', null),
  (116,'dddddddd-0003-4000-8000-000000000005', '100 m lisos', 'objetivo', 11.95, '11.95', '2026-09-05', 'Objetivo de temporada', null),
  (117,'dddddddd-0003-4000-8000-000000000016', '1.500 m', 'objetivo', 273.00, '4:33.00', '2026-09-05', 'Objetivo de temporada', null),
  (118,'dddddddd-0003-4000-8000-000000000042', '100 m libres', 'objetivo', 55.50, '55.50', '2026-09-19', 'Objetivo de temporada', null)
) as t(n, atleta, prueba, tipo, seg, disp, fecha, sede, ctx)
on conflict do nothing;

-- =====================================================================
-- 6. PAGOS (cuotas trimestrales)
-- =====================================================================
-- Cuatro trimestres para todos los atletas que no están de baja ni de
-- prueba, con estados variados para que se llenen los contadores.
-- ---------------------------------------------------------------------
insert into pagos (id, atleta_id, concepto, importe, estado, fecha_vencimiento, fecha_pago, metodo, periodo, cuenta, notas)
select
  ('dddddddd-0006-4000-8000-' || lpad((row_number() over (order by a.id, tr.orden))::text, 12, '0'))::uuid,
  a.id,
  tr.concepto,
  case g.seccion
    when 'competicion' then 135.00
    when 'natacion' then 120.00
    when 'escuela' then 95.00
    when 'escuela-natacion' then 90.00
    when 'triatlon' then 150.00
    when 'cubo' then 110.00
    else 75.00
  end,
  est.estado,
  tr.vence,
  case when est.estado = 'pagado' then tr.vence + 2 else null end,
  case when est.estado = 'pagado' then (array['domiciliado','domiciliado','transferencia','efectivo'])[1 + mod(a.orden, 4)] else null end,
  tr.periodo,
  case when g.seccion in ('escuela','escuela-natacion') then 'escuela' else 'club' end,
  case when est.estado = 'impagado' then 'Recibo devuelto por el banco. Pendiente de hablar con la familia.' else null end
from (
  select at.id, row_number() over (order by at.id) as orden, at.grupo_id
  from atletas at
  where at.id::text like 'dddddddd-%' and at.estado in ('activo','lesionado')
) a
join grupos g on g.id = a.grupo_id
cross join (values
  (1, 'Cuota trimestral octubre-diciembre 2025', date '2025-10-05', '2025-10'),
  (2, 'Cuota trimestral enero-marzo 2026',        date '2026-01-05', '2026-01'),
  (3, 'Cuota trimestral abril-junio 2026',        date '2026-04-05', '2026-04'),
  (4, 'Cuota trimestral julio-septiembre 2026',   date '2026-07-05', '2026-07')
) as tr(orden, concepto, vence, periodo)
cross join lateral (
  select case
    when tr.orden <= 2 then case when mod(a.orden, 17) = 0 then 'impagado' else 'pagado' end
    when tr.orden = 3 then case when mod(a.orden, 11) = 0 then 'impagado'
                                when mod(a.orden, 7) = 0 then 'pendiente'
                                else 'pagado' end
    else case when mod(a.orden, 9) = 0 then 'impagado'
              when mod(a.orden, 3) = 0 then 'pendiente'
              else 'pagado' end
  end as estado
) est
on conflict do nothing;

-- =====================================================================
-- 7. COMPETICIONES, INSCRIPCIONES Y BONO DE COMPETICIÓN
-- =====================================================================
insert into competiciones (id, nombre, sede, fecha_inicio, fecha_fin, nivel, ambito, coste, fecha_limite_interna, inscripcion_abierta, notas, creado_por)
values
  ('dddddddd-0007-4000-8000-000000000001','Cross de la Ermita','Petrer','2026-03-08','2026-03-08','C','atletismo', 5.00, '2026-03-02 22:00+01', false,'Cross popular de invierno. Ya celebrado.','dddddddd-0001-4000-8000-000000000003'),
  ('dddddddd-0007-4000-8000-000000000002','Control federativo de velocidad','Alicante','2026-05-16','2026-05-16','C','atletismo', 0.00, '2026-05-12 22:00+02', false,'Control para conseguir mínimas. Ya celebrado.','dddddddd-0001-4000-8000-000000000001'),
  ('dddddddd-0007-4000-8000-000000000003','Campeonato Autonómico Sub-18 y Sub-20','Castellón','2026-08-01','2026-08-02','A','atletismo', 12.00, '2026-07-25 20:00+02', false,'Inscripción cerrada. Salimos en autobús a las 14:00 desde el pabellón.','dddddddd-0001-4000-8000-000000000001'),
  ('dddddddd-0007-4000-8000-000000000004','Milla urbana de Villena','Villena','2026-08-01','2026-08-01','C','atletismo', 5.00, '2026-07-28 22:00+02', false,'Carrera nocturna por el centro. Dorsales en la carpa desde las 19:00.','dddddddd-0001-4000-8000-000000000003'),
  ('dddddddd-0007-4000-8000-000000000005','Campeonato de España Sub-23','Madrid','2026-08-22','2026-08-23','A','atletismo', 25.00, '2026-08-10 22:00+02', true,'Hace falta mínima. El club paga el desplazamiento a los clasificados.','dddddddd-0001-4000-8000-000000000001'),
  ('dddddddd-0007-4000-8000-000000000006','Trofeo Ciudad de Alcoy','Alcoy','2026-09-12','2026-09-12','B','atletismo', 8.00, '2026-09-04 22:00+02', true,'Primera competición del curso. Abierta a todas las categorías.','dddddddd-0001-4000-8000-000000000002'),
  ('dddddddd-0007-4000-8000-000000000007','Trofeo de natación Ciudad de Elda','Elda','2026-09-19','2026-09-19','B','natacion', 10.00, '2026-09-10 22:00+02', true,'Piscina de 25 m. Calentamiento a las 09:00.','dddddddd-0001-4000-8000-000000000007'),
  ('dddddddd-0007-4000-8000-000000000008','Media maratón de Santa Pola','Santa Pola','2026-10-11','2026-10-11','B','atletismo', 18.00, '2026-09-30 22:00+02', true,'Clásica de otoño. Quien quiera plaza que avise pronto, se agotan.','dddddddd-0001-4000-8000-000000000004')
on conflict (id) do update set
  nombre = excluded.nombre, sede = excluded.sede, fecha_inicio = excluded.fecha_inicio,
  fecha_fin = excluded.fecha_fin, nivel = excluded.nivel, ambito = excluded.ambito,
  coste = excluded.coste, fecha_limite_interna = excluded.fecha_limite_interna,
  inscripcion_abierta = excluded.inscripcion_abierta, notas = excluded.notas;

insert into competicion_atleta (id, competicion_id, atleta_id, prueba, estado, marca_acreditada, resultado, observaciones, confirmada_en, confirmada_por)
select ('dddddddd-0008-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.comp, t.atleta, t.prueba, t.estado, t.acred, t.resultado, t.obs, t.confirmada, t.confpor
from (values
  -- Autonómico (ya cerrado, con resultados del sábado)
  (1,  'dddddddd-0007-4000-8000-000000000003'::uuid, 'dddddddd-0003-4000-8000-000000000001'::uuid, '400 m vallas', 'confirmada', '53.85', null::text, 'Sale en la calle 4'::text, '2026-07-24 19:12+02'::timestamptz, 'dddddddd-0001-4000-8000-000000000001'::uuid),
  (2,  'dddddddd-0007-4000-8000-000000000003', 'dddddddd-0003-4000-8000-000000000002', '400 m vallas', 'confirmada', '57.10', null, null, '2026-07-24 19:12+02', 'dddddddd-0001-4000-8000-000000000001'),
  (3,  'dddddddd-0007-4000-8000-000000000003', 'dddddddd-0003-4000-8000-000000000003', '200 m lisos', 'confirmada', '22.48', null, null, '2026-07-24 19:14+02', 'dddddddd-0001-4000-8000-000000000001'),
  (4,  'dddddddd-0007-4000-8000-000000000003', 'dddddddd-0003-4000-8000-000000000004', '200 m lisos', 'confirmada', '23.40', null, null, '2026-07-24 19:14+02', 'dddddddd-0001-4000-8000-000000000001'),
  (5,  'dddddddd-0007-4000-8000-000000000003', 'dddddddd-0003-4000-8000-000000000005', '200 m lisos', 'confirmada', '25.14', null, null, '2026-07-24 19:15+02', 'dddddddd-0001-4000-8000-000000000001'),
  (6,  'dddddddd-0007-4000-8000-000000000003', 'dddddddd-0003-4000-8000-000000000006', '100 m lisos', 'confirmada', '12.72', null, null, '2026-07-24 19:15+02', 'dddddddd-0001-4000-8000-000000000001'),
  (7,  'dddddddd-0007-4000-8000-000000000003', 'dddddddd-0003-4000-8000-000000000006', 'Salto de longitud', 'confirmada', '5.46', null, 'Compagina las dos pruebas, cuidado con el horario', '2026-07-24 19:16+02', 'dddddddd-0001-4000-8000-000000000001'),
  (8,  'dddddddd-0007-4000-8000-000000000003', 'dddddddd-0003-4000-8000-000000000009', '110 m vallas', 'confirmada', '15.94', null, null, '2026-07-24 19:20+02', 'dddddddd-0001-4000-8000-000000000002'),
  (9,  'dddddddd-0007-4000-8000-000000000003', 'dddddddd-0003-4000-8000-000000000013', 'Salto de altura', 'confirmada', '1.76', null, null, '2026-07-24 19:20+02', 'dddddddd-0001-4000-8000-000000000002'),
  (10, 'dddddddd-0007-4000-8000-000000000003', 'dddddddd-0003-4000-8000-000000000014', '400 m lisos', 'cancelada', '58.90', null, 'Se cae por unas anginas', '2026-07-24 19:21+02', 'dddddddd-0001-4000-8000-000000000002'),
  -- Control de mayo (con resultado)
  (11, 'dddddddd-0007-4000-8000-000000000002', 'dddddddd-0003-4000-8000-000000000003', '400 m lisos', 'confirmada', '51.40', '50.55 · 2º de la serie', null, '2026-05-12 18:00+02', 'dddddddd-0001-4000-8000-000000000001'),
  (12, 'dddddddd-0007-4000-8000-000000000002', 'dddddddd-0003-4000-8000-000000000007', '100 m lisos', 'confirmada', '11.10', '10.98 · marca personal', null, '2026-05-12 18:00+02', 'dddddddd-0001-4000-8000-000000000001'),
  (13, 'dddddddd-0007-4000-8000-000000000002', 'dddddddd-0003-4000-8000-000000000005', '100 m lisos', 'confirmada', '12.45', '12.28 · 3ª', null, '2026-05-12 18:01+02', 'dddddddd-0001-4000-8000-000000000001'),
  -- Milla urbana de Villena
  (14, 'dddddddd-0007-4000-8000-000000000004', 'dddddddd-0003-4000-8000-000000000016', 'Milla', 'confirmada', '4:37.60', null, null, '2026-07-27 21:00+02', 'dddddddd-0001-4000-8000-000000000003'),
  (15, 'dddddddd-0007-4000-8000-000000000004', 'dddddddd-0003-4000-8000-000000000018', 'Milla', 'confirmada', '4:45.90', null, null, '2026-07-27 21:00+02', 'dddddddd-0001-4000-8000-000000000003'),
  (16, 'dddddddd-0007-4000-8000-000000000004', 'dddddddd-0003-4000-8000-000000000019', 'Milla', 'confirmada', '4:08.70', null, null, '2026-07-27 21:01+02', 'dddddddd-0001-4000-8000-000000000003'),
  (17, 'dddddddd-0007-4000-8000-000000000004', 'dddddddd-0003-4000-8000-000000000017', 'Milla', 'apuntado', null, null, 'Pendiente de decidir si corre', null, null),
  -- Campeonato de España Sub-23 (abierto)
  (18, 'dddddddd-0007-4000-8000-000000000005', 'dddddddd-0003-4000-8000-000000000001', '400 m vallas', 'apuntado', '53.85', null, 'Tiene la mínima', null, null),
  (19, 'dddddddd-0007-4000-8000-000000000005', 'dddddddd-0003-4000-8000-000000000016', '1.500 m', 'apuntado', '4:37.60', null, 'A falta de 2 segundos para la mínima', null, null),
  (20, 'dddddddd-0007-4000-8000-000000000005', 'dddddddd-0003-4000-8000-000000000005', '200 m lisos', 'apuntado', '25.14', null, null, null, null),
  -- Trofeo Ciudad de Alcoy (abierto, apuntados)
  (21, 'dddddddd-0007-4000-8000-000000000006', 'dddddddd-0003-4000-8000-000000000010', '100 m vallas', 'apuntado', '15.60', null, null, null, null),
  (22, 'dddddddd-0007-4000-8000-000000000006', 'dddddddd-0003-4000-8000-000000000011', '60 m vallas', 'apuntado', '9.78', null, null, null, null),
  (23, 'dddddddd-0007-4000-8000-000000000006', 'dddddddd-0003-4000-8000-000000000012', 'Salto de longitud', 'apuntado', '4.61', null, null, null, null),
  (24, 'dddddddd-0007-4000-8000-000000000006', 'dddddddd-0003-4000-8000-000000000009', '110 m vallas', 'apuntado', '15.94', null, null, null, null),
  (25, 'dddddddd-0007-4000-8000-000000000006', 'dddddddd-0003-4000-8000-000000000032', '60 m lisos', 'apuntado', '9.05', null, 'Primera competición fuera de casa', null, null),
  (26, 'dddddddd-0007-4000-8000-000000000006', 'dddddddd-0003-4000-8000-000000000033', 'Lanzamiento de peso', 'apuntado', '7.62', null, null, null, null),
  -- Trofeo de natación
  (27, 'dddddddd-0007-4000-8000-000000000007', 'dddddddd-0003-4000-8000-000000000042', '100 m libres', 'apuntado', '56.42', null, null, null, null),
  (28, 'dddddddd-0007-4000-8000-000000000007', 'dddddddd-0003-4000-8000-000000000043', '100 m espalda', 'apuntado', '1:11.35', null, null, null, null),
  (29, 'dddddddd-0007-4000-8000-000000000007', 'dddddddd-0003-4000-8000-000000000044', '50 m libres', 'apuntado', '26.28', null, null, null, null),
  (30, 'dddddddd-0007-4000-8000-000000000007', 'dddddddd-0003-4000-8000-000000000045', '100 m braza', 'apuntado', '1:25.10', null, null, null, null),
  -- Media maratón de Santa Pola
  (31, 'dddddddd-0007-4000-8000-000000000008', 'dddddddd-0003-4000-8000-000000000022', 'Media maratón', 'apuntado', '1:24:45', null, null, null, null),
  (32, 'dddddddd-0007-4000-8000-000000000008', 'dddddddd-0003-4000-8000-000000000023', 'Media maratón', 'apuntado', '1:45:00', null, null, null, null),
  (33, 'dddddddd-0007-4000-8000-000000000008', 'dddddddd-0003-4000-8000-000000000025', 'Media maratón', 'apuntado', '1:44:30', null, null, null, null),
  (34, 'dddddddd-0007-4000-8000-000000000008', 'dddddddd-0003-4000-8000-000000000028', 'Media maratón', 'apuntado', '1:48:00', null, null, null, null),
  (35, 'dddddddd-0007-4000-8000-000000000008', 'dddddddd-0003-4000-8000-000000000021', 'Media maratón', 'confirmada', '1:12:42', null, 'Va a por el podio de la general', '2026-07-30 10:00+02', 'dddddddd-0001-4000-8000-000000000004'),
  -- Cross de la Ermita (marzo, con resultados)
  (36, 'dddddddd-0007-4000-8000-000000000001', 'dddddddd-0003-4000-8000-000000000017', 'Cross largo', 'confirmada', null, '4º absoluto', null, '2026-03-02 20:00+01', 'dddddddd-0001-4000-8000-000000000003'),
  (37, 'dddddddd-0007-4000-8000-000000000001', 'dddddddd-0003-4000-8000-000000000019', 'Cross corto', 'confirmada', null, '2º Sub-20', null, '2026-03-02 20:00+01', 'dddddddd-0001-4000-8000-000000000003'),
  (38, 'dddddddd-0007-4000-8000-000000000001', 'dddddddd-0003-4000-8000-000000000016', 'Cross corto', 'confirmada', null, '1ª Sub-23', null, '2026-03-02 20:01+01', 'dddddddd-0001-4000-8000-000000000003')
) as t(n, comp, atleta, prueba, estado, acred, resultado, obs, confirmada, confpor)
on conflict do nothing;

-- Bono de competición: recargas de las familias y gastos por inscripción.
insert into bono_movimientos (id, atleta_id, concepto, importe, competicion_id, fecha, creado_por)
select ('dddddddd-0009-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.atleta, t.concepto, t.importe, t.comp, t.fecha, t.creado
from (values
  (1,  'dddddddd-0003-4000-8000-000000000001'::uuid, 'Recarga de bono de competición', 60.00::numeric, null::uuid, date '2026-01-15', 'dddddddd-0001-4000-8000-000000000001'::uuid),
  (2,  'dddddddd-0003-4000-8000-000000000001', 'Inscripción Control federativo', -0.00, 'dddddddd-0007-4000-8000-000000000002', '2026-05-12', 'dddddddd-0001-4000-8000-000000000001'),
  (3,  'dddddddd-0003-4000-8000-000000000001', 'Inscripción Autonómico Sub-20', -12.00, 'dddddddd-0007-4000-8000-000000000003', '2026-07-24', 'dddddddd-0001-4000-8000-000000000001'),
  (4,  'dddddddd-0003-4000-8000-000000000002', 'Recarga de bono de competición', 40.00, null, '2026-02-02', 'dddddddd-0001-4000-8000-000000000001'),
  (5,  'dddddddd-0003-4000-8000-000000000002', 'Inscripción Autonómico Sub-20', -12.00, 'dddddddd-0007-4000-8000-000000000003', '2026-07-24', 'dddddddd-0001-4000-8000-000000000001'),
  (6,  'dddddddd-0003-4000-8000-000000000003', 'Recarga de bono de competición', 50.00, null, '2026-01-20', 'dddddddd-0001-4000-8000-000000000001'),
  (7,  'dddddddd-0003-4000-8000-000000000003', 'Inscripción Autonómico Sub-20', -12.00, 'dddddddd-0007-4000-8000-000000000003', '2026-07-24', 'dddddddd-0001-4000-8000-000000000001'),
  (8,  'dddddddd-0003-4000-8000-000000000005', 'Recarga de bono de competición', 30.00, null, '2026-03-05', 'dddddddd-0001-4000-8000-000000000001'),
  (9,  'dddddddd-0003-4000-8000-000000000005', 'Inscripción Autonómico Sub-20', -12.00, 'dddddddd-0007-4000-8000-000000000003', '2026-07-24', 'dddddddd-0001-4000-8000-000000000001'),
  (10, 'dddddddd-0003-4000-8000-000000000006', 'Recarga de bono de competición', 45.00, null, '2026-02-10', 'dddddddd-0001-4000-8000-000000000001'),
  (11, 'dddddddd-0003-4000-8000-000000000006', 'Inscripción Autonómico Sub-18', -12.00, 'dddddddd-0007-4000-8000-000000000003', '2026-07-24', 'dddddddd-0001-4000-8000-000000000001'),
  (12, 'dddddddd-0003-4000-8000-000000000009', 'Recarga de bono de competición', 25.00, null, '2026-04-08', 'dddddddd-0001-4000-8000-000000000002'),
  (13, 'dddddddd-0003-4000-8000-000000000009', 'Inscripción Autonómico Sub-18', -12.00, 'dddddddd-0007-4000-8000-000000000003', '2026-07-24', 'dddddddd-0001-4000-8000-000000000002'),
  (14, 'dddddddd-0003-4000-8000-000000000013', 'Recarga de bono de competición', 20.00, null, '2026-04-08', 'dddddddd-0001-4000-8000-000000000002'),
  (15, 'dddddddd-0003-4000-8000-000000000013', 'Inscripción Autonómico Sub-18', -12.00, 'dddddddd-0007-4000-8000-000000000003', '2026-07-24', 'dddddddd-0001-4000-8000-000000000002'),
  (16, 'dddddddd-0003-4000-8000-000000000016', 'Recarga de bono de competición', 35.00, null, '2026-02-18', 'dddddddd-0001-4000-8000-000000000003'),
  (17, 'dddddddd-0003-4000-8000-000000000016', 'Inscripción Milla urbana', -5.00, 'dddddddd-0007-4000-8000-000000000004', '2026-07-28', 'dddddddd-0001-4000-8000-000000000003'),
  (18, 'dddddddd-0003-4000-8000-000000000017', 'Recarga de bono de competición', 30.00, null, '2026-02-18', 'dddddddd-0001-4000-8000-000000000003'),
  (19, 'dddddddd-0003-4000-8000-000000000017', 'Inscripción Cross de la Ermita', -5.00, 'dddddddd-0007-4000-8000-000000000001', '2026-03-02', 'dddddddd-0001-4000-8000-000000000003'),
  (20, 'dddddddd-0003-4000-8000-000000000021', 'Recarga de bono de competición', 40.00, null, '2026-06-01', 'dddddddd-0001-4000-8000-000000000004'),
  (21, 'dddddddd-0003-4000-8000-000000000021', 'Inscripción Media maratón de Santa Pola', -18.00, 'dddddddd-0007-4000-8000-000000000008', '2026-07-30', 'dddddddd-0001-4000-8000-000000000004'),
  (22, 'dddddddd-0003-4000-8000-000000000042', 'Recarga de bono de competición', 30.00, null, '2026-03-20', 'dddddddd-0001-4000-8000-000000000007'),
  (23, 'dddddddd-0003-4000-8000-000000000043', 'Recarga de bono de competición', 30.00, null, '2026-03-20', 'dddddddd-0001-4000-8000-000000000007'),
  (24, 'dddddddd-0003-4000-8000-000000000004', 'Recarga de bono de competición', 25.00, null, '2026-05-04', 'dddddddd-0001-4000-8000-000000000001'),
  (25, 'dddddddd-0003-4000-8000-000000000004', 'Inscripción Autonómico Sub-20', -12.00, 'dddddddd-0007-4000-8000-000000000003', '2026-07-24', 'dddddddd-0001-4000-8000-000000000001')
) as t(n, atleta, concepto, importe, comp, fecha, creado)
on conflict do nothing;

-- =====================================================================
-- 8. AVISOS, EVENTOS, MENSAJES Y SOLICITUDES
-- =====================================================================
insert into avisos (id, texto, tipo, enlace, texto_enlace, fecha_fin, activo)
values
  ('dddddddd-000a-4000-8000-000000000001','Abierta la inscripción para la temporada 2026-2027. Las plazas de la escuela son limitadas.','info','/inscripcion/','Apuntarse', '2026-09-30', true),
  ('dddddddd-000a-4000-8000-000000000002','La pista municipal estará cerrada por obras del 10 al 14 de agosto. Los entrenamientos se hacen en el parque.','aviso', null, null, '2026-08-14', true),
  ('dddddddd-000a-4000-8000-000000000003','Campus de verano completo. Gracias a todas las familias por la confianza.','info', null, null, '2026-06-30', false)
on conflict (id) do update set
  texto = excluded.texto, tipo = excluded.tipo, enlace = excluded.enlace,
  texto_enlace = excluded.texto_enlace, fecha_fin = excluded.fecha_fin, activo = excluded.activo;

insert into eventos (id, titulo, descripcion, tipo, fecha_inicio, fecha_fin, lugar, seccion, inscripcion_abierta)
values
  ('dddddddd-000b-4000-8000-000000000001','Campeonato Autonómico Sub-18 y Sub-20','Salida del autobús a las 14:00 desde el pabellón. Volvemos el domingo por la tarde.','competicion','2026-08-01 09:00+02','2026-08-02 20:00+02','Pista de atletismo de Castellón', array['competicion'], false),
  ('dddddddd-000b-4000-8000-000000000002','Milla urbana de Villena','Carrera nocturna por el centro. Recogida de dorsales desde las 19:00 en la carpa del club.','competicion','2026-08-01 20:00+02','2026-08-01 23:00+02','Centro de Villena', array['competicion','running'], false),
  ('dddddddd-000b-4000-8000-000000000003','Control de marcas de pretemporada','Control interno abierto a todo el club para ver por dónde andamos antes de septiembre.','control','2026-08-29 18:30+02','2026-08-29 21:00+02','Estadio Joaquín Villar', array['competicion','escuela'], true),
  ('dddddddd-000b-4000-8000-000000000004','Reunión de familias de la escuela','Presentación de la temporada, horarios, cuotas y calendario de competiciones.','actividad_padres','2026-09-05 18:00+02','2026-09-05 19:30+02','Sala de usos múltiples del pabellón', array['escuela','escuela-natacion'], false),
  ('dddddddd-000b-4000-8000-000000000005','Comida de fin de temporada','Comida de todo el club para cerrar la temporada. Apuntarse antes del 5 de septiembre.','evento_club','2026-09-13 14:00+02','2026-09-13 18:00+02','Restaurante El Molino', array['competicion','running','escuela','natacion','triatlon','montana'], true),
  ('dddddddd-000b-4000-8000-000000000006','Salida de montaña a la Font Roja','Tirada larga por el parque natural. Quedada en el aparcamiento del santuario.','entrenamiento_especial','2026-08-08 08:00+02','2026-08-08 12:00+02','Font Roja, Alcoy', array['montana'], false)
on conflict (id) do update set
  titulo = excluded.titulo, descripcion = excluded.descripcion, tipo = excluded.tipo,
  fecha_inicio = excluded.fecha_inicio, fecha_fin = excluded.fecha_fin, lugar = excluded.lugar,
  seccion = excluded.seccion, inscripcion_abierta = excluded.inscripcion_abierta;

insert into mensajes (id, nombre, medio, asunto, mensaje, atendido, created_at)
values
  ('dddddddd-000c-4000-8000-000000000001','Marisa Bonet','marisa.bonet@demo.apolana.test','Horarios de la escuela en septiembre','Buenos días. Tengo dos hijas de 8 y 11 años y me gustaría saber los horarios de la escuela para el curso que viene, y si van al mismo grupo o a grupos distintos. Gracias.', false, '2026-07-29 09:14+02'),
  ('dddddddd-000c-4000-8000-000000000002','Tomás Requena','666 111 222','Alquiler de la pista para un colegio','Somos el AMPA del colegio San Blas y querríamos organizar una jornada de atletismo en junio. ¿Se puede alquilar la instalación un sábado por la mañana?', false, '2026-07-30 17:40+02'),
  ('dddddddd-000c-4000-8000-000000000003','Nieves Aparisi','nieves.aparisi@demo.apolana.test','Grupo de running para empezar de cero','Hola, no he corrido nunca y me da un poco de vergüenza apuntarme. ¿Hay algún grupo para gente que empieza desde cero? Gracias.', false, '2026-07-31 08:05+02'),
  ('dddddddd-000c-4000-8000-000000000004','Paco Server','paco.server@demo.apolana.test','Camiseta del club talla XL','Buenas, quería una camiseta del club en talla XL. ¿Quedan o hay que esperar al siguiente pedido?', true, '2026-07-18 12:30+02')
on conflict (id) do update set
  nombre = excluded.nombre, medio = excluded.medio, asunto = excluded.asunto,
  mensaje = excluded.mensaje, atendido = excluded.atendido, created_at = excluded.created_at;

insert into solicitudes_inscripcion (id, nombre, medio, interes, origen, comentario, atendida, created_at)
values
  ('dddddddd-000d-4000-8000-000000000001','Álvaro Cortés Peiró','alvaro.cortes@demo.apolana.test','escuela','web','Mi hijo tiene 9 años y viene del fútbol. Le gustaría probar el atletismo un par de semanas antes de decidir.', false, '2026-07-28 20:10+02'),
  ('dddddddd-000d-4000-8000-000000000002','Cristina Bou Server','611 333 444','running','web','Corro por mi cuenta unos 40 km a la semana y busco grupo para preparar la media de Santa Pola.', false, '2026-07-30 21:35+02'),
  ('dddddddd-000d-4000-8000-000000000003','Jorge Ferrándiz Lloret','jorge.ferrandiz@demo.apolana.test','competicion','recomendacion','Sub-18, hace 400 y 800. Viene de otro club de la comarca y quiere entrenar aquí desde septiembre.', false, '2026-07-31 10:22+02'),
  ('dddddddd-000d-4000-8000-000000000004','Rocío Talens Mas','rocio.talens@demo.apolana.test','escuela-natacion','instagram','Niña de 6 años, sabe flotar pero no nada. Preguntaba por el grupo de iniciación.', false, '2026-07-27 19:48+02'),
  ('dddddddd-000d-4000-8000-000000000005','Miguel Ángel Sanz Doménech','miguelangel.sanz@demo.apolana.test','cubo','web','Quería información de los bonos de El Cubo y de los horarios de clase de la tarde.', true, '2026-07-15 11:05+02')
on conflict (id) do update set
  nombre = excluded.nombre, medio = excluded.medio, interes = excluded.interes,
  origen = excluded.origen, comentario = excluded.comentario, atendida = excluded.atendida,
  created_at = excluded.created_at;

-- =====================================================================
-- 9. EL CUBO: clases, bonos y reservas
-- =====================================================================
insert into cubo_clases (id, fecha, hora_inicio, hora_fin, titulo, monitor_id, monitor_nombre, plazas, notas, activa, creado_por)
values
  ('dddddddd-000e-4000-8000-000000000001','2026-07-28','09:30','10:30','Funcional · fuerza general','dddddddd-0001-4000-8000-000000000010','Diego Marín', 12,'Clase de mañana. Traer toalla.', true,'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-000e-4000-8000-000000000002','2026-07-29','19:00','20:00','Core y movilidad','dddddddd-0001-4000-8000-000000000010','Diego Marín', 10, null, true,'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-000e-4000-8000-000000000003','2026-07-30','09:30','10:30','Funcional · fuerza general','dddddddd-0001-4000-8000-000000000010','Diego Marín', 12, null, true,'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-000e-4000-8000-000000000004','2026-08-03','09:30','10:30','Funcional · fuerza general','dddddddd-0001-4000-8000-000000000010','Diego Marín', 12, null, true,'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-000e-4000-8000-000000000005','2026-08-03','19:00','20:00','Circuito metabólico','dddddddd-0001-4000-8000-000000000010','Diego Marín', 3,'Plazas muy limitadas por el material.', true,'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-000e-4000-8000-000000000006','2026-08-04','19:00','20:00','Core y movilidad','dddddddd-0001-4000-8000-000000000010','Diego Marín', 10, null, true,'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-000e-4000-8000-000000000007','2026-08-05','09:30','10:30','Funcional · fuerza general','dddddddd-0001-4000-8000-000000000010','Diego Marín', 12, null, true,'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-000e-4000-8000-000000000008','2026-08-05','20:00','21:00','Fuerza para corredores','dddddddd-0001-4000-8000-000000000004','Álvaro Peñalver', 14,'Pensada para La Tribu y Madre Tierra.', true,'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-000e-4000-8000-000000000009','2026-08-06','19:00','20:00','Circuito metabólico','dddddddd-0001-4000-8000-000000000010','Diego Marín', 10, null, true,'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-000e-4000-8000-000000000010','2026-08-07','09:30','10:30','Funcional · fuerza general','dddddddd-0001-4000-8000-000000000010','Diego Marín', 12, null, true,'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-000e-4000-8000-000000000011','2026-08-10','19:00','20:00','Core y movilidad','dddddddd-0001-4000-8000-000000000010','Diego Marín', 10, null, true,'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-000e-4000-8000-000000000012','2026-08-12','20:00','21:00','Fuerza para corredores','dddddddd-0001-4000-8000-000000000004','Álvaro Peñalver', 14, null, true,'dddddddd-0001-4000-8000-000000000010')
on conflict (id) do update set
  fecha = excluded.fecha, hora_inicio = excluded.hora_inicio, hora_fin = excluded.hora_fin,
  titulo = excluded.titulo, monitor_id = excluded.monitor_id, monitor_nombre = excluded.monitor_nombre,
  plazas = excluded.plazas, notas = excluded.notas, activa = excluded.activa;

-- Bonos (al darlos de alta, el propio sistema apunta el movimiento de alta)
insert into cubo_bonos (id, atleta_id, usos_totales, precio, fecha_compra, caducidad, activo, notas, creado_por)
values
  ('dddddddd-0010-4000-8000-000000000001','dddddddd-0003-4000-8000-000000000057', 10, 55.00,'2026-07-06','2026-10-06', true,'Bono de 10 usos', 'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-0010-4000-8000-000000000002','dddddddd-0003-4000-8000-000000000058', 20, 95.00,'2026-06-15','2026-12-15', true,'Bono de 20 usos', 'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-0010-4000-8000-000000000003','dddddddd-0003-4000-8000-000000000059', 5, 30.00,'2026-07-20','2026-09-20', true,'Bono de prueba de 5 usos', 'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-0010-4000-8000-000000000004','dddddddd-0003-4000-8000-000000000022', 10, 55.00,'2026-07-01','2026-10-01', true,'Bono para la clase de fuerza para corredores', 'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-0010-4000-8000-000000000005','dddddddd-0003-4000-8000-000000000024', 10, 55.00,'2026-07-01','2026-10-01', true,'Bono para la clase de fuerza para corredores', 'dddddddd-0001-4000-8000-000000000010'),
  ('dddddddd-0010-4000-8000-000000000006','dddddddd-0003-4000-8000-000000000028', 5, 30.00,'2026-07-18','2026-09-18', true,'Bono de 5 usos', 'dddddddd-0001-4000-8000-000000000010')
on conflict (id) do nothing;

-- Reservas ya pasadas (asistidas) — el uso gastado se apunta más abajo.
insert into cubo_reservas (id, clase_id, atleta_id, estado)
values
  ('dddddddd-000f-4000-8000-000000000001','dddddddd-000e-4000-8000-000000000001','dddddddd-0003-4000-8000-000000000057','asistida'),
  ('dddddddd-000f-4000-8000-000000000002','dddddddd-000e-4000-8000-000000000001','dddddddd-0003-4000-8000-000000000058','asistida'),
  ('dddddddd-000f-4000-8000-000000000003','dddddddd-000e-4000-8000-000000000002','dddddddd-0003-4000-8000-000000000059','asistida'),
  ('dddddddd-000f-4000-8000-000000000004','dddddddd-000e-4000-8000-000000000003','dddddddd-0003-4000-8000-000000000057','asistida'),
  ('dddddddd-000f-4000-8000-000000000005','dddddddd-000e-4000-8000-000000000003','dddddddd-0003-4000-8000-000000000058','no_asistida')
on conflict do nothing;

insert into cubo_movimientos (id, bono_id, atleta_id, tipo, usos, concepto, clase_id, reserva_id, fecha, creado_por)
select ('dddddddd-0011-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.bono, t.atleta, 'consumo', -1, t.concepto, t.clase, t.reserva, t.fecha, 'dddddddd-0001-4000-8000-000000000010'
from (values
  (1, 'dddddddd-0010-4000-8000-000000000001'::uuid,'dddddddd-0003-4000-8000-000000000057'::uuid,'Funcional · fuerza general','dddddddd-000e-4000-8000-000000000001'::uuid,'dddddddd-000f-4000-8000-000000000001'::uuid, '2026-07-28 09:30+02'::timestamptz),
  (2, 'dddddddd-0010-4000-8000-000000000002','dddddddd-0003-4000-8000-000000000058','Funcional · fuerza general','dddddddd-000e-4000-8000-000000000001','dddddddd-000f-4000-8000-000000000002','2026-07-28 09:30+02'),
  (3, 'dddddddd-0010-4000-8000-000000000003','dddddddd-0003-4000-8000-000000000059','Core y movilidad','dddddddd-000e-4000-8000-000000000002','dddddddd-000f-4000-8000-000000000003','2026-07-29 19:00+02'),
  (4, 'dddddddd-0010-4000-8000-000000000001','dddddddd-0003-4000-8000-000000000057','Funcional · fuerza general','dddddddd-000e-4000-8000-000000000003','dddddddd-000f-4000-8000-000000000004','2026-07-30 09:30+02'),
  (5, 'dddddddd-0010-4000-8000-000000000002','dddddddd-0003-4000-8000-000000000058','Funcional · fuerza general (no vino)','dddddddd-000e-4000-8000-000000000003','dddddddd-000f-4000-8000-000000000005','2026-07-30 09:30+02')
) as t(n, bono, atleta, concepto, clase, reserva, fecha)
on conflict do nothing;

-- Reservas futuras: aquí el uso lo descuenta el sistema solo.
insert into cubo_reservas (id, clase_id, atleta_id, estado)
values
  ('dddddddd-000f-4000-8000-000000000006','dddddddd-000e-4000-8000-000000000004','dddddddd-0003-4000-8000-000000000057','reservada'),
  ('dddddddd-000f-4000-8000-000000000007','dddddddd-000e-4000-8000-000000000004','dddddddd-0003-4000-8000-000000000058','reservada'),
  ('dddddddd-000f-4000-8000-000000000008','dddddddd-000e-4000-8000-000000000005','dddddddd-0003-4000-8000-000000000059','reservada'),
  ('dddddddd-000f-4000-8000-000000000009','dddddddd-000e-4000-8000-000000000005','dddddddd-0003-4000-8000-000000000057','reservada'),
  ('dddddddd-000f-4000-8000-000000000010','dddddddd-000e-4000-8000-000000000005','dddddddd-0003-4000-8000-000000000058','reservada'),
  ('dddddddd-000f-4000-8000-000000000011','dddddddd-000e-4000-8000-000000000005','dddddddd-0003-4000-8000-000000000028','reservada'),
  ('dddddddd-000f-4000-8000-000000000012','dddddddd-000e-4000-8000-000000000006','dddddddd-0003-4000-8000-000000000059','reservada'),
  ('dddddddd-000f-4000-8000-000000000013','dddddddd-000e-4000-8000-000000000008','dddddddd-0003-4000-8000-000000000022','reservada'),
  ('dddddddd-000f-4000-8000-000000000014','dddddddd-000e-4000-8000-000000000008','dddddddd-0003-4000-8000-000000000024','reservada'),
  ('dddddddd-000f-4000-8000-000000000015','dddddddd-000e-4000-8000-000000000008','dddddddd-0003-4000-8000-000000000028','reservada'),
  ('dddddddd-000f-4000-8000-000000000016','dddddddd-000e-4000-8000-000000000009','dddddddd-0003-4000-8000-000000000057','reservada'),
  ('dddddddd-000f-4000-8000-000000000017','dddddddd-000e-4000-8000-000000000010','dddddddd-0003-4000-8000-000000000058','reservada'),
  ('dddddddd-000f-4000-8000-000000000018','dddddddd-000e-4000-8000-000000000012','dddddddd-0003-4000-8000-000000000022','reservada')
on conflict do nothing;

commit;

-- =====================================================================
-- Comprobación rápida de lo que ha entrado
-- =====================================================================
select 'perfiles (entrenadores)' as tabla, count(*) from perfiles where id::text like 'dddddddd%'
union all select 'grupos', count(*) from grupos where id::text like 'dddddddd%'
union all select 'atletas', count(*) from atletas where id::text like 'dddddddd%'
union all select 'sesiones', count(*) from sesiones where id::text like 'dddddddd%'
union all select 'marcas_atleta', count(*) from marcas_atleta where id::text like 'dddddddd%'
union all select 'pagos', count(*) from pagos where id::text like 'dddddddd%'
union all select 'competiciones', count(*) from competiciones where id::text like 'dddddddd%'
union all select 'competicion_atleta', count(*) from competicion_atleta where id::text like 'dddddddd%'
union all select 'bono_movimientos', count(*) from bono_movimientos where id::text like 'dddddddd%'
union all select 'avisos', count(*) from avisos where id::text like 'dddddddd%'
union all select 'eventos', count(*) from eventos where id::text like 'dddddddd%'
union all select 'mensajes', count(*) from mensajes where id::text like 'dddddddd%'
union all select 'solicitudes_inscripcion', count(*) from solicitudes_inscripcion where id::text like 'dddddddd%'
union all select 'cubo_clases', count(*) from cubo_clases where id::text like 'dddddddd%'
union all select 'cubo_bonos', count(*) from cubo_bonos where id::text like 'dddddddd%'
union all select 'cubo_reservas', count(*) from cubo_reservas where id::text like 'dddddddd%'
union all select 'cubo_movimientos (con los del sistema)', count(*) from cubo_movimientos
  where bono_id in (select id from cubo_bonos where id::text like 'dddddddd%')
order by 1;
