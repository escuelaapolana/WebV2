# Apolana · lo que hemos decidido

Paquete de entrega para desarrollo e imprenta. Tres cosas dentro, en este orden:

1. **Portada de móvil** — el diseño y su documentación
2. **Mapa del sitio** — qué páginas hay, qué hace cada una, qué se cae
3. **Icono de la app** — el SVG y las notas de exportación

---

## 1 · Portada de móvil

**Archivos:** `1-portada/README.md` · `1-portada/Portada Apolana movil.html`

El README es la fuente de verdad: los once bloques con sus medidas, colores y copy
exactos, los tokens de diseño, qué datos necesita cada bloque y qué material falta.

**El problema que resuelve.** La portada intentaba ser buscador, catálogo, escaparate y
tablón a la vez. Síntoma: «abro inicio, tiro para abajo y me vuelvo loco». Medido: el
bloque «Encuentra tu grupo» aparecía dos veces y ocupaba 840 px, y los grupos salían
duplicados.

**El orden que queda:**

| # | Bloque |
|---|---|
| 0 | Cabecera crema con Acceso y menú |
| 1 | Hero a sangre · titular, un botón, un enlace |
| 2 | Hoy en el club |
| 3 | Qué hacemos · seis secciones |
| 4 | Escuelas · banda propia, «de 3 a 18 años» |
| 5 | ¿No sabes cuál es el tuyo? · dos tarjetas |
| 6 | Franja de El Cubo · una línea |
| 7 | Noticias · una destacada y tres titulares |
| 8 | Cifras · 420 / 175 / 38 |
| 9 | Con el apoyo de · patrocinadores |
| 10 | Pie · redes, contacto, sedes, legal |

**Las cinco reglas que no se deben deshacer:**

1. La portada no es un índice de secciones. Nada de rejillas de nueve cajas con solo un
   nombre dentro.
2. En portada van secciones (seis), no grupos. Los nombres propios —La Tribu, Madre
   Tierra, El Cubo— van como subtítulo, sin precio ni horario.
3. En la portada no hay precios. Ni uno. Viven en la página de cada sección.
4. El test guiado no se incrusta: solo el primer paso, que salta a la página con la
   respuesta puesta.
5. El club se presenta como club deportivo, no como club de atletismo.

**Fuera de la portada, a propósito:** el test completo, todos los precios, la parrilla
semanal y el bloque de sedes con mapa.

**Decisiones de estilo tomadas por el camino:**

- **Sin sombras ni relieve.** Se probó y se descartó. La separación es por color de fondo
  y línea de 1 px.
- **Sin monoespaciada.** Los dígitos se alinean con `font-variant-numeric: tabular-nums`
  sobre IBM Plex Sans. Solo puede volver donde los dígitos se comparan en columna: la
  parrilla semanal, la tabla de tarifas y los resultados.
- **La foto del hero va a sangre con velo suave.** La foto tiene que verse.

---

## 2 · Mapa del sitio

**Archivo:** `2-mapa-del-sitio/Mapa del sitio Apolana.html`

Trece páginas en tres niveles, cada una con una sola pregunta que contestar.

**Entrar** (no conoce el club): Portada · Encuentra tu grupo · Horarios · Prueba 4 días

**Decidir** (ya sabe qué le interesa): Escuelas · Running · Pista · Natación · Montaña ·
Fuerza (El Cubo) · Triatlón · Deporte adaptado

**Quedarse:** Hazte socio · El club · Noticias · Patrocinio

**Los dos puntos importantes:**

- Las ocho secciones son **la misma plantilla de siete bloques**: foto y frase del
  entrenador, para quién es, días y sede, precio con la cuota sumada, quién entrena, qué
  traer, botón de prueba. Se rellena una ficha, no se diseña una página.
- **La cuenta de septiembre.** Alguien tiene que revisar horarios, precios y entrenadores
  de las ocho secciones una vez al año. Si no hay quien lo haga, fusionar en tres:
  Escuelas, Adultos y Competición. Tres páginas ciertas valen más que ocho
  desactualizadas.

**Se caen:** la página de precios, la de sedes, «para mi hijo»/«para mí» como páginas, una
página por grupo, «Calendario» aparte de «Horarios», y la galería de fotos.

**Por dónde empezar:** Horarios, aunque no luzca. De ese dato dependen la portada y las
ocho secciones.

---

## 3 · Icono de la app

**Archivos:** `3-icono/icono-app.svg` · `3-icono/Icono app Apolana.html` ·
`3-icono/mojon.svg`

El sello completo no funciona a 60 px: el anillo de texto se vuelve una mancha gris y el
fondo blanco hace que el icono desaparezca sobre fondos de pantalla claros.

**Lo decidido:** el mojón desplazado a la derecha y medio salido por abajo, con su rayita
lateral y el 21 troquelado, sobre el azul de marca. Es un dibujo simplificado, no un calco
del logo: los lados van rectos, sin el ensanche de la base, y eso es lo que lo hace
rotundo a tamaño pequeño.

**Azul de marca: `#2E81BE`**, leído del SVG vectorial. El anterior estaba sacado de un PNG
y no era fiable.

**Antes de subirlo a las tiendas:**

- Convertir el 21 a curvas (ahora es texto con Barlow Condensed).
- Tres versiones: iOS entrega el cuadrado completo a 1024×1024; Android adaptativo
  necesita el mojón un 15 % más pequeño para que el círculo no lo corte; el favicon a
  32 px probablemente vaya sin número.

**El sello completo no se toca** en camisetas, dorsales, documentos ni en el pie de la
web. Las variantes de Natación y Fitness tampoco. Esto es solo la versión para 60 px.

`mojon.svg` es el mojón extraído del logo original, con la geometría exacta, por si hace
falta para otra cosa.

---

## Lo que falta para poder publicar

**Fotos.** Verticales y propias — las de hoy están recortadas para escritorio. Hace falta
una para el hero, una de la escuela y una miniatura de noticia; y cuando se hagan las
páginas de sección, una por sección. Una tarde de reportaje (martes o jueves: Joaquín
Villar 17:30 y Monte Tossal 20:00) resuelve seis de los nueve grupos. **Con las
autorizaciones de imagen de los menores firmadas antes.**

**Horarios.** Los nueve grupos con día, hora de inicio y fin, y sede, cargados y
mantenidos. Es lo que bloquea la portada entera y lo que menos se menciona.

**Textos.** Una frase por sección escrita por su entrenador («¿qué le dirías a alguien que
se lo está pensando?», máximo veinte palabras). El estado vacío de agosto para «Hoy en el
club». El nombre real de quien contesta el WhatsApp.

**Logos.** El escudo en SVG y los logos de los patrocinadores en SVG o PNG transparente.

## Tres cosas sin decidir

1. **«Atletismo en ruta» o «Running»** en la primera sección. Un padre entiende «Running»
   antes; «ruta» es lenguaje de dentro del club.
2. **Si «Club deportivo» sustituye a «Club de atletismo»** en el antetítulo del hero.
3. **Cuántos patrocinadores hay**, para dimensionar la rejilla.

## Cómo usar los HTML

Los archivos `.html` son prototipos: se abren con doble clic en cualquier navegador y
funcionan sin conexión. **No son código de producción** — llevan dentro el motor de
previsualización. Sirven para ver el diseño; los valores exactos están en los README.

La portada está diseñada a 402 px de ancho, así que en una pantalla grande sale una
columna estrecha centrada. En un móvil ocupa todo.
