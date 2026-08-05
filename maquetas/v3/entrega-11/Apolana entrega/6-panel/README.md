# 6 · El panel

Para quien implementa. Diez pantallas rehechas, la navegación unificada y **seis piezas
compartidas** que hay que escribir una sola vez.

**Archivo visual:** `Panel Apolana.html`. Tres turnos, el mas nuevo arriba:

1. **Arriba — el historial** (3a, 3b, 3c). Ver «El historial de entrenamientos» mas abajo.
2. **En medio — las siete reglas**, las seis piezas compartidas, la barra unica, Familia,
   Tarifas y Pedidos.
3. **Abajo — las seis restantes** (2a-2e): Planificar un entreno, Calendario, Documentos e
   Historico, Usuarios, Plantillas y Mapa de contenido.

---

## El diagnóstico

Palabras del club: «hay ventanas con sobreinformación, o que no están bien optimizadas».

Dicho con precisión: **no sobra información, sobra información a la vez.** Un entrenador a
pie de pista necesita tres cosas en pantalla; el resto puede estar **plegado, no ausente**.

La causa es conocida: la web está maquetada, los paneles no. 55 pantallas, doce con maqueta.

---

## Lo primero: haced las seis piezas

**Esto no es opcional y es la única cosa en la que contradigo el encargo.** El brief dice que
las 7.900 líneas de estilo repartidas no hace falta tocarlas ahora. Sin una hoja común, estas
reglas hay que aplicarlas 55 veces a mano y se desharán una por una — por eso hoy hay botones
de 44 px al lado de otros de 19.

**No hay que refactorizar las 55.** Basta con extraer seis piezas y usarlas en las diez que
se van a tocar. Las otras 45 se migran cuando se toquen por otra cosa.

Ya existe el juego común de estados de carga, vacío y error, y funciona. **Es la prueba de que
el mismo enfoque sirve para la forma.**

### 1 · Cabecera de pantalla

En todas las pantallas del panel, sin excepción.

- Título: **Barlow Condensed 700**, 34 px en escritorio, 30 px en móvil, uppercase, `#2E4256`.
- Debajo, una línea de contexto con las cifras: **15px/1.4** `#6E6656`.
  Ej. «Temporada 2026-27 · 14 tarifas».
- A la derecha, **la acción principal**: alto **44 px**, píldora, `#2F72AB`, texto 15 px peso
  500 blanco. En móvil baja a ancho completo bajo el título.

### 2 · Barra de filtros

**Una fila y solo una.** Alto 44 px en todo.

- Buscador: radio 10 px, borde `#C6BEAE`, texto 15 px, placeholder `#6E6656`.
- Chips **con su cifra dentro**: activo `#2E4256`/blanco · inactivo borde `#C6BEAE` sobre
  blanco · de aviso `#FDF6EA` con texto `#8A5207` y borde `#EBD9B8`.
- «Filtrar» para el resto, con la cuenta de filtros activos en un chip `#EAF2F9` / `#1E4E78`.

**La cifra va dentro del chip, nunca en una tarjeta de resumen aparte.**

### 3 · Fila de tabla

- Padding **15px 18px**, separador `1px solid #EFE9DC`.
- Cabecera sobre `#F1EADC`, texto **13 px peso 500** con `letter-spacing: 0.04em` en
  mayúsculas, `#6E6656`.
- Dato principal **16px/1.35** `#2E4256`; línea de contexto debajo **14px/1.35** `#6E6656`.
- Columnas de ancho fijo. Estado en chip. **Un solo «⋯»** al final, 18 px, `#6E6656`.
- **En edición:** la fila se tiñe de `#EAF2F9`, padding baja a 11 px y los campos son de
  **44 px** (radio 8 px, borde `#2F72AB` en el activo). «Editar» pasa a «Hecho».

### 4 · Ficha de móvil

Es la fila de tabla cuando hay **más de cuatro columnas**.

- Radio 12 px, borde `#E4DCCB`, fondo blanco, padding **15px 16px**, gap 9 px.
- Arriba: dato principal + línea de contexto, y el «⋯» a la derecha.
- Pie separado por `1px solid #EFE9DC`: **chip de estado** a la izquierda, **«Más detalles ▾»**
  a la derecha en `#2F6FA8`.
