// ============================================================
// natacion-espera-correo · correo a la LISTA DE ESPERA de natación (mig 415)
// ------------------------------------------------------------
// Cuando alguien marca «no voy» y se libera un hueco, la base (natacion_espera_avisar)
// ya avisaba dentro de la app y por push. Pero quien no tiene las notificaciones
// activadas no se enteraba (caso de Silvia, 20-oct). Ahora además se le manda un
// CORREO a cada uno de la lista: «el primero que reserve se lo queda».
// La llama la base con pg_net (cron_llamar_edge) y la cabecera x-cron-secret.
//
//   POST { franja_id, fecha 'YYYY-MM-DD', perfil_ids: [uuid…] }            → «se ha liberado un hueco»
//   POST { tipo: 'apuntado', franja_id, perfil_ids: [uuid] }               → «estás en la lista de espera»
//        (Andrés, 21-oct: un correo al apuntarse y otro cuando queda vacante; nada de SMS)
//
// CLAVES: CRON_SECRET / SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / BREVO_API_KEY /
//   CORREO_REMITENTE / CORREO_REMITENTE_NOMBRE / CORREO_RESPUESTAS
// DESPLIEGUE: supabase functions deploy natacion-espera-correo --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const CRON_SECRET = (Deno.env.get("CRON_SECRET") ?? "").trim();
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const RESPUESTAS = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const APP = "https://atletismoapolana.com/portal/";
const DIAS = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"];
const MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];

function json(c: unknown, s = 200) { return new Response(JSON.stringify(c), { status: s, headers: { "Content-Type": "application/json" } }); }
function iguales(a: string, b: string) {
  const ea = new TextEncoder().encode(a), eb = new TextEncoder().encode(b);
  let d = ea.length ^ eb.length; for (let i = 0; i < Math.max(ea.length, eb.length); i++) d |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return d === 0;
}
function esc(s: unknown) { return String(s ?? "").replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m] as string)); }
async function rest(ruta: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
  return r.ok ? await r.json() : [];
}
function pila(n: string) {
  const p = String(n ?? "").trim().split(/\s+/)[0] ?? "";
  return p ? p.charAt(0).toUpperCase() + p.slice(1).toLowerCase() : "";
}

function htmlApuntado(nombre: string, cuando: string, franja: string) {
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Natación</td></tr>
      <tr><td style="padding:22px 24px 6px 24px">
        <p style="margin:0 0 8px;font-size:17px;font-weight:700;color:#26374B">${nombre ? "¡Hola, " + esc(nombre) + "! " : ""}Ya estás en la lista de espera ✓</p>
        <p style="margin:0;color:#3f3f46;font-size:15px;line-height:1.5">Te has apuntado para que te avisemos si queda un hueco en:</p>
      </td></tr>
      <tr><td style="padding:12px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:14px 16px;font-size:16px;line-height:1.5;color:#26374B"><b>${esc(cuando)}</b><br>${esc(franja)}</td></tr>
        </table>
      </td></tr>
      <tr><td style="padding:4px 24px 24px 24px">
        <p style="margin:0 0 10px;color:#3f3f46;font-size:15px;line-height:1.5">En cuanto alguien deje su plaza libre ese día, <b>te llegará otro correo</b>. Avisamos a todos los de la lista a la vez: <b>el primero que lo reserve se lo queda</b>.</p>
        <p style="margin:0;color:#71717a;font-size:12.5px;line-height:1.5">Si ya no te interesa, quítate de la lista desde la página de natación.</p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;
}

