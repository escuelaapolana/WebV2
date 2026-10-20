-- ============================================================================
-- 401 · Escuela municipal: fichas de los niños del listado de martes/jueves que
-- estaban en «FORMULARIO ALTA ESCUELAS DEPORTIVAS MUNICIPALES … BUENA ISA» y no
-- tenían ficha. Verde = confirmado (activo); sin color = de prueba. Cada uno a
-- su grupo del listado. Además, fuera de su grupo de martes/jueves quien NO
-- sale en ningún Excel de 2026/27 (ni escuela ni municipal) ni en el listado:
-- Hugo González Fernández (Verde 2), Adriana Alba Quílez (Rojo 3), Bruno
-- Estévez Carbonell (Rojo 1a) y Lola de la Casa Gómez (Verde 3). Sus fichas se
-- quedan (no se dan de baja). Idempotente.
-- ============================================================================
begin;
create temp table _m401 (fila int primary key, nombre text, apellidos text, fecha_nacimiento date, sexo text, dni text, estado text,
  nombre_tutor text, email_tutor text, telefono_tutor text, direccion text, observaciones text, grupo uuid) on commit drop;
insert into _m401 values
  (9, 'Mario', 'Aviles Segura', '2019-08-05', null, null, 'activo', 'Neus Segura Lloret', 'neus.morgan@gmail.com', '635188036', 'AVDA. DOCTOR RICO, 6, 03005, ALICANTE', 'Alta municipal desde BUENA ISA (fila 9, verde) · cuadre 20-oct-2026 · OJO: el formulario dice 2019 y «femenino»; el listado del entrenador dice 2015 (revisar)', 'e37b928a-6fe3-455c-a033-dc081c3c37fa'),
  (47, 'Esther', 'Perez Merino', '2015-01-18', 'mujer', '56628976D', 'prueba', 'Teresa Merino Suarez', 'merino.ter@gmail.com', '685509039', 'CARMELO SIMÓN PLA 4, 03540, ALICANTE', 'Alta municipal desde BUENA ISA (fila 47, sin color: de prueba) · cuadre 20-oct-2026', 'd93016a6-ba64-45b4-ac83-2756d5337729'),
  (48, 'Valentina', 'Colmenares Quintero', '2016-02-27', 'mujer', null, 'activo', 'Maryelis Quintero', 'Rivasjunior023@gmail.com', '642164422', 'Calle francisco carratala cernuda 6., 03010, Alicante', 'Alta municipal desde BUENA ISA (fila 48, verde) · cuadre 20-oct-2026 · Formulario: Tiene licncia aparte de escuelas municipales', 'e37b928a-6fe3-455c-a033-dc081c3c37fa'),
  (53, 'Oskar', 'Wieczorek Espinosa', '2019-10-31', 'hombre', '02380161Y', 'activo', 'Ana Espinosa Seguí', 'anaretailing@yahoo.es', '620407345', 'Calle Brasil 13, 2ºA, 03008, Alicante', 'Alta municipal desde BUENA ISA (fila 53, verde) · cuadre 20-oct-2026 · Formulario: Somos familia numerosa general', 'ec084bfe-6906-4f06-8523-b708a7fc2efe'),
  (54, 'Álvaro', 'Oñate Sánchez', '2018-12-29', 'hombre', '54847699J', 'prueba', 'Juan Carlos', 'el1jcoc@hotmail.com', '630936303', 'Avenida Dr. Jiménez Díaz 11, esc 4, 1d, 03005, Alicante', 'Alta municipal desde BUENA ISA (fila 54, sin color: de prueba) · cuadre 20-oct-2026', 'ec084bfe-6906-4f06-8523-b708a7fc2efe'),
  (57, 'Luis', 'Romero Gumpert', '2020-11-03', 'hombre', '04723568N', 'activo', 'Elena Gumpert Mozas', 'elena_mozas@hotmail.com', '686611740', 'C/ENRIQUETA ELIZAICIN 2, 03007, ALICANTE', 'Alta municipal desde BUENA ISA (fila 57, verde) · cuadre 20-oct-2026', '74567283-d08e-4c41-8427-f64633ea9745'),
  (58, 'Carlos', 'Montes Mañogil', '2017-09-13', 'hombre', '54456505A', 'prueba', 'Vanessa Mañogil Ferrando', 'vanemanogil@gmail.com', '647979595', 'Calle José Llopis Díez, 9, 03015, Alicante', 'Alta municipal desde BUENA ISA (fila 58, sin color: de prueba) · cuadre 20-oct-2026', 'e37b928a-6fe3-455c-a033-dc081c3c37fa'),
  (62, 'Marcos', 'Estévez Carbonell', '2020-02-16', 'hombre', '02380997Z', 'activo', 'Rosa Carbonell Muñoz', 'rcarbm@gmail.com', '625229583', 'Maestro José Garberí 11 T5 E1 1A, 03540, Alicante', 'Alta municipal desde BUENA ISA (fila 62, verde) · cuadre 20-oct-2026', '74567283-d08e-4c41-8427-f64633ea9745'),
  (64, 'Lucía Arianna', 'Izquierdo Chacon', '2016-09-16', 'mujer', '60412844D', 'activo', 'Frank Izquierdo Aparicio', 'carlachaconsr@gmail.com', '658644014', 'CALLE PADRE RECAREDO DE LOS RIOS 19, PLANTA 2, PERTA B, 03005, ALICANTE - SAN BLAS', 'Alta municipal desde BUENA ISA (fila 64, verde) · cuadre 20-oct-2026', 'e37b928a-6fe3-455c-a033-dc081c3c37fa');

insert into public.atletas (nombre, apellidos, fecha_nacimiento, sexo, dni, estado, tipo_membresia, secciones,
                            nombre_tutor, email_tutor, telefono_tutor, direccion, observaciones, origen)
select m.nombre, m.apellidos, m.fecha_nacimiento, m.sexo, m.dni, m.estado, 'municipal', array['escuela'],
       m.nombre_tutor, m.email_tutor, m.telefono_tutor, m.direccion, m.observaciones, 'cuadre-municipal-2026-10-20'
  from _m401 m
 where not exists (select 1 from public.atletas a where a.fecha_nacimiento = m.fecha_nacimiento
                     and lower(btrim(a.nombre)) = lower(m.nombre) and lower(btrim(coalesce(a.apellidos,''))) = lower(m.apellidos));
insert into public.atleta_grupos (atleta_id, grupo_id, principal)
select a.id, m.grupo, true from _m401 m
  join public.atletas a on a.fecha_nacimiento = m.fecha_nacimiento and lower(btrim(a.nombre)) = lower(m.nombre)
                       and lower(btrim(coalesce(a.apellidos,''))) = lower(m.apellidos)
 where not exists (select 1 from public.atleta_grupos x where x.atleta_id = a.id and x.grupo_id = m.grupo);

delete from public.atleta_grupos ag using public.atletas a
 where ag.atleta_id = a.id
   and ag.grupo_id in (select id from public.grupos where seccion = 'escuela' and horario ilike 'Martes y jueves 17:30%')
   and ((a.nombre = 'Hugo' and a.apellidos = 'González Fernandez' and a.tipo_membresia = 'municipal')
     or (a.nombre = 'Adriana' and a.apellidos = 'Alba Quílez' and a.fecha_nacimiento = '2021-06-28')
     or (a.nombre = 'Bruno' and a.apellidos = 'Estevez Carbonell' and a.fecha_nacimiento = '2023-10-15')
     or (upper(a.nombre) = 'LOLA' and a.apellidos ilike 'De la casa Gomez' and a.fecha_nacimiento = '2015-05-30'));
commit;
