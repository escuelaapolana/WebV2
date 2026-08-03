# Inventario de datos personales del club

**Club Atletismo Apol·Ana · documento de trabajo interno**

---

## Para qué sirve este documento

El club maneja datos de unas doscientas personas, la mayoría **niños y niñas de 3 a 18
años**. Hoy no hay aviso legal, ni política de privacidad, ni registro de actividades de
tratamiento. Todo eso hay que escribirlo, y un abogado no puede escribirlo sin saber
antes **qué datos hay, de quién, dónde están y quién los ve**.

Esto es esa lista. No es la política de privacidad ni pretende serlo: es el trabajo de
campo previo, el que hay que llevarle al abogado para que él ponga las bases legales y
los plazos. Está escrito para que lo entienda alguien que no programa.

**Este documento no contiene ni un solo dato real de ninguna persona.** Describe *tipos*
de datos («el teléfono de la madre»), nunca valores. Los ejemplos son inventados. Está
hecho así a propósito, porque este archivo queda guardado para siempre en un sitio que
cualquiera puede consultar.

**Fecha de la revisión:** agosto de 2026.

---

## Lo primero, porque cambia cómo se lee todo lo demás

Hay **dos sitios distintos** donde el club guarda datos de personas, y ahora mismo el
grueso está en el segundo:

**1 · La aplicación del club** (la web, el portal de familias y el panel de gestión).
Está construida, funciona y tiene el control de accesos revisado. Pero **está casi vacía
de datos reales**: de las 206 fichas de atleta que hay dentro, 204 son fichas de prueba
con nombres inventados que se metieron para poder desarrollar. Ninguna ficha tiene DNI
rellenado. Ninguna tiene datos del tutor rellenados. De las 15 cuentas de acceso, 10 son
también de prueba.

**2 · Google** (formularios, hojas de cálculo, Drive y correo). **Aquí es donde están
hoy los datos reales del club**, incluidos los más delicados: el DNI escaneado por las
dos caras, la foto de la cara, el número de cuenta bancaria, el número de la tarjeta
sanitaria de los niños, el peso y la estatura. Nada de eso está en la aplicación del
club: está en formularios de Google y en carpetas de Google Drive.

Esto tiene dos consecuencias prácticas:

- El inventario que sigue describe **los dos sitios**. Cuando algo está solo en Google,
  se dice expresamente.
- Antes de volcar los datos reales a la aplicación hay una oportunidad que no se
  repetirá: **decidir qué se vuelca y qué no**. Es mucho más barato no meter un dato que
  quitarlo después.

Y una tarea de higiene, sin relación con lo legal pero conviene apuntarla: **las 204
fichas de prueba y las 10 cuentas de prueba habrá que borrarlas antes de arrancar de
verdad**, para que no se mezclen con las de personas reales.

---

## Cómo leer las marcas

A lo largo del documento verás estas marcas:

| Marca | Qué significa |
|---|---|
| **SENSIBLE** | Categoría que la ley trata con especial dureza: salud, datos bancarios, documento de identidad, imagen de la cara, o una valoración personal sobre alguien. |
| **MENOR** | Afecta a niños y niñas. En un club donde la mayoría son menores, esto es casi siempre. |
| **SOLO EN GOOGLE** | Hoy no está en la aplicación del club: está en un formulario o una carpeta de Google. |

---

# Parte 1 · Qué se sabe de cada persona

Organizado por **de quién es el dato**, no por dónde está guardado.

## 1.1 · Un atleta (la mayoría, menores)

### Su ficha básica

Nombre, apellidos, un nombre corto o apodo, **fecha de nacimiento**, sexo, categoría
deportiva, número de licencia federativa, su grupo de entrenamiento, quién es su
entrenador, en qué estado está (activo, a prueba, lesionado, de baja), y desde cuándo
está en el club.

- La fecha de nacimiento está en todas las fichas. **MENOR** — es el dato que permite
  saber que 114 de las fichas actuales son de menores de edad.
- El campo del **DNI del atleta** existe en la ficha y hoy está vacío en todas, pero
  **el formulario de la escuela sí lo pide** y por tanto ese dato existe en Google.
  **SENSIBLE · MENOR · SOLO EN GOOGLE**

### Cómo contactar con él

