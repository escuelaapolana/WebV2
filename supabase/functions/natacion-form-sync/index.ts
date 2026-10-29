// ============================================================
// natacion-form-sync · solicitudes de natación desde los formularios (mig 475)
// ------------------------------------------------------------
// Dos formas de llamarla:
//   · el script de Google (Apps Script en escuelaapolana@gmail.com) cada mañana:
//       POST { filas: [{origen:'Escuela'|'Máster', fila, datos:[[título, valor]…]}],
//              aplicar?: boolean (por defecto true) }
//       cabecera x-sync-token (el mismo token que BUENO ISA; lo comprueba la SQL)
//   · pg_cron a las 9:30 (cron_llamar_edge, cabecera x-cron-secret): solo el repaso.
//
// Lo que hace:
//   1. guarda las respuestas nuevas y da de alta de PRUEBA a quien tiene hueco
//      (natacion_form_sincronizar);
//   2. mira quién vino a su clase de prueba, quién ya tiene cuota y quién ya no
//      está en ninguna franja (natacion_solicitudes_revisar);
//   3. si hay algo que Andrés no sepa todavía (nuevas de prueba, por revisar,
//      vinieron a la prueba, cumplen los 15 días), le manda UN correo y lo marca
//      como avisado para no repetirlo.
//
// CLAVES: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / CRON_SECRET / BREVO_API_KEY /
//   CORREO_REMITENTE / CORREO_REMITENTE_NOMBRE / CORREO_RESPUESTAS
// DESPLIEGUE:
//   supabase functions deploy natacion-form-sync --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const CRON_SECRET = (Deno.env.get("CRON_SECRET") ?? "").trim();
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const DESTINO = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const PANEL = "https://atletismoapolana.com/portal/natacion-solicitudes/";

type Aviso = {
  id: string; que: "prueba" | "revisar" | "probo" | "plazo"; origen: string; nombre: string;
  nacimiento?: string | null; pide?: string | null; motivo?: string | null; franjas?: string | null;
  fecha_prueba?: string | null; vino_el?: string | null; espera_hasta?: string | null;
};

