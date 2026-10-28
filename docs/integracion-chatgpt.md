# Cargar en la app las planificaciones aprobadas en ChatGPT — conexión de PRUEBA construida

## Estado (28-oct-2026): prueba construida, solo grupo PRUEBA

Autorizado por Andrés: tablas y función con acceso **solo al grupo «Academia AC98 ·
PRUEBA»** (datos ficticios). Sin datos reales, sin salud y sin publicación en la
Academia real.

| Pieza | Dónde |
|---|---|
| Lógica (permisos, idempotencia, versiones, huellas) | `public.academia_api(hash, operación, args)` (mig 464), solo `service_role` |
| Servidor MCP (Streamable HTTP, respuestas JSON, sin estado) | Edge `academia-mcp` (`--no-verify-jwt`; autentica con `Authorization: Bearer`) |
| Puente local para la app de ChatGPT (Codex) | `herramientas/academia-mcp-puente.py`: lee la clave del **Llavero** y reenvía |
| Activar / quitar en este Mac | `bash herramientas/academia-mcp-activar.sh` · `… --quitar` |
| Claves, envíos, registro, clave_cliente | `api_claves` (solo sha256), `api_envios`, `api_registro`, `api_sesiones_cliente` |

**Candado de la prueba:** `academia_api_grupos` solo devuelve grupos `es_prueba` de
`academia_grupos`, aunque la clave incluya otros. Abrir la Academia real exigirá una
migración explícita y el visto bueno de Andrés.

**Herramientas** (el nombre que verá ChatGPT lleva delante el del servidor,
`apolana_academia`): `estado` · `leer_semana` · `leer_sesion` ·
`consultar_borradores` · `guardar_borradores` · `proponer_revision` ·
`publicar_prueba`. Las lecturas no llevan molestias, comentarios del atleta ni
motivos de ausencia.

**Reglas implementadas:**
- **Identidad:** `clave_cliente` estable por sesión nueva (`api_sesiones_cliente`).
  Reenviar la misma sesión no la duplica: «sin_cambios» si es igual, «ya_existe» si
  es distinta y no trae `version_base`.
- **Repetición:** `envio_id` por petición. El mismo `envio_id` con el mismo
  contenido devuelve la respuesta guardada (`repetido: true`); con otro contenido,
  error.
- **Concurrencia:** cambiar un borrador exige `version_base`; si no coincide, conflicto
  y **no se guarda nada** del envío.
- **Publicadas:** no se tocan; `proponer_revision` crea una revisión pendiente
  (`via = chatgpt`) que el entrenador aplica o descarta en el panel. Una por sesión.
- **Mover de día o de atleta** = sustituir → conflicto «otra_fecha_o_atleta».
- **Publicar:** solo `publicar_prueba`, con `version` y `huella` (md5 del contenido
  sin ids de fila ni publicación). Si algo no coincide, no publica nada; si
  publica, comprueba en el historial que la versión publicada tiene la misma huella.
- Autoría: `apolana.autor = 'chatgpt · <clave>'` en el historial de versiones;
  `creado_por`/`autor_perfil_id` = Andrés (dueño de la clave); `generado_por_ia = true`.

**Verificado (28-oct):** en seco en la base (todo el circuito) y contra la función
desplegada con una clave técnica temporal, ya revocada: leer → guardar → repetir el
mismo envío → mismo contenido con envío nuevo → consultar → cambiar con versión →
cambio concurrente rechazado → publicar una versión no revisada rechazado →
publicar la revisada (v2 → v3, huella coincide) → cambiar una publicada rechazado →
proponer revisión → repetirla → grupo real rechazado. Y **el Codex de la app de
ChatGPT** (el mismo binario, con un servidor temporal) llamó a `estado` por el
puente y respondió con el grupo PRUEBA. Todo lo creado en la prueba técnica se borró.

