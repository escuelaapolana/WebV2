# Maquetas del panel de administración · especificación

Documento de referencia extraído de las maquetas originales de diseño. Recoge, pantalla por
pantalla, lo que el diseño pide para el panel de administración: estructura, textos literales,
campos, controles y comportamiento. Sirve como especificación para rehacer las pantallas.

**Fichero de origen**: `maquetas/originales-design/Admin Apolana.dc.html` (copia en
`maquetas/admin.html`). Los mismos bloques aparecen dentro del documento completo
`maquetas/originales-design/App Apolana.dc.html`.

Cada bloque de la maqueta lleva una etiqueta corta (`5a`, `18b`, `17a`…) que identifica el turno de
diseño; se conservan aquí para poder ir a la maqueta y comprobar cualquier detalle.

**Índice de pantallas**

| Etiqueta | Pantalla |
| --- | --- |
| `5a` | Panel de administración · inicio |
| `18a` | Mapa de contenido |
| `18b` | Editor de tarifas |
| `18c` | Grupo, horario y responsable |
| `17a` | Dinero, captación y asistencia |
| `17b` | Entrenadores, avisos e informe |
| `15b` | Estadísticas de la temporada |
| `11c` | Pasar las cuotas del mes |
| `10a` | Biblioteca de imágenes |
| `10b` | Huecos de la web |
| `20a` | Plantillas de email y notificación |
| `20b` | Reglas del test «encuentra tu grupo» y Familia Apolana |

---

## Sistema visual común

- **Shell**: barra lateral crema, contenido sobre blanco, **azul solo para acciones**.
- **Tipografías**: `Archivo` (titulares), `Barlow Condensed` (títulos de panel en versalitas
  condensadas), `IBM Plex Sans` (texto), `JetBrains Mono` (etiquetas en versalitas, cifras de tabla,
  IBAN, códigos y variables).
- **Colores**: crema `#EFE9DC` / `#F5F0E6` / `#F1EADC` de fondo; azul del escudo `#2E4256` para
  titulares y texto fuerte; azul de acción `#2F6FA8` y `#3B85C0`; verde `#4C7A28` (al día, listo,
  firmado); ámbar `#B96F09` sobre `#FDF3DD` y `#EBDCAE` (nuevo, pendiente, borrador); rojo `#A8453F`
  (impago, devuelto); marrones `#7A7365` / `#6B6558` / `#5E5849` para texto secundario.
- **Patrón de cabecera de panel**: título condensado grande a la izquierda con una línea de contexto
  debajo (temporada, fecha de corte, número de registros), y a la derecha una o dos acciones —
  la principal en botón azul relleno, la secundaria en contorno.
- **Tablas**: cabecera en versalitas monoespaciadas, filas con separador crema, estado en color al
  final de la fila y acción de texto (`Editar`, `Ver`) en la última columna.
- **Regla general del diseño**: «Un dato se escribe una vez». Si un dato aparece en la web, se
  cambia en el panel y en ningún otro sitio.

---

# 1 · Panel de administración · inicio (`5a`)

**Propósito**: «Inicio con lo que hay que resolver hoy, no con métricas de adorno.»

## Barra lateral

Cabecera: logotipo «Apolana» con «ADMINISTRACIÓN» debajo en versalitas. Grupos de menú con su
encabezado en versalitas:

| Grupo | Entradas |
| --- | --- |
| `PANEL` | **Inicio** (activo, píldora azul) |
| `GESTIÓN` | Inscritos · Grupos · En prueba · Ropa · Pagos |
| `CONTENIDO WEB` | Fotos del club · Noticias · Eventos · Tienda · Aviso de portada · Palmarés y récords |
| `VER COMO` | Entrenador · Atleta · Familias (tres chips) |

## Cabecera del contenido

- Título: **Inicio**. Línea de contexto: «Temporada 2026-27 · datos de hoy, martes 29 de julio».
- A la derecha: botón **Ver web** y avatar circular `A`.

## Fila de cuatro contadores

| Etiqueta | Cifra | Nota |
| --- | --- | --- |
| INSCRITOS | **420** | «+18 esta temporada» |
| IMPAGADOS | **14** (rojo) | «1.180 € pendientes» |
| EN PRUEBA | **9** | «3 acaban esta semana» |
| ROPA PENDIENTE | **27** | «sin entregar» |

## Alertas de hoy

Tarjeta con título **Alertas de hoy** y contador a la derecha: **6 SIN RESOLVER**. Cada fila lleva
una etiqueta de tipo a la izquierda, el texto en el centro y el botón de resolución a la derecha:

| Tipo | Texto | Acción |
| --- | --- | --- |
| IMPAGO | «Lucía Bernabéu · 2 recibos de escuela sin cobrar» | **Reclamar** |
| PRUEBA | «Marc Server acaba el periodo de prueba el jueves» | **Confirmar alta** |
| PRUEBA | «Nora Sempere acaba el periodo de prueba el viernes» | **Confirmar alta** |
| ROPA | «12 equipaciones de escuela llegaron y están sin repartir» | **Ver listado** |
| WEB | «Noticia del Cross de Xixona en borrador desde el domingo» | **Publicar** |
| TIENDA | «4 pedidos de camiseta esperando confirmación» | **Revisar** |

## Columna derecha

