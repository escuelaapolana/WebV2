// ============================================================
// camp-publico · lo que hace el cliente con sus enlaces (sin cuenta)
// ------------------------------------------------------------
// El token del enlace es el permiso (64 caracteres al azar).
//   { accion:"propuesta", t }        → su presupuesto (sin costes ni notas internas)
//   { accion:"pdf", t }              → el PDF del presupuesto (base64)
//   { accion:"aceptar", t, nombre, acepto:true } → lo acepta (+ aviso a Andrés)
//   { accion:"pago", t }             → datos de un pago pedido (señal / resto)
//   { accion:"pagar", t }            → abre Stripe (cuenta Apolana, pagos_config.modo)
//   { accion:"comprobar", t }        → al volver: pregunta a STRIPE si está cobrado
//                                      y, si lo está, lo confirma (pagos_confirmar)
// Un pago solo cuenta como cobrado cuando lo dice Stripe (webhook de siempre o
// esta comprobación con la API): abrir la página de «gracias» no marca nada.
//
//   supabase functions deploy camp-publico --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

// deno-lint-ignore-file no-explicit-any
import * as PDFLib from "npm:pdf-lib@1.17.1";
import { presupuestoPdf } from "../_shared/camp-pdf.ts";
import {
  base64, cors, correoClub, correoHtml, enlacePanel, enlacePropuesta, enviarCorreo, esc, eurTxt, fechaTxt, logo,
  origenValido, responder, rest, rpc, SERVICE_KEY, SUPABASE_URL, URL_BASE,
} from "../_shared/camp.ts";

const SK_LIVE = Deno.env.get("STRIPE_SECRET_KEY_APOLANA") ?? "";
const SK_TEST = Deno.env.get("STRIPE_SECRET_KEY_APOLANA_TEST") ?? "";

const M: Record<string, Record<string, string>> = {
  en: { enlace: "This link is not valid.", nombre: "Enter your full name to accept.", acepto: "Please accept the booking conditions.",
        caducado: "This proposal has expired. Please contact us and we'll send you an updated one.",
        estado: "This proposal can no longer be accepted. Please contact us.", anulado: "This payment request has been cancelled.",
        pasarela: "The payment gateway did not respond. Please try again in a minute.", config: "Payments are not available right now.",
        no_se_puede: "We couldn't prepare the payment." },
  es: { enlace: "Este enlace no es válido.", nombre: "Escribe tu nombre completo para aceptar.", acepto: "Acepta las condiciones de contratación.",
        caducado: "Este presupuesto ha caducado. Escríbenos y te enviamos uno actualizado.",
        estado: "Este presupuesto ya no se puede aceptar. Escríbenos.", anulado: "Esta solicitud de pago está anulada.",
        pasarela: "La pasarela de pago no ha respondido. Vuelve a intentarlo en un minuto.", config: "El pago no está disponible ahora mismo.",
        no_se_puede: "No se ha podido preparar el pago." },
};

async function claveStripe(): Promise<string> {
  const r = await rest("pagos_config?select=modo&id=eq.1&limit=1");
  return String(r.datos?.[0]?.modo ?? "prueba").toLowerCase() === "real" ? SK_LIVE : SK_TEST;
}

// Correos cuando un pago queda cobrado (una sola vez por pago).
async function avisarCobro(t: string, p: any) {
  const r = await rpc("camp_pago_avisar", { p_token: t });
  if (r.datos !== true) return;
  const lang = p.idioma === "es" ? "es" : "en", L = lang === "es";
  const tipo = p.tipo === "senal" ? (L ? "la señal" : "the deposit") : p.tipo === "saldo" ? (L ? "el pago final" : "the final payment") : (L ? "el pago" : "the payment");
  await enviarCorreo({
    para: p.email, asunto: L ? `Pago recibido · ${p.codigo}` : `Payment received · ${p.codigo}`,
    html: correoHtml({
      lang, titulo: L ? "Pago recibido, ¡gracias!" : "Payment received, thank you!",
      parrafos: [L ? `Hemos recibido ${tipo} de vuestra concentración.` : `We have received ${tipo} for your training camp.`],
      filas: [[L ? "Referencia" : "Reference", p.codigo], [L ? "Concepto" : "Description", p.concepto], [L ? "Importe" : "Amount", eurTxt(p.importe, lang)],
        [L ? "Fechas" : "Dates", p.llegada ? `${fechaTxt(p.llegada, lang)} – ${fechaTxt(p.salida, lang)}` : ""]],
      despues: [p.tipo === "senal"
        ? (L ? "En cuanto confirmemos la disponibilidad definitiva te escribiremos para confirmar la reserva." : "As soon as availability is finally confirmed, we'll write to you to confirm the booking.")
        : (L ? "Cualquier cosa que necesites antes de llegar, contesta a este correo." : "If you need anything before you arrive, just reply to this email.")],
    }),
  });
  const rS = await rest(`camp_pagos?select=solicitud_id&token=eq.${t}`);
  const sid = rS.datos?.[0]?.solicitud_id;
  await enviarCorreo({
    para: await correoClub(), asunto: `Training camp · ${p.codigo} · COBRADO ${eurTxt(p.importe, "es")}`,
    html: correoHtml({
      lang: "es", antetitulo: "Training Camps · pago cobrado", titulo: `${p.entidad} · ${eurTxt(p.importe, "es")}`,
      parrafos: [`Stripe ha cobrado «${esc(p.concepto)}». ${p.tipo === "senal" ? "Si ya habías aprobado la disponibilidad, la reserva queda confirmada; si no, apruébala en el expediente." : ""}`],
      boton: sid ? { texto: "Abrir el expediente", url: enlacePanel(sid) } : undefined,
    }),
  });
}

