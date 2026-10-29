// ============================================================
// camp · piezas comunes de las funciones de Training Camps
// (camp-solicitud, camp-publico, camp-gestion)
// ============================================================

// deno-lint-ignore-file no-explicit-any
export const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
export const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
export const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";
const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
export const RESPUESTAS_EMAIL = (Deno.env.get("CORREO_RESPUESTAS") ?? Deno.env.get("CORREO_AVISOS") ?? "andres.apolana@gmail.com").trim();
export const URL_BASE = "https://atletismoapolana.com/";

const ORIGENES_OK = [
  "https://atletismoapolana.com", "https://www.atletismoapolana.com", "https://escuelaapolana.github.io",
  "http://localhost:8000", "http://127.0.0.1:8000", "http://localhost:8137", "http://localhost:8139", "http://localhost:8143",
];
export function cors(origen: string | null): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": origen && ORIGENES_OK.includes(origen) ? origen : ORIGENES_OK[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}
export function origenValido(origen: string | null) { return !origen || ORIGENES_OK.includes(origen); }
export function responder(cuerpo: unknown, estado: number, origen: string | null): Response {
  return new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...cors(origen), "Content-Type": "application/json; charset=utf-8" } });
}

// REST con la clave de servicio (jwt vacío) o en nombre del usuario (jwt del admin: RLS y es_admin() valen).
export async function rest(ruta: string, init: RequestInit & { jwt?: string } = {}) {
  const { jwt, ...resto } = init;
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...resto,
    headers: {
      apikey: jwt ? (ANON_KEY || SERVICE_KEY) : SERVICE_KEY, Authorization: `Bearer ${jwt || SERVICE_KEY}`,
      "Content-Type": "application/json", ...((resto.headers as Record<string, string>) ?? {}),
    },
  });
  const t = await r.text();
  let d: any = null;
  try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, estado: r.status, datos: d };
}
export async function rpc(nombre: string, args: Record<string, unknown>, jwt?: string) {
  return await rest(`rpc/${nombre}`, { method: "POST", body: JSON.stringify(args), jwt });
}
export function errorDe(r: { datos: any }): string {
  return String(r.datos?.message ?? r.datos?.mensaje ?? r.datos?.error ?? "Error");
}

