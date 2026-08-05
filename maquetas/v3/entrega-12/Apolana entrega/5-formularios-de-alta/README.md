# 5 · Los formularios de alta

Para quien implementa. Todo lo de aquí está decidido con el club; lo que sigue abierto está
marcado como **pendiente**.

**Archivo visual:** `Formularios de alta Apolana.html` — abrir en el navegador. Tres turnos,
el más reciente arriba. Es una referencia de diseño, no código de producción: los valores
exactos están en este documento.

---

## Qué hay que construir

Cuatro flujos. Hoy solo existe en la web un «déjanos tus datos y te llamamos» en
`/inscripcion/`; el resto vive en Google Forms, papel o WhatsApp.

| Flujo | Dónde vive | Estado hoy |
|---|---|---|
| Inscripción a la escuela | **Web pública** | Google Forms, 7 pantallas |
| Renovación de la escuela | **Web + app** (portal) | Google Forms, 4 pantallas |
| Alta de socio | **Web pública** | Google Forms, 1 pantalla larguísima |
| Domiciliación SEPA | **Web + app** (portal) | Google Forms, incompleto |

**Regla de plataforma:** quien se apunta no tiene cuenta todavía, así que la inscripción y
el alta de socio son **web pública**. El SEPA y la renovación llegan por aviso a alguien que
ya existe, así que se abren desde la web y desde la app.

**No son dos maquetas.** Es el mismo formulario responsive. Ver «Escritorio» más abajo.

---

## Las seis decisiones tomadas

### 1 · El SEPA se firma en pantalla, con el dedo

No hay vía de «descarga, imprime, firma, escanea». Pierde a media gente y obliga a tener
impresora; con dos caminos el club acaba persiguiendo papeles.

- El **PDF se genera después** con la firma dentro y se manda por correo al titular. Es su
  justificante, y queda descargable desde el portal.
- Hay que **guardar junto a la firma**: fecha y hora, IP, navegador y el **texto exacto del
  mandato que se mostró**. Sin eso la firma es un dibujo.
- Escape: **«Prefiero hacerlo en papel»** abre un WhatsApp con una persona del club. **No un
  PDF suelto** — si es un PDF, vuelven los papeles.

> **Pendiente del club:** que el gestor o el banco confirmen la validez del mandato
> electrónico. El diseño lo soporta; la validez depende de con quién se domicilie.

### 2 · El IBAN se pide en la inscripción, pero es opcional

Corregido con la experiencia del club: a casi nadie le molesta darlo. Pero los «24 ceros»
que algunos escriben son gente sin salida, y un `000000` pasa la validación y se descubre
cuando rebota el recibo.

- Campo **al final del paso 1**, con la etiqueta **«Opcional»** a la derecha del label.
- Debajo: «Si prefieres, déjalo en blanco y te lo pedimos cuando empiece. **No se cobra nada
  hasta que firmes la domiciliación.**»
- **Un hueco vale más que un cero:** un hueco se lista y se reclama.
- El párrafo actual de «no tengáis miedo de poner los datos bancarios» **se retira**. El
  miedo lo quita el campo opcional.
- **La firma del mandato sigue siendo un flujo aparte**, después de los primeros días. El
  IBAN es un dato; el mandato es un documento y necesita su pantalla.

### 3 · Las tres autorizaciones van dentro. Ningún PDF que firmar aparte

| Autorización | Cómo se pide |
|---|---|
| Normas del club + bases de premios | **Una sola casilla obligatoria**, con dos enlaces que abren encima sin sacarte del formulario. Son del mismo tipo y obligatorias las dos. |
| Imagen y datos | **Dos botones, «Sí, podéis» / «No, mejor no».** Elección real. |

**La de imagen no puede ser obligatoria:** si es condición para apuntarse, el consentimiento
no es libre y no vale. Se pide con dos botones y no con una casilla porque una casilla sin
marcar se lee como un descuido; dos botones dicen que negarse es normal. La pregunta lleva
el nombre del niño: «¿Podemos publicar fotos de Lucía?». Y se puede cambiar después desde el
portal.

