# Páginas del sistema — contexto para el maquetador

Web + app del Club Atletismo Apolana. Todo funciona ya; lo que falta es **piel**.
Estas páginas **no tienen maqueta**: las diseñé yo sobre la marcha y son
mejorables. Marco con ⚠️ las que creo que más lo necesitan.

**Sistema visual actual** (respetarlo salvo que se proponga algo mejor):
crema `#FBF9F4` · crema bloque `#F1EADC` · blanco tarjeta · borde `#EFE9DC`
navy `#2E4256` · azul medio `#2F6FA8` · azul acción `#3B85C0`
Titulares Barlow Condensed 700 mayúsculas · Cuerpo IBM Plex Sans 16 px
Sin tipografía monoespaciada y sin mayúsculas con espaciado ancho (se quitaron
a propósito: daban aire "generado"). Móvil primero, 375 px, táctiles ≥44 px.

---

## Lo primero que pediría: un kit de componentes ⚠️⚠️

El problema de fondo no es ninguna pantalla concreta: es que hay **40 pantallas
resueltas una a una**. Tarjetas con esquinas de 14, 16 y 18 px según la página;
dos sistemas de avisos distintos (uno en el panel, otro en la app); tres formas
de pintar una lista. Al navegar se nota cosido.

Un kit con estas piezas arreglaría las 40 de golpe:

- Tarjeta (y sus variantes: con foto, con cifra, pulsable)
- Fila de lista (con avatar, con dato a la derecha, con chevron)
- Tabla que en móvil se convierte en ficha
- Botones, chips y filtros
- Aviso / confirmación (unificar los dos que hay)
- **Estado vacío** y **estado cargando** (hoy son texto gris; es lo que más
  delata que algo está hecho en casa)
- Cabecera de pantalla, en app y en panel
- Escala tipográfica (hoy los tamaños los fui ajustando a ojo)
- Iconografía: los SVG los dibujé yo uno a uno, con grosores que no casan

---

## APP · Portal del socio

### ⚠️ Los tres "Inicio"
`/portal/atleta/` · `/portal/entrenador/` · `/portal/familia/`
Ya siguen la maqueta 22a (un solo Inicio, barra de cinco pestañas), pero el
dueño dice que **no le convencen**, y estoy de acuerdo: son listas de tarjetas
donde **todo pesa igual**. Un inicio bueno tiene *una* cosa protagonista.
- Atleta: recibo pendiente → entreno de hoy → próxima carrera y última marca.
- Entrenador: sesión de hoy con "Pasar lista" → avisos → sus atletas.
- Familia: próxima sesión del hijo → pagos si hay algo → nota del entrenador.

### ⚠️⚠️ Retos y medallas — `/portal/retos/` y `/admin/retos/`
**Invención mía al 100%, sin maqueta.** Es lo más ilusionante del proyecto y lo
que peor está resuelto visualmente.
Qué hace: retos que se cumplen solos con lo que ya sabe el sistema (asistencias,
rachas, clases de El Cubo, competiciones, marcas). Dan puntos → rango
(Debutante · Bronce · Plata · Oro · Platino · Élite · Leyenda) → medallas.
Cada uno elige cómo aparece (nombre o apodo, con foto o sin ella) y su perfil es
consultable por otros socios: ven sus medallas y sus retos cumplidos.
**Sin clasificación** (para no hacer sombra a la Liga); está construida pero
apagada tras un interruptor.
Necesita: cómo se ve un rango, cómo se ve una medalla ganada, la barra de
progreso de un reto, y el momento "has conseguido algo" — que ahora no existe.

### ⚠️ Mi perfil — `/portal/perfil/`
Foto (con recorte), apodo, datos, contraseña y un interruptor de privacidad.
Funciona, pero es un formulario largo y frío.

### Liga Apolana — `/portal/liga/`
Comunicar una prueba (con foto de la clasificación), ver cómo voy y avisar de
carreras que faltan. Ver abajo el bloque de Liga.

### Otras del portal
`/portal/calendario/` (Agenda · Semana · Mes — sí tiene maqueta, 24b) ·
`/portal/cubo/` · `/portal/competiciones/` · `/portal/documentos/` ·
`/portal/mensajes/` · `/portal/lesiones/` · `/portal/carga/` · `/portal/calles/`
(natación, se rehará con la maqueta 25) · `/portal/tests/` (maqueta 23b).

---

## WEB PÚBLICA

