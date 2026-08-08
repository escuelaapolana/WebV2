// ============================================================
// strava · lleva a Strava lo que se apunta aquí
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   El atleta entrena con su Garmin, el reloj sube la actividad a
//   Strava solo, y aquí apunta lo que hizo de verdad: las series, los
//   kilos, cómo se sintió. Esta función coge eso y lo escribe EN LA
//   ACTIVIDAD QUE YA ESTÁ EN STRAVA: le pone el título del
//   entrenamiento y, en la descripción, lo que el reloj no sabe.
//
// ⚠️ NO CREA ACTIVIDADES, Y ES LA DECISIÓN MÁS IMPORTANTE DE TODO ESTO
//   Crear era lo obvio y era lo peor: el reloj ya sube la suya, así
//   que cada día habría DOS actividades —la buena, con GPS y vueltas,
//   y una manual sin nada— y alguien tendría que borrar una a mano
//   cada día. Eso no se aguanta una semana.
//
// POR QUÉ ESTO NO PUEDE VIVIR EN EL NAVEGADOR
//   Porque hace falta el secreto de la aplicación de Strava para
//   cambiar un código por unas llaves y para renovarlas. Un secreto en
//   el navegador no es un secreto: la web del club es estática y
//   pública, cualquiera ve su código. Aquí abajo vive dentro de
//   Supabase y no sale.
//
//   Y por eso mismo las llaves de cada persona se guardan en una tabla
//   que el navegador NO PUEDE LEER (migración 145: RLS activado, cero
//   políticas y ningún permiso). Con esas llaves se puede modificar
//   todo el Strava de alguien; no son un dato del club.
//
// LAS CUATRO COSAS QUE SABE HACER  (?accion=)
//   conectar    · devuelve la dirección de Strava donde autorizar
//   volver      · Strava manda de vuelta un código; aquí se cambia por
//                 las llaves y se guardan
//   enviar      · busca la actividad de ese día y la enriquece
//   probar      · dice si hay actividad ese día, sin tocar nada
//
// CLAVES · ninguna está en este archivo ni puede estarlo
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY · las pone Supabase sola
//   STRAVA_CLIENT_ID     · de strava.com/settings/api
//   STRAVA_CLIENT_SECRET · lo mismo, y esto es un secreto de verdad
//   ACCESO_URL_BASE      · la web del club (a dónde vuelve Strava)
//
// Cómo se despliega:
//     supabase functions deploy strava --no-verify-jwt
//
// ⚠️ EL `--no-verify-jwt` ES IMPRESCINDIBLE Y NO ABRE NADA.
// Hace falta porque `volver` lo llama STRAVA, no el portal: es una
// redirección del navegador y no lleva ni puede llevar la sesión. Sin
// el `--no-verify-jwt`, Supabase la rechaza con un 401 antes de que
// este archivo se ejecute, y conectar la cuenta no funciona nunca.
//
// La sesión se sigue exigiendo, pero AQUÍ DENTRO: todas las acciones
// menos `volver` pasan por `quienLlama()`, que valida el token contra
// Supabase y saca de ahí de quién es la cuenta. Nada sale del cuerpo
// de la petición, así que nadie puede escribir en el Strava de otro.
// Y `volver` no lleva dentro más que un código de un solo uso que
// caduca, y un `state` que se comprueba contra la tabla de perfiles.
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";

const CLIENT_ID = Deno.env.get("STRAVA_CLIENT_ID") ?? "";
const CLIENT_SECRET = Deno.env.get("STRAVA_CLIENT_SECRET") ?? "";