- **ACCESOS RÁPIDOS**: **Nueva noticia** (botón azul relleno) · Ver impagados · Periodos de prueba ·
  Control de ropa · Aviso de portada.
- **AVISO ACTIVO EN PORTADA** (tarjeta crema): texto entrecomillado «Inscripción abierta para la
  escuela 2026-27 hasta el 7 de agosto» + enlace **Editar** y nota «Caduca el 7 ago».

## Últimos inscritos

Título **Últimos inscritos**; a la derecha, dos chips de filtro — **Escuela 264** y
**Club · socios 156** — y el botón **Exportar**.

Tabla con cabeceras `NOMBRE · SECCIÓN · GRUPO · ESTADO · PAGO`:

| Nombre | Sección | Grupo | Estado | Pago |
| --- | --- | --- | --- | --- |
| Pau Ripoll Sánchez | Escuela | Benjamín | Activo | Al día |
| Marc Server Lledó | Atletismo pista | Cadete | En prueba (ámbar) | — |
| Lucía Bernabéu Ortiz | Escuela | Alevín | Activo | Impagado (rojo) |
| Jorge Castell Marí | Running | La Tribu | Activo | Al día |

---

# 2 · Mapa de contenido (`18a`)

**Propósito**: «Todo lo editable, quién lo toca y cuándo se actualizó por última vez.»

## Barra lateral (variante de contenido)

Cabecera «Apolana / ADMINISTRACIÓN». Grupos:

| Grupo | Entradas |
| --- | --- |
| `CONTENIDO` | **Mapa de contenido** (activo) · Tarifas · Grupos y horarios · Responsables · Campus · Biblioteca de imágenes · Documentos |
| `DÍA A DÍA` | Noticias · Eventos · Aviso de portada · Tienda |

## Cabecera

Título **MAPA DE CONTENIDO**; contexto: «32 bloques editables · 5 sin revisar desde hace más de un
año». Acciones: chip de filtro **Solo desactualizados** y botón azul **Ver web**.

## Tabla · «PRECIOS Y HORARIOS · NUEVO»

Cabeceras: `BLOQUE · DÓNDE SALE · QUIÉN LO EDITA · ACTUALIZADO` + acción.

| Bloque | Dónde sale | Quién lo edita | Actualizado |
| --- | --- | --- | --- |
| Tarifas de secciones | Pista, running, natación, montaña, home | Tesorería | hace 3 días |
| Cuotas de escuela | Escuela, inscripción, home | Escuela | hace 12 días |
| Grupos y horarios | Cada sección y escuela, calendario | Coordinación | hace 1 día |
| Campus de verano | Campus, home en temporada | Escuela | hace 7 meses |
| El Cubo · clases y bonos | El Cubo, app de clases | Coordinación | hace 5 días |

Cada fila termina en **Editar**.

## Bloque «TEXTOS Y PERSONAS»

Lista con la antigüedad de la última revisión y **Editar** en cada fila:

- Responsables de sección — hace 2 días
- Junta directiva — hace 1 mes
- Historia y cronología — hace 2 años
- Normativa y documentos — hace 14 meses
- FAQ de familias — hace 20 días
- Instalaciones — hace 3 meses

## Bloque «AUTOMATISMOS»

- Plantillas de email — hace 9 días — **Editar**
- Notificaciones de la app — hace 9 días — **Editar**
- Reglas de «encuentra tu grupo» — hace 6 días — **Editar**
- Umbrales de alertas — hace 6 días — **Editar**
- Feed de Instagram — «conectado» — **Ver**
- Textos legales — hace 3 años — **Editar**

## Nota de regla

Caja crema con etiqueta **REGLA**: «Un dato se escribe una vez: la cuota de pista vive aquí y la
usan la página de pista, la home, "encuentra tu grupo", la inscripción y el recibo. Si cambias 40
por 42, cambia en los cinco sitios.»

---

# 3 · Editor de tarifas (`18b`)

**Propósito**: «Precio de socio y de no socio, periodicidad y dónde aparece cada uno.»

## Cabecera

Título **TARIFAS**; contexto: «Temporada 2026-27 · los cambios entran en la web al guardar».
Acciones: **Ver histórico** (contorno) y **Guardar cambios** (azul relleno).

## Pestañas

**Club · secciones** (activa, oscura) · `Escuela` · `El Cubo` · `Campus` · `Cuota de socio`.

## Tabla de tarifas

Cabeceras: `GRUPO · DÍAS · SOCIO · NO SOCIO · PERIODICIDAD` + acción.

| Grupo | Días | Socio | No socio | Periodicidad |
| --- | --- | --- | --- | --- |
| Pista · Velocidad A | 5 días | 55 € | 70 € | Trimestral |
| Pista · Velocidad B | 3 días | **42 €** (celda en edición, recuadrada) | 70 € | Trimestral |
| Pista · Fondo y medio fondo | 3 a 5 días | 40-55 € | 70 € | Trimestral |
| Pista · Recreativo | 3 días | 40 € | 70 € | Trimestral |
| Running · Madre Tierra | M, J, S | 40 € | — | Mensual |
| Running · La Tribu | M, J, S | 60 € | — | Mensual |
| Natación · bono 4 clases | 1 día | 35 € | 50 € | Mensual |
| Natación · bono 8 clases | 2 días | 45 € | 60 € | Mensual |
| Natación · bono 12 clases | 3 días | 55 € | 70 € | Mensual |
| Montaña | Fines de semana | Incluida | — | — |

