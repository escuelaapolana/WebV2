// ============================================================
// _shared/cubo-pausa.ts · UNA sola regla para «pausar un mes» el Cubo
// ------------------------------------------------------------
// La usan la Edge `cubo-pausa` (al aprobar / aplicar / deshacer) y
// `cubo-webhook` (al aplicar una pausa programada tras el cobro del mes
// anterior). Así las dos deciden igual. Se empaqueta con cada función al
// hacer `supabase functions deploy` (import relativo).
// ============================================================

export const MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
  "agosto", "septiembre", "octubre", "noviembre", "diciembre"];

// "2026-11-05" (fecha en Madrid) de un instante unix (segundos).
export const isoMadrid = (unix: number): string =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Madrid", year: "numeric", month: "2-digit", day: "2-digit" })
    .format(new Date(unix * 1000));

// Las 12:00 de Madrid (hora real, con horario de verano) de un día → unix.
export function mediodiaMadrid(y: number, m: number, d: number): number {
  const prueba = Date.UTC(y, m - 1, d, 12, 0, 0);
  const h = Number(new Intl.DateTimeFormat("en-GB", { timeZone: "Europe/Madrid", hour: "2-digit", hourCycle: "h23" })
    .format(new Date(prueba)));
  return Math.floor((prueba - (h - 12) * 3600 * 1000) / 1000);
}
// Fin de la pausa por defecto: día 6 a mediodía (Madrid) del mes pausado.
export function resumesBase(mes: string): number {
  const [y, m] = mes.split("-").map(Number);
  return mediodiaMadrid(y, m, 6);
}

// Próximo recibo de la suscripción (en APIs nuevas vive en el item).
export function finPeriodo(s: any): number {
  return Number(s?.current_period_end ?? s?.items?.data?.[0]?.current_period_end ?? 0);
}

export type Plan =
  | { tipo: "aplicar"; resumes: number; diaCobro: number }
  | { tipo: "programar"; diaCobro: number }
  | { tipo: "ya"; resumes: number; diaCobro: number }
  | { tipo: "error"; codigo: string; mensaje: string; http: number };

// Qué hacer con la suscripción `s` (objeto de Stripe, con latest_invoice
// expandido si se puede) para que NO se cobre el recibo del mes `mes`
// ("YYYY-MM-01"):
//   aplicar   → el próximo recibo ES el de ese mes: poner pause_collection ya.
//   programar → el próximo recibo es de un mes anterior: aún no (pausar ya
//               anularía también ese otro recibo).
//   ya        → ya está pausada con NUESTRA pausa (idempotente).
//   error     → no se puede (sub no activa, otra pausa ajena, ya cobrado…).
export function planificar(s: any, mes: string): Plan {
  const st = String(s?.status ?? "");
  if (st !== "active" && st !== "trialing") {
    return { tipo: "error", codigo: "sub_no_activa", http: 409, mensaje: `La suscripción no está activa en Stripe (${st || "sin estado"}).` };
  }
  const fin = finPeriodo(s);
  if (!fin) return { tipo: "error", codigo: "sin_periodo", http: 502, mensaje: "Stripe no dice cuándo es el próximo cobro." };
  const finIso = isoMadrid(fin);
  const mesRenov = finIso.slice(0, 7);
  const mesPausa = mes.slice(0, 7);
  const diaCobro = Number(finIso.slice(8, 10)) || 5;
  // Nunca quitar la pausa ANTES del recibo (por si un día el ancla no es el 5).
  const resumes = Math.max(resumesBase(mes), fin + 24 * 3600);

  const pc = s.pause_collection;
  if (pc) {
    // Ya pausada: si es la nuestra (cubre el recibo de ese mes), nada que hacer.
    // Si es otra (p. ej. la vieja «Pausar pagos» indefinida) NO se pisa.
    if (pc.behavior === "void" && pc.resumes_at && Number(pc.resumes_at) >= fin && mesRenov === mesPausa) {
      return { tipo: "ya", resumes: Number(pc.resumes_at), diaCobro };
    }
    return { tipo: "error", codigo: "ya_pausada", http: 409, mensaje: "Esta suscripción ya tiene los cobros en pausa en Stripe (otra pausa). Revísalo antes (botón «Reanudar pagos»)." };
  }
  if (mesRenov === mesPausa) {
    // Recibo aún en borrador (justo en la renovación): esperar.
    const inv = s.latest_invoice;
    if (inv && typeof inv === "object" && inv.status === "draft") {
      return { tipo: "error", codigo: "espera", http: 409, mensaje: "Stripe está generando un recibo ahora mismo; vuelve a intentarlo en un par de horas." };
    }
    return { tipo: "aplicar", resumes, diaCobro };
  }
  if (mesRenov < mesPausa) return { tipo: "programar", diaCobro };
  return { tipo: "error", codigo: "tarde", http: 409, mensaje: `El recibo de ${MESES[Number(mesPausa.slice(5, 7)) - 1]} ya se ha generado: no se puede pausar.` };
}

// Cargos/descuentos sueltos (invoice items) PENDIENTES de esta persona: irían
// al próximo recibo; si ese recibo se anula por la pausa, se perderían.
export async function cargosPendientes(key: string, cliente: string): Promise<{ ok: boolean; items: Array<{ importe: number; texto: string }> }> {
  if (!cliente) return { ok: true, items: [] };
  const r = await fetch(`https://api.stripe.com/v1/invoiceitems?customer=${encodeURIComponent(cliente)}&pending=true&limit=20`,
    { headers: { Authorization: `Bearer ${key}` } });
  if (!r.ok) return { ok: false, items: [] };
  const d = await r.json().catch(() => null);
  const items = (Array.isArray(d?.data) ? d.data : []).map((x: any) => ({
    importe: Number(x.amount ?? 0) / 100,
    texto: String(x.description ?? "cargo"),
  }));
  return { ok: true, items };
}
export function textoCargos(items: Array<{ importe: number; texto: string }>): string {
  return items.map((i) => `${i.texto} (${i.importe.toFixed(2).replace(".", ",")} €)`).join(", ");
}
