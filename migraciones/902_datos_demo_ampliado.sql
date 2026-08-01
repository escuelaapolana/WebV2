-- =====================================================================
-- 902_datos_demo_ampliado.sql  ·  EL CLUB A PLENO RENDIMIENTO (FICTICIO)
-- =====================================================================
-- Qué hace: encima de lo que ya dejó 900_datos_demo.sql, añade el club
-- «lleno»: grupos por especialidad (velocistas, vallistas, fondistas,
-- saltos, lanzamientos, marcha), varios niveles de natación, más escuela
-- y más running; muchos más atletas; El Cubo con clases todos los días,
-- listas de espera y bonos gastados; entrenamientos de natación repartidos
-- por CALLES; marcas, recibos, competiciones y eventos.
--
-- TODO lo que crea este archivo lleva un identificador que empieza por
-- «dddddddd-», igual que 900, para que 901_borrar_datos_demo.sql lo
-- pueda quitar todo de un golpe sin tocar los datos reales del club.
-- Se usan tramos nuevos (0021, 0023, 0024…) para no chocar con 900.
--
-- Se puede lanzar las veces que haga falta: no duplica nada.
--
-- Cómo se lanza:   bash .secrets/psql.sh -f migraciones/902_datos_demo_ampliado.sql
-- Cómo se borra:   bash .secrets/psql.sh -f migraciones/901_borrar_datos_demo.sql
--
-- Fecha de referencia: sábado 1 de agosto de 2026.
-- =====================================================================

begin;

-- =====================================================================
-- 1. GRUPOS NUEVOS (por especialidad y por nivel)
-- =====================================================================
-- Los entrenadores son los que ya existían en 900: aquí no se crea
-- ninguna cuenta nueva.
insert into grupos (id, nombre, seccion, entrenador_id, horario, descripcion, activo)
values
  ('dddddddd-0021-4000-8000-000000000001','Vallistas','competicion','dddddddd-0001-4000-8000-000000000001','Lunes, miércoles y viernes 19:00-21:00 · Estadio Joaquín Villar','Vallas cortas y 400 m vallas. Técnica de paso, ritmo entre vallas y trabajo de velocidad específica.', true),
  ('dddddddd-0021-4000-8000-000000000002','Fondistas','competicion','dddddddd-0001-4000-8000-000000000003','Lunes, miércoles y viernes 19:30-21:00 · Pista y Pantano','Del 3.000 al maratón. Series largas en pista, rodajes en el pantano y cross en invierno.', true),
  ('dddddddd-0021-4000-8000-000000000003','Saltos','competicion','dddddddd-0001-4000-8000-000000000002','Martes y jueves 19:00-20:30 · Estadio Joaquín Villar','Longitud, triple, altura y pértiga. Carrera de impulso, batida y mucha técnica.', true),
  ('dddddddd-0021-4000-8000-000000000004','Lanzamientos','competicion','dddddddd-0001-4000-8000-000000000002','Martes y viernes 18:30-20:00 · Jaula y zona de lanzamientos','Peso, disco, jabalina y martillo. Técnica de giro, fuerza general y trabajo de jaula.', true),
  ('dddddddd-0021-4000-8000-000000000005','Marcha','competicion','dddddddd-0001-4000-8000-000000000003','Martes y jueves 19:30-21:00 · Pista y Vía Verde','Marcha en ruta y en pista. Técnica, jueces de control y salidas largas los sábados.', true),
  ('dddddddd-0021-4000-8000-000000000006','Velocistas · Sub-16','competicion','dddddddd-0001-4000-8000-000000000001','Lunes y miércoles 18:00-19:30 · Estadio Joaquín Villar','Cantera de velocidad. Técnica de carrera, salidas y mucha variedad de pruebas.', true),
  ('dddddddd-0021-4000-8000-000000000007','Natación · Iniciación','natacion','dddddddd-0001-4000-8000-000000000007','Martes y jueves 18:15-19:00 · Piscina cubierta','Primer nivel del equipo: crol y espalda bien hechos, viraje sencillo y aguante para 400 m.', true),
  ('dddddddd-0021-4000-8000-000000000008','Natación · Tecnificación','natacion','dddddddd-0001-4000-8000-000000000007','Lunes, miércoles y viernes 19:15-20:30 · Piscina cubierta','Paso previo al grupo de competición: los cuatro estilos, salidas, virajes y series por calles.', true),
  ('dddddddd-0021-4000-8000-000000000009','Natación · Máster','natacion','dddddddd-0001-4000-8000-000000000007','Lunes, miércoles y viernes 21:00-22:00 · Piscina cubierta','Adultos que compiten en categoría máster o nadan por salud. Series cómodas y mucha técnica.', true),
  ('dddddddd-0021-4000-8000-000000000010','Aguas abiertas','natacion','dddddddd-0001-4000-8000-000000000008','Miércoles 21:00 (piscina) y domingos 09:00 (playa, de mayo a septiembre)','Travesías y aguas abiertas. Nado continuo, orientación, salidas desde la arena y pies de otro nadador.', true),
  ('dddddddd-0021-4000-8000-000000000011','Escuela · Sub-16','escuela','dddddddd-0001-4000-8000-000000000006','Lunes y miércoles 18:00-19:15 · Pista municipal','Los mayores de la escuela. Prueban todas las especialidades antes de elegir grupo de competición.', true),
  ('dddddddd-0021-4000-8000-000000000012','Escuela · Benjamines','escuela','dddddddd-0001-4000-8000-000000000005','Martes y jueves 17:15-18:15 · Pista municipal','De 5 a 8 años. Juego, carreras, saltos y lanzamientos con material adaptado.', true),
  ('dddddddd-0021-4000-8000-000000000013','Kilómetro Cero','running','dddddddd-0001-4000-8000-000000000009','Lunes y miércoles 19:30-20:30 · Parque Municipal','Para empezar a correr desde cero o volver después de años parado. Se acaba corriendo 10 km seguidos.', true),
  ('dddddddd-0021-4000-8000-000000000014','Vertical Apolana','montana','dddddddd-0001-4000-8000-000000000009','Jueves 19:00 (cuestas) y domingos 08:30 (salida larga)','Carreras por montaña de media y larga distancia. Desnivel, técnica de bajada y salidas de fin de semana.', true)
on conflict (id) do update set
  nombre = excluded.nombre, seccion = excluded.seccion, entrenador_id = excluded.entrenador_id,
  horario = excluded.horario, descripcion = excluded.descripcion, activo = true;

-- =====================================================================
-- 2. ATLETAS NUEVOS (118)
-- =====================================================================
-- Se insertan por grupos. La categoría va según el año de nacimiento,
-- con el mismo criterio que ya usaba 900.

-- ---- Vallistas (8) --------------------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000001', 'dddddddd-0001-4000-8000-000000000001',
       t.esp, t.lic, t.gym, t.obs