La fila en edición muestra **Guardar**; las demás, **Editar**.

## Panel lateral «CAMBIO EN CURSO»

- Resumen del cambio: «Velocidad B: **40 € → 42 €** al mes para socios.»
- **AFECTA A** — lista de los sitios donde repercute:
  - Página de atletismo en pista
  - Tabla de precios de la home
  - Hazte socio · coste total
  - Encuentra tu grupo
  - 14 recibos del próximo mes
- Campo **Entra en vigor** — valor «1 de septiembre de 2026».
- Casilla marcada `✓`: «Avisar por email a los socios del grupo».
- Caja crema de aviso: **Los precios no se tocan a media temporada** — «Por eso el cambio lleva
  fecha de entrada en vigor y queda registrado en el histórico, con quién lo hizo.»

---

# 4 · Grupo, horario y responsable (`18c`)

**Propósito**: «Un solo sitio para lo que hoy está repartido entre código y cabezas.»

## Cabecera

Título **ESCUELA · BENJAMÍN**; contexto: «61 atletas · 2 turnos». Acciones: **Ver en la web** y
**Guardar grupo** (azul).

## Tarjeta «Datos del grupo»

| Campo | Control | Valor de ejemplo |
| --- | --- | --- |
| Nombre | Texto | Benjamín |
| Nacidos entre | Texto / rango | 2019 y 2016 |
| Plazas | Número | 70 |
| Sede | Desplegable `▾` | Estadio Joaquín Villar |
| Tarifa aplicada | Desplegable `▾` | Escuela · tramo 2016-2023 |

## Tarjeta «Turnos y horario»

Acción a la derecha: **+ Añadir turno**. Cada turno es una fila con:

- **Selector de días** en cinco botones cuadrados `L M X J V`; los del turno van en azul relleno.
  - Turno 1: `L` y `X` marcados — horario **17:30 – 18:30** — «32 atletas» — acción **Quitar**
  - Turno 2: `M` y `J` marcados — horario **17:30 – 18:30** — «29 atletas» — acción **Quitar**
- Los campos de hora son dos campos con un guion entre medias.

Nota al pie: «Estos turnos alimentan la página de la escuela, el calendario, la app y la lista del
entrenador.»

## Panel lateral «RESPONSABLE»

- Foto del responsable, nombre **Andrés Clavero Giménez** y línea «CAFD · TAFAD · 681 968 563».
- Enlace **Cambiar foto**.
- **Otros técnicos del grupo**: chip «Claudia Otero» + acción **+ añadir**.
- **DÓNDE SE VE ESTE GRUPO** — lista de enlaces:
  - Escuela de atletismo · horarios
  - Inscripción · paso de grupo
  - Calendario de la web y la app
  - Panel del entrenador · pasar lista
- Caja crema de aviso: «Si cierras el grupo a nuevas inscripciones, deja de aparecer en el
  formulario pero sigue visible en la web con la etiqueta "completo".»
- Interruptor **Admite inscripciones** (encendido).

---

# 5 · Dinero, captación y asistencia (`17a`)

**Propósito**: «Bloques 1, 2 y 3» del cuadro de mando.

## Cabecera

Título **ECONOMÍA Y ACTIVIDAD**; contexto: «Temporada 2026-27 · cerrado a 31 de julio». Acciones:
desplegable **Escuela + club ▾** y botón **Exportar a Excel**.

## Ingresos por mes

Gráfico de barras apiladas con leyenda de dos series: **Escuela** (ámbar) y **Club** (azul). Eje de
meses: `SEP OCT NOV DIC ENE FEB MAR ABR MAY JUN JUL`.

Debajo, cuatro cifras con su etiqueta en versalitas:

| Cifra | Etiqueta |
| --- | --- |
| **142.380 €** | INGRESADO EN LA TEMPORADA |
| **3.840 €** | IMPAGADO · 2,7 % |
| **325 €** | INGRESO MEDIO POR ATLETA |
| **+9 %** | VS TEMPORADA ANTERIOR |

## De dónde salen las altas

Barras horizontales con el número a la derecha:

- Boca a boca — 31
- Instagram — 19
- Buscador — 13
- Colegio — 8
- Competición — 3

Pie: «Se pregunta en un desplegable de la inscripción.»

## Embudo de la prueba

Cuatro escalones con su cifra:

- Reservan prueba — 96
- Vienen el primer día — 81
- Terminan la prueba — 74
- **Se quedan — 68 · 71 %**

## Asistencia media por grupo

Encabezado con nota a la derecha: «ÚLTIMOS 30 DÍAS». Barras horizontales con porcentaje:

| Grupo | % |
| --- | --- |
| Benjamín | 91 % |
| Alevín | 87 % |
| Cadete | 68 % |
| La Tribu | 74 % |
| Madre Tierra | 62 % |
| Natación adultos | 55 % |

Pie: «Sale de la lista del entrenador. Por debajo del 60 % conviene revisar horario o grupo.»

## Cuántos siguen al año siguiente

Título con nota «POR AÑO DE ENTRADA». Tabla de cohortes con columnas `AÑO 1 · AÑO 2 · AÑO 3 · AÑO 4`
y celdas coloreadas:

| Cohorte | Año 1 | Año 2 | Año 3 | Año 4 |
| --- | --- | --- | --- | --- |
| 2023-24 | 100 | 78 | 64 | 57 |
| 2024-25 | 100 | 82 | 69 | — |
| 2025-26 | 100 | 81 | — | — |

Pie: «De cada 100 que entran, 81 siguen al año siguiente y 64 al tercero. Es el número que mejor
mide si el club funciona.»

---

# 6 · Entrenadores, avisos e informe (`17b`)

**Propósito**: «Bloque 5, más lo que hace que esto se use: alertas y el informe de asamblea.»

## Cabecera

Título **EQUIPO TÉCNICO Y ALERTAS**; contexto: «15 entrenadores · datos de los últimos 30 días».
Acción: botón azul **Generar informe de asamblea**.

## Carga por entrenador

Encabezado con nota a la derecha: «MEDIA DEL CLUB: 29 ATLETAS». Tabla con cabeceras
`ENTRENADOR · GRUPOS · ATLETAS · H/SEMANA · FEEDBACK`:

| Entrenador | Grupos | Atletas | H/semana | Feedback |
| --- | --- | --- | --- | --- |
| Andrés Clavero Giménez | Velocidad A y B | 31 | 12 | AL DÍA |
| Nicolás Tucci | La Tribu, fondo, Cubo | 58 | 17 | **7 SIN LEER** (fila resaltada) |
| Claudia Otero | Madre Tierra, Cubo | 34 | 9 | AL DÍA |
| Mario Clavero | Natación escuela y adultos | 47 | 14 | **2 SIN LEER** |
| Sergio Pastor | El Cubo | 22 | 6 | AL DÍA |
| Escuela · 8 técnicos | Prebenjamín a juvenil | 270 | 6-10 | AL DÍA |

## Avisos automáticos

Título con contador **4 ACTIVOS**. Cada aviso lleva su etiqueta de tipo en versalitas:

| Tipo | Texto |
| --- | --- |
| RENOVACIÓN | «Cadete renueva al 61 %, catorce puntos menos que el año pasado.» |
| ASISTENCIA | «Natación adultos lleva tres semanas por debajo del 60 %.» |
| ATLETA | «Marc Server acumula tres faltas seguidas sin avisar.» |
| CARGA | «Nicolás dobla la media de atletas por entrenador.» |

Caja **CUÁNDO SALTAN**: «Renovación por debajo del 70 %, asistencia por debajo del 60 % tres
semanas, impagado por encima del 4 %, tres faltas seguidas o más de 45 atletas por técnico. Los
umbrales se cambian aquí.» + botón **Ajustar umbrales**.

## Informe de asamblea en una página

Tarjeta ancha con miniatura del PDF a la izquierda. Título **INFORME DE ASAMBLEA EN UNA PÁGINA** y
texto: «Un PDF con las cifras de la temporada, la comparativa con el año anterior y los cuatro
gráficos principales: inscritos, economía, retención y asistencia. Se genera con un botón y sale
listo para repartir en la asamblea de socios.»

Botones: **Generar PDF** (azul) y **Ver el del año pasado**.

---

# 7 · Estadísticas de la temporada (`15b`)

**Propósito**: «Escuela y club por separado, siempre contra el año anterior.»

## Cabecera

Título **ESTADÍSTICAS**; contexto: «Temporada 2026-27 · comparada con 2025-26». Acciones:
desplegable **Temporada 2026-27 ▾**, chips **Escuela** / **Club** y botón **Exportar**.

## Fila de seis contadores

| Etiqueta | Cifra | Comparativa |
| --- | --- | --- |
| TOTAL DEPORTISTAS | **438** | «+18 vs 2025-26» |
| SOCIOS DEL CLUB | **168** | «+12» |
| ESCUELA | **270** | «+6» |
| ALTAS NUEVAS | **74** | «62 el año pasado» |
| RENOVACIÓN | **81 %** | «−3 pts» |
| BAJAS | **56** | «48 el año pasado» |

## Inscritos por temporada

Gráfico de barras apiladas con leyenda **Escuela** / **Club** y eje `22-23 · 23-24 · 24-25 · 25-26 ·
26-27`; la última barra lleva la cifra **438** encima.

## Chicas y chicos

Barra de proporción partida: **46 %** / **54 %**, con las cifras debajo: «201 chicas» y «237
chicos». Pie: «La escuela ya está al 49 % de niñas, tres puntos más que el año pasado.»

## Familias

Cuatro filas clave-valor:

- Familias con más de un hijo — **64**
- Hermanos con descuento — **71**
- Padres que entrenan en El Cubo — **38**
- Familias también socias — **52**

## Por categoría

Encabezado con nota «ESCUELA · 270 ATLETAS». Barras horizontales:

Prebenjamín 42 · Benjamín 61 · Alevín 55 · Infantil 46 · Cadete 38 · Juvenil 28.

Pie: «El salto de cadete a juvenil sigue siendo el punto donde más gente se pierde: −26 % de un año
a otro.»

## Por sección · club

Barras horizontales: Running 64 · Pista 44 · Triatlón 52 · Natación 37 · Montaña 31 · El Cubo 47.

Pie: «Un socio puede estar en varias secciones: la suma pasa de 168.»

---

# 8 · Pasar las cuotas del mes (`11c`)

**Propósito**: «Remesa SEPA por cuenta: la de la escuela y la del club, separadas.»

