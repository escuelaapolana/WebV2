// ============================================================
// escuela-isa-sync · comprobación diaria de «BUENO ISA» (mig 402)
// ------------------------------------------------------------
// Un script de Google (Apps Script, en la cuenta escuelaapolana@gmail.com)
// lee cada día a las 12:30 las hojas de Isa —Inscripción (BUENO ISA),
// Renovación (BUENA ISA) y Escuelas municipales (BUENA ISA + Respuestas)—
// con los COLORES de cada fila y las manda aquí:
//
//   POST { filas: [{hoja, fila, nombre, ap1, ap2, nacimiento, colores[], …}],
//          aplicar?: boolean (por defecto true), probar_correo?: boolean }
//   cabecera  x-sync-token: <token>   (el mismo que guarda Vault como
//             'escuela_sync_token'; lo comprueba la propia función SQL)
//
// La regla vive en la base (escuela_isa_sincronizar): de prueba → confirmado,
// bajas fuera de los grupos, fichas nuevas sin grupo, y lo dudoso se avisa sin
// tocar. Aquí solo se llama y, si ha cambiado algo o hay dudas, se manda UN
// correo con el diseño del club a Andrés.
// (mig 531) Los niños nuevos entran YA con grupo (el de su turno con niños de su
// edad) y quedan en la cola escuela_nuevos_aviso (mig 532).
// (mig 532) A las 11:00 la base llama aquí con x-cron-secret y { avisar_nuevos: true }:
// si hay nuevos pendientes, sale UN correo «N niños nuevos con su grupo» a quien esté
// en escuela_avisos_destinos (para avisar a las familias antes de la prueba) y se
// marcan como avisados; si no hay, no sale nada. Con { prueba: true } va solo a
// Andrés y no marca nada. En la sincronización, probar_correo manda también una
// muestra de ese correo, solo a Andrés.
// (mig 534) A las 20:00 la base llama con { avisar_pruebas: true }: los niños «de prueba»
// que ya han hecho 4 entrenamientos (lista con presente, o días de clase sin lista) salen
// en UN correo informativo a escuela_avisos_destinos y se marcan. Sin nadie, no sale nada.
//
// CLAVES: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / BREVO_API_KEY /
//   CORREO_REMITENTE / CORREO_REMITENTE_NOMBRE / CORREO_RESPUESTAS
// DESPLIEGUE:
//   supabase functions deploy escuela-isa-sync --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const DESTINO = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const PANEL = "https://atletismoapolana.com/admin/escuela-grupos/";
const CRON_SECRET = (Deno.env.get("CRON_SECRET") ?? "").trim();

