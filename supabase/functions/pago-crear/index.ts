// ============================================================
// pago-crear · abre una sesión de pago con tarjeta (Stripe Checkout)
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   El navegador dice: «quiero pagar el bono-cubo-10 para este
//   atleta». Esta función comprueba quién es, mira EN LA BASE cuánto
//   vale de verdad eso, apunta el pago y devuelve la dirección de la
//   pasarela de Stripe. El navegador solo tiene que ir a esa
//   dirección. Los datos de la tarjeta NUNCA pasan por la web del
//   club: se teclean en la página de Stripe.
//
// LO QUE NO SE FÍA DEL NAVEGADOR (todo, básicamente)
//   · El importe. Lo calcula `pagos_iniciar()` dentro de la base
//     leyendo el catálogo. Si el navegador manda un importe, se tira
//     a la basura. Es el mismo fallo que ya se corrigió en la tienda:
//     si el precio lo pone el cliente, se compra un bono por 1 céntimo.
//   · Quién es. Se comprueba el JWT contra Supabase, no se cree el
//     correo que venga en el cuerpo de la petición.
//   · De qué atleta es. Se comprueba que ese atleta sea suyo (o de un
//     hijo suyo); si no, no se abre el pago.
//
// CLAVES
//   Se leen de las variables de entorno de Supabase. En este archivo
//   no hay ni puede haber ninguna:
//     STRIPE_SECRET_KEY          (la pones tú en Supabase)
//     SUPABASE_URL               (la pone Supabase sola)
//     SUPABASE_SERVICE_ROLE_KEY  (la pone Supabase sola)
//     SUPABASE_ANON_KEY          (la pone Supabase sola)
//   Opcionales, para las páginas de vuelta:
//     PAGOS_URL_BASE, PAGOS_URL_OK, PAGOS_URL_KO
//
// Si falta cualquier clave, la función contesta «todavía no está
// activado» con buenos modales. No revienta ni deja botones muertos.
//
// Cómo se despliega:  supabase functions deploy pago-crear
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";

