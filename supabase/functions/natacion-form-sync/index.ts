// ============================================================
// natacion-form-sync · solicitudes de natación desde los formularios (migs 475, 510)
// ------------------------------------------------------------
// Dos formas de llamarla:
//   · el script de Google (Apps Script en escuelaapolana@gmail.com) cada hora:
//       POST { filas: [{origen:'Escuela'|'Máster', fila, datos:[[título, valor]…]}],
//              aplicar?: boolean (por defecto true) }
//       cabecera x-sync-token (el mismo token que BUENO ISA; lo comprueba la SQL)
//   · pg_cron a las 9:30 (cron_llamar_edge, cabecera x-cron-secret): solo el repaso.
//     Con { muestra: true } manda el correo con TODO lo pendiente (aunque ya se
//     avisara) y no marca nada: para ver cómo queda.
//
// Lo que hace:
//   1. guarda las respuestas nuevas y da de alta de PRUEBA a quien tiene hueco
//      (natacion_form_sincronizar);
//   2. mira quién vino a su clase de prueba, quién faltó, quién ya tiene cuota y
//      quién ya no está en ninguna franja (natacion_solicitudes_revisar);
//   3. si hay algo que aún no se ha avisado, manda UN correo y lo marca como avisado.
//      Los mensajes a las familias se mandan desde otro WhatsApp, así que el correo
//      lo trae todo (mig 510): quién viene a probar y qué día (para los monitores) y
//      el mensaje de cada familia ya escrito, para copiarlo. Las plantillas son las
//      mismas que las de la pantalla (portal/natacion-solicitudes, función mensaje):
//      si se cambia una, cambiar la otra.
//
// Destinatarios: CORREO_RESPUESTAS (o andres.apolana@) y los activos de la tabla
//   natacion_avisos_destinos (mig 511; las direcciones no van al repo). Uno por
//   persona, sin ver a los demás.
// CLAVES: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / CRON_SECRET / BREVO_API_KEY /
//   CORREO_REMITENTE / CORREO_REMITENTE_NOMBRE / CORREO_RESPUESTAS
// DESPLIEGUE:
//   supabase functions deploy natacion-form-sync --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const CRON_SECRET = (Deno.env.get("CRON_SECRET") ?? "").trim();
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const DESTINO = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
const PANEL = "https://atletismoapolana.com/portal/natacion-solicitudes/";

type Franja = { dia: number; hora: string; monitores?: string | null };
type Aviso = {
  id: string; que: "prueba" | "revisar" | "probo" | "plazo" | "falto"; origen: string; nombre: string;
  nombre_pila?: string | null; tutor?: string | null; socio?: boolean | null; nivel?: string | null;
  nacimiento?: string | null; pide?: string | null; motivo?: string | null; observaciones?: string | null;
  franjas?: string | null; franjas_det?: Franja[]; dias?: number;
  fecha_prueba?: string | null; vino_el?: string | null; falto_el?: string | null; espera_hasta?: string | null;
};
type Cita = {
  id: string; origen: string; nombre: string; nacimiento?: string | null; nivel?: string | null;
  observaciones?: string | null; fecha: string; dia?: number | null; hora?: string | null;
  monitores?: string | null; calle?: string | null;
};
type Tarifa = { dias: number; socio: number | null; no_socio: number | null };
type Datos = { avisos: Aviso[]; agenda: Cita[]; tarifas: Record<string, Tarifa[]> };

