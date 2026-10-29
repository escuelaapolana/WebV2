// ============================================================
// camp-pdf · el presupuesto de un Training Camp en PDF (A4)
// ------------------------------------------------------------
// Recibe la librería pdf-lib (así se puede probar fuera de Deno), los datos
// tal cual los da camp_propuesta_json (lo que ve el cliente: nunca costes ni
// notas internas) y, si se pudo descargar, el escudo en PNG.
// Fuente Helvetica estándar (WinAnsi): lo que no se pueda escribir se cambia.
// ============================================================

// deno-lint-ignore-file no-explicit-any
type Lib = any;

const T: Record<string, Record<string, string>> = {
  en: {
    titulo: "PROPOSAL", sub: "Training camps · Alicante", numero: "No.", fecha: "Date", valido: "Valid until",
    para: "PREPARED FOR", camp: "TRAINING CAMP", fechas: "Dates", participantes: "Participants", referencia: "Reference",
    noches: "nights", noche: "night", personas: "participants",
    concepto: "Description", cantidad: "Qty", precio: "Unit price", iva: "VAT", importe: "Amount",
    subtotal: "Subtotal", ivade: "VAT {p} % on {b}", total: "TOTAL", senal: "Deposit", senal_pct: "Deposit ({p} %)",
    senal_cuando: "to confirm the booking", saldo: "Balance", saldo_cuando: "due by {d}", saldo_antes: "due before arrival",
    notas: "Notes", pagos: "Payment", condiciones: "This proposal is subject to our booking conditions (version {v}): {u}",
    confirmacion: "The booking is confirmed once the proposal is accepted, the deposit has been received and availability has been confirmed by the club.",
    aceptado: "ACCEPTED on {d} by {n}", pagina: "Page {a} of {b}",
    instalaciones: "Facilities & track access", gimnasio: "Gym & strength", material: "Equipment", transporte: "Transport",
    entrenadores: "Coaching & technical support", servicios: "Additional services", otros: "Other",
  },
  es: {
    titulo: "PRESUPUESTO", sub: "Concentraciones deportivas · Alicante", numero: "N.º", fecha: "Fecha", valido: "Válido hasta",
    para: "PREPARADO PARA", camp: "CONCENTRACIÓN", fechas: "Fechas", participantes: "Participantes", referencia: "Referencia",
    noches: "noches", noche: "noche", personas: "participantes",
    concepto: "Concepto", cantidad: "Cant.", precio: "Precio unit.", iva: "IVA", importe: "Importe",
    subtotal: "Base imponible", ivade: "IVA {p} % sobre {b}", total: "TOTAL", senal: "Señal", senal_pct: "Señal ({p} %)",
    senal_cuando: "para confirmar la reserva", saldo: "Resto", saldo_cuando: "antes del {d}", saldo_antes: "antes de la llegada",
    notas: "Observaciones", pagos: "Forma de pago", condiciones: "Este presupuesto está sujeto a nuestras condiciones de contratación (versión {v}): {u}",
    confirmacion: "La reserva queda confirmada al aceptar el presupuesto, recibir la señal y confirmar el club la disponibilidad.",
    aceptado: "ACEPTADO el {d} por {n}", pagina: "Página {a} de {b}",
    instalaciones: "Instalaciones y acceso a pista", gimnasio: "Gimnasio y fuerza", material: "Material", transporte: "Transporte",
    entrenadores: "Entrenadores y asistencia técnica", servicios: "Servicios adicionales", otros: "Otros conceptos",
  },
};
const ORDEN_CAT = ["instalaciones", "gimnasio", "material", "transporte", "entrenadores", "servicios", "otros"];
const MESES: Record<string, string[]> = {
  en: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
  es: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"],
};

