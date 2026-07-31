-- ============================================================================
-- 011_seed_contenido_actual.sql
--
-- Vuelca en public.contenido_secciones el contenido REAL que hoy aparece en
-- las paginas de seccion (texto de recambio dentro de cada index.html).
--
-- REGLA DE ORO: NO se pisa nada. Cada UPDATE solo rellena campos que estan
-- a NULL o vacios (coalesce(nullif(campo,''), 'valor')). Los INSERT solo se
-- ejecutan si la fila de esa `seccion` no existe todavia.
--
-- Es idempotente: se puede volver a lanzar sin efectos secundarios.
--
-- Codigos de seccion usados por cada pagina (leidos del .eq('seccion','X')):
--   running/                      -> running
--   natacion/                     -> natacion
--   triatlon/                     -> triatlon
--   montana/                      -> montana
--   competicion/                  -> competicion
--   cubo/                         -> cubo
--   escuela/                      -> escuela
--   escuela-natacion/             -> escuela-natacion
--   instalaciones/                -> instalaciones
--   campus/                       -> campus              (NO existia fila)
--   escuela-municipal-atletismo/  -> escuela-municipal   (NO existia fila)
--
-- Aviso: la fila existente 'mun-atletismo' NO la usa ninguna pagina; la
-- escuela municipal lee 'escuela-municipal'. Se deja intacta por si acaso.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- RUNNING  (running/index.html)
-- ---------------------------------------------------------------------------
update public.contenido_secciones set
  titulo      = coalesce(nullif(titulo,''),      $txt$Running$txt$),
  dirigido_a  = coalesce(nullif(dirigido_a,''),  $txt$Adultos · asfalto, cross y trail$txt$),
  descripcion = coalesce(nullif(descripcion,''), $txt$Dos grupos según el momento en el que estés: uno para coger el hábito y disfrutar del kilómetro, otro para buscar marca. En los dos hay entrenador en pista y plan escrito cada semana.$txt$),
  horarios    = coalesce(nullif(horarios,''),    $txt$Martes 19:30 series en pista · Jueves 19:00 rodaje suave (playa de San Juan) · Sábado 08:00 tirada larga (salida desde la Explanada)$txt$),
  precio      = coalesce(nullif(precio,''),      $txt$Cuota socio 120€/año · entrenamiento 40-60€/mes$txt$),
  grupos      = coalesce(nullif(grupos,''),      $txt$Madre Tierra · 40€/mes · 20-40 km/semana · 10K y media
La Tribu · 60€/mes · 40-80 km/semana · media y maratón$txt$),
  puntos_destacados = coalesce(nullif(puntos_destacados,''), $txt$Días: M · J · S
Punto de encuentro: pista / playa
Cuota socio: 120€/año
Entrenamiento: 40-60€/mes$txt$)
where seccion = 'running';

-- ---------------------------------------------------------------------------
-- NATACION  (natacion/index.html)
-- ---------------------------------------------------------------------------
update public.contenido_secciones set
  titulo      = coalesce(nullif(titulo,''),      $txt$Natación$txt$),
  dirigido_a  = coalesce(nullif(dirigido_a,''),  $txt$Adultos · todos los niveles$txt$),
  descripcion = coalesce(nullif(descripcion,''), $txt$Grupos por nivel y sesiones dirigidas en el Tossal y Vía Parque: técnica de los cuatro estilos, series de fondo, velocidad y preparación de competición. En verano, piscina de 50 metros y aguas abiertas los sábados.$txt$),
  precio      = coalesce(nullif(precio,''),      $txt$desde 35 €/mes socios$txt$),
  grupos      = coalesce(nullif(grupos,''),      $txt$Bono 4 clases al mes · 35 € socios · 50 € no socios
Bono 8 clases al mes · 45 € socios · 60 € no socios (el más elegido)
Bono 12 clases al mes · 55 € socios · 70 € no socios$txt$),
  puntos_destacados = coalesce(nullif(puntos_destacados,''), $txt$Bonos: 4, 8 o 12 clases al mes
Cuota: desde 35 €/mes socios
Piscinas: Tossal y Vía Parque
Responsable: Mario Clavero · 666 03 30 44$txt$)
where seccion = 'natacion';