- Los detalles son pares etiqueta/valor de **14px/1.4** (`#6E6656` / `#2E4256`).

### 5 · Campo y bloque plegable

El campo es **el mismo que en los formularios de la web** — está documentado en el paquete 5.

- Campo alto **52 px**, radio 10 px, borde `#C6BEAE`, texto 16 px.
- Label encima 15 px peso 500. Ayuda debajo **14px/1.45** `#6E6656`.
- Si hace falta más explicación: **«¿Cómo funciona?»** a la derecha del label, que abre encima.
- Plegable: fila de **52 px**, radio 10 px, borde `#E4DCCB`, nombre 16px/1.35 y flecha `▾`.

### 6 · Franja de guardado

**No existe hasta que hay algo que guardar.**

- Fondo `#2E4256`, padding 14px 18px, anclada abajo.
- Texto blanco 15px/1.35 diciendo **cuántas cosas has cambiado**.
- «Descartar» en texto `#8FC0E8`; «Guardar» en **píldora blanca** de 42 px con texto `#1E4E78`.

**Sobre navy el botón se invierte, no se pone azul sobre azul.**

---

## Las siete reglas

Valen para las 55, no solo para las diez.

| # | Regla | Arregla |
|---|---|---|
| 1 | **Una acción principal, y arriba.** Cada pantalla tiene una cosa que la gente viene a hacer: va arriba, en botón sólido, antes de cualquier dato. Lo demás son enlaces o botones perfilados. | Familia · Plantillas · Usuarios |
| 2 | **Nada apagado en primer plano.** Un botón deshabilitado no puede ser lo más llamativo. Si no hay cambios, el botón **no está**. | Tarifas |
| 3 | **Cada número se dice una vez.** Contadores arriba + filtros debajo son lo mismo: se fusionan. | Pedidos · Mapa · Familia |
| 4 | **Los mandos nunca antes del dato.** Como máximo una fila; el resto detrás de «Filtrar». | Calendario · Pedidos · Histórico |
| 5 | **La tabla en móvil es ficha.** Por encima de cuatro columnas: dos datos visibles, resto plegado, una sola acción. | Documentos · Histórico · Usuarios |
| 6 | **La ayuda va junto al campo y plegada.** Ocho párrafos arriba no los lee nadie. | Planificar un entreno |
| 7 | **Un formulario dentro de otra pantalla sale a su página.** Regla práctica: **si tiene más de seis campos o su propio botón de guardar, es una pantalla.** | Planificar un entreno |

---

## Las pantallas

### La barra única · navegación

Hoy hay **dos barras superiores pegadas**: «Estás como atleta · Cambiar» y debajo otra oscura
con «Ir a la web · Cambiar de perfil · [nombre] · Salir». De ahí el «no sé dónde están las
cosas»: **cambiar de papel y cambiar de perfil son dos cosas distintas y compiten en el mismo
sitio**.

**Una sola barra**, alto 52 px, fondo `#2E4256`:

- **Izquierda:** escudo 26 px + «APOLANA» (Barlow Condensed 700, 18 px, `letter-spacing:
  0.03em`). El logo **es** «ir a la web».
- **Derecha, dos controles y nada más:**
  - **Píldora del papel** — lo que estás haciendo ahora. `background: rgba(255,255,255,0.14)`,
    padding 8px 14px, texto 14 px peso 500 blanco, con `▾`.
  - **Avatar** — 32 px, `#8FC0E8` con iniciales en `#1E4E78` 13 px peso 600. Abre lo tuyo:
    perfil, hijos, salir.

**Cada papel dice de qué:** «Entrenador · Verde 1 y Verde 2», «Familia · Lucía y Pablo»,
«Administración». Sin eso, alguien con cuatro papeles no sabe cuál abre qué. **Es la misma
etiqueta que en la tabla de Usuarios.**

**Si solo tienes un papel, la píldora no aparece.** La mayoría del club está en ese caso: para
ellos la barra es logo y avatar.

### 1 · Planificar semana

**Una rejilla de días, no un formulario.** Tres columnas en escritorio, una en móvil.

Cabecera: «Planificar la semana» + «Verde 1 · del 8 al 14 de septiembre · **2 de 3 sesiones
puestas**» + botón «Nuevo entreno».