**Si un niño no tiene autorización de imagen, su entrenador tiene que verlo en su lista.**
Si no, el acuerdo no sirve para nada.

El PDF sigue existiendo, pero **como copia generada** con lo marcado y enviada por correo.
Nadie firma dos veces.

> **Pendiente del club:** pasar los tres PDF actuales para extraer los textos cortos de las
> casillas. Lo que hoy es una página tiene que caber en dos líneas.

### 4 · Hermanos: un formulario, un pagador, varios niños

**Se rellena una vez:** familia, contacto, quién puede recoger, banco, normas y premios.

**Se repite por niño:** nombre, fecha de nacimiento, días/grupo, alergias y **la
autorización de imagen** — puede ser distinta para cada hijo.

- El botón **«Añadir otro hijo» va antes del resumen final**, no después de terminar. Si
  aparece al final, la mitad lo lee como «ya he acabado» y cierra.
- **El descuento se muestra al añadir:** −20 % el segundo hermano, −40 % el tercero. Es el
  momento en que decide.
- En el resumen del SEPA se ven los dos niños con el descuento aplicado y **un solo recibo**.

### 5 · Renovar es confirmar, no rellenar

Hoy una familia que renueva por tercer año vuelve a escribir nombre, apellidos, sexo, DNI y
fecha de nacimiento de su hijo. Eso desaparece.

**Una pantalla, tres respuestas:** los días, la talla de camiseta y si la cuota va en uno o
dos pagos.

- «Como el año pasado» **marcado por defecto** donde se pueda.
- Junto a las tallas, **«el año pasado llevó la 8»**. El club ya lo sabe; que se note.
- Arriba, lo único que sorprende al renovar: **«Este año pasa a la franja de 18:30 a
  20:00»**, cuando el cambio de edad lo provoca.
- Enlace **«Algo ha cambiado»** para corregir teléfono o dirección — es lo único que se mueve.
- **«Este año no sigue» tiene que estar y ser visible.** Si no, la baja llega por WhatsApp en
  octubre o no llega.
- No se vuelve a pedir el IBAN: «Se cobra en la misma cuenta de siempre. No hay que volver a
  firmar nada.»

### 6 · El alta de socio parte en dos

El formulario actual pide DNI escaneado por las dos caras, foto tipo carné, peso, estatura,
nacionalidad y lugar de nacimiento. **Eso no son datos para ser socio: son para federarse.**

- **Ser socio queda en:** nombre y apellidos, DNI, fecha de nacimiento, dirección, contacto y
  sección. Una pantalla corta, por pasos.
- **Federarse es un flujo aparte**, y solo para quien lo necesita: obligatorio en montaña y
  triatlón, opcional en el resto. Ahí van las subidas de archivo, el peso y la estatura.
- Menos datos que custodiar y menos abandono: tres subidas de archivo en el móvil son tres
  oportunidades de cerrar la pestaña.

**Los 125 € de alta:** se cobran **por el mismo recibo domiciliado**, que ya está firmado. Se
elimina la transferencia manual con justificante por correo — ahí se pierde gente y se pierde
el rastro de quién ha pagado.

**Y las dos condiciones que hoy están escondidas en una página van en el resumen antes de
firmar:** la obligación de federarse en montaña y triatlón, y los **cinco décimos de lotería
de Navidad o 15 € de donación**, que se cobran del 1 al 15 de diciembre por el mismo recibo.
Una sorpresa de 15 € en diciembre cuesta más que decirlo en agosto.

### 7 · Socio y grupo se piden juntos

Decisión no pedida, pero resuelve la confusión que señalabais. Que «ser socio» y «apuntarse a
un grupo» sean dos cosas distintas por dentro es asunto del club, no del padre.

Nadie entra pensando «voy a hacerme socio»: entra pensando «quiero correr con La Tribu» o
«quiero apuntar a mi hija». **El formulario se llama por lo que quieres hacer, y la cuota de
socio aparece como una línea del precio, no como un trámite previo.**

En la escuela basta una línea al empezar: **«Apuntar a tu hijo o hija no te hace socio del
club. Son cosas distintas.»**

---

## Los turnos y los grupos · esto era un fallo

