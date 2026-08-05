# Fundamentos del sistema visual — Apolana

Maqueta: `Fundamentos Apolana.dc.html` (bloques 28a a 28g)
Repos: `escuelaapolana/WebV2` + portal + panel

Esto no es una pantalla: son las reglas que arreglan las 40 de golpe. Aplicar
primero esto y después las pantallas concretas.

---

## 0 · Lo que se retira del sistema actual

**Etiquetas en mayúsculas con espaciado ancho.** El patrón
`font-size: 10px; letter-spacing: 0.18em; text-transform: uppercase; color: #A79F8E`
estaba en las 40 pantallas. Era lo que daba el aire de plantilla —más que la
tipografía— y encima no se lee al sol.

Se sustituye por: **13 px, minúscula, sin espaciado, color `#6E6656`.**

Buscar y reemplazar en todo el proyecto. Es el cambio de mayor efecto por
menos esfuerzo.

---

## 1 · Densidad · bloque 28a

El área útil de un portátil de 1366 × 768 son **640 px de alto**. Hoy la foto y
el titular se comen los 640 y el botón de «Prueba 4 días gratis» queda debajo
del pliegue: la página parece un cartel, no una web de club.

**Regla:** en los primeros 640 px entran navegación, titular, una frase, los dos
botones y **el borde superior del bloque siguiente**. Ese último punto es el que
dice «esto sigue» y es el que falta hoy.

| Valor | Antes | Ahora |
|---|---|---|
| Alto del hero (escritorio) | ventana completa | **420 px** |
| Titular del hero | 72 px | **52 px** |
| Aire vertical entre bloques | 80 px y más | **48 px** (32 en móvil) |
| Salto máximo entre dos tamaños | 1 : 2 | **1 : 1,3** |

**El hero mantiene la foto de fondo**, horizontal y a todo el ancho — eso
gustaba y no era el problema. Lo que cambia es el alto, y que el velo va en
degradado diagonal: `linear-gradient(100deg, rgba(28,38,48,0.88), rgba(28,38,48,0.72) 42%, rgba(28,38,48,0.28))`.
Oscuro donde está el texto, casi limpio a la derecha, para que la foto se vea.

---

## 2 · Escala tipográfica · bloque 28b

Ocho tamaños y ni uno más. **El cuerpo baja de 16 a 15 px.**

| px / interlineado | Familia | Uso |
|---|---|---|
| 52 / 0.98 | Barlow Condensed 700, mayúsculas | Titular de portada. Uno por página |
| 36 / 1.0 | Barlow Condensed 700, mayúsculas | Título de página interior |
| 28 / 1.05 | Barlow Condensed 700, mayúsculas | Título de sección · cabecera de pantalla en la app |
| 21 / 1.1 | Barlow Condensed 700, mayúsculas | Título de tarjeta |
| 17 / 1.45 | IBM Plex Sans 400 | Entradilla. Nunca más de dos líneas |
| **15 / 1.5** | IBM Plex Sans 400 | **Cuerpo · el tamaño por defecto.** Texto, filas, botones |
| 14 / 1.45 | IBM Plex Sans 400 | Secundario: subtítulos de fila, notas al pie de tarjeta |
| 13 / 1.4 | IBM Plex Sans 400 | Etiquetas y rótulos. **Minúscula, sin espaciado** |

**Barlow Condensed solo en titulares de página y de sección.** Nunca en el
rótulo de un bloque pequeño: «Hoy en el club» en mayúsculas condensadas competía
con el hero, que está justo encima y usa la misma letra. Va en Plex Sans.

---

## 3 · Monoespaciada: cuándo sí y cuándo no · bloque 28c

La decisión de quitarla de todo fue con brocha demasiado gorda. El criterio:

**SÍ — dato que se compara en columna.** Aquí no parece generada: parece un
cronómetro, y es el idioma del atletismo.
- Marcas y tiempos (`4:02.14`)
- Resultados de test (30 m, CMJ, RSI)
- Horas en tablas y parrillas
- Importes en columna
- Cifras de estadística y contadores
- IBAN y referencias de pago
- Metros y salidas de natación

