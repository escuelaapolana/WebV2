// ============================================================
// cubo-webhook · Stripe avisa de lo que pasa con la cuota del Cubo
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   La cuota de El Cubo es una SUSCRIPCIÓN: Stripe cobra solo cada mes.
//   Cada vez que pasa algo (se activa, entra un recibo, falla, se da de
//   baja), Stripe llama aquí para contarlo. Aquí se comprueba que el
//   aviso es de verdad suyo (la firma) y se anota el estado en la fila
//   de esa persona en `cubo_altas` (activa / impago / cancelada y las
//   fechas del último y el próximo cobro). Así el club y la propia
//   persona ven al momento si su cuota está al día.
//
// LA FIRMA (idéntica a la del webhook de la tienda): esta dirección es
//   pública; solo nos fiamos de los avisos cuya firma HMAC-SHA256 cuadra
//   con el secreto que solo tenéis Stripe y vosotros. Se firma sobre el
//   cuerpo CRUDO (`req.text()`), nunca sobre el JSON re-serializado.
//
// ES DE APOLANA (no de Ítaka): usa su propio secreto de webhook.
//
// CLAVES (variables de entorno de Supabase; aquí no hay ninguna)
//     STRIPE_WEBHOOK_SECRET_APOLANA   (la copias del panel de Stripe de Apolana)
//     SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY   (las pone Supabase)
//
//     supabase functions deploy cubo-webhook --no-verify-jwt
// ============================================================

import { planificar, finPeriodo as finPeriodoSub, isoMadrid, cargosPendientes, textoCargos } from "../_shared/cubo-pausa.ts";
import { cancelAtExacto, cobroEnPagos, finUnixDe } from "../_shared/cuota-entreno.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET_APOLANA") ?? "";
/* Secreto del webhook en modo PRUEBA (opcional). Con él, este mismo webhook
   verifica también los avisos de test (para probar el cobro del alta de socio en
   test sin romper el real). Si no está, solo funciona el real. */
const WEBHOOK_SECRET_TEST = Deno.env.get("STRIPE_WEBHOOK_SECRET_APOLANA_TEST") ?? "";
// Claves Stripe (para programar la cancelación de la suscripción de entreno tras
// el cargo de abril). Se elige por livemode del evento.
const SK_LIVE = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";
const SK_TEST = Deno.env.get("STRIPE_SECRET_KEY_APOLANA_TEST") ?? "";

const TOLERANCIA_SEGUNDOS = 60 * 5;

// La parada de la cuota de entreno (antes ENTRENO_CANCEL_AT = 6-may-2027 a pelo)
// se calcula ahora en un límite de periodo: _shared/cuota-entreno.ts (revisión 380).

// ---- Firma de Stripe (HMAC-SHA256, sin librerías) ----
function hexABytes(hex: string): Uint8Array {
  const limpio = hex.trim();
  if (limpio.length % 2 !== 0) return new Uint8Array(0);
  const salida = new Uint8Array(limpio.length / 2);
  for (let i = 0; i < salida.length; i++) {
    const b = parseInt(limpio.substr(i * 2, 2), 16);
    if (Number.isNaN(b)) return new Uint8Array(0);
    salida[i] = b;
  }
  return salida;
}
function igualesSinPrisa(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length === 0 || a.length !== b.length) return false;
  let dif = 0;
  for (let i = 0; i < a.length; i++) dif |= a[i] ^ b[i];
  return dif === 0;
}
async function firmaValida(cuerpo: string, cabecera: string, secreto: string): Promise<boolean> {
  if (!cabecera || !secreto) return false;
  let marca = "";
  const firmas: string[] = [];
  for (const trozo of cabecera.split(",")) {
    const [k, v] = trozo.split("=", 2).map((s) => (s ?? "").trim());
    if (k === "t") marca = v;
    else if (k === "v1") firmas.push(v);
  }
  if (!marca || firmas.length === 0) return false;
  const edad = Math.floor(Date.now() / 1000) - Number(marca);
  if (!Number.isFinite(edad) || Math.abs(edad) > TOLERANCIA_SEGUNDOS) return false;
  const clave = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secreto),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const esperada = new Uint8Array(
    await crypto.subtle.sign("HMAC", clave, new TextEncoder().encode(`${marca}.${cuerpo}`)),
  );
  return firmas.some((f) => igualesSinPrisa(esperada, hexABytes(f)));
}

// ---- Hablar con la base con la llave de servicio ----
async function patchAlta(filtro: string, cambios: Record<string, unknown>) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/cubo_altas?${filtro}`, {
    method: "PATCH",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify(cambios),
  });
  if (!r.ok) console.error("PATCH cubo_altas falló:", r.status, await r.text().catch(() => ""));
  return r.ok;
}

// Marca un pago puntual (cubo_cobros) como cobrado. Solo si sigue pendiente
// (idempotente: si el webhook llega dos veces, no pasa nada).
async function patchCobro(cobroId: string, cambios: Record<string, unknown>) {
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/cubo_cobros?id=eq.${encodeURIComponent(cobroId)}&estado=eq.pendiente`,
    {
      method: "PATCH",
      headers: {
        apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
        "Content-Type": "application/json", Prefer: "return=minimal",
      },
      body: JSON.stringify(cambios),
    },
  );
  if (!r.ok) console.error("PATCH cubo_cobros falló:", r.status, await r.text().catch(() => ""));
  return r.ok;
}

