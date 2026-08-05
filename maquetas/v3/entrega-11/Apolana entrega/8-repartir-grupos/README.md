# 8 · Repartir a los niños entre los grupos

Panel de administración, pantalla nueva. Hoy es ficha por ficha; con 400 familias es inviable.

**Archivo visual:** `Repartir grupos Apolana.html`. **1a** escritorio, arrastrando · **1b** móvil,
seleccionando y moviendo.

## La decisión: turno primero, nivel después

El filtro grande de arriba es el **turno** (lunes/miércoles o martes/jueves), no el nivel.
Son dos mundos que no se mezclan nunca, y es donde antes se confundían los dos grupos que se
llaman igual. Por defecto se ve **un nivel dentro de un turno ya elegido**, una columna: no hay
turno vecino al que arrastrar por error.

Un botón **«Ver los dos turnos»** abre la vista de dos columnas lado a lado como caso puntual,
para cuando hace falta comparar al repartir hermanos. Cada turno tiene su color de fondo (azul
claro / arena) para que arrastrar al vecino sea visualmente incómodo.

## Escritorio · 1a

- Columna «Sin grupo» siempre visible a la izquierda, con conteo.
- Tarjeta de niño: iniciales en círculo de color por nivel, nombre, año de nacimiento.
  **Aviso en rojo dentro de la tarjeta** cuando hay un hermano en el turno equivocado o el niño
  no es del año del grupo — nunca solo en un contador aparte.
- Amigos: «2 amigos aquí» cuando alguno de los nombres pedidos en la inscripción ya está en esa
  columna.
- Contador de plazas: `14/18` normal, **rojo si se pasa** (`19/18`) — avisa, no bloquea.
- **↺ Deshacer** fijo en la cabecera durante toda la sesión de reparto, no un aviso que
  desaparece solo.
- Selección múltiple: clic + mayúscula.

## Móvil · 1b

**Nada se arrastra.** Tocar selecciona (casilla + borde azul). «Mover a…» abre una hoja con los
grupos candidatos, ordenados por plazas libres, mismo nivel primero. Confirma antes de mover
aunque el grupo destino esté completo. Todo pulsable ≥ 44 px.

## Pendiente del club

- El campo «con quién le gustaría estar» del formulario de inscripción tiene que llegar hasta
  aquí como dato de amigos.
- Las 18 plazas por grupo y el año de cada nivel ya viven en la base (ver entrega 5).

---

# 9 · El planificador del entrenador

`portal/entrenador/`. Dos encargos: revisión de **Planificar semana** (entrega 9, 0a) y el
**calendario**, que nunca tuvo maqueta.

**Archivo visual:** `Planificador entrenador Apolana.html`. **2a** semana en escritorio ·
**2b** semana en móvil · **2c** calendario.

## Planificar semana · lo que cambia

1. **«Copiar la semana pasada» sube a botón sólido junto al título**, del mismo peso que la
   acción principal de cualquier pantalla del panel. Es el gesto más frecuente, no una opción
   más de la fila de mandos.
2. **Dos chips, no uno.** El deporte (azul) y el papel del día (arena), siempre en ese orden.
   Antes iban fundidos en un solo texto.

Lo demás se queda: banda ámbar de borrador, día vacío con borde discontinuo, estado + «Abrir»
al pie.

## El calendario · las dos decisiones que faltaban

**La leyenda de los puntos.** Verde y ámbar ya significan «bien» y «ojo» en pagos y avisos. Se
evita el choque usando **forma, no color nuevo**, todo en el mismo navy: punto relleno =
publicado, punto con borde = borrador, rombo = competición. Leyenda fija arriba del mes.

**Día con y sin entreno.** Sin punto y número algo más pálido (`#A79E8B`). Ningún fondo extra:
la ausencia del punto ya lo dice.

Tocar un día lo resalta con el borde azul de selección y abre su detalle debajo del mes — tal
como pidió el tesorero para el calendario de la web. Dos entrenos el mismo día son dos puntos
juntos, no una cifra.

## Tokens nuevos de estas dos pantallas

| Uso | Valor |
|---|---|
| Columna de turno lunes/miércoles | fondo `#EAF2F9`, borde `#CBDEEF`, texto `#1E4E78` |
| Columna de turno martes/jueves | fondo `#F1EADC`, borde `#E0D7C4`, texto `#6E5A34` |
| Aviso de hermano/año en tarjeta | borde `#B3261E`, fondo `#FDECEA`, texto `#8F1F19` |
| Punto de calendario (las 3 formas) | `#2E4256` — relleno / solo borde / rombo |
| Día sin entreno | número en `#A79E8B` |
