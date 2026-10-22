// ============================================================
// liga-camiseta-correo · correo a los finisher de la Liga para que elijan talla
// ------------------------------------------------------------
// Mig 434 (22-oct-2026). Cada finisher tiene su enlace /liga/camiseta/?t=…
//   body { prueba: true, a: "correo@…", t?: "token" } → UN ejemplo a ese correo
//   body { enviar: true }   → prepara las filas (liga_camisetas_preparar) y manda
//                             el correo a quien aún no lo recibió (avisado_en)
//   body { recordar: true } → a quien lo recibió y no ha contestado, un recordatorio
// Cabecera x-cron-secret (se lanza desde la base con cron_llamar_edge).
//
//   supabase functions deploy liga-camiseta-correo --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const CRON_SECRET = (Deno.env.get("CRON_SECRET") ?? "").trim();
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const RESPUESTAS = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const WEB = "https://atletismoapolana.com/";

function iguales(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a), eb = new TextEncoder().encode(b);
  let dif = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) dif |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return dif === 0;
}
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { "Content-Type": "application/json" } });
const escH = (v: unknown) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
const pila = (n: string) => { const p = String(n || "").trim().split(/\s+/)[0] || ""; return p.charAt(0).toUpperCase() + p.slice(1).toLowerCase(); };

async function rest(ruta: string, init: RequestInit = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...init, headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
  });
  const t = await r.text();
  try { return { ok: r.ok, datos: t ? JSON.parse(t) : null }; } catch { return { ok: r.ok, datos: t }; }
}

// Correo PERSONAL (texto sencillo, sin foto ni botón ni emoji): Gmail mandaba
// la versión «boletín» a Promociones (Andrés, 22-oct). La foto la ven en la página.
function correo(nombre: string, enlace: string, recordatorio: boolean) {
  const n = pila(nombre);
  const hola = n ? `Hola, ${n}:` : "Hola:";
  const p1 = recordatorio
    ? "Te escribo otra vez porque aún no nos has dicho la talla de tu camiseta Finisher de la Liga Apolana 2026."
    : "¡Enhorabuena! Has completado la Liga Apolana 2026 y te has ganado la camiseta Finisher.";
  const p2 = "Para encargarla necesito saber tu talla (es corte único, igual para todos). Elígela aquí, es un momento:";
  const p3 = "En ese enlace puedes ver cómo será la camiseta. Es una representación: el diseño aún tiene que aprobarlo el proveedor y puede cambiar algún detalle.";
  const html = `<!doctype html><html lang="es"><body style="margin:0;padding:16px;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.6;color:#222">
<p>${escH(hola)}</p>
<p>${escH(p1)}</p>
<p>${escH(p2)}<br><a href="${escH(enlace)}">${escH(enlace)}</a></p>
<p>${escH(p3)}</p>
<p>Si tienes cualquier duda, contesta a este correo.</p>
<p>Un saludo,<br>Club Atletismo Apolana</p>
</body></html>`;
  const texto = `${hola}\n\n${p1}\n\n${p2}\n${enlace}\n\n${p3}\n\nSi tienes cualquier duda, contesta a este correo.\n\nUn saludo,\nClub Atletismo Apolana`;
  return { html, texto, asunto: recordatorio ? "Tu talla de la camiseta de la Liga" : "Tu camiseta Finisher de la Liga: ¿qué talla usas?" };
}

async function enviar(a: string, c: { html: string; texto: string; asunto: string }) {
  const r = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({ sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL }, to: [{ email: a }],
      replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS }, subject: c.asunto, htmlContent: c.html, textContent: c.texto }),
    signal: AbortSignal.timeout(20000),
  });
  if (!r.ok) console.error("[liga-camiseta-correo] Brevo:", r.status, await r.text().catch(() => ""));
  return r.ok;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "metodo" }, 405);
  if (!SUPABASE_URL || !SERVICE_KEY || !CRON_SECRET || !BREVO_API_KEY) return json({ error: "config" }, 503);
  const sec = (req.headers.get("x-cron-secret") ?? "").trim();
  if (!sec || !iguales(sec, CRON_SECRET)) return json({ error: "secreto" }, 401);
  let b: Record<string, unknown> = {};
  try { b = await req.json(); } catch { /* vacío */ }

  if (b.prueba === true) {
    const a = String(b.a ?? "").trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(a)) return json({ error: "falta 'a'" }, 400);
    const t = String(b.t ?? "ejemplo");
    const ok = await enviar(a, correo(String(b.nombre ?? "Andrés"), `${WEB}liga/camiseta/?t=${t}`, b.recordatorio === true));
    return json({ ok, prueba: true, a });
  }
  if (b.enviar !== true && b.recordar !== true) return json({ error: "¿enviar o recordar?" }, 400);

  if (b.enviar === true) await rest("rpc/liga_camisetas_preparar", { method: "POST", body: "{}" });
  const filtro = b.enviar === true ? "avisado_en=is.null" : "avisado_en=not.is.null&respondido_en=is.null";
  const r = await rest(`liga_camisetas?select=id,nombre,email,token&email=not.is.null&${filtro}&clave=not.like.prueba-*`);
  const filas: any[] = Array.isArray(r.datos) ? r.datos : [];
  const salida: any[] = [];
  for (const f of filas) {
    const ok = await enviar(String(f.email), correo(String(f.nombre), `${WEB}liga/camiseta/?t=${f.token}`, b.recordar === true));
    if (ok && b.enviar === true) await rest(`liga_camisetas?id=eq.${f.id}`, { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ avisado_en: new Date().toISOString() }) });
    salida.push({ nombre: f.nombre, enviado: ok });
  }
  console.log("[liga-camiseta-correo]", b.enviar ? "enviar" : "recordar", JSON.stringify(salida));
  return json({ ok: true, enviados: salida.filter((x) => x.enviado).length, total: salida.length, detalle: salida });
});
