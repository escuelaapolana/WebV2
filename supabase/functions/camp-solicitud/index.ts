// ============================================================
// camp-solicitud · formulario público de /training-camps/
// ------------------------------------------------------------
// 1) Anti-spam: campo trampa «website», tiempo mínimo de relleno y límite por IP.
// 2) Valida todo (mensajes en el idioma de la página).
// 3) Crea el expediente (camp_solicitud_crear → código TC-AAAA-NNN).
// 4) Correo a Andrés con la solicitud completa y acuse al cliente en su idioma.
// Si un correo falla, la solicitud ya está guardada: se dice que sí.
//
//   supabase functions deploy camp-solicitud --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

// deno-lint-ignore-file no-explicit-any
import {
  correoClub, correoHtml, corta, enlacePanel, esc, enviarCorreo, ETQ, fechaTxt, lista, origenValido, pareceCorreo, responder,
  rest, rpc, SERVICE_KEY, servicioTexto, SUPABASE_URL, cors,
} from "../_shared/camp.ts";

const M: Record<string, Record<string, string>> = {
  en: {
    rate: "Too many attempts. Please try again in a while.", entidad: "Enter the name of your club, team or organisation.",
    pais: "Enter your country.", contacto: "Enter the contact person.", email: "Enter a valid email address.",
    telefono: "Enter a phone or WhatsApp number.", idioma: "Choose a communication language.",
    atletas: "Enter the number of athletes (1–500).", entrenadores: "Enter the number of coaches (0–100).",
    modalidades: "Choose at least one discipline.", llegada: "Enter a valid arrival date (not in the past).",
    salida: "The departure date must be on or after the arrival date.", larga: "For stays longer than 120 days, please contact us directly.",
    dias: "Choose at least one training day.", horario: "Choose at least one time slot.", sesiones: "Choose the number of sessions per day.",
    grupos: "Enter how many groups (2–6).", confirma: "Please confirm the information is correct.",
    privacidad: "Please accept the privacy policy.", guardar: "We couldn't save your request. Please try again or write to us.",
    menores: "Tell us whether any participants are under 18.", horario_modo: "Tell us whether you already know your schedule.",
    subgrupos: "Check the subgroups: up to 6, each with a name.", gimnasio_simultaneos: "Enter a valid number of athletes at a time.",
  },
  es: {
    rate: "Demasiados intentos. Prueba de nuevo dentro de un rato.", entidad: "Escribe el nombre del club, equipo o entidad.",
    pais: "Escribe el país.", contacto: "Escribe la persona de contacto.", email: "Escribe un correo electrónico válido.",
    telefono: "Escribe un teléfono o WhatsApp.", idioma: "Elige el idioma de comunicación.",
    atletas: "Indica el número de atletas (1–500).", entrenadores: "Indica el número de entrenadores (0–100).",
    modalidades: "Elige al menos una modalidad.", llegada: "Indica una fecha de llegada válida (no pasada).",
    salida: "La salida tiene que ser igual o posterior a la llegada.", larga: "Para estancias de más de 120 días, escríbenos directamente.",
    dias: "Elige al menos un día de entrenamiento.", horario: "Elige al menos una franja horaria.", sesiones: "Elige el número de sesiones diarias.",
    grupos: "Indica cuántos grupos (2–6).", confirma: "Confirma que los datos son correctos.",
    privacidad: "Acepta la política de privacidad.", guardar: "No hemos podido guardar la solicitud. Inténtalo de nuevo o escríbenos.",
    menores: "Indica si participa algún menor de 18 años.", horario_modo: "Indica si ya tenéis el horario.",
    subgrupos: "Revisa los subgrupos: hasta 6, cada uno con su nombre.", gimnasio_simultaneos: "Indica un número válido de atletas a la vez.",
  },
};

const CODIGOS = {
  idioma_com: ["en", "es", "fr", "de", "it", "pt", "nl", "other"],
  modalidades: ["sprints", "hurdles", "middle", "long", "jumps", "throws", "combined", "walk", "trail", "other"],
  dias: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"],
  horario: ["morning", "afternoon", "evening"],
  instalaciones: ["track", "throws", "jumps", "gym", "other"],   // «gym» lo manda aún el formulario v1
  material: ["hurdles", "blocks", "cones", "mats", "throwing", "medballs", "other"],
};
const DURACIONES = [60, 90, 120, 150];
const sub = (v: unknown, ok: string[]) => Array.from(new Set((Array.isArray(v) ? v : []).map(String).filter((x) => ok.includes(x))));
const entero = (v: unknown) => { const n = Number(v); return Number.isInteger(n) ? n : NaN; };
const esFecha = (s: string) => /^\d{4}-\d{2}-\d{2}$/.test(s) && !isNaN(Date.parse(s + "T00:00:00Z"));
const hoyMadrid = () => new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid" }).format(new Date());

