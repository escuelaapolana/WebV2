-- ============================================================================
-- 398 · Escuela de atletismo · cuadre del 20-oct-2026 (martes/jueves, 1er turno)
-- ----------------------------------------------------------------------------
-- Fuente (Excel de Andrés, 20-oct-2026):
--   · «Listado turno M_J.xlsx»: grupos de martes/jueves 17:30 hechos por los
--     entrenadores. Es LA VERDAD de quién va a qué grupo de martes/jueves.
--   · «Inscripción … (respuestas).xlsx», pestaña BUENO ISA: VERDE = confirmado
--     (activo), ROJO = baja (no debe aparecer en ningún grupo), SIN COLOR = prueba.
--   · «Renovación … (respuestas).xlsx», pestaña BUENA ISA: renovado = activo.
--     (Solo sube «prueba → activo»; no reactiva bajas ni pasa a nadie a prueba.)
-- Además: los grupos «Azul 3» y «Azul 4» de martes/jueves pasan a llamarse
-- «Azul 3a» y «Azul 3b», como en el listado.
--
-- No se borra ninguna ficha ni sesión ni recibo. Solo se mueven filas de
-- atleta_grupos y se cambia atletas.estado. Idempotente.
-- Pendiente de Andrés (NO se toca aquí): José Emilio Pineda (sale en Rojo 3 y en
-- Azul 1), 6 niños que están en grupos M/J y no salen en el listado, los niños
-- del listado sin formulario ni ficha (¿municipales?) y Ariana Demchuk (Sub 14).
-- ============================================================================
begin;

-- 0 · Nombres de grupo como en el listado (solo los de martes/jueves)
update public.grupos set nombre = 'Azul 3a' where id = 'c98add51-8636-4f01-b290-9e849a7fc935' and nombre <> 'Azul 3a';
update public.grupos set nombre = 'Azul 3b' where id = 'ec084bfe-6906-4f06-8523-b708a7fc2efe' and nombre <> 'Azul 3b';

