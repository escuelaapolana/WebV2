# Carácter y panel de inicio — Apolana

Maquetas: `Caracter Apolana.dc.html` (31a-31d) · `Panel Apolana.dc.html` (32a-32b)
Antes: `FUNDAMENTOS.md` y `KIT.md`

---

# PARTE 1 · Carácter

Tres cambios. Ninguno rehace nada: son un acento, una decisión sobre fotografía
y usar el vocabulario que el club ya tiene.

## 1 · El ámbar asciende a color de marca · bloque 31a

Hoy el azul lo hace todo: botones, datos, enlaces, iconos activos, gráficas.
Cuando un color sirve para todo deja de significar nada, y el resultado es
correcto pero anónimo — podría ser un colegio o una gestoría.

### Reparto nuevo

| Color | Trabajo |
|---|---|
| **Azul** `#3B85C0` | **Solo lo que se pulsa.** Un botón por pantalla, enlaces, activo de la barra. Se le quitan los datos y las gráficas |
| **Ámbar** `#B96F09` | **El club como institución:** rangos, medallas, Liga, récords, nombres propios de grupo, la temporada. Lo que da orgullo, no lo que se pulsa |
| **Navy** `#2E4256` | Títulos, datos, pantallas de trabajo. La voz normal |
| **Verde** `#3F7A4C` | Solo «está hecho» y mejoras de marca. Nunca decorativo |

Tonos de apoyo del ámbar: texto sobre crema `#8A5307`, fondo suave `#F6EBD6`,
contador sobre navy `#E0A33C`.

### El riesgo, y cómo se resuelve
El ámbar es hoy el color de «cuidado» (recibo pendiente, error, cierre de
inscripción). Se distingue **por forma, no por color**: el aviso siempre lleva
icono y fondo `#FDF3E3`; la marca va en texto o en trazo, **nunca en bloque de
fondo**.

Si al aplicarlo se confunde en alguna pantalla, la alternativa es un ladrillo
más oscuro `#A8482B`, que no se parece a un aviso.

## 2 · La foto tiene que jugar · bloque 31b

Un club de atletismo tiene el mejor material posible: gente sufriendo y gente
celebrando. Ahora la foto es relleno —cuadraditos de 200 px que se repiten— y
el diseño se sostiene sobre tarjetas y texto. Eso es lo que hace que parezca una
web de servicios.

- **Una foto grande por página**, ancho completo y 420 px de alto. En escuela,
  en cada grupo, en el club. Una buena vale más que seis pequeñas
- **Cara, sudor y dorsal.** Se descartan las fotos de grupo posando y las de
  instalaciones vacías. Si no se reconoce a alguien del club, no entra
- **Ninguna foto se repite.** Hoy `adultos.jpg` sale en tres sitios, uno de
  ellos haciéndose pasar por Instagram. Mejor cuatro huecos que ocho repetidos

### Galería
Agrupada **por acontecimiento**, no rejilla plana: un bloque por carrera con su
fecha, su recuento y una foto principal grande + tres pequeñas + «+30». Con 200
fotos, una rejilla plana es un vertedero; agrupada, es la memoria del club. Al
tocar, pantalla completa con flechas y descarga.

### Estado vacío honesto
> **Aún no hay fotos de esta temporada**
> Si has hecho alguna en una carrera del club, mándanosla por WhatsApp.

Mejor que la misma imagen puesta tres veces. Y además funciona: la gente manda.

## 3 · Usar el vocabulario que ya existe · bloque 31c

La Tribu. Madre Tierra. El Cubo. Familia Apolana. Son nombres con alma y en la
interfaz son etiquetas de tabla, indistinguibles de «Natación adultos».

**Antes:** una fila que dice `Running · M·J·S · 40-60 €`. No dice a quién le
toca cuál, y esconde que son dos grupos con dos caracteres distintos.

**Después:** dos tarjetas, cada una con su nombre en ámbar, su precio y una
frase propia.

- **Los nombres propios del club van en ámbar**; los genéricos, en navy. La
  diferencia de color enseña qué tiene identidad y qué es una categoría
- **Una frase por grupo, escrita por su entrenador.** No una descripción de
  folleto: «Para empezar a correr sin morir en el intento» dice más que tres
  líneas neutras, y es lo que hace elegir
