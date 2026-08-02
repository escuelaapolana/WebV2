# Handoff: portada de móvil — Club Atletismo Apolana

## Resumen

Rediseño de la primera pantalla y el orden de la portada en móvil de la web del Club
Atletismo Apolana (Alicante, fundado en 1988). El objetivo, en palabras del cliente:
**que un padre o un adulto que no conoce el club entienda en diez segundos qué hacemos y
encuentre su grupo.**

El club tiene 420 atletas y 175 socios, nueve grupos y cinco deportes: escuela de
atletismo (3-17), escuela de natación, pista, running (La Tribu y Madre Tierra), natación
de adultos, triatlón, montaña, fuerza (El Cubo) y deporte adaptado.

Web actual en producción: https://escuelaapolana.github.io/apolana-club/

## Sobre los archivos de diseño

Los archivos de este paquete son **referencias de diseño hechas en HTML** — prototipos que
muestran el aspecto y el comportamiento previstos, no código de producción para copiar tal
cual. La tarea es **recrear estos diseños en el entorno del repositorio existente**
(el sitio actual es estático, servido en GitHub Pages) siguiendo sus patrones y su CSS.

En concreto: `Portada Apolana movil.html` es un archivo compilado que incluye un runtime
de previsualización propio. **No lo copiéis ni lo importéis.** Sirve para abrirlo en el
navegador y ver el diseño. Los valores exactos (medidas, colores, tipografías, copy) están
documentados abajo y son la fuente de verdad.

## Fidelidad

**Alta fidelidad.** Colores, tipografías, espaciados y copy son definitivos salvo donde se
indique. Recread la interfaz con precisión usando el CSS y los patrones del repositorio.

Dos salvedades:
- Las **fotos son marcadores** (tramas diagonales grises). El club aún no tiene el material.
- Los **datos son de ejemplo** (horarios, precios, noticias). Hay que enchufarlos a los reales.

## Decisiones de diseño — por qué la portada es así

Contexto útil, porque condiciona qué se puede tocar y qué no:

1. **La portada no es un índice de secciones.** El cliente había probado cuatro variantes
   (buscador de cuatro preguntas, rejilla de secciones con precios, fotos pequeñas con el
   nombre encima, índice de una línea) y todas se leían como «un menú más». Cualquier
   cambio que devuelva la portada a una rejilla de nueve cajas con solo un nombre dentro
   deshace el trabajo.

2. **Una fila con edad, días, sede y precio ya es una respuesta.** Es el principio que hace
   que la lista de grupos no se lea como navegación. Los cuatro datos van en la fila.

3. **No existe un bloque de precios.** El precio vive dentro de la fila de cada grupo. La
   única cifra que sale suelta es la cuota de socio, y sale como argumento («te abre
   todo»), no como tarifa.

4. **El calendario va antes que los grupos, y las noticias van al final.** El calendario
   demuestra que el club está vivo y que es ancho — cinco deportes distintos en cinco
   líneas seguidas. Una noticia solo la entiende quien ya está dentro, y además envejece.

5. **El club se presenta como club deportivo, no como club de atletismo.** Afecta al copy
   en varios sitios («5 deportes» y no «7 secciones», «club deportivo» en la línea superior).

## Pantallas

Solo hay una: la portada en móvil. Diseñada a **402 px** de ancho (iPhone 14/15/16 en CSS px).

### Estructura, en orden

| # | Bloque | Fondo | Nota |
|---|--------|-------|------|
| 0 | Cabecera | `#FBF9F4` | Logo + hamburguesa |
| 1 | Banda de aviso | `#E08A18` | Opcional, estacional |
| 2 | Foto en tarjeta | — | Con margen, **sin texto encima** |
| 3 | Titular + dos botones | `#FBF9F4` | |
| 4 | Tira de cifras | `#FBF9F4` | 420 / 5 / 38 |
| 5 | Esta semana en el club | `#FBF9F4` | El calendario |
| 6 | Entrena todo el año | `#F1EADC` | Los nueve grupos |
| 7 | Ser socio te abre todo | `#2E4256` | |
| 8 | Ven cuatro días | `#F1EADC` | |
| 9 | Noticias | `#FBF9F4` | |
| 10 | Con el apoyo de | `#FBF9F4` | Patrocinadores |
| 11 | Pie | `#141C24` | Redes, contacto, sedes, legal |

