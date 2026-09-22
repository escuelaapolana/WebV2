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

const TOLERANCIA_SEGUNDOS = 60 * 5;

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

const idDe = (v: unknown): string | null =>
  typeof v === "string" ? v : ((v as { id?: string } | null)?.id ?? null);

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
  if (!SUPABASE_URL || !SERVICE_KEY || !WEBHOOK_SECRET) {
    console.error("Faltan variables: el webhook del Cubo no puede trabajar.");
    return new Response("Sin configurar.", { status: 503 });
  }

  const crudo = await req.text();
  const cabecera = req.headers.get("stripe-signature") ?? "";
  if (!(await firmaValida(crudo, cabecera, WEBHOOK_SECRET))) {
    console.warn("Aviso del Cubo con firma que no cuadra: descartado.");
    return new Response("Firma no válida.", { status: 400 });
  }

  let evento: Record<string, any>;
  try { evento = JSON.parse(crudo); } catch { return new Response("Aviso ilegible.", { status: 400 }); }

  const tipo: string = evento.type ?? "";
  const objeto = evento.data?.object ?? null;
  if (!objeto) return new Response(JSON.stringify({ recibido: true }), { status: 200 });

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

    // Cambió el estado de la suscripción (renovación, prueba→activa, mora…).
    case "customer.subscription.updated": {
      const est = estadoDe(String(objeto.status ?? ""));
      hecho = {
        stripe_subscription_id: objeto.id,
        stripe_customer_id: idDe(objeto.customer),
        ...(est ? { suscripcion_estado: est } : {}),
        proximo_cobro: aFecha(objeto.current_period_end),
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
