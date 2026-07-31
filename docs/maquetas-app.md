# Maquetas de la app y los portales · especificación

Documento de referencia extraído de las maquetas originales de diseño. Recoge, pantalla por
pantalla, lo que el diseño pide: estructura, textos literales, campos, controles y comportamiento.
Sirve como especificación para rehacer las pantallas.

**Ficheros de origen**

| Fichero | Contenido |
| --- | --- |
| `maquetas/originales-design/App Apolana movil.dc.html` (= `maquetas/app.html`) | Pantallas de móvil: acceso y roles (19b), marcas (15a), clases y bonos (11a), entrenador (11b), home e inscripción en móvil (8a, 8b), estados vacíos (8e) |
| `maquetas/originales-design/App Apolana.dc.html` (= `maquetas/diseno-completo.html`) | Documento completo. Contiene además «hoy», «entreno y feedback con ritmos» (1a, 1b, 1c), el calendario (4c), el mapa de roles (19a), Familia Apolana (19c) y los cuatro paneles privados de escritorio (5a-5d) |

Nota de lectura: en la maqueta, cada bloque lleva una etiqueta corta (`19b`, `15a`, `11a`…) que
identifica el turno de diseño. Se conservan esas etiquetas aquí para poder ir a la maqueta y
comprobar cualquier detalle.

---

## Sistema visual común

- **Tipografías**: `Archivo` (titulares, pesos 500/700/800/900), `Barlow Condensed` (títulos
  condensados dentro de las pantallas de móvil), `IBM Plex Sans` (texto corriente),
  `JetBrains Mono` (etiquetas en versalitas, cifras, códigos).
- **Fondos**: crema `#EFE9DC`, `#F5F0E6`, `#F1EADC`, `#FBF9F4`; blanco para el contenido.
- **Azules**: azul del escudo `#2E4256` (texto y cabeceras), azul de acción `#2F6FA8` y `#3B85C0`
  (botones e interruptores activos), azul muy claro `#EAF2F9` y borde `#C9D9E7` para cajas de aviso.
- **Marrones y bordes**: `#7A7365`, `#6B6558`, `#5E5849` (texto secundario), `#EFE9DC`, `#E4DCCB`,
  `#E0D8C8`, `#DCD2BF` (bordes y separadores).
- **Estados**: verde `#7FBF4A` y `#4C7A28` sobre `#EDF7E4` (hecho, apuntado, récord), ámbar
  `#B96F09` sobre `#FDF3DD` (pendiente, nuevo, aviso), rojo `#A8453F` (falta, impago, baja).
- **Formas**: tarjetas blancas con borde de 1 px crema y radio 12-16 px; botones de radio grande
  (píldora) en las acciones principales; interruptores de 42×24 px (azul `#3B85C0` encendido,
  `#DCD2BF` apagado).
- **Regla de color**: crema de fondo, blanco para el contenido y **azul solo para acciones**.

---

# Bloque 1 · Acceso, roles y perfiles

## 1.1 · Roles y qué ve cada uno (`19a`)

**Propósito**: definir el reparto de permisos. Un acceso único que reparte; nada se mezcla.

Seis tarjetas en fila, cada una con una franja de color arriba, la etiqueta en versalitas y una
línea de descripción:

| Etiqueta | Título | Qué ve |
| --- | --- | --- |
| SIN CUENTA | Visitante | Noticias, calendario, secciones, campus e inscripción. |
| ROL 1 | Atleta | Su entreno, feedback, marcas, clases y bono. |
| ROL 2 | Familia | Ficha de sus hijos, faltas, pagos y tienda. |
| ROL 3 | Entrenador | Sus grupos: planificar, pasar lista y leer feedback. |
| ROL 4 | Coordinador | Todos los grupos de su sección y sus técnicos. |
| ROL 5 | Administración | Cobros, contenido web, estadísticas y usuarios. |

Debajo, tres notas de comportamiento con encabezado en versalitas:

- **CÓMO SE CREA LA CUENTA** — «Al terminar la inscripción se crea sola con el rol que toca y llega
  un correo para poner contraseña. Nadie da de alta usuarios a mano salvo técnicos y junta.»
- **MENORES** — «Por debajo de 14 años la cuenta es de la familia. A partir de ahí el atleta tiene
  la suya y la familia sigue viendo pagos y asistencia, no su feedback.»
- **VARIOS ROLES A LA VEZ** — «Un entrenador que además entrena y tiene un hijo en la escuela usa un
  solo correo y cambia de panel desde su avatar, sin cerrar sesión.»

## 1.2 · Acceso, alta y cambio de perfil (`19b`)

Tres pantallas de móvil: entrada, credenciales recién creadas y selector de perfil.

### Pantalla A · Entrar

De arriba abajo:

1. Logotipo pequeño «Apolana» centrado.
2. Titular condensado a dos líneas: **CLUB APOLANA**.
3. Subtítulo: «Entra con tu cuenta o mira el club sin registrarte.»
4. Formulario:
   - Campo **Email** — valor de ejemplo `marta.ripoll@email.com`.
   - Campo **Contraseña** — valor `••••••••`.
   - Botón principal azul a todo el ancho: **Entrar**.
   - Enlace de texto centrado: **He olvidado la contraseña**.
5. Separador con texto en versalitas: **O SIN CUENTA**.
6. Tres filas-enlace con chevron `›` a la derecha, en tarjetas blancas apiladas:
   - «Noticias y calendario del club»
   - «Grupos, horarios y precios»
   - «Probar cuatro entrenamientos»
7. Pie de la pantalla: «¿Aún no estás en el club?» + botón secundario **Inscribirme**.

Comportamiento: la misma pantalla sirve a los cinco roles y reparte a cada uno a su panel. El
bloque «sin cuenta» permite entrar en modo público.

### Pantalla B · Ya tenéis vuestras cuentas

Pantalla de confirmación tras la inscripción de una familia.

1. Icono circular de comprobación `✓`.
2. Titular condensado a dos líneas: **YA TENÉIS / VUESTRAS CUENTAS**.
3. Párrafo: «Hemos enviado un correo a cada uno para que ponga su contraseña. Caduca en 72 horas.»
4. Encabezado en versalitas: **CUENTAS CREADAS**. Lista de tres tarjetas, cada una con avatar de
   iniciales, nombre, línea secundaria y etiqueta de rol a la derecha:
   - `MR` · **Marta Ripoll** · `marta.ripoll@email.com` — etiqueta **FAMILIA**
   - `PR` · **Pau Ripoll · 11 años** · «Sin cuenta propia hasta los 14» — etiqueta **MENOR**
   - `JR` · **Jorge Ripoll** · `jorge.r@email.com · La Tribu` — etiqueta **ATLETA**