### ⚠️⚠️ Galería — `/galeria/`
**Invención mía.** Una rejilla plana de fotos donde **ni siquiera se puede
ampliar una**. Es de lo más pobre del sitio. Necesita: cómo se agrupa (por
sección, por año), qué pasa al tocar una foto, y cómo se ve con 200 fotos.

### ⚠️ Instalar la app — `/app/`
**Invención mía.** Un muro de texto con los pasos para iPhone y Android.
Necesita hacerse deseable: una captura en un marco de móvil vale más que los
diez pasos escritos.

### ⚠️ Escuelas — `/escuelas/`
**Invención mía.** Página lanzadera con cuatro tarjetas (atletismo, natación,
municipal, campus) para elegir escuela. Cumple y poco más.

### Liga Apolana — `/liga/` ⚠️
**Invención mía.** Clasificación pública del club: general, por disciplina y por
categoría, más la normativa resumida y la tabla de puntos. Reproduce las
columnas del Excel que usaban (Posición · Nombre · Categoría · Atletismo ·
Running · Trail · Triatlón · Natación · Bonus · Total · Pruebas).
Necesita: cómo se lee una clasificación de 31 personas en un móvil, y cómo se
destaca el podio sin que parezca una hoja de cálculo.

### El día en el club — `/horarios/`
Sí tiene especificación (PAGINAS-NUEVAS.md). Parrilla semanal de los 27 grupos
con filtro por sección; en móvil, acordeón por día. **Funciona bien**, pero es
la página más útil del sitio y merece un repaso fino.

### Área de socio — `/socio/`
Panel personal con sesión (cuota, próxima carrera, grupos, marcas del trimestre,
"este mes", Familia Apolana y recibos). Sigue PAGINAS-NUEVAS.md.
**Ojo: tiene un cargador colgado** ("Cargando tu panel…") que estoy revisando.

---

## PANEL DE ADMINISTRACIÓN ⚠️⚠️

**26 páginas.** Es donde el club pasa más horas y es lo que peor está: tablas
densas, gris sobre gris, poca jerarquía. Comparado con la app, parece de otra
época. Si solo se puede maquetar una cosa del panel, que sea **Inicio, Atletas y
Cobros**, y que de ahí salga el patrón para el resto.

- **Inicio** — contadores (inscritos, impagados, en prueba, ropa) y "alertas de
  hoy" (lesiones, impagos, periodos de prueba que acaban). Los contadores ya son
  pulsables y llevan a su lista filtrada.
- **Atletas** — lista con filtros (estado, grupo, escuela/socio) y ficha en
  ventana emergente. En móvil cada atleta es una ficha.
- **Cobros y recibos** · **Tarifas** · **Pedidos de ropa**
- **En la pista** ⚠️ (`/admin/campo/`) — **invención mía**. La herramienta de
  campo: pasar lista (grupos por sección, plegados, con los de hoy arriba),
  buscar a un niño y ver quién ha venido. Se usa **con una mano, a pie de pista
  y con sol**. Merece maqueta propia.
- **Estadísticas** ⚠️ — **invención mía**. Gráficas hechas a mano en SVG
  (atletas por sección y categoría, ingresos por mes, El Cubo, escuela por
  temporadas). Funciona; es sosa.
- **Fotos de la web** ⚠️ — **invención mía**. Los 80 huecos de foto de toda la
  web, agrupados por página, con miniatura, encuadre y zoom.
- **Biblioteca de fotos** — subida múltiple, secciones, favoritas, selección
  múltiple y acciones en bloque.
- **Colaboradores** ⚠️ — **invención mía**. Logo, nombre y elegir si se muestra
  logo, nombre o ambos.
- **Liga Apolana** ⚠️ — **invención mía**. Bandeja de pruebas comunicadas por
  los socios (con el justificante a la vista para validar de un clic), carreras
  propuestas, clasificación y tabla de puntos editable.
- **Retos** ⚠️ — **invención mía**. Crear retos, ver quién los cumple, permisos
  familiares de menores.
