// ============================================================
// correo-alta-aviso · aviso a ADMINISTRACIÓN cuando entra un alta de socio
// ------------------------------------------------------------
// QUÉ HACE
//   Cuando alguien termina el formulario de "hacerte socio", el front
//   llama aquí con la REFERENCIA del alta (SOC-...). Esta función lee el
//   alta de la base (con la llave de servicio, no se fía del navegador),
//   arma un correo con todos los datos + enlaces firmados a las fotos del
//   DNI, y lo manda a administración. Marca el alta como avisada para no
//   mandar el correo dos veces.
//
// SEGURIDAD
//   · Es pública (la rellena gente sin sesión), pero SOLO escribe a la
//     dirección fija de administración (env CORREO_ADMIN). Nadie elige el
//     destinatario.
//   · Los datos y las fotos se leen de la base por la referencia; el
//     navegador solo dice qué alta.
//   · Idempotente: si el alta ya se avisó, no repite.
//
// CLAVES (las pone Supabase, ninguna vive aquí):
//   BREVO_API_KEY, CORREO_REMITENTE, CORREO_REMITENTE_NOMBRE, CORREO_ADMIN
//
// Deploy: supabase functions deploy correo-alta-aviso --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";

const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const CORREO_ADMIN = (Deno.env.get("CORREO_ADMIN") ?? "administracion@atletismoapolana.com").trim();
const BUCKET = "altas-documentos";

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

async function rest(metodo: string, ruta: string, cuerpo?: unknown, extra?: Record<string, string>) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    method: metodo,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(extra ?? {}),
    },
    body: cuerpo !== undefined ? JSON.stringify(cuerpo) : undefined,
  });
  const texto = await r.text();
  let datos: unknown = null;
  try { datos = texto ? JSON.parse(texto) : null; } catch { datos = texto; }
  return { ok: r.ok, datos };
}

// Enlace firmado (30 días) a un documento privado. Devuelve URL completa o null.
async function enlaceFirmado(ruta: string | null): Promise<string | null> {
  if (!ruta) return null;
  try {
    const r = await fetch(`${SUPABASE_URL}/storage/v1/object/sign/${BUCKET}/${ruta}`, {
      method: "POST",
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ expiresIn: 2592000 }),
    });
    if (!r.ok) return null;
    const d = await r.json();
    return d && d.signedURL ? `${SUPABASE_URL}/storage/v1${d.signedURL}` : null;
  } catch { return null; }
}

