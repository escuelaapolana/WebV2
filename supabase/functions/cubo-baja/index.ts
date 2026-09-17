// ============================================================
// cubo-baja · el club da de baja la cuota de un socio del Cubo
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   Desde el panel de admin, el club pulsa «Dar de baja» en una ficha del
//   Cubo. Esta función comprueba que quien llama es admin, cancela su
//   suscripción en Stripe (deja de cobrar) y marca la cuota como cancelada.
//   El aviso de baja pendiente (`baja_solicitada`) se limpia.
//
//   El padre NO llega aquí: él solo SOLICITA la baja (RPC
//   `cubo_baja_solicitar`), y el club la ejecuta. Así el club controla las
//   bajas (no se cancelan solas a media temporada).
//
// CLAVES (variables de Supabase; aquí no hay ninguna)
//   STRIPE_SECRET_KEY_APOLANA / SUPABASE_URL / SERVICE_ROLE_KEY / ANON_KEY
//
//   supabase functions deploy cubo-baja --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";

function cors(o: string | null): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": o ?? "*",
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

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY || !STRIPE_KEY) {
    return responder({ error: "config", mensaje: "No está configurado." }, 503, origen);
  }

  // 1 · Sesión y que sea ADMIN
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
  if (!esAdmin) return responder({ error: "no_admin", mensaje: "Solo el club puede dar de baja." }, 403, origen);

  // 2 · La ficha del Cubo
  let cuerpo: Record<string, any> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const altaId = String(cuerpo.alta_id ?? "").trim();
  if (!altaId) return responder({ error: "datos", mensaje: "Falta la ficha." }, 400, origen);
  const rA = await rest(`cubo_altas?select=id,stripe_subscription_id&id=eq.${encodeURIComponent(altaId)}&limit=1`);
  const alta = Array.isArray(rA.datos) ? rA.datos[0] : null;
  if (!alta) return responder({ error: "no_existe", mensaje: "Esa ficha ya no está." }, 404, origen);

  // 3 · Cancelar en Stripe (si tiene suscripción)
  const sub = alta.stripe_subscription_id;
  if (sub) {
    const rS = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(sub)}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${STRIPE_KEY}` },
    });
    if (!rS.ok) {
      const err = await rS.json().catch(() => null);
      const code = err?.error?.code ?? "";
      // Si ya no existe / ya está cancelada, seguimos como si nada.
      if (code !== "resource_missing") {
        console.error("Stripe no canceló:", err?.error?.message ?? rS.status);
        return responder({ error: "pasarela", mensaje: "No se ha podido cancelar en Stripe. Inténtalo de nuevo." }, 502, origen);
      }
    }
  }

  // 4 · Marcar cancelada y limpiar la solicitud (el webhook también lo hará)
  await rest(`cubo_altas?id=eq.${encodeURIComponent(altaId)}`, {
    method: "PATCH",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify({ suscripcion_estado: "cancelada", baja_solicitada: null }),
  });

  return responder({ ok: true }, 200, origen);
});