**Cómo funciona.** Primera hora, de 3 a unos 11 años, nueve grupos de color: rojo 1-2-3,
azul 1-2-3, verde 1-2-3. **El grupo entero —color y número— lo da el año de nacimiento.** Los nueve grupos cubren nueve años, uno cada uno:

| Grupo | Nacidos | | Grupo | Nacidos | | Grupo | Nacidos |
|---|---|---|---|---|---|---|---|
| Rojo 1 | 2023 | | Azul 1 | 2020 | | Verde 1 | 2017 |
| Rojo 2 | 2022 | | Azul 2 | 2019 | | Verde 2 | 2016 |
| Rojo 3 | 2021 | | Azul 3 | 2018 | | Verde 3 | 2015 |

Rojo 1 son los más pequeños, Verde 3 los mayores. El color agrupa tres años seguidos; el
número dice cuál de los tres. **Ya está en la base, con su campo de año por grupo, editable
desde el panel.**

**Y cada uno de esos nueve nombres existe dos veces.** Hay un Verde 1 de lunes y miércoles y
otro de martes y jueves: misma edad, mismo contenido, **niños distintos**. En total dieciocho
grupos reales con nueve nombres.

**En pantalla no hace falta contarlo.** La familia elige días y ya está en el grupo que le
toca, y el nombre es el mismo en las dos opciones. Pero **por dentro el grupo es nombre +
días**, no solo el nombre: si se identifica solo por el nombre, las listas del entrenador
mezclan a los dos grupos.

Y una línea que sí conviene poner, para la familia con dos hijos de la misma edad:
**«Si apuntas a dos hijos de la misma edad y quieres que coincidan, elige los mismos días
para los dos.»**

**El fallo actual:** el formulario enseña los cuatro turnos a todo el mundo, así que se puede
marcar el que no corresponde. Alguien lo detecta después y hay que llamar a la familia.

**La corrección: la franja la decide el año de nacimiento y no se elige.** Lo único que elige
la familia son los días.

Al introducir la fecha de nacimiento:

1. Aparece la franja **como un hecho, no como una opción**: tarjeta verde `#EDF5EE` con
   «Su franja · **17:30 a 18:30**» y la explicación: «La hora la marca el año de nacimiento
   —2017 entrena en la primera franja— y no se puede cambiar. Lo que eliges tú son los días.»
2. Debajo, la única elección real: **«Lunes y miércoles» / «Martes y jueves»**. Sin subtítulo
   de grupo, porque las dos llevan al mismo.
3. Cierre necesario, y ahora literal: **«Los dos entrenan lo mismo con el mismo entrenador,
   en el grupo Verde 1. Elige por lo que os encaje en casa.»** Sin esa frase el padre se
   pregunta cuál es el bueno.

Los cuatro turnos completos **no se enseñan nunca**.

### El grupo es provisional, y se dice

El grupo puede cambiar antes de empezar según cuánta gente se apunte. Así que **se afirma lo
que la familia eligió y se marca lo que puede cambiar**:

- En grande, lo que no se mueve: **«Lunes y miércoles, 17:30 a 18:30»** + sede + fecha de
  inicio. Es lo que necesita para organizarse.
- Debajo, con su color: **«Grupo previsto: Azul 2»** + chip **«provisional»**
  (`#8A5207` sobre `#FDF6EA`, borde `#EBD9B8`).
- Y la razón: «Puede cambiar según cuánta gente se apunte. Te avisamos en cuanto sea
  definitivo, unos días antes de empezar. **No tienes que consultar nada.**»

**Las listas de grupos desaparecen.** Hoy la familia recibe enlaces con el aviso de que «no
se actualiza automáticamente, revise el enlace el día anterior»: alguien las mantiene a mano
y la familia tiene que acordarse de volver.

Cuando el club cierra los grupos, **dispara un aviso de nivel «importante» (ámbar) desde el
panel**, una vez y para todos, con el grupo definitivo. El chip «provisional» desaparece del
portal. **El cambio va a buscar a la familia, no al contrario.** En el portal, la línea del
grupo es la única verdad.

---

## Escritorio

