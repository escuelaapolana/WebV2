// ============================================================
// cubo-pagar · activa la cuota mensual de El Cubo con tarjeta
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   La persona (ya con sesión de `cubo-atleta`) pulsa «Pagar la cuota».
//   Aquí se mira EN LA BASE cuánto le toca al mes (su `precio_mes` en
//   `cubo_altas`, que lo puso el club, NO el navegador) y se abre una
//   suscripción de Stripe: guarda la tarjeta ahora y cobra sola cada
//   mes. La tarjeta NUNCA pasa por la web: se teclea en Stripe.
//
// EL TRATO (decidido por Andrés)
//   · Arrancan el 21. El PRIMER recibo es el 21 y son 10 € a todos
//     (mes de entrada), da igual la tarifa. Para eso: la suscripción
//     empieza con «periodo de prueba» hasta el 21 (no cobra hoy) y el
//     primer recibo lleva un descuento de (tarifa − 10) €, de una vez.
//   · A partir de ahí, cada 21 se cobra la tarifa completa (20/30/40).
//   · Si alguien se apunta ya pasado el 21, se cobra en el acto (los
//     10 € de entrada) y de ahí en adelante, mensual.
//
// LO QUE NO SE FÍA DEL NAVEGADOR
//   · El importe. Lo pone el servidor leyendo `cubo_altas`. Si el
//     navegador manda un precio, se ignora.
//   · Quién es. Hace falta sesión válida; se saca el correo del token.
//
// CLAVES (variables de entorno de Supabase; aquí no hay ninguna)
//     STRIPE_SECRET_KEY_APOLANA  (la de APOLANA, distinta de la de Ítaka;
//                                 la pones tú en Supabase)
//     SUPABASE_URL / SERVICE_ROLE_KEY / ANON_KEY  (las pone Supabase)
//   Opcionales: PAGOS_URL_BASE, PAGOS_ORIGENES
//
// Se despliega SIN comprobar el JWT (el token lo validamos aquí a mano
// contra /auth/v1/user):
//     supabase functions deploy cubo-pagar --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";

