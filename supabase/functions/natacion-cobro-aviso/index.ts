// ============================================================
// natacion-cobro-aviso · Correo a la familia ANTES de cada cobro de natación
// ------------------------------------------------------------
// Mig 429 (22-oct-2026). Mario: «les debería llegar un aviso al mail de lo que
// les pasarán el día 5, como en SportMember».
//   · Cada mañana (pg_cron, 9:00 Madrid) mira las cuotas de natación
//     domiciliadas y le PREGUNTA A STRIPE cuándo es el próximo cobro y de
//     cuánto (no se fía de fechas guardadas). Si cae dentro de 1-3 días y aún no
//     se avisó de ESE cobro (cuotas_entreno.aviso_cobro_para), manda el correo.
//     Para el cobro del día 5 sale normalmente el día 2.
//   · No avisa si la cuota se para antes de ese cobro (cancel_at).
// body {}                                   → la pasada normal (cron).
// body { prueba: true, a: "correo@…" }      → manda UN ejemplo (la primera
//                                              cuota con cobro futuro) a ese
//                                              correo y no marca nada.
// Cabecera x-cron-secret obligatoria (cron_llamar_edge).
//
//   supabase functions deploy natacion-cobro-aviso --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";
const CRON_SECRET = (Deno.env.get("CRON_SECRET") ?? "").trim();
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const RESPUESTAS = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();

const MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
const MES3 = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

function iguales(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a), eb = new TextEncoder().encode(b);
  let dif = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) dif |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return dif === 0;
}
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { "Content-Type": "application/json" } });
const escH = (v: unknown) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
const ymdMadrid = (u: number) => new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(u * 1000));
const eur = (cent: number) => (cent / 100).toLocaleString("es-ES", { minimumFractionDigits: cent % 100 ? 2 : 0, maximumFractionDigits: 2 }) + " €";
const capital = (s: string) => String(s || "").toLowerCase().replace(/(^|[\s-])(\p{L})/gu, (_, a, b) => a + b.toUpperCase());
const diasEntre = (a: string, b: string) => Math.round((Date.parse(b + "T12:00:00Z") - Date.parse(a + "T12:00:00Z")) / 86400000);

async function rest(ruta: string, init: RequestInit = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...init, headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
  });
  const t = await r.text();
  try { return { ok: r.ok, datos: t ? JSON.parse(t) : null }; } catch { return { ok: r.ok, datos: t }; }
}
async function sub(id: string) {
  const r = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(id)}`, { headers: { Authorization: `Bearer ${STRIPE_KEY}` } });
  return r.ok ? await r.json().catch(() => null) : null;
}
function proximoDe(s: any): number {
  if (s?.status === "trialing" && Number(s.trial_end) > 0) return Number(s.trial_end);
  return Number(s?.current_period_end ?? s?.items?.data?.[0]?.current_period_end ?? 0);
}

// Qué periodo paga el cobro de esa fecha (mensual: «noviembre de 2026»; trimestral: «ene-mar 2027»).
function periodo(fecha: string, per: string | null): string {
  const [y, m] = fecha.split("-").map(Number);
  if (per === "mensual") return `${MESES[m - 1]} de ${y}`;
  const n = per === "anual" ? 12 : 3;
  const mf = ((m - 1 + n - 1) % 12) + 1, yf = y + Math.floor((m - 1 + n - 1) / 12);
  return yf === y ? `${MES3[m - 1]}-${MES3[mf - 1]} ${y}` : `${MES3[m - 1]} ${y}-${MES3[mf - 1]} ${yf}`;
}

function correo(x: { nadador: string; fecha: string; importe: number; periodo: string; concepto: string; tarjeta: boolean; fin: string | null }) {
  const [y, m, d] = x.fecha.split("-").map(Number);
  const dia = `${d} de ${MESES[m - 1]}`;
  const como = x.tarjeta ? "con la tarjeta que guardaste" : "por domiciliación en tu cuenta";
  const fila = (k: string, v: string) => `<tr><td style="padding:7px 12px;color:#71717a;white-space:nowrap;font-size:14px">${escH(k)}</td><td style="padding:7px 12px;color:#18181b;font-size:15px"><b>${escH(v)}</b></td></tr>`;
  const html = `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Natación</td></tr>
      <tr><td style="padding:22px 24px 6px 24px">
        <p style="margin:0 0 10px;font-size:17px;font-weight:700;color:#26374B">Aviso de cobro: el ${escH(dia)}</p>
        <p style="margin:0 0 6px;color:#3f3f46;line-height:1.6">Hola. Te avisamos de que el <b>${escH(dia)}</b> se cobrará ${escH(como)} la cuota de natación de <b>${escH(x.nadador)}</b>:</p>
      </td></tr>
      <tr><td style="padding:6px 24px 6px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          ${fila("Nadador/a", x.nadador)}${fila("Importe", eur(x.importe))}${fila("Corresponde a", x.periodo)}${fila("Fecha del cobro", `${dia} de ${y}`)}
        </table></td></tr>
      <tr><td style="padding:12px 24px 22px 24px">
        <p style="margin:0 0 8px;color:#3f3f46;line-height:1.6"><b>No tienes que hacer nada:</b> se cobra solo.${x.fin ? ` La cuota se para sola el ${escH(x.fin)}.` : ""}</p>
        <p style="margin:0;color:#71717a;font-size:13px;line-height:1.5">Si algo no cuadra o quieres cambiar algo, contesta a este correo y lo miramos.</p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;
  const texto = `Aviso de cobro: el ${dia} se cobrará ${como} la cuota de natación de ${x.nadador}: ${eur(x.importe)} (${x.periodo}). No tienes que hacer nada: se cobra solo. Si algo no cuadra, contesta a este correo.`;
  return { html, texto, asunto: `Aviso de cobro · natación ${x.periodo} · ${eur(x.importe)}` };
}