// A dónde vuelve la persona desde Stripe. Mientras no existan las
// pantallas de «pago hecho», vuelve a la portada con un aviso en la
// dirección, que siempre existe y nunca da un 404.
const URL_BASE = (Deno.env.get("PAGOS_URL_BASE") ?? "https://escuelaapolana.github.io/WebV2/")
  .replace(/\/*$/, "/");
const URL_OK = Deno.env.get("PAGOS_URL_OK") ?? `${URL_BASE}?pago=hecho`;
const URL_KO = Deno.env.get("PAGOS_URL_KO") ?? `${URL_BASE}?pago=cancelado`;

// --- Cabeceras para que el navegador pueda llamarnos ---
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

// --- Hablar con la base con la llave de servicio ---
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

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") {
    return responder({ error: "Método no admitido." }, 405, origen);
  }

  // ---------------------------------------------------------------
  // 0 · ¿Está todo montado? Si falta una clave, se dice sin dramas.
  // ---------------------------------------------------------------
  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ error: "config", mensaje: "El pago con tarjeta no está configurado." }, 503, origen);
  }
  if (!STRIPE_KEY) {
    return responder({
      error: "no_activado",
      mensaje: "El pago con tarjeta todavía no está activado. Escríbenos y te decimos cómo pagarlo.",
    }, 503, origen);
  }

  // ---------------------------------------------------------------
  // 1 · ¿Quién eres? Se comprueba el JWT de verdad, contra Supabase.
  // ---------------------------------------------------------------
  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  if (!jwt) {
    return responder({ error: "sin_sesion", mensaje: "Entra en tu cuenta para poder pagar." }, 401, origen);
  }

  const rUsuario = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` },
  });
  if (!rUsuario.ok) {
    return responder({ error: "sin_sesion", mensaje: "Tu sesión ha caducado. Vuelve a entrar." }, 401, origen);
  }
  const usuario = await rUsuario.json();
  const correo: string = (usuario?.email ?? "").toLowerCase();
  if (!correo) {
    return responder({ error: "sin_sesion", mensaje: "No hemos podido identificarte." }, 401, origen);
  }

  // ---------------------------------------------------------------
  // 2 · Qué quiere pagar (lo ÚNICO que se le acepta al navegador)
  // ---------------------------------------------------------------
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* cuerpo vacío */ }

  const clave = String(cuerpo.clave ?? cuerpo.tipo ?? "").trim();
  const atletaId = cuerpo.atleta_id ? String(cuerpo.atleta_id).trim() : null;
  // Nota deliberada: si viene un `importe`, se ignora. El precio sale de la base.

  if (!clave) {
    return responder({ error: "falta_clave", mensaje: "No sabemos qué quieres pagar." }, 400, origen);
  }

  // ---------------------------------------------------------------
  // 3 · Su ficha y sus atletas (nada de fiarse de lo que mande)
  // ---------------------------------------------------------------
  const rPerfil = await consulta(
    `perfiles?select=id,nombre,apellidos,email&email=eq.${encodeURIComponent(correo)}&limit=1`,
  );
  const perfil = Array.isArray(rPerfil.datos) ? rPerfil.datos[0] : null;
  if (!perfil?.id) {
    return responder({ error: "sin_ficha", mensaje: "Tu cuenta todavía no está enlazada con una ficha del club." }, 403, origen);
  }

  if (atletaId) {
    const rAtleta = await consulta(
      `atletas?select=id&id=eq.${encodeURIComponent(atletaId)}` +
      `&or=(perfil_id.eq.${perfil.id},perfil_padre_id.eq.${perfil.id})&limit=1`,
    );
    const suyo = Array.isArray(rAtleta.datos) && rAtleta.datos.length > 0;
    if (!suyo) {
      return responder({ error: "atleta_ajeno", mensaje: "Ese atleta no es tuyo." }, 403, origen);
    }
  }

  // ---------------------------------------------------------------
  // 4 · Abrir el pago EN LA BASE · aquí es donde nace el importe
  // ---------------------------------------------------------------
  const rPago = await consulta("rpc/pagos_iniciar", {
    method: "POST",
    body: JSON.stringify({
      p_clave: clave,
      p_perfil: perfil.id,
      p_atleta: atletaId,
      p_metadatos: { origen: "web", nota: cuerpo.nota ?? null },
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
  // 5 · La sesión de Stripe
  // ---------------------------------------------------------------
  // Se llama a la API de Stripe con `fetch` a pelo, sin librerías: son
  // dos peticiones y así no hay una dependencia más que actualizar.
  const params = new URLSearchParams();
  params.set("mode", "payment");
  params.set("locale", "es");
  params.set("client_reference_id", pago.referencia);
  params.set("customer_email", correo);
  params.set("success_url", `${URL_OK}${URL_OK.includes("?") ? "&" : "?"}ref=${pago.referencia}`);
  params.set("cancel_url", `${URL_KO}${URL_KO.includes("?") ? "&" : "?"}ref=${pago.referencia}`);
  params.set("line_items[0][quantity]", "1");
  params.set("line_items[0][price_data][currency]", pago.moneda ?? "eur");
  params.set("line_items[0][price_data][unit_amount]", String(pago.importe_centimos));
  params.set("line_items[0][price_data][product_data][name]", pago.concepto);
  params.set("line_items[0][price_data][product_data][description]", `Club Atletismo Apolana · ${pago.referencia}`);
  // La referencia viaja por partida doble: en la sesión y en el cobro.
  // Así el aviso de Stripe siempre trae con qué pago casarlo.
  params.set("metadata[referencia]", pago.referencia);
  params.set("payment_intent_data[metadata][referencia]", pago.referencia);
  params.set("payment_intent_data[description]", `${pago.concepto} · ${pago.referencia}`);

  const rStripe = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${STRIPE_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
      // Si esta misma petición se repite (doble clic, mala cobertura),
      // Stripe devuelve la sesión que ya creó en vez de crear otra.
      "Idempotency-Key": `apolana-${pago.referencia}`,
    },
    body: params.toString(),
  });

  const sesion = await rStripe.json().catch(() => null);

  if (!rStripe.ok || !sesion?.url) {
    // El pago queda marcado como fallido para que no se quede colgando
    // en «iniciado» para siempre en el panel.
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

  // Se apunta la sesión para poder cruzarla luego desde el panel.
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
