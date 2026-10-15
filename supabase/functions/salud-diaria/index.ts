// ============================================================
// salud-diaria · «avisarte cuando algo se rompe» (mig 391)
// ------------------------------------------------------------
// La llama pg_cron cada mañana (7:30 de Madrid) con la cabecera
// `x-cron-secret`. Comprueba cosas reales y baratas SIN crear datos:
//
//   1. La base (RPC `salud_comprobar`, service_role): los formularios
//      públicos simulados de verdad y deshechos (socio, escuela, Cubo, fuerza
//      gratis, entrenador, tienda, prueba de pista, acceso por enlace), los
//      permisos de las funciones que usa la web/app, los pagos (modo real,
//      cobros que el webhook no ha anotado, SEPA «en camino» > 10 días, silencio
//      de Stripe) y si la re-sincronización de cuotas de las 7:00 fue bien.
//   2. Que las Edge de los formularios y los webhooks ARRANCAN (una petición
//      OPTIONS/GET que no hace nada: si una función no despliega o revienta al
//      cargar, da 5xx/404).
//   3. Brevo: la clave sirve (GET /v3/account).
//   4. Stripe (Apolana): la clave sirve y es la de verdad (live), y los
//      webhooks hacia Supabase están activados.
//
// Si TODO está bien, no manda nada: solo deja una fila en `salud_registro`.
// Si algo falla, manda UN correo con el diseño del club a Andrés.
//
// body opcional: { "probar_correo": true } → manda el correo aunque todo esté
// bien (para comprobar que llega). Sin el secreto no se puede llamar.
//
// CLAVES (secretos de Supabase): CRON_SECRET / SUPABASE_URL /
//   SUPABASE_SERVICE_ROLE_KEY / BREVO_API_KEY / CORREO_REMITENTE /
//   CORREO_REMITENTE_NOMBRE / CORREO_RESPUESTAS (o CORREO_SALUD) /
//   STRIPE_SECRET_KEY_APOLANA
//
// DESPLIEGUE:
//   supabase functions deploy salud-diaria --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const CRON_SECRET = (Deno.env.get("CRON_SECRET") ?? "").trim();
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const DESTINO = (Deno.env.get("CORREO_SALUD") ?? Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const STRIPE_KEY = (Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "").trim();

type Fallo = { clave: string; titulo: string; donde: string; detalle: string };

function json(cuerpo: unknown, estado = 200): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}
function iguales(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a);
  const eb = new TextEncoder().encode(b);
  let dif = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) dif |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return dif === 0;
}
function esc(s: unknown): string {
  return String(s ?? "").replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m] as string));
}
type Op = Omit<RequestInit, "headers"> & { headers?: Record<string, string> };
async function rest(ruta: string, op: Op = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...op,
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", ...(op.headers ?? {}) },
    signal: AbortSignal.timeout(60000),
  });
  const t = await r.text();
  let d: unknown = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, estado: r.status, datos: d as any };
}

// ---- 1 · La base ------------------------------------------------------------
async function comprobarBase(): Promise<{ fallos: Fallo[]; notas: string[]; comprobado: string[] }> {
  try {
    const r = await rest("rpc/salud_comprobar", { method: "POST", body: "{}" });
    if (!r.ok || !r.datos || typeof r.datos !== "object") {
      return {
        fallos: [{ clave: "salud:rpc", titulo: "La comprobación de la base no responde",
          donde: "salud_comprobar() (¿migración 391 aplicada?)",
          detalle: `HTTP ${r.estado} · ${String(typeof r.datos === "string" ? r.datos : JSON.stringify(r.datos)).slice(0, 300)}` }],
        notas: [], comprobado: [],
      };
    }
    return {
      fallos: Array.isArray(r.datos.fallos) ? r.datos.fallos : [],
      notas: Array.isArray(r.datos.notas) ? r.datos.notas : [],
      comprobado: Array.isArray(r.datos.comprobado) ? r.datos.comprobado : [],
    };
  } catch (e) {
    return {
      fallos: [{ clave: "salud:rpc", titulo: "La comprobación de la base no responde", donde: "salud_comprobar()",
        detalle: String((e as Error)?.message ?? e) }],
      notas: [], comprobado: [],
    };
  }
}