El ritmo de fondos (crema → arena → navy → arena → crema → negro) es intencionado: evita
que dos bloques seguidos se confundan entre sí. **Mantenedlo.**

La primera pantalla (los primeros ~874 px) llega hasta la tira de cifras y deja asomando
el arranque de «Esta semana en el club». Que asome es deliberado: es lo que invita a
deslizar. Si al implementarlo la primera pantalla acaba justo en un límite de bloque,
ajustad para que se vea el borde del siguiente.

---

### 0 · Cabecera

- Alto 56 px, padding lateral 20 px, `display:flex`, `justify-content: space-between`.
- Izquierda: escudo circular 30 px (`border: 1.5px solid #2E4256`, sustituir por el escudo
  real) + «APOLANA» en Barlow Condensed 700, 20 px, `text-transform: uppercase`,
  `letter-spacing: 0.02em`, color `#2E4256`. Gap 10 px.
- Derecha: botón hamburguesa 40×40 px (cumple los 44 px de área táctil con el padding),
  tres barras de 22×2 px, `#2E4256`, gap 6 px.

### 1 · Banda de aviso (condicional)

- Contenedor con `padding: 4px 20px 0`.
- Caja `background: #E08A18`, `border-radius: 12px`, `padding: 13px 16px`, flex, gap 12 px.
- Etiqueta «AVISO»: IBM Plex Mono 500, 11 px, `letter-spacing: 0.1em`,
  `color: rgba(255,255,255,0.85)`.
- Texto: IBM Plex Sans 400, 15px/1.35, blanco.
- Copy actual: «Inscripción de la escuela abierta hasta el 7 de agosto».
- **Se oculta entera cuando no hay aviso vigente.** No dejar la banda vacía.

### 2 · Foto en tarjeta

- Contenedor `padding: 14px 20px 0`.
- Imagen: alto 196 px, ancho completo (362 px), `border-radius: 12px`, `overflow: hidden`,
  `object-fit: cover`.
- **La foto no lleva texto ni degradado encima.** Es la decisión que hace que se vea
  limpia y que funcione incluso con una foto mediocre. No convertirla en hero a sangre.

### 3 · Titular y botones

Contenedor `padding: 16px 20px 0`, `display:flex; flex-direction: column; gap: 11px`.

- Antetítulo: IBM Plex Mono 500, 12px/1.4, `letter-spacing: 0.09em`, color `#2F6FA8`.
  Copy: `CLUB DEPORTIVO · ALICANTE · 1988`
- Titular: Barlow Condensed 700, 40px/0.92, `text-transform: uppercase`, color `#2E4256`.
  Copy: «Aquí siempre hay alguien entrenando»
- Bajada: IBM Plex Sans 400, 15px/1.45, color `#4A4437`.
  Copy: «Correr, pista, nadar, montaña y fuerza. Entras por uno y los tienes todos.»
- Botones apilados, gap 10 px, alto 52 px, `border-radius: 999px`, texto IBM Plex Sans 500, 16 px:
  - Primario: `background: #3B85C0`, texto blanco. «Prueba 4 días gratis»
  - Secundario: `border: 1.5px solid #B9CFE2`, texto `#2F6FA8`, fondo transparente.
    «Encuentra tu grupo» → ancla al bloque 6.

### 4 · Tira de cifras

- `margin-top: 16px`, `padding: 15px 20px`, `border-top: 1px solid #E4DCCB`,
  `display:flex; justify-content: space-between`. Tres columnas: izquierda, centrada, derecha.
- Cifra: Barlow Condensed 700, 27px/1, `#2E4256`.
- Etiqueta: IBM Plex Mono 500, 11px/1, `letter-spacing: 0.08em`, `#6E6656`, `margin-top: 3px`.
- Contenido: **420 ATLETAS · 5 DEPORTES · 38 AÑOS**.
- «5 DEPORTES» es deliberado (antes ponía «7 SECCIONES»): sección es palabra de dentro del
  club, deportes es lo que busca quien no lo conoce. **El 38 se calcula desde 1988**, no
  hardcodear.

### 5 · Esta semana en el club

Contenedor `padding: 20px 20px 18px`, gap 11 px.