function iguales(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a), eb = new TextEncoder().encode(b);
  let dif = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) dif |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return dif === 0;
}
async function rpc(nombre: string, cuerpo: unknown = {}): Promise<{ ok: boolean; datos: unknown }> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${nombre}`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(cuerpo),
    signal: AbortSignal.timeout(30000),
  });
  const t = await r.text();
  let datos: unknown = t;
  try { datos = JSON.parse(t); } catch { /* texto */ }
  return { ok: r.ok, datos };
}

// (mig 531) Los nuevos traen ya el grupo que les pone la base por la edad.
type Item = {
  tipo?: string; nombre: string; de?: string; grupos?: string[]; estado?: string; hoja?: string; fila?: number;
  nacimiento?: string; turno?: string;
  grupo?: string | null; grupo_horario?: string | null; grupo_ninos?: number | null;
  alternativa?: string | null; aviso_grupo?: string | null; tutor?: string | null; telefono?: string | null;
  nombre_pila?: string | null; monitor?: string | null;   // (mig 533)
};
type Res = { ok: boolean; aplicado: boolean; filas: number; cambios: Item[]; nuevos: Item[]; dudas: Item[] };

function json(cuerpo: unknown, estado = 200): Response {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: { "Content-Type": "application/json; charset=utf-8" } });
}
function esc(s: unknown): string {
  return String(s ?? "").replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m] as string));
}
function bonito(n: string): string {
  const s = String(n ?? "").trim();
  if (!s || s !== s.toUpperCase()) return s;
  return s.toLowerCase().split(/\s+/).map((w, i) => (i && /^(de|del|la|las|los|y)$/.test(w)) ? w : w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
}

function bloque(titulo: string, color: string, filas: string[]): string {
  if (!filas.length) return "";
  return `
      <tr><td style="padding:14px 24px 4px 24px"><p style="margin:0;font-size:14px;font-weight:700;color:${color}">${esc(titulo)}</p></td></tr>
      <tr><td style="padding:4px 24px 8px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">${filas.join("")}</table>
      </td></tr>`;
}
function fila(principal: string, detalle: string): string {
  return `<tr><td style="padding:10px 16px;border-bottom:1px solid #e7dcc4;font-size:14px;line-height:1.45"><b style="color:#26374B">${principal}</b>${detalle ? `<br><span style="color:#6E6656;font-size:12.5px">${detalle}</span>` : ""}</td></tr>`;
}

// «Martes y jueves 17:30-18:30 · Estadio Joaquín Villar» → «martes y jueves 17:30-18:30»
function dias(horario?: string | null): string {
  const s = String(horario ?? "").split(" · ")[0].trim();
  return s ? s.charAt(0).toLowerCase() + s.slice(1) : "";
}
function fechaEs(iso?: string | null): string {
  const m = String(iso ?? "").match(/^(\d{4})-(\d{2})-(\d{2})/);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : "";
}

// (mig 533) Mensaje para la familia, ya personalizado (texto de Adriana/Andrés, 17-nov):
// grupo y monitor, horario del grupo y acceso por el parking Montessori.
function partesHorario(h?: string | null): { dias: string; ini: string; fin: string } | null {
  const base = String(h ?? "").split(" · ")[0].trim();
  const m = base.match(/^(.*?)\s+(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})/);
  return m ? { dias: m[1].charAt(0).toLowerCase() + m[1].slice(1), ini: m[2], fin: m[3] } : null;
}
function mensajeFamilia(c: Item): string {
  if (!c.grupo) return "";
  const pila = String(c.nombre_pila || String(c.nombre ?? "").split(/\s+/)[0] || "").trim();
  const h = partesHorario(c.grupo_horario);
  const grupo = c.monitor ? `${c.grupo} (${c.monitor})` : String(c.grupo);
  return `¡Buenos días! Hemos recibido el formulario de ${pila}. Como ya puede comenzar el periodo de prueba, os paso su grupo y monitor: *${grupo}*.\n\n` +
    (h ? `Os recordamos que el horario es los ${h.dias} de ${h.ini} a ${h.fin}, y el acceso es por el parking Montessori.\n\n`
       : `Os recordamos que el acceso es por el parking Montessori.\n\n`) +
    `Cualquier duda os la resolvemos con mucho gusto. ¡Nos vemos en la pista!`;
}
// Enlace para abrir WhatsApp con el mensaje ya escrito (lo envía la persona, no la app).
function enlaceWhatsApp(telefono?: string | null, texto?: string): string {
  let d = String(telefono ?? "").replace(/[^\d+]/g, "");
  if (!d || !texto) return "";
  if (d.startsWith("+")) d = d.slice(1);
  else if (d.startsWith("00")) d = d.slice(2);
  else if (/^[6789]\d{8}$/.test(d)) d = "34" + d;
  if (!/^\d{10,15}$/.test(d)) return "";
  return `https://wa.me/${d}?text=${encodeURIComponent(texto)}`;
}

