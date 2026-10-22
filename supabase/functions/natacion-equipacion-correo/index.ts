// ============================================================
// natacion-equipacion-correo · correos del pedido de equipación de natación
// ------------------------------------------------------------
// Mig 436 (22-oct-2026). La lanza Mario desde portal/natacion-equipacion (con
// su sesión: tiene que pasar natacion_cuotas_puede) o la base con x-cron-secret.
//   { enviar: true }            → a cada familia que aún no lo tiene, su enlace
//   { recordar: true }          → a las que lo recibieron y no han contestado
//   { llegado: "<familia_id>" } → «ya ha llegado»: con enlace de pago si hay algo que pagar
//   { prueba: true, a, t?, tipo? } → un ejemplo a ese correo (tipo: recordatorio | llegado)
// Correo SENCILLO (texto, sin foto ni botón): el «boletín» cae en Promociones.
//
//   supabase functions deploy natacion-equipacion-correo --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const CRON_SECRET = (Deno.env.get("CRON_SECRET") ?? "").trim();
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const RESPUESTAS = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const WEB = "https://atletismoapolana.com/";

function cors(o: string | null): Record<string, string> {
  return { "Access-Control-Allow-Origin": o ?? "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
    "Access-Control-Allow-Methods": "POST, OPTIONS", "Vary": "Origin" };
}
const responder = (d: unknown, s: number, o: string | null) =>
  new Response(JSON.stringify(d), { status: s, headers: { ...cors(o), "Content-Type": "application/json; charset=utf-8" } });
function iguales(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a), eb = new TextEncoder().encode(b);
  let dif = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) dif |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return dif === 0;
}
const escH = (v: unknown) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
const pila = (n: string) => { const p = String(n || "").trim().split(/\s+/)[0] || ""; return p.charAt(0).toUpperCase() + p.slice(1).toLowerCase(); };
const eur = (n: number) => (Math.round(n * 100) / 100).toLocaleString("es-ES", { minimumFractionDigits: n % 1 ? 2 : 0, maximumFractionDigits: 2 }) + " €";

async function rest(ruta: string, init: RequestInit = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...init, headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
  });
  const t = await r.text();
  try { return { ok: r.ok, datos: t ? JSON.parse(t) : null }; } catch { return { ok: r.ok, datos: t }; }
}

function sencillo(parrafos: string[], enlace?: string) {
  const html = `<!doctype html><html lang="es"><body style="margin:0;padding:16px;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.6;color:#222">
${parrafos.map((p) => `<p>${escH(p)}</p>`).join("\n").replace("{{ENLACE}}", enlace ? `<br><a href="${escH(enlace)}">${escH(enlace)}</a>` : "")}
<p>Un saludo,<br>Club Atletismo Apolana · Natación</p></body></html>`;
  const texto = parrafos.join("\n\n").replace("{{ENLACE}}", enlace ? "\n" + enlace : "") + "\n\nUn saludo,\nClub Atletismo Apolana · Natación";
  return { html, texto };
}
function correoEnlace(contacto: string, nadadores: string, enlace: string, recordatorio: boolean) {
  const n = pila(contacto);
  const c = sencillo([
    n ? `Hola, ${n}:` : "Hola:",
    recordatorio
      ? `Te recordamos que aún no nos has dicho las tallas de la equipación de natación de ${nadadores}.`
      : `Estamos preparando los pedidos de equipación de natación de esta temporada. En este enlace puedes elegir las tallas de ${nadadores} y, si queréis, encargar bañadores del club u otras prendas:{{ENLACE}}`,
    ...(recordatorio ? ["Es un momento, aquí:{{ENLACE}}"] : []),
    "Rellénalo antes del 2 de noviembre, que es cuando hacemos el pedido. La camiseta oficial y el gorro son gratis para todos, y la chaqueta es gratis para quien se incorpora este año. No se paga nada ahora: lo que haya que pagar se paga cuando llegue la ropa, antes de recogerla.",
    "Si tienes cualquier duda, contesta a este correo.",
  ], enlace);
  return { ...c, asunto: recordatorio ? "Recordatorio · tallas de la equipación de natación" : "Equipación de natación: elige las tallas" };
}
function correoLlegado(contacto: string, total: number, pago: string | null) {
  const n = pila(contacto);
  const c = sencillo([
    n ? `Hola, ${n}:` : "Hola:",
    "¡Ya ha llegado la equipación de natación que pediste!",
    pago ? `Antes de recogerla, paga ${eur(total)} con tarjeta aquí (o en la oficina):{{ENLACE}}` : "No tienes nada que pagar: te avisaremos de cuándo y dónde recogerla.",
    "Si tienes cualquier duda, contesta a este correo.",
  ], pago ?? undefined);
  return { ...c, asunto: "Ya ha llegado tu equipación de natación" };
}
async function enviar(a: string, c: { html: string; texto: string; asunto: string }) {
  const r = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({ sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL }, to: [{ email: a }],
      replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS }, subject: c.asunto, htmlContent: c.html, textContent: c.texto }),
    signal: AbortSignal.timeout(20000),
  });
  if (!r.ok) console.error("[natacion-equipacion-correo] Brevo:", r.status, await r.text().catch(() => ""));
  return r.ok;
}
const nombresDe = (ns: any[]) => {
  const l = ns.map((x) => pila(x.nombre));
  return l.length <= 1 ? (l[0] || "tu nadador/a") : l.slice(0, -1).join(", ") + " y " + l[l.length - 1];
};

