-- ============================================================
-- 073 · LAS FOTOS DEL CLUB, EN LA BIBLIOTECA DEL PANEL
-- ------------------------------------------------------------
-- QUÉ RESUELVE
--   Hay 59 fotos nuevas preparadas dentro del repositorio, en
--   `assets/img/club/`. Como no están en el almacén de Supabase,
--   el club no las veía en la biblioteca del panel y no podía
--   asignarlas a ninguna página.
--
--   Aquí se dan de alta como fichas de la biblioteca, con su
--   sección y con las mejores marcadas como favoritas. La página
--   `admin/biblioteca/` ya sabe distinguir las rutas que empiezan
--   por `assets/` (se sirven del propio sitio) de las del almacén.
--
-- LO QUE NO CAMBIA
--   Las 28 fotos que ya estaban registradas siguen igual: sus
--   rutas empiezan por `biblioteca/` y se siguen sirviendo del
--   almacén «imagenes».
--
-- Idempotente: se puede pasar las veces que haga falta. Si una
-- foto ya está, se le refresca el título y la sección; no se
-- duplica (la columna `ruta` es única) y no se toca ninguna otra.
-- ============================================================

insert into public.biblioteca_fotos (ruta, nombre, titulo, categoria, favorita) values
  ('assets/img/club/pista-altura-sobre-el-liston.jpg', 'pista-altura-sobre-el-liston.jpg', 'Altura: arqueada sobre el listón', 'competicion', true),
  ('assets/img/club/pista-altura-en-el-pabellon.jpg', 'pista-altura-en-el-pabellon.jpg', 'Altura en el pabellón, a contraluz', 'competicion', false),
  ('assets/img/club/pista-altura-de-espaldas.jpg', 'pista-altura-de-espaldas.jpg', 'Altura: pasando el listón de espaldas', 'competicion', false),
  ('assets/img/club/pista-longitud-en-vuelo.jpg', 'pista-longitud-en-vuelo.jpg', 'Longitud en pleno vuelo, con los jueces', 'competicion', true),
  ('assets/img/club/pista-triple-salto.jpg', 'pista-triple-salto.jpg', 'Triple salto, zancada abierta en el aire', 'competicion', false),
  ('assets/img/club/pista-martillo-en-la-jaula.jpg', 'pista-martillo-en-la-jaula.jpg', 'Martillo: el giro dentro de la jaula', 'competicion', false),
  ('assets/img/club/pista-valla-en-vuelo.jpg', 'pista-valla-en-vuelo.jpg', 'Vallas: en pleno vuelo sobre la valla', 'competicion', true),
  ('assets/img/club/pista-valla-con-rival.jpg', 'pista-valla-con-rival.jpg', 'Vallas: paso de valla con el rival al lado', 'competicion', false),
  ('assets/img/club/pista-obstaculos-la-ria.jpg', 'pista-obstaculos-la-ria.jpg', 'Obstáculos: cinco atletas llegando a la ría', 'competicion', true),
  ('assets/img/club/pista-obstaculos-a-la-vez.jpg', 'pista-obstaculos-a-la-vez.jpg', 'Obstáculos: dos del club volando a la vez', 'competicion', false),
  ('assets/img/club/pista-obstaculos-brazos-abiertos.jpg', 'pista-obstaculos-brazos-abiertos.jpg', 'Obstáculos: brazos abiertos al caer', 'competicion', false),
  ('assets/img/club/pista-salida-en-el-peralte.jpg', 'pista-salida-en-el-peralte.jpg', 'Salida explosiva sobre el peralte naranja', 'competicion', true),
  ('assets/img/club/pista-llegada-en-valencia.jpg', 'pista-llegada-en-valencia.jpg', 'Llegada a tope sobre las letras de la pista', 'competicion', false),
  ('assets/img/club/pista-tres-de-frente.jpg', 'pista-tres-de-frente.jpg', 'Tres corredores de frente, camiseta del club', 'competicion', true),
  ('assets/img/club/pista-perfil-a-fondo.jpg', 'pista-perfil-a-fondo.jpg', 'Perfil en pleno esfuerzo, media pista libre', 'competicion', false),
  ('assets/img/club/pista-salida-de-tacos-denia.jpg', 'pista-salida-de-tacos-denia.jpg', 'Salida de tacos con el mural al fondo', 'competicion', false),
  ('assets/img/club/pista-zancada-sobre-el-cesped.jpg', 'pista-zancada-sobre-el-cesped.jpg', 'Zancada completa de perfil sobre el césped', 'competicion', false),
  ('assets/img/club/pista-dorsal-41.jpg', 'pista-dorsal-41.jpg', 'El dorsal 41 y el nombre del club, legibles', 'competicion', true),
  ('assets/img/club/pista-dorsal-60-en-carrera.jpg', 'pista-dorsal-60-en-carrera.jpg', 'La 60 en plena zancada dentro de la pista', 'competicion', false),
  ('assets/img/club/pista-corredora-de-perfil.jpg', 'pista-corredora-de-perfil.jpg', 'Corredora de perfil, gesto de esfuerzo', 'competicion', false),
  ('assets/img/club/pista-sonrisa-en-la-curva.jpg', 'pista-sonrisa-en-la-curva.jpg', 'Sonriendo en la curva, con el público detrás', 'competicion', false),
  ('assets/img/club/pista-tres-corredoras.jpg', 'pista-tres-corredoras.jpg', 'Tres corredoras a la par, la del club en cabeza', 'competicion', false),
  ('assets/img/club/pista-solo-en-la-curva.jpg', 'pista-solo-en-la-curva.jpg', 'Solo sobre la curva, cara de esfuerzo', 'competicion', false),
  ('assets/img/club/escuela-dos-en-la-recta.jpg', 'escuela-dos-en-la-recta.jpg', 'Dos peques corriendo la recta, cielo abierto', 'escuela', true),
  ('assets/img/club/escuela-cielo-azul.jpg', 'escuela-cielo-azul.jpg', 'La escuela corriendo con dorsal, cielo azul', 'escuela', false),
  ('assets/img/club/escuela-nino-en-vuelo.jpg', 'escuela-nino-en-vuelo.jpg', 'Zancada en el aire sobre la pista', 'escuela', true),
  ('assets/img/club/escuela-peloton-de-salida.jpg', 'escuela-peloton-de-salida.jpg', 'Salida en pelotón de una carrera de menores', 'escuela', false),
  ('assets/img/club/escuela-fila-de-chicas.jpg', 'escuela-fila-de-chicas.jpg', 'Fila de chicas arrancando en la carrera', 'escuela', false),
  ('assets/img/club/escuela-grupo-de-frente.jpg', 'escuela-grupo-de-frente.jpg', 'El grupo de peques corriendo de frente', 'escuela', false),
  ('assets/img/club/escuela-junto-a-la-carpa.jpg', 'escuela-junto-a-la-carpa.jpg', 'Entre los conos, con la carpa del club al fondo', 'escuela', false),
  ('assets/img/club/escuela-con-la-grada-llena.jpg', 'escuela-con-la-grada-llena.jpg', 'Esperando el turno con la grada llena', 'escuela', false),
  ('assets/img/club/escuela-podio-con-medalla.jpg', 'escuela-podio-con-medalla.jpg', 'Podio de la escuela: tres con la medalla puesta', 'escuela', false),
  ('assets/img/club/escuela-natacion-entrenadora.jpg', 'escuela-natacion-entrenadora.jpg', 'La entrenadora al borde de la piscina', 'escuela-natacion', true),
  ('assets/img/club/escuela-natacion-salto-de-alegria.jpg', 'escuela-natacion-salto-de-alegria.jpg', 'El equipo saltando de alegría en la piscina', 'escuela-natacion', true),
  ('assets/img/club/escuela-natacion-antes-de-empezar.jpg', 'escuela-natacion-antes-de-empezar.jpg', 'Los peques con los churros, antes de empezar', 'escuela-natacion', false),
  ('assets/img/club/escuela-natacion-el-equipo.jpg', 'escuela-natacion-el-equipo.jpg', 'El equipo de la escuela de natación', 'escuela-natacion', false),
  ('assets/img/club/escuela-natacion-diplomas.jpg', 'escuela-natacion-diplomas.jpg', 'Todos con el diploma al terminar el curso', 'escuela-natacion', false),
  ('assets/img/club/escuela-natacion-diplomas-peques.jpg', 'escuela-natacion-diplomas-peques.jpg', 'Los pequeños con su diploma y su medalla', 'escuela-natacion', false),
  ('assets/img/club/escuela-natacion-brazo-arriba.jpg', 'escuela-natacion-brazo-arriba.jpg', 'Con el brazo arriba antes de tirarse', 'escuela-natacion', false),
  ('assets/img/club/escuela-natacion-en-el-agua.jpg', 'escuela-natacion-en-el-agua.jpg', 'Aprendiendo en el agua con los churros', 'escuela-natacion', false),
  ('assets/img/club/natacion-crol-en-la-piscina.jpg', 'natacion-crol-en-la-piscina.jpg', 'Crol por la calle de la piscina', 'natacion', true),
  ('assets/img/club/natacion-salto-desde-el-borde.jpg', 'natacion-salto-desde-el-borde.jpg', 'Entrada al agua desde el borde', 'natacion', false),
  ('assets/img/club/natacion-dos-calles.jpg', 'natacion-dos-calles.jpg', 'Dos nadando por calles contiguas', 'natacion', false),
  ('assets/img/club/cubo-el-contenedor-abierto.jpg', 'cubo-el-contenedor-abierto.jpg', 'El Cubo abierto, con todo el material', 'cubo', true),
  ('assets/img/club/cubo-sentadilla-con-barra.jpg', 'cubo-sentadilla-con-barra.jpg', 'Sentadilla con barra, camiseta del club', 'cubo', true),
  ('assets/img/club/cubo-peso-muerto.jpg', 'cubo-peso-muerto.jpg', 'Peso muerto, gesto de esfuerzo', 'cubo', false),
  ('assets/img/club/cubo-kettlebell.jpg', 'cubo-kettlebell.jpg', 'Trabajo con kettlebell frente al contenedor', 'cubo', false),
  ('assets/img/club/cubo-core-en-el-cesped.jpg', 'cubo-core-en-el-cesped.jpg', 'Trabajo de core sobre el césped', 'cubo', false),
  ('assets/img/club/cubo-bici-de-asalto.jpg', 'cubo-bici-de-asalto.jpg', 'Bici de asalto al aire libre', 'cubo', false),
  ('assets/img/club/club-pulgar-arriba-dorsal-89.jpg', 'club-pulgar-arriba-dorsal-89.jpg', 'Pulgar arriba con el dorsal 89', 'club', true),
  ('assets/img/club/club-retrato-dorsal-60.jpg', 'club-retrato-dorsal-60.jpg', 'Retrato con el dorsal 60, antes de la carrera', 'club', true),
  ('assets/img/club/club-abrazo-al-terminar.jpg', 'club-abrazo-al-terminar.jpg', 'El abrazo de rodillas al terminar la prueba', 'club', true),
  ('assets/img/club/club-podio-nacional-sub-18.jpg', 'club-podio-nacional-sub-18.jpg', 'Podio del nacional sub-18 en Antequera', 'club', true),
  ('assets/img/club/club-podio-con-medallas.jpg', 'club-podio-con-medallas.jpg', 'Podio con las tres medallas al cuello', 'club', false),
  ('assets/img/club/club-los-tres-del-podio.jpg', 'club-los-tres-del-podio.jpg', 'Los tres del podio, abrazados', 'club', false),
  ('assets/img/club/club-medalla-al-cuello.jpg', 'club-medalla-al-cuello.jpg', 'Con la medalla al cuello y el escudo del club', 'club', false),
  ('assets/img/club/club-las-cinco-del-equipo.jpg', 'club-las-cinco-del-equipo.jpg', 'Cinco del club con la equipación puesta', 'club', false),
  ('assets/img/club/club-la-tribu-en-carrera.jpg', 'club-la-tribu-en-carrera.jpg', 'El grupo de adultos, antes de una popular', 'club', false),
  ('assets/img/club/club-podio-liga-de-barrios.jpg', 'club-podio-liga-de-barrios.jpg', 'Podio de la Liga de Barrios', 'club', false)
