// ============================================================
// _shared/cubo-socio.ts · al hacerse socio, el Cubo se ajusta solo
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO (25-nov, caso Bibiana)
//   Alguien que ya entrena en el Cubo (cuota activa) se hace socio. Antes había
//   que hacer a mano: darle el papel «socio», marcarlo socio en su ficha del
//   Cubo y bajarle la cuota en el panel. Ahora, al firmarse la domiciliación del
//   alta (correo-alta-aviso, que corre UNA sola vez):
//     1 · Su cuenta (la del mismo correo) gana el papel «socio».
//     2 · Cada cuota del Cubo ACTIVA de esa cuenta pasa a tarifa de socio:
//         si lo que paga hoy es la tarifa general de sus días (30/40/50 =
//         1/2/3 días), se le pone la de socio de esos días (cubo_precio(días,
//         reducido=true)).
//         Si sale más barata, se cambia en Stripe desde el próximo recibo.
//     3 · Si paga algo que no es una tarifa general (precio a mano, escuela…),
//         NO se toca: se avisa para que Andrés lo mire.
//   Devuelve lo que hizo, para el correo y para guardarlo en
//   altas_socio.cubo_ajuste (mig 538): si el banco devuelve los 125 €,
//   cubo-webhook avisa a Andrés (no le sube la cuota solo).
//
// cambiarCuotaStripe lo comparte con cubo-pago («Cambiar cuota» del panel).
// ============================================================

export type CambioCubo = {
  alta_id: string;
  horario: string;
  antes: number;
  despues: number | null;
  estado: "bajada" | "ya_reducida" | "revisar" | "error";
  motivo?: string;
};
export type AjusteCubo = {
  en: string;
  rol_anadido: boolean;
  cubo: CambioCubo[];
};

async function stripeForm(key: string, ruta: string, metodo: string, campos?: Record<string, string>) {
  const init: RequestInit = { method: metodo, headers: { Authorization: `Bearer ${key}` } };
  if (campos) {
    (init.headers as Record<string, string>)["Content-Type"] = "application/x-www-form-urlencoded";
    init.body = new URLSearchParams(campos).toString();
  }
  const r = await fetch(`https://api.stripe.com/v1/${ruta}`, init);
  const d = await r.json().catch(() => null);
  return { ok: r.ok, estado: r.status, datos: d as Record<string, any> | null };
}

/**
 * Cambia la cuota mensual de una suscripción del Cubo (sin prorrateo: vale
 * desde el próximo recibo). Crea un precio nuevo en el mismo producto (o en uno
 * propio si el producto está archivado) y lo pone en el item de la suscripción.
 */
export async function cambiarCuotaStripe(
  key: string, sub: string, cents: number,
): Promise<{ ok: true } | { ok: false; mensaje: string }> {
  const rSub = await stripeForm(key, `subscriptions/${encodeURIComponent(sub)}?expand[]=items.data.price.product`, "GET");
  if (!rSub.ok) return { ok: false, mensaje: "No se ha podido leer la suscripción." };
  const item = rSub.datos?.items?.data?.[0];
  const prod = item?.price?.product;
  const producto: string = (typeof prod === "string" ? prod : prod?.id) ?? "";
  if (!item?.id || !producto) return { ok: false, mensaje: "No se ha podido identificar el precio actual." };
  // Los productos que crea el pago al vuelo (price_data) salen archivados y
  // Stripe no deja colgarles precios: entonces el precio lleva su producto.
  const prodActivo = typeof prod === "object" && prod ? prod.active !== false : true;
  const nombreProd: string = (typeof prod === "object" && prod?.name) ? prod.name : "Cuota El Cubo";
  const rPrice = await stripeForm(key, "prices", "POST", {
    currency: "eur", unit_amount: String(Math.abs(cents)),
    "recurring[interval]": "month",
    ...(prodActivo ? { product: producto } : { "product_data[name]": nombreProd }),
  });
  if (!rPrice.ok) return { ok: false, mensaje: "No se ha podido crear el precio nuevo." };
  const rUpd = await stripeForm(key, `subscriptions/${encodeURIComponent(sub)}`, "POST", {
    "items[0][id]": item.id, "items[0][price]": String(rPrice.datos?.id ?? ""), proration_behavior: "none",
  });
  if (!rUpd.ok) {
    console.error("Stripe update sub:", rUpd.datos?.error?.message ?? rUpd.estado);
    return { ok: false, mensaje: "Stripe no cambió la cuota: " + (rUpd.datos?.error?.message ?? "inténtalo otra vez") };
  }
  return { ok: true };
}

