// ============================================================
// natacion-aviso · AVISOS del mundo Natación (mig 418)
// ------------------------------------------------------------
// Mario (o admin) escribe un aviso —«cierre de la piscina el jueves»,
// «cambio de horario»— para una o varias franjas, para toda la natación,
// solo la escuela o solo el máster. Esta función:
//   1) comprueba quién lo manda (JWT) y que puede (natacion_cuotas_puede),
//   2) pide a la BASE los destinatarios (natacion_aviso_destinatarios, con el
//      JWT de quien envía: la base vuelve a mirar el permiso),
//   3) manda el correo con el diseño del club, uno a uno (nadie ve los correos
//      de los demás), desde info@ y con las respuestas a CORREO_RESPUESTAS,
//   4) deja el aviso dentro de la app y la fila del historial
//      (natacion_aviso_registrar, solo service_role).
//
//   POST (JWT de quien envía) {
//     accion: 'vista' | 'prueba' | 'enviar',
//     tipo: 'todos' | 'escuela' | 'master', franja_ids: uuid[] (vacío = todas),
//     asunto, mensaje
//   }
//     vista  → { html, resumen }                 (no envía nada)
//     prueba → el correo SOLO a quien lo envía, con «[PRUEBA]» (no deja aviso ni historial)
//     enviar → a todos; responde { enviados, fallidos, en_app, alcance }
//
// CLAVES (ya existen): SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / SUPABASE_ANON_KEY /
//   BREVO_API_KEY / CORREO_REMITENTE / CORREO_REMITENTE_NOMBRE / CORREO_RESPUESTAS / CORREO_ORIGENES
// DESPLIEGUE: supabase functions deploy natacion-aviso --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const RESPUESTAS_EMAIL = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const APP = "https://atletismoapolana.com/portal/";
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
async function rpcComo(rpc: string, jwt: string | null, args: unknown): Promise<{ ok: boolean; datos: unknown }> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: "POST",
    headers: {
      apikey: jwt ? (ANON_KEY || SERVICE_KEY) : SERVICE_KEY,
      Authorization: `Bearer ${jwt ?? SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(args ?? {}),
  });
  const t = await r.text(); let d: unknown = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, datos: d };
}
async function quienSoy(jwt: string): Promise<{ email: string } | null> {
  const r = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` } });
  if (!r.ok) return null; try { const u = await r.json(); return { email: String(u?.email ?? "") }; } catch { return null; }
}
async function perfilDe(email: string): Promise<string | null> {
  if (!email) return null;
  const r = await fetch(`${SUPABASE_URL}/rest/v1/perfiles?select=id&email=eq.${encodeURIComponent(email)}&limit=1`,
    { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
  if (!r.ok) return null;
  try { const d = await r.json(); return Array.isArray(d) && d[0] ? String(d[0].id) : null; } catch { return null; }
}

const esc = (s: unknown) => String(s ?? "").replace(/[&<>"']/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[m] as string));
const corto = (s: unknown, n: number) => String(s ?? "").trim().slice(0, n);
const pareceCorreo = (s: string) => /^[^\s@,;]{1,64}@[^\s@,;]{1,190}\.[a-z]{2,}$/i.test(s);
function pila(n: string) {
  const p = String(n ?? "").trim().split(/\s+/)[0] ?? "";
  return p ? p.charAt(0).toUpperCase() + p.slice(1).toLowerCase() : "";
}
function nombreBonito(n: string) {
  return String(n ?? "").toLowerCase().replace(/(^|[\s-])(\p{L})/gu, (_, a, b) => a + b.toUpperCase()).trim();
}
function lista(xs: string[]) {
  return xs.length <= 1 ? (xs[0] ?? "") : xs.slice(0, -1).join(", ") + " y " + xs[xs.length - 1];
}

type Nadador = { nombre: string; tipo: string; franjas: string };
type Dest = { email: string; nadadores: Nadador[]; escuela: boolean; master: boolean };

function saludo(d: Dest | null): string {
  if (!d || !d.nadadores.length) return "Hola:";
  const nombres = d.nadadores.map((n) => pila(n.nombre)).filter(Boolean);
  if (d.escuela && !d.master) return `Hola, familia de ${lista(nombres)}:`;
  if (d.master && !d.escuela && nombres.length === 1) return `¡Hola, ${nombres[0]}!`;
  return "Hola:";
}
function parrafos(texto: string): string {
  return texto.split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean)
    .map((p) => `<p style="margin:0 0 14px;color:#3f3f46;font-size:15px;line-height:1.6">${esc(p).replace(/\n/g, "<br>")}</p>`).join("");
}

function correoHtml(asunto: string, mensaje: string, d: Dest | null): string {
  const filas = (d?.nadadores ?? []).map((n) =>
    `<b>${esc(nombreBonito(n.nombre))}</b>${n.franjas ? ` · ${esc(n.franjas)}` : ""}`).join("<br>");
  const tarjeta = filas ? `
      <tr><td style="padding:0 24px 8px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border:1px solid #e9e2d2;border-radius:10px">
          <tr><td style="padding:14px 16px;color:#26374B;font-size:15px;line-height:1.6"><span style="font-size:12px;letter-spacing:.5px;text-transform:uppercase;color:#7a6a4f">Te llega por</span><br>${filas}</td></tr>
        </table>
      </td></tr>` : "";
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#f4f4f5" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px">
        <div style="font-size:12px;letter-spacing:1px;text-transform:uppercase;color:#C9D3DD">Club Atletismo Apolana · Natación</div>
        <div style="font-size:21px;font-weight:700;line-height:1.25;margin-top:6px;color:#ffffff">${esc(asunto)}</div>
      </td></tr>
      <tr><td style="padding:22px 24px 4px 24px">
        <p style="margin:0 0 14px;font-size:17px;font-weight:700;color:#26374B">${esc(saludo(d))}</p>
        ${parrafos(mensaje)}
      </td></tr>${tarjeta}
      <tr><td align="left" style="padding:10px 24px 6px 24px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr><td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">
          <a href="${APP}" style="display:inline-block;padding:12px 22px;color:#ffffff;text-decoration:none;font-weight:700;font-size:15px">Abrir la app del club →</a>
        </td></tr></table>
      </td></tr>
      <tr><td style="padding:14px 24px 24px 24px">
        <p style="margin:14px 0 0 0;color:#71717a;font-size:13px;line-height:1.5;border-top:1px solid #ececec;padding-top:14px">Si tienes cualquier duda, contesta a este correo.<br>Un saludo,<br><b style="color:#26374B">Club Atletismo Apolana · Natación</b></p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;
}
function correoTexto(asunto: string, mensaje: string, d: Dest | null): string {
  const filas = (d?.nadadores ?? []).map((n) => `· ${nombreBonito(n.nombre)}${n.franjas ? " — " + n.franjas : ""}`);
  return [asunto, "", saludo(d), "", mensaje.trim(), "", ...(filas.length ? ["Te llega por:", ...filas, ""] : []),
    "Si tienes cualquier duda, contesta a este correo.", "Club Atletismo Apolana · Natación", APP].join("\n");
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
      signal: AbortSignal.timeout(15000),
    });
    if (!r.ok) console.error("[natacion-aviso] Brevo", r.status, await r.text().catch(() => ""));
    return r.ok;
  } catch (e) { console.error("[natacion-aviso]", e); return false; }
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config" }, 503, origen);

  const cab = req.headers.get("Authorization") ?? "";
  const jwt = cab.toLowerCase().startsWith("bearer ") ? cab.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sin_sesion" }, 401, origen);
  const puede = await rpcComo("natacion_cuotas_puede", jwt, {});
  if (!puede.ok || puede.datos !== true) return responder({ error: "sin_permiso" }, 403, origen);

  let c: Record<string, unknown> = {};
  try { c = await req.json(); } catch { /* vacío */ }
  const accion = String(c.accion ?? "vista");
  const tipo = ["todos", "escuela", "master"].includes(String(c.tipo)) ? String(c.tipo) : "todos";
  const franjas = (Array.isArray(c.franja_ids) ? c.franja_ids : []).map(String)
    .filter((x) => /^[0-9a-f-]{36}$/i.test(x)).slice(0, 30);
  const asunto = corto(c.asunto, 150);
  const mensaje = corto(c.mensaje, 4000);

  const rD = await rpcComo("natacion_aviso_destinatarios", jwt, { p_tipo: tipo, p_franjas: franjas });
  if (!rD.ok) return responder({ ok: false, motivo: "destinatarios", mensaje: "No se pudo calcular a quién va." }, 200, origen);
  const res = (rD.datos ?? {}) as { alcance?: string; nadadores?: number; correos?: Dest[]; sin_correo?: string[]; en_app?: number };
  const dests = (res.correos ?? []).filter((d) => pareceCorreo(String(d.email)));
  const resumen = { alcance: res.alcance ?? "", nadadores: res.nadadores ?? 0, correos: dests.length,
    sin_correo: res.sin_correo ?? [], en_app: res.en_app ?? 0 };

  if (accion === "vista") {
    return responder({ ok: true, html: correoHtml(asunto || "Asunto del aviso", mensaje || "Aquí va tu mensaje.", dests[0] ?? null), resumen }, 200, origen);
  }

  if (!BREVO_API_KEY) return responder({ ok: false, motivo: "sin-configurar", mensaje: "El correo no está configurado." }, 200, origen);
  if (!asunto || !mensaje) return responder({ ok: false, motivo: "falta-texto", mensaje: "Pon el asunto y el mensaje." }, 200, origen);
  const yo = await quienSoy(jwt);

  if (accion === "prueba") {
    if (!yo?.email) return responder({ ok: false, motivo: "sin-correo", mensaje: "Tu cuenta no tiene correo." }, 200, origen);
    // La prueba sale con el primer destinatario de ejemplo (su saludo y sus franjas), pero SOLO a ti.
    const ej = dests[0] ?? null;
    const ok = await mandar(yo.email, "[PRUEBA] " + asunto, correoHtml(asunto, mensaje, ej), correoTexto(asunto, mensaje, ej));
    return responder({ ok, a: yo.email, mensaje: ok ? "" : "No se pudo enviar la prueba." }, 200, origen);
  }

  if (accion !== "enviar") return responder({ error: "accion" }, 400, origen);
  if (!dests.length && !(res.en_app ?? 0)) return responder({ ok: false, motivo: "sin-destinatarios", mensaje: "No hay nadie a quien enviarlo." }, 200, origen);
  if (dests.length > MAX_DESTINATARIOS) return responder({ ok: false, motivo: "demasiados", mensaje: `Son ${dests.length}; el máximo es ${MAX_DESTINATARIOS}.` }, 200, origen);
  // Freno: si la pantalla dice cuántos esperaba y no cuadra (alguien cambió las franjas entretanto), no se envía.
  const esperado = Number(c.esperado);
  if (Number.isFinite(esperado) && esperado >= 0 && esperado !== dests.length) {
    return responder({ ok: false, motivo: "cambio", mensaje: `Ahora son ${dests.length} correos (antes ${esperado}). Revísalo y vuelve a enviar.`, resumen }, 200, origen);
  }

  const enviados: string[] = []; const fallidos: string[] = [];
  for (let i = 0; i < dests.length; i += 8) {
    const tanda = dests.slice(i, i + 8);
    const r = await Promise.all(tanda.map((d) => mandar(d.email, asunto, correoHtml(asunto, mensaje, d), correoTexto(asunto, mensaje, d))));
    r.forEach((ok, k) => (ok ? enviados : fallidos).push(tanda[k].email));
  }

  const autor = await perfilDe(yo?.email ?? "");
  const reg = await rpcComo("natacion_aviso_registrar", null, {
    p_autor: autor, p_autor_email: yo?.email ?? null, p_tipo: tipo, p_franjas: franjas,
    p_asunto: asunto, p_mensaje: mensaje, p_correos: enviados, p_fallidos: fallidos.length,
  });
  if (!reg.ok) console.error("[natacion-aviso] registrar", reg.datos);
  const r2 = (reg.datos ?? {}) as { en_app?: number; alcance?: string };
  return responder({
    ok: fallidos.length === 0 && reg.ok, enviados: enviados.length, fallidos, en_app: r2.en_app ?? 0,
    alcance: r2.alcance ?? resumen.alcance, registrado: reg.ok,
  }, 200, origen);
});