-- ---------------------------------------------------------------------------
-- TRIATLON  (triatlon/index.html)
-- ---------------------------------------------------------------------------
update public.contenido_secciones set
  titulo      = coalesce(nullif(titulo,''),      $txt$Triatlón$txt$),
  dirigido_a  = coalesce(nullif(dirigido_a,''),  $txt$Natación · ciclismo · carrera$txt$),
  descripcion = coalesce(nullif(descripcion,''), $txt$Dominar tres disciplinas y saber encadenarlas: nadar, montar y correr gestionando el esfuerzo para que las piernas respondan al bajar de la bici. La sección nació en 2011 con cinco socios y hoy pasa de cincuenta.$txt$),
  horarios    = coalesce(nullif(horarios,''),    $txt$Natación 13:00 – 14:00 (lunes a sábado, piscinas de la Vía Parque) · Carrera a pie 19:00 – 21:30 (lunes a sábado, Estadio Joaquín Villar) · Ciclismo 08:00 – 12:30 (sábados y domingos, salida desde el Estadio)$txt$),
  grupos      = coalesce(nullif(grupos,''),      $txt$Disciplina 1 · Natación · 13:00 – 14:00 · lunes a sábado, piscinas de la Vía Parque
Disciplina 2 · Carrera a pie · 19:00 – 21:30 · lunes a sábado, Estadio Joaquín Villar
Disciplina 3 · Ciclismo · 08:00 – 12:30 · sábados y domingos, salida desde el Estadio$txt$),
  puntos_destacados = coalesce(nullif(puntos_destacados,''), $txt$Para quién: desde 14 años
Dónde: Vía Parque y Estadio
Federación: FATRI
Dirección: José Fernández$txt$)
where seccion = 'triatlon';

-- ---------------------------------------------------------------------------
-- MONTANA  (montana/index.html)
-- ---------------------------------------------------------------------------
update public.contenido_secciones set
  titulo      = coalesce(nullif(titulo,''),      $txt$Montaña$txt$),
  dirigido_a  = coalesce(nullif(dirigido_a,''),  $txt$Senderismo y trail · todas las edades$txt$),
  descripcion = coalesce(nullif(descripcion,''), $txt$Rutas por la Serra de la Marina, el Maigmó, el Puig Campana y las sierras que rodean Alicante. No hay ritmo obligatorio ni competición: hay rutas para todos los niveles, desde paseos familiares hasta travesías exigentes.$txt$),
  horarios    = coalesce(nullif(horarios,''),    $txt$Salidas de fin de semana$txt$),
  precio      = coalesce(nullif(precio,''),      $txt$Incluida en la cuota de socio$txt$),
  puntos_destacados = coalesce(nullif(puntos_destacados,''), $txt$Para quién: todas las edades
Salidas: fin de semana
Cuota: incluida en la de socio
Dirección: Enrique Gallego$txt$)
where seccion = 'montana';

-- ---------------------------------------------------------------------------
-- COMPETICION  (competicion/index.html)
-- ---------------------------------------------------------------------------
update public.contenido_secciones set
  titulo      = coalesce(nullif(titulo,''),      $txt$Atletismo en pista$txt$),
  dirigido_a  = coalesce(nullif(dirigido_a,''),  $txt$Federado y popular · temporada 2026-27$txt$),
  descripcion = coalesce(nullif(descripcion,''), $txt$El corazón del club: velocidad, vallas, medio fondo, fondo, saltos y lanzamientos, cada disciplina con su técnica y su forma de sufrir. Hay quien viene a bajar su 400 y quien busca el Campeonato de España; en los dos casos hay planificación individual detrás.$txt$),
  precio      = coalesce(nullif(precio,''),      $txt$desde 40 €/mes + socio$txt$),
  grupos      = coalesce(nullif(grupos,''),      $txt$Velocidad A · 55 €/mes socios · 5 entrenamientos por semana · acceso restringido, por decisión del club
Velocidad B · 40 €/mes socios · 3 entrenamientos por semana
Fondo y medio fondo · 40 – 55 €/mes según días · 3 a 5 entrenamientos por semana
Grupo recreativo · 40 €/mes socios · 3 entrenamientos por semana$txt$),
  puntos_destacados = coalesce(nullif(puntos_destacados,''), $txt$Para quién: federados y populares
Grupos: 4 según nivel
Cuota: desde 40 €/mes + socio
Prueba: 4 entrenamientos
Responsable: Andrés Clavero · 681 968 563$txt$)
where seccion = 'competicion';