5. Caja de aviso en crema con título **Cada uno ve lo suyo** y texto: «Tú ves pagos, faltas y ficha
   de tus hijos. Jorge ve su entreno y sus marcas. Nadie ve lo del otro.»
6. Botón principal azul: **Entrar como familia**.
7. Pie en gris: «¿No os llega el correo? Revisad spam o pedidlo de nuevo.»

### Pantalla C · Cambiar de perfil

Hoja modal sobre la app, con **Cerrar** arriba a la derecha.

1. Título condensado: **CAMBIAR DE PERFIL**.
2. Lista de perfiles del mismo usuario. El activo va recuadrado en azul con `✓`; los demás con
   chevron `›`:
   - `NT` · **Entrenador** · «La Tribu, fondo y El Cubo» — activo `✓`
   - `NT` · **Atleta** · «Tus entrenos y tus marcas» — `›`
   - `NT` · **Familia** · «Nora, escuela · benjamín» — `›`
3. Encabezado en versalitas: **AVISOS QUE QUIERES RECIBIR**. Cinco filas con interruptor:

   | Aviso | Estado en la maqueta |
   | --- | --- |
   | Entreno publicado | encendido |
   | Suspensión por lluvia | encendido |
   | Recibo cobrado | encendido |
   | Noticias del club | **apagado** |
   | Plaza libre en El Cubo | encendido |

4. Dos acciones al final, como filas de texto: **Cambiar contraseña** y **Cerrar sesión**.

Comportamiento: se cambia de panel desde el avatar, sin cerrar sesión.

---

# Bloque 2 · Hoy, entreno y feedback

El diseño ofrece **tres direcciones visuales** para la misma app y el mismo contenido; cada una
muestra la pantalla de inicio del atleta y una segunda pantalla que enseña cómo se comporta el
sistema. El texto de la maqueta pide elegir una (`1a`, `1b` o `1c`) para desarrollarla a fondo.

## 2.1 · Dirección A — «Club», clara y de confianza (`1a`)

Descripción de la maqueta: «Fondo crema, azul del escudo, titulares condensados. Lenguaje de club
histórico: legible para un padre de 50 años y para un atleta de 16. Es la evolución natural de la
web actual.»

### Pantalla «Hoy»

1. **Cabecera**: fecha en versalitas «MARTES 29 JULIO» y saludo grande **Hola, Marta**; a la derecha,
   botón circular de avisos con contador.
2. **Tira de semana**: siete letras `L M X J V S D` con el día actual marcado en círculo oscuro
   (día 21 destacado en la maqueta).
3. **Tarjeta de la sesión de hoy**, en azul oscuro sobre el resto crema:
   - Cabecera de la tarjeta: `HOY · LA TRIBU` a la izquierda y **19:30** a la derecha.
   - Título condensado grande: **Series 6×1000**.
   - Línea de detalle: «Rec. 2' trote · ritmo 4:05/km».
   - Línea de lugar: «Pista Joaquín Villar · Nicolás Tucci».
   - Dos botones: **Ver entreno** (azul, ancho) y un botón circular de marcar `✓`.
4. **Bloque «Esta semana»** con contador a la derecha: «42 km prev.». Dos filas:
   - `JUE` — **Rodaje suave 12 km** · «Playa San Juan · 19:00»
   - `SÁB` — **Tirada larga 20 km** · «Salida Explanada · 08:00»
5. **Aviso del club** en caja crema: «Inscripciones abiertas para el Cross de Alicante hasta el 8 de
   agosto.»
6. **Navegación inferior de 5 pestañas**: `Hoy · Calendario · Club · Pagos · Perfil`.

### Pantalla «¿Cómo ha ido?» — feedback del entreno con ritmos

Cabecera: «ENTRENO COMPLETADO · 20:41» y titular **¿Cómo ha ido?**.

1. **Fila de tres cifras** en tarjeta:
   - `6×1000` — «series»
   - `4:02` — «medio /km»
   - `13,4` — «km total»
2. **ESFUERZO PERCIBIDO** — escala de botones `1 3 5 7 9 10` con el 7 seleccionado en azul.
   Debajo, la lectura: «7 · Duro pero controlado».
3. **RITMOS POR SERIE** — con acción a la derecha **IMPORTAR RELOJ**. Rejilla de seis casillas
   numeradas, cada una editable:

   | # | Valor |
   | --- | --- |
   | 1 | 3:58 |
   | 2 | 4:01 |
   | 3 | 4:00 |
   | 4 | 4:04 |
   | 5 | 4:0 (campo en edición, con cursor) |
   | 6 | --:-- (vacío) |

   Debajo, comparación automática con el objetivo: «Objetivo 4:05 · vas 3 s por debajo» y la acción
   **+ Añadir serie**.
4. **SENSACIONES** — chips seleccionables: **Piernas cargadas** (seleccionado, fondo oscuro),
   **Buen ritmo**, **Molestia**, **Fresca**.
5. **Campo de texto libre** con marcador de posición: «Nota para Nicolás (opcional)…».
6. Botón principal: **Enviar al entrenador**.

## 2.2 · Dirección B — «Rendimiento», oscura y de datos (`1b`)

Descripción: «Modo oscuro, tipografía monoespaciada para las cifras y un acento cal sobre el azul
del club. Habla el idioma del atleta que mira su carga semanal. Muy buena de noche, en la pista.»

### Pantalla de inicio

1. Cabecera oscura: «Apolana · La Tribu» y avatar `MR`.
2. **Carga semanal**: cifra enorme monoespaciada **28,6** con «/ 42 km» al lado, barra de progreso y
   línea «3 de 5 sesiones completadas».
3. **Tarjeta de la próxima sesión** con borde verde cal: cabecera «Próxima · hoy 19:30» y «en 2 h»;
   título **Series 6×1000**; tres columnas de datos:
   - `RITMO` **4:05**
   - `REC` **2'00**
   - `VOL` **13 km**
   
   Botón cal a todo el ancho: **Abrir sesión**.
4. **Semana**: lista de cuatro filas con día, sesión y resultado:
   - `LUN` Rodaje 10 km — **4:48**
   - `MAR` Series 6×1000 — **—**
   - `JUE` Rodaje suave 12 km — **—**
   - `SÁB` Tirada larga 20 km — **—**
5. **Navegación inferior**: `Hoy · Plan · Marcas · Club · Yo`.

### Pantalla «Marcas personales»

