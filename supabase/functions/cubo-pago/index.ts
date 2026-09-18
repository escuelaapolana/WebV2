// ============================================================
// cubo-pago · ajustes de cobro de la cuota del Cubo (solo admin)
// ------------------------------------------------------------
// QUÉ HACE
//   Desde el panel, el club ajusta el cobro de una persona del Cubo. Acciones:
//     · saltar_mes  → no cobrarle el próximo recibo (viaje, vacaciones): mete un
//                     abono (recibo-item negativo) por el importe de su cuota.
//     · cargo       → suma un importe al próximo recibo (p. ej. el mes aplazado,
//                     material…). `importe` en €, `concepto` es el texto.
//     · descuento   → resta un importe del próximo recibo.
//     · cuota       → cambia su cuota mensual a `importe` € (de ahí en adelante).
//   «Aplazar/juntar dos meses» = saltar_mes este mes + cargo del importe el mes
//   siguiente (lo hace el club con los dos botones).
//
//   Comprueba que quien llama es admin. Usa Stripe (recibos-item y cambio de
//   precio de la suscripción). No cobra nada al instante: los ajustes caen en el
//   próximo recibo de la suscripción.
//
// CLAVES (secretos de Supabase): STRIPE_SECRET_KEY_APOLANA / SUPABASE_URL /
//   SUPABASE_SERVICE_ROLE_KEY / SUPABASE_ANON_KEY
//   supabase functions deploy cubo-pago --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";

