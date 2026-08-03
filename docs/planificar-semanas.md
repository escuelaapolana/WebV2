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

## Por CSV

Descarga la plantilla desde la propia página, rellénala en Excel, guarda como CSV y súbela.

## Para varios grupos

- Planifica uno y usa **Duplicar semana** para llevarlo a otro grupo o fecha.
- O guarda la semana como **plantilla** y aplícala al resto.
