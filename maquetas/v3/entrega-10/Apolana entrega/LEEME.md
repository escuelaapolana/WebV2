# Apolana · lo que hemos decidido

Paquete de entrega para desarrollo e imprenta. Siete cosas dentro, en este orden:

0. **Logo** — los originales del club
1. **Portada de móvil** — el diseño y su documentación
2. **Mapa del sitio** — qué páginas hay, qué hace cada una, qué se cae
3. **Icono de la app** — el SVG y las notas de exportación
4. **Avisos y pagos** — dos pantallas de la app
5. **Formularios de alta** — inscripción, renovación, socio y SEPA, en web y app
6. **El panel** — diez pantallas, la barra única y las seis piezas compartidas
7. **Apuntar el entreno** — la zona del atleta: fuerza, pista y natación

---

## 0 · Logo

**Carpeta:** `0-logo/`

| Archivo | Qué es | Para qué |
|---|---|---|
| `Logo Apolana vectorizado.pdf` | PDF/X de Illustrator, vectorial | **El máster.** Imprenta y cualquier reproducción grande |
| `Logo Apolana.svg` | El mismo, convertido a SVG | Web y pantalla |
| `Logo Apolana.png` | Ráster | Vistas rápidas, nada más |
| `Logo Apolana natacion.png` | Variante de sección | Página de Natación |
| `Logo Apolana fitness.png` | Variante de sección | Página de Fuerza / El Cubo |

**Azul de marca: `#2E81BE`.** Leído del SVG vectorial. Los hex sacados de los PNG no son
fiables. El PDF lleva perfil CMYK (Coated FOGRA39): para imprenta, pedir el CMYK o el
Pantone exacto a quien hizo el original.

**Falta:** las variantes de Natación y Fitness solo existen en PNG. Para usarlas en la web
o en camisetas hay que vectorizarlas igual que la principal.

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

## 4 · Avisos y pagos

**Archivos:** `4-avisos-y-pagos/README.md` · `4-avisos-y-pagos/Avisos y pagos Apolana.html`

Dos pantallas de la app. El README de esa carpeta lleva el detalle; lo esencial:

**Avisos — tres niveles, y el rojo casi nunca.**

| Nivel | Color | Cuándo |
|---|---|---|
| Informativo | gris azulado `#6E8CA6` | Novedades y crónicas. La mayoría. |
| Importante | ámbar `#E08A18` | Cambia tu plan de esta semana. **El de diario.** |
| Grave | rojo `#B3261E` | Seguridad y nada más. Solo la junta. |

El `#FBECEB` se queda, pero solo para grave: el problema no era el tono, era que se usaba
para todo. El color nunca va solo — siempre lleva la palabra.

Otras decisiones: **sin tarjeta navy** para el aviso (el navy es para bloques de una línea,
no para texto que hay que leer); **la fecha arriba**, con el tipo y el remitente; **nuevo
vs. leído** es el mismo diseño con punto, negrita y fondo, no dos tarjetas; **los
caducados no se borran**, se tachan y pasan a «Ya pasó».

Tres cosas por decidir fuera del diseño: quién puede enviar cada nivel, qué avisos suenan
en el móvil, y que quien envía ponga fecha de caducidad — sin ese dato «Ya pasó» no se
puede calcular.

**Pagos — cinco pantallas.** Elegir → confirmar → vuelta → fallo → estado sin Stripe. La
regla: en cada pantalla se ve qué se compra y cuánto cuesta, incluida la de error. «Los
gastos los paga el club» va en verde y sin importe, porque es una buena noticia y no una
línea de factura. El error de pago es **ámbar, no rojo** — misma regla que los avisos — y
lo primero que se lee es «no se te ha cobrado nada». Mientras no haya Stripe, el botón de
tarjeta se ve apagado y la vía real es WhatsApp.

---

## 5 · Formularios de alta

**Archivos:** `5-formularios-de-alta/README.md` · `5-formularios-de-alta/Formularios de alta Apolana.html`

Es el documento más completo del paquete y el que hay que leer entero antes de programar.
Cuatro flujos: inscripción a la escuela, renovación, alta de socio y domiciliación SEPA.
Con maquetas de móvil y de escritorio.

Las decisiones tomadas, en corto:

- **El SEPA se firma en pantalla con el dedo.** No hay vía de imprimir. El PDF se genera
  después como justificante.
- **El IBAN se pide en la inscripción pero es opcional**, con la salida escrita. Un hueco
  vale más que unos ceros inventados.
- **Las tres autorizaciones van dentro**, ningún PDF aparte. La de imagen con dos botones,
  no con casilla: no se puede exigir.
- **Hermanos:** un formulario, un pagador, varios niños. Solo se repite el bloque del niño.
- **Renovar es confirmar:** tres respuestas, no veinte campos.
- **El alta de socio parte en dos:** ser socio y federarse son cosas distintas.
- **La franja horaria la decide el año de nacimiento**, no se elige. Los cuatro turnos no se
  enseñan nunca.
- **El grupo se marca como provisional** y el club avisa cuando es definitivo. Las listas
  que había que consultar a mano desaparecen.

