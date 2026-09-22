// ============================================================
// entrenador-alta · alta de entrenador de la escuela CON contraseña
// ------------------------------------------------------------
// El entrenador rellena nombre, apellidos, correo y la CONTRASEÑA que
// quiera. Aquí:
//   1) Se crea la invitación de entrenador (RPC alta_entrenador, que ya
//      trae el anti-bots y el rol 'entrenador').
//   2) Se crea la cuenta de acceso con esa contraseña (admin API).
//   3) A partir de ahí entra siempre con correo + contraseña. El club le
//      asigna su grupo desde el panel.
// El importe/rol NO se fía del navegador: el rol lo da la invitación.
//
// Deploy:  supabase functions deploy entrenador-alta --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";

const WEBS_DEL_CLUB = [
  "https://escuelaapolana.github.io/WebV2/",
  "https://atletismoapolana.com/",
  "https://www.atletismoapolana.com/",
];
function origenesPermitidos(): string[] {
  const puestos = (Deno.env.get("ACCESO_ORIGENES") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const deLasWebs = WEBS_DEL_CLUB.map((u) => new URL(u).origin);
  return [...new Set([...puestos, ...deLasWebs, "http://localhost:8000", "http://127.0.0.1:8000", "http://localhost:8137"])];
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
async function api(ruta: string, opciones: RequestInit = {}): Promise<Response> {
  return await fetch(`${SUPABASE_URL}${ruta}`, {
    ...opciones,
    headers: {
      apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json", ...(opciones.headers ?? {}),
    },
  });
}
async function rpc(nombre: string, cuerpo: unknown): Promise<unknown> {
  const r = await api(`/rest/v1/rpc/${nombre}`, { method: "POST", body: JSON.stringify(cuerpo) });
  if (!r.ok) throw new Error(`${nombre}: ${r.status} ${await r.text()}`);
  const t = await r.text();
  try { return t ? JSON.parse(t) : null; } catch { return t; }
}
async function yaTieneCuenta(email: string): Promise<boolean> {
  const r = await api(`/auth/v1/admin/users?filter=${encodeURIComponent(email)}`);
  if (!r.ok) return false;
  const datos = await r.json();
  const lista = datos?.users ?? datos ?? [];
  return Array.isArray(lista) && lista.some((u: { email?: string }) =>
    (u.email ?? "").toLowerCase() === email.toLowerCase());
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ ok: false, error: "Método no admitido." }, 405, origen);
  if (origen && !origenesPermitidos().includes(origen)) return responder({ ok: false, error: "Origen no permitido." }, 403, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ ok: false, error: "config" }, 503, origen);

  let c: {
    nombre?: string; apellidos?: string; email?: string; password?: string;
    segundos?: number | string; apellido_de_soltera?: string;
  } = {};
  try { c = await req.json(); } catch { /* vacío */ }

  const nombre = String(c.nombre ?? "").trim();
  const apellidos = String(c.apellidos ?? "").trim();
  const email = String(c.email ?? "").trim().toLowerCase();
  const password = String(c.password ?? "");

  if (!nombre) return responder({ ok: false, error: "Pon tu nombre." }, 400, origen);
  if (!/^[^\s@,;]{1,64}@[^\s@,;]{1,190}\.[a-z]{2,}$/i.test(email)) {
    return responder({ ok: false, error: "Ese correo no parece bien escrito." }, 400, origen);
  }
  if (password.length < 8) return responder({ ok: false, error: "La contraseña necesita 8 caracteres o más." }, 400, origen);

  try {
    // 1 · Invitación de entrenador (anti-bots + rol dentro del RPC).
    const r = await rpc("alta_entrenador", {
      p: {
        nombre, apellidos, email,
        segundos: c.segundos, apellido_de_soltera: c.apellido_de_soltera ?? "",
      },
    }) as { ok?: boolean; ya?: string; mensaje?: string };

    if (!r || r.ok === false) {
      return responder({ ok: false, error: (r && r.mensaje) || "No se ha podido. Inténtalo otra vez." }, 400, origen);
    }
    // Ya tenía cuenta: que entre con su contraseña (no creamos otra).
    if (r.ya === "perfil") {
      return responder({ ok: true, ya: "perfil" }, 200, origen);
    }

    // 2 · ¿Ya existe la cuenta de acceso? Entonces no la recreamos.
    if (await yaTieneCuenta(email)) {
      return responder({ ok: true, ya: "cuenta" }, 200, origen);
    }

    // 3 · Crear la cuenta con la contraseña que ha puesto.
    const crear = await api(`/auth/v1/admin/users`, {
      method: "POST",
      body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { nombre, apellidos } }),
    });
    if (!crear.ok) {
      console.error("[entrenador-alta] crear cuenta:", crear.status, await crear.text());
      return responder({ ok: false, error: "No se pudo crear la cuenta. Inténtalo otra vez." }, 500, origen);
    }
    return responder({ ok: true, ya: "nuevo" }, 200, origen);
  } catch (e) {
    console.error("[entrenador-alta]", e);
    return responder({ ok: false, error: "No se ha podido. Inténtalo en un rato." }, 500, origen);
  }
});
