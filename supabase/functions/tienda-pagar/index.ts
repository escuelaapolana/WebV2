// ============================================================
// tienda-pagar · registra un ENCARGO de ropa (ya NO cobra: se paga en la oficina)
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   El navegador manda el CARRITO (qué prendas, tallas y cuántas) y,
//   si compra sin cuenta, sus datos de contacto. Esta función mira EN
//   LA BASE cuánto vale de verdad cada prenda y crea el ENCARGO
//   («pendiente», sin pago online). Se paga en la oficina del club, con
//   tarjeta o en efectivo, al recogerlo (lo marca admin/pedidos).
//
// LO QUE NO SE FÍA DEL NAVEGADOR
//   · Los precios. Los pone `tienda_pedido_efectivo()` leyendo `productos`.
//     Si el navegador manda un importe, se tira a la basura.
//   · Quién es. NO hace falta sesión (la ropa se vende también a
//     invitados). Pero SI viene una sesión válida, se enlaza el pedido
//     a su ficha de socio. Si el token no vale, se sigue como invitado.
//
// CLAVES (variables de entorno de Supabase; aquí no hay ninguna)
//     (desde la 413 ya NO usa STRIPE_SECRET_KEY: la ropa es por encargo)
//     SUPABASE_URL / SERVICE_ROLE_KEY / ANON_KEY  (las pone Supabase)
//   Opcional: PAGOS_ORIGENES
//
// Se despliega SIN comprobar el JWT (el invitado no tiene sesión; la
// función ya trata el token como opcional):
//     supabase functions deploy tienda-pagar --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";

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

// Solo se le acepta al navegador el carrito y el contacto; nada de dinero.
function limpiarItems(bruto: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(bruto)) return [];
  return bruto.slice(0, 50).map((l) => {
    const o = (l ?? {}) as Record<string, unknown>;
    return {
      producto_id: String(o.producto_id ?? o.id ?? "").trim(),
      talla: o.talla != null ? String(o.talla).trim() : "",
      cantidad: Math.max(1, Math.min(10, Math.round(Number(o.cantidad ?? 1)) || 1)),
    };
  }).filter((l) => l.producto_id);
}

function limpiarContacto(bruto: unknown): Record<string, string> {
  const o = (bruto ?? {}) as Record<string, unknown>;
  const corta = (v: unknown, n: number) => String(v ?? "").trim().slice(0, n);
  return {
    nombre: corta(o.nombre, 120),
    email: corta(o.email, 160).toLowerCase(),
    telefono: corta(o.telefono, 40),
    recogida: corta(o.recogida, 120),
    nota: corta(o.nota, 300),
  };
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ error: "config", mensaje: "El pago con tarjeta no está configurado." }, 503, origen);
  }

  // ---------------------------------------------------------------
  // 1 · Sesión OPCIONAL. Si hay token y vale, se enlaza a su ficha.
  //     Si no, se compra como invitado (la ropa es pública).
  // ---------------------------------------------------------------
  let perfilId: string | null = null;
  let correoSocio = "";
  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  // Ojo: el token del anon de Supabase también llega aquí; solo nos vale
  // si identifica a una PERSONA (tiene email). Si no, se ignora sin más.
  if (jwt) {
    const rUsuario = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` },
    });
    if (rUsuario.ok) {
      const usuario = await rUsuario.json().catch(() => null);
      const correo: string = (usuario?.email ?? "").toLowerCase();
      if (correo) {
        correoSocio = correo;
        const rPerfil = await consulta(
          `perfiles?select=id&email=eq.${encodeURIComponent(correo)}&limit=1`,
        );
        const perfil = Array.isArray(rPerfil.datos) ? rPerfil.datos[0] : null;
        perfilId = perfil?.id ?? null;
      }
    }
  }

  // ---------------------------------------------------------------
  // 2 · El carrito y el contacto (lo ÚNICO que se acepta del navegador)
  // ---------------------------------------------------------------
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }

  const items = limpiarItems(cuerpo.items ?? cuerpo.carrito);
  const contacto = limpiarContacto(cuerpo.contacto);

  if (!items.length) {
    return responder({ error: "carrito_vacio", mensaje: "Tu cesta está vacía." }, 400, origen);
  }
  // A un invitado le pedimos al menos nombre y una forma de contactar.
  if (!perfilId && (!contacto.nombre || !(contacto.email || contacto.telefono))) {
    return responder({
      error: "faltan_datos",
      mensaje: "Para comprar sin cuenta necesitamos tu nombre y un correo o teléfono.",
    }, 400, origen);
  }

  // ---------------------------------------------------------------
  // 3 · LA ROPA ES POR ENCARGO (Andrés, 20-oct-2026; migración 413)
  //     Se crea el pedido «pendiente» y se paga EN LA OFICINA, con tarjeta
  //     o en efectivo, al recogerlo. Esta función YA NO abre la pasarela de
  //     Stripe aunque alguien la llame a mano o se vuelva a poner
  //     pagos_config.tienda_pago_online = true: ese camino se ha quitado
  //     (tienda_pago_iniciar ya ni siquiera se puede llamar desde fuera).
  //     Si algún día se quiere cobrar la ropa online otra vez, hay que
  //     recuperar el bloque de Stripe del historial de git (antes de la 413).
  // ---------------------------------------------------------------
  const rPed = await consulta("rpc/tienda_pedido_efectivo", {
    method: "POST",
    body: JSON.stringify({ p_items: items, p_contacto: contacto, p_perfil: perfilId }),
  });
  if (!rPed.ok) {
    const msg = (rPed.datos as { message?: string } | null)?.message ?? "";
    return responder({ error: "no_se_puede", mensaje: msg || "No se ha podido registrar el encargo." }, 400, origen);
  }
  const ped = (Array.isArray(rPed.datos) ? rPed.datos[0] : rPed.datos) as Record<string, any> | null;
  return responder({ ok: true, efectivo: true, encargo: true, total: Number(ped?.total ?? 0) }, 200, origen);
});
