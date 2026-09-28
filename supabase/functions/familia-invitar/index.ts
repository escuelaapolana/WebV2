// ============================================================
// familia-invitar · manda a cada familia de escuela de natación su
// correo con el enlace de acceso + los horarios de sus hijos.
// ------------------------------------------------------------
// QUÉ HACE
//   modo "prueba": arma un correo de MUESTRA (con datos reales de una
//     familia con N hijos, pero enlace de demostración que no hace nada)
//     y lo manda a la dirección que le digas. Para verlo antes de lanzar.
//   modo "real": recorre TODAS las familias (familias_para_invitar) y a
//     cada una le manda su correo con SU enlace y SUS hijos. Requiere
//     confirmar:true para que no se dispare sin querer.
//
// LO QUE NO SE FÍA DEL NAVEGADOR
//   · Quién llama: JWT contra Supabase + es_admin(). Nadie más envía.
//   · A quién y con qué datos: todo se lee de la base con la llave de
//     servicio (RPC familias_para_invitar). El cuerpo solo elige modo,
//     destino de prueba y nº de hijos de la muestra.
//
// CLAVES (ninguna vive aquí): BREVO_API_KEY, y opcionalmente
//   CORREO_NATACION / CORREO_NATACION_NOMBRE / CORREO_URL_BASE.
//
// Deploy: supabase functions deploy familia-invitar --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";