function json(cuerpo: unknown, estado = 200): Response {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: { "Content-Type": "application/json; charset=utf-8" } });
}
function iguales(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a), eb = new TextEncoder().encode(b);
  let dif = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) dif |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return dif === 0;
}
function esc(s: unknown): string {
  return String(s ?? "").replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m] as string));
}
function bonito(n: string): string {
  const s = String(n ?? "").trim();
  if (!s || s !== s.toUpperCase()) return s;
  return s.toLowerCase().split(/\s+/).map((w, i) => (i && /^(de|del|la|las|los|y)$/.test(w)) ? w : w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
}
function dia(iso?: string | null): string {
  if (!iso) return "";
  return new Intl.DateTimeFormat("es-ES", { timeZone: "UTC", weekday: "long", day: "numeric", month: "long" })
    .format(new Date(`${iso.slice(0, 10)}T12:00:00Z`));
}

async function rpc(nombre: string, cuerpo: unknown): Promise<{ ok: boolean; estado: number; datos: any; texto: string }> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${nombre}`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(cuerpo ?? {}),
    signal: AbortSignal.timeout(90000),
  });
  const texto = await r.text();
  let datos: any = null;
  try { datos = JSON.parse(texto); } catch { /* texto */ }
  return { ok: r.ok, estado: r.status, datos, texto };
}

function bloque(titulo: string, color: string, filas: string[]): string {
  if (!filas.length) return "";
  return `
      <tr><td style="padding:14px 24px 4px 24px"><p style="margin:0;font-size:14px;font-weight:700;color:${color}">${esc(titulo)}</p></td></tr>
      <tr><td style="padding:4px 24px 8px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">${filas.join("")}</table>
      </td></tr>`;
}
function fila(principal: string, detalle: string): string {
  return `<tr><td style="padding:10px 16px;border-bottom:1px solid #e7dcc4;font-size:14px;line-height:1.45"><b style="color:#26374B">${principal}</b>${detalle ? `<br><span style="color:#6E6656;font-size:12.5px">${detalle}</span>` : ""}</td></tr>`;
}
function quien(a: Aviso): string {
  const anio = a.nacimiento ? ` (${String(a.nacimiento).slice(0, 4)})` : "";
  return `${esc(bonito(a.nombre))}${anio} · ${esc(a.origen === "Máster" ? "máster" : "escuela")}`;
}

function correoHtml(av: Aviso[]): string {
  const de = (q: Aviso["que"]) => av.filter((a) => a.que === q);
  const prueba = de("prueba"), revisar = de("revisar"), probo = de("probo"), plazo = de("plazo");
  const partes = [
    prueba.length ? `${prueba.length} de prueba` : "",
    revisar.length ? `${revisar.length} por revisar` : "",
    probo.length ? `${probo.length} ya ${probo.length === 1 ? "probó" : "probaron"}` : "",
    plazo.length ? `${plazo.length} ${plazo.length === 1 ? "cumple" : "cumplen"} 15 días` : "",
  ].filter(Boolean);
  const hoy = new Intl.DateTimeFormat("es-ES", { timeZone: "Europe/Madrid", weekday: "long", day: "numeric", month: "long" }).format(new Date());
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Solicitudes de natación</td></tr>
      <tr><td style="padding:22px 24px 4px 24px">
        <p style="margin:0 0 6px;font-size:17px;font-weight:700;color:#26374B">Natación: ${esc(partes.join(" · "))}</p>
        <p style="margin:0;color:#71717a;font-size:13px">${esc(hoy)} · formularios de la escuela y del máster</p>
      </td></tr>
      ${bloque("De prueba: mándales el mensaje con el día", "#1E7A3D", prueba.map((a) => fila(quien(a),
        esc([a.franjas || "", a.fecha_prueba ? "prueba el " + dia(a.fecha_prueba) : ""].filter(Boolean).join(" · ")))))}
      ${bloque("Por revisar: dales grupo o ponlos en espera", "#8A5307", revisar.map((a) => fila(quien(a),
        esc([a.motivo || "", a.pide ? "Pide: " + a.pide : ""].filter(Boolean).join(" · ")))))}
      ${bloque("Ya vinieron a su clase de prueba: pregúntales si se quedan", "#2F6FA8", probo.map((a) => fila(quien(a),
        esc([a.franjas || "", a.vino_el ? "vino el " + dia(a.vino_el) : ""].filter(Boolean).join(" · ")))))}
      ${bloque("Cumplen los 15 días de espera: ¿hay hueco ya?", "#B3261E", plazo.map((a) => fila(quien(a),
        esc([a.pide ? "Pide: " + a.pide : "", a.espera_hasta ? "plazo: " + dia(a.espera_hasta) : ""].filter(Boolean).join(" · ")))))}
      <tr><td style="padding:14px 24px 24px 24px">
        <a href="${PANEL}" style="display:inline-block;background-color:#26374B;color:#ffffff;text-decoration:none;font-weight:700;font-size:14px;padding:11px 18px;border-radius:10px">Abrir las solicitudes</a>
        <p style="margin:14px 0 0;color:#a1a1aa;font-size:11.5px">Cada cosa se avisa una sola vez. Los mensajes para las familias están en la pantalla, listos para WhatsApp.</p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;
}

async function enviarCorreo(av: Aviso[]): Promise<boolean> {
  if (!BREVO_API_KEY || !av.length) return false;
  const texto = av.map((a) => `- ${a.que.toUpperCase()}: ${bonito(a.nombre)} (${a.origen})${a.motivo ? " · " + a.motivo : ""}`).join("\n")
    + `\n\n${PANEL}`;
  try {
    const res = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        to: [{ email: DESTINO }],
        subject: `Natación · ${av.length} solicitud${av.length === 1 ? "" : "es"} que mirar · Apolana`,
        htmlContent: correoHtml(av),
        textContent: texto,
      }),
      signal: AbortSignal.timeout(20000),
    });
    if (!res.ok) console.error("[natacion-form-sync] Brevo:", res.status, await res.text().catch(() => ""));
    return res.ok;
  } catch (e) {
    console.error("[natacion-form-sync] correo:", e);
    return false;
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ error: "metodo" }, 405);
  if (!SUPABASE_URL || !SERVICE_KEY) return json({ error: "config" }, 503);
  const token = (req.headers.get("x-sync-token") ?? "").trim();
  const sec = (req.headers.get("x-cron-secret") ?? "").trim();
  const esCron = !!sec && !!CRON_SECRET && iguales(sec, CRON_SECRET);
  if (!token && !esCron) return json({ error: "token" }, 401);

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }

  // 1 · filas del Excel (solo el script de Google)
  let ingesta: unknown = null;
  if (token) {
    const filas = Array.isArray(cuerpo.filas) ? cuerpo.filas : [];
    if (filas.length > 5000) return json({ error: "demasiadas filas" }, 413);
    const aplicar = cuerpo.aplicar !== false;
    const r = await rpc("natacion_form_sincronizar", { p_token: token, p_filas: filas, p_aplicar: aplicar });
    if (!r.ok) {
      if (/token/.test(r.texto)) return json({ error: "token" }, 401);
      console.error("[natacion-form-sync] sincronizar:", r.estado, r.texto.slice(0, 400));
      return json({ error: "base", detalle: r.texto.slice(0, 300) }, 500);
    }
    ingesta = r.datos;
    if (!aplicar) return json({ ingesta, ensayo: true });
  }

  // 2 · repaso: vinieron a la prueba, ya tienen cuota, ya no están
  const rv = await rpc("natacion_solicitudes_revisar", {});
  if (!rv.ok) console.error("[natacion-form-sync] revisar:", rv.estado, rv.texto.slice(0, 300));

  // 3 · aviso a Andrés de lo que aún no sabe
  const ra = await rpc("natacion_solicitudes_avisos", {});
  const avisos: Aviso[] = ra.ok && Array.isArray(ra.datos) ? ra.datos : [];
  let correo = false;
  if (avisos.length) {
    correo = await enviarCorreo(avisos);
    if (correo) {
      const rm = await rpc("natacion_solicitudes_marcar_avisadas", { p_items: avisos.map((a) => ({ id: a.id, que: a.que })) });
      if (!rm.ok) console.error("[natacion-form-sync] marcar:", rm.estado, rm.texto.slice(0, 300));
    }
  }
  return json({ ingesta, repaso: rv.datos, avisos: avisos.length, correo_enviado: correo });
});