**Falta (Andrés):** activar la conexión en su Mac y hacer la prueba desde su chat
de planificación (§6). La prueba solo se da por completada cuando funcione allí.

---

> El resto del documento es la propuesta original; donde difiere, manda lo de arriba.

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
| **1. Servidor MCP en Codex** (candidata, **pendiente de prueba real**) | Se añade a `~/.codex/config.toml` un `[mcp_servers.academia]` con `url` (MCP por HTTP) y la clave por variable de entorno (`bearer_token_env_var`) o por un pequeño programa local que la lee del **Llavero de macOS** (`http_headers_helper`). La clave no va en la configuración ni en el chat. | Sí: las herramientas que exponga el servidor (incluidas las de escribir). | **Alto**: aparecen en los hilos de Codex de la app, también en su proyecto. **A comprobar:** que sus chats del proyecto sean hilos de Codex (todo indica que sí) y la incidencia conocida de que la app no vea la variable de entorno (por eso, mejor el Llavero). |
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

**Que exista `config.toml` no demuestra que la conexión funcione.** Se considera
demostrada solo tras la prueba real del §6, paso a paso.

**Pendiente de confirmar con Andrés antes de construir:** su plan de ChatGPT
(Plus/Pro/Business) y que sus conversaciones del proyecto sean hilos de Codex.