Correo electrónico y teléfono del propio atleta, y aparte **nombre, correo y teléfono
del padre, madre o tutor**. En las fichas actuales estos campos están vacíos, pero
existen y están preparados para recibir la importación.

- El correo y el teléfono de un niño son datos personales suyos. **MENOR**

### Su salud

Esta es la parte que legalmente más pesa. Todo lo que sigue son **datos de salud** y
casi siempre **de menores**:

- **Lesiones y molestias**: zona del cuerpo, tipo de lesión, gravedad, si puede entrenar
  o no, fecha en que empezó, fecha de revisión, fecha de alta, **el tratamiento que
  sigue** y notas libres del entrenador o del fisio. El propio atleta puede avisar desde
  el portal de que algo le duele, y eso también se guarda.
  **SENSIBLE · MENOR**
- **El parte de después de cada entreno**, que rellena el propio atleta: cómo se ha
  sentido, cuánto le ha costado el esfuerzo, si le molesta algo, **cuántas horas ha
  dormido** y **cuánto pesa ese día**. Hay más de mil de estos partes guardados.
  **SENSIBLE · MENOR**
- **La entrevista de entrada**, que se hace al llegar al club: por qué se apunta, qué
  objetivos tiene, su experiencia previa, su disponibilidad, **qué lesiones ha tenido
  antes**, qué otros deportes practica y notas libres.
  **SENSIBLE · MENOR**
- **Si hace gimnasio, si tiene fisioterapeuta y qué día va.**
  **SENSIBLE · MENOR**
- **Pruebas de fuerza**: cuánto peso levanta en cada ejercicio, con la fecha.
  **SENSIBLE · MENOR**
- **Tests físicos**: resultados de cada batería de tests, intentos, mejor marca, y si no
  se presentó.
  **MENOR**
- **Peso y estatura** los pide además el formulario de alta de socio, aparte de lo
  anterior. **SENSIBLE · SOLO EN GOOGLE**
- **El número de la tarjeta sanitaria (SIP)** lo pide el formulario de alta de la
  escuela. Es un identificador sanitario de un niño.
  **SENSIBLE · MENOR · SOLO EN GOOGLE**

### Lo que opinan de él los adultos del club

- **Notas privadas del entrenador sobre el atleta**: texto libre, con fecha y tipo. Son
  las notas que el equipo técnico escribe para sí mismo (comportamiento, actitud,
  evolución). El atleta y su familia **no las ven**.
  **SENSIBLE · MENOR** — una valoración subjetiva sobre un menor es de lo más delicado
  que hay aquí, precisamente porque es una opinión y porque el interesado no sabe que
  existe.
- **Notas para la familia**: texto libre con un interruptor de «visible sí/no». Cuando
  está visible, la familia la lee; cuando no, es otra nota interna.
  **SENSIBLE · MENOR**
- **Observaciones y contexto** dentro de la propia ficha: tres campos de texto libre
  (uno general, uno que escribe el entrenador y uno que escribe el atleta). Al ser texto
  libre, ahí puede acabar cualquier cosa, incluida información de salud o familiar que
  nadie previó.
  **SENSIBLE · MENOR**
- **Comentarios del entrenador sobre un entreno concreto** del atleta.
  **MENOR**
- **El motivo por el que faltó** a un entreno, que apunta quien avisa. En la práctica,
  suele ser un motivo médico o familiar.
  **SENSIBLE · MENOR**

### Su deporte

Pruebas principales y secundarias, especialidades, si es velocista o fondista, con qué
pierna ataca la valla, cuántos pasos da entre vallas, qué días entrena.

Marcas personales (tiempo, prueba, fecha, sede), ritmos parciales, asistencia a cada
entreno (presente o ausente, quién lo apuntó y cuándo), inscripciones a competiciones y
resultados, participaciones en la liga interna con los justificantes que sube, retos
conseguidos, medallas y puntos del juego, y su puesto en las clasificaciones.

- La **asistencia** es un registro día a día de dónde estaba un niño a una hora
  determinada. No es un dato de salud, pero es un rastro de presencia bastante detallado.
  **MENOR**

### Su dinero