const WEBS_DEL_CLUB = [
  "https://escuelaapolana.github.io/WebV2/",
  "https://escuelaapolana.github.io/apolana-club/",
];
const URL_BASE = (Deno.env.get("ACCESO_URL_BASE") ?? WEBS_DEL_CLUB[0]).replace(/\/*$/, "/");

// A dónde vuelve Strava. Es la propia función: la página del perfil no
// puede recibirlo porque el cambio de código por llaves necesita el
// secreto. Desde aquí se redirige al perfil ya con el resultado.
function urlDeVuelta(): string {
  return `${SUPABASE_URL}/functions/v1/strava?accion=volver`;
}

/* LOS PERMISOS QUE SE PIDEN, Y NI UNO MÁS
   · activity:read_all · para ENCONTRAR la actividad del día. El
     «_all» hace falta porque mucha gente tiene las actividades en
     privado, y sin él las suyas no se ven ni siendo su dueño.
   · activity:write · para escribirle el título y la descripción.
   NO se pide `profile:write` ni nada de los datos de la persona: aquí
   no se toca su perfil de Strava. */
const SCOPE = "activity:read_all,activity:write";

// ------------------------------------------------------------
// Quién puede llamarnos desde un navegador
// ------------------------------------------------------------
function origenesPermitidos(): string[] {
  const puestos = (Deno.env.get("ACCESO_ORIGENES") ?? "")
    .split(",").map((s) => s.trim()).filter(Boolean);
  if (puestos.length) return puestos;
  const deLasWebs = WEBS_DEL_CLUB.map((u) => new URL(u).origin);
  return [...new Set([...deLasWebs, "http://localhost:8137", "http://127.0.0.1:8137"])];
}
function cors(origen: string | null): Record<string, string> {
  const permitidos = origenesPermitidos();
  const valor = origen && permitidos.includes(origen) ? origen : permitidos[0];
  return {
    "Access-Control-Allow-Origin": valor,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
    "Vary": "Origin",
  };
}
function responder(cuerpo: unknown, estado: number, origen: string | null): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { ...cors(origen), "Content-Type": "application/json; charset=utf-8" },
  });
}

// ------------------------------------------------------------
// Hablar con la base con la llave de servicio
// ------------------------------------------------------------
async function tabla(ruta: string, opciones: RequestInit = {}): Promise<Response> {
  return await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...opciones,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(opciones.headers ?? {}),
    },
  });
}

/* Quién llama. Se saca del token de la sesión preguntándole a Supabase,
   no del cuerpo de la petición: si viniera en el cuerpo, cualquiera
   podría escribir en el Strava de otro poniendo su identificador. */
async function quienLlama(req: Request): Promise<{ perfilId: string; email: string } | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) return null;
  const r = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: SERVICE_KEY, Authorization: auth },
  });
  if (!r.ok) return null;
  const u = await r.json();
  const email = String(u?.email ?? "").toLowerCase();
  if (!email) return null;
  const p = await tabla(`perfiles?select=id&email=eq.${encodeURIComponent(email)}&limit=1`);
  const filas = p.ok ? await p.json() : [];
  if (!filas.length) return null;
  return { perfilId: filas[0].id, email };
}

// ------------------------------------------------------------
// Las llaves: guardarlas y renovarlas
// ------------------------------------------------------------
type Cuenta = {
  perfil_id: string;
  access_token: string;
  refresh_token: string;
  expira_en: string;
  scope: string | null;
};

async function cuentaDe(perfilId: string): Promise<Cuenta | null> {
  const r = await tabla(`strava_cuentas?perfil_id=eq.${perfilId}&limit=1`);
  if (!r.ok) return null;
  const filas = await r.json();
  return filas.length ? filas[0] : null;
}

/* Strava da los tokens para seis horas. Se renueva con UN MINUTO DE
   MARGEN y no justo al caducar: entre que se comprueba y se usa pasa
   tiempo, y un token que caduca a medio camino da un 401 que parece
   otra cosa. */
