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

function corta(v: unknown, n: number): string { return String(v ?? "").trim().slice(0, n); }

const PORTAL = Deno.env.get("ACCESO_REDIRECT_PORTAL") ?? "https://atletismoapolana.com/portal/";
// Verificación por enlace: si el correo ya es del club, la cuenta nace SIN
// contraseña y se manda un enlace mágico al correo real (nadie ocupa cuentas ajenas).
async function correoDelClub(email: string): Promise<boolean> {
  try { return (await rpc("correo_ya_del_club", { p_email: email })) === true; } catch { return false; }
}
async function enviarEnlace(email: string): Promise<void> {
  try {
    await api(`/auth/v1/otp`, { method: "POST", body: JSON.stringify({ email, should_create_user: false, options: { email_redirect_to: PORTAL }, redirect_to: PORTAL }) });
  } catch (e) { console.error("[entrenador-alta] enlace:", e); }
}

type Ficha = {
  telefono: string; fecha_nacimiento: string; dni: string;
  sexo: string; direccion: string; cp: string; localidad: string;
};

// Guarda la ficha del monitor: el teléfono va al PERFIL (contacto normal) y
// los datos sensibles (fecha, DNI, dirección, sexo) a `entrenador_ficha`, que
// solo ven el admin y el propio monitor. Es un extra a prueba de fallos: la
// cuenta ya está creada, así que si algo aquí falla, el alta no se rompe.
async function guardarFicha(email: string, f: Ficha): Promise<void> {
  // El perfil lo crea un trigger al nacer la cuenta; puede tardar un instante.
  let perfilId: string | null = null;
  for (let i = 0; i < 8 && !perfilId; i++) {
    const r = await api(`/rest/v1/perfiles?select=id&email=eq.${encodeURIComponent(email)}&limit=1`);
    if (r.ok) {
      const d = await r.json().catch(() => null);
      perfilId = Array.isArray(d) && d[0] ? d[0].id : null;
    }
    if (!perfilId) await new Promise((res) => setTimeout(res, 300));
  }
  if (!perfilId) return;

  if (f.telefono) {
    await api(`/rest/v1/perfiles?id=eq.${perfilId}`, {
      method: "PATCH",
      body: JSON.stringify({ telefono: f.telefono }),
    });
  }

  const ficha: Record<string, unknown> = { perfil_id: perfilId, updated_at: new Date().toISOString() };
  if (f.fecha_nacimiento) ficha.fecha_nacimiento = f.fecha_nacimiento;
  if (f.dni) ficha.dni = f.dni;
  if (f.sexo) ficha.sexo = f.sexo;
  if (f.direccion) ficha.direccion = f.direccion;
  if (f.cp) ficha.cp = f.cp;
  if (f.localidad) ficha.localidad = f.localidad;
  await api(`/rest/v1/entrenador_ficha?on_conflict=perfil_id`, {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify(ficha),
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ ok: false, error: "Método no admitido." }, 405, origen);
  if (origen && !origenesPermitidos().includes(origen)) return responder({ ok: false, error: "Origen no permitido." }, 403, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ ok: false, error: "config" }, 503, origen);

  let c: {
    nombre?: string; apellidos?: string; email?: string; password?: string;
    telefono?: string; fecha_nacimiento?: string; dni?: string; sexo?: string;
    direccion?: string; cp?: string; localidad?: string;
    segundos?: number | string; apellido_de_soltera?: string;
  } = {};
  try { c = await req.json(); } catch { /* vacío */ }

  const nombre = String(c.nombre ?? "").trim();
  const apellidos = String(c.apellidos ?? "").trim();
  const email = String(c.email ?? "").trim().toLowerCase();
  const password = String(c.password ?? "");

  // Ficha del monitor. La fecha debe venir como AAAA-MM-DD; si no, se ignora.
  const fnRaw = corta(c.fecha_nacimiento, 10);
  const ficha: Ficha = {
    telefono: corta(c.telefono, 40),
    fecha_nacimiento: /^\d{4}-\d{2}-\d{2}$/.test(fnRaw) ? fnRaw : "",
    dni: corta(c.dni, 30),
    sexo: corta(c.sexo, 20),
    direccion: corta(c.direccion, 240),
    cp: corta(c.cp, 10),
    localidad: corta(c.localidad, 120),
  };

  if (!nombre) return responder({ ok: false, error: "Pon tu nombre." }, 400, origen);
  if (!/^[^\s@,;]{1,64}@[^\s@,;]{1,190}\.[a-z]{2,}$/i.test(email)) {
    return responder({ ok: false, error: "Ese correo no parece bien escrito." }, 400, origen);
  }
  if (password.length < 8) return responder({ ok: false, error: "La contraseña necesita 8 caracteres o más." }, 400, origen);
  if (!ficha.telefono) return responder({ ok: false, error: "Hace falta un teléfono de contacto." }, 400, origen);
  if (!ficha.fecha_nacimiento) return responder({ ok: false, error: "Pon tu fecha de nacimiento (día, mes y año)." }, 400, origen);
  if (!ficha.dni) return responder({ ok: false, error: "Pon tu DNI." }, 400, origen);

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

    // ¿Existe ya la cuenta? Si no, se crea (sin contraseña si el correo ya es del club).
    let ya = "nuevo";
    let verificar = false;
    if (r.ya === "perfil" || await yaTieneCuenta(email)) {
      ya = "cuenta";
    } else {
      const conocido = await correoDelClub(email);
      const crear = await api(`/auth/v1/admin/users`, {
        method: "POST",
        body: JSON.stringify(conocido
          ? { email, email_confirm: true, user_metadata: { nombre, apellidos } }
          : { email, password, email_confirm: true, user_metadata: { nombre, apellidos } }),
      });
      if (!crear.ok) {
        console.error("[entrenador-alta] crear cuenta:", crear.status, await crear.text());
        return responder({ ok: false, error: "No se pudo crear la cuenta. Inténtalo otra vez." }, 500, origen);
      }
      if (conocido) { await enviarEnlace(email); verificar = true; }
    }

    // 4 · Guardar la ficha (teléfono al perfil + datos sensibles a
    //     entrenador_ficha). Best-effort: la cuenta ya está, no bloquea.
    try { await guardarFicha(email, ficha); }
    catch (e) { console.error("[entrenador-alta] ficha:", e); }

    return responder({ ok: true, ya, verificar }, 200, origen);
  } catch (e) {
    console.error("[entrenador-alta]", e);
    return responder({ ok: false, error: "No se ha podido. Inténtalo en un rato." }, 500, origen);
  }
});
