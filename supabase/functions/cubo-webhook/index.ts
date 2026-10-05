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

// La cuota de entreno se cancela sola tras ABRIL: cancel_at a primeros de mayo
// de 2027 (el cargo de abril ya ha pasado; el de julio no llega). En segundos.
const ENTRENO_CANCEL_AT = Math.floor(Date.UTC(2027, 4, 6, 9, 0, 0) / 1000);

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

// Marca un ALTA DE SOCIO como pagada. Solo si no lo estaba ya (idempotente).
async function patchAltaSocio(altaId: string, cambios: Record<string, unknown>) {
  const r = await fetch(
    `${SUPABASE_URL}/rest/v1/altas_socio?id=eq.${encodeURIComponent(altaId)}&pago_estado=neq.pagado`,
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
    `${SUPABASE_URL}/rest/v1/cuotas_entreno?select=id,atleta_id,nombre,apellidos,importe_cent,cancel_programado,stripe_subscription_id&id=eq.${encodeURIComponent(id)}&limit=1`,
    { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } },
  );
  if (!r.ok) return null;
  const filas = await r.json().catch(() => []);
  return Array.isArray(filas) ? (filas[0] ?? null) : null;
}

// Programa la cancelación de la suscripción tras el cargo de abril (cancel_at).
// Se hace una sola vez (cancel_programado). Elige la clave por livemode.
async function programarCancelEntreno(subId: string, livemode: boolean) {
  const key = livemode ? SK_LIVE : SK_TEST;
  if (!key || !subId) return;
  const r = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(subId)}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/x-www-form-urlencoded" },
    body: `cancel_at=${ENTRENO_CANCEL_AT}`,
  });
  if (!r.ok) console.error("No se pudo programar cancel_at de entreno:", r.status, await r.text().catch(() => ""));
  return r.ok;
}

// Registra un cobro liquidado de entreno como recibo PAGADO en `pagos`.
// Idempotente: no inserta si ya hay un recibo con la misma factura de Stripe
// (se guarda su id en `notas`). El trimestre sale del mes del periodo.
async function registrarCobroEntreno(objeto: Record<string, any>, cuota: Record<string, any>) {
  const invId = String(objeto.id ?? "");
  if (!invId) return;
  const marca = `stripe:${invId}`;
  const yaR = await fetch(
    `${SUPABASE_URL}/rest/v1/pagos?select=id&notas=eq.${encodeURIComponent(marca)}&limit=1`,
    { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } },
  );
  if (yaR.ok) { const f = await yaR.json().catch(() => []); if (Array.isArray(f) && f.length) return; }

  const inicio = Number(objeto.lines?.data?.[0]?.period?.start ?? objeto.created ?? 0);
  const d = inicio > 0 ? new Date(inicio * 1000) : new Date();
  const mes = d.getUTCMonth() + 1;   // 1..12
  const ano = d.getUTCFullYear();
  let etq = "trimestre";
  if (mes >= 10) etq = `1er trimestre (oct-dic ${ano})`;
  else if (mes <= 3) etq = `2º trimestre (ene-mar ${ano})`;
  else if (mes <= 6) etq = `3er trimestre (abr-jun ${ano})`;
  const periodo = `${ano}-${String(mes).padStart(2, "0")}`;
  const importe = (Number(objeto.amount_paid ?? cuota.importe_cent ?? 0) || 0) / 100;
  const hoy = new Date().toISOString().slice(0, 10);

  const r = await fetch(`${SUPABASE_URL}/rest/v1/pagos`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json", Prefer: "return=minimal",
    },
    body: JSON.stringify({
      atleta_id: cuota.atleta_id,
      concepto: `Cuota de entrenamiento · ${etq}`,
      importe,
      estado: "pagado",
      fecha_pago: hoy,
      metodo: "domiciliado",
      cuenta: "club",
      periodo,
      notas: marca,
    }),
  });
  if (!r.ok) console.error("INSERT pago de entreno falló:", r.status, await r.text().catch(() => ""));
}

// Devuelve true si el evento era de ENTRENO y ya se ha gestionado aquí.
async function manejarEntreno(tipo: string, objeto: Record<string, any>, livemode: boolean): Promise<boolean> {
  const ref = refDe(objeto);
  if (typeof ref !== "string" || !ref.startsWith("entreno-")) return false;
  const cuotaId = ref.slice("entreno-".length);

  switch (tipo) {
    case "checkout.session.completed": {
      if (objeto.mode === "subscription") {
        const subId = idDe(objeto.subscription);
        await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, {
          stripe_customer_id: idDe(objeto.customer),
          stripe_subscription_id: subId,
          suscripcion_estado: "activa",
        });
        // Programar la cancelación tras abril (una sola vez).
        const cuota = await getEntreno(cuotaId);
        if (subId && cuota && cuota.cancel_programado !== true) {
          await programarCancelEntreno(subId, livemode);
          await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, { cancel_programado: true });
        }
      }
      break;
    }
    case "invoice.paid":
    case "invoice.payment_succeeded": {
      const finPeriodo = objeto.lines?.data?.[0]?.period?.end ?? objeto.period_end;
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
    case "invoice.payment_failed": {
      await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, { suscripcion_estado: "impago" });
      break;
    }
    case "customer.subscription.created":
    case "customer.subscription.updated": {
      const est = estadoDe(String(objeto.status ?? ""));
      const proximo = aFecha(objeto.current_period_end) ?? aFecha(objeto.trial_end);
      await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, {
        stripe_subscription_id: objeto.id,
        stripe_customer_id: idDe(objeto.customer),
        ...(est ? { suscripcion_estado: est } : {}),
        ...(proximo ? { proximo_cobro: proximo } : {}),
      });
      break;
    }
    case "customer.subscription.deleted": {
      await patchEntreno(`id=eq.${encodeURIComponent(cuotaId)}`, { suscripcion_estado: "cancelada" });
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

  // --- ALTA DE SOCIO pagada por SEPA (referencia socio-<id de alta>) ---
  // El adeudo SEPA es de cobro diferido: al completar el checkout se acepta el
  // mandato (el dinero entra en unos días). Damos el alta por pagada aquí, al
  // aceptar el mandato, que es lo acordado; si luego se devuelve, lo ve el club.
  const refSocio: string | null =
    (typeof objeto.client_reference_id === "string" ? objeto.client_reference_id : null) ??
    (typeof objeto.metadata?.referencia === "string" ? objeto.metadata.referencia : null);
  if (typeof refSocio === "string" && refSocio.startsWith("socio-")) {
    if (tipo === "checkout.session.completed") {
      await patchAltaSocio(refSocio.slice("socio-".length), {
        pago_estado: "pagado",
        pagado_en: new Date().toISOString(),
        stripe_pago_ref: idDe(objeto.payment_intent),
      });
    }
    return new Response(JSON.stringify({ recibido: true, socio: true }), { status: 200 });
  }

  // --- CUOTA DE ENTRENO (suscripción SEPA trimestral, referencia entreno-<id>) ---
  if (await manejarEntreno(tipo, objeto, evento.livemode !== false)) {
    return new Response(JSON.stringify({ recibido: true, entreno: true }), { status: 200 });
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
        hecho = {
          stripe_customer_id: idDe(objeto.customer),
          stripe_subscription_id: idDe(objeto.subscription),
          suscripcion_estado: "activa",
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

  return new Response(JSON.stringify({ recibido: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