- **Batería de tests** (maqueta 23c) · **Informes** (con "Historial de un
  atleta": día a día de asistencia y notas, imprimible con membrete) ·
  **Competiciones · Eventos · Grupos · Usuarios · Importar · El Cubo · Pruebas ·
  Noticias · Páginas · Textos · Documentos · Mapa de contenido · Peticiones de
  redes · Plantillas · Récords · Palmarés · Histórico**

---

## PENDIENTE DE MAQUETA · dos pantallas que todavía no existen

Estas dos **no están hechas**: la base ya está preparada para las dos, pero no
se escribe ni una línea de pantalla hasta que haya maqueta.

### Inscripción de la escuela ⚠️⚠️ — pantalla nueva, no existe
Hoy la escuela no tiene formulario propio de inscripción. Cuando lo haya, el
sistema tiene que **proponer solo el grupo** a partir del año de nacimiento del
niño: los grupos de la escuela son nueve colores (rojo 1, 2 y 3 · azul 1, 2 y 3
· verde 1, 2 y 3) y cada uno lleva escrito su año en la ficha del grupo.
La propuesta es **solo una propuesta**: el club cambia de grupo a quien quiera.
Qué hace falta decidir en la maqueta: cómo se pide el año de nacimiento, cómo
se enseña el grupo propuesto (¿con su color?, ¿con sus días?), qué se ve cuando
para ese año no hay grupo abierto, y cómo se avisa de que la plaza no es firme
hasta que el club la confirma.

### «Empezar temporada nueva» en Panel → Grupos ⚠️ — botón nuevo, no existe
Cada septiembre los nueve colores suben un año: rojo 1 deja de ser el de 2023 y
pasa a ser el de 2024, y así los nueve. La base ya sabe hacerlo de una vez
(`grupos_avanza_temporada`), pero **no hay botón** que lo dispare, y hacerlo
grupo a grupo son nueve ediciones seguidas y una equivocación segura.
Qué hace falta: un botón en Panel → Grupos, una confirmación que enseñe **el
antes y el después de los nueve** (no un «¿seguro?» a ciegas: se cambian los
años de todo un club), y qué pasa con los grupos apagados. Después el club
retoca a mano lo que haga falta, que es lo normal: un año no hay niños de una
edad y ese grupo se apaga; otro se desborda y se duplica.

---

## Patrones que inventé y conviene revisar o bendecir

1. **Barra inferior de cinco pestañas** — en las 14 pantallas del portal
   (sigue la maqueta 22c) y también en las 26 del panel (esta segunda es
   invención mía: Inicio · Pista · Personas · Dinero · Menú).
2. **Panel "Más"** — pantalla completa con tres bloques (El club · Mi cuenta ·
   Ayuda).
3. **Editar en ventana emergente** — en todo el panel; antes el formulario se
   abría al fondo de la página y había que bajar.
4. **Menú del panel plegable por bloques** — con 30 secciones, una lista
   entera era inmanejable.
5. **Tablas que en móvil se convierten en fichas** — en atletas, cobros,
   récords, marcas, buzón.
6. **Entreno por bloques plegables** — con los huecos para anotar los tiempos
   **dentro de cada serie**, y "3 de 6 anotadas" en la cabecera.
7. **Estados vacíos con invitación** — decisión del club: si no tienes grupo,
   la pantalla de entreno no se esconde, te invita a apuntarte a uno.

---

## Notas útiles

- **Todo es dinámico**: los grupos, horarios, precios, fotos, textos y
  colaboradores salen del panel, no están escritos en el código.
- **Hay dos zonas con acceso**: el portal (socios, familias, entrenadores) y el
  panel (administración). Y una parte pública sin cuenta.
- **Datos sensibles**: hay menores. Las notas de comportamiento y los datos de
  contacto no se enseñan nunca fuera del equipo técnico; los números de cuenta
  solo con sesión iniciada.
- **La app es la web instalada** (PWA), así que lo que se maquete para móvil
  vale para las dos.

---

## Restricciones técnicas que condicionan el diseño

Conviene saberlas antes de maquetar, para no diseñar algo que luego no se pueda
hacer o que quede raro:

- **No hay servidor.** La web es estática y los datos llegan del navegador. Eso
  significa que **siempre hay un instante de carga**: hay que diseñar el estado
  "cargando" como parte del producto (esqueletos, no un "Cargando…" gris).
- **No usamos librerías** (ni Tailwind, ni React, ni librerías de gráficas):
  todo es HTML, CSS y JavaScript a mano. Si el diseño se apoya en componentes de
  una librería concreta, habrá que traducirlo. Las gráficas se dibujan a mano.
- **La app es la web instalada.** No hay barra del navegador ni botón "atrás":
  por eso la barra inferior es crítica y por eso hay que respetar el hueco de la
  barra de gestos del móvil.
- **Fuentes disponibles**: Barlow Condensed, IBM Plex Sans y Archivo (Google
  Fonts). Si se propone otra, hay que cargarla y afecta a la velocidad.
- **Formato de entrega**: los `.dc.html` que manda funcionan muy bien; se pueden
  leer y reproducir fielmente. Que siga así.

## Volúmenes reales (para no diseñar con datos de mentira)

Una lista de 5 se diseña distinto que una de 206:

- **206 atletas**, 27 grupos, 8 secciones
- **31 participantes** en la Liga, con 11 columnas de puntuación
- **26 páginas** en el panel · **14** en el portal · **35** públicas
- **80 huecos de foto** editables
- Un entrenador puede llevar **4 calles a la vez** en natación

## Casos que rompen los diseños bonitos

- **Nombres largos**: "Sergio Redondo del Río", "Natación · Perfeccionamiento",
  "Escuela municipal de atletismo". En 375 px se parten en tres líneas.
- **Cero datos**: el club acaba de empezar con la app. Muchas pantallas se verán
  vacías las primeras semanas (0 marcas, 0 retos, 0 participantes en la liga).
  **Los estados vacíos no son un caso raro: son el estado inicial.**
- **Textos que escribe el club** desde el panel: pueden ser más largos de lo
  previsto. Nada debe descuadrarse por un título de 60 caracteres.

## Los estados que siempre se olvidan

Para cada pantalla que maquete, harían falta: **cargando · vacío · con pocos
datos · con muchos · error · sin permiso**. Es justo donde se nota si algo está
cuidado o no.

## Contexto de uso (importa más de lo que parece)

- **A pie de pista, con sol y una mano ocupada**: pasar lista y anotar tiempos.
  Contraste alto y objetivos grandes, más de lo que pediría un diseño de oficina.
- **Gente de 8 a 70+ años**: hay categoría "60 en adelante" y escuela desde los
  3. Nada de texto de 10 px ni gris sobre gris.
- **El panel también se usa en ordenador**, con sesiones largas. Ahí sí caben
  tablas densas, pero con jerarquía.

## Decisiones abiertas que le corresponden al club

- **Modo oscuro**: no existe. ¿Interesa?
- **Color por sección** (atletismo, natación, montaña…): hoy solo se usa en
  horarios y calendario. ¿Lo llevamos a todo el sistema?
- **El escudo del club** está infrautilizado: solo aparece en la cabecera y el
  pie. ¿Puede formar parte del lenguaje visual?

---

## Lo más urgente de todo: DENSIDAD ⚠️⚠️⚠️

El dueño lo ha dicho con estas palabras: *"el hecho de que yo abra la página y,
al ser la foto y el título tan grandes, no quepa en mi campo visual, no me
gusta. Es todo muy grande."*

Es la crítica más importante de todas las que ha hecho, y tiene razón:

- Al abrir la web en un portátil, **la foto del hero y el titular ocupaban la
  pantalla entera**. No se veía nada más: ni el botón de "Prueba 4 días gratis",
  ni el resto de la página.
- He reducido de urgencia el hero (foto a un tercio del alto de la ventana y
  titular más contenido), pero es un parche: **hace falta una decisión de diseño
  sobre la densidad de todo el sitio**.
- La referencia que él usa es la web anterior del club: mucha más información
  por pantalla, sin sensación de cartel.

Lo que pediría: **una escala tipográfica y de espaciados pensada** (hoy los
números los fui ajustando a ojo, bajándolos cuando él decía "más pequeño"), y un
criterio claro de cuánto debe verse en la primera pantalla, en portátil y en
móvil.

## La barra de navegación no cabe

La web tiene **9 entradas de primer nivel** (El club · Entrena con nosotros ·
Escuelas · Familias · Horarios · Calendario · Noticias · Tienda · Contacto).
En portátiles de 1000-1200 px **no caben**: o se salen por la derecha o hay que
esconderlas tras el botón de menú, y entonces la web parece una app.

La web anterior tenía nueve entradas más cortas y sí cabían ("Club · Únete al
club · Entrena con nosotros · Secciones · Escuela · Noticias · Tienda ·
Contacto · Liga").

Hace falta decidir: ¿menos entradas de primer nivel? ¿nombres más cortos?
¿doble fila? Es decisión de diseño, no de código.

## Redes sociales

La web anterior tenía una fila de iconos arriba: Facebook, correo, Instagram,
WhatsApp y TikTok. **En la nueva no estaban**; los acabo de añadir al pie y al
menú del móvil, pero convendría que el diseño les dé un sitio propio.
Cuentas: Instagram @apolana.alicante · TikTok @escuela.apolana ·
Facebook /atletismo.apolana.alicante · WhatsApp 636 06 17 00.