export function eurTexto(n: unknown, lang: string): string {
  const v = Number(n ?? 0);
  const [ent, dec] = Math.abs(v).toFixed(2).split(".");
  const miles = ent.replace(/\B(?=(\d{3})+(?!\d))/g, lang === "es" ? "." : ",");
  const s = (v < 0 ? "-" : "") + miles + (lang === "es" ? "," : ".") + dec;
  return lang === "es" ? s + " €" : "€" + s;
}
export function fecha(d: unknown, lang: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(d ?? ""));
  if (!m) return "";
  return `${Number(m[3])} ${MESES[lang === "es" ? "es" : "en"][Number(m[2]) - 1]} ${m[1]}`;
}
function num(n: unknown, lang: string): string {
  const v = Number(n ?? 0);
  const s = Number.isInteger(v) ? String(v) : v.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
  return lang === "es" ? s.replace(".", ",") : s;
}
function rellena(s: string, o: Record<string, string>): string {
  return s.replace(/\{(\w+)\}/g, (_, k) => o[k] ?? "");
}

// Caracteres que la Helvetica estándar (WinAnsi) sí sabe escribir.
const EXTRA = "€‚ƒ„…†‡ˆ‰Š‹ŒŽ‘’“”•–—˜™š›œžŸ";
function limpia(s: unknown): string {
  return String(s ?? "").replace(/\t/g, " ").replace(/[→]/g, "->").split("").map((c) => {
    const k = c.charCodeAt(0);
    if ((k >= 0x20 && k <= 0x7e) || (k >= 0xa0 && k <= 0xff) || EXTRA.includes(c)) return c;
    if (c === "\n") return c;
    return "";
  }).join("");
}

