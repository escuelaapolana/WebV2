// ============================================================
// nevera-pagar · paga las bebidas de la nevera de la instalación
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   La página escondida /nevera/ (a la que lleva el QR pegado en la
//   nevera) manda QUÉ bebidas y CUÁNTAS. Esta función mira EN LA BASE
//   cuánto vale cada una (`nevera_venta_iniciar`), crea la venta y su
//   pago, y abre la pasarela de Stripe (tarjeta, Apple Pay, Google Pay).
//   El dinero va a la cuenta de Stripe de ÍTAKA, como la ropa: la misma
//   clave STRIPE_SECRET_KEY y el mismo webhook `pago-webhook`, que casa
//   el pago por `metadata.referencia` y marca la venta pagada.
//
//   Segunda tarea, { comprobar: "NEV-…" }: la pantalla «Pagado ✓» pide
//   que se mire en STRIPE si esa venta está cobrada. Si Stripe dice que sí,
//   se confirma aquí mismo (pagos_confirmar es idempotente). Así la persona
//   ve su «Pagado ✓» aunque el aviso del webhook tarde o no llegue. No se
//   fía del navegador: quien dice «pagado» es Stripe.
//
// LO QUE NO SE FÍA DEL NAVEGADOR
//   · Los precios: los pone la base. Si llega un importe, se ignora.
//   · No hay sesión ni datos personales: no se pide nada a nadie.
//
// CLAVES (variables de entorno de Supabase; aquí no hay ninguna)
//     STRIPE_SECRET_KEY   (la de ÍTAKA; la misma que tienda-pagar)
//     SUPABASE_URL / SERVICE_ROLE_KEY  (las pone Supabase)
//   Opcional: PAGOS_ORIGENES (se suman a los orígenes de abajo)
//
// Se despliega SIN comprobar el JWT (quien paga no tiene cuenta):
//     supabase functions deploy nevera-pagar --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";

const WEB = "https://atletismoapolana.com";
const ORIGENES = new Set([
  WEB,
  "https://www.atletismoapolana.com",
  "https://escuelaapolana.github.io",
  "http://localhost:8137",
  "http://127.0.0.1:8137",
  ...(Deno.env.get("PAGOS_ORIGENES") ?? "").split(",").map((s) => s.trim()).filter(Boolean),
]);

function cors(origen: string | null): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": origen && ORIGENES.has(origen) ? origen : WEB,
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

// A dónde vuelve la persona: a la web, o al servidor local si se está probando.
function paginaNevera(origen: string | null): string {
  if (origen && /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origen)) return `${origen}/nevera/`;
  return `${WEB}/nevera/`;
}

async function rpc(nombre: string, args: Record<string, unknown>) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${nombre}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(args),
  });
  const texto = await r.text();
  let datos: unknown = null;
  try { datos = texto ? JSON.parse(texto) : null; } catch { datos = texto; }
  return { ok: r.ok, estado: r.status, datos };
}

// Freno sencillo por IP (por instancia): nadie abre 20 pasarelas en 10 minutos
// delante de una nevera. La base tiene su propio freno para llamadas directas.
const visitas = new Map<string, number[]>();
function demasiadas(ip: string): boolean {
  const ahora = Date.now();
  const lista = (visitas.get(ip) ?? []).filter((t) => ahora - t < 10 * 60 * 1000);
  lista.push(ahora);
  visitas.set(ip, lista);
  if (visitas.size > 5000) visitas.clear();
  return lista.length > 20;
}

function limpiarItems(bruto: unknown): Array<{ producto_id: string; cantidad: number }> {
  if (!Array.isArray(bruto)) return [];
  return bruto.slice(0, 20).map((l) => {
    const o = (l ?? {}) as Record<string, unknown>;
    return {
      producto_id: String(o.producto_id ?? o.id ?? "").trim().slice(0, 64),
      cantidad: Math.round(Number(o.cantidad ?? 0)) || 0,
    };
  }).filter((l) => l.producto_id && l.cantidad > 0);
}

