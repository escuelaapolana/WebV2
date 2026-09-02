// ============================================================
// altas-export · copia de seguridad de las altas, con los datos enteros
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   Devuelve TODAS las altas (socios, escuela y niños de la escuela)
//   con los datos ENTEROS —DNI, IBAN, tarjeta sanitaria— para poder
//   guardar una copia de respaldo. La pantalla nunca carga esos datos
//   enteros a propósito; por eso la copia se pide aquí.
//
// POR QUÉ AQUÍ Y NO EN LA PANTALLA
//   El panel enseña el DNI y la cuenta tapados, y enseñarlos de uno en
//   uno queda apuntado. Un respaldo necesita el dato entero, así que
//   se saca por esta función, que:
//     · Comprueba el JWT contra Supabase.
//     · Pregunta a la base si quien llama es de administración o
//       tesorería. Si no, no devuelve nada.
//   Es un volcado en bloque: no queda apuntado alta por alta como el
//   «enseñar entero» de la pantalla. El archivo que sale lleva datos
//   personales: hay que guardarlo en sitio seguro.
//
// CLAVES · las de Supabase, que las pone Supabase sola. Aquí no hay
//   ninguna ni puede haberla.
//
// Cómo se despliega:  supabase functions deploy altas-export
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";

function cors(origen: string | null): Record<string, string> {
  const permitidos = (Deno.env.get("CORREO_ORIGENES") ?? Deno.env.get("PAGOS_ORIGENES") ?? "")
    .split(",").map((s) => s.trim()).filter(Boolean);
  const valor = permitidos.length
    ? (origen && permitidos.includes(origen) ? origen : permitidos[0])
    : (origen ?? "*");
  return {
    "Access-Control-Allow-Origin": valor,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function responder(cuerpo: unknown, estado: number, origen: string | null): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { ...cors(origen), "Content-Type": "application/json; charset=utf-8" },
  });
}

// Leer la base con la llave de servicio (ve el dato entero).
async function consulta(ruta: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
  });
  const texto = await r.text();
  let datos: unknown = null;
  try { datos = texto ? JSON.parse(texto) : null; } catch { datos = texto; }
  return { ok: r.ok, datos: Array.isArray(datos) ? datos : [] };
}

// Preguntar a la base COMO EL USUARIO (con su JWT) si tiene un papel.
async function comoUsuario(rpc: string, jwt: string): Promise<boolean> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: "POST",
    headers: {
      apikey: ANON_KEY || SERVICE_KEY,
      Authorization: `Bearer ${jwt}`,
      "Content-Type": "application/json",
    },
    body: "{}",
  });
  if (!r.ok) return false;
  try { return (await r.json()) === true; } catch { return false; }
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ ok: false, motivo: "config" }, 503, origen);
  }

  // 1 · ¿Quién eres? JWT de verdad, contra Supabase.
  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  if (!jwt) return responder({ ok: false, motivo: "sin-sesion" }, 401, origen);

  const rUsuario = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` },
  });
  if (!rUsuario.ok) return responder({ ok: false, motivo: "sin-sesion" }, 401, origen);

  // 1.b · ¿Puede? Administración o tesorería, como en las altas.
  const puede = (await comoUsuario("es_admin", jwt)) || (await comoUsuario("es_tesoreria", jwt));
  if (!puede) return responder({ ok: false, motivo: "sin-permiso" }, 403, origen);

  // 2 · Volcado entero de las tres tablas (la llave de servicio ve el dato real).
  const [socios, escuela, ninos] = await Promise.all([
    consulta("altas_socio?select=*&order=created_at.desc"),
    consulta("altas_escuela?select=*&order=created_at.desc"),
    consulta("altas_escuela_ninos?select=*&order=orden.asc"),
  ]);

  if (!socios.ok && !escuela.ok && !ninos.ok) {
    return responder({ ok: false, motivo: "sin-lectura" }, 502, origen);
  }

  return responder({
    ok: true,
    socios: socios.datos,
    escuela: escuela.datos,
    ninos: ninos.datos,
  }, 200, origen);
});