const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_NATACION") ?? "natacion@atletismoapolana.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_NATACION_NOMBRE") ?? "Escuela de Natación · Apolana").trim();
const URL_BASE = (Deno.env.get("CORREO_URL_BASE") ?? "https://atletismoapolana.com/")
  .replace(/\/*$/, "/");

const DIAS: Record<number, string> = {
  1: "Lunes", 2: "Martes", 3: "Miércoles", 4: "Jueves", 5: "Viernes", 6: "Sábado", 7: "Domingo",
};

function cors(origen: string | null): Record<string, string> {
  const permitidos = (Deno.env.get("CORREO_ORIGENES") ?? Deno.env.get("PAGOS_ORIGENES") ?? "")
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

// Preguntar a la base COMO EL USUARIO (con su JWT) si es admin.
async function comoUsuario(rpc: string, jwt: string): Promise<boolean> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: "POST",
    headers: {
      apikey: ANON_KEY || SERVICE_KEY,
      Authorization: `Bearer ${jwt}`,
      "Content-Type": "application/json",
    },
    body: "{}",
  });
  if (!r.ok) return false;
  try { return (await r.json()) === true; } catch { return false; }
}

// Llamar a un RPC con la llave de servicio (leer datos de todas las familias).
async function rpcServicio(rpc: string, body: unknown): Promise<unknown> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body ?? {}),
  });
  const t = await r.text();
  try { return t ? JSON.parse(t) : null; } catch { return t; }
}

// "AREEJ AHMED" -> "Areej Ahmed"
function tituloCase(s: string): string {
  return String(s || "").toLowerCase().replace(/(^|[\s'-])([\p{L}])/gu, (_m, p, c) => p + c.toUpperCase());
}

type Franja = { dia: number; hora: string; nivel: string };
type Hijo = { nombre: string; franjas: Franja[] };

// [{dia,hora,nivel}] -> ["Lunes y Miércoles · 18:30 · Iniciación", ...]
function lineasFranjas(franjas: Franja[]): string[] {
  const grupos = new Map<string, { hora: string; nivel: string; dias: number[] }>();
  for (const f of (franjas || [])) {
    const clave = `${f.hora}|${f.nivel}`;
    if (!grupos.has(clave)) grupos.set(clave, { hora: f.hora, nivel: f.nivel, dias: [] });
    grupos.get(clave)!.dias.push(f.dia);
  }
  const salida: string[] = [];
  for (const g of grupos.values()) {
    const dias = [...new Set(g.dias)].sort((a, b) => a - b).map((d) => DIAS[d] ?? `Día ${d}`);
    let etiqDias = "";
    if (dias.length === 1) etiqDias = dias[0];
    else etiqDias = dias.slice(0, -1).join(", ") + " y " + dias[dias.length - 1];
    const partes = [etiqDias, g.hora];
    if (g.nivel) partes.push(g.nivel);
    salida.push(partes.join(" · "));
  }
  return salida;
}

function bloqueHijos(hijos: Hijo[]): string {
  const items = (hijos || []).map((h) => {
    const lineas = lineasFranjas(h.franjas)
      .map((l) => `<div style="color:#334155;font-size:14px;line-height:1.5">🏊 ${l}</div>`)
      .join("");
    return `<div style="padding:12px 14px;border:1px solid #e2e8f0;border-radius:12px;margin:0 0 10px;background:#f8fafc">
        <div style="font-weight:700;color:#0f172a;font-size:15px;margin:0 0 4px">${tituloCase(h.nombre)}</div>
        ${lineas || '<div style="color:#64748b;font-size:14px">Horario por confirmar</div>'}
      </div>`;
  }).join("");
  return items;
}

function notaYaTiene(): string {
  return `<div style="margin:0 0 18px;padding:12px 14px;background:#eef7f7;border:1px solid #b9e0e0;border-radius:12px;color:#0e5b5b;font-size:14px;line-height:1.5">
    💪 <b>Ya tienes cuenta en el club</b> (entrenas con nosotros). Entra con <b>tu correo de siempre</b> y crea o actualiza tu contraseña desde el botón. Una vez dentro, toca <b>tu nombre arriba</b> para cambiar entre tu vista y la de tu familia.
  </div>`;
}

function correoHtml(hijos: Hijo[], enlace: string, yaTiene = false): string {
  return `<!doctype html><html lang="es"><body style="margin:0;background:#eef2f5;padding:24px 12px;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#0f172a">
    <div style="max-width:540px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;border:1px solid #e2e8f0">
      <div style="background:#0e2a47;color:#fff;padding:22px 24px">
        <div style="font-size:13px;letter-spacing:.5px;opacity:.85;text-transform:uppercase">Escuela de Natación</div>
        <div style="font-size:20px;font-weight:800;margin-top:2px">Club Atletismo Apolana</div>
      </div>
      <div style="padding:24px">
        <p style="margin:0 0 12px;font-size:16px">¡Hola! 👋</p>
        <p style="margin:0 0 18px;color:#334155;line-height:1.55">Ya puedes entrar a la <b>Web y App del club</b> para llevar la natación de tu familia desde el móvil. Solo tienes que pulsar el botón y crear tu contraseña.</p>
        <p style="margin:0 0 18px;text-align:center">
          <a href="${enlace}" style="display:inline-block;background:#12a3a3;color:#fff;text-decoration:none;padding:14px 26px;border-radius:12px;font-weight:700;font-size:16px">Entrar y crear mi contraseña</a>
        </p>
        ${yaTiene ? notaYaTiene() : ""}
        <p style="margin:0 0 8px;font-weight:700;color:#0f172a">Con tu acceso vas a poder:</p>
        <ul style="margin:0 0 22px;padding-left:20px;color:#334155;line-height:1.7">
          <li>Ver los <b>horarios y el grupo</b> de cada hijo/a.</li>
          <li>Avisar fácil si <b>algún día no puede venir</b>.</li>
          <li>Ver y actualizar sus <b>datos de contacto</b>.</li>
          <li>Estar al día de los <b>avisos del club</b>.</li>
          <li>Curiosear <b>todo lo que ofrece el club</b> (otras escuelas y secciones).</li>
        </ul>
        <p style="margin:0 0 8px;font-weight:700;color:#0f172a">En tu familia:</p>
        ${bloqueHijos(hijos)}
        <div style="margin:18px 0 4px;padding:12px 14px;background:#fff7ed;border:1px solid #fed7aa;border-radius:12px;color:#7c2d12;font-size:14px;line-height:1.5">
          💳 Las <b>mensualidades se siguen pagando por SportMember</b>, igual que hasta ahora. Este acceso es solo para la parte de horarios e información del club.
        </div>
        <p style="margin:18px 0 0;color:#334155;line-height:1.55">Cualquier duda, por el <b>WhatsApp de siempre</b>. ¡Nos vemos en el agua! 🏊</p>
        <p style="margin:16px 0 0;color:#0f172a;font-weight:700">Escuela de Natación · Club Atletismo Apolana</p>
      </div>
      <div style="padding:14px 24px;background:#f8fafc;border-top:1px solid #e2e8f0;color:#94a3b8;font-size:12px;line-height:1.5">
        Recibes este correo porque tu hijo/a está en la escuela de natación del club. Si no reconoces este mensaje, puedes ignorarlo.
      </div>
    </div>
  </body></html>`;
}

function textoPlano(hijos: Hijo[], enlace: string): string {
  const l = (hijos || []).map((h) =>
    `- ${tituloCase(h.nombre)}\n  ${lineasFranjas(h.franjas).join("\n  ")}`).join("\n");
  return `¡Hola!\n\nYa puedes entrar a la Web y App del Club Apolana para llevar la natación de tu familia.\n\nEntra y crea tu contraseña: ${enlace}\n\nEn tu familia:\n${l}\n\nLas mensualidades se siguen pagando por SportMember, igual que hasta ahora.\n\nEscuela de Natación · Club Atletismo Apolana`;
}

async function enviarBrevo(destino: string, hijos: Hijo[], enlace: string, asunto: string, yaTiene = false) {
  const r = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({
      sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
      to: [{ email: destino }],
      subject: asunto,
      htmlContent: correoHtml(hijos, enlace, yaTiene),
      textContent: textoPlano(hijos, enlace),
    }),
  });
  if (r.ok) return { ok: true };
  let datos: unknown = null;
  try { datos = await r.json(); } catch { /* */ }
  return { ok: false, estado: r.status, brevo: datos };
}

