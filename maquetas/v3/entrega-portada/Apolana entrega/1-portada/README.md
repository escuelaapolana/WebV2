# Handoff: portada de móvil — Club Atletismo Apolana

## Resumen

Rediseño de la portada en móvil de la web del Club Atletismo Apolana (Alicante, 1988).
El objetivo, en palabras del cliente: **que un padre o un adulto que no conoce el club
entienda en diez segundos qué hacemos y encuentre su grupo.**

El club tiene 420 atletas y 175 socios, nueve grupos y cinco deportes: escuela de
atletismo (3-17), escuela de natación, pista, running (La Tribu y Madre Tierra), natación
de adultos, triatlón, montaña, fuerza (El Cubo) y deporte adaptado.

Web actual en producción: https://escuelaapolana.github.io/apolana-club/

## Sobre los archivos de diseño

Los archivos de este paquete son **referencias de diseño hechas en HTML** — prototipos que
muestran el aspecto previsto, no código de producción para copiar. La tarea es **recrear
el diseño en el repositorio existente** (sitio estático en GitHub Pages) siguiendo sus
patrones y su CSS.

`Portada Apolana movil.html` es un archivo compilado que incluye un runtime de
previsualización propio. **No lo importéis ni copiéis su código.** Sirve para abrirlo en el
navegador y ver el diseño. Los valores exactos están documentados abajo y son la fuente de
verdad.

## Fidelidad

**Alta fidelidad.** Colores, tipografías, espaciados y copy son definitivos salvo donde se
indique. Dos salvedades:

- Las **fotos son marcadores** salvo la del hero. Las que faltan aparecen como trama
  diagonal gris con una nota de qué va ahí.
- La **foto del hero es un recorte de baja resolución** sacado de una captura de pantalla
  del cliente. Sirve para ver el diseño; **hay que sustituirla por el original**.
- Los **datos son de ejemplo** (horarios, noticias). Hay que enchufarlos a los reales.

## El problema que resuelve este rediseño

Contexto necesario, porque condiciona qué se puede tocar:

La portada anterior intentaba ser buscador, catálogo, escaparate y tablón a la vez. El
síntoma que describía el dueño: «abro inicio, tiro para abajo y me vuelvo loco». Medido:
el bloque «Encuentra tu grupo» aparecía dos veces y ocupaba 840 px, y los grupos salían
duplicados (una vez en «Para mí» y otra en «Grupos y precios»).

Las cinco decisiones que ordenan la portada actual:

1. **La portada no es un índice de secciones.** El cliente había probado cuatro variantes
   (buscador de cuatro preguntas incrustado, rejilla de secciones con precios, fotos
   pequeñas con el nombre encima, índice de una línea) y todas se leían como «un menú más».
   Cualquier cambio que devuelva la portada a una rejilla de nueve cajas con solo un nombre
   dentro deshace el trabajo.

2. **En portada van secciones, no grupos.** Seis secciones, una línea cada una. Los nombres
   propios (La Tribu, Madre Tierra, El Cubo) van como subtítulo de su sección, porque son
   lo que la gente repite — pero sin precio ni horario.

3. **En la portada no hay precios.** Ni uno. Viven en la página de cada sección.

4. **El test guiado no se incrusta.** La portada lleva solo el primer paso («¿para
   quién?») con dos respuestas que saltan a `/encuentra-tu-grupo/` con esa respuesta ya
   puesta. La página existe y hace el trabajo completo mejor.

5. **El club se presenta como club deportivo, no como club de atletismo.** Afecta al copy
   en varios sitios.

**Lo que el cliente pidió no tocar:** el hero (foto a sangre, velo, titular, un botón) y
«Hoy en el club».

## Pantalla

Solo hay una: la portada en móvil. Diseñada a **402 px** de ancho (iPhone 14/15/16 en CSS px).

### Estructura, en orden