1. Encabezado «MARCAS PERSONALES» y nombre grande **Marta Ripoll**.
2. Pestañas: **RUTA** (activa, cal) · **PISTA** · **CROSS**.
3. Tres filas de marca, cada una con prueba, competición y fecha en versalitas, y el tiempo en
   monoespaciada grande a la derecha:
   - **5 km** · `SAN VICENTE · 03·2026` — **19:48**
   - **10 km** · `10K ALICANTE · 05·2026` — **41:12**
   - **Media** · `SANTA POLA · 01·2026` — **1:31:05**
4. **Volumen 8 semanas**: gráfico de barras (las últimas en cal).
5. Navegación inferior igual: `Hoy · Plan · Marcas · Club · Yo`.

## 2.3 · Dirección C — «Cartel», grande y directa (`1c`)

Descripción: «Bloques de azul saturado, tipografía enorme, cero decoración. Pensada para que
cualquiera —padre, atleta o abuelo— entienda la pantalla en dos segundos. Aquí la segunda pantalla
es el perfil de familia: pagos y equipación.»

### Pantalla de inicio

1. Bloque azul saturado a sangre: «Apolana» y avatar `MR`; encima del titular, «Hoy entrenas».
2. Titular gigantesco a dos líneas: **19:30 / PISTA**.
3. Dos botones grandes en fila: **VER ENTRENO** (blanco) y **NO VOY** (contorno).
4. Sobre fondo claro: encabezado `SERIES 6×1000 · LA TRIBU` y párrafo «Pista Joaquín Villar con
   Nicolás Tucci. Recuperación de 2 minutos en trote.»
5. Dos contadores en tarjetas: **4** «entrenos esta semana» y **2** «competiciones abiertas».
6. Tarjeta oscura de competición: `CROSS DE ALICANTE` · «Cierra el 8 de agosto» + botón cal
   **APUNTARME**.
7. **Del club**: una noticia con miniatura — «Resultados del Cross de Xixona» · «hace 2 días».
8. **Navegación inferior**: `Hoy · Agenda · Club · Pagos · Yo`.

### Pantalla de familia · pagos y ropa

1. Cabecera oscura: «FAMILIA · RIPOLL SÁNCHEZ» y titular **PAGOS Y ROPA**.
2. Selector de hijo en chips: **Pau · 11 años** (activo) · **Jana · 8 años**.
3. Tarjeta **PENDIENTE**: «Cuota escuela agosto» — **45€** — botón azul ancho **PAGAR AHORA**.
4. Fila resuelta: «Cuota socio 2026 · pagada» — 120€.
5. **EQUIPACIÓN DEL CLUB**: dos fichas de producto con hueco de foto —
   «Camiseta tirantes 24€» y «Sudadera club 38€».
6. Navegación inferior: `Hoy · Agenda · Club · Pagos · Yo`.

---

# Bloque 3 · Calendario (`4c`)

**Propósito**: «Los mismos datos que ve la app, filtrables por grupo.»

Cabecera del sitio: logotipo «Apolana · ALICANTE · 1988» y menú `El club · Entrena con nosotros ·
Escuelas · Calendario · Noticias · Contacto · Mi perfil` + botón **Inscribirse**.

1. Título de la página: **Entrenamientos y competiciones**; a su lado, el mes: **Agosto 2026**.
2. **Filtros en chips**: `Todo` (activo) · `Escuela` · `Running` · `Pista` · `Natación` ·
   `Competiciones`.
3. **Rejilla mensual** con cabecera `LUN MAR MIÉ JUE VIE SÁB DOM`. Cada celda lleva el número del día
   y, si hay actividad, una línea resumen:
   - `29` → «4 entrenos», `30` → «3 entrenos», `1` → «Tirada larga»
   - `3` → «3 entrenos», `4` → «4 entrenos», `6` → «3 entrenos»
   - `7` → «Cierra inscripción», `8` → «Tirada larga»
   - `10` → «3 entrenos», `11` → «4 entrenos», `13` → «3 entrenos»
   - `16` → «Cross de Alicante»
4. **Panel lateral del día seleccionado**: **Martes 29** · etiqueta «4 ACTIVIDADES». Lista con hora,
   grupo e instalación:
   - `17:30` **Escuela · Benjamín** — Pista Joaquín Villar
   - `19:00` **Madre Tierra · rodaje** — Playa San Juan
   - `19:30` **La Tribu · series** — Pista Joaquín Villar
   - `20:30` **Natación adultos** — Monte Tossal
5. **Próxima competición**: **Cross de Alicante** · «16 de agosto · Cabo de las Huertas · 8 km» +
   botón **Inscribirme · 12€**.
6. **Leyenda** de tres marcas: `Entreno` · `Competición` · `Cierre de inscripción`.
7. Pie: «¿Prefieres tenerlo en el móvil? El calendario se sincroniza con la app del club y con tu
   calendario del teléfono.» + botón **Suscribirme al calendario**.

---

# Bloque 4 · Marcas y progresión (`15a`)

**Propósito**: «Curva del año con filtro de competición y entrenamiento, y registro rápido de una
marca nueva.» El atleta registra cada marca —de entrenamiento o de competición— y ve su curva del
año.

## Pantalla «Mis marcas»

1. **Cabecera**: en versalitas «TEMPORADA 2026-27»; título condensado **MIS MARCAS**; a la derecha,
   botón azul **+ Marca**.
2. **Selector de prueba** en píldoras horizontales: **1.500 m** (activa, azul oscuro) · `800 m` ·
   `5.000 m` · `10 km`.
3. **Bloque de la mejor marca**: cifra grande **4:12.6**, etiqueta «MEJOR DEL AÑO · MAYO» y a la
   derecha la variación en verde: «−9,4 s vs 2025».
4. **Gráfico de líneas** con eje de meses `OCT · DIC · FEB · ABR · JUN`. Dos series con leyenda:
   **Esta temporada** (línea azul continua con puntos) y **Temporada pasada** (línea gris
   discontinua).
5. **Filtro de tipo** en píldoras: **Todas** (activa, azul) · `Competición` · `Entrenamiento`.
6. **Lista de marcas**, cada fila con barra de color a la izquierda, marca + prueba en negrita,
   línea de contexto y etiqueta de tipo a la derecha:

   | Marca | Contexto | Etiqueta |
   | --- | --- | --- |
   | 4:12.6 · 1.500 m | Autonómico · Castellón · 17 may | **RÉCORD** (verde) |
   | 4:18.9 · 1.500 m | Control de club · 12 abr | **COMPETICIÓN** (azul) |
   | 4:24.0 · 1.500 m | Serie en entreno · 3 mar | **ENTRENO** |
   | 4:31.2 · 1.500 m | Serie en entreno · 14 ene | **ENTRENO** |