// Cambia el estado de pago de un ALTA DE SOCIO. El filtro decide desde qué
// estados se puede pasar (así un aviso que llega tarde nunca baja un «pagado»).
async function patchAltaSocioFiltro(filtro: string, cambios: Record<string, unknown>) {
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/altas_socio?${filtro}`,
    {
      method: "PATCH",
      headers: {
        apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
        "Content-Type": "application/json", Prefer: "return=minimal",
      },
      body: JSON.stringify(cambios),
    },
  );
  if (!r.ok) console.error("PATCH altas_socio falló:", r.status, await r.text().catch(() => ""));
  return r.ok;
}

// Modo efectivo del sistema ('prueba' | 'real'), SIEMPRE de la base (igual que
// socio-pagar). Ante cualquier fallo de lectura, 'prueba' (no endurecer de más:
// así nunca se rompe el flujo de test si la consulta falla puntualmente).
async function modoEfectivo(): Promise<string> {
  try {
    const r = await fetch(
      `${SUPABASE_URL}/rest/v1/pagos_config?select=modo&id=eq.1&limit=1`,
      { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } },
    );
    if (!r.ok) return "prueba";
    const filas = await r.json().catch(() => []);
    return String(filas?.[0]?.modo ?? "prueba").toLowerCase();
  } catch { return "prueba"; }
}

const idDe = (v: unknown): string | null =>
  typeof v === "string" ? v : ((v as { id?: string } | null)?.id ?? null);

// ============================================================
// CUOTA DE ENTRENO (suscripción SEPA trimestral) — bloque aditivo.
// El mismo endpoint recibe los eventos de entreno (misma cuenta Stripe que el
// Cubo). Se reconocen por la referencia `entreno-<id de cuotas_entreno>`.
// ============================================================

// Referencia que viaja en el evento (checkout, invoice o subscription).
function refDe(objeto: Record<string, any>): string | null {
  return (
    (typeof objeto.client_reference_id === "string" ? objeto.client_reference_id : null) ??
    objeto.metadata?.referencia ??
    objeto.subscription_details?.metadata?.referencia ??
    objeto.lines?.data?.[0]?.metadata?.referencia ??
    null
  );
}

async function patchEntreno(filtro: string, cambios: Record<string, unknown>) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/cuotas_entreno?${filtro}`, {
    method: "PATCH",
    headers: {
      apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json", Prefer: "return=minimal",
    },
    body: JSON.stringify(cambios),
  });
  if (!r.ok) console.error("PATCH cuotas_entreno falló:", r.status, await r.text().catch(() => ""));
  return r.ok;
}

async function getEntreno(id: string): Promise<Record<string, any> | null> {
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/cuotas_entreno?select=id,atleta_id,nombre,apellidos,importe_cent,cancel_programado,stripe_subscription_id,suscripcion_estado,fin,periodicidad,metodo,origen,concepto,inicio&id=eq.${encodeURIComponent(id)}&limit=1`,
    { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } },
  );
  if (!r.ok) return null;
  const filas = await r.json().catch(() => []);
  return Array.isArray(filas) ? (filas[0] ?? null) : null;
}

// Programa la PARADA de la suscripción (cancel_at). Revisión 380: Stripe
// prorratea el último periodo si cancel_at cae a mitad de periodo, así que se
// LEE la suscripción y se para EXACTAMENTE en un límite de periodo: el primero
// en o después del final de `fin` (sin `fin`: tras el cobro de abril). Ningún
// cobro se acorta y no hay ninguno después (_shared/cuota-entreno.ts).
// Devuelve true solo si Stripe lo aceptó (si no, cancel_programado se queda en
// false y entreno-resync lo reintenta).
async function programarCancelEntreno(subId: string, livemode: boolean, fin?: string | null): Promise<boolean> {
  const key = livemode ? SK_LIVE : SK_TEST;
  if (!key || !subId) return false;
  const rS = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(subId)}`, {
    headers: { Authorization: `Bearer ${key}` },
  });
  const sub = rS.ok ? await rS.json().catch(() => null) : null;
  if (!sub) { console.error("cancel_at de entreno: no se pudo leer la suscripción", subId, rS.status); return false; }
  const x = cancelAtExacto(sub, finUnixDe(fin));
  if ("error" in x) { console.error("cancel_at de entreno:", subId, x.error); return false; }
  if (x.cancelAt <= Math.floor(Date.now() / 1000) + 60) {
    console.error("cancel_at de entreno: el límite calculado ya ha pasado", subId, x.cancelAt);
    return false;
  }
  if (Number(sub.cancel_at) === x.cancelAt) return true;   // ya estaba bien
  const r = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(subId)}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/x-www-form-urlencoded" },
    body: `cancel_at=${x.cancelAt}&proration_behavior=none`,
  });
  if (!r.ok) console.error("No se pudo programar cancel_at de entreno:", r.status, await r.text().catch(() => ""));
  return r.ok;
}