function fila(etiqueta: string, valor: unknown): string {
  const v = Array.isArray(valor) ? valor.join(", ") : valor;
  if (v === null || v === undefined || String(v).trim() === "") return "";
  return `<tr><td style="padding:6px 10px;color:#71717a;white-space:nowrap;vertical-align:top">${esc(etiqueta)}</td>` +
    `<td style="padding:6px 10px;color:#18181b"><b>${esc(v)}</b></td></tr>`;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ ok: false, motivo: "config" }, 200, origen);
  if (!BREVO_API_KEY) return responder({ ok: false, motivo: "sin-configurar" }, 200, origen);

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const referencia = String(cuerpo.referencia ?? "").trim().toUpperCase();
  if (!/^SOC-[0-9A-Z-]{2,20}$/.test(referencia)) return responder({ ok: false, motivo: "referencia" }, 200, origen);

  // 1 · Leer el alta (todos los campos) por su referencia.
  const rAlta = await rest("GET", `altas_socio?select=*&referencia=eq.${encodeURIComponent(referencia)}&limit=1`);
  const a = Array.isArray(rAlta.datos) ? (rAlta.datos[0] as Record<string, unknown>) : null;
  if (!a) return responder({ ok: false, motivo: "no-esta" }, 200, origen);

  // 2 · Reclamar el aviso de forma atómica: solo si aún no se ha enviado.
  const reclamo = await rest(
    "PATCH",
    `altas_socio?referencia=eq.${encodeURIComponent(referencia)}&aviso_enviado_en=is.null`,
    { aviso_enviado_en: new Date().toISOString() },
    { Prefer: "return=representation" },
  );
  const reclamado = Array.isArray(reclamo.datos) && reclamo.datos.length > 0;
  if (!reclamado) return responder({ ok: true, motivo: "ya-avisado" }, 200, origen);

  // 3 · Enlaces firmados a las fotos.
  const [carnet, dniA, dniB] = await Promise.all([
    enlaceFirmado(a.foto_carnet as string | null),
    enlaceFirmado(a.dni_anverso as string | null),
    enlaceFirmado(a.dni_reverso as string | null),
  ]);

  const nombreCompleto = `${a.nombre ?? ""} ${a.apellidos ?? ""}`.trim();

  const docs: string[] = [];
  if (dniA) docs.push(`<a href="${esc(dniA)}" style="color:#0b5d3b">DNI (anverso)</a>`);
  if (dniB) docs.push(`<a href="${esc(dniB)}" style="color:#0b5d3b">DNI (reverso)</a>`);
  if (carnet) docs.push(`<a href="${esc(carnet)}" style="color:#0b5d3b">Foto de carnet</a>`);
  const bloqueDocs = docs.length
    ? `<p style="margin:18px 0 6px;font-weight:700">Documentos</p><p style="margin:0;line-height:1.9">${docs.join(" &nbsp;·&nbsp; ")}</p>` +
      `<p style="margin:6px 0 0;color:#a1a1aa;font-size:12px">Los enlaces caducan en 30 días.</p>`
    : `<p style="margin:18px 0 0;color:#a1a1aa;font-size:13px">No se han adjuntado documentos.</p>`;

  const permImg = a.permiso_imagen === true ? "Sí" : (a.permiso_imagen === false ? "No" : "");

  const filas = [
    fila("Referencia", a.referencia),
    fila("Nombre", nombreCompleto),
    fila("DNI", a.dni),
    fila("Nacimiento", a.fecha_nacimiento),
    fila("Sexo", a.sexo),
    fila("Correo", a.email),
    fila("Teléfono", a.telefono),
    fila("Dirección", `${a.direccion ?? ""} · ${a.cp ?? ""} ${a.localidad ?? ""} (${a.provincia ?? ""})`.replace(/^ · /, "").trim()),
    fila("Secciones", a.secciones),
    fila("Nacionalidad", a.nacionalidad),
    fila("Talla camiseta", a.talla_camiseta),
    fila("Talla pantalón", a.talla_pantalon),
    fila("Permiso de imagen", permImg),
    fila("Titular cuenta", a.titular_cuenta),
    fila("IBAN", a.iban),
    fila("Domiciliación aceptada", a.consiente_domiciliacion ? "Sí" : "No"),
  ].filter(Boolean).join("");

  const html = `<!doctype html><html lang="es"><body style="margin:0;background:#f4f4f5;padding:24px;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
    <div style="max-width:600px;margin:0 auto;background:#fff;border-radius:14px;overflow:hidden;border:1px solid #e4e4e7">
      <div style="background:#0b5d3b;color:#fff;padding:18px 24px;font-size:17px;font-weight:700">Nueva alta de socio</div>
      <div style="padding:22px 24px">
        <p style="margin:0 0 14px;color:#3f3f46">Ha entrado un alta de socio nueva desde la web. Datos:</p>
        <table style="border-collapse:collapse;width:100%;font-size:14px">${filas}</table>
        ${bloqueDocs}
        <p style="margin:20px 0 0;color:#a1a1aa;font-size:12px">Puedes revisarla y activarla desde el panel de administración.</p>
      </div>
    </div>
  </body></html>`;

  const texto = `Nueva alta de socio (${a.referencia}): ${nombreCompleto}, DNI ${a.dni}, ${a.email}, tel ${a.telefono}. ` +
    `IBAN ${a.iban ?? "-"} (titular ${a.titular_cuenta ?? "-"}). Documentos: ${[dniA, dniB, carnet].filter(Boolean).join(" ") || "ninguno"}`;

  // 4 · Enviar a administración por Brevo.
  let resp: Response;
  try {
    resp = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        to: [{ email: CORREO_ADMIN }],
        replyTo: a.email ? { email: String(a.email) } : undefined,
        subject: `Nueva alta de socio · ${nombreCompleto || a.referencia}`,
        htmlContent: html,
        textContent: texto,
      }),
    });
  } catch (e) {
    return responder({ ok: false, motivo: "sin-conexion", detalle: String(e) }, 200, origen);
  }
  if (!resp.ok) {
    let d: unknown = null;
    try { d = await resp.json(); } catch { /* */ }
    return responder({ ok: false, motivo: "brevo-rechazo", estado: resp.status, brevo: d }, 200, origen);
  }

  return responder({ ok: true }, 200, origen);
});