Deno.serve(async (req: Request) => {
  const o = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(o) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, o);
  if (!SUPABASE_URL || !SERVICE_KEY || !BREVO_API_KEY) return responder({ error: "config" }, 503, o);

  // ¿Quién llama? cron (secreto) o Mario/admin con su sesión.
  const sec = (req.headers.get("x-cron-secret") ?? "").trim();
  let ok = !!(CRON_SECRET && sec && iguales(sec, CRON_SECRET));
  if (!ok) {
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
    if (jwt && jwt !== ANON_KEY) {
      const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/natacion_cuotas_puede`, {
        method: "POST", headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" }, body: "{}" });
      ok = r.ok && (await r.json().catch(() => false)) === true;
    }
  }
  if (!ok) return responder({ error: "permiso", mensaje: "Solo quien lleva la natación." }, 403, o);

  let b: Record<string, unknown> = {};
  try { b = await req.json(); } catch { /* vacío */ }

  if (b.prueba === true) {
    const a = String(b.a ?? "").trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(a)) return responder({ error: "falta 'a'" }, 400, o);
    const quien = String(b.nombre ?? "Andrés");
    const c = b.tipo === "llegado"
      ? correoLlegado(quien, 70, `${WEB}pagar/?t=ejemplo`)
      : correoEnlace(quien, "Lucía y Marcos", `${WEB}natacion/equipacion/?t=${String(b.t ?? "ejemplo")}`, b.tipo === "recordatorio");
    const okp = await enviar(a, { ...c, asunto: (b.tipo ? "[Ejemplo] " : "") + c.asunto });
    return responder({ ok: okp, prueba: true, a }, 200, o);
  }

  if (typeof b.llegado === "string") {
    const r = await rest(`natacion_equip_familias?select=id,email,contacto,total,estado,pagos(token_pago,estado)&id=eq.${encodeURIComponent(b.llegado)}&limit=1`);
    const f = Array.isArray(r.datos) ? r.datos[0] : null;
    if (!f) return responder({ error: "no_existe" }, 404, o);
    const pago = f.pagos && f.pagos.token_pago && f.pagos.estado !== "pagado" ? `${WEB}pagar/?t=${f.pagos.token_pago}` : null;
    const okl = await enviar(String(f.email), correoLlegado(String(f.contacto ?? ""), Number(f.total || 0), pago));
    return responder({ ok: okl }, 200, o);
  }

  if (b.enviar !== true && b.recordar !== true) return responder({ error: "¿qué hago?" }, 400, o);
  if (b.enviar === true) await rest("rpc/natacion_equip_preparar", { method: "POST", body: "{}" });
  const filtro = b.enviar === true ? "avisado_en=is.null" : "avisado_en=not.is.null&respondido_en=is.null&estado=eq.pendiente";
  const r = await rest(`natacion_equip_familias?select=id,email,contacto,token,natacion_equip_nadadores(nombre)&temporada=eq.2026/27&email=not.like.prueba-*&${filtro}`);
  const fams: any[] = Array.isArray(r.datos) ? r.datos : [];
  let n = 0; const fallos: string[] = [];
  for (const f of fams) {
    const okf = await enviar(String(f.email), correoEnlace(String(f.contacto ?? ""), nombresDe(f.natacion_equip_nadadores || []),
      `${WEB}natacion/equipacion/?t=${f.token}`, b.recordar === true));
    if (okf) {
      n++;
      await rest(`natacion_equip_familias?id=eq.${f.id}`, { method: "PATCH", headers: { Prefer: "return=minimal" },
        body: JSON.stringify(b.enviar === true ? { avisado_en: new Date().toISOString() } : { recordado_en: new Date().toISOString() }) });
    } else fallos.push(String(f.email));
  }
  console.log("[natacion-equipacion-correo]", b.enviar ? "enviar" : "recordar", n, "de", fams.length, fallos);
  return responder({ ok: true, enviados: n, total: fams.length, fallos }, 200, o);
});
