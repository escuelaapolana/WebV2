-- ============================================================
-- 151 · El libro de récords absolutos del club
-- ------------------------------------------------------------
-- Hasta hoy `records_club` solo tenía cuatro marcas Sub-18 metidas
-- a mano. Estas son las PLUSMARCAS ABSOLUTAS del club (la mejor
-- marca de la historia en cada prueba, hombres y mujeres), sacadas
-- de la ficha del club en mundoatletismo.es/club/apol-ana.
--
-- Van en dos categorías, «Masculino» y «Femenino», porque la página
-- /club/records/ agrupa por `categoria` (no hay columna de sexo) y
-- así salen las dos pestañas, igual que en la maqueta de la página.
-- Las cuatro filas Sub-18 que ya había NO se tocan: se quedan como
-- una tercera pestaña. Algunas se repiten a propósito (el 400 y el
-- 800 de Sergio son a la vez récord absoluto y récord Sub-18).
--
-- OJO AL REVISAR:
--   · Los nombres vienen de mundoatletismo EN MAYÚSCULAS y SIN
--     TILDES. Aquí se han pasado a may/min y se les han puesto las
--     tildes evidentes, pero conviene que el club los repase.
--   · Las marcas de campo van en metros con coma («1,78 m»), como
--     ya se escribían en la maqueta. Los tiempos, tal cual.
--   · Se guarda solo el AÑO (la tabla no tiene fecha); mundoatletismo
--     da el día completo si algún día hace falta afinar.
--   · Gabriel Ródenas aparece en el origen con dos grafías del
--     apellido («García del Dionisio» / «García de Dionisio»);
--     se ha unificado a «García de Dionisio». Verificar.
--
-- Additivo. Para deshacer:
--   DELETE FROM public.records_club WHERE categoria IN ('Masculino','Femenino');
-- ============================================================

begin;

