// ============================================================
// cubo-resync · Re-sincronizar los pagos del Cubo con Stripe
// ------------------------------------------------------------
// El webhook (`cubo-webhook`) es quien normalmente escribe en
// `cubo_altas` el estado de la cuota y las fechas de último y
// próximo cobro. Pero si a alguien no le llega un evento (falло de
// entrega, un corte…), esa ficha se queda desfasada — le pasó a
// Gloria: activa pero sin fechas.
//
// Esta función le PREGUNTA a Stripe la verdad de cada suscripción
// (estado, fin del periodo actual = próximo cobro, y la fecha de la
// última factura pagada = último cobro) y rellena lo que falte. Es
// idempotente: se puede lanzar las veces que haga falta.
//
// Solo la puede llamar el club (admin/tesorería/contabilidad/junta).
//
// CLAVES (secretos de Supabase): STRIPE_SECRET_KEY_APOLANA /
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / SUPABASE_ANON_KEY
//
// DESPLIEGUE:
//   supabase functions deploy cubo-resync --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";

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
async function stripeGet(ruta: string) {
  const r = await fetch(`https://api.stripe.com/v1/${ruta}`, {
    method: "GET",
    headers: { Authorization: `Bearer ${STRIPE_KEY}` },
  });
  const d = await r.json().catch(() => null);
  return { ok: r.ok, estado: r.status, datos: d };
}

function aFecha(unix?: number | null): string | null {
  if (unix == null || !Number.isFinite(Number(unix))) return null;
  return new Date(Number(unix) * 1000).toISOString();
}
function estadoDe(s: string): "activa" | "impago" | "cancelada" | null {
  if (s === "active" || s === "trialing") return "activa";
  if (s === "past_due" || s === "unpaid" || s === "incomplete") return "impago";
  if (s === "canceled" || s === "incomplete_expired") return "cancelada";
  return null;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (origen && !ORIGENES_OK.includes(origen)) {
    return responder({ error: "origen", mensaje: "Origen no permitido." }, 403, origen);
  }
  if (!SUPABASE_URL || !SERVICE_KEY || !STRIPE_KEY) {
    return responder({ error: "config", mensaje: "No está configurado." }, 503, origen);
  }

  // 1 · Sesión y que sea ADMIN (mismo criterio que cubo-pago)
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
  if (!esAdmin) return responder({ error: "no_admin", mensaje: "Solo el club puede re-sincronizar." }, 403, origen);

  // 2 · Qué fichas: una (alta_id) o todas las que tienen suscripción
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const altaId = String((cuerpo.alta_id ?? "")).trim();

  const filtro = altaId
    ? `cubo_altas?select=id,nombre,apellidos,stripe_subscription_id&id=eq.${encodeURIComponent(altaId)}`
    : `cubo_altas?select=id,nombre,apellidos,stripe_subscription_id&stripe_subscription_id=not.is.null&estado=neq.rechazada`;
  const rA = await rest(filtro);
  const altas: Array<{ id: string; nombre: string; apellidos: string; stripe_subscription_id: string }> =
    Array.isArray(rA.datos) ? rA.datos : [];
  if (!altas.length) return responder({ ok: true, revisadas: 0, actualizadas: 0, detalle: [] }, 200, origen);

  const detalle: Array<Record<string, unknown>> = [];
  let actualizadas = 0;

  for (const a of altas) {
    const sub = a.stripe_subscription_id;
    if (!sub) continue;
    // Traemos la suscripción con su última factura expandida.
    const rS = await stripeGet(`subscriptions/${encodeURIComponent(sub)}?expand[]=latest_invoice`);
    if (!rS.ok || !rS.datos || rS.datos.error) {
      detalle.push({ id: a.id, nombre: `${a.nombre} ${a.apellidos}`.trim(), error: rS.datos?.error?.message ?? `Stripe ${rS.estado}` });
      continue;
    }
    const s: any = rS.datos;
    // Próximo cobro = fin del periodo actual (o fin de la prueba).
    const proximo =
      aFecha(s.current_period_end) ??
      aFecha(s.items?.data?.[0]?.current_period_end) ??
      aFecha(s.trial_end);
    // Último cobro = fecha de pago de la última factura, si está pagada.
    const inv: any = s.latest_invoice;
    const ultimo =
      inv && inv.status === "paid"
        ? (aFecha(inv.status_transitions?.paid_at) ?? aFecha(inv.created))
        : null;
    const estado = estadoDe(String(s.status ?? ""));

    const cambios: Record<string, unknown> = {};
    if (estado) cambios.suscripcion_estado = estado;
    if (proximo) cambios.proximo_cobro = proximo;
    if (ultimo) cambios.ultimo_cobro = ultimo;

    if (Object.keys(cambios).length) {
      const rW = await rest(`cubo_altas?id=eq.${encodeURIComponent(a.id)}`, {
        method: "PATCH",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify(cambios),
      });
      if (rW.ok) actualizadas++;
      detalle.push({
        id: a.id, nombre: `${a.nombre} ${a.apellidos}`.trim(),
        estado, ultimo_cobro: ultimo, proximo_cobro: proximo, guardado: rW.ok,
      });
    } else {
      detalle.push({ id: a.id, nombre: `${a.nombre} ${a.apellidos}`.trim(), sin_cambios: true });
    }
  }

  return responder({ ok: true, revisadas: altas.length, actualizadas, detalle }, 200, origen);
});
