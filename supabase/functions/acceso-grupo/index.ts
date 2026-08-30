// ============================================================
// ACCESO ANTICIPADO A UN GRUPO · crea la cuenta con la contraseña que
// el atleta escribe en el formulario, sin enviar ningún correo.
// ------------------------------------------------------------
// POR QUÉ EXISTE
//
// El registro público de Supabase está apagado a propósito, y el envío de
// correos en masa todavía no está montado. Andrés quiere que sus atletas
// entren YA a ver los entrenamientos, antes del alta oficial. Así que el
// formulario de la web llama aquí, y AQUÍ —con la llave de servicio— se
// crea la cuenta con la contraseña que ha puesto el atleta y su ficha
// provisional en el grupo. La cuenta nace con el correo dado por bueno
// («email_confirm»), así que puede entrar en el acto, sin confirmar nada.
//
// LA PUERTA
//   Un CÓDIGO de grupo. Sin un código válido, esto no crea nada. El código
//   lo comparte el entrenador solo con los suyos. Así un formulario abierto
//   no se convierte en una fábrica de cuentas para cualquiera.
//
// SE DESPLIEGA CON:
//   supabase functions deploy acceso-grupo --no-verify-jwt
// El `--no-verify-jwt` es imprescindible: aquí llama gente que TODAVÍA NO
// tiene cuenta. Lo que protege la puerta es el código, el límite de
// peticiones y la lista de webs permitidas.
//
// VARIABLES (las de siempre, ya están puestas para acceso-enlace):
//   SUPABASE_URL · SUPABASE_SERVICE_ROLE_KEY · ACCESO_ORIGENES · ACCESO_SAL
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const SAL = Deno.env.get("ACCESO_SAL") ?? "apolana-acceso";

const WEBS_DEL_CLUB = [
  "https://escuelaapolana.github.io/WebV2/",
  "https://escuelaapolana.github.io/apolana-club/",
];

function origenesPermitidos(): string[] {
  const puestos = (Deno.env.get("ACCESO_ORIGENES") ?? "")
    .split(",").map((s) => s.trim()).filter(Boolean);
  if (puestos.length) return puestos;
  const deLasWebs = WEBS_DEL_CLUB.map((u) => new URL(u).origin);
  return [...new Set([...deLasWebs, "http://localhost:8000", "http://127.0.0.1:8000", "http://localhost:8137"])];
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

async function resumen(texto: string): Promise<string> {
  const bytes = new TextEncoder().encode(SAL + "·" + texto);
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash)).slice(0, 12)
    .map((b) => b.toString(16).padStart(2, "0")).join("");
}

// --- hablar con la base con la llave de servicio ---
async function api(ruta: string, opciones: RequestInit = {}): Promise<Response> {
  return await fetch(`${SUPABASE_URL}${ruta}`, {
    ...opciones,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(opciones.headers ?? {}),
    },
  });
}

async function rpc(nombre: string, cuerpo: unknown): Promise<unknown> {
  const r = await api(`/rest/v1/rpc/${nombre}`, { method: "POST", body: JSON.stringify(cuerpo) });
  if (!r.ok) throw new Error(`${nombre}: ${r.status} ${await r.text()}`);
  const t = await r.text();
  try { return t ? JSON.parse(t) : null; } catch { return t; }
}

// ¿Ya tiene cuenta esta persona? (para no crear dos)
async function yaTieneCuenta(email: string): Promise<boolean> {
  const r = await api(`/auth/v1/admin/users?filter=${encodeURIComponent(email)}`);
  if (!r.ok) return false;
  const datos = await r.json();
  const lista = Array.isArray(datos?.users) ? datos.users : [];
  return lista.some((u: { email?: string }) => (u.email ?? "").toLowerCase() === email);
}

