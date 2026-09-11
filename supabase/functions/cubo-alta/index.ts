// ============================================================
// cubo-alta · alta + cuenta de quien entrena en El Cubo
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   El formulario público manda los datos + un correo y una contraseña.
//   Aquí se crea la CUENTA (para que pueda entrar), su PERFIL con el
//   papel `cubo-atleta`, su FICHA (tipo «cubo») en el grupo del turno
//   elegido, y se deja registrada el alta. No se cobra nada: el pago
//   (suscripción mensual) va aparte, del 21 en adelante.
//
//   El PERFIL lo crea solo el trigger `on_auth_user_created` al nacer la
//   cuenta. Ese trigger mira `invitaciones_equipo` por correo: por eso,
//   ANTES de crear la cuenta, dejamos una invitación con rol `cubo-atleta`
//   y el nombre de verdad, y el perfil nace ya correcto (sin carreras).
//
//   El precio (escuela 20/30 · fuera 30/40) lo calcula el servidor a
//   partir de escuela + días, nunca el navegador.
//
//   Si el correo YA tiene cuenta, no se rompe: se le añade el papel del
//   Cubo y entra con su contraseña de siempre.
//
// CLAVES (variables de entorno de Supabase; aquí no hay ninguna)
//     SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY  (las pone Supabase)
//
// Se despliega SIN comprobar el JWT (quien se apunta no tiene sesión):
//     supabase functions deploy cubo-alta --no-verify-jwt
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";

const SLOT_A_GRUPO: Record<string, string> = {
  "lx-1730": "El Cubo · L y X 17:30",
  "mj-1730": "El Cubo · M y J 17:30",
  "lx-1845": "El Cubo · L y X 18:45",
};

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
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(opciones.headers ?? {}),
    },
  });
  const t = await r.text();
  let d: unknown = null;
  try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: r.ok, estado: r.status, datos: d };
}