Cuota mensual asignada, nota sobre por qué es esa cuota, quién la fijó y cuándo. Recibos
emitidos (concepto, importe, estado, fecha de vencimiento, fecha de pago, método,
número de recibo, si se anuló y por qué). Bonos de El Cubo comprados y gastados. Saldo y
movimientos. Pedidos de ropa con talla. Pagos con tarjeta, si se activa la pasarela.

- Que alguien tenga una cuota reducida o un recibo devuelto dice bastante de su
  situación familiar. Hay 713 recibos guardados.
  **SENSIBLE en la práctica**
- **El número de cuenta bancaria de la familia NO está en la aplicación.** Está en el
  formulario de alta de socio y en la orden SEPA, ambos en Google.
  **SENSIBLE · SOLO EN GOOGLE**

### Su imagen

- **Foto de perfil** que sube él mismo o su familia, en un archivo guardado aparte.
  Está apagada por defecto y **a los menores no se les enseña nunca la foto** a otros
  socios.
  **SENSIBLE · MENOR**
- **Fotos del club** con atletas identificables, subidas por el equipo al archivo de
  fotos. Aquí hay un detalle importante: **el archivo general de fotos de la web es
  público**, es decir, quien tenga la dirección exacta de una foto puede verla sin
  entrar en ningún sitio.
  **SENSIBLE · MENOR**
- **Fotos que los propios socios proponen** para las redes del club, con título y
  descripción, guardadas en un archivo privado hasta que el club decide.
  **SENSIBLE · MENOR**
- **Foto tipo carné y foto del DNI por las dos caras**, que pide el formulario de alta
  de socio y se sube a Google Drive.
  **SENSIBLE · SOLO EN GOOGLE**
- Nombre y resultado en el palmarés y los récords del club, que **sí son públicos** en
  la web. Hay un interruptor para mostrar un nombre distinto o no aparecer.

### Sus mensajes

Mensajes directos entre el atleta o su familia y el entrenador (texto libre, con marca
de leído), respuestas a las confirmaciones de asistencia con su nota, y avisos que ha
recibido y cuáles ha leído.

**MENOR** · texto libre otra vez: puede contener cualquier cosa.

### Su móvil

Si instala la aplicación para recibir avisos, se guarda **la dirección técnica de su
dispositivo** y dos claves de cifrado, más un nombre de dispositivo y la fecha del
último uso. Eso permite mandarle un aviso al móvil concreto.

También se guarda **qué tipo de avisos quiere recibir** (entrenos, competiciones, pagos,
noticias, retos).

---

## 1.2 · Un padre, una madre o un tutor

- Nombre, apellidos, correo y teléfono, tanto en su propia cuenta como copiados dentro
  de la ficha de su hijo.
- Un enlace que dice **de qué niños es responsable**. Eso es, de hecho, un dato de
  relación familiar.
- **Su foto de perfil**, si la sube.
- Lo que escribe: mensajes al entrenador, motivos de ausencia, notas al confirmar
  asistencia, propuestas para las redes.
- **Su autorización parental** para que el hijo participe en el juego de retos, con la
  fecha y quién la dio.
- Los recibos y la cuota de sus hijos, y su relación con los pagos.
- **SOLO EN GOOGLE:** su DNI o NIE, nacionalidad, ciudad, provincia y país de
  nacimiento, **domicilio completo**, código postal, número de cuenta bancaria, foto del
  DNI por las dos caras, foto tipo carné, peso y estatura, y su talla de ropa.
  **SENSIBLE**

### Un apunte sobre el domicilio

El **domicilio completo de la familia** se recoge hoy en el formulario de alta de socio.
No está en la aplicación del club. Antes de meterlo, conviene preguntarse para qué hace
falta, porque una dirección postal de una familia con niños es de los datos que más
cuesta justificar si nadie la usa.

---

## 1.3 · Un socio o socia (adulto que no entrena)

Todo lo del apartado anterior, más:

- Sección o secciones a las que se apunta (ruta, montaña, triatlón, natación).
- **Talla de camiseta, pantalón y calcetín.** **SOLO EN GOOGLE**
- Compromiso de asistir a las asambleas.
- Su perfil visible o no para el resto de socios (apagado por defecto).
- Sus pedidos en la tienda y sus reservas de clases.

---

## 1.4 · Un entrenador, monitor o persona del equipo

