// ============================================================
// cubo-cobro-confirmar · confirma un pago puntual mirando Stripe
// ------------------------------------------------------------
// Red de seguridad por si el webhook no llega: dado un cobro con su
// sesión de Stripe, se le pregunta a Stripe si está pagado; si sí, se
// marca cobrado. Solo el dueño del cobro (por su sesión) puede pedirlo.
//   supabase functions deploy cubo-cobro-confirmar --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const STRIPE_KEY =
  Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ??
  Deno.env.get("STRIPE_SECRET_KEY") ?? "";

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
    status: estado, headers: { ...cors(origen), "Content-Type": "application/json; charset=utf-8" },
  });
}
async function rest(ruta: string, opciones: RequestInit = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...opciones,
    headers: {
      apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json", ...(opciones.headers ?? {} as Record<string,string>),
    },
  });
  const t = await r.text();
  let d: unknown = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, datos: d };
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ ok: false }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY || !STRIPE_KEY) return responder({ ok: false, motivo: "config" }, 200, origen);

  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  if (!jwt) return responder({ ok: false, motivo: "sesion" }, 401, origen);
  const rU = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` } });
  if (!rU.ok) return responder({ ok: false, motivo: "sesion" }, 401, origen);
  const usuario = await rU.json().catch(() => null);
  const correo: string = (usuario?.email ?? "").toLowerCase();
  if (!correo) return responder({ ok: false, motivo: "sesion" }, 401, origen);
  const rP = await rest(`perfiles?select=id&email=eq.${encodeURIComponent(correo)}&limit=1`);
  const perfilId: string | null = Array.isArray(rP.datos) && rP.datos[0] ? rP.datos[0].id : null;
  if (!perfilId) return responder({ ok: false, motivo: "perfil" }, 404, origen);

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* */ }
  const cobroId = String(cuerpo.cobro_id ?? "").trim();
  if (!cobroId) return responder({ ok: false, motivo: "datos" }, 400, origen);

  const rC = await rest(`cubo_cobros?select=id,perfil_id,estado,stripe_session_id&id=eq.${encodeURIComponent(cobroId)}&limit=1`);
  const cobro = Array.isArray(rC.datos) ? rC.datos[0] : null;
  if (!cobro || cobro.perfil_id !== perfilId) return responder({ ok: false, motivo: "no-tuyo" }, 403, origen);
  if (cobro.estado === "pagado") return responder({ ok: true, pagado: true }, 200, origen);
  if (!cobro.stripe_session_id) return responder({ ok: true, pagado: false }, 200, origen);

  // Preguntar a Stripe por la sesión.
  const rS = await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(cobro.stripe_session_id)}`, {
    headers: { Authorization: `Bearer ${STRIPE_KEY}` },
  });
  const ses = await rS.json().catch(() => null);
  if (!rS.ok || !ses) return responder({ ok: false, motivo: "stripe" }, 502, origen);

  if (ses.payment_status === "paid") {
    await rest(`cubo_cobros?id=eq.${encodeURIComponent(cobroId)}&estado=eq.pendiente`, {
      method: "PATCH", headers: { Prefer: "return=minimal" },
      body: JSON.stringify({
        estado: "pagado", pagado_en: new Date().toISOString(),
        stripe_payment_intent: typeof ses.payment_intent === "string" ? ses.payment_intent : null,
      }),
    });
    return responder({ ok: true, pagado: true }, 200, origen);
  }
  return responder({ ok: true, pagado: false }, 200, origen);
});
