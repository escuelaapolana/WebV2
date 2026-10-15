-- ============================================================================
-- 393 · Escuela de atletismo 2026/27 · cuadre con «BUENO ISA» + listados L-X / M-J
-- ----------------------------------------------------------------------------
-- Fuente (15-oct-2026, Excel de Andrés):
--   · «Inscripción Escuela Atletismo Apolana 2026_2027 (respuestas).xlsx»,
--     pestaña BUENO ISA, por color de fila: VERDE (D9EAD3) = alta definitiva,
--     ROJO (F4CCCC) = baja, SIN COLOR = sigue de prueba. Una fila ROSA
--     (D5A6BD, «RENOVACIÓN», Violeta Castaño) NO se clasifica: no se toca.
--   · «Listado turno L_X.xlsx» y «Listado turno M_J.xlsx»: grupos actualizados
--     del 1er turno (17:30-18:30). Se casa por NOMBRE DE PESTAÑA con el grupo de
--     la base (la pestaña M-J «Azul 4» = grupo «Azul 4», aunque dentro ponga «AZUL 3b»).
--
-- Representación de «de prueba» en la escuela: atletas.estado = 'prueba'
-- (+ fecha_prueba_fin, que pone sola el disparador atletas_fin_de_prueba:
-- hoy + 14 días = 4 entrenos; al pasar a 'activo' se vacía sola).
--
-- NO se tocan recibos (pagos), ni se borra ninguna ficha ni sesión. Las bajas
-- se marcan con estado. Lo único que se borra son filas de atleta_grupos
-- (sacar de un grupo de la escuela), que es lo que se pide.
--
-- Idempotente: cada bloque comprueba el estado antes de escribir; volver a
-- pasarlo no cambia nada. Al final, comprobación que hace RAISE si algo no cuadra.
-- Bloques:
--   1 · Bajas (rojo)                          4 · Cambios de grupo (listados)
--   2 · Verdes en prueba → activo             5 · Fichas sin grupo → grupo deducido
--   3 · Nuevos (fichas + grupo)               6 · Relleno de dirección (solo vacías)
--   7 · Comprobación final
-- ============================================================================
begin;

-- ----------------------------------------------------------------------------
-- 1 · BAJAS (fila ROJA en BUENO ISA). Estado baja + fecha + nota, y fuera de
--     sus grupos de la escuela. Sus recibos NO se tocan (ninguno tiene).
-- ----------------------------------------------------------------------------
create temp table _m393_bajas (atleta_id uuid primary key, nombre text) on commit drop;
insert into _m393_bajas values
  ('ee8eb129-363f-4e61-8d2c-8c240ea2ddc7', 'ADRIANA DE GEA ALMIÑANA'),
  ('dc44b016-ce33-43f1-a347-f4e9923f0f7f', 'Adriel Martinez Ruiz'),
  ('ee2798c5-8c79-41ef-9b3a-2b8382af16b8', 'Anastasia Esteban Sukhanova'),
  ('b37a3f2c-7bbd-4c34-a2b9-fae123f179c6', 'Begoña Gras Ramon-borja'),
  ('e5f92f68-aa1a-4ebf-b808-fe1b6ef3e915', 'Carlota Díez Jerez'),
  ('62535fed-87ea-429b-b831-b54a9c1bf4ba', 'Fernando Gras Ramon-Borja'),
  ('e3e376e3-ec27-477b-a011-092e8b3015cb', 'irene Esplá gonzalez'),
  ('afb4a6cd-7fa7-45f8-9ea5-01e9465f5e9a', 'Lucas Martínez Corella'),
  ('67b1e9fe-10e5-465e-b839-63fb07db6c5e', 'Lucia Puertas Romera'),
  ('8f0eb5b4-10fc-4e50-84cc-ab7cf7dfec2a', 'Martín Rodríguez Narro'),
  ('ecffb3ec-060b-4086-b7bf-5c93bd98c708', 'Mateo Coy Ortuño'),
  ('8f5a4408-3034-4b4f-a467-83c4c8a02a78', 'Matteo Rodríguez Narro');

update public.atletas a
   set estado = 'baja',
       fecha_baja = coalesce(a.fecha_baja, now()),
       observaciones = case when coalesce(a.observaciones,'') like '%Baja según listado de Isa 15-oct-2026%' then a.observaciones
                            else concat_ws(E'\n', nullif(btrim(a.observaciones),''), 'Baja según listado de Isa 15-oct-2026') end
  from _m393_bajas b
 where a.id = b.atleta_id and a.estado is distinct from 'baja';

-- Por si alguno ya estaba de baja sin la nota (no cambia nada si ya la tiene)
update public.atletas a
   set observaciones = concat_ws(E'\n', nullif(btrim(a.observaciones),''), 'Baja según listado de Isa 15-oct-2026')
  from _m393_bajas b
 where a.id = b.atleta_id and coalesce(a.observaciones,'') not like '%Baja según listado de Isa 15-oct-2026%';

delete from public.atleta_grupos ag
 using _m393_bajas b, public.grupos g
 where ag.atleta_id = b.atleta_id and g.id = ag.grupo_id and g.seccion = 'escuela';

-- ----------------------------------------------------------------------------
-- 2 · VERDES que en la base siguen 'prueba' → 'activo' (alta definitiva).
-- ----------------------------------------------------------------------------
create temp table _m393_activar (atleta_id uuid primary key, nombre text) on commit drop;
insert into _m393_activar values
  ('f798aaa7-1e06-4c09-b369-9f7ca9f03acf', 'Abril Sanz Blasco'),
  ('67209d80-e5c2-41cd-816a-4420ced517c6', 'Adeline Demchuk Dragomir'),
  ('d84c5145-81e4-48ce-9483-c2ce176394eb', 'Adrián Beya Pérez'),
  ('23c6a383-0927-4765-9b43-9922370f2ff8', 'Adriana Ripoll Pol'),
  ('8273f1dd-62d8-48d6-8c5e-7f148f19f78f', 'Alba Ramos Pérez'),
  ('02bf9479-4635-4ad9-a174-af4f7f50f500', 'Alexander Demchuk Dragomir'),
  ('bd6f5819-d0a0-45a0-86f8-6ae22895b118', 'Alonso López Valero'),
  ('f9240ec3-87f4-4661-b91f-5bf512f3c2c2', 'Antonio Ángel Guarido Roselló'),
  ('57633776-c891-475d-b519-bfc31606646b', 'Arantxa Gómez Martín'),
  ('654b8a5e-d47d-4e91-a0ac-96365504cdf6', 'Ariana Demchuk Dragomir'),
  ('0cd2c902-f6e9-4ce0-a2d1-8ce1c36c444a', 'Aurora López Martínez'),
  ('617e10ba-bb9d-4dd0-9976-ccfb97afd801', 'AZAHARA VIDAL FAIZ'),
  ('22818289-ef68-4162-aea5-3363a063619d', 'Blanca Olivares Muñoz'),
  ('56b99e62-d651-4cf9-af67-3a77446c41da', 'Bruno Ferrándiz Sánchez'),
  ('874e9493-0d1f-49be-821c-74e59a608b7d', 'Claudia Padilla García'),
  ('c084727f-be87-44a2-973f-647e82fbdc27', 'Cristina Moratalla Papi'),
  ('72f4c1a0-2a6d-4a32-b530-9132ab0b5167', 'Damián Morante Mula'),
  ('1aaf924b-9725-4217-963f-13bffa9b025e', 'Daniel Galindo Mas'),
  ('bfe6fef2-3502-4f89-b926-c208a109ef35', 'Darcy Hume Dougan'),
  ('3148fe5a-6870-4a3a-abf0-0f5d1d08c37f', 'Darío Miñán Barranco'),
  ('79d30d98-1ba4-4c1b-aa33-e531ad047865', 'Emma Noguera Ceballo'),
  ('077b2c1e-4006-4956-82b5-1ebb86392f5a', 'Esteban Montuenga Sola'),
  ('e8da6944-6255-4b14-a896-d3c191bb33c3', 'Eva Romero Gumpert'),
  ('f176f4b8-f860-4d47-964b-909638f38a38', 'Gabriel Ras García'),
  ('6e8409fc-0161-44e9-9959-f8e36533cc6d', 'GIULIANA CASELLES ORTIN'),
  ('82e749de-05df-4e84-9c5d-706ea73bc0bf', 'Hernán Vaillo Ramos'),
  ('700f74f4-7d54-4f2f-84ff-3211b37b8edd', 'Hugo Pastor Cecilia'),
  ('4ba3764e-4932-471a-9416-6536d88fa321', 'Izan Llamas Sánchez'),
  ('a67db4ee-d26d-4527-a3a2-1f098d20f232', 'Joel Morales Lopez'),
  ('f8a08318-3d3d-4227-b34e-5a4e0205225e', 'June Garmendia Gonzalez'),
  ('4cd14b9d-ef77-47ed-9eb3-da5ae6d5889d', 'Keitlyn anahi Solórzano Salinas'),
  ('d264c07e-bdde-460d-9535-fc5cac9c255e', 'KENDRIC THOMSON GÓMEZ'),
  ('a5bea0b4-c1b2-4706-b129-477722c78918', 'Khloe Perez Albertus'),
  ('0e14494d-2fbf-47c3-ab02-0639771bc75c', 'Lola Morante Mula'),
  ('6f9f5913-05e0-46ba-a4b5-594a2a8994d6', 'Lucas Rocamora Tovar'),
  ('87640a4e-8dba-4d85-a78a-db9ac7d39e89', 'Luis Soler Marin'),
  ('97e72e85-3d43-4027-8a54-b8873cd4bd56', 'Malaika Beya Pérez'),
  ('26f8ae8b-14c3-4134-a3d4-211240a47b82', 'Marc Galindo Mas'),
  ('8e2a21c3-29c1-4eb4-9c10-657f67ff756f', 'Marc Varona Alguacil'),
  ('77dd6782-1c7e-4259-8d82-2d198cd6e5a8', 'Marcus Cariño Coloma'),
  ('3be5133f-d918-4da6-b789-c60b95956433', 'María Laura Sánchez Gálvez'),
  ('520d5271-9c8c-4c59-aeb0-480db06b9905', 'Martín Muñoz Asensi'),
  ('7d1887b7-80ce-499b-a8ba-4512accecbc5', 'Mateo Collado Leal'),
  ('83764cba-f525-4b50-82f1-1d6c905beaab', 'Michael Segarra Arizaga'),
  ('94e67623-78a7-46cc-bae6-e5f2784f10a1', 'Miguel González Galiana'),
  ('3e46e906-e875-4aac-9955-adf8bb0cfd8c', 'Miguel Mingot Zaragoza'),
  ('9409f07d-7708-4aba-b74f-83fa67ee4454', 'Míriam Ras García'),
  ('5671bc52-f366-4186-a23e-9b235e06b6c1', 'Mohamed ali Moumen No tiene apellido segundo'),
  ('aeb66a2f-b82f-4c16-9b4f-1a3e7b4c5fed', 'Nolberto Rafael Sabate Franco'),
  ('9236c70a-7c62-41f1-8f34-8948715c76d3', 'PAU HERRERA SOMOLINOS'),
  ('482cab57-6408-4d70-9f8a-fc3f043a2bcd', 'Pilar Menchén Company'),
  ('36a1e85c-86af-4ce0-ac0e-6919e129597e', 'Raúl Fernández Pastor'),
  ('631d6817-5940-4f58-bd7e-1bb51188637e', 'Rodrigo Sanz Blasco'),
  ('a30e7554-e73d-486a-bd3f-e609dccef771', 'Shaddaï-Maël Prat Amugu'),
  ('64f52f77-bd8f-4627-bafc-1fe375cb5567', 'SILVIA CACHO HERNÁNDEZ'),
  ('69b63ee7-244f-4d00-8b10-b8072f410a5c', 'Sofía Rocamora Tovar'),
  ('e2815c15-3e35-41a9-b84c-ce8757814a26', 'Valentina Alberola Puerta'),
  ('6fd06a98-97dc-444f-afac-6af71c7e7c96', 'Valentina Campos Uribe'),
  ('294abc52-fdad-4889-a410-6bb3b6e5c46f', 'Vera Villena Gonzalez'),
  ('2be2e1f8-5bc9-4dd3-bbee-5a47a8219aad', 'Yaiza Martínez García');

update public.atletas a
   set estado = 'activo'
  from _m393_activar v
 where a.id = v.atleta_id and a.estado = 'prueba';

-- ----------------------------------------------------------------------------
-- 3 · NUEVOS: en BUENO ISA (verde o sin color) y sin ficha en la base.
--     origen = 'cuadre-isa-2026-10-15'. Verde → 'activo'; sin color → 'prueba' (fin de prueba
--     = hoy + 14 días, lo pone el disparador). «deducido» = no está en ningún
--     listado: grupo por turno y año (marcado en observaciones).
-- ----------------------------------------------------------------------------
create temp table _m393_nuevos (
  fila int primary key, nombre text, apellidos text, fecha_nacimiento date, sexo text, dni text,
  estado text, nombre_tutor text, email_tutor text, telefono_tutor text, direccion text,
  observaciones text, grupo1 uuid, grupo2 uuid) on commit drop;
