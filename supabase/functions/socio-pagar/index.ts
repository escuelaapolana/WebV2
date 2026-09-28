// ============================================================
// socio-pagar · cobra el alta de socio por adeudo SEPA (Stripe)
// ------------------------------------------------------------
// QUÉ HACE
//   Tras enviar el formulario de alta de socio (que ya guardó el alta y devolvió
//   su `referencia`), el navegador llama aquí. Se busca el alta EN LA BASE por su
//   referencia, se lee el importe EN LA BASE (pagos_config.precio_alta_socio_cent,
//   nunca del navegador) y se abre una sesión de pago de Stripe con adeudo SEPA
//   (mode=payment, una vez). La persona teclea su IBAN y acepta el mandato EN
//   STRIPE (nunca aquí). Cuando Stripe confirma, el webhook marca el alta pagada.
//
// TEST vs REAL
//   Se mira `pagos_config.modo`: si es 'real' se usa la clave live de Apolana; si
//   no, la de prueba (STRIPE_SECRET_KEY_APOLANA_TEST). Así se prueba en test y se
//   pasa a real cambiando el modo (cuando Stripe verifique los documentos del SEPA).
//
// CLAVES (variables de entorno de Supabase; aquí no hay ninguna)
//   STRIPE_SECRET_KEY_APOLANA        (live de Apolana)
//   STRIPE_SECRET_KEY_APOLANA_TEST   (sk_test de Apolana, para probar)
//   SUPABASE_URL / SERVICE_ROLE_KEY  (las pone Supabase)
//   Opcionales: PAGOS_URL_BASE, PAGOS_ORIGENES
//
// Se despliega sin comprobar JWT (es el flujo público del alta):
//   supabase functions deploy socio-pagar --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const SK_LIVE = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";
const SK_TEST = Deno.env.get("STRIPE_SECRET_KEY_APOLANA_TEST") ?? "";
const SAL = Deno.env.get("ACCESO_SAL") ?? "apolana-acceso";