const dormir = (ms: number) => new Promise((r) => setTimeout(r, ms));
function corta(v: unknown, n: number) { return String(v ?? "").trim().slice(0, n); }

Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);
  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ error: "config", mensaje: "El alta no está configurada todavía." }, 503, origen);
  }

  let b: Record<string, any> = {};
  try { b = await req.json(); } catch { /* vacío */ }

  // ---- 1 · Validar ----
  const nombre = corta(b.nombre, 120);
  const apellidos = corta(b.apellidos, 120);
  const telefono = corta(b.telefono, 40);
  const dni = corta(b.dni, 30);
  const direccion = corta(b.direccion, 240);
  const hijo = corta(b.hijo, 160);
  const nota = corta(b.nota, 400);
  const escuela = b.escuela === true || b.escuela === "true";
  const slot = corta(b.slot, 20);
  const diasN = Math.round(Number(b.dias));
  const dias = diasN === 1 ? 1 : (diasN === 2 ? 2 : 0);
  const email = corta(b.email, 160).toLowerCase();
  const password = String(b.password ?? "");

  if (!nombre || !apellidos) return responder({ error: "datos", mensaje: "Pon tu nombre y tus apellidos." }, 400, origen);
  if (!telefono) return responder({ error: "datos", mensaje: "Hace falta un teléfono de contacto." }, 400, origen);
  if (!SLOT_A_GRUPO[slot]) return responder({ error: "datos", mensaje: "Elige un horario de la lista." }, 400, origen);
  if (!dias) return responder({ error: "datos", mensaje: "Indica si vienes uno o dos días." }, 400, origen);
  if (escuela && !hijo) return responder({ error: "datos", mensaje: "Para el precio reducido, dinos el nombre de tu hijo/a en la escuela." }, 400, origen);
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return responder({ error: "correo", mensaje: "Ese correo no parece válido." }, 400, origen);
  if (password.length < 8) return responder({ error: "clave", mensaje: "La contraseña necesita al menos 8 caracteres." }, 400, origen);

  const precio = escuela ? (dias === 1 ? 20 : 30) : (dias === 1 ? 30 : 40);

  // ---- 2 · Grupo del turno ----
  const rGrupo = await rest(`grupos?select=id&seccion=eq.cubo&nombre=eq.${encodeURIComponent(SLOT_A_GRUPO[slot])}&limit=1`);
  const grupo = Array.isArray(rGrupo.datos) ? rGrupo.datos[0] : null;
  const grupoId: string | null = grupo?.id ?? null;

  // ---- 3 · Crear la cuenta. Un trigger crea el perfil (rol 'atleta' por
  //          defecto); justo después lo dejamos como 'cubo-atleta'. ----
  let yaExistia = false;
  const rCrea = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (!rCrea.ok) {
    const err = await rCrea.json().catch(() => null);
    const msg = String(err?.msg ?? err?.error_description ?? err?.message ?? "");
    if (rCrea.status === 422 || /registered|already|exists/i.test(msg)) {
      yaExistia = true;
    } else {
      console.error("Alta cuenta falló:", rCrea.status, msg);
      return responder({ error: "cuenta", mensaje: "No hemos podido crear la cuenta. Inténtalo de nuevo en un minuto." }, 502, origen);
    }
  }

  // ---- 4 · Perfil. El trigger lo crea al nacer la cuenta (reintenta por si
  //          tarda un instante). Nuevo → lo dejamos como cubo-atleta con su
  //          nombre; existente → solo le añadimos el papel del Cubo. ----
  let perfilId: string | null = null;
  for (let i = 0; i < 8 && !perfilId; i++) {
    const rP = await rest(`perfiles?select=id,roles,rol&email=eq.${encodeURIComponent(email)}&limit=1`);
    const p = Array.isArray(rP.datos) ? rP.datos[0] : null;
    if (p) {
      perfilId = p.id;
      if (yaExistia) {
        const roles: string[] = Array.isArray(p.roles) && p.roles.length ? p.roles.slice() : (p.rol ? [p.rol] : []);
        if (!roles.includes("cubo-atleta")) {
          roles.push("cubo-atleta");
          await rest(`perfiles?id=eq.${perfilId}`, { method: "PATCH", body: JSON.stringify({ roles }) });
        }
      } else {
        await rest(`perfiles?id=eq.${perfilId}`, {
          method: "PATCH",
          body: JSON.stringify({
            nombre, apellidos, telefono,
            rol: "cubo-atleta", roles: ["cubo-atleta"],
          }),
        });
      }
    } else {
      await dormir(300);
    }
  }
  if (!perfilId) {
    return responder({ error: "perfil", mensaje: "La cuenta se creó pero no pudimos terminar tu ficha. Escríbenos y lo dejamos listo." }, 200, origen);
  }

  // ---- 6 · Ficha de atleta (tipo cubo) en su grupo ----
  const rAt = await rest(`atletas?select=id,grupo_id,tipo_membresia&perfil_id=eq.${perfilId}&limit=1`);
  const yaFicha = Array.isArray(rAt.datos) ? rAt.datos[0] : null;
  if (yaFicha) {
    // No pisamos una membresía existente (socio/escuela): solo rellenamos huecos.
    const patch: Record<string, unknown> = {};
    if (!yaFicha.grupo_id && grupoId) patch.grupo_id = grupoId;
    if (!yaFicha.tipo_membresia) patch.tipo_membresia = "cubo";
    if (Object.keys(patch).length) await rest(`atletas?id=eq.${yaFicha.id}`, { method: "PATCH", body: JSON.stringify(patch) });
  } else {
    await rest("atletas", {
      method: "POST",
      body: JSON.stringify({
        perfil_id: perfilId, nombre, apellidos, dni: dni || null,
        email, telefono, tipo_membresia: "cubo", grupo_id: grupoId, estado: "prueba",
      }),
    });
  }

  // ---- 7 · Registro del alta (para la lista del club) ----
  await rest("cubo_altas", {
    method: "POST",
    body: JSON.stringify({
      nombre, apellidos, dni: dni || null, telefono,
      hijo: hijo || null, direccion: direccion || null,
      horario: SLOT_A_GRUPO[slot], dias, precio_mes: precio,
      nota: nota || null, es_escuela: escuela, estado: "pendiente",
    }),
  });

  return responder({ ok: true, ya_existia: yaExistia, perfil_id: perfilId, precio_mes: precio }, 200, origen);
});