## Cabecera

Título **CUOTAS DE AGOSTO**; contexto: «Se giran el día 3 · quedan 5 días». Acciones:
**Exportar para la gestoría** (contorno) y **Generar remesas** (azul relleno).

## Dos tarjetas de remesa

**REMESA · CUENTA DE LA ESCUELA** — IBAN `ES91 ··· 1332` — importe **7.940 €** — «218 recibos».
Desglose:
- «Escuela atletismo · 2ª cuota» — 164 · 5.740 €
- «Escuela natación · mensual» — 54 · 2.200 €

**REMESA · CUENTA DEL CLUB** — IBAN `ES44 ··· 8907` — importe **6.310 €** — «142 recibos».
Desglose:
- «Entrenamiento de secciones» — 128 · 5.420 €
- «Bonos de El Cubo» — 14 · 890 €

## Filtros

Chips: **Todos · 360** (activo) · `Sin mandato · 4` · `Devueltos el mes pasado · 6` ·
`Bajas de este mes · 3`.

## Tabla de recibos

Cabeceras: `NOMBRE · CONCEPTO · CUENTA · MANDATO · IMPORTE · ESTADO`.

| Nombre | Concepto | Cuenta | Mandato | Importe | Estado |
| --- | --- | --- | --- | --- | --- |
| Pau Ripoll Sánchez | Escuela · 2ª cuota | Escuela | Firmado | 124 € | LISTO |
| Jorge Castell Marí | La Tribu · agosto | Club | Firmado | 60 € | LISTO |
| Aitana Sanz Poveda | Bono El Cubo · 20 usos | Club | Firmado | 90 € | LISTO |
| Lucía Bernabéu Ortiz | Escuela · 2ª cuota | Escuela | **Sin firmar** | 124 € | **Pedir mandato** (fila ámbar) |
| Marc Server Lledó | Natación · julio devuelto | Escuela | Firmado | **45 € + 3 €** | **Reclamar** (fila roja) |
| Nora Sempere Gil | Natación · agosto | Escuela | Firmado | 45 € | LISTO |

La columna «Cuenta» va coloreada según sea Escuela o Club.

---

# 9 · Biblioteca de imágenes (`10a`)

**Propósito**: «Todas las fotos del club en un sitio, con etiquetas, buscador y aviso de dónde se
está usando cada una.» Idea de fondo: en lugar de crear un hueco con nombre fijo cada vez que
aparece una página nueva, una biblioteca común: se sube la foto una vez, se recorta y luego cada
hueco de la web la elige.

## Barra lateral

Cabecera «Apolana / ADMINISTRACIÓN». Grupo `CONTENIDO WEB`: **Biblioteca de imágenes** (activo) ·
Huecos de la web · Noticias · Eventos · Aviso de portada.

Debajo, bloque **ETIQUETAS** con su recuento:

Escuela 64 · Competición 128 · Running 41 · Natación 22 · Montaña 18 · Retratos 31 · Histórico 57.

## Cabecera del contenido

Título **BIBLIOTECA DE IMÁGENES**; contexto: «361 fotos · 2,4 GB · se recortan solas al colocarlas».
A la derecha: campo de búsqueda con marcador «Buscar por etiqueta o nombre…» y botón azul
**Subir fotos**.

## Filtros y selección

Chips: **Todas** (activo) · `Sin usar` · `Horizontales` · `Verticales` · `Este año`. A la derecha,
contador **3 seleccionadas** y acción **Etiquetar**.

## Rejilla de fotos

Miniaturas con insignia superpuesta cuando procede: **EN PORTADA** (azul), **EN 3 SITIOS**,
**SIN USAR** (ámbar). La foto seleccionada va recuadrada en azul. Una celda de la rejilla es la zona
de subida: `+` y el texto «Arrastra fotos aquí».

## Panel de detalle de la foto

- Vista previa grande.
- Nombre: **Salida de tacos · Castellón**.
- Datos técnicos: «3648 × 2432 · 1,8 MB · JUN 2026».
- Etiquetas como chips: `competición`, `pista`, y acción **+ etiqueta**.
- **SE ESTÁ USANDO EN** — lista: «Portada · hero» y «Noticia "Tres podios en Xixona"».
- Botones: **Recortar y encuadrar** (contorno) y **Colocar en un hueco…** (azul relleno).

---

# 10 · Huecos de la web (`10b`)

**Propósito**: «Mapa completo por página; en ámbar, los que hoy no existen en tu admin.»

## Cabecera

Título **HUECOS DE LA WEB**; contexto: «Cada hueco elige una foto de la biblioteca. El recorte se
calcula solo según el formato.» Acciones: chip **Solo vacíos · 9** y botón azul **Ver web**.

## PORTADA

Cuatro huecos en tarjeta con miniatura, nombre y formato:

| Hueco | Formato / estado |
| --- | --- |
| Hero | 3:2 · 1600 px |
| Tarjeta «Para mi hijo» | **NUEVO** · 3:2 (ámbar) |
| Tarjeta «Para mí» | **NUEVO** · 3:2 (ámbar) |
| Mosaico · 6 fotos | 1:1 · completo |

## CABECERAS DE PÁGINA

Diez fichas con estado **PUESTA** o **NUEVO** (las nuevas, en ámbar):