// ¿Sigue viva una suscripción? (para no abrir dos a la misma cuota)
async function subViva(subId: string, livemode: boolean): Promise<boolean | null> {
  const key = livemode ? SK_LIVE : SK_TEST;
  if (!key || !subId) return null;
  const r = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(subId)}`, {
    headers: { Authorization: `Bearer ${key}` },
  });
  if (!r.ok) return r.status === 404 ? false : null;
  const s = await r.json().catch(() => null);
  if (!s) return null;
  return !["canceled", "incomplete_expired"].includes(String(s.status ?? ""));
}
async function cancelarSubAhora(subId: string, livemode: boolean): Promise<boolean> {
  const key = livemode ? SK_LIVE : SK_TEST;
  if (!key || !subId) return false;
  const r = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(subId)}`, {
    method: "DELETE", headers: { Authorization: `Bearer ${key}` },
  });
  if (!r.ok) console.error("No se pudo cancelar la suscripción duplicada", subId, r.status, await r.text().catch(() => ""));
  return r.ok;
}

// Registra un cobro LIQUIDADO de Stripe como recibo PAGADO en `pagos` (histórico).
// Una factura = una fila: la idempotencia la pone la base (índice único sobre
// notas='stripe:in_…', mig 311) dentro de dinero_registrar_cobro_stripe(), así
// que da igual que lleguen invoice.paid e invoice.payment_succeeded a la vez.
// Fecha = la REAL del cobro (paid_at), sin `cuenta` (no es un recibo de remesa).
const MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
  "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
function fechaCobro(objeto: Record<string, any>): Date {
  const ts = Number(objeto.status_transitions?.paid_at ?? objeto.created ?? 0);
  return ts > 0 ? new Date(ts * 1000) : new Date();
}
const fechaMadrid = (d: Date): string =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid", year: "numeric", month: "2-digit", day: "2-digit" }).format(d);

async function registrarCobroStripe(
  objeto: Record<string, any>, atletaId: string | null, concepto: string, metodo: "tarjeta" | "domiciliado", periodo: string | null,
) {
  const invId = String(objeto.id ?? "");
  const importe = (Number(objeto.amount_paid ?? 0) || 0) / 100;
  if (!invId.startsWith("in_") || importe <= 0) return;   // factura de 0 € (prueba gratis): no es dinero
  await rpcServicio("dinero_registrar_cobro_stripe", {
    p_factura: invId,
    p_atleta: atletaId,
    p_concepto: concepto,
    p_importe: importe,
    p_fecha: fechaMadrid(fechaCobro(objeto)),
    p_metodo: metodo,
    p_periodo: periodo,
  });
}

async function registrarCobroEntreno(objeto: Record<string, any>, cuota: Record<string, any>) {
  // Concepto/periodo/método: las cuotas viejas como siempre («Cuota de
  // entrenamiento · 1er trimestre…», domiciliado); las del asistente «Nuevo
  // cobro» (mig 380) con su concepto, su periodo real y tarjeta o domiciliado.
  const inicio = Number(objeto.lines?.data?.[0]?.period?.start ?? objeto.created ?? 0);
  const x = cobroEnPagos(cuota, inicio);
  await registrarCobroStripe(objeto, cuota.atleta_id ?? null, x.concepto, x.metodo, x.periodo);
}

// Cubo: cada recibo cobrado de la suscripción deja su fila en `pagos`.
async function registrarCobroCubo(objeto: Record<string, any>, filtro: string) {
  if (!(Number(objeto.amount_paid ?? 0) > 0)) return;
  const r = await fetch(`${SUPABASE_URL}/rest/v1/cubo_altas?select=id,atleta_id&${filtro}&limit=1`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  });
  const filas = r.ok ? await r.json().catch(() => []) : [];
  const alta = Array.isArray(filas) ? filas[0] : null;
  if (!alta) { console.warn("Cobro del Cubo sin alta casada:", objeto.id); return; }
  const d = fechaCobro(objeto);
  const [ano, mes] = fechaMadrid(d).split("-");
  await registrarCobroStripe(objeto, alta.atleta_id ?? null,
    `Cuota El Cubo · ${MESES[Number(mes) - 1]} ${ano}`, "tarjeta", `${ano}-${mes}`);
}