insert into public.records_club (prueba, categoria, marca, atleta, anyo, orden) values
  -- ===== Masculino (absoluto) =====  prueba, cat, marca, atleta, anyo, orden
  ('60 m',                 'Masculino', '7.12',    'Israel Sala Díaz',                                2021,  1),
  ('100 m',                'Masculino', '10.99',   'Israel Sala Díaz',                                2021,  2),
  ('200 m',                'Masculino', '21.94',   'Ayoub Omairi',                                    2024,  3),
  ('400 m',                'Masculino', '48.14',   'Sergio Redondo del Río',                          2026,  4),
  ('800 m',                'Masculino', '1:49.82', 'Sergio Redondo del Río',                          2026,  5),
  ('1.500 m',              'Masculino', '3:51.32', 'Rubén Requena García',                            2019,  6),
  ('3.000 m',              'Masculino', '8:36.17', 'Nicolás Alejandro Tucci',                         2021,  7),
  ('5.000 m',              'Masculino', '13:54.38','Ossama Ifraj Akaoui',                             2018,  8),
  ('10.000 m',             'Masculino', '28:55.50','Miguel Ángel Barzola Estévez',                    2014,  9),
  ('60 m vallas',          'Masculino', '8.65',    'Rafael Gil de Bernabé Valero',                    2026, 10),
  ('100 m vallas (0,91)',  'Masculino', '16.53',   'Adrián Berenguer Marco',                          2024, 11),
  ('110 m vallas (1,067)', 'Masculino', '18.18',   'Rubén Yuste Navarro',                             2026, 12),
  ('400 m vallas (0,84)',  'Masculino', '54.67',   'Rafael Gil de Bernabé Valero',                    2026, 13),
  ('3.000 m obstáculos',   'Masculino', '9:34.73', 'Gonzalo López de Miguel',                         2021, 14),
  ('Altura',               'Masculino', '1,78 m',  'Ander Pastor Barragán',                           2026, 15),
  ('Pértiga',              'Masculino', '2,93 m',  'Víctor Manuel Guereni Pérez',                     2017, 16),
  ('Longitud',             'Masculino', '6,28 m',  'Israel Sala Díaz',                                2021, 17),
  ('Triple',               'Masculino', '12,72 m', 'Pablo Duró Fernández-Calvillo',                   2018, 18),
  ('Peso (5 kg)',          'Masculino', '10,09 m', 'Alberto Pastor Velasco',                          2016, 19),
  ('Disco (1 kg)',         'Masculino', '42,95 m', 'Gabriel Ródenas García de Dionisio',              2025, 20),
  ('Martillo (5 kg)',      'Masculino', '52,19 m', 'Gabriel Ródenas García de Dionisio',              2026, 21),
  ('Jabalina (800 g)',     'Masculino', '41,74 m', 'Damián Duró Fernández-Calvillo',                  2018, 22),
  ('3.000 m marcha',       'Masculino', '17:36.97','Unai Franco Coves',                               2026, 23),
  ('5.000 m marcha',       'Masculino', '28:00.52','Gonzalo López de Miguel',                         2015, 24),
  ('4x100 m',              'Masculino', '45.95',   'A. Tello · G. López · M. Nadal · H. Martínez',    2017, 25),
  ('4x400 m',              'Masculino', '3:31.63', 'A. Pastor · A. Berenguer · R. Gil · R. Yuste',    2026, 26),
  ('Milla en ruta',        'Masculino', '4:24.0',  'Rubén Requena García',                            2019, 27),
  ('5 km en ruta',         'Masculino', '13:33',   'Hamid Ben Daoud Ben Akki',                        2019, 28),
  ('10 km en ruta',        'Masculino', '28:06',   'Hamid Ben Daoud Ben Akki',                        2019, 29),
  ('15 km en ruta',        'Masculino', '44:16',   'Hassane Ahouchar',                                2015, 30),
  ('Medio maratón',        'Masculino', '1:02:41', 'Miguel Ángel Barzola Estévez',                    2022, 31),
  ('Maratón',              'Masculino', '2:08:14', 'Hamid Ben Daoud Ben Akki',                        2019, 32),
  ('100 km en ruta',       'Masculino', '8:45:57', 'Francisco José Pérez García',                     2013, 33),
  ('5 km marcha',          'Masculino', '28:22.0', 'Gonzalo López de Miguel',                         2015, 34),

  -- ===== Femenino (absoluto) =====
  ('60 m',                  'Femenino', '7.82',    'Zoe Valdés Eslava',                              2026, 101),
  ('100 m',                 'Femenino', '12.33',   'Zoe Valdés Eslava',                              2026, 102),
  ('200 m',                 'Femenino', '26.04',   'Miriam Cotillas Verdú',                          2016, 103),
  ('400 m',                 'Femenino', '57.11',   'Marlen Estévez Larauet',                         2014, 104),
  ('800 m',                 'Femenino', '2:33.30', 'Cristina Maciá Riquelme',                        2026, 105),
  ('1.500 m',               'Femenino', '5:13.92', 'Fátima Ezzahra El Khamlichi',                    2016, 106),
  ('3.000 m',               'Femenino', '12:03.90','Dolores Alves de Morini',                        2015, 107),
  ('5.000 m',               'Femenino', '21:25.97','Emilia López Abad',                              2021, 108),
  ('60 m vallas',           'Femenino', '10.07',   'Verónica García Albertos',                       2016, 109),
  ('100 m vallas (0,84)',   'Femenino', '16.38',   'Verónica García Albertos',                       2021, 110),
  ('400 m vallas (0,762)',  'Femenino', '1:09.63', 'Miriam García Server',                           2015, 111),
  ('3.000 m obstáculos',    'Femenino', '14:08.72','Cristina Maciá Riquelme',                        2026, 112),
  ('Altura',                'Femenino', '1,62 m',  'Giovanna Lanz Monllor',                          2026, 113),
  ('Pértiga',               'Femenino', '2,03 m',  'Ana Grau Albors',                                2017, 114),
  ('Longitud',              'Femenino', '5,46 m',  'Marlen Estévez Larauet',                         2014, 115),
  ('Triple',                'Femenino', '10,41 m', 'Marlen Estévez Larauet',                         2014, 116),
  ('Peso (4 kg)',           'Femenino', '8,00 m',  'Verónica García Albertos',                       2016, 117),
  ('Disco (1 kg)',          'Femenino', '29,57 m', 'Verónica García Albertos',                       2019, 118),
  ('Martillo (3 kg)',       'Femenino', '41,59 m', 'Raquel Meléndez García-Miguel',                  2015, 119),
  ('Jabalina (600 g)',      'Femenino', '38,83 m', 'Verónica García Albertos',                       2019, 120),
  ('5.000 m marcha (pista)','Femenino', '30:19.41','María Cano Ripoll',                              2019, 121),
  ('4x100 m',               'Femenino', '53.46',   'N. García de Dionisio · M. Jerez · C. Coves · V. García', 2021, 122),
  ('4x400 m',               'Femenino', '4:52.94', 'C. Valdivia · M. Molina · M. García · I. Ferriz',2015, 123),
  ('5 km en ruta',          'Femenino', '18:24',   'María Yolanda Gutiérrez Robles',                 2023, 124),
  ('10 km en ruta',         'Femenino', '37:57',   'María Yolanda Gutiérrez Robles',                 2023, 125),
  ('15 km en ruta',         'Femenino', '1:13:42', 'Nancy Garay Moulard',                            2023, 126),
  ('Medio maratón',         'Femenino', '1:38:46', 'María Elvira Cánovas Canales',                   2014, 127),
  ('Maratón',               'Femenino', '4:05:20', 'María del Mar Barbero David',                    2021, 128);

commit;