**Los campos no se estiran.** Una sola columna de **560 px**, la misma que en móvil. Un
formulario a dos columnas de campos se rellena mal: la vista salta y se olvidan cosas.

**El ancho de sobra se usa para poner al lado lo que confirma que vas bien** — lo que en
móvil va debajo:

| Pantalla | Columna derecha |
|---|---|
| Inscripción, paso 1 | La tarjeta verde de franja + grupo previsto, y la tarjeta «No hay nada que pagar ahora» |
| SEPA | «Qué se va a cobrar en esta cuenta» + «Y dos cosas más del club» (lotería, federación) |

**En el SEPA es donde el escritorio gana de verdad:** se firma con el detalle de qué se cobra
a la vista, no tres pantallazos más arriba.

Solo se emparejan de dos en dos los campos **cortos que van juntos** (fecha de nacimiento y
SIP). Los largos, nunca.

**El «1 de 3» pasa a una tira de pasos con nombre** —«El niño y su grupo · La familia ·
Permisos y tallas»— con el activo en `#2F72AB` y los demás perfilados. Es lo único que aporta
el escritorio en navegación.

Cabecera web normal del sitio (crema `#FBF9F4`, alto 68 px, logo + nav + «Acceso»), salvo en
el SEPA.

---

## Anatomía de las pantallas

### Estructura de la inscripción · 3 pasos

| Paso | Contenido |
|---|---|
| **1 · El niño y su grupo** | Nombre y apellidos · fecha de nacimiento · SIP · **días** (con la franja fija arriba) · alergias · **IBAN opcional** |
| **2 · La familia** | Nombre del padre/madre/tutor · DNI · dirección, CP y localidad · móvil (se añade al grupo de WhatsApp: **decirlo en el campo**) · correo · **quién puede recogerlo** · cómo se enteró |
| **3 · Permisos y tallas** | Imagen (dos botones) · normas + premios (una casilla) · talla de camiseta y sudadera con la foto de la equipación · **«¿Apuntas a más hijos?»** con el descuento · forma de pago |

Después del paso 3: **resumen** y envío. El SEPA no está aquí.

### Campos · estilo

- Alto **52 px**, `border: 1px solid #C6BEAE`, `border-radius: 10px`, fondo `#fff`,
  padding lateral 14-15 px, texto **16 px** `#2E4256`.
- Label encima: **15 px peso 500** `#2E4256`, gap 7-8 px.
- Ayuda debajo: **14px/1.45** `#6E6656`. **Nunca `#8C8474` sobre blanco** — no pasa contraste.
- Área de texto: alto 84 px, placeholder `#6E6656`.
- El IBAN con `letter-spacing: 0.04em` y validación al salir del campo, confirmando con el
  **nombre del banco** en verde `#2F5C39` («Banco reconocido: CaixaBank»). Quita mucho miedo.

### Opciones · radios como tarjetas

- Seleccionada: `border: 2px solid #2F72AB`, fondo `#EAF2F9`, círculo de 20 px con
  `border: 6px solid #2F72AB`.
- Sin seleccionar: `border: 1px solid #C6BEAE`, fondo `#fff`, círculo con
  `border: 1.5px solid #C6BEAE`.
- Título 17 px peso 500; subtítulo 14px/1.3 `#6E6656`.
- Tallas: botones de alto 48 px en fila, misma lógica de bordes.

### Casillas

Cuadrado de **26 px**, `border-radius: 6px`. Marcada: fondo `#2F72AB` con el check en blanco.
Texto al lado 16px/1.5 `#4A4437`, gap 13 px.

### Errores

- **Borde rojo de 2 px** (`#B3261E`) y el mensaje **debajo del campo**, 14px/1.45 en `#8F1F19`.
- **Nunca «campo inválido»: se dice qué hacer.** «Al IBAN le faltan 4 dígitos. Son 24 en total.»
- **Nunca solo color:** siempre con texto.
- Se valida **al salir del campo**, no mientras se escribe, y **nunca todo de golpe** al
  pulsar el botón.

### Botones

- Primario: alto **54 px**, píldora, fondo **`#2F72AB`**, texto 17 px peso 500 blanco.
  En escritorio, ancho fijo 220-240 px, no al 100 %.
