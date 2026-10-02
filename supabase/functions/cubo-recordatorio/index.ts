// ============================================================
// cubo-recordatorio · envía por correo (Brevo) el recordatorio de una sesión
// de FUERZA GRATIS de El Cubo a los apuntados de ese turno (viernes/sábado/
// domingo). Correo con diseño (cabecera navy, datos en negrita).
//
//   · Quién llama: JWT de verdad + es_admin() o es_cubo_lista().
//   · Destinatarios: cubo_prueba de ese turno, no cancelados, no lista de
//     espera, con correo. Se deduplican los correos repetidos.
//   · El importe/precio no entra aquí: es solo un aviso.
//
// Variables de entorno (ya están, las usa cubo-cobro-aviso):
//   BREVO_API_KEY, CORREO_REMITENTE, CORREO_REMITENTE_NOMBRE, CORREO_RESPUESTAS,
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY, CORREO_ORIGENES
//
// Deploy: supabase functions deploy cubo-recordatorio --no-verify-jwt
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
const RESPUESTAS_EMAIL = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();

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

// Datos de cada turno de fuerza gratis.
const TURNOS: Record<string, { dia: string; hora: string }> = {
  viernes: { dia: "VIERNES", hora: "18:30 a 19:30" },
  sabado:  { dia: "SÁBADO",  hora: "9:00 a 10:30" },
  domingo: { dia: "DOMINGO", hora: "9:00 a 10:30" },
};
const LUGAR = "El Cubo — Estadio de Atletismo Joaquín Villar";

function esc(s: string): string {
  return String(s ?? "").replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m] as string));
}

function correoHtml(nombre: string, dia: string, hora: string): string {
  const hola = nombre ? `¡Hola, ${esc(nombre)}!` : "¡Hola!";
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="520" cellpadding="0" cellspacing="0" style="max-width:520px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">El Cubo · Club Atletismo Apolana</td></tr>
      <tr><td style="padding:24px 24px 6px 24px">
        <p style="margin:0 0 14px;font-size:17px;font-weight:700;color:#26374B">${hola}</p>
        <p style="margin:0 0 16px;color:#3f3f46;line-height:1.6">Te recordamos tu <b>sesión de fuerza gratis</b> de El Cubo 💪</p>
      </td></tr>
      <tr><td style="padding:0 24px 8px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:12px">
          <tr><td style="padding:16px 18px;color:#26374B;font-size:16px;line-height:1.7">
            📅 <b>${esc(dia)}</b><br>
            🕒 <b>${esc(hora)}</b><br>
            📍 <b>${esc(LUGAR)}</b>
          </td></tr>
        </table>
      </td></tr>
      <tr><td style="padding:14px 24px 6px 24px">
        <p style="margin:0 0 6px;color:#3f3f46;line-height:1.6">Trae <b>ropa cómoda</b>, <b>zapatillas</b> y <b>agua</b>. ¡Nos vemos! 🙌</p>
      </td></tr>
      <tr><td style="padding:10px 24px 24px 24px;border-top:1px solid #ececec">
        <p style="margin:16px 0 0 0;color:#71717a;font-size:13px;line-height:1.5">¿No vas a poder venir? Contéstanos a este mensaje y lo apuntamos. 😊</p>
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
  if (!BREVO_API_KEY) return responder({ ok: false, motivo: "sin-configurar", mensaje: "El correo todavía no está configurado." }, 200, origen);

  // --- Quién eres ---
  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sin_sesion", mensaje: "Entra en tu cuenta." }, 401, origen);
  const puede = (await comoUsuario("es_admin", jwt)) || (await comoUsuario("es_cubo_lista", jwt));
  if (!puede) return responder({ error: "sin_permiso", mensaje: "Solo el club puede enviar recordatorios." }, 403, origen);

  // --- Qué turno ---
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const turno = String(cuerpo.turno ?? "").toLowerCase().trim();
  const info = TURNOS[turno];
  if (!info) return responder({ error: "turno", mensaje: "Turno no válido (viernes/sábado/domingo)." }, 400, origen);

  // --- A quién: apuntados de ese turno, no cancelados, no lista de espera ---
  const r = await consulta(
    `cubo_prueba?select=nombre,apellidos,email&turnos=cs.{${encodeURIComponent(turno)}}` +
    `&estado=neq.cancelado&lista_espera=eq.false&email=not.is.null`,
  );
  const filas = Array.isArray(r.datos) ? (r.datos as Array<Record<string, string>>) : [];

  // Deduplicar por correo (hay familias con el mismo correo).
  const vistos = new Set<string>();
  const destinos: Array<{ email: string; nombre: string }> = [];
  for (const f of filas) {
    const email = String(f.email ?? "").toLowerCase().trim();
    if (!email || vistos.has(email)) continue;
    vistos.add(email);
    destinos.push({ email, nombre: String(f.nombre ?? "").trim() });
  }
  if (!destinos.length) return responder({ ok: true, enviados: 0, fallidos: 0, mensaje: "No hay nadie apuntado a ese turno." }, 200, origen);

  // --- Enviar uno a uno ---
  let enviados = 0, fallidos = 0;
  for (const d of destinos) {
    try {
      const resp = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({
          sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
          replyTo: { email: RESPUESTAS_EMAIL, name: REMITENTE_NOMBRE },
          to: [{ email: d.email }],
          subject: `Recordatorio · Fuerza gratis de El Cubo — ${info.dia.toLowerCase()}`,
          htmlContent: correoHtml(d.nombre, info.dia, info.hora),
        }),
      });
      if (resp.ok) enviados++; else fallidos++;
    } catch { fallidos++; }
  }

  return responder({ ok: true, enviados, fallidos, total: destinos.length }, 200, origen);
});
