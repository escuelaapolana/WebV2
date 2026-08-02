# Descansos · cómo quedan modelados y cómo se enganchan

Hasta ahora una serie se escribía sin recuperación. Y sin recuperación una serie
no dice nada: **6×800 con 90" no tiene nada que ver con 6×800 con 3'**. Este
documento explica cómo se ha resuelto para las cinco disciplinas, qué escribe el
entrenador en cada una, cómo se calcula el tiempo estimado y qué queda por
enganchar en cada pantalla.

Todo vive en un solo archivo: **`assets/js/descansos.js`**. Ninguna página ha sido
tocada.

---

## 1 · Lo primero: NO hace falta migración

`sesiones.bloques` ya es una columna `jsonb`. Los campos nuevos caben dentro sin
tocar el esquema, sin `ALTER TABLE` y sin riesgo para lo que ya hay escrito. **No
se ha creado `migraciones/055_descansos.sql` y no hace ninguna falta.**

Además, lo que ya está escrito se sigue entendiendo solo: hoy el descanso vive en
un campo de texto libre `descanso` («2 min», «bajada suave», «1:30»…). El módulo
lo lee y lo interpreta. Comprobado contra la base real: **de 825 filas de
entrenamiento, 413 llevan ya un descanso escrito y el módulo entiende 409**. Las
4 que no («vuelta andando», «subida andando») se pintan tal cual, sin perder nada.

---

## 2 · Cómo se guarda

Un bloque de `sesiones.bloques` era, y sigue siendo:

```
{ etiqueta, matiz, calle, atletas, filas: [ … ] }
```

y una fila:

```
{ ejercicio, series, distancia, ritmo, descanso, material, calzado, carga, detalle, observaciones }
```

**Se añade, sin quitar nada:**

| Dónde | Campo nuevo | Para qué |
|---|---|---|
| Fila | `rec` | La recuperación **dentro** de la serie |
| Fila | `desnivel_m` | Montaña: metros de desnivel de la subida |
| Bloque | `rec_bloque` | El descanso **después** de ese bloque (el separador que faltaba) |
| Bloque | `rec_ejercicios` | El Cubo: el descanso **entre ejercicios**, que es otra cosa |

El objeto `rec` de una fila:

```js
rec = {
  modo:     'salida' | 'fijo' | 'tiempo' | 'distancia' | 'bajada' | 'ninguna',
  segundos: 90,        // cuando el modo va en tiempo
  metros:   200,       // cuando el modo va en metros
  forma:    'trote' | 'parado' | 'andando' | 'suave' | 'trotando' | 'bici' | 'bastones' | null,
  texto:    '…'        // solo si el entrenador escribió algo que no encaja en nada
}
```

Y los de bloque, más simples: `rec_bloque = { segundos: 180 }`,
`rec_ejercicios = { segundos: 180 }`.

### La red de seguridad: `descanso` se sigue escribiendo siempre

Cuando se guarda con `ponerRec(fila, rec, disciplina)`, el módulo escribe **las dos
cosas**: el objeto `rec` y el texto de siempre en `fila.descanso`. Así, si una
pantalla que todavía no conoce `rec` guarda esa fila y se deja el objeto por el
camino, **el dato no se pierde**: al volver a leerla, el módulo lo interpreta otra
vez desde el texto.

> ⚠️ Aun así, cuando enganches las pantallas, añade `'rec'` a las listas de campos
> que se copian al guardar una fila. Hoy en `portal/entrenador/index.html` hay dos
> (líneas ~2642 y ~3122) con `['series','distancia','ritmo','descanso',…]` que
> reconstruyen la fila desde el formulario y se dejarían `rec` fuera. Con la red de
> seguridad no se rompe nada, pero se pierde precisión.

---

## 3 · Qué escribe el entrenador en cada disciplina

El módulo sabe de qué deporte se trata con
`disciplinaDe(sesion, grupo)`, que cruza `sesiones.tipo` con `grupos.seccion`
(un `continuo` de la sección montaña se escribe por desnivel, no por series).
Devuelve una de estas cinco: `natacion`, `pista`, `running`, `cubo`, `montana`.