// ---- Comprobar en Stripe si una venta está cobrada --------------------------
async function comprobar(ref: string, origen: string | null): Promise<Response> {
  if (!/^NEV-\d{6}-[A-Z0-9]{6}$/.test(ref)) {
    return responder({ estado: "no_existe" }, 200, origen);
  }
  const rEstado = await rpc("nevera_venta_estado", { p_ref: ref });
  let estado = (rEstado.datos ?? {}) as Record<string, any>;
  if (estado.estado !== "pendiente" || !STRIPE_KEY) return responder(estado, 200, origen);

  const rPago = await fetch(
    `${SUPABASE_URL}/rest/v1/pagos_online?select=stripe_session_id&tipo=eq.nevera&referencia=eq.${encodeURIComponent(ref)}&limit=1`,
    { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } },
  );
  const filas = await rPago.json().catch(() => []);
  const sesionId: string = Array.isArray(filas) && filas[0]?.stripe_session_id ? filas[0].stripe_session_id : "";
  if (!sesionId) return responder(estado, 200, origen);

  const rS = await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sesionId)}`, {
    headers: { Authorization: `Bearer ${STRIPE_KEY}` },
  });
  const s = await rS.json().catch(() => null);
  if (rS.ok && s?.payment_status === "paid" && (s?.metadata?.referencia === ref || s?.client_reference_id === ref)) {
    await rpc("pagos_confirmar", {
      p_referencia: ref,
      p_session: s.id,
      p_intent: typeof s.payment_intent === "string" ? s.payment_intent : null,
      p_evento: null,
    });
    const r2 = await rpc("nevera_venta_estado", { p_ref: ref });
    estado = (r2.datos ?? estado) as Record<string, any>;
  } else if (rS.ok && s?.status === "expired") {
    await rpc("pagos_marcar", { p_referencia: ref, p_estado: "cancelado", p_evento: null });
    const r2 = await rpc("nevera_venta_estado", { p_ref: ref });
    estado = (r2.datos ?? estado) as Record<string, any>;
  }
  return responder(estado, 200, origen);
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ error: "config", mensaje: "El pago no está configurado." }, 503, origen);
  }

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }

  if (typeof cuerpo.comprobar === "string") {
    return await comprobar(String(cuerpo.comprobar).trim().toUpperCase().slice(0, 40), origen);
  }

  if (!STRIPE_KEY) {
    return responder({ error: "no_activado", mensaje: "El pago con tarjeta no está activado. Usa el datáfono de la nevera." }, 503, origen);
  }

  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "?";
  if (demasiadas(ip)) {
    return responder({ error: "espera", mensaje: "Demasiados intentos seguidos. Espera unos minutos." }, 429, origen);
  }

  const items = limpiarItems(cuerpo.items);
  if (!items.length) {
    return responder({ error: "vacio", mensaje: "Elige al menos una bebida." }, 400, origen);
  }

  // 1 · La venta y su pago, EN LA BASE (precios de la base).
  const rVenta = await rpc("nevera_venta_iniciar", { p_items: items });
  if (!rVenta.ok) {
    const msg = (rVenta.datos as { message?: string } | null)?.message ?? "";
    return responder({ error: "no_se_puede", mensaje: msg || "No se ha podido preparar el pago." }, 400, origen);
  }
  const venta = rVenta.datos as Record<string, any> | null;
  if (!venta?.referencia || !Array.isArray(venta.items)) {
    return responder({ error: "interno", mensaje: "No se ha podido preparar el pago." }, 500, origen);
  }
  const ref: string = venta.referencia;

  // 2 · La pasarela de Stripe: una línea por bebida, con el precio de la base.
  //     Solo `card`: Apple Pay y Google Pay van dentro de «tarjeta» y salen
  //     solos en el móvil. Así NO se ofrecen SEPA ni Klarna (en la cuenta de
  //     Ítaka están activos), que tardan días y no darían el «Pagado ✓» al momento.
  const pagina = paginaNevera(origen);
  const params = new URLSearchParams();
  params.set("mode", "payment");
  params.set("locale", "es");
  params.set("submit_type", "pay");
  params.set("payment_method_types[0]", "card");
  params.set("client_reference_id", ref);
  params.set("success_url", `${pagina}?ref=${ref}`);
  params.set("cancel_url", `${pagina}?cancelado=${ref}`);
  venta.items.forEach((l: Record<string, any>, i: number) => {
    params.set(`line_items[${i}][quantity]`, String(l.cantidad));
    params.set(`line_items[${i}][price_data][currency]`, venta.moneda ?? "eur");
    params.set(`line_items[${i}][price_data][unit_amount]`, String(l.precio_cent));
    params.set(`line_items[${i}][price_data][product_data][name]`, String(l.nombre));
  });
  params.set("metadata[referencia]", ref);
  params.set("metadata[origen]", "nevera");
  params.set("payment_intent_data[metadata][referencia]", ref);
  params.set("payment_intent_data[description]", `Nevera Apolana · ${ref}`);
  params.set("payment_intent_data[statement_descriptor_suffix]", "NEVERA");
  params.set("custom_text[submit][message]", "Nevera Apolana · bebidas de la instalación. Al pagar verás «Pagado ✓»: enséñalo si te lo piden.");

  const rStripe = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${STRIPE_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key": `apolana-${ref}`,
    },
    body: params.toString(),
  });
  const sesion = await rStripe.json().catch(() => null);

  if (!rStripe.ok || !sesion?.url) {
    await rpc("pagos_marcar", { p_referencia: ref, p_estado: "fallido", p_evento: null });
    console.error("Stripe rechazó la sesión de la nevera:", sesion?.error?.message ?? rStripe.status);
    return responder({
      error: "pasarela",
      mensaje: "La pasarela de pago no ha respondido. Prueba otra vez o usa el datáfono.",
    }, 502, origen);
  }

  await fetch(`${SUPABASE_URL}/rest/v1/pagos_online?referencia=eq.${encodeURIComponent(ref)}`, {
    method: "PATCH",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ stripe_session_id: sesion.id }),
  });

  return responder({ url: sesion.url, referencia: ref, importe_centimos: venta.importe_centimos }, 200, origen);
});