| # | Bloque | Fondo | Nota |
|---|--------|-------|------|
| 0 | Cabecera | `#FBF9F4` | Barra crema propia, sobre la foto |
| 1 | Hero | foto | A sangre, velo, titular, un botón + enlace |
| 2 | Hoy en el club | `#2E4256` | |
| 3 | Qué hacemos | `#F1EADC` | Seis secciones |
| 4 | Escuelas | foto | Banda propia, «de 3 a 18 años» |
| 5 | ¿No sabes cuál es el tuyo? | `#FBF9F4` | El gancho, dos tarjetas |
| 6 | Franja de El Cubo | `#E08A18` | Una línea |
| 7 | Noticias | `#FBF9F4` | Una destacada + tres titulares |
| 8 | Cifras | `#2E4256` | 420 / 175 / 38 |
| 9 | Con el apoyo de | `#FBF9F4` | Patrocinadores |
| 10 | Pie | `#141C24` | Redes, contacto, sedes, legal |

El ritmo de fondos (crema → foto → navy → arena → foto → crema → ámbar → crema → navy →
crema → negro) es intencionado: evita que dos bloques seguidos se confundan. **Mantenedlo.**

**Fuera de la portada, deliberadamente:** el test guiado completo, todos los precios, la
parrilla semanal y el bloque de sedes con mapa.

**El diseño es plano.** No hay sombras, degradados de relieve ni botones en 3D. La
separación es por color de fondo y por línea de 1 px. Se probó añadir elevación y el
cliente lo rechazó explícitamente. La única excepción son los velos de las fotos.

---

### 0 · Cabecera

- Alto 62 px, `background: #FBF9F4`, padding lateral 18 px, `justify-content: space-between`.
- Izquierda: escudo circular 30 px (`border: 1.5px solid #2F6FA8`, sustituir por el escudo
  real) + «APOLANA» en Barlow Condensed 700, 21 px, uppercase, `letter-spacing: 0.03em`,
  color `#2E4256`. Gap 10 px.
- Derecha, gap 9 px:
  - Píldora «Acceso»: alto 44 px, `padding: 0 20px`, `border-radius: 999px`,
    `border: 1px solid #DCD3C0`, IBM Plex Sans 400, 15 px, `#4A4437`.
  - Botón hamburguesa: 44×44 px, mismo borde y radio, tres barras de 18×2 px `#2E4256`,
    gap 5 px.

### 1 · Hero

- Alto 456 px, `position: relative`, `overflow: hidden`.
- Foto a sangre: `object-fit: cover`, `object-position: 62% 30%`.
- Velo: `linear-gradient(to top, rgba(20,28,36,0.62) 0%, rgba(20,28,36,0.38) 46%,
  rgba(20,28,36,0.08) 80%, rgba(20,28,36,0.12) 100%)`.
  **Es un velo suave a propósito: la foto tiene que verse.** No oscurecerlo más.
- Contenido anclado abajo: `left/right: 20px`, `bottom: 26px`, columna con gap 12 px.
  - Antetítulo: IBM Plex Sans 400, 16px/1.4, `rgba(255,255,255,0.82)`.
    Copy: «Club deportivo · Alicante · desde 1988»
  - Titular: Barlow Condensed 700, 46px/0.9, uppercase, blanco.
    Copy: «Aquí siempre hay alguien entrenando»
  - Bajada: IBM Plex Sans 400, 16px/1.45, `rgba(255,255,255,0.92)`.
    Copy: «Atletismo, running, triatlón, natación y montaña.»
  - Botón: alto 58 px, `border-radius: 999px`, `background: #3B85C0` **plano**, texto
    IBM Plex Sans 600, 17 px, blanco. «Prueba 4 días gratis»
  - Enlace: alto 34 px, centrado, IBM Plex Sans 600, 16 px, blanco. «Conocer el club →»

### 2 · Hoy en el club

`padding: 24px 20px 22px`, `background: #2E4256`.

