// ============================================================
// camp-gestion · lo que hace el panel «Training Camps» y necesita servidor
// ------------------------------------------------------------
// Solo admin: se comprueba es_admin() con SU sesión y todo se hace en su
// nombre (RLS y funciones del panel), salvo el envío de correos (Brevo).
//   { accion:"pdf", presupuesto_id }                     → PDF (base64), también de un borrador
//   { accion:"enviar_presupuesto", presupuesto_id, mensaje?, para? }
//        → lo marca enviado (enlace para el cliente), guarda el PDF en el
//          expediente y lo manda por correo con el PDF adjunto
//   { accion:"pedir_pago", solicitud_id, tipo, importe?, vence?, concepto?, enviar?, mensaje? }
//        → crea el recibo con su enlace (NO cobra nada) y, si enviar, lo manda
//   { accion:"reenviar_pago", camp_pago_id, mensaje? }
//   { accion:"correo", solicitud_id, asunto, mensaje }    → correo libre al cliente (queda en el registro)
//
//   supabase functions deploy camp-gestion --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

// deno-lint-ignore-file no-explicit-any
import * as PDFLib from "npm:pdf-lib@1.17.1";
import { presupuestoPdf } from "../_shared/camp-pdf.ts";
import {
  ANON_KEY, base64, cors, correoHtml, corta, enlacePago, enlacePropuesta, enviarCorreo, errorDe, esc, eurTxt, fechaTxt, logo,
  origenValido, pareceCorreo, responder, rest, rpc, SERVICE_KEY, SUPABASE_URL,
} from "../_shared/camp.ts";

const uno = (d: any) => (Array.isArray(d) ? d[0] : d);

function parrafosLibres(texto: string): string[] {
  return texto.split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean).map((p) => esc(p).replace(/\n/g, "<br>"));
}

