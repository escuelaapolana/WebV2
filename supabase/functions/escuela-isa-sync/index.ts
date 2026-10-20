// ============================================================
// escuela-isa-sync · comprobación diaria de «BUENO ISA» (mig 402)
// ------------------------------------------------------------
// Un script de Google (Apps Script, en la cuenta escuelaapolana@gmail.com)
// lee cada día a las 12:30 las hojas de Isa —Inscripción (BUENO ISA),
// Renovación (BUENA ISA) y Escuelas municipales (BUENA ISA + Respuestas)—
// con los COLORES de cada fila y las manda aquí:
//
//   POST { filas: [{hoja, fila, nombre, ap1, ap2, nacimiento, colores[], …}],
//          aplicar?: boolean (por defecto true), probar_correo?: boolean }
//   cabecera  x-sync-token: <token>   (el mismo que guarda Vault como
//             'escuela_sync_token'; lo comprueba la propia función SQL)
//
// La regla vive en la base (escuela_isa_sincronizar): de prueba → confirmado,
// bajas fuera de los grupos, fichas nuevas sin grupo, y lo dudoso se avisa sin
// tocar. Aquí solo se llama y, si ha cambiado algo o hay dudas, se manda UN
// correo con el diseño del club a Andrés.
//
// CLAVES: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / BREVO_API_KEY /
//   CORREO_REMITENTE / CORREO_REMITENTE_NOMBRE / CORREO_RESPUESTAS
// DESPLIEGUE:
//   supabase functions deploy escuela-isa-sync --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const DESTINO = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const PANEL = "https://atletismoapolana.com/admin/escuela-grupos/";

type Item = { tipo?: string; nombre: string; de?: string; grupos?: string[]; estado?: string; hoja?: string; fila?: number; nacimiento?: string; turno?: string };
type Res = { ok: boolean; aplicado: boolean; filas: number; cambios: Item[]; nuevos: Item[]; dudas: Item[] };

