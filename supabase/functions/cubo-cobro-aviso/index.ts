// ============================================================
// cubo-cobro-aviso · avisa por correo de que ya puede activar su cuota
// ------------------------------------------------------------
// QUÉ HACE
//   Cuando el club «abre el cobro» a una persona del Cubo, esta función
//   le manda un correo: «ya puedes activar tu cuota» con un botón a su
//   portal. El primer pago (entrada) y la cuota mensual los ve allí.
//
// LO QUE NO SE FÍA DEL NAVEGADOR
//   · Quién llama: JWT de verdad + es_admin()/es_tesoreria().
//   · A quién se escribe: el correo se lee DE LA BASE (perfil del alta),
//     nunca del cuerpo. Solo se acepta el id del alta.
//
// CLAVES (variables de entorno de Supabase)
//   BREVO_API_KEY, CORREO_REMITENTE, CORREO_REMITENTE_NOMBRE,
//   CORREO_URL_BASE, y las de Supabase. Si falta Brevo, contesta con
//   buenos modales (el cobro ya se abrió; el correo es un extra).
//
//   supabase functions deploy cubo-cobro-aviso --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";

const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const URL_BASE = (Deno.env.get("CORREO_URL_BASE") ?? "https://escuelaapolana.github.io/WebV2/")
  .replace(/\/*$/, "/");

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
async function consulta(ruta: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
  });
  const t = await r.text();
  let d: unknown = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, datos: d };
}
async function comoUsuario(rpc: string, jwt: string): Promise<boolean> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: "POST",
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
    body: "{}",
  });
  if (!r.ok) return false;
  try { return (await r.json()) === true; } catch { return false; }
}

function correoHtml(nombre: string): string {
  const hola = nombre ? `Hola, ${nombre}:` : "Hola:";
  return `<!doctype html><html lang="es"><body style="margin:0;background:#f4f4f5;padding:24px;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
    <div style="max-width:520px;margin:0 auto;background:#fff;border-radius:14px;overflow:hidden;border:1px solid #e4e4e7">
      <div style="background:#26374B;color:#fff;padding:20px 24px;font-size:18px;font-weight:700">El Cubo · Club Atletismo Apolana</div>
      <div style="padding:24px">
        <p style="margin:0 0 12px;font-size:16px;font-weight:600">${hola}</p>
        <p style="margin:0 0 16px;color:#3f3f46;line-height:1.55">Ya puedes <b>activar tu cuota de El Cubo</b>. Entra en tu portal y pulsa «Pagar la cuota»: harás el primer pago y tu tarjeta queda guardada. A partir de ahí, la cuota mensual se cobra sola cada día 5, sin que tengas que hacer nada.</p>
        <p style="margin:0 0 20px"><a href="${URL_BASE}portal/" style="display:inline-block;background:#26374B;color:#fff;text-decoration:none;padding:12px 22px;border-radius:10px;font-weight:600">Activar mi cuota</a></p>
        <p style="margin:0;color:#71717a;font-size:13px">Entra con <b>este mismo correo</b>. Si tienes cualquier duda, contesta a este mensaje y te ayudamos.</p>
      </div>
    </div>
  </body></html>`;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config" }, 503, origen);
  if (!BREVO_API_KEY) return responder({ ok: false, motivo: "sin-configurar" }, 200, origen);

  // 1 · Quién llama
  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sin_sesion" }, 401, origen);
  const rU = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` },
  });
  if (!rU.ok) return responder({ error: "sin_sesion" }, 401, origen);
  const puede = (await comoUsuario("es_admin", jwt)) || (await comoUsuario("es_tesoreria", jwt));
  if (!puede) return responder({ error: "sin_permiso" }, 403, origen);

  // 2 · Qué alta (solo se acepta el id)
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const altaId = String(cuerpo.alta_id ?? "").trim();
  if (!altaId) return responder({ error: "falta_alta" }, 400, origen);

  // 3 · El correo sale de la base (perfil del alta), no del navegador.
  const rAlta = await consulta(`cubo_altas?select=nombre,perfil_id&id=eq.${encodeURIComponent(altaId)}&limit=1`);
  const alta = Array.isArray(rAlta.datos) ? rAlta.datos[0] : null;
  if (!alta || !alta.perfil_id) return responder({ ok: false, motivo: "sin-perfil" }, 200, origen);
  const rP = await consulta(`perfiles?select=email,nombre&id=eq.${encodeURIComponent(String(alta.perfil_id))}&limit=1`);
  const perfil = Array.isArray(rP.datos) ? rP.datos[0] : null;
  const destino = String(perfil?.email ?? "").trim();
  if (!destino) return responder({ ok: false, motivo: "sin-correo" }, 200, origen);
  const nombre = String(alta.nombre ?? perfil?.nombre ?? "").trim().split(/\s+/)[0] ?? "";

  // 4 · Enviar por Brevo
  let resp: Response;
  try {
    resp = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        to: [{ email: destino }],
        subject: "Ya puedes activar tu cuota de El Cubo",
        htmlContent: correoHtml(nombre),
        textContent: `${nombre ? "Hola, " + nombre + ":" : "Hola:"}\nYa puedes activar tu cuota de El Cubo. Entra en ${URL_BASE}portal/ con este mismo correo y pulsa «Pagar la cuota». Luego se cobra sola cada día 5.`,
      }),
    });
  } catch (e) {
    return responder({ ok: false, motivo: "sin-conexion", detalle: String(e) }, 200, origen);
  }
  if (!resp.ok) {
    let datos: unknown = null; try { datos = await resp.json(); } catch { /* */ }
    return responder({ ok: false, motivo: "brevo-rechazo", estado: resp.status, brevo: datos }, 200, origen);
  }
  return responder({ ok: true, destino }, 200, origen);
});