**NO — todo lo que se lee como frase**, aunque contenga un número.
- Etiquetas y rótulos
- Navegación, botones y chips
- Títulos de sección
- Descripciones y avisos
- Fechas escritas en frase («martes 8 de septiembre»)
- Precios dentro de una frase («la cuota son 120 € al año»)

**Caso mixto:** en listas cortas de horario (dos o tres filas, tipo «Hoy en el
club») la hora va en Plex Sans con `font-variant-numeric: tabular-nums`. Alinea
igual en columna sin el aire de cronómetro. La mono se reserva para tablas de
verdad.

---

## 4 · La barra de navegación · bloque 28d

Nueve entradas no caben en 1100 px, y esconderlas tras el botón de menú hace
que la web parezca una app.

**Siete entradas:**
`Entrena con nosotros · Escuelas · Horarios · Calendario · Liga · Noticias · Club`
\+ botón `Acceso`

### Qué absorbe cada una
- **Entrena con nosotros** — adultos por deporte, deporte adaptado, programas
  municipales, triatlón, y **El Cubo · entrenamiento funcional** (el último de la
  lista, y con el precio en bonos a la vista: los demás son cuota mensual y El
  Cubo va por usos). Desplegable al pasar el ratón; en móvil, una lista.
- **Escuelas** — atletismo, natación, campus. Fuera de «Entrena con nosotros»
  porque el padre que busca escuela no se identifica con «entrenar».
- **Liga** — entrada propia, sin desplegable. Con Calendario y Noticias forma el
  grupo de «qué está pasando en el club». Enterrarla en «Club» la mata.
- **Club** — historia, junta, instalaciones, patrocinadores, familias, tienda,
  contacto y galería. Todo lo que no es «cómo apuntarme».

⚠️ **Aviso de holgura:** «Entrena con nosotros» es la entrada más larga con
diferencia. Las siete pasan de ~560 a ~720 px, así que caben en 1100 px pero sin
margen: el logotipo tiene que ir compacto y el margen lateral bajar a 24 px. Si
algún día hace falta una octava entrada, esa es la primera que habría que
acortar.

---

## 5 · Redes sociales y colaboradores · bloque 28e

Nada de fila de cinco iconos en la cabecera: roba el sitio que necesita la
navegación, que ya va justa.

### En el pie, en todas las páginas
Cuatro filas, icono + cuenta + nombre de la red, 44 px de alto cada una:
- Instagram — `@apolana.alicante`
- TikTok — `@escuela.apolana`
- Facebook — `/atletismo.apolana.alicante`
- WhatsApp — `636 06 17 00`

### WhatsApp, además, arriba a la derecha
Sale dos veces a propósito: aquí no es una red social, es cómo pregunta la
gente. Un padre que duda si su hijo de 6 años puede empezar no escribe un
correo: manda un mensaje.

Va junto al botón de acceso, **solo texto e icono, sin fondo verde** — un botón
verde de WhatsApp en la cabecera se lee como publicidad. En móvil, solo en el
menú y en contacto: flotando encima del contenido molesta.

### Colaboradores en el pie
Con logos, **todos a 26 px de alto y en un solo tono** sobre el azul del pie.
El problema no es que haya logotipos: es que cada uno llega con su color, su
fondo y su proporción. En monocromo y a la misma altura se leen como un
conjunto y no como cuatro pegatinas. Debajo, los nombres en texto para quien no
reconozca el logo.

En la portada siguen a color y grandes. En el pie, pequeños y normalizados.

### Lo que no se hace
Muro de Instagram incrustado en la portada. Para eso está la galería; un muro
embebido carga lento y descuadra la página el día que no hay publicaciones.

---

## 6 · Los cuatro estados de cualquier bloque · bloque 28f

**El vacío es el estado inicial.** El club acaba de empezar: habrá pantallas sin
datos las primeras semanas, y eso es lo normal, no la excepción.

Ejemplo real: los contadores de `/liga/` salen hoy en producción como
**«Edición — · Participantes — · Pruebas puntuadas — · Camiseta Finisher —»**.
Una fila de guiones en la primera pantalla de una página pública transmite
abandono.