7. **Navegación inferior**: `Hoy · Semana · Clases · Marcas · Perfil`.

## Pantalla modal «Nueva marca»

Cabecera de la hoja: **Cancelar** (izquierda) · **NUEVA MARCA** (centro) · **Guardar** (derecha,
inactivo hasta rellenar).

Campos, en orden:

| Campo | Control | Valor de ejemplo |
| --- | --- | --- |
| Tipo | Segmentado de dos opciones | **Competición** (seleccionada) / Entrenamiento |
| Prueba | Desplegable con chevron `›` | «1.500 m lisos» |
| Marca | Campo grande destacado, con ayuda de formato a la derecha | **4:12** `.6` — `MIN:SEG.DÉC` |
| Fecha | Campo de fecha | 17/05/2026 |
| Puesto | Campo corto | 3º |
| Dónde | Campo de texto | «Autonómico · Castellón» |
| Nota para el entrenador | Área de texto | «Salí conservador y apreté los últimos 400…» |

Debajo, **caja verde de aviso** con icono `↑`: «Sería tu mejor marca del año en 1.500: 6,3 segundos
menos que en abril.»

Botón principal azul a todo el ancho: **Guardar marca**. Pie en gris: «Tu entrenador la ve al
instante en tu ficha.»

---

# Bloque 5 · Clases y bonos de El Cubo (`11a`)

**Propósito**: «Un nadador ve las clases abiertas de El Cubo y se apunta o se borra; el bono
descuenta un uso al confirmar la asistencia y lo devuelve si cancela a tiempo.»

## Pantalla «El Cubo · clases abiertas»

1. **Cabecera**: en versalitas «ABIERTO A SOCIOS»; título condensado **EL CUBO**; a la derecha,
   enlace **Mi bono**.
2. **Tarjeta azul oscuro del bono**: «BONO DE 20 USOS» / «Te quedan 14 · caduca en junio» y a la
   derecha la cifra grande **14**.
3. **Pestañas**: **Esta semana** (activa) · `Siguiente` · `Mis clases`.
4. **Lista de clases**, una tarjeta por clase. Cada tarjeta: fecha y hora en versalitas a la
   izquierda, estado a la derecha, nombre de la clase, entrenador y ocupación, y un botón de acción
   a todo el ancho:

   | Fecha/hora | Estado | Clase | Entrenador · plazas | Botón |
   | --- | --- | --- | --- | --- |
   | MIÉ 30 · 20:00 | **APUNTADO** (verde) | Fuerza para nadadores | Sergio Pastor · 8 de 12 plazas | **Desapuntarme** (contorno verde) |
   | JUE 31 · 19:00 | **4 PLAZAS** | Core y movilidad | Claudia Otero · 8 de 12 plazas | **Apuntarme · 1 uso** (azul relleno) |
   | VIE 1 · 18:00 | **COMPLETA** | Circuito funcional | Nicolás Tucci · 12 de 12 plazas | **Entrar en lista de espera** (contorno apagado) |

   La tarjeta en la que el atleta está apuntado va con fondo verde muy claro.
5. **Nota de reglas** en caja crema: «El uso se descuenta al empezar la clase. Si cancelas con más de
   3 horas, se te devuelve.»
6. **Navegación inferior**: `Hoy · Semana · Clases · Club · Perfil`.

## Pantalla «Bono El Cubo · 20 usos»

Cabecera con **‹ Clases** (volver) y **Ayuda**.

1. **Tarjeta azul oscuro**: «BONO EL CUBO · 20 USOS»; cifra enorme **14** con la palabra «usos
   disponibles»; barra de puntos que representa los usos; pie con «Comprado el 12 de mayo · 90 €» y
   «Caduca 30 jun».
2. **ÚLTIMOS USOS** con enlace **Ver todos**. Filas de movimiento con signo a la derecha:
   - Circuito funcional · «Lun 28 · 18:00» — **−1**
   - Core y movilidad · «Jue 24 · 19:00» — **−1**
   - Cancelada a tiempo · «Mar 22 · 20:00» — **+1** (en verde)
   - Fuerza para nadadores · «Lun 21 · 20:00» — **−1**
3. **Compra de bono**: dos opciones en botones — `10 usos · 50 €` y **20 usos · 90 €** (destacada,
   azul).
4. Pie: «Se cobra con la cuota del mes siguiente.»

---

# Bloque 6 · Panel del entrenador en móvil (`11b`)

**Propósito**: «Pasar lista en 20 segundos y, desde la ficha, cambiar de grupo o dar de baja.»

## Pantalla «Pasar lista»

1. **Cabecera**: en versalitas «MIÉ 30 · 18:30 · NATACIÓN 10-15»; título condensado **PASAR LISTA**;
   a la derecha, contador **9/12**.
2. **Dos acciones en fila**: **Marcar todos** y **Buscar**.
3. **Lista de atletas**. Cada fila: avatar de iniciales, nombre y, a la derecha, control de estado:
   - `PR` Pau Ripoll — `✓` verde
   - `LB` Lucía Bernabéu — `✓` verde
   - `MS` Marc Server — línea secundaria **«Avisó: está malo»** — `✕` rojo, fila con fondo rojo claro
   - `NS` Nora Sempere — `✓` verde
   - `JC` Jorge Castell — `✓` verde
   - `AS` Aitana Sanz — `✓` verde
   - `DP` David Pastor — `✓` sin marcar (contorno)
   - `+1` Iker Ferriz — línea secundaria **«De prueba · día 2 de 4»** — `✓` verde
4. **Botón principal**: **Guardar lista**.
5. **Nota**: «Las faltas sin avisar se notifican a la familia.»

## Pantalla «Ficha del atleta»

Cabecera con **‹ Lista** (volver) y **Editar**.

1. **Encabezado**: avatar `MS`, nombre **MARC SERVER** y línea «14 años · natación 10-15 · L, J y V».
2. **Tres filas de datos** clave-valor:
   - «Asistencia últimos 30 días» — **10 de 13**
   - «Estado» — **En prueba · acaba el jueves** (en ámbar)
   - «Pagos» — **Al día**
3. **GESTIÓN DEL GRUPO** — filas de acción:
   - **Cambiar de grupo** — valor a la derecha «Natación 10-15 ›»
   - **Confirmar alta tras la prueba** — botón azul **Confirmar**
   - **Marcar lesión o molestia** — `›`
   - **Escribir a la familia** — `›`
   - **Dar de baja** — `›`, fila en rojo claro
4. **Nota** en caja crema: «Cambios de grupo y bajas avisan a administración y se reflejan en el
   cobro del mes siguiente.»
