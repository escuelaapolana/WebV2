// ============================================================
// entreno-enlace · envía por correo el enlace para DOMICILIAR (SEPA) la cuota
// de entrenamiento. Explica que el correo anterior (pagar con tarjeta) fue un
// error y que la forma correcta es la domiciliación.
//
//   · POST con JWT de admin/staff/tesorería.
//   · body { cuota_id }  → manda el correo al atleta de esa cuota de entreno.
//   · body { cuota_id, recordatorio: true } (370 · admin/dinero «Recordar»):
//     el mismo enlace, pero con un texto neutro de recordatorio (sin el
//     «perdona, el correo anterior fue un error», que era solo para el 1er envío).
//   · body { ping: true } → { ok, recordatorio: true }: así la pantalla Dinero
//     sabe que esta versión ya está desplegada antes de mandar recordatorios.
//
//   Variables (ya existen, las usa cubo-cobro-aviso / recibo-aviso):
//     BREVO_API_KEY, CORREO_REMITENTE, CORREO_REMITENTE_NOMBRE, CORREO_RESPUESTAS,
//     SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY, CORREO_ORIGENES
//   supabase functions deploy entreno-enlace --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
//
// MIG 380 · cuotas del asistente «Nuevo cobro» (origen = 'asistente'): correo
//   propio que se adapta a TARJETA o SEPA y a mensual / trimestral / anual, con
//   su mes de inicio y su fecha de fin (_shared/cuota-entreno.ts). El enlace va
//   sin parámetros: /entreno/cuota/ pide los datos de la cuota por el token.
//   { ping: true } → también { generico: true } (el asistente lo comprueba antes
//   de mandar nada, para no enviar nunca el texto viejo a una cuota nueva).
// ============================================================

import { esAsistente, esNatacion, textosCuota } from "../_shared/cuota-entreno.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const RESPUESTAS_EMAIL = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const URL_BASE = (Deno.env.get("PAGOS_URL_BASE") ?? "https://atletismoapolana.com/").replace(/\/*$/, "/");
// 28-oct-2026 · también lo puede lanzar la base (cron_llamar_edge, cabecera
// x-cron-secret), para mandar los enlaces de natación desde el servidor.
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
  const valor = permitidos.length ? (origen && permitidos.includes(origen) ? origen : permitidos[0]) : (origen ?? "*");
  return {
    "Access-Control-Allow-Origin": valor,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}