export async function presupuestoPdf(lib: Lib, d: any, logo?: Uint8Array | null): Promise<Uint8Array> {
  const { PDFDocument, StandardFonts, rgb } = lib;
  const lang = d.idioma === "es" ? "es" : "en";
  const t = T[lang];
  const eur = (n: unknown, l: string) => eurTexto(n, l).replace("€", l === "es" ? "€" : "€\u00A0").replace("\u00A0€", " €");
  const doc = await PDFDocument.create();
  doc.setTitle(`${t.titulo} ${d.numero}`);
  doc.setAuthor("Club Atletismo Apolana");
  doc.setCreator("atletismoapolana.com");
  const F = await doc.embedFont(StandardFonts.Helvetica);
  const FB = await doc.embedFont(StandardFonts.HelveticaBold);
  let img: any = null;
  if (logo && logo.length) { try { img = await doc.embedPng(logo); } catch { img = null; } }

  const NAVY = rgb(0.18, 0.259, 0.337), AZUL = rgb(0.184, 0.435, 0.659), CREMA = rgb(0.945, 0.918, 0.863);
  const CREMA2 = rgb(0.984, 0.976, 0.957), LINEA = rgb(0.894, 0.863, 0.796), TEXTO = rgb(0.29, 0.267, 0.216);
  const SUAVE = rgb(0.431, 0.4, 0.337), BLANCO = rgb(1, 1, 1), VERDE = rgb(0.247, 0.478, 0.298), VERDE_F = rgb(0.929, 0.961, 0.933);
  const W = 595.28, H = 841.89, M = 46, DER = W - M;
  const paginas: any[] = [];
  let pg: any, y = 0;

  const txt = (s: string, x: number, yy: number, o: { f?: any; z?: number; c?: any; der?: boolean; centro?: boolean } = {}) => {
    const f = o.f ?? F, z = o.z ?? 9.5, s2 = limpia(s);
    let xx = x;
    if (o.der) xx = x - f.widthOfTextAtSize(s2, z);
    else if (o.centro) xx = x - f.widthOfTextAtSize(s2, z) / 2;
    pg.drawText(s2, { x: xx, y: yy, size: z, font: f, color: o.c ?? TEXTO });
  };
  const partir = (s: string, f: any, z: number, max: number): string[] => {
    const out: string[] = [];
    for (const parrafo of limpia(s).split("\n")) {
      let linea = "";
      for (const pal of parrafo.split(/\s+/).filter(Boolean)) {
        const prueba = linea ? linea + " " + pal : pal;
        if (f.widthOfTextAtSize(prueba, z) <= max) { linea = prueba; continue; }
        if (linea) out.push(linea);
        linea = pal;
        while (f.widthOfTextAtSize(linea, z) > max && linea.length > 1) {   // palabra larguísima (un enlace)
          let i = linea.length; while (i > 1 && f.widthOfTextAtSize(linea.slice(0, i), z) > max) i--;
          out.push(linea.slice(0, i)); linea = linea.slice(i);
        }
      }
      out.push(linea);
    }
    return out;
  };
  const caja = (x: number, yy: number, w: number, h: number, color: any) => pg.drawRectangle({ x, y: yy, width: w, height: h, color });
  const raya = (x1: number, yy: number, x2: number, c = LINEA, g = 0.6) => pg.drawLine({ start: { x: x1, y: yy }, end: { x: x2, y: yy }, thickness: g, color: c });

  function nuevaPagina(primera: boolean) {
    pg = doc.addPage([W, H]);
    paginas.push(pg);
    // franja superior
    caja(0, H - 6, W, 6, NAVY);
    const top = H - 30;
    if (img) {
      const z = primera ? 58 : 34;
      pg.drawImage(img, { x: M, y: top - z, width: z, height: z });
      txt("CLUB ATLETISMO APOLANA", M + z + 12, top - (primera ? 22 : 15), { f: FB, z: primera ? 13 : 10.5, c: NAVY });
      txt(t.sub, M + z + 12, top - (primera ? 37 : 27), { z: primera ? 9.5 : 8.5, c: SUAVE });
    } else {
      txt("CLUB ATLETISMO APOLANA", M, top - 18, { f: FB, z: 13, c: NAVY });
      txt(t.sub, M, top - 32, { z: 9.5, c: SUAVE });
    }
    if (primera) {
      txt(t.titulo, DER, top - 20, { f: FB, z: 22, c: NAVY, der: true });
      txt(`${t.numero} ${d.numero}`, DER, top - 36, { f: FB, z: 10, c: AZUL, der: true });
      const linea = `${t.fecha} ${fecha(d.fecha, lang)}` + (d.valido_hasta ? `   ·   ${t.valido} ${fecha(d.valido_hasta, lang)}` : "");
      txt(linea, DER, top - 50, { z: 8.5, c: SUAVE, der: true });
      y = top - 74;
    } else {
      txt(`${t.titulo} ${d.numero}`, DER, top - 15, { f: FB, z: 10, c: NAVY, der: true });
      y = top - 50;
    }
    raya(M, y, DER, LINEA, 0.8);
    y -= 16;
  }
  function sitio(h: number) { if (y - h < 70) { nuevaPagina(false); return true; } return false; }

  nuevaPagina(true);

  // --- Dos fichas: cliente y concentración ---
  const ex = d.expediente ?? {};
  const colW = (DER - M - 14) / 2;
  const ficha = (x: number, titulo: string, filas: [string, string][]) => {
    caja(x, y - 20, colW, 20, CREMA);
    txt(titulo, x + 10, y - 13.5, { f: FB, z: 8, c: SUAVE });
    let yy = y - 34, primera = true;
    for (const [k, v] of filas) {
      if (!v) continue;
      if (k) { txt(k, x + 10, yy, { z: 8.5, c: SUAVE }); }
      const negrita = !k && primera;
      const f = negrita ? FB : F, z = negrita ? 10.5 : 9.5;
      const lineas = partir(v, f, z, colW - (k ? 92 : 20));
      lineas.forEach((l, i) => txt(l, x + (k ? 82 : 10), yy - i * 12, { f, z, c: negrita ? NAVY : TEXTO }));
      yy -= Math.max(1, lineas.length) * 12 + 3;
      primera = false;
    }
    return yy;
  };
  let noches = "";
  if (d.llegada && d.salida) {
    const n = Math.round((Date.parse(d.salida) - Date.parse(d.llegada)) / 86400000);
    if (n > 0) noches = ` (${n} ${n === 1 ? t.noche : t.noches})`;
  }
  let fechas = "";
  if (d.llegada) {
    const a = fecha(d.llegada, lang), b = fecha(d.salida, lang);
    const mismoAnio = String(d.llegada).slice(0, 4) === String(d.salida ?? "").slice(0, 4);
    fechas = `${mismoAnio ? a.replace(/ \d{4}$/, "") : a} – ${b}${noches}`;
  }
  const y1 = ficha(M, t.para, [["", ex.entidad ?? ""], ["", ex.contacto ?? ""], ["", ex.email ?? ""], ["", ex.pais ?? ""]]);
  const y2 = ficha(M + colW + 14, t.camp, [[t.fechas, fechas], [t.participantes, d.participantes ? `${d.participantes} ${t.personas}` : ""],
    [t.referencia, ex.codigo ?? ""]]);
  y = Math.min(y1, y2) - 8;
  if (d.titulo) {
    for (const l of partir(d.titulo, FB, 12, DER - M)) { txt(l, M, y, { f: FB, z: 12, c: NAVY }); y -= 15; }
    y -= 4;
  }

  // --- Tabla de conceptos ---
  const X_CANT = 352, X_PRECIO = 432, X_IVA = 474, X_IMP = DER - 8;
  const cabeceraTabla = () => {
    caja(M, y - 20, DER - M, 20, NAVY);
    txt(t.concepto, M + 10, y - 13.5, { f: FB, z: 8.5, c: BLANCO });
    txt(t.cantidad, X_CANT, y - 13.5, { f: FB, z: 8.5, c: BLANCO, der: true });
    txt(t.precio, X_PRECIO, y - 13.5, { f: FB, z: 8.5, c: BLANCO, der: true });
    txt(t.iva, X_IVA, y - 13.5, { f: FB, z: 8.5, c: BLANCO, der: true });
    txt(t.importe, X_IMP, y - 13.5, { f: FB, z: 8.5, c: BLANCO, der: true });
    y -= 24;
  };
  sitio(60);
  cabeceraTabla();
  const lineas: any[] = Array.isArray(d.lineas) ? d.lineas : [];
  const cats = ORDEN_CAT.filter((c) => lineas.some((l) => l.categoria === c));
  for (const cat of cats) {
    if (sitio(48)) cabeceraTabla();
    caja(M, y - 16, DER - M, 16, CREMA2);
    txt((t[cat] ?? cat).toUpperCase(), M + 10, y - 11, { f: FB, z: 7.5, c: AZUL });
    y -= 20;
    for (const l of lineas.filter((x) => x.categoria === cat)) {
      const desc = partir(l.descripcion ?? "", FB, 9.5, X_CANT - M - 70);
      const det = l.detalle ? partir(l.detalle, F, 8.5, X_CANT - M - 70) : [];
      const alto = desc.length * 12 + det.length * 10.5 + 8;
      if (sitio(alto + 4)) cabeceraTabla();
      desc.forEach((s, i) => txt(s, M + 10, y - 9 - i * 12, { f: FB, z: 9.5, c: NAVY }));
      det.forEach((s, i) => txt(s, M + 10, y - 9 - desc.length * 12 - i * 10.5, { z: 8.5, c: SUAVE }));
      const cant = num(l.cantidad, lang) + (l.unidad ? " " + l.unidad : "");
      txt(cant, X_CANT, y - 9, { z: 9.5, der: true });
      txt(eur(l.precio, lang), X_PRECIO, y - 9, { z: 9.5, der: true });
      txt(num(l.iva, lang) + " %", X_IVA, y - 9, { z: 9, c: SUAVE, der: true });
      txt(eur(l.importe, lang), X_IMP, y - 9, { f: FB, z: 9.5, c: NAVY, der: true });
      y -= alto;
      raya(M, y + 3, DER);
    }
    y -= 4;
  }

  // --- Totales ---
  const desglose: any[] = Array.isArray(d.desglose) ? d.desglose : [];
  const altoTot = 26 + desglose.length * 15 + 34 + 46;
  sitio(altoTot);
  const XT = 318;
  y -= 6;
  const filaTot = (k: string, v: string, o: { f?: any; z?: number; c?: any } = {}) => {
    txt(k, XT + 10, y, { f: o.f ?? F, z: o.z ?? 9.5, c: o.c ?? SUAVE });
    txt(v, X_IMP, y, { f: o.f ?? FB, z: o.z ?? 9.5, c: o.c ?? NAVY, der: true });
    y -= 15;
  };
  filaTot(t.subtotal, eur(d.base, lang));
  for (const r of desglose) filaTot(rellena(t.ivade, { p: num(r.pct, lang), b: eur(r.base, lang) }), eur(r.cuota, lang));
  y -= 12;
  caja(XT, y - 9, DER - XT, 26, NAVY);
  txt(t.total, XT + 10, y + 0.5, { f: FB, z: 11, c: BLANCO });
  txt(eur(d.total, lang), X_IMP, y + 0.5, { f: FB, z: 13, c: BLANCO, der: true });
  y -= 30;
  const senalTxt = d.senal_tipo === "porcentaje" ? rellena(t.senal_pct, { p: num(d.senal_valor, lang) }) : t.senal;
  txt(senalTxt, XT + 10, y, { f: FB, z: 9.5, c: NAVY });
  txt(eur(d.senal, lang), X_IMP, y, { f: FB, z: 9.5, c: NAVY, der: true });
  txt(t.senal_cuando, XT + 10, y - 11, { z: 8, c: SUAVE });
  y -= 26;
  txt(t.saldo, XT + 10, y, { f: FB, z: 9.5, c: NAVY });
  txt(eur(d.saldo, lang), X_IMP, y, { f: FB, z: 9.5, c: NAVY, der: true });
  txt(d.saldo_vence ? rellena(t.saldo_cuando, { d: fecha(d.saldo_vence, lang) }) : t.saldo_antes, XT + 10, y - 11, { z: 8, c: SUAVE });
  const yTot = y;

  // Sello de aceptado (a la izquierda de los totales)
  if (d.estado === "aceptado" && d.aceptado_en) {
    const s = rellena(t.aceptado, { d: fecha(String(d.aceptado_en).slice(0, 10), lang), n: d.aceptado_nombre || "—" });
    const lin = partir(s, FB, 9, XT - M - 30);
    const h = lin.length * 12 + 14;
    caja(M, yTot + 40 - h, XT - M - 16, h, VERDE_F);
    pg.drawRectangle({ x: M, y: yTot + 40 - h, width: 3, height: h, color: VERDE });
    lin.forEach((l, i) => txt(l, M + 12, yTot + 40 - 14 - i * 12, { f: FB, z: 9, c: VERDE }));
  }
  y -= 30;

  // --- Observaciones, pago, condiciones ---
  const bloque = (titulo: string, texto: string, z = 9) => {
    if (!texto) return;
    const ls = partir(texto, F, z, DER - M);
    sitio(22 + ls.length * (z + 3));
    txt(titulo.toUpperCase(), M, y, { f: FB, z: 7.5, c: SUAVE });
    y -= 13;
    for (const l of ls) { if (sitio(z + 3)) { /* sigue en la página nueva */ } txt(l, M, y, { z, c: TEXTO }); y -= z + 3; }
    y -= 8;
  };
  bloque(t.notas, d.notas_cliente ?? "");
  bloque(t.pagos, [d.formas_pago ?? "", t.confirmacion].filter(Boolean).join("\n"));
  if (d.nota_impuestos) bloque(t.iva, d.nota_impuestos, 8.5);
  if (d.condiciones_version) {
    const u = `atletismoapolana.com/training-camps/terms/${lang === "es" ? "?lang=es" : ""}`;
    for (const l of partir(rellena(t.condiciones, { v: String(d.condiciones_version), u }), F, 8, DER - M)) {
      sitio(11); txt(l, M, y, { z: 8, c: SUAVE }); y -= 11;
    }
  }

  // --- Pie en todas las páginas ---
  const em = d.emisor ?? {};
  const pie = [em.nombre, em.nif ? "NIF " + em.nif : "", em.direccion].filter(Boolean).join(" · ");
  const pie2 = [em.email, em.web].filter(Boolean).join(" · ");
  paginas.forEach((p, i) => {
    pg = p;
    raya(M, 52, DER, LINEA, 0.6);
    const ls = partir(pie, F, 7.5, DER - M - 70);
    ls.forEach((l, k) => txt(l, M, 40 - k * 9.5, { z: 7.5, c: SUAVE }));
    if (pie2) txt(pie2, M, 40 - ls.length * 9.5, { z: 7.5, c: SUAVE });
    txt(rellena(t.pagina, { a: String(i + 1), b: String(paginas.length) }), DER, 40, { z: 7.5, c: SUAVE, der: true });
  });
  return await doc.save();
}
