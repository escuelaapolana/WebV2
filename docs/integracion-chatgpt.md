# Cargar en la app las planificaciones aprobadas en ChatGPT — PROPUESTA (sin implementar)

> 28-oct-2026 · Andrés prepara las planificaciones de Academia con ChatGPT. Cuando
> las aprueba, ChatGPT las carga en la app sin copiar nada. Publicar es otra
> operación, solo cuando Andrés lo pide. Ver también
> [modelo-datos-seguimiento.md](modelo-datos-seguimiento.md) e
> [historial-entrenos.md](historial-entrenos.md).

## 1. Dos piezas distintas (y hacen falta las dos)

1. **El servicio del club** (lo construimos aquí): una función en Supabase,
   `academia-planificacion`, con pocas operaciones bien cerradas. Es la misma para
   cualquier cliente.
2. **La conexión en ChatGPT** (la configura Andrés en su cuenta): que ese chat
   concreto sepa llamar al servicio y con qué clave. **Que el servicio exista no
   significa que el chat pueda usarlo**: hasta que no se conecta, ChatGPT no lo ve.

## 2. Formas de conectar ChatGPT (de la más sencilla a la más compleja)

| Opción | Cómo | Ventajas | Límites / a comprobar en tu cuenta |
|---|---|---|---|
| **A. GPT personalizado con «Acciones»** (recomendada para empezar) | Creas un GPT «Planificación Academia», le pegas la descripción OpenAPI del servicio y, en *Autenticación → Clave de API*, pegas TÚ la clave (ChatGPT la guarda cifrada; nunca va en el chat). | Funciona con clave de API, sin montar un sistema de inicio de sesión. Las operaciones de escritura pueden exigir **tu confirmación** en cada llamada (`x-openai-isConsequential`). | Las Acciones viven en ese GPT: hay que planificar **dentro de ese GPT** (puede llevar tus instrucciones y documentos), no en un Proyecto normal. Un GPT no puede usar a la vez Acciones y Apps. |
| **B. Conector MCP (modo desarrollador / Apps)** | El servicio se publica también como servidor MCP remoto y se añade como conector en *Ajustes → Conectores*. | Se puede activar en cualquier chat. Las escrituras piden confirmación. | Exige inicio de sesión **OAuth** (más trabajo). Según varias fuentes, las escrituras con conectores propios pueden estar limitadas a planes Business/Enterprise/Edu y en Plus/Pro ser solo lectura: **hay que comprobarlo en tu plan.** Está en beta y cambia a menudo. |
| **C. Codex en tu Mac** | El agente local llama al servicio con una clave guardada en un fichero de tu Mac (nunca en el chat). | No depende del plan de ChatGPT. | Solo desde tu ordenador; la clave queda en disco. |

**Propuesta:** construir el servicio una vez, con su descripción OpenAPI, y
conectar primero la **opción A**. Si más adelante la B está disponible con
escritura en tu plan, se añade el modo MCP sobre el mismo servicio.

## 3. Operaciones del servicio

Todas con la clave de la integración y limitadas a **Academia AC98**.

| Operación | Qué hace | Confirmación en ChatGPT |
|---|---|---|
| `GET /contexto?semana=AAAA-MM-DD` | Atletas del grupo (id, nombre corto, pruebas, disponibilidad y restricciones vigentes, objetivos), sesiones de la semana (id, fecha, mañana/tarde, atletas, título, publicada, versión, archivada, si tiene registros) y seguimiento resumido (estado, RPE, molestias, cobertura del feedback). **Sin DNI, teléfonos ni correos.** | No (solo lectura) |
| `POST /borradores` | Crea o actualiza **borradores** de la semana con bloques y filas (§4). | Sí |
| `GET /borradores?semana=` | Lo que hay guardado de esa semana, para comprobar el resultado. | No |
| `POST /publicar` | Publica los borradores indicados, **solo cuando Andrés lo pide**. | Sí (siempre) |
| `GET /prueba` | Comprueba la conexión y la clave sin tocar nada. | No |

## 4. Reglas de `POST /borradores`

