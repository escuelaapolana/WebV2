// ============================================================
// entreno-enlace · envía por correo el enlace para DOMICILIAR (SEPA) la cuota
// de entrenamiento. Explica que el correo anterior (pagar con tarjeta) fue un
// error y que la forma correcta es la domiciliación.
//
//   · POST con JWT de admin/staff/tesorería.
//   · body { cuota_id }  → manda el correo al atleta de esa cuota de entreno.
//
//   Variables (ya existen, las usa cubo-cobro-aviso / recibo-aviso):
//     BREVO_API_KEY, CORREO_REMITENTE, CORREO_REMITENTE_NOMBRE, CORREO_RESPUESTAS,
//     SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY, CORREO_ORIGENES
//   supabase functions deploy entreno-enlace --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const RESPUESTAS_EMAIL = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const URL_BASE = (Deno.env.get("PAGOS_URL_BASE") ?? "https://atletismoapolana.com/").replace(/\/*$/, "/");

function cors(origen: string | null): Record<string, string> {
  const permitidos = (Deno.env.get("CORREO_ORIGENES") ?? Deno.env.get("PAGOS_ORIGENES") ?? "")
    .split(",").map((s) => s.trim()).filter(Boolean);
  const valor = permitidos.length ? (origen && permitidos.includes(origen) ? origen : permitidos[0]) : (origen ?? "*");
  return {
    "Access-Control-Allow-Origin": valor,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}
function responder(cuerpo: unknown, estado: number, origen: string | null): Response {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...cors(origen), "Content-Type": "application/json; charset=utf-8" } });
}
async function consulta(ruta: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
  });
  const t = await r.text(); let d: unknown = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, datos: d };
}
async function comoUsuario(rpc: string, jwt: string): Promise<boolean> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: "POST", headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" }, body: "{}",
  });
  if (!r.ok) return false; try { return (await r.json()) === true; } catch { return false; }
}
function esc(s: string): string { return String(s ?? "").replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m] as string)); }
const eur = (n: number) => (Number(n) || 0).toLocaleString("es-ES", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + " €";

function correoHtml(nombre: string, importe: number, enlace: string): string {
  const hola = nombre ? `¡Hola, ${esc(nombre)}!` : "¡Hola!";
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana</td></tr>
      <tr><td style="padding:24px 24px 6px 24px">
        <p style="margin:0 0 14px;font-size:17px;font-weight:700;color:#26374B">${hola}</p>
        <p style="margin:0 0 12px;color:#3f3f46;line-height:1.6">Perdona por el lío: el correo anterior te pedía pagar la cuota de entrenamiento <b>con tarjeta</b>, y fue un <b>error nuestro</b>. <b>Ignóralo</b> — no tienes que pagar nada por ahí.</p>
        <p style="margin:0 0 14px;color:#3f3f46;line-height:1.6">La forma correcta, y más cómoda, es por <b>domiciliación bancaria (SEPA)</b>: metes tu IBAN <b>una sola vez</b> y la cuota se cobra sola cada trimestre.</p>
      </td></tr>
      <tr><td style="padding:2px 24px 10px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:14px 18px;color:#5C4A1E;font-size:15px;line-height:1.7">
            <b>Cuota de entrenamiento</b><br>
            <span style="font-size:20px;font-weight:700">${eur(importe)}</span> cada trimestre<br>
            <span style="font-size:13.5px">Se cobra ahora (octubre), en enero y en abril. <b>Tras abril se para solo</b>: en junio no se te pasa nada.</span>
          </td></tr>
        </table></td></tr>
      <tr><td align="center" style="padding:6px 24px 6px 24px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">
            <a href="${enlace}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:700;font-size:16px">Domiciliar mi cuota →</a>
          </td>
        </tr></table></td></tr>
      <tr><td align="center" style="padding:0 24px 18px 24px">
        <p style="margin:0;color:#71717a;font-size:13px">El IBAN se teclea en la pantalla segura de Stripe, nunca en nuestra web.</p>
      </td></tr>
      <tr><td style="padding:0 24px 24px 24px;border-top:1px solid #ececec">
        <p style="margin:16px 0 0 0;color:#71717a;font-size:13px;line-height:1.5">¿Alguna duda? Contéstanos a este mensaje. 😊</p>
      </td></tr>
    </table>
  </td></tr></table>
  </body></html>`;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config" }, 503, origen);
  if (!BREVO_API_KEY) return responder({ ok: false, motivo: "sin-configurar" }, 200, origen);

  const cab = req.headers.get("Authorization") ?? "";
  const jwt = cab.toLowerCase().startsWith("bearer ") ? cab.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sin_sesion" }, 401, origen);
  const puede = (await comoUsuario("es_admin", jwt)) || (await comoUsuario("es_staff", jwt)) || (await comoUsuario("puede_girar", jwt));
  if (!puede) return responder({ error: "sin_permiso" }, 403, origen);

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const cuotaId = String(cuerpo.cuota_id ?? "").trim();
  if (!cuotaId) return responder({ error: "falta_cuota" }, 400, origen);

  const rC = await consulta(`cuotas_entreno?select=nombre,email,importe_cent,token&id=eq.${encodeURIComponent(cuotaId)}&limit=1`);
  const c = Array.isArray(rC.datos) ? rC.datos[0] as { nombre: string; email: string; importe_cent: number; token: string } : null;
  if (!c) return responder({ ok: false, motivo: "no-existe" }, 200, origen);
  const destino = String(c.email ?? "").trim();
  if (!destino) return responder({ ok: false, motivo: "sin-correo" }, 200, origen);

  const nombre = String(c.nombre ?? "").trim().split(/\s+/)[0] ?? "";
  const importe = (Number(c.importe_cent) || 0) / 100;
  const enlace = `${URL_BASE}entreno/cuota/?t=${encodeURIComponent(c.token)}`;

  try {
    const resp = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS_EMAIL },
        to: [{ email: destino }],
        subject: "Domicilia tu cuota de entrenamiento (ignora el correo anterior)",
        htmlContent: correoHtml(nombre, importe, enlace),
        textContent: `${nombre ? "¡Hola, " + nombre + "!" : "¡Hola!"}\n\nPerdona: el correo anterior pedía pagar con tarjeta y fue un error. Ignóralo.\n\nLa forma correcta es por domiciliación (SEPA): metes tu IBAN una vez y la cuota (${eur(importe)} por trimestre) se cobra sola en octubre, enero y abril. Tras abril se para solo.\n\nDomicilia tu cuota aquí: ${enlace}\n\n¿Dudas? Contesta a este mensaje.`,
      }),
    });
    const ok = resp.ok;
    return responder({ ok, destino: ok ? destino : undefined }, 200, origen);
  } catch (e) {
    return responder({ ok: false, motivo: String((e as Error).message || e) }, 200, origen);
  }
});
