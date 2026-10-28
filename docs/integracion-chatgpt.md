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

## 2. El entorno de Andrés y las formas de conectar (revisado 28-oct-2026)

**Entorno comprobado en su Mac:** planifica en un **proyecto de la app de ChatGPT
para Mac con Codex integrado** (el proyecto vive en `~/.codex/.chatgpt-projects/`,
y la configuración de Codex, `~/.codex/config.toml`, ya tiene servidores MCP locales
como `node_repl` y `computer-use`). **No se da por decidido pasar a un GPT
personalizado.**

| Opción | Cómo | Escritura (borradores/publicar) | Encaje con «seguir en este proyecto» |
|---|---|---|---|
| **1. Servidor MCP en Codex** (la más prometedora) | Se añade a `~/.codex/config.toml` un `[mcp_servers.academia]` con `url` (MCP por HTTP) y la clave por variable de entorno (`bearer_token_env_var`) o por un pequeño programa local que la lee del **Llavero de macOS** (`http_headers_helper`). La clave no va en la configuración ni en el chat. | Sí: las herramientas que exponga el servidor (incluidas las de escribir). | **Alto**: aparecen en los hilos de Codex de la app, también en su proyecto. **A comprobar:** que sus chats del proyecto sean hilos de Codex (todo indica que sí) y la incidencia conocida de que la app no vea la variable de entorno (por eso, mejor el Llavero). |
| 2. App/conector MCP en ChatGPT (modo desarrollador) | Se registra el servidor en los ajustes de ChatGPT. | Según la ayuda oficial de OpenAI, la escritura completa es para planes **Business, Enterprise y Edu** (en beta); en **Pro**, solo lectura. | Medio: depende del plan; necesita OAuth. |
| 3. GPT personalizado con Acciones | OpenAPI + clave de API guardada en el GPT. | Sí, con confirmación. | Bajo: obliga a planificar dentro del GPT, fuera del proyecto. Queda como alternativa. |

**El servicio del club se diseña para no depender de la conexión:** las
operaciones viven en la base y en una función de Supabase. Esa función habla MCP
(para Codex y ChatGPT) y también REST con su descripción OpenAPI (para un GPT con
Acciones o cualquier otro cliente). Si mañana cambia la conexión, el servicio es el
mismo.

**Primera prueba de conexión:** con datos ficticios (un «grupo de prueba» con
atletas inventados) y sin información de salud. La selección de datos reales y los
permisos se cierran después.

**Pendiente de confirmar con Andrés antes de construir:** su plan de ChatGPT
(Plus/Pro/Business) y que sus conversaciones del proyecto sean hilos de Codex.

Fuentes oficiales:
- [Codex · Model Context Protocol](https://developers.openai.com/codex/mcp)
- [Codex · referencia de configuración](https://developers.openai.com/codex/config-reference)
- [ChatGPT · modo desarrollador y apps MCP](https://help.openai.com/en/articles/12584461-developer-mode-and-mcp-apps-in-chatgpt)
- [ChatGPT · Acciones en GPTs](https://help.openai.com/en/articles/9442513-gpt-actions)

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
  fichero local de tu Mac; tú la guardas en el **Llavero** (opción 1) o donde pida
  la conexión elegida, y se borra el fichero. Si se filtra, se revoca al momento y
  solo afecta a Academia.
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
2. Conexión elegida (§2): para la opción 1, la entrada en `~/.codex/config.toml` y la clave en el Llavero; la descripción OpenAPI queda lista por si se usa otra conexión.
3. Prueba de punta a punta en tu ChatGPT: leer, guardar borrador, repetir el mismo
   envío (sin duplicados), cambiar algo en la app y volver a enviar (conflicto),
   publicar.

## Preguntas para Andrés

1. ¿Qué plan de ChatGPT tienes (Plus, Pro, Business…)?
2. ¿Tus conversaciones del proyecto son hilos de Codex (los que pueden ejecutar
   herramientas y dejan ficheros en tu Mac)?
3. Publicar: ChatGPT podrá hacerlo **cuando se lo pidas**, con confirmación (decidido).
4. Datos de salud: la primera prueba va sin ellos y con datos ficticios (decidido);
   lo real se decide después.