function html(nombre: string, cuando: string, franja: string) {
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Natación</td></tr>
      <tr><td style="padding:22px 24px 6px 24px">
        <p style="margin:0 0 8px;font-size:17px;font-weight:700;color:#26374B">${nombre ? "¡Hola, " + esc(nombre) + "! " : ""}Se ha liberado un hueco 🏊</p>
        <p style="margin:0;color:#3f3f46;font-size:15px;line-height:1.5">Estás en la lista de espera y acaba de quedar sitio:</p>
      </td></tr>
      <tr><td style="padding:12px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:14px 16px;font-size:16px;line-height:1.5;color:#26374B"><b>${esc(cuando)}</b><br>${esc(franja)}</td></tr>
        </table>
      </td></tr>
      <tr><td style="padding:4px 24px 8px 24px">
        <p style="margin:0 0 14px;color:#3f3f46;font-size:15px;line-height:1.5"><b>El primero que lo reserve se lo queda.</b> Entra en la app y resérvalo desde tu natación.</p>
        <a href="${APP}" style="display:inline-block;background-color:#2F6FA8;color:#ffffff;text-decoration:none;font-weight:700;font-size:15px;padding:12px 20px;border-radius:10px">Reservar el hueco</a>
      </td></tr>
      <tr><td style="padding:14px 24px 24px 24px">
        <p style="margin:0;color:#71717a;font-size:12.5px;line-height:1.5">Te llega porque te apuntaste a «Avísame si se libera» en esta franja. Si ya no te interesa, quítate de la lista desde la página de natación.</p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "metodo" }, 405);
  if (!SUPABASE_URL || !SERVICE_KEY || !CRON_SECRET || !BREVO_API_KEY) return json({ error: "config" }, 503);
  const s = (req.headers.get("x-cron-secret") ?? "").trim();
  if (!s || !iguales(s, CRON_SECRET)) return json({ error: "secreto" }, 401);
  let b: Record<string, unknown> = {};
  try { b = await req.json(); } catch { return json({ error: "json" }, 400); }
  const franja = String(b.franja_id ?? ""), fecha = String(b.fecha ?? "");
  const apuntado = b.tipo === "apuntado";
  const ids = (Array.isArray(b.perfil_ids) ? b.perfil_ids : []).map(String).filter((x) => /^[0-9a-f-]{36}$/.test(x)).slice(0, 50);
  if (!/^[0-9a-f-]{36}$/.test(franja) || (!apuntado && !/^\d{4}-\d{2}-\d{2}$/.test(fecha)) || !ids.length) return json({ error: "datos" }, 400);

  const [f] = await rest(`natacion_franjas?select=dia,hora,grupo&id=eq.${franja}`);
  if (!f) return json({ error: "franja" }, 404);
  let cuando: string;
  if (apuntado) {
    const dn = DIAS[Number(f.dia) % 7] ?? "";
    cuando = `Los ${dn}${dn.endsWith("s") ? "" : "s"} · ${String(f.hora).slice(0, 5)}`;
  } else {
    const [y, m, d] = fecha.split("-").map(Number);
    const dt = new Date(Date.UTC(y, m - 1, d));
    cuando = `${DIAS[dt.getUTCDay()].charAt(0).toUpperCase() + DIAS[dt.getUTCDay()].slice(1)} ${d} de ${MESES[m - 1]} · ${String(f.hora).slice(0, 5)}`;
  }
  const nomFranja = `${f.grupo || "Natación"} · Piscina Vía Parque`;

  const perfiles = await rest(`perfiles?select=id,nombre,email&id=in.(${ids.join(",")})`);
  let enviados = 0;
  for (const p of perfiles) {
    const email = String(p.email ?? "").trim();
    if (!email || !email.includes("@")) continue;
    try {
      const r = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({
          sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
          replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS },
          to: [{ email }],
          subject: apuntado ? `Estás en la lista de espera de natación · ${cuando}` : `Se ha liberado un hueco en natación · ${cuando}`,
          htmlContent: apuntado ? htmlApuntado(pila(p.nombre), cuando, nomFranja) : html(pila(p.nombre), cuando, nomFranja),
          textContent: apuntado
            ? `${pila(p.nombre) ? "¡Hola, " + pila(p.nombre) + "! " : ""}Ya estás en la lista de espera de natación: ${cuando} (${nomFranja}). Cuando quede un hueco te llegará otro correo; el primero que lo reserve se lo queda.`
            : `${pila(p.nombre) ? "¡Hola, " + pila(p.nombre) + "! " : ""}Se ha liberado un hueco en natación: ${cuando} (${nomFranja}). El primero que lo reserve se lo queda. Resérvalo en la app: ${APP}`,
        }),
        signal: AbortSignal.timeout(15000),
      });
      if (r.ok) enviados++; else console.error("[natacion-espera-correo] Brevo", r.status, await r.text().catch(() => ""));
    } catch (e) { console.error("[natacion-espera-correo]", e); }
  }
  return json({ ok: true, enviados });
});