- Nombre, apellidos, correo, teléfono, foto de perfil, un nombre público si lo pone.
- **Su papel en el club** (entrenador, coordinador, administración, tesorería,
  contabilidad, junta) y de qué secciones se ocupa. Una misma persona puede tener varios
  papeles y elegir con cuál entra.
- Si su cuenta está activa o no.
- **El rastro de todo lo que hace**: quién apuntó cada asistencia, quién escribió cada
  nota, quién fijó cada cuota, quién emitió cada recibo, quién mandó cada aviso, quién
  atendió cada mensaje del buzón, quién importó cada fichero, quién publicó cada
  documento. Con fecha y hora.
  Esto es un **registro de actividad laboral o voluntaria** de personas identificadas.
  No es malo tenerlo —de hecho hace falta— pero hay que decir que existe, para qué es y
  cuánto dura.
- Si es contacto público de una sección: su cargo y, **solo si él lo autoriza con un
  interruptor**, su teléfono y su correo aparecen en la web abierta. Están apagados por
  defecto, que es lo correcto.

---

## 1.5 · Alguien de fuera que escribe al club

Cualquiera, sin necesidad de tener cuenta, puede rellenar dos formularios de la web:

- **El formulario de contacto**: nombre, correo **o** teléfono, asunto y un mensaje
  libre. Entra en el buzón del club. Hay 4 mensajes guardados.
- **La solicitud de información para apuntarse**: nombre, correo o teléfono, qué le
  interesa, cómo conoció al club y un comentario libre. Hay 5 guardadas.

Detalles a tener en cuenta:

- Quien escribe suele ser **un padre o una madre preguntando por su hijo**, así que en
  el mensaje libre acaba habiendo edad del niño, a veces su nombre, y a veces su
  situación (una lesión, un problema).
  **SENSIBLE en la práctica · MENOR**
- **En este momento no hay ningún texto de privacidad ni casilla de consentimiento en
  esos dos formularios.** La persona rellena y envía sin que se le diga quién guarda sus
  datos, para qué, ni cómo pedir que se borren.

---

## 1.6 · Cualquiera que simplemente visita la web

Aunque no rellene nada:

- El servidor que aloja la web registra la visita. La web está en **GitHub Pages**, que
  guarda sus propios registros de acceso (incluida la dirección de internet del
  visitante). El club no controla esos registros.
- **Cada página carga las letras (tipografías) desde un servidor de Google.** Eso
  significa que, en cada visita a cualquier página del club, el navegador del visitante
  se conecta a Google y le comunica su dirección de internet. Ocurre sin avisar y sin
  pedir permiso.
- Cada página carga también una librería técnica desde un servidor de distribución de
  terceros, con el mismo efecto.
- **No hay Google Analytics, ni píxel de Facebook, ni ninguna otra herramienta de
  medición o publicidad.** Eso es una buena noticia y conviene decirlo.
- **No hay aviso de cookies**, y con las cargas anteriores probablemente haría falta al
  menos un aviso informativo. Esto lo tiene que decidir el abogado.

---

# Parte 2 · Por dónde entran los datos

