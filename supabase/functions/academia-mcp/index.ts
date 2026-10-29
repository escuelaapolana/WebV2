// ============================================================
// academia-mcp · servidor MCP de Academia para ChatGPT (Codex en la app de
// ChatGPT para Mac). Mig 464 (28-oct-2026, solo PRUEBA) y mig 499 (29-oct-2026):
//
//   · Grupos: los de prueba de la clave y los REALES habilitados uno a uno en
//     academia_api_habilitados (hoy solo Academia AC98: leer, borradores,
//     revisiones y publicar). Los permisos se comprueban por grupo en la base.
//   · Grupo real: publicar en dos pasos (preparar_publicacion → código atado a
//     versión y huella; publicar con el código y la autorización literal de
//     Andrés). No hay operaciones de borrar sesiones ni de tocar feedback.
//     Sin datos de salud en las lecturas.
//   · Transporte «Streamable HTTP» de MCP, sin estado, respondiendo JSON
//     (no abre flujos SSE). Autenticación: «Authorization: Bearer <clave>».
//     De la clave solo se usa su sha256; la base la busca en api_claves.
//   · Toda la lógica (permisos, idempotencia, versiones, huellas) está en la
//     base: public.academia_api(hash, operación, args), que solo puede
//     ejecutar service_role.
//
//   En la app de ChatGPT se conecta con el puente local
//   herramientas/academia-mcp-puente.py (lee la clave del Llavero del Mac).
//   supabase functions deploy academia-mcp --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const VERSION = "2026-10-29";
const PROTOCOLOS = ["2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25"];

const INSTRUCCIONES = [
  "Servidor de la Academia AC98 del Club Atletismo Apolana. Grupos: Academia AC98 (REAL: sus atletas ven lo que se publique) y Academia AC98 · PRUEBA (datos ficticios).",
  "Empieza con «estado» para ver los grupos, los permisos de cada uno y las reglas.",
  "Guarda borradores solo cuando el usuario lo pida expresamente; esa petición es la autorización (no hace falta una segunda confirmación).",
  "Cada sesión nueva lleva una clave_cliente estable; cada petición de escritura, un envio_id nuevo (reutilízalo solo para reintentar exactamente lo mismo).",
  "Para cambiar un borrador manda sesion_id y version_base. Si hay conflicto de versión, vuelve a leer y enséñale al usuario qué cambió.",
  "Una sesión publicada no se cambia: se propone una revisión, que el entrenador aplica o descarta en el panel.",
  "Grupo de PRUEBA: publicar_prueba solo si el usuario lo pide, con la version y la huella exactas que revisó.",
  "Grupo REAL: nunca publiques sin autorización expresa de Andrés. Primero preparar_publicacion (no publica: da un resumen y un código); enséñale el resumen y pídele que autorice escribiendo el código; después publicar con ese código y sus palabras literales.",
  "Nunca se borran sesiones ni se toca el feedback de los atletas: esta conexión no puede hacerlo.",
  "No inventes la clasificación de una sesión ni calcules volúmenes o cargas: eso aún no está definido.",
].join("\n");

const BLOQUES = {
  type: "array",
  description: "Bloques de la sesión en orden. Cada fila, una línea tal como la escribe el entrenador (series, ritmos, recuperación // y calzado Z/C).",
  items: {
    type: "object",
    properties: {
      etiqueta: { type: "string", description: "Calentamiento, Parte principal, Vuelta a la calma…" },
      filas: { type: "array", items: { type: "string" } },
      nota: { type: "string", description: "Nota del bloque que ve el atleta (opcional)." },
    },
    required: ["etiqueta", "filas"],
  },
};
const EXIGENCIA = {
  type: "object",
  description: "Exigencia PREVISTA (no es RPE).",
  properties: {
    global: { type: "string", enum: ["baja", "media", "alta"] },
    neuromuscular: { type: "string", enum: ["baja", "media", "alta"] },
    metabolica: { type: "string", enum: ["baja", "media", "alta"] },
  },
};
const CAMPOS_SESION = {
  titulo: { type: "string", description: "Título breve de la sesión." },
  objetivo: { type: "string", description: "Objetivo breve (máx. 80), p. ej. «Ritmo 400». No inventar clasificaciones." },
  exigencia: EXIGENCIA,
  tipo_dia: { type: "string", enum: ["entreno", "descanso"] },
  momento: { type: "string", enum: ["unica", "manana", "tarde", "sin_especificar"], description: "Si ese día hay una sola sesión, «unica» (o no lo envíes: es el valor por defecto). Solo con dos sesiones el mismo día: «manana» / «tarde»; «sin_especificar» solo si hay dos y no se sabe cuál es cuál." },
  hora: { type: "string", description: "HH:MM (opcional)." },
  duracion_min: { type: "integer" },
  bloques: BLOQUES,
  instrucciones_atleta: { type: "string", description: "Instrucciones para el atleta: las LEE en su app, debajo del entrenamiento." },
  nota_entrenador: { type: "string", description: "Nota privada del entrenador: solo la ven los entrenadores, nunca el atleta. '' la quita. No cambia la versión de la sesión." },
};

