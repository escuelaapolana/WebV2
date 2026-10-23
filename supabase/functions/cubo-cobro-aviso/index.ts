// ============================================================
// cubo-cobro-aviso · avisa por correo de que ya puede activar su cuota
// ------------------------------------------------------------
// QUÉ HACE
//   Cuando el club «abre el cobro» a una persona del Cubo, esta función
//   le manda un correo: «ya puedes activar tu cuota» con un botón a su
//   portal. El primer pago (entrada) y la cuota mensual los ve allí.
//
//   body { alta_id, correccion?: true, recordatorio?: true }  ·  { comprobar: true } → solo dice si
//   esta versión entiende «recordatorio» (no envía nada).
//   · recordatorio (15-oct): botón «Recordar a los que no han pagado» de
//     admin/cubo-altas. Otro asunto/texto («aún no nos consta el pago de tu
//     cuota de <mes>») y la Edge vuelve a comprobar que toca: cobro abierto,
//     aprobada, sin suscripción activa/cancelada/impago, sin pago externo,
//     lista de espera, baja ni Fuerza gratis, sin cobro este mes, y que no
//     tenga «no reclamar hasta que venga» vigente (mig 390). Si no toca,
//     contesta { ok:false, motivo:'no-toca', detalle } y NO envía nada.
//     Sella cobro_avisado_en y cobro_recordado_en.
//   · Al correo solo va el primer trozo de nota_cobro (antes de « · »): lo
//     que va detrás son apuntes internos.
//
// LO QUE NO SE FÍA DEL NAVEGADOR
//   · Quién llama: JWT de verdad + es_admin()/es_tesoreria().
//   · A quién se escribe: el correo se lee DE LA BASE (perfil del alta),
//     nunca del cuerpo. Solo se acepta el id del alta.
//
// CLAVES (variables de entorno de Supabase)
//   BREVO_API_KEY, CORREO_REMITENTE, CORREO_REMITENTE_NOMBRE,
//   CORREO_URL_BASE, y las de Supabase. Si falta Brevo, contesta con
//   buenos modales (el cobro ya se abrió; el correo es un extra).
//
//   supabase functions deploy cubo-cobro-aviso --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";