export const esc = (s: unknown) => String(s ?? "").replace(/[&<>"']/g, (c) =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
export const corta = (v: unknown, n: number) => String(v ?? "").trim().slice(0, n);
export const pareceCorreo = (s: string) => /^[^\s@,;]{1,64}@[^\s@,;]{1,190}\.[a-z]{2,}$/i.test(s);

export function base64(u8: Uint8Array): string {
  let s = "";
  for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode(...u8.subarray(i, i + 0x8000));
  return btoa(s);
}

let LOGO: Uint8Array | null | undefined;
export async function logo(): Promise<Uint8Array | null> {
  if (LOGO !== undefined) return LOGO;
  try {
    const r = await fetch(`${URL_BASE}assets/img/escudo-circulo.png`);
    LOGO = r.ok ? new Uint8Array(await r.arrayBuffer()) : null;
  } catch { LOGO = null; }
  return LOGO;
}

// ---------------------------------------------------------------- textos
export const ETQ: Record<string, Record<string, Record<string, string>>> = {
  modalidades: {
    en: { sprints: "Sprints", hurdles: "Hurdles", middle: "Middle distance", long: "Long distance", jumps: "Jumps", throws: "Throws",
          combined: "Combined events", walk: "Race walking", trail: "Trail / mountain running", other: "Other" },
    es: { sprints: "Velocidad", hurdles: "Vallas", middle: "Medio fondo", long: "Fondo", jumps: "Saltos", throws: "Lanzamientos",
          combined: "Pruebas combinadas", walk: "Marcha", trail: "Trail / montaña", other: "Otras" },
  },
  dias: {
    en: { mon: "Mon", tue: "Tue", wed: "Wed", thu: "Thu", fri: "Fri", sat: "Sat", sun: "Sun" },
    es: { mon: "Lun", tue: "Mar", wed: "Mié", thu: "Jue", fri: "Vie", sat: "Sáb", sun: "Dom" },
  },
  horario: {
    en: { morning: "Morning (8:15–14:00)", afternoon: "Afternoon (15:15–17:15)", evening: "Evening (18:30–21:45)" },
    es: { morning: "Mañana (8:15–14:00)", afternoon: "Tarde (15:15–17:15)", evening: "Noche (18:30–21:45)" },
  },
  instalaciones: {
    en: { track: "Athletics track", throws: "Throwing area", jumps: "Jumps area", gym: "Gym / strength", other: "Other" },
    es: { track: "Pista de atletismo", throws: "Zona de lanzamientos", jumps: "Zona de saltos", gym: "Gimnasio / fuerza", other: "Otras" },
  },
  idioma_com: {
    en: { en: "English", es: "Spanish", fr: "French", de: "German", it: "Italian", pt: "Portuguese", nl: "Dutch", other: "Other" },
    es: { en: "Inglés", es: "Español", fr: "Francés", de: "Alemán", it: "Italiano", pt: "Portugués", nl: "Neerlandés", other: "Otro" },
  },
  sino: { en: { yes: "Yes", no: "No", unsure: "Not sure" }, es: { yes: "Sí", no: "No", unsure: "No lo sabe" } },
  servicios: {
    en: { transporte: "Transport", alojamiento: "Accommodation", comidas: "Meals", fisio: "Physiotherapy", entrenadores: "Coaches",
          playa_montana: "Beach / mountain sessions", actividades: "Complementary activities", otros: "Other services" },
    es: { transporte: "Transporte", alojamiento: "Alojamiento", comidas: "Comidas", fisio: "Fisioterapia", entrenadores: "Entrenadores",
          playa_montana: "Playa / montaña", actividades: "Actividades complementarias", otros: "Otros servicios" },
  },
  sub: {
    en: { aeropuerto: "airport transfers", diario: "daily hotel ↔ track", puntual: "occasional trips", hotel: "hotel", apartments: "apartments", any: "no preference",
          breakfast: "breakfast", lunch: "lunch", dinner: "dinner", beach: "beach", mountain: "mountain",
          lt50: "under €50 pp/night", "50-80": "€50–80 pp/night", "80-120": "€80–120 pp/night", gt120: "over €120 pp/night" },
    es: { aeropuerto: "traslados aeropuerto", diario: "hotel ↔ pista a diario", puntual: "desplazamientos puntuales", hotel: "hotel", apartments: "apartamentos", any: "sin preferencia",
          breakfast: "desayuno", lunch: "comida", dinner: "cena", beach: "playa", mountain: "montaña",
          lt50: "menos de 50 €/persona y noche", "50-80": "50–80 €/persona y noche", "80-120": "80–120 €/persona y noche", gt120: "más de 120 €/persona y noche" },
  },
  material: {
    en: { hurdles: "hurdles", blocks: "starting blocks", cones: "cones / markers", mats: "mats", throwing: "throwing implements", medballs: "medicine balls", other: "other" },
    es: { hurdles: "vallas", blocks: "tacos de salida", cones: "conos / marcas", mats: "colchonetas", throwing: "artefactos de lanzamiento", medballs: "balones medicinales", other: "otro" },
  },
};
export function lista(grupo: string, lang: string, v: unknown): string {
  const m = ETQ[grupo]?.[lang] ?? {};
  return (Array.isArray(v) ? v : []).map((x) => m[String(x)] ?? String(x)).join(", ");
}
export function servicioTexto(clave: string, o: any, lang: string): string {
  const s = ETQ.sub[lang];
  const partes: string[] = [];
  if (o?.aeropuerto) partes.push(s.aeropuerto);
  if (o?.diario) partes.push(s.diario);
  if (o?.puntual) partes.push(s.puntual);
  if (o?.tipo) partes.push(s[o.tipo] ?? o.tipo);
  if (o?.habitaciones) partes.push(String(o.habitaciones));
  if (o?.presupuesto) partes.push(s[o.presupuesto] ?? o.presupuesto);
  if (Array.isArray(o?.cuales) && o.cuales.length) partes.push(o.cuales.map((x: string) => s[x] ?? x).join(" + "));
  if (Array.isArray(o?.cual) && o.cual.length) partes.push(o.cual.map((x: string) => s[x] ?? x).join(" + "));
  if (o?.dieta) partes.push((lang === "es" ? "dieta: " : "diet: ") + o.dieta);
  if (o?.detalle) partes.push(String(o.detalle));
  return partes.join(" · ") || "✓";
}

const MESES: Record<string, string[]> = {
  en: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
  es: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"],
};
export function fechaTxt(d: unknown, lang: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(d ?? ""));
  return m ? `${Number(m[3])} ${MESES[lang === "es" ? "es" : "en"][Number(m[2]) - 1]} ${m[1]}` : "";
}
export function eurTxt(n: unknown, lang: string): string {
  const v = Number(n ?? 0);
  const [ent, dec] = Math.abs(v).toFixed(2).split(".");
  const s = (v < 0 ? "-" : "") + ent.replace(/\B(?=(\d{3})+(?!\d))/g, lang === "es" ? "." : ",") + (lang === "es" ? "," : ".") + dec;
  return lang === "es" ? s + " €" : "€" + s;
}

// --------------------------------------------------------------- correo
// Diseño de la casa: cabecera navy, tabla de datos con la etiqueta en crema, botón.
export function correoHtml(o: { lang: string; antetitulo?: string; titulo: string; parrafos: string[]; filas?: [string, string][];
  boton?: { texto: string; url: string }; despues?: string[]; pie?: string }): string {
  const p = (t: string) => `<p style="margin:0 0 14px;font-size:15px;line-height:1.6;color:#2E4256">${t}</p>`;
  const filas = (o.filas ?? []).filter(([, v]) => v).map(([k, v]) =>
    `<tr><td bgcolor="#F1EADC" style="background-color:#F1EADC;padding:9px 12px;color:#6E6656;font-size:13px;width:150px;vertical-align:top;border-bottom:1px solid #ffffff">${esc(k)}</td>` +
    `<td style="padding:9px 12px;color:#2E4256;font-size:14.5px;font-weight:bold;border-bottom:1px solid #F1EADC">${esc(v).replace(/\n/g, "<br>")}</td></tr>`).join("");
  const boton = o.boton
    ? `<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:6px 0 18px"><tr><td bgcolor="#2F6FA8" style="background-color:#2F6FA8;border-radius:10px">` +
      `<a href="${esc(o.boton.url)}" style="display:inline-block;padding:13px 22px;color:#ffffff;font-size:15px;font-weight:bold;text-decoration:none">${esc(o.boton.texto)}</a></td></tr></table>`
    : "";
  return `<!doctype html><html lang="${o.lang}"><body style="margin:0;padding:0;background-color:#F7F3EA">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#F7F3EA"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" width="580" cellpadding="0" cellspacing="0" border="0" style="max-width:580px;width:100%;font-family:Arial,Helvetica,sans-serif">
<tr><td bgcolor="#2E4256" style="background-color:#2E4256;padding:22px 26px;border-radius:12px 12px 0 0">
<div style="color:#C9D3DD;font-size:12px;letter-spacing:1px;text-transform:uppercase">${esc(o.antetitulo ?? "Club Atletismo Apolana · Training Camps")}</div>
<div style="color:#ffffff;font-size:22px;font-weight:bold;margin-top:6px;line-height:1.25">${esc(o.titulo)}</div></td></tr>
<tr><td bgcolor="#ffffff" style="background-color:#ffffff;padding:24px 26px">
${o.parrafos.map(p).join("")}
${filas ? `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;margin:4px 0 18px">${filas}</table>` : ""}
${boton}
${(o.despues ?? []).map(p).join("")}
</td></tr>
<tr><td bgcolor="#2E4256" style="background-color:#2E4256;padding:12px 26px;border-radius:0 0 12px 12px;color:#C9D3DD;font-size:12px">${esc(o.pie ?? (o.lang === "es"
    ? "Club Atletismo Apolana · Alicante · atletismoapolana.com · Contesta a este correo si necesitas algo."
    : "Club Atletismo Apolana · Alicante, Spain · atletismoapolana.com · Just reply to this email if you need anything."))}</td></tr>
</table></td></tr></table></body></html>`;
}

export async function enviarCorreo(o: { para: string; nombre?: string; asunto: string; html: string; responderA?: string;
  adjuntos?: { nombre: string; contenido: string }[] }): Promise<boolean> {
  if (!BREVO_API_KEY || !pareceCorreo(o.para)) return false;
  try {
    const r = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "Content-Type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { email: REMITENTE_EMAIL, name: REMITENTE_NOMBRE },
        to: [{ email: o.para, ...(o.nombre ? { name: o.nombre } : {}) }],
        replyTo: { email: o.responderA && pareceCorreo(o.responderA) ? o.responderA : RESPUESTAS_EMAIL, name: REMITENTE_NOMBRE },
        subject: o.asunto,
        htmlContent: o.html,
        ...(o.adjuntos?.length ? { attachment: o.adjuntos.map((a) => ({ name: a.nombre, content: a.contenido })) } : {}),
      }),
    });
    if (!r.ok) console.error("[camp] Brevo:", r.status, await r.text());
    return r.ok;
  } catch (e) {
    console.error("[camp] Brevo:", e);
    return false;
  }
}

// A quién avisar en el club: lo que diga Ajustes, si no CORREO_RESPUESTAS (Andrés).
export async function correoClub(): Promise<string> {
  const r = await rest("camp_config?select=correo_avisos&id=eq.1");
  const c = String(r.datos?.[0]?.correo_avisos ?? "").trim();
  return pareceCorreo(c) ? c : RESPUESTAS_EMAIL;
}

export const enlacePanel = (id: string) => `${URL_BASE}admin/training-camps/?id=${id}`;
export const enlacePropuesta = (t: string, lang: string) => `${URL_BASE}training-camps/proposal/?t=${t}&lang=${lang}`;
export const enlacePago = (t: string, lang: string) => `${URL_BASE}training-camps/pay/?t=${t}&lang=${lang}`;