function servicios(v: any): Record<string, any> {
  const o: Record<string, any> = {};
  if (!v || typeof v !== "object") return o;
  const det = (x: any) => corta(x?.detalle, 800);
  if (v.transporte) o.transporte = { aeropuerto: v.transporte.aeropuerto === true, diario: v.transporte.diario === true,
    puntual: v.transporte.puntual === true, detalle: det(v.transporte) };
  if (v.alojamiento) o.alojamiento = { tipo: ["hotel", "apartments", "any"].includes(v.alojamiento.tipo) ? v.alojamiento.tipo : "",
    habitaciones: corta(v.alojamiento.habitaciones, 120),
    presupuesto: ["lt50", "50-80", "80-120", "gt120"].includes(v.alojamiento.presupuesto) ? v.alojamiento.presupuesto : "", detalle: det(v.alojamiento) };
  if (v.comidas) o.comidas = { cuales: sub(v.comidas.cuales, ["breakfast", "lunch", "dinner"]), dieta: corta(v.comidas.dieta, 300), detalle: det(v.comidas) };
  if (v.playa_montana) o.playa_montana = { cual: sub(v.playa_montana.cual, ["beach", "mountain"]), detalle: det(v.playa_montana) };
  for (const k of ["fisio", "entrenadores", "actividades", "otros"]) if (v[k]) o[k] = { detalle: det(v[k]) };
  // Fuera lo vacío, para que el expediente se lea limpio.
  for (const k of Object.keys(o)) for (const s of Object.keys(o[k])) {
    const x = o[k][s];
    if (x === "" || x === false || (Array.isArray(x) && !x.length)) delete o[k][s];
  }
  return o;
}

// Filas del horario para el correo al club (v1: días + franjas; v2: también «por concretar» o por día).
function horarioFilas(d: any): [string, string][] {
  if (d.horario_modo === "tba") return [["Horario", "Por concretar" + (d.horario.length ? " · prefieren " + lista("horario", "es", d.horario) : "")]];
  if (d.horario_dias) {
    return [["Días", lista("dias", "es", d.dias)], ["Horario por día", Object.entries(d.horario_dias).map(([dia, x]: [string, any]) =>
      `${ETQ.dias.es[dia] ?? dia}: ${lista("horario", "es", x.franjas) || "—"}${x.sesiones ? " · " + x.sesiones + " ses." : ""}${x.duracion ? " · " + x.duracion + " min" : ""}`).join("\n")]];
  }
  return [["Días", lista("dias", "es", d.dias)], ["Horario", lista("horario", "es", d.horario)],
    ["Sesiones al día", Number.isFinite(d.sesiones_dia) ? String(d.sesiones_dia) + (d.duracion ? ` · unos ${d.duracion} min` : "") : (d.duracion ? `unos ${d.duracion} min` : "")]];
}

