// ============================================================
// natacion-pausa · PAUSAR la cuota de natación (no cobrar uno o más meses)
//                  y apuntar el motivo (mig 543)
// ------------------------------------------------------------
// Criterio de Mario aprobado por Andrés (26-nov-2026): una baja médica, una
// exención o una ausencia NO se resuelve anulando la cuota, sino pausándola
// con su motivo (y una fecha para revisarla).
//
//   { accion: "pausar", atleta_id, tipo, motivo, desde_mes: "AAAA-MM",
//     hasta_mes: "AAAA-MM" | null (= hasta nuevo aviso), revisar_el?, guarda_plaza? }
//     · Cuota domiciliada (Stripe): pause_collection behavior=void → Stripe
//       genera los recibos de esos meses y los ANULA solo; con hasta_mes,
//       resumes_at = día 1 del mes siguiente y vuelve a cobrar el día 5.
//       Pausar ya anula todos los recibos hasta reanudar, así que la pausa
//       empieza en el PRÓXIMO cobro (desde_mes no puede ser posterior).
//     · «Mes a mes» / transferencia: anula los recibos sin pagar de esos meses
//       y natacion_recibos_generar ya no los crea.
//     · Enlace sin activar: solo se apunta (y no recibe «actívala»).
//   { accion: "reanudar", situacion_id } → quita la pausa de Stripe (si la hay)
//     y cierra la situación.
//
// Quién: natacion_cuotas_puede() (Mario, responsables de natación, admin),
// comprobado con el JWT de quien llama.
//
//   supabase functions deploy natacion-pausa --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";

const ORIGENES_OK = [
  "https://atletismoapolana.com", "https://www.atletismoapolana.com", "https://escuelaapolana.github.io",
  "http://localhost:8000", "http://127.0.0.1:8000", "http://localhost:8151",
];
const cors = (o: string | null) => ({
  "Access-Control-Allow-Origin": o && ORIGENES_OK.includes(o) ? o : ORIGENES_OK[0],
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS", "Vary": "Origin",
});
const responder = (d: unknown, s: number, o: string | null) =>
  new Response(JSON.stringify(d), { status: s, headers: { ...cors(o), "Content-Type": "application/json; charset=utf-8" } });

async function rest(ruta: string, init: RequestInit = {}, jwt?: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...init,
    headers: { apikey: jwt ? (ANON_KEY || SERVICE_KEY) : SERVICE_KEY, Authorization: `Bearer ${jwt ?? SERVICE_KEY}`,
      "Content-Type": "application/json", ...(init.headers ?? {}) },
  });
  const t = await r.text();
  let d: any = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, estado: r.status, datos: d };
}
async function stripe(metodo: "GET" | "POST", ruta: string, campos?: Record<string, string>) {
  const r = await fetch(`https://api.stripe.com/v1/${ruta}`, {
    method: metodo,
    headers: { Authorization: `Bearer ${STRIPE_KEY}`, ...(campos ? { "Content-Type": "application/x-www-form-urlencoded" } : {}) },
    body: campos ? new URLSearchParams(campos).toString() : undefined,
  });
  return { ok: r.ok, estado: r.status, datos: await r.json().catch(() => null) as any };
}
const ymdMadrid = (u: number) => new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(u * 1000));
const proximoDe = (s: any): number =>
  s?.status === "trialing" && Number(s.trial_end) > 0 ? Number(s.trial_end) : Number(s?.current_period_end ?? s?.items?.data?.[0]?.current_period_end ?? 0);
const MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
const mesTxt = (m: string) => { const [y, mm] = m.split("-").map(Number); return `${MESES[mm - 1]} de ${y}`; };
const TIPOS = ["baja_medica", "ausencia", "exencion", "rebaja", "transferencia", "otra"];

