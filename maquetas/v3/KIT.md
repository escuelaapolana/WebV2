# Kit de piezas — Apolana

Maqueta: `Kit Apolana.dc.html` (bloques 30a a 30i)
Antes: `FUNDAMENTOS.md` + `Fundamentos Apolana.dc.html`

Con estas ocho piezas ninguna pantalla tiene que volver a decidir nada.

---

## Decisiones confirmadas

**Aviso unificado: se queda el de la app** — abajo y en navy. Se retira el
blanco de arriba a la derecha del panel. Razones: en móvil está al alcance del
pulgar, arriba a la derecha compite con la cabecera, y el navy ya es el color
del sistema.

**Nombre corto de la primera entrada: «Entrenar».** Ver el punto 9.

**Las maquetas anteriores no se rehacen.** Navegación, tests, calendario,
natación y pagos usan el patrón viejo de etiquetas: se traducen al aplicar
(13 px, minúscula, sin espaciado). ⚠️ **Pero la monoespaciada de las cifras se
queda** — marcas, tiempos, metros, salidas e importes son datos que se comparan
en columna. Lo que se traduce son los rótulos, no los números.

---

## 1 · Iconografía · bloque 30a

Es la prioridad: los iconos están en las dos barras inferiores, los paneles
«Más», los estados vacíos y el panel entero.

- **Lienzo de 24 × 24**, con 2 px de margen: el dibujo vive en 20 × 20
- **Trazo de 1,9 px**, uno solo, nunca mezclado
- **Puntas y uniones redondas** (`stroke-linecap` / `stroke-linejoin: round`)
- **Sin relleno.** Dos excepciones: los tres puntos de «Más» y el punto de
  aviso, que son círculos macizos
- **El activo no engorda el trazo: cambia de color.** `#2F6FA8` activo,
  `#6E6656` inactivo
- Trazo de 2,4 px solo en el visto de confirmación, porque a 1,9 se pierde
- **Un icono, un significado.** El calendario no puede querer decir «fecha» en
  un sitio y «evento» en otro. Dos ideas = dos iconos

### Juego mínimo (dibujado en la maqueta)
- **Barra del portal:** inicio, entreno, calendario, marcas, más
- **Deportes:** natación, pista, montaña, triatlón, El Cubo, escuela
- **Acciones:** hecho, aviso, copiar, buscar, filtrar, descargar, mensaje, entrar

El chevron de «entrar» es el único que va a la derecha de una fila, y siempre en
`#6E6656` — nunca azul: en azul se lee como un enlace distinto del resto de la
fila.

---

## 2 · Radios: tres y solo tres · bloque 30b

| Radio | Uso |
|---|---|
| **14 px** | Tarjeta o bloque contenedor |
| **10 px** | Lo que vive dentro de una tarjeta: iconos con fondo, avatares cuadrados, campos, sub-bloques |
| **999 px** | Botones, chips, filtros, contadores |

Se retiran los 16, 18 y 20 px repartidos por el sistema.

**Regla para decidir:** si lo que dibujas *contiene* otras cosas → 14. Si *está
contenido* → 10. Si se pulsa y no es una fila → píldora.

---

## 3 · Tarjeta y sus cuatro variantes · bloque 30c

**Normal · con foto · con cifra · pulsable.**

- **Fondo según dónde vive:** sobre crema, la tarjeta va en blanco; sobre
  blanco, en crema `#FBF9F4`. Nunca blanco sobre blanco con solo un borde.
- **Solo la pulsable lleva sombra**, y lleva las tres cosas juntas: sombra baja
  y difusa (`0 12px 24px -18px rgba(46,66,86,0.5)`), borde a `#E4DCCB` y
  chevron. Así se sabe qué se puede pulsar sin probar.
- **Relleno 16 / 18** (arriba-abajo / lados). En móvil, 14 / 16. La variante con
  foto no lleva relleno en la imagen.
- Título de tarjeta en Barlow Condensed 21 px mayúsculas; cifra en mono.

---

## 4 · Fila de lista · bloque 30d

- **Un solo contenedor con separadores horizontales.** Cada fila con su borde y
  su radio hace que diez filas parezcan diez tarjetas y se pierde la lista.
- **48 px de alto mínimo**, relleno 12 / 16.
- **La fila entera es pulsable**, no el chevron.
- **Dato de la derecha en mono** si es cifra comparable (importes, contadores,
  tiempos); en Plex Sans si es una palabra («Al día», «Pendiente»).
- **Máximo dos líneas por fila.** Si hace falta una tercera, es una tarjeta.

---

## 5 · Tabla que en móvil se vuelve ficha · bloque 30e