- Cabecera de bloque: título Barlow Condensed 700, 24px/1, uppercase, `#2E4256`; a la
  derecha «Todo» en IBM Plex Sans 400, 14 px, `#2F6FA8`, alineados por `baseline`.
- Subtítulo: IBM Plex Sans 400, 14px/1.45, `#6E6656`.
  Copy: «Entrenes lo que entrenes, puedes ir a cualquiera de estas.»
- Tarjeta: `background: #fff`, `border: 1px solid #E4DCCB`, `border-radius: 14px`,
  `overflow: hidden`. Filas separadas por `border-bottom: 1px solid #EFE9DC` (la última sin).
- Cada fila: `padding: 12px 14px`, flex, gap 12 px, `align-items: center`.
  - Columna izquierda, 48 px fija, centrada:
    - Día: IBM Plex Sans 400, 12px/1.2. `#6E6656`, o **`#B96F09` si es hoy** (y la palabra
      pasa a ser «hoy»).
    - Hora: IBM Plex Mono 500, 17px/1.25, `#2E4256`.
  - Columna derecha:
    - Título: IBM Plex Sans 400, 15px/1.3, `#2E4256`.
    - Debajo, `margin-top: 3px`, flex gap 7 px:
      - Chip de deporte: `padding: 3px 8px`, `border-radius: 999px`,
        `background: #F1EADC`, IBM Plex Sans 400, 12px/1.3, `#6E6656`.
      - Modo de acceso, IBM Plex Sans 400, 13px/1.3, con color semántico:
        - `ven y ya` → `#3F7A4C` (verde)
        - `con bono · N plazas` → `#2F6FA8` (azul) — **solo El Cubo**, que es lo único con
          reserva real
        - `avisa antes · coches` → `#B96F09` (ámbar) — montaña

**Regla importante:** este bloque vende *permiso*, no plazas. Salvo El Cubo, no hay
sistema de reservas y no debe haberlo en la interfaz. «Ven y ya» es información, no un
botón.

**Falta por decidir en el club (no en el código):** qué es exactamente «ven y ya» para
alguien de otra sección. Si un corredor aparece un miércoles en Monte Tossal, ¿puede
meterse a la calle? Hasta que eso esté claro, no publicar la promesa.

**Estado vacío obligatorio.** En agosto, Navidad o si falla el dato, este bloque no puede
quedar en blanco. Texto de reserva: «La temporada arranca el 8 de septiembre» + enlace al
calendario completo.

### 6 · Entrena todo el año

`padding: 20px`, `background: #F1EADC`, gap 12 px.

- Título: Barlow Condensed 700, 24px/1, uppercase, `#2E4256`.
- Subtítulo: IBM Plex Sans 400, 14px/1.45, `#6E6656`.
  Copy: «Nueve grupos con entrenador y plan. Esto es lo que buscas si vienes a quedarte.»
- Filtros (chips), flex gap 8 px, `padding: 9px 15px`, `border-radius: 999px`,
  IBM Plex Sans 400, 14 px:
  - Activo: `background: #2E4256`, texto blanco.
  - Inactivo: `border: 1px solid #D4CBB9`, texto `#4A4437`, fondo transparente.
  - Opciones: Todos / Niños / Adultos. Filtran la lista en cliente.
- Filas de grupo: `padding: 13px 0`, `border-bottom: 1px solid #E0D7C4` (la última sin),
  flex gap 12 px, `align-items: baseline`.
  - Izquierda (flex:1): nombre en IBM Plex Sans 400, 15px/1.3, `#2E4256`; debajo
    (`margin-top: 3px`) la línea de datos en IBM Plex Sans 400, 13px/1.3, `#6E6656`,
    con formato `edad · días · sede`.
  - Derecha: precio en IBM Plex Mono 500, 15px/1, `#2E4256`.

Contenido actual (datos de ejemplo — sustituir por los reales):

