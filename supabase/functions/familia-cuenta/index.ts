// ============================================================
// familia-cuenta · la familia abre su enlace y pone su contraseña
// ------------------------------------------------------------
// QUÉ HACE
//   Cada familia de la escuela de natación recibe un ENLACE único
//   (con un token). Al abrirlo pone una contraseña nueva y con eso
//   se le crea la cuenta de "familia" (rol padre), atada a su correo
//   de tutor —el que ya está en las fichas de sus hijos—. Al entrar
//   ve a sus hijos: horarios, faltas, avisos y su ficha.
//
// POR QUÉ POR TOKEN Y NO POR CORREO
//   Andrés reparte el enlace él mismo (p. ej. por WhatsApp del
//   responsable). El token es el secreto: es de un solo uso y caduca.
//   No hace falta que la familia reciba nada en su bandeja.
//
// SEGURIDAD (datos de menores)
//   - El token vive en familia_invitaciones, que NADIE lee por RLS;
//     aquí se mira con la llave de servicio.
//   - El correo de la cuenta NO lo pone la familia: sale del token
//     (email_tutor). Así nadie se cuela con el correo de otro.
//   - acceso_enganchar ata SOLO las fichas cuyo email_tutor coincide.
//   - Token de un solo uso: al gastarlo, usado_en queda sellado.
//
// CLAVES (las pone Supabase, no viajan aquí)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY
//
// Se despliega:
//   supabase functions deploy familia-cuenta --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
//   (--no-verify-jwt imprescindible: aquí llama gente que aún no ha entrado.)
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
// A dónde lleva el enlace mágico cuando el correo ya es de una cuenta con más
// permisos que una familia (se le manda en vez de fijarle la contraseña).
const PORTAL = Deno.env.get("ACCESO_REDIRECT_PORTAL") ?? "https://atletismoapolana.com/portal/";

const WEBS_DEL_CLUB = [
  "https://escuelaapolana.github.io/WebV2/",
  "https://atletismoapolana.com/",
  "https://www.atletismoapolana.com/",
];