**El botón primario pasa a `#2F72AB`** en estas pantallas, por contraste. Está pendiente
aplicarlo también en las carpetas 1 a 4.

**CIF correcto: `G-03845500`.** El SEPA actual lo tiene mal.

---

## 6 · El panel

**Archivos:** `6-panel/README.md` · `6-panel/Panel Apolana.html`

Diez pantallas rehechas, la navegación unificada y **seis piezas compartidas**.

El diagnóstico, dicho con precisión: **no sobra información, sobra información a la vez.**
Lo que no se usa ahora va **plegado, no ausente**.

**Lo primero son las seis piezas** — cabecera de pantalla, barra de filtros, fila de tabla,
ficha de móvil, campo y plegable, franja de guardado — dibujadas con sus medidas. Es la
única cosa en la que contradigo el encargo: sin una hoja común, las reglas hay que aplicarlas
55 veces a mano y se deshacen. No hay que refactorizar las 55: basta extraer seis piezas y
usarlas en las diez que se van a tocar.

Las siete reglas, en corto: una acción principal y arriba · nada apagado en primer plano ·
cada número se dice una vez · los mandos nunca antes del dato · la tabla en móvil es ficha ·
la ayuda junto al campo y plegada · **si algo tiene más de seis campos o su propio guardar, es
una pantalla**.

**La barra única:** logo (que es «ir a la web») y, a la derecha, solo dos controles — la
píldora del papel y el avatar. Cada papel dice de qué: «Entrenador · Verde 1 y 2». Si solo
tienes un papel, la píldora no aparece.

**Las tarjetas azules en degradado:** aquí es donde funcionan, pero **una sola por pantalla y
solo para lo que pasa hoy**.

**Incluye el historial de entrenamientos** (turno 3 del archivo, arriba): la lista del atleta
con su resumen de carga, el detalle al tocar uno, y el del entrenador — que no es una pantalla,
es «Planificar semana» andando hacia atrás. La puerta es el grupo **ENTRENAMIENTO** que ya
estaba en `maquetas-app.md`, traído a móvil como conmutador de tres: **sin sexta pestaña y sin
«Más»**.

---

## 7 · Apuntar el entreno

**Archivos:** `7-apuntar-entreno/README.md` · `7-apuntar-entreno/Apuntar entreno Apolana.html`

Las seis piezas que faltaban en la zona del atleta. Todas viven en la misma pantalla, así que
la primera manda: **si la fila del ejercicio está bien, las otras cinco son partes de ella.**

Lo decidido:

- **Escribir siempre gana.** Campo de texto libre; las sugerencias ayudan y nunca cierran.
- **La fila sabe de qué deporte habla:** fuerza lleva Reps · Kg · RIR; pista, Distancia ·
  Tiempo · Descanso; natación, Metros · Tiempo, y el material en chips.
- **Los rangos se quedan como rangos.** «35-45 min» se muestra tal cual y **nunca** se rellena
  la casilla con la media.
- **El plan en vuestra notación:** `3×8×60 kg (RIR 2)`.
- **El arrastre en gris** es lo que hace que la app se use: la serie siguiente viene rellenada
  con lo de la anterior y se guarda si no la tocas.
- **El RIR va por serie**, en columna estrecha, con teclado de 0 a 4.
- **«Lo cambié»** enseña lo planificado tachado y lo hecho como título — el historial deja de
  mentir.
- **«Añadir al banco»** aparece después de apuntar, discreto y perfilado.

Hace falta del club: **los 193 ejercicios con su bloque y su unidad**, quién aprueba lo que
entra en el banco, y el catálogo de material de natación.

---

## Un cabo suelto, decidid vosotros

**El azul de los botones.** En las carpetas 5 y 6 el primario es `#2F72AB`; en las carpetas 1 a
4 sigue el anterior, que **no pasa contraste con texto blanco**. Lo suyo es unificar todo a
`#2F72AB` — pedidlo y se hace de una pasada, o aplicadlo directamente al implementar.

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

**Logos.** El escudo ya está en `0-logo/`. Faltan los logos de los patrocinadores en SVG o
PNG transparente, y vectorizar las variantes de Natación y Fitness.

## Tres cosas sin decidir

1. **Si «Club deportivo» sustituye a «Club de atletismo»** en el antetítulo del hero.
2. **Cuántos patrocinadores hay**, para dimensionar la rejilla.
3. **El CMYK o Pantone exacto** del azul, para imprenta.

## Ya decidido

- **«Running»**, no «Atletismo en ruta».
- **Redes: Facebook, TikTok, Instagram y WhatsApp.** Fuera Strava. Al ser cuatro, en el pie
  van en dos filas de dos.
- **Sin monoespaciada.** Solo vuelve donde los dígitos se comparan en columna: parrilla
  semanal, tarifas y resultados.

## Cómo usar los HTML

Los archivos `.html` son prototipos: se abren con doble clic en cualquier navegador y
funcionan sin conexión. **No son código de producción** — llevan dentro el motor de
previsualización. Sirven para ver el diseño; los valores exactos están en los README.

La portada está diseñada a 402 px de ancho, así que en una pantalla grande sale una
columna estrecha centrada. En un móvil ocupa todo.
