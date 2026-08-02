// ============================================================
// pago-webhook · Stripe avisa de que el dinero ha entrado
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   Cuando alguien termina de pagar, Stripe llama a esta dirección
//   para contarlo. Aquí se comprueba que el aviso es de verdad de
//   Stripe, se marca el pago como cobrado y —lo importante— se le
//   dan al momento los usos del bono de El Cubo. La persona no
//   espera a que nadie mire el banco.
//
// LOS DOS PUNTOS DELICADOS
//
//   1) LA FIRMA. Esta dirección es pública: cualquiera puede llamarla
//      y decir «hola, fulano ha pagado». Por eso Stripe firma cada
//      aviso con una clave que solo tenéis vosotros y él. Aquí se
//      recalcula esa firma sobre el texto EXACTO recibido y se
//      compara. Si no cuadra, se contesta 400 y no se toca nada.
//      Sin esto, cualquiera se regalaría bonos.
//      Ojo: la firma se hace sobre el cuerpo CRUDO. Por eso se lee
//      con `req.text()` y no con `req.json()`: si se parsea y se
//      vuelve a serializar, cambia un espacio y la firma ya no vale.
//
//   2) NO REPETIR. Stripe reintenta sus avisos hasta que le
//      contestamos 200: recibir el mismo dos o tres veces es normal,
//      no una avería. Los usos del bono NO se pueden dar dos veces.
//      Aquí solo se llama a `pagos_confirmar()`, que lleva dentro los
//      tres candados (el identificador del aviso, el sello del pago y
//      el índice único del bono). Ver la migración 053, apartado 6.
//
// CLAVES (variables de entorno de Supabase; aquí no hay ninguna)
//     STRIPE_WEBHOOK_SECRET      (la copias del panel de Stripe)
//     SUPABASE_URL               (la pone Supabase sola)
//     SUPABASE_SERVICE_ROLE_KEY  (la pone Supabase sola)
//
// Cómo se despliega (SIN comprobar el JWT: quien llama es Stripe, no
// una persona con sesión; la seguridad la da la firma):
//     supabase functions deploy pago-webhook --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";

// Margen de reloj: un aviso con más de cinco minutos se rechaza, para
// que nadie pueda reenviar uno viejo que grabó por el camino.
const TOLERANCIA_SEGUNDOS = 60 * 5;

// ------------------------------------------------------------
// Comprobar la firma de Stripe (HMAC-SHA256, sin librerías)
// ------------------------------------------------------------
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

// Comparación que tarda siempre lo mismo: si se saliera en cuanto
// falla un byte, se podría adivinar la firma a base de medir tiempos.
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
    "raw",
    new TextEncoder().encode(secreto),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const esperada = new Uint8Array(
    await crypto.subtle.sign("HMAC", clave, new TextEncoder().encode(`${marca}.${cuerpo}`)),
  );

  return firmas.some((f) => igualesSinPrisa(esperada, hexABytes(f)));
}

// ------------------------------------------------------------
// Hablar con la base con la llave de servicio
// ------------------------------------------------------------
async function rpc(nombre: string, args: Record<string, unknown>) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${nombre}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(args),
  });
  const texto = await r.text();
  let datos: unknown = null;
  try { datos = texto ? JSON.parse(texto) : null; } catch { datos = texto; }
  return { ok: r.ok, datos };
}

// De un aviso de Stripe, sacar CON QUÉ PAGO casarlo.
function referenciaDe(objeto: Record<string, any> | null | undefined): string | null {
  if (!objeto) return null;
  return objeto.client_reference_id
    ?? objeto.metadata?.referencia
    ?? objeto.payment_intent?.metadata?.referencia
    ?? null;
}