- ⚠️ **No inventarlas.** Hay que pedírselas a Rubén, Nora y compañía. Es trabajo
  de copy pendiente y no lo puede hacer un diseñador

## Lo que no se toca

Crema y azul es valiente para un club de atletismo — lo fácil era negro y verde
flúor. Barlow Condensed en mayúsculas tiene aire de dorsal. El admin como única
fuente de datos está bien pensado. La app para el día a día y la web para lo que
se hace sentado es el reparto correcto. Y el modelo de calles de natación es lo
mejor del proyecto.

---

# PARTE 2 · Inicio del panel

Maqueta: `Panel Apolana.dc.html` · bloque 32a

El panel no arranca con contadores: arranca con **la bandeja de lo que hay que
resolver hoy**.

## Estructura

**Columna izquierda (55 %)**
1. **Necesita tu atención** — la bandeja, con recuento y filtro «Solo lo mío»
2. **El club hoy** — cuatro contadores, debajo y pulsables

**Columna derecha (45 %)**
3. **Se pone solo** — las dos automatizaciones, visibles y funcionando

## La bandeja

Un contenedor con separadores (patrón de fila del kit), 48 px por fila, cada una
con icono en cuadrado de 34 px y **su acción a la derecha**.

Tipos de aviso, en este orden:

| Aviso | Acción en la fila |
|---|---|
| Un socio propone una publicación | `Ver` + `Publicar` |
| N pruebas de Liga por validar | `Validar` |
| Periodos de prueba que acaban | `Ver los N` |
| Recibo devuelto | `Escribirle` |
| Lesión comunicada | `Ver` |
| Resto | «Y 7 avisos más, ninguno urgente» + `Ver todos` |

### Reglas
- **Cada aviso trae su acción.** Nunca un aviso que solo lleva a otra pantalla
  donde volver a buscar: las cinco cosas más repetidas se resuelven desde la
  propia fila
- **«Solo lo mío»** filtra por papel y recuerda la elección. Isabel no tiene que
  ver lesiones; Adrián no tiene que ver recibos devueltos
- **Los contadores del menú lateral van en ámbar** `#E0A33C` sobre navy. En azul
  se confundirían con lo pulsable; en rojo parecería que algo va mal, y no va
  mal: hay trabajo

## Las dos automatizaciones

### Entrenamientos fijos — se publican solos
Los 27 grupos con horario fijo publican en el calendario cada semana sin que
nadie los toque (≈ 64 sesiones). Se cambian solo cuando cambias el horario del
grupo. Un festivo o un cierre de pista se marcan una vez y afectan a todos.

### Carreras de la Liga — se proponen
Cuando un socio comunica una prueba, la carrera **se propone** para el
calendario público. Un clic por carrera, o «Publicar las 7 de golpe».

### La distinción, y por qué
- **Los entrenos van solos** porque no hay nada que decidir
- **Las carreras se proponen** porque una prueba comunicada puede estar mal
  escrita o ser de otro club
- **Nunca se publica solo:** noticias, fotos y cualquier cosa con nombre de un
  menor. La automatización llega hasta donde no hay que decidir nada

### Por qué «Se pone solo» es una columna y no un ajuste
Que 27 grupos publiquen 64 sesiones sin tocarlas es el mayor ahorro del sistema,
y hay que **verlo funcionando** para confiar en él. En un menú de configuración,
nadie sabe que existe.

---

## Pendiente

- **Retos y medallas** — a medias en `Retos Apolana.dc.html`. En espera de
  hablar con el responsable de la Liga por si se integran los puntos
- **Panel: Atletas y Cobros** — de ahí sale el patrón para las otras 23 páginas
- **Galería**, **En la pista** (`/admin/campo/`), **Instalar la app**,
  **Escuelas**, **Estadísticas**
- **Frases de grupo** escritas por los entrenadores
- ⚠️ **Sigue sin aplicarse en producción:** los dos cargadores colgados («Hoy en
  el club» y «Cargando tu panel…») y los cuatro guiones de `/liga/`. Es lo
  primero que ve un socio y va antes que cualquier cosa de este documento