function origenesPermitidos(): string[] {
  const puestos = (Deno.env.get("ACCESO_ORIGENES") ?? "")
    .split(",").map((s) => s.trim()).filter(Boolean);
  const deLasWebs = WEBS_DEL_CLUB.map((u) => new URL(u).origin);
  return [...new Set([...puestos, ...deLasWebs, "http://localhost:8000", "http://127.0.0.1:8000"])];
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

async function rest(path: string, init: RequestInit): Promise<Response> {
  return await fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

async function rpc(nombre: string, cuerpo: unknown): Promise<unknown> {
  const r = await rest(`/rest/v1/rpc/${nombre}`, { method: "POST", body: JSON.stringify(cuerpo) });
  if (!r.ok) throw new Error(`${nombre}: ${r.status} ${await r.text()}`);
  const t = await r.text();
  try { return t ? JSON.parse(t) : null; } catch { return t; }
}

// Papeles que un alta de FAMILIA puede llevar sin riesgo: los que salen de las
// fichas (padre/atleta) o el de familia. Cualquier OTRO papel (entrenador,
// responsable, admin, junta, tesoreria, coordinador, socio, cubo-*…) es una
// cuenta con más permisos, y a ésa NUNCA se le fija contraseña con un token de
// familia: se le manda un enlace mágico a su correo real (igual que socio-cuenta).
const PAPELES_FAMILIA = new Set(["atleta", "padre", "familia"]);

// Enlace mágico al correo real: solo el dueño del buzón entra (should_create_user
// false: si por lo que fuera no existiera la cuenta, no se crea nada).
async function enviarEnlace(email: string): Promise<void> {
  try {
    await rest(`/auth/v1/otp`, {
      method: "POST",
      body: JSON.stringify({ email, should_create_user: false, options: { email_redirect_to: PORTAL }, redirect_to: PORTAL }),
    });
  } catch (e) { console.error("[familia-cuenta] enlace:", e); }
}

// ¿Existe ya una cuenta con este correo? Devuelve su id (o null).
async function buscarCuenta(email: string): Promise<string | null> {
  const buscar = await rest(
    `/auth/v1/admin/users?filter=${encodeURIComponent(email)}`, { method: "GET" });
  if (!buscar.ok) return null;
  const datos = await buscar.json();
  const lista = Array.isArray(datos?.users) ? datos.users : [];
  const suya = lista.find((u: { email?: string }) => (u.email ?? "").toLowerCase() === email);
  return (suya?.id as string) ?? null;
}

// ¿La cuenta (buscada por id, sin depender de mayúsculas del correo) tiene algún
// papel por encima de una familia? Ante la duda (no se puede leer el perfil)
// decimos que sí: preferimos mandar enlace antes que fijarle una contraseña a
// alguien. Una cuenta a medias (sin perfil aún) no cuenta como cuenta con permisos.
async function cuentaElevada(uid: string): Promise<boolean> {
  const r = await rest(`/rest/v1/perfiles?id=eq.${uid}&select=rol,roles`, { method: "GET" });
  if (!r.ok) return true;
  const filas = await r.json().catch(() => null);
  const p = Array.isArray(filas) ? filas[0] : null;
  if (!p) return false;
  const papeles = [p.rol, ...(Array.isArray(p.roles) ? p.roles : [])]
    .filter((x: unknown) => typeof x === "string" && (x as string).trim() !== "");
  return papeles.some((x: string) => !PAPELES_FAMILIA.has(x));
}

// Deja la cuenta con la contraseña puesta. Si no existía, la crea; si ya existía
// (aquí solo se llega con cuentas de familia/atleta), le fija la nueva.
async function cuentaConClave(email: string, password: string, idExistente: string | null): Promise<string | null> {
  if (idExistente) {
    await rest(`/auth/v1/admin/users/${idExistente}`, {
      method: "PUT", body: JSON.stringify({ password, email_confirm: true }),
    });
    return idExistente;
  }
  const crear = await rest(`/auth/v1/admin/users`, {
    method: "POST",
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (crear.ok) { const d = await crear.json(); return (d?.id as string) ?? null; }
  return null;
}

Deno.serve(async (peticion) => {
  const origen = peticion.headers.get("origin");
  if (peticion.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(origen) });
  if (peticion.method !== "POST") return responder({ ok: false, error: "Método no permitido." }, 405, origen);
  if (origen && !origenesPermitidos().includes(origen)) {
    return responder({ ok: false, error: "Origen no permitido." }, 403, origen);
  }
  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ ok: false, error: "El acceso de familias todavía no está activado." }, 503, origen);
  }

  let cuerpo: { token?: string; password?: string };
  try { cuerpo = await peticion.json(); } catch { cuerpo = {}; }
  const token = String(cuerpo.token ?? "").trim();
  const password = String(cuerpo.password ?? "");
  if (!/^[A-Za-z0-9_-]{16,80}$/.test(token)) {
    return responder({ ok: false, error: "Enlace no válido." }, 200, origen);
  }
  if (password.length < 6) {
    return responder({ ok: false, error: "La contraseña es muy corta (mínimo 6)." }, 200, origen);
  }

  try {
    // 1 · El token: que exista, no esté usado y no haya caducado.
    const r = await rest(
      `/rest/v1/familia_invitaciones?token=eq.${encodeURIComponent(token)}&select=token,email_tutor,usado_en,caduca_en`,
      { method: "GET" });
    const filas = r.ok ? await r.json() : [];
    const inv = Array.isArray(filas) ? filas[0] : null;
    if (!inv) return responder({ ok: false, error: "Este enlace no es válido." }, 200, origen);
    if (inv.usado_en) return responder({ ok: false, error: "Este enlace ya se ha usado. Si ya tienes cuenta, entra con tu contraseña." }, 200, origen);
    if (inv.caduca_en && new Date(inv.caduca_en) < new Date()) {
      return responder({ ok: false, error: "Este enlace ha caducado. Pídele al club uno nuevo." }, 200, origen);
    }
    const email = String(inv.email_tutor ?? "").trim().toLowerCase();
    if (!email) return responder({ ok: false, error: "Este enlace no es válido." }, 200, origen);

    // 2 · Sellar el token AHORA y de forma atómica, ANTES de tocar ninguna
    //     cuenta: un único UPDATE lo marca SOLO si sigue sin usar (usado_en is
    //     null). Si otra petición ya lo gastó, no se actualiza ninguna fila y
    //     paramos. Así el enlace no se puede reusar ni correr dos veces a la vez.
    const sello = await rest(
      `/rest/v1/familia_invitaciones?token=eq.${encodeURIComponent(token)}&usado_en=is.null`,
      { method: "PATCH", headers: { Prefer: "return=representation" },
        body: JSON.stringify({ usado_en: new Date().toISOString() }) });
    const selladas = sello.ok ? await sello.json().catch(() => []) : [];
    if (!Array.isArray(selladas) || selladas.length === 0) {
      return responder({ ok: false, error: "Este enlace ya se ha usado. Si ya tienes cuenta, entra con tu contraseña." }, 200, origen);
    }

    // 3 · ¿Ya hay cuenta con este correo? Si la hay y tiene MÁS permisos que una
    //     familia (entrenador, responsable, admin, tesoreria, socio, cubo-*…), NO
    //     le fijamos la contraseña con un token de familia: le mandamos un enlace
    //     mágico a su buzón —solo el dueño entra— (igual que socio-cuenta). El
    //     token ya quedó gastado, así que el enlace de WhatsApp no vale a nadie más.
    const idExistente = await buscarCuenta(email);
    if (idExistente && await cuentaElevada(idExistente)) {
      await enviarEnlace(email);
      return responder({ ok: true, enlace: true, email }, 200, origen);
    }

    // 4 · Cuenta con la contraseña puesta (nueva, o ya existente de familia/atleta).
    const uid = await cuentaConClave(email, password, idExistente);
    if (!uid) return responder({ ok: false, error: "No hemos podido crear la cuenta. Inténtalo de nuevo." }, 500, origen);

    // 5 · Atar a sus hijos (por email_tutor) y ponerle rol de familia.
    try { await rpc("acceso_enganchar", { p_uid: uid, p_email: email }); }
    catch (e) { console.error("[familia-cuenta] enganche:", e); }

    // 6 · Anotar quién gastó el enlace (ya sellado como usado en el paso 2).
    await rest(`/rest/v1/familia_invitaciones?token=eq.${encodeURIComponent(token)}`, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ usado_por: uid }),
    });

    // Devolvemos el correo para que la página inicie sesión con la contraseña.
    return responder({ ok: true, email }, 200, origen);
  } catch (e) {
    console.error("[familia-cuenta]", e);
    return responder({ ok: false, error: "Ha habido un problema. Inténtalo de nuevo en un momento." }, 500, origen);
  }
});