-- ---------------------------------------------------------------------------
-- EL CUBO  (cubo/index.html)
-- ---------------------------------------------------------------------------
update public.contenido_secciones set
  titulo      = coalesce(nullif(titulo,''),      $txt$El Cubo$txt$),
  dirigido_a  = coalesce(nullif(dirigido_a,''),  $txt$Entrenamiento funcional$txt$),
  descripcion = coalesce(nullif(descripcion,''), $txt$El gimnasio del club, junto a la pista: fuerza, core y prevención en grupos de doce. Nadadores, corredores y triatletas comparten sala y cada uno lleva su progresión.$txt$),
  horarios    = coalesce(nullif(horarios,''),    $txt$LUN 18:00 Circuito funcional
LUN 20:00 Fuerza nadadores
MIÉ 20:00 Fuerza nadadores
JUE 19:00 Core y movilidad
VIE 18:00 Circuito funcional$txt$),
  precio      = coalesce(nullif(precio,''),      $txt$Desde 30 €/mes$txt$),
  grupos      = coalesce(nullif(grupos,''),      $txt$01 · Padres y madres · entrena mientras tu hijo está en la escuela · 40 €/mes (30 €/mes si tu hijo o hija está en la escuela)
02 · Socios del club · horario de mañana asignado · consultar disponibilidad
03 · Atletas de la escuela · fuerza dentro del entrenamiento · incluido en la cuota
04 · Alquiler a grupos · entidades y grupos externos · precio a consultar$txt$),
  puntos_destacados = coalesce(nullif(puntos_destacados,''), $txt$Plazas: 12 por clase
Duración: 55 minutos
Reserva: desde la app
Dónde: Pista Joaquín Villar$txt$)
where seccion = 'cubo';

-- ---------------------------------------------------------------------------
-- ESCUELA DE ATLETISMO  (escuela/index.html)
-- ---------------------------------------------------------------------------
update public.contenido_secciones set
  titulo      = coalesce(nullif(titulo,''),      $txt$Escuela de atletismo$txt$),
  dirigido_a  = coalesce(nullif(dirigido_a,''),  $txt$Escuela · temporada 2026-27$txt$),
  descripcion = coalesce(nullif(descripcion,''), $txt$Iniciación y desarrollo del atletismo de los 3 a los 17 años. Correr, saltar y lanzar en forma de juego en las categorías pequeñas, y especialización cuando toca.$txt$),
  horarios    = coalesce(nullif(horarios,''),    $txt$Grupo 1 (2 días/semana): 17:30 – 18:30 h · lunes y miércoles ó martes y jueves
Grupo 2 (3 días/semana): 18:30 – 20:00 h · viernes 17:30 – 19:00 · L, X y V ó M, J y V$txt$),
  precio      = coalesce(nullif(precio,''),      $txt$desde 300 € la temporada, en 2 pagos$txt$),
  grupos      = coalesce(nullif(grupos,''),      $txt$Grupo 1 · 2 días por semana · nacidos 2023 – 2015 · 17:30 – 18:30 h · lunes y miércoles ó martes y jueves
Grupo 2 · 3 días por semana · nacidos 2014 – 2009 · 18:30 – 20:00 h (viernes 17:30 – 19:00) · L, X y V ó M, J y V$txt$),
  puntos_destacados = coalesce(nullif(puntos_destacados,''), $txt$Edad: 3 a 17 años
Horario: 2 o 3 días/semana
Temporada: desde 300 € en 2 pagos
Prueba: 2 semanas gratis
Contacto: 636 06 17 00$txt$)
where seccion = 'escuela';

