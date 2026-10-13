// ============================================================
// entreno-resync · Re-sincronizar las cuotas de ENTRENO con Stripe
// ------------------------------------------------------------
// Igual que cubo-resync pero para `cuotas_entreno`. El webhook
// (`cubo-webhook`) normalmente escribe el estado de la suscripción y
// las fechas de último/próximo cobro. Si a alguien no le llega un
// evento (fallo de entrega, un corte…), la fila se queda «activa pero
// sin fechas» — el mismo desfase que le pasó a Gloria en el Cubo.
//
// Esta función le PREGUNTA a Stripe la verdad de cada suscripción
// (estado, fin del periodo actual = próximo cobro, y la fecha de la
// última factura pagada = último cobro) y rellena lo que falte. Es
// idempotente: se puede lanzar las veces que haga falta. NO cobra ni
// cancela nada; solo lee Stripe y actualiza fechas/estado.
//
// Solo la puede llamar el club (admin/tesorería/contabilidad/junta).
//
// CLAVES (secretos de Supabase): STRIPE_SECRET_KEY_APOLANA /
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / SUPABASE_ANON_KEY
//
// DESPLIEGUE:
//   supabase functions deploy entreno-resync --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
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

// ============================================================
// ALTAS DE SOCIO «en camino» (mig 311) — pasada extra
// El webhook viejo daba el alta por pagada al firmar el mandato e ignoraba
// `checkout.session.async_payment_succeeded`, y Stripe no repite ese aviso. Las
// altas que pasaron a «en_camino» podrían quedarse así para siempre. Aquí se
// pregunta a Stripe por su PaymentIntent (stripe_pago_ref):
//   succeeded                       → pagos_confirmar (pagado), con pagado_en =
//                                     fecha REAL del cargo (charge.created), no hoy
//   requires_payment_method/canceled → pagos_marcar 'fallido'
//   processing                       → sigue en camino
// ============================================================
async function revisarAltasSocio(): Promise<Array<Record<string, unknown>>> {
  const salida: Array<Record<string, unknown>> = [];
  const rA = await rest(`altas_socio?select=id,referencia,nombre,apellidos,stripe_pago_ref,mandato_firmado_en&pago_estado=eq.en_camino&stripe_pago_ref=not.is.null`);
  const altas: Array<{ id: string; referencia: string; nombre: string; apellidos: string | null; stripe_pago_ref: string }> =
    Array.isArray(rA.datos) ? rA.datos : [];
  for (const a of altas) {
    const nombre = `${a.nombre} ${a.apellidos ?? ""}`.trim();
    const refPago = `socio-${a.id}`;
    const rPi = await stripeGet(`payment_intents/${encodeURIComponent(a.stripe_pago_ref)}?expand[]=latest_charge`);
    if (!rPi.ok || !rPi.datos || rPi.datos.error) {
      salida.push({ id: a.id, nombre, referencia: a.referencia, error: rPi.datos?.error?.message ?? `Stripe ${rPi.estado}` });
      continue;
    }
    const pi: any = rPi.datos;
    const est = String(pi.status ?? "");
    if (est === "succeeded") {
      const cargo: any = typeof pi.latest_charge === "object" ? pi.latest_charge : null;
      const ts = Number(cargo?.created ?? pi.created ?? 0);
      const fechaCargo = ts > 0 ? new Date(ts * 1000).toISOString() : null;
      // La fecha real va primero en pagos_online (pagos_confirmar respeta la que
      // haya) y de ahí la copia pagos_aplicar_efecto al alta.
      if (fechaCargo) {
        await rest(`pagos_online?referencia=eq.${encodeURIComponent(refPago)}&estado=neq.pagado`, {
          method: "PATCH", headers: { Prefer: "return=minimal" },
          body: JSON.stringify({ pagado_en: fechaCargo, stripe_payment_intent: pi.id }),
        });
      }
      const rC = await rest(`rpc/pagos_confirmar`, {
        method: "POST",
        body: JSON.stringify({ p_referencia: refPago, p_intent: pi.id }),
      });
      salida.push({ id: a.id, nombre, referencia: a.referencia, resultado: rC.ok ? "pagado" : "error al confirmar", cobrado_en: fechaCargo });
    } else if (est === "requires_payment_method" || est === "canceled") {
      const rM = await rest(`rpc/pagos_marcar`, {
        method: "POST",
        body: JSON.stringify({ p_referencia: refPago, p_estado: "fallido" }),
      });
      salida.push({ id: a.id, nombre, referencia: a.referencia, resultado: rM.ok ? "falló" : "error al marcar", stripe: est });
    } else {
      salida.push({ id: a.id, nombre, referencia: a.referencia, resultado: "sigue en camino", stripe: est });
    }
  }
  return salida;
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

  // 1 · Sesión y que sea ADMIN (mismo criterio que cubo-resync)
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

  // 2 · Qué cuotas: una (cuota_id) o todas las que tienen suscripción
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const cuotaId = String((cuerpo.cuota_id ?? "")).trim();

  const filtro = cuotaId
    ? `cuotas_entreno?select=id,nombre,apellidos,stripe_subscription_id,atleta_id,ultimo_cobro&id=eq.${encodeURIComponent(cuotaId)}`
    : `cuotas_entreno?select=id,nombre,apellidos,stripe_subscription_id,atleta_id,ultimo_cobro&stripe_subscription_id=not.is.null&suscripcion_estado=neq.cancelada`;
  const rA = await rest(filtro);
  const cuotas: Array<{ id: string; nombre: string; apellidos: string; stripe_subscription_id: string; atleta_id: string | null; ultimo_cobro: string | null }> =
    Array.isArray(rA.datos) ? rA.datos : [];
  // Pasada extra: altas de socio con el adeudo SEPA en camino (solo en la
  // revisión general, no al revisar una cuota suelta).
  let socio: Array<Record<string, unknown>> = [];
  if (!cuotaId) {
    try { socio = await revisarAltasSocio(); }
    catch (e) { socio = [{ error: String((e as Error)?.message ?? e) }]; }
  }
  if (!cuotas.length) return responder({ ok: true, revisadas: 0, actualizadas: 0, detalle: [], socio }, 200, origen);

  const detalle: Array<Record<string, unknown>> = [];
  let actualizadas = 0;

  for (const a of cuotas) {
    const sub = a.stripe_subscription_id;
    if (!sub) continue;
    // Traemos la suscripción con su última factura expandida.
    const rS = await stripeGet(`subscriptions/${encodeURIComponent(sub)}?expand[]=latest_invoice.payment_intent`);
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
    const inv: any = s.latest_invoice;
    let pi: any = inv?.payment_intent;
    // En las versiones nuevas de la API la factura ya no trae
    // `payment_intent`: los pagos van en `invoice_payments`. Sin esto no se
    // distingue «en proceso (SEPA)» de «pendiente» (todo salía pendiente).
    if ((!pi || typeof pi === "string") && inv?.id && inv.status !== "paid") {
      const rP = await stripeGet(`invoice_payments?invoice=${encodeURIComponent(inv.id)}&limit=5&expand[]=data.payment.payment_intent`);
      const pagos: any[] = Array.isArray(rP.datos?.data) ? rP.datos.data : [];
      const pago = pagos.find((x) => x?.payment?.payment_intent) ?? null;
      const cand = pago?.payment?.payment_intent ?? pi;
      if (cand && typeof cand === "object") pi = cand;
      else if (typeof cand === "string") {
        const rPi = await stripeGet(`payment_intents/${encodeURIComponent(cand)}`);
        if (rPi.ok && rPi.datos && !rPi.datos.error) pi = rPi.datos;
      }
    }
    const facturaEstado = inv ? String(inv.status ?? "") : null;
    const piEstado = pi ? String(pi.status ?? "") : null;
    // Último cobro = fecha de pago de la última factura, si está pagada.
    const ultimo =
      inv && inv.status === "paid"
        ? (aFecha(inv.status_transitions?.paid_at) ?? aFecha(inv.created))
        : null;
    const estado = estadoDe(String(s.status ?? ""));
    // Etiqueta humana del cobro de ESTE periodo (el primero = octubre).
    let cobro = "sin factura";
    if (inv) {
      if (inv.status === "paid") cobro = "cobrado";
      else if (piEstado === "processing") cobro = "en proceso (SEPA)";
      else if (inv.status === "void" || inv.status === "uncollectible") cobro = "anulada/incobrable";
      // Un adeudo devuelto deja la factura «open» con el pago sin método:
      // hay que mirarlo ANTES que «open» o nunca se vería.
      else if (inv.attempted && (piEstado === "requires_payment_method" || piEstado === "canceled")) cobro = "falló / sin método";
      else if (inv.status === "open") cobro = "pendiente de cobro";
      else cobro = inv.status || "desconocido";
    }
    const facturaImporte = inv && Number.isFinite(Number(inv.total)) ? Number(inv.total) / 100 : null;
    const facturaFecha = inv ? aFecha(inv.created) : null;

    // (mig 311) Firmar el mandato no es cobrar: Stripe pone la suscripción
    // «active» (o «incomplete») mientras el PRIMER adeudo SEPA se procesa. Sin
    // ningún cobro confirmado todavía, eso es «en_camino», no «activa».
    let estadoFinal: string | null = estado;
    const yaCobrado = !!(ultimo || a.ultimo_cobro);
    if (cobro === "falló / sin método") estadoFinal = "impago";
    else if (!yaCobrado && (estado === "activa" || String(s.status ?? "") === "incomplete")) estadoFinal = "en_camino";

    // Si la última factura está pagada y el webhook no dejó su fila en `pagos`,
    // se deja ahora (idempotente por id de factura: no duplica).
    if (inv && inv.status === "paid" && String(inv.id ?? "").startsWith("in_") && Number(inv.amount_paid ?? 0) > 0) {
      const ini = Number(inv.lines?.data?.[0]?.period?.start ?? inv.created ?? 0);
      const d = ini > 0 ? new Date(ini * 1000) : new Date();
      const mes = d.getUTCMonth() + 1, ano = d.getUTCFullYear();
      const etq = mes >= 10 ? `1er trimestre (oct-dic ${ano})`
        : mes <= 3 ? `2º trimestre (ene-mar ${ano})`
        : mes <= 6 ? `3er trimestre (abr-jun ${ano})` : "trimestre";
      const pagadoEn = new Date(Number(inv.status_transitions?.paid_at ?? inv.created) * 1000);
      const fecha = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid", year: "numeric", month: "2-digit", day: "2-digit" }).format(pagadoEn);
      await rest(`rpc/dinero_registrar_cobro_stripe`, {
        method: "POST",
        body: JSON.stringify({
          p_factura: String(inv.id), p_atleta: a.atleta_id ?? null,
          p_concepto: `Cuota de entrenamiento · ${etq}`, p_importe: Number(inv.amount_paid) / 100,
          p_fecha: fecha, p_metodo: "domiciliado", p_periodo: `${ano}-${String(mes).padStart(2, "0")}`,
        }),
      });
    }

    const cambios: Record<string, unknown> = {};
    if (estadoFinal) cambios.suscripcion_estado = estadoFinal;
    if (proximo) cambios.proximo_cobro = proximo;
    if (ultimo) cambios.ultimo_cobro = ultimo;
    if (cobro) cambios.factura_cobro = cobro;
    if (facturaFecha) cambios.factura_fecha = facturaFecha;

    if (Object.keys(cambios).length) {
      const rW = await rest(`cuotas_entreno?id=eq.${encodeURIComponent(a.id)}`, {
        method: "PATCH",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify(cambios),
      });
      if (rW.ok) actualizadas++;
    }
    detalle.push({
      id: a.id, nombre: `${a.nombre} ${a.apellidos}`.trim(),
      estado: estadoFinal, factura: facturaEstado, cobro, factura_importe: facturaImporte,
      factura_fecha: facturaFecha, ultimo_cobro: ultimo, proximo_cobro: proximo,
    });
  }

  return responder({ ok: true, revisadas: cuotas.length, actualizadas, detalle, socio }, 200, origen);
});