5. **Navegación inferior del entrenador (4 pestañas)**: `Semana · Atletas · Feedback · Perfil`.

---

# Bloque 7 · Estados vacíos (`8e`)

**Propósito**: «Lo que ve un entrenador nuevo, un admin con todo resuelto y un atleta en día de
descanso.»

## Estado vacío del entrenador · semana en blanco

1. Cabecera: «SEMANA 31 · 27 JUL – 2 AGO» y selector de grupo **Escuela · Benjamín ▾**.
2. Fila de siete recuadros vacíos (los siete días).
3. Titular condensado: **ESTA SEMANA ESTÁ EN BLANCO**.
4. Texto: «Empieza por una plantilla de tu metodología, copia la semana pasada o descríbesela a la
   IA. Después podrás retocar sesión a sesión.»
5. Tres botones: **Usar una plantilla** (azul) · **Copiar semana 30** · **Generar con IA**.
6. Pie: «Los atletas no ven nada hasta que publicas.»

## Estado vacío del atleta · día de descanso

1. Cabecera: «VIERNES 31 DE JULIO» con etiqueta **HOY**; título **HOY**.
2. Icono circular con una `Z`.
3. Titular condensado: **HOY TOCA DESCANSAR**.
4. Texto: «No hay sesión programada. Mañana a las 08:00, tirada larga de 90 minutos desde la
   Explanada.»
5. Botón: **Ver mi semana**.
6. Segunda tarjeta, **PENDIENTE DE AYER**: «No registraste el feedback del rodaje del jueves.» +
   enlace **Registrarlo ahora →**.
7. **Navegación inferior**: `Hoy · Semana · Marcas · Club · Perfil`.

---

# Bloque 8 · Entradas a la app desde la web en móvil

## 8.1 · Home en móvil (`8a`)

«Con el aviso de portada arriba y "encuentra tu grupo" como segundo bloque.»

1. Barra superior: logotipo **APOLANA** y botón de menú.
2. **Aviso de portada** en tarjeta ámbar, con etiqueta `AVISO`: «Inscripción de la escuela abierta
   hasta el 7 de agosto».
3. Hueco de foto grande.
4. Encabezado en versalitas: «CLUB DE ATLETISMO · ALICANTE · 1988».
5. Titular condensado enorme: **AQUÍ SIEMPRE HAY ALGUIEN ENTRENANDO**.
6. Párrafo: «Atletismo, running, triatlón, natación y montaña. De los 3 años a la alta competición.»
7. Dos botones: **Prueba 4 días gratis** (azul) y **Encuentra tu grupo** (contorno).
8. Tres cifras: **420** ATLETAS · **7** SECCIONES · **38** AÑOS.

## 8.2 · «Encuentra tu grupo» · paso y resultado (`8a`)

Pantalla de test:

1. Cabecera: **‹ Volver** y «PASO 2 DE 3»; barra de progreso de tres tramos.
2. Encabezado en versalitas «ENCUENTRA TU GRUPO» y titular **¿QUÉ BUSCAS?**.
3. Cuatro opciones en tarjetas seleccionables (la segunda aparece seleccionada, con borde azul):
   - **Coger el hábito** — «Salir a correr con gente, sin presión»
   - **Bajar mi marca** — «Series, plan escrito y objetivos»
   - **Competir en pista** — «Velocidad, saltos o lanzamientos»
   - **Montaña o triatlón** — «Trail, natación y bici»
4. Botón **Siguiente**.
5. Pie: «Tres preguntas y te decimos grupo, horario y precio.»

Pantalla de resultado:

1. Cabecera: **TU GRUPO** y enlace **Repetir test**.
2. Etiqueta **TE ENCAJA** y titular condensado **LA TRIBU**.
3. Descripción: «Series en pista, tiradas largas y planificación por objetivos con Nicolás Tucci.»
4. Dos filas de datos: «Días — M · J · S» y «Precio — 60€/mes + 120€ socio».
5. Botón azul: **Probar un martes**.
6. **TAMBIÉN PODRÍA VALERTE** — dos alternativas en tarjeta con precio a la derecha:
   - **Madre Tierra** · «Rodajes y técnica · M, J, S» — 40€
   - **Atletismo pista** · «Federado · L, X, V» — 45€
7. Pie: «¿Dudas? Te llamamos y lo vemos.» + botón **Que me llamen**.

## 8.3 · Inscripción en móvil y confirmación (`8b`)

«Resumen de precio fijo abajo y una confirmación que dice qué pasa después.»

Pantalla de formulario:

1. Cabecera: **‹ Grupo** y «PASO 1 DE 3» con barra de progreso.
2. Titular condensado: **QUIÉN SE APUNTA**.
3. Campos:
   - **Nombre y apellidos** — «Pau Ripoll Sánchez»
   - **Fecha de nacimiento** — «14/03/2015»
   - **Teléfono de la familia** — «625 47 38 30» (campo con foco, borde azul)
   - Casilla marcada `✓`: «Autorizo el uso de imágenes del club en redes y web»
4. **Barra de resumen fija abajo**: «Escuela · Benjamín» / «38€/mes + ficha 42€» a la izquierda y
   **80€** grande a la derecha; botón **Continuar**.
5. Pie: «No se cobra nada hasta el último paso.»

Pantalla de confirmación:

1. Icono circular `✓`.
2. Titular condensado a dos líneas: **PAU YA ESTÁ / DENTRO**.
3. Texto: «Le esperamos el lunes a las 17:30 en la Pista Joaquín Villar. Preguntad por Andrés en la
   puerta del container.»
4. **QUÉ PASA AHORA** — lista numerada:
   1. «Recibes un correo con la ficha y el resguardo»
   2. «El primer recibo se domicilia el 3 de septiembre»
   3. «La equipación se recoge en el container, martes y jueves»
5. Caja crema: «Descarga la app para ver los entrenos, avisar de faltas y seguir cómo va.» + botón
   oscuro **Descargar la app**.
6. Botón secundario: **Añadir el horario a mi calendario**.
7. Pie: «¿Algo no cuadra? 636 06 17 00».

---

# Bloque 9 · Los mismos paneles en escritorio

Shell común de los cuatro paneles: **barra lateral crema, contenido sobre blanco y azul solo para
acciones**. Arriba de la barra lateral, el logotipo «Apolana» con el rol debajo en versalitas. Abajo
del todo, la tarjeta de usuario con avatar de iniciales, nombre y grupo. El elemento de menú activo
va en píldora azul rellena.

## 9.1 · Portal del atleta (`5c`)

«Misma información que la app de `1a`, en escritorio.»