on conflict (ruta) do update
  set nombre    = excluded.nombre,
      titulo    = excluded.titulo,
      categoria = excluded.categoria,
      favorita  = excluded.favorita;

-- ------------------------------------------------------------
-- Permisos: quien entra sin cuenta no pinta nada aquí
-- ------------------------------------------------------------
-- Supabase reparte permisos de serie sobre todo lo de `public`, y
-- `biblioteca_fotos` los tenía todos concedidos a `anon` (quien
-- navega sin haber entrado). Hoy no se cuela nada porque las
-- reglas de acceso (RLS) solo dejan pasar a quien tiene sesión,
-- pero el permiso sobraba: la biblioteca es cosa del panel.
revoke all on public.biblioteca_fotos from anon;

-- Comprobación: deja escrito en el registro cómo han quedado los
-- permisos de verdad, para no fiarse de lo que se pretendía.
do $$
declare
  resto text;
begin
  select coalesce(string_agg(distinct privilege_type, ', ' order by privilege_type), '(ninguno)')
    into resto
  from information_schema.role_table_grants
  where table_schema = 'public'
    and table_name   = 'biblioteca_fotos'
    and grantee      = 'anon';

  raise notice 'biblioteca_fotos · permisos de anon: %', resto;
  if resto <> '(ninguno)' then
    raise exception 'biblioteca_fotos: anon se ha quedado con permisos (%)', resto;
  end if;
end $$;