| Deporte | Qué elige el entrenador | Lo que se escribe en pantalla |
|---|---|---|
| **Natación** | Dos modos, uno u otro por bloque: **salida cada X** (nadar y descansar caben dentro) o **descanso fijo** (X segundos al tocar pared) | `8 × 50 salida 1'00"` · `10 × 100 descanso 20"` |
| **Atletismo pista** | Recuperación en tiempo o en metros, diciendo si es trote o parado. Obligatoria | `6 × 800 rec 2' trote` · `10 × 400 rec 200 m` |
| **Running** | Igual que pista. En rodajes y tiradas **el campo se oculta** | `5 × 1.000 rec 90"` · `12 km` |
| **El Cubo · fuerza** | Descanso entre series **y** descanso entre ejercicios, separados | `4 × 6 sentadilla desc. 2'` + `3' entre ejercicios` |
| **Montaña** | Por desnivel, no por series. La recuperación es la bajada | `5 × subida 400 m D+ · rec: bajada suave` |

Y en las cinco, el separador entre bloques: **`3' de descanso`**.

Estos textos no los escribe cada pantalla: los escribe el módulo, para que las
cinco digan exactamente lo mismo.

### Las reglas comunes, ya resueltas

- **Nunca un campo vacío.** Si un bloque no lleva recuperación, `textoRec()`
  devuelve cadena vacía y la pieza no se pinta. **Nunca un «—»**: un guion hace
  dudar de si falta el dato o de si de verdad no hay descanso.
- **Salida y descanso, distinguidos por color** en natación. `etiquetaNatacion(rec)`
  devuelve ya el color, el fondo, el borde, la palabra y una línea de ayuda:
  - **salida** → azul del club `#1F5C8F` sobre `#E7F0F8` · «Nadar y descansar caben
    dentro del intervalo.»
  - **descanso** → tierra `#6B5227` sobre `#F7EFDD` · «Segundos parado al tocar la
    pared, tardes lo que tardes.» *(el ámbar no se usa: está reservado a los avisos)*
- **Cuándo es obligatorio.** `pideRec(fila, disciplina)` dice si el formulario debe
  exigir la recuperación: en pista y running, sí, salvo que la fila sea de una sola
  repetición (rodaje, tirada, ejercicio suelto), donde el campo se oculta.

---

## 4 · Cómo se calcula el tiempo estimado

Con la recuperación puesta ya se puede calcular la duración. **Volumen y tiempo se
muestran separados**: `2.000 m` **y** `~55'`. Las familias planifican con el
tiempo, no con los metros.

### Las reglas del cálculo

- **Natación, «salida cada X»**: el intervalo lo incluye todo, así que 8 × 50 al
  1'00" son 8 minutos clavados. **Es el único caso en que el tiempo se sabe seguro
  sin conocer el ritmo.**
- **Descanso fijo, en tiempo o en metros**: se suma el trabajo más el descanso. El
  descanso va **entre** repeticiones, o sea `(series − 1)` veces; el de después de
  la última es el descanso del bloque.