- Secundario junto al primario: **texto** `#2F6FA8`, no un segundo botón.
- **«Guardar y seguir luego» en todos los pasos.** Guarda en el dispositivo y manda un enlace
  por WhatsApp o correo si ya hay contacto.

> **Pendiente del club:** cuánto se guarda un formulario a medias. **Propuesta: 30 días y se
> borra solo.** Son datos de menores; no conviene tener altas incompletas eternamente.

### La pantalla del SEPA

Es la única con **cabecera navy `#2E4256` a ancho completo**. El tono cambia porque se pide
una cuenta.

De arriba abajo:

1. Antetítulo `#8FC0E8` 12 px con `letter-spacing: 0.09em`: **«Lucía y Pablo se quedan»**.
2. Titular Barlow Condensed 700 en blanco: **«Orden de domiciliación»**.
3. Bajada: «Autorizas al Club Atletismo Apolana (**CIF G-03845500**) a cobrar los recibos en
   tu cuenta. **Puedes anularla cuando quieras** en tu banco o escribiéndonos.» — Lo primero
   que se lee es que se puede anular.
4. Campos: titular («Quien firma tiene que ser el titular de la cuenta») · IBAN · dirección
   del titular.
5. **«Qué se va a cobrar en esta cuenta»** sobre `#F1EADC`: una línea por niño con su grupo y
   el descuento, y «Un solo recibo por los dos. El cobro es periódico, cada temporada.»
   **Esto resuelve titular ≠ atleta sin explicarlo, y va antes de firmar.**
6. Caja de firma: alto 130-150 px, `border: 1.5px dashed #C6BEAE`, radio 12 px, fondo blanco.
   Debajo, a los lados: fecha y lugar («3 de agosto de 2026, Alicante») y **«Borrar y
   repetir»**.
7. «Firmar y terminar» + **«Prefiero hacerlo en papel»**.

> **Pendiente del club:** el **texto legal del mandato SEPA** tal cual lo vaya a usar el
> banco, con el identificador de acreedor. Va literal en la pantalla; no se puede redactar
> por aproximación.

**El SEPA actual está incompleto de forma que importa:** no pide IBAN, ni fecha, ni firma, ni
lugar de firma. Hay que rehacerlo partiendo del **formato oficial de orden SEPA**.

**El CIF correcto es `G-03845500`.** El SEPA actual pone `G0384500` — le falta un dígito, y va
en un documento con valor legal. Corregirlo en el formulario y comprobar con el banco si hay
que rehacer las órdenes ya firmadas que lo lleven mal.

### La pantalla final

**No dice «gracias»: dice qué pasa ahora.** Cabecera navy con «Lucía y Pablo ya están
apuntados» y «Te hemos mandado a marta@correo.es la orden firmada y el resumen».

Después, **«Qué pasa ahora»** numerado en tres líneas concretas:

1. «Su entrenador os escribirá esta semana por WhatsApp para deciros qué traer el primer día.»
2. «Lucía empieza el lunes 8 a las 17:30 en Joaquín Villar.»
3. **«El primer recibo se cobra el 1 de octubre. No hay nada que pagar ahora.»**

Botones: «Entrar en mi portal» y «Descargar el resumen».

**Y el club:** le entra un aviso en el panel con el alta pendiente de revisar, y el entrenador
ve al niño en su lista con la marca de si tiene autorización de imagen.

> **Pendiente del club:** **quién revisa las altas**, con nombre. Si nadie las mira, el aviso
> se acumula y las familias se quedan esperando.

### El correo de confirmación

El club ya manda uno y sirve de base. Tiene que llevar, en este orden:

1. Asunto con el resultado, no con el trámite: **«Lucía ya está apuntada»**.
2. Días, hora y sede en grande. **El grupo, con el chip «provisional».**
3. **El primer día:** fecha, hora y qué traer (ropa y calzado deportivo, botella de agua con
   su nombre para los pequeños). Y **por dónde se entra**, con enlace al mapa.
4. **«Lo que has pedido»:** tallas y forma de pago. Es su comprobante.
5. Cuándo se cobra el primer recibo.
6. Firma del coordinador con su teléfono.