Deno.serve(async (req: Request) => {
  const o = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(o) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, o);
  if (o && !ORIGENES_OK.includes(o)) return responder({ error: "origen" }, 403, o);
  if (!SUPABASE_URL || !SERVICE_KEY || !STRIPE_KEY) return responder({ error: "config", mensaje: "No está configurado." }, 503, o);

  // 1 · Sesión y permiso (lo decide la base con el JWT de quien llama)
  const cab = req.headers.get("Authorization") ?? "";
  const jwt = cab.toLowerCase().startsWith("bearer ") ? cab.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sesion", mensaje: "Vuelve a entrar en la app." }, 401, o);
  const rU = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` } });
  if (!rU.ok) return responder({ error: "sesion", mensaje: "Vuelve a entrar en la app." }, 401, o);
  const correo = String((await rU.json().catch(() => null))?.email ?? "").toLowerCase();
  const rP = await rest("rpc/natacion_cuotas_puede", { method: "POST", body: "{}" }, jwt);
  if (!rP.ok || rP.datos !== true) return responder({ error: "permiso", mensaje: "Solo quien lleva la natación puede pausar cuotas." }, 403, o);
  const rN = await rest(`perfiles?select=nombre&email=eq.${encodeURIComponent(correo)}&limit=1`);
  const quien = String(rN.datos?.[0]?.nombre ?? "").trim() || correo;

  let b: Record<string, any> = {};
  try { b = await req.json(); } catch { /* vacío */ }
  const accion = String(b.accion ?? "");
  const hoy = ymdMadrid(Math.floor(Date.now() / 1000));
  const sello = `${hoy.slice(8, 10)}/${hoy.slice(5, 7)}/${hoy.slice(0, 4)}`;

  // ---------------- REANUDAR ----------------
  if (accion === "reanudar") {
    const rS = await rest(`natacion_situaciones?select=*&id=eq.${encodeURIComponent(String(b.situacion_id ?? ""))}&limit=1`);
    const sit = rS.datos?.[0];
    if (!sit || sit.estado !== "abierta") return responder({ error: "no_existe", mensaje: "Esa situación ya está cerrada." }, 404, o);
    if (sit.stripe_pausa && sit.cuota_id) {
      const rQ = await rest(`cuotas_entreno?select=stripe_subscription_id&id=eq.${sit.cuota_id}&limit=1`);
      const subId = rQ.datos?.[0]?.stripe_subscription_id;
      if (subId) {
        const u = await stripe("POST", `subscriptions/${encodeURIComponent(subId)}`, { pause_collection: "" });
        if (!u.ok) return responder({ error: "stripe", mensaje: u.datos?.error?.message ?? "Stripe no ha respondido." }, 502, o);
      }
    }
    const nota = String(b.nota ?? "").trim();
    await rest(`natacion_situaciones?id=eq.${sit.id}`, { method: "PATCH", headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ estado: "cerrada", cerrada_en: new Date().toISOString(), cierre_nota: `Reanudado el ${sello} por ${quien}${nota ? `: ${nota}` : ""}` }) });
    return responder({ ok: true, reanudada: true }, 200, o);
  }

  if (accion !== "pausar") return responder({ error: "accion", mensaje: "Acción no reconocida." }, 400, o);

  // ---------------- PAUSAR ----------------
  const atletaId = String(b.atleta_id ?? "");
  const tipo = String(b.tipo ?? "");
  const motivo = String(b.motivo ?? "").trim();
  const desde = String(b.desde_mes ?? "");
  const hasta = b.hasta_mes ? String(b.hasta_mes) : null;
  if (!atletaId || !TIPOS.includes(tipo) || !motivo) return responder({ error: "datos", mensaje: "Falta el tipo o el motivo." }, 400, o);
  if (!/^\d{4}-\d{2}$/.test(desde) || (hasta && !/^\d{4}-\d{2}$/.test(hasta))) return responder({ error: "datos", mensaje: "Los meses van como AAAA-MM." }, 400, o);
  if (hasta && hasta < desde) return responder({ error: "datos", mensaje: "El último mes sin cobrar no puede ser anterior al primero." }, 400, o);
  let revisar = b.revisar_el && /^\d{4}-\d{2}-\d{2}$/.test(String(b.revisar_el)) ? String(b.revisar_el) : null;
  if (!revisar && tipo === "baja_medica") { const d = new Date(`${hoy}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + 28); revisar = d.toISOString().slice(0, 10); }

  const rQ = await rest(`cuotas_entreno?select=id,metodo,suscripcion_estado,stripe_subscription_id,transferencia&origen=eq.natacion` +
    `&atleta_id=eq.${encodeURIComponent(atletaId)}&suscripcion_estado=neq.cancelada&order=created_at.desc&limit=1`);
  const q = rQ.datos?.[0];
  if (!q) return responder({ error: "sin_cuota", mensaje: "No tiene ninguna cuota viva que pausar. Si solo quieres apuntar la situación, usa «Apuntar sin pausar»." }, 409, o);

  let stripePausa = false, resumes: number | null = null, anulados = 0, detalle = "";
  if (q.stripe_subscription_id) {
    const g = await stripe("GET", `subscriptions/${encodeURIComponent(q.stripe_subscription_id)}`);
    const s = g.datos;
    if (!g.ok || !s || ["canceled", "incomplete_expired"].includes(String(s.status))) return responder({ error: "stripe", mensaje: "Su suscripción de Stripe no está viva." }, 409, o);
    if (s.pause_collection) return responder({ error: "ya", mensaje: "Esta cuota ya está en pausa en Stripe." }, 409, o);
    const prox = proximoDe(s);
    const mesProx = prox > 0 ? ymdMadrid(prox).slice(0, 7) : "";
    if (mesProx && desde > mesProx) {
      return responder({ error: "desde", mensaje: `Su próximo cobro es en ${mesTxt(mesProx)}: la pausa tiene que empezar ahí (pausar ya anula todos los cobros hasta reanudar).` }, 409, o);
    }
    const campos: Record<string, string> = { "pause_collection[behavior]": "void" };
    if (hasta) {
      const [hy, hm] = hasta.split("-").map(Number);
      resumes = Math.floor(Date.UTC(hm === 12 ? hy + 1 : hy, hm === 12 ? 0 : hm, 1, 0, 0, 0) / 1000);   // día 1 del mes siguiente
      campos["pause_collection[resumes_at]"] = String(resumes);
    }
    const u = await stripe("POST", `subscriptions/${encodeURIComponent(s.id)}`, campos);
    if (!u.ok) return responder({ error: "stripe", mensaje: u.datos?.error?.message ?? "Stripe no ha respondido." }, 502, o);
    stripePausa = true;
    detalle = hasta ? `Stripe no cobra hasta ${mesTxt(hasta)} incluido; vuelve a cobrar el día 5 del mes siguiente.` : "Stripe no cobra nada hasta que se reanude.";
  } else if (q.metodo === "mes_a_mes") {
    const rR = await rest(`pagos?select=id,periodo&cuota_entreno_id=eq.${q.id}&anulado=is.false&estado=neq.pagado`);
    for (const p of (Array.isArray(rR.datos) ? rR.datos : [])) {
      if (!p.periodo || p.periodo < desde || (hasta && p.periodo > hasta)) continue;
      const a = await rest(`pagos?id=eq.${p.id}&estado=neq.pagado`, { method: "PATCH", headers: { Prefer: "return=minimal" },
        body: JSON.stringify({ anulado: true, anulado_en: new Date().toISOString(), anulado_motivo: `Cuota en pausa (${tipo.replace("_", " ")}): ${motivo}` }) });
      if (a.ok) anulados++;
    }
    detalle = `No se crean los recibos de esos meses${anulados ? ` (anulados ${anulados} sin pagar)` : ""}.`;
  } else {
    detalle = "El enlace no estaba activado: solo queda apuntado (no le llegará «actívala»).";
  }

  const ins = await rest("natacion_situaciones", { method: "POST", headers: { Prefer: "return=representation" }, body: JSON.stringify({
    atleta_id: atletaId, cuota_id: q.id, tipo, motivo, revisar_el: revisar, guarda_plaza: b.guarda_plaza !== false,
    sin_cobro: true, cobro_desde: `${desde}-01`, cobro_hasta: hasta ? `${hasta}-01` : null,
    stripe_pausa: stripePausa, stripe_resumes_at: resumes ? new Date(resumes * 1000).toISOString() : null, creado_por: quien,
  }) });
  if (!ins.ok) {
    console.error("[natacion-pausa] no se pudo apuntar:", JSON.stringify(ins.datos));
    return responder({ error: "base", mensaje: `La pausa ${stripePausa ? "está hecha en Stripe" : "está hecha"}, pero no se ha podido apuntar. Avisa a Andrés.` }, 500, o);
  }
  console.log("[natacion-pausa]", quien, atletaId, tipo, desde, hasta, detalle);
  return responder({ ok: true, situacion_id: ins.datos?.[0]?.id, detalle }, 200, o);
});