| Grupo | Línea de datos | Precio |
|---|---|---|
| Escuela de atletismo | 3 a 17 años · L X V · J. Villar | 2 pagos |
| Escuela de natación | 5 a 16 años · M J · M. Tossal | 35 € |
| Pista · competición | desde 14 años · 3 o 5 días | 40 € |
| La Tribu · running | adultos · M J S · Explanada | 60 € |
| Madre Tierra · running | adultos · empezar a correr | 40 € |
| Natación de adultos | bonos de 4, 8 o 12 · M. Tossal | 35 € |
| El Cubo · fuerza | adultos · bonos · El Cubo | 40 € |
| Montaña | adultos · salidas de fin de semana | 0 € |
| Triatlón · deporte adaptado | arrancan en septiembre · avísame | *(sin precio)* |

Triatlón y adaptado van juntos en una fila **solo mientras no tengan horario**. Cuando lo
tengan, se separan en dos filas normales. Nunca poner guiones ni «próximamente» a secas:
la fila lleva un enlace de aviso.

### 7 · Ser socio te abre todo

`padding: 22px 20px`, `background: #2E4256`, gap 13 px.

- Título: Barlow Condensed 700, 24px/1, uppercase, blanco.
- Texto: IBM Plex Sans 400, 15px/1.5, `rgba(255,255,255,0.85)`.
  Copy: «120 € al año. No es la cuota del atletismo: es la del club. Entras por un deporte
  y puedes ir a los cinco.»
- Lista, gap 9 px, cada ítem flex gap 10 px: bullet `·` en `#8FC0E8`, texto IBM Plex Sans
  400, 15px/1.4, blanco.
  - Todas las quedadas y salidas abiertas
  - Licencia federativa y seguro
  - Segundo adulto de la familia, −10 %

Va justo detrás de los grupos porque es ahí donde surge la pregunta del precio total. El
propósito es convertir los 120 € de peaje en llave — importa porque hay 420 atletas y solo
175 socios.

### 8 · Ven cuatro días antes de decidir

`padding: 22px 20px`, `background: #F1EADC`, gap 12 px.

- Título Barlow Condensed 700, 24px/1, uppercase, `#2E4256`.
- Texto IBM Plex Sans 400, 15px/1.5, `#4A4437`: «Cuatro entrenamientos gratis con el grupo
  que elijas. Sin pagar nada y sin compromiso.»
- Botón alto 52 px, `border-radius: 999px`, `background: #3B85C0`, texto blanco IBM Plex
  Sans 500, 16 px: «Reservar mi prueba».
- Debajo, centrado, IBM Plex Sans 400, 15px/1, `#2F6FA8`: «O escribe a Marta por WhatsApp».
  **Poner un nombre real y una cara ayuda; un número suelto no da confianza.**

### 9 · Noticias

`padding: 20px`, gap 14 px.

- Cabecera igual que el bloque 5 («Noticias» + «Ver todas»).
- Dos entradas, cada una flex gap 14 px, `align-items: flex-start`:
  - Miniatura 88×66 px, `border-radius: 10px`, `object-fit: cover`.
  - Fecha: IBM Plex Sans 400, 13px/1.3, `#6E6656`.
  - Titular: IBM Plex Sans 400, 15px/1.35, `#2E4256`, `margin-top: 4px`.

Van al final a propósito. No subirlas.

### 10 · Con el apoyo de

`padding: 22px 20px`, `background: #FBF9F4`, `border-top: 1px solid #E4DCCB`, gap 14 px.

- Etiqueta: IBM Plex Mono 500, 11px/1, `letter-spacing: 0.1em`, `#6E6656`. «CON EL APOYO DE».
- Rejilla 2×2, gap 12 px. Cada hueco: alto 56 px, `background: #fff`,
  `border: 1px solid #E4DCCB`, `border-radius: 10px`, logo centrado con `object-fit: contain`
  y padding interior.
- Enlace: IBM Plex Sans 400, 14px/1.4, `#2F6FA8`. «¿Quieres patrocinar al club? →»

Va sobre fondo claro **a propósito**: los logos de terceros casi siempre vienen sobre
blanco y en navy se ven sucios. El número de huecos debe ajustarse a los patrocinadores
reales; si son muchos, separar «principales» de «colaboradores» en dos filas con tamaños
distintos.

### 11 · Pie

`padding: 24px 20px 32px`, `background: #141C24`, gap 18 px.

- Escudo 28 px (`border: 1.5px solid #fff`) + «APOLANA» Barlow Condensed 700, 20 px,
  uppercase, `letter-spacing: 0.02em`, blanco.
