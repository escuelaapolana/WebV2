// ============================================================
// correo-prueba · comprueba que el envío de correo (Brevo) funciona
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   Manda UN correo de prueba a una dirección fija del club y
//   contesta si Brevo lo aceptó o no. Sirve solo para confirmar que
//   la clave y el remitente están bien puestos. No lee nada del
//   cuerpo de la petición: da igual lo que le mandes, siempre hace
//   lo mismo, así que nadie puede usarla para enviar spam.
//
// POR QUÉ EL DESTINATARIO ES FIJO
//   Si dejáramos elegir a quién se escribe, esto sería un buzón
//   abierto para mandar correos en nombre del club. El destinatario
//   está clavado aquí (CORREO_PRUEBA_DESTINO), y por defecto es el
//   propio remitente verificado.
//
// CLAVES · ninguna vive en este archivo
//   BREVO_API_KEY          · la clave de Brevo (la pone el club en Supabase)
//   CORREO_REMITENTE       · quién firma      (opcional; por defecto el Gmail verificado)
//   CORREO_REMITENTE_NOMBRE· nombre que se ve (opcional)
//   CORREO_PRUEBA_DESTINO  · a quién llega la prueba (opcional; por defecto el remitente)
//
// Si falta la clave, contesta «todavía no está activado» con buenos
// modales. No revienta.
//
// Cómo se despliega:  supabase functions deploy correo-prueba --no-verify-jwt
// ============================================================

const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();

const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const DESTINO_PRUEBA = (Deno.env.get("CORREO_PRUEBA_DESTINO") ?? REMITENTE_EMAIL).trim();

function responder(cuerpo: unknown, estado: number): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return responder({ ok: true }, 200);

  // Sin clave no se puede hacer nada: se avisa con buenos modales.
  if (!BREVO_API_KEY) {
    return responder({
      error: "sin_configurar",
      mensaje: "El envío de correo todavía no está activado (falta BREVO_API_KEY en Supabase).",
    }, 200);
  }

  const cuando = new Date().toLocaleString("es-ES", { timeZone: "Europe/Madrid" });

  const html = `<!doctype html><html lang="es"><body style="margin:0;background:#f4f4f5;padding:24px;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
    <div style="max-width:520px;margin:0 auto;background:#fff;border-radius:14px;overflow:hidden;border:1px solid #e4e4e7">
      <div style="background:#0b5d3b;color:#fff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana</div>
      <div style="padding:24px">
        <p style="margin:0 0 12px;font-size:16px">Correo de prueba ✅</p>
        <p style="margin:0 0 12px;color:#3f3f46;line-height:1.5">Si estás leyendo esto, el envío de correos del club funciona: la clave y el remitente están bien puestos.</p>
        <p style="margin:0;color:#71717a;font-size:13px">Enviado el ${cuando} desde la web del club.</p>
      </div>
    </div>
  </body></html>`;

  const texto = `Correo de prueba del Club Atletismo Apolana.\nSi lo recibes, el envío de correos funciona.\nEnviado el ${cuando}.`;

  let respBrevo: Response;
  try {
    respBrevo = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "api-key": BREVO_API_KEY,
        "content-type": "application/json",
        "accept": "application/json",
      },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        to: [{ email: DESTINO_PRUEBA }],
        subject: "Prueba de correo · Club Apolana",
        htmlContent: html,
        textContent: texto,
      }),
    });
  } catch (e) {
    return responder({
      error: "sin_conexion",
      mensaje: "No se pudo contactar con Brevo. Vuelve a intentarlo en un minuto.",
      detalle: String(e),
    }, 502);
  }

  const cuerpo = await respBrevo.text();
  let datos: unknown = null;
  try { datos = JSON.parse(cuerpo); } catch { /* Brevo casi siempre da JSON */ }

  if (!respBrevo.ok) {
    // Brevo devuelve { code, message } cuando algo falla (clave mala, remitente sin verificar…)
    return responder({
      error: "brevo_rechazo",
      estado: respBrevo.status,
      brevo: datos ?? cuerpo,
      remitente: REMITENTE_EMAIL,
      destino: DESTINO_PRUEBA,
    }, 502);
  }

  return responder({
    ok: true,
    mensaje: "Correo de prueba enviado.",
    destino: DESTINO_PRUEBA,
    remitente: REMITENTE_EMAIL,
    brevo: datos,
  }, 200);
});
