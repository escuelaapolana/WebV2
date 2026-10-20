-- ============================================================================
-- 406 · Escuela de atletismo · lunes/miércoles 17:30 = «Listado turno L_X.xlsx»
-- (Andrés, 20-oct-2026: «para añadir a la escuela estos grupos»). Igual que la 398
-- con martes/jueves: el listado de los entrenadores manda sobre el grupo; las
-- bajas de BUENO ISA (Artem Pashchenko, Lucas Martínez Corella, Elke Rodríguez)
-- NO se meten aunque salgan en el listado. Quien está en un grupo L/X y no sale
-- en el listado sale de ese grupo (la ficha se queda). Tres nombres del Excel
-- casados a mano: «Luca Tor*** Mor***» = Luca Torres Moratalla, «Valentia
-- Alberola Puertas» = Valentina Alberola Puerta, «Ryam» = Rym Yamina Bentria.
-- Días: quien va a los dos turnos o solo algún día, en atletas.escuela_dias
-- (unión de los días que va): Sara Riera lunes+jueves, Adrián García de
-- Dionisio lunes+martes+miércoles, Gonzalo Aragüez solo lunes.
-- Avisos para el entrenador: Marc Sánchez Gonzalvo (TEA grado 1) y Kai Valle
-- (semanas alternas). Idempotente.
-- ============================================================================
begin;
create temp table _m406 (atleta_id uuid primary key, grupo_id uuid not null, nombre text) on commit drop;
insert into _m406 values
  ('7d8752cc-f740-4138-816a-69ded9992dbf', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Miguel Alonso García'),
  ('dc2886f9-5057-4e7e-b9c0-8b2defebf3cd', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Javier López Bonmatí'),
  ('108f1c46-ffc0-4798-bc8c-be2f9e5ed1e7', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Patricia Alfonzo Boller'),
  ('401a6f5a-f468-4c29-ad74-cf870ec665b4', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Bruno Fenoll García'),
  ('57ce7226-910c-47fd-afab-16a8e49b77a4', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Luca Tor*** Mor***'),
  ('3be5133f-d918-4da6-b789-c60b95956433', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'María Laura Sánchez Gálvez'),
  ('0e14494d-2fbf-47c3-ab02-0639771bc75c', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Lola Morante Mula'),
  ('6f9f5913-05e0-46ba-a4b5-594a2a8994d6', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Lucas Rocamora Tovar'),
  ('2a700f70-92ea-4ccb-92c6-28410fa79fbb', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Julen Cabrero García'),
  ('72d23b31-4016-4dd0-9926-4954cc84b973', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Jorge Mínguez Rodriguez'),
  ('9409f07d-7708-4aba-b74f-83fa67ee4454', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Míriam Ras García'),
  ('680b8923-cd64-41bc-affb-1253d957f168', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Olivia Díaz Piatek'),
  ('c4fe81ae-a117-4e45-a9ce-81f0026354d2', '26bb007d-0d6e-4b15-b9a8-e2baf83573d1', 'Manuel Martinez Izquierdo'),
  ('9ce93e3b-3b3a-4081-bcfd-023e7ee318a6', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Marc Lanz Torres'),
  ('8a76794e-2d51-43cb-b2f5-6866f62b10dc', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Samuela Bangura Kawa'),
  ('e941610d-6633-4a76-bc27-572578c77fd5', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Hèctor Arrabal Jiménez'),
  ('0dfe172d-2865-4df2-8fb7-e6a8df280a32', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Lucía Bellido García'),
  ('41599f11-eac5-4436-b8e5-b2633faa1fb4', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Julen Larrosa López'),
  ('ea4830e9-4b2f-41d9-84aa-88498198424e', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Marc Herreros Ramirez'),
  ('5e0c0e4e-0712-4f0a-85d5-b63db83a2da0', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Alba Cano Santos'),
  ('f6d3b50f-49ed-41e6-a995-fe58be2bea5c', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Manuela Vandroux Paterna'),
  ('0164aa42-1982-4572-a984-cbf857b73b30', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Hugo Martin Muñoz'),
  ('ebf14054-4cac-44a5-9d5a-496dd576764e', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Markus Cid Diop'),
  ('7025fbae-ce21-4924-87f0-4cb17d28c8ba', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Neline Dali Dali'),
  ('23c026aa-0e25-481f-8aff-9b4185d3795c', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Fernando Gómez Pastor'),
  ('f9240ec3-87f4-4661-b91f-5bf512f3c2c2', '7b9fe4a3-3328-492b-b88e-0aa549cd76d0', 'Antonio Ángel Guarido Roselló'),
  ('b80b8a70-7735-4d99-b7c7-70d85ec07ddf', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Marc Álvarez López'),
  ('835b5cd9-59df-4ea1-9297-8d25fe560579', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Inés Sánchez Ramos'),
  ('db4215a6-bf1a-45e6-8a48-96a484fda32c', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Jimena Castro Pedraza'),
  ('ee72d9fc-7308-440a-8334-888d1fd950de', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Jesús Gil González'),
  ('ef1cc583-f0a7-444a-9348-cbd9fb2697b6', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Germán Gómez Cantó'),
  ('e18c4b9c-0724-49bb-a5bb-153c551fe07f', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Rafael Castillo Lloréns'),
  ('307c4ce0-b2b2-400c-bce9-cab0a2a8b3e1', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Martín De la Fuente Paco'),
  ('d84c5145-81e4-48ce-9483-c2ce176394eb', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Adrián Beya Pérez'),
  ('8f1f9dae-49ae-4e11-aa0f-01e9202cca64', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Adrián Martínez Corella'),
  ('825da28c-4977-4233-b61a-f2694aba9162', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Hugo Espinosa Saiz'),
  ('a1d6f8a7-d54e-4599-925f-6958d4d9c8cd', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Manuel Pérez Jover'),
  ('abbea049-fce1-48c5-aff5-155e264036dd', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Lyra Cervera Savage'),
  ('77dd6782-1c7e-4259-8d82-2d198cd6e5a8', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Marcus Cariño Coloma'),
  ('22818289-ef68-4162-aea5-3363a063619d', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Blanca Olivares Muñoz'),
  ('5336894b-3490-4cbc-aa17-5174c4352243', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Emil Zhuravlev Zhuravlev'),
  ('9b47c303-ed88-45f4-8db4-13a470ca34cd', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Adriana Alba Quílez'),
  ('6fd06a98-97dc-444f-afac-6af71c7e7c96', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Valentina Campos Uribe'),
  ('e2815c15-3e35-41a9-b84c-ce8757814a26', 'e09b4694-8de8-4387-89f4-3313c37e81d4', 'Valentia Alberola Puertas'),
  ('4fa17c3c-2e49-4836-92cf-5f4e4c93d3bc', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Alan Juan Sanz'),
  ('18faaf52-599e-421a-a912-cd3aa805f4c6', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Sara Riera Agulló'),
  ('8e2a21c3-29c1-4eb4-9c10-657f67ff756f', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Marc Varona Alguacil'),
  ('e59b4883-0e17-4d51-a6a7-fdb56b8882d6', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Mateo Gil Sáez'),
  ('7d0985c0-8d7a-442e-83ff-67da3b72cce2', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Paula Castillo Martínez'),
  ('36a1e85c-86af-4ce0-ac0e-6919e129597e', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Raúl Fernández Pastor'),
  ('eb010e9d-4b8c-4770-9b4b-d343075a4e86', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Lucas Aray Cabrera Flores'),
  ('31556aad-8de7-4468-9827-2a07f675f4c2', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Hugo Toro Ibañez'),
  ('97e72e85-3d43-4027-8a54-b8873cd4bd56', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Malaika Beya Pérez'),
  ('e65f3cca-63a8-4dee-98fd-893a0ed49c52', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Treysa mbaye Cid Diop'),
  ('f8a08318-3d3d-4227-b34e-5a4e0205225e', '1949f211-ed08-495b-9e75-c8a398a0e681', 'June Garmendia Gonzalez'),
  ('48c7aa19-72f4-43b8-9873-ed737438740c', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Alma Pinales Zapata'),
  ('0961ad10-1f18-482c-8be8-986daf91f29b', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Emma Pinales Zapata'),
  ('e5c082ea-a378-4804-b0f4-15a07df03528', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Yulen Moreno García'),
  ('f176f4b8-f860-4d47-964b-909638f38a38', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Gabriel Ras García'),
  ('a4143fb1-f7f7-472b-8054-cde2d2528e35', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Kalama Guillan Imas'),
  ('9a7fdd9b-df0d-49ff-a33a-420d2d25f4ba', '1949f211-ed08-495b-9e75-c8a398a0e681', 'Adrián Cano Santos'),
  ('c8f3ed9a-5b4d-4e24-adc6-e19579e2cd3e', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Gonzalo Aragüez Rodríguez'),
  ('1bcd0b85-8a1a-4fa0-8db8-4994de496fb4', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Juan Andrés Quetglas Barreto'),
  ('6ddc91f0-85e2-4d35-bb1c-da8cc3bf0cb5', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Vera Fenoll García'),
  ('683c7588-9560-4f34-adf8-bd248058fef5', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Leo Suarez Rua'),
  ('c78ec71b-426f-46a0-b17d-c5adfd3d21ed', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Mateo Rodriguez Kopciara'),
  ('72f4c1a0-2a6d-4a32-b530-9132ab0b5167', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Damián Morante Mula'),
  ('342320e5-7b99-4679-876c-2613da31ffec', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Inés Segura Huedo'),
  ('32629d9c-8bab-41c4-b8ca-f496f2a814f4', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Sebastián Santana Rodríguez'),
  ('226306ff-4ce3-4f9f-8a2c-29c7323f7b6f', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Daiana ailyn Solórzano Peredo'),
  ('3148fe5a-6870-4a3a-abf0-0f5d1d08c37f', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Dario Miñán Barranco'),
  ('077b2c1e-4006-4956-82b5-1ebb86392f5a', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Esteban Montuenga Sola'),
  ('a6717954-b6d5-410a-818e-b48c1b1d110e', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Candela Martinez Izquierdo'),
  ('4f6d354d-90d1-4b10-8c81-75df3418add3', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Aksel Khelouat Kadi'),
  ('3e749130-0e9f-4fe7-ad4c-f064dece2174', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Sara Gilabert Gómez'),
  ('92164f42-8698-4265-a9c5-e6e21c2fa534', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Lucas Cerdan Mendez'),
  ('96dee032-ec48-4c07-acdf-9bcd27dfe6f1', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Eric Martín Roman'),
  ('5508a949-a789-4438-83da-fa31b4d96616', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Amaya Asunción Díaz Piatek'),
  ('2eac0dcc-cbb6-4034-971b-1804b422b625', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Matías Cataldo Piqueras'),
  ('96193c12-4973-48d8-abba-cc6953687658', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Aleksandar Markovic López'),
  ('841c4f66-831c-42e8-9e07-b40138866b23', '78fe7dac-6dd2-4e6a-ba3e-88563e028f5c', 'Noel Gomis Cuéllar'),
  ('e0fa3ee0-827d-47d9-8b33-6a595900305b', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Mark Gumberidze'),
  ('35981c60-36b4-4b9a-b770-156996dea2ce', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Ángela Alarcón Asunción'),
  ('0a813d7b-0440-4843-9688-03ff0611b371', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Jimena Frigola Saiz'),
  ('4ef05014-2956-4d75-91a2-93345c4bf603', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Carlota Alzamora Fasanar'),
  ('f35dc606-0a3a-4644-b6ab-57153908aef4', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Inés Martín Sánchez'),
  ('572aa9f4-09ce-4a42-a136-dcf067cfeb47', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Mario Gabaldón Fernández'),
  ('d281cd0a-bebc-4ea1-b4d6-3836beb32641', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Maia Rodríguez Ferrer'),
  ('d037a647-9072-4a4e-aef5-6a77050b8cba', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Rodrigo Segui Ferrandiz'),
  ('740f8909-b1fe-459f-aa6f-5903c5e598be', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Adrián Garcia de Dionisio Gathy'),
  ('82293a35-cef6-4a8d-ab06-17aeeca72827', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Noah Carrasco Ortega'),
  ('d4ce1e0e-4473-4772-be41-87140d4bd0c4', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Marc Sánchez Gonzalvo'),
  ('5d24eefe-0fd2-4194-a66d-f6ce96813329', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Valentina De la Fuente Paco'),
  ('15576bdc-d762-4f52-91d8-fb14bced7ac4', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Marcos Raúl Juan Martínez'),
  ('69b63ee7-244f-4d00-8b10-b8072f410a5c', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Sofia Rocamora Tovar'),
  ('50ca1204-19c3-4f19-baf2-1c2a69c12256', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Oliver Amboage Fernández'),
  ('7d41762e-d468-4316-a140-a266a90a5206', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Oliver Llopis Arnes'),
  ('b5539c35-98ea-4b4e-8d72-719fa83c07be', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Hugo Martinez Mataix'),
  ('94a7ab62-d8b8-4920-8538-f23ab3a51bdc', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Carmen Bailén Mula'),
  ('ccc93bba-0abb-4888-a75f-02c5465baa56', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Vega Reyero Gallego'),
  ('72858c72-6c01-4d7d-813b-009a2a53f8ae', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Samantha Paula Bazan'),
  ('c64a2a26-eaa5-482f-8858-5e72ca1f1f83', '335ff5aa-3be2-4c74-9301-6ed13b63f36c', 'Lucia Slon Escolano'),
  ('6241a3f6-783f-47a9-b1bf-19dcd6bcfa91', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Victoria Rodriguez Kopciara'),
  ('2acad017-9d3d-4537-8400-f8739b96a52a', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Jhoan Lucas Cuéllar Carrillo'),
  ('e1fad8e6-d5ac-45d8-a64f-fd67b19ec0d7', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Pablo Hurtado Fernandez'),
  ('20cfc16e-7324-4d51-aa97-456ad50bb013', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Paula María Rab Pruteanu'),
  ('ea80a924-7627-4ec1-b839-8ffdf83e0ba3', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Rodrigo Munera Valero'),
  ('06cf5a54-7b05-4d43-a39d-0033cd70b27f', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Azahara Navarro Bonete'),
  ('a0514e7a-beaa-4957-83b1-f6ec3c5ee61e', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Elida Makeyla Mardinera Grijalba'),
  ('b7372109-e08d-414a-986c-186c5080e662', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Sofía Vallés Ibáñez'),
  ('4cd14b9d-ef77-47ed-9eb3-da5ae6d5889d', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Keitlyn anahi Solórzano Salinas'),
  ('90928299-61bc-4492-9d69-7b8e1ac740f2', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Ryam Yamina Bentria Bentria'),
  ('61d61ab3-5d97-4737-bb4f-d050d615191c', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Aimara Viveros Martín'),
  ('54fe4e09-975f-4625-b4c4-70fe9d5dcd85', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Rodrigo Montuenga Sola'),
  ('a34033a8-f7ca-4d78-9161-e235bf472c0c', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Carmen Ruiz Cruz'),
  ('82ba8f0a-dbfe-4e1b-b57d-724941453335', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Walid Lahsinia Tahori'),
  ('89ad0280-fc03-4ff0-b62a-d85f47053af2', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Mia Di Pietro Sánchez'),
  ('1b7415ab-c72e-44e8-ae51-5fcbe0bd6faa', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Krzysztof Mizera Mizera'),
  ('cb04217a-c0f5-49fc-b29c-872684f6af00', 'b016e6de-988b-4cd7-be13-d1568d81e5c7', 'Ruth Medina Sánchez'),
  ('3015ab34-c6ac-434d-8019-603252a1d3d6', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Massimo Alessandro Troncone Burgler'),
  ('fb4231a2-f2e5-4be5-9785-47b1ae47a5af', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Unai Torres Martin'),
  ('bdcd4bb9-1372-47d1-89dd-4ed6da85bb32', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Yeray Bellido García'),
  ('8e121176-131d-40cf-be56-90c6b75a27f0', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Kai Valle Andreu'),
  ('a98b6c70-e03e-4354-bcef-490340c33c80', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Noa Jover Núñez'),
  ('045ddbf6-0b17-4d10-ac2e-56b950117832', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Lucas Amboage Fernández'),
  ('e62e0e3d-f26c-4fd5-bd51-99b86a43b111', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Martín Suarez Rua'),
  ('bf29a087-a64f-4f6a-8c33-bf2660247c14', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Leire Hurtado Fernandez'),
  ('c3ce358d-d76f-491a-a67d-6911df516688', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'María Martínez Ortega'),
  ('e546af29-d7c6-4f41-814e-d5a596bcbf2e', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Silvia Aracil Sevilla'),
  ('1aaf924b-9725-4217-963f-13bffa9b025e', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Daniel Galindo Mas'),
  ('9c0f5fa2-a4d8-4330-a674-a531085cc7ad', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Leyre Varela García'),
  ('aabb5472-43f8-4a2b-b7ae-8ecfad3846e8', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Alen García Martínez'),
  ('a67db4ee-d26d-4527-a3a2-1f098d20f232', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Joel Morales Lopez'),
  ('f99cf1e9-f440-489e-8ffc-e33855129a66', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Cayetana Arenas del Caño'),
  ('c4bc2638-d6fa-418b-b0d0-02bdcc02ff41', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Alejandra Bailén Mula'),
  ('b6e58fcf-e2e2-4d58-bacc-4befefea1440', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Martina Segura Garcia'),
  ('ed18ba6d-c484-4a7d-ba0f-5eba908dffef', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Joel Brantuas Batalla'),
  ('c2bbf8b6-ccba-448c-b98c-1f284278cd77', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Naiara Pardo Gonzalez'),
  ('9a81e54b-8353-4507-8eaf-fc2c0acfa9f1', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Sofía Martinez Mataix'),
  ('fd89e048-f051-488b-bc49-88f4ba802710', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Lucia Barrera Civera'),
  ('83faf04f-b566-4f0c-856e-9fd1143dffd3', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Mateo Henares Domenech'),
  ('59461e23-687b-411f-9326-f4b13be1015e', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Sofia Celeste Mandatori Mandatori'),
  ('55cfb904-adcf-4dd0-aac3-20ffe9dc0cf3', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'María Nieto Román'),
  ('4400050b-31be-4bf7-88a8-ba71276d7a41', 'af8c1675-905f-4548-979b-3409fc2b25a4', 'Abdelmalek Khelouat Kadi');

create temp table _m406_glx on commit drop as
  select id from public.grupos where seccion = 'escuela' and horario ilike 'Lunes y miércoles 17:30%';

-- fuera de los grupos L/X 17:30 quien no sale en el listado (o sale en otro)
delete from public.atleta_grupos ag
 where ag.grupo_id in (select id from _m406_glx)
   and not exists (select 1 from _m406 m where m.atleta_id = ag.atleta_id and m.grupo_id = ag.grupo_id);
-- dentro de su grupo
insert into public.atleta_grupos (atleta_id, grupo_id, principal)
select m.atleta_id, m.grupo_id,
       not exists (select 1 from public.atleta_grupos x where x.atleta_id = m.atleta_id and x.principal)
  from _m406 m
 where not exists (select 1 from public.atleta_grupos x where x.atleta_id = m.atleta_id and x.grupo_id = m.grupo_id);

-- días
update public.atletas set escuela_dias = '{1,4}'   where public._nombre_norm(nombre||' '||apellidos) = 'sara riera agullo';
update public.atletas set escuela_dias = '{1,2,3}' where public._nombre_norm(nombre||' '||apellidos) = 'adrian garcia de dionisio gathy';
update public.atletas set escuela_dias = '{1}'     where public._nombre_norm(nombre||' '||apellidos) = 'gonzalo araguez rodriguez';
-- avisos
update public.atletas set aviso_salud = 'Diagnóstico de TEA (grado 1). Autónomo, habla y se comunica sin problema. Dificultad en comprensión de conceptos abstractos'
 where nombre = 'Marc' and apellidos ilike 'Sánchez Gonzalvo' and aviso_salud is null;
update public.atletas set aviso_salud = 'Asistirá por semanas alternas (custodia compartida)'
 where nombre = 'Kai' and apellidos ilike 'Valle Andreu' and aviso_salud is null;

do $$
declare v int;
begin
  select count(*) into v from _m406 m where not exists (select 1 from public.atleta_grupos x where x.atleta_id = m.atleta_id and x.grupo_id = m.grupo_id);
  if v > 0 then raise exception '406: % niños del listado sin su grupo', v; end if;
end $$;
commit;
