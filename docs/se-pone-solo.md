# Se pone solo

Qué hace el club sin que nadie lo toque, qué espera un clic, y cómo se para
todo si algo va mal.

Todo esto está en el panel, en **Inicio → Se pone solo → Ver cómo se publica**
(o directamente en `/admin/automatizaciones/`).

---

## En una frase

Los **entrenamientos** se publican solos porque no hay nada que decidir: el
horario ya está escrito en la ficha del grupo. Las **carreras de la Liga** se
proponen y esperan un clic, porque una prueba que comunica un socio puede estar
mal escrita o ser de otro club.

Y hay una línea que no se cruza nunca: **noticias, fotos y cualquier cosa con
el nombre de un menor no se publican solas jamás.** Lo automático llega hasta
donde no hay que decidir nada, y ni un paso más.

---

## 1 · Los entrenamientos se publican solos

### De dónde salen

Del horario que ya escribes en la ficha de cada grupo, tal cual:

> Martes y jueves 20:00-21:15 · Salida desde el Parque Municipal

El sistema lee ese texto igual que lo lee la página pública de horarios, y de
ahí saca los días, la hora y el sitio. **No hay que escribir el horario dos
veces**: se escribe donde siempre.

Ahora mismo son **27 grupos y 64 sesiones cada semana**. El Cubo no entra aquí:
sus clases van una a una, desde su propia pantalla.

### Cuándo salen

Se publican **por adelantado**, seis semanas por delante (se puede poner cuatro,
ocho o doce). Así, quien entra en el calendario del club ve el mes y medio que
viene, no solo esta semana.

### Qué hay que hacer

Entrar en **Ver cómo se publica** y darle a **Publicar ahora**. Antes de escribir
nada te dice cuántas sesiones va a poner, cuántas va a poner al día y cuántas va
a quitar; tú confirmas. A partir de ahí solo hay que volver a entrar de vez en
cuando (una vez al mes sobra) y darle otra vez, para que la ventana de seis
semanas siga llena.

### Si cambias el horario de un grupo

No hay que hacer nada más. En cuanto guardas el horario nuevo en la ficha del
grupo, las franjas se rehacen solas. La próxima vez que publiques, las sesiones
futuras se ponen al día. **Las que ya pasaron no se tocan nunca**: son el
histórico del club.

---

## 2 · Un festivo o un cierre se marcan una vez

En **Festivos y cierres de instalación**:

- **Un festivo** (Navidad, un puente): pones el día y el motivo, y dejas
  «Instalación afectada» en *Todas*. Ese día se cae para todo el club.
- **Un cierre** (limpian la piscina del 1 al 5): pones el día de inicio, el de
  fin y eliges la instalación. Se caen solo los grupos que ese día usan esa
  instalación; los demás siguen igual.

Se marca **una sola vez** y afecta a todos a la vez. No hay que ir grupo por
grupo.

Después de marcarlo, dale a **Publicar ahora** para que las sesiones de ese día
desaparezcan del calendario.

Si te equivocas, se quita con el botón **Quitar** y ese día vuelve a ser normal.

---

## 3 · Qué pasa si un entrenador cambia una sesión

**Se respeta lo que él puso, siempre.** Esto es lo importante de todo el
sistema: la automatización nunca pisa el trabajo de una persona.

- Si un entrenador **cambia** una sesión publicada (la hora, el sitio, el
  título, lo que sea), esa sesión queda marcada como suya y **no se vuelve a
  generar nunca más**. Ni aunque cambies el horario del grupo. En la pantalla
  sale en ámbar, como «cambiada a mano».
- Si un entrenador **borra** una sesión publicada, **no vuelve**. Si quieres que
  vuelva, hay que decirlo a mano.
- Si un entrenador **crea** una sesión suya un día en que el grupo ya tenía
  entreno fijo, el sistema **no toca ese día**: manda la suya.
- Una sesión con **gente apuntada** o con **asistencia pasada** no se borra
  nunca, pase lo que pase.

Dicho al revés: el sistema solo toca las sesiones que ha puesto él mismo y que
nadie ha tocado después.

---

## 4 · Cuando algo no se hace todo el año

Hay horarios que solo valen unos meses. Por ejemplo, *Aguas abiertas* pone
«domingos 09:00 (playa, de mayo a septiembre)»: el texto lo dice, pero el
sistema no entiende de temporadas y publicaría los domingos todo el año.

Para eso está **De dónde salen los horarios**: cada franja de cada grupo tiene un
botón de **Apagar** / **Encender**. Apagas la del domingo en octubre, la
enciendes en mayo, y el texto del horario no hace falta tocarlo. Una franja que
apagas a mano se queda apagada aunque vuelvas a guardar el horario del grupo.

---

## 5 · Las carreras de la Liga

Estas **no se publican solas**, y es a propósito.

Cuando un socio comunica una prueba desde la app, aparece esperando en dos
sitios: en el inicio del panel (bloque «Se pone solo») y en la pantalla de
automatizaciones.

- **Publicar** (una) — la carrera sale en el calendario público del club como
  competición, con su nombre, su día, su sitio y su enlace.
- **Publicar las N de golpe** — publica todas las que tienen fecha. Las que no
  tienen fecha se quedan esperando, porque sin día no hay dónde ponerlas.

Antes de publicar, míralo: el nombre puede venir mal escrito, o puede ser una
carrera de otro club. Ese vistazo es justo la razón de que esto no vaya solo.

Pulsar dos veces no duplica nada.

---

## 6 · Quién ve qué en la bandeja del panel

El inicio del panel arranca con la bandeja de lo que hay que resolver hoy, y
tiene un interruptor de **«Solo lo mío»**.

En **Quién ve qué en la bandeja** repartes las áreas de cada persona del equipo:
Personas, Dinero, La web, Liga y Club. Isabel marca «Dinero» y no le salen
lesiones; Adrián marca «Personas» y no le salen recibos devueltos.

Quien no tenga nada marcado ve todo, como hasta ahora. La elección del
interruptor se recuerda de una vez para otra.

---

## 7 · Cómo se para todo si algo va mal

Arriba del todo de la pantalla de automatizaciones hay una banda con el estado.
El botón dice **Parar**.

Al pararlo:

- **Deja de publicarse nada nuevo.** El botón de publicar no escribe.
- **Lo que ya estaba publicado se queda.** Parar no es deshacer: nadie se queda
  sin ver su entreno de mañana porque hayas parado la máquina.

Para volver a ponerlo en marcha, el mismo botón.

Si lo que quieres es **quitar** lo publicado, no lo hagas con el interruptor: se
quitan las sesiones desde el calendario, o se apagan las franjas del grupo y se
vuelve a publicar. Así se quita solo lo que sobra y no se toca nada de lo que
haya hecho una persona.

---

## Lo que nunca se publica solo

- **Noticias.** Las escribe alguien y las publica alguien.
- **Fotos.** Igual.
- **Cualquier cosa con el nombre de un menor.** Sin excepción.

No es que esté pendiente de hacer: es que no se va a hacer. La automatización
llega hasta donde no hay que decidir nada.