// ============================================================
Deno.serve(async (peticion) => {
  const origen = peticion.headers.get("origin");

  if (peticion.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(origen) });
  if (peticion.method !== "POST") return responder({ ok: false, error: "Método no permitido." }, 405, origen);
  if (origen && !origenesPermitidos().includes(origen)) {
    return responder({ ok: false, error: "Origen no permitido." }, 403, origen);
  }
  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ ok: false, error: "El acceso al grupo todavía no está activado." }, 503, origen);
  }

  let c: {
    nombre?: string; apellidos?: string; email?: string;
    anio?: number | string; password?: string; codigo?: string;
  };
  try { c = await peticion.json(); } catch { c = {}; }

  const nombre = String(c.nombre ?? "").trim();
  const apellidos = String(c.apellidos ?? "").trim();
  const email = String(c.email ?? "").trim().toLowerCase();
  const password = String(c.password ?? "");
  const codigo = String(c.codigo ?? "").trim();
  const anio = parseInt(String(c.anio ?? ""), 10);

  // Validaciones amables: cada una con su mensaje, que aquí SÍ conviene
  // decir qué falta (es un formulario, no una puerta anónima).
  if (nombre.length < 2) return responder({ ok: false, error: "Falta el nombre." }, 400, origen);
  if (!/^[^\s@,;]{1,64}@[^\s@,;]{1,190}\.[a-z]{2,}$/i.test(email)) {
    return responder({ ok: false, error: "El correo no tiene buena pinta." }, 400, origen);
  }
  if (password.length < 8) return responder({ ok: false, error: "La contraseña necesita 8 caracteres o más." }, 400, origen);
  if (!codigo) return responder({ ok: false, error: "Falta el código del grupo." }, 400, origen);
  const anioOk = anio >= 1940 && anio <= new Date().getFullYear();

  try {
    // 1 · Límite de peticiones (mismo control que el acceso por enlace).
    const dedonde = await resumen(peticion.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "sin-origen");
    const sePuede = await rpc("acceso_pedir_apuntar", { p_email: email, p_origen: dedonde });
    if (sePuede !== true) {
      return responder({ ok: false, error: "Demasiados intentos. Prueba dentro de un rato." }, 429, origen);
    }

    // 2 · El código tiene que abrir un grupo. Si no, no se crea nada.
    const grupoId = await rpc("grupo_por_codigo", { p_codigo: codigo });
    if (!grupoId || typeof grupoId !== "string") {
      return responder({ ok: false, error: "Ese código no vale para ningún grupo." }, 403, origen);
    }

    // 3 · ¿Ya tiene cuenta? Entonces no se crea otra: que entre normal.
    if (await yaTieneCuenta(email)) {
      return responder({ ok: true, ya_existe: true }, 200, origen);
    }

    // 4 · El entrenador del grupo, para dejarlo puesto en la ficha.
    let entrenadorId: string | null = null;
    const g = await api(`/rest/v1/grupos?id=eq.${grupoId}&select=entrenador_id`);
    if (g.ok) { const filas = await g.json(); entrenadorId = filas?.[0]?.entrenador_id ?? null; }

    // 5 · La ficha provisional, ANTES de la cuenta. Así, cuando la cuenta
    //     se cree, el enganche automático (por email) la ata sola. El año
    //     se guarda como 1 de enero: la fecha exacta llega con el alta.
    const ficha = {
      nombre, apellidos,
      email,
      fecha_nacimiento: anioOk ? `${anio}-01-01` : null,
      grupo_id: grupoId,
      entrenador_id: entrenadorId,
      provisional: true,
      origen: "acceso_anticipado",
      estado: "activo",
    };
    const insFicha = await api(`/rest/v1/atletas`, {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify(ficha),
    });
    if (!insFicha.ok) {
      console.error("[acceso-grupo] ficha:", insFicha.status, await insFicha.text());
      return responder({ ok: false, error: "No se pudo crear la ficha. Avisa al club." }, 500, origen);
    }
    const fichaCreada = (await insFicha.json())?.[0];
    const atletaId = fichaCreada?.id;

    // 6 · La pertenencia al grupo (por si el disparador de la ficha no la
    //     crea sola: si ya existe, no pasa nada).
    if (atletaId) {
      await api(`/rest/v1/atleta_grupos`, {
        method: "POST",
        headers: { Prefer: "resolution=ignore-duplicates" },
        body: JSON.stringify({ atleta_id: atletaId, grupo_id: grupoId, principal: true }),
      });
    }

    // 7 · La cuenta, con la contraseña que ha elegido el atleta y el correo
    //     ya confirmado. El disparador de la base crea el perfil y engancha
    //     la ficha por email.
    const crear = await api(`/auth/v1/admin/users`, {
      method: "POST",
      body: JSON.stringify({
        email, password, email_confirm: true,
        user_metadata: { nombre, apellidos },
      }),
    });
    if (!crear.ok) {
      console.error("[acceso-grupo] cuenta:", crear.status, await crear.text());
      return responder({ ok: false, error: "No se pudo crear la cuenta. ¿Ya te habías apuntado?" }, 500, origen);
    }

    return responder({ ok: true }, 200, origen);
  } catch (e) {
    console.error("[acceso-grupo]", e);
    return responder({ ok: false, error: "Algo ha fallado. Inténtalo otra vez en un momento." }, 500, origen);
  }
});
