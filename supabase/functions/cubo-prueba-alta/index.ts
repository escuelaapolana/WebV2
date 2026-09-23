// ============================================================
// cubo-prueba-alta · alta a la PRUEBA GRATIS del Cubo (fuerza, octubre)
// ------------------------------------------------------------
// El formulario público manda: datos + correo/contraseña + los TURNOS que
// elige (viernes/sábado/domingo, uno o varios) + si es socio/escuela/otro
// (+ nombre del hijo si es de la escuela) + un horario alternativo libre.
// Aquí:
//   1) Se crea la CUENTA (o, si el correo ya existe, se le AÑADE el papel
//      cubo-atleta sin quitarle los que tenga: socio+cubo, escuela+cubo…).
//   2) Se busca/crea su FICHA (sin pisar una membresía existente).
//   3) Aforo: cada turno tiene 20 plazas; los turnos llenos se descartan.
//   4) Se apunta a los grupos gratis elegidos y se registra en cubo_prueba.
//   5) Correo de confirmación con sus turnos. Es GRATIS: no se cobra nada.
//
// Deploy: supabase functions deploy cubo-prueba-alta --no-verify-jwt --project-ref icaxokjsvhlreuwpyxeb
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") ?? "";
const CORREO_REMITENTE = Deno.env.get("CORREO_REMITENTE") ?? "andres.apolana@gmail.com";
const CORREO_REMITENTE_NOMBRE = Deno.env.get("CORREO_REMITENTE_NOMBRE") ?? "Club Atletismo Apolana";
const CORREO_URL_BASE = (Deno.env.get("CORREO_URL_BASE") ?? "https://atletismoapolana.com").replace(/\/+$/, "");

const AFORO = 20;
const TURNOS: Record<string, string> = {
  viernes: "Viernes · 18:30–19:30",
  sabado: "Sábado · 9:00–10:30",
  domingo: "Domingo · 9:00–10:30",
};
// Palabra del día que aparece en el nombre del grupo, para enlazar turno→grupo.
const DIA_EN_NOMBRE: Record<string, string> = { viernes: "Viernes", sabado: "Sábado", domingo: "Domingo" };

