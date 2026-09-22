// ============================================================
// cubo-cobro-pagar · paga un «pago puntual» que el club le puso a
// esta persona (Stripe Checkout, un solo pago).
// ------------------------------------------------------------
// El club pone el pago en `cubo_cobros` (concepto + importe). Aquí:
//   · Se comprueba la sesión (JWT) y que ese cobro es SUYO y está
//     pendiente.
//   · El IMPORTE se lee de la base (nunca del navegador).
//   · Se abre una sesión de pago de Stripe (mode=payment) por ese
//     importe. Al pagar, el webhook (cubo-webhook) lo marca cobrado.
//
// Se despliega SIN verificar el JWT (lo validamos a mano):
//   supabase functions deploy cubo-cobro-pagar --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const STRIPE_KEY =
  Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ??
  Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const URL_BASE = (Deno.env.get("PAGOS_URL_BASE") ?? "https://escuelaapolana.github.io/WebV2/")
  .replace(/\/*$/, "/");

function vuelta(resultado: "hecho" | "cancelado"): string {
  return `${URL_BASE}portal/cubo-atleta/?pago=${resultado}`;
}

function cors(origen: string | null): Record<string, string> {
  const permitidos = (Deno.env.get("PAGOS_ORIGENES") ?? "")
    .split(",").map((s) => s.trim()).filter(Boolean);
  const valor = permitidos.length
    ? (origen && permitidos.includes(origen) ? origen : permitidos[0])
    : (origen ?? "*");
  return {
    "Access-Control-Allow-Origin": valor,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}
function responder(cuerpo: unknown, estado: number, origen: string | null): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { ...cors(origen), "Content-Type": "application/json; charset=utf-8" },
  });
}
type Opciones = Omit<RequestInit, "headers"> & { headers?: Record<string, string> };
async function rest(ruta: string, opciones: Opciones = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...opciones,
    headers: {
      apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json", ...(opciones.headers ?? {}),
    },
  });
  const t = await r.text();
  let d: unknown = null;
  try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, estado: r.status, datos: d };
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config", mensaje: "El pago no está configurado." }, 503, origen);
  if (!STRIPE_KEY) return responder({ error: "no_activado", mensaje: "El pago todavía no está activado." }, 503, origen);

  // 1 · Sesión obligatoria
  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sesion", mensaje: "Entra con tu cuenta para pagar." }, 401, origen);
  const rUsuario = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` },
  });
  if (!rUsuario.ok) return responder({ error: "sesion", mensaje: "Tu sesión ha caducado. Vuelve a entrar." }, 401, origen);
  const usuario = await rUsuario.json().catch(() => null);
  const correo: string = (usuario?.email ?? "").toLowerCase();
  if (!correo) return responder({ error: "sesion", mensaje: "No hemos podido identificarte." }, 401, origen);
  const rPerfil = await rest(`perfiles?select=id&email=eq.${encodeURIComponent(correo)}&limit=1`);
  const perfil = Array.isArray(rPerfil.datos) ? rPerfil.datos[0] : null;
  const perfilId: string | null = perfil?.id ?? null;
  if (!perfilId) return responder({ error: "perfil", mensaje: "No encontramos tu ficha." }, 404, origen);

  // 2 · El cobro: suyo y pendiente. El importe sale de la base.
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const cobroId = String(cuerpo.cobro_id ?? "").trim();
  if (!cobroId) return responder({ error: "datos", mensaje: "Falta el pago." }, 400, origen);

  const rC = await rest(`cubo_cobros?select=id,perfil_id,concepto,importe_cent,estado,stripe_session_id&id=eq.${encodeURIComponent(cobroId)}&limit=1`);
  const cobro = Array.isArray(rC.datos) ? rC.datos[0] : null;
  if (!cobro) return responder({ error: "no_existe", mensaje: "Ese pago ya no está." }, 404, origen);
  if (cobro.perfil_id !== perfilId) return responder({ error: "ajeno", mensaje: "Ese pago no es tuyo." }, 403, origen);
  if (cobro.estado === "pagado") return responder({ error: "ya_pagado", mensaje: "Este pago ya está cobrado. ¡Gracias!" }, 409, origen);
  if (cobro.estado !== "pendiente") return responder({ error: "estado", mensaje: "Ese pago ya no está pendiente." }, 409, origen);

  // ANTI DOBLE-COBRO. Si ya había una sesión de pago de este cobro, se mira en
  // Stripe: si YA está pagada (aunque la base aún ponga pendiente porque el
  // webhook no llegó), se marca cobrado y NO se abre otro pago. Si sigue
  // abierta, se reutiliza esa misma sesión (Stripe cobra una sola vez).
  if (cobro.stripe_session_id) {
    const rExist = await fetch(
      `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(String(cobro.stripe_session_id))}`,
      { headers: { Authorization: `Bearer ${STRIPE_KEY}` } });
    const sesExist = await rExist.json().catch(() => null);
    if (rExist.ok && sesExist) {
      if (sesExist.payment_status === "paid") {
        await rest(`cubo_cobros?id=eq.${encodeURIComponent(cobro.id)}&estado=eq.pendiente`, {
          method: "PATCH", headers: { Prefer: "return=minimal" },
          body: JSON.stringify({
            estado: "pagado", pagado_en: new Date().toISOString(),
            stripe_payment_intent: typeof sesExist.payment_intent === "string" ? sesExist.payment_intent : null,
          }),
        });
        return responder({ error: "ya_pagado", mensaje: "Este pago ya se había cobrado. ¡Gracias!" }, 409, origen);
      }
      // Sesión aún válida y sin pagar → se reutiliza (no se crea otra).
      if (sesExist.status === "open" && sesExist.url) {
        return responder({ url: sesExist.url, cobro_id: cobro.id, reutilizada: true }, 200, origen);
      }
    }
  }

  const importeCent = Math.round(Number(cobro.importe_cent));
  if (!Number.isFinite(importeCent) || importeCent < 1) {
    return responder({ error: "importe", mensaje: "El importe de ese pago no es válido." }, 409, origen);
  }
  const concepto = String(cobro.concepto ?? "Pago del Cubo").slice(0, 120);

  // 3 · Sesión de Stripe (un solo pago)
  const params = new URLSearchParams();
  params.set("mode", "payment");
  params.set("locale", "es");
  params.set("client_reference_id", `cubocobro-${cobro.id}`);
  params.set("customer_email", correo);
  params.set("success_url", `${vuelta("hecho")}&cobro=${cobro.id}`);
  params.set("cancel_url", vuelta("cancelado"));
  params.set("line_items[0][quantity]", "1");
  params.set("line_items[0][price_data][currency]", "eur");
  params.set("line_items[0][price_data][unit_amount]", String(importeCent));
  params.set("line_items[0][price_data][product_data][name]", concepto);
  params.set("metadata[cobro_id]", String(cobro.id));
  params.set("payment_intent_data[metadata][cobro_id]", String(cobro.id));

  const rStripe = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: { Authorization: `Bearer ${STRIPE_KEY}`, "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString(),
  });
  const sesion = await rStripe.json().catch(() => null);
  if (!rStripe.ok || !sesion?.url) {
    console.error("Stripe rechazó el pago puntual del Cubo:", sesion?.error?.message ?? rStripe.status);
    return responder({ error: "pasarela", mensaje: "La pasarela de pago no ha respondido. Vuelve a intentarlo." }, 502, origen);
  }

  // Guardamos la sesión para casarla en el webhook.
  await rest(`cubo_cobros?id=eq.${encodeURIComponent(cobro.id)}`, {
    method: "PATCH", headers: { Prefer: "return=minimal" },
    body: JSON.stringify({ stripe_session_id: sesion.id }),
  });

  return responder({ url: sesion.url, cobro_id: cobro.id }, 200, origen);
});