### 1 · Cargando
Bloques con la forma del dato que va a llegar, para que la página no salte.
**Nunca «Cargando…» en gris.** Máximo dos segundos; si tarda más, pasa a error.

Esto afecta a dos cargadores colgados hoy en producción: «Hoy en el club» en la
portada y «Cargando tu panel…» en `/socio/`.

### 2 · Vacío
Explica y ofrece algo que hacer. **Nunca guiones ni un cero.**

> **La primera edición arranca en enero**
> Aún no hay pruebas comunicadas. Cuando empiece, aquí verás los participantes y
> la clasificación en directo.
> `[Ver el reglamento]`

«0 participantes» transmite abandono; «arranca en enero» transmite lo contrario.

### 3 · Con datos
Cifras en monoespaciada (se comparan entre ediciones), rótulo debajo en
minúscula. **Con muchos datos:** nunca más de 20 filas de golpe, «Ver más», y
buscador a partir de 30.

### 4 · Error
**Ámbar, no rojo** — el rojo se reserva para lo que el usuario ha hecho mal.
Siempre un botón de reintentar. Si hay datos antiguos en memoria, se muestran
diciendo de cuándo son.

> **No hemos podido cargar la clasificación**
> Puede ser tu conexión. La última actualización fue hace 12 minutos.
> `[Volver a intentarlo]`

---

## 7 · Contraste y zona pulsable · bloque 28g

**El texto no crece.** El problema del sistema es que todo es demasiado grande;
la densidad manda. Lo que sube es el contraste, y la zona pulsable es
independiente del tamaño de letra.

### Grises, con su ratio sobre crema `#FBF9F4`
| Color | Ratio | Uso |
|---|---|---|
| ~~`#A79F8E`~~ | 2,3:1 | **Retirado.** Al sol desaparece |
| `#6E6656` | 5,1:1 | Texto secundario y rótulos |
| `#4A4437` | 8,4:1 | Todo el texto corrido |
| `#2E4256` | 10,9:1 | Títulos y datos |

Ningún texto por debajo de 4,5:1. Los bordes de tarjeta suben de `#EFE9DC` a
`#E4DCCB` cuando separan cosas pulsables.

### Zona pulsable
**44 px de zona, 15 px de letra.** Lo que crece es el relleno, no el texto. A
pie de pista y con una mano ocupada lo que falla no es leer: es acertar con el
dedo. En listas de asistencia, **la fila entera es pulsable**, no solo la casilla.

---

## Paleta completa

```
Crema fondo      #FBF9F4     Crema bloque     #F1EADC
Blanco tarjeta   #FFFFFF     Borde tarjeta    #EFE9DC
Borde marcado    #E4DCCB     Borde chip       #D4CBB9
Navy             #2E4256     Azul medio       #2F6FA8
Azul acción      #3B85C0     Azul hover       #1E4E78
Texto cuerpo     #4A4437     Texto secundario #6E6656
Verde ok         #3F7A4C     Fondo verde      #EDF5EE   Borde #CBE0CE
Ámbar aviso      #B96F09     Fondo ámbar      #FDF3E3   Borde #EBD9B8
Rojo error       #B0563A     (solo error del usuario)
```

---

## Lo que falta del kit

Estos fundamentos no incluyen las piezas. Pendiente de maquetar, y conviene
hacerlo antes de tocar Retos o el panel:

1. **Radio de esquina único** — hoy convive 14, 16 y 18 px
2. **Tarjeta** y sus variantes: normal, con foto, con cifra, pulsable
3. **Fila de lista** — con avatar, con dato a la derecha, con chevron
4. **Tabla que en móvil se vuelve ficha** — está en seis pantallas
5. **Botones y chips** — tres niveles de jerarquía y estado activo
6. **Aviso unificado** — hoy hay dos sistemas distintos, panel y app
7. **Cabecera de pantalla** — app y panel
8. **Iconografía** — un grosor único, 24 px, y el juego mínimo

Y después: **Retos y medallas**, y el panel (**Inicio, Atletas, Cobros**), de
donde sale el patrón para las otras 23 páginas.