Una fila de mandos: navegador de semana (`← 8-14 sep →`), selector de grupo, y «Copiar de otra
semana» como enlace a la derecha.

Cada día es una tarjeta:

- Cabecera sobre `#F1EADC` con el día y la hora.
- Tipo de sesión (16px/1.35), resumen (14px/1.45 `#6E6656`).
- Pie separado: **chip de estado** + **«Abrir»** en `#2F6FA8`.
- Estados: **Publicado** (`#EDF5EE`/`#2F5C39`) · **Borrador** (`#FDF6EA`/`#8A5207`).
- **El día vacío se ve vacío:** borde `1.5px dashed #C6BEAE`, fondo `#FBF9F4`, texto «Sin
  entreno puesto» y su propio botón perfilado «Planificar este día».

Y una banda ámbar al final: **«El borrador del miércoles no lo ve la familia hasta que lo
publiques. Los atletas ven solo los publicados.»** Un entrenador no debe dudar de si la
familia ya lo ha visto.

### 2 · Planificar un entreno · reglas 6 y 7

**Sale de dentro de «Planificar semana» a su propia pantalla**, con tres pasos: qué grupo y qué
día · **el contenido** · las notas. Barra de progreso de 4 px, `#2F72AB`.

- Título del paso + línea de contexto («Verde 1 · miércoles 10, 17:30»).
- **Los ocho párrafos de explicación desaparecen:** una línea de ayuda bajo el campo que la
  necesita, y «¿Cómo funciona?» al lado del label.
- **Lo que casi nadie toca va plegado, no fuera:** «Ajustes avanzados» y «Repetir esta sesión».
- Pie: «Siguiente · las notas» y **«Guardar como borrador»** como texto.
- Al guardar, vuelve a la semana.

### 3 · Familia · reglas 1 y 3

- **«Avisar de una falta» sube a lo primero**, botón sólido de 54 px debajo del nombre. Es lo
  que más hace un padre y estaba en tercera posición.
- **Los pagos se dicen en un solo sitio:** una franja de una línea sobre `#F1EADC` con el
  estado («Pagos al día») y el siguiente recibo («1 de octubre, 96 €»), con `›`. Estaban en
  cinco sitios.
- **Las cinco tarjetas de «Entreno» pasan a dos líneas** —lo de esta semana— y «Ver el mes
  entero».
- Lo demás baja a una **lista de secciones** con `›`, no cinco tarjetas: datos, pedidos de ropa
  (con chip «1 preparando»), documentos y permisos, competiciones.

### 4 · Calendario · regla 4

- **La tarjeta azul del día va primero.** Una sola por pantalla y solo para lo de hoy: fondo
  `#2F72AB`, línea de contexto en `rgba(255,255,255,0.75)`, nombre grande, y dos botones —
  blanco sólido «Ver el entreno» y perfilado «No voy».
- **El bono y la próxima competición suben antes del calendario.** Caían al final del todo y
  son un dato, no un pie.
- **Las tres barras de mandos pasan a una** —mes + «Filtrar»— y van **después** de la tarjeta
  de hoy: lo primero que quiere ver alguien es lo de hoy, no cómo filtrar.
- La lista por días: encabezado de día en versalitas, filas con hora en 50 px `#2F6FA8`.

### 5 · Tarifas · reglas 2 y 4

- **El botón azul de arriba es «Nueva tarifa»**, no «Guardar». Lo que destaca es lo que se
  puede hacer siempre.
- **«Guardar» no existe hasta que hay algo que guardar** → aparece la franja de guardado
  (pieza 6) diciendo «Has cambiado 1 tarifa».
- **Los precios se editan en la fila**, en campos de 44 px. No rompen la rejilla porque toda la
  fila crece. «Editar» pasa a «Hecho».
- Los recuadros de 31 px desaparecen: **44 px mínimo**.
- Una sola fila de mandos: buscador + «Filtrar» con la cuenta.

### 6 · Pedidos de ropa · reglas 3 y 5

- **Las cuatro tarjetas de resumen desaparecen.** La cifra vive dentro del filtro: «Todos 23 ·
  Preparando 8 · Entregados 15». Un número, un sitio — antes «Preparando 8» arriba y
  «Preparando 1» debajo decían cosas distintas a la vez.
- **Los cuatro mandos por fila pasan a un menú «⋯».** En la fila solo queda el estado, que es
  el dato que se mira.