- Redes: texto IBM Plex Sans 400, 15px/1.4, `rgba(255,255,255,0.85)` — «Síguenos, ahí
  ponemos las fotos de cada entreno» — y debajo tres píldoras en fila (gap 10 px, `flex: 1`
  cada una), alto 46 px, `border: 1px solid rgba(255,255,255,0.28)`, `border-radius: 999px`,
  texto blanco IBM Plex Sans 400, 14 px: Instagram, Facebook, Strava.
  **La frase es el argumento; tres iconos sueltos no los pulsa nadie.**
- Separador `border-top: 1px solid rgba(255,255,255,0.16)`, `padding-top: 16px`, gap 10 px:
  - Contacto, IBM Plex Sans 400, 14px/1.6, `rgba(255,255,255,0.7)`.
  - Sedes, mismo estilo: «Dónde entrenamos: Estadio Joaquín Villar · Piscina Monte Tossal ·
    El Cubo · Explanada».
  - Legal, 13px/1.5, `rgba(255,255,255,0.58)`: «Aviso legal · Privacidad · Protección del menor».
    *(La opacidad es 0.58 y no menos por contraste AA — no bajarla.)*

## Interacciones y comportamiento

- **Chips de filtro** (bloque 6): filtrado en cliente, sin recarga. Estado activo = fondo
  `#2E4256`. Por defecto «Todos».
- **Filas de grupo**: toda la fila es enlace a la página del grupo.
- **Filas del calendario**: toda la fila es enlace al grupo o al evento.
- **«Encuentra tu grupo»**: ancla al bloque 6 con scroll suave.
- **Banda de aviso**: se renderiza solo si hay aviso con fecha de caducidad futura.
- **Hover** (para tablet/escritorio): oscurecer el primario a `#2F6FA8`; en filas,
  `background: rgba(46,66,86,0.04)`.
- **Área táctil mínima 44 px** en todo lo pulsable. Las filas del calendario y de grupos ya
  la superan; vigilad los chips de filtro (38 px de alto — subir a 44 px si se implementan
  como botones).
- **Responsive**: el diseño es de móvil. A partir de ~720 px el contenido debe pasar a dos
  columnas o quedar centrado con ancho máximo; no estirar las filas a 1200 px.

## Estado y datos

Datos que la portada necesita, con su origen:

| Dato | Uso | Nota |
|---|---|---|
| Aviso vigente (texto + caducidad) | Bloque 1 | Opcional |
| Sesiones de la semana | Bloque 5 | día, hora, título, deporte, sede, modo de acceso, plazas |
| Los nueve grupos | Bloque 6 | nombre, edades, días, sede, precio, público (niños/adultos) |
| Noticias | Bloque 9 | dos últimas |
| Patrocinadores | Bloque 10 | logo + enlace |

**El dato que bloquea todo son los horarios de los nueve grupos** (días, hora de inicio y
fin, sede) cargados y mantenidos. Sin eso los bloques 5 y 6 no se pueden construir. Es el
requisito del que menos se habla y el más crítico.

## Tokens de diseño

### Color

| Token | Hex | Uso |
|---|---|---|
| Navy | `#2E4256` | Texto principal, bloque de socio, chips activos |
| Navy oscuro | `#141C24` | Pie |
| Azul acción | `#3B85C0` | Botones primarios |
| Azul enlace | `#2F6FA8` | Enlaces, «con bono» |
| Azul claro | `#8FC0E8` | Bullets y enlaces sobre navy |
| Azul borde | `#B9CFE2` | Borde del botón secundario |
| Crema | `#FBF9F4` | Fondo base |
| Arena | `#F1EADC` | Fondo de bloques alternos, chips de deporte |
| Borde arena | `#E4DCCB` | Bordes de tarjetas |
| Borde suave | `#EFE9DC` | Separadores dentro de tarjeta blanca |
| Borde sobre arena | `#E0D7C4` | Separadores en el bloque 6 |
| Borde chip | `#D4CBB9` | Chips inactivos |
| Texto cuerpo | `#4A4437` | Párrafos |
| Texto secundario | `#6E6656` | Metadatos, etiquetas |
| Ámbar aviso | `#E08A18` | Banda de aviso |
| Ámbar acento | `#B96F09` | «hoy», «avisa antes» |
| Verde acceso | `#3F7A4C` | «ven y ya» |