| Camino | Quién lo usa | Qué recoge | Dónde acaba |
|---|---|---|---|
| **Formulario de alta de la escuela** (Google) | Familias nuevas | Nombre, apellidos, sexo, **DNI del niño**, **tarjeta sanitaria**, fecha de nacimiento, turno, hermanos, correo | Google Forms + hoja de cálculo |
| **Formulario de renovación** (Google) | Familias que siguen | Lo mismo, más teléfono, sin tarjeta sanitaria | Google Forms + hoja de cálculo |
| **Formulario de alta de socio** (Google) | Socios adultos | **El más sensible de todos**: DNI/NIE, nacionalidad, lugar de nacimiento, domicilio completo, teléfono, correo, tallas, **peso y estatura**, **foto tipo carné**, **foto del DNI por las dos caras**, **número de cuenta bancaria**, consentimientos | Google Forms + **Google Drive** (los archivos) |
| **Orden de domiciliación SEPA** (Google) | Socios adultos | Titular, dirección, tipo de pago, **número de cuenta**, aceptación | Google Forms |
| **Formulario de contacto de la web** | Cualquiera | Nombre, correo o teléfono, mensaje libre | Base del club |
| **Solicitud de información** | Cualquiera | Nombre, correo o teléfono, interés, comentario libre | Base del club |
| **Importación desde fichero** | Administración | Vuelca de golpe fichas completas desde una hoja de cálculo: nombre, apellidos, **DNI**, fecha de nacimiento, correo, teléfono, **datos del tutor** | Base del club |
| **Panel de gestión** | Administración, tesorería | Fichas, recibos, cuotas, contactos, documentos, fotos | Base del club |
| **Panel del entrenador** | Entrenadores | **Notas privadas sobre menores**, notas para la familia, asistencia, lesiones, tests | Base del club |
| **Portal del atleta y de la familia** | Atletas y familias | Parte de después del entreno (**peso, sueño, molestias**), marcas, molestias, mensajes, ausencias, foto de perfil, propuestas para redes, justificantes de liga | Base del club + archivos |
| **Instalación de la app en el móvil** | Quien la instale | Dirección técnica del dispositivo y claves de cifrado | Base del club |
| **Pago con tarjeta** | Quien pague | Nombre y correo del pagador van a la pasarela; **los datos de la tarjeta no pasan por la web del club** | Stripe |
| **Grupo de WhatsApp del club** | Socios | El teléfono móvil, que el formulario de alta advierte que se añadirá al grupo | Meta (WhatsApp) |

---

# Parte 3 · Dónde acaban de verdad los datos

Cada uno de estos es **una empresa distinta que trata datos por cuenta del club**. El
club, hasta donde consta, **no tiene contrato firmado con ninguna**. La ley pide un
contrato escrito con cada una (lo que se llama «contrato de encargado del tratamiento»).

| Proveedor | Qué tiene | Dónde | Contrato |
|---|---|---|---|
| **Supabase** | La base entera del club, los archivos (fotos, documentos, justificantes) y las cuentas de acceso con sus contraseñas. También manda los correos de «recuperar contraseña». | Centro de datos en la **Unión Europea (Alemania)**. Conviene confirmarlo en el panel y dejarlo por escrito. | No consta |
| **Google — Forms y Sheets** | **Las inscripciones reales del club**, con DNI, tarjeta sanitaria de menores y número de cuenta. | No consta | No consta |
| **Google — Drive** | **Las fotos del DNI por las dos caras y las fotos tipo carné.** | No consta | No consta |
| **Google — Gmail** | El correo del club, por donde pasan las respuestas a familias. | No consta | No consta |
| **Google — tipografías** | La dirección de internet de **cada visitante de cada página**. | No consta | No consta |
| **Servicio de avisos al móvil** | Para que suene un aviso en un móvil, hay que pasar por **Google** (Android y Chrome), **Apple** (iPhone) o **Mozilla** (Firefox), según el móvil. El texto del aviso va cifrado, pero el intermediario sabe que a ese dispositivo le llegó un aviso del club. | No consta | No consta |
| **Stripe** | Si se activa el cobro con tarjeta: nombre, correo y datos de la tarjeta del pagador. | No consta | No consta |
| **GitHub Pages** | Aloja la web. Registros de visita con dirección de internet. | No consta | No consta |
| **Red de distribución de librerías** | Dirección de internet de cada visitante. | No consta | No consta |
| **Meta (WhatsApp)** | Los teléfonos del grupo del club. | No consta | No consta |

Además, el documento de autorización que firman las familias ya dice que los datos se
comunican a **las federaciones** (autonómica y nacional de atletismo, montaña y
triatlón), a **los organizadores de las competiciones**, a **la aseguradora** y a **las
administraciones públicas**. Eso no son proveedores: son cesiones a terceros, y también
tienen que aparecer en la política de privacidad.

---

# Parte 4 · Quién puede ver cada cosa

El control de accesos está construido y revisado, y funciona: cada persona ve lo que le
toca y no más. Esta tabla lo resume en lenguaje llano. **Sirve, tal cual, como borrador
del apartado «quién accede a sus datos» de la política de privacidad.**

Una persona puede tener varios papeles a la vez y elegir con cuál entra; lo que ve
depende del papel que tenga puesto en ese momento.

