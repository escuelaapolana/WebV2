-- 152 · Huecos de foto de la portada nueva («¿Qué hacemos?» + mosaico)
--
-- La portada nueva (index.html) trae huecos de foto editables en modo
-- fantasma y en Panel → Fotos de la web. Cada uno necesita su fila en
-- imagenes_web para poder cambiarlo desde el panel y para que salga en la
-- lista de «Fotos de la web». El `respaldo` es la foto que trae el HTML,
-- para que el panel enseñe «la de siempre».
--
-- Idempotente: si la fila ya existe, no se toca (así no se pisa un título
-- afinado ni una foto ya elegida).

insert into imagenes_web (clave, pagina, titulo, respaldo, orden) values
  ('home.publico.comp.running',     'Portada', 'Qué hacemos · Running',                'assets/img/club/running-equipo-media-maraton.jpg', 10),
  ('home.publico.comp.pista',       'Portada', 'Qué hacemos · Atletismo en pista',     'assets/img/club/pista-joven-en-los-tacos.jpg',      11),
  ('home.publico.comp.natacion',    'Portada', 'Qué hacemos · Natación',               'assets/img/club/natacion-crol-en-la-piscina.jpg',   12),
  ('home.publico.comp.montana',     'Portada', 'Qué hacemos · Montaña',                'assets/img/club/montana-subida-serra-grossa.jpg',   13),
  ('home.publico.comp.triatlon',    'Portada', 'Qué hacemos · Triatlón',               'assets/img/club/triatlon-podio-del-equipo.jpg',     14),
  ('home.publico.comp.fuerza',      'Portada', 'Qué hacemos · Fuerza',                 'assets/img/club/cubo-peso-muerto.jpg',              15),
  ('home.publico.esc.atletismo',    'Portada', 'Qué hacemos · Escuela de atletismo',   'assets/img/club/escuela-primeros-metros.jpg',       16),
  ('home.publico.esc.natacion',     'Portada', 'Qué hacemos · Escuela de natación',    'assets/img/escuela-natacion-hero.jpg',              17),
  ('home.publico.esc.municipales',  'Portada', 'Qué hacemos · Escuelas municipales',   'assets/img/ig-2.jpg',                               18),
  ('home.publico.esc.campus',       'Portada', 'Qué hacemos · Campus de verano',       'assets/img/campus-itaka.jpg',                       19),
  ('home.publico.mosaico.1',        'Portada', 'Mosaico · foto 1 (grande)',            'assets/img/club/pista-joven-en-los-tacos.jpg',      20),
  ('home.publico.mosaico.2',        'Portada', 'Mosaico · foto 2',                     'assets/img/club/running-equipo-media-maraton.jpg',  21),
  ('home.publico.mosaico.3',        'Portada', 'Mosaico · foto 3 (alta)',              'assets/img/club/escuela-primeros-metros.jpg',       22),
  ('home.publico.mosaico.4',        'Portada', 'Mosaico · foto 4',                     'assets/img/club/natacion-crol-en-la-piscina.jpg',   23),
  ('home.publico.mosaico.5',        'Portada', 'Mosaico · foto 5',                     'assets/img/club/montana-subida-serra-grossa.jpg',   24),
  ('home.publico.mosaico.6',        'Portada', 'Mosaico · foto 6',                     'assets/img/club/triatlon-podio-del-equipo.jpg',     25)
on conflict (clave) do nothing;