function json(cuerpo: unknown, estado = 200): Response {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: { "Content-Type": "application/json; charset=utf-8" } });
}
function esc(s: unknown): string {
  return String(s ?? "").replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m] as string));
}
function bonito(n: string): string {
  const s = String(n ?? "").trim();
  if (!s || s !== s.toUpperCase()) return s;
  return s.toLowerCase().split(/\s+/).map((w, i) => (i && /^(de|del|la|las|los|y)$/.test(w)) ? w : w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
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

function correoHtml(r: Res, prueba: boolean): string {
  const fecha = new Intl.DateTimeFormat("es-ES", { timeZone: "Europe/Madrid", weekday: "long", day: "numeric", month: "long" }).format(new Date());
  const confirmados = r.cambios.filter((c) => c.tipo === "confirmado");
  const bajas = r.cambios.filter((c) => c.tipo === "baja");
  const partes = [
    confirmados.length ? `${confirmados.length} confirmado${confirmados.length === 1 ? "" : "s"}` : "",
    bajas.length ? `${bajas.length} baja${bajas.length === 1 ? "" : "s"}` : "",
    r.nuevos.length ? `${r.nuevos.length} nuevo${r.nuevos.length === 1 ? "" : "s"}` : "",
    r.dudas.length ? `${r.dudas.length} por revisar` : "",
  ].filter(Boolean);
  const titular = partes.length ? `Escuela: ${partes.join(" · ")}` : "Escuela: sin cambios (correo de prueba)";
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Escuela (BUENO ISA)</td></tr>
      <tr><td style="padding:22px 24px 4px 24px">
        <p style="margin:0 0 6px;font-size:17px;font-weight:700;color:#26374B">${esc(titular)}</p>
        <p style="margin:0;color:#71717a;font-size:13px">${esc(fecha)} · comprobación de las 12:30${prueba ? " · prueba" : ""}${r.aplicado ? "" : " · NO aplicado (solo simulación)"}</p>
      </td></tr>
      ${bloque("Confirmados (ya no salen «de prueba»)", "#1E7A3D", confirmados.map((c) => fila(esc(bonito(c.nombre)), "")))}
      ${bloque("Bajas (fuera de sus grupos)", "#B3261E", bajas.map((c) => fila(esc(bonito(c.nombre)), (c.grupos && c.grupos.length) ? "Estaba en " + esc(c.grupos.join(", ")) : "")))}
      ${bloque("Nuevos sin grupo (asígnalos en el panel)", "#2F6FA8", r.nuevos.map((c) => fila(esc(c.nombre) + (c.estado === "prueba" ? " · de prueba" : ""), esc([c.nacimiento ? "nacido/a " + c.nacimiento.slice(0, 4) : "", c.turno || ""].filter(Boolean).join(" · ")))))}
      ${bloque("Por revisar (no se ha tocado)", "#8A5307", r.dudas.map((c) => fila(esc(bonito(c.nombre)), esc((c.tipo || "") + (c.de ? " · " + c.de : "")))))}
      <tr><td style="padding:14px 24px 24px 24px">
        <a href="${PANEL}" style="display:inline-block;background-color:#26374B;color:#ffffff;text-decoration:none;font-weight:700;font-size:14px;padding:11px 18px;border-radius:10px">Abrir los grupos de la escuela</a>
        <p style="margin:14px 0 0;color:#a1a1aa;font-size:11.5px">${r.filas} filas leídas de las hojas de Isa. Si no cambia nada, no llega correo.</p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;
}

async function enviarCorreo(r: Res, prueba: boolean): Promise<boolean> {
  if (!BREVO_API_KEY) return false;
  const n = r.cambios.length + r.nuevos.length + r.dudas.length;
  const asunto = n ? `Escuela · ${n} cambio${n === 1 ? "" : "s"} en BUENO ISA · Apolana` : "Prueba · escuela (BUENO ISA) · Apolana";
  const texto = [
    ...r.cambios.map((c) => `- ${c.tipo === "baja" ? "BAJA" : "Confirmado"}: ${bonito(c.nombre)}`),
    ...r.nuevos.map((c) => `- Nuevo sin grupo: ${c.nombre} (${c.turno ?? ""})`),
    ...r.dudas.map((c) => `- Revisar: ${bonito(c.nombre)} · ${c.tipo}`),
  ].join("\n") || "Sin cambios.";
  try {
    const res = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        to: [{ email: DESTINO }],
        subject: asunto,
        htmlContent: correoHtml(r, prueba),
        textContent: texto,
      }),
      signal: AbortSignal.timeout(20000),
    });
    if (!res.ok) console.error("[escuela-isa-sync] Brevo:", res.status, await res.text().catch(() => ""));
    return res.ok;
  } catch (e) {
    console.error("[escuela-isa-sync] correo:", e);
    return false;
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ error: "metodo" }, 405);
  if (!SUPABASE_URL || !SERVICE_KEY) return json({ error: "config" }, 503);
  const token = (req.headers.get("x-sync-token") ?? "").trim();
  if (!token) return json({ error: "token" }, 401);

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { return json({ error: "json" }, 400); }
  const filas = Array.isArray(cuerpo.filas) ? cuerpo.filas : null;
  if (!filas || !filas.length) return json({ error: "sin filas" }, 400);
  if (filas.length > 3000) return json({ error: "demasiadas filas" }, 413);
  const aplicar = cuerpo.aplicar !== false;
  const probarCorreo = cuerpo.probar_correo === true;

  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/escuela_isa_sincronizar`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ p_token: token, p_filas: filas, p_aplicar: aplicar }),
    signal: AbortSignal.timeout(60000),
  });
  const t = await r.text();
  if (!r.ok) {
    if (/token/.test(t)) return json({ error: "token" }, 401);
    console.error("[escuela-isa-sync] rpc:", r.status, t.slice(0, 400));
    return json({ error: "base", detalle: t.slice(0, 300) }, 500);
  }
  const res = JSON.parse(t) as Res;
  // Las dudas se repiten cada día hasta que alguien las resuelve: solo provocan
  // correo si son NUEVAS respecto a la comprobación aplicada anterior.
  let dudasNuevas = res.dudas.length;
  try {
    const rl = await fetch(`${SUPABASE_URL}/rest/v1/escuela_sync_log?select=resumen&aplicado=eq.true&order=id.desc&offset=1&limit=1`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    const prev = rl.ok ? await rl.json() : [];
    if (Array.isArray(prev) && prev[0]?.resumen?.dudas) {
      const antes = new Set((prev[0].resumen.dudas as Item[]).map((d) => `${d.tipo}|${d.nombre}`));
      dudasNuevas = res.dudas.filter((d) => !antes.has(`${d.tipo}|${d.nombre}`)).length;
    }
  } catch { /* si falla, se avisa de todas */ }
  const hay = res.cambios.length + res.nuevos.length + dudasNuevas > 0;
  const correo = (hay || probarCorreo) ? await enviarCorreo(res, probarCorreo) : false;
  return json({ ...res, correo_enviado: correo });
});
