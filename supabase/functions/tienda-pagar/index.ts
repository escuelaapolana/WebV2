// ============================================================
// tienda-pagar · abre el pago con tarjeta de un pedido de la tienda
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   El navegador manda el CARRITO (qué prendas, tallas y cuántas) y,
//   si compra sin cuenta, sus datos de contacto. Esta función mira EN
//   LA BASE cuánto vale de verdad cada prenda, crea el pedido y su
//   pago, y devuelve la dirección de la pasarela de Stripe. La tarjeta
//   NUNCA pasa por la web: se teclea en la página de Stripe.
//
// LO QUE NO SE FÍA DEL NAVEGADOR
//   · Los precios. Los pone `tienda_pago_iniciar()` leyendo `productos`.
//     Si el navegador manda un importe, se tira a la basura.
//   · Quién es. NO hace falta sesión (la ropa se vende también a
//     invitados). Pero SI viene una sesión válida, se enlaza el pedido
//     a su ficha de socio. Si el token no vale, se sigue como invitado.
//
// CLAVES (variables de entorno de Supabase; aquí no hay ninguna)
//     STRIPE_SECRET_KEY          (la de ITAKA; la pones tú en Supabase)
//     SUPABASE_URL / SERVICE_ROLE_KEY / ANON_KEY  (las pone Supabase)
//   Opcionales: PAGOS_URL_BASE, PAGOS_URL_OK, PAGOS_URL_KO, PAGOS_ORIGENES
//
// Se despliega SIN comprobar el JWT (el invitado no tiene sesión; la
// función ya trata el token como opcional):
//     supabase functions deploy tienda-pagar --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";

