// ============================================================
// correo-alta · correo de bienvenida cuando se crea la ficha
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   Cuando alguien del club convierte un alta en ficha (el atleta ya
//   existe de verdad y puede entrar), esta función le manda un correo
//   de bienvenida con cómo entrar en su zona del club. Nada más.
//
// LO QUE NO SE FÍA DEL NAVEGADOR
//   · Quién llama. Se comprueba el JWT contra Supabase y se pregunta
//     a la base si esa persona es de administración o tesorería. No se
//     cree el correo que venga en el cuerpo.
//   · A quién se escribe. La dirección NO llega del navegador: se lee
//     de la ficha en la base a partir del atleta_id. Así nadie puede
//     usar esto para mandar correos a quien quiera.
//
// CLAVES · ninguna vive en este archivo
//   BREVO_API_KEY, CORREO_REMITENTE, CORREO_REMITENTE_NOMBRE,
//   CORREO_URL_BASE (la web del club), y las de Supabase, que las pone
//   Supabase sola. Si falta la de Brevo, contesta «todavía no está
//   activado» con buenos modales. No revienta.
//
// Cómo se despliega:  supabase functions deploy correo-alta
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";

const BREVO_API_KEY = (Deno.env.get("BREVO_API_KEY") ?? "").trim();
const REMITENTE_EMAIL = (Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com").trim();
const REMITENTE_NOMBRE = (Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana").trim();
const URL_BASE = (Deno.env.get("CORREO_URL_BASE") ?? "https://escuelaapolana.github.io/WebV2/")
  .replace(/\/*$/, "/");

function cors(origen: string | null): Record<string, string> {
  const permitidos = (Deno.env.get("CORREO_ORIGENES") ?? Deno.env.get("PAGOS_ORIGENES") ?? "")
    .split(",").map((s) => s.trim()).filter(Boolean);
  const valor = permitidos.length
    ? (origen && permitidos.includes(origen) ? origen : permitidos[0])
    : (origen ?? "*");
  return {
    "Access-Control-Allow-Origin": valor,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function responder(cuerpo: unknown, estado: number, origen: string | null): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { ...cors(origen), "Content-Type": "application/json; charset=utf-8" },
  });
}

// Hablar con la base con la llave de servicio (para leer la ficha).
async function consulta(ruta: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
  });
  const texto = await r.text();
  let datos: unknown = null;
  try { datos = texto ? JSON.parse(texto) : null; } catch { datos = texto; }
  return { ok: r.ok, datos };
}

// Preguntar a la base COMO EL USUARIO (con su JWT) si tiene un papel.
async function comoUsuario(rpc: string, jwt: string): Promise<boolean> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${rpc}`, {
    method: "POST",
    headers: {
      apikey: ANON_KEY || SERVICE_KEY,
      Authorization: `Bearer ${jwt}`,
      "Content-Type": "application/json",
    },
    body: "{}",
  });
  if (!r.ok) return false;
  try { return (await r.json()) === true; } catch { return false; }
}

function correoHtml(saludo: string): string {
  return `<!doctype html><html lang="es"><body style="margin:0;background:#f4f4f5;padding:24px;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#18181b">
    <div style="max-width:520px;margin:0 auto;background:#fff;border-radius:14px;overflow:hidden;border:1px solid #e4e4e7">
      <div style="background:#0b5d3b;color:#fff;padding:20px 24px;font-size:18px;font-weight:700">Club Atletismo Apolana</div>
      <div style="padding:24px">
        <p style="margin:0 0 12px;font-size:16px;font-weight:600">¡Bienvenido/a al Club Atletismo Apolana!</p>
        <p style="margin:0 0 20px;color:#3f3f46;line-height:1.5">${saludo} Ya puedes entrar en tu zona del club: pulsa el botón y pide tu enlace de acceso con <b>este mismo correo</b>.</p>
        <p style="margin:0 0 20px"><a href="${URL_BASE}portal/" style="display:inline-block;background:#0b5d3b;color:#fff;text-decoration:none;padding:12px 22px;border-radius:10px;font-weight:600">Entrar en el club</a></p>
        <p style="margin:0;color:#71717a;font-size:13px">Si tienes cualquier duda, contesta a este correo y te ayudamos.</p>
      </div>
    </div>
  </body></html>`;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ error: "config", mensaje: "El correo no está configurado." }, 503, origen);
  }
  if (!BREVO_API_KEY) {
    // El alta ya está creada: la bienvenida es un extra, no un fallo.
    return responder({ ok: false, motivo: "sin-configurar" }, 200, origen);
  }

  // 1 · ¿Quién eres? JWT de verdad, contra Supabase.
  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sin_sesion" }, 401, origen);

  const rUsuario = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` },
  });
  if (!rUsuario.ok) return responder({ error: "sin_sesion" }, 401, origen);

  // 1.b · ¿Puede? Administración o tesorería, como en alta_marcar.
  const puede = (await comoUsuario("es_admin", jwt)) || (await comoUsuario("es_tesoreria", jwt));
  if (!puede) return responder({ error: "sin_permiso" }, 403, origen);

  // 2 · Qué ficha (lo único que se acepta del navegador es el id y el tipo)
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* vacío */ }
  const que = String(cuerpo.que ?? "").trim();
  const atletaId = cuerpo.atleta_id ? String(cuerpo.atleta_id).trim() : "";
  if (!atletaId) return responder({ error: "falta_atleta" }, 400, origen);

  // 3 · El correo se lee DE LA BASE, no del navegador.
  const rAtleta = await consulta(
    `atletas?select=nombre,apellidos,email,email_tutor,nombre_tutor&id=eq.${encodeURIComponent(atletaId)}&limit=1`,
  );
  const ficha = Array.isArray(rAtleta.datos) ? rAtleta.datos[0] : null;
  if (!ficha) return responder({ ok: false, motivo: "no-esta" }, 200, origen);

  const esEscuela = que === "escuela";
  const destino = String(
    (esEscuela ? (ficha.email_tutor || ficha.email) : (ficha.email || ficha.email_tutor)) ?? "",
  ).trim();
  if (!destino) return responder({ ok: false, motivo: "sin-correo" }, 200, origen);

  const nombre = String(ficha.nombre ?? "").trim();
  const saludo = esEscuela
    ? (nombre ? `La inscripción de ${nombre} ya está confirmada.` : "La inscripción ya está confirmada.")
    : (nombre ? `Tu alta ya está confirmada, ${nombre}.` : "Tu alta ya está confirmada.");

  // 4 · Enviar por Brevo
  let respBrevo: Response;
  try {
    respBrevo = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: REMITENTE_NOMBRE, email: REMITENTE_EMAIL },
        to: [{ email: destino }],
        subject: "¡Bienvenido/a al Club Atletismo Apolana!",
        htmlContent: correoHtml(saludo),
        textContent: `${saludo}\nEntra en tu zona del club desde ${URL_BASE}portal/ pidiendo tu enlace con este mismo correo.`,
      }),
    });
  } catch (e) {
    return responder({ ok: false, motivo: "sin-conexion", detalle: String(e) }, 200, origen);
  }

  if (!respBrevo.ok) {
    let datos: unknown = null;
    try { datos = await respBrevo.json(); } catch { /* Brevo casi siempre da JSON */ }
    return responder({ ok: false, motivo: "brevo-rechazo", estado: respBrevo.status, brevo: datos }, 200, origen);
  }

  return responder({ ok: true, destino }, 200, origen);
});