- **Sin duplicados al repetir un envío.**
  - Cada envío lleva un `envio_id`. Si el mismo `envio_id` llega con el mismo
    contenido, devuelve el resultado guardado. Si llega con contenido distinto, lo
    rechaza (tabla `api_envios`).
  - Además, cada sesión se identifica por **atleta + fecha + mañana/tarde**: si ya
    existe, se actualiza; no se crea otra.
- **Sin sobrescribir cambios hechos en la app.**
  - Para actualizar, el envío trae la `version_base` que leyó (la columna
    `sesiones.version` ya existe).
  - Si la sesión cambió entretanto (versión distinta), **no se toca**: se devuelve
    «conflicto» con quién la cambió y cuándo (de `sesiones_versiones`) y su
    contenido actual.
  - Una sesión **ya publicada o con registros de atletas** nunca se cambia desde
    aquí: se devuelve «conflicto: publicada/con registros».
- **El histórico se conserva solo:** cada cambio pasa por los disparadores de la
  fase 1 y la versión queda firmada como «ChatGPT (clave …)».
- **Borrador = `publicada = false`.** El atleta no lo ve. Lo revisas en la app (o
  en ChatGPT) y publicas aparte.
- **Respuesta de cada sesión:** `id`, fecha, mañana/tarde, atletas, `version` y
  `estado` (creada · actualizada · sin cambios · conflicto), con el motivo si hay
  conflicto.
- **Bloques:** el formato actual (`etiqueta`, `solo_marcar`, `filas` con
  `ejercicio`, `detalle` y los campos opcionales `series`, `distancia`, `ritmo`,
  `descanso`, `calzado`, `carga`). La estructura nueva (`componentes`, contenido
  principal, etiquetas) se añadirá cuando exista (paso 3 del modelo de datos). Si
  algo no se entiende, la fila queda «pendiente de revisión»: no se inventa.
- **Modo prueba:** `simular: true` lo valida todo y devuelve lo que haría, sin
  guardar.

## 5. Seguridad

- **Clave propia de la integración, nunca la maestra.** Se guarda cifrada en la
  tabla `api_claves` con:
  - a qué grupo llega (Academia);
  - qué puede hacer (`leer`, `borradores`, `publicar`);
  - caducidad y botón de revocar;
  - último uso.
- **La clave no pasa por ningún chat.** La genero en el servidor y te la dejo en un
  fichero local de tu Mac. Tú la pegas una sola vez en la configuración del GPT. Si
  se filtra, se revoca al momento y solo afecta a Academia.
- **La función solo usa operaciones de la base hechas a medida**, que comprueban el
  alcance de la clave. No hay acceso libre a las tablas.
- **Registro de cada llamada** (`api_registro`: cuándo, qué operación y qué
  resultado), sin guardar el contenido sensible.
- **Datos de salud:** RPE, molestias y bienestar salen hacia OpenAI. Conviene que
  lo vea la asesoría y avisar a los atletas antes de activarlo. Se puede empezar
  sin enviar molestias ni bienestar.

## 6. Pasos cuando se apruebe

1. Servicio, tablas `api_claves` / `api_envios` / `api_registro` y operaciones de
   la base. Pruebas con `simular` y en un día de prueba sin atletas reales.
2. Descripción OpenAPI y guía corta para crear el GPT (§2 A).
3. Prueba de punta a punta en tu ChatGPT: leer, guardar borrador, repetir el mismo
   envío (sin duplicados), cambiar algo en la app y volver a enviar (conflicto),
   publicar.

## Preguntas para Andrés

1. ¿Qué plan de ChatGPT tienes (Plus, Pro, Business…)?
2. ¿Planificas en un **Proyecto** de ChatGPT? Con la opción A habría que pasar a un
   GPT propio (con tus instrucciones y documentos dentro).
3. ¿Quieres que ChatGPT pueda **publicar** (con tu confirmación) o publicas siempre
   tú desde la app?
4. ¿Le enviamos a ChatGPT RPE y molestias, o al principio solo lo realizado sin
   datos de salud?
