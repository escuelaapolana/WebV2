# Propuesta · conexión de ChatGPT: modelos de parciales (SIN ACTIVAR)

29-oct-2026. Solo propuesta: **no hay código ni migración aplicada**. La conexión de
prueba (`academia_api` + Edge `academia-mcp`, ver docs/integracion-chatgpt.md) sigue
como está. Se activa solo con OK explícito de Andrés.

## Alcance

- Solo grupos **de prueba** (el mismo candado de `academia_api`: `es_prueba`).
- Dos herramientas nuevas: **leer** modelos y **proponer** un modelo. Nada más.
- La conexión **no puede**: aprobar un modelo, ponerlo vigente, descartar el de
  Andrés, cambiar el objetivo acordado (`atleta_objetivos`) ni tocar nada real.
- Guardar una propuesta solo cuando Andrés lo pida expresamente en el chat (como
  `guardar_borradores`): cada guardado es una petición suya.

## 1 · `leer_modelos_parciales` (solo lectura)

Entrada: `atleta_id` (o `grupo_id` para todos los del grupo de prueba), `prueba_id` opcional.

Devuelve, por objetivo acordado de la temporada:
- **Objetivo** (solo lectura): prueba, valor, temporada, versión.
- **Modelo actual**: total, tramos y subdivisiones, `estado` (borrador · propuesta ·
  vigente · descartado), `origen`, `version`, `fundamento`, `limitaciones`, autor y
  fechas, aprobación (quién, cuándo, qué versión) y la comprobación de sumas
  (`objetivo_parciales_comprobar`).
- **Propuestas de la conexión** pendientes (ver § 3), con su estado.
- **Resultados con parciales** de esa prueba (12 meses): fecha, valor, método,
  oficial, tramos por intento. Para que la propuesta parta de datos medidos.

## 2 · `proponer_modelo_parciales` (escritura; NO habilitada todavía)

En dos pasos, como `aplicar`:
1. **Simular** (por defecto, `guardar:false`): no escribe. Devuelve la comprobación de
   sumas, las diferencias con el modelo actual y los conflictos.
2. **Guardar** (`guardar:true`, solo si Andrés lo pide en ese momento).

Entrada:
- `objetivo_id`, `tiempo_total_s`, `tramos` ([{desde_m, hasta_m, tiempo_s}],
  subdivisiones incluidas).
- `fundamento` y `limitaciones` (**obligatorios**: sin ellos no se guarda).
- `version_base`: la versión del modelo actual que se leyó (o `null` si no había).
- `clave_cliente`: estable para esa propuesta (evita duplicados).

Reglas:
- **Procedencia**: `origen = 'chatgpt'` siempre; autor «ChatGPT (conexión de prueba)»
  en el historial. Nunca `chatgpt_simulado` (eso es solo para datos ficticios).
- **Duplicados**: misma `clave_cliente` y mismo contenido → «ya estaba guardada», no se
  repite. Misma clave con otro contenido → se rechaza (hay que usar otra clave).
- **Cambios simultáneos**: si el modelo actual ya no está en `version_base` (alguien lo
  ha cambiado o aprobado), se rechaza sin escribir y se devuelve lo que hay ahora.
- **Sumas**: no se guarda una propuesta que no cuadre (tramos seguidos desde 0, suma =
  total, cada subdivisión cubre su tramo y suma su tiempo).
- **Nunca pisa lo de Andrés**: la propuesta no reemplaza el modelo actual (ver § 3).

## 3 · Dónde se guarda una propuesta (recomendación)

**Recomendado: tabla aparte `objetivo_parciales_propuestas`** (atleta, objetivo,
total, tramos, fundamento, limitaciones, `clave_cliente` única, `version_base`,
estado `pendiente · adoptada · rechazada`, historial). Andrés la ve en
«Modelo de parciales…» y elige **«Adoptar como propuesta»** (se copia a
`objetivo_parciales` con origen `chatgpt`, sin aprobar, comprobando `version_base`) o
**«Rechazar»**. La aprobación sigue siendo un paso suyo aparte.
- Ventaja: una propuesta nunca sustituye ni desaprueba un modelo que Andrés ya tiene.

Alternativa más simple: escribir directamente en `objetivo_parciales` como
`propuesta` **solo si no hay modelo o el actual no está aprobado**. Desventaja: pisa
el borrador del entrenador y un modelo aprobado bloquea cualquier propuesta.

## 4 · Qué haría falta (cuando se active)

- Migración: tabla de propuestas + RLS (leer: quien puede ver al atleta; escribir: solo
  por la función) + `academia_api` con las dos operaciones (candado de prueba).
- Edge `academia-mcp`: las dos herramientas (lectura con `readOnlyHint`).
- Pantalla: bloque «Propuestas de ChatGPT» en el diálogo del modelo (adoptar / rechazar).
- Pruebas en transacción deshecha: duplicado, conflicto de versión, no cuadra, grupo
  real rechazado, intento de aprobar o tocar el objetivo rechazado.