type Rest = (metodo: string, ruta: string, cuerpo?: unknown, extra?: Record<string, string>) =>
  Promise<{ ok: boolean; datos: any }>;

function hoy(): string {
  return new Intl.DateTimeFormat("es-ES", { timeZone: "Europe/Madrid", day: "numeric", month: "short" }).format(new Date());
}

/**
 * Hace socio en el Cubo a quien acaba de darse de alta de socio.
 * @param rest      llamada REST a Supabase con la clave de servicio.
 * @param stripeKey clave live de Apolana (las cuotas del Cubo son live).
 * @param simular   true con los pagos en modo prueba: no toca Stripe ni la base,
 *                  solo cuenta lo que haría.
 * Devuelve null si ese correo no tiene cuenta en la app.
 */
export async function cuboAlHacerseSocio(opts: {
  rest: Rest; stripeKey: string; email: string; altaSocioId: string; referencia: string; simular?: boolean;
}): Promise<AjusteCubo | null> {
  const { rest, stripeKey, simular } = opts;
  const email = opts.email.trim().toLowerCase();
  if (!email) return null;

  const rP = await rest("GET", `perfiles?select=id,roles&email=eq.${encodeURIComponent(email)}&limit=1`);
  const perfil = Array.isArray(rP.datos) ? rP.datos[0] as { id: string; roles?: string[] | null } : null;
  if (!perfil) return null;

  // 1 · Papel «socio» (sin tocar los demás) y el alta enlazada a su cuenta.
  const roles = Array.isArray(perfil.roles) ? perfil.roles : [];
  const rolAnadido = !roles.includes("socio");
  if (!simular) {
    if (rolAnadido) {
      const r = await rest("PATCH", `perfiles?id=eq.${perfil.id}`, { roles: [...roles, "socio"] }, { Prefer: "return=minimal" });
      if (!r.ok) console.error("cubo-socio: no se pudo añadir el papel socio:", r.datos);
    }
    await rest("PATCH", `altas_socio?id=eq.${encodeURIComponent(opts.altaSocioId)}&perfil_id=is.null`,
      { perfil_id: perfil.id }, { Prefer: "return=minimal" });
  }

  // 2 · Sus cuotas del Cubo activas que aún no son de socio.
  const rA = await rest("GET",
    `cubo_altas?select=id,horario,dias,dias_semana,precio_mes,es_socio,es_escuela,stripe_subscription_id,nota_cobro` +
    `&perfil_id=eq.${perfil.id}&suscripcion_estado=eq.activa&es_socio=eq.false`);
  const altas: any[] = Array.isArray(rA.datos) ? rA.datos : [];
  const cambios: CambioCubo[] = [];
  if (!altas.length) return { en: new Date().toISOString(), rol_anadido: rolAnadido, cubo: cambios };

  // Tarifas por días: general y de socio (hoy 30/40/50 y 20/30/30).
  const general = new Map<number, number>(), socio = new Map<number, number>();
  for (const d of [1, 2, 3]) {
    const [g, s] = await Promise.all([
      rest("POST", "rpc/cubo_precio", { p_dias: d, p_reducido: false }),
      rest("POST", "rpc/cubo_precio", { p_dias: d, p_reducido: true }),
    ]);
    if (Number(g.datos) > 0) general.set(d, Number(g.datos));
    if (Number(s.datos) > 0) socio.set(d, Number(s.datos));
  }
  // Su tarifa de socio: la de los días que tiene (entre semana, o contando el
  // sábado) cuya tarifa GENERAL es justo lo que paga hoy. Así 30 € con 1 día →
  // 20 €, pero 30 € con 2 días (ya reducida) no casa y se deja para mirarlo.
  const tarifaSocio = (a: any): number | null => {
    const antes = Number(a.precio_mes) || 0;
    const dias = [Number(a.dias), Array.isArray(a.dias_semana) ? a.dias_semana.length : 0];
    for (const d of dias) if (general.get(d) === antes && socio.has(d)) return socio.get(d)!;
    return null;
  };

  for (const a of altas) {
    const antes = Number(a.precio_mes) || 0;
    const horario = String(a.horario ?? "").replace(/^El Cubo\s*·\s*/, "");
    const base = { alta_id: String(a.id), horario, antes };
    const nota = (txt: string) => [txt, a.nota_cobro].filter(Boolean).join(" · ").slice(0, 500);

    // Familia de escuela: ya paga la reducida. Solo se le marca socio.
    if (a.es_escuela) {
      if (!simular) await rest("PATCH", `cubo_altas?id=eq.${a.id}`, { es_socio: true }, { Prefer: "return=minimal" });
      cambios.push({ ...base, despues: antes, estado: "ya_reducida", motivo: "Ya pagaba la tarifa reducida (familia de escuela)." });
      continue;
    }
    const despues = tarifaSocio(a);
    if (despues == null) {
      // Precio que no es una tarifa general: a mano. Se marca socio igualmente
      // (lo es) y la nota de cobro lo deja dicho en su ficha.
      if (!simular) {
        await rest("PATCH", `cubo_altas?id=eq.${a.id}`,
          { es_socio: true, nota_cobro: nota(`${hoy()}: se hace socio (${opts.referencia}); paga ${antes} €, que no es tarifa general: revisar cuota a mano`) },
          { Prefer: "return=minimal" });
      }
      cambios.push({ ...base, despues: null, estado: "revisar", motivo: `Paga ${antes} €/mes, que no es una tarifa general: revisa su cuota a mano.` });
      continue;
    }
    if (despues >= antes) {
      if (!simular) await rest("PATCH", `cubo_altas?id=eq.${a.id}`, { es_socio: true }, { Prefer: "return=minimal" });
      cambios.push({ ...base, despues: antes, estado: "ya_reducida" });
      continue;
    }
    if (!a.stripe_subscription_id) {
      cambios.push({ ...base, despues, estado: "error", motivo: "Su cuota no tiene suscripción en Stripe." });
      continue;
    }
    if (simular) { cambios.push({ ...base, despues, estado: "bajada", motivo: "(modo prueba: no se ha cambiado)" }); continue; }

    const r = await cambiarCuotaStripe(stripeKey, String(a.stripe_subscription_id), despues * 100);
    if (!r.ok) {
      // Sin tocar es_socio: así sigue saliendo como «no socio» y se ve que falta.
      cambios.push({ ...base, despues, estado: "error", motivo: r.mensaje });
      continue;
    }
    await rest("PATCH", `cubo_altas?id=eq.${a.id}`, {
      es_socio: true, precio_mes: despues,
      nota_cobro: nota(`${hoy()}: se hace socio (${opts.referencia}) → cuota de ${antes} € a ${despues} €/mes desde el próximo recibo (automático)`),
    }, { Prefer: "return=minimal" });
    cambios.push({ ...base, despues, estado: "bajada" });
  }

  return { en: new Date().toISOString(), rol_anadido: rolAnadido, cubo: cambios };
}