insert into _m393_nuevos values
  (48, 'Alén', 'García Martínez', '2015-01-20', 'hombre', null, 'activo', 'María Martínez Ortega', 'merymewi@hotmail.com', '617654873', 'PDA valverde bajo 198, 03139, Elche',
     'Alta desde BUENO ISA (fila 48, verde) · cuadre 15-oct-2026 · Formulario: El amigo con quién quiere ir ha nacido en 2014', 'af8c1675-905f-4548-979b-3409fc2b25a4', null),
  (91, 'Máximo', 'Murillo Tarruella', '2022-07-29', 'hombre', null, 'activo', 'Laura Tarruella López', 'tarloplau@gmail.com', '650148732', 'Rio Tajo 25, 03690, San vicente del Raspeig',
     'Alta desde BUENO ISA (fila 91, verde) · cuadre 15-oct-2026 · Formulario: Su hermano tiene 2 años y medio imagino que hasta los 3 años no puedo apuntarlo.', '00ec2abf-346e-4e3a-9895-73c55b40b07d', null),
  (204, 'Sofia', 'Aghyourli Yazidi', '2023-02-12', 'mujer', '60699543J', 'prueba', 'Sabrine Yazidi', 'maryamaghiorly@gmail.com', '613210442', 'Calle general Shelly 35, 03012, Alicante',
     'Alta desde BUENO ISA (fila 204, sin color = de prueba) · cuadre 15-oct-2026', '00ec2abf-346e-4e3a-9895-73c55b40b07d', null),
  (205, 'Maria', 'Nieto román', '2016-05-24', 'mujer', null, 'prueba', 'Claudio', 'claudionietomaestre@gmail.com', '650063289', 'avda médico ricardo ferré 22    1.2    8a, 03005, Alicante',
     'Alta desde BUENO ISA (fila 205, sin color = de prueba) · cuadre 15-oct-2026', 'af8c1675-905f-4548-979b-3409fc2b25a4', null),
  (206, 'Sandra', 'Cacho Hernández', '2020-09-23', 'mujer', null, 'prueba', 'IGOR CACHO MARÍN', 'igor.cacho@gmail.com', '696590181', 'C/ GADEA, 7, 03009, ALICANTE',
     'Alta desde BUENO ISA (fila 206, sin color = de prueba) · cuadre 15-oct-2026 · Listado: Solo jueves · Formulario: Es para probar este jueves 8 de octubre y, la intención, si va bien mañana, sería inscribirla solo para ir los jueves.', '0833f3d7-b760-416b-9677-0dcf07aba7db', null),
  (207, 'Lucia', 'Iniesta Lopez', '2021-10-18', 'mujer', null, 'prueba', 'Adriana', 'adrianapancorbo@gmail.com', '684013307', 'Ramon Gómez sempere, 03008, Alicante',
     'Alta desde BUENO ISA (fila 207, sin color = de prueba) · cuadre 15-oct-2026', '74567283-d08e-4c41-8427-f64633ea9745', null),
  (208, 'Valeria', 'Giménez Sánchez', '2021-11-01', 'mujer', '60333255T', 'prueba', 'Jerónimo Giménez Serna', 'jeronimogimenez18@gmail.com', '671673485', 'Calle Ondara N 4. 2D, 03005, Alicante',
     'Alta desde BUENO ISA (fila 208, sin color = de prueba) · cuadre 15-oct-2026', '629bd004-c3f1-4139-a051-17dcd15f9de1', null),
  (209, 'José Emilio', 'Pineda Carchipulla', '2021-09-13', 'hombre', '38189689Y', 'prueba', 'PILAR CARCHIPULLA SIGCHI', 'pilarcarchipulla2@gmail.com', '623327290', 'Calle Poeta quintana número 8, 03004, Alicante',
     'Alta desde BUENO ISA (fila 209, sin color = de prueba) · cuadre 15-oct-2026 · En el listado M-J sale en dos grupos (M-J Rojo 3 y M-J Azul 1): se pone en el primero; revisar', '629bd004-c3f1-4139-a051-17dcd15f9de1', null),
  (210, 'Aleksandar', 'Markovic Lopez', '2019-09-20', 'hombre', null, 'prueba', 'BEGOÑA MARKOVIC LOPEZ', 'bmarkoviclopez@gmail.com', '620106365', 'CARRER PONTEVEDRA 3, BLOQUE 2, 1ºI, 03005, ALICANTE',
     'Alta desde BUENO ISA (fila 210, sin color = de prueba) · cuadre 15-oct-2026', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', null),
  (211, 'Triana', 'Montero Vazquez', '2020-02-15', 'mujer', null, 'prueba', 'Vanesa Vázquez macias', 'vanebrit25@gmail.com', '617856363', null,
     'Alta desde BUENO ISA (fila 211, sin color = de prueba) · cuadre 15-oct-2026 · Formulario: N', '0833f3d7-b760-416b-9677-0dcf07aba7db', null),
  (212, 'Agnes', 'Brantuas Batalla', '2021-07-22', 'hombre', null, 'prueba', 'Oscar Brantuas Batalla', 'brantuas@gmail.com', '669821998', 'Plaza Pintor Lorenzo Aguirre 2, 03009, Alicante (Alacant)',
     'Alta desde BUENO ISA (fila 212, sin color = de prueba) · cuadre 15-oct-2026 · Sin grupo del listado: grupo deducido por turno y año (L-X Rojo 2) · Formulario: Prueba', 'e09b4694-8de8-4387-89f4-3313c37e81d4', null),
  (213, 'Krzysztof', 'Mizera Mizera', '2015-07-01', 'mujer', null, 'prueba', 'Justyna Mizera', 'krzysztofmizera@o2.pl', '34644240255', 'Botella Sempere 11, 03130, Gran Alacant',
     'Alta desde BUENO ISA (fila 213, sin color = de prueba) · cuadre 15-oct-2026 · Formulario: Decidiremos después de 4 clases de prueba.', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', null),
  (214, 'Éric', 'González Orea', '2021-10-28', 'hombre', '04722770L', 'prueba', 'Marina Orea Garví', 'mimochiladelcole@gmail.com', '635588709', 'Médico Antonio Arroyo 2, 03005, Alicante',
     'Alta desde BUENO ISA (fila 214, sin color = de prueba) · cuadre 15-oct-2026 · Sin grupo del listado: grupo deducido por turno y año (L-X Rojo 2) · Formulario: Mi gustaría que mi hijo fuera en el mismo grupo que dos amiguitos del cole de su edad, día y hora. L y X a las 17:30. El monitor se llama Alejandro. Muchas gracias', 'e09b4694-8de8-4387-89f4-3313c37e81d4', null),
  (215, 'Adriana', 'Mayor Infante', '2022-10-13', 'mujer', null, 'prueba', 'Isabel Infante Miñano', 'isabel.infante14@gmail.com', '675479212', 'Calle Padre Recaredo de los Ríos 52, 03005, Alicante',
     'Alta desde BUENO ISA (fila 215, sin color = de prueba) · cuadre 15-oct-2026 · Sin grupo del listado: grupo deducido por turno y año (L-X Rojo 1b) · Formulario: La nena se apunta porque van dos amigas suyas los Miércoles a las 17:30 en el grupo rojo 1 con la monitora Patri. Manuela y Lucia Bellido , nos gustaría que fueran juntas, es posible?? Gracias! Sería solo para los Miércoles', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', null),
  (216, 'Carmen', 'Febrero Candela', '2009-03-07', 'mujer', '50593788K', 'prueba', 'Reme Candela Bautista', 'remecande@gmail.com', '673828596', 'Deportista Isabel Fernández 18, 03005, Alicante',
     'Alta desde BUENO ISA (fila 216, sin color = de prueba) · cuadre 15-oct-2026 · Sin grupo del listado: grupo deducido por turno y año (L-X-V Recreativo)', '701f1399-50ae-402f-adea-ed6a65dc0d35', null);

insert into public.atletas (nombre, apellidos, fecha_nacimiento, sexo, dni, estado, tipo_membresia, secciones,
                            nombre_tutor, email_tutor, telefono_tutor, direccion, observaciones, origen)
select n.nombre, n.apellidos, n.fecha_nacimiento, n.sexo, n.dni, n.estado, 'escuela', array['escuela'],
       n.nombre_tutor, n.email_tutor, n.telefono_tutor, n.direccion, n.observaciones, 'cuadre-isa-2026-10-15'
  from _m393_nuevos n
 where not exists (select 1 from public.atletas a
                    where a.fecha_nacimiento = n.fecha_nacimiento
                      and lower(btrim(a.nombre)) = lower(n.nombre)
                      and lower(btrim(coalesce(a.apellidos,''))) = lower(n.apellidos));

insert into public.atleta_grupos (atleta_id, grupo_id, principal)
select a.id, n.grupo1, true
  from _m393_nuevos n
  join public.atletas a on a.origen = 'cuadre-isa-2026-10-15' and a.fecha_nacimiento = n.fecha_nacimiento
                       and lower(btrim(a.nombre)) = lower(n.nombre)
                       and lower(btrim(coalesce(a.apellidos,''))) = lower(n.apellidos)
 where n.grupo1 is not null
   and not exists (select 1 from public.atleta_grupos ag join public.grupos g on g.id = ag.grupo_id
                    where ag.atleta_id = a.id and g.seccion = 'escuela');

-- ----------------------------------------------------------------------------
-- 4 · CAMBIOS DE GRUPO según los listados del 1er turno (17:30). Se ponen los
--     grupos del listado y se quitan los otros grupos de 17:30 de la escuela.
--     Los grupos de 18:30 (Sub 14 / Recreativo) NO se tocan aquí.
-- ----------------------------------------------------------------------------
create temp table _m393_mover (atleta_id uuid, grupo_id uuid, accion text, nombre text, grupo text, primary key (atleta_id, grupo_id)) on commit drop;
insert into _m393_mover values
  ('e0ce5031-c769-4f2b-b0d5-553cef9ad3a8', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'poner', 'Aaron Tucci Cordoba', 'M-J Verde 1'),
  ('e0ce5031-c769-4f2b-b0d5-553cef9ad3a8', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'quitar', 'Aaron Tucci Cordoba', 'M-J Verde 2'),
  ('f798aaa7-1e06-4c09-b369-9f7ca9f03acf', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'Abril Sanz Blasco', 'M-J Verde 2'),
  ('f798aaa7-1e06-4c09-b369-9f7ca9f03acf', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'Abril Sanz Blasco', 'M-J Verde 4'),
  ('740f8909-b1fe-459f-aa6f-5903c5e598be', 'c98add51-8636-4f01-b290-9e849a7fc935', 'poner', 'ADRIAN GARCIA DE DIONISIO GATHY', 'M-J Azul 3'),
  ('740f8909-b1fe-459f-aa6f-5903c5e598be', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'quitar', 'ADRIAN GARCIA DE DIONISIO GATHY', 'M-J Azul 2'),
  ('ae1c1366-fa69-4386-8e75-021810f62651', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'Adriana Diez Ibáñez', 'M-J Verde 4'),
  ('5508a949-a789-4438-83da-fa31b4d96616', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'poner', 'Amaya Ascensión Díaz Piatek', 'L-X Azul 1'),
  ('71f3df6e-f457-4f52-83ea-a56ba14c5647', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'Ángela Jordá Padrino', 'M-J Verde 2'),
  ('71f3df6e-f457-4f52-83ea-a56ba14c5647', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'Ángela Jordá Padrino', 'M-J Verde 4'),
  ('0cd2c902-f6e9-4ce0-a2d1-8ce1c36c444a', '7ac68a0a-5139-43e1-8a58-b78d18382c1a', 'poner', 'Aurora López Martínez', 'M-J Rojo 2'),
  ('0cd2c902-f6e9-4ce0-a2d1-8ce1c36c444a', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'quitar', 'Aurora López Martínez', 'M-J Rojo 1b'),
  ('56b99e62-d651-4cf9-af67-3a77446c41da', '85b804bd-b180-4881-b95b-857821e4f137', 'poner', 'Bruno Ferrándiz Sánchez', 'M-J Rojo 1a'),
  ('56b99e62-d651-4cf9-af67-3a77446c41da', '7ac68a0a-5139-43e1-8a58-b78d18382c1a', 'quitar', 'Bruno Ferrándiz Sánchez', 'M-J Rojo 2'),
  ('4ef05014-2956-4d75-91a2-93345c4bf603', 'c98add51-8636-4f01-b290-9e849a7fc935', 'poner', 'Carlota Alzamora Fasanar', 'M-J Azul 3'),
  ('a34033a8-f7ca-4d78-9161-e235bf472c0c', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'poner', 'Carmen Ruiz Cruz', 'L-X Azul 3'),
  ('a34033a8-f7ca-4d78-9161-e235bf472c0c', '514d3102-4eaa-44d8-b5b5-9b1b07d7c30b', 'quitar', 'Carmen Ruiz Cruz', 'L-X Verde 2'),
  ('f99cf1e9-f440-489e-8ffc-e33855129a66', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'poner', 'CAYETANA ARENAS DEL CAÑO', 'L-X Verde 1'),
  ('f99cf1e9-f440-489e-8ffc-e33855129a66', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'quitar', 'CAYETANA ARENAS DEL CAÑO', 'L-X Azul 3'),
  ('242c8203-1f7c-4b32-9f1d-d956e15bf878', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'CESAR MAYORDOMO BLASCO', 'M-J Verde 2'),
  ('242c8203-1f7c-4b32-9f1d-d956e15bf878', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'CESAR MAYORDOMO BLASCO', 'M-J Verde 4'),
  ('462e6a95-cd57-4c5f-894d-fe2c28c027ba', '85b804bd-b180-4881-b95b-857821e4f137', 'quitar', 'DANIEL ASENSI BOTÍA', 'M-J Rojo 1a'),
  ('7568a472-9eb7-4136-9ebf-f62097d2ca3b', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'poner', 'Diego García Gomez', 'M-J Azul 2'),
  ('7568a472-9eb7-4136-9ebf-f62097d2ca3b', '74567283-d08e-4c41-8427-f64633ea9745', 'quitar', 'Diego García Gomez', 'M-J Azul 1'),
  ('a5876033-a1f5-428b-9032-0dc7ac82b5c2', 'ec084bfe-6906-4f06-8523-b708a7fc2efe', 'poner', 'EIDEN IBAÑEZ SENENT', 'M-J Azul 4'),
  ('a5876033-a1f5-428b-9032-0dc7ac82b5c2', 'c98add51-8636-4f01-b290-9e849a7fc935', 'quitar', 'EIDEN IBAÑEZ SENENT', 'M-J Azul 3'),
  ('96dee032-ec48-4c07-acdf-9bcd27dfe6f1', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'poner', 'ERiC MARTÍN ROMAN', 'L-X Azul 1'),
  ('96dee032-ec48-4c07-acdf-9bcd27dfe6f1', 'c98add51-8636-4f01-b290-9e849a7fc935', 'quitar', 'ERiC MARTÍN ROMAN', 'M-J Azul 3'),
  ('23c026aa-0e25-481f-8aff-9b4185d3795c', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'poner', 'Fernando Gómez Pastor', 'L-X Rojo 1b'),
  ('424f7dff-05d5-4e3a-a909-b9c93693d5cf', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'poner', 'Hugo González Pérez', 'M-J Verde 1'),
  ('0164aa42-1982-4572-a984-cbf857b73b30', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'quitar', 'Hugo Martin Muñoz', 'L-X Azul 2'),
  ('b9b64da7-890e-4f52-b805-32a639523eae', '74567283-d08e-4c41-8427-f64633ea9745', 'quitar', 'HUGO SORIA PASTOR', 'M-J Azul 1'),
  ('48880b7c-78b4-4d4a-b4eb-7a48fd136943', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'poner', 'Inés García Martínez', 'M-J Verde 1'),
  ('48880b7c-78b4-4d4a-b4eb-7a48fd136943', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'quitar', 'Inés García Martínez', 'M-J Verde 2'),
  ('48880b7c-78b4-4d4a-b4eb-7a48fd136943', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'quitar', 'Inés García Martínez', 'M-J Rojo 3'),
  ('4ba3764e-4932-471a-9416-6536d88fa321', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'Izan Llamas Sánchez', 'M-J Verde 2'),
  ('4ba3764e-4932-471a-9416-6536d88fa321', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'Izan Llamas Sánchez', 'M-J Verde 4'),
  ('e136d25d-59be-4344-a21f-9632e8c6e133', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'JOAN HERNÁNDEZ CIVERA', 'M-J Verde 2'),
  ('e136d25d-59be-4344-a21f-9632e8c6e133', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'JOAN HERNÁNDEZ CIVERA', 'M-J Verde 4'),
  ('ed18ba6d-c484-4a7d-ba0f-5eba908dffef', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'poner', 'Joel Brantuas Batalla', 'L-X Verde 1'),
  ('ed18ba6d-c484-4a7d-ba0f-5eba908dffef', '514d3102-4eaa-44d8-b5b5-9b1b07d7c30b', 'quitar', 'Joel Brantuas Batalla', 'L-X Verde 2'),
  ('8ae064a2-37af-4386-8a0f-b27e041eba07', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'poner', 'Kael Tucci Cordoba', 'M-J Verde 1'),
  ('8ae064a2-37af-4386-8a0f-b27e041eba07', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'quitar', 'Kael Tucci Cordoba', 'M-J Verde 2'),
  ('a4143fb1-f7f7-472b-8054-cde2d2528e35', '1949f211-ed08-495b-9e75-c8a398a0e681', 'poner', 'Kalama Guillan Imas', 'L-X Rojo 3'),
  ('a4143fb1-f7f7-472b-8054-cde2d2528e35', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'quitar', 'Kalama Guillan Imas', 'L-X Rojo 2'),
  ('d264c07e-bdde-460d-9535-fc5cac9c255e', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'KENDRIC THOMSON GÓMEZ', 'M-J Verde 2'),
  ('d264c07e-bdde-460d-9535-fc5cac9c255e', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'KENDRIC THOMSON GÓMEZ', 'M-J Verde 4'),
  ('20f39355-e487-494a-ab63-c16dce1a4c5b', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'Laura Almansa Papis', 'M-J Verde 2'),
  ('20f39355-e487-494a-ab63-c16dce1a4c5b', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'Laura Almansa Papis', 'M-J Verde 4'),
  ('3d088222-0904-4bad-a7e3-d076c6c547e9', '74567283-d08e-4c41-8427-f64633ea9745', 'poner', 'Leticia Andrés Plana', 'M-J Azul 1'),
  ('3d088222-0904-4bad-a7e3-d076c6c547e9', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'quitar', 'Leticia Andrés Plana', 'M-J Azul 2'),
  ('2f5f025d-2f0c-4b65-b859-bc3e9eb9ed17', '7ac68a0a-5139-43e1-8a58-b78d18382c1a', 'poner', 'Liam Liébana Martínez', 'M-J Rojo 2'),
  ('eb81a622-9a34-4bdf-83bb-3cd735352db3', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'LUCAS DÍAZ GARRIDO', 'M-J Verde 2'),
  ('eb81a622-9a34-4bdf-83bb-3cd735352db3', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'LUCAS DÍAZ GARRIDO', 'M-J Verde 4'),
  ('677e0a06-5aed-4689-ac64-166ed49e3b0b', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'quitar', 'Lucía González Izquierdo', 'M-J Verde 2'),
  ('f2d2aba9-645f-473f-8457-fa6899e35741', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'poner', 'Manuela Alfonso González', 'M-J Verde 1'),
  ('f2d2aba9-645f-473f-8457-fa6899e35741', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'quitar', 'Manuela Alfonso González', 'M-J Verde 2'),
  ('15576bdc-d762-4f52-91d8-fb14bced7ac4', '7ac68a0a-5139-43e1-8a58-b78d18382c1a', 'quitar', 'MARCOS RAÚL JUAN MARTÍNEZ', 'M-J Rojo 2'),
  ('751af95f-34ec-4744-86f2-8b5785d23dc1', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'Maria Ortigosa Lavilla', 'M-J Verde 2'),
  ('751af95f-34ec-4744-86f2-8b5785d23dc1', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'Maria Ortigosa Lavilla', 'M-J Verde 4'),
  ('7ba34d69-d081-4dce-9be5-9dbf80529769', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'Marina Valdés Ruiz', 'M-J Verde 2'),
  ('7ba34d69-d081-4dce-9be5-9dbf80529769', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'quitar', 'Marina Valdés Ruiz', 'M-J Verde 3'),
  ('572aa9f4-09ce-4a42-a136-dcf067cfeb47', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'poner', 'Mario Gabaldón Fernández', 'M-J Verde 1'),
  ('572aa9f4-09ce-4a42-a136-dcf067cfeb47', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'quitar', 'Mario Gabaldón Fernández', 'M-J Azul 2'),
  ('9552bfac-792c-49c6-aff4-5fd3e8d67118', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'Marta Botella Aznar', 'M-J Verde 2'),
  ('9552bfac-792c-49c6-aff4-5fd3e8d67118', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'Marta Botella Aznar', 'M-J Verde 4'),
  ('c682306f-f6dc-47b8-8ef8-f54368c89b38', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'poner', 'MARTÍN DE GEA ALMIÑANA', 'M-J Rojo 3'),
  ('307c4ce0-b2b2-400c-bce9-cab0a2a8b3e1', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'poner', 'MARTÍN DE LA FUENTE PACO', 'L-X Rojo 2'),
  ('7747de3f-f000-4b24-8398-8f30e4b79c2d', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'quitar', 'MARTINA ARQUES GARCIA', 'M-J Rojo 3'),
  ('b6e58fcf-e2e2-4d58-bacc-4befefea1440', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'poner', 'Martina Segura Garcia', 'L-X Verde 1'),
  ('b6e58fcf-e2e2-4d58-bacc-4befefea1440', '514d3102-4eaa-44d8-b5b5-9b1b07d7c30b', 'quitar', 'Martina Segura Garcia', 'L-X Verde 2'),
  ('2eac0dcc-cbb6-4034-971b-1804b422b625', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'poner', 'MATIAS CATALDO PIQUERAS', 'L-X Azul 1'),
  ('83764cba-f525-4b50-82f1-1d6c905beaab', '74567283-d08e-4c41-8427-f64633ea9745', 'poner', 'Michael Segarra Arizaga', 'M-J Azul 1'),
  ('83764cba-f525-4b50-82f1-1d6c905beaab', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'quitar', 'Michael Segarra Arizaga', 'M-J Azul 2'),
  ('c2bbf8b6-ccba-448c-b98c-1f284278cd77', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'poner', 'Naiara Pardo Gonzalez', 'L-X Verde 1'),
  ('c2bbf8b6-ccba-448c-b98c-1f284278cd77', '514d3102-4eaa-44d8-b5b5-9b1b07d7c30b', 'quitar', 'Naiara Pardo Gonzalez', 'L-X Verde 2'),
  ('7025fbae-ce21-4924-87f0-4cb17d28c8ba', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'poner', 'Neline Dali Dali', 'L-X Rojo 1b'),
  ('7025fbae-ce21-4924-87f0-4cb17d28c8ba', '1949f211-ed08-495b-9e75-c8a398a0e681', 'quitar', 'Neline Dali Dali', 'L-X Rojo 3'),
  ('680b8923-cd64-41bc-affb-1253d957f168', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'poner', 'OLIVIA DÍAZ PIATEK', 'L-X Rojo 1a'),
  ('d4aed12c-8ae3-4d4e-8ddc-0b08ff36d330', '85b804bd-b180-4881-b95b-857821e4f137', 'quitar', 'PABLO GARCÍA GOMEZ', 'M-J Rojo 1a'),
  ('72858c72-6c01-4d7d-813b-009a2a53f8ae', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'poner', 'Samantha Paula Bazan', 'L-X Azul 2'),
  ('72858c72-6c01-4d7d-813b-009a2a53f8ae', 'c98add51-8636-4f01-b290-9e849a7fc935', 'quitar', 'Samantha Paula Bazan', 'M-J Azul 3'),
  ('651f278d-7eaa-427b-bb6b-43711b88adee', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'SARA DANIELA ROJAS MARIN', 'M-J Verde 2'),
  ('651f278d-7eaa-427b-bb6b-43711b88adee', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'SARA DANIELA ROJAS MARIN', 'M-J Verde 4'),
  ('9a81e54b-8353-4507-8eaf-fc2c0acfa9f1', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'poner', 'Sofia Martinez Mataix', 'L-X Verde 1'),
  ('9a81e54b-8353-4507-8eaf-fc2c0acfa9f1', '514d3102-4eaa-44d8-b5b5-9b1b07d7c30b', 'quitar', 'Sofia Martinez Mataix', 'L-X Verde 2'),
  ('59461e23-687b-411f-9326-f4b13be1015e', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'poner', 'Sofía Celeste Mandatori Mandatori', 'L-X Verde 1'),
  ('59461e23-687b-411f-9326-f4b13be1015e', '514d3102-4eaa-44d8-b5b5-9b1b07d7c30b', 'quitar', 'Sofía Celeste Mandatori Mandatori', 'L-X Verde 2'),
  ('92e6dfbf-610f-4083-a7fb-dbb21853213d', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'SUSANA DOPOZO TORO', 'M-J Verde 2'),
  ('92e6dfbf-610f-4083-a7fb-dbb21853213d', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'SUSANA DOPOZO TORO', 'M-J Verde 4'),
  ('e2815c15-3e35-41a9-b84c-ce8757814a26', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'poner', 'Valentina Alberola Puerta', 'L-X Rojo 2'),
  ('e2815c15-3e35-41a9-b84c-ce8757814a26', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'quitar', 'Valentina Alberola Puerta', 'M-J Rojo 3'),
  ('2c85e24c-294a-4eea-98f0-cb8d7044e2ea', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'VALENTINO ALONSO TORREALBA', 'M-J Verde 2'),
  ('2c85e24c-294a-4eea-98f0-cb8d7044e2ea', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'VALENTINO ALONSO TORREALBA', 'M-J Verde 4'),
  ('294abc52-fdad-4889-a410-6bb3b6e5c46f', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'poner', 'Vera Villena Gonzalez', 'M-J Rojo 3'),
  ('294abc52-fdad-4889-a410-6bb3b6e5c46f', '74567283-d08e-4c41-8427-f64633ea9745', 'quitar', 'Vera Villena Gonzalez', 'M-J Azul 1'),
  ('3d715188-fba9-421e-b5ad-178a6ce0a810', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'poner', 'Vicente Castell Podea', 'M-J Verde 2'),
  ('3d715188-fba9-421e-b5ad-178a6ce0a810', '138c719a-2d35-4dda-867b-6438db4cff2c', 'quitar', 'Vicente Castell Podea', 'M-J Verde 4'),
  ('6241a3f6-783f-47a9-b1bf-19dcd6bcfa91', 'c98add51-8636-4f01-b290-9e849a7fc935', 'quitar', 'VICTORIA RODRIGUEZ KOPCIARA', 'M-J Azul 3'),
  ('82ba8f0a-dbfe-4e1b-b57d-724941453335', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'poner', 'Walid Lahsinia Tahori', 'L-X Azul 3'),
  ('82ba8f0a-dbfe-4e1b-b57d-724941453335', '514d3102-4eaa-44d8-b5b5-9b1b07d7c30b', 'quitar', 'Walid Lahsinia Tahori', 'L-X Verde 2');

insert into public.atleta_grupos (atleta_id, grupo_id, principal)
select m.atleta_id, m.grupo_id, false
  from _m393_mover m
 where m.accion = 'poner'
on conflict (atleta_id, grupo_id) do nothing;

delete from public.atleta_grupos ag
 using _m393_mover m
 where m.accion = 'quitar' and ag.atleta_id = m.atleta_id and ag.grupo_id = m.grupo_id;

-- Quien se haya quedado sin grupo principal: el primero del listado manda
-- (el disparador pone la ficha —grupo_id y entrenador— en ese grupo).
-- Si hubiera dos grupos nuevos, se elige el primero por nombre.
update public.atleta_grupos ag
   set principal = true
  from (select distinct on (m.atleta_id) m.atleta_id, m.grupo_id
          from _m393_mover m
         where m.accion = 'poner'
         order by m.atleta_id, m.grupo) p
 where ag.atleta_id = p.atleta_id and ag.grupo_id = p.grupo_id
   and not exists (select 1 from public.atleta_grupos x where x.atleta_id = p.atleta_id and x.principal);

-- ----------------------------------------------------------------------------
-- 5 · FICHAS DE BUENO ISA (verde o sin color) SIN NINGÚN GRUPO de la escuela y
--     que no salen en los listados: grupo deducido por turno del formulario y
--     año (18:30: ≥2013 → Sub 14, ≤2012 → Recreativo). Solo si siguen sin grupo.
-- ----------------------------------------------------------------------------
create temp table _m393_sin_grupo (atleta_id uuid primary key, grupo_id uuid, nombre text, grupo text) on commit drop;
insert into _m393_sin_grupo values
  ('80646ddc-5c4a-4655-b6bf-680fbc132d09', '85b804bd-b180-4881-b95b-857821e4f137', 'Bruno Estevez Carbonell', 'M-J Rojo 1a'),
  ('69a33da7-3f2a-4817-b84d-86e652370230', '701f1399-50ae-402f-adea-ed6a65dc0d35', 'Elizabeth Torrisi -', 'L-X-V Recreativo'),
  ('f92010ac-1cb4-456c-bcb3-a6642db9429f', '1d7a73d2-b784-4421-9c36-fd6003e96075', 'Justin Resnik 0', 'M-J-V Recreativo'),
  ('f12f3e75-6136-4cf0-978d-825b4e8736ad', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'LOLA De la casa Gomez', 'M-J Verde 3'),
  ('5671bc52-f366-4186-a23e-9b235e06b6c1', 'ac820efa-d9ca-441e-bfef-56a0065d7bcd', 'Mohamed ali Moumen No tiene apellido segundo', 'L-X-V Sub 14'),
  ('c7be5ffe-2411-4c9e-b7e4-97f54135a6c7', '701f1399-50ae-402f-adea-ed6a65dc0d35', 'Nike Undine Von Kupsch No tiene. es alemana', 'L-X-V Recreativo'),
  ('aeb66a2f-b82f-4c16-9b4f-1a3e7b4c5fed', '701f1399-50ae-402f-adea-ed6a65dc0d35', 'Nolberto Rafael Sabate Franco', 'L-X-V Recreativo'),
  ('03672da2-1ff8-4bb0-b108-0a574fa55d40', '9d3cf257-4d63-44fd-9647-edb23fb93d53', 'Polina Sokalo -', 'M-J-V Sub 14'),
  ('339fe887-d751-4f61-b9a8-9a5d920c7726', '701f1399-50ae-402f-adea-ed6a65dc0d35', 'Sabrina Kirsten Nathalie Bourne Garcia', 'L-X-V Recreativo'),
  ('96c94927-e559-4fe7-b413-ee864916e515', 'ac820efa-d9ca-441e-bfef-56a0065d7bcd', 'Victoria Sifre Berenguer', 'L-X-V Sub 14');

insert into public.atleta_grupos (atleta_id, grupo_id, principal)
select s.atleta_id, s.grupo_id, true
  from _m393_sin_grupo s
 where not exists (select 1 from public.atleta_grupos ag join public.grupos g on g.id = ag.grupo_id
                    where ag.atleta_id = s.atleta_id and g.seccion = 'escuela');

update public.atletas a
   set observaciones = concat_ws(E'\n', nullif(btrim(a.observaciones),''),
         'Sin grupo del listado: grupo deducido por turno y año (' || s.grupo || ') · cuadre 15-oct-2026')
  from _m393_sin_grupo s
 where a.id = s.atleta_id and coalesce(a.observaciones,'') not like '%Sin grupo del listado%';

-- ----------------------------------------------------------------------------
-- 6 · RELLENO de datos SOLO donde la base está vacía. DNI, fecha de nacimiento,
--     correo y teléfono del tutor ya están en todas las fichas casadas (o
--     coinciden); lo único vacío que trae el Excel es la DIRECCIÓN.
--     (Discrepancia listada aparte, NO se sobrescribe: correo tutor de Artem.)
-- ----------------------------------------------------------------------------
create temp table _m393_direccion (atleta_id uuid primary key, direccion text) on commit drop;
insert into _m393_direccion values
  ('f798aaa7-1e06-4c09-b369-9f7ca9f03acf', 'C/ montgo 6 urb villamontes, 03690, Alicante'),
  ('67209d80-e5c2-41cd-816a-4420ced517c6', 'Calle Virgen del Socorro, 54, 03002, Alicante'),
  ('d84c5145-81e4-48ce-9483-c2ce176394eb', 'C/la vega 52 2D, 03007, Alicante'),
  ('9b47c303-ed88-45f4-8db4-13a470ca34cd', 'Juanito santero 5 escalera 5 2izq, 03005, Alicante'),
  ('ae1c1366-fa69-4386-8e75-021810f62651', 'Pasaje del metal n2 3 B, 03006, Alicante'),
  ('23c6a383-0927-4765-9b43-9922370f2ff8', 'Calle bailarín José Espadero 16, 03013, Alicante'),
  ('61d61ab3-5d97-4737-bb4f-d050d615191c', 'Calle Tarragona 3 edificio II 3A, 03005, Alicante'),
  ('02decd96-e873-4b73-9f6c-129034eb53ac', 'Av Jijona 45, 03010, Alicante'),
  ('8273f1dd-62d8-48d6-8c5e-7f148f19f78f', 'Andrómeda 19 P1, 03007, Alicante'),
  ('c69f0338-01a4-49b1-9ea8-f69b25198c2c', 'Calle la Esperanza 1, 03004, Alicante'),
  ('9abe7ca5-e3e2-436b-81ff-b1c22c389549', 'Calle maestro marques 77, C, 03005, Alicante'),
  ('02bf9479-4635-4ad9-a174-af4f7f50f500', 'Calle Virgen del Socorro, 54, 03002, Alicante'),
  ('bd6f5819-d0a0-45a0-86f8-6ae22895b118', 'C/Médico Antonio Arroyo 2, fase 2, esc 6, 8B, 03005, Alicante'),
  ('5508a949-a789-4438-83da-fa31b4d96616', 'Calle Britania 24, 03540, ALICANTE'),
  ('35981c60-36b4-4b9a-b770-156996dea2ce', 'C. Polux 33 Ático C, 03007, Alicante'),
  ('769a327e-b860-4a47-9906-4ff81316d2a8', 'Calle San Pablo, 73, 03012, Alicante'),
  ('f9240ec3-87f4-4661-b91f-5bf512f3c2c2', 'Avenida Jaime I  29, 03005, Alicante'),
  ('57633776-c891-475d-b519-bfc31606646b', 'Avda deportista Isabel Fernández 20, 03005, Alicante'),
  ('654b8a5e-d47d-4e91-a0ac-96365504cdf6', 'Calle Virgen del Socorro, 54, 03002, Alicante'),
  ('65669d70-ae40-46a5-8cfa-766299110363', 'Calle Gadea 2, 4 d, 03009, Alicante'),
  ('0cd2c902-f6e9-4ce0-a2d1-8ce1c36c444a', 'CALLE JOSÉ REUS GARCÍA 3, 03010, ALICANTE'),
  ('617e10ba-bb9d-4dd0-9976-ccfb97afd801', 'calle Teulada 21 4 centro, 03009, alicante'),
  ('8ecbee5f-eb35-43b4-8aaa-73d1782e7488', 'Calle Villafranqueza 54, 03690, Alicante'),
  ('22818289-ef68-4162-aea5-3363a063619d', 'Calle Padre Recaredo de los Rios 37 B, 03005, Alicante'),
  ('80646ddc-5c4a-4655-b6bf-680fbc132d09', 'Maestro José Garberí 11 T5 E1 1A, 03540, Alicante'),
  ('401a6f5a-f468-4c29-ad74-cf870ec665b4', 'Av Conde de Lumiares, 34 3°F, 03010, Alicante'),
  ('56b99e62-d651-4cf9-af67-3a77446c41da', 'Calle Alcalde Mariano Beviá 14, 03690, Sant Vicent del Raspeig'),
  ('a6717954-b6d5-410a-818e-b48c1b1d110e', 'C/Ceramica 17, esc E, 2D, 03010, Alicante'),
  ('f4412a2c-3de3-4747-b312-731e66e17447', 'Calle benillup 3 bajo T, 03005, Alicante'),
  ('b71948f6-c1a3-4141-8a93-8a334264ecae', 'Av maestro jose garberi numero 11, 03540, Alicante (Alacant)'),
  ('1b101203-1fd9-4a5f-9960-55f0ffc2e70c', 'Av.Fotógrafo Francisco Cano 39 bl1 1J, 03540, Alicante'),
  ('874e9493-0d1f-49be-821c-74e59a608b7d', 'Calle ciudad de Riga, 2, portal 2, 5B, 03005, Alicante'),
  ('c084727f-be87-44a2-973f-647e82fbdc27', 'Calle monte de Santa pola 10, 03130, Santa pola'),
  ('226306ff-4ce3-4f9f-8a2c-29c7323f7b6f', 'Pasaje metal 9, 03006, Alicante'),
  ('72f4c1a0-2a6d-4a32-b530-9132ab0b5167', 'Calle Enfermera Angelina Ceballos Quintanal n5 esc 4 6b, 03005, Alicante'),
  ('462e6a95-cd57-4c5f-894d-fe2c28c027ba', 'Avenida Cardenal Francisco Álvarez, 2A 5B, 03005, Alicante'),
  ('7f9d0c7a-d279-49b7-a02f-3fbb6ec93095', 'Avenida deportista Isabel Fernández 2, 03005, Alicante'),
  ('1aaf924b-9725-4217-963f-13bffa9b025e', 'C/ Camino del Faro 18. Bw 5, 03540, Alicante'),
  ('bfe6fef2-3502-4f89-b926-c208a109ef35', 'Avenida de Villajoyosa 95A., 03016, Alicante'),
  ('3148fe5a-6870-4a3a-abf0-0f5d1d08c37f', 'Camino del Guillemet 21, 03113, El Rebolledo'),
  ('a5876033-a1f5-428b-9032-0dc7ac82b5c2', 'PLAZA PADRE FONTOVA, 2 1ºA, 03005, ALICANTE'),
  ('69a33da7-3f2a-4817-b84d-86e652370230', 'Avenida Jose Garberi Serrano N11, 03540, Alicante'),
  ('fdee1f38-41b7-4d86-80f6-d49627efa8cf', 'Calle Santa Leonor, 8, 03005, Alicante'),
  ('5d131b04-c9d1-4707-bd42-da619c0335b1', 'Calle San Pedro Poveda número 17-1D, 03010, Alicante'),
  ('5336894b-3490-4cbc-aa17-5174c4352243', 'Practicante Juan Caturla Gosálvez 2, 03005, Alicante'),
  ('79d30d98-1ba4-4c1b-aa33-e531ad047865', 'Calle Bellea del Foc 6. Bloque A. 1B, 03015, Alicante'),
  ('a3000b5e-1140-447e-988c-beb08ee48272', 'Camino del Algarrobo 6, 03113, Alicante'),
  ('5073cfef-1ed9-4488-b0a4-ccd9e91ada6a', 'Calle general pintos 19, 03010, Alicante'),
  ('077b2c1e-4006-4956-82b5-1ebb86392f5a', 'Calle García Gutiérrez 4, ático Dch, 03013, ALICANTE'),
  ('e8da6944-6255-4b14-a896-d3c191bb33c3', 'C/Enriqueta Elizaicin 2, 03007, Alicante'),
  ('b06c1e7f-dbf0-48ee-b27c-7622abf059ac', 'Calle Padre Recaredo de los Ríos 43 bl 9 2B, 03005, Alicante'),
  ('23c026aa-0e25-481f-8aff-9b4185d3795c', 'Avd. Alfonso el Sabio 35,5izq, 03001, Alicante'),
  ('f176f4b8-f860-4d47-964b-909638f38a38', 'Médico Andrés Boldó N2 Blq8 5B, 03005, Alicante'),
  ('00c31460-1da9-4bc9-a9d4-b563862e73fe', 'Calle Tucumán número 9, 03005, Alicante'),
  ('1762f5cb-2982-4f68-97d5-9dc8e784d692', 'c/ Zarandieta, 7 - 5*A, 03010, Alicante'),
  ('9e6b0dba-645d-4b62-9747-faf213d3a8e8', 'AVENIDA ALCOY 84 4D, 03010, ALICANTE'),
  ('ef1cc583-f0a7-444a-9348-cbd9fb2697b6', 'Enfermera Angelina Ceballos n°8, 03005, Alicante'),
  ('6e8409fc-0161-44e9-9959-f8e36533cc6d', 'AVDA.DR.JIMENEZ DIAZ, 24 - B/1- 8B, 03005, ALICANTE'),
  ('c8f3ed9a-5b4d-4e24-adc6-e19579e2cd3e', 'C/Manuel Antón 8, 03004, Alicante'),
  ('82e749de-05df-4e84-9c5d-706ea73bc0bf', 'C/MÉDICO EUGENIODE LA CRUZ,Nº1, 6ºC, 03005, ALICANTE'),
  ('363be8ae-9234-423f-9156-cd6ad4518e2b', 'Camino del Algarrobo 6, 03113, Alicante'),
  ('825da28c-4977-4233-b61a-f2694aba9162', 'CALLE MÉDICO PEDRO ORTS 2, ESC.5, 6°B, 03005, ALICANTE'),
  ('700f74f4-7d54-4f2f-84ff-3211b37b8edd', 'Avenida Orihuela N91A 3D, 03007, Alicante'),
  ('178e91a1-6d52-446f-8002-dacc9917cd83', 'Avenida José jornet navarro 1 portal 2, 2ºD, 05003, Alicante'),
  ('f35dc606-0a3a-4644-b6ab-57153908aef4', 'Calle Rosa Chacel núm 30 esc 3 9 E, 03008, Alicante'),
  ('c6c231e5-0a8e-4ad7-8a1d-4f73b95a8c6e', 'Farmacéutico ángel Establier 11,6B, 03008, Alicante'),
  ('4ba3764e-4932-471a-9416-6536d88fa321', 'C/Ébano, 2, 03699, Alicante'),
  ('dc2886f9-5057-4e7e-b9c0-8b2defebf3cd', 'CALLE CAMPO DE MIRRA 12, BLOQUE 6, 5D, 03005, ALICANTE'),
  ('0a813d7b-0440-4843-9688-03ff0611b371', 'Calle Médico Andrés Boldó 2, esc.3, 1ºa, 03005, Alicante'),
  ('2faa7c76-f0f6-4313-8d02-643bbc90dc07', 'campo de mirra, 03005, alicante'),
  ('a67db4ee-d26d-4527-a3a2-1f098d20f232', 'Avda Dr Jiménez Díaz núm 22 bloque 1 7B, 03005, Alicante'),
  ('8203b35f-34ee-424d-a0f9-a42b4bca9cee', 'Virgen del Socorro, 47. 4 C, 03002, Alicante'),
  ('2a700f70-92ea-4ccb-92c6-28410fa79fbb', 'Avenida Médico Ricardo Ferre 8 Esc5 8A, 03005, Alicante'),
  ('41599f11-eac5-4436-b8e5-b2633faa1fb4', 'Calle campo de mirra número 12 escalera 6 piso 4 derecha, 03005, Alicante'),
  ('f8a08318-3d3d-4227-b34e-5a4e0205225e', 'Calle la Vega, 7 ático E, 03007, Alicante'),
  ('f92010ac-1cb4-456c-bcb3-a6642db9429f', '15 Calle Tomás López Torregrosa
Apartment 5b
Alacant-alicante, Alicante 03002, 03002, Alicante'),
  ('a4143fb1-f7f7-472b-8054-cde2d2528e35', 'Calle polop n8, 03015, Alicante'),
  ('4cd14b9d-ef77-47ed-9eb3-da5ae6d5889d', 'Calle pasaje metal 9, 03006, Alicante'),
  ('d264c07e-bdde-460d-9535-fc5cac9c255e', 'C/ PERÚ, 14 ESC 6 PISO 4ºD, 03008, ALICANTE'),
  ('a5bea0b4-c1b2-4706-b129-477722c78918', 'Santa Felicitas N7 atico, 03005, Alicante'),
  ('39737606-8e20-49aa-b9e9-a1d5d7a8a0ec', 'Calle Roque Chabás nº 21, puerta 324, 03011, Alicante'),
  ('20f39355-e487-494a-ab63-c16dce1a4c5b', 'paseo Las Margaritas 13A, 03690, San Vicente del Raspeig'),
  ('3882346f-51e2-4d24-af76-3e001f5b7ccd', 'Hermanos machado 10, 9A, 03007, Alicante'),
  ('783bcfea-b166-438c-8bf6-3036d56fdb83', 'Calle Alcala Galiano 19-1, 03012, Alicante'),
  ('d60188ef-49ce-4000-bc62-1a4aeb66f4a4', 'Campello N1 2C, 03005, Alicante'),
  ('9ab561ed-4d16-498a-92bb-1ff7bf924af8', 'Calle
México 7,3b, 03008, Alicante'),
  ('683c7588-9560-4f34-adf8-bd248058fef5', 'Avda Medico Ricardo Ferre n 42 esc1 6ºB, 3005.0, Alicante'),
  ('2c6f1077-b530-4863-b4b9-88ebff8fdf76', 'paseo Las Margaritas 13A, 03690, San Vicente del Raspeig'),
  ('60982b88-107f-4c37-894b-3951d54bbf66', 'Avenida Cardenal Francisco Álvarez, 03005, Alicante'),
  ('9c0f5fa2-a4d8-4330-a674-a531085cc7ad', 'Calle de Santa Isabel, 7, 03005, Alicante'),
  ('2f5f025d-2f0c-4b65-b859-bc3e9eb9ed17', 'C/Bailarin Jose Espadero,9-2-3B, 03015, Alicante (Alacant)'),
  ('f12f3e75-6136-4cf0-978d-825b4e8736ad', 'Calle agustín Gosalvez Orts 4, 03010, Alicante'),
  ('0e14494d-2fbf-47c3-ab02-0639771bc75c', 'Calle Enfermera Angelina Ceballos Quintanal n5 esc 4 6b, 03005, Alicante'),
  ('debd2aa2-253f-4f6a-8f6f-016bd77fb1bc', 'AVENIDA ALCOY 84 4D, 03010, ALICANTE'),
  ('045ddbf6-0b17-4d10-ac2e-56b950117832', 'Av Doctor Jimenez Diaz 23 5B, 03005, Alicante (Alacant)'),
  ('a5f7a14e-d521-4a1f-9df3-739f7d0bf4aa', 'Calle chipre 52 puerta 22, 03130, Santa Pola'),
  ('6f9f5913-05e0-46ba-a4b5-594a2a8994d6', 'Calle Sacerdote Isidro Albert N12,Esc 3,Piso 6, 03010, Alicante'),
  ('68705002-ab90-41f5-add2-e8b37010a06c', 'CALLE MAESTRO MARQUES, 35, 03004, ALICANTE'),
  ('87640a4e-8dba-4d85-a78a-db9ac7d39e89', 'Avenida cardenal francisco Álvarez 14, 03005, Alicante'),
  ('88d4b8bc-b4b0-4cfa-8ac0-f044ae9a1cd0', 'Calle Juan Caturla Gosalvez 2, 03005, San Clemente'),
  ('abbea049-fce1-48c5-aff5-155e264036dd', 'Avenida Maestro José Garberí Serrano 14, bl 3, esc 5, 5AD, 03540, Alicante'),
  ('71032663-7993-4c28-853c-7150a6a412ad', 'Calle Vasco de Gama 40, 03009, Alicante'),
  ('e2b2b42c-242a-4ad9-8da2-b22064dfd22a', 'Calle Camino de Ronda 9, 03005, Alicante'),
  ('97e72e85-3d43-4027-8a54-b8873cd4bd56', 'C/la vega 52, 03007, Alicante'),
  ('c4fe81ae-a117-4e45-a9ce-81f0026354d2', 'C/Ceramica 17, esc E, 2D, 03010, Alicante'),
  ('f6d3b50f-49ed-41e6-a995-fe58be2bea5c', 'C/ Juanito Santero 4, 4F, 03005, Alicante'),
  ('26f8ae8b-14c3-4134-a3d4-211240a47b82', 'C/ Camino del faro 18. bw 5, 03540, Alicante'),
  ('d4ce1e0e-4473-4772-be41-87140d4bd0c4', 'c/Padre Recaredo de los ríos, núm.57, Bl.1, E4, 9ºizda, 03005, Alicante'),
  ('8e2a21c3-29c1-4eb4-9c10-657f67ff756f', 'Avenida Vicente Blasco Ibáñez, 15, 03005, Alicante'),
  ('15576bdc-d762-4f52-91d8-fb14bced7ac4', 'CALLE VICENTE ALEXANDRE, N°11, 03010, ALICANTE'),
  ('77dd6782-1c7e-4259-8d82-2d198cd6e5a8', 'Calle Médico Pedro Orts 2, 03005, Alicante'),
  ('3be5133f-d918-4da6-b789-c60b95956433', 'C/Lliber nº9, 03007, Alicante'),
  ('e0fa3ee0-827d-47d9-8b33-6a595900305b', 'Calle Jacinto Benavente 15, 1 Izq, 03010, Alicante'),
  ('520d5271-9c8c-4c59-aeb0-480db06b9905', 'Calle Asturias 6 Atico, 03007, Alicante'),
  ('e62e0e3d-f26c-4fd5-bd51-99b86a43b111', 'Avda Medico Ricardo Ferre n 42 esc 1 6ºB, 03005, Alicante'),
  ('296da506-86a3-4ba7-b727-83f88166a228', 'Calle médico Pedro orts n2, 03005, Alicante'),
  ('3015ab34-c6ac-434d-8019-603252a1d3d6', 'Calle Ciudad Real 23, 03005, Alicante'),
  ('7d1887b7-80ce-499b-a8ba-4512accecbc5', 'Calle Guadalest, 15, 03005, Alicante'),
  ('f8e1b0df-19cf-49d5-be04-1fdd63509d8b', 'C/ Escritor Enrique Cerdan Tato 13, 03005, Alicante'),
  ('83764cba-f525-4b50-82f1-1d6c905beaab', 'Calle Polop 32, 03915, Alicante'),
  ('7d8752cc-f740-4138-816a-69ded9992dbf', 'C/ Médico Andrés Boldó, 2, P2, 7A, 03005, Alicante'),
  ('94e67623-78a7-46cc-bae6-e5f2784f10a1', 'Calle médico Andrés boldo 2, 03005, Alicante'),
  ('3e46e906-e875-4aac-9955-adf8bb0cfd8c', 'Calle Gadea 15 3C, 03009, Alicante'),
  ('9409f07d-7708-4aba-b74f-83fa67ee4454', 'Medico Andrés Boldó N2 Blq8 5B, 03005, Alicante'),
  ('5671bc52-f366-4186-a23e-9b235e06b6c1', 'Calle general shelly n24, 03012, Alicante'),
  ('c53737aa-d63c-4939-93f2-5fc51b1f8b2c', 'CALLE DOCTOR JUST N 10, 03007, Alacant'),
  ('7025fbae-ce21-4924-87f0-4cb17d28c8ba', 'Calle Ana Navarro 42 3B florida alicante, 03007, Alicante'),
  ('0112fe21-91bc-44f4-b39a-e7a60b3beaca', 'Avda José María Hernández Mata núm 2 3D, 03007, ALICANTE'),
  ('c7be5ffe-2411-4c9e-b7e4-97f54135a6c7', 'Calle Brasil num 17, 03008, Alicante'),
  ('aeb66a2f-b82f-4c16-9b4f-1a3e7b4c5fed', 'CALLE ENRIC VALOR 2, ESCALERA 5, PISO 7B, 03540, Alicante'),
  ('f4207d90-3409-4a1e-af6a-3c5cf7510711', 'Calle pintor cabrera n14., 03003, Alicante'),
  ('c8b71161-4e8a-4274-bf3c-33f18c83f29a', 'Calle México 11, 03008, Alicante'),
  ('50ca1204-19c3-4f19-baf2-1c2a69c12256', 'Av Doctor Jimenez Diaz 23 5B, 03005, Alicante (Alacant)'),
  ('680b8923-cd64-41bc-affb-1253d957f168', 'CALLE BRITANIA 24, 03540, ALICANTE'),
  ('2e112789-cead-4771-a365-b216d989dab7', 'C/Juanito Santero, nº5, esc:1, 3ºD, 03005, Alicante'),
  ('108f1c46-ffc0-4798-bc8c-be2f9e5ed1e7', 'Calle Padre Recaredo de los Ríos 40 BW28, 03005, Alicante'),
  ('9236c70a-7c62-41f1-8f34-8948715c76d3', 'Avd.José Jornet Navarro, 1 Esc 12 2°Dcha, 03005, ALICANTE'),
  ('c8eac940-34c7-4c7d-9012-4e5fd530770f', 'Calle Campello, 1, 03005, Alicante'),
  ('482cab57-6408-4d70-9f8a-fc3f043a2bcd', 'Avenida Benito Pérez Galdós 10, 03004, Alicante'),
  ('03672da2-1ff8-4bb0-b108-0a574fa55d40', 'Avenida Niza 30, p. 15 C izq, 03540, Alicante'),
  ('e18c4b9c-0724-49bb-a5bb-153c551fe07f', 'Padre Recaredo de los Ríos, 41, 2Izquierda, 03005, Alicante'),
  ('c1ad7dc6-1315-4961-84d2-b62babaf7910', 'General Pintos n19, 03010, Alicante'),
  ('36a1e85c-86af-4ce0-ac0e-6919e129597e', 'PLAZA PAPA JUAN PABLO II, NUMERO 11, 3D, 03005, ALICANTE'),
  ('631d6817-5940-4f58-bd7e-1bb51188637e', 'C/ montgo 6 urb villamontes, 03690, Alicante'),
  ('90928299-61bc-4492-9d69-7b8e1ac740f2', 'Calle barcelona 9 2 derecha, 03013, Alicante'),
  ('339fe887-d751-4f61-b9a8-9a5d920c7726', 'Av. periodista Rodolfo salazar 26, esc derch 5° B, 03012, Alicante'),
  ('72858c72-6c01-4d7d-813b-009a2a53f8ae', 'Calle Deportista Ángel Aznar 8, 03006, Alicante'),
  ('651f278d-7eaa-427b-bb6b-43711b88adee', 'CALLE DOCTOR JUST N 10, 03007, ALICANTE'),
  ('32629d9c-8bab-41c4-b8ca-f496f2a814f4', 'Calle Buenos Aires 9, 1-A, 03009, Alicante'),
  ('7e8a82c9-1917-470b-8d39-c997076b8c85', 'Avenida Condes Soto Ameno 59 1ºB, 03005, Alicante'),
  ('a30e7554-e73d-486a-bd3f-e609dccef771', 'Calle escorpión 20 2 derecha, 03006, Alicante'),
  ('e335f930-9019-4471-a973-da048ffc1da5', 'Calle Campello, 1, 03005, Alicante'),
  ('e546af29-d7c6-4f41-814e-d5a596bcbf2e', 'Calle Riu algar 4 Bw.26, 03690, San Vicente del raspeig'),
  ('64f52f77-bd8f-4627-bafc-1fe375cb5567', 'C/ Gadea, 7, 03009, Alicante'),
  ('69b63ee7-244f-4d00-8b10-b8072f410a5c', 'Calle Sacerdote Isidro Albert N12,Esc3,piso 6, 03010, Alicante'),
  ('36c824f8-fa1f-4554-8bc7-0e0c69b206de', 'Calle DOCTOR FERRAN 13-15, 03012, ALICANTE'),
  ('59461e23-687b-411f-9326-f4b13be1015e', 'Avenida Doctor Jiménez Díaz 16, 03005, Alicante'),
  ('3a3b7c8b-42a8-46fd-be50-db4d6551bc58', 'Calle Juan Caturla Gosalvez 2, 03005, Alicante'),
  ('5e386d92-fcb2-41bc-a3d7-70d896fc7432', 'Calle los sogorb 37, 03006, Alicante'),
  ('e2815c15-3e35-41a9-b84c-ce8757814a26', 'C/Belfast, 27, 3 dcha, 03005, Alicante'),
  ('6fd06a98-97dc-444f-afac-6af71c7e7c96', 'Calle campo de mirra, 12, 03005, Alicante'),
  ('f36b8680-ce7b-4924-b346-a6fd212496b7', 'Avda Pintor Xavier Soler, 7, 03015, Alicante'),
  ('6ddc91f0-85e2-4d35-bb1c-da8cc3bf0cb5', 'Av Conde de luminarias,34 3°F, 03010, Alicante'),
  ('294abc52-fdad-4889-a410-6bb3b6e5c46f', 'C/Ciudad Real 16 bl9 2D, 03005, Alicante'),
  ('96c94927-e559-4fe7-b413-ee864916e515', 'Av. CONDE LUMIARES, 34, 2º, F, 03010, ALICA TE'),
  ('291076dc-aac0-4e21-b955-6c3ccbc33927', 'Les Fogueres de Sant Joan 4, 03009, Alicante'),
  ('4e536ea1-609b-4c42-9063-da23c0e87423', 'Calle presbítero baltasar carrasco 32,1,izq, 03005, Alicante'),
  ('53610299-3ef3-43e2-a309-05c5a03d1f00', 'C/virgen del Puig 19 bl8. 3A, 03009, Alicante'),
  ('93970a87-0ffe-485e-8942-33c85ad15835', 'Avenida Novelda 68, 03010, Alicante'),
  ('2be2e1f8-5bc9-4dd3-bbee-5a47a8219aad', 'Reyes Católicos N82, 3690.0, San Vicente del Raspeig'),
  ('3595f42c-495a-4088-ad01-18ef0efa7d89', 'Calle Juan Caturla Gosalvez 2, 03005, Alicante'),
  ('e5c082ea-a378-4804-b0f4-15a07df03528', 'C/Campello 1, 03005, Alicante'),
  ('1f293b95-fab4-40f5-ae8b-f39d4ae6c360', 'Avenida Condes Soto Ameno 59 1ºB, 03005, Alicante');

update public.atletas a
   set direccion = d.direccion
  from _m393_direccion d
 where a.id = d.atleta_id and nullif(btrim(a.direccion), '') is null;

-- ----------------------------------------------------------------------------
-- 7 · COMPROBACIÓN FINAL (sobre el estado final: vale igual en la 1ª pasada y en
--     las siguientes). Si algo no cuadra → RAISE y no se guarda nada.
-- ----------------------------------------------------------------------------
do $$
declare v int; msg text := '';
begin
  -- 1 · bajas
  select count(*) into v from _m393_bajas;                              if v <> 12 then msg := msg || format(' bajas en lista=%s (esperado 12);', v); end if;
  select count(*) into v from _m393_bajas b join public.atletas a on a.id = b.atleta_id
   where a.estado = 'baja' and a.fecha_baja is not null and a.observaciones like '%Baja según listado de Isa 15-oct-2026%';
  if v <> 12 then msg := msg || format(' bajas marcadas=%s/12;', v); end if;
  select count(*) into v from _m393_bajas b join public.atleta_grupos ag on ag.atleta_id = b.atleta_id
    join public.grupos g on g.id = ag.grupo_id and g.seccion = 'escuela';
  if v <> 0 then msg := msg || format(' bajas aún en grupos de escuela=%s;', v); end if;
  -- 2 · verdes
  select count(*) into v from _m393_activar t join public.atletas a on a.id = t.atleta_id where a.estado = 'activo';
  if v <> 60 then msg := msg || format(' verdes activos=%s/60;', v); end if;
  -- 3 · nuevos (una sola ficha cada uno, con su grupo)
  select count(*) into v from _m393_nuevos n join public.atletas a
    on a.fecha_nacimiento = n.fecha_nacimiento and lower(btrim(a.nombre)) = lower(n.nombre)
   and lower(btrim(coalesce(a.apellidos,''))) = lower(n.apellidos);
  if v <> 15 then msg := msg || format(' nuevos con ficha=%s/15 (¿duplicado o falta?);', v); end if;
  select count(*) into v from _m393_nuevos n join public.atletas a
    on a.fecha_nacimiento = n.fecha_nacimiento and lower(btrim(a.nombre)) = lower(n.nombre)
   and lower(btrim(coalesce(a.apellidos,''))) = lower(n.apellidos)
  join public.atleta_grupos ag on ag.atleta_id = a.id and ag.grupo_id = n.grupo1 and ag.principal;
  if v <> 15 then msg := msg || format(' nuevos en su grupo=%s/15;', v); end if;
  -- 4 · cambios de grupo
  select count(*) into v from _m393_mover m join public.atleta_grupos ag
    on ag.atleta_id = m.atleta_id and ag.grupo_id = m.grupo_id where m.accion = 'poner';
  if v <> 50 then msg := msg || format(' puestos en grupo=%s/50;', v); end if;
  select count(*) into v from _m393_mover m join public.atleta_grupos ag
    on ag.atleta_id = m.atleta_id and ag.grupo_id = m.grupo_id where m.accion = 'quitar';
  if v <> 0 then msg := msg || format(' siguen en el grupo viejo=%s;', v); end if;
  select count(distinct m.atleta_id) into v from _m393_mover m
   where not exists (select 1 from public.atleta_grupos ag where ag.atleta_id = m.atleta_id and ag.principal);
  if v <> 0 then msg := msg || format(' movidos sin grupo principal=%s;', v); end if;
  -- ficha (atletas.grupo_id) coherente con el principal
  select count(*) into v from (select atleta_id from _m393_mover union select atleta_id from _m393_sin_grupo) t
    join public.atletas a on a.id = t.atleta_id
    left join public.atleta_grupos ag on ag.atleta_id = a.id and ag.principal
   where a.grupo_id is distinct from ag.grupo_id;
  if v <> 0 then msg := msg || format(' fichas con grupo_id distinto del principal=%s;', v); end if;
  -- 5 · sin grupo → deducido
  select count(*) into v from _m393_sin_grupo s join public.atleta_grupos ag
    on ag.atleta_id = s.atleta_id and ag.grupo_id = s.grupo_id;
  if v <> 10 then msg := msg || format(' deducidos en su grupo=%s/10;', v); end if;
  -- 6 · direcciones
  select count(*) into v from _m393_direccion d join public.atletas a on a.id = d.atleta_id
   where nullif(btrim(a.direccion),'') is not null;
  if v <> 173 then msg := msg || format(' direcciones=%s/173;', v); end if;
  -- Global: todo el que sale en un listado (y no es baja) está en ese grupo
  select count(*) into v from (values ('00c31460-1da9-4bc9-a9d4-b563862e73fe'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('0164aa42-1982-4572-a984-cbf857b73b30'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('02bf9479-4635-4ad9-a174-af4f7f50f500'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('02decd96-e873-4b73-9f6c-129034eb53ac'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('045ddbf6-0b17-4d10-ac2e-56b950117832'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('06cf5a54-7b05-4d43-a39d-0033cd70b27f'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('077b2c1e-4006-4956-82b5-1ebb86392f5a'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('0961ad10-1f18-482c-8be8-986daf91f29b'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('0a813d7b-0440-4843-9688-03ff0611b371'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('0ad150c5-f266-413a-850d-fa4ee1c006bd'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('0b3cb855-6f03-43a0-90fc-ce281305215b'::uuid,'ec084bfe-6906-4f06-8523-b708a7fc2efe'::uuid), ('0cd2c902-f6e9-4ce0-a2d1-8ce1c36c444a'::uuid,'7ac68a0a-5139-43e1-8a58-b78d18382c1a'::uuid), ('0d6f24a8-be22-47c9-88b8-a63e033cda19'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('0dfe172d-2865-4df2-8fb7-e6a8df280a32'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('0e14494d-2fbf-47c3-ab02-0639771bc75c'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('10555c59-530b-49bc-9c94-26b68b36741a'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('108f1c46-ffc0-4798-bc8c-be2f9e5ed1e7'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('15576bdc-d762-4f52-91d8-fb14bced7ac4'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('1762f5cb-2982-4f68-97d5-9dc8e784d692'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('178e91a1-6d52-446f-8002-dacc9917cd83'::uuid,'7ac68a0a-5139-43e1-8a58-b78d18382c1a'::uuid), ('18596e0c-9454-4680-835f-e3f9a6f9f647'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('18faaf52-599e-421a-a912-cd3aa805f4c6'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('18faaf52-599e-421a-a912-cd3aa805f4c6'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('1aaf924b-9725-4217-963f-13bffa9b025e'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('1bcd0b85-8a1a-4fa0-8db8-4994de496fb4'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('1f293b95-fab4-40f5-ae8b-f39d4ae6c360'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('20cfc16e-7324-4d51-aa97-456ad50bb013'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('20f39355-e487-494a-ab63-c16dce1a4c5b'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('226306ff-4ce3-4f9f-8a2c-29c7323f7b6f'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('22818289-ef68-4162-aea5-3363a063619d'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('23c026aa-0e25-481f-8aff-9b4185d3795c'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('23c6a383-0927-4765-9b43-9922370f2ff8'::uuid,'7ac68a0a-5139-43e1-8a58-b78d18382c1a'::uuid), ('242c8203-1f7c-4b32-9f1d-d956e15bf878'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('24933ce0-436b-4fb6-b642-c04309b1495f'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('2586e34d-f487-4140-ad86-679f53bd1813'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('291076dc-aac0-4e21-b955-6c3ccbc33927'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('294abc52-fdad-4889-a410-6bb3b6e5c46f'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('296ad4b5-90d3-453b-81e2-44c2beefed8c'::uuid,'00ec2abf-346e-4e3a-9895-73c55b40b07d'::uuid), ('296da506-86a3-4ba7-b727-83f88166a228'::uuid,'7ac68a0a-5139-43e1-8a58-b78d18382c1a'::uuid), ('2a700f70-92ea-4ccb-92c6-28410fa79fbb'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('2acad017-9d3d-4537-8400-f8739b96a52a'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('2ad66e4d-3836-4f9b-a48d-a96760eb7f8a'::uuid,'ec084bfe-6906-4f06-8523-b708a7fc2efe'::uuid), ('2c6f1077-b530-4863-b4b9-88ebff8fdf76'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('2c704f95-72c5-4dbe-954e-b6784d251523'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('2c85e24c-294a-4eea-98f0-cb8d7044e2ea'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('2ca836d9-622d-47dd-bec2-a76be1e625eb'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('2e112789-cead-4771-a365-b216d989dab7'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('2eac0dcc-cbb6-4034-971b-1804b422b625'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('2f5f025d-2f0c-4b65-b859-bc3e9eb9ed17'::uuid,'7ac68a0a-5139-43e1-8a58-b78d18382c1a'::uuid), ('3015ab34-c6ac-434d-8019-603252a1d3d6'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('303bfcf8-40c2-4696-8059-e0762a0a0754'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('307c4ce0-b2b2-400c-bce9-cab0a2a8b3e1'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('3148fe5a-6870-4a3a-abf0-0f5d1d08c37f'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('31556aad-8de7-4468-9827-2a07f675f4c2'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('32629d9c-8bab-41c4-b8ca-f496f2a814f4'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('333c6e30-236c-4ff6-9cb3-f33416578216'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('336e4d1c-8f9e-4ecb-8772-b3d5b47386d7'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('342320e5-7b99-4679-876c-2613da31ffec'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('34ee97c2-d9bf-481c-9e4a-998c9818e15f'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('35078352-274b-43be-a20b-c5defb32011f'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('3589fc66-9f6c-469f-b2d5-02eb3e829949'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('3595f42c-495a-4088-ad01-18ef0efa7d89'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('35981c60-36b4-4b9a-b770-156996dea2ce'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('363be8ae-9234-423f-9156-cd6ad4518e2b'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('36a1e85c-86af-4ce0-ac0e-6919e129597e'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('37b6703e-e88b-49a5-b5fc-a86175abe3e2'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('3882346f-51e2-4d24-af76-3e001f5b7ccd'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('39737606-8e20-49aa-b9e9-a1d5d7a8a0ec'::uuid,'7ac68a0a-5139-43e1-8a58-b78d18382c1a'::uuid), ('3999310b-ef15-4e90-bd44-037f63b37425'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('3a3b7c8b-42a8-46fd-be50-db4d6551bc58'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('3ab8aca1-0582-4b9d-95da-c9ee8997afc2'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('3be5133f-d918-4da6-b789-c60b95956433'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('3d088222-0904-4bad-a7e3-d076c6c547e9'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('3d715188-fba9-421e-b5ad-178a6ce0a810'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('3db34245-59e2-4663-a865-e2e21be5b1d5'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('3e46e906-e875-4aac-9955-adf8bb0cfd8c'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('3e749130-0e9f-4fe7-ad4c-f064dece2174'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('3fff0c26-77fd-4680-902e-832ca93eb111'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('401a6f5a-f468-4c29-ad74-cf870ec665b4'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('41599f11-eac5-4436-b8e5-b2633faa1fb4'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('424f7dff-05d5-4e3a-a909-b9c93693d5cf'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('462e6a95-cd57-4c5f-894d-fe2c28c027ba'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('482cab57-6408-4d70-9f8a-fc3f043a2bcd'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('48880b7c-78b4-4d4a-b4eb-7a48fd136943'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('48c7aa19-72f4-43b8-9873-ed737438740c'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('4a6e601f-48db-4857-8ee4-d2be4728c827'::uuid,'ec084bfe-6906-4f06-8523-b708a7fc2efe'::uuid), ('4ba3764e-4932-471a-9416-6536d88fa321'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('4cd14b9d-ef77-47ed-9eb3-da5ae6d5889d'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('4e536ea1-609b-4c42-9063-da23c0e87423'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('4ef05014-2956-4d75-91a2-93345c4bf603'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('4ef05014-2956-4d75-91a2-93345c4bf603'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('4f6d354d-90d1-4b10-8c81-75df3418add3'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('4fa17c3c-2e49-4836-92cf-5f4e4c93d3bc'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('50ca1204-19c3-4f19-baf2-1c2a69c12256'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('520d5271-9c8c-4c59-aeb0-480db06b9905'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('52a7eaab-33b1-43ac-80fc-340b8d74f347'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('53066138-6125-4678-985b-96f4d9384e61'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('5336894b-3490-4cbc-aa17-5174c4352243'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('5508a949-a789-4438-83da-fa31b4d96616'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('56b99e62-d651-4cf9-af67-3a77446c41da'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('572aa9f4-09ce-4a42-a136-dcf067cfeb47'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('572aa9f4-09ce-4a42-a136-dcf067cfeb47'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('57ce7226-910c-47fd-afab-16a8e49b77a4'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('59461e23-687b-411f-9326-f4b13be1015e'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('5d24eefe-0fd2-4194-a66d-f6ce96813329'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('5e0c0e4e-0712-4f0a-85d5-b63db83a2da0'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('5e386d92-fcb2-41bc-a3d7-70d896fc7432'::uuid,'00ec2abf-346e-4e3a-9895-73c55b40b07d'::uuid), ('60982b88-107f-4c37-894b-3951d54bbf66'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('617e10ba-bb9d-4dd0-9976-ccfb97afd801'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('61d61ab3-5d97-4737-bb4f-d050d615191c'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('6241a3f6-783f-47a9-b1bf-19dcd6bcfa91'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('631d6817-5940-4f58-bd7e-1bb51188637e'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('64f52f77-bd8f-4627-bafc-1fe375cb5567'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('651f278d-7eaa-427b-bb6b-43711b88adee'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('65669d70-ae40-46a5-8cfa-766299110363'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('666fd110-3397-4e07-89e3-8cb0d984bcf8'::uuid,'00ec2abf-346e-4e3a-9895-73c55b40b07d'::uuid), ('67209d80-e5c2-41cd-816a-4420ced517c6'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('677e0a06-5aed-4689-ac64-166ed49e3b0b'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('680b8923-cd64-41bc-affb-1253d957f168'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('683c7588-9560-4f34-adf8-bd248058fef5'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('68705002-ab90-41f5-add2-e8b37010a06c'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('69b63ee7-244f-4d00-8b10-b8072f410a5c'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('6ddc91f0-85e2-4d35-bb1c-da8cc3bf0cb5'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('6e8409fc-0161-44e9-9959-f8e36533cc6d'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('6f9f5913-05e0-46ba-a4b5-594a2a8994d6'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('6fd06a98-97dc-444f-afac-6af71c7e7c96'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('700f35a0-137f-4366-9080-91c94068f769'::uuid,'ec084bfe-6906-4f06-8523-b708a7fc2efe'::uuid), ('700f74f4-7d54-4f2f-84ff-3211b37b8edd'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('7025fbae-ce21-4924-87f0-4cb17d28c8ba'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('71032663-7993-4c28-853c-7150a6a412ad'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('71f3df6e-f457-4f52-83ea-a56ba14c5647'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('72858c72-6c01-4d7d-813b-009a2a53f8ae'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('72d23b31-4016-4dd0-9926-4954cc84b973'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('72f4c1a0-2a6d-4a32-b530-9132ab0b5167'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('72f4c1a0-2a6d-4a32-b530-9132ab0b5167'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('740f8909-b1fe-459f-aa6f-5903c5e598be'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('740f8909-b1fe-459f-aa6f-5903c5e598be'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('74d99483-834d-4b85-8d18-4e13e28127c3'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('751af95f-34ec-4744-86f2-8b5785d23dc1'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('7568a472-9eb7-4136-9ebf-f62097d2ca3b'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('759f0cfd-bacd-426c-bdc8-2f1d1a5d1599'::uuid,'00ec2abf-346e-4e3a-9895-73c55b40b07d'::uuid), ('766d59e0-ea2e-4a4d-9533-3e508baf8be0'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('7747de3f-f000-4b24-8398-8f30e4b79c2d'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('77dd6782-1c7e-4259-8d82-2d198cd6e5a8'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('783bcfea-b166-438c-8bf6-3036d56fdb83'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('7a3f22a1-a7dd-4359-9797-7d359cd1239b'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('7ba34d69-d081-4dce-9be5-9dbf80529769'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('7cabe10c-5fbf-4576-80d5-284f3ca9dfa1'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('7d0985c0-8d7a-442e-83ff-67da3b72cce2'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('7d1887b7-80ce-499b-a8ba-4512accecbc5'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('7d41762e-d468-4316-a140-a266a90a5206'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('7d8752cc-f740-4138-816a-69ded9992dbf'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('7e8a82c9-1917-470b-8d39-c997076b8c85'::uuid,'00ec2abf-346e-4e3a-9895-73c55b40b07d'::uuid), ('7e937446-171e-49e9-a5d3-21a316292f06'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('7f9d0c7a-d279-49b7-a02f-3fbb6ec93095'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('8203b35f-34ee-424d-a0f9-a42b4bca9cee'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('82293a35-cef6-4a8d-ab06-17aeeca72827'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('825da28c-4977-4233-b61a-f2694aba9162'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('8273f1dd-62d8-48d6-8c5e-7f148f19f78f'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('82ba8f0a-dbfe-4e1b-b57d-724941453335'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('82e749de-05df-4e84-9c5d-706ea73bc0bf'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('835b5cd9-59df-4ea1-9297-8d25fe560579'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('83764cba-f525-4b50-82f1-1d6c905beaab'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('841c4f66-831c-42e8-9e07-b40138866b23'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('850c95a9-a1bc-4e05-a22a-b2099166e558'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('87640a4e-8dba-4d85-a78a-db9ac7d39e89'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('8887e2c6-0cb4-4999-bc01-dce89526a710'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('88d4b8bc-b4b0-4cfa-8ac0-f044ae9a1cd0'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('89fa1848-3c29-4247-8fa8-29278f89ffcc'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('8a76794e-2d51-43cb-b2f5-6866f62b10dc'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('8ae064a2-37af-4386-8a0f-b27e041eba07'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('8bbadb65-d11f-48f0-89ea-23d363f99998'::uuid,'ec084bfe-6906-4f06-8523-b708a7fc2efe'::uuid), ('8e121176-131d-40cf-be56-90c6b75a27f0'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('8e2a21c3-29c1-4eb4-9c10-657f67ff756f'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('8ecbee5f-eb35-43b4-8aaa-73d1782e7488'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('8f1f9dae-49ae-4e11-aa0f-01e9202cca64'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('90928299-61bc-4492-9d69-7b8e1ac740f2'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('9236c70a-7c62-41f1-8f34-8948715c76d3'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('92e6dfbf-610f-4083-a7fb-dbb21853213d'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('93970a87-0ffe-485e-8942-33c85ad15835'::uuid,'7ac68a0a-5139-43e1-8a58-b78d18382c1a'::uuid), ('9409f07d-7708-4aba-b74f-83fa67ee4454'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('94e67623-78a7-46cc-bae6-e5f2784f10a1'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('9552bfac-792c-49c6-aff4-5fd3e8d67118'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('96dee032-ec48-4c07-acdf-9bcd27dfe6f1'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('97e72e85-3d43-4027-8a54-b8873cd4bd56'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('9a81e54b-8353-4507-8eaf-fc2c0acfa9f1'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('9ab561ed-4d16-498a-92bb-1ff7bf924af8'::uuid,'7ac68a0a-5139-43e1-8a58-b78d18382c1a'::uuid), ('9b47c303-ed88-45f4-8db4-13a470ca34cd'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('9c0f5fa2-a4d8-4330-a674-a531085cc7ad'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('9ce65c2e-5d04-4e17-9b55-d4cc3d208b08'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('9ce93e3b-3b3a-4081-bcfd-023e7ee318a6'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('9d1f7257-32f5-4d16-8d38-e8f8cc40c825'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('9e6b0dba-645d-4b62-9747-faf213d3a8e8'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('a0514e7a-beaa-4957-83b1-f6ec3c5ee61e'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('a1d6f8a7-d54e-4599-925f-6958d4d9c8cd'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('a3000b5e-1140-447e-988c-beb08ee48272'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('a30e7554-e73d-486a-bd3f-e609dccef771'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('a34033a8-f7ca-4d78-9161-e235bf472c0c'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('a3fed751-145f-40ed-a558-c149d24277f1'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('a4143fb1-f7f7-472b-8054-cde2d2528e35'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('a5876033-a1f5-428b-9032-0dc7ac82b5c2'::uuid,'ec084bfe-6906-4f06-8523-b708a7fc2efe'::uuid), ('a5f7a14e-d521-4a1f-9df3-739f7d0bf4aa'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('a6717954-b6d5-410a-818e-b48c1b1d110e'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('a67db4ee-d26d-4527-a3a2-1f098d20f232'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('a98b6c70-e03e-4354-bcef-490340c33c80'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('abbea049-fce1-48c5-aff5-155e264036dd'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('ad87ab0b-1daf-40c5-a9ad-1f8e77ba5b06'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('ae1c1366-fa69-4386-8e75-021810f62651'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('b06c1e7f-dbf0-48ee-b27c-7622abf059ac'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('b126960e-1c36-4529-9a1b-5452fc5e9114'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('b375cdc5-4203-423c-a8df-9f2ef00cec5b'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('b46c6b5c-f1d8-4fe0-abd4-c69a44f8ec1f'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('b4f2d5d6-2098-4a9a-a5df-9051717a3c88'::uuid,'ec084bfe-6906-4f06-8523-b708a7fc2efe'::uuid), ('b5231cac-a1b8-42e4-a738-67de4b58adf2'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('b5a86d2b-be26-453e-8d16-7ddea80205c1'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('b64173d1-90c6-4823-a7ff-47abf33e8e2b'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('b6e58fcf-e2e2-4d58-bacc-4befefea1440'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('b7357b00-43dc-4a65-b959-24b8da071086'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('b7372109-e08d-414a-986c-186c5080e662'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('b80b8a70-7735-4d99-b7c7-70d85ec07ddf'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('b9795132-06b9-4321-b78b-94828682c705'::uuid,'00ec2abf-346e-4e3a-9895-73c55b40b07d'::uuid), ('b9b64da7-890e-4f52-b805-32a639523eae'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('bd6f5819-d0a0-45a0-86f8-6ae22895b118'::uuid,'85b804bd-b180-4881-b95b-857821e4f137'::uuid), ('bdcd4bb9-1372-47d1-89dd-4ed6da85bb32'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('be9f7039-f03b-4378-afd1-37224e93035b'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('bea43430-f63e-4d8d-ba40-a9918a04b970'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('bf29a087-a64f-4f6a-8c33-bf2660247c14'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('bfe6fef2-3502-4f89-b926-c208a109ef35'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('c2bbf8b6-ccba-448c-b98c-1f284278cd77'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('c3ce358d-d76f-491a-a67d-6911df516688'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('c42f4974-99b8-44a1-9fff-f2138171e505'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('c484f6a1-5964-4f40-8f98-d50eb7a7fa77'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('c4fe81ae-a117-4e45-a9ce-81f0026354d2'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('c53737aa-d63c-4939-93f2-5fc51b1f8b2c'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('c64a2a26-eaa5-482f-8858-5e72ca1f1f83'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('c682306f-f6dc-47b8-8ef8-f54368c89b38'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('c69f0338-01a4-49b1-9ea8-f69b25198c2c'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('c6c231e5-0a8e-4ad7-8a1d-4f73b95a8c6e'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('c75ce74d-06ba-4671-9e8f-3cb44f6f8e00'::uuid,'00ec2abf-346e-4e3a-9895-73c55b40b07d'::uuid), ('c78ec71b-426f-46a0-b17d-c5adfd3d21ed'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('c8eac940-34c7-4c7d-9012-4e5fd530770f'::uuid,'0833f3d7-b760-416b-9677-0dcf07aba7db'::uuid), ('c8f3ed9a-5b4d-4e24-adc6-e19579e2cd3e'::uuid,'78fe7dac-6dd2-4e6a-ba3e-88563e028f5c'::uuid), ('cb04217a-c0f5-49fc-b29c-872684f6af00'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('ccc93bba-0abb-4888-a75f-02c5465baa56'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('cd0c70ad-c6cd-424c-a2c7-68b5dd3240a2'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('cd261ce0-00cd-442a-ac79-b3e7f1db8a1e'::uuid,'74567283-d08e-4c41-8427-f64633ea9745'::uuid), ('ce2ccbf9-8a96-4fc8-b788-f073af0f78db'::uuid,'ec084bfe-6906-4f06-8523-b708a7fc2efe'::uuid), ('d037a647-9072-4a4e-aef5-6a77050b8cba'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('d264c07e-bdde-460d-9535-fc5cac9c255e'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('d281cd0a-bebc-4ea1-b4d6-3836beb32641'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('d4aed12c-8ae3-4d4e-8ddc-0b08ff36d330'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('d4ce1e0e-4473-4772-be41-87140d4bd0c4'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('d60188ef-49ce-4000-bc62-1a4aeb66f4a4'::uuid,'c98add51-8636-4f01-b290-9e849a7fc935'::uuid), ('d84c5145-81e4-48ce-9483-c2ce176394eb'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('db4215a6-bf1a-45e6-8a48-96a484fda32c'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('dc2886f9-5057-4e7e-b9c0-8b2defebf3cd'::uuid,'26bb007d-0d6e-4b15-b9a8-e2baf83573d1'::uuid), ('de8f96f9-a681-4514-97b8-ef46df0e1ace'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('e0ce5031-c769-4f2b-b0d5-553cef9ad3a8'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('e0fa3ee0-827d-47d9-8b33-6a595900305b'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('e136d25d-59be-4344-a21f-9632e8c6e133'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('e18c4b9c-0724-49bb-a5bb-153c551fe07f'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('e1fad8e6-d5ac-45d8-a64f-fd67b19ec0d7'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('e2815c15-3e35-41a9-b84c-ce8757814a26'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('e335f930-9019-4471-a973-da048ffc1da5'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('e546af29-d7c6-4f41-814e-d5a596bcbf2e'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('e59b4883-0e17-4d51-a6a7-fdb56b8882d6'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('e5c082ea-a378-4804-b0f4-15a07df03528'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('e62e0e3d-f26c-4fd5-bd51-99b86a43b111'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('e65f3cca-63a8-4dee-98fd-893a0ed49c52'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('e8da6944-6255-4b14-a896-d3c191bb33c3'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('e941610d-6633-4a76-bc27-572578c77fd5'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('ea4830e9-4b2f-41d9-84aa-88498198424e'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('ea80a924-7627-4ec1-b839-8ffdf83e0ba3'::uuid,'b016e6de-988b-4cd7-be13-d1568d81e5c7'::uuid), ('eb010e9d-4b8c-4770-9b4b-d343075a4e86'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('eb2062fa-1b0d-4198-91f3-8f3a917c99cb'::uuid,'00ec2abf-346e-4e3a-9895-73c55b40b07d'::uuid), ('eb81a622-9a34-4bdf-83bb-3cd735352db3'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('ebf14054-4cac-44a5-9d5a-496dd576764e'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('ed18ba6d-c484-4a7d-ba0f-5eba908dffef'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('ed320f72-8cb8-4388-9b92-e4627aef233c'::uuid,'629bd004-c3f1-4139-a051-17dcd15f9de1'::uuid), ('ee72d9fc-7308-440a-8334-888d1fd950de'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('ef1cc583-f0a7-444a-9348-cbd9fb2697b6'::uuid,'e09b4694-8de8-4387-89f4-3313c37e81d4'::uuid), ('f176f4b8-f860-4d47-964b-909638f38a38'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('f2d2aba9-645f-473f-8457-fa6899e35741'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('f35dc606-0a3a-4644-b6ab-57153908aef4'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid), ('f36b8680-ce7b-4924-b346-a6fd212496b7'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('f4207d90-3409-4a1e-af6a-3c5cf7510711'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('f4412a2c-3de3-4747-b312-731e66e17447'::uuid,'d93016a6-ba64-45b4-ac83-2756d5337729'::uuid), ('f6d3b50f-49ed-41e6-a995-fe58be2bea5c'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('f798aaa7-1e06-4c09-b369-9f7ca9f03acf'::uuid,'e37b928a-6fe3-455c-a033-dc081c3c37fa'::uuid), ('f8a08318-3d3d-4227-b34e-5a4e0205225e'::uuid,'1949f211-ed08-495b-9e75-c8a398a0e681'::uuid), ('f8e1b0df-19cf-49d5-be04-1fdd63509d8b'::uuid,'7ac68a0a-5139-43e1-8a58-b78d18382c1a'::uuid), ('f91e9fa8-c7ef-4834-b31e-db55bc9af740'::uuid,'d6bcda32-7d6d-4cde-a828-cc0deb3ad658'::uuid), ('f9240ec3-87f4-4661-b91f-5bf512f3c2c2'::uuid,'7b9fe4a3-3328-492b-b88e-0aa549cd76d0'::uuid), ('f99cf1e9-f440-489e-8ffc-e33855129a66'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('fb4231a2-f2e5-4be5-9785-47b1ae47a5af'::uuid,'af8c1675-905f-4548-979b-3409fc2b25a4'::uuid), ('fdee1f38-41b7-4d86-80f6-d49627efa8cf'::uuid,'335ff5aa-3be2-4c74-9301-6ed13b63f36c'::uuid)) e(atleta_id, grupo_id)
   where not exists (select 1 from public.atleta_grupos ag where ag.atleta_id = e.atleta_id and ag.grupo_id = e.grupo_id);
  if v <> 0 then msg := msg || format(' del listado fuera de su grupo=%s;', v); end if;

  if msg <> '' then
    raise exception '393 NO CUADRA:%', msg;
  end if;
  raise notice '393 OK · bajas 12 · verdes→activo 60 · nuevos 15 · grupos puestos 50 / quitados 51 · sin grupo→deducido 10 · direcciones 173';
end $$;

-- ── 8 · (Andrés, 15-oct) Los 5 que estaban en un grupo de 17:30 Y en Sub 14 de 18:30
--        se quedan SOLO en su grupo de 17:30: fuera Sub 14, y ese pasa a principal.
delete from public.atleta_grupos ag using public.grupos g
 where g.id = ag.grupo_id and g.seccion = 'escuela' and g.nombre ilike 'Sub 14%'
   and ag.atleta_id in ('617e10ba-bb9d-4dd0-9976-ccfb97afd801','363be8ae-9234-423f-9156-cd6ad4518e2b',
                        'a67db4ee-d26d-4527-a3a2-1f098d20f232','18596e0c-9454-4680-835f-e3f9a6f9f647',
                        '52a7eaab-33b1-43ac-80fc-340b8d74f347')
   and exists (select 1 from public.atleta_grupos o join public.grupos og on og.id = o.grupo_id
                where o.atleta_id = ag.atleta_id and og.seccion = 'escuela' and og.nombre not ilike 'Sub 14%');
update public.atleta_grupos ag set principal = true
 where ag.atleta_id in ('617e10ba-bb9d-4dd0-9976-ccfb97afd801','363be8ae-9234-423f-9156-cd6ad4518e2b',
                        'a67db4ee-d26d-4527-a3a2-1f098d20f232','18596e0c-9454-4680-835f-e3f9a6f9f647',
                        '52a7eaab-33b1-43ac-80fc-340b8d74f347')
   and not exists (select 1 from public.atleta_grupos o where o.atleta_id = ag.atleta_id and o.principal);
update public.atletas a set grupo_id = ag.grupo_id
  from public.atleta_grupos ag
 where ag.atleta_id = a.id and ag.principal
   and a.id in ('617e10ba-bb9d-4dd0-9976-ccfb97afd801','363be8ae-9234-423f-9156-cd6ad4518e2b',
                'a67db4ee-d26d-4527-a3a2-1f098d20f232','18596e0c-9454-4680-835f-e3f9a6f9f647',
                '52a7eaab-33b1-43ac-80fc-340b8d74f347');

commit;