**Sin enlaces a listas.** Para muchas familias este correo es el único papel que les queda
del trámite.

---

## Lo que atraviesa los cuatro flujos

- **Móvil primero.** El escenario que manda: un padre a pie de pista, con el móvil en una
  mano y cinco minutos. Un dato por pantalla cuando el dato es delicado.
- **Área táctil mínima 44 px** en todo lo pulsable.
- **Datos de menores.** Cada campo de más es un dato que hay que custodiar. Si no se usa, no
  se pide.
- **Se dejan a medias.** «Guardar y seguir luego» en todos los pasos.
- **Decir para qué se usa cada dato incómodo** en el propio campo: el móvil «se añadirá al
  grupo informativo de WhatsApp», el SIP para las licencias y urgencias.

## Lo que NO se ha usado, y por qué

**Las tarjetas azules en degradado del portal.** En el portal funcionan porque son
**destinos**: invitan a ir a un sitio. Un formulario no invita, acompaña — y un degradado
detrás de un campo de texto le quita legibilidad y seriedad justo donde más falta hacen.

Lo que **sí** se trae del portal: **el par de botones** (uno sólido, uno perfilado o texto) y
**la línea fina de contexto arriba** («Lucía y Pablo se quedan», «Paso 1 de 3»).

**La escuela municipal no es una opción del formulario.** Uno se apunta en el ayuntamiento, no
aquí. Lo que hace falta es que el club pueda **marcar en el panel** que ese niño viene por esa
vía —dos días, sin viernes— sin que la familia tenga que entenderlo.

---

## Tokens usados

**Color**

| Uso | Hex |
|---|---|
| Texto principal, cabecera navy | `#2E4256` |
| **Botón primario** | **`#2F72AB`** |
| Enlace / texto secundario de acción | `#2F6FA8` |
| Azul sobre navy | `#8FC0E8` |
| Fondo de opción seleccionada | `#EAF2F9` |
| Fondo base | `#FBF9F4` |
| Fondo de bloque alterno | `#F1EADC` |
| Borde de campo | `#C6BEAE` |
| Borde de tarjeta / separador | `#E4DCCB` / `#EFE9DC` |
| Texto cuerpo | `#4A4437` |
| Texto de ayuda y metadatos | `#6E6656` |
| Confirmación (banco, descuento) | `#2F5C39` |
| Fondo de confirmación | `#EDF5EE` / borde `#CBE0CE` |
| Aviso / provisional | `#8A5207` sobre `#FDF6EA` / borde `#EBD9B8` |
| Error | borde `#B3261E` · texto `#8F1F19` |

**Tipografía.** Barlow Condensed 700 (siempre en mayúsculas) para titulares y cifras;
IBM Plex Sans 400/500/600 para todo lo demás. **Sin monoespaciada.**

**Sin sombras, sin degradados, sin bordes redondeados en la cabecera navy.**

**Nota de contraste, ya pisada tres veces en este proyecto:** validad cada color de texto
contra **el fondo real**. `#8C8474` no vale sobre blanco. `#6E6656` y `#3F7A4C` no valen sobre
`#E6E0D3`. Blanco sobre `#3B85C0` tampoco pasa — por eso el botón primario es `#2F72AB`.

---

## Pendiente de decidir o de recibir

1. **Confirmación del gestor o el banco** sobre el mandato SEPA electrónico.
2. **El texto legal del mandato** con el identificador de acreedor.
3. **Los tres PDF de autorizaciones**, para extraer los textos cortos.
4. **Quién revisa las altas**, con nombre.
5. **Cuánto se guarda un formulario a medias** — propuesta: 30 días.
6. **Comprobar con el banco** si hay que rehacer las órdenes firmadas con el CIF mal.

## Orden de trabajo recomendado

**Primero la inscripción a la escuela.** Es la más larga, la más usada, y contiene todos los
problemas de las otras: menores, permisos, hermanos y banco. Cuando esa funcione:

2. **El SEPA**, que reutiliza el bloque de banco y la firma.
3. **La renovación**, que es la inscripción en modo confirmación.
4. **El alta de socio**, que es la inscripción sin niño y sin permisos.
