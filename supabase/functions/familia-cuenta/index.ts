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

// Busca la cuenta por correo; si no está, la crea con la contraseña puesta.
// Si ya existe, le fija esa contraseña (el token es la autorización).
async function cuentaConClave(email: string, password: string): Promise<string | null> {
  const buscar = await rest(
    `/auth/v1/admin/users?filter=${encodeURIComponent(email)}`, { method: "GET" });
  let id: string | null = null;
  if (buscar.ok) {
    const datos = await buscar.json();
    const lista = Array.isArray(datos?.users) ? datos.users : [];
    const suya = lista.find((u: { email?: string }) => (u.email ?? "").toLowerCase() === email);
    if (suya?.id) id = suya.id as string;
  }
  if (id) {
    // Ya tenía cuenta (p. ej. es socia/atleta): le ponemos la contraseña nueva.
    await rest(`/auth/v1/admin/users/${id}`, {
      method: "PUT", body: JSON.stringify({ password, email_confirm: true }),
    });
    return id;
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

    // 2 · Cuenta con la contraseña puesta.
    const uid = await cuentaConClave(email, password);
    if (!uid) return responder({ ok: false, error: "No hemos podido crear la cuenta. Inténtalo de nuevo." }, 500, origen);

    // 3 · Atar a sus hijos (por email_tutor) y ponerle rol de familia.
    try { await rpc("acceso_enganchar", { p_uid: uid, p_email: email }); }
    catch (e) { console.error("[familia-cuenta] enganche:", e); }

    // 4 · Sellar el token (un solo uso).
    await rest(`/rest/v1/familia_invitaciones?token=eq.${encodeURIComponent(token)}`, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ usado_en: new Date().toISOString(), usado_por: uid }),
    });

    // Devolvemos el correo para que la página inicie sesión con la contraseña.
    return responder({ ok: true, email }, 200, origen);
  } catch (e) {
    console.error("[familia-cuenta]", e);
    return responder({ ok: false, error: "Ha habido un problema. Inténtalo de nuevo en un momento." }, 500, origen);
  }
});
