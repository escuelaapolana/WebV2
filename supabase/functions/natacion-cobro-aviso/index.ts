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
// MIG 431 · «MES A MES» (sin tarjeta guardada): cada mañana además
//   1) crea el recibo del periodo que empieza (natacion_recibos_generar);
//   2) manda el correo «ya puedes pagar» con el botón /pagar/?t=… a los
//      recibos pendientes que vencen en ≤ 4 días y aún no se avisaron
//      (pagos.aviso_pago_en): sale el día 1 para pagar antes del 5;
//   3) si a los 3 días de vencer sigue sin pagar, UN recordatorio
//      (pagos.recordatorio_pago_en).
// body { prueba_mes: true, a: "correo@…" } → un ejemplo de ese correo.
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

// Correo de un recibo «mes a mes»: botón para pagar ese mes.
function correoMes(x: { nadador: string; concepto: string; importe: number; vence: string; enlace: string; recordatorio: boolean }) {
  const [, m, d] = x.vence.split("-").map(Number);
  const dia = `${d} de ${MESES[m - 1]}`;
  const fila = (k: string, v: string) => `<tr><td style="padding:7px 12px;color:#71717a;white-space:nowrap;font-size:14px">${escH(k)}</td><td style="padding:7px 12px;color:#18181b;font-size:15px"><b>${escH(v)}</b></td></tr>`;
  const titulo = x.recordatorio ? "Recordatorio: cuota de natación pendiente" : "Ya puedes pagar la cuota de natación";
  const intro = x.recordatorio
    ? `Te recordamos que la cuota de natación de <b>${escH(x.nadador)}</b> sigue pendiente (vencía el ${escH(dia)}).`
    : `Ya puedes pagar la cuota de natación de <b>${escH(x.nadador)}</b>. Es un momento: pulsa el botón y paga con tarjeta, <b>antes del ${escH(dia)}</b>.`;
  const html = `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Natación</td></tr>
      <tr><td style="padding:22px 24px 6px 24px">
        <p style="margin:0 0 10px;font-size:17px;font-weight:700;color:#26374B">${escH(titulo)}</p>
        <p style="margin:0 0 6px;color:#3f3f46;line-height:1.6">Hola. ${intro}</p>
      </td></tr>
      <tr><td style="padding:6px 24px 6px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          ${fila("Nadador/a", x.nadador)}${fila("Concepto", x.concepto)}${fila("Importe", eur(x.importe))}${fila("Pagar antes del", dia)}
        </table></td></tr>
      <tr><td align="center" style="padding:18px 24px 6px 24px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">
            <a href="${escH(x.enlace)}" style="display:inline-block;padding:14px 30px;color:#ffffff;text-decoration:none;font-weight:700;font-size:16px">Pagar ${escH(eur(x.importe))} →</a>
          </td></tr></table>
      </td></tr>
      <tr><td style="padding:12px 24px 22px 24px">
        <p style="margin:0;color:#71717a;font-size:13px;line-height:1.5">Se paga en la pantalla segura de Stripe y la tarjeta no se guarda. Si ya lo has pagado, ignora este correo. ¿Dudas? Contesta a este correo.</p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;
  const texto = `${titulo}. ${intro.replace(/<\/?b>/g, "")} Importe: ${eur(x.importe)} (${x.concepto}). Pagar: ${x.enlace}`;
  return { html, texto, asunto: `${x.recordatorio ? "Recordatorio · " : ""}Cuota de natación · ${x.concepto.split(" · ").slice(-1)[0]} · ${eur(x.importe)}` };
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
  // --- 431 · ejemplo del correo «mes a mes» ---
  if (cuerpo.prueba_mes === true) {
    const a = String(cuerpo.a ?? "").trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(a)) return json({ error: "falta 'a'" }, 400);
    const ok = await enviar(a, correoMes({ nadador: "Nombre del nadador", concepto: "Cuota de natación máster · noviembre 2026",
      importe: 4500, vence: "2026-11-05", enlace: "https://atletismoapolana.com/pagar/?t=ejemplo", recordatorio: false }));
    return json({ ok, prueba_mes: true, a });
  }
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

  // --- 431 · «MES A MES»: recibos del periodo + aviso con enlace + recordatorio ---
  const mes: any[] = [];
  const rG = await rest("rpc/natacion_recibos_generar", { method: "POST", body: "{}" });
  if (!rG.ok) console.error("[natacion-cobro-aviso] natacion_recibos_generar:", JSON.stringify(rG.datos));
  const rM = await rest("pagos?select=id,concepto,importe,fecha_vencimiento,token_pago,aviso_pago_en,recordatorio_pago_en,cuota_entreno_id," +
    "cuotas_entreno(nombre,apellidos,email,metodo,suscripcion_estado)&cuota_entreno_id=not.is.null&estado=neq.pagado&anulado=is.false&token_pago=not.is.null");
  for (const p of (Array.isArray(rM.datos) ? rM.datos : [])) {
    const q = p.cuotas_entreno;
    if (!q || q.metodo !== "mes_a_mes" || q.suscripcion_estado === "cancelada" || !p.fecha_vencimiento) continue;
    const nadador = capital(`${q.nombre ?? ""} ${q.apellidos ?? ""}`.trim());
    const faltan = diasEntre(hoy, String(p.fecha_vencimiento));
    const enlace = `https://atletismoapolana.com/pagar/?t=${p.token_pago}`;
    let tipo: "aviso" | "recordatorio" | null = null;
    if (!p.aviso_pago_en && faltan <= 4) tipo = "aviso";
    else if (p.aviso_pago_en && !p.recordatorio_pago_en && faltan <= -3) tipo = "recordatorio";
    if (!tipo) continue;
    if (!q.email) { mes.push({ nadador, error: "sin correo" }); continue; }
    const ok = await enviar(String(q.email), correoMes({ nadador, concepto: p.concepto, importe: Math.round(Number(p.importe) * 100),
      vence: String(p.fecha_vencimiento), enlace, recordatorio: tipo === "recordatorio" }));
    if (ok) await rest(`pagos?id=eq.${p.id}`, { method: "PATCH", headers: { Prefer: "return=minimal" },
      body: JSON.stringify(tipo === "aviso" ? { aviso_pago_en: new Date().toISOString() } : { recordatorio_pago_en: new Date().toISOString() }) });
    mes.push({ nadador, concepto: p.concepto, tipo, enviado: ok });
  }
  if (mes.length) salida.push({ mes_a_mes: mes });
  console.log("[natacion-cobro-aviso]", hoy, JSON.stringify(salida));
  return json({ ok: true, hoy, cuotas: salida });
});