- Título: Barlow Condensed 700, 26px/1, uppercase, blanco.
- Fecha: IBM Plex Sans 400, 15px/1.3, `rgba(255,255,255,0.62)`, `margin-top: 4px`.
- Cada fila: `margin-top: 14px`, `padding-top: 15px`,
  `border-top: 1px solid rgba(255,255,255,0.2)`, flex gap 14 px, `align-items: baseline`.
  - Hora: 50 px fijos, IBM Plex Sans 500, 16px/1.3, `#8FC0E8`,
    **`font-variant-numeric: tabular-nums`** (así se alinean sin monoespaciada).
  - Título: IBM Plex Sans 400, 16px/1.35, blanco.
  - Sede: IBM Plex Sans 400, 14px/1.35, `rgba(255,255,255,0.6)`, `margin-top: 3px`.
- Enlace final: `margin-top: 18px`, IBM Plex Sans 500, 16px/1.3, `#8FC0E8`.
  «Ver la semana entera →»

Se muestran las **tres primeras sesiones del día**. Toda la fila es enlace.

**Estado vacío obligatorio.** En agosto, Navidad o si falla el dato, este bloque no puede
quedar en blanco. Texto de reserva: «La temporada arranca el 8 de septiembre» + enlace al
calendario.

### 3 · Qué hacemos

`padding: 24px 20px`, `background: #F1EADC`.

- Título: Barlow Condensed 700, 25px/1, uppercase, `#2E4256`, `margin-bottom: 8px`.
- Filas: `padding: 14px 0`, `border-bottom: 1px solid #E0D7C4` (la última sin), flex gap
  12 px, `align-items: baseline`.
  - Nombre: IBM Plex Sans 400, 17px/1.3, `#2E4256`.
  - Subtítulo: IBM Plex Sans 400, 13px/1.35, `#6E6656`, `margin-top: 3px`.
  - Chevron `›`: IBM Plex Sans 400, 18px/1, `#6E6656`.

| Sección | Subtítulo |
|---|---|
| Atletismo en ruta | La Tribu y Madre Tierra |
| Atletismo en pista | Competición y velocidad |
| Natación | Adultos, en Monte Tossal |
| Montaña | Salidas de fin de semana |
| Triatlón | Arranca en septiembre |
| Fuerza | El Cubo |

**Pendiente de decidir con el cliente:** «Atletismo en ruta» es lenguaje de dentro del
club. Un padre entiende «Running» antes. Recomendación: rotular «Running» en portada y
dejar «ruta» para la página de la sección.

### 4 · Escuelas

Contenedor `padding: 0 20px`. Banda: alto 176 px, `border-radius: 16px`,
`margin-top: 24px`, `overflow: hidden`.

- Foto de fondo `object-fit: cover`.
- Velo: `linear-gradient(to top, rgba(20,28,36,0.9), rgba(20,28,36,0.08))`.
- Texto abajo (`left/right: 18px`, `bottom: 16px`):
  - «Escuelas» en Barlow Condensed 700, 32px/0.96, uppercase, blanco.
  - «De 3 a 18 años · atletismo y natación» en IBM Plex Sans 400, 14px/1.4,
    `rgba(255,255,255,0.85)`, `margin-top: 5px`.

Va separada de «Qué hacemos» a propósito: es otro público y otra decisión.

### 5 · ¿No sabes cuál es el tuyo?

`padding: 24px 20px`, gap 14 px.

- Título: Barlow Condensed 700, 25px/1, uppercase, `#2E4256`.
- Texto: IBM Plex Sans 400, 15px/1.45, `#4A4437`. «Contesta una cosa y te lo decimos.»
- Rejilla 2 columnas, gap 11 px. Cada tarjeta: `background: #fff`,
  `border: 1px solid #E4DCCB`, `border-radius: 14px`, `padding: 17px 15px`, columna gap 5 px.
  - Título: IBM Plex Sans 500, 17px/1.2, `#2E4256`.
  - Sub: IBM Plex Sans 400, 13px/1.3, `#6E6656`.
  - «Para mi hijo» / «3 a 18 años» → `/encuentra-tu-grupo/?para=hijo`
  - «Para mí» / «Adulto» → `/encuentra-tu-grupo/?para=adulto`

