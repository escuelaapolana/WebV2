// ============================================================
// cubo-pausa · el club APRUEBA «pausar un mes» la cuota del Cubo
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   La persona pide pausar un mes desde su zona (RPC cubo_pausa_solicitar,
//   mig 360). El club pulsa «Aprobar» en admin/cubo-altas y llega aquí:
//     1) Comprueba que quien llama es ADMIN (lo comprueba la base: la RPC
//        cubo_pausa_para_aprobar se llama CON SU JWT y solo deja a es_admin()).
//     2) Mira la suscripción en Stripe y, si el próximo recibo ES el del mes
//        pausado, pone `pause_collection` (behavior=void, resumes_at = día 6
//        a las 12:00 de Madrid de ese mes): Stripe genera el recibo del día 5
//        y lo ANULA solo; el día 6 vuelve a cobrar normal (el mes siguiente).
//        Si el mes pausado es más adelante (p. ej. aprueba en octubre la de
//        diciembre), NO se pausa aún —pausar ya anularía también noviembre—:
//        queda «aprobada, pendiente de Stripe» y la aplica `cubo-webhook` al
//        cobrarse el mes anterior (o el botón «Aplicar en Stripe»).
//     3) Lo apunta en la base (cubo_pausa_registrar, solo llave de servicio).
//     4) Manda el correo de confirmación (Brevo, diseño de cubo-cobro-aviso).
//
//   Acciones (cuerpo JSON):
//     { accion: "aprobar", pausa_id }  → todo lo de arriba. Si tiene cargos o
//                                        descuentos sueltos pendientes (cubo-pago)
//                                        que caerían en el recibo anulado, PARA y
//                                        lo explica (se perderían).
//     { accion: "aplicar", pausa_id }  → solo el paso 2-3 de una ya aprobada
//                                        (reserva por si el webhook no llegó)
//     { accion: "deshacer", pausa_id } → quita NUESTRA pause_collection (si ya
//                                        estaba en Stripe) y la deja «anulada»;
//                                        solo hasta el día 4 del mes pausado.
//   La regla de qué hacer en Stripe vive en ../_shared/cubo-pausa.ts (la
//   misma que usa cubo-webhook).
//   Rechazar NO pasa por aquí: es la RPC cubo_pausa_rechazar (no toca Stripe).
//
// CLAVES (secretos de Supabase; aquí no hay ninguna)
//   STRIPE_SECRET_KEY_APOLANA (real) / STRIPE_SECRET_KEY_APOLANA_TEST (prueba),
//   elegida por pagos_config.modo — NUNCA la genérica STRIPE_SECRET_KEY (Ítaka).
//   BREVO_API_KEY, CORREO_REMITENTE, CORREO_REMITENTE_NOMBRE, CORREO_RESPUESTAS,
//   CORREO_URL_BASE, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY
//
//   supabase functions deploy cubo-pausa --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

import { MESES, planificar, cargosPendientes, textoCargos } from "../_shared/cubo-pausa.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const SK_LIVE = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";
const SK_TEST = Deno.env.get("STRIPE_SECRET_KEY_APOLANA_TEST") ?? "";

const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const RESPUESTAS_EMAIL = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const URL_BASE = (Deno.env.get("CORREO_URL_BASE") ?? "https://atletismoapolana.com/").replace(/\/*$/, "/");

// Lista FIJA de webs (nunca "*"), mismo criterio que cubo-baja / cubo-pago.
const ORIGENES_OK = [
  "https://escuelaapolana.github.io",
  "https://atletismoapolana.com",
  "https://www.atletismoapolana.com",
  "http://localhost:8000",
  "http://127.0.0.1:8000",
];
function cors(o: string | null): Record<string, string> {
  const valor = o && ORIGENES_OK.includes(o) ? o : ORIGENES_OK[0];
  return {
    "Access-Control-Allow-Origin": valor,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}
function responder(cuerpo: unknown, estado: number, o: string | null): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { ...cors(o), "Content-Type": "application/json; charset=utf-8" },
  });
}

// ---- Base: como servicio, o como el usuario (su JWT) ----
async function rpc(nombre: string, cuerpo: Record<string, unknown>, jwt?: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${nombre}`, {
    method: "POST",
    headers: {
      apikey: jwt ? (ANON_KEY || SERVICE_KEY) : SERVICE_KEY,
      Authorization: `Bearer ${jwt ?? SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(cuerpo),
  });
  const t = await r.text();
  let d: any = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, estado: r.status, datos: d };
}
async function patch(ruta: string, cambios: Record<string, unknown>) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    method: "PATCH",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", Prefer: "return=minimal" },
    body: JSON.stringify(cambios),
  });
  return r.ok;
}
async function modoPagos(): Promise<string> {
  try {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/pagos_config?select=modo&id=eq.1&limit=1`,
      { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
    const f = r.ok ? await r.json() : [];
    return String(f?.[0]?.modo ?? "prueba").toLowerCase();
  } catch { return "prueba"; }
}

// ---- Stripe ----
async function stripe(key: string, ruta: string, metodo: "GET" | "POST", campos?: Record<string, string>) {
  const init: RequestInit = { method: metodo, headers: { Authorization: `Bearer ${key}` } };
  if (campos) {
    (init.headers as Record<string, string>)["Content-Type"] = "application/x-www-form-urlencoded";
    init.body = new URLSearchParams(campos).toString();
  }
  const r = await fetch(`https://api.stripe.com/v1/${ruta}`, init);
  const d = await r.json().catch(() => null);
  return { ok: r.ok, estado: r.status, datos: d as any };
}

function correoHtml(nombre: string, mesTxt: string, sigTxt: string, horario: string): string {
  const hola = nombre ? `¡Hola, ${nombre}!` : "¡Hola!";
  const enlace = `${URL_BASE}portal/`;
  // Tablas + bgcolor (atributo) para que Gmail/Outlook respeten los fondos.
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">El Cubo · Club Atletismo Apolana</td></tr>
      <tr><td style="padding:24px 24px 6px 24px">
        <p style="margin:0 0 14px;font-size:17px;font-weight:700;color:#26374B">${hola}</p>
        <p style="margin:0 0 16px;color:#3f3f46;line-height:1.6">El club ha <b>aprobado la pausa</b> que pediste. Te lo dejamos claro aquí:</p>
      </td></tr>
      <tr><td style="padding:0 24px 14px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:14px 16px;color:#26374B;font-size:15px;line-height:1.7">
            ⏸️ Tu cuota de <b>${mesTxt}</b> queda <b>en pausa</b>: ese mes <b>no se te cobra</b>.<br>
            🔒 <b>Tu plaza se mantiene</b>${horario ? ` en <b>${horario}</b>` : ""}.<br>
            💳 El <b>${sigTxt}</b> se vuelve a cobrar solo, con tu tarjeta de siempre.
          </td></tr>
        </table>
      </td></tr>
      <tr><td style="padding:0 24px 6px 24px">
        <p style="margin:0 0 18px;color:#3f3f46;line-height:1.6">No tienes que hacer nada. Si al final te animas a venir algún día de ${mesTxt}, ¡las puertas están abiertas!</p>
      </td></tr>
      <tr><td align="center" style="padding:0 24px 20px 24px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">
            <a href="${enlace}" style="display:inline-block;padding:13px 28px;color:#ffffff;text-decoration:none;font-weight:700;font-size:15px">Ver mi cuota →</a>
          </td>
        </tr></table>
      </td></tr>
      <tr><td style="padding:0 24px 24px 24px;border-top:1px solid #ececec">
        <p style="margin:16px 0 0 0;color:#71717a;font-size:13px;line-height:1.5">¿Alguna duda? Contéstanos a este mensaje y te echamos una mano. 😊</p>
      </td></tr>
    </table>
  </td></tr></table>
  </body></html>`;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (origen && !ORIGENES_OK.includes(origen)) {
    return responder({ error: "origen", mensaje: "Origen no permitido." }, 403, origen);
  }
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config", mensaje: "No está configurado." }, 503, origen);

  // 1 · Sesión (el permiso de admin lo da la RPC, que se llama con este JWT)
  const cab = req.headers.get("Authorization") ?? "";
  const jwt = cab.toLowerCase().startsWith("bearer ") ? cab.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sesion" }, 401, origen);
  const rU = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` } });
  if (!rU.ok) return responder({ error: "sesion" }, 401, origen);
  const correoAdmin: string = ((await rU.json().catch(() => null))?.email ?? "").toLowerCase();

  let cuerpo: Record<string, any> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const pausaId = String(cuerpo.pausa_id ?? "").trim();
  const accion = String(cuerpo.accion ?? "aprobar").trim();
  if (!pausaId) return responder({ error: "datos", mensaje: "Falta la solicitud." }, 400, origen);
  if (!["aprobar", "aplicar", "deshacer"].includes(accion)) return responder({ error: "accion", mensaje: "Acción no reconocida." }, 400, origen);

  const rD = await rpc("cubo_pausa_para_aprobar", { p_id: pausaId }, jwt);
  if (!rD.ok) {
    const no = rD.estado === 403 || String(rD.datos?.code ?? "") === "42501";
    return responder({ error: no ? "no_admin" : "base", mensaje: no ? "Solo el club puede gestionar pausas." : "No se ha podido leer la solicitud." }, no ? 403 : 500, origen);
  }
  const d = rD.datos ?? {};
  if (d.ok === false) return responder({ error: "no_existe", mensaje: d.error ?? "Esa solicitud ya no está." }, 404, origen);
  if (accion === "aprobar" && d.estado !== "solicitada" && d.estado !== "aprobada") {
    return responder({ error: "estado", mensaje: `Esa solicitud está ${d.estado}.` }, 409, origen);
  }
  if ((accion === "aplicar" || accion === "deshacer") && d.estado !== "aprobada") {
    return responder({ error: "estado", mensaje: "Eso solo vale para una pausa ya aprobada." }, 409, origen);
  }
  if (!d.a_tiempo) {
    return responder({ error: "tarde", mensaje: accion === "deshacer"
      ? "El recibo de ese mes ya se generó (y se anuló): ya no se puede deshacer. Si hay que cobrarlo, usa «Cargo / descuento»."
      : "Ya ha pasado el día 4: el recibo de ese mes se genera el día 5 y no se puede pausar." }, 409, origen);
  }
  const sub = String(d.stripe_subscription_id ?? "");
  const cliente = String(d.stripe_customer_id ?? "");
  const aplicadaYa = !!d.stripe_aplicada_en;
  // Deshacer una pausa solo PROGRAMADA (aún no está en Stripe): solo base.
  const necesitaStripe = accion !== "deshacer" || aplicadaYa;
  if (necesitaStripe && (!sub || d.suscripcion_estado !== "activa")) {
    return responder({ error: "sin_sub", mensaje: "Esta persona no tiene la cuota activa con tarjeta." }, 409, origen);
  }

  // 2 · Stripe (clave de Apolana según el modo; nunca la genérica)
  const modo = await modoPagos();
  const KEY = modo === "real" ? SK_LIVE : SK_TEST;
  if (necesitaStripe && !KEY) return responder({ error: "config", mensaje: `Falta la clave de Stripe de Apolana (${modo}).` }, 503, origen);
  const mes = String(d.mes);                       // "2026-11-01"

  // ---- DESHACER ----
  if (accion === "deshacer") {
    if (aplicadaYa) {
      const rS = await stripe(KEY, `subscriptions/${encodeURIComponent(sub)}`, "GET");
      if (!rS.ok) return responder({ error: "pasarela", mensaje: "No se ha podido leer la suscripción en Stripe." }, 502, origen);
      const pc = rS.datos?.pause_collection;
      const nuestra = d.stripe_resumes_at ? Math.floor(Date.parse(String(d.stripe_resumes_at)) / 1000) : 0;
      if (pc) {
        // Solo se quita si es NUESTRA pausa (mismo fin); una ajena no se toca.
        if (Number(pc.resumes_at ?? 0) !== nuestra) {
          return responder({ error: "ajena", mensaje: "La pausa que hay en Stripe no es esta (otra pausa). Revísalo en Stripe." }, 409, origen);
        }
        const rP = await stripe(KEY, `subscriptions/${encodeURIComponent(sub)}`, "POST", { pause_collection: "" });
        if (!rP.ok) return responder({ error: "pasarela", mensaje: "Stripe no quitó la pausa: " + (rP.datos?.error?.message ?? "inténtalo otra vez") }, 502, origen);
      }
    }
    const rX = await rpc("cubo_pausa_deshacer_registrar", { p_id: pausaId, p_por_email: correoAdmin || null });
    if (!rX.ok || rX.datos?.ok === false) {
      console.error("cubo_pausa_deshacer_registrar:", rX.estado, JSON.stringify(rX.datos));
      return responder({ error: "base", mensaje: "Stripe está bien, pero no se pudo guardar en el panel. Vuelve a pulsar." }, 500, origen);
    }
    return responder({ ok: true, accion, mes, stripe: aplicadaYa ? "reanudada" : "sin_tocar" }, 200, origen);
  }

  // ---- APROBAR / APLICAR ----
  let diaCobro = 5;
  let aplicada = aplicadaYa;
  let resumesGuardar: number | null = null;
  if (!aplicada) {
    const rS = await stripe(KEY, `subscriptions/${encodeURIComponent(sub)}?expand[]=latest_invoice`, "GET");
    if (!rS.ok) {
      console.error("Stripe GET sub:", rS.datos?.error?.message ?? rS.estado);
      return responder({ error: "pasarela", mensaje: "No se ha podido leer la suscripción en Stripe." }, 502, origen);
    }
    const plan = planificar(rS.datos, mes);
    if (plan.tipo === "error") return responder({ error: plan.codigo, mensaje: plan.mensaje }, plan.http, origen);
    diaCobro = plan.diaCobro;
    if (plan.tipo === "programar" && accion === "aplicar") {
      return responder({ error: "aun_no", mensaje: "Aún no toca: se aplica en Stripe después del cobro del mes anterior." }, 409, origen);
    }
    if (plan.tipo === "aplicar") {
      // Cargos/descuentos sueltos pendientes irían al recibo que se va a anular
      // y se perderían: se para y se explica (el club decide).
      const cp = await cargosPendientes(KEY, cliente || String(rS.datos?.customer ?? ""));
      if (!cp.ok) return responder({ error: "pasarela", mensaje: "No se han podido revisar sus cargos pendientes en Stripe. Inténtalo otra vez." }, 502, origen);
      if (cp.items.length) {
        return responder({ error: "cargos_pendientes", mensaje:
          `Tiene ${cp.items.length === 1 ? "un cargo/descuento pendiente" : cp.items.length + " cargos/descuentos pendientes"} para el próximo recibo: ${textoCargos(cp.items)}. ` +
          "Con la pausa ese recibo se anula y se perderían. Quítalo en Stripe (o pásalo al mes siguiente) y vuelve a aprobar." }, 409, origen);
      }
      const rP = await stripe(KEY, `subscriptions/${encodeURIComponent(sub)}`, "POST", {
        "pause_collection[behavior]": "void",
        "pause_collection[resumes_at]": String(plan.resumes),
      });
      if (!rP.ok) {
        console.error("Stripe pause_collection:", rP.datos?.error?.message ?? rP.estado);
        return responder({ error: "pasarela", mensaje: "Stripe no aceptó la pausa: " + (rP.datos?.error?.message ?? "inténtalo otra vez") }, 502, origen);
      }
      resumesGuardar = plan.resumes; aplicada = true;
    } else if (plan.tipo === "ya") {
      resumesGuardar = plan.resumes; aplicada = true;
    }
  }

  // 3 · Apuntarlo en la base (solo llave de servicio)
  const rR = await rpc("cubo_pausa_registrar", {
    p_id: pausaId,
    p_aprobar: accion === "aprobar",
    p_por_email: correoAdmin || null,
    p_resumes: resumesGuardar ? new Date(resumesGuardar * 1000).toISOString() : null,
  });
  if (!rR.ok || rR.datos?.ok === false) {
    // Stripe ya está pausado (si tocaba): el reintento es idempotente («ya»).
    console.error("cubo_pausa_registrar:", rR.estado, JSON.stringify(rR.datos));
    return responder({ error: "base", mensaje: "Stripe está bien, pero no se pudo guardar en el panel. Vuelve a pulsar." }, 500, origen);
  }

  // 4 · Correo (solo al aprobar y una vez). Si falla, la pausa ya está hecha.
  let correo = "no";
  if (accion === "aprobar" && !d.correo_enviado_en && d.email && BREVO_API_KEY) {
    const nM = Number(mes.slice(5, 7));            // 1..12
    const mesTxt = MESES[nM - 1];
    const sigTxt = `${diaCobro} de ${MESES[nM % 12]}`;
    const nombre = String(d.nombre ?? "").trim().split(/\s+/)[0] ?? "";
    const horario = String(d.horario ?? "").replace(/^El Cubo\s*·\s*/, "").replace(/[<>]/g, "");
    try {
      const rB = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({
          sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
          replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS_EMAIL },
          to: [{ email: String(d.email) }],
          subject: `Tu cuota de ${mesTxt} de El Cubo queda en pausa`,
          htmlContent: correoHtml(nombre.replace(/[<>]/g, ""), mesTxt, sigTxt, horario),
          textContent: `${nombre ? "¡Hola, " + nombre + "!" : "¡Hola!"}\n\nTu cuota de ${mesTxt} queda en pausa: ese mes no se te cobra. Tu plaza se mantiene. El ${sigTxt} se vuelve a cobrar solo.\n\n¿Dudas? Contesta a este mensaje.`,
        }),
      });
      correo = rB.ok ? "enviado" : "fallo";
      if (rB.ok) await patch(`cubo_pausas?id=eq.${encodeURIComponent(pausaId)}`, { correo_enviado_en: new Date().toISOString() });
      else console.error("Brevo:", rB.status, await rB.text().catch(() => ""));
    } catch (e) { correo = "fallo"; console.error("Brevo sin conexión:", e); }
  }

  return responder({
    ok: true, accion, mes,
    stripe: aplicada ? "pausada" : "programada",   // programada = la aplica el webhook tras el cobro anterior
    resumes_at: resumesGuardar, correo, modo,
  }, 200, origen);
});