### 7 · Usuarios y permisos · reglas 1, 3 y 5

- **La lista de personas es lo primero.** Estaba a tres pantallas de scroll y es a lo que va
  todo el mundo.
- **La rejilla de ocho cifras desaparece.** Se quedan las dos que se usan —«Con panel 12» y
  «Sin verificar 7»— dentro de los filtros. El total va en la línea bajo el título.
- Columnas: Persona (nombre + correo) · Papeles · Estado · «⋯».
- **Los papeles dicen de qué**, como chips `#EAF2F9`/`#1E4E78`: «Entrenador · Verde 1 y 2»,
  «Familia · Lucía y Pablo». Misma etiqueta que en la barra.
- En móvil, esta tabla **es la ficha de la pieza 4**.

### 8 · Plantillas de correo · reglas 1 y 4

- **Una columna con la lista**, no tres a la vez.
- **La plantilla se edita a pantalla completa.** Escribir un correo en una columna de 300 px no
  se puede.
- **Un solo botón sólido.** Arriba «Nueva plantilla»; dentro de la plantilla, «Guardar la
  plantilla». Nunca dos azules compitiendo.
- Cada fila: nombre + «cuándo se envía · usada N veces», «Abrir» y «⋯». Las sin usar llevan la
  línea en `#8A5207`.

### 9 · Documentos · regla 5

**Ficha (pieza 4).** Nombre del documento + «Firmado el …» arriba, chip de vigencia, y «Más
detalles» para tipo, referencia y a quién cubre. **Los cuatro botones por fila van al «⋯».**

### 10 · Mapa de contenido · reglas 3 y 5

- **Fuera el medidor:** repetía exactamente lo que ya dicen las etiquetas.
- **Un enlace por fila**, alto **60 px**, y la etiqueta como chip a la derecha («Al día»,
  «Sin foto», «Sin horario»). Nada de dos enlaces pegados en la misma línea, ni enlaces de
  18 px.

### 11 · Histórico de la escuela · regla 5

Misma ficha que Documentos. Trece columnas: **tres visibles** (nombre, temporada+grupo+días,
estado) y el resto detrás de «Ver las 13 columnas». **En el código ya hay etiquetas preparadas
para esta vista** — alguien la pensó y no llegó a escribirla.

Y arreglar la franja de tablet en vertical.

---

## Las tarjetas azules en degradado

Al club le gustan mucho, y **aquí es donde funcionan** — no en los formularios.

**Son para la sesión del día y para nada más.** Una por pantalla, arriba, con la línea de
contexto, el nombre grande y los dos botones.

**El riesgo de que gusten tanto es usarlas para todo:** si hay tres tarjetas azules en una
pantalla, ninguna es la importante. **Regla: una sola por pantalla, y solo para lo que pasa
hoy.**

---

## Tokens

Los mismos del paquete 5. Los que más se usan aquí:

| Uso | Hex |
|---|---|
| Barra, franja de guardado, chip activo | `#2E4256` |
| Botón primario, tarjeta del día | `#2F72AB` |
| Enlaces y acciones en fila | `#2F6FA8` |
| Sobre navy: enlaces y avatar | `#8FC0E8` · texto del botón invertido `#1E4E78` |
| Fila en edición, chips de papel | `#EAF2F9` |
| Fondo base | `#FBF9F4` |
| Cabecera de tabla, franjas alternas | `#F1EADC` |
| Borde de campo | `#C6BEAE` |
| Borde de tarjeta / separador | `#E4DCCB` / `#EFE9DC` |
| Texto cuerpo / metadatos | `#4A4437` / `#6E6656` |
| Estado bueno | `#EDF5EE` · borde `#CBE0CE` · texto `#2F5C39` |
| Estado de aviso | `#FDF6EA` · borde `#EBD9B8` · texto `#8A5207` |

**Barlow Condensed 700** (uppercase) para títulos y cifras · **IBM Plex Sans** 400/500/600 para
el resto. **Sin monoespaciada, sin sombras, sin degradados** salvo la tarjeta del día.

**Contraste:** validad cada color contra el fondo real. `#8C8474` no vale sobre blanco;
`#6E6656` y `#3F7A4C` no valen sobre `#E6E0D3`; blanco sobre `#3B85C0` tampoco — por eso el
primario es `#2F72AB`.