### Tipografía

Dos familias, de Google Fonts:

- **Barlow Condensed** 600/700 — titulares y cifras. Siempre `text-transform: uppercase`.
- **IBM Plex Sans** 400/500/600 — todo el texto corrido.
- **IBM Plex Mono** 400/500 — horas, precios, etiquetas con `letter-spacing`.

| Rol | Familia | Tamaño / interlínea | Peso |
|---|---|---|---|
| Titular hero | Barlow Condensed | 40 / 0.92 | 700 |
| Título de bloque | Barlow Condensed | 24 / 1 | 700 |
| Cifra | Barlow Condensed | 27 / 1 | 700 |
| Bajada | IBM Plex Sans | 15 / 1.45 | 400 |
| Cuerpo | IBM Plex Sans | 15 / 1.5 | 400 |
| Fila principal | IBM Plex Sans | 15 / 1.3 | 400 |
| Metadato | IBM Plex Sans | 13 / 1.3 | 400 |
| Botón | IBM Plex Sans | 16 / 1 | 500 |
| Hora, precio | IBM Plex Mono | 17 / 1.25 y 15 / 1 | 500 |
| Antetítulo | IBM Plex Mono | 12 / 1.4, `ls 0.09em` | 500 |
| Etiqueta | IBM Plex Mono | 11 / 1, `ls 0.08-0.1em` | 500 |

Ningún texto baja de 12 px, y solo en etiquetas.

### Espaciado

Escala usada: **3 · 4 · 6 · 7 · 8 · 10 · 11 · 12 · 13 · 14 · 16 · 18 · 20 · 22 · 24 px**.
Padding lateral de página: **20 px**. Padding vertical de bloque: **20-22 px**.

### Radios

`999px` (píldoras y chips) · `14px` (tarjetas) · `12px` (foto, aviso) · `10px`
(miniaturas, huecos de logo) · `6px`.

### Sombras

Ninguna. El diseño separa por color de fondo y por borde de 1 px, no por elevación.

## Assets

Todas las imágenes del prototipo son **marcadores** (tramas diagonales grises con una nota
de qué va ahí). Material que hace falta antes de publicar:

**Fotos**
- Una foto apaisada para el hero. Va en tarjeta y sin texto encima, así que no necesita
  zona muerta — pero sí tiene que aguantar recorte a 362×196.
- Dos miniaturas de noticia, 88×66 mínimo (servir a 2x).
- Cuando haya páginas de grupo: una vertical 3:4 por grupo, plano medio, caras
  reconocibles, en su sede y a su hora reales.
- Una tarde de reportaje (martes o jueves: Joaquín Villar 17:30 y Monte Tossal 20:00)
  resuelve seis de los nueve grupos.
- **Autorizaciones de imagen de los menores firmadas antes del reportaje.**

**Logos**
- Escudo del club en SVG (ahora es un círculo con borde).
- Logos de patrocinadores, preferiblemente SVG o PNG con fondo transparente.

**Textos**
- Una frase por grupo escrita por su entrenador («¿qué le dirías a alguien que se lo está
  pensando?», máximo veinte palabras). Las del prototipo están inventadas y no se publican.
- El estado vacío de agosto para el bloque 5.
- Nombre real de quien contesta el WhatsApp.

## Archivos

- `Portada Apolana movil.html` — el prototipo compilado. **Abrir en el navegador para ver
  el diseño; no importar ni copiar.** Es un archivo autocontenido con un runtime de
  previsualización dentro.
- `README.md` — este documento. Es la fuente de verdad de medidas, colores y copy.

## Tres cosas que el cliente aún no ha decidido

1. **Si el botón secundario «Encuentra tu grupo» se queda.** Con la lista a un dedo de
   distancia puede sobrar, y un solo botón azul pega más fuerte. Fácil de probar.
2. **Si la cuota de socio debe aparecer también en el hero**, en letra pequeña bajo los
   botones. Ahora mismo un adulto ve «60 €» en La Tribu y descubre los 120 € tres pantallas
   más abajo.
3. **Cuántos patrocinadores hay de verdad**, para dimensionar la rejilla del bloque 10.