Deno.serve(async (req) => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, origen);
  if (!origenValido(origen)) return responder({ error: "origen" }, 403, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config", mensaje: M.en.config }, 503, origen);

  let b: Record<string, any> = {};
  try { b = await req.json(); } catch { /* vacío */ }
  const accion = String(b.accion ?? "");
  const t = String(b.t ?? "").trim();
  let lang = b.lang === "es" ? "es" : "en";
  if (!/^[0-9a-f]{40,128}$/i.test(t)) return responder({ error: "enlace", mensaje: M[lang].enlace }, 400, origen);

  // ---------------- presupuesto ----------------
  if (accion === "propuesta" || accion === "pdf") {
    const r = await rpc("camp_propuesta_publica", { p_token: t });
    const d = r.datos;
    if (!r.ok || !d || !d.numero) return responder({ error: "enlace", mensaje: M[lang].enlace }, 404, origen);
    if (accion === "propuesta") return responder({ ok: true, propuesta: d }, 200, origen);
    const pdf = await presupuestoPdf(PDFLib, d, await logo());
    return responder({ ok: true, nombre: `${d.numero}.pdf`, pdf: base64(pdf) }, 200, origen);
  }

  if (accion === "aceptar") {
    const nombre = String(b.nombre ?? "").trim().slice(0, 120);
    if (nombre.length < 3) return responder({ error: "nombre", mensaje: M[lang].nombre }, 400, origen);
    if (b.acepto !== true) return responder({ error: "acepto", mensaje: M[lang].acepto }, 400, origen);
    const r = await rpc("camp_propuesta_aceptar", { p_token: t, p_nombre: nombre });
    const res = r.datos ?? {};
    if (!r.ok) return responder({ error: "interno", mensaje: M[lang].estado }, 500, origen);
    if (!res.ok) return responder({ error: res.error, mensaje: M[lang][res.error] ?? M[lang].estado }, 409, origen);
    if (!res.repetido) {
      const rp = await rpc("camp_propuesta_publica", { p_token: t });
      const d = rp.datos ?? {};
      lang = d.idioma === "es" ? "es" : "en";
      const L = lang === "es";
      await enviarCorreo({
        para: await correoClub(), asunto: `Training camp · ${res.codigo} · PRESUPUESTO ACEPTADO`,
        html: correoHtml({
          lang: "es", antetitulo: "Training Camps · presupuesto aceptado", titulo: `${res.entidad} acepta ${res.numero}`,
          parrafos: [`<b>${esc(nombre)}</b> ha aceptado el presupuesto ${esc(res.numero)} (${eurTxt(res.total, "es")}) desde su enlace.`,
            "Siguiente paso: confirma la disponibilidad y pídele la señal desde el expediente (no se cobra nada hasta que la pidas)."],
          boton: { texto: "Abrir el expediente", url: enlacePanel(res.solicitud_id) },
        }),
      });
      if (d.expediente?.email) {
        await enviarCorreo({
          para: d.expediente.email, nombre: d.expediente.contacto,
          asunto: L ? `Presupuesto aceptado · ${res.numero}` : `Proposal accepted · ${res.numero}`,
          html: correoHtml({
            lang, titulo: L ? "Hemos recibido tu aceptación" : "We've received your acceptance",
            parrafos: [L ? `Gracias, ${esc(nombre)}. Hemos registrado la aceptación del presupuesto ${esc(res.numero)}.` : `Thank you, ${esc(nombre)}. We have recorded your acceptance of proposal ${esc(res.numero)}.`,
              L ? "Ahora confirmaremos la disponibilidad definitiva y te enviaremos el enlace para pagar la señal. La reserva queda confirmada al recibirla."
                : "We'll now confirm final availability and send you the link to pay the deposit. The booking is confirmed once the deposit has been received."],
            filas: [[L ? "Total" : "Total", eurTxt(d.total, lang)], [L ? "Señal" : "Deposit", eurTxt(d.senal, lang)]],
            boton: { texto: L ? "Ver el presupuesto" : "View your proposal", url: enlacePropuesta(t, lang) },
          }),
        });
      }
    }
    return responder({ ok: true }, 200, origen);
  }

  // ---------------- pagos ----------------
  if (accion === "pago" || accion === "pagar" || accion === "comprobar") {
    const r = await rpc("camp_pago_publico", { p_token: t });
    const p = r.datos;
    if (!r.ok || !p || !p.codigo) return responder({ error: "enlace", mensaje: M[lang].enlace }, 404, origen);
    lang = p.idioma === "es" ? "es" : "en";
    const vista = { tipo: p.tipo, concepto: p.concepto, importe: p.importe, vence: p.vence, pagado: p.pagado, fecha_pago: p.fecha_pago,
      anulado: p.anulado, cancelado: p.cancelado, codigo: p.codigo, entidad: p.entidad, idioma: lang, presupuesto: p.presupuesto,
      propuesta_token: p.propuesta_token, total: p.total, llegada: p.llegada, salida: p.salida, emisor: p.emisor };
    if (p.pagado) { await avisarCobro(t, p); return responder({ ok: true, pagado: true, pago: vista }, 200, origen); }
    if (accion === "pago") return responder({ ok: true, pago: vista }, 200, origen);
    if (p.anulado || p.cancelado) return responder({ error: "anulado", mensaje: M[lang].anulado }, 409, origen);

    const KEY = await claveStripe();
    if (!KEY) return responder({ error: "config", mensaje: M[lang].config }, 503, origen);
    const rR = await rest(`pagos?select=id&token_pago=eq.${t}&limit=1`);
    const recibo = rR.datos?.[0];
    if (!recibo) return responder({ error: "enlace", mensaje: M[lang].enlace }, 404, origen);

    if (accion === "comprobar") {
      const rP = await rest(`pagos_online?select=referencia,stripe_session_id&metadatos->>pago_id=eq.${recibo.id}&stripe_session_id=not.is.null&order=creado_en.desc&limit=3`);
      for (const po of (Array.isArray(rP.datos) ? rP.datos : [])) {
        const rS = await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(po.stripe_session_id)}`, { headers: { Authorization: `Bearer ${KEY}` } });
        const s = rS.ok ? await rS.json().catch(() => null) : null;
        if (s?.payment_status === "paid") {
          await rpc("pagos_confirmar", { p_referencia: po.referencia, p_session: s.id, p_intent: typeof s.payment_intent === "string" ? s.payment_intent : null });
          await avisarCobro(t, p);
          return responder({ ok: true, pagado: true, pago: { ...vista, pagado: true } }, 200, origen);
        }
      }
      return responder({ ok: true, pagado: false, pago: vista }, 200, origen);
    }

    // pagar: el importe lo pone la base (pagos_iniciar_recibo_token), nunca el navegador.
    const rI = await rpc("pagos_iniciar_recibo_token", { p_token: t });
    if (!rI.ok) return responder({ error: "no_se_puede", mensaje: M[lang].no_se_puede }, 400, origen);
    const pago = Array.isArray(rI.datos) ? rI.datos[0] : rI.datos;
    if (!pago?.referencia) return responder({ error: "interno", mensaje: M[lang].no_se_puede }, 500, origen);
    const vuelta = (estado: string) => `${URL_BASE}training-camps/pay/?t=${t}&lang=${lang}&pago=${estado}`;
    const q = new URLSearchParams();
    q.set("mode", "payment");
    q.set("locale", lang);
    q.set("payment_method_types[0]", "card");
    q.set("client_reference_id", pago.referencia);
    if (p.email) q.set("customer_email", p.email);
    q.set("success_url", vuelta("hecho"));
    q.set("cancel_url", vuelta("cancelado"));
    q.set("line_items[0][quantity]", "1");
    q.set("line_items[0][price_data][currency]", "eur");
    q.set("line_items[0][price_data][unit_amount]", String(pago.importe_centimos));
    q.set("line_items[0][price_data][product_data][name]", p.concepto);
    q.set("line_items[0][price_data][product_data][description]", `Club Atletismo Apolana · ${p.entidad} · ${pago.referencia}`);
    q.set("metadata[referencia]", pago.referencia);
    q.set("payment_intent_data[metadata][referencia]", pago.referencia);
    q.set("payment_intent_data[description]", `${p.concepto} · ${pago.referencia}`);
    const rS = await fetch("https://api.stripe.com/v1/checkout/sessions", {
      method: "POST",
      headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/x-www-form-urlencoded", "Idempotency-Key": `apolana-${pago.referencia}` },
      body: q.toString(),
    });
    const ses = await rS.json().catch(() => null);
    if (!rS.ok || !ses?.url) {
      await rpc("pagos_marcar", { p_referencia: pago.referencia, p_estado: "fallido", p_evento: null });
      console.error("[camp-publico] Stripe:", ses?.error?.message ?? rS.status);
      return responder({ error: "pasarela", mensaje: M[lang].pasarela }, 502, origen);
    }
    await rest(`pagos_online?referencia=eq.${encodeURIComponent(pago.referencia)}`, { method: "PATCH", body: JSON.stringify({ stripe_session_id: ses.id }) });
    return responder({ ok: true, url: ses.url }, 200, origen);
  }

  return responder({ error: "accion" }, 400, origen);
});