function cors(origen: string | null): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": origen ?? "*",
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
type Opciones = Omit<RequestInit, "headers"> & { headers?: Record<string, string> };
async function rest(ruta: string, opciones: Opciones = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...opciones,
    headers: {
      apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json", ...(opciones.headers ?? {}),
    },
  });
  const t = await r.text();
  let d: unknown = null;
  try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, estado: r.status, datos: d };
}
const dormir = (ms: number) => new Promise((r) => setTimeout(r, ms));
function corta(v: unknown, n: number) { return String(v ?? "").trim().slice(0, n); }
function esc(s: unknown): string {
  return String(s ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
}

function correoHtml(nombre: string, turnos: string[]): string {
  const filas = turnos.map((t) => `<li style="margin:2px 0">${esc(TURNOS[t] || t)}</li>`).join("");
  return `<!doctype html><html><body style="margin:0;background:#F1EADC;padding:24px 12px;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif">
    <table role="presentation" cellpadding="0" cellspacing="0" style="max-width:520px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 12px 30px -18px rgba(38,55,75,.5)">
      <tr><td style="background:#26374B;padding:20px 28px"><span style="color:#fff;font-size:17px;font-weight:700">EL CUBO · Fuerza gratis</span></td></tr>
      <tr><td style="padding:26px 28px 30px">
        <p style="margin:0 0 6px;font-size:20px;font-weight:700;color:#26374B">¡Te has apuntado! ✅</p>
        <p style="margin:0 0 12px;font-size:15px;line-height:1.6;color:#40484F">Hola <b>${esc(nombre)}</b>, te esperamos en el entrenamiento de fuerza gratuito del Cubo. Tus turnos:</p>
        <ul style="margin:0 0 18px;padding-left:20px;color:#26374B;font-size:15px;font-weight:600">${filas}</ul>
        <p style="margin:0 0 20px;font-size:15px;line-height:1.6;color:#40484F">Es gratis y en grupo, dirigido por un entrenador. Ya tienes tu cuenta creada — puedes entrar en la app con tu correo.</p>
        <a href="${CORREO_URL_BASE}/portal/" style="display:inline-block;background:#26374B;color:#fff;text-decoration:none;font-weight:600;font-size:15px;padding:12px 22px;border-radius:11px">Entrar en la app</a>
        <p style="margin:22px 0 0;font-size:13px;color:#6E6656">¿Dudas? Escribe al 681 96 85 63.<br>Club Atletismo Apolana</p>
      </td></tr>
    </table></body></html>`;
}
async function enviarConfirmacion(email: string, nombre: string, turnos: string[]): Promise<void> {
  if (!BREVO_API_KEY || !email) return;
  try {
    await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": BREVO_API_KEY, "Content-Type": "application/json", accept: "application/json" },
      body: JSON.stringify({
        sender: { name: CORREO_REMITENTE_NOMBRE, email: CORREO_REMITENTE },
        to: [{ email, name: nombre || undefined }],
        subject: "Te has apuntado · Fuerza gratis del Cubo ✅",
        htmlContent: correoHtml(nombre, turnos),
      }),
    });
  } catch (e) { console.error("Correo prueba Cubo:", e); }
}

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) return responder({ error: "config", mensaje: "El alta no está configurada todavía." }, 503, origen);

  let b: Record<string, any> = {};
  try { b = await req.json(); } catch { /* vacío */ }

  // 0 · Anti-spam (honeypot + límite por IP)
  if (String(b.website ?? "").trim() !== "") return responder({ ok: true, turnos: [] }, 200, origen);
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim();
  if (ip) {
    const desde = new Date(Date.now() - 15 * 60000).toISOString();
    const rRate = await rest(`rate_limit_log?select=id&accion=eq.cubo-prueba&ip=eq.${encodeURIComponent(ip)}&creado_en=gt.${encodeURIComponent(desde)}`);
    const n = Array.isArray(rRate.datos) ? rRate.datos.length : 0;
    if (n >= 6) return responder({ error: "rate", mensaje: "Demasiados intentos. Prueba dentro de un rato." }, 429, origen);
    await rest("rate_limit_log", { method: "POST", body: JSON.stringify({ ip, accion: "cubo-prueba" }) });
  }

  // 1 · Validar
  const nombre = corta(b.nombre, 120);
  const apellidos = corta(b.apellidos, 120);
  const telefono = corta(b.telefono, 40);
  const email = corta(b.email, 160).toLowerCase();
  const password = String(b.password ?? "");
  const quien = ["socio", "escuela", "otro"].includes(String(b.quien)) ? String(b.quien) : "";
  const hijo = corta(b.hijo, 160);
  const alternativa = corta(b.alternativa, 400);
  let turnos: string[] = Array.isArray(b.turnos) ? b.turnos.filter((t: unknown) => typeof t === "string" && TURNOS[t]) : [];
  turnos = [...new Set(turnos)];

  if (!nombre || !apellidos) return responder({ error: "datos", mensaje: "Pon tu nombre y tus apellidos." }, 400, origen);
  if (!telefono) return responder({ error: "datos", mensaje: "Hace falta un teléfono de contacto." }, 400, origen);
  if (!turnos.length) return responder({ error: "datos", mensaje: "Elige al menos un turno." }, 400, origen);
  if (!quien) return responder({ error: "datos", mensaje: "Dinos si eres socio, de la escuela u otro." }, 400, origen);
  if (quien === "escuela" && !hijo) return responder({ error: "datos", mensaje: "Pon el nombre de tu hijo/a de la escuela." }, 400, origen);
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return responder({ error: "correo", mensaje: "Ese correo no parece válido." }, 400, origen);
  if (password.length < 8) return responder({ error: "clave", mensaje: "La contraseña necesita al menos 8 caracteres." }, 400, origen);

  // 2 · Aforo: descartar turnos ya llenos (20). Se cuentan las altas no canceladas.
  const rEx = await rest(`cubo_prueba?select=turnos&estado=neq.cancelado`);
  const cuenta: Record<string, number> = { viernes: 0, sabado: 0, domingo: 0 };
  if (Array.isArray(rEx.datos)) {
    for (const fila of rEx.datos as { turnos?: string[] }[]) {
      for (const t of (fila.turnos ?? [])) if (cuenta[t] != null) cuenta[t]++;
    }
  }
  const disponibles = turnos.filter((t) => (cuenta[t] ?? 0) < AFORO);
  if (!disponibles.length) {
    return responder({ error: "lleno", mensaje: "Los turnos que has elegido ya están completos (20 plazas). Prueba con otro día o escríbenos al 681 96 85 63." }, 200, origen);
  }

  // 3 · Grupos gratis (para apuntar la ficha a cada turno elegido)
  const rG = await rest(`grupos?select=id,nombre&seccion=eq.cubo&nombre=like.El%20Cubo%20%C2%B7%20Fuerza%20gratis%25`);
  const gruposGratis = Array.isArray(rG.datos) ? rG.datos as { id: string; nombre: string }[] : [];
  function grupoDe(turno: string): string | null {
    const dia = DIA_EN_NOMBRE[turno];
    const g = gruposGratis.find((x) => String(x.nombre).includes(dia));
    return g?.id ?? null;
  }

  // 4 · Cuenta: crear, o si ya existe añadir el papel cubo-atleta (sin quitar los demás).
  let yaExistia = false;
  const rCrea = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (!rCrea.ok) {
    const err = await rCrea.json().catch(() => null);
    const msg = String(err?.msg ?? err?.error_description ?? err?.message ?? "");
    if (rCrea.status === 422 || /registered|already|exists/i.test(msg)) yaExistia = true;
    else { console.error("Alta cuenta:", rCrea.status, msg); return responder({ error: "cuenta", mensaje: "No hemos podido crear la cuenta. Inténtalo de nuevo en un minuto." }, 502, origen); }
  }

  // 5 · Perfil (lo crea un trigger). Añadimos cubo-atleta a sus roles.
  let perfilId: string | null = null;
  for (let i = 0; i < 8 && !perfilId; i++) {
    const rP = await rest(`perfiles?select=id,roles,rol,nombre&email=eq.${encodeURIComponent(email)}&limit=1`);
    const p = Array.isArray(rP.datos) ? rP.datos[0] : null;
    if (p) {
      perfilId = p.id;
      const patch: Record<string, unknown> = {};
      if (yaExistia) {
        // Cuenta que ya existía (socio, escuela…): se le AÑADE el papel del
        // Cubo sin quitarle los demás, y no se le toca el rol principal.
        const roles: string[] = Array.isArray(p.roles) && p.roles.length ? p.roles.slice() : (p.rol ? [p.rol] : []);
        if (!roles.includes("cubo-atleta")) { roles.push("cubo-atleta"); patch.roles = roles; }
      } else {
        // Cuenta nueva: cubo-atleta de principal, con sus datos.
        patch.nombre = nombre; patch.apellidos = apellidos; patch.telefono = telefono;
        patch.rol = "cubo-atleta"; patch.roles = ["cubo-atleta"];
      }
      if (Object.keys(patch).length) await rest(`perfiles?id=eq.${perfilId}`, { method: "PATCH", body: JSON.stringify(patch) });
    } else { await dormir(300); }
  }
  if (!perfilId) return responder({ error: "perfil", mensaje: "La cuenta se creó pero no pudimos terminar tu ficha. Escríbenos y lo dejamos listo." }, 200, origen);

  // 6 · Ficha: buscar la suya (por perfil, o por correo/DNI si ya la tenía como socio/escuela). No se pisa su tipo.
  let atletaId: string | null = null;
  let rAt = await rest(`atletas?select=id,grupo_id,tipo_membresia,perfil_id&perfil_id=eq.${perfilId}&limit=1`);
  let ficha = Array.isArray(rAt.datos) ? rAt.datos[0] : null;
  if (!ficha) {
    rAt = await rest(`atletas?select=id,grupo_id,tipo_membresia,perfil_id&email=eq.${encodeURIComponent(email)}&limit=1`);
    ficha = Array.isArray(rAt.datos) ? rAt.datos[0] : null;
    if (ficha && !ficha.perfil_id) await rest(`atletas?id=eq.${ficha.id}`, { method: "PATCH", body: JSON.stringify({ perfil_id: perfilId }) });
  }
  if (ficha) {
    atletaId = ficha.id;
    if (!ficha.tipo_membresia) await rest(`atletas?id=eq.${ficha.id}`, { method: "PATCH", body: JSON.stringify({ tipo_membresia: "cubo" }) });
  } else {
    const rIns = await rest("atletas", {
      method: "POST", headers: { Prefer: "return=representation" },
      body: JSON.stringify({ perfil_id: perfilId, nombre, apellidos, email, telefono, tipo_membresia: "cubo", estado: "prueba" }),
    });
    const creada = Array.isArray(rIns.datos) ? rIns.datos[0] : rIns.datos;
    atletaId = (creada as { id?: string } | null)?.id ?? null;
  }

  // 7 · Apuntar la ficha a cada grupo gratis elegido (sin duplicar).
  if (atletaId) {
    for (const t of disponibles) {
      const gid = grupoDe(t);
      if (!gid) continue;
      const rY = await rest(`atleta_grupos?select=atleta_id&atleta_id=eq.${atletaId}&grupo_id=eq.${gid}&limit=1`);
      const hay = Array.isArray(rY.datos) && rY.datos.length;
      if (!hay) await rest("atleta_grupos", { method: "POST", body: JSON.stringify({ atleta_id: atletaId, grupo_id: gid, principal: false }) });
    }
  }

  // 8 · Registrar el alta de prueba.
  await rest("cubo_prueba", {
    method: "POST",
    body: JSON.stringify({
      nombre, apellidos, telefono, email, turnos: disponibles,
      quien, hijo: quien === "escuela" ? (hijo || null) : null,
      alternativa: alternativa || null, perfil_id: perfilId, atleta_id: atletaId, estado: "apuntado",
    }),
  });

  // 9 · Correo de confirmación (no bloquea).
  await enviarConfirmacion(email, nombre, disponibles);

  const descartados = turnos.filter((t) => !disponibles.includes(t));
  return responder({ ok: true, ya_existia: yaExistia, turnos: disponibles, turnos_llenos: descartados }, 200, origen);
});