create temp table _m398_mj (atleta_id uuid primary key, grupo_id uuid not null, nombre text) on commit drop;
insert into _m398_mj values
  ('2e112789-cead-4771-a365-b216d989dab7', '85b804bd-b180-4881-b95b-857821e4f137', 'Pablo Garibaldi Sánchez'),
  ('68705002-ab90-41f5-add2-e8b37010a06c', '85b804bd-b180-4881-b95b-857821e4f137', 'Lucía Alexandra Rubido Granada'),
  ('520d5271-9c8c-4c59-aeb0-480db06b9905', '85b804bd-b180-4881-b95b-857821e4f137', 'Martín Muñoz Asensi'),
  ('7d1887b7-80ce-499b-a8ba-4512accecbc5', '85b804bd-b180-4881-b95b-857821e4f137', 'Mateo Collado Leal'),
  ('7f9d0c7a-d279-49b7-a02f-3fbb6ec93095', '85b804bd-b180-4881-b95b-857821e4f137', 'Daniel Botana Cruañes'),
  ('3595f42c-495a-4088-ad01-18ef0efa7d89', '85b804bd-b180-4881-b95b-857821e4f137', 'Yeray Escudero Nardin'),
  ('88d4b8bc-b4b0-4cfa-8ac0-f044ae9a1cd0', '85b804bd-b180-4881-b95b-857821e4f137', 'Lyan Escudero Nardin'),
  ('bd6f5819-d0a0-45a0-86f8-6ae22895b118', '85b804bd-b180-4881-b95b-857821e4f137', 'Alonso López Valero'),
  ('1762f5cb-2982-4f68-97d5-9dc8e784d692', '85b804bd-b180-4881-b95b-857821e4f137', 'Gael Toledo Moyano'),
  ('0d6f24a8-be22-47c9-88b8-a63e033cda19', '85b804bd-b180-4881-b95b-857821e4f137', 'Gabriel Andrés Plana'),
  ('57795602-9b95-4c83-8ee2-6a75ce0f8394', '85b804bd-b180-4881-b95b-857821e4f137', 'Sofía Aghyourli Yazidi'),
  ('56b99e62-d651-4cf9-af67-3a77446c41da', '85b804bd-b180-4881-b95b-857821e4f137', 'Bruno Ferrándiz Sánchez'),
  ('1f293b95-fab4-40f5-ae8b-f39d4ae6c360', '85b804bd-b180-4881-b95b-857821e4f137', 'Zoe Sirvent Fernandez'),
  ('f8e1b0df-19cf-49d5-be04-1fdd63509d8b', '85b804bd-b180-4881-b95b-857821e4f137', 'Mia Ortuño Muñoz'),
  ('39737606-8e20-49aa-b9e9-a1d5d7a8a0ec', '85b804bd-b180-4881-b95b-857821e4f137', 'Lara Mora García'),
  ('9e20d173-a4bf-43a2-b59e-62c1992d4349', '85b804bd-b180-4881-b95b-857821e4f137', 'Máximo Murillo Tarruella'),
  ('666fd110-3397-4e07-89e3-8cb0d984bcf8', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Mateo Garcia Navarro'),
  ('b9795132-06b9-4321-b78b-94828682c705', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Leo García Navarro'),
  ('759f0cfd-bacd-426c-bdc8-2f1d1a5d1599', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Andrea Azorín Arrarte'),
  ('c75ce74d-06ba-4671-9e8f-3cb44f6f8e00', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Alejandra Guerrero Alarcón'),
  ('7e8a82c9-1917-470b-8d39-c997076b8c85', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Sebastián Sirvent Fernandez'),
  ('296ad4b5-90d3-453b-81e2-44c2beefed8c', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Teo Alessandro Rubanez Lazaro'),
  ('eb2062fa-1b0d-4198-91f3-8f3a917c99cb', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Jorge Fernandez Lillo'),
  ('5e386d92-fcb2-41bc-a3d7-70d896fc7432', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Triana Iniesta Torrecillas'),
  ('9ab561ed-4d16-498a-92bb-1ff7bf924af8', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Leo Ruiz Anton'),
  ('296da506-86a3-4ba7-b727-83f88166a228', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Martina Romeu Garulo'),
  ('93970a87-0ffe-485e-8942-33c85ad15835', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Violeta Castaño Perez'),
  ('23c6a383-0927-4765-9b43-9922370f2ff8', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Adriana Ripoll Pol'),
  ('2f5f025d-2f0c-4b65-b859-bc3e9eb9ed17', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Liam Liébana Martínez'),
  ('0cd2c902-f6e9-4ce0-a2d1-8ce1c36c444a', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'Aurora López Martínez'),
  ('178e91a1-6d52-446f-8002-dacc9917cd83', '00ec2abf-346e-4e3a-9895-73c55b40b07d', 'India Sol de la Torre'),
  ('850c95a9-a1bc-4e05-a22a-b2099166e558', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Elena Jordá Padrino'),
  ('89fa1848-3c29-4247-8fa8-29278f89ffcc', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Gonzalo Belmar Company'),
  ('a5f7a14e-d521-4a1f-9df3-739f7d0bf4aa', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Lucas Jimenez Medina'),
  ('783bcfea-b166-438c-8bf6-3036d56fdb83', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Leia Bailey Welle Donker'),
  ('c682306f-f6dc-47b8-8ef8-f54368c89b38', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Martín De Gea Almiñana'),
  ('18faaf52-599e-421a-a912-cd3aa805f4c6', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Sara Riera Agulló'),
  ('291076dc-aac0-4e21-b955-6c3ccbc33927', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Victoria Tendero Sanchez'),
  ('de8f96f9-a681-4514-97b8-ef46df0e1ace', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Iván David Rubido Granada'),
  ('3e46e906-e875-4aac-9955-adf8bb0cfd8c', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Miguel Mingot Zaragoza'),
  ('b7357b00-43dc-4a65-b959-24b8da071086', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Saúl Huesca Pérez'),
  ('ed320f72-8cb8-4388-9b92-e4627aef233c', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Alejandra Carrasco Kasiuk'),
  ('10555c59-530b-49bc-9c94-26b68b36741a', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Pablo Belmar Company'),
  ('294abc52-fdad-4889-a410-6bb3b6e5c46f', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Vera Villena Gonzalez'),
  ('a3fed751-145f-40ed-a558-c149d24277f1', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Josemaría Company Roquetto'),
  ('3deb0b2a-d808-4e9b-9df3-79761ed71c9e', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Valeria Gímenez Sánchez'),
  ('b06c1e7f-dbf0-48ee-b27c-7622abf059ac', '629bd004-c3f1-4139-a051-17dcd15f9de1', 'Eva Torres Dordik'),
  ('c69f0338-01a4-49b1-9ea8-f69b25198c2c', '74567283-d08e-4c41-8427-f64633ea9745', 'Alejandra Zenasni de Castro'),
  ('cd261ce0-00cd-442a-ac79-b3e7f1db8a1e', '74567283-d08e-4c41-8427-f64633ea9745', 'María Laura Company Roquetto'),
  ('482cab57-6408-4d70-9f8a-fc3f043a2bcd', '74567283-d08e-4c41-8427-f64633ea9745', 'Pilar Menchén Company'),
  ('ad87ab0b-1daf-40c5-a9ad-1f8e77ba5b06', '74567283-d08e-4c41-8427-f64633ea9745', 'Álvaro Bocchino Garcia'),
  ('333c6e30-236c-4ff6-9cb3-f33416578216', '74567283-d08e-4c41-8427-f64633ea9745', 'Luis Iniesta López'),
  ('7747de3f-f000-4b24-8398-8f30e4b79c2d', '74567283-d08e-4c41-8427-f64633ea9745', 'Martina Arques Garcia'),
  ('be9f7039-f03b-4378-afd1-37224e93035b', '74567283-d08e-4c41-8427-f64633ea9745', 'Lucas Arques Garcia'),
  ('8ecbee5f-eb35-43b4-8aaa-73d1782e7488', '74567283-d08e-4c41-8427-f64633ea9745', 'Blanca Escolano Arteaga'),
  ('700f74f4-7d54-4f2f-84ff-3211b37b8edd', '74567283-d08e-4c41-8427-f64633ea9745', 'Hugo Pastor Cecilia'),
  ('bfe6fef2-3502-4f89-b926-c208a109ef35', '74567283-d08e-4c41-8427-f64633ea9745', 'Darcy Hume Dougan'),
  ('53066138-6125-4678-985b-96f4d9384e61', '74567283-d08e-4c41-8427-f64633ea9745', 'Alejandro Belmar Company'),
  ('a30e7554-e73d-486a-bd3f-e609dccef771', '74567283-d08e-4c41-8427-f64633ea9745', 'Shaddaï-Maël Prat Amugu'),
  ('3589fc66-9f6c-469f-b2d5-02eb3e829949', '74567283-d08e-4c41-8427-f64633ea9745', 'Marcos Donet Romero'),
  ('94e67623-78a7-46cc-bae6-e5f2784f10a1', '74567283-d08e-4c41-8427-f64633ea9745', 'Miguel González Galiana'),
  ('8afef51f-c2b4-4d6c-afd3-48880f731a72', '74567283-d08e-4c41-8427-f64633ea9745', 'Lucia Iniesta Lopez'),
  ('3d088222-0904-4bad-a7e3-d076c6c547e9', '74567283-d08e-4c41-8427-f64633ea9745', 'Leticia Andrés Plana'),
  ('83764cba-f525-4b50-82f1-1d6c905beaab', '74567283-d08e-4c41-8427-f64633ea9745', 'Michael Segarra Arizaga'),
  ('82e749de-05df-4e84-9c5d-706ea73bc0bf', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Hernán Vaillo Ramos'),
  ('2ca836d9-622d-47dd-bec2-a76be1e625eb', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Martín López Valero'),
  ('c484f6a1-5964-4f40-8f98-d50eb7a7fa77', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Lena Coronado Nutz'),
  ('303bfcf8-40c2-4696-8059-e0762a0a0754', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Alma Navarro López'),
  ('9ce65c2e-5d04-4e17-9b55-d4cc3d208b08', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Lucía Domínguez Esplá'),
  ('72f4c1a0-2a6d-4a32-b530-9132ab0b5167', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Damián Morante Mula'),
  ('c8eac940-34c7-4c7d-9012-4e5fd530770f', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Pelayo Izquierdo Serrano'),
  ('b5a86d2b-be26-453e-8d16-7ddea80205c1', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Martín Roberto Borja'),
  ('b46c6b5c-f1d8-4fe0-abd4-c69a44f8ec1f', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Martín Garibaldi Sánchez'),
  ('b9b64da7-890e-4f52-b805-32a639523eae', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Hugo Soria Pastor'),
  ('9236c70a-7c62-41f1-8f34-8948715c76d3', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Pau Herrera Somolinos'),
  ('7568a472-9eb7-4136-9ebf-f62097d2ca3b', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Diego García Gomez'),
  ('36f87eb6-4de0-45e8-bc84-be4284248079', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Sandra Cacho Hernández'),
  ('3db34245-59e2-4663-a865-e2e21be5b1d5', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Joan Ballester Pacheco'),
  ('87640a4e-8dba-4d85-a78a-db9ac7d39e89', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Emma Soler Zapata'),
  ('05bb652d-974f-45dd-ac84-ad065dfcdac1', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Triana Montero Vazquez'),
  ('2c6f1077-b530-4863-b4b9-88ebff8fdf76', '0833f3d7-b760-416b-9677-0dcf07aba7db', 'Leon Almansa Papis'),
  ('462e6a95-cd57-4c5f-894d-fe2c28c027ba', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Daniel Asensi Botía'),
  ('d60188ef-49ce-4000-bc62-1a4aeb66f4a4', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Leo Góngora Verdú'),
  ('766d59e0-ea2e-4a4d-9533-3e508baf8be0', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Rubén Gallego Fernández'),
  ('631d6817-5940-4f58-bd7e-1bb51188637e', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Rodrigo Sanz Blasco'),
  ('3a3b7c8b-42a8-46fd-be50-db4d6551bc58', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Tiago Escudero Nardin'),
  ('0ad150c5-f266-413a-850d-fa4ee1c006bd', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Marta Belmar Company'),
  ('b126960e-1c36-4529-9a1b-5452fc5e9114', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Carlos Maximiliano Company Roquetto'),
  ('3882346f-51e2-4d24-af76-3e001f5b7ccd', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Leandro Mendoza Montilla'),
  ('bea43430-f63e-4d8d-ba40-a9918a04b970', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Rodrigo Muñoz Asensi'),
  ('3999310b-ef15-4e90-bd44-037f63b37425', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Dmytro Zubets'),
  ('677e0a06-5aed-4689-ac64-166ed49e3b0b', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Lucía González Izquierdo'),
  ('67209d80-e5c2-41cd-816a-4420ced517c6', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Adeline Demchuk Dragomir'),
  ('cd0c70ad-c6cd-424c-a2c7-68b5dd3240a2', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Sara Mayordomo Blasco'),
  ('37b6703e-e88b-49a5-b5fc-a86175abe3e2', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Altea Fructuoso Davó'),
  ('740f8909-b1fe-459f-aa6f-5903c5e598be', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Adrián Garcia de Dionisio Gathy'),
  ('64f52f77-bd8f-4627-bafc-1fe375cb5567', 'c98add51-8636-4f01-b290-9e849a7fc935', 'SILVIA Cacho Hernández'),
  ('4ef05014-2956-4d75-91a2-93345c4bf603', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Carlota Alzamora Fasanar'),
  ('24933ce0-436b-4fb6-b642-c04309b1495f', 'c98add51-8636-4f01-b290-9e849a7fc935', 'Anna Catarina Company Roquetto'),
  ('4a6e601f-48db-4857-8ee4-d2be4728c827', 'ec084bfe-6906-4f06-8523-b708a7fc2efe', 'Carlos Torreblanca Lopez'),
  ('700f35a0-137f-4366-9080-91c94068f769', 'ec084bfe-6906-4f06-8523-b708a7fc2efe', 'Juan Navarro Belmonte'),
  ('ce2ccbf9-8a96-4fc8-b788-f073af0f78db', 'ec084bfe-6906-4f06-8523-b708a7fc2efe', 'Youssef Nieto Morcillo'),
  ('b4f2d5d6-2098-4a9a-a5df-9051717a3c88', 'ec084bfe-6906-4f06-8523-b708a7fc2efe', 'Axel Mendo Fernández'),
  ('8bbadb65-d11f-48f0-89ea-23d363f99998', 'ec084bfe-6906-4f06-8523-b708a7fc2efe', 'Marta González Galiana'),
  ('2ad66e4d-3836-4f9b-a48d-a96760eb7f8a', 'ec084bfe-6906-4f06-8523-b708a7fc2efe', 'Lyam Madroñero Escalante'),
  ('0b3cb855-6f03-43a0-90fc-ce281305215b', 'ec084bfe-6906-4f06-8523-b708a7fc2efe', 'Lara Estévez Carbonell'),
  ('a5876033-a1f5-428b-9032-0dc7ac82b5c2', 'ec084bfe-6906-4f06-8523-b708a7fc2efe', 'Eiden Ibañez Senent'),
  ('c6c231e5-0a8e-4ad7-8a1d-4f73b95a8c6e', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Irene Marvá Blasco'),
  ('8887e2c6-0cb4-4999-bc01-dce89526a710', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Oliver Compaño Romero'),
  ('35078352-274b-43be-a20b-c5defb32011f', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Jordi Franco Coves'),
  ('34ee97c2-d9bf-481c-9e4a-998c9818e15f', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Amaris Iakubovska Jakubovskij'),
  ('2586e34d-f487-4140-ad86-679f53bd1813', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Lucía Olmos Sabater'),
  ('f91e9fa8-c7ef-4834-b31e-db55bc9af740', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Adrian Sanchez Fuentes'),
  ('71032663-7993-4c28-853c-7150a6a412ad', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Maia Costa Donate'),
  ('60982b88-107f-4c37-894b-3951d54bbf66', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Leonor Lladosa Pardo'),
  ('6e8409fc-0161-44e9-9959-f8e36533cc6d', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Giuliana Caselles Ortin'),
  ('d4aed12c-8ae3-4d4e-8ddc-0b08ff36d330', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Pablo Garcia Gomez'),
  ('a9cac494-0cf3-4f42-bf34-51bf19fdd45c', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Catalina Quetglas Barreto'),
  ('e8da6944-6255-4b14-a896-d3c191bb33c3', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Eva Romero Gumpert'),
  ('2c704f95-72c5-4dbe-954e-b6784d251523', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Ángel López Font'),
  ('74d99483-834d-4b85-8d18-4e13e28127c3', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Paula Collado Leal'),
  ('f2d2aba9-645f-473f-8457-fa6899e35741', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Manuela Alfonso González'),
  ('e0ce5031-c769-4f2b-b0d5-553cef9ad3a8', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Aaron Tucci Cordoba'),
  ('8ae064a2-37af-4386-8a0f-b27e041eba07', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Kael Tucci Cordoba'),
  ('424f7dff-05d5-4e3a-a909-b9c93693d5cf', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Hugo González Pérez'),
  ('572aa9f4-09ce-4a42-a136-dcf067cfeb47', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658', 'Mario Gabaldón Fernández'),
  ('242c8203-1f7c-4b32-9f1d-d956e15bf878', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Cesar Mayordomo Blasco'),
  ('e136d25d-59be-4344-a21f-9632e8c6e133', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Joan Hernández Civera'),
  ('651f278d-7eaa-427b-bb6b-43711b88adee', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Sara Daniela Rojas Marín'),
  ('3d715188-fba9-421e-b5ad-178a6ce0a810', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Vicente Castell Podea'),
  ('71f3df6e-f457-4f52-83ea-a56ba14c5647', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Ángela Jordá Padrino'),
  ('eb81a622-9a34-4bdf-83bb-3cd735352db3', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Lucas Díaz Garrido'),
  ('2c85e24c-294a-4eea-98f0-cb8d7044e2ea', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Valentino Alonso Torrealba'),
  ('d264c07e-bdde-460d-9535-fc5cac9c255e', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Kendric Thomson Gómez'),
  ('9552bfac-792c-49c6-aff4-5fd3e8d67118', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Marta Botella Aznar'),
  ('f798aaa7-1e06-4c09-b369-9f7ca9f03acf', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Abril Sanz Blasco'),
  ('20f39355-e487-494a-ab63-c16dce1a4c5b', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Laura Almansa Papis'),
  ('4ba3764e-4932-471a-9416-6536d88fa321', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Izan Llamas Sánchez'),
  ('751af95f-34ec-4744-86f2-8b5785d23dc1', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'María Ortigosa Lavilla'),
  ('7ba34d69-d081-4dce-9be5-9dbf80529769', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Marina Valdés Ruiz'),
  ('7a3f22a1-a7dd-4359-9797-7d359cd1239b', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Carlota De la Vega Clemente'),
  ('ae1c1366-fa69-4386-8e75-021810f62651', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Adriana Diez Ibáñez'),
  ('92e6dfbf-610f-4083-a7fb-dbb21853213d', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Susana Dopozo Toro'),
  ('debd2aa2-253f-4f6a-8f6f-016bd77fb1bc', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Loren Ariadna Aramburo Giraldo'),
  ('9e6b0dba-645d-4b62-9747-faf213d3a8e8', 'e37b928a-6fe3-455c-a033-dc081c3c37fa', 'Gael Josue Aramburo Giraldo'),
  ('336e4d1c-8f9e-4ecb-8772-b3d5b47386d7', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Alejandro Morales Pascual'),
  ('7cabe10c-5fbf-4576-80d5-284f3ca9dfa1', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Carlos Soler Alonso'),
  ('3ab8aca1-0582-4b9d-95da-c9ee8997afc2', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Julia Marvá Ruiz'),
  ('b5231cac-a1b8-42e4-a738-67de4b58adf2', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Lara Verdu Martinez'),
  ('3fff0c26-77fd-4680-902e-832ca93eb111', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Rebeca Quintana Villalaín'),
  ('b64173d1-90c6-4823-a7ff-47abf33e8e2b', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Paula Gallego Fernández'),
  ('f4412a2c-3de3-4747-b312-731e66e17447', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Carla Perez Bellido'),
  ('f4207d90-3409-4a1e-af6a-3c5cf7510711', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Noor Sofia Benchaib Benchaib'),
  ('8203b35f-34ee-424d-a0f9-a42b4bca9cee', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Juan Llinares Agulló'),
  ('02decd96-e873-4b73-9f6c-129034eb53ac', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Ainhoa Heredia Mera'),
  ('8273f1dd-62d8-48d6-8c5e-7f148f19f78f', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Alba Ramos Perez'),
  ('18596e0c-9454-4680-835f-e3f9a6f9f647', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Lucia Perez Cañaveras'),
  ('617e10ba-bb9d-4dd0-9976-ccfb97afd801', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'AZAHARA Vidal Faiz'),
  ('f36b8680-ce7b-4924-b346-a6fd212496b7', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Valeria Méndez Mira'),
  ('c53737aa-d63c-4939-93f2-5fc51b1f8b2c', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Nahiara Rojas Marín'),
  ('a3000b5e-1140-447e-988c-beb08ee48272', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Enzo Díaz Zamora'),
  ('363be8ae-9234-423f-9156-cd6ad4518e2b', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Hugo Díaz Zamora'),
  ('9d1f7257-32f5-4d16-8d38-e8f8cc40c825', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Carlo Mira Garcia'),
  ('b375cdc5-4203-423c-a8df-9f2ef00cec5b', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Gael Compaño Romero'),
  ('7e937446-171e-49e9-a5d3-21a316292f06', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Nora Téllez Maestre'),
  ('c42f4974-99b8-44a1-9fff-f2138171e505', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Sara Climent Ramos'),
  ('52a7eaab-33b1-43ac-80fc-340b8d74f347', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Óscar Llamas Sánchez'),
  ('654b8a5e-d47d-4e91-a0ac-96365504cdf6', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Ariana Demchuk Dragomir'),
  ('02bf9479-4635-4ad9-a174-af4f7f50f500', 'd93016a6-ba64-45b4-ac83-2756d5337729', 'Alexander Demchuk Dragomir');

create temp table _m398_bajas (atleta_id uuid primary key, nombre text) on commit drop;
insert into _m398_bajas values
  ('65669d70-ae40-46a5-8cfa-766299110363', 'Artem Pashchenko Pashchenko'),
  ('48880b7c-78b4-4d4a-b4eb-7a48fd136943', 'Inés García Martínez'),
  ('00c31460-1da9-4bc9-a9d4-b563862e73fe', 'Gabriela Plana Alarcón'),
  ('e335f930-9019-4471-a973-da048ffc1da5', 'Sheila Izquierdo Serrano'),
  ('fdee1f38-41b7-4d86-80f6-d49627efa8cf', 'Elke Rodriguez Messmer'),
  ('4e536ea1-609b-4c42-9063-da23c0e87423', 'Victoria Sofía Rodríguez Mata');

create temp table _m398_activos (atleta_id uuid primary key, nombre text) on commit drop;
insert into _m398_activos values
  ('2a700f70-92ea-4ccb-92c6-28410fa79fbb', 'JULEN Cabrero García'),
  ('c7be5ffe-2411-4c9e-b7e4-97f54135a6c7', 'Nike Undine Von Kupsch'),
  ('a4143fb1-f7f7-472b-8054-cde2d2528e35', 'Kalama Guillan Imas'),
  ('c8eac940-34c7-4c7d-9012-4e5fd530770f', 'Pelayo Izquierdo Serrano'),
  ('b06c1e7f-dbf0-48ee-b27c-7622abf059ac', 'Eva Torres Dordik'),
  ('e2b2b42c-242a-4ad9-8da2-b22064dfd22a', 'Maia Raimondetto Miralles'),
  ('c5edeaae-540a-4351-a480-aef18cd62b1a', 'Carmen Febrero Candela'),
  ('339fe887-d751-4f61-b9a8-9a5d920c7726', 'Sabrina Kirsten Nathalie Bourne Garcia'),
  ('1f293b95-fab4-40f5-ae8b-f39d4ae6c360', 'Zoe Sirvent Fernandez'),
  ('15576bdc-d762-4f52-91d8-fb14bced7ac4', 'MARCOS RAÚL JUAN MARTÍNEZ'),
  ('60982b88-107f-4c37-894b-3951d54bbf66', 'Leonor Lladosa Pardo'),
  ('7e8a82c9-1917-470b-8d39-c997076b8c85', 'Sebastián Sirvent Fernandez'),
  ('59461e23-687b-411f-9326-f4b13be1015e', 'Sofía Celeste Mandatori Mandatori'),
  ('178e91a1-6d52-446f-8002-dacc9917cd83', 'India Sol De la Torre'),
  ('69a33da7-3f2a-4817-b84d-86e652370230', 'Elizabeth Torrisi'),
  ('debd2aa2-253f-4f6a-8f6f-016bd77fb1bc', 'Loren Ariadna Aramburo Giraldo'),
  ('9e6b0dba-645d-4b62-9747-faf213d3a8e8', 'Gael josue Aramburo Giraldo'),
  ('8ecbee5f-eb35-43b4-8aaa-73d1782e7488', 'Blanca Escolano Arteaga'),
  ('90928299-61bc-4492-9d69-7b8e1ac740f2', 'Rym Yamina Bentria Bentria'),
  ('50ca1204-19c3-4f19-baf2-1c2a69c12256', 'Óliver Amboage Fernández'),
  ('045ddbf6-0b17-4d10-ac2e-56b950117832', 'Lucas Amboage Fernández'),
  ('9c0f5fa2-a4d8-4330-a674-a531085cc7ad', 'Leyre Varela García'),
  ('23c026aa-0e25-481f-8aff-9b4185d3795c', 'Fernando Gómez Pastor'),
  ('abbea049-fce1-48c5-aff5-155e264036dd', 'Lyra Cervera Savage'),
  ('7f9d0c7a-d279-49b7-a02f-3fbb6ec93095', 'Daniel Botana Cruañes'),
  ('96c94927-e559-4fe7-b413-ee864916e515', 'Victoria Sifre Berenguer'),
  ('9abe7ca5-e3e2-436b-81ff-b1c22c389549', 'Aleksandr Gubenkov Gubenkov'),
  ('36c824f8-fa1f-4554-8bc7-0e0c69b206de', 'SOFIA ALEJANDRA VALENCIA MORENO'),
  ('5336894b-3490-4cbc-aa17-5174c4352243', 'Emil Zhuravlev Zhuravlev'),
  ('e5c082ea-a378-4804-b0f4-15a07df03528', 'Yulen Moreno García'),
  ('61d61ab3-5d97-4737-bb4f-d050d615191c', 'Aimara Viveros Martín'),
  ('a6717954-b6d5-410a-818e-b48c1b1d110e', 'Candela Martinez Izquierdo'),
  ('c4fe81ae-a117-4e45-a9ce-81f0026354d2', 'Manuel Martinez Izquierdo'),
  ('02decd96-e873-4b73-9f6c-129034eb53ac', 'Ainhoa Heredia Mera'),
  ('c53737aa-d63c-4939-93f2-5fc51b1f8b2c', 'NAHIARA Rojas Marin'),
  ('651f278d-7eaa-427b-bb6b-43711b88adee', 'SARA DANIELA ROJAS MARIN'),
  ('f12f3e75-6136-4cf0-978d-825b4e8736ad', 'LOLA De la casa Gomez'),
  ('f35dc606-0a3a-4644-b6ab-57153908aef4', 'Inés Martín Sánchez'),
  ('c1ad7dc6-1315-4961-84d2-b62babaf7910', 'Ramón Bautista Palacios'),
  ('5073cfef-1ed9-4488-b0a4-ccd9e91ada6a', 'Erica Bulu Bulu Moya'),
  ('1762f5cb-2982-4f68-97d5-9dc8e784d692', 'Gael Toledo Moyano'),
  ('3a3b7c8b-42a8-46fd-be50-db4d6551bc58', 'Tiago Escudero Nardin'),
  ('3595f42c-495a-4088-ad01-18ef0efa7d89', 'Yeray Escudero Nardin'),
  ('88d4b8bc-b4b0-4cfa-8ac0-f044ae9a1cd0', 'Lyan Escudero Nardin'),
  ('3882346f-51e2-4d24-af76-3e001f5b7ccd', 'Leandro Mendoza Montilla'),
  ('5508a949-a789-4438-83da-fa31b4d96616', 'Amaya Ascensión Díaz Piatek'),
  ('680b8923-cd64-41bc-affb-1253d957f168', 'OLIVIA DÍAZ PIATEK'),
  ('57795602-9b95-4c83-8ee2-6a75ce0f8394', 'Sofia Aghyourli Yazidi'),
  ('55cfb904-adcf-4dd0-aac3-20ffe9dc0cf3', 'Maria Nieto román'),
  ('36f87eb6-4de0-45e8-bc84-be4284248079', 'Sandra Cacho Hernández'),
  ('8afef51f-c2b4-4d6c-afd3-48880f731a72', 'Lucia Iniesta Lopez'),
  ('3deb0b2a-d808-4e9b-9df3-79761ed71c9e', 'Valeria Giménez Sánchez'),
  ('ec24d571-4ab8-4318-bb66-198b2707cc02', 'José Emilio Pineda Carchipulla'),
  ('96193c12-4973-48d8-abba-cc6953687658', 'Aleksandar Markovic Lopez'),
  ('05bb652d-974f-45dd-ac84-ad065dfcdac1', 'Triana Montero Vazquez'),
  ('3cb0877c-7511-4b8c-ac3f-e84a31215a7f', 'Agnes Brantuas Batalla'),
  ('1b7415ab-c72e-44e8-ae51-5fcbe0bd6faa', 'Krzysztof Mizera Mizera'),
  ('827a8e52-cb70-4b94-9542-c4d3e7409f86', 'Éric González Orea'),
  ('a5e4a43f-aa23-4954-9339-da9ddc14afbe', 'Adriana Mayor Infante'),
  ('93970a87-0ffe-485e-8942-33c85ad15835', 'Violeta Castaño Perez');

-- Grupos de martes/jueves del 1er turno (17:30) de la escuela
create temp table _m398_gmj on commit drop as
  select id from public.grupos
   where seccion = 'escuela' and horario ilike 'Martes y jueves 17:30%';

-- 1 · BAJAS (rojo en BUENO ISA): estado baja + fuera de TODOS los grupos de la escuela
update public.atletas a
   set estado = 'baja', fecha_baja = coalesce(a.fecha_baja, now()),
       observaciones = concat_ws(E'\n', nullif(btrim(a.observaciones),''), 'Baja según BUENO ISA 20-oct-2026')
  from _m398_bajas b where a.id = b.atleta_id and a.estado is distinct from 'baja';
delete from public.atleta_grupos ag
 using _m398_bajas b, public.grupos g
 where ag.atleta_id = b.atleta_id and g.id = ag.grupo_id and g.seccion = 'escuela';

-- 2 · CONFIRMADOS (verde / renovado): prueba → activo
update public.atletas a set estado = 'activo'
  from _m398_activos x where a.id = x.atleta_id and a.estado = 'prueba';

-- 3 · GRUPOS DE MARTES/JUEVES = el listado
--     3a · fuera de los otros grupos M/J 17:30 en los que estuviera
delete from public.atleta_grupos ag
 using _m398_mj m
 where ag.atleta_id = m.atleta_id
   and ag.grupo_id in (select id from _m398_gmj)
   and ag.grupo_id <> m.grupo_id;
--     3b · dentro de su grupo (principal si no tiene otro principal)
insert into public.atleta_grupos (atleta_id, grupo_id, principal)
select m.atleta_id, m.grupo_id,
       not exists (select 1 from public.atleta_grupos x where x.atleta_id = m.atleta_id and x.principal)
  from _m398_mj m
 where not exists (select 1 from public.atleta_grupos x where x.atleta_id = m.atleta_id and x.grupo_id = m.grupo_id);
--     3c · Loren Ariadna Aramburo: del Verde 1 de lunes/miércoles al Verde 2 de martes/jueves (con su hermano)
delete from public.atleta_grupos
 where grupo_id = 'af8c1675-905f-4548-979b-3409fc2b25a4'
   and atleta_id in (select atleta_id from _m398_mj where nombre ilike 'Loren Ariadna%');
update public.atleta_grupos ag set principal = true
  from _m398_mj m
 where m.nombre ilike 'Loren Ariadna%' and ag.atleta_id = m.atleta_id and ag.grupo_id = m.grupo_id
   and not exists (select 1 from public.atleta_grupos x where x.atleta_id = m.atleta_id and x.principal);

-- 4 · NUEVOS con formulario (verde en BUENO ISA) y sin ficha
create temp table _m398_nuevos (
  fila int primary key, nombre text, apellidos text, fecha_nacimiento date, sexo text, dni text,
  nombre_tutor text, email_tutor text, telefono_tutor text, direccion text, observaciones text, grupo uuid) on commit drop;
insert into _m398_nuevos values
  (216, 'Catalina', 'Kurguzova Savka', '2017-03-15', 'mujer', 'Y5708560C', 'Khrystyna Savka', 'khrystynys@hotmail.com', '663462032',
     'Glorieta Tomás Ramírez 3, 03010, Alicante', 'Alta desde BUENO ISA (fila 216, verde) · cuadre 20-oct-2026', 'd6bcda32-7d6d-4cde-a828-cc0deb3ad658'),
  (217, 'Leo', 'Sempere Candela', '2023-04-20', 'hombre', '38187770L', 'Penelope Candela', 'penelopecandelalidon@gmail.com', '654506514',
     'Avenida maestro José Garberi Serrano, 03540, Alicante', 'Alta desde BUENO ISA (fila 217, verde) · cuadre 20-oct-2026', '85b804bd-b180-4881-b95b-857821e4f137'),
  (136, 'Martina', 'Lladosa Pardo', '2014-06-11', 'mujer', '04717877W', 'Rosa Pardo Crespo', 'pardo_ros@hotmail.com', '615552381',
     'Av. Cardenal Fco Álvarez, 2C, 03005, Alicante', 'Alta desde BUENO ISA (fila 136, verde) · cuadre 20-oct-2026 · Formulario: solo irá los VIERNES · grupo deducido por turno y año', 'ac820efa-d9ca-441e-bfef-56a0065d7bcd'),
  (218, 'Joan Marc', 'Rovira Bou', '2014-05-27', 'hombre', null, 'Joan Miquel Rovira Collado', 'rovijm@gmail.com', '687851863',
     'Calle Manuel Antón 6, 1ºA, 03003, Alacant', 'Alta desde BUENO ISA (fila 218, verde) · cuadre 20-oct-2026 · grupo deducido por turno y año', '9d3cf257-4d63-44fd-9647-edb23fb93d53');

insert into public.atletas (nombre, apellidos, fecha_nacimiento, sexo, dni, estado, tipo_membresia, secciones,
                            nombre_tutor, email_tutor, telefono_tutor, direccion, observaciones, origen)
select n.nombre, n.apellidos, n.fecha_nacimiento, n.sexo, n.dni, 'activo', 'escuela', array['escuela'],
       n.nombre_tutor, n.email_tutor, n.telefono_tutor, n.direccion, n.observaciones, 'cuadre-isa-2026-10-20'
  from _m398_nuevos n
 where not exists (select 1 from public.atletas a
                    where a.fecha_nacimiento = n.fecha_nacimiento
                      and lower(btrim(a.nombre)) = lower(n.nombre)
                      and lower(btrim(coalesce(a.apellidos,''))) = lower(n.apellidos));
insert into public.atleta_grupos (atleta_id, grupo_id, principal)
select a.id, n.grupo, true
  from _m398_nuevos n
  join public.atletas a on a.fecha_nacimiento = n.fecha_nacimiento and lower(btrim(a.nombre)) = lower(n.nombre)
                       and lower(btrim(coalesce(a.apellidos,''))) = lower(n.apellidos)
 where not exists (select 1 from public.atleta_grupos x where x.atleta_id = a.id and x.grupo_id = n.grupo);

-- 5 · Comprobación
do $$
declare v int;
begin
  select count(*) into v from _m398_mj m
   where not exists (select 1 from public.atleta_grupos x where x.atleta_id = m.atleta_id and x.grupo_id = m.grupo_id);
  if v > 0 then raise exception '398: % niños del listado sin su grupo', v; end if;
  select count(*) into v from _m398_bajas b join public.atleta_grupos ag on ag.atleta_id = b.atleta_id
    join public.grupos g on g.id = ag.grupo_id and g.seccion = 'escuela';
  if v > 0 then raise exception '398: % bajas siguen en un grupo de la escuela', v; end if;
  select count(*) into v from _m398_nuevos n where not exists (select 1 from public.atletas a
     where a.fecha_nacimiento = n.fecha_nacimiento and lower(btrim(a.nombre)) = lower(n.nombre));
  if v > 0 then raise exception '398: % nuevos sin ficha', v; end if;
end $$;

commit;