Calendario PUESTA · Noticias PUESTA · Hazte socio PUESTA · Historia NUEVO · Normativa NUEVO ·
Palmarés NUEVO · Récords NUEVO · Contacto NUEVO · Campus PUESTA · Secciones PUESTA.

## GALERÍAS · MÁXIMO 8 POR PÁGINA

Fichas con el contador de fotos usadas:

Escuela atletismo 6/8 · Running 8/8 · Pista 5/8 · Natación 0/8 · Montaña 4/8 · Triatlón 0/8 ·
El Cubo 3/8 · Instalaciones 7/8 · Cartel del campus **NUEVO** · Escuela natación **NUEVO** ·
Municipales y adaptado **NUEVO**.

## RETRATOS · AHORA COMO LISTA

Tarjeta con etiqueta **CAMBIO**: «En vez de cuatro huecos fijos de entrenador, cada grupo trae el
suyo: si mañana hay un grupo nuevo, aparece solo su hueco de foto. Igual con la junta directiva.»
Debajo, chips con foto: Nicolás Tucci · Claudia Otero · Andrés Clavero Giménez · Mario Clavero ·
**+ nuevo**.

## INSTAGRAM

Tarjeta azul claro: «Las seis fotos de la home dejan de subirse a mano: se leen del feed de
@apolana.alicante y se actualizan solas.» + enlace **Conectar la cuenta →**.

---

# 11 · Plantillas de email y notificación (`20a`)

**Propósito**: «Lo que el club manda de verdad, escrito una vez.»

## Cabecera

Título **PLANTILLAS**; contexto: «9 automáticas · se envían solas cuando pasa algo». Acción: botón
azul **Guardar**.

## Columna izquierda · CUÁNDO SE ENVÍA

Lista de las nueve plantillas; cada una con su nombre y, debajo, el canal y el matiz. La activa va
resaltada en azul claro:

| Plantilla | Canal / matiz |
| --- | --- |
| **Inscripción completada** (activa) | Email · con credenciales |
| Recibo cobrado | Email + notificación |
| Recibo devuelto | Email · con enlace de pago |
| Entrenamiento suspendido | Notificación · urgente |
| Recordatorio de competición | Notificación · 48 h antes |
| Cierra la inscripción | Email · 5 días antes |
| Acaba el periodo de prueba | Email a la familia |
| Tres faltas sin avisar | Email al entrenador y familia |
| Ropa lista para recoger | Notificación |

## Columna central · editor

Título de la plantilla en condensada: **INSCRIPCIÓN COMPLETADA**, con interruptor de activación a la
derecha (encendido).

| Campo | Contenido de ejemplo |
| --- | --- |
| **Asunto** | «Bienvenido al Club Apolana, {nombre}» |
| **Cuerpo** | «Hola {nombre_familia}: / {nombre} ya está inscrito en {grupo}. Empieza el {fecha_inicio} a las {hora} en {instalacion}. / Para entrar en la app y ver los entrenamientos, pon tu contraseña aquí: {enlace_contrasena} / El primer recibo, de {importe}, se girará el {fecha_cobro} en la cuenta {iban_oculto}.» |

Debajo, chips de variables insertables: `{nombre}` · `{grupo}` · `{importe}` · `{instalacion}` ·
`{enlace_contrasena}`.

## Columna derecha · CÓMO LLEGA

Vista previa del correo tal y como lo recibe la familia:

- Remitente: **Club Apolana** · `escuela.apolana@gmail.com`
- Asunto: **Bienvenido al Club Apolana, Pau**
- Cuerpo recortado: «Hola Marta: Pau ya está inscrito en Escuela · Benjamín. Empieza el lunes 8 de
  septiembre a las 17:30 en la Pista Joaquín Villar…»
- Botón del correo: **Crear mi contraseña**

Debajo, caja **Firma común**: «Los correos de escuela salen con el teléfono y la cuenta de la
escuela; los del club, con los suyos. La plantilla lo elige sola según de quién sea el recibo.»

---

# 12 · Reglas del test y familias en admin (`20b`)

**Propósito**: «Qué grupo recomienda cada respuesta, y los ajustes de cuota aprobados.»

## 12.1 · Encuentra tu grupo

Cabecera: título **ENCUENTRA TU GRUPO**; contexto: «6 reglas · se aplican de arriba abajo, gana la
primera que encaje». Acciones: **Probar el test** (contorno) y **Guardar reglas** (azul).

Tabla con cabeceras `# · PARA QUIÉN · QUÉ BUSCA · DÍAS · RECOMIENDA` + acción:

| # | Para quién | Qué busca | Días | Recomienda |
| --- | --- | --- | --- | --- |
| 1 | Mi hijo/a | Cualquiera | — | Escuela por edad |
| 2 | Para mí | Coger el hábito | 2-3 días | Madre Tierra |
| 3 | Para mí | Bajar mi marca | 3 o más | La Tribu (fila en edición → **Guardar**) |
| 4 | Para mí | Competir en pista | 3 días | Velocidad B |
| 5 | Para mí | Competir en pista | 4 o más | Velocidad A |
| 6 | Para mí | Montaña o triatlón | — | Triatlón o montaña |

Panel lateral **QUÉ SE ENSEÑA DESPUÉS**, tres interruptores (los tres encendidos):

- Dos alternativas
- Precio con cuota de socio
- Botón «que me llamen»