function json(cuerpo: unknown, estado = 200): Response {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: { "Content-Type": "application/json; charset=utf-8" } });
}
function iguales(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a), eb = new TextEncoder().encode(b);
  let dif = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) dif |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return dif === 0;
}
function esc(s: unknown): string {
  return String(s ?? "").replace(/[&<>"]/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[m] as string));
}

// ------------------------------------------------------------ mensajes
// Copia de las plantillas de portal/natacion-solicitudes (función mensaje).
const DIAS = ["", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"];
const MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
const TARIFA_SOCIO: Record<number, number> = { 1: 35, 2: 45, 3: 55 };   // respaldo
const RECARGO_NO_SOCIO = 15;

function capital(n: unknown): string {
  const s = String(n ?? "").trim();
  if (!s) return s;
  if (s !== s.toUpperCase() && s !== s.toLowerCase()) return s;
  return s.toLowerCase().split(/\s+/).map((w, i) => (i && /^(de|del|la|las|los|y)$/.test(w)) ? w : w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
}
function mayus1(s: string): string { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }
function lista(l: string[]): string { return l.length > 1 ? l.slice(0, -1).join(", ") + " y " + l[l.length - 1] : (l[0] || ""); }
function primero(s: unknown): string { return capital(String(s ?? "").trim().split(/\s+/)[0] || ""); }
function dow(iso: string): number { const p = iso.slice(0, 10).split("-"); const d = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2])).getUTCDay(); return d === 0 ? 7 : d; }
function fechaLarga(iso?: string | null): string {
  if (!iso) return "";
  const p = String(iso).slice(0, 10).split("-");
  return DIAS[dow(String(iso))] + " " + (+p[2]) + " de " + MESES[+p[1] - 1];
}
function hhmm(h: unknown): string { return String(h ?? "").slice(0, 5); }
// Por la FECHA (4-nov): de octubre a mayo, de lunes a viernes en Vía Parque y el sábado
// (Máster 8:30, la única) en Monte Tossal; en verano (junio a septiembre), Monte Tossal,
// como dice la web. Sin fecha, vale el día de la franja.
function piscina(fecha?: string | null, dia?: number | null): string {
  const p = fecha ? String(fecha).slice(0, 10).split("-") : null;
  const m = p ? +p[1] : new Date().getMonth() + 1;
  const sab = p ? new Date(Date.UTC(+p[0], +p[1] - 1, +p[2])).getUTCDay() === 6 : dia === 6;
  return (m >= 6 && m <= 9) || sab ? "la piscina Monte Tossal" : "la piscina Vía Parque";
}
function monitoresTxt(m?: string | null): string {
  const l = String(m ?? "").split(/\s*(?:\+|,|\/|\sy\s)\s*/).map((x) => x.trim()).filter(Boolean);
  if (!l.length) return "";
  return (l.length === 1 ? "La clase la lleva " : "La clase la llevan ") + (l.length === 1 ? l[0] : l.slice(0, -1).join(", ") + " y " + l[l.length - 1]) + ".";
}
function eur(n: number): string { return (Math.round(n * 100) / 100).toLocaleString("es-ES") + " €"; }
function franjaPrueba(a: Aviso): Franja | null {
  const l = a.franjas_det || [];
  const d = a.fecha_prueba ? dow(a.fecha_prueba) : 0;
  return l.filter((f) => f.dia === d)[0] || l[0] || null;
}
function pideTxt(a: Aviso): string {
  const l = (a.franjas_det || []).map((f) => DIAS[f.dia] + " " + hhmm(f.hora));
  return l.length ? lista(l) : (a.pide || "sin horario");
}
function tarifa(tarifas: Record<string, Tarifa[]>, tipo: string, dias: number) {
  const t = (tarifas[tipo] || []).filter((x) => x.dias === dias)[0];
  const m = t && t.socio != null ? Number(t.socio) : TARIFA_SOCIO[Math.min(Math.max(dias, 1), 3)];
  const ns = t && t.no_socio != null ? Number(t.no_socio) : m + RECARGO_NO_SOCIO;
  return { mes: m, trim: 3 * m - 15, mesNS: ns, trimNS: 3 * ns - 15 };
}

function mensaje(a: Aviso, que: "prueba" | "formaliza" | "espera" | "sin_hueco", tarifas: Record<string, Tarifa[]>): string {
  const escuela = a.origen !== "Máster";
  const sal = escuela ? primero(a.tutor) : primero(a.nombre_pila);
  const hola = "¡Hola" + (sal ? ", " + sal : "") + "!";
  const nino = primero(a.nombre_pila), grupo = pideTxt(a);
  if (que === "prueba") {
    const f = franjaPrueba(a);
    const cuando = (a.fecha_prueba ? "el " + fechaLarga(a.fecha_prueba) : "el próximo " + (f ? DIAS[f.dia] : "")) + (f ? " a las " + hhmm(f.hora) : "");
    const pis = piscina(a.fecha_prueba, f && f.dia).replace(/^la /, ""), mon = monitoresTxt(f && f.monitores);
    const comun = "• *Qué traer:* bañador, gorro, toalla, chanclas y gafas de agua.\n" +
      "• No hay taquillas: después de cambiarse en el vestuario, se entra a la piscina con la mochila y se deja junto a la zona de entrenamiento.\n\n";
    const fin = "Para cualquier cuestión, nos dice. ¡Nos vemos en el agua! 💦\n\nNatación Apolana";
    return escuela
      ? hola + " 👋 Hemos recibido su formulario de la Escuela de Natación de Apolana. ¡Nos alegramos mucho!\n\n" +
        nino + " puede venir a hacer su *clase de prueba " + cuando + "* en la *" + pis + "*." + (mon ? " " + mon : "") + "\n\n" +
        "Información a tener en cuenta:\n" +
        "• Estén *15 minutos antes* en la recepción de la instalación, para poder acceder con " + nino + " a los vestuarios e indicarles el lugar de encuentro.\n" +
        "• *Acceso a la piscina:* si han ido antes a alguna piscina municipal, puede que les pidan su número de abonado para vincularlo con el Club Apolana y que no les cobren la entrada. " +
        "Si no, tiene que venir el padre, la madre o el tutor legal con su DNI o pasaporte *original* (a veces piden el libro de familia) y el de " + nino + ". Con eso les dan de alta en el momento, sin coste.\n" +
        comun + "Toda la información, en https://atletismoapolana.com/escuela-natacion/\n" + fin
      : hola + " 👋 Hemos recibido su formulario de Natación Máster de Apolana. ¡Nos alegramos mucho!\n\n" +
        "Puede venir a hacer su *clase de prueba " + cuando + "* en la *" + pis + "*." + (mon ? " " + mon : "") + "\n\n" +
        "Información a tener en cuenta:\n" +
        "• Esté *15 minutos antes* en la recepción de la instalación, para poder acceder a los vestuarios e indicarle el lugar de encuentro.\n" +
        "• *Acceso a la piscina:* si ha ido antes a alguna piscina municipal, puede que le pidan su número de abonado para vincularlo con el Club Apolana y que no le cobren la entrada. " +
        "Si no, traiga su DNI o pasaporte *original* y le dan de alta en el momento, sin coste.\n" +
        comun + "Toda la información, en https://atletismoapolana.com/natacion/\n" + fin;
  }
  if (que === "formaliza") {
    const dias = a.dias || (a.franjas_det || []).length || 1;
    const t = tarifa(tarifas, a.origen, dias), dtxt = dias === 1 ? "1 día" : dias + " días";
    let precio: string;
    if (!escuela && a.socio === false) precio = eur(t.mesNS) + " al mes o " + eur(t.trimNS) + " al trimestre";
    else if (!escuela && a.socio == null) precio = eur(t.mes) + " al mes o " + eur(t.trim) + " al trimestre si eres socio del club (si no, " + eur(t.mesNS) + " o " + eur(t.trimNS) + ")";
    else precio = eur(t.mes) + " al mes o " + eur(t.trim) + " al trimestre";
    return escuela
      ? hola + " ¿Qué tal le fue a " + nino + " la clase de prueba? Si queréis que siga, formalizamos la inscripción. Con " + dtxt + " a la semana, la cuota es de " + precio + ".\n\n¿Seguís con nosotros? ¿Y qué preferís, mensual o trimestral? En cuanto nos digáis, os mandamos el enlace para domiciliarla.\n\nUn saludo,\nNatación Apolana"
      : hola + " ¿Qué tal la clase de prueba? Si quieres seguir, formalizamos la inscripción. Con " + dtxt + " a la semana, la cuota es de " + precio + ".\n\n¿Te quedas con nosotros? ¿Y qué prefieres, mensual o trimestral? En cuanto nos digas, te mandamos el enlace para domiciliarla.\n\nUn saludo,\nNatación Apolana";
  }
  if (que === "espera") {
    return escuela
      ? hola + " Hemos revisado la solicitud de " + nino + " para el grupo de " + grupo + ". Ahora mismo está completo y todavía no puede empezar. Vamos a revisar su caso y en un plazo de 15 días os damos una respuesta. ¡Gracias por la paciencia!\n\nUn saludo,\nNatación Apolana"
      : hola + " Hemos revisado tu solicitud para el grupo de " + grupo + ". Ahora mismo está completo y todavía no puedes empezar. Vamos a revisar tu caso y en un plazo de 15 días te damos una respuesta. ¡Gracias por la paciencia!\n\nUn saludo,\nNatación Apolana";
  }
  return escuela
    ? hola + " Pasadas estas dos semanas, seguimos sin hueco en el grupo de " + nino + "; lo sentimos. Si más adelante seguís interesados, escribidnos y os contamos cómo va el cupo. Y si no, ¡nos vemos en verano!\n\nUn saludo,\nNatación Apolana"
    : hola + " Pasadas estas dos semanas, seguimos sin hueco en el grupo que pedías; lo sentimos. Si más adelante te sigue interesando, escríbenos y te contamos cómo va el cupo. Y si no, ¡nos vemos en verano!\n\nUn saludo,\nNatación Apolana";
}

// ------------------------------------------------------------ correo
async function rpc(nombre: string, cuerpo: unknown): Promise<{ ok: boolean; estado: number; datos: any; texto: string }> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${nombre}`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(cuerpo ?? {}),
    signal: AbortSignal.timeout(90000),
  });
  const texto = await r.text();
  let datos: any = null;
  try { datos = JSON.parse(texto); } catch { /* texto */ }
  return { ok: r.ok, estado: r.status, datos, texto };
}

function quien(nombre: string, nacimiento: string | null | undefined, origen: string): string {
  const anio = nacimiento ? ` (${String(nacimiento).slice(0, 4)})` : "";
  return `${esc(capital(nombre))}${anio} · ${esc(origen === "Máster" ? "máster" : "escuela")}`;
}
function seccion(titulo: string, color: string, explica: string, cuerpo: string): string {
  if (!cuerpo) return "";
  return `
      <tr><td style="padding:18px 24px 4px 24px"><p style="margin:0;font-size:15px;font-weight:700;color:${color}">${esc(titulo)}</p>
        ${explica ? `<p style="margin:3px 0 0;font-size:12.5px;color:#71717a">${esc(explica)}</p>` : ""}</td></tr>
      <tr><td style="padding:6px 24px 6px 24px">${cuerpo}</td></tr>`;
}
// Mensaje para copiar: caja blanca con el texto tal cual (los *asteriscos* son la
// negrita de WhatsApp).
function cajaMensaje(texto: string): string {
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#ffffff" style="background-color:#ffffff;border:1px solid #d9cfba;border-radius:8px;margin-top:8px">
      <tr><td style="padding:12px 14px;font-size:13.5px;line-height:1.5;color:#18181b;white-space:pre-wrap;word-break:break-word">${esc(texto)}</td></tr></table>`;
}
function tarjeta(a: Aviso, detalle: string, extra: string): string {
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px;margin-bottom:10px">
      <tr><td style="padding:12px 14px;font-size:14px;line-height:1.45">
        <b style="color:#26374B">${quien(a.nombre, a.nacimiento, a.origen)}</b>
        ${detalle ? `<br><span style="color:#6E6656;font-size:12.5px">${detalle}</span>` : ""}
        ${extra}
        <p style="margin:8px 0 0;font-size:12px"><a href="${PANEL}?id=${encodeURIComponent(a.id)}" style="color:#2F6FA8">Abrir en la app</a></p>
      </td></tr></table>`;
}
function agendaHtml(ag: Cita[]): string {
  if (!ag.length) return "";
  const porDia: Record<string, Cita[]> = {};
  ag.forEach((c) => { (porDia[c.fecha] = porDia[c.fecha] || []).push(c); });
  return Object.keys(porDia).sort().map((f) => {
    const filas = porDia[f].map((c) => {
      const calle = c.calle ? (c.calle === "Vaso" ? "vaso" : "calle " + String(c.calle).replace("C", "")) : "";
      const donde = [hhmm(c.hora), piscina(c.fecha, c.dia).replace(/^la piscina /, ""), c.monitores ? "con " + c.monitores.replace(/\s*\+\s*/g, " y ") : ""].filter(Boolean).join(" · ");
      const que = [c.nivel || "", calle].filter(Boolean).join(", ");
      return `<tr><td style="padding:8px 14px;border-top:1px solid #e7dcc4;font-size:13.5px;line-height:1.45">
          <b style="color:#26374B">${esc(donde)}</b><br>${quien(c.nombre, c.nacimiento, c.origen)}${que ? ` · ${esc(que)}` : ""}
          ${c.observaciones ? `<br><span style="color:#8A5307;font-size:12.5px">Observaciones: ${esc(c.observaciones)}</span>` : ""}</td></tr>`;
    }).join("");
    return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F1EADC" style="background-color:#F1EADC;border-radius:10px;margin-bottom:10px">
        <tr><td style="padding:10px 14px 6px 14px;font-size:14px;font-weight:700;color:#26374B">${esc(mayus1(fechaLarga(f)))}</td></tr>${filas}</table>`;
  }).join("");
}