- **El trabajo** se sabe si la fila trae el tiempo escrito («10 min») o si trae
  metros **y** un ritmo de verdad («3:00/km», «1'40"/100»).
- **Entre bloques** se suma `rec_bloque` de todos menos el último. En El Cubo,
  además, `rec_ejercicios` entre filas.

### Es honesto: si falta un dato, no se inventa

Un «al 90%» o un «por sensaciones» **no son ritmos** y no se usan para calcular. Si
falta algo, el resultado trae `completo: false`, `minutos: null` y una lista en
`faltan` con el porqué. **La pantalla entonces enseña solo el volumen.**

Si el entrenador ya puso la duración de la sesión (`sesiones.duracion_min`), esa
manda y se pinta **sin tilde**: es un dato, no una estimación (`estimado: false`).

### Estado real hoy

Probado con las 129 sesiones reales de la base: **50 tienen la duración puesta a
mano, 6 se estiman ya con los datos existentes y 73 no dan tiempo** (no traen ni
tiempo ni ritmo utilizable). Ese número subirá solo, según los entrenadores vayan
usando los campos nuevos. Ninguna sesión reventó el módulo y ninguna línea salió
con «undefined» ni «NaN».

### Natación con calles

Cada nadador hace los bloques comunes **más los de su calle**, no los de todas. Por
eso el volumen de una sesión con calles no se puede dar «en general»:

- `resumen(sesion, { calle: 3 })` → lo que le toca a la calle 3
- `estimarPorCalles(sesion)` → una estimación por calle, que es como se mira desde
  el bordillo: `calle 1 · 1.400 m · ~48'`
- Si no se pasa calle, el resultado trae `tiene_calles: true` para que la pantalla
  sepa que debe preguntar por una.

---

## 5 · Cómo se engancha (lo que tengo que hacer yo)

En la página, antes de tu script:

```html
<script src="/assets/js/descansos.js"></script>
```

Y luego:

```js
var D   = window.APOLANA_DESCANSOS;          // o el atajo window.Descansos
var dis = D.disciplinaDe(sesion, grupo);     // 'natacion' | 'pista' | 'running' | 'cubo' | 'montana'

// --- pintar una fila ---
D.partesFila(fila, dis)     // ['6 × 800 m', 'ritmo 3:00/km', 'rec 2\' trote'] → chips
D.textoFila(fila, dis)      // '6 × 800 m rec 2\' trote' → una línea
D.textoRec(D.recDeFila(fila, dis), dis)      // solo el descanso, '' si no hay

// --- el separador entre bloques ---
D.textoEntreBloques(bloque)      // "3' de descanso" — '' si ese bloque no lleva
D.textoEntreEjercicios(bloque)   // El Cubo: "3' entre ejercicios"

// --- volumen y tiempo, separados ---
var r = D.resumen(sesion, { disciplina: dis });
r.volumen        // '2.000 m'   ('' si no hay metros)
r.tiempo         // '~55'' si es estimación · '55'' si lo puso el entrenador · '' si no se sabe
r.estimado       // true = lleva la tilde de «más o menos»

// --- guardar ---
D.ponerRec(fila, { modo: 'salida', segundos: 60 }, 'natacion');
D.quitarRec(fila);      // borra `rec` y `descanso`: el campo desaparece
D.ponerRecEntreBloques(bloque, 180);
D.ponerRecEntreEjercicios(bloque, 180);   // solo El Cubo
```

**Dos detalles al pintar:**

1. En **El Cubo**, `textoFila()` ya trae el nombre del ejercicio dentro
   (`4 × 6 sentadilla desc. 2'`), porque ahí la serie sin el ejercicio no significa
   nada. En el resto de deportes el nombre lo sigue pintando la pantalla aparte, y
   `partesFila()` nunca lo incluye.
2. `resumen()` trae `volumen_parcial: true` cuando hay filas medidas en tiempo o en
   repeticiones: los metros no lo cuentan todo y conviene no presumir de ellos.

### Lo que falta por enganchar, pantalla a pantalla

| Pantalla | Qué hay que hacer |
|---|---|
| **`portal/entrenador/`** | El formulario de fila: sustituir el `input` suelto `.f-descanso` por selector de modo (según `MODOS[disciplina]`) + valor + trote/parado. Añadir `'rec'` y `'desnivel_m'` a las dos listas de campos que se copian (~2642 y ~3122). Campo de descanso al pie de cada bloque (`rec_bloque`) y, en El Cubo, `rec_ejercicios`. En la vista previa, cambiar `'rec '+f.descanso` (~3344) por `D.textoRec(…)`. |
| **`portal/calles/`** | El `input` «Descanso» (~387) pasa a los dos modos de natación con su etiqueta de color. Volumen y tiempo por calle con `estimarPorCalles()`. |
| **`portal/atleta/`** | Cambiar `'desc. '+f.descanso` (~433 y ~971) por `D.partesFila()`. Añadir el separador entre bloques y la cabecera con volumen **y** tiempo. |
| **`portal/familia/`** | Igual (~656). Aquí el tiempo estimado es lo que más se mira: es lo que usa la familia para planificar. |
| **`admin/`** | Solo lectura: volumen y tiempo en la ficha de sesión, con `resumen()`. |
| **`portal/carga/`** | Tiene una tabla fija `DUR_ESTIMADA` por tipo de sesión (~211). Cuando el módulo dé tiempo (`r.completo`), usar ese en vez del número fijo; si no, dejar el de siempre. |

Nada de esto está hecho: el módulo está entregado y probado, pero **ninguna página
ha sido tocada**.