- **Barra lateral** — cabecera «Apolana / MI PANEL». Grupos de menú:
  - `ENTRENAMIENTO`: **Sesión de hoy** (activo) · Mi semana · Historial
  - `MI PERFIL`: Mis marcas · Competiciones · Datos personales
  - Pie: `JC` **Jorge Castell** · «La Tribu»
- **Cabecera del contenido**: «JUEVES 30 DE JULIO · SEMANA 31» y titular condensado
  **RODAJE 50' + TÉCNICA**; a la derecha, botón azul **Registrar feedback**.
- **Cuerpo de la sesión** en cuatro bloques etiquetados en versalitas a la izquierda:

  | Bloque | Contenido |
  | --- | --- |
  | CALENTAR | «15' trote suave + movilidad de tobillo y cadera» / «Playa de San Juan, desde el chiringuito» |
  | PRINCIPAL | «50' de rodaje continuo a 4:45-5:00 min/km» / «Cómodo: tienes que poder hablar todo el rato» |
  | TÉCNICA | «6×80 m progresivos descalzo en la orilla» / «Vuelta caminando, sin prisa» |
  | SOLTAR | «10' de estiramientos y core suave» |

- **Nota del entrenador** en tarjeta azul claro: avatar `NT`, encabezado «NOTA DE NICOLÁS» y texto:
  «El martes apretaste bien las series. Hoy toca de verdad suave: si el ritmo te sale por debajo de
  4:45, frena. El sábado quiero la tirada fresca.»
- **Columna derecha**, tres tarjetas:
  - **MI SEMANA**: `Lun · descanso` — `—` · `Mar · 6×800` — **HECHO** · `Mié · fuerza` — **HECHO** ·
    `Jue · rodaje 50'` — **HOY** (resaltado en azul) · `Vie · descanso` — `—` · `Sáb · tirada 90'` —
    `08:00`
  - **MIS MARCAS**: `5.000 m` **16:42** · `10 km ruta` **34:58** · `Media maratón` **1:18:24**
  - **PRÓXIMA COMPETICIÓN** (tarjeta crema): **CROSS DE ALICANTE** · «16 de agosto · en 17 días»

## 9.2 · Portal de familias (`5d`)

«Ficha del hijo, próximos entrenos, estado de los pagos y tienda del club.»

- **Barra lateral** — «Apolana / FAMILIAS». Menú: **Ficha del atleta** (activo) · Entrenamientos ·
  Calendario · Pagos y recibos · Tienda del club. Pie: `MR` **Marta Ripoll** · «Madre de Pau».
- **Cabecera del contenido**: foto redonda del atleta, nombre **PAU RIPOLL SÁNCHEZ** y línea
  «Escuela de atletismo · Benjamín · L, X, V 17:30 · Pista Joaquín Villar»; a la derecha, etiqueta
  verde **Al día**.
- **PRÓXIMOS ENTRENAMIENTOS** con enlace **Ver calendario**. Tres filas con día y hora a la
  izquierda, actividad y lugar en el centro y acción a la derecha:
  - `VIE · 17:30` **Técnica de salto y relevos** · «Pista Joaquín Villar · Andrés Clavero» —
    **Avisar falta**
  - `LUN · 17:30` **Velocidad y juegos de reacción** · «Pista Joaquín Villar» — **Avisar falta**
  - `SÁB 16/8` **Cross de Alicante · categoría benjamín** · «Cabo de las Huertas · inscripción hasta
    el 7» — **Inscribir** (azul)
- **CÓMO VA PAU**: avatar `AC`, encabezado «ANDRÉS CLAVERO · 24 JUL» y texto: «Muy bien en los
  relevos, empieza a controlar el ritmo en la vuelta larga. Le vendría bien traer zapatilla de clavos
  para septiembre.»
- **Columna derecha**:
  - **PAGOS**: «Cuota de julio» / «Cobrada el 3/07» — 38€ · «Ficha federativa» / «Cobrada el 12/06» —
    42€ · «Cuota de agosto» / «Se cobra el 3/08» — 38€. Botón **Descargar recibos**.
  - **TIENDA DEL CLUB** con enlace **Ver todo**: «Camiseta oficial / Tallas 6 a 16 — 22€» y
    «Sudadera del club / Tallas 8 a 16 — 34€». Botón azul **Ver carrito · 1 artículo**.

## 9.3 · Panel del entrenador en escritorio (`5b`)

«Semana en rejilla, feedback de atletas al lado y el asistente de IA como acción, no como pestaña
aparte.»

- **Barra lateral** — «Apolana / ENTRENADOR». Grupos:
  - `PLANIFICACIÓN`: **Vista semanal** (activo) · Plantillas de bloque · Catálogo de ejercicios
  - `ATLETAS`: Mis atletas · Grupos · Competiciones
  - `SEGUIMIENTO`: Feedback de atletas — con globo contador **7**
  - Pie: `NT` **Nicolás Tucci** · «La Tribu · pista»
- **Cabecera**: titular **SEMANA 31 · 27 JUL – 2 AGO**, flechas `‹ ›`, selector **La Tribu ▾**,
  botón **Generar con IA** y botón azul **Nueva sesión**.
- **Rejilla semanal** de siete columnas (`LUN 27 … DOM 2`, con «JUE 30 · HOY» resaltado). Cada
  sesión es una tarjeta con tipo en versalitas, título, detalle y estado:

  | Día | Tipo | Sesión | Detalle | Estado |
  | --- | --- | --- | --- | --- |
  | LUN 27 | — | Descanso | — | — |
  | MAR 28 | PISTA · CALIDAD | 6×800 a ritmo umbral | «rec. 2' trote · 3 bloques» | **PUBLICADA** |
  | MIÉ 29 | GIMNASIO | Fuerza general | «sentadilla, peso muerto, core» | **PUBLICADA** |
  | JUE 30 · HOY | CONTINUO · SUAVE | Rodaje 50' + técnica | «playa · zapatilla amortiguada» | **BORRADOR** (ámbar) |
  | VIE 31 | — | **+ Añadir** | — | — |
  | SÁB 1 | CONTINUO · LARGO | Tirada 90' | «últimos 20' progresivos» | **PUBLICADA** |
  | DOM 2 | — | Descanso | — | — |

- **FEEDBACK SIN LEER** (columna izquierda inferior), encabezado «MARTES · 6×800». Cada fila:
  avatar, nombre + RPE, contenido y etiqueta de acción a la derecha:
  - `JC` **Jorge Castell · RPE 8** — «2:38 / 2:36 / 2:37 / 2:35 / 2:39 / 2:41» — **OK**
  - `MR` **Marta Ripoll · RPE 9** — «Molestia en el sóleo derecho desde la 4ª serie» (en rojo) —
    **REVISAR**
  - `AS` **Aitana Sanz · RPE 6** — «"Me he quedado con ganas de más"» — **SUBIR CARGA**
  - `DP` **David Pastor · RPE 7** — «2:41 / 2:40 / 2:42 / 2:40 / 2:44 / 2:46» — **OK**