Fuentes oficiales:
- [Codex · Model Context Protocol](https://developers.openai.com/codex/mcp)
- [Codex · referencia de configuración](https://developers.openai.com/codex/config-reference)
- [ChatGPT · modo desarrollador y apps MCP](https://help.openai.com/en/articles/12584461-developer-mode-and-mcp-apps-in-chatgpt)
- [ChatGPT · Acciones en GPTs](https://help.openai.com/en/articles/9442513-gpt-actions)

## 3. Operaciones del servicio

Todas con la clave de la integración y limitadas a **Academia AC98**.

| Operación | Qué hace | Confirmación |
|---|---|---|
| `prueba` | Comprueba la conexión y la clave sin tocar nada. | No |
| `contexto(semana)` | Atletas del grupo (id, nombre corto, pruebas, disponibilidad y restricciones vigentes, objetivos), sesiones de la semana (id, fecha, momento, atletas, título, clase de día, publicada, versión, archivada, si tiene registros) y seguimiento resumido. **Sin DNI, teléfonos ni correos**; en la primera prueba, **sin salud**. | No |
| `guardar_borradores(envio)` | Crea o actualiza borradores (§4). | **No otra vez**: pedir expresamente «guarda los borradores» ya es la autorización |
| `proponer_revision(sesion_id, version_base, cambios)` | Propone cambios a una sesión **ya publicada** (§4.4). | No otra vez, si se ha pedido expresamente |
| `ver_borradores(semana)` | Lo guardado, con ids, versiones y estado, para comprobar el resultado. | No |
| `publicar(lista de {id, version_revisada})` | Publica **solo** lo indicado y **solo** si la versión no ha cambiado (§4.5). | Solo cuando Andrés pide publicar |

El mismo servicio habla **MCP** (Codex, ChatGPT) y **REST con OpenAPI** (otros
clientes). Si cambia la conexión, el servicio no cambia.

## 4. Reglas

### 4.1 Identidad: id estable, no «atleta + fecha + momento»

- Una sesión se identifica por su **`id`** (y su `version`). Atleta, fecha y momento
  pueden cambiar, y en una misma franja puede haber varias sesiones.
- Para una **sesión nueva**, ChatGPT manda una **`clave_cliente`** estable que elige él
  (p. ej. `S10-atletaX-lunes-1`). El servicio la guarda junto a la sesión que crea y
  devuelve su `id`. Desde entonces, se trabaja con el `id`.

### 4.2 Repetición de envíos (aparte de la identidad)

- Cada envío lleva un **`envio_id`** (tabla `api_envios`):
  - mismo `envio_id` y mismo contenido → devuelve el resultado ya guardado, **sin
    duplicar**;
  - mismo `envio_id` y contenido distinto → se rechaza.
- Si una `clave_cliente` ya creó una sesión, otro envío con esa clave **actualiza esa
  sesión** (por su `id`); no crea otra.

### 4.3 Cambios hechos entretanto en la app

- Para actualizar un borrador, el envío trae la **`version_base`** que leyó.
- Si la sesión cambió desde entonces → **conflicto**: no se toca, y se devuelve quién la
  cambió, cuándo y el contenido actual.
- **Nada se sobrescribe en silencio.**

### 4.4 Cambios a sesiones ya publicadas: revisión en borrador

- No se toca la sesión publicada ni se crea un entrenamiento duplicado.
- Se guarda una **revisión en borrador vinculada** (`sesiones_revisiones`: sesión
  original, `version_base`, cambios propuestos, autor, estado).
- Al aprobarla, se aplica **sobre la misma sesión**, que pasa a una versión nueva.
  Mantiene su `id`, su feedback y su historial. Si la sesión cambió desde
  `version_base`, conflicto.
- Si la sesión ya tiene registros de atletas, la revisión lo avisa expresamente.
- **Revisar o sustituir**: ver la tabla de [mundo-academia.md](mundo-academia.md)
  («Revisar frente a sustituir»). ChatGPT revisa; sustituir es otra operación y nunca
  se hace sobre una sesión con registros.

### 4.5 Publicar

- Solo cuando Andrés lo pide, y solo lo que se indique, cada sesión con la **versión
  que revisó**.
- Si la versión actual no coincide (alguien cambió algo después) → **no se publica**
  esa sesión y se devuelve el motivo. Nunca se publica otra versión en silencio.

### 4.6 Respuesta y formato

- Cada sesión devuelve: `id`, `clave_cliente`, fecha, momento, atletas, `version`,
  `estado` (creada · actualizada · sin cambios · conflicto · revisión propuesta) y el
  motivo si hay conflicto.
- **Bloques**: el formato actual (`etiqueta`, `solo_marcar`, `filas` con `ejercicio`,
  `detalle`, `series`, `distancia`, `ritmo`, `descanso`, `calzado`, `carga`). La
  estructura del modelo se añadirá cuando esté validada. Lo dudoso queda pendiente;
  no se inventa.
- **Modo prueba** (`simular: true`): lo valida todo y devuelve lo que haría, sin
  guardar.
- **Histórico**: todo pasa por los disparadores de la fase 1; la versión queda
  firmada como «ChatGPT (clave …)».

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

## 6. Prueba real (en este orden; cada paso se da por bueno antes del siguiente)

Siempre con un **grupo de prueba con atletas ficticios** y **sin datos de salud**:

1. **Descubrimiento y lectura**: Codex ve las herramientas del servicio y lee el
   contexto ficticio.
2. **Guardar y consultar** borradores.
3. **Repetir el mismo envío** → no duplica.
4. **Cambio concurrente**: se edita en la app un borrador y ChatGPT reenvía con la
   versión vieja → conflicto, sin sobrescribir.
5. **Revisión de una sesión publicada** → borrador vinculado, sin duplicar.
6. **Publicar** cuando Andrés lo pide, con la versión revisada; y comprobar que no
   publica si la versión cambió.

La selección de datos reales y los permisos se cierran después.

## Preguntas para Andrés

1. ¿Qué plan de ChatGPT tienes (Plus, Pro, Business…)?
2. ¿Tus conversaciones del proyecto son hilos de Codex (los que pueden ejecutar
   herramientas y dejan ficheros en tu Mac)?
3. Publicar: ChatGPT podrá hacerlo **cuando se lo pidas**, con confirmación (decidido).
4. Datos de salud: la primera prueba va sin ellos y con datos ficticios (decidido);
   lo real se decide después.