type FilaFamilia = { email: string; token: string | null; hijos: Hijo[]; ya_tiene_cuenta: boolean; invitado_en?: string | null };

// Deja sellado en la base que a esta familia YA se le mandó (por token, único).
// Así un reintento no vuelve a escribirle: es idempotente.
async function sellarInvitado(token: string): Promise<void> {
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/familia_invitaciones?token=eq.${encodeURIComponent(token)}`, {
      method: "PATCH",
      headers: {
        apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
        "Content-Type": "application/json", Prefer: "return=minimal",
      },
      body: JSON.stringify({ invitado_en: new Date().toISOString() }),
    });
  } catch (_e) { /* si falla el sello, peor es no enviar; el reintento lo pilla luego */ }
}

// Pregunta a Brevo a QUIÉN se le ha enviado un correo HOY (por si un intento
// anterior mandó a algunas antes de "cortarse"). Usa el endpoint de EVENTOS,
// que sí lista los envíos recientes con su destinatario. Devuelve el conjunto
// de correos (minúsculas), cuántos eventos vio (diagnóstico) y si Brevo contestó.
async function yaEnviadosBrevo(): Promise<{ set: Set<string>; rebotados: Set<string>; raw: number; ok: boolean }> {
  const set = new Set<string>();
  const rebotados = new Set<string>();
  let raw = 0, ok = false;
  try {
    // days=1 = hoy (no compatible con startDate/endDate). Traemos todos los eventos.
    const url = `https://api.brevo.com/v3/smtp/statistics/events?days=1&limit=2500&sort=desc`;
    const r = await fetch(url, { headers: { "api-key": BREVO_API_KEY, accept: "application/json" } });
    if (!r.ok) return { set, rebotados, raw, ok };
    ok = true;
    const d = await r.json();
    const arr = (d?.events ?? []) as Array<Record<string, unknown>>;
    raw = arr.length;
    for (const e of arr) {
      const to = String(e?.email ?? "").toLowerCase().trim();
      if (!to) continue;
      const subj = String(e?.subject ?? "");
      if (subj.startsWith("[PRUEBA")) continue; // no contar las pruebas
      set.add(to);
      const ev = String(e?.event ?? "").toLowerCase();
      if (ev.includes("bounce") || ev === "blocked" || ev === "invalid" || ev === "error" || ev === "spam") {
        rebotados.add(to);
      }
    }
  } catch (_e) { /* sin reconciliación; nos quedamos con lo que diga invitado_en */ }
  return { set, rebotados, raw, ok };
}

