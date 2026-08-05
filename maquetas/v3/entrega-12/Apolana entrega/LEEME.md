# Apolana · paquete de diseño

Diez carpetas. Cada una lleva su `README.md` con las decisiones y las medidas, y un archivo
`.html` que se abre en el navegador como referencia visual.

**Los README manda sobre las maquetas.** Los HTML son para ver; los valores exactos, los
motivos y lo que está pendiente están escritos en el README de cada carpeta.

---

## Por dónde empezar

Este es el orden recomendado, y no es arbitrario: cada paso desbloquea al siguiente.

| # | Qué | Por qué va aquí |
|---|---|---|
| 1 | **5 · Formularios de alta** | Sin inscripción no hay niños en la base, y sin niños no hay nada que repartir. Es además la más larga y la que contiene todos los problemas de las demás. |
| 2 | **8 · Repartir grupos** | Depende de que la inscripción exista. En septiembre es lo que más urge. |
| 3 | **10 · Página del atleta** | La pantalla que más se abre. Es la puerta de la app: hasta que exista, lo demás no se ve. |
| 4 | **7 · Apuntar el entreno** | Se entra desde la página del atleta. La tarjeta de fuerza con el arrastre en gris es el 80 % del valor. |
| 5 | **9 · Planificador** | El entrenador puede seguir planificando con lo que hay ahora; la mejora no bloquea a nadie. |
| 6 | **6 · Las diez del panel** | Son mejoras sobre pantallas que ya funcionan. Van al final, pero **las seis piezas comunes que describe esa carpeta conviene sacarlas antes**, porque las usan todas las demás. |

**Excepción a ese orden:** las **seis piezas comunes** de la carpeta 6 (cabecera de pantalla,
barra de filtros, fila de tabla, ficha de móvil, campo de formulario, bloque plegable) son la
base de todo lo demás. Sacarlas al empezar la carpeta 5 ahorra rehacerlas cinco veces.

---

## Las diez carpetas

| # | Carpeta | Qué contiene |
|---|---|---|
| 0 | `0-logo/` | Los originales del club. El máster para imprenta es el PDF vectorial. |
| 1 | `1-portada-movil/` | La portada de móvil, decidida y documentada. |
| 2 | `2-mapa-del-sitio/` | Qué páginas hay, qué hace cada una, qué se cae. |
| 3 | `3-icono/` | El icono de la app y las notas de exportación por sistema. |
| 4 | `4-avisos-y-pagos/` | La pantalla del aviso y el circuito de compra de bono. |
| 5 | `5-formularios-de-alta/` | Inscripción, renovación, alta de socio y SEPA. Web y app. |
| 6 | `6-panel/` | Siete reglas, diez pantallas, la barra única y las seis piezas comunes. |
| 7 | `7-apuntar-entreno/` | La zona del atleta apuntando: fuerza, pista y natación. |
| 8 | `8-repartir-grupos/` | Repartir la escuela: arrastrando en escritorio, tocando en móvil. |
| 9 | `9-planificador/` | Planificar semana revisado + el calendario del entrenador. |
| 10 | `10-pagina-del-atleta/` | La portada de la app, y los estados vacíos y de error de 7, 8 y 9. |

---

## Lo que atraviesa todo el paquete

**Móvil primero.** El escenario que manda es un padre a pie de pista o un atleta entre
máquinas, con una mano y cinco minutos.

**Nada pulsable por debajo de 44 px.** Es la regla que más se ha incumplido en el panel.

**Tipografía.** Barlow Condensed 700 en mayúsculas para titulares y cifras grandes;
IBM Plex Sans 400/500/600 para todo lo demás. **Sin monoespaciada** en ningún sitio.

**Sin sombras y sin degradados**, con una excepción deliberada: las tarjetas azules del portal,
que son para «lo que toca hoy» y **solo una por pantalla**.

**Menos es más.** Es la decisión de fondo de todo el proyecto, empezando por la portada. Cada
bloque que se añade tiene que quitar otro.

### Colores

| Uso | Hex |
|---|---|
| Texto principal / navy | `#2E4256` |
| Botón primario | `#2F72AB` |
| Enlace | `#2F6FA8` |
| Azul de marca (logo) | `#2E81BE` |
| Azul sobre navy | `#8FC0E8` |
| Fondo de selección | `#EAF2F9` |
| Fondo base | `#FBF9F4` |
| Fondo alterno | `#F1EADC` |
| Borde de campo | `#C6BEAE` |
| Borde de tarjeta | `#E4DCCB` |
| Texto cuerpo | `#4A4437` |
| Texto de ayuda | `#6E6656` |
| Bien / confirmación | `#2F5C39` sobre `#EDF5EE`, borde `#CBE0CE` |
| Ojo / aviso | `#8A5207` sobre `#FDF6EA`, borde `#EBD9B8` |
| Error | `#8F1F19` sobre `#FDECEA`, borde `#F6D7D4` |
| Valor arrastrado sin confirmar | `#A79E8B` |

**El verde significa «bien» y el ámbar «ojo» en toda la app.** No se pueden reutilizar para
otra cosa — por eso los puntos del calendario del entrenador usan **forma y no color**.

**Nota de contraste, ya pisada varias veces:** validad cada color de texto contra el fondo
real. `#8C8474` no vale sobre blanco. `#6E6656` no vale sobre `#E6E0D3`. Blanco sobre `#3B85C0`
tampoco pasa — de ahí que el botón primario sea `#2F72AB`.

---

## Los estados obligatorios

Toda pantalla que carga datos tiene cuatro: **cargando · vacío · error · con datos.** Ya existe
el juego común en el panel y funciona; hay que usarlo en todo lo nuevo.

Dos reglas que vienen de bugs reales:

- **Nunca decir «no hay nada» cuando ha fallado la consulta.** Se dice que ha fallado y se deja
  reintentar.
- **Todo estado vacío lleva su salida:** el botón que lleva a la pantalla donde se crea lo que
  falta.

Los cuatro casos concretos están dibujados en `10-pagina-del-atleta/`.

---

## Lo que sigue pendiente del club

Recogido de todas las carpetas, para que no se pierda:

1. **El texto legal del mandato SEPA** con el identificador de acreedor. Bloquea la carpeta 5.
2. **Los tres PDF de autorizaciones**, para extraer los textos cortos de las casillas.
3. **Los 193 ejercicios con su bloque y su unidad.** Sin eso las sugerencias de la carpeta 7 no
   se pueden agrupar.
4. **Quién revisa las altas**, con nombre. Si nadie las mira, las familias esperan.
5. **Quién aprueba lo que entra en el banco de ejercicios.** Si no, en un año hay «sentadilla»,
   «sentadillas» y «squat» como tres ejercicios distintos.
6. **El catálogo de material de natación.**
7. **El campo «con quién le gustaría estar»** del formulario tiene que llegar a la pantalla de
   repartir.
8. **Cuánto se guarda un formulario a medias.** Propuesta: 30 días.
9. **Comprobar con el banco** si hay que rehacer las órdenes SEPA firmadas con el CIF mal.
10. **Vectorizar** las variantes de logo de Natación y Fitness, que solo existen en PNG.

**El CIF correcto es `G-03845500`.** El formulario SEPA actual pone `G0384500`, que le falta un
dígito y va en un documento con valor legal.
