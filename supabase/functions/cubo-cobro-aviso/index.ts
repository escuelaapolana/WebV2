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
// El correo SALE de info@ (remitente pro), pero las RESPUESTAS van a Andrés,
// que es quien las lee (info@ no lo mira nadie). Así no se pierde nada.
const RESPUESTAS_EMAIL = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const URL_BASE = (Deno.env.get("CORREO_URL_BASE") ?? "https://atletismoapolana.com/")
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

function correoHtml(nombre: string, precioMes: number, primer: number): string {
  const hola = nombre ? `¡Hola, ${nombre}!` : "¡Hola!";
  const cuotaLinea = precioMes > 0
    ? `luego, tu cuota de <b>${precioMes} €/mes</b>`
    : `luego, tu cuota mensual`;
  const enlace = `${URL_BASE}portal/`;
  // Estructura con TABLAS + bgcolor (atributo, no solo CSS): así los fondos de
  // color se ven en Gmail/Outlook y el texto blanco no queda sobre blanco.
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="520" cellpadding="0" cellspacing="0" style="max-width:520px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">El Cubo · Club Atletismo Apolana</td></tr>
      <tr><td style="padding:24px 24px 6px 24px">
        <p style="margin:0 0 14px;font-size:17px;font-weight:700;color:#26374B">${hola}</p>
        <p style="margin:0 0 14px;color:#3f3f46;line-height:1.6">¡Bienvenido/a a <b>El Cubo</b>! 💪 Ya has empezado a entrenar con nosotros, así que <b>ya puedes dejar lista tu cuota</b> y olvidarte del tema.</p>
        <p style="margin:0 0 20px;color:#3f3f46;line-height:1.6">Es muy fácil: entra en tu espacio y pulsa <b>«Pagar la cuota»</b>. Hoy solo pagas <b>${primer} €</b> (el primer pago) y tu tarjeta queda guardada; ${cuotaLinea} se cobra sola cada <b>día 5</b>, sin que tengas que hacer nada.</p>
      </td></tr>
      <tr><td align="center" style="padding:4px 24px 6px 24px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">
            <a href="${enlace}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:700;font-size:16px">Entrar y pagar mi cuota →</a>
          </td>
        </tr></table>
      </td></tr>
      <tr><td align="center" style="padding:0 24px 20px 24px">
        <p style="margin:0;color:#71717a;font-size:13px">o entra tú mismo en <a href="${enlace}" style="color:#2F6FA8">atletismoapolana.com/portal</a></p>
      </td></tr>
      <tr><td style="padding:0 24px 24px 24px;border-top:1px solid #ececec">
        <p style="margin:16px 0 0 0;color:#71717a;font-size:13px;line-height:1.5">Entra con <b>este mismo correo</b>. ¿Alguna duda? Contéstanos a este mensaje y te echamos una mano. 😊</p>
      </td></tr>
    </table>
  </td></tr></table>
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
  const rAlta = await consulta(`cubo_altas?select=nombre,perfil_id,precio_mes,primer_pago_cent&id=eq.${encodeURIComponent(altaId)}&limit=1`);
  const alta = Array.isArray(rAlta.datos) ? rAlta.datos[0] : null;
  if (!alta || !alta.perfil_id) return responder({ ok: false, motivo: "sin-perfil" }, 200, origen);
  const rP = await consulta(`perfiles?select=email,nombre&id=eq.${encodeURIComponent(String(alta.perfil_id))}&limit=1`);
  const perfil = Array.isArray(rP.datos) ? rP.datos[0] : null;
  const destino = String(perfil?.email ?? "").trim();
  if (!destino) return responder({ ok: false, motivo: "sin-correo" }, 200, origen);
  const nombre = String(alta.nombre ?? perfil?.nombre ?? "").trim().split(/\s+/)[0] ?? "";
  const precioMes = Math.round(Number(alta.precio_mes) || 0);
  const primer = (alta.primer_pago_cent != null && Number(alta.primer_pago_cent) > 0)
    ? Math.round(Number(alta.primer_pago_cent) / 100)
    : 10;
  const cuotaTxt = precioMes > 0 ? `luego, tu cuota de ${precioMes} €/mes` : "luego, tu cuota mensual";

  // 4 · Enviar por Brevo
  let resp: Response;
  try {
    resp = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS_EMAIL },
        to: [{ email: destino }],
        subject: "Ya puedes activar tu cuota de El Cubo",
        htmlContent: correoHtml(nombre, precioMes, primer),
        textContent: `${nombre ? "¡Hola, " + nombre + "!" : "¡Hola!"}\n\n¡Bienvenido/a a El Cubo! Ya puedes dejar lista tu cuota. Entra en ${URL_BASE}portal/ con este mismo correo y pulsa «Pagar la cuota»: hoy solo pagas ${primer} € (el primer pago) y tu tarjeta queda guardada; ${cuotaTxt} se cobra sola cada día 5.\n\n¿Dudas? Contesta a este mensaje y te ayudamos.`,
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