-- ---------------------------------------------------------------------------
-- ESCUELA DE NATACION  (escuela-natacion/index.html)
-- ---------------------------------------------------------------------------
update public.contenido_secciones set
  titulo      = coalesce(nullif(titulo,''),      $txt$Escuela de natación$txt$),
  dirigido_a  = coalesce(nullif(dirigido_a,''),  $txt$Escuela · 6 a 15 años$txt$),
  descripcion = coalesce(nullif(descripcion,''), $txt$Aprendizaje y perfeccionamiento en las piscinas del Tossal y Vía Parque, con grupos reducidos y la opción de competir en federado si al niño le apetece.$txt$),
  horarios    = coalesce(nullif(horarios,''),    $txt$Junio – septiembre · Piscina Tossal (25 m): 6 – 9 años L, M y J 17:30 · 10 – 15 años L, M y J 18:30
Octubre – mayo · Piscina Vía Parque: 6 – 9 años L, J y V 17:30 · 10 – 15 años L, J y V 18:30$txt$),
  precio      = coalesce(nullif(precio,''),      $txt$desde 35 €/mes$txt$),
  grupos      = coalesce(nullif(grupos,''),      $txt$6 – 9 años
10 – 15 años$txt$),
  puntos_destacados = coalesce(nullif(puntos_destacados,''), $txt$Edad: 6 a 15 años
Cuota: desde 35 €/mes
Piscinas: Tossal y Vía Parque
Responsable: Mario Clavero · 666 03 30 44$txt$)
where seccion = 'escuela-natacion';

-- ---------------------------------------------------------------------------
-- INSTALACIONES  (instalaciones/index.html)
-- ---------------------------------------------------------------------------
update public.contenido_secciones set
  titulo      = coalesce(nullif(titulo,''),      $txt$Instalaciones$txt$),
  dirigido_a  = coalesce(nullif(dirigido_a,''),  $txt$Dónde entrenamos$txt$),
  descripcion = coalesce(nullif(descripcion,''), $txt$Cuatro sedes repartidas por la ciudad. Todas son municipales salvo El Cubo, que es del club y está dentro del estadio.$txt$),
  grupos      = coalesce(nullif(grupos,''),      $txt$Estadio Joaquín Villar · escuela, pista, running y triatlón
El Cubo · padres, socios, escuela y alquiler
Piscina Monte Tossal · escuela de natación y natación adultos
Piscina Vía Parque$txt$),
  puntos_destacados = coalesce(nullif(puntos_destacados,''), $txt$Estadio Joaquín Villar: pista de tartán, foso de saltos y jaula de lanzamientos
El Cubo: container de entrenamiento funcional junto a la pista, del club
Piscina Monte Tossal: vaso de 25 m y de 50 m en temporada
Piscina Vía Parque$txt$)
where seccion = 'instalaciones';

-- ---------------------------------------------------------------------------
-- CAMPUS DE VERANO  (campus/index.html) -> seccion 'campus'  [FILA NUEVA]
-- ---------------------------------------------------------------------------
insert into public.contenido_secciones (seccion, titulo, dirigido_a, horarios, precio, grupos, descripcion, puntos_destacados)
select
  'campus',
  $txt$XII Campus de verano$txt$,
  $txt$Del 29 de junio al 31 de julio · 3 a 16 años$txt$,
  $txt$9:00 – 14:00 · entrada desde las 8:30 y recogida hasta las 14:20 sin coste añadido$txt$,
  $txt$Desde 189 € · 2 semanas · 15 % de descuento para el segundo hermano (no aplica al comedor)$txt$,
  $txt$Los grupos se organizan por edad, de 3 a 16 años$txt$,
  $txt$Atletismo, multideporte, pádel, natación, juegos de agua, gymkanas, talleres y una excursión cada semana. Todo con enfoque lúdico: el objetivo es que hagan deporte pasándolo bien.$txt$,
  $txt$Edades: 3 a 16 años
Fechas: 29 jun – 31 jul
Horario: 9:00 – 14:00
Entrada y recogida: 8:30 – 14:20
Dónde: Ciudad Deportiva de Alicante
Desde: 189 € · 2 semanas$txt$
where not exists (select 1 from public.contenido_secciones where seccion = 'campus');