Está en seis pantallas: atletas, cobros, récords, marcas, buzón, liga.

### Escritorio
Sin líneas verticales y sin filas alternas en gris — los separadores
horizontales y la alineación bastan. Importes a la derecha y en mono, para poder
sumarlos con la vista.

### Móvil · una ficha por fila
- La columna más importante pasa a **título**
- El estado, **arriba a la derecha**
- El resto, en **una línea de datos**
- Las columnas que no caben **se pierden a propósito**: están en la ficha completa

### Cuándo se cambia
Por debajo de **720 px**, siempre ficha. **Nunca desplazamiento horizontal:** en
una tabla de siete columnas obliga a arrastrar para ver el dato que importa, y
con el móvil en una mano es imposible.

A partir de 20 filas, «Ver más». A partir de 30, buscador.

---

## 6 · Botones y chips · bloque 30f

### Tres niveles y ni uno más
1. **Azul relleno** `#3B85C0` — **uno por pantalla.** Si hay dos, ninguno destaca
2. **Borde** `#C9C0AE` con texto navy
3. **Solo texto** en `#2F6FA8`

Altura mínima 44 px en los tres. Relleno 13 / 22.

### Chips
Activo relleno navy, resto borde `#D4CBB9`.

**El filtro aplicado se ve siempre**, como chip en crema con su «×», y un
«Quitar filtros» al lado. **Nunca «Filtrar · 0»:** se dice qué está aplicado, no
cuántos.

---

## 7 · Aviso unificado · bloque 30g

Fondo navy `#2E4256`, radio 14, en los dos casos.

- **Confirmación** — icono de visto en blanco, desaparece a los 4 segundos,
  siempre con «Deshacer» si la acción es reversible. Sin botón de cerrar.
- **Error** — mismo fondo navy, icono en ámbar `#F0B968`, se queda hasta que se
  toca, con «Reintentar». **No cambia el color del bloque entero**: así el aviso
  es siempre la misma cosa.

### Dónde aparece
- Móvil: abajo, 16 px por encima de la barra de pestañas
- Panel de escritorio: abajo a la **izquierda**, no centrado (tapa el contenido)

### Reglas
- **Uno a la vez.** Si llega otro, sustituye al anterior. Nunca apilados.
- Lo que es parte del contenido —un recibo pendiente— **no es un aviso**: va en
  la página.

---

## 8 · Cabecera de pantalla · bloque 30h

### App
Sobre crema, sin barra de color. Migas a 14 px arriba, título a 28 px debajo,
acción a la derecha alineada con la base del título.

**La cabecera navy se reserva** para pantallas de trabajo —entreno, calles,
tests— donde marca «esto es otro modo».

### Panel
Migas, título a 28 px con **el recuento al lado en mono** (no como tarjeta
aparte), y máximo dos acciones: una azul y una de borde. Si hacen falta más, van
en un menú de tres puntos.

---

## 9 · Los dos nombres de la primera entrada · bloque 30i

| Nombre | Ancho de menú | Nota |
|---|---|---|
| «Entrena con nosotros» | ≈ 720 px | Cabe en 1100 px con logotipo compacto y margen de 24 px. Sin holgura |
| **«Entrenar»** | ≈ 610 px | 110 px menos y no pierde nada |

**Cuándo se cambia, sin volver a preguntar:** en cuanto se cumpla cualquiera de
las dos condiciones — que haga falta una octava entrada de primer nivel, o que
el menú pase de **760 px medidos**. Se cambia solo esa palabra; el resto de
nombres se queda.

---

## Orden de aplicación sugerido

1. **Punto 0 de `FUNDAMENTOS.md`** — buscar y reemplazar las etiquetas en
   mayúsculas con espaciado ancho. Toca las 40 pantallas y es lo más barato
2. **Iconografía** (punto 1) — segundo en relación efecto/esfuerzo
3. **Radios** (punto 2) — mecánico
4. **Aviso unificado** (punto 7) — retira un sistema entero
5. Tarjeta, fila, tabla-ficha, botones, cabecera — al ir tocando cada pantalla

## Pendiente de maquetar

- **Retos y medallas** — a medias en `Retos Apolana.dc.html`: están los siete
  rangos y los cuatro estados de la tarjeta de reto; falta cerrar el momento
  «lo has conseguido», el perfil público y el módulo de admin
- **Panel: Inicio, Atletas, Cobros** — de ahí sale el patrón para las otras 23
- **Galería** — rejilla plana sin ampliar foto, y con 200 fotos
- **En la pista** (`/admin/campo/`) — pasar lista con una mano y con sol
- **Instalar la app**, **Escuelas**, **Liga**, **Estadísticas**