const URL_BASE = (Deno.env.get("PAGOS_URL_BASE") ?? "https://atletismoapolana.com/")
  .replace(/\/*$/, "/");

function vuelta(resultado: "hecho" | "cancelado"): string {
  return `${URL_BASE}socio/alta/?pago=${resultado}`;
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
async function consulta(ruta: string, opciones: Opciones = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...opciones,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(opciones.headers ?? {}),
    },
  });
  const texto = await r.text();
  let datos: unknown = null;
  try { datos = texto ? JSON.parse(texto) : null; } catch { datos = texto; }
  return { ok: r.ok, estado: r.status, datos };
}

// Hash del origen para contar peticiones sin guardar la IP (como acceso-enlace).
async function resumen(texto: string): Promise<string> {
  const bytes = new TextEncoder().encode(SAL + "·" + texto);
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash)).slice(0, 12)
    .map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ error: "config", mensaje: "El pago del alta no está configurado." }, 503, origen);
  }

  // --- 0 · Freno anti-abuso por origen ---
  // Sin esto se podían ENUMERAR las referencias SOC-… (oráculo de quién es socio y
  // quién ha pagado) y, con una referencia ajena, escribir es_familiar/familiar_nota
  // en un alta que no es tuya. El freno corta el aporreo (con tu propia referencia,
  // recién obtenida de tu alta, nunca llegas al tope).
  const dedonde = await resumen(req.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "sin-origen");
  const ritmo = await consulta(`rpc/alta_ritmo`, {
    method: "POST",
    body: JSON.stringify({ p_tipo: "socio-pagar", p_origen: dedonde, p_max: 40 }),
  });
  if (ritmo.datos !== true) {
    return responder({ error: "ritmo", mensaje: "Demasiados intentos desde aquí. Prueba de nuevo dentro de un rato." }, 429, origen);
  }

  // --- 1 · Datos del navegador: solo la referencia y el sí/no de familiar ---
  let cuerpo: { referencia?: string; es_familiar?: boolean; familiar_nota?: string } = {};
  try { cuerpo = await req.json(); } catch { /* cuerpo vacío */ }
  const referencia = String(cuerpo.referencia ?? "").trim();
  if (!referencia) {
    return responder({ error: "sin_referencia", mensaje: "Falta la referencia del alta." }, 400, origen);
  }

  // --- 2 · Config: modo (test/real) e importe, SIEMPRE de la base ---
  const rCfg = await consulta(`pagos_config?select=modo,precio_alta_socio_cent&id=eq.1&limit=1`);
  const cfg = Array.isArray(rCfg.datos) ? rCfg.datos[0] as { modo?: string; precio_alta_socio_cent?: number } : null;
  const modo = (cfg?.modo ?? "prueba").toLowerCase();
  const importeCent = Math.round(Number(cfg?.precio_alta_socio_cent ?? 3500));
  if (!Number.isFinite(importeCent) || importeCent < 50) {
    return responder({ error: "sin_precio", mensaje: "El importe del alta no está configurado." }, 409, origen);
  }

  const STRIPE_KEY = modo === "real" ? SK_LIVE : (SK_TEST || SK_LIVE);
  if (!STRIPE_KEY) {
    return responder({
      error: "no_activado",
      mensaje: "El pago del alta todavía no está activado. Escríbenos y te decimos cómo pagarlo.",
    }, 503, origen);
  }

  // --- 3 · El alta, por su referencia (para casarlo y coger el correo) ---
  const rAlta = await consulta(
    `altas_socio?select=id,referencia,email,nombre,apellidos,pago_estado&referencia=eq.${encodeURIComponent(referencia)}&order=created_at.desc&limit=1`,
  );
  const alta = Array.isArray(rAlta.datos) ? rAlta.datos[0] as {
    id: string; referencia: string; email: string; nombre: string; apellidos: string; pago_estado: string;
  } : null;
  if (!alta) {
    return responder({ error: "sin_alta", mensaje: "No encontramos tu alta. Escríbenos y lo dejamos listo." }, 404, origen);
  }
  if (alta.pago_estado === "pagado") {
    return responder({ error: "ya_pagado", mensaje: "Tu alta ya está pagada. No hace falta volver a pagar." }, 409, origen);
  }

  // Guardamos el sí/no de familiar en el alta (lo comprueba Isa para diciembre).
  const esFamiliar = cuerpo.es_familiar === true;
  await consulta(`altas_socio?id=eq.${alta.id}`, {
    method: "PATCH",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify({ es_familiar: esFamiliar, familiar_nota: (cuerpo.familiar_nota ?? "").toString().slice(0, 300) || null }),
  });

  // --- 4 · La sesión de Stripe (adeudo SEPA, de una vez) ---
  const refPago = `socio-${alta.id}`;
  const params = new URLSearchParams();
  params.set("mode", "payment");
  params.set("locale", "es");
  params.set("payment_method_types[0]", "sepa_debit");
  params.set("client_reference_id", refPago);
  if (alta.email) params.set("customer_email", alta.email);
  params.set("success_url", `${vuelta("hecho")}&ref=${encodeURIComponent(referencia)}`);
  params.set("cancel_url", vuelta("cancelado"));
  params.set("line_items[0][quantity]", "1");
  params.set("line_items[0][price_data][currency]", "eur");
  params.set("line_items[0][price_data][unit_amount]", String(importeCent));
  params.set("line_items[0][price_data][product_data][name]", "Cuota de alta de socio · Club Atletismo Apolana");
  // Etiquetas para reconocer el pago en el webhook.
  params.set("payment_intent_data[metadata][referencia]", refPago);
  params.set("payment_intent_data[metadata][alta_ref]", referencia);
  params.set("payment_intent_data[metadata][alta_id]", alta.id);
  params.set("metadata[referencia]", refPago);
  params.set("metadata[alta_ref]", referencia);
  params.set("metadata[alta_id]", alta.id);

  const rStripe = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: { Authorization: `Bearer ${STRIPE_KEY}`, "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString(),
  });
  const sesion = await rStripe.json().catch(() => null);
  if (!rStripe.ok || !sesion?.url) {
    console.error("Stripe rechazó la sesión del alta de socio:", sesion?.error?.message ?? rStripe.status);
    return responder({
      error: "pasarela",
      mensaje: "La pasarela de pago no ha respondido. Vuelve a intentarlo en un minuto.",
    }, 502, origen);
  }

  // Guardamos la sesión para casar el aviso de Stripe si hiciera falta.
  await consulta(`altas_socio?id=eq.${alta.id}`, {
    method: "PATCH",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify({ stripe_session_id: sesion.id ?? null }),
  });

  return responder({ url: sesion.url, referencia: refPago, importe_cent: importeCent, modo }, 200, origen);
});