// ---- 2 · Las Edge arrancan --------------------------------------------------
// OPTIONS a las de formularios (contestan «ok» sin hacer nada) y GET a los
// webhooks (contestan 405 sin hacer nada). 5xx o 404 = rota / sin desplegar.
const EDGES: Array<{ fn: string; metodo: "OPTIONS" | "GET"; donde: string }> = [
  { fn: "cubo-alta", metodo: "OPTIONS", donde: "Web · Apuntarse al Cubo (/cubo/apuntarse/)" },
  { fn: "cubo-prueba-alta", metodo: "OPTIONS", donde: "Web · Fuerza gratis (/cubo/fuerza-gratis/)" },
  { fn: "entrenador-alta", metodo: "OPTIONS", donde: "Web · Alta de entrenador (/entrenador/alta/)" },
  { fn: "tienda-pagar", metodo: "OPTIONS", donde: "Web · Tienda (/tienda/)" },
  { fn: "pista-prueba", metodo: "OPTIONS", donde: "Web · Probar en pista (/pista/probar/)" },
  { fn: "acceso-enlace", metodo: "OPTIONS", donde: "App · Pantalla de acceso (enlace por correo)" },
  { fn: "socio-cuenta", metodo: "OPTIONS", donde: "Web · Hazte socio (crear la cuenta)" },
  { fn: "socio-pagar", metodo: "OPTIONS", donde: "Web · Hazte socio (pago de la primera cuota)" },
  { fn: "entreno-resync", metodo: "OPTIONS", donde: "Panel · Cuotas de entreno (Re-sincronizar)" },
  { fn: "cubo-webhook", metodo: "GET", donde: "Cobros del Cubo, cuotas de entreno y recibos (aviso de Stripe)" },
  { fn: "pago-webhook", metodo: "GET", donde: "Pagos con tarjeta de la tienda/bonos (aviso de Stripe)" },
];
async function comprobarEdges(): Promise<{ fallos: Fallo[]; estados: Record<string, number | string> }> {
  const estados: Record<string, number | string> = {};
  const fallos: Fallo[] = [];
  await Promise.all(EDGES.map(async (e) => {
    try {
      const r = await fetch(`${SUPABASE_URL}/functions/v1/${e.fn}`, {
        method: e.metodo,
        headers: e.metodo === "OPTIONS"
          ? { Origin: "https://atletismoapolana.com", "Access-Control-Request-Method": "POST" }
          : {},
        signal: AbortSignal.timeout(20000),
      });
      await r.body?.cancel();
      estados[e.fn] = r.status;
      if (r.status >= 500 || r.status === 404) {
        fallos.push({ clave: `edge:${e.fn}`, titulo: `La función ${e.fn} no responde (HTTP ${r.status})`,
          donde: e.donde, detalle: r.status === 404 ? "No está desplegada" : "Falla al arrancar o al contestar" });
      }
    } catch (err) {
      estados[e.fn] = "error";
      fallos.push({ clave: `edge:${e.fn}`, titulo: `La función ${e.fn} no responde`, donde: e.donde,
        detalle: String((err as Error)?.message ?? err).slice(0, 200) });
    }
  }));
  return { fallos, estados };
}

// ---- 3 · Brevo --------------------------------------------------------------
const DONDE_CORREO = "Todos los correos automáticos (acuses de altas, avisos, recibos, enlaces)";
async function comprobarBrevo(): Promise<Fallo[]> {
  if (!BREVO_API_KEY) return [{ clave: "correo:brevo", titulo: "Falta la clave de Brevo (BREVO_API_KEY)", donde: DONDE_CORREO, detalle: "Secreto vacío en Supabase" }];
  try {
    const r = await fetch("https://api.brevo.com/v3/account", {
      headers: { "api-key": BREVO_API_KEY, accept: "application/json" },
      signal: AbortSignal.timeout(20000),
    });
    const t = await r.text().catch(() => "");
    if (r.status === 401 || r.status === 403) {
      return [{ clave: "correo:brevo", titulo: "La clave de Brevo ya no sirve", donde: DONDE_CORREO, detalle: `HTTP ${r.status} · ${t.slice(0, 200)}` }];
    }
    if (!r.ok) return [{ clave: "correo:brevo", titulo: `Brevo responde con error (HTTP ${r.status})`, donde: DONDE_CORREO, detalle: t.slice(0, 200) }];
    return [];
  } catch (e) {
    return [{ clave: "correo:brevo", titulo: "No se puede hablar con Brevo", donde: DONDE_CORREO, detalle: String((e as Error)?.message ?? e).slice(0, 200) }];
  }
}