function responder(cuerpo: unknown, estado: number, origen: string | null): Response {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...cors(origen), "Content-Type": "application/json; charset=utf-8" } });
}
async function consulta(ruta: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
  });
  const t = await r.text(); let d: unknown = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, datos: d };
}
async function comoUsuario(rpc: string, jwt: string): Promise<boolean> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: "POST", headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" }, body: "{}",
  });
  if (!r.ok) return false; try { return (await r.json()) === true; } catch { return false; }
}
function esc(s: string): string { return String(s ?? "").replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m] as string)); }
const eur = (n: number) => (Number(n) || 0).toLocaleString("es-ES", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + " €";

// Cuota MENSUAL (mig 313, p. ej. natación): correo propio, sin el «perdona
// por el lío» que era solo para los 6 adultos de entreno.
function correoMensualHtml(nombre: string, importe: number, enlace: string, concepto: string): string {
  // Lo lee la familia (el nadador suele ser un niño): «familia de …».
  const hola = nombre ? `¡Hola, familia de ${esc(nombre)}!` : "¡Hola!";
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana</td></tr>
      <tr><td style="padding:24px 24px 6px 24px">
        <p style="margin:0 0 14px;font-size:17px;font-weight:700;color:#26374B">${hola}</p>
        <p style="margin:0 0 14px;color:#3f3f46;line-height:1.6">Como nos pedisteis, la cuota pasa a <b>domiciliación bancaria (SEPA)</b>: metéis el IBAN <b>una sola vez</b> y se cobra sola cada mes.</p>
      </td></tr>
      <tr><td style="padding:2px 24px 10px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:14px 18px;color:#5C4A1E;font-size:15px;line-height:1.7">
            <b>${esc(concepto || "Cuota mensual")}</b><br>
            <span style="font-size:20px;font-weight:700">${eur(importe)}</span> al mes<br>
            <span style="font-size:13.5px">El mes en curso se cobra al domiciliar y después <b>cada mes en esa misma fecha</b>. <b>Tras junio se para sola.</b></span>
          </td></tr>
        </table></td></tr>
      <tr><td align="center" style="padding:6px 24px 6px 24px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">
            <a href="${enlace}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:700;font-size:16px">Domiciliar la cuota →</a>
          </td>
        </tr></table></td></tr>
      <tr><td align="center" style="padding:0 24px 18px 24px">
        <p style="margin:0;color:#71717a;font-size:13px">El IBAN se teclea en la pantalla segura de Stripe, nunca en nuestra web.</p>
      </td></tr>
      <tr><td style="padding:0 24px 24px 24px;border-top:1px solid #ececec">
        <p style="margin:16px 0 0 0;color:#71717a;font-size:13px;line-height:1.5">¿Alguna duda? Contéstanos a este mensaje. 😊</p>
      </td></tr>
    </table>
  </td></tr></table>
  </body></html>`;
}

function correoHtml(nombre: string, importe: number, enlace: string): string {
  const hola = nombre ? `¡Hola, ${esc(nombre)}!` : "¡Hola!";
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana</td></tr>
      <tr><td style="padding:24px 24px 6px 24px">
        <p style="margin:0 0 14px;font-size:17px;font-weight:700;color:#26374B">${hola}</p>
        <p style="margin:0 0 12px;color:#3f3f46;line-height:1.6">Perdona por el lío: el correo anterior te pedía pagar la cuota de entrenamiento <b>con tarjeta</b>, y fue un <b>error nuestro</b>. <b>Ignóralo</b> — no tienes que pagar nada por ahí.</p>
        <p style="margin:0 0 14px;color:#3f3f46;line-height:1.6">La forma correcta, y más cómoda, es por <b>domiciliación bancaria (SEPA)</b>: metes tu IBAN <b>una sola vez</b> y la cuota se cobra sola cada trimestre.</p>
      </td></tr>
      <tr><td style="padding:2px 24px 10px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:14px 18px;color:#5C4A1E;font-size:15px;line-height:1.7">
            <b>Cuota de entrenamiento</b><br>
            <span style="font-size:20px;font-weight:700">${eur(importe)}</span> cada trimestre<br>
            <span style="font-size:13.5px">Se cobra ahora (octubre), en enero y en abril. <b>Tras abril se para solo</b>: en junio no se te pasa nada.</span>
          </td></tr>
        </table></td></tr>
      <tr><td align="center" style="padding:6px 24px 6px 24px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">
            <a href="${enlace}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:700;font-size:16px">Domiciliar mi cuota →</a>
          </td>
        </tr></table></td></tr>
      <tr><td align="center" style="padding:0 24px 18px 24px">
        <p style="margin:0;color:#71717a;font-size:13px">El IBAN se teclea en la pantalla segura de Stripe, nunca en nuestra web.</p>
      </td></tr>
      <tr><td style="padding:0 24px 24px 24px;border-top:1px solid #ececec">
        <p style="margin:16px 0 0 0;color:#71717a;font-size:13px;line-height:1.5">¿Alguna duda? Contéstanos a este mensaje. 😊</p>
      </td></tr>
    </table>
  </td></tr></table>
  </body></html>`;
}

// 380 · Cuota creada con el asistente «Nuevo cobro»: un solo correo que vale
// para tarjeta o SEPA y cualquier periodicidad. Lo puede leer la familia (el
// atleta puede ser menor), así que nombra a la persona de la cuota.
function correoAsistenteHtml(persona: string, importe: number, enlace: string, c: Record<string, any>, recordatorio: boolean): string {
  const t = textosCuota(c);
  const intro = recordatorio
    ? `Te recordamos que la cuota${persona ? ` de <b>${esc(persona)}</b>` : ""} sigue <b>sin ${t.tarjeta ? "activar" : "domiciliar"}</b>.`
    : `Te escribimos por la cuota${persona ? ` de <b>${esc(persona)}</b>` : ""}.`;
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana</td></tr>
      <tr><td style="padding:24px 24px 6px 24px">
        <p style="margin:0 0 14px;font-size:17px;font-weight:700;color:#26374B">¡Hola!</p>
        <p style="margin:0 0 12px;color:#3f3f46;line-height:1.6">${intro}</p>
        <p style="margin:0 0 14px;color:#3f3f46;line-height:1.6">Se paga ${t.como}.</p>
      </td></tr>
      <tr><td style="padding:2px 24px 10px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:14px 18px;color:#5C4A1E;font-size:15px;line-height:1.7">
            <b>${esc(String(c.concepto ?? "Cuota"))}</b><br>
            <span style="font-size:20px;font-weight:700">${eur(importe)}</span> ${t.cada}<br>
            <span style="font-size:13.5px">${esc(t.primero)}${t.fin ? ` <b>${esc(t.fin)}</b>` : ""}</span>
          </td></tr>
        </table></td></tr>
      <tr><td align="center" style="padding:6px 24px 6px 24px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">
            <a href="${enlace}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:700;font-size:16px">${esc(t.boton)}</a>
          </td>
        </tr></table></td></tr>
      <tr><td align="center" style="padding:0 24px 18px 24px">
        <p style="margin:0;color:#71717a;font-size:13px">${esc(t.seguro)}</p>
      </td></tr>
      <tr><td style="padding:0 24px 24px 24px;border-top:1px solid #ececec">
        <p style="margin:16px 0 0 0;color:#71717a;font-size:13px;line-height:1.5">¿Alguna duda? Contéstanos a este mensaje. 😊</p>
      </td></tr>
    </table>
  </td></tr></table>
  </body></html>`;
}

// 370 · Recordatorio (admin/dinero): el mismo correo sin el «perdona por el lío».
function correoRecordatorioHtml(nombre: string, importe: number, enlace: string): string {
  const hola = nombre ? `¡Hola, ${esc(nombre)}!` : "¡Hola!";
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana</td></tr>
      <tr><td style="padding:24px 24px 6px 24px">
        <p style="margin:0 0 14px;font-size:17px;font-weight:700;color:#26374B">${hola}</p>
        <p style="margin:0 0 12px;color:#3f3f46;line-height:1.6">Te recordamos que tu <b>cuota de entrenamiento</b> sigue <b>sin domiciliar</b>.</p>
        <p style="margin:0 0 14px;color:#3f3f46;line-height:1.6">Se hace por <b>domiciliación bancaria (SEPA)</b>: metes tu IBAN <b>una sola vez</b> y la cuota se cobra sola cada trimestre.</p>
      </td></tr>
      <tr><td style="padding:2px 24px 10px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:14px 18px;color:#5C4A1E;font-size:15px;line-height:1.7">
            <b>Cuota de entrenamiento</b><br>
            <span style="font-size:20px;font-weight:700">${eur(importe)}</span> cada trimestre<br>
            <span style="font-size:13.5px">Se cobra en octubre, enero y abril. <b>Tras abril se para solo</b>: en junio no se te pasa nada.</span>
          </td></tr>
        </table></td></tr>
      <tr><td align="center" style="padding:6px 24px 6px 24px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">
            <a href="${enlace}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:700;font-size:16px">Domiciliar mi cuota →</a>
          </td>
        </tr></table></td></tr>
      <tr><td align="center" style="padding:0 24px 18px 24px">
        <p style="margin:0;color:#71717a;font-size:13px">El IBAN se teclea en la pantalla segura de Stripe, nunca en nuestra web.</p>
      </td></tr>
      <tr><td style="padding:0 24px 24px 24px;border-top:1px solid #ececec">
        <p style="margin:16px 0 0 0;color:#71717a;font-size:13px;line-height:1.5">¿Alguna duda? Contéstanos a este mensaje. 😊</p>
      </td></tr>
    </table>
  </td></tr></table>
  </body></html>`;
}

// 28-oct-2026 · NATACIÓN (origen 'natacion'): correo propio que dice lo mismo
// que el mensaje de WhatsApp de Mario (portal/natacion-cuotas): se activa con
// tarjeta o IBAN (lo eligen ellos, mig 430), el primer cobro al activarla (o el
// día 5 del mes de inicio, si empieza más adelante) y después siempre el DÍA 5
// (mig 429). El texto genérico del asistente decía «solo IBAN» y «en esa misma
// fecha», que en natación ya no es así. Escuela → a la familia (vosotros);
// Máster → al nadador (tú).
const MESES_N = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
  "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
function mesAnioN(iso: string | null | undefined): string {
  if (!iso || !/^\d{4}-\d{2}/.test(iso)) return "";
  const [y, m] = iso.split("-").map(Number);
  return `${MESES_N[m - 1]} de ${y}`;
}
function hoyMadridN(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
}
function correoNatacion(c: Record<string, any>, enlace: string, recordatorio: boolean): { asunto: string; html: string; texto: string } {
  const fam = /escuela/i.test(String(c.concepto ?? ""));
  const pila0 = String(c.nombre ?? "").trim().split(/\s+/)[0] ?? "";
  const pila = pila0 ? pila0.charAt(0).toUpperCase() + pila0.slice(1).toLowerCase() : "";
  const imp = (Number(c.importe_cent) || 0) / 100;
  const cargo = (Number(c.cargo_inicial_cent) || 0) / 100;
  const tri = c.periodicidad === "trimestral";
  const per = tri ? "al trimestre" : "al mes";
  const cada = tri ? "cada trimestre" : "cada mes";
  const dia5 = tri ? "el día 5 de cada trimestre" : "el día 5 de cada mes";
  const ambos = !c.metodo || c.metodo === "ambos", tarjeta = c.metodo === "tarjeta";
  const verbo = ambos || tarjeta ? "activarla" : "domiciliarla";
  const hoy = hoyMadridN();
  const futuro = !!c.inicio && String(c.inicio).slice(0, 7) > hoy.slice(0, 7);
  const primero = cargo >= 0.5 && futuro
    ? `Al ${verbo} se cobran <b>${eur(cargo)}</b>; después, ${eur(imp)} ${per}, ${dia5} desde el 5 de ${mesAnioN(c.inicio)}.`
    : futuro
    ? `El primer cobro será el <b>5 de ${mesAnioN(c.inicio)}</b>; después, ${dia5}. Al ${verbo} no se cobra nada.`
    : `El primer cobro se hace al ${verbo} (${tri ? "el trimestre en curso" : "el mes en curso"}); después, ${dia5}.`;
  const como = ambos
    ? `Se hace <b>una sola vez</b>, con <b>tarjeta o con IBAN</b> (como ${fam ? "prefiráis" : "prefieras"}), y después se cobra sola ${cada}. Unos días antes de cada cobro ${fam ? "os llega" : "te llega"} un aviso por correo.`
    : tarjeta
    ? `Se mete la tarjeta <b>una sola vez</b> y después se cobra sola ${cada}.`
    : `Se hace <b>una sola vez</b>: ${fam ? "metéis" : "metes"} el IBAN y después se cobra sola ${cada}.`;
  const de = fam ? `la cuota de natación de <b>${esc(pila)}</b>` : `tu cuota de natación`;
  const intro = recordatorio
    ? `${fam ? "Os recordamos" : "Te recordamos"} que ${de} sigue <b>sin activar</b>. Aquí ${fam ? "tenéis" : "tienes"} el enlace:`
    : `${fam ? "Os enviamos" : "Te enviamos"} el enlace para <b>activar</b> ${de} 🏊`;
  const boton = ambos || tarjeta ? "Activar la cuota →" : "Domiciliar la cuota →";
  const hasta = c.fin ? ` · hasta ${mesAnioN(c.fin)}` : "";
  const asunto = (recordatorio ? "Recordatorio: " : "") +
    (fam ? `cuota de natación de ${pila} · enlace para activarla` : "tu cuota de natación · enlace para activarla");
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Natación</td></tr>
      <tr><td style="padding:24px 24px 6px 24px">
        <p style="margin:0 0 14px;font-size:17px;font-weight:700;color:#26374B">¡Hola${fam || !pila ? "" : ", " + esc(pila)}!</p>
        <p style="margin:0 0 14px;color:#3f3f46;line-height:1.6">${intro}</p>
      </td></tr>
      <tr><td style="padding:2px 24px 10px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:14px 18px;color:#5C4A1E;font-size:15px;line-height:1.7">
            <span style="font-size:13px;text-transform:uppercase;letter-spacing:.06em">Cuota</span><br>
            <span style="font-size:22px;font-weight:700">${eur(imp)}</span> ${per}<span style="font-size:13.5px">${esc(hasta)}</span><br>
            <span style="font-size:14px">📅 ${primero}</span>
          </td></tr>
        </table></td></tr>
      <tr><td style="padding:6px 24px 6px 24px">
        <p style="margin:0 0 14px;color:#3f3f46;line-height:1.6">✅ ${como}</p>
      </td></tr>
      <tr><td align="center" style="padding:4px 24px 8px 24px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">
            <a href="${enlace}" style="display:inline-block;padding:14px 32px;color:#ffffff;text-decoration:none;font-weight:700;font-size:16px">${boton}</a>
          </td>
        </tr></table></td></tr>
      <tr><td align="center" style="padding:0 24px 18px 24px">
        <p style="margin:0;color:#71717a;font-size:13px">La tarjeta o el IBAN se teclean en la pantalla segura de Stripe, nunca en nuestra web.</p>
      </td></tr>
      <tr><td style="padding:0 24px 24px 24px;border-top:1px solid #ececec">
        <p style="margin:16px 0 0 0;color:#71717a;font-size:13px;line-height:1.5">¿Alguna duda? ${fam ? "Contestad" : "Contesta"} a este correo. ¡Gracias! 😊</p>
      </td></tr>
    </table>
  </td></tr></table>
</body></html>`;
  const quitar = (s: string) => s.replace(/<\/?b>/g, "");
  const texto = `¡Hola${fam || !pila ? "" : ", " + pila}!\n\n${quitar(intro)}\n\nCuota: ${eur(imp)} ${per}${hasta}\n${quitar(primero)}\n\n${quitar(como)}\n\n${boton.replace(" →", "")}: ${enlace}\n\nLa tarjeta o el IBAN se teclean en la pantalla segura de Stripe, nunca en nuestra web.\n\n¿Alguna duda? ${fam ? "Contestad" : "Contesta"} a este correo.`;
  return { asunto, html, texto };
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config" }, 503, origen);
  if (!BREVO_API_KEY) return responder({ ok: false, motivo: "sin-configurar" }, 200, origen);

  const sec = (req.headers.get("x-cron-secret") ?? "").trim();
  const porCron = !!CRON_SECRET && !!sec && iguales(sec, CRON_SECRET);
  if (!porCron) {
    const cab = req.headers.get("Authorization") ?? "";
    const jwt = cab.toLowerCase().startsWith("bearer ") ? cab.slice(7).trim() : "";
    if (!jwt) return responder({ error: "sin_sesion" }, 401, origen);
    const puede = (await comoUsuario("es_admin", jwt)) || (await comoUsuario("es_staff", jwt)) || (await comoUsuario("puede_girar", jwt));
    if (!puede) return responder({ error: "sin_permiso" }, 403, origen);
  }

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  if (cuerpo.ping === true) return responder({ ok: true, recordatorio: true, generico: true }, 200, origen);
  const recordatorio = cuerpo.recordatorio === true;
  const cuotaId = String(cuerpo.cuota_id ?? "").trim();
  if (!cuotaId) return responder({ error: "falta_cuota" }, 400, origen);

  const rC = await consulta(`cuotas_entreno?select=nombre,apellidos,email,importe_cent,token,suscripcion_estado,periodicidad,concepto,metodo,inicio,fin,origen,cobro_abierto,cargo_inicial_cent&id=eq.${encodeURIComponent(cuotaId)}&limit=1`);
  const c = Array.isArray(rC.datos) ? rC.datos[0] as { nombre: string; apellidos: string | null; email: string; importe_cent: number; token: string; suscripcion_estado: string | null; periodicidad: string | null; concepto: string | null;
    metodo: string | null; inicio: string | null; fin: string | null; origen: string | null; cobro_abierto: boolean | null; cargo_inicial_cent: number | null } : null;
  if (!c) return responder({ ok: false, motivo: "no-existe" }, 200, origen);
  // Ya domiciliada (o con el mandato firmado y el 1er adeudo en camino, mig 311):
  // no se manda el enlace, que abriría otra suscripción y cobraría dos veces.
  if (c.suscripcion_estado === "activa" || c.suscripcion_estado === "en_camino") {
    return responder({ ok: false, motivo: "ya domiciliada" }, 200, origen);
  }
  const destino = String(c.email ?? "").trim();
  if (!destino) return responder({ ok: false, motivo: "sin-correo" }, 200, origen);
  // Cancelada o con el enlace cerrado: el enlace no serviría (entreno-pagar lo rechaza).
  if (c.suscripcion_estado === "cancelada" || c.cobro_abierto === false) {
    return responder({ ok: false, motivo: "cuota cerrada" }, 200, origen);
  }

  // Natación: su propio correo (tarjeta o IBAN, día 5), ver correoNatacion.
  if (esNatacion(c)) {
    const link = `${URL_BASE}entreno/cuota/?t=${encodeURIComponent(c.token)}`;
    const m = correoNatacion(c, link, recordatorio);
    try {
      const resp = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({
          sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
          replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS_EMAIL },
          to: [{ email: destino }],
          subject: m.asunto, htmlContent: m.html, textContent: m.texto,
        }),
      });
      return responder({ ok: resp.ok, destino: resp.ok ? destino : undefined }, 200, origen);
    } catch (e) {
      return responder({ ok: false, motivo: String((e as Error).message || e) }, 200, origen);
    }
  }

  // 380 · Cuota del asistente: correo propio (tarjeta o SEPA, cualquier periodicidad).
  if (esAsistente(c)) {
    const persona = `${String(c.nombre ?? "").trim()} ${String(c.apellidos ?? "").trim()}`.trim();
    const imp = (Number(c.importe_cent) || 0) / 100;
    const link = `${URL_BASE}entreno/cuota/?t=${encodeURIComponent(c.token)}`;
    const t = textosCuota(c);
    try {
      const resp = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({
          sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
          replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS_EMAIL },
          to: [{ email: destino }],
          subject: (recordatorio ? "Recordatorio: " : "") +
            (t.tarjeta ? "activa tu cuota con tarjeta" : "domicilia tu cuota") + ` · ${String(c.concepto ?? "Club Atletismo Apolana")}`,
          htmlContent: correoAsistenteHtml(persona, imp, link, c, recordatorio),
          textContent: `¡Hola!\n\n${recordatorio ? "Te recordamos que la cuota" : "Te escribimos por la cuota"}${persona ? " de " + persona : ""}: ${String(c.concepto ?? "")}, ${eur(imp)} ${t.cada}.\n\nSe paga ${t.comoTxt}. ${t.primero}${t.fin ? " " + t.fin : ""}\n\n${t.tarjeta ? "Actívala" : "Domicíliala"} aquí: ${link}\n\n${t.seguro}\n\n¿Dudas? Contesta a este mensaje.`,
        }),
      });
      return responder({ ok: resp.ok, destino: resp.ok ? destino : undefined }, 200, origen);
    } catch (e) {
      return responder({ ok: false, motivo: String((e as Error).message || e) }, 200, origen);
    }
  }

  const nombre = String(c.nombre ?? "").trim().split(/\s+/)[0] ?? "";
  const importe = (Number(c.importe_cent) || 0) / 100;
  const mensual = c.periodicidad === "mensual";
  const enlace = `${URL_BASE}entreno/cuota/?t=${encodeURIComponent(c.token)}${mensual ? "&m=1" : ""}`;

  try {
    const resp = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        replyTo: { name: REMITENTE_NOMBRE, email: RESPUESTAS_EMAIL },
        to: [{ email: destino }],
        subject: mensual ? "Domicilia tu cuota mensual · Club Atletismo Apolana"
          : recordatorio ? "Recordatorio: domicilia tu cuota de entrenamiento · Club Atletismo Apolana"
          : "Domicilia tu cuota de entrenamiento (ignora el correo anterior)",
        htmlContent: mensual ? correoMensualHtml(nombre, importe, enlace, String(c.concepto ?? ""))
          : recordatorio ? correoRecordatorioHtml(nombre, importe, enlace)
          : correoHtml(nombre, importe, enlace),
        textContent: mensual
          ? `${nombre ? "¡Hola, familia de " + nombre + "!" : "¡Hola!"}\n\nComo nos pedisteis, la cuota (${eur(importe)} al mes) pasa a domiciliación bancaria (SEPA): metéis el IBAN una vez y se cobra sola cada mes (el mes en curso al domiciliar y luego en esa misma fecha). Tras junio se para sola.\n\nDomiciliad la cuota aquí: ${enlace}\n\n¿Dudas? Contestad a este mensaje.`
          : recordatorio
          ? `${nombre ? "¡Hola, " + nombre + "!" : "¡Hola!"}\n\nTe recordamos que tu cuota de entrenamiento (${eur(importe)} por trimestre) sigue sin domiciliar. Metes tu IBAN una vez y se cobra sola en octubre, enero y abril; tras abril se para sola.\n\nDomicilia tu cuota aquí: ${enlace}\n\n¿Dudas? Contesta a este mensaje.`
          : `${nombre ? "¡Hola, " + nombre + "!" : "¡Hola!"}\n\nPerdona: el correo anterior pedía pagar con tarjeta y fue un error. Ignóralo.\n\nLa forma correcta es por domiciliación (SEPA): metes tu IBAN una vez y la cuota (${eur(importe)} por trimestre) se cobra sola en octubre, enero y abril. Tras abril se para solo.\n\nDomicilia tu cuota aquí: ${enlace}\n\n¿Dudas? Contesta a este mensaje.`,
      }),
    });
    const ok = resp.ok;
    return responder({ ok, destino: ok ? destino : undefined }, 200, origen);
  } catch (e) {
    return responder({ ok: false, motivo: String((e as Error).message || e) }, 200, origen);
  }
});