- **ASISTENTE DE PLANIFICACIÓN** (tarjeta derecha, etiqueta `IA`): texto «Describe la fase, el
  estado del grupo y la competición objetivo. Genera la semana completa siguiendo tu metodología y
  la deja en borrador.»; área de texto con el ejemplo «Semana de descarga antes del Cross de
  Alicante. Marta con molestia en el sóleo: nada de series largas. Aitana puede subir volumen.»;
  botones **Generar semana** (azul) y **Usar plantilla**.

---

# Bloque 10 · Familia Apolana (`19c`)

Página pública que alimenta lo que la familia ve en su portal. Se documenta aquí porque define las
reglas de precio que el portal de familias debe reflejar.

1. **Hero**: etiqueta «Familia Apolana», titular condensado **Cuando entrena toda la casa** y texto:
   «Si ya traes a tu hijo tres tardes por semana, lo lógico es que tú también entrenes. Desde el
   segundo miembro la cuota baja, y todo llega en un solo recibo al mes.» Botones **Calcular lo
   nuestro** y **Ver grupos de adultos**.
2. **Las reglas** — «Se aplican solas: no hay que pedirlas». Cuatro tarjetas:

   | Regla | Valor | Detalle |
   | --- | --- | --- |
   | SEGUNDO ADULTO | −10 % | «En su cuota de entrenamiento» |
   | TERCERO Y SIGUIENTES | −15 % | «Cada adulto a partir del tercero» |
   | HERMANOS EN LA ESCUELA | 20/40 % | «Segundo y tercero, como hasta ahora» |
   | PADRES CON HIJO EN ESCUELA | 30 € | «El Cubo, y precio de socio en natación» |

3. **Tres avisos**: «No se acumulan — Se aplica siempre el más favorable de los que correspondan» /
   «Solo sobre el entrenamiento — La cuota de socio y la ficha federativa no llevan descuento» / «Si
   uno se da de baja — El descuento dura hasta final de temporada, no se corta a mitad».
4. **Calculadora «Calculad lo vuestro»**: filas con rol de la casa, desplegable de grupo, importe y
   descuento aplicado:
   - Hijo — «Escuela de atletismo · Benjamín ▾» — 36,5 €/mes
   - Segunda hija — «Escuela de natación · 2 clases ▾» — 36,0 €/mes — «−20 % hermana»
   - Madre — «Running · Madre Tierra ▾» — 36,0 €/mes — «−10 % familia»
   - Padre — «El Cubo · padres ▾» — 30,0 €/mes — «tarifa escuela»
   - Acción **+ Añadir a alguien más de casa**
   
   **VUESTRO RECIBO**: «Sin descuentos 161,5 €» / «Ahorro Familia Apolana −23,0 €» / «Al mes
   **138,5 €**». Nota: «Aparte van los 120 € al año de socio por cada adulto y las cuotas de
   temporada de la escuela.» Botón **Empezar la inscripción**.
5. **Casos excepcionales**: «Si vuestra situación no encaja en las reglas de arriba, la junta puede
   ajustar la cuota. Se estudia caso por caso y con discreción.» + enlace **Escribir a la junta →**.
6. **Un recibo, una familia**: «Todo junto el día 3, con el desglose por persona en el portal de
   familias.» + botón **Crear ficha de familia**.

---

# Resumen de navegación por rol

| Rol | Navegación que pide la maqueta |
| --- | --- |
| Atleta (móvil, dirección `1a`) | `Hoy · Calendario · Club · Pagos · Perfil` |
| Atleta (móvil, dirección `1b`) | `Hoy · Plan · Marcas · Club · Yo` |
| Atleta (móvil, dirección `1c`) | `Hoy · Agenda · Club · Pagos · Yo` |
| Atleta (pantallas de marcas y clases) | `Hoy · Semana · Clases · Marcas · Perfil` / `Hoy · Semana · Clases · Club · Perfil` / `Hoy · Semana · Marcas · Club · Perfil` |
| Entrenador (móvil) | `Semana · Atletas · Feedback · Perfil` |
| Atleta (escritorio) | Sesión de hoy · Mi semana · Historial · Mis marcas · Competiciones · Datos personales |
| Familia (escritorio) | Ficha del atleta · Entrenamientos · Calendario · Pagos y recibos · Tienda del club |
| Entrenador (escritorio) | Vista semanal · Plantillas de bloque · Catálogo de ejercicios · Mis atletas · Grupos · Competiciones · Feedback de atletas |

---

## Diferencias con lo que hay hoy

Comparado con `/portal/index.html`, `/portal/atleta/index.html`, `/portal/entrenador/index.html` y
`/portal/familia/index.html` (más `assets/js/portal-auth.js`, que aporta el acceso y la barra
superior comunes).

### Lo que sí está alineado

- El **feedback del entreno con tiempos por serie** existe en la zona de atleta: casillas por serie
  dentro del ejercicio y formulario «¿Cómo ha ido?» que guarda en `registros_sesion`.
- El **registro de marcas** existe, con alta, mejores marcas personales y gráfico de evolución.
- El **planificador semanal del entrenador** existe y va más allá de la maqueta (pegar texto,
  importar CSV, duplicar semana, plantillas, previsualización, publicar/borrador, dirigir sesiones a
  atletas concretos).
- Los **pagos** se listan en la zona de atleta y en la de familia.

### Tabla de diferencias, de más a menos importante