**Área táctil mínima 44 px** en todo lo pulsable, empezando por lo que borra cosas.

---

## El historial de entrenamientos

Peticion aparte, resuelta en el mismo archivo (turno 3, arriba: **3a, 3b, 3c**).

La frase del entrenador — «que el vea su progresion» — pide **dos cosas en la misma
pantalla**: una lista larga que demuestre constancia, y un resumen que explique de que han ido
estos tres meses. La lista sola no convence a un chaval de catorce anos; el resumen solo no
tiene pruebas.

### La puerta: el grupo ENTRENAMIENTO, ya disenado

**No hay sexta pestana y no hace falta un «Mas».** En `uploads/maquetas-app.md` (linea 552) la
barra lateral de escritorio ya agrupa **«ENTRENAMIENTO: Sesion de hoy · Mi semana ·
Historial»**, y aparte **«MI PERFIL: Mis marcas · Competiciones · Datos personales»**.

En movil, ese primer grupo es **un conmutador de tres pestanas** bajo la cabecera de la
pantalla «Hoy», con las mismas tres palabras y en el mismo orden. Las otras tres entradas ya
estaban resueltas en «MI PERFIL», que en movil es la pestana **Perfil**.

- Las cinco pestanas de abajo **no cambian**: `Hoy · Calendario · Club · Pagos · Perfil`.
- Un «Mas» esconderia justo lo que queremos que el atleta mire.
- Las cuatro pulsaciones para llegar a hace un mes se quedan en una.

**La cabecera de la pantalla es la documentada y no se toca:** fecha en versalitas + «Hola,
[nombre]» + boton circular de avisos con contador. **Persiste en los tres conmutadores**; solo
cambia el contenido de debajo. No anadir un titulo «Entrenamiento»: con la pestana llamandose
«Hoy» y el primer conmutador «Sesion de hoy», el mismo sitio tendria tres nombres.

La tira de semana `L M X J V S D` **no aparece en Historial** — sirve para moverse por la
semana en curso y aqui la navegacion es por meses. Vuelve en «Sesion de hoy» y «Mi semana».

### 3a · La lista del atleta

**El resumen va arriba, no al final.** Es lo que contesta «de que han ido estos tres meses» en
dos segundos, y es lo que el entrenador senala con el dedo.

Bloque de resumen sobre `#F1EADC`:

1. Titulo «Ultimos 3 meses» + **«Cambiar ▾»** (periodo: este mes · 3 meses · temporada).
2. Cifra grande: **41** en Barlow Condensed 700 a 44 px + «dias entrenados».
3. **Una barra por deporte**, con etiqueta a la izquierda (96 px), carril `#E0D7C4` de 10 px de
   alto y numero a la derecha.
4. Separador, y **una sola barra de 14 px partida en dos**: carga `#2E4256` / recuperacion
   `#3F7A4C`. **Debajo, la frase escrita:** «Dos de cada tres dias fueron de carga. El resto,
   recuperacion y activacion.»

**La frase es la que se entiende; la barra solo la respalda.** Nada de grafico de laboratorio.

**Los deportes no llevan color propio.** Van en chip neutro (borde `#C6BEAE`, texto
`#4A4437`) y las barras todas en navy: la longitud y el numero ya distinguen. Cuatro colores
nuevos chocarian con el verde y el ambar, que en toda la aplicacion significan «bien» y «ojo».

Debajo, la lista **agrupada por mes** con encabezado en versalitas y la cuenta de dias
(«Agosto · 9 dias»). Cada fila:

- **Dia en 38 px**: numero en Barlow Condensed 20 px + dia de la semana en 12 px.
- **Chips de deporte** y, debajo, el **papel del dia en texto**: «Carga · pesas y series de
  300». El papel es lo que explica; el deporte solo clasifica.
- **Punto de 11 px**: relleno `#2F72AB` si apunto, hueco con borde `#C6BEAE` si no — y el
  numero del dia en `#6E6656`. Es la marca de constancia.
- `›` al final.

**Un dia es una linea aunque haya dos deportes.** El caso real —pesas y luego series como
transferencia— son dos chips en la misma fila, no dos filas: fue un dia de entrenar, no dos.