const HERRAMIENTAS = [
  {
    name: "estado", op: "estado",
    description: "Comprueba la conexión: clave en uso, grupos permitidos (real o de prueba, «datos_ficticios»), permisos de cada grupo y reglas de uso.",
    inputSchema: { type: "object", properties: {} },
    annotations: { title: "Estado de la conexión", readOnlyHint: true, openWorldHint: false },
  },
  {
    name: "leer_semana", op: "leer_semana",
    description: "Lee una semana del grupo: atletas (con su modo de seguimiento) y sesiones con versión, huella, plan por bloques, publicación, revisión pendiente y registros resumidos. Sin datos de salud.",
    inputSchema: {
      type: "object",
      properties: {
        fecha: { type: "string", description: "Cualquier día de la semana (YYYY-MM-DD). Por defecto, hoy." },
        grupo_id: { type: "string", description: "Grupo (mira «estado»): Academia AC98 es el REAL; el de PRUEBA tiene datos ficticios. Obligatorio si hay más de un grupo." },
      },
    },
    annotations: { title: "Leer la semana", readOnlyHint: true, openWorldHint: false },
  },
  {
    name: "leer_sesion", op: "leer_sesion",
    description: "Lee una sesión con su historial de versiones (con huella de cada una) y sus revisiones.",
    inputSchema: { type: "object", properties: { sesion_id: { type: "string" } }, required: ["sesion_id"] },
    annotations: { title: "Leer una sesión", readOnlyHint: true, openWorldHint: false },
  },
  {
    name: "consultar_borradores", op: "consultar_borradores",
    description: "Lista los borradores (sin publicar) del grupo entre dos fechas, con versión, huella y su clave_cliente si los creó esta conexión.",
    inputSchema: {
      type: "object",
      properties: {
        desde: { type: "string", description: "YYYY-MM-DD (por defecto, hace 7 días)." },
        hasta: { type: "string", description: "YYYY-MM-DD (por defecto, dentro de 4 semanas)." },
        grupo_id: { type: "string", description: "Obligatorio si hay más de un grupo (mira «estado»)." },
      },
    },
    annotations: { title: "Consultar borradores", readOnlyHint: true, openWorldHint: false },
  },
  {
    name: "guardar_borradores", op: "guardar_borradores",
    description:
      "Úsala solo cuando el usuario pida expresamente guardar. Crea o cambia BORRADORES (los atletas no los ven). " +
      "Sesión nueva: clave_cliente estable + atleta_id + fecha + titulo + bloques. Cambiar un borrador: sesion_id (o la misma clave_cliente) + version_base leída. " +
      "Reenviar lo mismo no duplica nada. Si algo choca (versión distinta, sesión publicada, otra fecha u otro atleta), no se guarda nada y se devuelven los conflictos. " +
      "Una sesión publicada se cambia con proponer_revision; moverla de día o de atleta es sustituir: sesión nueva.",
    inputSchema: {
      type: "object",
      properties: {
        envio_id: { type: "string", description: "Único por petición. Repetirlo con el mismo contenido no repite nada." },
        sesiones: {
          type: "array",
          maxItems: 60,
          items: {
            type: "object",
            properties: {
              clave_cliente: { type: "string", description: "Identificador estable que pones tú a cada sesión nueva (p. ej. «alex-2026-11-02»)." },
              sesion_id: { type: "string", description: "Para cambiar un borrador existente." },
              version_base: { type: "integer", description: "La versión que leíste del borrador que cambias." },
              grupo_id: { type: "string", description: "Grupo de la sesión nueva (obligatorio si hay más de uno: mira «estado»)." },
              atleta_id: { type: "string" },
              fecha: { type: "string", description: "YYYY-MM-DD" },
              ...CAMPOS_SESION,
            },
          },
        },
      },
      required: ["envio_id", "sesiones"],
    },
    annotations: { title: "Guardar borradores", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  {
    name: "proponer_revision", op: "proponer_revision",
    description:
      "Propone un cambio a una sesión PUBLICADA sin tocarla: queda como revisión pendiente para que el entrenador la aplique (versión nueva de la misma sesión) o la descarte en el panel. " +
      "Necesita version_base (la versión leída); si la sesión cambió, devuelve conflicto.",
    inputSchema: {
      type: "object",
      properties: {
        envio_id: { type: "string" },
        sesion_id: { type: "string" },
        version_base: { type: "integer" },
        cambios: { type: "object", properties: CAMPOS_SESION, description: "Solo los campos que cambian (bloques, si cambian, completos)." },
        motivo: { type: "string", description: "Por qué se propone (máx. 300)." },
      },
      required: ["envio_id", "sesion_id", "version_base", "cambios"],
    },
    annotations: { title: "Proponer una revisión", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  {
    name: "publicar_prueba", op: "publicar_prueba",
    description:
      "Solo si el usuario lo pide expresamente, después de revisar. Publica borradores del grupo de PRUEBA exactamente en la version y huella revisadas; " +
      "si cualquiera cambió, no publica nada. Devuelve la versión publicada y comprueba que su huella coincide con la revisada.",
    inputSchema: {
      type: "object",
      properties: {
        envio_id: { type: "string" },
        sesiones: {
          type: "array",
          items: {
            type: "object",
            properties: { sesion_id: { type: "string" }, version: { type: "integer" }, huella: { type: "string" } },
            required: ["sesion_id", "version", "huella"],
          },
        },
      },
      required: ["envio_id", "sesiones"],
    },
    annotations: { title: "Publicar (solo prueba)", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  {
    name: "preparar_publicacion", op: "preparar_publicacion",
    description:
      "Grupo REAL (Academia AC98). NO publica nada: comprueba que cada borrador está exactamente en la version y huella revisadas y devuelve un resumen " +
      "(fecha, atleta, título, versión) y un código de autorización que caduca en 30 minutos. Enséñale el resumen a Andrés y pídele que autorice escribiendo ese código. " +
      "Si cambias algo después, el código deja de valer: prepara otra vez.",
    inputSchema: {
      type: "object",
      properties: {
        sesiones: {
          type: "array",
          items: {
            type: "object",
            properties: { sesion_id: { type: "string" }, version: { type: "integer" }, huella: { type: "string" } },
            required: ["sesion_id", "version", "huella"],
          },
        },
      },
      required: ["sesiones"],
    },
    annotations: { title: "Preparar una publicación (grupo real)", readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false },
  },
  {
    name: "publicar", op: "publicar",
    description:
      "Grupo REAL. Úsala SOLO después de que Andrés autorice expresamente la publicación escribiendo el código que dio preparar_publicacion. " +
      "Publica exactamente las sesiones, versiones y huellas de ese código (no las que mandes ahora); si algo cambió, no publica nada. " +
      "autorizacion_texto = las palabras literales de Andrés (tienen que incluir el código). Queda registrado. Los atletas lo ven al momento.",
    inputSchema: {
      type: "object",
      properties: {
        envio_id: { type: "string" },
        codigo: { type: "string", description: "El código de 6 caracteres de preparar_publicacion." },
        autorizacion_texto: { type: "string", description: "Las palabras literales de Andrés autorizando, con el código." },
      },
      required: ["envio_id", "codigo", "autorizacion_texto"],
    },
    annotations: { title: "Publicar con autorización (grupo real)", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
];

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, accept, mcp-protocol-version, mcp-session-id",
};

function json(cuerpo: unknown, status = 200, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(cuerpo), { status, headers: { "Content-Type": "application/json; charset=utf-8", ...CORS, ...extra } });
}

async function sha256hex(s: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function api(hash: string, op: string, args: unknown): Promise<Record<string, unknown>> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/academia_api`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ p_hash: hash, p_operacion: op, p_args: args ?? {} }),
  });
  if (!r.ok) throw new Error(`La base respondió ${r.status}`);
  return await r.json();
}

type Mensaje = { jsonrpc?: string; id?: string | number | null; method?: string; params?: Record<string, unknown> };

async function atender(m: Mensaje, hash: string): Promise<Record<string, unknown> | null> {
  const id = m.id;
  if (id === undefined || id === null) return null;   // notificación: no se responde
  const ok = (result: unknown) => ({ jsonrpc: "2.0", id, result });
  const fallo = (code: number, message: string) => ({ jsonrpc: "2.0", id, error: { code, message } });
  switch (m.method) {
    case "initialize": {
      const pedido = String((m.params ?? {}).protocolVersion ?? "");
      return ok({
        protocolVersion: PROTOCOLOS.includes(pedido) ? pedido : "2025-06-18",
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "apolana-academia", title: "Academia AC98 · Apolana", version: VERSION },
        instructions: INSTRUCCIONES,
      });
    }
    case "ping":
      return ok({});
    case "tools/list":
      return ok({ tools: HERRAMIENTAS.map(({ op: _op, ...t }) => t) });
    case "tools/call": {
      const nombre = String((m.params ?? {}).name ?? "");
      const h = HERRAMIENTAS.find((t) => t.name === nombre);
      if (!h) return fallo(-32602, `Herramienta desconocida: ${nombre}`);
      try {
        const res = await api(hash, h.op, (m.params ?? {}).arguments ?? {});
        return ok({
          content: [{ type: "text", text: JSON.stringify(res, null, 2) }],
          structuredContent: res,
          isError: res.ok !== true,
        });
      } catch (e) {
        return ok({ content: [{ type: "text", text: `No se pudo completar: ${(e as Error).message}` }], isError: true });
      }
    }
    default:
      return fallo(-32601, `Método no disponible: ${m.method}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return json({ error: "Usa POST (MCP Streamable HTTP, sin flujo SSE)." }, 405, { Allow: "POST, OPTIONS" });

  const auth = req.headers.get("authorization") ?? "";
  const clave = auth.toLowerCase().startsWith("bearer ") ? auth.slice(7).trim() : "";
  if (!clave) return json({ jsonrpc: "2.0", id: null, error: { code: -32001, message: "Falta la clave (Authorization: Bearer …)." } }, 401, { "WWW-Authenticate": "Bearer" });
  const hash = await sha256hex(clave);

  const texto = await req.text();
  if (texto.length > 512 * 1024) return json({ jsonrpc: "2.0", id: null, error: { code: -32600, message: "Petición demasiado grande." } }, 413);
  let cuerpo: Mensaje | Mensaje[];
  try { cuerpo = JSON.parse(texto); } catch { return json({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "JSON no válido." } }, 400); }

  const lista = Array.isArray(cuerpo) ? cuerpo : [cuerpo];
  // Al iniciar se comprueba la clave: con una clave mala no se llega a listar nada.
  if (lista.some((m) => m && m.method === "initialize")) {
    const est = await api(hash, "estado", {}).catch(() => ({ ok: false }));
    if (est.ok !== true) return json({ jsonrpc: "2.0", id: null, error: { code: -32001, message: "La clave no es válida o está revocada." } }, 401, { "WWW-Authenticate": "Bearer" });
  }
  const respuestas = (await Promise.all(lista.map((m) => atender(m, hash)))).filter((r) => r !== null);
  if (!respuestas.length) return new Response(null, { status: 202, headers: CORS });
  return json(Array.isArray(cuerpo) ? respuestas : respuestas[0]);
});