// ============================================================
// PAUSA DE UN MES (mig 360) — bloque aditivo.
// Si el club aprobó pausar un mes que NO era el próximo recibo (p. ej. en
// octubre la de diciembre), la Edge cubo-pausa no pudo poner aún la pausa en
// Stripe (pausar ya habría anulado también noviembre). Aquí, al cobrarse un
// recibo (invoice.paid), se PREGUNTA A STRIPE por la suscripción (no se fía de
// las líneas del recibo: con un cargo suelto la 1ª línea es otra) y, si su
// próximo recibo es el de un mes con pausa aprobada pendiente, se aplica con
// la MISMA regla que la Edge (_shared/cubo-pausa.ts → planificar). Nunca
// lanza: cualquier fallo queda en el log y el panel enseña «Aplicar en Stripe».
// ============================================================
async function aplicarPausaPendiente(filtro: string, objeto: Record<string, any>, livemode: boolean) {
  const subId = idDe(objeto.subscription) ?? idDe(objeto.parent?.subscription_details?.subscription);
  const key = livemode ? SK_LIVE : SK_TEST;
  if (!subId || !key) return;
  const h = { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` };
  const rA = await fetch(`${SUPABASE_URL}/rest/v1/cubo_altas?select=id&${filtro}&limit=1`, { headers: h });
  const alta = rA.ok ? (await rA.json().catch(() => []))?.[0] : null;
  if (!alta?.id) return;
  // ¿Tiene ALGUNA pausa aprobada sin aplicar? (si no, ni se molesta a Stripe)
  const rN = await fetch(
    `${SUPABASE_URL}/rest/v1/cubo_pausas?select=id&alta_id=eq.${encodeURIComponent(alta.id)}` +
    `&estado=eq.aprobada&stripe_aplicada_en=is.null&limit=1`, { headers: h });
  if (!rN.ok || !((await rN.json().catch(() => [])) ?? []).length) return;

  const rS = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(subId)}?expand[]=latest_invoice`,
    { headers: { Authorization: `Bearer ${key}` } });
  if (!rS.ok) { console.error("Pausa del Cubo: no se pudo leer la suscripción:", rS.status); return; }
  const s = await rS.json().catch(() => null);
  const fin = finPeriodoSub(s);
  if (!fin) return;
  // La pausa del MES EXACTO del próximo recibo (no «la más antigua»).
  const mes = isoMadrid(fin).slice(0, 7) + "-01";
  const rP = await fetch(
    `${SUPABASE_URL}/rest/v1/cubo_pausas?select=id,mes&alta_id=eq.${encodeURIComponent(alta.id)}` +
    `&estado=eq.aprobada&stripe_aplicada_en=is.null&mes=eq.${mes}&limit=1`, { headers: h });
  const pausa = rP.ok ? (await rP.json().catch(() => []))?.[0] : null;
  if (!pausa?.id) return;

  const plan = planificar(s, mes);
  let resumes = 0;
  if (plan.tipo === "aplicar") {
    const cp = await cargosPendientes(key, idDe(s?.customer) ?? "");
    if (cp.items.length) {
      // Se aplica igual (la pausa ya está prometida), pero queda la pista.
      console.warn(`Pausa del Cubo ${pausa.id}: cargos pendientes que irán al recibo anulado: ${textoCargos(cp.items)}`);
    }
    const r = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(subId)}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ "pause_collection[behavior]": "void", "pause_collection[resumes_at]": String(plan.resumes) }).toString(),
    });
    if (!r.ok) { console.error("Pausa del Cubo: Stripe no la aceptó:", r.status, await r.text().catch(() => "")); return; }
    resumes = plan.resumes;
  } else if (plan.tipo === "ya") {
    resumes = plan.resumes;
  } else {
    if (plan.tipo === "error") console.warn(`Pausa del Cubo ${pausa.id} sin aplicar: ${plan.codigo} · ${plan.mensaje}`);
    return;
  }
  await rpcServicio("cubo_pausa_registrar", {
    p_id: pausa.id, p_aprobar: false, p_por_email: null, p_resumes: new Date(resumes * 1000).toISOString(),
  });
}

// ============================================================
// RECIBOS y BONOS (pago-crear) — bloque aditivo.
// pago-crear cobra en la cuenta de Apolana, así que el aviso llega a ESTE
// webhook. La referencia de un recibo/bono vive en `pagos_online` (no empieza
// por cubo-/socio-/entreno-). Se confirma llamando a pagos_confirmar, igual que
// hace pago-webhook. Así un recibo pagado con tarjeta queda PAGADO solo.
// ============================================================
async function rpcServicio(nombre: string, cuerpo: Record<string, unknown>): Promise<boolean> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${nombre}`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(cuerpo),
  });
  if (!r.ok) console.error(`RPC ${nombre} falló:`, r.status, await r.text().catch(() => ""));
  return r.ok;
}
async function esReferenciaDePago(ref: string): Promise<boolean> {
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/pagos_online?select=referencia&referencia=eq.${encodeURIComponent(ref)}&limit=1`,
    { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } },
  );
  if (!r.ok) return false;
  const filas = await r.json().catch(() => []);
  return Array.isArray(filas) && filas.length > 0;
}
// Devuelve true si era un recibo/bono y ya se ha gestionado aquí.
async function manejarRecibo(tipo: string, objeto: Record<string, any>, eventoId: string): Promise<boolean> {
  const ref = refDe(objeto);
  if (!ref || ref.startsWith("cubo-") || ref.startsWith("socio-") || ref.startsWith("entreno-")) return false;
  if (!(await esReferenciaDePago(ref))) return false;
  const ses = (objeto?.id as string | undefined) ?? null;
  switch (tipo) {
    case "checkout.session.completed":
      if (objeto?.payment_status === "paid")
        await rpcServicio("pagos_confirmar", { p_referencia: ref, p_session: ses, p_evento: eventoId });
      break;
    case "checkout.session.async_payment_succeeded":
      await rpcServicio("pagos_confirmar", { p_referencia: ref, p_session: ses, p_evento: eventoId });
      break;
    case "payment_intent.succeeded":
      await rpcServicio("pagos_confirmar", { p_referencia: ref, p_intent: idDe(objeto), p_evento: eventoId });
      break;
    case "checkout.session.async_payment_failed":
      await rpcServicio("pagos_marcar", { p_referencia: ref, p_estado: "fallido", p_evento: eventoId });
      break;
    case "checkout.session.expired":
      await rpcServicio("pagos_marcar", { p_referencia: ref, p_estado: "cancelado", p_evento: eventoId });
      break;
    default:
      break;
  }
  return true;
}