**Las tarjetas navegan a la página con la primera respuesta ya seleccionada.** No abren un
test dentro de la portada. Va en el puesto 5, después de las secciones, porque quien ya se
ha reconocido en una no lo necesita.

### 6 · Franja de El Cubo

`padding: 13px 20px`, `background: #E08A18`, flex, `justify-content: space-between`.

- Texto: IBM Plex Sans **500**, 15px/1.3, color `#141C24`.
- Chevron `›`: 16 px, `#141C24`.

**El texto va en oscuro, no en blanco** — blanco sobre este ámbar da 2.69:1 y no pasa AA.
`#141C24` sobre `#E08A18` da 6.40:1.

Es una franja de una línea. Si el aviso no cabe en una línea, hay que acortar el texto, no
crecer la franja. Se oculta entera cuando no hay aviso.

### 7 · Noticias

`padding: 24px 20px`, gap 16 px.

- Cabecera: «Noticias» (Barlow Condensed 700, 25px/1, uppercase, `#2E4256`) + «Ver todas»
  (IBM Plex Sans 400, 14 px, `#2F6FA8`), alineadas por `baseline`.
- **Una destacada:** flex gap 13 px, `align-items: center`.
  - Miniatura 76×58 px, `border-radius: 8px`, `object-fit: cover`.
  - Fecha: IBM Plex Sans 400, 12px/1.3, `#6E6656`.
  - Titular: IBM Plex Sans 400, 15px/1.3, `#2E4256`, `margin-top: 3px`.
- **Tres titulares en lista**, separados de la destacada por
  `border-top: 1px solid #EFE9DC`, gap 11 px. Cada uno: fecha corta en 52 px
  (IBM Plex Sans 400, 12px/1.4, `#6E6656`) + titular (IBM Plex Sans 400, 15px/1.35,
  `#2E4256`).

Sin tarjetas grandes. Van al final a propósito: una noticia solo la entiende quien ya está
dentro, y además envejece.

### 8 · Cifras

`padding: 20px`, `background: #2E4256`, `justify-content: space-between`. Tres columnas:
izquierda, centrada, derecha.

- Cifra: **Barlow Condensed 700, 30px/1**, blanco.
- Etiqueta: IBM Plex Sans 400, 13px/1, `rgba(255,255,255,0.65)`, `margin-top: 4px`, en
  minúscula.
- Contenido: **420 atletas · 175 socios · 38 años**.

**El 38 se calcula desde 1988**, no hardcodear.

### 9 · Con el apoyo de

`padding: 22px 20px`, `background: #FBF9F4`, gap 14 px.

- Etiqueta: IBM Plex Sans 500, 12px/1, `letter-spacing: 0.11em`, uppercase, `#6E6656`.
- Rejilla 2×2, gap 12 px. Cada hueco: alto 56 px, `background: #fff`,
  `border: 1px solid #E4DCCB`, `border-radius: 10px`, logo centrado con
  `object-fit: contain` y padding interior.
- Enlace: IBM Plex Sans 400, 14px/1.4, `#2F6FA8`. «¿Quieres patrocinar al club? →»

Va sobre fondo claro **a propósito**: los logos de terceros vienen casi siempre sobre
blanco y en navy se ven sucios. El número de huecos debe ajustarse a los patrocinadores
reales; si son muchos, separar «principales» de «colaboradores».

### 10 · Pie

`padding: 24px 20px 32px`, `background: #141C24`, gap 18 px.

- Escudo 28 px (`border: 1.5px solid #fff`) + «APOLANA» Barlow Condensed 700, 20 px,
  uppercase, `letter-spacing: 0.02em`, blanco.
- Redes: texto IBM Plex Sans 400, 15px/1.4, `rgba(255,255,255,0.85)` — «Síguenos, ahí
  ponemos las fotos de cada entreno» — y debajo tres píldoras en fila (gap 10 px,
  `flex: 1` cada una), alto 46 px, `border: 1px solid rgba(255,255,255,0.28)`,
  `border-radius: 999px`, texto blanco IBM Plex Sans 400, 14 px: Instagram, Facebook, Strava.
  **La frase es el argumento; tres iconos sueltos no los pulsa nadie.**