// Ejecuta `fn` sobre los items en tandas concurrentes de `n` (rápido y sin
// pasarse: el envío secuencial de 61 tardaba tanto que cortaba la función).
async function enTandas<T, R>(items: T[], n: number, fn: (x: T) => Promise<R>): Promise<R[]> {
  const out: R[] = [];
  for (let i = 0; i < items.length; i += n) {
    const lote = items.slice(i, i + n);
    out.push(...await Promise.all(lote.map(fn)));
  }
  return out;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config" }, 503, origen);
  if (!BREVO_API_KEY) return responder({ error: "sin-configurar", mensaje: "Falta BREVO_API_KEY." }, 503, origen);

  // 1 · ¿Quién eres? JWT + admin.
  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sin_sesion" }, 401, origen);
  const rUser = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` },
  });
  if (!rUser.ok) return responder({ error: "sin_sesion" }, 401, origen);
  if (!(await comoUsuario("es_admin", jwt))) return responder({ error: "sin_permiso" }, 403, origen);

  // 2 · Cuerpo
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* */ }
  const modo = String(cuerpo.modo ?? "prueba").trim();

  // Datos de todas las familias (una sola consulta)
  const familias = (await rpcServicio("familias_para_invitar", {}) as FilaFamilia[]) || [];
  if (!Array.isArray(familias)) return responder({ error: "sin_datos" }, 500, origen);

  const enlaceDe = (token: string | null) =>
    `${URL_BASE}familia/entrar/?t=${encodeURIComponent(token ?? "")}`;
  const ASUNTO = "Tu acceso a la Web y App del Club Apolana 🏊";

  // No enviar a: cuentas de prueba, correos internos, ni direcciones mal
  // formadas. Se saltan y se cuentan aparte (no se cuela ni un correo raro).
  const emailOk = (e: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(e || ""));
  const excluible = (e: string) => {
    const x = String(e || "").toLowerCase().trim();
    return /@apolana\.club$/.test(x) || x === "andres.apolana@gmail.com" || x === "itakadyr@gmail.com";
  };
  const enviable = (f: FilaFamilia) => !!f.token && emailOk(f.email) && !excluible(f.email);

  // ---- MODO PRUEBA: correo de muestra a un destino ----
  if (modo === "prueba") {
    const destino = String(cuerpo.destino ?? "andres.apolana@gmail.com").trim();
    const nHijos = Math.max(1, Math.min(6, Number(cuerpo.n_hijos ?? 1) || 1));
    // Busca una familia real con ese nº de hijos; si no hay, la que más se acerque.
    const conN = familias.filter((f) => (f.hijos || []).length === nHijos);
    const elegida = conN[0]
      ?? [...familias].sort((a, b) =>
        Math.abs((a.hijos?.length ?? 0) - nHijos) - Math.abs((b.hijos?.length ?? 0) - nHijos))[0];
    if (!elegida) return responder({ error: "sin_familias" }, 200, origen);
    // Enlace de DEMOSTRACIÓN (no válido) para que al pulsarlo no toque ninguna cuenta real.
    const enlaceDemo = `${URL_BASE}familia/entrar/?t=DEMO-no-valido`;
    const yaCuenta = cuerpo.ya_cuenta === true;
    const r = await enviarBrevo(destino, elegida.hijos, enlaceDemo, `[PRUEBA · ${nHijos} hijo/a(s)] ${ASUNTO}`, yaCuenta);
    return responder({
      ok: r.ok, modo, destino, n_hijos: nHijos,
      muestra_hijos: (elegida.hijos || []).map((h) => tituloCase(h.nombre)),
      ...(r.ok ? {} : { fallo: r }),
    }, 200, origen);
  }

  // ---- MODO REAL: a todas las familias (idempotente y en tandas) ----
  if (modo === "real") {
    const soloA = String(cuerpo.solo_a ?? "").trim().toLowerCase(); // opcional: solo una familia
    const objetivo = soloA ? familias.filter((f) => (f.email || "").toLowerCase() === soloA) : familias;
    const enviables = objetivo.filter(enviable);

    // RECONCILIAR SIEMPRE (tanto al contar como al enviar): preguntar a Brevo a
    // quién ya se le mandó hoy y sellarlo. Así «Ver a cuántas» ya descuenta lo
    // que alcanzó un intento anterior, y nunca se reenvía a nadie.
    let brevoHoy = -1;      // nº de eventos que Brevo reporta hoy (-1 = no contestó)
    let brevoOk = false;
    const rebotados: string[] = []; // familias de la campaña cuyo correo rebotó
    try {
      const rec = await yaEnviadosBrevo();
      brevoOk = rec.ok; brevoHoy = rec.raw;
      for (const f of enviables) {
        const suyo = (f.email || "").toLowerCase().trim();
        if (rec.rebotados.has(suyo)) rebotados.push(f.email);
        if (!f.invitado_en && f.token && rec.set.has(suyo)) {
          await sellarInvitado(f.token);
          f.invitado_en = new Date().toISOString(); // reflejarlo ya en este cálculo
        }
      }
    } catch (_e) { /* sin reconciliación nos guiamos por invitado_en */ }

    const pendientes = enviables.filter((f) => !f.invitado_en);
    const yaInvitadas = enviables.length - pendientes.length;

    if (cuerpo.confirmar !== true) {
      return responder({
        error: "falta_confirmar", mensaje: "Pon confirmar:true para enviar de verdad.",
        total: objetivo.length, enviables: enviables.length,
        pendientes: pendientes.length, ya_invitadas: yaInvitadas,
        brevo_ok: brevoOk, brevo_hoy: brevoHoy,
        rebotados: rebotados.length, detalle_rebotados: rebotados,
      }, 200, origen);
    }

    try {
      const enviados: string[] = [];
      const fallos: Array<{ email: string; motivo: unknown }> = [];
      await enTandas(pendientes, 8, async (f) => {
        const r = await enviarBrevo(f.email, f.hijos, enlaceDe(f.token), ASUNTO, f.ya_tiene_cuenta === true);
        if (r.ok) { enviados.push(f.email); if (f.token) await sellarInvitado(f.token); }
        else fallos.push({ email: f.email, motivo: r });
      });
      const saltados = objetivo.filter((f) => !enviable(f)).map((f) => f.email);
      return responder({
        ok: true, modo, total: objetivo.length,
        enviados: enviados.length, ya_estaban: yaInvitadas,
        saltados: saltados.length, fallos: fallos.length,
        detalle_fallos: fallos, detalle_saltados: saltados,
      }, 200, origen);
    } catch (e) {
      // Aun si algo peta, lo enviado quedó sellado: reintentar es seguro.
      return responder({ ok: false, modo, error: "fallo_envio", detalle: String(e) }, 200, origen);
    }
  }

  return responder({ error: "modo_desconocido", modo }, 400, origen);
});