Y una linea al pie del resumen, en `#6E6656` y sin reganar: «Seis dias sin apuntar nada.
Apuntarlo es lo que hace que esto sirva.»

### 3b · Al tocar uno · no hay pantalla nueva

**Es la pantalla que ya existe** —la de abrir el entreno de hoy— con dos anadidos:

1. **La fecha en la cabecera** («Lunes 3 de agosto») en vez de «Hoy».
2. **Flechas de anterior y siguiente**, arriba y repetidas al pie («‹ 1 de agosto» / «5 de
   agosto ›»). Eso convierte la consulta en un repaso: se recorre sin volver a la lista.

Contenido, en orden: titulo del entreno · chips de deporte (neutros) y **papel del dia**
(`#EAF2F9`/`#1E4E78`) · un bloque por deporte con sus series · **el feedback guardado** ·
el comentario del entrenador.

**El porcentaje ya cabe:** «4×300 al 85 %» y debajo, en 14px/1.45 `#6E6656`: «Para ti, 85 %
son **44,8 s** — desde tu 38,1 de mayo». **Con la marca de referencia a la vista**, porque si
no el numero parece inventado.

**El feedback en modo lectura**, sobre `#F1EADC`, con el vocabulario de «Como ha ido?»: la
lectura del esfuerzo («8 · Muy duro»), los **chips de sensaciones marcados** (`#2E4256` con
texto blanco) y la nota entre comillas. **No editable:** lo que se apunto aquel dia es un hecho.

**Y el comentario del entrenador al final**, sobre `#EAF2F9` con borde `#C9DDEE`: «Nacho, tu
entrenador» + el texto. Es lo que cierra «hablar con el atleta» sin que tengan que coincidir en
la pista, y lo que hace que un chaval vuelva.

### 3c · El del entrenador no es una pantalla

**Es «Planificar semana» andando hacia atras.** El navegador `← 27 jul – 2 ago →` ya existe;
solo hay que dejarlo retroceder hasta donde haya datos.

Lo unico nuevo, **un pie por dia: «Como les fue»** sobre `#FBF9F4`:

- **Esfuerzo medio** en Barlow Condensed 22 px + «7 de 7» de cuantos apuntaron.
- La queja que se repite: «"Las dos ultimas muy duras" · 3 dicen algo parecido».
- **«2 no apuntaron nada» en `#8A5207`.** Es lo unico de la semana sobre lo que puede actuar.

Ademas:

- **«Semana pasada» escrito en la cabecera**, no solo en las fechas. Quien navega rapido tiene
  que saber sin pensar si lo que ve ya paso.
- **El dia sin entreno se ve igual que en la semana futura**, con «Anadirlo ahora». Rellenar un
  hueco de hace un mes es raro pero legitimo.
- El pie de la tarjeta: «Ver el detalle» + «⋯».

**«Copiar esta semana a…» sustituye al paso 3 y sus dos desplegables.** Ya estas en la semana
que quieres copiar, asi que solo falta decir a cual. El boton principal de la pantalla y una
banda al pie lo repiten.

### Contexto

- **Las familias no ven el contenido del entrenamiento ni el feedback**, por decision del club.
  Estas pantallas son del atleta y del entrenador.
- El historial de datos **ya existe y es completo**: flechas de semana hacia atras
  indefinidamente, con tiempos y sensaciones. **Lo que faltaba era la puerta y la vista de
  conjunto.**
- Las dos etiquetas nuevas son las que el entrenador ya usa: **deporte** (Atletismo · Natacion ·
  Fuerza · El Cubo, hasta dos el mismo dia) y **papel del dia** (Ajuste · Carga · Impacto ·
  Recuperacion · Activacion · Tapering · Competicion · Descanso · Rehabilitador).

---

## Orden de trabajo

1. **Las seis piezas.** Sin esto, lo demás se deshace.
2. **La barra única.** Es navegación: cuanto antes, menos hay que rehacer.
3. **Familia y Calendario.** Las que más usa la gente que no es del club por dentro.
4. **Planificar semana + Planificar un entreno.** Las dos juntas, porque la regla 7 las separa.
5. **Tarifas, Pedidos, Usuarios.** Ya con las piezas hechas, son horas.
6. **Plantillas, Documentos, Mapa, Histórico.** Aplicación directa de las piezas 3, 4 y 5.