- Separador `border-top: 1px solid rgba(255,255,255,0.16)`, `padding-top: 16px`, gap 10 px:
  - Contacto, IBM Plex Sans 400, 14px/1.6, `rgba(255,255,255,0.7)`.
  - Sedes, mismo estilo: «Dónde entrenamos: Estadio Joaquín Villar · Piscina Monte Tossal ·
    El Cubo · Explanada».
  - Legal, 13px/1.5, `rgba(255,255,255,0.58)`: «Aviso legal · Privacidad · Protección del
    menor». *(La opacidad es 0.58 y no menos por contraste AA — no bajarla.)*

## Interacciones y comportamiento

- **Filas de sección y de «Hoy en el club»**: toda la fila es enlace.
- **Tarjetas del gancho**: navegan con el parámetro de la respuesta.
- **Franja de El Cubo**: se renderiza solo si hay aviso con caducidad futura.
- **Hover** (tablet/escritorio): primario a `#2F6FA8`; en filas,
  `background: rgba(46,66,86,0.04)`.
- **Área táctil mínima 44 px** en todo lo pulsable. Cabecera, botones y filas ya la cumplen.
- **Responsive**: el diseño es de móvil. A partir de ~720 px el contenido debe pasar a dos
  columnas o quedar centrado con ancho máximo; no estirar las filas a 1200 px.
- **Sin animaciones.** Nada aparece al hacer scroll.

## Estado y datos

| Dato | Uso | Nota |
|---|---|---|
| Sesiones de hoy | Bloque 2 | hora, título, sede — las tres primeras |
| Las seis secciones | Bloque 3 | nombre, subtítulo, URL. Contenido casi estático |
| Aviso vigente | Bloque 6 | texto + URL + caducidad. Opcional |
| Noticias | Bloque 7 | cuatro últimas: una con foto, tres en lista |
| Cifras | Bloque 8 | atletas, socios, año de fundación |
| Patrocinadores | Bloque 9 | logo + enlace |

**El dato que bloquea la portada son los horarios de los nueve grupos** (días, hora de
inicio y fin, sede) cargados y mantenidos. Sin eso el bloque 2 no se puede construir, y es
el que el cliente ha pedido conservar. Es el requisito del que menos se habla y el más
crítico.

## Tokens de diseño

### Color

| Token | Hex | Uso |
|---|---|---|
| Navy | `#2E4256` | Texto principal, «Hoy en el club», cifras |
| Navy oscuro | `#141C24` | Pie, texto sobre ámbar |
| Azul acción | `#3B85C0` | Botón primario |
| Azul enlace | `#2F6FA8` | Enlaces |
| Azul claro | `#8FC0E8` | Horas y enlaces sobre navy |
| Crema | `#FBF9F4` | Fondo base y cabecera |
| Arena | `#F1EADC` | Fondo de «Qué hacemos» |
| Borde arena | `#E4DCCB` | Bordes de tarjetas |
| Borde suave | `#EFE9DC` | Separador en noticias |
| Borde sobre arena | `#E0D7C4` | Separadores en «Qué hacemos» |
| Borde cabecera | `#DCD3C0` | Píldoras de la cabecera |
| Texto cuerpo | `#4A4437` | Párrafos |
| Texto secundario | `#6E6656` | Metadatos, chevrons |
| Ámbar aviso | `#E08A18` | Franja de El Cubo |
| Gris marcador | `#A79E8B` | Solo en los marcadores de logo |

### Tipografía

Dos familias, de Google Fonts:

- **Barlow Condensed** 700 — titulares y cifras. Siempre `text-transform: uppercase`
  (excepto las cifras, que son números).
- **IBM Plex Sans** 400/500/600 — todo lo demás.

**No hay monoespaciada.** Se retiró del sistema en la portada por decisión del cliente. La
alineación de dígitos se consigue con `font-variant-numeric: tabular-nums` sobre IBM Plex
Sans, que es lo que hacen las horas de «Hoy en el club».

