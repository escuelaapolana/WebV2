// ============================================================
// acceso-enlace · manda el enlace para entrar sin contraseña
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   Una familia escribe su correo en el portal y pulsa «Enviarme un
//   enlace». Esta función mira si ese correo está en la base del
//   club; si lo está, le manda un correo con un enlace que, al
//   pulsarlo, la mete dentro. Sin contraseña que elegir ni que
//   olvidar. Y la cuenta se crea sola la primera vez.
//
// POR QUÉ ESTO NO PUEDE HACERSE DESDE EL NAVEGADOR
//   Porque hay que comprobar quién tiene derecho a entrar ANTES de
//   mandar nada, y esa comprobación no puede vivir en el móvil de
//   nadie: quien la tuviera podría ir probando correos hasta
//   averiguar cuáles están dados de alta en el club. Aquí abajo se
//   hace con la llave de servicio, que solo existe dentro de
//   Supabase y no viaja a ningún sitio.
//
// LA REGLA DE ORO: SIEMPRE SE CONTESTA LO MISMO
//   Exista el correo o no, se responda o no se responda, esta
//   función devuelve exactamente la misma respuesta y tarda
//   parecido. Si contestara distinto, sería justo el buscador de
//   correos del club que queremos evitar.
//
// LOS TRES PASOS
//   1. ¿Se puede pedir? (`acceso_pedir_apuntar`) · 3 veces por
//      correo y 20 por origen en una hora. Ni una más.
//   2. ¿Tiene derecho?  (`acceso_puede_entrar`) · su correo tiene
//      que estar en su ficha de atleta, en la de alguno de sus
//      hijos o en su perfil de siempre.
//   3. Se le crea la cuenta si no la tiene, se le ata a su ficha
//      (`acceso_enganchar`) y Supabase le manda el correo.
//
//   El enganche se hace AQUÍ y no al pulsar el enlace, a propósito:
//   así, cuando la persona entra, sus datos ya están puestos y no
//   se encuentra el portal vacío. Y como se puede repetir sin
//   estropear nada, también arregla las cuentas viejas que se
//   crearon antes de que su ficha tuviera correo.
//
// CLAVES · ninguna está en este archivo ni puede estarlo
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY · las pone Supabase sola
//   ACCESO_URL_BASE  · la web del club, p. ej.
//                      https://escuelaapolana.github.io/WebV2/
//                      (a dónde lleva el enlace del correo)
//   ACCESO_ORIGENES  · webs que pueden llamar aquí, separadas por
//                      comas. Si falta, se aceptan las de la lista
//                      de abajo.
//   ACCESO_SAL       · un texto cualquiera y largo. Sirve para
//                      contar peticiones por origen sin guardar la
//                      dirección de internet de nadie. Opcional,
//                      pero mejor ponerlo.
//
// Cómo se despliega:
//     supabase functions deploy acceso-enlace --no-verify-jwt
//
// El `--no-verify-jwt` está puesto a propósito y es imprescindible:
// aquí llama gente que TODAVÍA NO HA ENTRADO —ese es el sentido de
// todo esto—, así que no puede traer ninguna sesión. Lo que protege
// esta puerta es lo de dentro: el límite de peticiones, la lista de
// webs permitidas y que la respuesta sea siempre la misma.
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";

// A dónde lleva el enlace del correo. NO se coge del navegador: si
// se cogiera, cualquiera podría pedir un enlace del club que lleve a
// su propia web y quedarse con la sesión de quien lo pulse.
const WEBS_DEL_CLUB = [
  "https://escuelaapolana.github.io/WebV2/",
  "https://escuelaapolana.github.io/apolana-club/",
];