Deno.serve(async (req: Request): Promise<Response> => {
  // A esta dirección solo llama Stripe, y siempre con POST. No lleva
  // cabeceras CORS a propósito: no es para el navegador.
  if (req.method !== "POST") return new Response("Método no admitido.", { status: 405 });

  if (!SUPABASE_URL || !SERVICE_KEY || !WEBHOOK_SECRET) {
    // Sin claves no se puede comprobar nada, así que no se confirma
    // ningún pago. Se contesta 503 para que Stripe reintente cuando
    // el club termine de configurarlo.
    console.error("Faltan variables de entorno: el webhook no puede trabajar.");
    return new Response("Sin configurar.", { status: 503 });
  }

  // ¡El cuerpo CRUDO! (ver la nota de arriba sobre la firma)
  const crudo = await req.text();
  const cabecera = req.headers.get("stripe-signature") ?? "";

  if (!(await firmaValida(crudo, cabecera, WEBHOOK_SECRET))) {
    console.warn("Aviso con firma que no cuadra: descartado.");
    return new Response("Firma no válida.", { status: 400 });
  }

  let evento: Record<string, any>;
  try {
    evento = JSON.parse(crudo);
  } catch {
    return new Response("Aviso ilegible.", { status: 400 });
  }

  const tipo: string = evento.type ?? "";
  const eventoId: string = evento.id ?? "";
  const objeto = evento.data?.object ?? null;
  const referencia = referenciaDe(objeto);

  // Un aviso sin referencia no es nuestro (o es de una prueba suelta
  // del panel de Stripe): se acepta y se ignora, para que Stripe no
  // se quede reintentándolo eternamente.
  if (!referencia) {
    console.log(`Aviso ${tipo} sin referencia del club: se ignora.`);
    return new Response(JSON.stringify({ recibido: true, ignorado: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  let resultado: unknown = null;

  switch (tipo) {
    // El caso normal: se ha pagado con tarjeta y el dinero está.
    case "checkout.session.completed": {
      if (objeto?.payment_status === "paid") {
        resultado = (await rpc("pagos_confirmar", {
          p_referencia: referencia,
          p_session: objeto?.id ?? null,
          p_intent: typeof objeto?.payment_intent === "string" ? objeto.payment_intent : null,
          p_evento: eventoId,
        })).datos;
      } else {
        // Métodos que tardan (algunos adeudos): aún no está cobrado.
        // Se deja «iniciado» y ya avisará Stripe cuando entre.
        console.log(`Sesión ${objeto?.id} terminada pero aún sin cobrar.`);
        resultado = { pendiente: true };
      }
      break;
    }

    // Pago lento que al final sí entró.
    case "checkout.session.async_payment_succeeded":
    case "payment_intent.succeeded": {
      resultado = (await rpc("pagos_confirmar", {
        p_referencia: referencia,
        p_session: tipo.startsWith("checkout") ? (objeto?.id ?? null) : null,
        p_intent: tipo.startsWith("payment_intent") ? (objeto?.id ?? null) : null,
        p_evento: eventoId,
      })).datos;
      break;
    }

    // No salió.
    case "checkout.session.async_payment_failed":
    case "payment_intent.payment_failed": {
      resultado = (await rpc("pagos_marcar", {
        p_referencia: referencia, p_estado: "fallido", p_evento: eventoId,
      })).datos;
      break;
    }

    // Se dejó a medias o caducó la pasarela.
    case "checkout.session.expired": {
      resultado = (await rpc("pagos_marcar", {
        p_referencia: referencia, p_estado: "cancelado", p_evento: eventoId,
      })).datos;
      break;
    }

    // Se devolvió el dinero. OJO: esto marca el pago como devuelto,
    // pero NO quita los usos del bono. Quitar usos es una decisión del
    // club (puede que ya se hayan gastado), así que se hace a mano
    // desde el panel de El Cubo. Aquí solo queda constancia.
    case "charge.refunded":
    case "charge.refund.updated": {
      resultado = (await rpc("pagos_marcar", {
        p_referencia: referencia, p_estado: "reembolsado", p_evento: eventoId,
      })).datos;
      break;
    }

    default:
      console.log(`Aviso ${tipo}: no hace falta hacer nada.`);
      resultado = { ignorado: true };
  }

  // Siempre 200 si el aviso era legítimo: si contestáramos error,
  // Stripe lo reintentaría en bucle sin que sirviera de nada.
  return new Response(JSON.stringify({ recibido: true, resultado }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
