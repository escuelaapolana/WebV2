// ============================================================
// pista-prueba · lead de PRUEBA de atletismo en pista
// ------------------------------------------------------------
// El formulario público (corto) manda: nombre, teléfono, qué día quiere
// probar y, si es peque, edad + tutor. Aquí:
//   1) Anti-spam (honeypot + límite por IP).
//   2) Se guarda el lead en `pista_pruebas` (estado 'nueva').
//   3) Se avisa al club por correo (para que le escriban y lo citen).
// NO crea cuenta ni ficha: eso llega con el formulario de socio cuando
// decidan quedarse.
//
// Deploy: supabase functions deploy pista-prueba --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") ?? "";
const CORREO_REMITENTE = Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com";
const CORREO_REMITENTE_NOMBRE = Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana";
const CORREO_AVISOS = Deno.env.get("CORREO_AVISOS") ?? CORREO_REMITENTE;

const DIAS: Record<string, string> = {
  "lx": "Lunes y miércoles",
  "mj": "Martes y jueves",
  "cualquiera": "Cualquier día / me da igual",
};

const ORIGENES_OK = [
  "https://escuelaapolana.github.io",
  "https://atletismoapolana.com",
  "https://www.atletismoapolana.com",
  "http://localhost:8000",
  "http://127.0.0.1:8000",
];
function cors(origen: string | null): Record<string, string> {
  const valor = origen && ORIGENES_OK.includes(origen) ? origen : ORIGENES_OK[0];
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
type Opciones = Omit<RequestInit, "headers"> & { headers?: Record<string, string> };
async function rest(ruta: string, opciones: Opciones = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...opciones,
    headers: {
      apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json", ...(opciones.headers ?? {}),
    },
  });
  const t = await r.text();
  let d: unknown = null;
  try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, estado: r.status, datos: d };
}
function corta(v: unknown, n: number) { return String(v ?? "").trim().slice(0, n); }
function esc(s: unknown): string {
  return String(s ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
}

async function avisarClub(d: { nombre: string; telefono: string; dia: string; menor: boolean; edad: string; tutor: string; nota: string }) {
  if (!BREVO_API_KEY) return;
  const filas: string[] = [
    ["Nombre", d.nombre],
    ["Teléfono", d.telefono],
    ["Día que prefiere", d.dia || "—"],
  ];
  if (d.menor) { filas.push(["Es menor", "Sí · " + (d.edad ? d.edad + " años" : "edad sin indicar")]); filas.push(["Tutor/a", d.tutor || "—"]); }
  if (d.nota) filas.push(["Nota", d.nota]);
  const trs = filas.map(([k, v]) =>
    `<tr><td bgcolor="#F1EADC" style="padding:8px 12px;color:#6E6656;font-size:13px;width:150px">${esc(k)}</td>` +
    `<td style="padding:8px 12px;color:#26374B;font-size:15px;font-weight:600">${esc(v)}</td></tr>`).join("");
  const html = `<!doctype html><html><body style="margin:0;background:#F1EADC;padding:24px 12px;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif">
    <table role="presentation" cellpadding="0" cellspacing="0" style="max-width:520px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 12px 30px -18px rgba(38,55,75,.5)">
      <tr><td style="background:#26374B;padding:20px 28px"><span style="color:#fff;font-size:17px;font-weight:700">ATLETISMO EN PISTA · Prueba</span></td></tr>
      <tr><td style="padding:24px 28px 28px">
        <p style="margin:0 0 14px;font-size:18px;font-weight:700;color:#26374B">Nueva solicitud de prueba 🏃</p>
        <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="border-collapse:collapse;margin:0 0 18px">${trs}</table>
        <p style="margin:0;font-size:14px;line-height:1.6;color:#40484F">Escríbele para citarle un día de prueba. Lo tienes en el panel: <b>Admin › Pruebas de pista</b>.</p>
      </td></tr>
    </table></body></html>`;
  try {
    await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "Content-Type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { email: CORREO_REMITENTE, name: CORREO_REMITENTE_NOMBRE },
        to: [{ email: CORREO_AVISOS }],
        subject: `Prueba de pista · ${d.nombre}`,
        htmlContent: html,
      }),
    });
  } catch (e) { console.error("[pista-prueba] aviso:", e); }
}

Deno.serve(async (req) => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (origen && !ORIGENES_OK.includes(origen)) {
    return responder({ error: "origen", mensaje: "Origen no permitido." }, 403, origen);
  }
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config", mensaje: "El formulario no está configurado todavía." }, 503, origen);

  let b: Record<string, any> = {};
  try { b = await req.json(); } catch { /* vacío */ }

  // 0 · Anti-spam (honeypot + límite por IP)
  if (String(b.website ?? "").trim() !== "") return responder({ ok: true }, 200, origen);
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim();
  if (ip) {
    const desde = new Date(Date.now() - 15 * 60000).toISOString();
    const rRate = await rest(`rate_limit_log?select=id&accion=eq.pista-prueba&ip=eq.${encodeURIComponent(ip)}&creado_en=gt.${encodeURIComponent(desde)}`);
    const n = Array.isArray(rRate.datos) ? rRate.datos.length : 0;
    if (n >= 6) return responder({ error: "rate", mensaje: "Demasiados intentos. Prueba dentro de un rato." }, 429, origen);
    await rest("rate_limit_log", { method: "POST", body: JSON.stringify({ ip, accion: "pista-prueba" }) });
  }

  // 1 · Validar
  const nombre = corta(b.nombre, 120);
  const telefono = corta(b.telefono, 40);
  const diaCodigo = DIAS[String(b.dia)] ? String(b.dia) : "";
  const menor = b.menor === true || b.menor === "true";
  const edad = corta(b.edad, 4);
  const tutor = corta(b.tutor, 120);
  const nota = corta(b.nota, 400);

  if (!nombre) return responder({ error: "datos", mensaje: "Pon el nombre." }, 400, origen);
  if (!telefono) return responder({ error: "datos", mensaje: "Hace falta un teléfono de contacto." }, 400, origen);
  if (menor && !tutor) return responder({ error: "datos", mensaje: "Si es menor, pon el nombre del padre/madre o tutor." }, 400, origen);

  // 2 · Guardar el lead
  const rIns = await rest("pista_pruebas", {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({
      nombre, telefono,
      dia_preferido: diaCodigo ? DIAS[diaCodigo] : null,
      es_menor: menor,
      edad: edad ? Number(edad) || null : null,
      tutor: menor ? (tutor || null) : null,
      nota: nota || null,
      seccion: "pista",
      estado: "nueva",
    }),
  });
  if (!rIns.ok) {
    console.error("[pista-prueba] insert falló:", rIns.estado, rIns.datos);
    return responder({ error: "guardar", mensaje: "No hemos podido registrar tu prueba. Inténtalo de nuevo o escríbenos por WhatsApp." }, 502, origen);
  }

  // 3 · Avisar al club (extra: si falla, el lead ya está guardado)
  await avisarClub({ nombre, telefono, dia: diaCodigo ? DIAS[diaCodigo] : "", menor, edad, tutor, nota });

  return responder({ ok: true }, 200, origen);
});