const URL_BASE = (Deno.env.get("PAGOS_URL_BASE") ?? "https://escuelaapolana.github.io/WebV2/")
  .replace(/\/*$/, "/");

// El primer cobro: el 21 de septiembre de 2026 a las 00:00 (hora de
// Madrid, CEST = UTC+2) → 2026-09-20T22:00:00Z.
const INICIO_TS = Math.floor(Date.UTC(2026, 8, 20, 22, 0, 0) / 1000);
// El mes de entrada cuesta 10 € a todos, sea cual sea la tarifa.
const PRIMER_MES_EUROS = 10;

function vuelta(resultado: "hecho" | "cancelado"): string {
  return `${URL_BASE}portal/cubo-atleta/?cuota=${resultado}`;
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
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(opciones.headers ?? {}),
    },
  });
  const t = await r.text();
  let d: unknown = null;
  try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, estado: r.status, datos: d };
}

// Un cupón de «(tarifa − 10) € de descuento, una sola vez». Se crea con
// un id fijo por importe, así clics repetidos reutilizan el mismo cupón
// en vez de sembrar Stripe de cupones. Si ya existe, se reutiliza.
async function cuponEntrada(descuentoCent: number): Promise<string | null> {
  const id = `cubo-entrada-${descuentoCent}`;
  const p = new URLSearchParams();
  p.set("id", id);
  p.set("amount_off", String(descuentoCent));
  p.set("currency", "eur");
  p.set("duration", "once");
  p.set("name", "El Cubo · mes de entrada");
  const r = await fetch("https://api.stripe.com/v1/coupons", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${STRIPE_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key": `cupon-${id}`,
    },
    body: p.toString(),
  });
  if (r.ok) return id;
  const err = await r.json().catch(() => null);
  // Ya existía (de un pago anterior): perfecto, se reutiliza.
  if (err?.error?.code === "resource_already_exists") return id;
  console.error("No se pudo crear el cupón de entrada:", err?.error?.message ?? r.status);
  return null;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ error: "config", mensaje: "El pago de la cuota no está configurado." }, 503, origen);
  }
  if (!STRIPE_KEY) {
    return responder({
      error: "no_activado",
      mensaje: "El pago de la cuota todavía no está activado. Muy pronto podrás pagarla desde aquí.",
    }, 503, origen);
  }

  // ---- 1 · Sesión OBLIGATORIA: sacamos el correo del token ----
  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sesion", mensaje: "Entra con tu cuenta para pagar la cuota." }, 401, origen);

  const rUsuario = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` },
  });
  if (!rUsuario.ok) return responder({ error: "sesion", mensaje: "Tu sesión ha caducado. Vuelve a entrar." }, 401, origen);
  const usuario = await rUsuario.json().catch(() => null);
  const correo: string = (usuario?.email ?? "").toLowerCase();
  if (!correo) return responder({ error: "sesion", mensaje: "No hemos podido identificarte. Vuelve a entrar." }, 401, origen);

  const rPerfil = await rest(`perfiles?select=id&email=eq.${encodeURIComponent(correo)}&limit=1`);
  const perfil = Array.isArray(rPerfil.datos) ? rPerfil.datos[0] : null;
  const perfilId: string | null = perfil?.id ?? null;
  if (!perfilId) return responder({ error: "perfil", mensaje: "No encontramos tu ficha. Escríbenos y lo miramos." }, 404, origen);

  // ---- 2 · Su alta del Cubo: de ahí sale el precio (nunca del navegador) ----
  const rAlta = await rest(
    `cubo_altas?select=id,precio_mes,stripe_subscription_id,suscripcion_estado,nombre,apellidos,cobro_abierto` +
    `&perfil_id=eq.${perfilId}&order=created_at.desc&limit=1`,
  );
  const alta = Array.isArray(rAlta.datos) ? rAlta.datos[0] : null;
  if (!alta) {
    return responder({
      error: "sin_alta",
      mensaje: "No encontramos tu alta en El Cubo. Escríbenos y lo dejamos listo.",
    }, 404, origen);
  }

  // El cobro se abre POR PERSONA desde el club (columna cobro_abierto). Si no
  // está abierto, no se puede pagar aún — ni desde el botón ni llamando aquí.
  if (alta.cobro_abierto !== true) {
    return responder({
      error: "cobro_cerrado",
      mensaje: "El pago de tu cuota aún no está abierto. El club te avisará cuando puedas activarlo.",
    }, 409, origen);
  }

  // Ya tiene la cuota activa: no abrimos otra (evita doble suscripción).
  if (alta.stripe_subscription_id && alta.suscripcion_estado === "activa") {
    return responder({
      error: "ya_activa",
      mensaje: "Tu cuota ya está activa y se cobra sola cada mes. No hace falta volver a pagar.",
    }, 409, origen);
  }

  const precioMes = Math.round(Number(alta.precio_mes));
  if (!Number.isFinite(precioMes) || precioMes < PRIMER_MES_EUROS) {
    return responder({
      error: "sin_precio",
      mensaje: "Tu cuota aún no tiene tarifa asignada. Escríbenos y lo dejamos listo.",
    }, 409, origen);
  }
  const importeMesCent = precioMes * 100;
  const descuentoCent = (precioMes - PRIMER_MES_EUROS) * 100; // (tarifa − 10) €

  // La referencia con la que casaremos el aviso de Stripe en el webhook.
  const referencia = `cubo-${alta.id}`;

  // ---- 3 · Cupón del mes de entrada (si hay algo que descontar) ----
  let cuponId: string | null = null;
  if (descuentoCent > 0) {
    cuponId = await cuponEntrada(descuentoCent);
    if (!cuponId) {
      return responder({
        error: "pasarela",
        mensaje: "No hemos podido preparar el pago. Vuelve a intentarlo en un minuto.",
      }, 502, origen);
    }
  }

  // ---- 4 · La sesión de Stripe (suscripción mensual) ----
  const ahora = Math.floor(Date.now() / 1000);
  const enPrueba = INICIO_TS > ahora + 60; // aún no ha llegado el 21 → no cobra hoy

  const params = new URLSearchParams();
  params.set("mode", "subscription");
  params.set("locale", "es");
  params.set("client_reference_id", referencia);
  params.set("customer_email", correo);
  params.set("success_url", `${vuelta("hecho")}&ref=${referencia}`);
  params.set("cancel_url", vuelta("cancelado"));

  // Precio recurrente mensual, montado al vuelo con la tarifa de la base.
  params.set("line_items[0][quantity]", "1");
  params.set("line_items[0][price_data][currency]", "eur");
  params.set("line_items[0][price_data][unit_amount]", String(importeMesCent));
  params.set("line_items[0][price_data][recurring][interval]", "month");
  params.set("line_items[0][price_data][product_data][name]", "Cuota mensual · El Cubo");

  if (cuponId) params.set("discounts[0][coupon]", cuponId);

  // El primer cobro, el 21: hasta entonces, «prueba» (guarda tarjeta, no
  // cobra). Si ya pasó el 21, se cobra en el acto.
  if (enPrueba) params.set("subscription_data[trial_end]", String(INICIO_TS));

  // Etiquetas para reconocer el pago desde el webhook (en la suscripción,
  // que es lo que viaja en los avisos de cobro recurrente).
  params.set("subscription_data[metadata][referencia]", referencia);
  params.set("subscription_data[metadata][perfil_id]", perfilId);
  params.set("subscription_data[metadata][alta_id]", alta.id);
  params.set("metadata[referencia]", referencia);

  const rStripe = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${STRIPE_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });
  const sesion = await rStripe.json().catch(() => null);

  if (!rStripe.ok || !sesion?.url) {
    console.error("Stripe rechazó la sesión del Cubo:", sesion?.error?.message ?? rStripe.status);
    return responder({
      error: "pasarela",
      mensaje: "La pasarela de pago no ha respondido. Vuelve a intentarlo en un minuto.",
    }, 502, origen);
  }

  return responder({
    url: sesion.url,
    referencia,
    precio_mes: precioMes,
    primer_mes: PRIMER_MES_EUROS,
    en_prueba: enPrueba,
  }, 200, origen);
});
