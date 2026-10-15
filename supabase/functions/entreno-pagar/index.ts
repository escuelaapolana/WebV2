// ============================================================
// entreno-pagar · activa la cuota de ENTRENO por SUSCRIPCIÓN SEPA (trimestral)
// ------------------------------------------------------------
// QUÉ HACE
//   El atleta abre su enlace (/entreno/cuota/?t=TOKEN) y pulsa «Domiciliar».
//   Aquí se busca su fila en `cuotas_entreno` POR EL TOKEN (nunca del
//   navegador viene el importe), y se abre una SUSCRIPCIÓN de Stripe por
//   DOMICILIACIÓN SEPA que cobra cada 3 meses (oct, ene, abr). El IBAN se
//   teclea en la pantalla de Stripe, nunca en la web.
//
//   La suscripción se cancela sola tras el cargo de ABRIL: eso lo programa el
//   webhook (cubo-webhook) al nacer la suscripción (cancel_at ≈ mayo 2027).
//
// TEST vs REAL
//   Igual que socio-pagar: mira `pagos_config.modo`. 'real' → clave live; si no,
//   la de test (para probar un enlace sin cobrar de verdad).
//
// CLAVES (variables de entorno de Supabase):
//   STRIPE_SECRET_KEY_APOLANA / STRIPE_SECRET_KEY_APOLANA_TEST
//   SUPABASE_URL / SERVICE_ROLE_KEY
//   Opcionales: PAGOS_URL_BASE, PAGOS_ORIGENES, ACCESO_SAL
//
//   supabase functions deploy entreno-pagar --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
//
// MIG 380 · asistente «Nuevo cobro» (admin/dinero)
//   La misma tabla sirve ahora para cuotas recurrentes con TARJETA o SEPA,
//   mensuales, trimestrales o anuales, con mes de inicio y fecha de fin:
//     · metodo 'tarjeta' → payment_method_types[0]=card (cobro al momento).
//     · inicio futuro (> 48 h) → subscription_data[trial_end] = ese día: se
//       guarda la tarjeta/el mandato y el 1er cobro llega el día 1 del mes.
//     · repercutir_comision (pagos_config) → con tarjeta se suma la comisión
//       con la MISMA fórmula que los bonos (pagos_con_comision). Con SEPA no.
//   Las cuotas viejas (origen NULL) siguen igual que antes.
//   body { ping: true } → { ok, tarjeta: true }: el asistente comprueba que esta
//   versión está desplegada antes de crear cuotas nuevas.
// ============================================================

import { cobroDiferido, esAsistente, fechaLarga, intervalo } from "../_shared/cuota-entreno.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const SK_LIVE = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";
const SK_TEST = Deno.env.get("STRIPE_SECRET_KEY_APOLANA_TEST") ?? "";
const SAL = Deno.env.get("ACCESO_SAL") ?? "apolana-acceso";

