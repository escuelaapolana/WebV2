// ============================================================
// correo-grupo · manda un correo con el diseño del club a uno o
// varios grupos (El Cubo, escuela, natación…). Sale de info@ (Brevo)
// y las respuestas llegan a CORREO_RESPUESTAS (andres.apolana).
//
//   · POST con JWT de ADMIN (se comprueba en la base, no se fía del navegador).
//   · body {
//       accion: 'vista' | 'prueba' | 'enviar',
//       grupo_ids: uuid[], excluir?: string[] (correos que no),
//       asunto, titular?, mensaje, firma?,
//       destacados?: [{ tipo: 'rojo'|'verde'|'azul'|'ambar', etiqueta, texto }]
//     }
//     vista  → { html, destinatarios:[{nombre,email}] }  (no envía nada)
//     prueba → se lo manda SOLO a quien está usando el panel
//     enviar → a todos los del grupo menos `excluir`, uno a uno (nadie ve
//              los correos de los demás) y lo apunta en `correos_grupo`.
//
//   Variables (ya existen): BREVO_API_KEY, CORREO_REMITENTE,
//   CORREO_REMITENTE_NOMBRE, CORREO_RESPUESTAS, CORREO_ORIGENES, SUPABASE_*.
//   supabase functions deploy correo-grupo --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const CRON_SECRET = (Deno.env.get("CRON_SECRET") ?? "").trim();
function iguales(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a), eb = new TextEncoder().encode(b);
  let dif = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) dif |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return dif === 0;
}
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const RESPUESTAS_EMAIL = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const MAX_DESTINATARIOS = 400;

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
async function rest(ruta: string, init: RequestInit = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...init,
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
  });
  const t = await r.text(); let d: unknown = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, datos: d };
}
async function comoUsuario(rpc: string, jwt: string): Promise<unknown> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: "POST", headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" }, body: "{}",
  });
  if (!r.ok) return null; try { return await r.json(); } catch { return null; }
}
async function quienSoy(jwt: string): Promise<{ email: string } | null> {
  const r = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` } });
  if (!r.ok) return null; try { const u = await r.json(); return { email: String(u?.email ?? "") }; } catch { return null; }
}

const esc = (s: unknown) => String(s ?? "").replace(/[&<>"']/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[m] as string));
const corto = (s: unknown, n: number) => String(s ?? "").trim().slice(0, n);
const pareceCorreo = (s: string) => /^[^\s@,;]{1,64}@[^\s@,;]{1,190}\.[a-z]{2,}$/i.test(s);

type Destacado = { tipo: string; etiqueta: string; texto: string };
const COLORES: Record<string, { fondo: string; borde: string; etq: string }> = {
  rojo: { fondo: "#FBEDEA", borde: "#B3261E", etq: "#8A3B32" },
  verde: { fondo: "#EAF3E3", borde: "#4E8A3E", etq: "#3F6F32" },
  azul: { fondo: "#EAF2F9", borde: "#2F6FA8", etq: "#1E4E78" },
  ambar: { fondo: "#FDF3E3", borde: "#B96F09", etq: "#8A5307" },
};

function parrafos(texto: string): string {
  return texto.split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean)
    .map((p) => `<p style="margin:0 0 16px;">${esc(p).replace(/\n/g, "<br>")}</p>`).join("");
}

function correoHtml(o: { titular: string; mensaje: string; firma: string; destacados: Destacado[] }): string {
  const cajas = o.destacados.map((d) => {
    const c = COLORES[d.tipo] ?? COLORES.azul;
    return `<tr><td bgcolor="${c.fondo}" style="background-color:${c.fondo};padding:14px 16px;border-left:4px solid ${c.borde};border-radius:6px;">` +
      (d.etiqueta ? `<div style="font-size:12px;color:${c.etq};text-transform:uppercase;letter-spacing:.5px;">${esc(d.etiqueta)}</div>` : "") +
      `<div style="font-size:17px;font-weight:bold;color:#2E4256;margin-top:3px;">${esc(d.texto)}</div></td></tr>` +
      `<tr><td style="height:10px;line-height:10px;font-size:0;">&nbsp;</td></tr>`;
  }).join("");
  const firma = esc(o.firma).replace(/\n/g, "<br>");
  return `<!doctype html><html lang="es"><body style="margin:0;padding:0;background-color:#F7F3EA;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#F7F3EA"><tr><td align="center" style="padding:24px 12px;">
<table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;width:100%;font-family:Arial,Helvetica,sans-serif;">
<tr><td bgcolor="#2E4256" style="background-color:#2E4256;padding:22px 26px;border-radius:12px 12px 0 0;">
<div style="color:#C9D3DD;font-size:12px;letter-spacing:1px;text-transform:uppercase;">Club Atletismo Apolana</div>
${o.titular ? `<div style="color:#ffffff;font-size:22px;font-weight:bold;margin-top:6px;line-height:1.25;">${esc(o.titular)}</div>` : ""}
</td></tr>
<tr><td bgcolor="#ffffff" style="background-color:#ffffff;padding:24px 26px;color:#2E4256;font-size:15px;line-height:1.55;">
${parrafos(o.mensaje)}
${cajas ? `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 8px;">${cajas}</table>` : ""}
${firma ? `<p style="margin:14px 0 0;">${firma}</p>` : ""}
</td></tr>
<tr><td bgcolor="#2E4256" style="background-color:#2E4256;padding:12px 26px;border-radius:0 0 12px 12px;color:#C9D3DD;font-size:12px;">atletismoapolana.com · Si tienes cualquier duda, contesta a este correo.</td></tr>
</table></td></tr></table></body></html>`;
}
function correoTexto(o: { titular: string; mensaje: string; firma: string; destacados: Destacado[] }): string {
  return [o.titular, "", o.mensaje.trim(), "",
    ...o.destacados.map((d) => `${d.etiqueta ? d.etiqueta.toUpperCase() + ": " : ""}${d.texto}`),
    "", o.firma].join("\n").replace(/\n{3,}/g, "\n\n").trim();
}

async function destinatariosDe(grupoIds: string[]): Promise<{ nombre: string; email: string }[]> {
  if (!grupoIds.length) return [];
  const ids = grupoIds.map(encodeURIComponent).join(",");
  const rAg = await rest(`atleta_grupos?select=atleta_id&grupo_id=in.(${ids})`);
  const atletaIds = [...new Set((Array.isArray(rAg.datos) ? rAg.datos : []).map((x: { atleta_id: string }) => x.atleta_id))];
  if (!atletaIds.length) return [];
  const rA = await rest(`atletas?select=id,nombre,apellidos,email,email_tutor,perfil_id,estado&id=in.(${atletaIds.join(",")})`);
  const atletas = (Array.isArray(rA.datos) ? rA.datos : []) as Array<Record<string, string | null>>;
  const sinCorreo = atletas.filter((a) => !a.email && !a.email_tutor && a.perfil_id).map((a) => a.perfil_id as string);
  const correoPerfil: Record<string, string> = {};
  if (sinCorreo.length) {
    const rP = await rest(`perfiles?select=id,email&id=in.(${sinCorreo.join(",")})`);
    (Array.isArray(rP.datos) ? rP.datos : []).forEach((p: { id: string; email: string }) => { correoPerfil[p.id] = p.email; });
  }
  const vistos = new Set<string>(); const out: { nombre: string; email: string }[] = [];
  for (const a of atletas) {
    if (a.estado === "baja" || String(a.nombre ?? "").includes("(duplicado)")) continue;
    const email = String(a.email || a.email_tutor || (a.perfil_id ? correoPerfil[a.perfil_id] : "") || "").trim().toLowerCase();
    if (!pareceCorreo(email) || vistos.has(email)) continue;
    vistos.add(email);
    out.push({ nombre: `${a.nombre ?? ""} ${a.apellidos ?? ""}`.replace(/\s+/g, " ").trim(), email });
  }
  return out.sort((x, y) => x.nombre.localeCompare(y.nombre, "es"));
}

async function mandar(email: string, asunto: string, html: string, texto: string): Promise<boolean> {
  try {
    const r = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS_EMAIL },
        to: [{ email }], subject: asunto, htmlContent: html, textContent: texto,
      }),
    });
    return r.ok;
  } catch { return false; }
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config" }, 503, origen);

  // Quién llama: administración con su sesión, o la base con su secreto
  // (cron_llamar_edge, x-cron-secret), para mandarlo sin abrir el panel (24-oct).
  const secreto = (req.headers.get("x-cron-secret") ?? "").trim();
  const esLaBase = !!(CRON_SECRET && secreto && iguales(secreto, CRON_SECRET));
  const cab = req.headers.get("Authorization") ?? "";
  const jwt = cab.toLowerCase().startsWith("bearer ") ? cab.slice(7).trim() : "";
  if (!esLaBase) {
    if (!jwt) return responder({ error: "sin_sesion" }, 401, origen);
    if ((await comoUsuario("es_admin", jwt)) !== true) return responder({ error: "sin_permiso" }, 403, origen);
  }

  let c: Record<string, unknown> = {};
  try { c = await req.json(); } catch { /* vacío */ }
  const accion = String(c.accion ?? "vista");
  const grupoIds = (Array.isArray(c.grupo_ids) ? c.grupo_ids : []).map(String)
    .filter((x) => /^[0-9a-f-]{36}$/i.test(x)).slice(0, 30);
  const excluir = new Set((Array.isArray(c.excluir) ? c.excluir : []).map((x) => String(x).trim().toLowerCase()));
  const asunto = corto(c.asunto, 150);
  const o = {
    titular: corto(c.titular, 150),
    mensaje: corto(c.mensaje, 6000),
    firma: corto(c.firma ?? "Club Atletismo Apolana", 200),
    destacados: (Array.isArray(c.destacados) ? c.destacados : []).slice(0, 5)
      .map((d: Record<string, unknown>) => ({ tipo: corto(d?.tipo, 10), etiqueta: corto(d?.etiqueta, 60), texto: corto(d?.texto, 160) }))
      .filter((d: Destacado) => d.texto),
  };
  const html = correoHtml(o);
  const destinatarios = await destinatariosDe(grupoIds);

  if (accion === "vista") return responder({ ok: true, html, destinatarios }, 200, origen);

  if (!BREVO_API_KEY) return responder({ ok: false, motivo: "sin-configurar" }, 200, origen);
  if (!asunto || !o.mensaje) return responder({ ok: false, motivo: "falta-texto", mensaje: "Pon el asunto y el mensaje." }, 200, origen);
  const texto = correoTexto(o);
  // Desde la base no hay sesión: «en nombre de» solo sirve para el historial y la prueba.
  const yo = esLaBase ? (c.en_nombre_de ? { email: corto(c.en_nombre_de, 120) } : null) : await quienSoy(jwt);

  if (accion === "prueba") {
    if (!yo?.email) return responder({ ok: false, motivo: "sin-correo" }, 200, origen);
    const ok = await mandar(yo.email, "[PRUEBA] " + asunto, html, texto);
    return responder({ ok, a: yo.email }, 200, origen);
  }

  if (accion !== "enviar") return responder({ error: "accion" }, 400, origen);
  const lista = destinatarios.filter((d) => !excluir.has(d.email));
  if (!lista.length) return responder({ ok: false, motivo: "sin-destinatarios", mensaje: "No hay nadie a quien enviarlo." }, 200, origen);
  if (lista.length > MAX_DESTINATARIOS) return responder({ ok: false, motivo: "demasiados", mensaje: `Son ${lista.length}; el máximo es ${MAX_DESTINATARIOS}.` }, 200, origen);

  const enviados: string[] = []; const fallidos: string[] = [];
  for (let i = 0; i < lista.length; i += 8) {
    const tanda = lista.slice(i, i + 8);
    const res = await Promise.all(tanda.map((d) => mandar(d.email, asunto, html, texto)));
    res.forEach((ok, k) => (ok ? enviados : fallidos).push(tanda[k].email));
  }

  let perfilId: string | null = null;
  if (yo?.email) {
    const rP = await rest(`perfiles?select=id&email=eq.${encodeURIComponent(yo.email)}&limit=1`);
    perfilId = Array.isArray(rP.datos) && rP.datos[0] ? (rP.datos[0] as { id: string }).id : null;
  }
  await rest("correos_grupo", {
    method: "POST", headers: { Prefer: "return=minimal" },
    body: JSON.stringify({ enviado_por: perfilId, enviado_email: yo?.email ?? null, grupo_ids: grupoIds, asunto, titular: o.titular || null,
      n_enviados: enviados.length, n_fallidos: fallidos.length, destinatarios: enviados }),
  });
  return responder({ ok: fallidos.length === 0, enviados: enviados.length, fallidos }, 200, origen);
});
