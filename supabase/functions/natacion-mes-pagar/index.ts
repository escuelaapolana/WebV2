// ============================================================
// natacion-mes-pagar · paga UN recibo de natación «mes a mes» por su enlace
// ------------------------------------------------------------
// Mig 431 (22-oct-2026). Hay familias que no quieren dejar la tarjeta
// guardada: cada mes les llega un aviso con un enlace /pagar/?t=… y pagan ese
// mes. Esta función, SIN cuenta (el enlace es el permiso):
//   · { t }                  → abre la pasarela de Stripe (un solo pago, tarjeta)
//                              por el importe que dice LA BASE
//                              (pagos_iniciar_recibo_token). Si ya está
//                              pagado, { pagado: true }.
//   · { t, comprobar: true } → mira en STRIPE la última sesión de ese recibo
//                              y, si está cobrada, la confirma aquí mismo
//                              (pagos_confirmar, idempotente). Así el
//                              «Pagado ✓» sale al volver aunque el webhook tarde.
// El webhook de siempre (cubo-webhook → pagos_confirmar) deja el recibo PAGADO.
// Claves: STRIPE_SECRET_KEY_APOLANA (+ _TEST), por pagos_config.modo.
//
//   supabase functions deploy natacion-mes-pagar --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const SK_LIVE = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";
const SK_TEST = Deno.env.get("STRIPE_SECRET_KEY_APOLANA_TEST") ?? "";
const URL_BASE = "https://atletismoapolana.com/";

function cors(origen: string | null): Record<string, string> {
  const permitidos = (Deno.env.get("PAGOS_ORIGENES") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const valor = permitidos.length ? (origen && permitidos.includes(origen) ? origen : permitidos[0]) : (origen ?? "*");
  return { "Access-Control-Allow-Origin": valor, "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS", "Vary": "Origin" };
}
const responder = (d: unknown, s: number, o: string | null) =>
  new Response(JSON.stringify(d), { status: s, headers: { ...cors(o), "Content-Type": "application/json; charset=utf-8" } });

async function rest(ruta: string, init: RequestInit = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...init, headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
  });
  const t = await r.text();
  let d: any = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, datos: d };
}

Deno.serve(async (req: Request) => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config", mensaje: "El pago no está disponible ahora mismo." }, 503, origen);

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const t = String(cuerpo.t ?? "").trim();
  if (!/^[0-9a-f]{40,128}$/i.test(t)) return responder({ error: "enlace", mensaje: "Este enlace no es válido." }, 400, origen);

  const rCfg = await rest("pagos_config?select=modo&id=eq.1&limit=1");
  const modo = String(rCfg.datos?.[0]?.modo ?? "prueba").toLowerCase();
  const KEY = modo === "real" ? SK_LIVE : SK_TEST;
  if (!KEY) return responder({ error: "config", mensaje: "El pago no está disponible ahora mismo." }, 503, origen);

  const rR = await rest(`pagos?select=id,estado,anulado,importe,concepto,atleta_id,cuota_entreno_id&token_pago=eq.${t}&limit=1`);
  const rec = Array.isArray(rR.datos) ? rR.datos[0] : null;
  if (!rec) return responder({ error: "enlace", mensaje: "Este enlace no es válido." }, 404, origen);
  if (rec.anulado) return responder({ error: "anulado", mensaje: "Este recibo está anulado. Si crees que es un error, escríbenos." }, 409, origen);
  if (rec.estado === "pagado") return responder({ pagado: true }, 200, origen);

  // --- ¿Ya está cobrado en Stripe? (al volver de la pasarela) ---
  if (cuerpo.comprobar === true) {
    const rP = await rest(`pagos_online?select=referencia,stripe_session_id&metadatos->>pago_id=eq.${rec.id}&stripe_session_id=not.is.null&order=creado_en.desc&limit=3`);
    for (const po of (Array.isArray(rP.datos) ? rP.datos : [])) {
      const rS = await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(po.stripe_session_id)}`, { headers: { Authorization: `Bearer ${KEY}` } });
      const s = rS.ok ? await rS.json().catch(() => null) : null;
      if (s?.payment_status === "paid") {
        await rest("rpc/pagos_confirmar", { method: "POST", body: JSON.stringify({
          p_referencia: po.referencia, p_session: s.id, p_intent: typeof s.payment_intent === "string" ? s.payment_intent : null }) });
        return responder({ pagado: true }, 200, origen);
      }
    }
    return responder({ pagado: false }, 200, origen);
  }

  // --- Abrir la pasarela ---
  const rI = await rest("rpc/pagos_iniciar_recibo_token", { method: "POST", body: JSON.stringify({ p_token: t }) });
  if (!rI.ok) return responder({ error: "no_se_puede", mensaje: rI.datos?.message ?? "No se ha podido preparar el pago." }, 400, origen);
  const pago = Array.isArray(rI.datos) ? rI.datos[0] : rI.datos;
  if (!pago?.referencia) return responder({ error: "interno", mensaje: "No se ha podido preparar el pago." }, 500, origen);

  let email = "";
  if (rec.cuota_entreno_id) {
    const rQ = await rest(`cuotas_entreno?select=email&id=eq.${rec.cuota_entreno_id}&limit=1`);
    email = String(rQ.datos?.[0]?.email ?? "");
  }
  const vuelta = (r: string) => `${URL_BASE}pagar/?t=${t}&pago=${r}`;
  const p = new URLSearchParams();
  p.set("mode", "payment");
  p.set("locale", "es");
  p.set("payment_method_types[0]", "card");
  p.set("client_reference_id", pago.referencia);
  if (email) p.set("customer_email", email);
  p.set("success_url", vuelta("hecho"));
  p.set("cancel_url", vuelta("cancelado"));
  p.set("line_items[0][quantity]", "1");
  p.set("line_items[0][price_data][currency]", "eur");
  p.set("line_items[0][price_data][unit_amount]", String(pago.importe_centimos));
  p.set("line_items[0][price_data][product_data][name]", pago.concepto);
  p.set("line_items[0][price_data][product_data][description]", `Club Atletismo Apolana · ${pago.referencia}`);
  p.set("metadata[referencia]", pago.referencia);
  p.set("payment_intent_data[metadata][referencia]", pago.referencia);
  p.set("payment_intent_data[description]", `${pago.concepto} · ${pago.referencia}`);
  const rS = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/x-www-form-urlencoded", "Idempotency-Key": `apolana-${pago.referencia}` },
    body: p.toString(),
  });
  const ses = await rS.json().catch(() => null);
  if (!rS.ok || !ses?.url) {
    await rest("rpc/pagos_marcar", { method: "POST", body: JSON.stringify({ p_referencia: pago.referencia, p_estado: "fallido", p_evento: null }) });
    console.error("[natacion-mes-pagar] Stripe:", ses?.error?.message ?? rS.status);
    return responder({ error: "pasarela", mensaje: "La pasarela de pago no ha respondido. Vuelve a intentarlo en un minuto." }, 502, origen);
  }
  await rest(`pagos_online?referencia=eq.${encodeURIComponent(pago.referencia)}`, { method: "PATCH", body: JSON.stringify({ stripe_session_id: ses.id }) });
  return responder({ url: ses.url }, 200, origen);
});