const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
// El correo SALE de info@ (remitente pro), pero las RESPUESTAS van a Andrés,
// que es quien las lee (info@ no lo mira nadie). Así no se pierde nada.
const RESPUESTAS_EMAIL = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const URL_BASE = (Deno.env.get("CORREO_URL_BASE") ?? "https://atletismoapolana.com/")
  .replace(/\/*$/, "/");
// La base también puede pedirlo (cron_llamar_edge, con x-cron-secret): así el
// club lo manda sin tener que abrir el panel (23-oct). Mismo patrón que
// natacion-equipacion-correo.
const CRON_SECRET = (Deno.env.get("CRON_SECRET") ?? "").trim();
function iguales(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a), eb = new TextEncoder().encode(b);
  let dif = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) dif |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return dif === 0;
}

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
async function consulta(ruta: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
  });
  const t = await r.text();
  let d: unknown = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, datos: d };
}
async function comoUsuario(rpc: string, jwt: string): Promise<boolean> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: "POST",
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
    body: "{}",
  });
  if (!r.ok) return false;
  try { return (await r.json()) === true; } catch { return false; }
}

function esc(s: string): string {
  return String(s ?? "").replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m] as string));
}
const MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
// Fecha de hoy en Madrid (YYYY-MM-DD) y nombre del mes en curso.
function hoyMadrid(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
}
function diaMadrid(iso: string): string {
  try {
    return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(iso));
  } catch { return ""; }
}
// La nota del cobro lleva a veces apuntes internos tras « · » (bajas, «no
// reclamar…»). Al correo solo va el PRIMER trozo, que es el que se escribe
// para la persona («Primer pago = cuota de octubre…»).
function notaParaCorreo(nota: string): string {
  return String(nota ?? "").split(" · ")[0].trim();
}

type Modo = "aviso" | "correccion" | "recordatorio";

// Diseño del club (como recibo-aviso): cabecera navy, caja crema con los
// datos, botón «Pagar la cuota» al portal. TABLAS + bgcolor (atributo, no
// solo CSS) para que los fondos se vean en Gmail/Outlook.
function correoHtml(o: { nombre: string; precioMes: number; primer: number; nota: string; grupo: string; modo: Modo; mes: string }): string {
  const hola = o.nombre ? `¡Hola, ${esc(o.nombre)}!` : "¡Hola!";
  const enlace = `${URL_BASE}portal/`;
  let intro = "";
  if (o.modo === "correccion") {
    intro = '🙏 <b>Perdona el lío:</b> en el correo anterior ponía <b>10 €</b> por error. Estos son los datos correctos de tu cuota de El Cubo.';
  } else if (o.modo === "recordatorio") {
    intro = `Te escribimos porque <b>aún no nos consta el pago de tu cuota de El Cubo de ${esc(o.mes)}</b>. Seguramente se te ha pasado: se hace en un momento desde tu espacio en la app.`;
  } else {
    intro = '¡Bienvenido/a a <b>El Cubo</b>! 💪 Ya has empezado a entrenar con nosotros, así que <b>ya puedes dejar lista tu cuota</b> y olvidarte del tema.';
  }
  const como = `Entra con <b>este mismo correo</b> y pulsa <b>«Pagar la cuota»</b>: hoy pagas <b>${o.primer} €</b> y tu tarjeta queda guardada; a partir de ahí ${o.precioMes > 0 ? "tu cuota de <b>" + o.precioMes + " €/mes</b>" : "tu cuota"} se cobra sola cada <b>día 5</b>, sin que tengas que hacer nada.`;
  const fila = (k: string, v: string) =>
    `<tr><td style="padding:3px 0;color:#5C4A1E;font-size:14px;width:46%">${k}</td><td style="padding:3px 0;color:#26374B;font-size:14px;font-weight:700">${v}</td></tr>`;
  const datos =
    (o.grupo ? fila("Grupo", esc(o.grupo)) : "") +
    fila("Hoy pagas", `${o.primer} €`) +
    (o.precioMes > 0 ? fila("Después", `${o.precioMes} €/mes · se cobra solo el día 5`) : "");
  const notaHtml = o.nota
    ? `<tr><td colspan="2" style="padding:8px 0 0;color:#5C4A1E;font-size:13px;line-height:1.5">${esc(o.nota)}</td></tr>`
    : "";
  const pie = o.modo === "recordatorio"
    ? "¿Ya lo has pagado, has dejado de venir o hay algún problema? Contéstanos a este mensaje y lo vemos. 😊"
    : "¿Alguna duda? Contéstanos a este mensaje y te echamos una mano. 😊";
  return `<!doctype html><html lang="es"><head><meta charset="utf-8"></head><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">El Cubo · Club Atletismo Apolana</td></tr>
      <tr><td style="padding:24px 24px 6px 24px">
        <p style="margin:0 0 14px;font-size:17px;font-weight:700;color:#26374B">${hola}</p>
        <p style="margin:0 0 14px;color:#3f3f46;line-height:1.6">${intro}</p>
        <p style="margin:0 0 16px;color:#3f3f46;line-height:1.6">${como}</p>
      </td></tr>
      <tr><td style="padding:2px 24px 14px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:14px 18px">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0">${datos}${notaHtml}</table>
          </td></tr>
        </table></td></tr>
      <tr><td align="center" style="padding:4px 24px 6px 24px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">
            <a href="${enlace}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:700;font-size:16px">Pagar la cuota →</a>
          </td>
        </tr></table>
      </td></tr>
      <tr><td align="center" style="padding:0 24px 20px 24px">
        <p style="margin:0;color:#71717a;font-size:13px">o entra tú mismo en <a href="${enlace}" style="color:#2F6FA8">atletismoapolana.com/portal</a> con este mismo correo</p>
      </td></tr>
      <tr><td style="padding:0 24px 24px 24px;border-top:1px solid #ececec">
        <p style="margin:16px 0 0 0;color:#71717a;font-size:13px;line-height:1.5">${pie}</p>
      </td></tr>
    </table>
  </td></tr></table>
  </body></html>`;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config" }, 503, origen);
  if (!BREVO_API_KEY) return responder({ ok: false, motivo: "sin-configurar" }, 200, origen);

  // 1 · Quién llama: la base con su secreto, o administración/tesorería con su sesión.
  const secreto = (req.headers.get("x-cron-secret") ?? "").trim();
  const esLaBase = !!(CRON_SECRET && secreto && iguales(secreto, CRON_SECRET));
  if (!esLaBase) {
    const cabecera = req.headers.get("Authorization") ?? "";
    const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
    if (!jwt) return responder({ error: "sin_sesion" }, 401, origen);
    const rU = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` },
    });
    if (!rU.ok) return responder({ error: "sin_sesion" }, 401, origen);
    const puede = (await comoUsuario("es_admin", jwt)) || (await comoUsuario("es_tesoreria", jwt));
    if (!puede) return responder({ error: "sin_permiso" }, 403, origen);
  }

  // 2 · Qué alta (solo se acepta el id)
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const altaId = String(cuerpo.alta_id ?? "").trim();
  const correccion = cuerpo.correccion === true;
  // Recordatorio de pago (botón «Recordar a los que no han pagado»): otro texto
  // y, sobre todo, se vuelve a comprobar AQUÍ que de verdad toca reclamarle.
  const recordatorio = cuerpo.recordatorio === true && !correccion;
  const modo: Modo = recordatorio ? "recordatorio" : (correccion ? "correccion" : "aviso");
  // El panel pregunta antes de nada si esta Edge ya entiende «recordatorio»
  // (así, si no se ha desplegado, no sale ni un correo equivocado).
  if (cuerpo.comprobar === true) return responder({ ok: true, recordatorio: true }, 200, origen);
  if (!altaId) return responder({ error: "falta_alta" }, 400, origen);

  // 3 · El correo sale de la base (perfil del alta), no del navegador.
  const base = "nombre,perfil_id,precio_mes,primer_pago_cent,nota_cobro,horario,estado,cobro_abierto,suscripcion_estado,pago_externo,lista_espera,baja_solicitada,ultimo_cobro,atleta_id";
  let rAlta = await consulta(`cubo_altas?select=${base},no_reclamar_hasta_asistir,no_reclamar_desde&id=eq.${encodeURIComponent(altaId)}&limit=1`);
  // Si aún no se ha aplicado la migración 390, se lee sin las columnas nuevas.
  if (!rAlta.ok) rAlta = await consulta(`cubo_altas?select=${base}&id=eq.${encodeURIComponent(altaId)}&limit=1`);
  const alta = Array.isArray(rAlta.datos) ? rAlta.datos[0] : null;
  if (!alta || !alta.perfil_id) return responder({ ok: false, motivo: "sin-perfil" }, 200, origen);

  if (recordatorio) {
    // Solo quien tiene el cobro abierto y no ha pagado el mes en curso.
    const hoy = hoyMadrid();
    const st = String(alta.suscripcion_estado ?? "");
    const fuera =
      alta.estado !== "aprobada" ? "no-aprobada" :
      !alta.cobro_abierto ? "cobro-cerrado" :
      st === "activa" ? "ya-paga" :
      st === "cancelada" ? "cancelada" :
      st === "impago" ? "impago" :
      alta.pago_externo ? "pago-externo" :
      alta.lista_espera ? "lista-espera" :
      alta.baja_solicitada ? "baja" :
      /fuerza gratis/i.test(String(alta.horario ?? "")) ? "fuerza-gratis" :
      (alta.ultimo_cobro && diaMadrid(String(alta.ultimo_cobro)).slice(0, 7) === hoy.slice(0, 7)) ? "pagado-este-mes" :
      "";
    if (fuera) return responder({ ok: false, motivo: "no-toca", detalle: fuera, recordatorio: true }, 200, origen);
    // «No reclamar hasta que venga»: se salta mientras no tenga UNA asistencia
    // desde que se marcó. En cuanto viene, deja de saltarse sola.
    if (alta.no_reclamar_hasta_asistir === true) {
      const desde = alta.no_reclamar_desde ? diaMadrid(String(alta.no_reclamar_desde)) : "";
      let vino = false;
      if (alta.atleta_id) {
        const rAs = await consulta(`asistencia?select=id&atleta_id=eq.${encodeURIComponent(String(alta.atleta_id))}&presente=is.true${desde ? "&fecha=gte." + desde : ""}&limit=1`);
        vino = rAs.ok && Array.isArray(rAs.datos) && rAs.datos.length > 0;
      }
      if (!vino) return responder({ ok: false, motivo: "no-toca", detalle: "no-reclamar-hasta-que-venga", recordatorio: true }, 200, origen);
    }
  }

  const rP = await consulta(`perfiles?select=email,nombre&id=eq.${encodeURIComponent(String(alta.perfil_id))}&limit=1`);
  const perfil = Array.isArray(rP.datos) ? rP.datos[0] : null;
  const destino = String(perfil?.email ?? "").trim();
  if (!destino) return responder({ ok: false, motivo: "sin-correo", recordatorio }, 200, origen);
  const nombre = String(alta.nombre ?? perfil?.nombre ?? "").trim().split(/\s+/)[0] ?? "";
  const precioMes = Math.round(Number(alta.precio_mes) || 0);
  const primer = (alta.primer_pago_cent != null && Number(alta.primer_pago_cent) > 0)
    ? Math.round(Number(alta.primer_pago_cent) / 100)
    : precioMes;
  const nota = notaParaCorreo(String(alta.nota_cobro ?? ""));
  const grupo = String(alta.horario ?? "").replace(/^El Cubo\s*·\s*/i, "").trim();
  const mes = MESES[Number(hoyMadrid().slice(5, 7)) - 1] ?? "este mes";

  const asunto = modo === "correccion" ? "Corrección · tu cuota de El Cubo"
    : modo === "recordatorio" ? `Recordatorio · tu cuota de El Cubo de ${mes} está pendiente`
    : "Ya puedes activar tu cuota de El Cubo";
  const introTxt = modo === "correccion" ? "Perdona el lío: en el correo anterior ponía 10 € por error. Estos son los datos correctos. "
    : modo === "recordatorio" ? `Aún no nos consta el pago de tu cuota de El Cubo de ${mes}. `
    : "¡Bienvenido/a a El Cubo! ";
  const texto = `${nombre ? "¡Hola, " + nombre + "!" : "¡Hola!"}\n\n${introTxt}Entra en ${URL_BASE}portal/ con este mismo correo y pulsa «Pagar la cuota»: hoy pagas ${primer} €${nota ? " (" + nota + ")" : ""} y tu tarjeta queda guardada; a partir de ahí ${precioMes > 0 ? "tu cuota de " + precioMes + " €/mes" : "tu cuota"} se cobra sola cada día 5.\n\n${modo === "recordatorio" ? "¿Ya lo has pagado o hay algún problema? Contesta a este mensaje y lo vemos." : "¿Dudas? Contesta a este mensaje y te ayudamos."}`;

  // 4 · Enviar por Brevo
  let resp: Response;
  try {
    resp = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS_EMAIL },
        to: [{ email: destino }],
        subject: asunto,
        htmlContent: correoHtml({ nombre, precioMes, primer, nota, grupo, modo, mes }),
        textContent: texto,
      }),
    });
  } catch (e) {
    return responder({ ok: false, motivo: "sin-conexion", detalle: String(e), recordatorio }, 200, origen);
  }
  if (!resp.ok) {
    let datos: unknown = null; try { datos = await resp.json(); } catch { /* */ }
    return responder({ ok: false, motivo: "brevo-rechazo", estado: resp.status, brevo: datos, recordatorio }, 200, origen);
  }
  // Sellar que a esta alta ya se le avisó del cobro: así el botón «avisar solo a
  // los nuevos» (admin) sabe quién falta. Es un extra; si falla, el correo ya salió.
  const ahora = new Date().toISOString();
  const sellar = async (campos: Record<string, unknown>) => {
    try {
      await fetch(`${SUPABASE_URL}/rest/v1/cubo_altas?id=eq.${encodeURIComponent(altaId)}`, {
        method: "PATCH",
        headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json", Prefer: "return=minimal" },
        body: JSON.stringify(campos),
      });
    } catch (_e) { /* no pasa nada: el aviso ya se envió */ }
  };
  await sellar({ cobro_avisado_en: ahora });
  // Aparte (columna de la mig 390): si aún no existe, no estropea el sello de arriba.
  if (recordatorio) await sellar({ cobro_recordado_en: ahora });
  return responder({ ok: true, destino, recordatorio }, 200, origen);
});