from (values
  (1,'Aitor','Peñarrubia Grau','Aitor','2008-04-12','Sub-20','activo',array['110 m vallas','100 m lisos'],'A-25001'::text, true,'Referencia del grupo en vallas altas.'::text),
  (2,'Rocío','Beltrán Almagro','Rocío','2007-09-03','Sub-23','activo',array['100 m vallas','400 m vallas'],'A-25002', true,'Multidisciplina: vallas cortas y 400 mv.'),
  (3,'Sergio','Ibarra Moliner','Sergio','2010-02-25','Sub-18','activo',array['110 m vallas','60 m vallas'],'A-25003', true, null),
  (4,'Naiara','Cortés Vilaplana','Naiara','2011-06-14','Sub-18','activo',array['100 m vallas','Salto de longitud'],'A-25004', true,'Multidisciplina: vallas y longitud.'),
  (5,'Ismael','Quesada Boix','Isma','2009-11-08','Sub-20','lesionado',array['400 m vallas','400 m lisos'],'A-25005', true,'Fascitis plantar. Solo bici y piscina de momento.'),
  (6,'Berta','Lorenzo Sirvent','Berta','2012-03-30','Sub-16','activo',array['60 m vallas','60 m lisos'],'A-25006', false, null),
  (7,'Unai','Garrigós Pons','Unai','2006-07-19','Sub-23','activo',array['110 m vallas','Decatlón'],'A-25007', true,'Multidisciplina: prueba combinada y vallas.'),
  (8,'Candela','Ripoll Nogués','Candela','2013-01-22','Sub-16','prueba',array['60 m vallas'], null, false,'Un mes de prueba. Viene de gimnasia rítmica.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Fondistas (11) -------------------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000002', 'dddddddd-0001-4000-8000-000000000003',
       t.esp, t.lic, t.gym, t.obs
from (values
  (9,'Aarón','Melgarejo Ruano','Aarón','2004-05-11','Sub-23','activo',array['5.000 m','10.000 m'],'A-25009'::text, true,'Objetivo del año: bajar de 15:00 en 5.000.'::text),
  (10,'Lidia','Cañadas Torregrosa','Lidia','2003-02-18','Absoluto','activo',array['3.000 m obstáculos','1.500 m'],'A-25010', true,'Multidisciplina: obstáculos y 1.500.'),
  (11,'Joaquín','Peral Espinosa','Ximo','1996-10-04','Absoluto','activo',array['10.000 m','Media maratón'],'A-25011', false, null),
  (12,'Nerea','Bautista Colomina','Nerea','2008-08-27','Sub-20','activo',array['1.500 m','3.000 m'],'A-25012', true, null),
  (13,'Rodrigo','Salinas Mompó','Rodri','2009-04-16','Sub-20','activo',array['800 m','1.500 m'],'A-25013', true, null),
  (14,'Tomás','Bonmatí Server','Tomás','2005-03-09','Sub-23','activo',array['5.000 m','3.000 m obstáculos'],'A-25014', true,'Multidisciplina: fondo y obstáculos.'),
  (15,'Alicia','Ferrándiz Prats','Ali','2006-11-23','Sub-23','lesionado',array['1.500 m','3.000 m'],'A-25015', true,'Periostitis. Vuelve progresivo desde septiembre.'),
  (16,'Hugo','Estruch Berenguer','Hugo','2011-05-05','Sub-18','activo',array['800 m','1.000 m'],'A-25016', false, null),
  (17,'Marina','Cerdá Alonso','Marina','1999-01-14','Absoluto','activo',array['Media maratón','10.000 m'],'A-25017', false,'Prepara la media de Santa Pola.'),
  (18,'Iker','Doménech Ávila','Iker','2012-09-12','Sub-16','prueba',array['1.000 m'], null, false,'Dos semanas de prueba.'),
  (19,'Patricia','Solbes Marín','Patri','2007-06-30','Sub-23','baja',array['3.000 m'],'A-25019', false,'Baja por traslado a estudiar fuera.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Saltos (6) -----------------------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000003', 'dddddddd-0001-4000-8000-000000000002',
       t.esp, t.lic, t.gym, t.obs
from (values
  (20,'Diego','Alarcón Requena','Diego','2007-01-28','Sub-23','activo',array['Salto de longitud','Triple salto'],'A-25020'::text, true,'Multidisciplina: longitud y triple.'::text),
  (21,'Ainhoa','Vercher Piera','Ainhoa','2009-07-07','Sub-20','activo',array['Salto de altura'],'A-25021', true, null),
  (22,'Bruno','Talavera Ocaña','Bruno','2010-03-19','Sub-18','activo',array['Salto con pértiga','Salto de longitud'],'A-25022', true,'Único pertiguista del club.'),
  (23,'Vega','Montesinos Ruiz','Vega','2011-10-26','Sub-18','activo',array['Salto de longitud','100 m lisos'],'A-25023', true,'Multidisciplina: longitud y velocidad.'),
  (24,'Marc','Company Escrivá','Marc','2005-12-02','Sub-23','activo',array['Triple salto','Salto de longitud'],'A-25024', true, null),
  (25,'Julia','Ballester Ortuño','Julia','2013-04-15','Sub-16','prueba',array['Salto de altura'], null, false,'Viene del baloncesto, mucha capacidad de salto.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Lanzamientos (5) -----------------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000004', 'dddddddd-0001-4000-8000-000000000002',
       t.esp, t.lic, t.gym, t.obs
from (values
  (26,'Ricardo','Bernabéu Falcó','Ricar','2004-08-21','Sub-23','activo',array['Lanzamiento de peso','Lanzamiento de disco'],'A-25026'::text, true,'Multidisciplina: peso y disco.'::text),
  (27,'Estela','Vilar Pastor','Estela','2008-02-06','Sub-20','activo',array['Lanzamiento de jabalina'],'A-25027', true, null),
  (28,'Nicolás','Aznar Tortosa','Nico','2010-09-29','Sub-18','activo',array['Lanzamiento de disco','Lanzamiento de peso'],'A-25028', true, null),
  (29,'Rebeca','Andújar Sempere','Rebe','2006-04-03','Sub-23','activo',array['Lanzamiento de martillo','Lanzamiento de peso'],'A-25029', true,'La única del club en martillo.'),
  (30,'Álex','Fenoll Cremades','Álex','2012-11-11','Sub-16','activo',array['Lanzamiento de peso'],'A-25030', false, null)
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Marcha (4) -----------------------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000005', 'dddddddd-0001-4000-8000-000000000003',
       t.esp, t.lic, t.gym, t.obs
from (values
  (31,'Salvador','Mengual Pérez','Salva','2003-06-24','Absoluto','activo',array['10.000 m marcha','5.000 m marcha'],'A-25031'::text, true,'Multidisciplina: marcha en pista y en ruta.'::text),
  (32,'Elsa','Torró Bernad','Elsa','2009-03-13','Sub-20','activo',array['5.000 m marcha','3.000 m marcha'],'A-25032', false, null),
  (33,'Iván','Zaragoza Llin','Iván','2011-01-09','Sub-18','activo',array['3.000 m marcha'],'A-25033', false, null),
  (34,'Maite','Ortolá Server','Maite','2012-05-27','Sub-16','activo',array['3.000 m marcha'],'A-25034', false,'Muy buena técnica para la edad.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Velocistas · Sub-16 (9) ----------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000006', 'dddddddd-0001-4000-8000-000000000001',
       t.esp, t.lic, t.gym, t.obs
from (values
  (35,'Óliver','Cantó Ferrer','Óliver','2012-02-14','Sub-16','activo',array['60 m lisos','150 m lisos'],'A-25035'::text, false, null::text),
  (36,'Daniela','Sempere Roig','Dani','2012-07-21','Sub-16','activo',array['60 m lisos','Salto de longitud'],'A-25036', false,'Multidisciplina: velocidad y longitud.'),
  (37,'Adam','Segura Botella','Adam','2013-03-05','Sub-16','activo',array['60 m lisos','300 m lisos'],'A-25037', false, null),
  (38,'Emma','Doménech Requena','Emma','2013-08-18','Sub-16','activo',array['150 m lisos','60 m lisos'],'A-25038', false, null),
  (39,'Pau','Ochoa Miralles','Pau','2012-10-30','Sub-16','activo',array['300 m lisos','60 m vallas'],'A-25039', false,'Multidisciplina: velocidad larga y vallas.'),
  (40,'Valeria','Nadal Grau','Vale','2013-05-12','Sub-16','prueba',array['60 m lisos'], null, false,'Prueba de un mes.'),
  (41,'Enzo','Rico Palomares','Enzo','2012-12-08','Sub-16','activo',array['60 m lisos','Salto de altura'],'A-25041', false,'Multidisciplina: velocidad y altura.'),
  (42,'Jimena','Alcaraz Ruano','Jimena','2013-01-31','Sub-16','activo',array['150 m lisos'],'A-25042', false, null),
  (43,'Gabriel','Puchades Ferri','Gabi','2012-04-24','Sub-16','lesionado',array['60 m lisos'],'A-25043', false,'Esguince de tobillo jugando al fútbol en el patio.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Natación · Iniciación (10) -------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000007', 'dddddddd-0001-4000-8000-000000000007',
       t.esp, t.lic, t.gym, t.obs
from (values
  (44,'Leo','Miralles Cantos','Leo','2015-03-11','Sub-12','activo',array['50 m libres'],'N-25044'::text, false, null::text),
  (45,'Martina','Grau Silvestre','Martina','2015-08-02','Sub-12','activo',array['50 m libres','50 m espalda'],'N-25045', false, null),
  (46,'Bruno','Sanz Ortolá','Bruno','2014-05-19','Sub-14','activo',array['50 m libres'],'N-25046', false, null),
  (47,'Abril','Tormo Belda','Abril','2016-01-27','Sub-12','activo',array['50 m libres'],'N-25047', false,'Le cuesta el viraje, se trabaja aparte.'),
  (48,'Izan','Ripoll Ferrando','Izan','2014-11-06','Sub-14','activo',array['50 m espalda','50 m libres'],'N-25048', false, null),
  (49,'Noa','Berenguer Lledó','Noa','2016-06-15','Sub-12','activo',array['50 m libres'],'N-25049', false, null),
  (50,'Thiago','Ávila Serrano','Thiago','2015-10-23','Sub-12','prueba',array['50 m libres'], null, false,'Dos semanas de prueba.'),
  (51,'Carmen','Pastor Gadea','Carmen','2014-02-09','Sub-14','activo',array['50 m braza','50 m libres'],'N-25051', false,'Multidisciplina: braza y crol.'),
  (52,'Lucía','Torregrosa Beneito','Lucía','2015-12-17','Sub-12','activo',array['50 m espalda'],'N-25052', false, null),
  (53,'Dylan','Cabrera Ponce','Dylan','2014-07-08','Sub-14','baja',array['50 m libres'],'N-25053', false,'Baja por cambio de horario del colegio.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Natación · Tecnificación (9) -----------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000008', 'dddddddd-0001-4000-8000-000000000007',
       t.esp, t.lic, t.gym, t.obs
from (values
  (54,'Marc','Aliaga Ferrer','Marc','2011-04-21','Sub-18','activo',array['100 m libres','200 m libres'],'N-25054'::text, false, null::text),
  (55,'Ainara','Sanchis Ortega','Ainara','2012-01-16','Sub-16','activo',array['100 m espalda','200 m espalda'],'N-25055', false, null),
  (56,'Álvaro','Beneyto Cruz','Álvaro','2010-08-03','Sub-18','activo',array['100 m braza','200 m estilos'],'N-25056', true,'Multidisciplina: braza y estilos.'),
  (57,'Julia','Roca Vilanova','Julia','2012-06-28','Sub-16','activo',array['50 m mariposa','100 m mariposa'],'N-25057', false, null),
  (58,'Samuel','Piera Rovira','Samu','2011-11-14','Sub-18','activo',array['200 m libres','400 m libres'],'N-25058', false, null),
  (59,'Claudia','Esteve Marí','Clau','2013-02-25','Sub-16','activo',array['100 m libres','100 m estilos'],'N-25059', false,'Multidisciplina: crol y estilos.'),
  (60,'Nil','Pina Almendros','Nil','2012-09-07','Sub-16','activo',array['100 m espalda','100 m libres'],'N-25060', false, null),
  (61,'Greta','Bou Escrivá','Greta','2013-07-19','Sub-16','prueba',array['50 m libres','50 m espalda'], null, false,'Viene de la escuela de natación, un mes de prueba.'),
  (62,'Aleix','Llorens Mataix','Aleix','2010-12-30','Sub-18','lesionado',array['200 m estilos','100 m mariposa'],'N-25062', true,'Molestias en el hombro derecho. Solo pies y espalda.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Natación · Máster (8) ------------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000009', 'dddddddd-0001-4000-8000-000000000007',
       t.esp, t.lic, t.gym, t.obs
from (values
  (63,'Ramón','Alemany Gisbert','Ramón','1978-05-14','Máster','activo',array['100 m libres','50 m libres'],'N-25063'::text, false, null::text),
  (64,'Inmaculada','Verdú Sala','Inma','1982-09-26','Máster','activo',array['200 m libres','100 m espalda'],'N-25064', false,'Multidisciplina: crol y espalda.'),
  (65,'José Luis','Marqués Baeza','Jose','1975-03-08','Máster','activo',array['50 m braza','100 m braza'],'N-25065', false, null),
  (66,'Yolanda','Ruescas Camps','Yoli','1986-11-19','Máster','activo',array['100 m libres','200 m estilos'],'N-25066', true, null),
  (67,'Vicente','Mollá Adsuar','Vicent','1970-01-23','Máster','activo',array['50 m libres','50 m mariposa'],'N-25067', false,'El más veterano del grupo, no falla un día.'),
  (68,'Sonia','Aracil Pomares','Sonia','1990-07-02','Máster','activo',array['200 m libres','400 m libres'],'N-25068', false, null),
  (69,'Ángel','Bonet Sirera','Ángel','1968-04-17','Máster','lesionado',array['100 m braza'],'N-25069', false,'Operado de menisco. Solo brazos con pull-buoy.'),
  (70,'Marisa','Guillén Ortuño','Marisa','1984-12-05','Máster','activo',array['100 m espalda','200 m espalda'],'N-25070', false, null)
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Aguas abiertas (6) ---------------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000010', 'dddddddd-0001-4000-8000-000000000008',
       t.esp, t.lic, t.gym, t.obs
from (values
  (71,'Borja','Cremades Tarí','Borja','1993-06-09','Absoluto','activo',array['1.500 m libres','800 m libres'],'N-25071'::text, true,'Travesía de Tabarca todos los años.'::text),
  (72,'Laura','Espí Doménech','Laura','1997-02-21','Absoluto','activo',array['800 m libres','400 m libres'],'N-25072', false, null),
  (73,'Sebastián','Ivorra Ramos','Sebas','1988-10-12','Máster','activo',array['1.500 m libres','Media maratón'],'N-25073', true,'Multidisciplina: aguas abiertas y carrera.'),
  (74,'Ariadna','Girona Peidró','Ari','2005-05-30','Sub-23','activo',array['1.500 m libres','400 m libres'],'N-25074', false, null),
  (75,'Kevin','Terol Blasco','Kevin','2001-08-15','Absoluto','activo',array['800 m libres','1.500 m libres'],'N-25075', false, null),
  (76,'Míriam','Ordóñez Bas','Miri','1991-03-27','Máster','prueba',array['800 m libres'], null, false,'Prueba hasta final de temporada de playa.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Escuela · Sub-16 (9) -------------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000011', 'dddddddd-0001-4000-8000-000000000006',
       t.esp, t.lic, t.gym, t.obs
from (values
  (77,'Marcos','Guardiola Pina','Marcos','2012-03-04','Sub-16','activo',array['60 m lisos','Salto de longitud'],'A-25077'::text, false,'Multidisciplina: velocidad y longitud.'::text),
  (78,'Aroa','Tomás Requena','Aroa','2013-09-16','Sub-16','activo',array['1.000 m','Salto de altura'],'A-25078', false,'Multidisciplina: medio fondo y altura.'),
  (79,'Darío','Ferri Blanquer','Darío','2012-06-22','Sub-16','activo',array['Lanzamiento de peso','60 m lisos'],'A-25079', false, null),
  (80,'Nayara','Bru Sellés','Naya','2013-11-01','Sub-16','activo',array['60 m vallas','Salto de longitud'],'A-25080', false, null),
  (81,'Aitor','Reig Bordera','Aitor R.','2013-02-13','Sub-16','activo',array['1.000 m'],'A-25081', false, null),
  (82,'Ivet','Palau Camarasa','Ivet','2012-08-25','Sub-16','activo',array['Salto de altura','60 m lisos'],'A-25082', false, null),
  (83,'Rayan','Ferrando Chaves','Rayan','2013-05-07','Sub-16','prueba',array['60 m lisos'], null, false,'Prueba de dos semanas.'),
  (84,'Carla','Moltó Peiró','Carla M.','2012-12-19','Sub-16','activo',array['Lanzamiento de jabalina','60 m lisos'],'A-25084', false, null),
  (85,'Jan','Úbeda Ferriols','Jan','2013-07-29','Sub-16','activo',array['1.000 m','60 m vallas'],'A-25085', false,'Multidisciplina: medio fondo y vallas.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Escuela · Benjamines (10) --------------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000012', 'dddddddd-0001-4000-8000-000000000005',
       t.esp, t.lic, t.gym, t.obs
from (values
  (86,'Mateo','Sirvent Bou','Mateo','2018-04-10','Sub-10','activo',array['60 m lisos'], null::text, false, null::text),
  (87,'Vera','Llinares Poveda','Vera','2018-09-21','Sub-10','activo',array['60 m lisos'], null, false, null),
  (88,'Biel','Antolí Vera','Biel','2019-01-15','Sub-10','activo',array['60 m lisos'], null, false, null),
  (89,'Alma','Cerdán Ripoll','Alma','2019-06-03','Sub-10','activo',array['60 m lisos'], null, false, null),
  (90,'Pol','Mira Escandell','Pol','2018-11-27','Sub-10','activo',array['Salto de longitud','60 m lisos'], null, false, null),
  (91,'Lía','Bernabeu Sanjuán','Lía','2020-02-18','Sub-8','activo',array['60 m lisos'], null, false, null),
  (92,'Adrià','Poveda Gil','Adrià','2020-07-09','Sub-8','activo',array['60 m lisos'], null, false,'El más pequeño del club.'),
  (93,'Chloe','Navarro Ferrer','Chloe','2019-10-30','Sub-10','activo',array['60 m lisos'], null, false, null),
  (94,'Sofía','Ortuño Blanes','Sofía','2018-12-12','Sub-10','activo',array['60 m lisos','Salto de longitud'], null, false, null),
  (95,'Arnau','Escoda Ferrándiz','Arnau','2019-03-26','Sub-10','prueba',array['60 m lisos'], null, false,'Prueba de un mes, viene con su hermana.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Kilómetro Cero · running de iniciación (10) --------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000013', 'dddddddd-0001-4000-8000-000000000009',
       t.esp, t.lic, t.gym, t.obs
from (values
  (96,'Pedro Antonio','Ruiz Cutillas','Pedro','1981-02-07','Máster','activo',array['10.000 m'], null::text, false,'Empezó en enero sin correr nada.'::text),
  (97,'Encarna','Gil Poveda','Encarna','1974-06-18','Máster','activo',array['5.000 m','10.000 m'], null, false, null),
  (98,'Alberto','Nieto Villar','Alberto','1989-11-09','Máster','activo',array['10.000 m'], null, true, null),
  (99,'Raquel','Miró Sanchis','Raquel','1993-04-30','Absoluto','activo',array['5.000 m'], null, false, null),
  (100,'Juan Carlos','Reina Amat','Juanca','1971-08-14','Máster','activo',array['10.000 m','Media maratón'],'A-25100', false,'Ya se ha federado para correr la media.'),
  (101,'Verónica','Estopiñá Roig','Vero','1986-01-21','Máster','activo',array['10.000 m'], null, false, null),
  (102,'Fran','Boluda Torres','Fran','1998-09-05','Absoluto','activo',array['5.000 m','10.000 m'], null, true, null),
  (103,'Ximo','Server Aparici','Ximo S.','1977-12-02','Máster','activo',array['Media maratón'],'A-25103', false, null),
  (104,'Lorena','Aparicio Cano','Lorena','1995-07-24','Absoluto','prueba',array['5.000 m'], null, false,'Ha venido dos días de prueba.'),
  (105,'Susana','Vilaplana Cortés','Susana','1990-10-08','Máster','baja',array['5.000 m'], null, false,'Baja voluntaria hasta septiembre.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Vertical Apolana · montaña (6) ---------------------------------
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0021-4000-8000-000000000014', 'dddddddd-0001-4000-8000-000000000009',
       t.esp, t.lic, t.gym, t.obs
from (values
  (106,'Quique','Boix Server','Quique','1987-04-19','Máster','activo',array['Maratón','Media maratón'],'A-25106'::text, true,'Prepara la Penyagolosa.'::text),
  (107,'Ángela','Colomer Micó','Ángela','1992-08-27','Absoluto','activo',array['Media maratón'],'A-25107', false, null),
  (108,'Roberto','Sanz Alarcón','Rober','1979-01-13','Máster','activo',array['Maratón'],'A-25108', true, null),
  (109,'Tania','Escrig Doménech','Tania','1996-05-06','Absoluto','activo',array['Media maratón','10.000 m'],'A-25109', false,'Multidisciplina: montaña y asfalto.'),
  (110,'Aurelio','Pastor Ivorra','Aure','1972-11-23','Máster','activo',array['Maratón','Media maratón'],'A-25110', false, null),
  (111,'Cristóbal','Ferrer Aznar','Cristo','2000-07-15','Absoluto','activo',array['Maratón','10.000 m'],'A-25111', true, null)
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- ---- Refuerzo del grupo de Natación · Perfeccionamiento (7) ---------
-- Este grupo ya existía (lo creó 900) con 4 nadadores. Con estos siete
-- más y el atleta de la cuenta de prueba se llenan las cuatro calles.
insert into atletas (id, nombre, apellidos, nombre_corto, fecha_nacimiento, categoria, estado,
                     grupo_id, entrenador_id, especialidades, licencia, hace_gym, observaciones)
select ('dddddddd-0023-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       t.nombre, t.apellidos, t.corto, t.fnac::date, t.cat, t.estado,
       'dddddddd-0002-4000-8000-000000000008', 'dddddddd-0001-4000-8000-000000000007',
       t.esp, t.lic, t.gym, t.obs
from (values
  (112,'Gerard','Tomás Peiró','Gerard','2009-02-19','Sub-20','activo',array['100 m libres','100 m mariposa'],'N-25112'::text, true,'Multidisciplina: crol y mariposa.'::text),
  (113,'Neus','Ferrando Lledó','Neus','2010-06-11','Sub-18','activo',array['200 m estilos','200 m espalda'],'N-25113', true, null),
  (114,'Marçal','Bataller Sanchis','Marçal','2008-10-25','Sub-20','activo',array['400 m libres','1.500 m libres'],'N-25114', true,'El fondista de la piscina.'),
  (115,'Zoe','Requena Belda','Zoe','2011-03-08','Sub-18','activo',array['50 m libres','100 m libres'],'N-25115', false, null),
  (116,'Jaume','Ferri Colomina','Jaume','2007-12-14','Sub-23','activo',array['100 m braza','200 m braza'],'N-25116', true, null),
  (117,'Mireia','Segarra Bonet','Mireia','2009-08-30','Sub-20','activo',array['200 m mariposa','200 m estilos'],'N-25117', true,'Multidisciplina: mariposa y estilos.'),
  (118,'Guillem','Andreu Peris','Guillem','2012-01-05','Sub-16','prueba',array['100 m espalda','50 m espalda'], null, false,'Sube de Tecnificación un mes a prueba.')
) as t(n,nombre,apellidos,corto,fnac,cat,estado,esp,lic,gym,obs)
on conflict (id) do nothing;

-- =====================================================================
-- 3. LA CUENTA DE PRUEBA PASA A SER NADADORA
-- =====================================================================
-- El atleta enlazado a la cuenta atleta.prueba@apolana.test se mete en
-- el grupo de Natación · Perfeccionamiento, con especialidades de
-- natación, para poder ver la web tal y como la ve un nadador (su calle
-- en cada entrenamiento, sus marcas de piscina, su grupo).
-- 901_borrar_datos_demo.sql lo deja como estaba.
update atletas
   set grupo_id       = 'dddddddd-0002-4000-8000-000000000008',
       entrenador_id  = 'dddddddd-0001-4000-8000-000000000007',
       especialidades = array['100 m libres','200 m libres','100 m estilos'],
       estado         = 'activo',
       observaciones  = 'Nadador de crol medio. Entrena en la calle 2 con Alejandro y Zoe.'
 where id = '2ac18ce3-5740-4a82-bf65-7202ffe54e26';

-- =====================================================================
-- 4. ENTRENAMIENTOS DE NATACIÓN POR CALLES
-- =====================================================================
-- Cada calle es un bloque con su número («calle»), la gente que nada en
-- ella («atletas») y su propio trabajo (series, metros, material, ritmos
-- y observaciones). Los bloques sin «calle» son trabajo de todos.
-- Van publicadas: el nadador ve su calle desde la zona del atleta.

insert into sesiones (id, grupo_id, fecha, dia_semana, tipo, rol, titulo, nota_razonamiento,
                      bloques, publicada, calles, hora, lugar, creado_por)
values
-- ---------- Natación · Perfeccionamiento ----------
('dddddddd-0024-4000-8000-000000000001','dddddddd-0002-4000-8000-000000000008','2026-07-22','miércoles','natacion','secundaria',
 'Aeróbico por calles · 3.000 m',
 'Semana de volumen antes del descanso de agosto. Cada calle lleva su ritmo: no se trata de ir todos juntos, sino de que cada uno aguante el suyo de principio a fin.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave alternando estilos","series":"1","distancia":"400 m","material":["Sin material"],"observaciones":"Entrar en el agua sin prisa."},
    {"ejercicio":"Pies","series":"6","distancia":"50 m","descanso":"15 s","material":["Tabla"],"observaciones":"Tobillo suelto, cadera alta."}
  ]},
  {"etiqueta":"Calle 1","matiz":"Rápidos · velocidad y mariposa","calle":1,
   "atletas":["dddddddd-0003-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000112","dddddddd-0023-4000-8000-000000000117"],
   "filas":[
    {"ejercicio":"Series de 100 crol","series":"10","distancia":"100 m","descanso":"20 s","ritmo":"ritmo de 400","material":["Sin material"],"observaciones":"Pablo: 1:07-1:09 · Gerard: 1:06-1:08 · Mireia: 1:10-1:12"},
    {"ejercicio":"Mariposa técnica","series":"8","distancia":"50 m","descanso":"25 s","material":["Aletas"],"observaciones":"Dos brazadas y respiración. Sin romper el ritmo de piernas."},
    {"ejercicio":"Brazos con palas","series":"4","distancia":"100 m","descanso":"30 s","material":["Palas","Pull-buoy"],"observaciones":"Agarre largo, sin tirar del hombro."}
  ]},
  {"etiqueta":"Calle 2","matiz":"Crol medio","calle":2,
   "atletas":["dddddddd-0003-4000-8000-000000000042","2ac18ce3-5740-4a82-bf65-7202ffe54e26","dddddddd-0023-4000-8000-000000000115"],
   "filas":[
    {"ejercicio":"Series de 100 crol","series":"8","distancia":"100 m","descanso":"25 s","ritmo":"ritmo de 400","material":["Sin material"],"observaciones":"Alejandro: 1:12-1:14 · Prueba: 1:15-1:18 · Zoe: 1:16-1:19"},
    {"ejercicio":"Progresivos de 50","series":"6","distancia":"50 m","descanso":"20 s","material":["Sin material"],"observaciones":"El ultimo de cada tres, fuerte."},
    {"ejercicio":"Brazos","series":"4","distancia":"100 m","descanso":"30 s","material":["Pull-buoy"],"observaciones":"Respiracion cada 3. Cuidado con cruzar la mano."}
  ]},
  {"etiqueta":"Calle 3","matiz":"Fondo","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000114","dddddddd-0003-4000-8000-000000000043","dddddddd-0023-4000-8000-000000000113"],
   "filas":[
    {"ejercicio":"Continuo","series":"1","distancia":"1.000 m","ritmo":"comodo","material":["Sin material"],"observaciones":"Marcal: 13:00-13:20 · Irene: 14:00-14:20 · Neus: 14:10-14:30"},
    {"ejercicio":"Series de 200","series":"5","distancia":"200 m","descanso":"20 s","ritmo":"ritmo de 800","material":["Sin material"],"observaciones":"Marcal: 2:30-2:35 · Irene: 2:45-2:50 · Neus: 2:48-2:52"},
    {"ejercicio":"Pies con aletas","series":"4","distancia":"100 m","descanso":"20 s","material":["Aletas","Tabla"]}
  ]},
  {"etiqueta":"Calle 4","matiz":"Braza y espalda","calle":4,
   "atletas":["dddddddd-0003-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000116","dddddddd-0023-4000-8000-000000000118"],
   "filas":[
    {"ejercicio":"Braza tecnica","series":"10","distancia":"50 m","descanso":"25 s","material":["Sin material"],"observaciones":"Carla y Jaume: patada estrecha. Guillem: solo espalda."},
    {"ejercicio":"Espalda continua","series":"1","distancia":"600 m","material":["Sin material"],"observaciones":"Guillem marca el ritmo, que es el que mejor va de espalda."},
    {"ejercicio":"Pies de braza","series":"6","distancia":"50 m","descanso":"20 s","material":["Tabla"]}
  ]},
  {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave","series":"1","distancia":"200 m","material":["Sin material"],"observaciones":"Espalda y crol suave, soltando hombros."}
  ]}
 ]$j$::jsonb, true, 4, '18:00','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

('dddddddd-0024-4000-8000-000000000002','dddddddd-0002-4000-8000-000000000008','2026-07-30','jueves','natacion','calidad_fuerte',
 'Calidad · series de 100 al ritmo de 200',
 'La sesión fuerte de la semana. Menos metros que el miércoles pero a tope de calidad: se busca el ritmo de competición de 200, no aguantar por aguantar.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]},
    {"ejercicio":"Tecnica de brazada","series":"8","distancia":"25 m","descanso":"15 s","material":["Sin material"],"observaciones":"Un largo de puntos muertos, otro de brazada completa."},
    {"ejercicio":"Progresivos","series":"4","distancia":"50 m","descanso":"20 s","material":["Aletas"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Rapidos","calle":1,
   "atletas":["dddddddd-0003-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000112","dddddddd-0023-4000-8000-000000000117"],
   "filas":[
    {"ejercicio":"100 al ritmo de 200","series":"8","distancia":"100 m","descanso":"1 min","ritmo":"ritmo de 200","material":["Sin material"],"observaciones":"Pablo: 1:02-1:03 · Gerard: 1:01-1:02 · Mireia: 1:05-1:06"},
    {"ejercicio":"25 lanzados","series":"6","distancia":"25 m","descanso":"45 s","ritmo":"maximo","material":["Sin material"],"observaciones":"Sin salida, entrando lanzado desde media piscina."}
  ]},
  {"etiqueta":"Calle 2","matiz":"Crol medio","calle":2,
   "atletas":["dddddddd-0003-4000-8000-000000000042","2ac18ce3-5740-4a82-bf65-7202ffe54e26","dddddddd-0023-4000-8000-000000000115"],
   "filas":[
    {"ejercicio":"100 al ritmo de 200","series":"6","distancia":"100 m","descanso":"1 min 15 s","ritmo":"ritmo de 200","material":["Sin material"],"observaciones":"Alejandro: 1:06-1:08 · Prueba: 1:09-1:11 · Zoe: 1:10-1:12"},
    {"ejercicio":"50 fuertes con salida","series":"6","distancia":"50 m","descanso":"1 min","ritmo":"fuerte","material":["Sin material"],"observaciones":"Salida desde poyete. Prueba: cuidar la entrada, no clavarse."}
  ]},
  {"etiqueta":"Calle 3","matiz":"Fondo","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000114","dddddddd-0003-4000-8000-000000000043","dddddddd-0023-4000-8000-000000000113"],
   "filas":[
    {"ejercicio":"400 a ritmo","series":"3","distancia":"400 m","descanso":"1 min 30 s","ritmo":"ritmo de 800","material":["Sin material"],"observaciones":"Marcal: 4:55-5:00 · Irene: 5:20-5:25 · Neus: 5:25-5:30"},
    {"ejercicio":"100 fuertes","series":"4","distancia":"100 m","descanso":"1 min","ritmo":"fuerte","material":["Palas"]}
  ]},
  {"etiqueta":"Calle 4","matiz":"Braza y espalda","calle":4,
   "atletas":["dddddddd-0003-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000116","dddddddd-0023-4000-8000-000000000118"],
   "filas":[
    {"ejercicio":"100 braza a ritmo","series":"6","distancia":"100 m","descanso":"1 min 15 s","ritmo":"ritmo de 200","material":["Sin material"],"observaciones":"Carla: 1:24-1:26 · Jaume: 1:18-1:20 · Guillem: espalda, 1:20-1:22"},
    {"ejercicio":"Virajes","series":"8","distancia":"25 m","descanso":"30 s","material":["Sin material"],"observaciones":"Llegada y salida de pared, que es donde se pierde el tiempo."}
  ]},
  {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
    {"ejercicio":"Suave a eleccion","series":"1","distancia":"300 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true, 4, '18:00','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

('dddddddd-0024-4000-8000-000000000003','dddddddd-0002-4000-8000-000000000008','2026-08-05','miércoles','natacion','activacion',
 'Velocidad, salidas y virajes',
 'Vuelta después del puente. Poco volumen, mucha chispa: salidas, virajes y series cortas para recuperar sensaciones de agua rápida.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]},
    {"ejercicio":"Pies","series":"8","distancia":"25 m","descanso":"15 s","material":["Aletas","Tabla"]}
  ]},
  {"etiqueta":"Salidas desde poyete","matiz":"Todos","filas":[
    {"ejercicio":"Salida y 15 m","series":"6","distancia":"25 m","descanso":"1 min","material":["Sin material"],"observaciones":"Se cronometra la entrada. Vale mas una buena entrada que dos brazadas mas."}
  ]},
  {"etiqueta":"Calle 1","matiz":"Rapidos","calle":1,
   "atletas":["dddddddd-0003-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000112","dddddddd-0023-4000-8000-000000000117"],
   "filas":[
    {"ejercicio":"25 a tope","series":"8","distancia":"25 m","descanso":"1 min","ritmo":"maximo","material":["Sin material"],"observaciones":"Pablo: 11.8-12.0 · Gerard: 11.6-11.8 · Mireia: 12.6-12.9"},
    {"ejercicio":"Nado facil entre series","series":"4","distancia":"50 m","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 2","matiz":"Crol medio","calle":2,
   "atletas":["dddddddd-0003-4000-8000-000000000042","2ac18ce3-5740-4a82-bf65-7202ffe54e26","dddddddd-0023-4000-8000-000000000115"],
   "filas":[
    {"ejercicio":"25 a tope","series":"6","distancia":"25 m","descanso":"1 min","ritmo":"maximo","material":["Sin material"],"observaciones":"Alejandro: 12.4-12.6 · Prueba: 12.9-13.2 · Zoe: 13.0-13.3"},
    {"ejercicio":"50 con viraje","series":"4","distancia":"50 m","descanso":"1 min","ritmo":"fuerte","material":["Sin material"],"observaciones":"Prueba: llegar a la pared sin frenar la brazada."}
  ]},
  {"etiqueta":"Calle 3","matiz":"Fondo","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000114","dddddddd-0003-4000-8000-000000000043","dddddddd-0023-4000-8000-000000000113"],
   "filas":[
    {"ejercicio":"Series de 75 progresivas","series":"6","distancia":"75 m","descanso":"45 s","material":["Sin material"],"observaciones":"El ultimo largo, fuerte de verdad."},
    {"ejercicio":"Continuo suave","series":"1","distancia":"400 m","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 4","matiz":"Braza y espalda","calle":4,
   "atletas":["dddddddd-0003-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000116","dddddddd-0023-4000-8000-000000000118"],
   "filas":[
    {"ejercicio":"25 de salida de braza","series":"8","distancia":"25 m","descanso":"1 min","material":["Sin material"],"observaciones":"Brazada subacuatica larga. Es donde se gana el 100."},
    {"ejercicio":"Espalda facil","series":"1","distancia":"300 m","material":["Sin material"]}
  ]},
  {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
    {"ejercicio":"Suave y estiramientos en el agua","series":"1","distancia":"200 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true, 4, '18:00','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

-- ---------- Natación · Tecnificación ----------
('dddddddd-0024-4000-8000-000000000004','dddddddd-0021-4000-8000-000000000008','2026-07-21','martes','natacion','secundaria',
 'Los cuatro estilos por calles',
 'En tecnificación toca que cada uno pula su estilo, pero sin dejar de nadar los cuatro. Cada calle trabaja lo suyo y el calentamiento y la vuelta a la calma son comunes.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]},
    {"ejercicio":"Pies","series":"8","distancia":"25 m","descanso":"15 s","material":["Tabla"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Crol","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000054","dddddddd-0023-4000-8000-000000000058","dddddddd-0023-4000-8000-000000000059"],
   "filas":[
    {"ejercicio":"Series de 100","series":"8","distancia":"100 m","descanso":"25 s","ritmo":"ritmo de 400","material":["Sin material"],"observaciones":"Marc: 1:14-1:16 · Samuel: 1:13-1:15 · Claudia: 1:18-1:20"},
    {"ejercicio":"Brazos con palas","series":"4","distancia":"75 m","descanso":"25 s","material":["Palas","Pull-buoy"]}
  ]},
  {"etiqueta":"Calle 2","matiz":"Espalda y estilos","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000055","dddddddd-0023-4000-8000-000000000060","dddddddd-0023-4000-8000-000000000062"],
   "filas":[
    {"ejercicio":"Espalda a ritmo","series":"8","distancia":"75 m","descanso":"25 s","material":["Sin material"],"observaciones":"Ainara: 1:00-1:02 · Nil: 1:02-1:04 · Aleix: solo pies y espalda, hombro."},
    {"ejercicio":"Pies de espalda","series":"6","distancia":"50 m","descanso":"20 s","material":["Aletas"]}
  ]},
  {"etiqueta":"Calle 3","matiz":"Braza y mariposa","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000056","dddddddd-0023-4000-8000-000000000057","dddddddd-0023-4000-8000-000000000061"],
   "filas":[
    {"ejercicio":"Braza tecnica","series":"8","distancia":"50 m","descanso":"25 s","material":["Sin material"],"observaciones":"Alvaro marca el ritmo. Greta va a su aire, que lleva dos semanas."},
    {"ejercicio":"Mariposa por partes","series":"8","distancia":"25 m","descanso":"20 s","material":["Aletas"],"observaciones":"Un largo solo piernas, otro completo."}
  ]},
  {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
    {"ejercicio":"Suave","series":"1","distancia":"200 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true, 3, '19:15','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

('dddddddd-0024-4000-8000-000000000005','dddddddd-0021-4000-8000-000000000008','2026-07-31','viernes','natacion','calidad_fuerte',
 'Series de 50 fuertes y trabajo de viraje',
 'Sesión corta y rápida de final de semana. Se busca nadar bien cansado, que es cuando se rompe la técnica.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave alternando","series":"1","distancia":"400 m","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Crol","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000054","dddddddd-0023-4000-8000-000000000058","dddddddd-0023-4000-8000-000000000059"],
   "filas":[
    {"ejercicio":"50 fuertes","series":"12","distancia":"50 m","descanso":"45 s","ritmo":"fuerte","material":["Sin material"],"observaciones":"Marc: 32-33 s · Samuel: 32-34 s · Claudia: 35-36 s"}
  ]},
  {"etiqueta":"Calle 2","matiz":"Espalda y estilos","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000055","dddddddd-0023-4000-8000-000000000060","dddddddd-0023-4000-8000-000000000062"],
   "filas":[
    {"ejercicio":"50 de espalda fuertes","series":"10","distancia":"50 m","descanso":"45 s","ritmo":"fuerte","material":["Sin material"],"observaciones":"Ainara: 37-38 s · Nil: 38-40 s · Aleix: pies con aletas, sin brazos."}
  ]},
  {"etiqueta":"Calle 3","matiz":"Braza y mariposa","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000056","dddddddd-0023-4000-8000-000000000057","dddddddd-0023-4000-8000-000000000061"],
   "filas":[
    {"ejercicio":"50 de braza y mariposa alternos","series":"10","distancia":"50 m","descanso":"50 s","ritmo":"fuerte","material":["Sin material"],"observaciones":"Julia hace mariposa, Alvaro braza, Greta braza suave."}
  ]},
  {"etiqueta":"Virajes","matiz":"Todos","filas":[
    {"ejercicio":"Llegada, viraje y 10 m","series":"10","distancia":"25 m","descanso":"30 s","material":["Sin material"]}
  ]},
  {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
    {"ejercicio":"Suave","series":"1","distancia":"200 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true, 3, '19:15','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

('dddddddd-0024-4000-8000-000000000006','dddddddd-0021-4000-8000-000000000008','2026-08-06','jueves','natacion','secundaria',
 'Aeróbico con material',
 'Semana de volumen. Mucho pull-buoy y palas para que noten el agarre, y pies con aletas para soltar tobillo.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]},
    {"ejercicio":"Pies","series":"6","distancia":"50 m","descanso":"15 s","material":["Aletas","Tabla"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Crol","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000054","dddddddd-0023-4000-8000-000000000058","dddddddd-0023-4000-8000-000000000059"],
   "filas":[
    {"ejercicio":"Brazos con palas","series":"6","distancia":"150 m","descanso":"30 s","material":["Palas","Pull-buoy"],"observaciones":"Sin pasar de 20 brazadas por largo."},
    {"ejercicio":"Continuo","series":"1","distancia":"600 m","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 2","matiz":"Espalda y estilos","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000055","dddddddd-0023-4000-8000-000000000060","dddddddd-0023-4000-8000-000000000062"],
   "filas":[
    {"ejercicio":"Estilos por 100","series":"6","distancia":"100 m","descanso":"30 s","material":["Sin material"],"observaciones":"Aleix cambia mariposa por espalda mientras dure el hombro."},
    {"ejercicio":"Pies de espalda","series":"8","distancia":"50 m","descanso":"20 s","material":["Aletas"]}
  ]},
  {"etiqueta":"Calle 3","matiz":"Braza y mariposa","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000056","dddddddd-0023-4000-8000-000000000057","dddddddd-0023-4000-8000-000000000061"],
   "filas":[
    {"ejercicio":"Braza con pull-buoy","series":"6","distancia":"100 m","descanso":"30 s","material":["Pull-buoy"]},
    {"ejercicio":"Mariposa con aletas","series":"8","distancia":"25 m","descanso":"20 s","material":["Aletas"]}
  ]},
  {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
    {"ejercicio":"Suave","series":"1","distancia":"200 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true, 3, '19:15','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

-- ---------- Natación · Iniciación ----------
('dddddddd-0024-4000-8000-000000000007','dddddddd-0021-4000-8000-000000000007','2026-07-23','jueves','natacion','secundaria',
 'Crol y espalda · aguantar 400 m',
 'El objetivo del trimestre es que todos acaben nadando 400 m seguidos sin pararse. Se va subiendo la distancia poco a poco y se reparte por calles según lo que aguanta cada uno.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave","series":"1","distancia":"100 m","material":["Sin material"],"observaciones":"Sin prisa, entrando en calor."},
    {"ejercicio":"Pies","series":"6","distancia":"25 m","descanso":"20 s","material":["Tabla"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Los que ya hacen 400","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000046","dddddddd-0023-4000-8000-000000000048","dddddddd-0023-4000-8000-000000000051"],
   "filas":[
    {"ejercicio":"Continuo","series":"1","distancia":"400 m","material":["Sin material"],"observaciones":"Sin pararse en la pared. Si hace falta, se baja el ritmo."},
    {"ejercicio":"Series de 50","series":"6","distancia":"50 m","descanso":"30 s","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 2","matiz":"Crol y espalda","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000052"],
   "filas":[
    {"ejercicio":"Series de 50","series":"8","distancia":"50 m","descanso":"30 s","material":["Sin material"],"observaciones":"Cuatro de crol y cuatro de espalda."},
    {"ejercicio":"Pies con aletas","series":"6","distancia":"25 m","descanso":"20 s","material":["Aletas","Tabla"]}
  ]},
  {"etiqueta":"Calle 3","matiz":"Aprendiendo el viraje","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000047","dddddddd-0023-4000-8000-000000000049","dddddddd-0023-4000-8000-000000000050"],
   "filas":[
    {"ejercicio":"Viraje sencillo","series":"10","distancia":"25 m","descanso":"30 s","material":["Sin material"],"observaciones":"Tocar, girar y empujar. Abril: sin miedo a meter la cabeza."},
    {"ejercicio":"Nado con tabla","series":"6","distancia":"25 m","descanso":"25 s","material":["Tabla"]}
  ]},
  {"etiqueta":"Juego final","matiz":"Todos","filas":[
    {"ejercicio":"Relevos por calles","series":"4","distancia":"25 m","material":["Sin material"],"observaciones":"Se acaba siempre jugando."}
  ]}
 ]$j$::jsonb, true, 3, '18:15','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

('dddddddd-0024-4000-8000-000000000008','dddddddd-0021-4000-8000-000000000007','2026-07-30','jueves','natacion','secundaria',
 'Técnica de brazada y pies',
 'Sesión de técnica pura. Poca distancia, muchas repeticiones cortas y corrección uno a uno.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave","series":"1","distancia":"100 m","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Los que ya hacen 400","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000046","dddddddd-0023-4000-8000-000000000048","dddddddd-0023-4000-8000-000000000051"],
   "filas":[
    {"ejercicio":"Brazada con puntos muertos","series":"8","distancia":"25 m","descanso":"20 s","material":["Sin material"]},
    {"ejercicio":"Series de 100","series":"4","distancia":"100 m","descanso":"40 s","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 2","matiz":"Crol y espalda","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000052"],
   "filas":[
    {"ejercicio":"Respiracion cada 3","series":"8","distancia":"25 m","descanso":"25 s","material":["Sin material"],"observaciones":"Sin sacar toda la cabeza, solo la boca."},
    {"ejercicio":"Espalda con tabla en la tripa","series":"6","distancia":"25 m","descanso":"20 s","material":["Tabla"]}
  ]},
  {"etiqueta":"Calle 3","matiz":"Aprendiendo el viraje","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000047","dddddddd-0023-4000-8000-000000000049","dddddddd-0023-4000-8000-000000000050"],
   "filas":[
    {"ejercicio":"Pies con tabla","series":"10","distancia":"25 m","descanso":"25 s","material":["Tabla"],"observaciones":"Pierna larga, desde la cadera."},
    {"ejercicio":"Deslizamientos de pared","series":"8","distancia":"15 m","descanso":"20 s","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true, 3, '18:15','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

('dddddddd-0024-4000-8000-000000000009','dddddddd-0021-4000-8000-000000000007','2026-08-04','martes','natacion','secundaria',
 'Control de 200 m y juegos',
 'Primer control de la temporada de verano: 200 m cronometrados para ver por dónde anda cada uno. Después, juegos.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave y pies","series":"1","distancia":"150 m","material":["Tabla"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Los que ya hacen 400","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000046","dddddddd-0023-4000-8000-000000000048","dddddddd-0023-4000-8000-000000000051"],
   "filas":[
    {"ejercicio":"200 m cronometrados","series":"1","distancia":"200 m","material":["Sin material"],"observaciones":"Bruno: sobre 3:20 · Izan: 3:25 · Carmen: 3:35"}
  ]},
  {"etiqueta":"Calle 2","matiz":"Crol y espalda","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000044","dddddddd-0023-4000-8000-000000000045","dddddddd-0023-4000-8000-000000000052"],
   "filas":[
    {"ejercicio":"100 m cronometrados","series":"1","distancia":"100 m","material":["Sin material"],"observaciones":"Leo y Martina, crol. Lucia, espalda."}
  ]},
  {"etiqueta":"Calle 3","matiz":"Aprendiendo el viraje","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000047","dddddddd-0023-4000-8000-000000000049","dddddddd-0023-4000-8000-000000000050"],
   "filas":[
    {"ejercicio":"50 m cronometrados","series":"1","distancia":"50 m","material":["Sin material"],"observaciones":"Sin agobios, es solo para saber dónde estamos."}
  ]},
  {"etiqueta":"Juegos","matiz":"Todos","filas":[
    {"ejercicio":"Waterpolo adaptado","series":"1","distancia":"15 min","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true, 3, '18:15','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

-- ---------- Natación · Máster ----------
('dddddddd-0024-4000-8000-000000000010','dddddddd-0021-4000-8000-000000000009','2026-07-24','viernes','natacion','secundaria',
 'Aeróbico de 2.000 m por ritmos',
 'Grupo de máster: cada uno viene de trabajar, así que se busca nadar bien y salir con buen sabor de boca. Tres calles por ritmo para que nadie vaya a rueda de otro.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]},
    {"ejercicio":"Pies","series":"4","distancia":"50 m","descanso":"20 s","material":["Tabla"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Los más rápidos","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000063","dddddddd-0023-4000-8000-000000000066","dddddddd-0023-4000-8000-000000000068"],
   "filas":[
    {"ejercicio":"Series de 200","series":"5","distancia":"200 m","descanso":"30 s","ritmo":"comodo-fuerte","material":["Sin material"],"observaciones":"Ramon: 2:55-3:00 · Yolanda: 3:05-3:10 · Sonia: 3:00-3:05"},
    {"ejercicio":"Brazos con palas","series":"4","distancia":"100 m","descanso":"30 s","material":["Palas","Pull-buoy"]}
  ]},
  {"etiqueta":"Calle 2","matiz":"Ritmo medio","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000064","dddddddd-0023-4000-8000-000000000070","dddddddd-0023-4000-8000-000000000067"],
   "filas":[
    {"ejercicio":"Series de 100","series":"8","distancia":"100 m","descanso":"30 s","material":["Sin material"],"observaciones":"Inma: 1:40 · Marisa: 1:42 · Vicente: 1:38"},
    {"ejercicio":"Espalda suave","series":"4","distancia":"50 m","descanso":"20 s","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 3","matiz":"Técnica y braza","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000065","dddddddd-0023-4000-8000-000000000069"],
   "filas":[
    {"ejercicio":"Braza tecnica","series":"10","distancia":"50 m","descanso":"30 s","material":["Sin material"],"observaciones":"Angel solo brazos, que viene de la rodilla."},
    {"ejercicio":"Brazos con pull-buoy","series":"6","distancia":"50 m","descanso":"25 s","material":["Pull-buoy"]}
  ]},
  {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
    {"ejercicio":"Suave","series":"1","distancia":"200 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true, 3, '21:00','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

('dddddddd-0024-4000-8000-000000000011','dddddddd-0021-4000-8000-000000000009','2026-07-29','miércoles','natacion','calidad_fuerte',
 'Series de 50 y 100 al ritmo de competición',
 'Se acerca el trofeo de Elda, así que toca meter ritmo de competición. Series cortas, descansos largos y a nadar rápido.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave alternando","series":"1","distancia":"400 m","material":["Sin material"]},
    {"ejercicio":"Progresivos","series":"4","distancia":"50 m","descanso":"25 s","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Los más rápidos","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000063","dddddddd-0023-4000-8000-000000000066","dddddddd-0023-4000-8000-000000000068"],
   "filas":[
    {"ejercicio":"100 a ritmo de prueba","series":"6","distancia":"100 m","descanso":"1 min 30 s","ritmo":"ritmo de competicion","material":["Sin material"],"observaciones":"Ramon: 1:12-1:14 · Yolanda: 1:18-1:20 · Sonia: 1:16-1:18"}
  ]},
  {"etiqueta":"Calle 2","matiz":"Ritmo medio","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000064","dddddddd-0023-4000-8000-000000000070","dddddddd-0023-4000-8000-000000000067"],
   "filas":[
    {"ejercicio":"50 fuertes","series":"10","distancia":"50 m","descanso":"1 min","ritmo":"fuerte","material":["Sin material"],"observaciones":"Vicente: 33-34 s (mariposa los pares) · Inma: 40-41 s · Marisa: 41-42 s"}
  ]},
  {"etiqueta":"Calle 3","matiz":"Técnica y braza","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000065","dddddddd-0023-4000-8000-000000000069"],
   "filas":[
    {"ejercicio":"50 de braza a ritmo","series":"8","distancia":"50 m","descanso":"1 min","material":["Sin material"],"observaciones":"Jose Luis: 43-44 s. Angel, solo brazos y sin apretar."}
  ]},
  {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
    {"ejercicio":"Suave","series":"1","distancia":"300 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true, 3, '21:00','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

('dddddddd-0024-4000-8000-000000000012','dddddddd-0021-4000-8000-000000000009','2026-08-05','miércoles','natacion','secundaria',
 'Continuo largo y técnica',
 'Sesión tranquila de mitad de semana. Un continuo largo y después técnica, que en máster es lo que más se agradece.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave","series":"1","distancia":"300 m","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Los más rápidos","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000063","dddddddd-0023-4000-8000-000000000066","dddddddd-0023-4000-8000-000000000068"],
   "filas":[
    {"ejercicio":"Continuo","series":"1","distancia":"1.200 m","ritmo":"comodo","material":["Sin material"],"observaciones":"Sonia sale primera y marca el ritmo."}
  ]},
  {"etiqueta":"Calle 2","matiz":"Ritmo medio","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000064","dddddddd-0023-4000-8000-000000000070","dddddddd-0023-4000-8000-000000000067"],
   "filas":[
    {"ejercicio":"Continuo","series":"1","distancia":"1.000 m","ritmo":"comodo","material":["Sin material"]},
    {"ejercicio":"Pies con aletas","series":"6","distancia":"50 m","descanso":"20 s","material":["Aletas","Tabla"]}
  ]},
  {"etiqueta":"Calle 3","matiz":"Técnica y braza","calle":3,
   "atletas":["dddddddd-0023-4000-8000-000000000065","dddddddd-0023-4000-8000-000000000069"],
   "filas":[
    {"ejercicio":"Braza por partes","series":"10","distancia":"50 m","descanso":"25 s","material":["Sin material"],"observaciones":"Un largo brazos, otro completo."}
  ]},
  {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
    {"ejercicio":"Suave","series":"1","distancia":"200 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true, 3, '21:00','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000007'),

-- ---------- Aguas abiertas ----------
('dddddddd-0024-4000-8000-000000000013','dddddddd-0021-4000-8000-000000000010','2026-07-25','sábado','natacion','secundaria',
 'Travesía en la playa · 2.500 m',
 'Salida en aguas abiertas. Se sale desde la arena, se dan tres vueltas a la boya grande y se practica nadar a los pies de otro.',
 $j$[
  {"etiqueta":"Antes de entrar","matiz":"Todos","filas":[
    {"ejercicio":"Movilidad de hombros en la arena","series":"1","distancia":"10 min","material":["Sin material"],"observaciones":"Gorro naranja obligatorio y nadie se separa del grupo."}
  ]},
  {"etiqueta":"Calle 1","matiz":"Ritmo de travesía","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000071","dddddddd-0023-4000-8000-000000000075","dddddddd-0023-4000-8000-000000000074"],
   "filas":[
    {"ejercicio":"Vueltas a la boya","series":"3","distancia":"700 m","descanso":"1 min","ritmo":"ritmo de travesia","material":["Sin material"],"observaciones":"Borja: 9:30-9:50 · Kevin: 9:50-10:10 · Ariadna: 10:10-10:30"},
    {"ejercicio":"Salidas desde la arena","series":"4","distancia":"100 m","descanso":"2 min","material":["Sin material"],"observaciones":"Entrada corriendo y primeras brazadas fuertes."}
  ]},
  {"etiqueta":"Calle 2","matiz":"Continuo cómodo","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000072","dddddddd-0023-4000-8000-000000000073","dddddddd-0023-4000-8000-000000000076"],
   "filas":[
    {"ejercicio":"Continuo con orientacion","series":"1","distancia":"1.500 m","material":["Sin material"],"observaciones":"Levantar la vista cada seis brazadas. Miriam va en medio del grupo."},
    {"ejercicio":"Nado a los pies","series":"4","distancia":"200 m","descanso":"1 min","material":["Sin material"],"observaciones":"Se turnan de primero cada 200."}
  ]}
 ]$j$::jsonb, true, 2, '09:00','Playa del Postiguet','dddddddd-0001-4000-8000-000000000008'),

('dddddddd-0024-4000-8000-000000000014','dddddddd-0021-4000-8000-000000000010','2026-08-01','sábado','natacion','calidad_fuerte',
 'Simulacro de travesía de 3 km',
 'Ensayo general de la travesía de Tabarca: 3 km sin parar, con avituallamiento a mitad y salida en masa desde la orilla.',
 $j$[
  {"etiqueta":"Antes de entrar","matiz":"Todos","filas":[
    {"ejercicio":"Calentamiento en la orilla","series":"1","distancia":"10 min","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Ritmo de travesía","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000071","dddddddd-0023-4000-8000-000000000075","dddddddd-0023-4000-8000-000000000074"],
   "filas":[
    {"ejercicio":"Continuo a ritmo de prueba","series":"1","distancia":"3.000 m","ritmo":"ritmo de travesia","material":["Sin material"],"observaciones":"Borja: 41-43 min · Kevin: 43-45 min · Ariadna: 45-47 min"}
  ]},
  {"etiqueta":"Calle 2","matiz":"Continuo cómodo","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000072","dddddddd-0023-4000-8000-000000000073","dddddddd-0023-4000-8000-000000000076"],
   "filas":[
    {"ejercicio":"Continuo comodo","series":"1","distancia":"2.000 m","material":["Sin material"],"observaciones":"Sin mirar el reloj. Se trata de acabar entera."}
  ]}
 ]$j$::jsonb, true, 2, '09:00','Playa del Postiguet','dddddddd-0001-4000-8000-000000000008'),

('dddddddd-0024-4000-8000-000000000015','dddddddd-0021-4000-8000-000000000010','2026-08-08','sábado','natacion','secundaria',
 'Piscina · series largas con palas',
 'Sábado de piscina porque la previsión da levante. Series largas con palas para trabajar el agarre que hace falta en mar abierto.',
 $j$[
  {"etiqueta":"Calentamiento","matiz":"Todos","filas":[
    {"ejercicio":"Nado suave","series":"1","distancia":"400 m","material":["Sin material"]}
  ]},
  {"etiqueta":"Calle 1","matiz":"Ritmo de travesía","calle":1,
   "atletas":["dddddddd-0023-4000-8000-000000000071","dddddddd-0023-4000-8000-000000000075","dddddddd-0023-4000-8000-000000000074"],
   "filas":[
    {"ejercicio":"Series de 400","series":"5","distancia":"400 m","descanso":"30 s","ritmo":"ritmo de travesia","material":["Palas"],"observaciones":"Borja: 5:10-5:15 · Kevin: 5:20-5:25 · Ariadna: 5:30-5:35"}
  ]},
  {"etiqueta":"Calle 2","matiz":"Continuo cómodo","calle":2,
   "atletas":["dddddddd-0023-4000-8000-000000000072","dddddddd-0023-4000-8000-000000000073","dddddddd-0023-4000-8000-000000000076"],
   "filas":[
    {"ejercicio":"Series de 300","series":"5","distancia":"300 m","descanso":"40 s","material":["Palas","Pull-buoy"],"observaciones":"Sin apretar. Si duele el hombro, se quitan las palas."}
  ]},
  {"etiqueta":"Vuelta a la calma","matiz":"Todos","filas":[
    {"ejercicio":"Suave","series":"1","distancia":"300 m","material":["Sin material"]}
  ]}
 ]$j$::jsonb, true, 2, '09:30','Piscina cubierta municipal','dddddddd-0001-4000-8000-000000000008')
on conflict (id) do update set
  bloques = excluded.bloques, titulo = excluded.titulo, publicada = true,
  calles = excluded.calles, hora = excluded.hora, lugar = excluded.lugar;

-- =====================================================================
-- 5. ENTRENAMIENTOS DE LOS GRUPOS NUEVOS DE PISTA, ESCUELA Y RUNNING
-- =====================================================================
insert into sesiones (id, grupo_id, fecha, dia_semana, tipo, rol, titulo, nota_razonamiento,
                      bloques, publicada, hora, lugar, creado_por)
values
-- ---------- Vallistas ----------
('dddddddd-0024-4000-8000-000000000016','dddddddd-0021-4000-8000-000000000001','2026-07-22','miércoles','pista','calidad_fuerte',
 'Ritmo entre vallas · la sesión fuerte de la semana',
 'Se trabaja el ritmo real de carrera, con las vallas a la altura y separación de competición. Poca cantidad y recuperaciones completas: en cuanto se rompe el ritmo, se para.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"12 min","calzado":"Zapatillas"},
    {"ejercicio":"Movilidad de cadera y tobillo","series":"1","distancia":"10 min","calzado":"Zapatillas","observaciones":"Especial atencion al aductor."},
    {"ejercicio":"Pasos de valla laterales y frontales","series":"3","distancia":"6 vallas","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Ritmo entre vallas","matiz":"Vallas altas","filas":[
    {"ejercicio":"5 vallas desde tacos","series":"5","distancia":"5 vallas","descanso":"5 min","calzado":"Clavos","ritmo":"ritmo de carrera","observaciones":"Aitor: 3 pasos justos · Sergio: 3 pasos, valla a 1,00 · Unai: sale cada dos series"},
    {"ejercicio":"3 vallas lanzadas","series":"4","distancia":"3 vallas","descanso":"4 min","calzado":"Clavos","observaciones":"Entrada lanzada, sin salida de tacos."}
  ]},
  {"etiqueta":"Ritmo entre vallas","matiz":"Vallas cortas femeninas","filas":[
    {"ejercicio":"5 vallas desde tacos","series":"5","distancia":"5 vallas","descanso":"5 min","calzado":"Clavos","observaciones":"Rocio: 3 pasos · Naiara: 3 pasos justos, cuidado con acortar · Berta: 3 pasos con valla baja"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote suave y estiramientos","series":"1","distancia":"10 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true, '19:00','Estadio Joaquín Villar','dddddddd-0001-4000-8000-000000000001'),

('dddddddd-0024-4000-8000-000000000017','dddddddd-0021-4000-8000-000000000001','2026-07-31','viernes','gym','secundaria',
 'Fuerza y potencia para vallas',
 'Día de gimnasio. Cargas medias movidas rápido: interesa la velocidad de la barra, no el peso que se levanta.',
 $j$[
  {"etiqueta":"Fuerza y potencia","filas":[
    {"ejercicio":"Cargada de fuerza","series":"4x3","carga":"75% RM","observaciones":"Movida rapidisima. Sin llegar a fallo."},
    {"ejercicio":"Sentadilla trasera","series":"4x4","carga":"80% RM"},
    {"ejercicio":"Salto al cajon","series":"4x4","observaciones":"Cajon de 60 cm. Caida amortiguada."}
  ]},
  {"etiqueta":"Prevención","filas":[
    {"ejercicio":"Nordicos de isquios","series":"3x5"},
    {"ejercicio":"Aductor Copenhague","series":"3x8 por lado","observaciones":"Isma solo este bloque, que viene de la fascitis."}
  ]}
 ]$j$::jsonb, true, '19:00','Gimnasio del club','dddddddd-0001-4000-8000-000000000001'),

('dddddddd-0024-4000-8000-000000000018','dddddddd-0021-4000-8000-000000000001','2026-08-05','miércoles','pista','secundaria',
 'Vallas en curva y trabajo de 400 mv',
 'Los de 400 mv necesitan pasar vallas cansados y en curva, que es donde se pierde la carrera. Los de vallas cortas hacen técnica.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote y movilidad","series":"1","distancia":"18 min","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"400 mv","matiz":"Rocío e Isma (sin vallas)","filas":[
    {"ejercicio":"300 m con 5 vallas","series":"3","distancia":"300 m","descanso":"8 min","calzado":"Clavos","observaciones":"Rocio: 45-47 s. Isma hace el mismo trabajo en bici estatica."}
  ]},
  {"etiqueta":"Vallas cortas","matiz":"El resto","filas":[
    {"ejercicio":"3 vallas desde tacos","series":"6","distancia":"3 vallas","descanso":"4 min","calzado":"Clavos"},
    {"ejercicio":"Tecnica de pierna de ataque","series":"4","distancia":"6 vallas","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"10 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true, '19:00','Estadio Joaquín Villar','dddddddd-0001-4000-8000-000000000001'),

-- ---------- Fondistas ----------
('dddddddd-0024-4000-8000-000000000019','dddddddd-0021-4000-8000-000000000002','2026-07-20','lunes','continuo','secundaria',
 'Rodaje largo por el pantano',
 'Rodaje tranquilo de domingo movido al lunes por el calor. Ritmo de conversación de principio a fin: si no se puede hablar, se va demasiado rápido.',
 $j$[
  {"etiqueta":"Rodaje","filas":[
    {"ejercicio":"Carrera continua","series":"1","distancia":"75 min","calzado":"Zapatillas","ritmo":"comodo","observaciones":"Aaron y Tomas: 4:10-4:20 min/km · el resto: 4:40-5:00 min/km"},
    {"ejercicio":"Progresivos finales","series":"6","distancia":"100 m","descanso":"vuelta andando","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Después de correr","filas":[
    {"ejercicio":"Core y estiramientos","series":"1","distancia":"15 min"}
  ]}
 ]$j$::jsonb, true, '19:30','Pantano de Tibi','dddddddd-0001-4000-8000-000000000003'),

('dddddddd-0024-4000-8000-000000000020','dddddddd-0021-4000-8000-000000000002','2026-07-29','miércoles','pista','calidad_fuerte',
 'Series de 1.000 m a ritmo de 10K',
 'La sesión de calidad de la semana. Cinco mil metros de trabajo a ritmo de 10K, con recuperación corta para que no baje la pulsación del todo.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"20 min","calzado":"Zapatillas"},
    {"ejercicio":"Tecnica de carrera","series":"3","distancia":"40 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Serie principal","matiz":"Ritmo de 10K","filas":[
    {"ejercicio":"1.000 m","series":"5","distancia":"1.000 m","descanso":"2 min trotando","calzado":"Zapatillas","ritmo":"ritmo de 10K","observaciones":"Aaron: 3:05-3:08 · Tomas: 3:08-3:12 · Joaquin: 3:20-3:25 · Marina: 3:35-3:40 · Lidia: 3:15-3:20"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"12 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true, '19:30','Estadio Joaquín Villar','dddddddd-0001-4000-8000-000000000003'),

('dddddddd-0024-4000-8000-000000000021','dddddddd-0021-4000-8000-000000000002','2026-08-05','miércoles','pista','secundaria',
 'Cambios de ritmo y obstáculos',
 'Trabajo de cambio de ritmo para los de pista y paso de ría para Lidia y Tomás, que compiten en obstáculos.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote y movilidad","series":"1","distancia":"20 min","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Cambios de ritmo","filas":[
    {"ejercicio":"400 fuerte + 400 suave","series":"6","distancia":"800 m","calzado":"Zapatillas","observaciones":"El fuerte a ritmo de 3.000, el suave sin pararse."}
  ]},
  {"etiqueta":"Obstáculos","matiz":"Lidia y Tomás","filas":[
    {"ejercicio":"Paso de ria","series":"8","distancia":"1 paso","descanso":"2 min","calzado":"Clavos","observaciones":"Alternando pierna de apoyo."}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Trote suave","series":"1","distancia":"10 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true, '19:30','Estadio Joaquín Villar','dddddddd-0001-4000-8000-000000000003'),

-- ---------- Saltos ----------
('dddddddd-0024-4000-8000-000000000022','dddddddd-0021-4000-8000-000000000003','2026-07-23','jueves','pista','calidad_fuerte',
 'Carrera de impulso y batida',
 'Todo el trabajo del día va a la carrera de impulso. Si la carrera no llega bien a la tabla, el salto no existe.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote y movilidad","series":"1","distancia":"18 min","calzado":"Zapatillas"},
    {"ejercicio":"Multisaltos","series":"4","distancia":"20 m","calzado":"Zapatillas","observaciones":"Pata coja y triple salto sin carrera."}
  ]},
  {"etiqueta":"Longitud y triple","matiz":"Diego, Marc y Vega","filas":[
    {"ejercicio":"Carrera de impulso completa","series":"6","distancia":"18 pasos","descanso":"4 min","calzado":"Clavos","observaciones":"Diego: marca a 36,20 m · Marc: 35,40 m · Vega: 30,10 m"},
    {"ejercicio":"Saltos con carrera media","series":"6","descanso":"4 min","calzado":"Clavos"}
  ]},
  {"etiqueta":"Altura y pértiga","matiz":"Ainhoa, Bruno y Julia","filas":[
    {"ejercicio":"Batida en curva","series":"8","descanso":"3 min","calzado":"Clavos","observaciones":"Ainhoa: sin listón, solo entrada."},
    {"ejercicio":"Clavada de pertiga","series":"6","descanso":"3 min","calzado":"Clavos","observaciones":"Bruno, con pertiga corta."}
  ]}
 ]$j$::jsonb, true, '19:00','Estadio Joaquín Villar','dddddddd-0001-4000-8000-000000000002'),

('dddddddd-0024-4000-8000-000000000023','dddddddd-0021-4000-8000-000000000003','2026-08-06','jueves','gym','secundaria',
 'Fuerza específica de saltador',
 'Cargas altas y poca repetición. En saltos manda la fuerza que se aplica en muy poco tiempo.',
 $j$[
  {"etiqueta":"Fuerza","filas":[
    {"ejercicio":"Sentadilla","series":"5x3","carga":"85% RM"},
    {"ejercicio":"Arrancada colgante","series":"4x3","carga":"70% RM"},
    {"ejercicio":"Saltos con lastre","series":"4x5","carga":"10 kg"}
  ]},
  {"etiqueta":"Tobillo y pie","filas":[
    {"ejercicio":"Saltos a la comba","series":"4x60 s"},
    {"ejercicio":"Excentricos de gemelo","series":"3x10"}
  ]}
 ]$j$::jsonb, true, '19:00','Gimnasio del club','dddddddd-0001-4000-8000-000000000002'),

-- ---------- Lanzamientos ----------
('dddddddd-0024-4000-8000-000000000024','dddddddd-0021-4000-8000-000000000004','2026-07-24','viernes','pista','calidad_fuerte',
 'Técnica de giro en la jaula',
 'Sesión de jaula. Muchos lanzamientos con peso de competición y algunos con artefacto más ligero para ganar velocidad de giro.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Movilidad de tronco y hombro","series":"1","distancia":"15 min"},
    {"ejercicio":"Lanzamientos con balon medicinal","series":"4x6","carga":"3 kg"}
  ]},
  {"etiqueta":"Disco y martillo","matiz":"Ricardo, Nicolás y Rebeca","filas":[
    {"ejercicio":"Giros sin artefacto","series":"6","observaciones":"Pie de apoyo firme, cadera por delante."},
    {"ejercicio":"Lanzamientos completos","series":"12","descanso":"2 min","observaciones":"Ricardo: disco 1,75 kg · Nicolas: disco 1,5 kg · Rebeca: martillo 4 kg"}
  ]},
  {"etiqueta":"Peso y jabalina","matiz":"Estela y Álex","filas":[
    {"ejercicio":"Lanzamientos desde parado","series":"10","descanso":"1 min 30 s"},
    {"ejercicio":"Lanzamientos con carrera","series":"8","descanso":"2 min","observaciones":"Estela: jabalina 500 g · Alex: peso 4 kg"}
  ]}
 ]$j$::jsonb, true, '18:30','Zona de lanzamientos','dddddddd-0001-4000-8000-000000000002'),

('dddddddd-0024-4000-8000-000000000025','dddddddd-0021-4000-8000-000000000004','2026-08-04','martes','gym','secundaria',
 'Fuerza general de lanzador',
 'Sesión de fuerza de base. Sin prisa, técnica limpia y descansos largos.',
 $j$[
  {"etiqueta":"Fuerza","filas":[
    {"ejercicio":"Press banca","series":"5x5","carga":"80% RM"},
    {"ejercicio":"Sentadilla frontal","series":"4x5","carga":"75% RM"},
    {"ejercicio":"Peso muerto","series":"4x4","carga":"80% RM"}
  ]},
  {"etiqueta":"Tronco","filas":[
    {"ejercicio":"Giros con balon medicinal","series":"4x10","carga":"5 kg"},
    {"ejercicio":"Plancha lateral","series":"3x45 s por lado"}
  ]}
 ]$j$::jsonb, true, '18:30','Gimnasio del club','dddddddd-0001-4000-8000-000000000002'),

-- ---------- Marcha ----------
('dddddddd-0024-4000-8000-000000000026','dddddddd-0021-4000-8000-000000000005','2026-07-21','martes','pista','calidad_fuerte',
 'Series de 1.000 m en marcha',
 'Series a ritmo de competición con un juez mirando la técnica. Vale más marchar bien que marchar rápido: si hay pérdida de contacto, se corta la serie.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Marcha suave","series":"1","distancia":"15 min","calzado":"Zapatillas"},
    {"ejercicio":"Tecnica de cadera","series":"4","distancia":"50 m","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Serie principal","filas":[
    {"ejercicio":"1.000 m marcha","series":"6","distancia":"1.000 m","descanso":"2 min","calzado":"Zapatillas","observaciones":"Salva: 4:15-4:20 · Elsa: 4:50-4:55 · Ivan: 5:05-5:10 · Maite: 5:20-5:25"}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Marcha suave","series":"1","distancia":"10 min","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true, '19:30','Estadio Joaquín Villar','dddddddd-0001-4000-8000-000000000003'),

('dddddddd-0024-4000-8000-000000000027','dddddddd-0021-4000-8000-000000000005','2026-08-08','sábado','continuo','secundaria',
 'Salida larga por la Vía Verde',
 'Salida larga de sábado. Ritmo cómodo y toda la atención puesta en no perder la técnica cuando aparece el cansancio.',
 $j$[
  {"etiqueta":"Salida larga","filas":[
    {"ejercicio":"Marcha continua","series":"1","distancia":"14 km","ritmo":"comodo","observaciones":"Salva: 14 km · Elsa: 10 km · Ivan y Maite: 8 km"},
    {"ejercicio":"Ultimo kilometro a ritmo","series":"1","distancia":"1 km","ritmo":"ritmo de competicion"}
  ]}
 ]$j$::jsonb, true, '08:30','Vía Verde del Maigmó','dddddddd-0001-4000-8000-000000000003'),

-- ---------- Velocistas · Sub-16 ----------
('dddddddd-0024-4000-8000-000000000028','dddddddd-0021-4000-8000-000000000006','2026-07-22','miércoles','pista','calidad_fuerte',
 'Salidas y velocidad corta',
 'A esta edad interesa correr rápido y poco. Muchas salidas, descansos largos y ningún ejercicio que canse de más.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Juegos de reacción","series":"1","distancia":"10 min","calzado":"Zapatillas"},
    {"ejercicio":"Tecnica de carrera","series":"4","distancia":"30 m","calzado":"Zapatillas","observaciones":"Skipping, talones y rodillas."}
  ]},
  {"etiqueta":"Velocidad","filas":[
    {"ejercicio":"Salidas de tres apoyos","series":"6","distancia":"20 m","descanso":"2 min","calzado":"Zapatillas"},
    {"ejercicio":"30 m lanzados","series":"4","distancia":"30 m","descanso":"3 min","calzado":"Clavos","observaciones":"Oliver: 3.9-4.0 s · Adam: 4.0-4.1 s · Daniela: 4.2-4.3 s"}
  ]},
  {"etiqueta":"Juego final","filas":[
    {"ejercicio":"Relevos por equipos","series":"4","distancia":"40 m"}
  ]}
 ]$j$::jsonb, true, '18:00','Estadio Joaquín Villar','dddddddd-0001-4000-8000-000000000001'),

('dddddddd-0024-4000-8000-000000000029','dddddddd-0021-4000-8000-000000000006','2026-08-05','miércoles','pista','secundaria',
 'Multisaltos y velocidad larga',
 'Se prueba un poco de todo, que a estas edades no toca especializarse: saltos, algo de vallas y una serie de 150 para aguantar la velocidad.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote y movilidad","series":"1","distancia":"12 min","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Multisaltos","filas":[
    {"ejercicio":"Saltos horizontales","series":"4","distancia":"20 m","calzado":"Zapatillas"},
    {"ejercicio":"Vallas bajas","series":"4","distancia":"5 vallas","calzado":"Zapatillas","observaciones":"Pau y Enzo, con valla un poco mas alta."}
  ]},
  {"etiqueta":"Velocidad larga","filas":[
    {"ejercicio":"150 m","series":"3","distancia":"150 m","descanso":"6 min","calzado":"Clavos","observaciones":"Jimena: 21.5-22.0 s · Emma: 21.8-22.3 s · Pau: 20.5-21.0 s"}
  ]}
 ]$j$::jsonb, true, '18:00','Estadio Joaquín Villar','dddddddd-0001-4000-8000-000000000001'),

-- ---------- Escuela · Sub-16 ----------
('dddddddd-0024-4000-8000-000000000030','dddddddd-0021-4000-8000-000000000011','2026-07-20','lunes','pista','secundaria',
 'Probamos lanzamientos y saltos',
 'En la escuela se prueba todo. Hoy toca peso y jabalina con material ligero, y longitud desde carrera corta.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Juego de calentamiento","series":"1","distancia":"12 min","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Lanzamientos","filas":[
    {"ejercicio":"Peso desde parado","series":"10","carga":"3 kg","observaciones":"Dario y Carla, que son los que mejor lo cogen, con 4 kg."},
    {"ejercicio":"Jabalina de goma","series":"10"}
  ]},
  {"etiqueta":"Saltos","filas":[
    {"ejercicio":"Longitud con carrera corta","series":"8","distancia":"8 pasos","calzado":"Zapatillas"}
  ]}
 ]$j$::jsonb, true, '18:00','Pista municipal','dddddddd-0001-4000-8000-000000000006'),

('dddddddd-0024-4000-8000-000000000031','dddddddd-0021-4000-8000-000000000011','2026-08-05','miércoles','pista','secundaria',
 'Velocidad, vallas y un poco de fondo',
 'Sesión variada de escuela. Se acaba con una carrera continua suave para los que quieren probar el medio fondo.',
 $j$[
  {"etiqueta":"Parte inicial","filas":[
    {"ejercicio":"Trote y juegos","series":"1","distancia":"12 min","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Velocidad y vallas","filas":[
    {"ejercicio":"Salidas","series":"6","distancia":"20 m","descanso":"2 min","calzado":"Zapatillas"},
    {"ejercicio":"Vallas bajas","series":"6","distancia":"4 vallas","calzado":"Zapatillas","observaciones":"Nayara y Jan, que van a probar el 60 mv en el control."}
  ]},
  {"etiqueta":"Medio fondo","matiz":"Aroa, Aitor y Jan","filas":[
    {"ejercicio":"Carrera continua","series":"1","distancia":"12 min","calzado":"Zapatillas","ritmo":"comodo"}
  ]}
 ]$j$::jsonb, true, '18:00','Pista municipal','dddddddd-0001-4000-8000-000000000006'),

-- ---------- Escuela · Benjamines ----------
('dddddddd-0024-4000-8000-000000000032','dddddddd-0021-4000-8000-000000000012','2026-07-21','martes','pista','secundaria',
 'Circuito de juegos y carreras',
 'Con los pequeños todo es juego. El circuito toca carrera, salto y lanzamiento sin que se den cuenta.',
 $j$[
  {"etiqueta":"Calentamiento","filas":[
    {"ejercicio":"Pilla-pilla de colores","series":"1","distancia":"8 min"}
  ]},
  {"etiqueta":"Circuito","filas":[
    {"ejercicio":"Carrera entre conos","series":"4","distancia":"20 m"},
    {"ejercicio":"Saltos en aros","series":"4","distancia":"10 aros"},
    {"ejercicio":"Lanzamiento de pelota","series":"6","carga":"200 g"}
  ]},
  {"etiqueta":"Final","filas":[
    {"ejercicio":"Relevos por equipos","series":"3","distancia":"30 m","observaciones":"Se acaba con la carrera de los padres el ultimo dia del mes."}
  ]}
 ]$j$::jsonb, true, '17:15','Pista municipal','dddddddd-0001-4000-8000-000000000005'),

('dddddddd-0024-4000-8000-000000000033','dddddddd-0021-4000-8000-000000000012','2026-08-06','jueves','pista','secundaria',
 'Saltamos y lanzamos',
 'Sesión de saltos y lanzamientos con material adaptado. Mucha repetición corta y cambio de estación cada cinco minutos.',
 $j$[
  {"etiqueta":"Calentamiento","filas":[
    {"ejercicio":"Juego del semaforo","series":"1","distancia":"8 min"}
  ]},
  {"etiqueta":"Estaciones","filas":[
    {"ejercicio":"Salto de longitud desde parado","series":"8"},
    {"ejercicio":"Salto de altura con goma","series":"8"},
    {"ejercicio":"Lanzamiento de vortex","series":"8"}
  ]},
  {"etiqueta":"Final","filas":[
    {"ejercicio":"Carrera de sacos","series":"2","distancia":"20 m"}
  ]}
 ]$j$::jsonb, true, '17:15','Pista municipal','dddddddd-0001-4000-8000-000000000005'),

-- ---------- Kilómetro Cero ----------
('dddddddd-0024-4000-8000-000000000034','dddddddd-0021-4000-8000-000000000013','2026-07-22','miércoles','continuo','secundaria',
 'Andar y correr · semana 6',
 'Sexta semana del plan. Ya se corre más de lo que se anda, que es donde la gente empieza a creérselo.',
 $j$[
  {"etiqueta":"Calentamiento","filas":[
    {"ejercicio":"Caminar rapido","series":"1","distancia":"8 min","calzado":"Zapatillas"},
    {"ejercicio":"Movilidad","series":"1","distancia":"5 min"}
  ]},
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Correr 5 min y andar 1 min","series":"5","distancia":"30 min","calzado":"Zapatillas","ritmo":"comodo","observaciones":"Se tiene que poder hablar mientras se corre. Si no, mas despacio."}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Caminar y estirar","series":"1","distancia":"10 min"}
  ]}
 ]$j$::jsonb, true, '19:30','Parque Municipal','dddddddd-0001-4000-8000-000000000009'),

('dddddddd-0024-4000-8000-000000000035','dddddddd-0021-4000-8000-000000000013','2026-08-05','miércoles','continuo','secundaria',
 'Primer continuo de 30 minutos',
 'El día que todo el grupo corre media hora seguida sin andar. Ritmo el que salga, lo importante es no parar.',
 $j$[
  {"etiqueta":"Calentamiento","filas":[
    {"ejercicio":"Caminar y movilidad","series":"1","distancia":"10 min"}
  ]},
  {"etiqueta":"Parte principal","filas":[
    {"ejercicio":"Carrera continua","series":"1","distancia":"30 min","calzado":"Zapatillas","ritmo":"comodo","observaciones":"Alberto y Fran, si van sobrados, que acompañen a los de atras."}
  ]},
  {"etiqueta":"Vuelta a la calma","filas":[
    {"ejercicio":"Caminar y estirar","series":"1","distancia":"10 min"}
  ]}
 ]$j$::jsonb, true, '19:30','Parque Municipal','dddddddd-0001-4000-8000-000000000009'),

-- ---------- Vertical Apolana ----------
('dddddddd-0024-4000-8000-000000000036','dddddddd-0021-4000-8000-000000000014','2026-07-23','jueves','continuo','calidad_fuerte',
 'Cuestas en la subida a la Ermita',
 'Sesión de fuerza en cuesta. Se sube fuerte y se baja andando: la bajada rápida destroza las piernas y hoy no toca.',
 $j$[
  {"etiqueta":"Calentamiento","filas":[
    {"ejercicio":"Trote suave hasta la cuesta","series":"1","distancia":"20 min","calzado":"Zapatillas"}
  ]},
  {"etiqueta":"Cuestas","filas":[
    {"ejercicio":"Subida fuerte","series":"8","distancia":"400 m","descanso":"bajada andando","calzado":"Zapatillas de trail","observaciones":"Quique y Cristobal: las 8. Aurelio y Angela: 6."}
  ]},
  {"etiqueta":"Vuelta","filas":[
    {"ejercicio":"Trote de vuelta","series":"1","distancia":"15 min","calzado":"Zapatillas de trail"}
  ]}
 ]$j$::jsonb, true, '19:00','Subida a la Ermita','dddddddd-0001-4000-8000-000000000009'),

('dddddddd-0024-4000-8000-000000000037','dddddddd-0021-4000-8000-000000000014','2026-08-09','domingo','continuo','secundaria',
 'Salida larga a la Font Roja',
 'Salida larga de domingo con desnivel de verdad. Se lleva comida y agua, y se para arriba a almorzar.',
 $j$[
  {"etiqueta":"Salida","filas":[
    {"ejercicio":"Carrera y caminata por montaña","series":"1","distancia":"24 km","calzado":"Zapatillas de trail","observaciones":"1.100 m de desnivel positivo. Se sube andando lo que haga falta."},
    {"ejercicio":"Bajada tecnica","series":"1","distancia":"6 km","calzado":"Zapatillas de trail","observaciones":"Pies rapidos y mirada lejos."}
  ]}
 ]$j$::jsonb, true, '08:30','Parque Natural de la Font Roja','dddddddd-0001-4000-8000-000000000009')
on conflict (id) do update set
  bloques = excluded.bloques, titulo = excluded.titulo, publicada = true,
  hora = excluded.hora, lugar = excluded.lugar;

-- =====================================================================
-- 6. MARCAS DE LOS ATLETAS NUEVOS
-- =====================================================================
-- Mezcla de marca personal (mmp), mejor del año (temporada) y algún
-- objetivo, en competición y en entrenamiento, con progresión a lo
-- largo de la temporada.
insert into marcas_atleta (id, atleta_id, prueba, tipo, tiempo_segundos, tiempo_display, fecha, sede, contexto)
select ('dddddddd-0025-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       ('dddddddd-0023-4000-8000-' || lpad(t.a::text, 12, '0'))::uuid,
       t.prueba, t.tipo, t.seg, t.disp, t.fecha::date, t.sede, t.ctx
from (values
  -- Vallistas
  (1,1,'110 m vallas','temporada',15.42,'15.42','2026-03-21','Alicante','competicion'::text),
  (2,1,'110 m vallas','mmp',14.87,'14.87','2026-06-13','Valencia','competicion'),
  (3,1,'110 m vallas','objetivo',14.50,'14.50','2026-09-05','Objetivo de temporada',null),
  (4,2,'100 m vallas','temporada',15.10,'15.10','2026-04-11','Elche','competicion'),
  (5,2,'100 m vallas','mmp',14.62,'14.62','2026-06-27','Alicante','competicion'),
  (6,2,'400 m vallas','mmp',64.20,'1:04.20','2026-05-30','Castellón','competicion'),
  (7,3,'110 m vallas','temporada',16.30,'16.30','2026-05-09','Petrer','competicion'),
  (8,3,'110 m vallas','mmp',15.88,'15.88','2026-07-04','Alicante','competicion'),
  (9,4,'100 m vallas','mmp',15.44,'15.44','2026-06-06','Elda','competicion'),
  (10,4,'Salto de longitud','temporada',5.12,'5.12','2026-04-25','Alicante','entreno'),
  (11,5,'400 m vallas','mmp',57.90,'57.90','2026-05-16','Valencia','competicion'),
  (12,6,'60 m vallas','mmp',9.68,'9.68','2026-02-14','Alicante','competicion'),
  (13,7,'110 m vallas','mmp',15.02,'15.02','2026-06-20','Castellón','competicion'),
  (14,7,'Decatlón','mmp',6240,'6.240 puntos','2026-05-24','Castellón','competicion'),
  -- Fondistas
  (15,9,'5.000 m','temporada',922.40,'15:22.40','2026-05-02','Alicante','competicion'),
  (16,9,'5.000 m','mmp',904.80,'15:04.80','2026-06-19','Valencia','competicion'),
  (17,9,'10.000 m','mmp',1900.00,'31:40.00','2026-03-14','Elche','competicion'),
  (18,10,'3.000 m obstáculos','mmp',638.20,'10:38.20','2026-06-06','Castellón','competicion'),
  (19,10,'1.500 m','mmp',278.90,'4:38.90','2026-05-23','Alicante','competicion'),
  (20,11,'10.000 m','mmp',2050.00,'34:10.00','2026-02-22','Elda','competicion'),
  (21,11,'Media maratón','mmp',4540.00,'1:15:40','2026-01-25','Santa Pola','competicion'),
  (22,12,'1.500 m','temporada',292.30,'4:52.30','2026-04-18','Alicante','competicion'),
  (23,12,'1.500 m','mmp',286.10,'4:46.10','2026-06-27','Valencia','competicion'),
  (24,13,'800 m','temporada',122.40,'2:02.40','2026-05-09','Petrer','competicion'),
  (25,13,'800 m','mmp',118.70,'1:58.70','2026-07-04','Alicante','competicion'),
  (26,14,'5.000 m','mmp',920.10,'15:20.10','2026-06-13','Valencia','competicion'),
  (27,14,'3.000 m obstáculos','mmp',568.60,'9:28.60','2026-05-30','Castellón','competicion'),
  (28,15,'1.500 m','mmp',284.20,'4:44.20','2026-03-07','Alicante','competicion'),
  (29,16,'800 m','mmp',128.90,'2:08.90','2026-06-20','Elche','competicion'),
  (30,16,'1.000 m','temporada',168.00,'2:48.00','2026-07-15','Estadio Joaquín Villar','entreno'),
  (31,17,'Media maratón','mmp',5310.00,'1:28:30','2026-01-25','Santa Pola','competicion'),
  (32,17,'10.000 m','mmp',2390.00,'39:50.00','2026-04-12','Alicante','competicion'),
  (33,19,'3.000 m','mmp',640.00,'10:40.00','2025-11-15','Alicante','competicion'),
  -- Saltos
  (34,20,'Salto de longitud','temporada',6.84,'6.84','2026-04-25','Elche','competicion'),
  (35,20,'Salto de longitud','mmp',7.12,'7.12','2026-06-13','Valencia','competicion'),
  (36,20,'Triple salto','mmp',14.32,'14.32','2026-05-16','Alicante','competicion'),
  (37,21,'Salto de altura','temporada',1.58,'1.58','2026-03-14','Alicante','competicion'),
  (38,21,'Salto de altura','mmp',1.66,'1.66','2026-06-06','Alicante','competicion'),
  (39,22,'Salto con pértiga','mmp',4.20,'4.20','2026-05-30','Valencia','competicion'),
  (40,22,'Salto de longitud','temporada',6.05,'6.05','2026-04-11','Petrer','competicion'),
  (41,23,'Salto de longitud','mmp',5.48,'5.48','2026-06-27','Alicante','competicion'),
  (42,23,'100 m lisos','temporada',12.94,'12.94','2026-05-09','Elda','competicion'),
  (43,24,'Triple salto','mmp',14.86,'14.86','2026-06-20','Castellón','competicion'),
  (44,24,'Salto de longitud','temporada',6.72,'6.72','2026-04-18','Alicante','competicion'),
  (45,25,'Salto de altura','temporada',1.42,'1.42','2026-07-18','Petrer','entreno'),
  -- Lanzamientos
  (46,26,'Lanzamiento de peso','mmp',14.86,'14.86','2026-05-23','Alicante','competicion'),
  (47,26,'Lanzamiento de disco','mmp',45.20,'45.20','2026-06-13','Valencia','competicion'),
  (48,27,'Lanzamiento de jabalina','temporada',34.90,'34.90','2026-03-21','Alicante','competicion'),
  (49,27,'Lanzamiento de jabalina','mmp',38.44,'38.44','2026-06-06','Elche','competicion'),
  (50,28,'Lanzamiento de disco','mmp',38.60,'38.60','2026-05-16','Alicante','competicion'),
  (51,28,'Lanzamiento de peso','mmp',12.34,'12.34','2026-04-25','Petrer','competicion'),
  (52,29,'Lanzamiento de martillo','mmp',48.72,'48.72','2026-06-20','Valencia','competicion'),
  (53,29,'Lanzamiento de peso','temporada',11.90,'11.90','2026-05-09','Alicante','competicion'),
  (54,30,'Lanzamiento de peso','mmp',10.42,'10.42','2026-06-13','Elda','competicion'),
  -- Marcha
  (55,31,'10.000 m marcha','mmp',2660.00,'44:20.00','2026-04-12','Alicante','competicion'),
  (56,31,'5.000 m marcha','mmp',1295.00,'21:35.00','2026-06-06','Valencia','competicion'),
  (57,32,'5.000 m marcha','temporada',1600.00,'26:40.00','2026-02-28','Alicante','competicion'),
  (58,32,'5.000 m marcha','mmp',1510.00,'25:10.00','2026-05-23','Alicante','competicion'),
  (59,33,'3.000 m marcha','mmp',920.00,'15:20.00','2026-06-13','Elche','competicion'),
  (60,34,'3.000 m marcha','mmp',965.00,'16:05.00','2026-06-20','Petrer','competicion'),
  -- Velocistas Sub-16
  (61,35,'60 m lisos','mmp',8.12,'8.12','2026-02-14','Alicante','competicion'),
  (62,35,'150 m lisos','temporada',18.90,'18.90','2026-06-13','Petrer','competicion'),
  (63,36,'60 m lisos','mmp',8.65,'8.65','2026-02-14','Alicante','competicion'),
  (64,36,'Salto de longitud','temporada',4.62,'4.62','2026-05-09','Elda','competicion'),
  (65,37,'60 m lisos','mmp',8.34,'8.34','2026-03-07','Alicante','competicion'),
  (66,38,'150 m lisos','mmp',20.10,'20.10','2026-06-20','Petrer','competicion'),
  (67,39,'300 m lisos','mmp',41.20,'41.20','2026-06-06','Alicante','competicion'),
  (68,39,'60 m vallas','temporada',10.20,'10.20','2026-02-21','Valencia','competicion'),
  (69,41,'60 m lisos','mmp',8.40,'8.40','2026-02-28','Alicante','competicion'),
  (70,41,'Salto de altura','temporada',1.45,'1.45','2026-05-23','Elche','competicion'),
  (71,42,'150 m lisos','mmp',20.85,'20.85','2026-05-30','Petrer','competicion'),
  (72,43,'60 m lisos','mmp',8.50,'8.50','2026-01-31','Alicante','competicion'),
  -- Natación · Iniciación
  (73,44,'50 m libres','temporada',48.90,'48.90','2026-03-14','Elda','competicion'),
  (74,44,'50 m libres','mmp',45.20,'45.20','2026-06-13','Elda','competicion'),
  (75,45,'50 m libres','mmp',44.10,'44.10','2026-06-13','Elda','competicion'),
  (76,45,'50 m espalda','mmp',52.30,'52.30','2026-05-09','Alicante','competicion'),
  (77,46,'50 m libres','mmp',39.80,'39.80','2026-06-13','Elda','competicion'),
  (78,47,'50 m libres','mmp',52.40,'52.40','2026-06-13','Elda','competicion'),
  (79,48,'50 m espalda','mmp',49.80,'49.80','2026-05-09','Alicante','competicion'),
  (80,48,'50 m libres','mmp',42.60,'42.60','2026-06-13','Elda','competicion'),
  (81,49,'50 m libres','temporada',55.10,'55.10','2026-07-16','Piscina cubierta municipal','entreno'),
  (82,51,'50 m braza','mmp',55.60,'55.60','2026-06-13','Elda','competicion'),
  (83,51,'50 m libres','mmp',44.90,'44.90','2026-06-13','Elda','competicion'),
  (84,52,'50 m espalda','mmp',51.20,'51.20','2026-06-13','Elda','competicion'),
  -- Natación · Tecnificación
  (85,54,'100 m libres','mmp',64.30,'1:04.30','2026-05-16','Alicante','competicion'),
  (86,54,'200 m libres','mmp',140.80,'2:20.80','2026-06-13','Valencia','competicion'),
  (87,55,'100 m espalda','mmp',75.40,'1:15.40','2026-05-16','Alicante','competicion'),
  (88,55,'200 m espalda','mmp',162.60,'2:42.60','2026-06-13','Valencia','competicion'),
  (89,56,'100 m braza','mmp',78.20,'1:18.20','2026-06-13','Valencia','competicion'),
  (90,56,'200 m estilos','mmp',156.90,'2:36.90','2026-05-16','Alicante','competicion'),
  (91,57,'50 m mariposa','mmp',32.40,'32.40','2026-05-16','Alicante','competicion'),
  (92,57,'100 m mariposa','mmp',74.80,'1:14.80','2026-06-13','Valencia','competicion'),
  (93,58,'200 m libres','mmp',138.40,'2:18.40','2026-06-13','Valencia','competicion'),
  (94,58,'400 m libres','mmp',292.30,'4:52.30','2026-04-25','Elda','competicion'),
  (95,59,'100 m libres','mmp',68.90,'1:08.90','2026-06-13','Valencia','competicion'),
  (96,59,'100 m estilos','mmp',79.60,'1:19.60','2026-05-16','Alicante','competicion'),
  (97,60,'100 m espalda','mmp',76.80,'1:16.80','2026-06-13','Valencia','competicion'),
  (98,62,'200 m estilos','mmp',149.40,'2:29.40','2026-03-21','Alicante','competicion'),
  -- Natación · Máster
  (99,63,'100 m libres','mmp',68.40,'1:08.40','2026-05-30','Elda','competicion'),
  (100,63,'50 m libres','mmp',30.90,'30.90','2026-05-30','Elda','competicion'),
  (101,64,'200 m libres','mmp',168.60,'2:48.60','2026-05-30','Elda','competicion'),
  (102,65,'100 m braza','mmp',86.30,'1:26.30','2026-05-30','Elda','competicion'),
  (103,65,'50 m braza','mmp',39.80,'39.80','2026-05-30','Elda','competicion'),
  (104,66,'100 m libres','mmp',74.20,'1:14.20','2026-05-30','Elda','competicion'),
  (105,66,'200 m estilos','mmp',182.50,'3:02.50','2026-04-18','Alicante','competicion'),
  (106,67,'50 m libres','mmp',29.80,'29.80','2026-05-30','Elda','competicion'),
  (107,67,'50 m mariposa','mmp',33.40,'33.40','2026-05-30','Elda','competicion'),
  (108,68,'400 m libres','mmp',334.10,'5:34.10','2026-04-18','Alicante','competicion'),
  (109,68,'200 m libres','mmp',158.90,'2:38.90','2026-04-18','Alicante','competicion'),
  (110,70,'100 m espalda','mmp',84.60,'1:24.60','2026-05-30','Elda','competicion'),
  -- Aguas abiertas
  (111,71,'1.500 m libres','mmp',1160.00,'19:20.00','2026-06-27','Alicante','competicion'),
  (112,71,'800 m libres','mmp',598.00,'9:58.00','2026-05-09','Elda','competicion'),
  (113,72,'800 m libres','mmp',670.00,'11:10.00','2026-05-09','Elda','competicion'),
  (114,73,'1.500 m libres','temporada',1300.00,'21:40.00','2026-07-11','Piscina cubierta municipal','entreno'),
  (115,74,'1.500 m libres','mmp',1250.00,'20:50.00','2026-06-27','Alicante','competicion'),
  (116,74,'400 m libres','mmp',318.00,'5:18.00','2026-06-27','Alicante','competicion'),
  (117,75,'800 m libres','mmp',620.00,'10:20.00','2026-05-09','Elda','competicion'),
  -- Escuela · Sub-16
  (118,77,'60 m lisos','mmp',8.72,'8.72','2026-05-09','Petrer','competicion'),
  (119,77,'Salto de longitud','temporada',4.55,'4.55','2026-05-09','Petrer','competicion'),
  (120,78,'1.000 m','mmp',202.40,'3:22.40','2026-06-06','Alicante','competicion'),
  (121,79,'Lanzamiento de peso','mmp',9.20,'9.20','2026-05-23','Elda','competicion'),
  (122,80,'60 m vallas','mmp',11.40,'11.40','2026-05-09','Petrer','competicion'),
  (123,82,'Salto de altura','mmp',1.32,'1.32','2026-06-06','Alicante','competicion'),
  (124,84,'Lanzamiento de jabalina','mmp',21.40,'21.40','2026-05-23','Elda','competicion'),
  (125,85,'1.000 m','mmp',198.90,'3:18.90','2026-06-06','Alicante','competicion'),
  -- Escuela · Benjamines
  (126,86,'60 m lisos','temporada',11.80,'11.80','2026-06-16','Pista municipal','entreno'),
  (127,90,'Salto de longitud','temporada',2.85,'2.85','2026-06-16','Pista municipal','entreno'),
  (128,94,'60 m lisos','temporada',12.10,'12.10','2026-06-16','Pista municipal','entreno'),
  -- Kilómetro Cero
  (129,96,'10.000 m','mmp',3500.00,'58:20','2026-06-14','Alicante','competicion'),
  (130,97,'5.000 m','mmp',1900.00,'31:40','2026-05-17','Elda','competicion'),
  (131,98,'10.000 m','mmp',2970.00,'49:30','2026-06-14','Alicante','competicion'),
  (132,99,'5.000 m','mmp',1670.00,'27:50','2026-05-17','Elda','competicion'),
  (133,100,'10.000 m','mmp',3250.00,'54:10','2026-06-14','Alicante','competicion'),
  (134,100,'Media maratón','objetivo',7500.00,'2:05:00','2026-10-11','Objetivo de temporada',null),
  (135,102,'10.000 m','mmp',2660.00,'44:20','2026-06-14','Alicante','competicion'),
  (136,103,'Media maratón','mmp',6750.00,'1:52:30','2026-01-25','Santa Pola','competicion'),
  -- Vertical Apolana
  (137,106,'Maratón','mmp',11560.00,'3:12:40','2025-12-07','Valencia','competicion'),
  (138,106,'Media maratón','mmp',5290.00,'1:28:10','2026-01-25','Santa Pola','competicion'),
  (139,107,'Media maratón','mmp',6260.00,'1:44:20','2026-01-25','Santa Pola','competicion'),
  (140,108,'Maratón','mmp',12910.00,'3:35:10','2025-12-07','Valencia','competicion'),
  (141,109,'Media maratón','mmp',5990.00,'1:39:50','2026-01-25','Santa Pola','competicion'),
  (142,109,'10.000 m','mmp',2720.00,'45:20','2026-04-12','Alicante','competicion'),
  (143,110,'Maratón','mmp',14320.00,'3:58:40','2025-12-07','Valencia','competicion'),
  (144,111,'Maratón','mmp',10700.00,'2:58:20','2025-12-07','Valencia','competicion'),
  (145,111,'10.000 m','mmp',2140.00,'35:40','2026-04-12','Alicante','competicion'),
  -- Natación · Perfeccionamiento (refuerzo)
  (146,112,'100 m libres','mmp',56.80,'56.80','2026-06-13','Valencia','competicion'),
  (147,112,'100 m mariposa','mmp',62.40,'1:02.40','2026-06-13','Valencia','competicion'),
  (148,113,'200 m estilos','mmp',154.20,'2:34.20','2026-06-13','Valencia','competicion'),
  (149,113,'200 m espalda','mmp',151.80,'2:31.80','2026-06-13','Valencia','competicion'),
  (150,114,'400 m libres','mmp',264.60,'4:24.60','2026-06-13','Valencia','competicion'),
  (151,114,'1.500 m libres','mmp',1060.00,'17:40.00','2026-05-09','Alicante','competicion'),
  (152,115,'50 m libres','mmp',28.90,'28.90','2026-06-13','Valencia','competicion'),
  (153,115,'100 m libres','mmp',63.40,'1:03.40','2026-06-13','Valencia','competicion'),
  (154,116,'100 m braza','mmp',69.80,'1:09.80','2026-06-13','Valencia','competicion'),
  (155,116,'200 m braza','mmp',152.40,'2:32.40','2026-06-13','Valencia','competicion'),
  (156,117,'200 m mariposa','mmp',152.90,'2:32.90','2026-06-13','Valencia','competicion'),
  (157,117,'200 m estilos','mmp',156.10,'2:36.10','2026-06-13','Valencia','competicion'),
  (158,118,'100 m espalda','temporada',82.40,'1:22.40','2026-07-16','Piscina cubierta municipal','entreno')
) as t(n,a,prueba,tipo,seg,disp,fecha,sede,ctx)
on conflict (id) do nothing;

-- Marcas de natación de la cuenta de prueba (para ver la ficha de un nadador)
insert into marcas_atleta (id, atleta_id, prueba, tipo, tiempo_segundos, tiempo_display, fecha, sede, contexto)
values
  ('dddddddd-0025-4000-8000-000000000201','2ac18ce3-5740-4a82-bf65-7202ffe54e26','100 m libres','temporada',76.40,'1:16.40','2026-03-21','Elda','competicion'),
  ('dddddddd-0025-4000-8000-000000000202','2ac18ce3-5740-4a82-bf65-7202ffe54e26','100 m libres','mmp',72.80,'1:12.80','2026-06-13','Valencia','competicion'),
  ('dddddddd-0025-4000-8000-000000000203','2ac18ce3-5740-4a82-bf65-7202ffe54e26','200 m libres','mmp',162.30,'2:42.30','2026-06-13','Valencia','competicion'),
  ('dddddddd-0025-4000-8000-000000000204','2ac18ce3-5740-4a82-bf65-7202ffe54e26','100 m estilos','mmp',85.60,'1:25.60','2026-05-16','Alicante','competicion'),
  ('dddddddd-0025-4000-8000-000000000205','2ac18ce3-5740-4a82-bf65-7202ffe54e26','50 m libres','temporada',32.40,'32.40','2026-07-30','Piscina cubierta municipal','entreno'),
  ('dddddddd-0025-4000-8000-000000000206','2ac18ce3-5740-4a82-bf65-7202ffe54e26','100 m libres','objetivo',70.00,'1:10.00','2026-11-14','Objetivo de temporada',null)
on conflict (id) do nothing;

-- =====================================================================
-- 7. RECIBOS DE LOS ATLETAS NUEVOS
-- =====================================================================
-- Tres mensualidades (mayo, junio y julio) por atleta en activo: la
-- mayoría cobradas, algunas pendientes y unas cuantas impagadas.
with base as (
  select a.id as atleta_id,
         coalesce(g.seccion,'club') as seccion,
         row_number() over (order by a.id) as rn
    from atletas a
    left join grupos g on g.id = a.grupo_id
   where a.id::text like 'dddddddd-0023-%'
     and a.estado in ('activo','lesionado','prueba')
), periodos as (
  select * from (values
    (1,'2026-05', date '2026-05-05'),
    (2,'2026-06', date '2026-06-05'),
    (3,'2026-07', date '2026-07-05')
  ) as v(k, periodo, venc)
), calc as (
  select b.atleta_id, b.seccion, b.rn, p.k, p.periodo, p.venc,
         case b.seccion
           when 'escuela' then 28.00
           when 'escuela-natacion' then 30.00
           when 'natacion' then 34.00
           when 'competicion' then 38.00
           else 25.00
         end as importe,
         case
           when p.k = 3 and b.rn % 4 = 0 then 'pendiente'
           when p.k < 3 and b.rn % 13 = 0 then 'impagado'
           else 'pagado'
         end as estado
    from base b cross join periodos p
)
insert into pagos (id, atleta_id, concepto, importe, estado, fecha_vencimiento, fecha_pago,
                   metodo, periodo, cuenta, notas)
select ('dddddddd-0026-4000-8000-' || lpad((c.rn * 10 + c.k)::text, 12, '0'))::uuid,
       c.atleta_id,
       'Cuota mensual ' || c.periodo,
       c.importe,
       c.estado,
       c.venc,
       case when c.estado = 'pagado' then c.venc else null end,
       case when c.estado = 'pagado' then 'domiciliado' else null end,
       c.periodo,
       case when c.seccion in ('escuela','escuela-natacion') then 'escuela' else 'club' end,
       case when c.estado = 'impagado' then 'Recibo devuelto por el banco. Pendiente de hablar con la familia.' else null end
from calc c
on conflict (id) do nothing;

-- Licencia federativa de quien la tiene
insert into pagos (id, atleta_id, concepto, importe, estado, fecha_vencimiento, fecha_pago,
                   metodo, periodo, cuenta, notas)
select ('dddddddd-0026-4000-8000-' || lpad((500000 + row_number() over (order by a.id))::text, 12, '0'))::uuid,
       a.id, 'Licencia federativa temporada 2026', 45.00, 'pagado',
       date '2026-01-31', date '2026-01-28', 'transferencia', '2026-01', 'club', null
from atletas a
where a.id::text like 'dddddddd-0023-%' and a.licencia is not null
on conflict (id) do nothing;

-- =====================================================================
-- 8. MÁS COMPETICIONES E INSCRIPCIONES
-- =====================================================================
insert into competiciones (id, nombre, sede, fecha_inicio, fecha_fin, nivel, ambito,
                           coste, fecha_limite_interna, inscripcion_abierta, notas, creado_por)
values
  ('dddddddd-0027-4000-8000-000000000001','Travesía a nado de Tabarca','Santa Pola','2026-08-16','2026-08-16','C','natacion', 25.00,'2026-08-08 22:00+02', true,'Travesía de 3 km. Se sale en autobús desde el club a las 7:00.','dddddddd-0001-4000-8000-000000000007'),
  ('dddddddd-0027-4000-8000-000000000002','Control de pista al aire libre','Alicante','2026-08-29','2026-08-29','C','atletismo', 0.00,'2026-08-24 22:00+02', true,'Control abierto para coger marca antes del autonómico.','dddddddd-0001-4000-8000-000000000001'),
  ('dddddddd-0027-4000-8000-000000000003','Campeonato Autonómico Máster de natación','Alicante','2026-09-26','2026-09-27','B','natacion', 12.00,'2026-09-14 22:00+02', true,'Dos jornadas. Cada nadador puede apuntarse a tres pruebas individuales.','dddddddd-0001-4000-8000-000000000007'),
  ('dddddddd-0027-4000-8000-000000000004','Campeonato Autonómico de Marcha en Ruta','Elche','2026-10-04','2026-10-04','B','atletismo', 8.00,'2026-09-25 22:00+02', true,'Circuito de 1 km en el paseo. Jueces autonómicos.','dddddddd-0001-4000-8000-000000000003'),
  ('dddddddd-0027-4000-8000-000000000005','Cross Escolar de Petrer','Petrer','2026-11-08','2026-11-08','C','atletismo', 0.00,'2026-11-02 22:00+02', false,'Primera carrera del curso para la escuela. Se abre la inscripción en octubre.','dddddddd-0001-4000-8000-000000000006')
on conflict (id) do update set
  nombre = excluded.nombre, sede = excluded.sede, fecha_inicio = excluded.fecha_inicio,
  fecha_fin = excluded.fecha_fin, nivel = excluded.nivel, ambito = excluded.ambito,
  coste = excluded.coste, fecha_limite_interna = excluded.fecha_limite_interna,
  inscripcion_abierta = excluded.inscripcion_abierta, notas = excluded.notas;

insert into competicion_atleta (id, competicion_id, atleta_id, prueba, estado, marca_acreditada, observaciones)
select ('dddddddd-0028-4000-8000-' || lpad(t.n::text, 12, '0'))::uuid,
       ('dddddddd-0027-4000-8000-' || lpad(t.c::text, 12, '0'))::uuid,
       ('dddddddd-0023-4000-8000-' || lpad(t.a::text, 12, '0'))::uuid,
       t.prueba, t.estado, t.marca, t.obs
from (values
  -- Travesía a nado de Tabarca
  (1,1,71,'Travesía 3 km','confirmada','19:20.00'::text,'Va a por el podio de su categoría.'::text),
  (2,1,75,'Travesía 3 km','confirmada','10:20.00',null),
  (3,1,74,'Travesía 3 km','confirmada','20:50.00',null),
  (4,1,72,'Travesía 3 km','apuntado',null,null),
  (5,1,73,'Travesía 3 km','apuntado',null,'Duda si hará la corta de 1,5 km.'),
  (6,1,76,'Travesía 3 km','apuntado',null,'Primera travesía. Va acompañada.'),
  (7,1,114,'Travesía 3 km','apuntado','17:40.00','Se lo toma como entrenamiento de fondo.'),
  -- Control de pista al aire libre
  (8,2,1,'110 m vallas','confirmada','14.87',null),
  (9,2,2,'100 m vallas','confirmada','14.62',null),
  (10,2,3,'110 m vallas','apuntado','15.88',null),
  (11,2,4,'100 m vallas','apuntado','15.44',null),
  (12,2,13,'800 m','confirmada','1:58.70','Busca mínima para el autonómico.'),
  (13,2,12,'1.500 m','confirmada','4:46.10',null),
  (14,2,20,'Salto de longitud','confirmada','7.12',null),
  (15,2,24,'Triple salto','apuntado','14.86',null),
  (16,2,21,'Salto de altura','apuntado','1.66',null),
  (17,2,26,'Lanzamiento de peso','confirmada','14.86',null),
  (18,2,29,'Lanzamiento de martillo','apuntado','48.72',null),
  (19,2,35,'60 m lisos','apuntado','8.12',null),
  (20,2,39,'300 m lisos','apuntado','41.20',null),
  (21,2,7,'110 m vallas','cancelada','15.02','Se cae del control, tiene boda familiar.'),
  -- Campeonato Autonómico Máster de natación
  (22,3,63,'100 m libres','confirmada','1:08.40',null),
  (23,3,63,'50 m libres','confirmada','30.90',null),
  (24,3,64,'200 m libres','confirmada','2:48.60',null),
  (25,3,65,'100 m braza','confirmada','1:26.30',null),
  (26,3,65,'50 m braza','apuntado','39.80',null),
  (27,3,66,'100 m libres','confirmada','1:14.20',null),
  (28,3,66,'200 m estilos','apuntado','3:02.50',null),
  (29,3,67,'50 m libres','confirmada','29.80','El favorito de su grupo de edad.'),
  (30,3,67,'50 m mariposa','confirmada','33.40',null),
  (31,3,68,'400 m libres','confirmada','5:34.10',null),
  (32,3,70,'100 m espalda','apuntado','1:24.60',null),
  (33,3,69,'100 m braza','cancelada',null,'De baja por la rodilla.'),
  -- Campeonato Autonómico de Marcha en Ruta
  (34,4,31,'10.000 m marcha','confirmada','44:20.00',null),
  (35,4,32,'5.000 m marcha','confirmada','25:10.00',null),
  (36,4,33,'3.000 m marcha','apuntado','15:20.00',null),
  (37,4,34,'3.000 m marcha','apuntado','16:05.00','Primera vez fuera de la provincia.'),
  -- Cross Escolar de Petrer
  (38,5,77,'Cross Sub-16','apuntado',null,null),
  (39,5,78,'Cross Sub-16','apuntado',null,null),
  (40,5,81,'Cross Sub-16','apuntado',null,null),
  (41,5,85,'Cross Sub-16','apuntado',null,null),
  (42,5,80,'Cross Sub-16','apuntado',null,null)
) as t(n,c,a,prueba,estado,marca,obs)
on conflict (id) do nothing;

-- =====================================================================
-- 9. EVENTOS Y AVISOS
-- =====================================================================
insert into eventos (id, titulo, descripcion, tipo, fecha_inicio, fecha_fin, lugar, seccion, inscripcion_abierta)
values
  ('dddddddd-002b-4000-8000-000000000001','Travesía a nado de Tabarca','Travesía de 3 km entre la isla y la costa. Salida en autobús desde el club a las 7:00 y comida de todos juntos al acabar.','competicion','2026-08-16 09:00+02','2026-08-16 15:00+02','Santa Pola', array['natacion','triatlon'], true),
  ('dddddddd-002b-4000-8000-000000000002','Control de marcas de natación','Control interno en piscina de 25 m para ver cómo llega el equipo a septiembre. Cronometran los entrenadores.','control','2026-08-28 18:00+02','2026-08-28 20:30+02','Piscina cubierta municipal', array['natacion','escuela-natacion'], true),
  ('dddddddd-002b-4000-8000-000000000003','Ruta nocturna con frontales','Salida de montaña de noche por la Vía Verde. Frontal obligatorio y se acaba con cena de bocadillo.','entrenamiento_especial','2026-08-21 21:00+02','2026-08-21 23:59+02','Vía Verde del Maigmó', array['montana','running'], true),
  ('dddddddd-002b-4000-8000-000000000004','Charla de alimentación para deportistas','Una nutricionista del centro de salud explica cómo comer alrededor del entrenamiento y de la competición. Abierta a familias.','otro','2026-09-19 18:00+02','2026-09-19 19:30+02','Sala de reuniones del club', array['competicion','running','natacion','escuela'], false),
  ('dddddddd-002b-4000-8000-000000000005','Puertas abiertas de la escuela','Día de pruebas gratis para niños y niñas que quieran conocer la escuela de atletismo y la de natación.','actividad_padres','2026-09-12 10:00+02','2026-09-12 13:00+02','Pista municipal', array['escuela','escuela-natacion'], true)
on conflict (id) do update set
  titulo = excluded.titulo, descripcion = excluded.descripcion, tipo = excluded.tipo,
  fecha_inicio = excluded.fecha_inicio, fecha_fin = excluded.fecha_fin, lugar = excluded.lugar,
  seccion = excluded.seccion, inscripcion_abierta = excluded.inscripcion_abierta;

insert into avisos (id, texto, tipo, enlace, texto_enlace, fecha_fin, activo)
values
  ('dddddddd-002a-4000-8000-000000000001','La sección de natación ya funciona por niveles: iniciación, tecnificación, perfeccionamiento, máster y aguas abiertas. Pregunta a Lucía en qué grupo encajas.','info','/secciones/natacion.html','Ver los grupos de natación','2026-09-30', true),
  ('dddddddd-002a-4000-8000-000000000002','En agosto El Cubo abre también por las mañanas de lunes a viernes a las 9:30. Las plazas vuelan.','info','/portal/cubo/','Ver las clases de El Cubo','2026-08-31', true),
  ('dddddddd-002a-4000-8000-000000000003','Abierta la inscripción de la travesía a nado de Tabarca. Plazo hasta el 8 de agosto.','aviso',null,null,'2026-08-08', true)
on conflict (id) do update set
  texto = excluded.texto, tipo = excluded.tipo, enlace = excluded.enlace,
  texto_enlace = excluded.texto_enlace, fecha_fin = excluded.fecha_fin, activo = true;

-- =====================================================================
-- 10. EL CUBO A TOPE: clases todos los días, bonos y reservas
-- =====================================================================
-- Clases de lunes a viernes: una de mañana todos los días y otra de
-- tarde los lunes, miércoles y viernes, desde tres semanas atrás hasta
-- tres semanas por delante. Si en ese hueco ya había una clase (las que
-- creó 900), no se crea otra encima.
insert into cubo_clases (id, fecha, hora_inicio, hora_fin, titulo, monitor_id, monitor_nombre,
                         plazas, notas, activa, creado_por)
select ('dddddddd-002e-4000-8000-' || lpad(((g.dia - date '2026-07-13') * 10 + s.slot)::text, 12, '0'))::uuid,
       g.dia, s.hora, s.hora_fin, s.titulo, s.monitor, s.monitor_nombre, 12, s.notas, true,
       'dddddddd-0001-4000-8000-000000000010'
from (select d::date as dia
        from generate_series(date '2026-07-13', date '2026-08-21', interval '1 day') as d) as g
cross join lateral (
  select * from (values
    (1, time '09:30', time '10:30',
       case extract(isodow from g.dia)
         when 1 then 'Funcional · fuerza general'
         when 2 then 'Core y movilidad'
         when 3 then 'Circuito metabólico'
         when 4 then 'Funcional · fuerza general'
         else 'Movilidad y prevención'
       end,
       'dddddddd-0001-4000-8000-000000000010'::uuid,'Diego Marín',
       case when extract(isodow from g.dia) = 5 then 'Sesión suave para acabar la semana.' else null end),
    (2, time '18:15', time '19:15',
       case extract(isodow from g.dia)
         when 1 then 'Fuerza para corredores'
         when 3 then 'Funcional · fuerza general'
         else 'Circuito metabólico'
       end,
       case when extract(isodow from g.dia) = 1
            then 'dddddddd-0001-4000-8000-000000000004'::uuid
            else 'dddddddd-0001-4000-8000-000000000010'::uuid end,
       case when extract(isodow from g.dia) = 1 then 'Álvaro Peñalver' else 'Diego Marín' end,
       case when extract(isodow from g.dia) = 1 then 'Pensada para La Tribu, Madre Tierra y Kilómetro Cero.' else null end)
  ) as v(slot, hora, hora_fin, titulo, monitor, monitor_nombre, notas)
  where v.slot = 1 or extract(isodow from g.dia) in (1,3,5)
) as s
where extract(isodow from g.dia) between 1 and 5
  and not exists (
    select 1 from cubo_clases c where c.fecha = g.dia and c.hora_inicio = s.hora
  )
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Bonos: 60 atletas con bono de 10 o de 20 usos, comprados en fechas
-- distintas. Al darlos de alta, el propio sistema apunta el movimiento.
-- ---------------------------------------------------------------------
insert into cubo_bonos (id, atleta_id, usos_totales, precio, fecha_compra, caducidad, activo, notas, creado_por)
select ('dddddddd-0030-4000-8000-' || lpad(t.rn::text, 12, '0'))::uuid,
       t.id,
       case when t.rn % 3 = 0 then 20 else 10 end,
       case when t.rn % 3 = 0 then 95.00 else 55.00 end,
       date '2026-05-04' + (t.rn * 2)::int,
       date '2026-05-04' + (t.rn * 2)::int + 180,
       true,
       case when t.rn % 3 = 0 then 'Bono de 20 usos' else 'Bono de 10 usos' end,
       'dddddddd-0001-4000-8000-000000000010'
from (
  select a.id, row_number() over (order by a.id) as rn
    from atletas a
   where a.estado in ('activo','lesionado','prueba')
     and a.grupo_id in (
       'dddddddd-0002-4000-8000-000000000001','dddddddd-0002-4000-8000-000000000002',
       'dddddddd-0002-4000-8000-000000000003','dddddddd-0002-4000-8000-000000000004',
       'dddddddd-0002-4000-8000-000000000005','dddddddd-0002-4000-8000-000000000010',
       'dddddddd-0002-4000-8000-000000000011',
       'dddddddd-0021-4000-8000-000000000001','dddddddd-0021-4000-8000-000000000002',
       'dddddddd-0021-4000-8000-000000000003','dddddddd-0021-4000-8000-000000000004',
       'dddddddd-0021-4000-8000-000000000005','dddddddd-0021-4000-8000-000000000009',
       'dddddddd-0021-4000-8000-000000000010','dddddddd-0021-4000-8000-000000000013',
       'dddddddd-0021-4000-8000-000000000014')
) as t
where t.rn <= 60
on conflict (id) do nothing;

-- Alguna renovación: los cinco primeros ya van por el segundo bono.
insert into cubo_bonos (id, atleta_id, usos_totales, precio, fecha_compra, caducidad, activo, notas, creado_por)
select ('dddddddd-0030-4000-8000-' || lpad((100 + t.rn)::text, 12, '0'))::uuid,
       t.atleta_id, 10, 55.00, date '2026-07-20', date '2027-01-16', true,
       'Renovación del bono de 10 usos', 'dddddddd-0001-4000-8000-000000000010'
from (
  select b.atleta_id, row_number() over (order by b.id) as rn
    from cubo_bonos b
   where b.id::text like 'dddddddd-0030-4000-8000-0000000000%'
) as t
where t.rn <= 5
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Reservas
-- ---------------------------------------------------------------------
-- OJO: el control de plazas está en un disparador de la base de datos
-- (cubo_reservas_control). Para las clases FUTURAS se inserta siempre
-- «reservada» y es el disparador el que decide si hay sitio o si la
-- persona se queda en lista de espera; también es él quien descuenta el
-- uso del bono. Por eso las clases con más de 12 apuntados salen llenas
-- y con lista de espera sin tocar nada a mano.
-- Para las clases PASADAS se guarda el estado final (asistió, no vino o
-- canceló) y el consumo del bono se apunta aquí, igual que hizo 900.
do $$
declare
  v_atletas   uuid[];
  v_total     int;
  v_clase     record;
  v_i         int := 0;
  v_n         int;
  v_j         int;
  v_atleta    uuid;
  v_res       uuid;
  v_estado    text;
  v_bono      uuid;
begin
  select array_agg(b.atleta_id order by b.id) into v_atletas
    from cubo_bonos b
   where b.id::text like 'dddddddd-0030-4000-8000-0000000000%';

  v_total := coalesce(array_length(v_atletas, 1), 0);
  if v_total = 0 then return; end if;

  for v_clase in
    select * from cubo_clases
     where id::text like 'dddddddd-002e-%'
     order by fecha, hora_inicio
  loop
    v_i := v_i + 1;

    if v_clase.fecha < date '2026-08-01' then
      -- clases ya pasadas: entre 5 y 12 personas
      v_n := (array[9,7,11,6,12,10,8,5])[1 + (v_i % 8)];
    else
      -- clases por venir: unas llenas con lista de espera y otras a medias
      v_n := (array[15,12,7,4,14,9,16,6])[1 + (v_i % 8)];
    end if;

    for v_j in 0 .. (v_n - 1) loop
      v_atleta := v_atletas[1 + ((v_i * 7 + v_j) % v_total)];
      v_res := ('dddddddd-002f-4000-8000-' || lpad((v_i * 100 + v_j)::text, 12, '0'))::uuid;

      if exists (select 1 from cubo_reservas r
                  where r.clase_id = v_clase.id and r.atleta_id = v_atleta) then
        continue;
      end if;

      if v_clase.fecha < date '2026-08-01' then
        v_estado := case
                      when v_j = 0 and v_i % 5 = 0 then 'no_asistida'
                      when v_j = 1 and v_i % 7 = 0 then 'cancelada'
                      else 'asistida'
                    end;

        insert into cubo_reservas (id, clase_id, atleta_id, estado)
        values (v_res, v_clase.id, v_atleta, v_estado);

        -- El uso gastado se apunta a mano, como en 900.
        v_bono := public.cubo_bono_a_usar(v_atleta);
        if v_bono is not null then
          insert into cubo_movimientos (id, bono_id, atleta_id, tipo, usos, concepto,
                                        clase_id, reserva_id, fecha, creado_por)
          values (('dddddddd-0031-4000-8000-' || lpad((v_i * 100 + v_j)::text, 12, '0'))::uuid,
                  v_bono, v_atleta, 'consumo', -1,
                  case when v_estado = 'no_asistida'
                       then v_clase.titulo || ' (no vino)'
                       else v_clase.titulo end,
                  v_clase.id, v_res,
                  (v_clase.fecha + v_clase.hora_inicio)::timestamptz,
                  'dddddddd-0001-4000-8000-000000000010');

          if v_estado = 'cancelada' then
            insert into cubo_movimientos (id, bono_id, atleta_id, tipo, usos, concepto,
                                          clase_id, reserva_id, fecha, creado_por)
            values (('dddddddd-0031-4000-8000-' || lpad((500000 + v_i * 100 + v_j)::text, 12, '0'))::uuid,
                    v_bono, v_atleta, 'devolucion', 1, 'Cancelada a tiempo',
                    v_clase.id, v_res,
                    (v_clase.fecha + v_clase.hora_inicio - interval '1 day')::timestamptz,
                    'dddddddd-0001-4000-8000-000000000010');
          end if;
        end if;

      else
        -- clases por venir: si no le quedan usos, no se le puede apuntar
        if public.cubo_usos_disponibles(v_atleta) <= 0 then
          continue;
        end if;
        insert into cubo_reservas (id, clase_id, atleta_id, estado)
        values (v_res, v_clase.id, v_atleta, 'reservada');
      end if;
    end loop;
  end loop;
end $$;

commit;

-- =====================================================================
-- Comprobación de lo que ha entrado
-- =====================================================================
select 'grupos' as tabla, count(*) from grupos where id::text like 'dddddddd%'
union all select 'atletas', count(*) from atletas where id::text like 'dddddddd%'
union all select 'sesiones', count(*) from sesiones where id::text like 'dddddddd%'
union all select 'sesiones de natación por calles', count(*) from sesiones where calles is not null
union all select 'marcas_atleta', count(*) from marcas_atleta where id::text like 'dddddddd%'
union all select 'pagos', count(*) from pagos where id::text like 'dddddddd%'
union all select 'competiciones', count(*) from competiciones where id::text like 'dddddddd%'
union all select 'competicion_atleta', count(*) from competicion_atleta where id::text like 'dddddddd%'
union all select 'eventos', count(*) from eventos where id::text like 'dddddddd%'
union all select 'avisos', count(*) from avisos where id::text like 'dddddddd%'
union all select 'cubo_clases', count(*) from cubo_clases where id::text like 'dddddddd%'
union all select 'cubo_bonos', count(*) from cubo_bonos where id::text like 'dddddddd%'
union all select 'cubo_reservas', count(*) from cubo_reservas
union all select 'cubo_movimientos', count(*) from cubo_movimientos
order by 1;