async function tokenBueno(c: Cuenta): Promise<string> {
  const quedan = new Date(c.expira_en).getTime() - Date.now();
  if (quedan > 60_000) return c.access_token;

  const r = await fetch("https://www.strava.com/oauth/token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      grant_type: "refresh_token",
      refresh_token: c.refresh_token,
    }),
  });
  if (!r.ok) throw new Error(`renovar: ${r.status} ${await r.text()}`);
  const t = await r.json();
  /* ⚠️ EL `refresh_token` PUEDE CAMBIAR AL RENOVAR, y si no se guarda el
     nuevo, la siguiente renovación falla y hay que volver a conectar a
     mano. Se guardan los dos siempre. */
  await tabla(`strava_cuentas?perfil_id=eq.${c.perfil_id}`, {
    method: "PATCH",
    body: JSON.stringify({
      access_token: t.access_token,
      refresh_token: t.refresh_token ?? c.refresh_token,
      expira_en: new Date(t.expires_at * 1000).toISOString(),
    }),
  });
  return t.access_token;
}

// ------------------------------------------------------------
// Lo que se le escribe a la actividad
// ------------------------------------------------------------
// La descripción la manda el portal ya montada: es él quien sabe cómo
// se lee una serie de este club, y ese texto ya está escrito y probado
// (`assets/js/descansos.js`). Aquí solo se recorta y se firma.
//
// Strava corta las descripciones largas, así que se limita. Y la firma
// del final no es vanidad: dentro de dos meses, viendo la actividad,
// hay que poder saber de dónde salió ese texto.
const TOPE_DESCRIPCION = 4000;
function montarDescripcion(texto: string): string {
  const firma = "\n\n— Apolana";
  const t = String(texto || "").trim();
  if (!t) return firma.trim();
  const sitio = TOPE_DESCRIPCION - firma.length;
  return (t.length > sitio ? t.slice(0, sitio - 1) + "…" : t) + firma;
}

/* La actividad de ese día. Se pide la ventana del día en HORA LOCAL
   convertida a segundos: `after`/`before` van en tiempo Unix.

   ⚠️ SE COGE LA MÁS LARGA DEL DÍA, no la primera. Quien entrena por la
   mañana y sale a andar por la tarde tiene dos actividades ese día, y
   la que corresponde al entrenamiento del club es la de verdad, no el
   paseo de veinte minutos. No es infalible —por eso el portal enseña
   cuál ha elegido antes de escribir nada—. */