| | Atleta (o su familia) | Entrenador | Coordinador de sección | Administración | Tesorería y contabilidad | Junta | Público sin cuenta |
|---|---|---|---|---|---|---|---|
| **Ficha del atleta** | La suya y la de sus hijos | Solo la de los atletas de sus grupos | Solo los de su sección | Todas | Todas | — | No |
| **Salud: lesiones y molestias** | Las suyas | Solo las de sus atletas | — | Todas | No | — | No |
| **Parte de después del entreno** (peso, sueño) | El suyo | Solo el de sus atletas | — | Todos | No | — | No |
| **Entrevista de entrada** | La suya | Solo la de sus atletas | — | Todas | No | — | No |
| **Notas privadas del entrenador** | **No, nunca** | Solo las de los atletas que entrena | — | Todas | No | — | No |
| **Notas para la familia** | Solo si el entrenador las marca visibles | Las de sus atletas | — | Todas | No | — | No |
| **Recibos y cuotas** | Los suyos y los de sus hijos | No | No | Todos | Todos | — | No |
| **Datos de contacto de otras familias** | No | Los de sus atletas | Los de su sección | Todos | Todos | — | No |
| **Mensajes directos** | Solo los suyos | Solo los suyos | — | — | — | — | No |
| **Buzón de contacto de la web** | No | Solo lo que le derivan | — | Todo | — | — | No |
| **Perfil y foto de otros socios** | Solo de quien lo haya encendido, **y nunca de menores** | Igual | Igual | Todos | — | — | No |
| **Clasificaciones y récords** | Sí | Sí | Sí | Sí | Sí | Sí | **Sí, con nombre**, salvo que la persona lo apague |
| **Documentos del club** | Los públicos y los de socios | Igual | Igual | Todos | — | — | Solo los marcados públicos |
| **Archivo general de fotos** | — | — | — | Gestiona | — | — | **Sí, quien tenga la dirección de la foto** |
| **Horarios, tarifas, noticias, calendario** | Sí | Sí | Sí | Sí | Sí | Sí | Sí |

Vale la pena destacar tres cosas que están **bien** y que conviene contar al abogado
porque juegan a favor del club:

1. **Los teléfonos y correos de los contactos del club solo salen en la web si esa
   persona lo enciende expresamente.** Están apagados de fábrica.
2. **A los menores no se les enseña nunca la foto ni el perfil** al resto de socios,
   aunque quisieran.
3. **La tesorería ve el dinero pero no ve la salud.** Están separados de verdad, no solo
   en la pantalla.

---

# Parte 5 · Cuánto tiempo se guardan los datos

**Aquí es donde peor está el club, y con diferencia.**

## No existe ningún borrado automático. Ninguno.

Se ha revisado toda la aplicación buscando cualquier cosa que borre datos con el paso
del tiempo: tareas programadas, limpiezas periódicas, caducidades, anonimizaciones.
**No hay nada.** Ni una sola línea.

Lo que sí existe es lo siguiente, y conviene no confundirlo con borrar:

- **Dar de baja a un atleta no borra nada.** Cambia una etiqueta de «activo» a «baja» y
  deja de aparecer en las listas. Su ficha completa —fecha de nacimiento, teléfonos,
  datos del tutor, historial de lesiones, notas del entrenador, asistencia, recibos—
  **se queda entera y para siempre**. Hoy hay 4 fichas en ese estado.
- **Hay caducidades que no borran.** Un aviso caducado, un bono caducado o una tarifa
  vencida dejan de mostrarse, pero la fila sigue guardada indefinidamente.
- **El buzón de contacto no tiene botón de borrar en absoluto.** Solo se puede marcar
  como «atendido». Los mensajes que manda gente de fuera, con lo que hayan escrito
  dentro, no se pueden eliminar desde el panel.
- Lo único que se borra solo son entrenamientos futuros que nadie ha usado, y las
  direcciones de móviles que ya no responden. Nada de eso es dato personal relevante.

## Y cuando sí se borra a mano, se borra mal

Existe un botón para borrar una ficha de atleta. Al pulsarlo:

- Sí desaparecen: las notas del entrenador, las notas para la familia, la entrevista de
  entrada, las inscripciones a competiciones, los bonos, los tests, los retos y las
  cuotas.
- **No desaparece su cuenta de acceso** (el propio botón lo advierte).
- **No desaparecen sus archivos**: la foto de perfil, las fotos que subió y los
  justificantes que aportó **se quedan en el almacén de archivos para siempre**. Borrar
  una ficha en la base no borra los archivos; son dos sitios distintos y nadie los une.
