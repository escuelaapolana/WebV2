// ============================================================
// correo-natacion-horarios · envía a la FAMILIA los horarios de natación
// ------------------------------------------------------------
// QUÉ HACE
//   Desde el panel, el club pulsa «Enviar horarios» de un nadador. Esta función
//   comprueba que quien llama es del club (admin/entrenador/responsable), lee de
//   la base los horarios de ese nadador (sus franjas de natación) + su código de
//   acceso, y manda un correo a la familia (email del tutor, o el suyo) con los
//   horarios y el enlace directo a «mi plaza». El destinatario y los datos salen
//   de la BASE por el código; el navegador solo dice de qué nadador se trata.
//
// CLAVES (variables de entorno de Supabase; ninguna vive aquí):
//   BREVO_API_KEY, CORREO_REMITENTE, CORREO_REMITENTE_NOMBRE, CORREO_URL_BASE
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / SUPABASE_ANON_KEY
//
// Deploy (SÍ verifica JWT: quien llama es una persona con sesión del panel):
//   supabase functions deploy correo-natacion-horarios --project-ref icaxokjsvhlreuwpyxeb
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
const URL_BASE = (Deno.env.get("CORREO_URL_BASE") ?? "https://atletismoapolana.com").replace(/\/+$/, "");

const DIAS = ["", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];

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
function esc(v: unknown): string {
  return String(v ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
}
async function rest(ruta: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  });
  const t = await r.text();
  try { return { ok: r.ok, datos: t ? JSON.parse(t) : null }; } catch { return { ok: r.ok, datos: t }; }
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config" }, 503, origen);
  if (!BREVO_API_KEY) return responder({ error: "sin_correo", mensaje: "El correo no está configurado." }, 503, origen);

  // --- 1 · Quién llama: tiene que ser del club ---
  const cab = req.headers.get("Authorization") ?? "";
  const jwt = cab.toLowerCase().startsWith("bearer ") ? cab.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sesion" }, 401, origen);
  const rU = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` } });
  if (!rU.ok) return responder({ error: "sesion" }, 401, origen);
  const correoQuien: string = ((await rU.json().catch(() => null))?.email ?? "").toLowerCase();
  if (!correoQuien) return responder({ error: "sesion" }, 401, origen);
  const rP = await rest(`perfiles?select=rol,rol_activo,roles&email=eq.${encodeURIComponent(correoQuien)}&limit=1`);
  const p = Array.isArray(rP.datos) ? rP.datos[0] : null;
  const roles: string[] = [p?.rol, p?.rol_activo, ...(Array.isArray(p?.roles) ? p.roles : [])].filter(Boolean);
  const permitido = roles.some((r) => ["admin", "tesoreria", "contabilidad", "junta", "coordinador", "entrenador", "responsable"].includes(r));
  if (!permitido) return responder({ error: "no_permiso", mensaje: "Solo el club puede enviar horarios." }, 403, origen);

  // --- 2 · Qué nadador: por código (del panel) o por atleta_id ---
  let cuerpo: { codigo?: string; atleta_id?: string } = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const codigo = String(cuerpo.codigo ?? "").trim().toUpperCase();
  let atletaId = String(cuerpo.atleta_id ?? "").trim();

  if (!atletaId && codigo) {
    const rAc = await rest(`natacion_accesos?select=atleta_id&codigo=eq.${encodeURIComponent(codigo)}&limit=1`);
    atletaId = (Array.isArray(rAc.datos) && rAc.datos[0]?.atleta_id) ? rAc.datos[0].atleta_id : "";
  }
  if (!atletaId) return responder({ error: "sin_nadador", mensaje: "No encuentro a ese nadador." }, 404, origen);

  // --- 3 · Datos del nadador: nombre, correos, código y horarios ---
  const rAt = await rest(`atletas?select=nombre,apellidos,email,email_tutor,nombre_tutor&id=eq.${encodeURIComponent(atletaId)}&limit=1`);
  const at = Array.isArray(rAt.datos) ? rAt.datos[0] : null;
  if (!at) return responder({ error: "sin_nadador" }, 404, origen);
  const destino: string = (at.email_tutor || at.email || "").trim();
  if (!destino) return responder({ error: "sin_correo_familia", mensaje: "Ese nadador no tiene correo de familia guardado." }, 409, origen);

  const rCod = await rest(`natacion_accesos?select=codigo&atleta_id=eq.${encodeURIComponent(atletaId)}&activo=eq.true&limit=1`);
  const cod: string = (Array.isArray(rCod.datos) && rCod.datos[0]?.codigo) ? rCod.datos[0].codigo : codigo;

  // Horarios (franjas activas de ese nadador), ordenados por día y hora.
  const rIns = await rest(`natacion_inscripciones?select=calle,nivel,franja_id&atleta_id=eq.${encodeURIComponent(atletaId)}&activa=eq.true`);
  const inscr: Array<{ calle: string; nivel: string; franja_id: string }> = Array.isArray(rIns.datos) ? rIns.datos : [];
  const franjaIds = [...new Set(inscr.map((i) => i.franja_id).filter(Boolean))];
  const franjas: Record<string, { dia: number; hora: string }> = {};
  if (franjaIds.length) {
    const rF = await rest(`natacion_franjas?select=id,dia,hora&id=in.(${franjaIds.map((x) => `"${x}"`).join(",")})`);
    (Array.isArray(rF.datos) ? rF.datos : []).forEach((f: { id: string; dia: number; hora: string }) => {
      franjas[f.id] = { dia: f.dia, hora: String(f.hora).slice(0, 5) };
    });
  }
  // Una línea por (día+hora+calle+nivel), sin repetir, ordenadas.
  const vistas = new Set<string>();
  const lineas = inscr.map((i) => {
    const f = franjas[i.franja_id];
    if (!f) return null;
    const k = `${f.dia}|${f.hora}|${i.calle}|${i.nivel}`;
    if (vistas.has(k)) return null; vistas.add(k);
    return { dia: f.dia, hora: f.hora, calle: i.calle, nivel: i.nivel };
  }).filter(Boolean) as Array<{ dia: number; hora: string; calle: string; nivel: string }>;
  lineas.sort((a, b) => (a.dia - b.dia) || a.hora.localeCompare(b.hora));

  if (!lineas.length) return responder({ error: "sin_horarios", mensaje: "Ese nadador no tiene horarios activos." }, 409, origen);

  const nombre = `${at.nombre ?? ""} ${at.apellidos ?? ""}`.trim();
  const enlace = cod ? `${URL_BASE}/natacion/mi-plaza/?c=${encodeURIComponent(cod)}` : "";
  const filas = lineas.map((l) =>
    `<tr><td style="padding:8px 12px;border-bottom:1px solid #EDE6D7;color:#26374B;white-space:nowrap"><b>${esc(DIAS[l.dia] || "")} ${esc(l.hora)}</b></td>` +
    `<td style="padding:8px 12px;border-bottom:1px solid #EDE6D7;color:#40484F">${esc([l.calle ? "Calle " + l.calle : "", l.nivel].filter(Boolean).join(" · "))}</td></tr>`).join("");

  const html = `<!doctype html><html lang="es"><body style="margin:0;background:#eef3f0;padding:24px 12px;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif">
    <table role="presentation" cellpadding="0" cellspacing="0" style="max-width:520px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 12px 30px -18px rgba(11,93,59,.4)">
      <tr><td style="background:#2E8C86;padding:20px 28px"><span style="color:#fff;font-size:17px;font-weight:700">Club Atletismo Apolana · Natación</span></td></tr>
      <tr><td style="padding:24px 28px 28px">
        <p style="margin:0 0 6px;font-size:19px;font-weight:700;color:#26374B">Horarios de natación${nombre ? " de " + esc(nombre) : ""}</p>
        <p style="margin:0 0 16px;font-size:15px;line-height:1.6;color:#40484F">Estos son los horarios de piscina:</p>
        <table style="border-collapse:collapse;width:100%;font-size:14.5px;margin:0 0 18px">${filas}</table>
        ${enlace ? `<p style="margin:0 0 10px;font-size:14.5px;line-height:1.6;color:#40484F">Puedes verlos, consultar faltas y avisos en este enlace (sin contraseña):</p>
        <a href="${esc(enlace)}" style="display:inline-block;background:#2E8C86;color:#fff;text-decoration:none;font-weight:600;font-size:15px;padding:12px 22px;border-radius:11px">Ver la plaza de natación</a>` : ""}
        <p style="margin:22px 0 0;font-size:13px;color:#6E6656;line-height:1.6">Un saludo,<br>Club Atletismo Apolana</p>
      </td></tr>
    </table>
  </body></html>`;

  const texto = `Horarios de natación${nombre ? " de " + nombre : ""}:\n` +
    lineas.map((l) => `- ${DIAS[l.dia] || ""} ${l.hora} · ${[l.calle ? "Calle " + l.calle : "", l.nivel].filter(Boolean).join(" · ")}`).join("\n") +
    (enlace ? `\n\nVer la plaza: ${enlace}` : "");

  // --- 4 · Enviar por Brevo ---
  let resp: Response;
  try {
    resp = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        to: [{ email: destino, name: (at.nombre_tutor || nombre || undefined) }],
        subject: `Horarios de natación${nombre ? " de " + nombre : ""}`,
        htmlContent: html,
        textContent: texto,
      }),
    });
  } catch (e) {
    return responder({ error: "sin_conexion", detalle: String(e) }, 502, origen);
  }
  if (!resp.ok) {
    let d: unknown = null; try { d = await resp.json(); } catch { /* */ }
    return responder({ error: "brevo", estado: resp.status, brevo: d }, 502, origen);
  }
  // No devolvemos el correo entero por privacidad; solo confirmamos + una pista.
  const pista = destino.replace(/^(.).*(@.*)$/, "$1***$2");
  return responder({ ok: true, enviado_a: pista, horarios: lineas.length }, 200, origen);
});