-- Por si la fila ya existia vacia: rellenar solo huecos.
update public.contenido_secciones set
  titulo      = coalesce(nullif(titulo,''),      $txt$XII Campus de verano$txt$),
  dirigido_a  = coalesce(nullif(dirigido_a,''),  $txt$Del 29 de junio al 31 de julio · 3 a 16 años$txt$),
  descripcion = coalesce(nullif(descripcion,''), $txt$Atletismo, multideporte, pádel, natación, juegos de agua, gymkanas, talleres y una excursión cada semana. Todo con enfoque lúdico: el objetivo es que hagan deporte pasándolo bien.$txt$),
  horarios    = coalesce(nullif(horarios,''),    $txt$9:00 – 14:00 · entrada desde las 8:30 y recogida hasta las 14:20 sin coste añadido$txt$),
  precio      = coalesce(nullif(precio,''),      $txt$Desde 189 € · 2 semanas$txt$),
  grupos      = coalesce(nullif(grupos,''),      $txt$Los grupos se organizan por edad, de 3 a 16 años$txt$),
  puntos_destacados = coalesce(nullif(puntos_destacados,''), $txt$Edades: 3 a 16 años
Fechas: 29 jun – 31 jul
Horario: 9:00 – 14:00
Entrada y recogida: 8:30 – 14:20
Dónde: Ciudad Deportiva de Alicante
Desde: 189 € · 2 semanas$txt$)
where seccion = 'campus';

-- ---------------------------------------------------------------------------
-- ATLETISMO MUNICIPAL  (escuela-municipal-atletismo/index.html)
-- -> seccion 'escuela-municipal'  [FILA NUEVA]
-- ---------------------------------------------------------------------------
insert into public.contenido_secciones (seccion, titulo, dirigido_a, horarios, precio, grupos, descripcion, puntos_destacados)
select
  'escuela-municipal',
  $txt$Atletismo municipal$txt$,
  $txt$Programa de Deportes Alicante$txt$,
  $txt$Grupo 1: 17:30 – 18:30 h · Grupo 2: 18:30 – 20:00 h · lunes y miércoles ó martes y jueves$txt$,
  $txt$70 € toda la actividad$txt$,
  $txt$Grupo 1 · 25 plazas · nacidos 2019 – 2014 · 17:30 – 18:30 h · lunes y miércoles ó martes y jueves
Grupo 2 · 25 plazas · nacidos 2013 – 2009 · 18:30 – 20:00 h · lunes y miércoles ó martes y jueves$txt$,
  $txt$Escuela deportiva municipal que gestiona el club dentro del programa del Ayuntamiento de Alicante. La inscripción y el precio los fija Deportes Alicante; los entrenadores y la metodología son los mismos de la escuela del club.$txt$,
  $txt$Nacidos: 2019 a 2009
Temporada: 1 oct – 28 may
Precio: 70 € toda la actividad
Contacto: 636 06 17 00$txt$
where not exists (select 1 from public.contenido_secciones where seccion = 'escuela-municipal');

-- Por si la fila ya existia vacia: rellenar solo huecos.
update public.contenido_secciones set
  titulo      = coalesce(nullif(titulo,''),      $txt$Atletismo municipal$txt$),
  dirigido_a  = coalesce(nullif(dirigido_a,''),  $txt$Programa de Deportes Alicante$txt$),
  descripcion = coalesce(nullif(descripcion,''), $txt$Escuela deportiva municipal que gestiona el club dentro del programa del Ayuntamiento de Alicante. La inscripción y el precio los fija Deportes Alicante; los entrenadores y la metodología son los mismos de la escuela del club.$txt$),
  horarios    = coalesce(nullif(horarios,''),    $txt$Grupo 1: 17:30 – 18:30 h · Grupo 2: 18:30 – 20:00 h · lunes y miércoles ó martes y jueves$txt$),
  precio      = coalesce(nullif(precio,''),      $txt$70 € toda la actividad$txt$),
  grupos      = coalesce(nullif(grupos,''),      $txt$Grupo 1 · 25 plazas · nacidos 2019 – 2014 · 17:30 – 18:30 h
Grupo 2 · 25 plazas · nacidos 2013 – 2009 · 18:30 – 20:00 h$txt$),
  puntos_destacados = coalesce(nullif(puntos_destacados,''), $txt$Nacidos: 2019 a 2009
Temporada: 1 oct – 28 may
Precio: 70 € toda la actividad
Contacto: 636 06 17 00$txt$)
where seccion = 'escuela-municipal';

commit;