- Algunos datos **se quedan huérfanos en vez de borrarse**: los mensajes que escribió,
  las propuestas que hizo para las redes, sus participaciones en la liga y sus pagos con
  tarjeta pierden el enlace con la persona pero **el texto y el contenido siguen ahí**.
  Y en un texto libre suele estar el nombre.

## El único plazo escrito está en un PDF y no se cumple

El documento de autorización de imagen y datos que firman las familias dice que los
datos se conservan «mientras dure la relación con el club y, después, durante los plazos
legales de prescripción», y promete que se puede pedir la supresión escribiendo un
correo.

**Nada de eso está implementado.** No hay ningún mecanismo para atender una petición de
borrado, ni ninguna forma de saber qué se borraría. Si mañana una familia pide por
escrito que se borren los datos de su hijo, hoy el club no sabría contestar con
seguridad qué hay ni dónde.

**Traducción práctica:** los datos de un niño que se apuntó a la escuela con 5 años y se
fue con 9 —su fecha de nacimiento, sus lesiones, su peso, lo que su entrenador opinaba
de él— siguen guardados hoy, y lo seguirán estando dentro de veinte años, salvo que
alguien entre y los borre uno a uno. **Esto es de los primeros incumplimientos que se
señalan en cualquier inspección**, y en un club de menores pesa el doble.

---

# Parte 6 · Lo que falta o preocupa

Ordenado de más grave a menos. Las tres primeras son las que hay que llevar al abogado
el primer día.

## Muy grave

**1 · No hay plazos de conservación y no se borra nada, nunca.**
Explicado arriba. Afecta a datos de salud de menores. Hace falta decidir, con el
abogado, cuánto se guarda cada cosa (probablemente: la ficha y los datos deportivos unos
años tras la baja; los recibos, lo que exija Hacienda; las notas del entrenador,
bastante menos) y después **construir el borrado**, porque hoy no existe.

**2 · No hay política de privacidad, ni aviso legal, ni registro de tratamientos.**
Los tres son obligatorios. Además, los dos formularios abiertos de la web recogen datos
de gente que no ha sido informada de nada. Y el registro de actividades de tratamiento
es obligatorio precisamente porque el club trata datos de salud y datos de menores a
escala.

**3 · Diez proveedores tratan datos del club y no hay contrato con ninguno.**
Especialmente grave con **Google**, porque es quien tiene hoy los datos más sensibles:
el DNI escaneado, la tarjeta sanitaria de los niños y el número de cuenta bancaria de
las familias.

**4 · Los datos más sensibles están en formularios de Google y en Drive, sin control.**
DNI escaneado por las dos caras, foto de la cara, número de cuenta, tarjeta sanitaria de
menores, peso y estatura. Ahí no hay papeles, no hay caducidad, no hay control de quién
lo abre más allá de con quién esté compartida la carpeta, y no hay forma de saber quién
ha mirado qué. **Es el punto más débil de todo el club.**

**5 · No consta la autorización parental como requisito para tener cuenta.**
Un menor puede tener cuenta en el portal y escribir en él (marcas, molestias, mensajes).
La única autorización parental que se guarda es la del juego de retos. Con menores de
14 años, la ley española exige el consentimiento de los padres para casi todo. Hay que
preguntarle al abogado desde qué edad y para qué.

## Grave

**6 · El archivo general de fotos es público.**
Cualquier foto subida ahí —incluidas fotos de grupo con niños identificables— se puede
ver con solo tener la dirección, sin entrar en ningún sitio y sin que caduque el enlace.
Los archivos privados (fotos de perfil, documentos de socios, justificantes) sí están
bien protegidos; **el problema es solo este archivo concreto**, y probablemente es donde
más fotos de menores hay.

**7 · Se piden datos que quizá no hagan falta.**
Merece una conversación honesta antes de volcar nada a la aplicación:
- **Peso y estatura en el alta de socio.** Se piden junto a las tallas de ropa, así que
  probablemente es para eso; pero para eso ya está la talla. Es un dato de salud pedido
  para elegir una camiseta.
