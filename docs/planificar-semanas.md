# Planificar semanas rápido

La idea: **no rellenar formularios sesión a sesión**. Escribes (o generas) la semana en un
formato de texto sencillo, la pegas en el portal del entrenador → "Planificar semana" →
*Interpretar* → *Crear semana*. También puedes rellenar la plantilla CSV y subirla.

## Formato de texto aceptado

```
LUNES · pista · calidad_fuerte · Series 6x150
Nota: objetivo y sensaciones a buscar en la sesión.
# Calentamiento
- Carrera continua suave | 10 min
- Drills de frecuencia | 2x30 m
# Parte principal
- Voladoras | 4x60 m | 90-95% | desc 4 min
- Salidas desde tacos | 5x20 m | desc 2 min
# Vuelta a la calma
- Trote suave | 8 min

MARTES · descanso

MIÉRCOLES · gym · secundaria · Fuerza general
# Parte principal
- Sentadilla | 4x6 | 80% | desc 3 min
- Hip thrust | 3x8
```

Reglas:
- Una línea por **día** (LUNES…DOMINGO). Detrás, separado por `·`: **tipo**, **rol** y **título**.
- **tipo**: `pista`, `gym`, `continuo`, `activacion`, `competicion`, `descanso`.
- **rol**: `calidad_fuerte`, `secundaria`, `activacion`, `ultimo_toque_48h`, `descarga`, `competicion`.

> **Estos dos nombres son los de antes, y se siguen entendiendo.** Al planificar
> de uno en uno ya no se elige «tipo» y «rol», sino **deporte** (atletismo,
> natación, fuerza, El Cubo) y **papel del día** (ajuste, carga, impacto,
> recuperación, activación, tapering, competición, descanso, rehabilitador).
> Lo que se pega aquí en texto o se sube en CSV se traduce solo a los dos ejes
> nuevos al guardarlo, así que las plantillas de siempre siguen valiendo.
- `Nota:` (opcional) = razonamiento de la sesión.
- `#` abre un **bloque** (Calentamiento / Parte principal / Vuelta a la calma…).
- `-` es un **ejercicio**. Detrás, separados por `|`: series×distancia (`4x60 m`), ritmo (`90%`),
  descanso (`desc 4 min`) o cualquier detalle.
- Un día de descanso solo necesita su línea.

## Por Excel (lo más cómodo, y lo que se le da a otro entrenador)

Hay un Excel por deporte, y el botón que sale es el del deporte del grupo que
estés mirando: **plantilla-semana-natacion.xlsx** y **plantilla-semana-atletismo.xlsx**.
Se sube a Drive, se abre con Hojas de cálculo —listas y fórmulas incluidas—, se
rellena y se baja como CSV.

La gracia es que se explica solo: quien lo abra ve las columnas y sabe qué hacer,
sin que nadie le enseñe un formato. Los dos traen una semana de ejemplo en
cursiva para borrar, una hoja que se calcula sola y una hoja de instrucciones.

> ⚠️ Drive descarga **solo la hoja que tengas abierta**. Hay que ponerse en
> «Semana» antes de bajar el CSV. Es el error que se comete la primera vez.

Se generan con `herramientas/plantilla-semana-atletismo.py`. **Las cabeceras son
un contrato**: el importador reconoce cada columna por su nombre (`ALIAS_CSV` y
`claveDeCabecera`). Si se cambia una en la hoja y no en el portal, esa columna
entera se pierde al subir el archivo y no avisa nadie.

### La columna «Para quién»

Es la que hace que una misma semana valga para gente que entrena junta pero no
hace lo mismo, que es como se planifica de verdad en pista:

- vacío = lo hace **todo el grupo**;
- un nombre (`Juan`) = solo esa persona;
- un subgrupo (`Vallistas`) = ese grupo de dentro del grupo.

Viaja como **matiz del bloque**, así que en el portal se ve «Parte principal —
Juan», igual que en las planificaciones de papel. Hay que escribirlo idéntico en
todas las líneas de esa persona: el bloque se identifica por etiqueta + matiz.

Lo que **todavía no hace**: marcar solo a esos atletas como destinatarios de la
sesión. Eso sigue siendo un paso aparte, «Solo estos atletas», y es por sesión
entera, no por bloque.

## Por CSV

Descarga la plantilla CSV desde la propia página, rellénala en Excel, guarda como
CSV y súbela. Es la misma cadena que el Excel, con menos ayudas.

## Para varios grupos

- Planifica uno y usa **Duplicar semana** para llevarlo a otro grupo o fecha.
- O guarda la semana como **plantilla** y aplícala al resto.