const URL_BASE = (Deno.env.get("ACCESO_URL_BASE") ?? WEBS_DEL_CLUB[0]).replace(/\/*$/, "/");
const SAL = Deno.env.get("ACCESO_SAL") ?? "apolana-acceso";

// ------------------------------------------------------------
// Quién puede llamarnos desde un navegador
// ------------------------------------------------------------
function origenesPermitidos(): string[] {
  const puestos = (Deno.env.get("ACCESO_ORIGENES") ?? "")
    .split(",").map((s) => s.trim()).filter(Boolean);
  if (puestos.length) return puestos;
  // Por defecto, las webs del club (solo el dominio, sin la carpeta)
  // y el servidor de pruebas de casa.
  const deLasWebs = WEBS_DEL_CLUB.map((u) => new URL(u).origin);
  return [...new Set([...deLasWebs, "http://localhost:8000", "http://127.0.0.1:8000"])];
}

function cors(origen: string | null): Record<string, string> {
  const permitidos = origenesPermitidos();
  const valor = origen && permitidos.includes(origen) ? origen : permitidos[0];
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

// La ÚNICA respuesta buena que da esta función. Se usa para todo:
// correo que existe, correo que no existe, correo que se ha pasado
// de peticiones. Desde fuera son indistinguibles.
function comoSiempre(origen: string | null): Response {
  return responder({ ok: true }, 200, origen);
}

// ------------------------------------------------------------
// Hablar con la base con la llave de servicio
// ------------------------------------------------------------
async function rpc(nombre: string, cuerpo: unknown): Promise<unknown> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${nombre}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(cuerpo),
  });
  if (!r.ok) throw new Error(`${nombre}: ${r.status} ${await r.text()}`);
  const texto = await r.text();
  try { return texto ? JSON.parse(texto) : null; } catch { return texto; }
}

// Un resumen del origen que no se puede deshacer: sirve para contar
// peticiones y no sirve para saber de quién son.
async function resumen(texto: string): Promise<string> {
  const bytes = new TextEncoder().encode(SAL + "·" + texto);
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash)).slice(0, 12)
    .map((b) => b.toString(16).padStart(2, "0")).join("");
}

// ------------------------------------------------------------
// La cuenta: buscarla y, si no está, crearla
// ------------------------------------------------------------
// Se crea con el correo YA dado por bueno («email_confirm»), porque
// el enlace que va a recibir es la propia confirmación: si no, habría
// que pedirle dos correos seguidos para lo mismo.
async function cuentaDe(email: string): Promise<string | null> {
  const buscar = await fetch(
    `${SUPABASE_URL}/auth/v1/admin/users?filter=${encodeURIComponent(email)}`,
    { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } },
  );
  if (buscar.ok) {
    const datos = await buscar.json();
    const lista = Array.isArray(datos?.users) ? datos.users : [];
    const suya = lista.find((u: { email?: string }) =>
      (u.email ?? "").toLowerCase() === email);
    if (suya?.id) return suya.id as string;
  }

  const crear = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email, email_confirm: true }),
  });
  if (crear.ok) {
    const datos = await crear.json();
    return (datos?.id as string) ?? null;
  }
  // Si dos peticiones a la vez han intentado crear la misma cuenta,
  // una de las dos se encuentra con «ya existe». No es un fallo.
  return null;
}

// ------------------------------------------------------------
// El correo con el enlace
// ------------------------------------------------------------
// Lo manda Supabase con su propia plantilla y su propio remitente.
// `should_create_user: false` a posta: la cuenta ya se ha creado
// arriba, después de comprobar que esa persona tiene derecho. Así,
// aunque un día se abra este hueco por error, por aquí no se puede
// dar de alta a nadie que no esté en la base del club.
async function mandarEnlace(email: string): Promise<boolean> {
  const r = await fetch(`${SUPABASE_URL}/auth/v1/otp`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email,
      create_user: false,
      should_create_user: false,
    // El enlace vuelve SIEMPRE al portal del club, a una dirección
    // que está escrita aquí y que nadie de fuera puede cambiar.
      options: { email_redirect_to: `${URL_BASE}portal/` },
      redirect_to: `${URL_BASE}portal/`,
    }),
  });
  if (!r.ok) console.error("[acceso-enlace] no se pudo enviar:", r.status, await r.text());
  return r.ok;
}

// ============================================================
// LA PUERTA
// ============================================================
Deno.serve(async (peticion) => {
  const origen = peticion.headers.get("origin");

  if (peticion.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors(origen) });
  }
  if (peticion.method !== "POST") {
    return responder({ ok: false, error: "Método no permitido." }, 405, origen);
  }

  // Si la llamada viene de una web que no es del club, ni se mira.
  if (origen && !origenesPermitidos().includes(origen)) {
    return responder({ ok: false, error: "Origen no permitido." }, 403, origen);
  }

  if (!SUPABASE_URL || !SERVICE_KEY) {
    // Sin las llaves esto no puede funcionar, y hay que decirlo: es
    // el único caso en el que NO se contesta «ok», porque no es un
    // correo que no exista, es el club que no lo ha terminado de
    // configurar.
    return responder(
      { ok: false, error: "El acceso por enlace todavía no está activado." },
      503, origen,
    );
  }

  let cuerpo: { email?: string };
  try { cuerpo = await peticion.json(); } catch { cuerpo = {}; }

  const email = String(cuerpo.email ?? "").trim().toLowerCase();
  // Un correo con pinta de correo y de largo razonable. Lo que no
  // pase de aquí ni siquiera se apunta.
  if (!/^[^\s@,;]{1,64}@[^\s@,;]{1,190}\.[a-z]{2,}$/i.test(email)) {
    return comoSiempre(origen);
  }

  try {
    const dedonde = await resumen(
      peticion.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "sin-origen",
    );

    // 1 · ¿Se puede pedir, o ya se ha pedido demasiadas veces?
    const sePuede = await rpc("acceso_pedir_apuntar", { p_email: email, p_origen: dedonde });
    if (sePuede !== true) return comoSiempre(origen);

    // 2 · ¿Tiene derecho a entrar?
    const tieneDerecho = await rpc("acceso_puede_entrar", { p_email: email });
    if (tieneDerecho !== true) return comoSiempre(origen);

    // 3 · Cuenta, enganche y correo.
    const id = await cuentaDe(email);
    if (id) {
      // Que el enganche falle no puede impedir que entre: entra y el
      // club le ata la ficha desde el panel.
      try { await rpc("acceso_enganchar", { p_uid: id, p_email: email }); }
      catch (e) { console.error("[acceso-enlace] enganche:", e); }
    }
    await mandarEnlace(email);
  } catch (e) {
    // Un fallo por dentro tampoco cambia lo que ve quien lo pidió:
    // queda escrito en el registro de Supabase y punto.
    console.error("[acceso-enlace]", e);
  }

  return comoSiempre(origen);
});