async function actividadDelDia(token: string, dia: string): Promise<Record<string, unknown> | null> {
  const desde = Math.floor(new Date(`${dia}T00:00:00Z`).getTime() / 1000) - 12 * 3600;
  const hasta = desde + 24 * 3600 + 24 * 3600;
  const r = await fetch(
    `https://www.strava.com/api/v3/athlete/activities?after=${desde}&before=${hasta}&per_page=30`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (!r.ok) throw new Error(`actividades: ${r.status} ${await r.text()}`);
  const lista = await r.json();
  if (!Array.isArray(lista)) return null;
  // Del día que se pide, en la hora local que dice la propia actividad.
  const delDia = lista.filter((a) => String(a?.start_date_local ?? "").slice(0, 10) === dia);
  if (!delDia.length) return null;
  delDia.sort((a, b) => Number(b?.elapsed_time ?? 0) - Number(a?.elapsed_time ?? 0));
  return delDia[0];
}

function resumenActividad(a: Record<string, unknown>): Record<string, unknown> {
  return {
    id: a.id,
    nombre: a.name,
    tipo: a.sport_type ?? a.type,
    cuando: a.start_date_local,
    metros: a.distance,
    segundos: a.elapsed_time,
  };
}

// ============================================================
// LA PUERTA
// ============================================================
Deno.serve(async (req) => {
  const origen = req.headers.get("Origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });

  const url = new URL(req.url);
  /* La acción puede venir por la dirección o dentro del cuerpo. Las dos
     hacen falta: el portal llama con `functions.invoke`, que manda un
     POST con cuerpo y no deja poner cosas en la dirección; y `volver`
     lo trae el navegador desde Strava, donde solo hay dirección. */
  let cuerpo: Record<string, unknown> = {};
  if (req.method === "POST") cuerpo = await req.json().catch(() => ({})) as Record<string, unknown>;
  const accion = String(cuerpo?.accion ?? url.searchParams.get("accion") ?? "");

  if (!CLIENT_ID || !CLIENT_SECRET) {
    return responder(
      { error: "sin_configurar", mensaje: "Falta la aplicación de Strava. Lo tiene que poner administración." },
      503, origen,
    );
  }

  // --------------------------------------------------------
  // VOLVER · Strava trae el código. Es lo único que no viene
  // del portal, así que ni lleva sesión ni puede llevarla.
  // --------------------------------------------------------
  if (accion === "volver") {
    const destino = (bien: string, extra = "") =>
      Response.redirect(`${URL_BASE}portal/perfil/?strava=${bien}${extra}`, 302);

    const error = url.searchParams.get("error");
    if (error) return destino("no", "");           // le dio a «Cancelar» en Strava

    const code = url.searchParams.get("code") ?? "";
    const state = url.searchParams.get("state") ?? "";
    const scope = url.searchParams.get("scope") ?? "";
    if (!code || !state) return destino("mal");

    /* El `state` es el identificador del perfil, y NO basta con
       creérselo: si lo hiciera, cualquiera podría llamar a esta
       dirección con el identificador de otro y engancharle una cuenta
       de Strava. Se comprueba que ese perfil existe y que el código lo
       acepta Strava; el código es de un solo uso y caduca. */
    const p = await tabla(`perfiles?select=id&id=eq.${encodeURIComponent(state)}&limit=1`);
    const filas = p.ok ? await p.json() : [];
    if (!filas.length) return destino("mal");

    const r = await fetch("https://www.strava.com/oauth/token", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        code,
        grant_type: "authorization_code",
      }),
    });
    if (!r.ok) return destino("mal");
    const t = await r.json();

    /* Si no concedió los dos permisos, se dice AHORA y no cuando falle
       el primer envío con un 401 que no explica nada. */
    if (!scope.includes("activity:write") || !scope.includes("activity:read")) {
      return destino("faltan-permisos");
    }

    await tabla("strava_cuentas?on_conflict=perfil_id", {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates" },
      body: JSON.stringify({
        perfil_id: filas[0].id,
        strava_id: t.athlete?.id ?? null,
        access_token: t.access_token,
        refresh_token: t.refresh_token,
        expira_en: new Date(t.expires_at * 1000).toISOString(),
        scope,
        atleta_nombre: [t.athlete?.firstname, t.athlete?.lastname].filter(Boolean).join(" ") || null,
        ultimo_error: null,
      }),
    });
    return destino("si");
  }

  // A partir de aquí hace falta sesión.
  const yo = await quienLlama(req);
  if (!yo) return responder({ error: "sin_sesion", mensaje: "No hemos podido identificarte." }, 401, origen);

  // --------------------------------------------------------
  // CONECTAR · la dirección donde autoriza
  // --------------------------------------------------------
  if (accion === "conectar") {
    const a = new URL("https://www.strava.com/oauth/authorize");
    a.searchParams.set("client_id", CLIENT_ID);
    a.searchParams.set("redirect_uri", urlDeVuelta());
    a.searchParams.set("response_type", "code");
    a.searchParams.set("approval_prompt", "auto");
    a.searchParams.set("scope", SCOPE);
    a.searchParams.set("state", yo.perfilId);
    return responder({ url: a.toString() }, 200, origen);
  }

  const cuenta = await cuentaDe(yo.perfilId);
  if (!cuenta) {
    return responder(
      { error: "sin_conectar", mensaje: "Todavía no has conectado tu Strava." },
      409, origen,
    );
  }

  const dia = String(cuerpo?.dia ?? url.searchParams.get("dia") ?? "");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dia)) {
    return responder({ error: "sin_dia", mensaje: "Falta el día del entrenamiento." }, 400, origen);
  }

  let token: string;
  try {
    token = await tokenBueno(cuenta);
  } catch (e) {
    await tabla(`strava_cuentas?perfil_id=eq.${yo.perfilId}`, {
      method: "PATCH",
      body: JSON.stringify({ ultimo_error: String(e).slice(0, 300) }),
    });
    return responder(
      { error: "caducado", mensaje: "Tu permiso de Strava ha caducado. Vuelve a conectarlo desde tu perfil." },
      409, origen,
    );
  }

  // --------------------------------------------------------
  // PROBAR · qué actividad se encontraría, sin tocar nada
  // --------------------------------------------------------
  // Existe para que el portal pueda ENSEÑAR cuál va a enriquecer antes
  // de escribir. Escribir encima del título de una actividad sin que
  // la persona sepa cuál es, es la clase de cosa que solo se descubre
  // cuando ya te ha pisado la buena.
  if (accion === "probar") {
    try {
      const a = await actividadDelDia(token, dia);
      return responder(a ? { hay: true, actividad: resumenActividad(a) } : { hay: false }, 200, origen);
    } catch (e) {
      return responder({ error: "strava", mensaje: String(e).slice(0, 200) }, 502, origen);
    }
  }

  // --------------------------------------------------------
  // ENVIAR · el enriquecido
  // --------------------------------------------------------
  if (accion === "enviar") {
    const titulo = String(cuerpo?.titulo ?? "").trim();
    const texto = String(cuerpo?.descripcion ?? "");
    let act: Record<string, unknown> | null;
    try {
      act = await actividadDelDia(token, dia);
    } catch (e) {
      return responder({ error: "strava", mensaje: String(e).slice(0, 200) }, 502, origen);
    }
    /* Que el reloj todavía no haya subido nada NO es un error: es lo
       normal si acabas de terminar. Se contesta con calma y el portal
       deja el botón para volver a intentarlo. */
    if (!act) {
      return responder(
        {
          error: "sin_actividad",
          mensaje: "Todavía no hay ninguna actividad de ese día en tu Strava. Suele tardar un poco desde que el reloj sincroniza; prueba en un rato.",
        },
        404, origen,
      );
    }

    const cambios: Record<string, unknown> = { description: montarDescripcion(texto) };
    if (titulo) cambios.name = titulo;

    const r = await fetch(`https://www.strava.com/api/v3/activities/${act.id}`, {
      method: "PUT",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify(cambios),
    });
    if (!r.ok) {
      const detalle = `${r.status} ${(await r.text()).slice(0, 200)}`;
      await tabla(`strava_cuentas?perfil_id=eq.${yo.perfilId}`, {
        method: "PATCH",
        body: JSON.stringify({ ultimo_error: detalle }),
      });
      return responder({ error: "strava", mensaje: "Strava no lo ha aceptado: " + detalle }, 502, origen);
    }

    await tabla(`strava_cuentas?perfil_id=eq.${yo.perfilId}`, {
      method: "PATCH",
      body: JSON.stringify({ ultimo_envio: new Date().toISOString(), ultimo_error: null }),
    });
    return responder({ ok: true, actividad: resumenActividad(act) }, 200, origen);
  }

  return responder({ error: "no_se_que_quieres" }, 400, origen);
});

// ============================================================
// LO QUE ESTA FUNCIÓN NO HACE
// ------------------------------------------------------------
//   · No crea actividades. Ver el aviso de arriba: el reloj ya sube la
//     suya y dos actividades el mismo día no se aguantan.
//   · No borra ni sube archivos. Los permisos que pide no lo permiten.
//   · No reintenta sola. No hay tareas programadas en este proyecto
//     (`pg_cron` no está instalado), así que si la actividad todavía no
//     ha llegado se dice y queda el botón. Preferible a un reintento
//     silencioso que nadie sabe si ocurrió.
//   · No toca el Strava de nadie más: `state` es el perfil de quien
//     pidió conectar, y todo lo demás sale de la sesión, nunca del
//     cuerpo de la petición.
// ============================================================