Caja crema **Grupos completos**: «Si el grupo recomendado no admite inscripciones, el test propone
el siguiente de la lista y avisa de que hay lista de espera.»

## 12.2 · Familia Apolana

Cabecera: título **FAMILIA APOLANA**; contexto: «86 familias · 1.940 € al mes en descuentos · 1,4 %
de los ingresos». Acciones: **Editar reglas** (contorno) y **Nuevo ajuste de junta** (azul).

Tabla con cabeceras `FAMILIA · MIEMBROS · RECIBO · DESCUENTO` + acción **Ver**:

| Familia | Miembros | Recibo | Descuento |
| --- | --- | --- | --- |
| Ripoll Sánchez | 2 hijos · madre · padre | 138,5 € | −23,0 € |
| Ferriz Coral | 3 hijos · madre | 129,4 € | −41,6 € |
| Bernabéu Ortiz | 2 hijos · **ajuste de junta** | 45,0 € | **−55 %** (fila ámbar) |
| Server Lledó | 1 hijo · padre | 75,0 € | −10,0 € |
| Castell Marí | padre · madre | 96,0 € | −6,0 € |
| Sanz Poveda | 1 hija · madre · padre | 112,0 € | −14,5 € |

### Panel «Ajuste excepcional»

Etiqueta **SOLO JUNTA**. Texto: «Fuera de las reglas automáticas, la junta puede fijar una cuota
distinta para una familia. Queda registrado con motivo, importe y fecha de revisión, y no aparece en
ningún listado público.»

| Campo | Control | Valor de ejemplo |
| --- | --- | --- |
| Familia | Texto / buscador | Bernabéu Ortiz |
| Cuota acordada | Importe (campo con foco) | 45,00 € |
| Revisar en | Selector de mes | Junio 2027 |
| Motivo · solo lo ve la junta | Área de texto | «Situación familiar sobrevenida. Acordado en junta del 12 de julio.» |

Botón azul a todo el ancho: **Aprobar ajuste**.

Caja crema al pie: **4 ajustes vigentes** — «185 € al mes. Se revisan todos en junio, antes de
cerrar la temporada.»

---

## Diferencias con lo que hay hoy

Comparado con `/admin/index.html` y los trece módulos existentes: `/admin/atletas/`,
`/admin/biblioteca/`, `/admin/competiciones/`, `/admin/contenido/`, `/admin/documentos/`,
`/admin/estadisticas/`, `/admin/eventos/`, `/admin/grupos/`, `/admin/historico/`, `/admin/paginas/`,
`/admin/palmares/`, `/admin/pruebas/` y `/admin/records/`.

### Lo que sí está alineado

- **Aviso de portada**: existe en el panel principal, con niveles «Informativo (azul) / Importante
  (ámbar) / Urgente (rojo)», caducidad, enlace y estado activo. Coincide con la maqueta.
- **Palmarés y récords**: existen como módulos propios.
- **Documentos y normativa**: existe `/admin/documentos/` con categorías y visibilidad
  público/socios, que va más allá de lo dibujado.
- **Competiciones y bono**: `/admin/competiciones/` gestiona circular, coste, inscripciones y saldo
  de bono; la maqueta no llegaba a ese detalle.
- **Histórico de la escuela**: `/admin/historico/` cubre buena parte del cuadro de mando de la
  escuela (apuntados por temporada, conversión de la prueba, nuevos y renovaciones, categorías,
  captación, sexo, turnos).

### Tabla de diferencias, de más a menos importante