// ---- 4 · Stripe (cuenta de Apolana) ----------------------------------------
const DONDE_PAGOS = "Todos los cobros con tarjeta/SEPA de Apolana (Cubo, alta de socio, cuotas, recibos)";
async function comprobarStripe(modo: string | null): Promise<{ fallos: Fallo[]; notas: string[] }> {
  const fallos: Fallo[] = [];
  const notas: string[] = [];
  if (!STRIPE_KEY) {
    fallos.push({ clave: "stripe:clave", titulo: "Falta la clave de Stripe de Apolana", donde: DONDE_PAGOS, detalle: "STRIPE_SECRET_KEY_APOLANA vacío" });
    return { fallos, notas };
  }
  if (modo === "real" && !/^(sk|rk)_live_/.test(STRIPE_KEY)) {
    fallos.push({ clave: "stripe:live", titulo: "Los pagos están en modo real pero la clave de Stripe no es la de verdad",
      donde: DONDE_PAGOS, detalle: "STRIPE_SECRET_KEY_APOLANA no empieza por sk_live_/rk_live_" });
  }
  const get = (ruta: string) => fetch(`https://api.stripe.com/v1/${ruta}`, {
    headers: { Authorization: `Bearer ${STRIPE_KEY}` }, signal: AbortSignal.timeout(20000),
  });
  try {
    const rB = await get("balance");
    await rB.body?.cancel();
    if (rB.status === 401) {
      fallos.push({ clave: "stripe:clave", titulo: "La clave de Stripe de Apolana ya no sirve", donde: DONDE_PAGOS, detalle: "HTTP 401 en /v1/balance" });
      return { fallos, notas };
    }
    if (!rB.ok && rB.status !== 403) {
      fallos.push({ clave: "stripe:api", titulo: `Stripe responde con error (HTTP ${rB.status})`, donde: DONDE_PAGOS, detalle: "/v1/balance" });
    }
    const rW = await get("webhook_endpoints?limit=100");
    if (rW.status === 403) {
      await rW.body?.cancel();
      notas.push("La clave de Stripe no deja leer los webhooks (clave restringida): no se ha comprobado.");
    } else if (rW.ok) {
      const d = await rW.json().catch(() => null);
      const lista: Array<{ url?: string; status?: string }> = Array.isArray(d?.data) ? d.data : [];
      const nuestros = lista.filter((w) => String(w.url ?? "").includes("/functions/v1/"));
      if (!nuestros.length) {
        fallos.push({ clave: "stripe:webhooks", titulo: "Stripe no tiene ningún webhook hacia Supabase",
          donde: "Los pagos no se marcarían como pagados solos", detalle: `${lista.length} endpoint(s) en la cuenta, ninguno a /functions/v1/` });
      }
      for (const w of nuestros) {
        if (w.status !== "enabled") {
          fallos.push({ clave: `stripe:webhook:${w.url}`, titulo: "Un webhook de Stripe está desactivado",
            donde: "Los pagos no se marcan como pagados solos", detalle: `${w.url} · estado: ${w.status}` });
        }
      }
      notas.push(`Webhooks de Stripe hacia Supabase: ${nuestros.map((w) => `${String(w.url).split("/functions/v1/")[1]} (${w.status})`).join(", ") || "ninguno"}`);
    } else {
      await rW.body?.cancel();
      fallos.push({ clave: "stripe:api", titulo: `Stripe responde con error (HTTP ${rW.status})`, donde: DONDE_PAGOS, detalle: "/v1/webhook_endpoints" });
    }
  } catch (e) {
    fallos.push({ clave: "stripe:red", titulo: "No se puede hablar con Stripe", donde: DONDE_PAGOS, detalle: String((e as Error)?.message ?? e).slice(0, 200) });
  }
  return { fallos, notas };
}