async function subirPdf(jwt: string, ruta: string, pdf: Uint8Array): Promise<boolean> {
  const r = await fetch(`${SUPABASE_URL}/storage/v1/object/training-camps/${ruta}`, {
    method: "POST",
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}`, "Content-Type": "application/pdf", "x-upsert": "true" },
    body: pdf,
  });
  if (!r.ok) console.error("[camp-gestion] subir PDF:", r.status, await r.text());
  return r.ok;
}

async function correoPago(c: any, s: any, mensaje: string): Promise<boolean> {
  const lang = c.idioma ?? s.idioma ?? "en", L = lang === "es";
  const que = c.tipo === "senal" ? (L ? "la señal" : "the deposit") : c.tipo === "saldo" ? (L ? "el pago final" : "the final payment") : (L ? "el pago" : "the payment");
  return await enviarCorreo({
    para: s.email, nombre: s.contacto,
    asunto: L ? `${c.tipo === "senal" ? "Pago de la señal" : c.tipo === "saldo" ? "Pago final" : "Pago"} · Concentración ${s.codigo}`
              : `${c.tipo === "senal" ? "Deposit payment" : c.tipo === "saldo" ? "Final payment" : "Payment"} · Training camp ${s.codigo}`,
    html: correoHtml({
      lang, titulo: L ? `Enlace para pagar ${que}` : `Your link to pay ${que}`,
      parrafos: [L ? `Hola, ${esc(s.contacto)}:` : `Hello ${esc(s.contacto)},`, ...parrafosLibres(mensaje),
        L ? `Te enviamos el enlace para pagar ${que} de vuestra concentración con tarjeta, de forma segura (Stripe).`
          : `Here is the secure link to pay ${que} for your training camp by card (Stripe).`],
      filas: [[L ? "Referencia" : "Reference", s.codigo], [L ? "Concepto" : "Description", c.concepto], [L ? "Importe" : "Amount", eurTxt(c.importe, lang)],
        [L ? "Fecha límite" : "Due date", c.vence ? fechaTxt(c.vence, lang) : ""]],
      boton: { texto: L ? `Pagar ${eurTxt(c.importe, lang)}` : `Pay ${eurTxt(c.importe, lang)}`, url: enlacePago(c.token, lang) },
      despues: [c.tipo === "senal"
        ? (L ? "La reserva queda confirmada al recibir la señal y confirmar el club la disponibilidad." : "The booking is confirmed once the deposit has been received and the club has confirmed availability.")
        : (L ? "Si prefieres pagar por transferencia, contesta a este correo." : "If you'd rather pay by bank transfer, just reply to this email."),
        L ? "Un saludo,<br><b>Club Atletismo Apolana</b>" : "Kind regards,<br><b>Club Atletismo Apolana</b>"],
    }),
  });
}

Deno.serve(async (req) => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, origen);
  if (!origenValido(origen)) return responder({ error: "origen" }, 403, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config", mensaje: "No está configurado." }, 503, origen);

  // Quién llama: tiene que ser admin con su sesión.
  const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!jwt || jwt === ANON_KEY) return responder({ error: "sesion", mensaje: "Inicia sesión." }, 401, origen);
  const rA = await rpc("es_admin", {}, jwt);
  if (rA.datos !== true) return responder({ error: "permiso", mensaje: "Solo para administración." }, 403, origen);

  let b: Record<string, any> = {};
  try { b = await req.json(); } catch { /* vacío */ }
  const accion = String(b.accion ?? "");
  const fallo = (r: any, n = 400) => responder({ error: "datos", mensaje: errorDe(r) }, n, origen);

  // ---------------- PDF (vista previa / descarga) ----------------
  if (accion === "pdf") {
    const r = await rpc("camp_propuesta_admin", { p_id: b.presupuesto_id }, jwt);
    if (!r.ok || !r.datos?.numero) return fallo(r, 404);
    const pdf = await presupuestoPdf(PDFLib, r.datos, await logo());
    return responder({ ok: true, nombre: `${r.datos.numero}.pdf`, pdf: base64(pdf) }, 200, origen);
  }

  // ---------------- Enviar el presupuesto ----------------
  if (accion === "enviar_presupuesto") {
    const r0 = await rest(`camp_presupuestos?select=id,solicitud_id,numero,estado&id=eq.${encodeURIComponent(String(b.presupuesto_id))}`, { jwt });
    const pre = r0.datos?.[0];
    if (!pre) return responder({ error: "datos", mensaje: "Ese presupuesto no existe." }, 404, origen);
    const rS = await rest(`camp_solicitudes?select=id,codigo,email,contacto,entidad,idioma&id=eq.${pre.solicitud_id}`, { jwt });
    const s = rS.datos?.[0];
    const para = corta(b.para, 160) || s?.email;
    if (!pareceCorreo(para)) return responder({ error: "datos", mensaje: "El correo del cliente no es válido." }, 400, origen);

    const rE = await rpc("camp_presupuesto_enviado", { p_id: pre.id, p_email: para }, jwt);
    if (!rE.ok) return fallo(rE);
    const e = uno(rE.datos);
    const rD = await rpc("camp_propuesta_admin", { p_id: pre.id }, jwt);
    const d = rD.datos;
    const pdf = await presupuestoPdf(PDFLib, d, await logo());
    const ruta = `${s.id}/presupuestos/${d.numero}-${Date.now()}.pdf`;
    if (await subirPdf(jwt, ruta, pdf)) {
      await rest("camp_archivos", { method: "POST", jwt, body: JSON.stringify({
        solicitud_id: s.id, ruta, nombre: `${d.numero}.pdf`, mime: "application/pdf", tamano: pdf.length, origen: "presupuesto",
        descripcion: `Presupuesto enviado a ${para}`,
      }) });
    }
    const lang = d.idioma === "es" ? "es" : "en", L = lang === "es";
    const mensaje = String(b.mensaje ?? "").trim().slice(0, 4000);
    const enlace = enlacePropuesta(e.token, lang);
    const ok = await enviarCorreo({
      para, nombre: s.contacto,
      asunto: L ? `Vuestra propuesta de concentración en Alicante · ${d.numero}` : `Your training camp proposal for Alicante · ${d.numero}`,
      html: correoHtml({
        lang, titulo: L ? "Tu propuesta de concentración" : "Your training camp proposal",
        parrafos: [L ? `Hola, ${esc(s.contacto)}:` : `Hello ${esc(s.contacto)},`,
          ...(mensaje ? parrafosLibres(mensaje) : [L ? "Te enviamos la propuesta para vuestra concentración en Alicante. La tienes adjunta en PDF y también en el enlace, desde donde puedes aceptarla."
            : "Please find attached our proposal for your training camp in Alicante. You can also view it online and accept it from the link below."])],
        filas: [[L ? "Presupuesto" : "Proposal", d.numero],
          [L ? "Fechas" : "Dates", d.llegada ? `${fechaTxt(d.llegada, lang)} – ${fechaTxt(d.salida, lang)}` : ""],
          [L ? "Participantes" : "Participants", d.participantes ? String(d.participantes) : ""],
          [L ? "Total" : "Total", eurTxt(d.total, lang)],
          [L ? "Señal para confirmar" : "Deposit to confirm", eurTxt(d.senal, lang)],
          [L ? "Válido hasta" : "Valid until", fechaTxt(d.valido_hasta, lang)]],
        boton: { texto: L ? "Ver y aceptar la propuesta" : "View and accept your proposal", url: enlace },
        despues: [L ? "Si quieres cambiar algo (fechas, servicios, número de personas), contesta a este correo y la ajustamos." : "If you'd like to change anything (dates, services, number of people), just reply to this email and we'll adjust it.",
          L ? "Un saludo,<br><b>Club Atletismo Apolana</b>" : "Kind regards,<br><b>Club Atletismo Apolana</b>"],
      }),
      adjuntos: [{ nombre: `${d.numero}.pdf`, contenido: base64(pdf) }],
    });
    if (!ok) {
      await rest("camp_registro", { method: "POST", jwt, body: JSON.stringify({ solicitud_id: s.id, tipo: "sistema",
        texto: `El correo con ${d.numero} NO ha salido: comparte el enlace a mano` }) });
    }
    return responder({ ok: true, correo: ok, enlace }, 200, origen);
  }

  // Interruptor de Training Camps: apagado = no sale ningún enlace de pago.
  const pagosOnline = async () => (await rest("camp_config?select=pagos_online&id=eq.1")).datos?.[0]?.pagos_online === true;

  // ---------------- Pedir un pago ----------------
  if (accion === "pedir_pago") {
    const r = await rpc("camp_pago_crear", { p_solicitud: b.solicitud_id, p_tipo: b.tipo, p_importe: b.importe ?? null,
      p_vence: b.vence || null, p_concepto: b.concepto || null }, jwt);
    if (!r.ok) return fallo(r);
    const c = uno(r.datos);
    const rS = await rest(`camp_solicitudes?select=id,codigo,email,contacto,idioma&id=eq.${c.solicitud_id}`, { jwt });
    const s = rS.datos?.[0];
    const rP = await rest(`camp_presupuestos?select=idioma&id=eq.${c.presupuesto_id}`, { jwt });
    c.idioma = rP.datos?.[0]?.idioma ?? s.idioma;
    let correo = false;
    const online = await pagosOnline();
    if (b.enviar !== false && online) {
      correo = await correoPago(c, s, String(b.mensaje ?? "").trim().slice(0, 4000));
      if (correo) await rpc("camp_pago_enviado", { p_id: c.id, p_email: s.email }, jwt);
    }
    return responder({ ok: true, correo, pagos_online: online, enlace: online ? enlacePago(c.token, c.idioma) : null, camp_pago: c }, 200, origen);
  }

  if (accion === "reenviar_pago") {
    const r = await rest(`camp_pagos_v?select=*&id=eq.${encodeURIComponent(String(b.camp_pago_id))}`, { jwt });
    const c = r.datos?.[0];
    if (!c) return responder({ error: "datos", mensaje: "Ese pago no existe." }, 404, origen);
    if (c.situacion !== "pendiente") return responder({ error: "datos", mensaje: "Ese pago ya no está pendiente." }, 409, origen);
    if (!(await pagosOnline())) return responder({ error: "pagos_off", mensaje: "Los pagos online de Training Camps están desactivados (Ajustes): no se envía ningún enlace." }, 409, origen);
    const rS = await rest(`camp_solicitudes?select=id,codigo,email,contacto,idioma&id=eq.${c.solicitud_id}`, { jwt });
    const s = rS.datos?.[0];
    const rP = await rest(`camp_presupuestos?select=idioma&id=eq.${c.presupuesto_id}`, { jwt });
    c.idioma = rP.datos?.[0]?.idioma ?? s.idioma;
    const correo = await correoPago(c, s, String(b.mensaje ?? "").trim().slice(0, 4000));
    if (correo) await rpc("camp_pago_enviado", { p_id: c.id, p_email: s.email }, jwt);
    return responder({ ok: true, correo, enlace: enlacePago(c.token, c.idioma) }, 200, origen);
  }

  // ---------------- Correo libre ----------------
  if (accion === "correo") {
    const rS = await rest(`camp_solicitudes?select=id,codigo,email,contacto,idioma&id=eq.${encodeURIComponent(String(b.solicitud_id))}`, { jwt });
    const s = rS.datos?.[0];
    if (!s) return responder({ error: "datos", mensaje: "Ese expediente no existe." }, 404, origen);
    const asunto = corta(b.asunto, 200), mensaje = String(b.mensaje ?? "").trim().slice(0, 8000);
    if (!asunto || !mensaje) return responder({ error: "datos", mensaje: "Escribe el asunto y el mensaje." }, 400, origen);
    const lang = s.idioma === "es" ? "es" : "en";
    const ok = await enviarCorreo({
      para: s.email, nombre: s.contacto, asunto: `${asunto} · ${s.codigo}`,
      html: correoHtml({ lang, titulo: asunto, parrafos: parrafosLibres(mensaje),
        despues: [lang === "es" ? "Un saludo,<br><b>Club Atletismo Apolana</b>" : "Kind regards,<br><b>Club Atletismo Apolana</b>"] }),
    });
    if (!ok) return responder({ error: "correo", mensaje: "El correo no ha salido. Inténtalo otra vez." }, 502, origen);
    await rest("camp_registro", { method: "POST", jwt, body: JSON.stringify({ solicitud_id: s.id, tipo: "comunicacion", canal: "email",
      sentido: "saliente", texto: `${asunto}\n\n${mensaje}`, datos: { enviado_desde_panel: true } }) });
    return responder({ ok: true }, 200, origen);
  }

  return responder({ error: "accion" }, 400, origen);
});