| Elemento de la maqueta | ¿Existe hoy? | Qué falta o difiere |
| --- | --- | --- |
| **Inicio del panel** (`5a`): cuatro contadores (Inscritos, Impagados, En prueba, Ropa pendiente), «Alertas de hoy · 6 sin resolver» con acción por alerta, accesos rápidos, aviso activo en portada y tabla de últimos inscritos | No | El panel principal abre directamente en «Noticias». No hay pantalla de inicio, ni contadores, ni alertas, ni accesos rápidos, ni últimos inscritos. Es la diferencia más visible de todas |
| **Editor de tarifas** (`18b`): pestañas Club/Escuela/El Cubo/Campus/Cuota de socio, precio socio y no socio, periodicidad, panel «afecta a», fecha de entrada en vigor, aviso por email e histórico de cambios | No | No existe ningún editor de tarifas. Los precios viven como texto libre en el campo «Precio» de `/admin/paginas/` y `/admin/contenido/`, así que el mismo dato se repite y se descuadra entre páginas |
| **Pasar las cuotas del mes** (`11c`): dos remesas SEPA por cuenta con IBAN y desglose, filtros (sin mandato, devueltos, bajas), tabla de recibos con mandato y estado, «Generar remesas» y «Exportar para la gestoría» | No | No existe ningún módulo de cobros ni de remesas. Los pagos solo se ven como dos totales en `/admin/estadisticas/` |
| **Grupos con turnos y responsable** (`18c`): nacidos entre, plazas, sede, tarifa aplicada, turnos con selector de días `L M X J V` y horas, responsable con foto y titulación, otros técnicos, «dónde se ve este grupo» e interruptor «Admite inscripciones» | Parcial | `/admin/grupos/` solo tiene Nombre, Sección, Horario (texto libre), Descripción y Activo. Faltan turnos estructurados, plazas, sede, tarifa, responsable y técnicos, y el cierre a nuevas inscripciones |
| **Cuadro de mando económico y de actividad** (`17a`): ingresos por mes escuela/club, impagado, ingreso medio, origen de las altas, embudo de la prueba, asistencia por grupo y retención por cohorte | Parcial | `/admin/estadisticas/` solo da 7 contadores y 2 totales de cobros. `/admin/historico/` cubre embudo y captación, pero **solo de la escuela**. No hay ingresos por mes, ni asistencia por grupo, ni cohortes del club |
| **Alertas y avisos automáticos con umbrales** (`5a`, `17b`): impago, fin de periodo de prueba, faltas seguidas, renovación baja, asistencia baja, carga por técnico, y «Ajustar umbrales» | No | No hay ningún sistema de alertas internas. Las únicas «alertas» del panel son la barra pública de aviso de portada |
| **Plantillas de email y notificación** (`20a`): nueve plantillas automáticas, editor de asunto y cuerpo con variables, interruptor por plantilla, vista previa y firma según escuela o club | No | No existe. Ningún correo ni notificación se gestiona desde el panel |
| **Familia Apolana** (`20b`): tabla de familias con recibo y descuento, reglas de descuento y ajuste excepcional de la junta con motivo, importe y fecha de revisión | No | No existe. Tampoco hay concepto de familia ni de descuento en el panel |
| **Reglas del test «encuentra tu grupo»** (`20b`): seis reglas ordenadas con para quién / qué busca / días / recomienda, «Probar el test», qué se enseña después y comportamiento con grupos completos | No | No existe |
| **Mapa de contenido** (`18a`): 32 bloques editables con dónde salen, quién los edita y cuándo se actualizaron, filtro «solo desactualizados» y la regla de dato único | No | No existe. Y la realidad se aleja del principio: `/admin/contenido/` y `/admin/paginas/` se solapan editando lo mismo |
| **Biblioteca de imágenes** (`10a`): etiquetas con recuento, buscador, filtros (sin usar, horizontales, verticales, este año), selección múltiple, «se está usando en», recorte y encuadre, «colocar en un hueco» | Parcial | `/admin/biblioteca/` es una rejilla del bucket con «Copiar enlace» y «Borrar». Sin etiquetas, sin buscador, sin filtros, sin saber dónde se usa cada foto y sin recorte |
| **Huecos de la web** (`10b`): mapa por página de portada, cabeceras y galerías con su formato y su estado, retratos como lista por grupo y feed de Instagram | No | No existe. Solo se puede poner una imagen de cabecera por página desde `/admin/paginas/` |
| **Estadísticas de temporada del club** (`15b`): total deportistas, socios, escuela, altas, renovación, bajas, inscritos por temporada, chicas y chicos, familias, por categoría y por sección, siempre contra el año anterior | Parcial | Existe solo para la escuela (`/admin/historico/`). Faltan las cifras del club, el reparto por sección, el bloque de familias y la comparativa contra el año anterior en el módulo de estadísticas |
| **Informe de asamblea en PDF** (`17b`) | No | No existe |
| **Menú lateral por grupos** (`5a`: PANEL / GESTIÓN / CONTENIDO WEB / VER COMO; `18a`: CONTENIDO / DÍA A DÍA) | Parcial | Hoy el menú es una lista de botones (Noticias, Avisos de portada, Tienda, Buzón) más un separador «Más gestión» y trece enlaces sueltos. No hay agrupación por tema ni «Ver como» (entrenador / atleta / familias) |
| **Gestión de inscritos** (`5a`: entrada «Inscritos», tabla con sección, grupo, estado y pago, chips Escuela/Club y exportación) | Parcial | `/admin/atletas/` tiene ficha de atleta (nombre, correo, fecha, categoría, estado, grupo, especialidades) pero sin vista de inscritos con estado de pago, sin chips escuela/club y sin exportar |
| **Periodos de prueba** (`5a`: contador «En prueba 9 · 3 acaban esta semana» y alerta con «Confirmar alta») | No | Solo existe el valor de estado «Prueba» en la ficha del atleta y un contador en `/admin/estadisticas/` |
| **Control de ropa** (`5a`: «Ropa pendiente 27 sin entregar», alerta «12 equipaciones… sin repartir», acceso rápido «Control de ropa») | No | No existe. Solo hay alta de productos con tallas y stock |
| **Pedidos de la tienda** (`5a`: alerta «4 pedidos de camiseta esperando confirmación · Revisar») | No | La tienda gestiona el catálogo, pero no hay pedidos, ni estados, ni entregas |
| **Campus** (`18a`: bloque editable «Campus de verano», y `18b`: pestaña «Campus» en tarifas) | No | Hay página pública de campus sin ningún editor en el panel |
| **Responsables de sección, junta directiva, FAQ de familias, instalaciones, historia y cronología, textos legales** (`18a`) | No | Ninguno tiene módulo propio. «Instalaciones» solo existe como una de las páginas editables |
| **Feed de Instagram** (`10b`) | No | No existe |
| **Buzón de contacto y solicitudes de inscripción** | Existe hoy, **no está en la maqueta** | Función útil que el diseño no contempla; conviene incorporarla |
| **Catálogo de pruebas** (`/admin/pruebas/`) y **ficha de atleta con especialidades** | Existen hoy, **no están en la maqueta** | Ídem: son la base del registro de marcas y del cálculo de ritmos, y deben conservarse |