const URL_BASE = (Deno.env.get("PAGOS_URL_BASE") ?? "https://atletismoapolana.com/")
  .replace(/\/*$/, "/");

function vuelta(resultado: "hecho" | "cancelado", token: string, mensual = false): string {
  return `${URL_BASE}entreno/cuota/?pago=${resultado}&t=${encodeURIComponent(token)}${mensual ? "&m=1" : ""}`;
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
    return responder({ error: "config", mensaje: "El pago de la cuota no está configurado." }, 503, origen);
  }

  let cuerpo: { token?: string; ping?: boolean } = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  // Versión (mig 380): no toca la base ni Stripe.
  if (cuerpo.ping === true) return responder({ ok: true, tarjeta: true, anual: true, inicio: true }, 200, origen);

  // --- Freno anti-abuso por origen (no enumerar tokens) ---
  const dedonde = await resumen(req.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "sin-origen");
  const ritmo = await rest(`rpc/alta_ritmo`, {
    method: "POST",
    body: JSON.stringify({ p_tipo: "entreno-pagar", p_origen: dedonde, p_max: 40 }),
  });
  if (ritmo.datos !== true) {
    return responder({ error: "ritmo", mensaje: "Demasiados intentos desde aquí. Prueba de nuevo dentro de un rato." }, 429, origen);
  }

  const token = String(cuerpo.token ?? "").trim();
  if (!token || token.length < 20) {
    return responder({ error: "sin_token", mensaje: "Enlace no válido." }, 400, origen);
  }

  // --- Modo (test/real), SIEMPRE de la base ---
  const rCfg = await rest(`pagos_config?select=modo,repercutir_comision&id=eq.1&limit=1`);
  const cfg = Array.isArray(rCfg.datos) ? rCfg.datos[0] as { modo?: string; repercutir_comision?: boolean } : null;
  const modo = (cfg?.modo ?? "prueba").toLowerCase();
  const STRIPE_KEY = modo === "real" ? SK_LIVE : SK_TEST;
  if (!STRIPE_KEY) {
    return responder({
      error: "no_activado",
      mensaje: modo === "real"
        ? "El pago todavía no está activado. Escríbenos y lo dejamos listo."
        : "El pago en modo prueba aún no está listo (falta la clave de test de Stripe).",
    }, 503, origen);
  }

  // --- La fila de la cuota, por su token ---
  const rC = await rest(
    `cuotas_entreno?select=id,atleta_id,perfil_id,nombre,apellidos,email,concepto,importe_cent,cobro_abierto,stripe_subscription_id,suscripcion_estado,periodicidad,fin,metodo,inicio,origen&token=eq.${encodeURIComponent(token)}&limit=1`,
  );
  const c = Array.isArray(rC.datos) ? rC.datos[0] as {
    id: string; atleta_id: string; perfil_id: string | null; nombre: string; apellidos: string;
    email: string; concepto: string; importe_cent: number; cobro_abierto: boolean;
    stripe_subscription_id: string | null; suscripcion_estado: string;
    periodicidad: string | null; fin: string | null;
    metodo: string | null; inicio: string | null; origen: string | null;
  } : null;
  if (!c) return responder({ error: "no_existe", mensaje: "No encontramos tu cuota. Escríbenos y lo miramos." }, 404, origen);

  if (c.cobro_abierto !== true) {
    return responder({ error: "cerrado", mensaje: "Tu cuota no está abierta ahora mismo. El club te avisará." }, 409, origen);
  }
  if (c.stripe_subscription_id && c.suscripcion_estado === "activa") {
    return responder({ error: "ya_activa", mensaje: c.metodo === "tarjeta"
      ? "Tu cuota ya está activa con tu tarjeta y se cobra sola. No hace falta hacer nada más."
      : "Tu cuota ya está domiciliada y se cobra sola. No hace falta hacer nada más." }, 409, origen);
  }
  // Mandato ya firmado y primer adeudo en camino (mig 311): no abrir otra
  // suscripción, que se cobraría dos veces.
  if (c.stripe_subscription_id && c.suscripcion_estado === "en_camino") {
    return responder({ error: "ya_activa", mensaje: "Ya has domiciliado tu cuota: el primer cobro está en camino (el banco tarda unos 5 días hábiles). No hace falta hacer nada más." }, 409, origen);
  }

  let importeCent = Math.round(Number(c.importe_cent));
  if (!Number.isFinite(importeCent) || importeCent < 50) {
    return responder({ error: "sin_precio", mensaje: "Tu cuota no tiene importe. Escríbenos y lo dejamos listo." }, 409, origen);
  }
  const tarjeta = c.metodo === "tarjeta";
  // Comisión: la paga el club salvo que pagos_config diga lo contrario. Solo
  // con tarjeta (la fórmula es la de tarjeta, la misma de bonos y tienda).
  if (tarjeta && cfg?.repercutir_comision === true) {
    const rCom = await rest(`rpc/pagos_con_comision`, { method: "POST", body: JSON.stringify({ p_centimos: importeCent }) });
    const conCom = Number(rCom.datos);
    if (!rCom.ok || !Number.isFinite(conCom) || conCom < importeCent) {
      return responder({ error: "comision", mensaje: "No se pudo calcular el importe. Vuelve a intentarlo en un minuto." }, 503, origen);
    }
    importeCent = Math.round(conCom);
  }
  // Ya pasada la fecha de fin: no se abre nada (cobraría una vez y se pararía).
  if (c.fin && Date.parse(`${c.fin}T21:00:00Z`) <= Date.now()) {
    return responder({ error: "terminada", mensaje: "Esta cuota ya terminó. Si crees que es un error, escríbenos." }, 409, origen);
  }

  const referencia = `entreno-${c.id}`;
  const persona = String((c.nombre || "") + " " + (c.apellidos || "")).trim();

  // --- Sesión de Stripe: SUSCRIPCIÓN (SEPA o tarjeta; cada mes, 3 meses o año) ---
  const params = new URLSearchParams();
  params.set("mode", "subscription");
  params.set("locale", "es");
  params.set("payment_method_types[0]", tarjeta ? "card" : "sepa_debit");
  params.set("client_reference_id", referencia);
  if (c.email) params.set("customer_email", c.email);
  const mensual = c.periodicidad === "mensual";
  params.set("success_url", vuelta("hecho", token, mensual));
  params.set("cancel_url", vuelta("cancelado", token, mensual));

  // Cuota trimestral: se cobra HOY (octubre) y cada 3 meses (ene, abr). El
  // webhook programará la cancelación tras abril (en junio no se pasa nada).
  params.set("line_items[0][quantity]", "1");
  params.set("line_items[0][price_data][currency]", "eur");
  params.set("line_items[0][price_data][unit_amount]", String(importeCent));
  const iv = intervalo(c.periodicidad);
  params.set("line_items[0][price_data][recurring][interval]", iv.interval);
  params.set("line_items[0][price_data][recurring][interval_count]", String(iv.count));
  params.set("line_items[0][price_data][product_data][name]",
    esAsistente(c) ? `${c.concepto || "Cuota"} · Club Atletismo Apolana`
    : mensual ? `${c.concepto || "Cuota mensual"} · Club Atletismo Apolana`
            : "Cuota de entrenamiento (trimestral) · Club Atletismo Apolana");
  // Mes de inicio futuro (mig 380): se guarda la tarjeta / el mandato hoy y el
  // primer cobro llega ese día (Stripe lo llama «prueba»; por eso el aviso).
  const diferido = esAsistente(c) ? cobroDiferido(c) : null;
  if (diferido) {
    params.set("subscription_data[trial_end]", String(diferido));
    params.set("custom_text[submit][message]",
      `Hoy no se cobra nada: el primer cobro será el ${fechaLarga(c.inicio)}` +
      (c.fin ? ` y la cuota se para sola el ${fechaLarga(c.fin)}.` : "."));
  } else if (esAsistente(c) && c.fin) {
    params.set("custom_text[submit][message]", `La cuota se para sola el ${fechaLarga(c.fin)}: después no se cobra nada más.`);
  }
  // MENSUAL (mig 313): la suscripción arranca HOY (se cobra ya el mes en
  // curso) y se repite cada mes en esa misma fecha; el webhook programa la
  // parada en `fin`. (Stripe no admite cobro único + anclaje al día 1 sin
  // prorrateo en la misma pasarela: se probó el 14-oct y lo rechaza.)

  // Etiquetas para que el webhook case el cobro y el export de Stripe sepa quién es.
  params.set("subscription_data[metadata][referencia]", referencia);
  params.set("subscription_data[metadata][cuota_id]", c.id);
  params.set("subscription_data[metadata][metodo]", tarjeta ? "tarjeta" : "sepa");
  params.set("subscription_data[metadata][atleta_id]", c.atleta_id);
  if (c.perfil_id) params.set("subscription_data[metadata][perfil_id]", c.perfil_id);
  if (persona) {
    params.set("subscription_data[metadata][persona]", persona);
    params.set("metadata[persona]", persona);
  }
  params.set("metadata[referencia]", referencia);

  const rStripe = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: { Authorization: `Bearer ${STRIPE_KEY}`, "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString(),
  });
  const sesion = await rStripe.json().catch(() => null);
  if (!rStripe.ok || !sesion?.url) {
    console.error("Stripe rechazó la sesión de entreno:", sesion?.error?.message ?? rStripe.status);
    return responder({ error: "pasarela", mensaje: "La pasarela no ha respondido. Vuelve a intentarlo en un minuto.", detalle: sesion?.error?.message ?? null }, 502, origen);
  }

  return responder({ url: sesion.url, referencia, importe_cent: importeCent, modo }, 200, origen);
});