// (mig 531) Correo de los NUEVOS con su grupo, para avisar a las familias antes de la
// prueba. Va a quien esté en escuela_avisos_destinos (las direcciones NO van en el repo).
function correoNuevosHtml(nuevos: Item[], prueba: boolean): string {
  const fecha = new Intl.DateTimeFormat("es-ES", { timeZone: "Europe/Madrid", weekday: "long", day: "numeric", month: "long" }).format(new Date());
  const n = nuevos.length;
  const tarjetas = nuevos.map((c) => {
    const grupo = c.grupo
      ? `<b style="color:#26374B;font-size:15px">${esc(c.grupo)}</b>${c.monitor ? ` <span style="color:#26374B">· monitor: <b>${esc(c.monitor)}</b></span>` : ""}<br><span style="color:#3F3A30">${esc(dias(c.grupo_horario))}</span>${c.grupo_ninos != null ? ` <span style="color:#6E6656;font-size:12.5px">(${c.grupo_ninos} niños en el grupo)</span>` : ""}`
      : `<b style="color:#B3261E">Sin grupo</b> <span style="color:#6E6656">· hay que elegirlo en el panel</span>`;
    const msg = mensajeFamilia(c);
    const wa = enlaceWhatsApp(c.telefono, msg);
    const bloqueMsg = msg ? `
          <tr><td style="padding:10px 16px 0 16px">
            <p style="margin:0 0 4px;font-size:11.5px;font-weight:700;color:#6E6656;letter-spacing:.04em;text-transform:uppercase">Mensaje para la familia</p>
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#ffffff" style="background-color:#ffffff;border:1px solid #e7dcc4;border-radius:8px">
              <tr><td style="padding:10px 12px;font-size:13.5px;line-height:1.5;color:#18181b">${esc(msg).replace(/\n/g, "<br>")}</td></tr>
            </table>
            ${wa ? `<a href="${esc(wa)}" style="display:inline-block;margin-top:8px;background-color:#1F8F4E;color:#ffffff;text-decoration:none;font-weight:700;font-size:13px;padding:8px 14px;border-radius:8px">Abrir en WhatsApp con el mensaje</a>` : ""}
          </td></tr>` : "";
    const tel = c.telefono ? `<a href="tel:${esc(String(c.telefono).replace(/\s+/g, ""))}" style="color:#2F6FA8;text-decoration:none;font-weight:700">${esc(c.telefono)}</a>` : "";
    const familia = [c.tutor ? esc(bonito(c.tutor)) : "", tel].filter(Boolean).join(" · ");
    const avisos = [
      c.aviso_grupo ? esc(c.aviso_grupo) : "",
      c.alternativa ? `También podría ir a <b>${esc(c.alternativa)}</b> (niños de la misma edad).` : "",
    ].filter(Boolean);
    return `
      <tr><td style="padding:6px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:12px 16px 4px 16px;font-size:16px;font-weight:700;color:#18181b">${esc(c.nombre)}${c.estado === "prueba" ? ` <span style="font-size:12px;font-weight:600;color:#8A5307;background-color:#FBF1DE;border-radius:20px;padding:2px 8px">de prueba</span>` : ""}</td></tr>
          <tr><td style="padding:2px 16px;font-size:14px;line-height:1.5">Grupo: ${grupo}</td></tr>
          <tr><td style="padding:2px 16px;font-size:13px;color:#6E6656;line-height:1.5">${[c.nacimiento ? "Fecha de nacimiento: " + esc(fechaEs(c.nacimiento)) : "", c.turno ? "Eligió: " + esc(String(c.turno).replace(/\s*\(.*$/, "").replace(/\s*-\s*Nacidos.*$/i, "")) : ""].filter(Boolean).join(" · ")}</td></tr>
          ${familia ? `<tr><td style="padding:2px 16px;font-size:13px;color:#3F3A30;line-height:1.5">Familia: ${familia}</td></tr>` : ""}
          ${avisos.length ? `<tr><td style="padding:6px 16px 0 16px;font-size:12.5px;color:#8A5307;line-height:1.45">${avisos.join("<br>")}</td></tr>` : ""}
          ${bloqueMsg}
          <tr><td style="padding:0 0 12px 0;font-size:1px;line-height:1px">&nbsp;</td></tr>
        </table>
      </td></tr>`;
  }).join("");
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Escuela de atletismo</td></tr>
      <tr><td style="padding:22px 24px 6px 24px">
        <p style="margin:0 0 6px;font-size:17px;font-weight:700;color:#26374B">${n} ${n === 1 ? "niño nuevo" : "niños nuevos"} con su grupo</p>
        <p style="margin:0 0 10px;color:#71717a;font-size:13px">${esc(fecha)}${prueba ? " · CORREO DE PRUEBA" : ""}</p>
        <p style="margin:0;font-size:14px;line-height:1.5;color:#3F3A30">Acaban de entrar en la app desde las inscripciones. Este es el grupo que les ha puesto la app según su edad y el turno que eligieron, con su monitor y el mensaje ya escrito para cada familia (el botón verde abre WhatsApp con el mensaje; se envía a mano).</p>
      </td></tr>
      ${tarjetas}
      <tr><td style="padding:14px 24px 24px 24px">
        <a href="${PANEL}" style="display:inline-block;background-color:#26374B;color:#ffffff;text-decoration:none;font-weight:700;font-size:14px;padding:11px 18px;border-radius:10px">Abrir los grupos de la escuela</a>
        <p style="margin:14px 0 0;color:#a1a1aa;font-size:11.5px">La app elige, entre los grupos de su turno, el de los niños de edad más parecida; si hay dos iguales, el que tiene menos niños. Si alguno no encaja, se cambia en el panel.</p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;
}