function cors(o: string | null): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": o ?? "*",
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
type Op = Omit<RequestInit, "headers"> & { headers?: Record<string, string> };
async function rest(ruta: string, op: Op = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...op,
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", ...(op.headers ?? {}) },
  });
  const t = await r.text();
  let d: unknown = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, estado: r.status, datos: d };
}
// Llamada a Stripe con cuerpo form-url-encoded (lo que espera su API).
async function stripe(ruta: string, metodo: string, campos?: Record<string, string>) {
  const init: RequestInit = { method: metodo, headers: { Authorization: `Bearer ${STRIPE_KEY}` } };
  if (campos) {
    (init.headers as Record<string, string>)["Content-Type"] = "application/x-www-form-urlencoded";
    init.body = new URLSearchParams(campos).toString();
  }
  const r = await fetch(`https://api.stripe.com/v1/${ruta}`, init);
  const d = await r.json().catch(() => null);
  return { ok: r.ok, estado: r.status, datos: d };
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY || !STRIPE_KEY) {
    return responder({ error: "config", mensaje: "No está configurado." }, 503, origen);
  }

  // 1 · Sesión y que sea ADMIN
  const cab = req.headers.get("Authorization") ?? "";
  const jwt = cab.toLowerCase().startsWith("bearer ") ? cab.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sesion" }, 401, origen);
  const rU = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` } });
  if (!rU.ok) return responder({ error: "sesion" }, 401, origen);
  const correo: string = ((await rU.json().catch(() => null))?.email ?? "").toLowerCase();
  if (!correo) return responder({ error: "sesion" }, 401, origen);
  const rP = await rest(`perfiles?select=rol,rol_activo,roles&email=eq.${encodeURIComponent(correo)}&limit=1`);
  const p = Array.isArray(rP.datos) ? rP.datos[0] : null;
  const roles: string[] = [p?.rol, p?.rol_activo, ...(Array.isArray(p?.roles) ? p.roles : [])].filter(Boolean);
  const esAdmin = roles.some((r) => ["admin", "tesoreria", "contabilidad", "junta"].includes(r));
  if (!esAdmin) return responder({ error: "no_admin", mensaje: "Solo el club puede ajustar los pagos." }, 403, origen);

  // 2 · Datos de la ficha + la acción
  let cuerpo: Record<string, any> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const altaId = String(cuerpo.alta_id ?? "").trim();
  const accion = String(cuerpo.accion ?? "").trim();
  const importe = Math.round(Number(cuerpo.importe) * 100);   // € → céntimos
  const concepto = String(cuerpo.concepto ?? "").slice(0, 120).trim();
  if (!altaId) return responder({ error: "datos", mensaje: "Falta la ficha." }, 400, origen);

  const rA = await rest(`cubo_altas?select=id,stripe_subscription_id,stripe_customer_id,precio_mes,nombre,apellidos&id=eq.${encodeURIComponent(altaId)}&limit=1`);
  const alta = Array.isArray(rA.datos) ? rA.datos[0] : null;
  if (!alta) return responder({ error: "no_existe", mensaje: "Esa ficha ya no está." }, 404, origen);
  const sub: string = alta.stripe_subscription_id ?? "";
  const cliente: string = alta.stripe_customer_id ?? "";
  if (!sub || !cliente) {
    return responder({ error: "sin_sub", mensaje: "Esta persona aún no tiene la cuota activa (sin tarjeta). Los ajustes se pueden hacer cuando ya paga." }, 409, origen);
  }

  // 3 · La acción
  if (accion === "saltar_mes" || accion === "cargo" || accion === "descuento") {
    // Recibo-item que cae en el PRÓXIMO recibo de la suscripción.
    let cents = 0, texto = concepto;
    if (accion === "saltar_mes") {
      cents = -Math.abs(Math.round(Number(alta.precio_mes) * 100));
      texto = concepto || "Mes no cobrado (ausencia)";
    } else {
      if (!Number.isFinite(importe) || importe <= 0) return responder({ error: "datos", mensaje: "Pon un importe válido." }, 400, origen);
      cents = accion === "descuento" ? -Math.abs(importe) : Math.abs(importe);
      texto = concepto || (accion === "descuento" ? "Descuento" : "Cargo");
    }
    const r = await stripe("invoiceitems", "POST", {
      customer: cliente, subscription: sub, currency: "eur",
      amount: String(cents), description: texto,
    });
    if (!r.ok) {
      console.error("Stripe invoiceitem:", r.datos?.error?.message ?? r.estado);
      return responder({ error: "pasarela", mensaje: "Stripe no lo aceptó: " + (r.datos?.error?.message ?? "inténtalo otra vez") }, 502, origen);
    }
    return responder({ ok: true, accion, cents }, 200, origen);
  }

  if (accion === "cuota") {
    if (!Number.isFinite(importe) || importe <= 0) return responder({ error: "datos", mensaje: "Pon una cuota válida." }, 400, origen);
    // Hace falta el item de la suscripción y el producto de su precio actual.
    const rSub = await stripe(`subscriptions/${encodeURIComponent(sub)}?expand[]=items.data.price`, "GET");
    if (!rSub.ok) return responder({ error: "pasarela", mensaje: "No se ha podido leer la suscripción." }, 502, origen);
    const item = rSub.datos?.items?.data?.[0];
    const producto: string = item?.price?.product ?? "";
    if (!item?.id || !producto) return responder({ error: "pasarela", mensaje: "No se ha podido identificar el precio actual." }, 502, origen);
    // Precio nuevo (mensual) para ese producto.
    const rPrice = await stripe("prices", "POST", {
      currency: "eur", unit_amount: String(Math.abs(importe)),
      "recurring[interval]": "month", product: producto,
    });
    if (!rPrice.ok) return responder({ error: "pasarela", mensaje: "No se ha podido crear el precio nuevo." }, 502, origen);
    const precioId: string = rPrice.datos?.id ?? "";
    // Cambiar el item de la suscripción al precio nuevo, sin prorrateo.
    const rUpd = await stripe(`subscriptions/${encodeURIComponent(sub)}`, "POST", {
      "items[0][id]": item.id, "items[0][price]": precioId, proration_behavior: "none",
    });
    if (!rUpd.ok) {
      console.error("Stripe update sub:", rUpd.datos?.error?.message ?? rUpd.estado);
      return responder({ error: "pasarela", mensaje: "Stripe no cambió la cuota: " + (rUpd.datos?.error?.message ?? "inténtalo otra vez") }, 502, origen);
    }
    await rest(`cubo_altas?id=eq.${encodeURIComponent(altaId)}`, {
      method: "PATCH", headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ precio_mes: Math.round(Math.abs(importe) / 100) }),
    });
    return responder({ ok: true, accion, precio_mes: Math.round(Math.abs(importe) / 100) }, 200, origen);
  }

  return responder({ error: "accion", mensaje: "Acción no reconocida." }, 400, origen);
});