- **La tarjeta sanitaria de los niños.** Si es para una urgencia en un entreno, es
  defendible; pero entonces debería guardarse aparte, con acceso muy restringido, y no
  en una hoja de cálculo compartida.
- **La foto del DNI por las dos caras.** Suele bastar con ver el DNI y anotar el número;
  guardar la imagen escaneada es lo que convierte una filtración en un problema serio.
- **Nacionalidad, ciudad, provincia y país de nacimiento.** Si no lo exige la
  federación, sobra. La nacionalidad es además un dato que conviene no tener sin motivo.
- **El domicilio completo**, si no se manda nada por correo postal.

**8 · Los textos libres son un agujero difícil de tapar.**
Hay muchísimos campos de «observaciones», «notas», «comentario» y «motivo». En un campo
libre acaba entrando de todo: diagnósticos, situaciones familiares, opiniones. No se
puede evitar del todo, pero sí conviene (a) que el equipo técnico sepa que esas notas
son datos personales sujetos a la ley, y (b) que se borren antes que el resto.

**9 · Las notas privadas sobre menores no las conoce nadie de fuera del equipo técnico.**
Están bien protegidas técnicamente, pero un padre tiene derecho a saber que existen y a
pedir ver lo que se ha escrito sobre su hijo. Hoy no se le dice en ninguna parte. Hay
que preguntarle al abogado cómo se informa de esto sin que el entrenador deje de poder
tomar notas útiles.

## Importante

**10 · Los mismos datos están en dos sitios a la vez.**
El nombre, correo y teléfono del tutor están **dentro de la ficha del hijo** y también
en **su propia cuenta**. Lo mismo con el correo del atleta. Cuando alguien cambia de
teléfono, se actualiza en uno y queda viejo en el otro; y cuando alguien pide que se
borren sus datos, hay que acordarse de los dos sitios. Conviene decidir cuál manda.

**11 · Las tipografías se cargan desde Google en todas las páginas.**
Cada visitante, sin saberlo ni consentirlo, le comunica su dirección de internet a
Google al abrir cualquier página del club. Tiene arreglo fácil (guardar las letras en el
propio servidor) y quita de encima un problema de cookies y de transferencias.

**12 · No hay ningún procedimiento para atender derechos.**
Si alguien pide acceder a sus datos, corregirlos o borrarlos, hoy no hay ni un correo
designado, ni un plazo, ni una lista de dónde mirar. Este inventario es el primer paso;
falta el procedimiento.

**13 · No consta ningún registro de quién ha consultado qué.**
Se guarda muy bien quién *escribe* cada cosa, pero no quién *lee*. Con datos de salud de
menores, poder demostrar quién ha mirado una ficha es útil si algún día hay una queja.

**14 · No consta ninguna evaluación de impacto ni delegado de protección de datos.**
Tratar datos de salud de menores a escala suele obligar a hacer una evaluación de
impacto. Que haga falta o no es cosa del abogado, pero conviene preguntarlo
expresamente.

## Menor, pero hay que hacerlo

**15 · Hay 204 fichas de prueba y 10 cuentas de prueba dentro de la base real.**
No son personas reales y no hay problema legal, pero hay que limpiarlas antes de meter
los datos de verdad para que nadie las confunda.

**16 · La orden SEPA y el alta de socio están en formularios distintos.**
El número de cuenta se pide dos veces, en dos sitios. Un sitio menos donde tenerlo es un
riesgo menos.

**17 · No hay aviso de cookies.**
Probablemente haga falta al menos uno informativo por las cargas de Google. Lo decide el
abogado.

---

## Qué llevarle al abogado

Este documento, más:

- Los tres PDF que ya existen: normas del club, autorización de imagen y datos, y
  premios.
- Copia de los cuatro formularios de Google, tal como los ve una familia.
- La tabla de la Parte 4, que es media política de privacidad ya escrita.

Y estas tres preguntas por delante:

1. **¿Cuánto tiempo se guarda cada cosa?** Sin esa respuesta no se puede construir el
   borrado, que es el trabajo más largo que queda.
2. **¿Desde qué edad hace falta autorización de los padres**, y para qué exactamente?
3. **¿Qué datos de los que se piden hoy hay que dejar de pedir?** Lo que no se recoge no
   hay que protegerlo, ni borrarlo, ni explicarlo.