const URL_BASE = (Deno.env.get("PAGOS_URL_BASE") ?? "https://escuelaapolana.github.io/WebV2/")
  .replace(/\/*$/, "/");

// La ropa vuelve siempre a la tienda: es donde se ve la cesta y el aviso.
function vuelta(resultado: "hecho" | "cancelado"): string {
  const puesta = Deno.env.get(resultado === "hecho" ? "PAGOS_URL_OK" : "PAGOS_URL_KO");
  if (puesta) return puesta;
  return `${URL_BASE}tienda/?pago=${resultado}`;
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

// Solo se le acepta al navegador el carrito y el contacto; nada de dinero.
function limpiarItems(bruto: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(bruto)) return [];
  return bruto.slice(0, 50).map((l) => {
    const o = (l ?? {}) as Record<string, unknown>;
    return {
      producto_id: String(o.producto_id ?? o.id ?? "").trim(),
      talla: o.talla != null ? String(o.talla).trim() : "",
      cantidad: Math.max(1, Math.min(10, Math.round(Number(o.cantidad ?? 1)) || 1)),
    };
  }).filter((l) => l.producto_id);
}

function limpiarContacto(bruto: unknown): Record<string, string> {
  const o = (bruto ?? {}) as Record<string, unknown>;
  const corta = (v: unknown, n: number) => String(v ?? "").trim().slice(0, n);
  return {
    nombre: corta(o.nombre, 120),
    email: corta(o.email, 160).toLowerCase(),
    telefono: corta(o.telefono, 40),
    recogida: corta(o.recogida, 120),
    nota: corta(o.nota, 300),
  };
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ error: "config", mensaje: "El pago con tarjeta no está configurado." }, 503, origen);
  }
  if (!STRIPE_KEY) {
    return responder({
      error: "no_activado",
      mensaje: "El pago con tarjeta todavía no está activado. Escríbenos y te decimos cómo pagar tu pedido.",
    }, 503, origen);
  }

  // ---------------------------------------------------------------
  // 1 · Sesión OPCIONAL. Si hay token y vale, se enlaza a su ficha.
  //     Si no, se compra como invitado (la ropa es pública).
  // ---------------------------------------------------------------
  let perfilId: string | null = null;
  let correoSocio = "";
  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  // Ojo: el token del anon de Supabase también llega aquí; solo nos vale
  // si identifica a una PERSONA (tiene email). Si no, se ignora sin más.
  if (jwt) {
    const rUsuario = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` },
    });
    if (rUsuario.ok) {
      const usuario = await rUsuario.json().catch(() => null);
      const correo: string = (usuario?.email ?? "").toLowerCase();
      if (correo) {
        correoSocio = correo;
        const rPerfil = await consulta(
          `perfiles?select=id&email=eq.${encodeURIComponent(correo)}&limit=1`,
        );
        const perfil = Array.isArray(rPerfil.datos) ? rPerfil.datos[0] : null;
        perfilId = perfil?.id ?? null;
      }
    }
  }

  // ---------------------------------------------------------------
  // 2 · El carrito y el contacto (lo ÚNICO que se acepta del navegador)
  // ---------------------------------------------------------------
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }

  const items = limpiarItems(cuerpo.items ?? cuerpo.carrito);
  const contacto = limpiarContacto(cuerpo.contacto);

  if (!items.length) {
    return responder({ error: "carrito_vacio", mensaje: "Tu cesta está vacía." }, 400, origen);
  }
  // A un invitado le pedimos al menos nombre y una forma de contactar.
  if (!perfilId && (!contacto.nombre || !(contacto.email || contacto.telefono))) {
    return responder({
      error: "faltan_datos",
      mensaje: "Para comprar sin cuenta necesitamos tu nombre y un correo o teléfono.",
    }, 400, origen);
  }

  // ---------------------------------------------------------------
  // 3 · Abrir el pago EN LA BASE · aquí nacen el pedido y el importe
  // ---------------------------------------------------------------
  const rPago = await consulta("rpc/tienda_pago_iniciar", {
    method: "POST",
    body: JSON.stringify({
      p_items: items,
      p_contacto: contacto,
      p_perfil: perfilId,
      p_metadatos: { origen: perfilId ? "app" : "web" },
    }),
  });

  if (!rPago.ok) {
    const msg = (rPago.datos as { message?: string } | null)?.message ?? "";
    const apagado = msg.includes("no está activado");
    return responder({
      error: apagado ? "no_activado" : "no_se_puede",
      mensaje: msg || "No se ha podido preparar el pago.",
    }, apagado ? 503 : 400, origen);
  }

  const pago = (Array.isArray(rPago.datos) ? rPago.datos[0] : rPago.datos) as
    Record<string, any> | null;
  if (!pago?.referencia) {
    return responder({ error: "interno", mensaje: "No se ha podido preparar el pago." }, 500, origen);
  }

  // ---------------------------------------------------------------
  // 4 · La sesión de Stripe (importe y concepto, de la base)
  // ---------------------------------------------------------------
  const emailPagador = perfilId ? correoSocio : contacto.email;
  const params = new URLSearchParams();
  params.set("mode", "payment");
  params.set("locale", "es");
  params.set("client_reference_id", pago.referencia);
  if (emailPagador) params.set("customer_email", emailPagador);
  const urlOk = vuelta("hecho");
  const urlKo = vuelta("cancelado");
  params.set("success_url", `${urlOk}${urlOk.includes("?") ? "&" : "?"}ref=${pago.referencia}`);
  params.set("cancel_url", `${urlKo}${urlKo.includes("?") ? "&" : "?"}ref=${pago.referencia}`);
  params.set("line_items[0][quantity]", "1");
  params.set("line_items[0][price_data][currency]", pago.moneda ?? "eur");
  params.set("line_items[0][price_data][unit_amount]", String(pago.importe_centimos));
  params.set("line_items[0][price_data][product_data][name]", pago.concepto);
  params.set("line_items[0][price_data][product_data][description]", `Club Atletismo Apolana · ${pago.referencia}`);
  params.set("metadata[referencia]", pago.referencia);
  params.set("payment_intent_data[metadata][referencia]", pago.referencia);
  params.set("payment_intent_data[description]", `${pago.concepto} · ${pago.referencia}`);

  const rStripe = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${STRIPE_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key": `apolana-${pago.referencia}`,
    },
    body: params.toString(),
  });

  const sesion = await rStripe.json().catch(() => null);

  if (!rStripe.ok || !sesion?.url) {
    await consulta("rpc/pagos_marcar", {
      method: "POST",
      body: JSON.stringify({ p_referencia: pago.referencia, p_estado: "fallido", p_evento: null }),
    });
    console.error("Stripe rechazó la sesión:", sesion?.error?.message ?? rStripe.status);
    return responder({
      error: "pasarela",
      mensaje: "La pasarela de pago no ha respondido. Vuelve a intentarlo en un minuto.",
    }, 502, origen);
  }

  await consulta(`pagos_online?referencia=eq.${encodeURIComponent(pago.referencia)}`, {
    method: "PATCH",
    body: JSON.stringify({ stripe_session_id: sesion.id }),
  });

  return responder({
    url: sesion.url,
    referencia: pago.referencia,
    importe_centimos: pago.importe_centimos,
    concepto: pago.concepto,
  }, 200, origen);
});
