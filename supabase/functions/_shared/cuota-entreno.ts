// ============================================================
// _shared/cuota-entreno.ts · UNA sola regla para las cuotas recurrentes
// (`cuotas_entreno`) que salen del asistente «Nuevo cobro» (mig 380).
// ------------------------------------------------------------
// La usan entreno-pagar (pasarela), cubo-webhook y entreno-resync (fila en
// `pagos` de cada cobro) y entreno-enlace (textos del correo). Se empaqueta
// con cada función al hacer `supabase functions deploy` (import relativo).
//
// Las cuotas VIEJAS (origen NULL: los 6 adultos trimestrales y Maia) siguen
// EXACTAMENTE como antes: mismo concepto en `pagos`, mismos textos.
// ============================================================

export type Cuota = {
  periodicidad?: string | null;   // mensual · trimestral · anual
  metodo?: string | null;         // sepa · tarjeta
  origen?: string | null;         // 'asistente' = «Nuevo cobro» · 'natacion' = Natación › Cuotas y cobros (395)
  concepto?: string | null;
  inicio?: string | null;         // YYYY-MM-DD (día 1 del mes de inicio)
  fin?: string | null;            // YYYY-MM-DD (último día que cubre)
};

const MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
  "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
const MES3 = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

// 'natacion' (mig 395) = creada por el responsable de natación en
// portal/natacion-cuotas: mismo formato que el asistente (mes de inicio, fin,
// concepto propio), así que se comporta IGUAL (cobro diferido, recibo, correo).
export const esAsistente = (c: Cuota | null | undefined): boolean =>
  c?.origen === "asistente" || c?.origen === "natacion";
export const esTarjeta = (c: Cuota | null | undefined): boolean => c?.metodo === "tarjeta";

// Intervalo de la suscripción de Stripe.
export function intervalo(periodicidad: string | null | undefined): { interval: "month" | "year"; count: number } {
  if (periodicidad === "mensual") return { interval: "month", count: 1 };
  if (periodicidad === "anual") return { interval: "year", count: 1 };
  return { interval: "month", count: 3 };   // trimestral (lo de siempre)
}

// Hora a la que arranca una cuota con mes de inicio futuro: 08:00 UTC del día 1
// (9-10 h en Madrid). Stripe exige que el fin de la «prueba» esté a más de 48 h.
export function inicioUnix(inicio: string | null | undefined): number | null {
  if (!inicio || !/^\d{4}-\d{2}-\d{2}$/.test(inicio)) return null;
  const t = Date.parse(`${inicio}T08:00:00Z`);
  return Number.isFinite(t) ? Math.floor(t / 1000) : null;
}
const MARGEN_DIFERIDO_S = 49 * 3600;
// ¿El primer cobro espera al mes de inicio? (si no, se cobra al pagar/domiciliar)
export function cobroDiferido(c: Cuota, ahoraMs = Date.now()): number | null {
  const t = inicioUnix(c.inicio);
  if (!t) return null;
  return t - Math.floor(ahoraMs / 1000) > MARGEN_DIFERIDO_S ? t : null;
}

// "2026-10-14" en Madrid de un instante unix.
const ymdMadrid = (unix: number): string =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid", year: "numeric", month: "2-digit", day: "2-digit" })
    .format(new Date(unix * 1000));

// Concepto, periodo y método de la fila que deja en `pagos` un cobro liquidado.
// `inicioPeriodo` = inicio (unix) del periodo que paga la factura.
export function cobroEnPagos(c: Cuota, inicioPeriodo: number): { concepto: string; periodo: string; metodo: "tarjeta" | "domiciliado" } {
  if (!esAsistente(c)) {
    // Regla de siempre (en UTC, como estaba): trimestre de la temporada.
    const d = inicioPeriodo > 0 ? new Date(inicioPeriodo * 1000) : new Date();
    const mes = d.getUTCMonth() + 1, ano = d.getUTCFullYear();
    const etq = mes >= 10 ? `1er trimestre (oct-dic ${ano})`
      : mes <= 3 ? `2º trimestre (ene-mar ${ano})`
      : mes <= 6 ? `3er trimestre (abr-jun ${ano})` : "trimestre";
    return { concepto: `Cuota de entrenamiento · ${etq}`, periodo: `${ano}-${String(mes).padStart(2, "0")}`, metodo: "domiciliado" };
  }
  const [y, m] = ymdMadrid(inicioPeriodo > 0 ? inicioPeriodo : Math.floor(Date.now() / 1000)).split("-").map(Number);
  let etq: string;
  if (c.periodicidad === "mensual") {
    etq = `${MESES[m - 1]} ${y}`;
  } else {
    const n = c.periodicidad === "anual" ? 12 : 3;
    const mf = ((m - 1 + n - 1) % 12) + 1;
    const yf = y + Math.floor((m - 1 + n - 1) / 12);
    etq = yf === y ? `${MES3[m - 1]}-${MES3[mf - 1]} ${y}` : `${MES3[m - 1]} ${y}-${MES3[mf - 1]} ${yf}`;
  }
  const base = String(c.concepto ?? "").trim() || "Cuota";
  return {
    concepto: `${base} · ${etq}`,
    periodo: `${y}-${String(m).padStart(2, "0")}`,
    metodo: esTarjeta(c) ? "tarjeta" : "domiciliado",
  };
}

// Fecha legible: "1 de diciembre de 2026".
export function fechaLarga(iso: string | null | undefined): string {
  if (!iso || !/^\d{4}-\d{2}-\d{2}/.test(iso)) return "";
  const [y, m, d] = iso.slice(0, 10).split("-").map(Number);
  return `${d} de ${MESES[m - 1]} de ${y}`;
}