Deno.serve(async (req) => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, origen);
  if (!origenValido(origen)) return responder({ error: "origen", mensaje: "Origin not allowed." }, 403, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config", mensaje: "Not available right now." }, 503, origen);

  let b: Record<string, any> = {};
  try { b = await req.json(); } catch { /* vacío */ }
  const lang = b.lang === "es" ? "es" : "en";
  const m = M[lang];
  const mal = (k: string) => responder({ error: "datos", campo: k, mensaje: m[k] }, 400, origen);

  // 0 · Anti-spam: la trampa y el que rellena 4 pasos en menos de 4 segundos se dan por buenos sin guardar nada.
  if (String(b.website ?? "").trim() !== "") return responder({ ok: true }, 200, origen);
  const t0 = Number(b.t0);
  if (Number.isFinite(t0) && t0 > 0 && Date.now() - t0 < 4000) return responder({ ok: true }, 200, origen);
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim();
  if (ip) {
    const desde = new Date(Date.now() - 60 * 60000).toISOString();
    const r = await rest(`rate_limit_log?select=id&accion=eq.camp-solicitud&ip=eq.${encodeURIComponent(ip)}&creado_en=gt.${encodeURIComponent(desde)}`);
    if ((Array.isArray(r.datos) ? r.datos.length : 0) >= 8) return responder({ error: "rate", mensaje: m.rate }, 429, origen);
    await rest("rate_limit_log", { method: "POST", body: JSON.stringify({ ip, accion: "camp-solicitud" }) });
  }

  // 1 · Validar
  const d: Record<string, any> = {
    lang,
    entidad: corta(b.entidad, 160), pais: corta(b.pais, 80), contacto: corta(b.contacto, 120),
    email: corta(b.email, 160).toLowerCase(), telefono: corta(b.telefono, 40),
    idioma_com: CODIGOS.idioma_com.includes(String(b.idioma_com)) ? String(b.idioma_com) : "",
    idioma_com_otro: corta(b.idioma_com_otro, 60),
    n_atletas: entero(b.n_atletas), n_entrenadores: entero(b.n_entrenadores ?? 0),
    modalidades: sub(b.modalidades, CODIGOS.modalidades), modalidades_otro: corta(b.modalidades_otro, 160),
    llegada: corta(b.llegada, 10), salida: corta(b.salida, 10), fechas_flexibles: b.fechas_flexibles === true,
    dias: sub(b.dias, CODIGOS.dias), horario: sub(b.horario, CODIGOS.horario), sesiones_dia: entero(b.sesiones_dia),
    dividir: ["yes", "no", "unsure"].includes(b.dividir) ? b.dividir : "",
    grupos: null as number | null, grupos_detalle: corta(b.grupos_detalle, 400),
    instalaciones: sub(b.instalaciones, CODIGOS.instalaciones), instalaciones_otro: corta(b.instalaciones_otro, 200),
    material: corta(b.material, 1000),
    gimnasio: ["yes", "no", "unsure"].includes(b.gimnasio) ? b.gimnasio : "", gimnasio_detalle: corta(b.gimnasio_detalle, 500),
    servicios: servicios(b.servicios),
    necesidades: corta(b.necesidades, 2000), comentarios: corta(b.comentarios, 3000),
    // v2 (si no vienen, es el formulario v1: horario conocido, como antes)
    horario_modo: b.horario_modo === "tba" ? "tba" : "known",
    horario_igual: b.horario_igual === false ? false : true,
    duracion: DURACIONES.includes(Number(b.duracion)) ? Number(b.duracion) : null,
    horario_dias: null as Record<string, unknown> | null,
    menores: ["yes", "no"].includes(b.menores) ? b.menores : "",
    menores_n: null as number | null,
    subgrupos: [] as { nombre: string; modalidad: string; atletas: number | null }[],
    gimnasio_simultaneos: null as number | null, gimnasio_sesiones: null as number | null,
    material_items: sub(b.material_items, CODIGOS.material),
  };
  const v2 = "horario_modo" in b || "menores" in b;
  if (!d.entidad) return mal("entidad");
  if (!d.pais) return mal("pais");
  if (!d.contacto) return mal("contacto");
  if (!pareceCorreo(d.email)) return mal("email");
  if (d.telefono.replace(/\D/g, "").length < 6) return mal("telefono");
  if (!d.idioma_com) return mal("idioma");
  if (!(d.n_atletas >= 1 && d.n_atletas <= 500)) return mal("atletas");
  if (!(d.n_entrenadores >= 0 && d.n_entrenadores <= 100)) return mal("entrenadores");
  if (!d.modalidades.length) return mal("modalidades");
  if (!esFecha(d.llegada) || d.llegada < hoyMadrid()) return mal("llegada");
  if (!esFecha(d.salida) || d.salida < d.llegada) return mal("salida");
  if ((Date.parse(d.salida) - Date.parse(d.llegada)) / 86400000 > 120) return mal("larga");
  if (v2 && !d.menores) return mal("menores");
  if (d.menores === "yes") { const n = entero(b.menores_n); d.menores_n = n >= 1 && n <= 1000 ? n : null; }
  if (v2 && !["known", "tba"].includes(b.horario_modo)) return mal("horario_modo");
  if (d.horario_modo === "known") {
    if (!d.dias.length) return mal("dias");
    if (!v2 || d.horario_igual) {
      if (!d.horario.length) return mal("horario");
      if (!v2 && !(d.sesiones_dia >= 1 && d.sesiones_dia <= 3)) return mal("sesiones");
    } else {
      // Un horario por día: solo los días elegidos, con sus franjas.
      const hd: Record<string, unknown> = {}, todas = new Set<string>();
      for (const dia of d.dias) {
        const x = b.horario_dias?.[dia] ?? {};
        const franjas = sub(x.franjas, CODIGOS.horario);
        franjas.forEach((f) => todas.add(f));
        const ses = entero(x.sesiones);
        hd[dia] = { franjas, sesiones: ses >= 1 && ses <= 3 ? ses : null, duracion: DURACIONES.includes(Number(x.duracion)) ? Number(x.duracion) : null };
      }
      if (!todas.size) return mal("horario");
      d.horario_dias = hd;
      d.horario = CODIGOS.horario.filter((f) => todas.has(f));
      d.duracion = null;
    }
  } else {
    // Por concretar: días y sesiones fuera; la franja preferida es opcional.
    d.dias = []; d.horario_igual = true; d.duracion = null;
  }
  if (!(d.sesiones_dia >= 1 && d.sesiones_dia <= 3) || (d.horario_modo === "known" && !d.horario_igual)) d.sesiones_dia = NaN;
  if (d.dividir === "yes") {
    if (Array.isArray(b.subgrupos)) {
      if (b.subgrupos.length > 6) return mal("subgrupos");
      for (const g of b.subgrupos) {
        const nombre = corta(g?.nombre, 60), at = entero(g?.atletas);
        const modalidad = [...CODIGOS.modalidades, "mixed"].includes(String(g?.modalidad)) ? String(g.modalidad) : "";
        if (!nombre && !modalidad && !(at >= 1)) continue;   // fila vacía: se ignora
        if (!nombre) return mal("subgrupos");
        d.subgrupos.push({ nombre, modalidad, atletas: at >= 1 && at <= 500 ? at : null });
      }
      d.grupos = d.subgrupos.length >= 2 ? Math.min(d.subgrupos.length, 10) : null;
    } else {
      const g = entero(b.grupos);
      if (!(g >= 2 && g <= 6)) return mal("grupos");
      d.grupos = g;
    }
  } else { d.grupos_detalle = ""; }
  // El gimnasio se pregunta una sola vez (v2): «gym» ya no va en instalaciones.
  if (v2) d.instalaciones = d.instalaciones.filter((x: string) => x !== "gym");
  if (d.gimnasio === "yes") {
    if (b.gimnasio_simultaneos != null && b.gimnasio_simultaneos !== "") {
      const n = entero(b.gimnasio_simultaneos);
      if (!(n >= 1 && n <= 500)) return mal("gimnasio_simultaneos");
      d.gimnasio_simultaneos = n;
    }
    const se = entero(b.gimnasio_sesiones);
    d.gimnasio_sesiones = se >= 1 && se <= 50 ? se : null;
  } else { d.gimnasio_detalle = ""; }
  if (!d.material_items.includes("other") && !v2) d.material_items = [];
  if (!d.modalidades.includes("other")) d.modalidades_otro = "";
  if (!d.instalaciones.includes("other")) d.instalaciones_otro = "";
  if (d.idioma_com !== "other") d.idioma_com_otro = "";
  if (b.confirma !== true) return mal("confirma");
  if (b.privacidad !== true) return mal("privacidad");

  // 2 · Guardar
  const rIns = await rpc("camp_solicitud_crear", { p: d });
  const nuevo = Array.isArray(rIns.datos) ? rIns.datos[0] : rIns.datos;
  if (!rIns.ok || !nuevo?.codigo) {
    console.error("[camp-solicitud] guardar:", rIns.estado, rIns.datos);
    return responder({ error: "guardar", mensaje: m.guardar }, 502, origen);
  }
  const codigo = String(nuevo.codigo), id = String(nuevo.id);

  // 3 · Correos (extra: si fallan, la solicitud ya está guardada)
  const es = (g: string, v: unknown) => lista(g, "es", v);
  const servEs = Object.entries(d.servicios).map(([k, o]) => `${ETQ.servicios.es[k] ?? k}: ${servicioTexto(k, o, "es")}`).join("\n");
  const noches = Math.round((Date.parse(d.salida) - Date.parse(d.llegada)) / 86400000);
  const htmlClub = correoHtml({
    lang: "es", antetitulo: "Training Camps · nueva solicitud", titulo: `${d.entidad} (${d.pais})`,
    parrafos: [`Ha llegado una solicitud de concentración por la web. Código <b>${codigo}</b>. Escribe al cliente en <b>${ETQ.idioma_com.es[d.idioma_com] ?? d.idioma_com}</b>${d.idioma_com_otro ? " (" + esc(d.idioma_com_otro) + ")" : ""}: si contestas a este correo le escribes a él.`],
    filas: [
      ["Contacto", d.contacto], ["Correo", d.email], ["Teléfono / WhatsApp", d.telefono],
      ["Participantes", `${d.n_atletas} atletas · ${d.n_entrenadores} entrenadores`],
      ["Modalidades", es("modalidades", d.modalidades) + (d.modalidades_otro ? " (" + d.modalidades_otro + ")" : "")],
      ["Fechas", `${fechaTxt(d.llegada, "es")} → ${fechaTxt(d.salida, "es")} (${noches} noches)${d.fechas_flexibles ? " · flexibles" : ""}`],
      ["Menores", d.menores === "yes" ? "Sí" + (d.menores_n ? ` · unos ${d.menores_n}` : "") : d.menores === "no" ? "No" : ""],
      ...horarioFilas(d),
      ["Subgrupos", d.subgrupos.length
        ? d.subgrupos.map((g) => `${g.nombre}${g.modalidad ? " · " + (g.modalidad === "mixed" ? "mixto" : ETQ.modalidades.es[g.modalidad] ?? g.modalidad) : ""}${g.atletas ? " · " + g.atletas + " atletas" : ""}`).join("\n")
        : (ETQ.sino.es[d.dividir] ?? "—") + (d.grupos ? ` · ${d.grupos} grupos` : "") + (d.grupos_detalle ? ` · ${d.grupos_detalle}` : "")],
      ["Instalaciones", es("instalaciones", d.instalaciones) + (d.instalaciones_otro ? " (" + d.instalaciones_otro + ")" : "")],
      ["El Cubo", (ETQ.sino.es[d.gimnasio] ?? "—") + (d.gimnasio_simultaneos ? ` · ${d.gimnasio_simultaneos} a la vez` : "") +
        (d.gimnasio_sesiones ? ` · ${d.gimnasio_sesiones} sesiones/semana` : "") + (d.gimnasio_detalle ? " · " + d.gimnasio_detalle : "")],
      ["Material", [lista("material", "es", d.material_items), d.material].filter(Boolean).join(" · ")], ["Servicios", servEs], ["Necesidades especiales", d.necesidades], ["Comentarios", d.comentarios],
    ],
    boton: { texto: "Abrir el expediente", url: enlacePanel(id) },
  });
  const avisado = await enviarCorreo({ para: await correoClub(), asunto: `Training camp · ${codigo} · ${d.entidad} (${d.pais})`, html: htmlClub, responderA: d.email });

  const L = lang === "es";
  const htmlCliente = correoHtml({
    lang, titulo: L ? "Hemos recibido tu solicitud" : "We've received your request",
    parrafos: [
      L ? `Hola, ${esc(d.contacto)}:` : `Hello ${esc(d.contacto)},`,
      L ? "Gracias por pensar en Alicante para vuestra concentración. Vamos a estudiar la disponibilidad de las instalaciones y los servicios que nos pides, y te enviaremos una propuesta a medida."
        : "Thank you for considering Alicante for your training camp. We'll check the availability of the facilities and services you've asked for and send you a tailor-made proposal.",
    ],
    filas: [
      [L ? "Referencia" : "Reference", codigo],
      [L ? "Entidad" : "Organisation", d.entidad],
      [L ? "Fechas" : "Dates", `${fechaTxt(d.llegada, lang)} – ${fechaTxt(d.salida, lang)}`],
      [L ? "Participantes" : "Participants", L ? `${d.n_atletas} atletas · ${d.n_entrenadores} entrenadores` : `${d.n_atletas} athletes · ${d.n_entrenadores} coaches`],
      [L ? "Modalidades" : "Disciplines", lista("modalidades", lang, d.modalidades)],
    ],
    despues: [
      L ? "Recuerda que los horarios son orientativos y que nada queda reservado hasta que aceptes la propuesta y se confirme la disponibilidad. Si quieres añadir algo, contesta a este correo indicando tu referencia."
        : "Please note that time slots are indicative and nothing is booked until you accept the proposal and availability is confirmed. If you'd like to add anything, just reply to this email quoting your reference.",
      L ? "Un saludo,<br><b>Club Atletismo Apolana</b>" : "Kind regards,<br><b>Club Atletismo Apolana</b>",
    ],
  });
  const acuse = await enviarCorreo({
    para: d.email, nombre: d.contacto, html: htmlCliente,
    asunto: L ? `Hemos recibido tu solicitud · ${codigo}` : `We've received your training camp request · ${codigo}`,
  });
  await rest("camp_registro", { method: "POST", body: JSON.stringify({
    solicitud_id: id, tipo: "comunicacion", canal: "email", sentido: "saliente",
    texto: acuse ? `Acuse de recibo enviado a ${d.email} (${lang === "es" ? "castellano" : "inglés"})` : `El acuse de recibo a ${d.email} NO ha salido`,
    datos: { automatico: true, aviso_club: avisado },
  }) });

  return responder({ ok: true, codigo }, 200, origen);
});