function correoHtml(d: Datos, muestra: boolean): { asunto: string; html: string; texto: string } {
  const de = (q: Aviso["que"]) => d.avisos.filter((a) => a.que === q);
  const prueba = de("prueba"), revisar = de("revisar"), probo = de("probo"), plazo = de("plazo"), falto = de("falto");
  const partes = [
    prueba.length ? `${prueba.length} de prueba` : "",
    revisar.length ? `${revisar.length} por revisar` : "",
    probo.length ? `${probo.length} ya ${probo.length === 1 ? "probó" : "probaron"}` : "",
    falto.length ? `${falto.length} ${falto.length === 1 ? "faltó" : "faltaron"} a la prueba` : "",
    plazo.length ? `${plazo.length} ${plazo.length === 1 ? "cumple" : "cumplen"} 15 días` : "",
  ].filter(Boolean);
  const hoy = new Intl.DateTimeFormat("es-ES", { timeZone: "Europe/Madrid", weekday: "long", day: "numeric", month: "long" }).format(new Date());
  const T = d.tarifas || {};

  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head><body style="margin:0;background-color:#f4f4f5;padding:24px 0;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border:1px solid #e4e4e7;border-radius:14px;overflow:hidden">
      <tr><td bgcolor="#26374B" style="background-color:#26374B;color:#ffffff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana · Solicitudes de natación</td></tr>
      <tr><td style="padding:22px 24px 4px 24px">
        <p style="margin:0 0 6px;font-size:17px;font-weight:700;color:#26374B">${muestra ? "Natación: resumen de lo pendiente" : "Natación: " + esc(partes.join(" · "))}</p>
        <p style="margin:0;color:#71717a;font-size:13px">${esc(hoy)} · formularios de la escuela y del máster</p>
      </td></tr>
      ${seccion("Quién viene a probar", "#26374B", "Para avisar a los monitores: de hoy en adelante, por día.", agendaHtml(d.agenda || []))}
      ${seccion("De prueba: mándales el mensaje con el día", "#1E7A3D", "Cópialo y pégalo en WhatsApp.", prueba.map((a) => tarjeta(a,
        esc([a.franjas || "", a.fecha_prueba ? "prueba el " + fechaLarga(a.fecha_prueba) : "", a.observaciones ? "observaciones: " + a.observaciones : ""].filter(Boolean).join(" · ")),
        cajaMensaje(mensaje(a, "prueba", T)))).join(""))}
      ${seccion("Faltaron a su clase de prueba", "#B3261E", "Escríbeles para buscar otro día (y cámbiaselo en la app).", falto.map((a) => tarjeta(a,
        esc([a.franjas || "", a.falto_el ? "faltó el " + fechaLarga(a.falto_el) : ""].filter(Boolean).join(" · ")), "")).join(""))}
      ${seccion("Ya vinieron a su clase de prueba: pregúntales si se quedan", "#2F6FA8", "", probo.map((a) => tarjeta(a,
        esc([a.franjas || "", a.vino_el ? "vino el " + fechaLarga(a.vino_el) : ""].filter(Boolean).join(" · ")),
        cajaMensaje(mensaje(a, "formaliza", T)))).join(""))}
      ${seccion("Por revisar: dales grupo o ponlos en espera", "#8A5307", "Si no hay hueco, debajo va el mensaje de espera. Al mandarlo, márcalo en la app («Sin hueco: en espera 15 días»).", revisar.map((a) => tarjeta(a,
        esc([a.motivo || "", a.pide ? "Pide: " + a.pide : ""].filter(Boolean).join(" · ")),
        cajaMensaje(mensaje(a, "espera", T)))).join(""))}
      ${seccion("Cumplen los 15 días de espera: ¿hay hueco ya?", "#B3261E", "Si sigue sin haber hueco, este es el mensaje.", plazo.map((a) => tarjeta(a,
        esc([a.pide ? "Pide: " + a.pide : "", a.espera_hasta ? "plazo: " + fechaLarga(a.espera_hasta) : ""].filter(Boolean).join(" · ")),
        cajaMensaje(mensaje(a, "sin_hueco", T)))).join(""))}
      <tr><td style="padding:14px 24px 24px 24px">
        <a href="${PANEL}" style="display:inline-block;background-color:#26374B;color:#ffffff;text-decoration:none;font-weight:700;font-size:14px;padding:11px 18px;border-radius:10px">Abrir las solicitudes</a>
        <p style="margin:14px 0 0;color:#a1a1aa;font-size:11.5px">Cada novedad se avisa una sola vez. «Quién viene a probar» sale en todos los correos.</p>
      </td></tr>
    </table>
  </td></tr></table></body></html>`;

  const lineas: string[] = [];
  if ((d.agenda || []).length) {
    lineas.push("QUIÉN VIENE A PROBAR");
    d.agenda.forEach((c) => lineas.push(`- ${mayus1(fechaLarga(c.fecha))} ${hhmm(c.hora)}${c.monitores ? " (" + c.monitores + ")" : ""}: ${capital(c.nombre)} · ${c.origen}${c.nivel ? " · " + c.nivel : ""}`));
    lineas.push("");
  }
  d.avisos.forEach((a) => {
    lineas.push(`${a.que.toUpperCase()}: ${capital(a.nombre)} (${a.origen})${a.motivo ? " · " + a.motivo : ""}`);
    const m = a.que === "prueba" ? "prueba" : a.que === "probo" ? "formaliza" : a.que === "revisar" ? "espera" : a.que === "plazo" ? "sin_hueco" : "";
    if (m) lineas.push(mensaje(a, m as "prueba", T));
    lineas.push(`${PANEL}?id=${a.id}`, "");
  });
  lineas.push(PANEL);

  const n = d.avisos.length;
  const asunto = muestra ? "Natación · resumen de solicitudes · Apolana"
    : `Natación · ${n} novedad${n === 1 ? "" : "es"} de las solicitudes · Apolana`;
  return { asunto, html, texto: lineas.join("\n") };
}

// Andrés + los activos de natacion_avisos_destinos.
async function destinos(): Promise<string[]> {
  let extra: string[] = [];
  try {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/natacion_avisos_destinos?activo=eq.true&select=email`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` }, signal: AbortSignal.timeout(15000),
    });
    if (r.ok) extra = ((await r.json()) as { email: string }[]).map((x) => x.email);
    else console.error("[natacion-form-sync] destinos:", r.status, (await r.text()).slice(0, 200));
  } catch (e) {
    console.error("[natacion-form-sync] destinos:", e);
  }
  return [...new Set([DESTINO, ...extra].map((x) => String(x || "").trim().toLowerCase())
    .filter((x) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(x)))];
}

async function enviarCorreo(d: Datos, muestra: boolean): Promise<number> {
  const para_ = await destinos();
  if (!BREVO_API_KEY || !para_.length) return 0;
  const c = correoHtml(d, muestra);
  let enviados = 0;
  for (const para of para_) {   // uno por persona: nadie ve las direcciones de los demás
    try {
      const res = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({
          sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
          to: [{ email: para }],
          subject: c.asunto,
          htmlContent: c.html,
          textContent: c.texto,
        }),
        signal: AbortSignal.timeout(20000),
      });
      if (!res.ok) console.error("[natacion-form-sync] Brevo:", res.status, await res.text().catch(() => ""));
      if (res.ok) enviados++;
    } catch (e) {
      console.error("[natacion-form-sync] correo:", e);
    }
  }
  return enviados;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ error: "metodo" }, 405);
  if (!SUPABASE_URL || !SERVICE_KEY) return json({ error: "config" }, 503);
  const token = (req.headers.get("x-sync-token") ?? "").trim();
  const sec = (req.headers.get("x-cron-secret") ?? "").trim();
  const esCron = !!sec && !!CRON_SECRET && iguales(sec, CRON_SECRET);
  if (!token && !esCron) return json({ error: "token" }, 401);

  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }

  // 1 · filas del Excel (solo el script de Google)
  let ingesta: unknown = null;
  if (token) {
    const filas = Array.isArray(cuerpo.filas) ? cuerpo.filas : [];
    if (filas.length > 5000) return json({ error: "demasiadas filas" }, 413);
    const aplicar = cuerpo.aplicar !== false;
    const r = await rpc("natacion_form_sincronizar", { p_token: token, p_filas: filas, p_aplicar: aplicar });
    if (!r.ok) {
      if (/token/.test(r.texto)) return json({ error: "token" }, 401);
      console.error("[natacion-form-sync] sincronizar:", r.estado, r.texto.slice(0, 400));
      return json({ error: "base", detalle: r.texto.slice(0, 300) }, 500);
    }
    ingesta = r.datos;
    if (!aplicar) return json({ ingesta, ensayo: true });
  }

  // 2 · repaso: vinieron a la prueba, faltaron, ya tienen cuota, ya no están
  const rv = await rpc("natacion_solicitudes_revisar", {});
  if (!rv.ok) console.error("[natacion-form-sync] revisar:", rv.estado, rv.texto.slice(0, 300));

  // 3 · correo con lo que aún no se ha avisado (o, de muestra, con todo lo pendiente)
  const muestra = esCron && cuerpo.muestra === true;
  const rc = await rpc("natacion_solicitudes_correo", { p_todo: muestra });
  if (!rc.ok) console.error("[natacion-form-sync] correo (datos):", rc.estado, rc.texto.slice(0, 300));
  const d: Datos = rc.ok && rc.datos ? { avisos: rc.datos.avisos || [], agenda: rc.datos.agenda || [], tarifas: rc.datos.tarifas || {} }
                                     : { avisos: [], agenda: [], tarifas: {} };
  let enviados = 0;
  if (d.avisos.length || (muestra && d.agenda.length)) {
    enviados = await enviarCorreo(d, muestra);
    if (enviados && !muestra && d.avisos.length) {
      const rm = await rpc("natacion_solicitudes_marcar_avisadas", { p_items: d.avisos.map((a) => ({ id: a.id, que: a.que })) });
      if (!rm.ok) console.error("[natacion-form-sync] marcar:", rm.estado, rm.texto.slice(0, 300));
    }
  }
  return json({ ingesta, repaso: rv.datos, avisos: d.avisos.length, agenda: d.agenda.length, correo_enviado: enviados > 0, enviados, muestra });
});