| Elemento de la maqueta | ¿Existe hoy? | Qué falta o difiere |
| --- | --- | --- |
| **Pantalla de acceso del club** (`19b`): titular «CLUB APOLANA», «Entra con tu cuenta o mira el club sin registrarte», bloque «O SIN CUENTA» con tres accesos públicos, «He olvidado la contraseña» y «¿Aún no estás en el club? Inscribirme» | Parcial | Hoy es una tarjeta genérica: «Portal del club», «Entra con tu correo y contraseña.», campos «Correo»/«Contraseña» y botón «Entrar». **No hay** modo público sin cuenta, ni recuperación de contraseña, ni llamada a inscripción, ni identidad visual del club |
| **Pantalla «Hoy»** del atleta (tarjeta azul de la sesión, saludo, tira de semana, «Ver entreno», aviso del club) | No | No hay pantalla de hoy: hoy es un día más de la tira de siete días dentro de «Entreno». Faltan el saludo, la tarjeta destacada de la sesión, el km previsto de la semana y el aviso del club |
| **Navegación inferior de la app** (`Hoy · Calendario · Club · Pagos · Perfil`, y las variantes por rol) | No | El portal usa barra lateral de escritorio que en móvil se convierte en tira horizontal. No hay barra de pestañas inferior en ninguna zona |
| **Clases abiertas y bono de El Cubo** (`11a`): pestañas Esta semana/Siguiente/Mis clases, tarjetas de clase con plazas y estado, «Apuntarme · 1 uso», «Desapuntarme», «Entrar en lista de espera», detalle del bono con movimientos y compra de bonos | No | Solo existe un «Mi bono» en `/portal/competiciones/`, sin clases, sin horarios, sin apuntarse ni desapuntarse, sin lista de espera y sin compra de bonos |
| **Pasar lista del entrenador** (`11b`): contador 9/12, «Marcar todos», «Buscar», filas con `✓`/`✕`, «Guardar lista», «Las faltas sin avisar se notifican a la familia» | No | No existe asistencia en ninguna parte del portal, pese a que `/portal/index.html` la anuncia («planificar, pasar lista y feedback») |
| **Ficha del atleta desde el entrenador** (`11b`): asistencia 30 días, estado de prueba, pagos, «Cambiar de grupo», «Confirmar alta tras la prueba», «Marcar lesión o molestia», «Escribir a la familia», «Dar de baja» | No | El entrenador solo ve una tabla de solo lectura de sus atletas; no puede abrir la ficha ni gestionar el grupo |
| **Cambio de perfil sin cerrar sesión** (`19b`, `19a`: un mismo correo con varios roles) | No | El rol se resuelve una sola vez desde `perfiles.rol`; no hay selector de perfil ni vuelta a `/portal/` desde las subzonas |
| **Avisos que quieres recibir** (cinco interruptores: entreno publicado, suspensión por lluvia, recibo cobrado, noticias del club, plaza libre en El Cubo) y notificaciones en general | No | No hay preferencias de aviso, ni campana, ni notificaciones |
| **Calendario** (`4c`): rejilla mensual, filtros por sección, panel del día, próxima competición, leyenda y «Suscribirme al calendario» | No | Solo la tira de siete días de la semana en la zona de atleta. Ni calendario mensual, ni filtros, ni sincronización con el calendario del teléfono |
| **Portal del atleta en escritorio** (`5c`): sesión estructurada en CALENTAR / PRINCIPAL / TÉCNICA / SOLTAR, «Nota de Nicolás», columna con MI SEMANA (HECHO/HOY), MIS MARCAS y PRÓXIMA COMPETICIÓN | Parcial | Los bloques y la nota existen, pero como lista genérica. Falta la columna lateral con estado de la semana, marcas y próxima competición; y el menú de la maqueta (Sesión de hoy · Mi semana · Historial · Mis marcas · Competiciones · Datos personales) no coincide con el actual (Entreno · Marcas · Pagos · Competiciones · Documentos) |
| **Portal de familias** (`5d`): cabecera con foto y estado «Al día», próximos entrenamientos con **Avisar falta** e **Inscribir**, «CÓMO VA PAU» (nota del entrenador con fecha y firma), pagos con fechas de cobro y **Descargar recibos**, tienda del club con carrito | Parcial | Hoy hay selector de hijos, entreno (solo lectura), marcas y pagos. **Faltan**: avisar falta, inscribir a competición, nota del entrenador para la familia, descarga de recibos, tienda y carrito, y el menú «Ficha del atleta · Entrenamientos · Calendario · Pagos y recibos · Tienda del club» |
| **Panel del entrenador en escritorio** (`5b`): rejilla de siete días con estado PUBLICADA/BORRADOR, feedback sin leer al lado con etiquetas OK / REVISAR / SUBIR CARGA, contador de feedback en el menú | Parcial | Existe el planificador y una sección de feedback, pero el feedback se consulta eligiendo sesión en un desplegable, sin bandeja de «sin leer», sin contador y sin etiquetas de acción. Tampoco hay rejilla semanal visual del estado de las sesiones |
| **Estados vacíos con salida** (`8e`): «ESTA SEMANA ESTÁ EN BLANCO» con «Usar una plantilla / Copiar semana 30 / Generar con IA»; «HOY TOCA DESCANSAR» con la sesión de mañana y «PENDIENTE DE AYER» | Parcial | Los vacíos actuales son frases sueltas («Hoy no toca entreno.», «Aún no estás asignado a un grupo…»). Falta el aviso de feedback pendiente y el vacío del entrenador con los tres caminos de salida |
| **Pagos como acción** (`1c`: «PAGAR AHORA»; `5d`: «Descargar recibos») | No | Los pagos son una tabla de consulta: concepto, importe, estado y vencimiento. Sin pagar, sin domiciliación, sin recibos |
| **Competiciones desde la app** (`4c` «Inscribirme · 12€»; `1c` «APUNTARME»; `5d` «Inscribir») | Parcial | Existe `/portal/competiciones/` pero no está enlazada desde la maqueta de forma equivalente ni aparece en la zona de entrenador; no hay inscripción con precio desde el calendario |
| **Tienda del club dentro del portal** (`1c` equipación, `5d` tienda y carrito) | No | La tienda está solo en la web pública y no se enlaza desde el portal |
| **Menores y cuenta de familia** (`19a`: por debajo de 14 la cuenta es de la familia; la familia ve pagos y asistencia pero no el feedback) | Parcial | La familia hoy ve el entreno del hijo, pero no hay asistencia; y no está expresada la regla de los 14 años |
| **Zona de coordinador** (`19a`, ROL 4) | No | `/portal/index.html` enlaza a `portal/coordinador/`, pero ese directorio no existe |
| **Dirección visual** (crema `#EFE9DC`, azul del escudo `#2E4256`, titulares condensados `Archivo` / `Barlow Condensed`, cifras en `JetBrains Mono`, azul solo para acciones) | Parcial | El portal reutiliza el CSS de la web pública más estilos embebidos por página; no hay un sistema común de tarjetas, etiquetas de estado ni tipografía condensada como el de la maqueta |
| **Personalización de ritmos** («tú: {tiempo}» calculado con la mejor marca) | Existe hoy, **no está en la maqueta** | Es una mejora de la implementación sobre lo diseñado; conviene incorporarla al diseño en vez de perderla |
| **Observaciones privadas del entrenador** | Existe hoy, **no está en la maqueta** | Ídem: función útil que la maqueta no contempla |
