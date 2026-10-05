// ============================================================
// stripe-payout-export · desglose de los PAYOUTS de Stripe (Apolana) para
// cuadrar con el banco / pasarle a Isa qué incluye cada transferencia.
//
//   · POST con JWT de admin/staff.
//   · body { accion:'lista' }            -> últimos payouts (id, importe, fecha, estado)
//   · body { accion:'detalle', payout }  -> cargos del payout, ENRIQUECIDOS con
//        los datos de quien paga (nombre, apellidos, tel, correo, DNI) cruzando
//        con cubo_altas (por customer de Stripe) y atletas (por correo).
//
//   Usa STRIPE_SECRET_KEY_APOLANA (live) y la service key para leer la base.
//   supabase functions deploy stripe-payout-export --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const STRIPE_KEY = (Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "").trim();

function cors(origen: string | null): Record<string, string> {
  const permitidos = (Deno.env.get("PAGOS_ORIGENES") ?? Deno.env.get("CORREO_ORIGENES") ?? "")
    .split(",").map((s) => s.trim()).filter(Boolean);
  const valor = permitidos.length ? (origen && permitidos.includes(origen) ? origen : permitidos[0]) : (origen ?? "*");
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
async function esAdminStaff(jwt: string): Promise<boolean> {
  for (const rpc of ["es_admin", "es_staff"]) {
    try {
      const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
        method: "POST",
        headers: { apikey: ANON_KEY, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
        body: "{}",
      });
      if (r.ok && (await r.json()) === true) return true;
    } catch { /* sigue */ }
  }
  return false;
}
async function stripe(path: string): Promise<any> {
  const r = await fetch(`https://api.stripe.com/v1/${path}`, { headers: { Authorization: `Bearer ${STRIPE_KEY}` } });
  const d = await r.json();
  if (!r.ok) throw new Error(d?.error?.message || "Stripe error");
  return d;
}
async function db(ruta: string): Promise<any[]> {
  try {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    return r.ok ? await r.json() : [];
  } catch { return []; }
}
const eur = (cent: number) => Math.round(cent) / 100;
const fISO = (unix: number) => unix ? new Date(unix * 1000).toISOString().slice(0, 10) : null;

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, origen);
  if (!STRIPE_KEY) return responder({ ok: false, msg: "Falta la clave de Stripe." }, 503, origen);

  const cab = req.headers.get("Authorization") ?? "";
  const jwt = cab.toLowerCase().startsWith("bearer ") ? cab.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sin_sesion" }, 401, origen);
  if (!(await esAdminStaff(jwt))) return responder({ error: "sin_permiso", msg: "Solo administración." }, 403, origen);

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { /* vacío */ }
  const accion = String(body.accion ?? "lista");

  try {
    if (accion === "lista") {
      const d = await stripe("payouts?limit=24");
      const payouts = (d.data ?? []).map((p: any) => ({
        id: p.id, importe: eur(p.amount), moneda: (p.currency ?? "eur").toUpperCase(),
        estado: p.status, fecha_llegada: fISO(p.arrival_date), creado: fISO(p.created), banco: p.destination || null,
      }));
      return responder({ ok: true, payouts }, 200, origen);
    }

    if (accion === "detalle") {
      const payout = String(body.payout ?? "");
      if (!/^po_/.test(payout)) return responder({ ok: false, msg: "Payout no válido." }, 400, origen);

      const po = await stripe(`payouts/${payout}`).catch(() => null);
      const fechaLlegada = po ? fISO(po.arrival_date) : null;

      const d = await stripe(`balance_transactions?payout=${payout}&limit=100&expand[]=data.source`);
      const txns = (d.data ?? []).filter((t: any) => t.type !== "payout");

      // Recoger clientes y correos para cruzar con la base
      const customers = new Set<string>(), emails = new Set<string>();
      for (const t of txns) {
        const s = t.source || {};
        if (typeof s.customer === "string") customers.add(s.customer);
        const em = (s.billing_details?.email || s.receipt_email || "").toLowerCase().trim();
        if (em) emails.add(em);
      }
      // Cruce: Cubo (por customer de Stripe) y atletas (por correo)
      const porCustomer: Record<string, any> = {}, porEmail: Record<string, any> = {};
      if (customers.size) {
        const list = [...customers].map((c) => `"${c}"`).join(",");
        const rows = await db(`cubo_altas?select=nombre,apellidos,telefono,email,dni,horario,stripe_customer_id&stripe_customer_id=in.(${list})`);
        for (const r of rows) if (r.stripe_customer_id) porCustomer[r.stripe_customer_id] = r;
      }
      if (emails.size) {
        const list = [...emails].map((e) => `"${e}"`).join(",");
        const rows = await db(`atletas?select=nombre,apellidos,telefono,email,dni&email=in.(${list})`);
        for (const r of rows) if (r.email) porEmail[String(r.email).toLowerCase().trim()] = r;
      }

      const lineas: any[] = [];
      let bruto = 0, comision = 0, neto = 0;
      for (const t of txns) {
        const s = t.source || {};
        const bd = s.billing_details || {};
        const em = (bd.email || s.receipt_email || "").toLowerCase().trim();
        const m = (typeof s.customer === "string" && porCustomer[s.customer]) || (em && porEmail[em]) || null;
        const nombre = m ? [m.nombre, m.apellidos].filter(Boolean).join(" ").trim() : (bd.name || "");
        const concepto = s.description || s.calculated_statement_descriptor || t.description || t.type;
        lineas.push({
          importe: eur(t.amount), comision: eur(t.fee), neto: eur(t.net),
          concepto,
          nombre: nombre || "—",
          telefono: (m && m.telefono) || bd.phone || "",
          email: (m && m.email) || bd.email || s.receipt_email || "",
          dni: (m && m.dni) || "",
          seccion: (m && m.horario) || "",
          fecha_cargo: fISO(t.created),
          fecha_llegada: fechaLlegada,
          tipo: t.type,
        });
        bruto += t.amount; comision += t.fee; neto += t.net;
      }
      return responder({
        ok: true, payout, fecha_llegada: fechaLlegada,
        totales: { importe: eur(bruto), comision: eur(comision), neto: eur(neto), lineas: lineas.length },
        lineas,
      }, 200, origen);
    }

    return responder({ ok: false, msg: "Acción no válida." }, 400, origen);
  } catch (e) {
    return responder({ ok: false, msg: String((e as Error).message || e) }, 200, origen);
  }
});
