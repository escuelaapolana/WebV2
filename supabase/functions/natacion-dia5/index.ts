// ============================================================
// natacion-dia5 · Pasar al DÍA 5 las cuotas de natación ya domiciliadas
// ------------------------------------------------------------
// Mig 429 (22-oct-2026, Mario/Andrés): desde ahora las cuotas de natación se
// cobran el día 5. Las nuevas ya nacen así (entreno-pagar + planNatacion);
// esta función mueve las que YA estaban domiciliadas con otro día (el del
// alta), sin cobrar de más ni de menos:
//   · su próximo cobro pasa al día 5 DEL MISMO MES en que tocaba
//     (21-nov → 5-nov; 20-ene → 5-ene; 1-nov → 5-nov), con `trial_end` y
//     proration_behavior=none (el hueco hasta el 5 no se cobra ni se devuelve);
//   · la parada (`cancel_at`) se recoloca en el límite de periodo nuevo
//     (_shared cancelAtExacto), para que el último cobro no se prorratee.
// body {}                → solo calcula (antes / después), NO toca nada.
// body { aplicar: true } → lo cambia en Stripe y en `cuotas_entreno`.
// Se llama desde la base: select public.cron_llamar_edge('natacion-dia5', '{...}')
// (cabecera x-cron-secret). Idempotente: si ya cobra el día 5, no la toca.
//
//   supabase functions deploy natacion-dia5 --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

import { cancelAtExacto, diaDeMes, finUnixDe, DIA_COBRO_NATACION } from "../_shared/cuota-entreno.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";
const CRON_SECRET = (Deno.env.get("CRON_SECRET") ?? "").trim();

function iguales(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a), eb = new TextEncoder().encode(b);
  let dif = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) dif |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return dif === 0;
}
const json = (d: unknown, s = 200) => new Response(JSON.stringify(d), { status: s, headers: { "Content-Type": "application/json" } });
const aFecha = (u?: number | null) => (u && u > 0 ? new Date(u * 1000).toISOString() : null);
const ymdMadrid = (u: number) => new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(u * 1000));

async function rest(ruta: string, init: RequestInit = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...init, headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
  });
  const t = await r.text();
  try { return { ok: r.ok, datos: t ? JSON.parse(t) : null }; } catch { return { ok: r.ok, datos: t }; }
}
async function stripe(metodo: "GET" | "POST", ruta: string, cuerpo?: string) {
  const r = await fetch(`https://api.stripe.com/v1/${ruta}`, {
    method: metodo, headers: { Authorization: `Bearer ${STRIPE_KEY}`, ...(cuerpo ? { "Content-Type": "application/x-www-form-urlencoded" } : {}) },
    body: cuerpo,
  });
  return { ok: r.ok, estado: r.status, datos: await r.json().catch(() => null) };
}
// Próximo cobro de una suscripción: fin de la «prueba» o fin del periodo actual.
function proximoDe(s: any): number {
  if (s?.status === "trialing" && Number(s.trial_end) > 0) return Number(s.trial_end);
  return Number(s?.current_period_end ?? s?.items?.data?.[0]?.current_period_end ?? 0);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "metodo" }, 405);
  if (!SUPABASE_URL || !SERVICE_KEY || !STRIPE_KEY || !CRON_SECRET) return json({ error: "config" }, 503);
  const sec = (req.headers.get("x-cron-secret") ?? "").trim();
  if (!sec || !iguales(sec, CRON_SECRET)) return json({ error: "secreto" }, 401);
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const aplicar = cuerpo.aplicar === true;

  const rA = await rest("cuotas_entreno?select=id,nombre,apellidos,stripe_subscription_id,fin,periodicidad,suscripcion_estado" +
    "&origen=eq.natacion&stripe_subscription_id=not.is.null&suscripcion_estado=in.(activa,en_camino)");
  const cuotas: any[] = Array.isArray(rA.datos) ? rA.datos : [];
  const ahora = Math.floor(Date.now() / 1000);
  const salida: any[] = [];

  for (const c of cuotas) {
    const quien = `${c.nombre ?? ""} ${c.apellidos ?? ""}`.trim();
    const g = await stripe("GET", `subscriptions/${encodeURIComponent(c.stripe_subscription_id)}`);
    const s = g.datos;
    if (!g.ok || !s || ["canceled", "incomplete_expired"].includes(String(s.status))) {
      salida.push({ quien, error: g.ok ? `suscripción ${s?.status}` : `Stripe ${g.estado}` }); continue;
    }
    const prox = proximoDe(s);
    if (!(prox > 0)) { salida.push({ quien, error: "sin próximo cobro" }); continue; }
    const [y, m, d] = ymdMadrid(prox).split("-").map(Number);
    const nuevo = diaDeMes(y, m, 0);
    const fila: Record<string, unknown> = { quien, estado: s.status, antes: aFecha(prox), despues: aFecha(nuevo), cancel_antes: aFecha(s.cancel_at) };
    if (d === DIA_COBRO_NATACION) { fila.nada = "ya cobra el día 5"; salida.push(fila); continue; }
    if (nuevo <= ahora + 49 * 3600) { fila.error = "el día 5 de ese mes ya está demasiado cerca"; salida.push(fila); continue; }
    const x = cancelAtExacto({ ...s, billing_cycle_anchor: nuevo }, finUnixDe(c.fin));
    if ("error" in x) { fila.error = x.error; salida.push(fila); continue; }
    fila.cancel_despues = aFecha(x.cancelAt);
    fila.cobros_restantes = x.cobros;
    if (aplicar) {
      const u = await stripe("POST", `subscriptions/${encodeURIComponent(s.id)}`, `trial_end=${nuevo}&proration_behavior=none`);
      if (!u.ok) { fila.error = u.datos?.error?.message ?? `Stripe ${u.estado}`; salida.push(fila); continue; }
      const v = await stripe("POST", `subscriptions/${encodeURIComponent(s.id)}`, `cancel_at=${x.cancelAt}&proration_behavior=none`);
      if (!v.ok) fila.error_parada = v.datos?.error?.message ?? `Stripe ${v.estado}`;
      const fin = await stripe("GET", `subscriptions/${encodeURIComponent(s.id)}`);
      fila.comprobado = { estado: fin.datos?.status, proximo: aFecha(proximoDe(fin.datos)), ancla: aFecha(fin.datos?.billing_cycle_anchor), cancel_at: aFecha(fin.datos?.cancel_at) };
      await rest(`cuotas_entreno?id=eq.${encodeURIComponent(c.id)}`, {
        method: "PATCH", headers: { Prefer: "return=minimal" },
        body: JSON.stringify({ proximo_cobro: aFecha(nuevo), cancel_programado: !v.ok ? false : true }),
      });
      fila.aplicado = true;
    }
    salida.push(fila);
  }
  console.log("[natacion-dia5]", aplicar ? "APLICADO" : "simulación", JSON.stringify(salida));
  return json({ ok: true, aplicar, cuotas: salida });
});
