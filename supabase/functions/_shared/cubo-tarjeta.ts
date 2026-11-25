// ============================================================
// _shared/cubo-tarjeta.ts · deja la tarjeta nueva como la de la cuota del Cubo
// ------------------------------------------------------------
// Lo usan DOS sitios, para que dé igual quién llegue antes:
//   · cubo-tarjeta (accion «aplicar»), cuando la persona vuelve de Stripe.
//   · cubo-webhook, con el aviso checkout.session.completed (mode=setup), por
//     si la persona cierra la pestaña antes de volver.
// Repetirlo no hace daño: poner la misma tarjeta por defecto dos veces es igual
// que una.
//
// Qué hace: lee la sesión de Stripe (modo setup) con su SetupIntent, comprueba
// que es del cliente y de la suscripción de ESA alta del Cubo y pone la tarjeta
// como la de cobro en la suscripción y en el cliente. Stripe la cobra desde el
// siguiente recibo.
// ============================================================

export const PREFIJO_TARJETA = "cubotarjeta-";

export type ResultadoTarjeta =
  | { ok: true; alta_id: string; perfil_id: string | null; marca: string | null; ultimas4: string | null }
  | { ok: false; codigo: string; mensaje: string };

async function stripe(key: string, ruta: string, metodo = "GET", cuerpo?: URLSearchParams) {
  const r = await fetch(`https://api.stripe.com/v1/${ruta}`, {
    method: metodo,
    headers: {
      Authorization: `Bearer ${key}`,
      ...(cuerpo ? { "Content-Type": "application/x-www-form-urlencoded" } : {}),
    },
    body: cuerpo ? cuerpo.toString() : undefined,
  });
  const d = await r.json().catch(() => null);
  return { ok: r.ok, datos: d as Record<string, any> | null };
}

function idDe(x: unknown): string | null {
  if (typeof x === "string") return x;
  if (x && typeof x === "object" && typeof (x as any).id === "string") return (x as any).id;
  return null;
}

/**
 * Aplica la tarjeta de una sesión de Checkout en modo setup.
 * @param leerAlta  lee la fila de cubo_altas por id (con la clave de servicio).
 */
export async function aplicarTarjeta(
  key: string,
  sesionId: string,
  leerAlta: (id: string) => Promise<Record<string, any> | null>,
): Promise<ResultadoTarjeta> {
  if (!/^cs_[A-Za-z0-9_]+$/.test(sesionId)) return { ok: false, codigo: "sesion", mensaje: "Sesión de pago no válida." };

  const rS = await stripe(key, `checkout/sessions/${sesionId}?expand[]=setup_intent.payment_method`);
  const s = rS.datos;
  if (!rS.ok || !s) return { ok: false, codigo: "stripe", mensaje: "No hemos podido leer el cambio en Stripe." };
  if (s.mode !== "setup") return { ok: false, codigo: "modo", mensaje: "Esa sesión no es un cambio de tarjeta." };
  const ref = String(s.client_reference_id ?? s.metadata?.referencia ?? "");
  if (!ref.startsWith(PREFIJO_TARJETA)) return { ok: false, codigo: "ref", mensaje: "Esa sesión no es del Cubo." };
  if (s.status !== "complete") return { ok: false, codigo: "sin_terminar", mensaje: "El cambio de tarjeta no se terminó." };

  const si = s.setup_intent && typeof s.setup_intent === "object" ? s.setup_intent : null;
  if (!si || si.status !== "succeeded") {
    return { ok: false, codigo: "sin_confirmar", mensaje: "Stripe todavía no ha confirmado la tarjeta. Prueba en un minuto." };
  }
  const pm = si.payment_method && typeof si.payment_method === "object" ? si.payment_method : null;
  const pmId = idDe(si.payment_method);
  if (!pmId) return { ok: false, codigo: "sin_tarjeta", mensaje: "No ha llegado ninguna tarjeta." };

  const altaId = ref.slice(PREFIJO_TARJETA.length);
  const alta = await leerAlta(altaId);
  if (!alta) return { ok: false, codigo: "sin_alta", mensaje: "No encontramos tu alta del Cubo." };
  const cliente = idDe(s.customer);
  if (!cliente || alta.stripe_customer_id !== cliente) {
    return { ok: false, codigo: "cliente", mensaje: "La tarjeta no corresponde a tu cuota. Escríbenos y lo miramos." };
  }
  const sub = String(alta.stripe_subscription_id ?? "");
  if (!sub) return { ok: false, codigo: "sin_sub", mensaje: "Tu cuota no tiene suscripción activa. Escríbenos y lo miramos." };

  // 1 · La suscripción cobra con esta tarjeta (lo que manda para la cuota).
  const pSub = new URLSearchParams();
  pSub.set("default_payment_method", pmId);
  const rSub = await stripe(key, `subscriptions/${encodeURIComponent(sub)}`, "POST", pSub);
  if (!rSub.ok) {
    console.error("cubo-tarjeta: Stripe no aceptó la tarjeta en la suscripción:", rSub.datos?.error?.message);
    return { ok: false, codigo: "suscripcion", mensaje: "Stripe no ha aceptado la tarjeta para la cuota. Escríbenos y lo miramos." };
  }
  // 2 · Y también por defecto en el cliente (por si algún cobro suelto la usa).
  const pCli = new URLSearchParams();
  pCli.set("invoice_settings[default_payment_method]", pmId);
  const rCli = await stripe(key, `customers/${encodeURIComponent(cliente)}`, "POST", pCli);
  if (!rCli.ok) console.warn("cubo-tarjeta: no se pudo poner por defecto en el cliente:", rCli.datos?.error?.message);

  return {
    ok: true,
    alta_id: altaId,
    perfil_id: (alta.perfil_id as string | null) ?? null,
    marca: pm?.card?.brand ?? null,
    ultimas4: pm?.card?.last4 ?? null,
  };
}
