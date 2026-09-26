// ============================================================
// socio-cuenta · crea la cuenta de ACCESO de un socio (rol 'socio')
// ------------------------------------------------------------
// Cuando alguien se hace socio (formulario /socio/alta/), además de
// guardar su alta (eso lo hace `enviar_alta_socio`), aquí se le crea la
// CUENTA para entrar a su zona (noticias + actividades). Rol 'socio'.
//   · Si el correo ya tiene cuenta, no se duplica: se le añade el papel
//     'socio' y se le dice que entre con su contraseña de siempre.
//   · La contraseña NUNCA pasa por la base: la teclea la persona y va a
//     Supabase Auth. Mínimo 8 caracteres.
// Se despliega SIN verificar JWT (es un alta pública):
//   supabase functions deploy socio-cuenta --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const SAL = Deno.env.get("ACCESO_SAL") ?? "apolana-acceso";
const PORTAL = Deno.env.get("ACCESO_REDIRECT_PORTAL") ?? "https://atletismoapolana.com/portal/";

function cors(origen: string | null): Record<string, string> {
  const permitidos = (Deno.env.get("PAGOS_ORIGENES") ?? Deno.env.get("CORREO_ORIGENES") ?? "")
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
    status: estado, headers: { ...cors(origen), "Content-Type": "application/json; charset=utf-8" },
  });
}
async function rest(ruta: string, opciones: RequestInit = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...opciones,
    headers: {
      apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json", ...(opciones.headers ?? {} as Record<string, string>),
    },
  });
  const t = await r.text();
  let d: unknown = null; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, datos: d };
}
const corta = (v: unknown, n: number) => String(v ?? "").trim().slice(0, n);

// Un resumen del origen que no se puede deshacer: sirve para contar peticiones
// sin guardar la IP de nadie (mismo patrón que acceso-enlace).
async function resumen(texto: string): Promise<string> {
  const bytes = new TextEncoder().encode(SAL + "·" + texto);
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash)).slice(0, 12)
    .map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Verificación por enlace: ¿el correo ya es del club (ficha o perfil)? Si lo es,
// la cuenta se crea SIN contraseña y se manda un enlace mágico al correo real, para
// que nadie ocupe la cuenta de un miembro importado poniéndole una contraseña.
async function correoDelClub(email: string): Promise<boolean> {
  const r = await rest(`rpc/correo_ya_del_club`, { method: "POST", body: JSON.stringify({ p_email: email }) });
  return r.datos === true;
}
async function enviarEnlace(email: string): Promise<void> {
  try {
    await fetch(`${SUPABASE_URL}/auth/v1/otp`, {
      method: "POST",
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ email, should_create_user: false, options: { email_redirect_to: PORTAL }, redirect_to: PORTAL }),
    });
  } catch (e) { console.error("[socio-cuenta] enlace:", e); }
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "metodo" }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config", mensaje: "El alta no está configurada." }, 503, origen);

  let b: Record<string, unknown> = {};
  try { b = await req.json(); } catch { /* vacío */ }
  const email = corta(b.email, 160).toLowerCase();
  const password = String(b.password ?? "");
  const nombre = corta(b.nombre, 80);
  const apellidos = corta(b.apellidos, 120);

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return responder({ error: "correo", mensaje: "Ese correo no parece válido." }, 400, origen);
  if (password.length < 8) return responder({ error: "clave", mensaje: "La contraseña necesita al menos 8 caracteres." }, 400, origen);

  // 0 · Freno anti-abuso por origen (mismo patrón que acceso-enlace): sin esto,
  //     cualquiera podía crear cuentas en masa o enumerar correos aporreando
  //     esta puerta. 30 por origen y hora; de sobra para un alta de verdad.
  const dedonde = await resumen(req.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "sin-origen");
  const ritmo = await rest(`rpc/alta_ritmo`, {
    method: "POST",
    body: JSON.stringify({ p_tipo: "socio-cuenta", p_origen: dedonde, p_max: 30 }),
  });
  if (ritmo.datos !== true) {
    return responder({ error: "ritmo", mensaje: "Demasiados intentos desde aquí. Prueba de nuevo dentro de un rato." }, 429, origen);
  }

  // 1 · Crear la cuenta (un trigger crea el perfil; luego lo dejamos 'socio').
  // Si el correo ya es del club, la cuenta nace SIN contraseña (solo enlace mágico).
  const conocido = await correoDelClub(email);
  let yaExistia = false;
  const rCrea = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(conocido ? { email, email_confirm: true } : { email, password, email_confirm: true }),
  });
  if (!rCrea.ok) {
    const err = await rCrea.json().catch(() => null);
    const msg = String((err as { msg?: string; message?: string; error_description?: string })?.msg
      ?? (err as { message?: string })?.message ?? (err as { error_description?: string })?.error_description ?? "");
    if (rCrea.status === 422 || /registered|already|exists/i.test(msg)) yaExistia = true;
    else {
      console.error("socio-cuenta: crear usuario falló:", rCrea.status, msg);
      return responder({ error: "cuenta", mensaje: "No hemos podido crear la cuenta. Inténtalo en un minuto." }, 502, origen);
    }
  }

  // 2 · Perfil. Nuevo → rol 'socio' (con su nombre). Existente → se le añade
  //     el papel 'socio' sin tocar los demás.
  let perfilId: string | null = null;
  for (let i = 0; i < 8 && !perfilId; i++) {
    const rP = await rest(`perfiles?select=id,roles,rol&email=eq.${encodeURIComponent(email)}&limit=1`);
    const p = Array.isArray(rP.datos) ? rP.datos[0] as { id: string; roles?: string[]; rol?: string } : null;
    if (p) {
      perfilId = p.id;
      if (yaExistia) {
        // Cuenta YA existente: no se le tocan los roles. Añadir 'socio' a una
        // cuenta ajena identificada solo por el correo (sin comprobar la
        // contraseña) sería modificar el perfil de un tercero. Si un socio real
        // ya tenía cuenta, entra con su contraseña de siempre; si necesita el rol
        // 'socio', se lo pone administración desde el panel.
      } else {
        await rest(`perfiles?id=eq.${perfilId}`, {
          method: "PATCH",
          body: JSON.stringify({
            ...(nombre ? { nombre } : {}), ...(apellidos ? { apellidos } : {}),
            rol: "socio", roles: ["socio"],
          }),
        });
      }
    } else {
      await new Promise((r) => setTimeout(r, 350));
    }
  }
  if (!perfilId) {
    return responder({ ok: false, error: "perfil", mensaje: "La cuenta se creó pero no pudimos terminar tu ficha. Escríbenos y lo dejamos listo." }, 200, origen);
  }

  const verificar = conocido && !yaExistia;
  if (verificar) await enviarEnlace(email);
  return responder({ ok: true, ya_existia: yaExistia, verificar }, 200, origen);
});