async function destinosNuevos(): Promise<string[]> {
  try {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/escuela_avisos_destinos?select=email&activo=eq.true`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    const d = r.ok ? await r.json() : [];
    return Array.isArray(d) ? d.map((x: { email?: string }) => String(x.email ?? "").trim()).filter(Boolean) : [];
  } catch (e) {
    console.error("[escuela-isa-sync] destinos:", e);
    return [];
  }
}

async function enviarNuevos(nuevos: Item[], prueba: boolean): Promise<boolean> {
  if (!BREVO_API_KEY || !nuevos.length) return false;
  // En pruebas solo le llega a Andrés; de verdad, a la lista de destinos.
  const para = prueba ? [DESTINO] : await destinosNuevos();
  if (!para.length) return false;
  const n = nuevos.length;
  const asunto = `${prueba ? "Prueba · " : ""}Escuela · ${n} ${n === 1 ? "niño nuevo" : "niños nuevos"} con su grupo · Apolana`;
  const texto = nuevos.map((c) => {
    const msg = mensajeFamilia(c);
    return `- ${c.nombre}${c.estado === "prueba" ? " (de prueba)" : ""}: ${c.grupo ? c.grupo + (c.monitor ? " (" + c.monitor + ")" : "") + " · " + dias(c.grupo_horario) : "SIN GRUPO"}${c.telefono ? " · familia " + c.telefono : ""}${c.aviso_grupo ? " · " + c.aviso_grupo : ""}${msg ? "\n  Mensaje: " + msg.replace(/\n+/g, " ") : ""}`;
  }).join("\n\n");
  try {
    const res = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        to: para.map((email) => ({ email })),
        replyTo: { email: DESTINO },
        subject: asunto,
        htmlContent: correoNuevosHtml(nuevos, prueba),
        textContent: texto,
      }),
      signal: AbortSignal.timeout(20000),
    });
    if (!res.ok) console.error("[escuela-isa-sync] Brevo nuevos:", res.status, await res.text().catch(() => ""));
    return res.ok;
  } catch (e) {
    console.error("[escuela-isa-sync] correo nuevos:", e);
    return false;
  }
}

// (mig 534) Niños de prueba que acaban de hacer su 4.º entrenamiento. Solo INFORMA a
// quien esté en escuela_avisos_destinos (Adriana): ella pregunta a la familia si formaliza
// y se encarga de lo demás («solamente tienes que informarme a mí», 17-nov).
type Sesion = { fecha: string; como: string };
type Cumplido = {
  atleta_id: string; nombre: string; nombre_pila?: string | null;
  grupo?: string | null; grupo_horario?: string | null; monitor?: string | null;
  alta?: string | null; cuarto_dia?: string | null; sesiones?: Sesion[] | null; faltas?: string[] | null;
  tutor?: string | null; telefono?: string | null;
};
function diaCorto(iso?: string | null): string {
  const m = String(iso ?? "").match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!m) return "";
  const f = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], 12));
  const d = new Intl.DateTimeFormat("es-ES", { timeZone: "UTC", weekday: "short" }).format(f).replace(".", "");
  return `${d} ${+m[3]}/${+m[2]}`;
}
function correoPruebasHtml(lista: Cumplido[], prueba: boolean): string {
  const fecha = new Intl.DateTimeFormat("es-ES", { timeZone: "Europe/Madrid", weekday: "long", day: "numeric", month: "long" }).format(new Date());
  const n = lista.length;
  const tarjetas = lista.map((c) => {
    const grupo = c.grupo
      ? `<b style="color:#26374B">${esc(c.grupo)}</b>${c.monitor ? ` · monitor: <b style="color:#26374B">${esc(c.monitor)}</b>` : ""}${c.grupo_horario ? ` <span style="color:#6E6656">(${esc(dias(c.grupo_horario))})</span>` : ""}`
      : `<span style="color:#6E6656">sin grupo</span>`;
    const ses = (c.sesiones ?? []).map((s) => `${esc(diaCorto(s.fecha))}${s.como === "vino" ? " ✓" : ` <span style="color:#8A5307">(sin lista)</span>`}`).join(" · ");
    const faltas = (c.faltas ?? []).length ? `Faltó: ${(c.faltas ?? []).map((f) => esc(diaCorto(f))).join(", ")}` : "";
    const tel = c.telefono ? `<a href="tel:${esc(String(c.telefono).replace(/\s+/g, ""))}" style="color:#2F6FA8;text-decoration:none;font-weight:700">${esc(c.telefono)}</a>` : "";
    const familia = [c.tutor ? esc(bonito(c.tutor)) : "", tel].filter(Boolean).join(" · ");
    return `
      <tr><td style="padding:6px 24px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px">
          <tr><td style="padding:12px 16px 4px 16px;font-size:16px;font-weight:700;color:#18181b">${esc(c.nombre)}</td></tr>
          <tr><td style="padding:2px 16px;font-size:14px;line-height:1.5">Grupo: ${grupo}</td></tr>
          <tr><td style="padding:2px 16px;font-size:13px;color:#3F3A30;line-height:1.5">Entrenamientos de prueba: ${ses}</td></tr>
          <tr><td style="padding:2px 16px;font-size:13px;color:#6E6656;line-height:1.5">${[c.alta ? "En la app desde el " + esc(fechaEs(c.alta)) : "", faltas].filter(Boolean).join(" · ")}</td></tr>
          ${familia ? `<tr><td style="padding:2px 16px 12px 16px;font-size:13px;color:#3F3A30;line-height:1.5">Familia: ${familia}</td></tr>` : `<tr><td style="padding:0 0 12px 0;font-size:1px;line-height:1px">&nbsp;</td></tr>`}
        </table>
      </td></tr>`;
  }).join("");
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Escuela de atletismo</td></tr>
      <tr><td style="padding:22px 24px 6px 24px">
        <p style="margin:0 0 6px;font-size:17px;font-weight:700;color:#26374B">${n} ${n === 1 ? "niño ha terminado" : "niños han terminado"} los 4 días de prueba</p>
        <p style="margin:0 0 10px;color:#71717a;font-size:13px">${esc(fecha)}${prueba ? " · CORREO DE PRUEBA" : ""}</p>
        <p style="margin:0;font-size:14px;line-height:1.5;color:#3F3A30">Ya han hecho su 4.º entrenamiento de prueba y siguen «de prueba» en la app: falta saber si formalizan la inscripción.</p>
      </td></tr>
      ${tarjetas}
      <tr><td style="padding:14px 24px 24px 24px">
        <a href="${PANEL}" style="display:inline-block;background-color:#26374B;color:#ffffff;text-decoration:none;font-weight:700;font-size:14px;padding:11px 18px;border-radius:10px">Abrir los grupos de la escuela</a>
        <p style="margin:14px 0 0;color:#a1a1aa;font-size:11.5px">Cuentan los días que el entrenador pasó lista y lo marcó presente (✓). En los grupos que ese día no pasaron lista (los de las 18:30 no la pasan), cuenta el día de clase desde que entró en la app. Llega un correo cada noche a las 20:00, solo si alguien ha terminado ese día.</p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;
}
async function enviarPruebas(lista: Cumplido[], prueba: boolean): Promise<boolean> {
  if (!BREVO_API_KEY || !lista.length) return false;
  const para = prueba ? [DESTINO] : await destinosNuevos();
  if (!para.length) return false;
  const n = lista.length;
  const asunto = `${prueba ? "Prueba · " : ""}Escuela · ${n} ${n === 1 ? "niño ha terminado" : "niños han terminado"} la prueba · Apolana`;
  const texto = lista.map((c) =>
    `- ${c.nombre}: ${c.grupo ? c.grupo + (c.monitor ? " (" + c.monitor + ")" : "") : "sin grupo"} · prueba: ${(c.sesiones ?? []).map((s) => diaCorto(s.fecha) + (s.como === "vino" ? "" : " (sin lista)")).join(", ")}${c.telefono ? " · familia " + (c.tutor ? bonito(c.tutor) + " " : "") + c.telefono : ""}`
  ).join("\n");
  try {
    const res = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        to: para.map((email) => ({ email })),
        replyTo: { email: DESTINO },
        subject: asunto,
        htmlContent: correoPruebasHtml(lista, prueba),
        textContent: texto,
      }),
      signal: AbortSignal.timeout(20000),
    });
    if (!res.ok) console.error("[escuela-isa-sync] Brevo pruebas:", res.status, await res.text().catch(() => ""));
    return res.ok;
  } catch (e) {
    console.error("[escuela-isa-sync] correo pruebas:", e);
    return false;
  }
}

function correoHtml(r: Res, prueba: boolean): string {
  const fecha = new Intl.DateTimeFormat("es-ES", { timeZone: "Europe/Madrid", weekday: "long", day: "numeric", month: "long" }).format(new Date());
  const confirmados = r.cambios.filter((c) => c.tipo === "confirmado");
  const bajas = r.cambios.filter((c) => c.tipo === "baja");
  const aPrueba = r.cambios.filter((c) => c.tipo === "a prueba");   // mig 448: fila sin acabar de pintar
  const partes = [
    confirmados.length ? `${confirmados.length} confirmado${confirmados.length === 1 ? "" : "s"}` : "",
    bajas.length ? `${bajas.length} baja${bajas.length === 1 ? "" : "s"}` : "",
    aPrueba.length ? `${aPrueba.length} vuelve${aPrueba.length === 1 ? "" : "n"} a prueba` : "",
    r.nuevos.length ? `${r.nuevos.length} nuevo${r.nuevos.length === 1 ? "" : "s"}` : "",
    r.dudas.length ? `${r.dudas.length} por revisar` : "",
  ].filter(Boolean);
  const titular = partes.length ? `Escuela: ${partes.join(" · ")}` : "Escuela: sin cambios (correo de prueba)";
  return `<!doctype html><html lang="es"><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Escuela (BUENO ISA)</td></tr>
      <tr><td style="padding:22px 24px 4px 24px">
        <p style="margin:0 0 6px;font-size:17px;font-weight:700;color:#26374B">${esc(titular)}</p>
        <p style="margin:0;color:#71717a;font-size:13px">${esc(fecha)} · comprobación de las 12:30${prueba ? " · prueba" : ""}${r.aplicado ? "" : " · NO aplicado (solo simulación)"}</p>
      </td></tr>
      ${bloque("Confirmados (ya no salen «de prueba»)", "#1E7A3D", confirmados.map((c) => fila(esc(bonito(c.nombre)), "")))}
      ${bloque("Vuelven a prueba (en BUENO ISA su fila no está entera en verde)", "#8A5307", aPrueba.map((c) => fila(esc(bonito(c.nombre)), esc(c.de || ""))))}
      ${bloque("Bajas (fuera de sus grupos)", "#B3261E", bajas.map((c) => fila(esc(bonito(c.nombre)), (c.grupos && c.grupos.length) ? "Estaba en " + esc(c.grupos.join(", ")) : "")))}
      ${bloque("Nuevos (con el grupo que les ha puesto la app)", "#2F6FA8", r.nuevos.map((c) => fila(esc(c.nombre) + (c.estado === "prueba" ? " · de prueba" : ""), esc([c.grupo ? "→ " + c.grupo + " (" + dias(c.grupo_horario) + ")" : "SIN GRUPO: asígnalo en el panel", c.nacimiento ? "año " + c.nacimiento.slice(0, 4) : "", c.aviso_grupo || ""].filter(Boolean).join(" · ")))))}
      ${bloque("Por revisar (no se ha tocado)", "#8A5307", r.dudas.map((c) => fila(esc(bonito(c.nombre)), esc((c.tipo || "") + (c.de ? " · " + c.de : "")))))}
      <tr><td style="padding:14px 24px 24px 24px">
        <a href="${PANEL}" style="display:inline-block;background-color:#26374B;color:#ffffff;text-decoration:none;font-weight:700;font-size:14px;padding:11px 18px;border-radius:10px">Abrir los grupos de la escuela</a>
        <p style="margin:14px 0 0;color:#a1a1aa;font-size:11.5px">${r.filas} filas leídas de las hojas de Isa. Si no cambia nada, no llega correo.</p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;
}

async function enviarCorreo(r: Res, prueba: boolean): Promise<boolean> {
  if (!BREVO_API_KEY) return false;
  const n = r.cambios.length + r.nuevos.length + r.dudas.length;
  const asunto = n ? `Escuela · ${n} cambio${n === 1 ? "" : "s"} en BUENO ISA · Apolana` : "Prueba · escuela (BUENO ISA) · Apolana";
  const texto = [
    ...r.cambios.map((c) => `- ${c.tipo === "baja" ? "BAJA" : "Confirmado"}: ${bonito(c.nombre)}`),
    ...r.nuevos.map((c) => `- Nuevo sin grupo: ${c.nombre} (${c.turno ?? ""})`),
    ...r.dudas.map((c) => `- Revisar: ${bonito(c.nombre)} · ${c.tipo}`),
  ].join("\n") || "Sin cambios.";
  try {
    const res = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        to: [{ email: DESTINO }],
        subject: asunto,
        htmlContent: correoHtml(r, prueba),
        textContent: texto,
      }),
      signal: AbortSignal.timeout(20000),
    });
    if (!res.ok) console.error("[escuela-isa-sync] Brevo:", res.status, await res.text().catch(() => ""));
    return res.ok;
  } catch (e) {
    console.error("[escuela-isa-sync] correo:", e);
    return false;
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ error: "metodo" }, 405);
  if (!SUPABASE_URL || !SERVICE_KEY) return json({ error: "config" }, 503);

  // (mig 532) Correo diario de las 11:00 con los nuevos pendientes (lo lanza la base).
  const secreto = (req.headers.get("x-cron-secret") ?? "").trim();
  if (secreto) {
    if (!CRON_SECRET || !iguales(secreto, CRON_SECRET)) return json({ error: "secreto" }, 401);
    let c: Record<string, unknown> = {};
    try { c = await req.json(); } catch { /* vacío */ }
    const prueba = c.prueba === true;
    // (mig 534) 20:00 · niños que acaban de hacer su 4.º entrenamiento de prueba.
    if (c.avisar_pruebas === true) {
      const p = await rpc("escuela_pruebas_revisar");
      if (!p.ok || !Array.isArray(p.datos)) {
        console.error("[escuela-isa-sync] pruebas:", JSON.stringify(p.datos).slice(0, 300));
        return json({ error: "base" }, 500);
      }
      // Con prueba:true se puede pasar una lista inventada (muestra): solo le llega a Andrés y no marca nada.
      const lista = (prueba && Array.isArray(c.lista)) ? c.lista as Cumplido[] : p.datos as Cumplido[];
      if (!lista.length) return json({ terminados: 0, correo: false });
      const enviado = await enviarPruebas(lista, prueba);
      let marcados = 0;
      if (enviado && !prueba) {
        const m = await rpc("escuela_pruebas_marcar", { p_ids: lista.map((x) => x.atleta_id) });
        marcados = m.ok ? Number(m.datos) || 0 : 0;
        if (!m.ok) console.error("[escuela-isa-sync] marcar pruebas:", JSON.stringify(m.datos).slice(0, 300));
      }
      return json({ terminados: lista.length, correo: enviado, prueba, marcados });
    }
    if (c.avisar_nuevos !== true) return json({ error: "que" }, 400);
    const p = await rpc("escuela_nuevos_pendientes");
    if (!p.ok || !Array.isArray(p.datos)) {
      console.error("[escuela-isa-sync] pendientes:", JSON.stringify(p.datos).slice(0, 300));
      return json({ error: "base" }, 500);
    }
    const lista = p.datos as (Item & { atleta_id: string })[];
    if (!lista.length) return json({ nuevos: 0, correo: false });
    const enviado = await enviarNuevos(lista, prueba);
    let marcados = 0;
    if (enviado && !prueba) {
      const m = await rpc("escuela_nuevos_marcar", { p_ids: lista.map((x) => x.atleta_id) });
      marcados = m.ok ? Number(m.datos) || 0 : 0;
      if (!m.ok) console.error("[escuela-isa-sync] marcar:", JSON.stringify(m.datos).slice(0, 300));
    }
    return json({ nuevos: lista.length, correo: enviado, prueba, marcados });
  }

  const token = (req.headers.get("x-sync-token") ?? "").trim();
  if (!token) return json({ error: "token" }, 401);

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { return json({ error: "json" }, 400); }
  const filas = Array.isArray(cuerpo.filas) ? cuerpo.filas : null;
  if (!filas || !filas.length) return json({ error: "sin filas" }, 400);
  if (filas.length > 3000) return json({ error: "demasiadas filas" }, 413);
  const aplicar = cuerpo.aplicar !== false;
  const probarCorreo = cuerpo.probar_correo === true;

  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/escuela_isa_sincronizar`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ p_token: token, p_filas: filas, p_aplicar: aplicar }),
    signal: AbortSignal.timeout(60000),
  });
  const t = await r.text();
  if (!r.ok) {
    if (/token/.test(t)) return json({ error: "token" }, 401);
    console.error("[escuela-isa-sync] rpc:", r.status, t.slice(0, 400));
    return json({ error: "base", detalle: t.slice(0, 300) }, 500);
  }
  const res = JSON.parse(t) as Res;
  // (mig 518) Con la «Marca temporal» de cada fila se rehace la curva día a día
  // de la temporada en curso («Ritmo de inscripciones» del Histórico). Si falla,
  // no estropea la sincronización: solo se queda sin actualizar la gráfica.
  if (aplicar) {
    try {
      await fetch(`${SUPABASE_URL}/rest/v1/rpc/escuela_ritmo_registrar`, {
        method: "POST",
        headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({ p_token: token, p_filas: filas }),
        signal: AbortSignal.timeout(30000),
      });
    } catch (e) { console.error("[escuela-isa-sync] ritmo:", e); }
  }
  // Las dudas se repiten cada día hasta que alguien las resuelve: solo provocan
  // correo si son NUEVAS respecto a la comprobación aplicada anterior.
  let dudasNuevas = res.dudas.length;
  try {
    const rl = await fetch(`${SUPABASE_URL}/rest/v1/escuela_sync_log?select=resumen&aplicado=eq.true&order=id.desc&offset=1&limit=1`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    const prev = rl.ok ? await rl.json() : [];
    if (Array.isArray(prev) && prev[0]?.resumen?.dudas) {
      const antes = new Set((prev[0].resumen.dudas as Item[]).map((d) => `${d.tipo}|${d.nombre}`));
      dudasNuevas = res.dudas.filter((d) => !antes.has(`${d.tipo}|${d.nombre}`)).length;
    }
  } catch { /* si falla, se avisa de todas */ }
  const hay = res.cambios.length + res.nuevos.length + dudasNuevas > 0;
  const correo = (hay || probarCorreo) ? await enviarCorreo(res, probarCorreo) : false;
  // (mig 532) El correo de los nuevos con su grupo NO sale aquí: quedan en la cola y
  // salen juntos a las 11:00. Con probar_correo, una muestra solo para Andrés.
  const correoNuevos = res.nuevos.length && probarCorreo ? await enviarNuevos(res.nuevos, true) : false;
  return json({ ...res, correo_enviado: correo, correo_nuevos_enviado: correoNuevos });
});
