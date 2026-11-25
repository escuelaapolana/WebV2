// ============================================================
// cubo-tarjeta · la persona cambia ella misma la tarjeta de su cuota del Cubo
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   Antes la app decía «¿Cambiar de tarjeta? Escríbenos» (Yolanda, 25-nov).
//   Ahora, con la cuota ACTIVA, hay un botón «Cambiar la tarjeta»:
//     1 · accion «abrir»: abre la página segura de Stripe en modo «guardar
//         tarjeta» (no cobra nada) para SU cliente de Stripe.
//     2 · accion «aplicar»: al volver, pone esa tarjeta como la de la cuota
//         (suscripción + cliente). El siguiente recibo del día 5 ya va a ella.
//   El webhook (cubo-webhook) hace lo mismo con el aviso de Stripe, por si la
//   persona cierra la pestaña antes de volver (_shared/cubo-tarjeta.ts).
//
// LO QUE NO SE FÍA DEL NAVEGADOR
//   · Quién es: sesión obligatoria; se saca el correo del token.
//   · Qué alta y qué cliente: se leen de la base (cubo_altas de su perfil).
//   · A dónde vuelve: solo a dos páginas fijas del portal.
//
// CLAVES: STRIPE_SECRET_KEY_APOLANA (siempre la live de Apolana) + las de Supabase.
//
//     supabase functions deploy cubo-tarjeta --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

import { aplicarTarjeta, PREFIJO_TARJETA } from "../_shared/cubo-tarjeta.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";
const URL_BASE = (Deno.env.get("PAGOS_URL_BASE") ?? "https://atletismoapolana.com/").replace(/\/*$/, "/");

// Páginas a las que se puede volver (el navegador solo elige una de estas).
const VUELTAS: Record<string, string> = {
  "mas": "portal/mas/",
  "cubo-atleta": "portal/cubo-atleta/",
};

function cors(origen: string | null): Record<string, string> {
  const permitidos = (Deno.env.get("PAGOS_ORIGENES") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const valor = permitidos.length ? (origen && permitidos.includes(origen) ? origen : permitidos[0]) : (origen ?? "*");
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
async function rest(ruta: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  });
  const d = await r.json().catch(() => null);
  return { ok: r.ok, datos: d };
}
async function leerAlta(id: string): Promise<Record<string, any> | null> {
  if (!/^[0-9a-f-]{36}$/i.test(id)) return null;
  const r = await rest(`cubo_altas?select=id,perfil_id,stripe_customer_id,stripe_subscription_id,suscripcion_estado&id=eq.${id}&limit=1`);
  return Array.isArray(r.datos) && r.datos[0] ? r.datos[0] : null;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY || !STRIPE_KEY) {
    return responder({ error: "config", mensaje: "El cambio de tarjeta no está disponible ahora mismo. Escríbenos." }, 503, origen);
  }

  // ---- Sesión obligatoria ----
  const cab = req.headers.get("Authorization") ?? "";
  const jwt = cab.toLowerCase().startsWith("bearer ") ? cab.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sesion", mensaje: "Entra con tu cuenta para cambiar la tarjeta." }, 401, origen);
  const rU = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` } });
  if (!rU.ok) return responder({ error: "sesion", mensaje: "Tu sesión ha caducado. Vuelve a entrar." }, 401, origen);
  const usuario = await rU.json().catch(() => null);
  const correo = String(usuario?.email ?? "").toLowerCase();
  if (!correo) return responder({ error: "sesion", mensaje: "No hemos podido identificarte. Vuelve a entrar." }, 401, origen);
  const rP = await rest(`perfiles?select=id&email=eq.${encodeURIComponent(correo)}&limit=1`);
  const perfilId: string | null = Array.isArray(rP.datos) && rP.datos[0] ? rP.datos[0].id : null;
  if (!perfilId) return responder({ error: "perfil", mensaje: "No encontramos tu ficha. Escríbenos y lo miramos." }, 404, origen);

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const accion = String(cuerpo.accion ?? "abrir");

  // ---- 2 · Al volver de Stripe: aplicar la tarjeta ----
  if (accion === "aplicar") {
    const sid = String(cuerpo.session_id ?? "").trim();
    const res = await aplicarTarjeta(STRIPE_KEY, sid, leerAlta);
    if (!res.ok) return responder({ error: res.codigo, mensaje: res.mensaje }, 409, origen);
    // Solo se le cuenta a la dueña del alta (no se enseñan datos de otra).
    if (res.perfil_id !== perfilId) return responder({ error: "ajena", mensaje: "Ese cambio no es de tu cuota." }, 403, origen);
    return responder({ ok: true, marca: res.marca, ultimas4: res.ultimas4 }, 200, origen);
  }

  if (accion !== "abrir") return responder({ error: "accion", mensaje: "Acción no reconocida." }, 400, origen);

  // ---- 1 · Abrir Stripe en modo «guardar tarjeta» ----
  // Su alta: la activa (igual que cubo-pagar / cubo-cuota.js).
  const rA = await rest(
    `cubo_altas?select=id,stripe_customer_id,stripe_subscription_id,suscripcion_estado&perfil_id=eq.${perfilId}&order=created_at.desc`,
  );
  const filas: any[] = Array.isArray(rA.datos) ? rA.datos : [];
  const alta = filas.find((a) => a.suscripcion_estado === "activa") ?? null;
  if (!alta || !alta.stripe_customer_id || !alta.stripe_subscription_id) {
    return responder({
      error: "sin_cuota",
      mensaje: "Para cambiar la tarjeta hace falta tener la cuota activa. Si no, escríbenos y lo miramos.",
    }, 409, origen);
  }

  const volver = URL_BASE + (VUELTAS[String(cuerpo.desde ?? "")] ?? VUELTAS["mas"]);
  const ref = `${PREFIJO_TARJETA}${alta.id}`;
  const p = new URLSearchParams();
  p.set("mode", "setup");
  p.set("locale", "es");
  p.set("customer", alta.stripe_customer_id);
  p.set("payment_method_types[0]", "card");
  p.set("client_reference_id", ref);
  p.set("metadata[referencia]", ref);
  p.set("metadata[alta_id]", alta.id);
  p.set("setup_intent_data[metadata][referencia]", ref);
  p.set("setup_intent_data[metadata][alta_id]", alta.id);
  p.set("success_url", `${volver}?tarjeta=hecha&sid={CHECKOUT_SESSION_ID}`);
  p.set("cancel_url", `${volver}?tarjeta=cancelada`);

  // Doble clic → la misma sesión (tramos de 30 min por alta).
  const tramo = Math.floor(Date.now() / (30 * 60 * 1000));
  const rS = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${STRIPE_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key": `apolana-cubo-tarjeta-${alta.id}-${tramo}-${String(cuerpo.desde ?? "mas")}`,
    },
    body: p.toString(),
  });
  const ses = await rS.json().catch(() => null);
  if (!rS.ok || !ses?.url) {
    console.error("cubo-tarjeta: Stripe rechazó la sesión:", ses?.error?.message ?? rS.status);
    return responder({ error: "pasarela", mensaje: "La página de Stripe no ha respondido. Vuelve a intentarlo en un minuto." }, 502, origen);
  }
  return responder({ url: ses.url }, 200, origen);
});