Regla para el resto del sitio: la monoespaciada solo puede volver **donde los dígitos se
comparan en columna** — la parrilla semanal, la tabla de tarifas y los resultados. Nunca en
etiquetas, antetítulos, importes sueltos dentro de una frase ni bandas de cifras.

| Rol | Familia | Tamaño / interlínea | Peso |
|---|---|---|---|
| Titular hero | Barlow Condensed | 46 / 0.9 | 700 |
| Título de bloque | Barlow Condensed | 25-26 / 1 | 700 |
| Título de banda (Escuelas) | Barlow Condensed | 32 / 0.96 | 700 |
| Cifra | Barlow Condensed | 30 / 1 | 700 |
| Antetítulo hero / bajada | IBM Plex Sans | 16 / 1.4-1.45 | 400 |
| Botón primario | IBM Plex Sans | 17 / 1 | 600 |
| Fila de sección | IBM Plex Sans | 17 / 1.3 | 400 |
| Fila de agenda | IBM Plex Sans | 16 / 1.35 | 400 |
| Hora | IBM Plex Sans | 16 / 1.3, tabular | 500 |
| Cuerpo | IBM Plex Sans | 15 / 1.45 | 400 |
| Titular de noticia | IBM Plex Sans | 15 / 1.3-1.35 | 400 |
| Metadato | IBM Plex Sans | 13-14 / 1.3-1.6 | 400 |
| Fecha corta | IBM Plex Sans | 12 / 1.3-1.4 | 400 |
| Etiqueta | IBM Plex Sans | 12 / 1, `ls 0.11em` | 500 |

Ningún texto baja de 12 px.

### Espaciado

Escala usada: **3 · 4 · 5 · 8 · 9 · 10 · 11 · 12 · 13 · 14 · 15 · 16 · 18 · 20 · 22 · 24 · 26 px**.
Padding lateral de página: **20 px** (18 px solo en la cabecera).
Padding vertical de bloque: **22-24 px**.

### Radios

`999px` (píldoras) · `16px` (banda de Escuelas) · `14px` (tarjetas del gancho) ·
`10px` (huecos de logo) · `8px` (miniatura de noticia).

### Sombras

**Ninguna.** Decisión explícita del cliente. Ver la nota en «Estructura».

## Assets

**Fotos**
- `assets/hero.png` — recorte de baja resolución de una captura. **Sustituir por el
  original.** Necesita un recorte vertical propio, con el tercio inferior sin nada
  importante (ahí van el titular y el botón).
- Escuelas: una foto apaisada de niños de la escuela, recorte 362×176.
- Noticias: una miniatura 76×58 (servir a 2x).
- Cuando haya páginas de sección: una vertical 3:4 por grupo, plano medio, caras
  reconocibles, en su sede y a su hora reales. Una tarde de reportaje (martes o jueves:
  Joaquín Villar 17:30 y Monte Tossal 20:00) resuelve seis de los nueve grupos.
- **Autorizaciones de imagen de los menores firmadas antes del reportaje.**

**Logos**
- Escudo del club en SVG (ahora es un círculo con borde).
- Logos de patrocinadores, en SVG o PNG con fondo transparente.

**Textos**
- El estado vacío de agosto para el bloque 2.
- Una frase por sección escrita por su entrenador, para las páginas de sección.
- Nombre real de quien contesta el WhatsApp.

## Archivos

- `Portada Apolana movil.html` — el prototipo compilado. **Abrir en el navegador para ver
  el diseño; no importar ni copiar.**
- `README.md` — este documento. Fuente de verdad de medidas, colores y copy.

## Pendiente de decidir con el cliente

1. **«Atletismo en ruta» vs «Running»** en la primera sección (ver bloque 3).
2. **Si «Club deportivo» sustituye definitivamente a «Club de atletismo»** en el antetítulo
   del hero. La última maqueta del cliente decía «Club de atletismo»; aquí está como «Club
   deportivo», que es la decisión de posicionamiento acordada.
3. **Cuántos patrocinadores hay de verdad**, para dimensionar la rejilla del bloque 9.