/**
 * El banco ha rechazado o devuelto los 125 € de un alta de socio. Si al
 * firmarla se le bajó la cuota del Cubo, avisa a Andrés (UNA vez) para que se la
 * vuelva a subir. No la sube sola: puede ser un fallo del banco que se arregla
 * volviendo a pagar. Lo llama cubo-webhook.
 */
export async function avisarAjusteDevuelto(opts: {
  supabaseUrl: string; serviceKey: string; altaId: string; motivo: "rechazado" | "devuelto";
}): Promise<void> {
  const { supabaseUrl, serviceKey, altaId } = opts;
  if (!/^[0-9a-f-]{36}$/i.test(altaId)) return;
  const cab = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, "Content-Type": "application/json" };
  const rA = await fetch(`${supabaseUrl}/rest/v1/altas_socio?select=nombre,apellidos,referencia,cubo_ajuste&id=eq.${altaId}&limit=1`, { headers: cab });
  const a = rA.ok ? (await rA.json().catch(() => []))?.[0] : null;
  const ajuste = a?.cubo_ajuste as (AjusteCubo & { alerta_enviada_en?: string }) | null;
  const bajadas = (ajuste?.cubo ?? []).filter((c) => c.estado === "bajada" && !String(c.motivo ?? "").includes("modo prueba"));
  if (!ajuste || !bajadas.length || ajuste.alerta_enviada_en) return;

  // Reclamo atómico: solo el primero que llegue manda el correo.
  const rC = await fetch(
    `${supabaseUrl}/rest/v1/altas_socio?id=eq.${altaId}&cubo_ajuste->>alerta_enviada_en=is.null`,
    { method: "PATCH", headers: { ...cab, Prefer: "return=representation" },
      body: JSON.stringify({ cubo_ajuste: { ...ajuste, alerta_enviada_en: new Date().toISOString() } }) },
  );
  const filasC = rC.ok ? await rC.json().catch(() => null) : null;
  const reclamado = Array.isArray(filasC) && filasC.length > 0;
  if (!reclamado) return;

  const BREVO = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
  if (!BREVO) { console.error("cubo-socio: sin BREVO_API_KEY, no se avisa de la devolución"); return; }
  const remitente = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
  const remNombre = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
  const destino = (Deno.env.get("CORREO_RESPUESTAS") ?? "andres.apolana@gmail.com").trim();
  const base = (Deno.env.get("CORREO_URL_BASE") ?? "https://atletismoapolana.com").replace(/\/+$/, "");
  const esc = (v: unknown) => String(v ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
  const nombre = `${a.nombre ?? ""} ${a.apellidos ?? ""}`.trim() || a.referencia;
  const que = opts.motivo === "rechazado" ? "ha rechazado" : "ha devuelto";
  const filas = bajadas.map((c) =>
    `<p style="margin:6px 0 0;font-size:14px">${esc(c.horario)}: se le bajó de <b>${c.antes} €</b> a <b>${c.despues} €/mes</b>. ` +
    `<a href="${esc(`${base}/admin/cubo-altas/?ver=${c.alta_id}#altas`)}" style="color:#22496d">Abrir su ficha →</a></p>`).join("");
  const html = `<!doctype html><html lang="es"><body style="margin:0;background:#f4f4f5;padding:24px;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
    <div style="max-width:560px;margin:0 auto;background:#fff;border-radius:14px;border:1px solid #e4e4e7;overflow:hidden">
      <div style="background:#9a3412;color:#fff;padding:16px 22px;font-size:16px;font-weight:700">El banco ${que} el alta de socio de ${esc(nombre)}</div>
      <div style="padding:20px 22px">
        <p style="margin:0;font-size:15px">Al firmar el alta (${esc(a.referencia)}) se le puso la cuota de socio en el Cubo:</p>
        ${filas}
        <p style="margin:14px 0 0;font-size:14px;color:#3f3f46">Si no lo arregla (volver a pagar los 125 €), súbele la cuota en su ficha con <b>«Cambiar cuota»</b>. No se ha tocado nada solo.</p>
      </div>
    </div></body></html>`;
  const texto = `El banco ${que} el alta de socio de ${nombre} (${a.referencia}). Al firmarla se le bajó la cuota del Cubo: ` +
    bajadas.map((c) => `${c.horario} de ${c.antes} € a ${c.despues} €/mes (${base}/admin/cubo-altas/?ver=${c.alta_id}#altas)`).join("; ") +
    ". Si no lo arregla, súbele la cuota con «Cambiar cuota».";
  const r = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: { "api-key": BREVO, "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify({
      sender: { name: remNombre, email: remitente }, to: [{ email: destino }],
      subject: `Alta de socio ${opts.motivo} · ${nombre} tiene la cuota del Cubo de socio`,
      htmlContent: html, textContent: texto,
    }),
  }).catch((e) => { console.error("cubo-socio: Brevo falló:", e); return null; });
  if (r && !r.ok) console.error("cubo-socio: Brevo rechazó el aviso:", r.status, await r.text().catch(() => ""));
}