// Textos para el correo de una cuota del asistente (sepa/tarjeta × periodicidad).
export function textosCuota(c: Cuota, ahoraMs = Date.now()) {
  const tarjeta = esTarjeta(c);
  const cada = c.periodicidad === "mensual" ? "al mes" : c.periodicidad === "anual" ? "al año" : "cada 3 meses";
  const repite = c.periodicidad === "mensual" ? "cada mes" : c.periodicidad === "anual" ? "cada año" : "cada 3 meses";
  const diferido = cobroDiferido(c, ahoraMs);
  const verbo = tarjeta ? "pagar" : "domiciliar";
  const primero = diferido
    ? `El primer cobro será el ${fechaLarga(c.inicio)}; después, ${repite} en esa misma fecha.`
    : `El primer cobro se hace al ${verbo} y después ${repite} en esa misma fecha.`;
  const fin = c.fin ? `Se para sola el ${fechaLarga(c.fin)}: después no se cobra nada más.` : "";
  const como = tarjeta
    ? "con <b>tarjeta</b>: la metes <b>una sola vez</b> y la cuota se cobra sola"
    : "por <b>domiciliación bancaria (SEPA)</b>: metes el IBAN <b>una sola vez</b> y la cuota se cobra sola";
  const comoTxt = como.replace(/<\/?b>/g, "");
  const seguro = tarjeta
    ? "La tarjeta se teclea en la pantalla segura de Stripe, nunca en nuestra web."
    : "El IBAN se teclea en la pantalla segura de Stripe, nunca en nuestra web. El adeudo tarda unos días en llegar al banco.";
  const boton = tarjeta ? "Pagar con tarjeta →" : "Domiciliar la cuota →";
  return { tarjeta, cada, primero, fin, como, comoTxt, seguro, boton };
}

// ============================================================
// FECHA DE PARADA EXACTA (revisión 380)
// ------------------------------------------------------------
// Stripe PRORRATEA el último periodo si `cancel_at` cae a mitad de periodo
// (y eso no lo quita proration_behavior). Así que la cuota se para justo en
// un LÍMITE DE PERIODO: el primero que cae en o después del final del día
// `fin` (hora de Madrid). Ningún periodo se acorta, el último cobro va entero
// y no hay ningún cobro después de `fin`.
//   · Cuotas sin `fin` (los adultos trimestrales de 2026/27): el límite justo
//     después del cobro de abril → `finPorDefecto` (6-may-2027) da ~7-jul.
// ============================================================

// Final del día `fin` en Madrid (= 00:00 del día siguiente), en unix.
export function finDelDiaMadrid(fin: string): number | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(fin || "")) return null;
  const [y, m, d] = fin.split("-").map(Number);
  const prueba = Date.UTC(y, m - 1, d + 1, 12, 0, 0);
  const h = Number(new Intl.DateTimeFormat("en-GB", { timeZone: "Europe/Madrid", hour: "2-digit", hourCycle: "h23" })
    .format(new Date(prueba)));
  return Math.floor((Date.UTC(y, m - 1, d + 1, 0, 0, 0) - (h - 12) * 3600 * 1000) / 1000);
}

// Límite k-ésimo de periodo desde el ancla, como lo calcula Stripe: mismo día
// del mes que el ancla (si el mes no lo tiene, el último día), misma hora UTC.
export function limitePeriodo(ancla: number, meses: number, k: number): number {
  const a = new Date(ancla * 1000);
  const total = a.getUTCMonth() + meses * k;
  const y = a.getUTCFullYear() + Math.floor(total / 12);
  const m = ((total % 12) + 12) % 12;
  const ultimo = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
  const d = Math.min(a.getUTCDate(), ultimo);
  return Math.floor(Date.UTC(y, m, d, a.getUTCHours(), a.getUTCMinutes(), a.getUTCSeconds()) / 1000);
}

// De una suscripción de Stripe (tal cual la devuelve la API) y del final que
// toca (unix), el `cancel_at` exacto y cuántos cobros hará en total.
export function cancelAtExacto(sub: Record<string, any>, finUnix: number):
  { cancelAt: number; cobros: number; ancla: number; meses: number } | { error: string } {
  const ancla = Number(sub?.billing_cycle_anchor ?? 0);
  const rec = sub?.items?.data?.[0]?.price?.recurring ?? sub?.items?.data?.[0]?.plan ?? sub?.plan ?? null;
  const intervalo = String(rec?.interval ?? "");
  const cuenta = Number(rec?.interval_count ?? 1) || 1;
  const meses = intervalo === "month" ? cuenta : intervalo === "year" ? 12 * cuenta : 0;
  if (!(ancla > 0) || !meses) return { error: `suscripción sin ancla o con intervalo raro (${intervalo || "?"})` };
  // El primer cobro es el ancla (con «prueba» hasta el mes de inicio, el ancla
  // es el fin de la prueba). Si el ancla ya pasa del final, no debería cobrar
  // nada: se para en el propio ancla.
  let k = 0;
  while (limitePeriodo(ancla, meses, k) < finUnix && k < 400) k++;
  return { cancelAt: limitePeriodo(ancla, meses, k), cobros: k, ancla, meses };
}

// El final que toca a una cuota: su `fin` o, si no tiene, la regla de la
// trimestral de adultos (tras abril).
export const ENTRENO_FIN_POR_DEFECTO = Math.floor(Date.UTC(2027, 4, 6, 9, 0, 0) / 1000);
export function finUnixDe(fin: string | null | undefined): number {
  return (fin ? finDelDiaMadrid(fin) : null) ?? ENTRENO_FIN_POR_DEFECTO;
}