// Devuelve true si el evento era de ENTRENO y ya se ha gestionado aquí.
async function manejarEntreno(tipo: string, objeto: Record<string, any>, livemode: boolean): Promise<boolean> {
  const ref = refDe(objeto);
  if (typeof ref !== "string" || !ref.startsWith("entreno-")) return false;
  const cuotaId = ref.slice("entreno-".length);

  // --- Revisión 380 · DOBLE SUSCRIPCIÓN (dos pestañas, dos pagos…) ---
  // Si la cuota ya tiene OTRA suscripción y esa sigue viva, la que llega ahora
  // sobra: se cancela al momento y NO toca la fila. Si la vieja ya no vale
  // (cancelada: p. ej. la cerró entreno-pagar por impago), la nueva la sustituye.
  const subEvento: string | null = tipo.startsWith("customer.subscription.")
    ? (typeof objeto.id === "string" ? objeto.id : null)
    : (idDe(objeto.subscription) ?? idDe(objeto.parent?.subscription_details?.subscription));
  const cuota0 = await getEntreno(cuotaId);
  const actual: string | null = cuota0?.stripe_subscription_id ?? null;
  if (cuota0 && subEvento && actual && subEvento !== actual) {
    let viva = await subViva(actual, livemode);
    if (viva === null) viva = ["activa", "en_camino"].includes(String(cuota0.suscripcion_estado ?? ""));
    if (viva) {
      if (tipo === "checkout.session.completed" || tipo === "customer.subscription.created") {
        console.error(`REVISAR · cuota ${cuotaId}: llegó una 2ª suscripción (${subEvento}) con la ${actual} viva → se cancela la nueva.` +
          " Si ya se cobró algo en ella, REEMBOLSARLO en Stripe.");
        await cancelarSubAhora(subEvento, livemode);
      }
      // Dinero que de verdad entró por la duplicada: se apunta (para devolverlo).
      if ((tipo === "invoice.paid" || tipo === "invoice.payment_succeeded") && Number(objeto.amount_paid ?? 0) > 0) {
        console.error(`REVISAR · cuota ${cuotaId}: cobro ${objeto.id} en la suscripción duplicada ${subEvento} → reembolsar en Stripe.`);
        await registrarCobroEntreno(objeto, cuota0);
      }
      return true;
    }
    // La actual está muerta: un evento de borrado de OTRA suscripción no toca nada.
    if (tipo === "customer.subscription.deleted") return true;
  }

  switch (tipo) {
    case "checkout.session.completed": {
      if (objeto.mode === "subscription") {
        const subId = idDe(objeto.subscription);
        // SEPA: terminar la pasarela = MANDATO FIRMADO, no cobro. El primer
        // adeudo tarda ~5 días hábiles (hasta 14). Hasta que llegue
        // invoice.paid queda «en_camino»; solo si Stripe dice 'paid' ya, activa.
        // 'no_payment_required' (mig 380) = cuota con mes de inicio futuro: la
        // tarjeta/el mandato quedan guardados y el 1er cobro llega ese día →
        // está «activa» (configurada), no «en camino».
        const pagado = objeto.payment_status === "paid" || objeto.payment_status === "no_payment_required";
        await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, {
          stripe_customer_id: idDe(objeto.customer),
          stripe_subscription_id: subId,
        });
        await patchEntreno(
          `id=eq.${encodeURIComponent(cuotaId)}` + (pagado ? "" : "&ultimo_cobro=is.null"),
          { suscripcion_estado: pagado ? "activa" : "en_camino" },
        );
        // Programar la parada en su límite de periodo (una sola vez). Solo se
        // marca hecha si Stripe la aceptó; si no, la reintenta entreno-resync.
        const cuota = await getEntreno(cuotaId);
        if (subId && cuota && cuota.cancel_programado !== true) {
          if (await programarCancelEntreno(subId, livemode, cuota.fin)) {
            await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, { cancel_programado: true });
          }
        }
      }
      break;
    }
    case "invoice.paid":
    case "invoice.payment_succeeded": {
      const finPeriodo = objeto.lines?.data?.[0]?.period?.end ?? objeto.period_end;
      // Factura de 0 € (arranque de una cuota con mes de inicio futuro, mig 380):
      // no es un cobro → ni «último cobro» ni fila en `pagos`.
      if (!(Number(objeto.amount_paid ?? 0) > 0)) {
        await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, {
          stripe_customer_id: idDe(objeto.customer),
          stripe_subscription_id: idDe(objeto.subscription),
          ...(aFecha(finPeriodo) ? { proximo_cobro: aFecha(finPeriodo) } : {}),
        });
        break;
      }
      await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, {
        suscripcion_estado: "activa",
        stripe_customer_id: idDe(objeto.customer),
        stripe_subscription_id: idDe(objeto.subscription),
        ultimo_cobro: aFecha(objeto.status_transitions?.paid_at) ?? new Date().toISOString(),
        proximo_cobro: aFecha(finPeriodo),
      });
      const cuota = await getEntreno(cuotaId);
      if (cuota) await registrarCobroEntreno(objeto, cuota);
      break;
    }
    case "checkout.session.async_payment_succeeded": {
      // El primer adeudo SEPA se liquidó. (invoice.paid también llega y es el
      // que deja la fila en `pagos`; esto solo adelanta el estado.)
      await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, { suscripcion_estado: "activa" });
      break;
    }
    case "checkout.session.async_payment_failed":
    case "invoice.payment_failed": {
      // Adeudo rechazado o devuelto: deshace el «en camino».
      await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, { suscripcion_estado: "impago" });
      break;
    }
    case "customer.subscription.created":
    case "customer.subscription.updated": {
      const st = String(objeto.status ?? "");
      // 'incomplete' = el primer pago aún se está procesando (SEPA): no es impago.
      const est = st === "incomplete" ? null : estadoDe(st);
      const proximo = aFecha(objeto.current_period_end) ?? aFecha(objeto.trial_end);
      await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, {
        stripe_subscription_id: objeto.id,
        stripe_customer_id: idDe(objeto.customer),
        ...(proximo ? { proximo_cobro: proximo } : {}),
      });
      // Stripe pone la suscripción «active» mientras el adeudo SEPA se procesa:
      // eso NO convierte un «en_camino» en «activa» (lo hace invoice.paid).
      if (est) {
        await patchEntreno(
          `id=eq.${encodeURIComponent(cuotaId)}` + (est === "activa" ? "&suscripcion_estado=neq.en_camino" : ""),
          { suscripcion_estado: est },
        );
      }
      break;
    }
    case "customer.subscription.deleted": {
      // Solo si es LA suscripción de la cuota (no una duplicada, ni la vieja que
      // cerró entreno-pagar por impago: esa ya no está en la fila).
      await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}` +
        (subEvento ? `&stripe_subscription_id=eq.${encodeURIComponent(subEvento)}` : ""),
        { suscripcion_estado: "cancelada" });
      break;
    }
    default:
      // otros eventos de entreno: nada que hacer, pero ya está «gestionado».
      break;
  }
  return true;
}

// ¿A qué fila casamos el aviso? Por referencia (cubo-<id de alta>), o por
// la suscripción, o por el cliente de Stripe. Devuelve el filtro PostgREST.
function filtroDe(objeto: Record<string, any>): string | null {
  const ref: string | null =
    objeto.client_reference_id ??
    objeto.metadata?.referencia ??
    objeto.subscription_details?.metadata?.referencia ??
    objeto.lines?.data?.[0]?.metadata?.referencia ??
    null;
  if (ref && ref.startsWith("cubo-")) {
    return `id=eq.${encodeURIComponent(ref.slice(5))}`;
  }
  const sub = idDe(objeto.subscription) ?? (objeto.object === "subscription" ? objeto.id : null);
  if (sub) return `stripe_subscription_id=eq.${encodeURIComponent(sub)}`;
  const cli = idDe(objeto.customer);
  if (cli) return `stripe_customer_id=eq.${encodeURIComponent(cli)}`;
  return null;
}

// De 'active'/'trialing'/'past_due'... al estado que guardamos.
function estadoDe(estadoStripe: string): "activa" | "impago" | "cancelada" | null {
  if (estadoStripe === "active" || estadoStripe === "trialing") return "activa";
  if (estadoStripe === "past_due" || estadoStripe === "unpaid" || estadoStripe === "incomplete") return "impago";
  if (estadoStripe === "canceled" || estadoStripe === "incomplete_expired") return "cancelada";
  return null;
}
const aFecha = (ts: unknown): string | null =>
  Number.isFinite(Number(ts)) && Number(ts) > 0 ? new Date(Number(ts) * 1000).toISOString() : null;

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return new Response("Método no admitido.", { status: 405 });
  if (!SUPABASE_URL || !SERVICE_KEY || (!WEBHOOK_SECRET && !WEBHOOK_SECRET_TEST)) {
    console.error("Faltan variables: el webhook del Cubo no puede trabajar.");
    return new Response("Sin configurar.", { status: 503 });
  }

  const crudo = await req.text();
  const cabecera = req.headers.get("stripe-signature") ?? "";
  // Se acepta si cuadra con el secreto REAL o con el de PRUEBA (así vale para los
  // dos modos: el cobro del Cubo en real y el del alta de socio en test).
  const firmaOk =
    (WEBHOOK_SECRET && await firmaValida(crudo, cabecera, WEBHOOK_SECRET)) ||
    (WEBHOOK_SECRET_TEST && await firmaValida(crudo, cabecera, WEBHOOK_SECRET_TEST));
  if (!firmaOk) {
    console.warn("Aviso con firma que no cuadra (ni real ni prueba): descartado.");
    return new Response("Firma no válida.", { status: 400 });
  }

  let evento: Record<string, any>;
  try { evento = JSON.parse(crudo); } catch { return new Response("Aviso ilegible.", { status: 400 }); }

  // Blindaje al pasar a REAL: si por descuido se dejara puesto el secreto de
  // PRUEBA, un evento de test (livemode=false) firmado con él NO debe tocar
  // altas reales. Solo consultamos la config cuando el evento es de test; los
  // reales (livemode=true) pasan sin mirar nada. En modo 'prueba' se acepta
  // como hasta ahora (el guard no dispara).
  if (evento.livemode === false && (await modoEfectivo()) === "real") {
    console.warn("Evento de PRUEBA (livemode=false) recibido en modo REAL: descartado.");
    return new Response("Evento de prueba en modo real.", { status: 400 });
  }

  const tipo: string = evento.type ?? "";
  const objeto = evento.data?.object ?? null;
  if (!objeto) return new Response(JSON.stringify({ recibido: true }), { status: 200 });

  // --- ALTA DE SOCIO: adeudo DEVUELTO después de cobrado (reembolso o
  //     devolución del banco). Va ANTES de la rama de socio: el cargo suele traer
  //     metadata.referencia='socio-…' y allí saldría por `default` sin hacer nada.
  //     Se casa por el payment_intent guardado en altas_socio.stripe_pago_ref
  //     (la disputa no trae metadata). Si no es de un alta, sigue su camino. ---
  if (tipo === "charge.refunded" || tipo === "charge.dispute.created") {
    const pi = idDe(objeto.payment_intent);
    const completo = tipo === "charge.dispute.created" || objeto.refunded === true;
    const refMeta = typeof objeto.metadata?.referencia === "string" && objeto.metadata.referencia.startsWith("socio-")
      ? objeto.metadata.referencia.slice("socio-".length) : null;
    if ((pi || refMeta) && completo) {
      let altaId: string | null = null;
      if (pi) {
        const r = await fetch(
          `${SUPABASE_URL}/rest/v1/altas_socio?select=id&stripe_pago_ref=eq.${encodeURIComponent(pi)}&limit=1`,
          { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } },
        );
        const filas = r.ok ? await r.json().catch(() => []) : [];
        altaId = (Array.isArray(filas) ? filas[0]?.id : null) ?? null;
      }
      altaId = altaId ?? refMeta;
      if (altaId) {
        await rpcServicio("pagos_marcar", { p_referencia: `socio-${altaId}`, p_estado: "reembolsado", p_evento: String(evento.id ?? "") });
        await patchAltaSocioFiltro(`id=eq.${encodeURIComponent(altaId)}`, { pago_estado: "devuelto" });
        return new Response(JSON.stringify({ recibido: true, socio: true, devuelto: true }), { status: 200 });
      }
    }
  }

  // --- ALTA DE SOCIO pagada por SEPA (referencia socio-<id de alta>) ---
  // El adeudo SEPA es de cobro DIFERIDO: al completar el checkout solo se FIRMA
  // el mandato (payment_status 'unpaid'); el dinero entra días después (~5 días
  // hábiles el primer adeudo de un mandato nuevo, a veces hasta 14) o se
  // rechaza. Por eso (mig 311):
  //   completed sin pagar  → pago_estado 'en_camino' (+ mandato_firmado_en)
  //   async_payment_succeeded / completed 'paid' → pagos_confirmar → 'pagado'
  //       (pagos_aplicar_efecto pone pago_estado y pagado_en = fecha real)
  //   async_payment_failed → 'fallido' (y pagos_online 'fallido')
  //   charge.refunded / charge.dispute.created → 'devuelto'
  // pagos_confirmar/pagos_marcar son idempotentes por id de evento, así que no
  // pasa nada si pago-webhook recibe el mismo aviso y lo atiende también.
  const refSocio: string | null =
    (typeof objeto.client_reference_id === "string" ? objeto.client_reference_id : null) ??
    (typeof objeto.metadata?.referencia === "string" ? objeto.metadata.referencia : null);
  if (typeof refSocio === "string" && refSocio.startsWith("socio-")) {
    const altaId = refSocio.slice("socio-".length);
    const ses = typeof objeto.id === "string" && objeto.id.startsWith("cs_") ? objeto.id : null;
    const eventoId = String(evento.id ?? "");
    switch (tipo) {
      case "checkout.session.completed": {
        const pi = idDe(objeto.payment_intent);
        if (objeto.payment_status === "paid") {
          await rpcServicio("pagos_confirmar", { p_referencia: refSocio, p_session: ses, p_intent: pi, p_evento: eventoId });
          if (pi) await patchAltaSocioFiltro(`id=eq.${encodeURIComponent(altaId)}`, { stripe_pago_ref: pi });
        } else {
          await patchAltaSocioFiltro(
            `id=eq.${encodeURIComponent(altaId)}&pago_estado=in.(pendiente,fallido)`,
            { pago_estado: "en_camino", mandato_firmado_en: new Date().toISOString(), pagado_en: null, stripe_pago_ref: pi },
          );
        }
        break;
      }
      case "checkout.session.async_payment_succeeded": {
        await rpcServicio("pagos_confirmar", { p_referencia: refSocio, p_session: ses, p_evento: eventoId });
        break;
      }
      case "checkout.session.async_payment_failed": {
        await rpcServicio("pagos_marcar", { p_referencia: refSocio, p_estado: "fallido", p_evento: eventoId });
        await patchAltaSocioFiltro(
          `id=eq.${encodeURIComponent(altaId)}&pago_estado=in.(pendiente,en_camino)`,
          { pago_estado: "fallido" },
        );
        break;
      }
      default:
        break;
    }
    return new Response(JSON.stringify({ recibido: true, socio: true }), { status: 200 });
  }

  // --- CUOTA DE ENTRENO (suscripción SEPA trimestral, referencia entreno-<id>) ---
  if (await manejarEntreno(tipo, objeto, evento.livemode !== false)) {
    return new Response(JSON.stringify({ recibido: true, entreno: true }), { status: 200 });
  }

  // --- RECIBOS / BONOS (pago-crear; referencia en pagos_online) ---
  if (await manejarRecibo(tipo, objeto, evento.id ?? "")) {
    return new Response(JSON.stringify({ recibido: true, recibo: true }), { status: 200 });
  }

  const filtro = filtroDe(objeto);
  if (!filtro) {
    console.log(`Aviso ${tipo} sin forma de casarlo con un alta: se ignora.`);
    return new Response(JSON.stringify({ recibido: true, ignorado: true }), { status: 200 });
  }

  let hecho: Record<string, unknown> | null = null;

  switch (tipo) {
    // Se completó el alta de la suscripción (tarjeta guardada). Anotamos
    // cliente y suscripción y la damos por activa (aunque esté en prueba
    // hasta el 21: 'trialing' cuenta como activa para nosotros).
    case "checkout.session.completed": {
      if (objeto.mode === "subscription") {
        // Guardamos SIEMPRE cliente y suscripción, pero solo damos por «activa»
        // si Stripe confirma que el primer pago se cobró (payment_status 'paid',
        // o 'no_payment_required' en prueba sin cargo). Si queda 'unpaid' (la
        // tarjeta falló o quedó pendiente), NO la marcamos activa: ya lo hará
        // `invoice.paid` cuando el cobro entre de verdad, o `subscription.updated`
        // la dejará en impago. Así no cuenta como pagado a quien no lo está
        // (le pasó a una persona: activa sin ningún cobro).
        const pagado = objeto.payment_status === "paid" || objeto.payment_status === "no_payment_required";
        hecho = {
          stripe_customer_id: idDe(objeto.customer),
          stripe_subscription_id: idDe(objeto.subscription),
          ...(pagado ? { suscripcion_estado: "activa" } : {}),
        };
      } else if (objeto.mode === "payment") {
        // Pago puntual («ponle un pago»): marcar el cobro como cobrado.
        // El id del cobro viaja en metadata Y en client_reference_id
        // (cubocobro-<id>): se prueban las dos por robustez.
        let cobroId: string | null =
          (objeto.metadata?.cobro_id as string | undefined) ?? null;
        const ref = objeto.client_reference_id;
        if (!cobroId && typeof ref === "string" && ref.startsWith("cubocobro-")) {
          cobroId = ref.slice("cubocobro-".length);
        }
        if (cobroId) {
          await patchCobro(String(cobroId), {
            estado: "pagado",
            pagado_en: new Date().toISOString(),
            stripe_payment_intent: idDe(objeto.payment_intent),
          });
        } else {
          console.error("checkout.session.completed (payment) sin cobro_id:", JSON.stringify(objeto.metadata), objeto.client_reference_id);
        }
      }
      break;
    }

    // Entró un recibo mensual (o el primero, el del 21). Al día.
    case "invoice.paid":
    case "invoice.payment_succeeded": {
      const finPeriodo = objeto.lines?.data?.[0]?.period?.end ?? objeto.period_end;
      hecho = {
        suscripcion_estado: "activa",
        stripe_customer_id: idDe(objeto.customer),
        stripe_subscription_id: idDe(objeto.subscription),
        ultimo_cobro: aFecha(objeto.status_transitions?.paid_at) ?? new Date().toISOString(),
        proximo_cobro: aFecha(finPeriodo),
      };
      // Histórico: UNA fila en `pagos` por recibo cobrado (idempotente por factura).
      // Si falla (red, base), se apunta en el log y se sigue: lo importante es
      // que la cuota quede al día (patchAlta, más abajo). El resync no lo rehace
      // para el Cubo, así que el log es la pista.
      try { await registrarCobroCubo(objeto, filtro); }
      catch (e) { console.error("No se pudo registrar el cobro del Cubo en pagos:", objeto.id, e); }
      break;
    }

    // Falló un recibo (tarjeta caducada, sin fondos…). Impago.
    case "invoice.payment_failed": {
      hecho = { suscripcion_estado: "impago" };
      break;
    }

    // Se creó la suscripción (al activar), o cambió su estado (renovación,
    // prueba→activa, mora…). En ambos casos anotamos estado y próximo cobro.
    // En «prueba hasta el día 5», el próximo cobro es el fin de la prueba.
    case "customer.subscription.created":
    case "customer.subscription.updated": {
      const est = estadoDe(String(objeto.status ?? ""));
      const proximo = aFecha(objeto.current_period_end) ?? aFecha(objeto.trial_end);
      hecho = {
        stripe_subscription_id: objeto.id,
        stripe_customer_id: idDe(objeto.customer),
        ...(est ? { suscripcion_estado: est } : {}),
        ...(proximo ? { proximo_cobro: proximo } : {}),
      };
      break;
    }

    // Se dio de baja la suscripción.
    case "customer.subscription.deleted": {
      hecho = { suscripcion_estado: "cancelada" };
      break;
    }

    default:
      console.log(`Aviso ${tipo}: no hace falta hacer nada.`);
  }

  if (hecho) {
    // Quitamos los nulos para no pisar datos buenos con vacíos.
    const limpio = Object.fromEntries(Object.entries(hecho).filter(([, v]) => v != null));
    if (Object.keys(limpio).length) await patchAlta(filtro, limpio);
  }

  // [360] Tras dejar la cuota al día (y el cobro registrado): ¿había una pausa
  // de un mes aprobada esperando a este cobro? Solo en invoice.paid del Cubo.
  if (tipo === "invoice.paid" || tipo === "invoice.payment_succeeded") {
    try { await aplicarPausaPendiente(filtro, objeto, evento.livemode !== false); }
    catch (e) { console.error("Pausa del Cubo pendiente sin aplicar:", objeto.id, e); }
  }

  return new Response(JSON.stringify({ recibido: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