async function enviar(a: string, c: { html: string; texto: string; asunto: string }) {
  const r = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({
      sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
      to: [{ email: a }], replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS },
      subject: c.asunto, htmlContent: c.html, textContent: c.texto,
    }),
    signal: AbortSignal.timeout(20000),
  });
  if (!r.ok) console.error("[natacion-cobro-aviso] Brevo:", r.status, await r.text().catch(() => ""));
  return r.ok;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "metodo" }, 405);
  if (!SUPABASE_URL || !SERVICE_KEY || !STRIPE_KEY || !CRON_SECRET || !BREVO_API_KEY) return json({ error: "config" }, 503);
  const sec = (req.headers.get("x-cron-secret") ?? "").trim();
  if (!sec || !iguales(sec, CRON_SECRET)) return json({ error: "secreto" }, 401);
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const prueba = cuerpo.prueba === true;
  const destinoPrueba = String(cuerpo.a ?? "").trim().toLowerCase();
  if (prueba && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(destinoPrueba)) return json({ error: "falta 'a' (correo de prueba)" }, 400);

  const rA = await rest("cuotas_entreno?select=id,nombre,apellidos,email,periodicidad,metodo,fin,stripe_subscription_id,aviso_cobro_para" +
    "&origen=eq.natacion&stripe_subscription_id=not.is.null&suscripcion_estado=in.(activa,en_camino)");
  const cuotas: any[] = Array.isArray(rA.datos) ? rA.datos : [];
  const hoy = ymdMadrid(Math.floor(Date.now() / 1000));
  const salida: any[] = [];

  for (const q of cuotas) {
    const nadador = capital(`${q.nombre ?? ""} ${q.apellidos ?? ""}`.trim());
    const s = await sub(q.stripe_subscription_id);
    if (!s || ["canceled", "incomplete_expired"].includes(String(s.status))) { salida.push({ nadador, nada: "sin suscripción viva" }); continue; }
    const prox = proximoDe(s);
    if (!(prox > 0)) { salida.push({ nadador, nada: "sin próximo cobro" }); continue; }
    if (Number(s.cancel_at) > 0 && Number(s.cancel_at) <= prox) { salida.push({ nadador, nada: "se para antes del próximo cobro" }); continue; }
    const fecha = ymdMadrid(prox);
    const faltan = diasEntre(hoy, fecha);
    const importe = Number(s.items?.data?.[0]?.price?.unit_amount ?? 0);
    const datos = { nadador, fecha, importe, periodo: periodo(fecha, q.periodicidad), concepto: "", tarjeta: q.metodo === "tarjeta",
      fin: q.fin ? (() => { const [fy, fm, fd] = String(q.fin).split("-").map(Number); return `${fd} de ${MESES[fm - 1]} de ${fy}`; })() : null };
    if (prueba) {
      if (faltan < 1 || !(importe > 0)) continue;
      const ok = await enviar(destinoPrueba, correo(datos));
      return json({ ok, prueba: true, a: destinoPrueba, ejemplo: { ...datos, faltan } });
    }
    if (faltan < 1 || faltan > 3) { salida.push({ nadador, fecha, faltan, nada: "aún no toca" }); continue; }
    if (q.aviso_cobro_para === fecha) { salida.push({ nadador, fecha, nada: "ya avisado" }); continue; }
    if (!q.email || !(importe > 0)) { salida.push({ nadador, fecha, error: !q.email ? "sin correo" : "sin importe" }); continue; }
    const ok = await enviar(String(q.email), correo(datos));
    if (ok) await rest(`cuotas_entreno?id=eq.${encodeURIComponent(q.id)}`, {
      method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ aviso_cobro_para: fecha }),
    });
    salida.push({ nadador, fecha, enviado: ok });
  }
  if (prueba) return json({ ok: false, prueba: true, error: "no hay ninguna cuota con cobro futuro para el ejemplo" });
  console.log("[natacion-cobro-aviso]", hoy, JSON.stringify(salida));
  return json({ ok: true, hoy, cuotas: salida });
});