// ---- Correo -----------------------------------------------------------------
function correoHtml(fallos: Fallo[], notas: string[], comprobado: string[], prueba: boolean): string {
  const fecha = new Intl.DateTimeFormat("es-ES", { timeZone: "Europe/Madrid", weekday: "long", day: "numeric", month: "long" }).format(new Date());
  const filas = fallos.length
    ? fallos.map((f) => `
          <tr><td style="padding:12px 16px;border-bottom:1px solid #e7dcc4;font-size:14px;line-height:1.5">
            <b style="color:#26374B">${esc(f.titulo)}</b><br>
            <span style="color:#3f3f46">Dónde se nota: <b>${esc(f.donde)}</b></span><br>
            <span style="color:#8a5a00;font-size:12.5px">${esc(f.detalle)}</span>
          </td></tr>`).join("")
    : `<tr><td style="padding:12px 16px;font-size:14px;color:#1f6f3f"><b>Todo bien.</b> (Correo de prueba: lo has pedido con «probar_correo».)</td></tr>`;
  const titular = fallos.length
    ? (fallos.length === 1 ? "Esta mañana hay 1 cosa que no va bien" : `Esta mañana hay ${fallos.length} cosas que no van bien`)
    : "Prueba del aviso diario";
  const notasHtml = notas.length
    ? `<p style="margin:14px 0 0;color:#71717a;font-size:12.5px;line-height:1.5">${notas.map(esc).join("<br>")}</p>` : "";
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Revisión de la mañana</td></tr>
      <tr><td style="padding:22px 24px 6px 24px">
        <p style="margin:0 0 6px;font-size:17px;font-weight:700;color:#26374B">${esc(titular)}</p>
        <p style="margin:0;color:#71717a;font-size:13px">${esc(fecha)}${prueba ? " · correo de prueba" : ""}</p>
      </td></tr>
      <tr><td style="padding:12px 24px 8px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">${filas}
        </table>
      </td></tr>
      <tr><td style="padding:4px 24px 24px 24px">
        <p style="margin:10px 0 0;color:#52525b;font-size:13px;line-height:1.5">Se ha comprobado: formularios públicos (simulados y deshechos, sin crear nada), permisos de la app, pagos, Stripe, Brevo y las funciones del servidor. Si todo va bien, no llega ningún correo.</p>
        ${notasHtml}
        <p style="margin:12px 0 0;color:#a1a1aa;font-size:11.5px">${esc(comprobado.join(" · "))}</p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;
}
async function enviarCorreo(fallos: Fallo[], notas: string[], comprobado: string[], prueba: boolean): Promise<boolean> {
  if (!BREVO_API_KEY) return false;
  const asunto = fallos.length
    ? `Algo no va bien en la web · ${fallos.length} aviso${fallos.length === 1 ? "" : "s"} · Apolana`
    : "Prueba · revisión de la mañana · Apolana";
  const texto = (fallos.length ? fallos.map((f) => `- ${f.titulo}\n  Dónde se nota: ${f.donde}\n  ${f.detalle}`).join("\n\n") : "Todo bien (correo de prueba).") +
    (notas.length ? `\n\n${notas.join("\n")}` : "");
  try {
    const r = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        to: [{ email: DESTINO }],
        subject: asunto,
        htmlContent: correoHtml(fallos, notas, comprobado, prueba),
        textContent: texto,
      }),
      signal: AbortSignal.timeout(20000),
    });
    if (!r.ok) console.error("[salud-diaria] Brevo:", r.status, await r.text().catch(() => ""));
    return r.ok;
  } catch (e) {
    console.error("[salud-diaria] correo:", e);
    return false;
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ error: "metodo" }, 405);
  if (!SUPABASE_URL || !SERVICE_KEY || !CRON_SECRET) return json({ error: "config" }, 503);
  const secreto = (req.headers.get("x-cron-secret") ?? "").trim();
  if (!secreto || !iguales(secreto, CRON_SECRET)) return json({ error: "secreto" }, 401);

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const probarCorreo = cuerpo.probar_correo === true;
  const inicio = Date.now();

  const rCfg = await rest("pagos_config?select=modo&id=eq.1&limit=1").catch(() => null);
  const modo: string | null = Array.isArray(rCfg?.datos) && rCfg!.datos[0] ? String(rCfg!.datos[0].modo) : null;

  const [base, edges, brevo, stripe] = await Promise.all([
    comprobarBase(), comprobarEdges(), comprobarBrevo(), comprobarStripe(modo),
  ]);
  const fallos: Fallo[] = [...base.fallos, ...edges.fallos, ...brevo, ...stripe.fallos];
  const notas: string[] = [...base.notas, ...stripe.notas];
  const comprobado = [...base.comprobado, "edges", "brevo", "stripe"];
  const ok = fallos.length === 0;

  let correoEnviado = false;
  if (!ok || probarCorreo) correoEnviado = await enviarCorreo(fallos, notas, comprobado, probarCorreo && ok);

  await rest("salud_registro", {
    method: "POST",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify({
      ok, fallos, correo_enviado: correoEnviado, origen: probarCorreo ? "prueba" : "cron",
      detalle: { notas, comprobado, edges: edges.estados, modo_pagos: modo, duracion_ms: Date.now() - inicio },
    }),
  }).catch((e) => console.error("[salud-diaria] registro:", e));
  // Limpieza: un año de historial es de sobra.
  const haceUnAno = new Date(Date.now() - 365 * 86400000).toISOString();
  await rest(`salud_registro?creado_en=lt.${encodeURIComponent(haceUnAno)}`, { method: "DELETE", headers: { Prefer: "return=minimal" } })
    .catch(() => null);

  return json({ ok, fallos, notas, correo_enviado: correoEnviado, edges: edges.estados });
});
