// ============================================================
// aviso-enviar · manda un aviso a los móviles del club
// ------------------------------------------------------------
// QUÉ HACE, EN CRISTIANO
//   Alguien del club escribe «Mañana no hay entreno» en el panel y
//   pulsa enviar. Esta función mira a quién le toca, respeta lo que
//   cada uno haya elegido recibir, cifra el aviso para cada móvil y
//   se lo entrega a Google (Android y Chrome) o a Apple (iPhone con
//   la app instalada), que son quienes lo hacen sonar.
//
// LOS TRES NIVELES (maqueta «4 · Avisos y pagos», apartado A)
//   informativo · importante · grave. El nivel decide el color y la
//   palabra de la pantalla, y aquí decide dos cosas más:
//     · «grave» va siempre a todo el club (se pueden QUITAR grupos) y
//       siempre suena en el móvil, sin que haya que marcarlo.
//     · quien escribe elige, aviso a aviso, si además suena en el
//       móvil. Un aviso que no suena no se pierde: queda en la app.
//
// LO QUE NO SE FÍA DEL NAVEGADOR
//   · Quién eres. Se comprueba el JWT contra Supabase y después se
//     pregunta a la base si esa persona puede mandar avisos
//     (`avisos_puede_enviar()`: administración o tesorería, y con ese
//     papel puesto). No se cree el correo que venga en el cuerpo.
//   · A quién va. La lista de destinatarios la calcula la BASE, con
//     las preferencias ya aplicadas. Aquí no llega ni un endpoint
//     que el navegador haya podido elegir.
//   · A dónde lleva el aviso. El enlace tiene que ser de la propia
//     web del club: si no, se tira. Un aviso del club que lleva a
//     una web de fuera es la puerta de entrada de una estafa.
//
// CLAVES · ninguna está en este archivo ni puede estarlo
//   VAPID_PUBLIC_KEY   · la pública  (la pone el club en Supabase)
//   VAPID_PRIVATE_KEY  · la PRIVADA  (la pone el club en Supabase)
//   VAPID_SUBJECT      · «mailto:escuelaapolana@gmail.com»
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / SUPABASE_ANON_KEY
//                      · las pone Supabase sola
//   Opcionales: AVISOS_URL_BASE (la web del club), AVISOS_ORIGENES.
//
// Si falta cualquier clave, la función contesta «todavía no está
// activado» con buenos modales. No revienta ni deja botones muertos.
//
// Cómo se despliega:  supabase functions deploy aviso-enviar
// ============================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ?? "";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ?? "";

// Se normaliza el formato: hay páginas que dan las claves con «+», «/»
// o «=» al final, y así valen igual sin que nadie tenga que darse cuenta.
const VAPID_PUBLICA = (Deno.env.get("VAPID_PUBLIC_KEY") ?? "").trim()
  .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const VAPID_PRIVADA = (Deno.env.get("VAPID_PRIVATE_KEY") ?? "").trim();
const VAPID_CONTACTO = (Deno.env.get("VAPID_SUBJECT") ?? "mailto:escuelaapolana@gmail.com").trim();

const URL_BASE = (Deno.env.get("AVISOS_URL_BASE") ?? "https://escuelaapolana.github.io/WebV2/")
  .replace(/\/*$/, "/");

const CATEGORIAS = ["entrenos", "competiciones", "pagos", "noticias", "retos"];
const PUBLICOS = ["todos", "grupo", "rol", "persona"];
const ROLES = ["admin", "coordinador", "entrenador", "atleta", "padre"];
const NIVELES = ["informativo", "importante", "grave"];

// ------------------------------------------------------------
// Cabeceras para que el navegador pueda llamarnos
// ------------------------------------------------------------
function cors(origen: string | null): Record<string, string> {
  const permitidos = (Deno.env.get("AVISOS_ORIGENES") ?? Deno.env.get("PAGOS_ORIGENES") ?? "")
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
    status: estado,
    headers: { ...cors(origen), "Content-Type": "application/json; charset=utf-8" },
  });
}

// ------------------------------------------------------------
// Hablar con la base con la llave de servicio
// ------------------------------------------------------------
type Opciones = Omit<RequestInit, "headers"> & { headers?: Record<string, string> };

async function consulta(ruta: string, opciones: Opciones = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${ruta}`, {
    ...opciones,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(opciones.headers ?? {}),
    },
  });
  const texto = await r.text();
  let datos: unknown = null;
  try { datos = texto ? JSON.parse(texto) : null; } catch { datos = texto; }
  return { ok: r.ok, estado: r.status, datos };
}

// ============================================================
// EL CIFRADO DEL AVISO (Web Push)
// ------------------------------------------------------------
// Se hace a mano con la criptografía que ya trae el propio Deno, sin
// añadir ninguna librería: son cuarenta líneas y así no hay una
// dependencia más que mantener al día. Es el estándar de siempre
// (RFC 8291 y RFC 8188, «aes128gcm»).
//
// La idea, en una frase: el aviso se cifra con una clave que solo
// puede calcular ESE móvil. Ni Google ni Apple ven lo que pone: para
// ellos es un churro de bytes que reparten y ya está.
// ============================================================

function b64urlABytes(s: string): Uint8Array {
  const relleno = "=".repeat((4 - (s.length % 4)) % 4);
  const limpia = (s + relleno).replace(/-/g, "+").replace(/_/g, "/");
  const crudo = atob(limpia);
  const bytes = new Uint8Array(crudo.length);
  for (let i = 0; i < crudo.length; i++) bytes[i] = crudo.charCodeAt(i);
  return bytes;
}

function bytesAB64url(b: ArrayBuffer | Uint8Array): string {
  const bytes = b instanceof Uint8Array ? b : new Uint8Array(b);
  let s = "";
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function unir(...trozos: Uint8Array[]): Uint8Array {
  const total = trozos.reduce((n, t) => n + t.length, 0);
  const salida = new Uint8Array(total);
  let i = 0;
  for (const t of trozos) { salida.set(t, i); i += t.length; }
  return salida;
}

const texto = new TextEncoder();

/** HKDF: de un secreto compartido saca una clave del largo que haga falta. */
async function derivar(ikm: Uint8Array, salt: Uint8Array, info: Uint8Array, bytes: number) {
  const clave = await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "HKDF", hash: "SHA-256", salt, info }, clave, bytes * 8,
  );
  return new Uint8Array(bits);
}

/** El cuerpo cifrado del aviso, tal y como lo espera el móvil. */
async function cifrar(carga: string, p256dh: string, auth: string): Promise<Uint8Array> {
  const claveMovil = b64urlABytes(p256dh);      // 65 bytes
  const secretoMovil = b64urlABytes(auth);      // 16 bytes

  // Un par de claves de usar y tirar, distintas en cada envío.
  const efimeras = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"],
  ) as CryptoKeyPair;
  const publicaServidor = new Uint8Array(await crypto.subtle.exportKey("raw", efimeras.publicKey));

  const publicaMovil = await crypto.subtle.importKey(
    "raw", claveMovil, { name: "ECDH", namedCurve: "P-256" }, false, [],
  );
  const compartido = new Uint8Array(await crypto.subtle.deriveBits(
    { name: "ECDH", public: publicaMovil }, efimeras.privateKey, 256,
  ));

  // Paso 1 · mezclar el secreto compartido con el del móvil
  const infoClave = unir(texto.encode("WebPush: info"), new Uint8Array([0]), claveMovil, publicaServidor);
  const ikm = await derivar(compartido, secretoMovil, infoClave, 32);

  // Paso 2 · de ahí salen la clave de cifrado y el número de un solo uso
  const sal = crypto.getRandomValues(new Uint8Array(16));
  const cek = await derivar(ikm, sal, unir(texto.encode("Content-Encoding: aes128gcm"), new Uint8Array([0])), 16);
  const nonce = await derivar(ikm, sal, unir(texto.encode("Content-Encoding: nonce"), new Uint8Array([0])), 12);

  // Paso 3 · cifrar (el 0x02 del final marca que no hay más trozos)
  const claveAes = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["encrypt"]);
  const claro = unir(texto.encode(carga), new Uint8Array([2]));
  const cifrado = new Uint8Array(await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: nonce, tagLength: 128 }, claveAes, claro,
  ));

  // Paso 4 · la cabecera que dice cómo desenvolverlo
  const tamano = new Uint8Array(4);
  new DataView(tamano.buffer).setUint32(0, 4096, false);
  return unir(sal, tamano, new Uint8Array([publicaServidor.length]), publicaServidor, cifrado);
}

/** La firma que demuestra que el aviso lo manda el club y no un tercero. */
const jwtCache = new Map<string, { valor: string; caduca: number }>();

async function firmaVapid(endpoint: string): Promise<string> {
  const destino = new URL(endpoint).origin;
  const ahora = Math.floor(Date.now() / 1000);

  const guardada = jwtCache.get(destino);
  if (guardada && guardada.caduca > ahora + 300) return guardada.valor;

  const publica = b64urlABytes(VAPID_PUBLICA);           // 65 bytes: 0x04 || x || y
  const jwk: JsonWebKey = {
    kty: "EC",
    crv: "P-256",
    // Algunas páginas dan la clave con «+», «/» o «=» al final. Se
    // normaliza, que si no la criptografía la rechaza sin explicar nada.
    d: VAPID_PRIVADA.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, ""),
    x: bytesAB64url(publica.slice(1, 33)),
    y: bytesAB64url(publica.slice(33, 65)),
    ext: true,
  };
  const clave = await crypto.subtle.importKey(
    "jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );

  const caduca = ahora + 12 * 3600;
  const cabecera = bytesAB64url(texto.encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const cuerpo = bytesAB64url(texto.encode(JSON.stringify({
    aud: destino, exp: caduca, sub: VAPID_CONTACTO,
  })));
  const sinFirma = `${cabecera}.${cuerpo}`;
  const firma = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, clave, texto.encode(sinFirma),
  );
  const jwt = `${sinFirma}.${bytesAB64url(firma)}`;
  jwtCache.set(destino, { valor: jwt, caduca });
  return jwt;
}

type Destino = { id: string; endpoint: string; p256dh: string; auth: string };

/** Manda el aviso a UN aparato. Devuelve qué ha pasado. */
async function mandarA(d: Destino, carga: string): Promise<"ok" | "muerto" | "fallo"> {
  try {
    const cuerpo = await cifrar(carga, d.p256dh, d.auth);
    const jwt = await firmaVapid(d.endpoint);

    const r = await fetch(d.endpoint, {
      method: "POST",
      headers: {
        "Authorization": `vapid t=${jwt}, k=${VAPID_PUBLICA}`,
        "Content-Encoding": "aes128gcm",
        "Content-Type": "application/octet-stream",
        // Cuánto tiempo lo guarda Google/Apple si el móvil está
        // apagado. Cuatro horas: un aviso de «hoy no hay entreno»
        // que llega mañana no vale para nada.
        "TTL": "14400",
        "Urgency": "high",
      },
      body: cuerpo,
    });

    if (r.status === 201 || r.status === 200 || r.status === 202) {
      await r.body?.cancel();                  // sin esto la conexión se queda colgada
      return "ok";
    }
    // 404 y 410: la app se desinstaló o se borraron los datos del
    // navegador. Ese buzón ya no existe y hay que quitarlo.
    if (r.status === 404 || r.status === 410) {
      await r.body?.cancel();
      return "muerto";
    }
    console.error("aviso rechazado", r.status, (await r.text()).slice(0, 200));
    return "fallo";
  } catch (e) {
    console.error("aviso no enviado:", e instanceof Error ? e.message : e);
    return "fallo";
  }
}

// ------------------------------------------------------------
// El enlace tiene que ser de la web del club. Punto.
// ------------------------------------------------------------
function enlaceSeguro(v: unknown): string | null {
  const s = String(v ?? "").trim();
  if (!s) return null;
  try {
    const u = new URL(s, URL_BASE);
    // Ni «javascript:» ni «data:» ni nada raro.
    if (u.protocol !== "https:" && u.protocol !== "http:") return null;

    const base = new URL(URL_BASE);
    if (u.origin === base.origin) return u.toString();

    // Viene de otro sitio: se queda SOLO el camino y se pega a la web
    // del club. Así el aviso nunca puede llevar fuera, ni por un
    // despiste al copiar una dirección ni a propósito.
    const camino = u.pathname.replace(/^\/+/, "") + u.search + u.hash;
    return new URL(camino, URL_BASE).toString();
  } catch { return null; }
}

function recortar(v: unknown, tope: number): string {
  return String(v ?? "").replace(/\s+/g, " ").trim().slice(0, tope);
}

/** Una fecha «2026-09-30» y nada más. Cualquier otra cosa, nada. */
function fechaSuelta(v: unknown): string | null {
  const s = String(v ?? "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const d = new Date(s + "T00:00:00Z");
  return isNaN(d.getTime()) ? null : s;
}

/** Los grupos que se han quitado. Solo identificadores de verdad. */
function uuidsSueltos(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  const bueno = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return [...new Set(v.map((x) => String(x ?? "").trim()).filter((x) => bueno.test(x)))].slice(0, 60);
}

// ============================================================
Deno.serve(async (req: Request): Promise<Response> => {
  const origen = req.headers.get("origin");

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origen) });
  if (req.method !== "POST") return responder({ error: "Método no admitido." }, 405, origen);

  // ---------------------------------------------------------------
  // 0 · ¿Está todo montado? Si falta una clave, se dice sin dramas.
  // ---------------------------------------------------------------
  if (!SUPABASE_URL || !SERVICE_KEY) {
    return responder({ error: "config", mensaje: "Los avisos no están configurados." }, 503, origen);
  }
  if (!VAPID_PUBLICA || !VAPID_PRIVADA) {
    return responder({
      error: "no_activado",
      mensaje: "Los avisos al móvil todavía no están activados. Faltan las claves en Supabase.",
    }, 503, origen);
  }

  // ---------------------------------------------------------------
  // 1 · ¿Quién eres? El JWT se comprueba de verdad, contra Supabase.
  // ---------------------------------------------------------------
  const cabecera = req.headers.get("Authorization") ?? "";
  const jwt = cabecera.toLowerCase().startsWith("bearer ") ? cabecera.slice(7).trim() : "";
  if (!jwt) return responder({ error: "sin_sesion", mensaje: "Entra en tu cuenta." }, 401, origen);

  const rUsuario = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: ANON_KEY || SERVICE_KEY, Authorization: `Bearer ${jwt}` },
  });
  if (!rUsuario.ok) {
    return responder({ error: "sin_sesion", mensaje: "Tu sesión ha caducado. Vuelve a entrar." }, 401, origen);
  }
  const usuario = await rUsuario.json();
  const correo: string = (usuario?.email ?? "").toLowerCase();
  if (!correo) return responder({ error: "sin_sesion", mensaje: "No hemos podido identificarte." }, 401, origen);

  // 1.b · ¿Puede mandar avisos? Se lo preguntamos a la BASE con SU
  //       sesión, no con la llave de servicio: así manda la misma
  //       regla que en todas las pantallas. Mandar avisos es de
  //       administración y tesorería; los entrenadores no mandan.
  //       Esconder el botón en el panel es cortesía; la barrera es
  //       esta y la de `avisos_alcance`, que están en la base.
  const rPuede = await fetch(`${SUPABASE_URL}/rest/v1/rpc/avisos_puede_enviar`, {
    method: "POST",
    headers: {
      apikey: ANON_KEY || SERVICE_KEY,
      Authorization: `Bearer ${jwt}`,
      "Content-Type": "application/json",
    },
    body: "{}",
  });
  const puedeEnviar = rPuede.ok && (await rPuede.json()) === true;
  if (!puedeEnviar) {
    return responder({
      error: "sin_permiso",
      mensaje: "Los avisos los manda administración o tesorería. Si tienes los dos papeles, cambia al de administración y vuelve a intentarlo.",
    }, 403, origen);
  }

  // ---------------------------------------------------------------
  // 2 · ¿Está encendido el sistema?
  // ---------------------------------------------------------------
  const rCfg = await consulta("avisos_config?select=activo&id=eq.1&limit=1");
  const cfg = Array.isArray(rCfg.datos) ? rCfg.datos[0] : null;
  if (!cfg?.activo) {
    return responder({
      error: "no_activado",
      mensaje: "Los avisos están apagados. Se encienden desde el panel cuando estén puestas las claves.",
    }, 503, origen);
  }

  // ---------------------------------------------------------------
  // 3 · Qué se quiere mandar
  // ---------------------------------------------------------------
  let cuerpo: Record<string, unknown> = {};
  try { cuerpo = await req.json(); } catch { /* cuerpo vacío */ }

  const titulo = recortar(cuerpo.titulo, 80);
  const mensaje = recortar(cuerpo.cuerpo ?? cuerpo.texto, 200);
  const enlacePedido = enlaceSeguro(cuerpo.url);
  const categoria = String(cuerpo.categoria ?? "entrenos");
  const soloPrueba = cuerpo.prueba === true;

  const nivel = String(cuerpo.nivel ?? "informativo").toLowerCase().trim();
  const caduca = fechaSuelta(cuerpo.caduca_el);
  const esGrave = nivel === "grave";

  // Un aviso grave se reparte AL REVÉS: va a todo el club y se quitan
  // los grupos a los que no aplica. Aquí se impone, no se pide: si el
  // navegador dijera otra cosa, un aviso de seguridad podría acabar
  // yendo a un solo grupo por un descuido.
  const publico = esGrave ? "todos" : String(cuerpo.publico ?? "todos");
  const grupoId = esGrave ? null : (cuerpo.grupo_id ? String(cuerpo.grupo_id) : null);
  const rol = esGrave ? null : (cuerpo.rol ? String(cuerpo.rol) : null);
  const perfilId = esGrave ? null : (cuerpo.perfil_id ? String(cuerpo.perfil_id) : null);
  const excluir = esGrave ? uuidsSueltos(cuerpo.grupos_excluidos) : [];

  // Suena en el móvil si quien escribe lo ha marcado. En los graves no
  // se pregunta: un aviso de seguridad que no suena no sirve de nada.
  // Si no viene el dato —una pantalla vieja sin desplegar— se manda,
  // que es lo que se hacía siempre: nunca se deja de avisar por un
  // campo que falta.
  const alMovil = esGrave ? true : cuerpo.al_movil !== false;

  if (!titulo) return responder({ error: "falta_titulo", mensaje: "El aviso necesita un título." }, 400, origen);
  if (!mensaje) return responder({ error: "falta_texto", mensaje: "El aviso necesita un texto." }, 400, origen);
  if (!NIVELES.includes(nivel)) {
    return responder({ error: "nivel", mensaje: "Ese nivel de aviso no existe." }, 400, origen);
  }
  // Sin fecha de caducidad no se puede escribir «Ya pasó» y el aviso se
  // queda para siempre como si siguiera en pie. En los informativos no
  // hace falta: una crónica no caduca.
  if ((nivel === "importante" || nivel === "grave") && !caduca) {
    return responder({
      error: "falta_caducidad",
      mensaje: "Dinos hasta qué día vale este aviso. Sin esa fecha se queda para siempre como si siguiera en pie.",
    }, 400, origen);
  }
  if (!PUBLICOS.includes(publico)) {
    return responder({ error: "publico", mensaje: "No sabemos a quién mandarlo." }, 400, origen);
  }
  if (!CATEGORIAS.includes(categoria)) {
    return responder({ error: "categoria", mensaje: "Ese tipo de aviso no existe." }, 400, origen);
  }
  if (publico === "grupo" && !grupoId) {
    return responder({ error: "falta_grupo", mensaje: "Elige el grupo." }, 400, origen);
  }
  if (publico === "rol" && (!rol || !ROLES.includes(rol))) {
    return responder({ error: "falta_rol", mensaje: "Elige a qué papel del club va." }, 400, origen);
  }
  if (publico === "persona" && !perfilId) {
    return responder({ error: "falta_persona", mensaje: "Elige a la persona." }, 400, origen);
  }
  if (cuerpo.url && !enlacePedido) {
    return responder({
      error: "enlace",
      mensaje: "Ese enlace no vale. Un aviso del club solo puede llevar a una página de la web del club.",
    }, 400, origen);
  }

  // ---------------------------------------------------------------
  // 3.b · A DÓNDE LLEVA AL TOCARLO
  //   Si quien escribe ha elegido una pantalla, se respeta. Si no, el
  //   aviso lleva A SÍ MISMO: se abre con su título, su texto entero y
  //   cuándo se mandó. Antes, sin enlace, se abría el portal a secas y
  //   el aviso no estaba en ninguna parte.
  //
  //   El identificador se decide AQUÍ, antes de mandar nada, porque el
  //   enlace viaja dentro del propio aviso. Después se le pasa igual a
  //   `avisos_registrar` (migración 082), así que el historial y el
  //   enlace hablan de la misma fila.
  // ---------------------------------------------------------------
  const idAviso = crypto.randomUUID();
  const enlace = enlacePedido ?? `${URL_BASE}portal/avisos/?id=${idAviso}`;

  // ---------------------------------------------------------------
  // 4 · Quién lo manda (para el historial)
  // ---------------------------------------------------------------
  const rPerfil = await consulta(
    `perfiles?select=id&email=eq.${encodeURIComponent(correo)}&limit=1`,
  );
  const autor = (Array.isArray(rPerfil.datos) ? rPerfil.datos[0] : null)?.id ?? null;

  // ---------------------------------------------------------------
  // 5 · A quién va · LA LISTA LA CALCULA LA BASE
  //     Con las preferencias de cada uno ya aplicadas: quien apagó
  //     «noticias del club» no sale de aquí aunque el aviso vaya a
  //     todo el club. TAMPOCO SI ES GRAVE: nada se salta lo que la
  //     persona ha elegido. Si es algo que no se puede perder nadie,
  //     hay que decirlo también por otra vía.
  // ---------------------------------------------------------------
  let destinos: Destino[] = [];
  if (alMovil) {
    const rDestinos = await consulta("rpc/avisos_destinatarios", {
      method: "POST",
      body: JSON.stringify({
        p_publico: publico,
        p_categoria: categoria,
        p_grupo: grupoId,
        p_rol: rol,
        p_perfil: perfilId,
        p_excluir: excluir,
      }),
    });
    if (!rDestinos.ok) {
      console.error("no se ha podido calcular a quién va:", rDestinos.datos);
      return responder({ error: "interno", mensaje: "No hemos podido calcular a quién va el aviso." }, 500, origen);
    }
    destinos = (Array.isArray(rDestinos.datos) ? rDestinos.datos : []) as Destino[];
  }

  // Modo «solo mirar»: dice a cuántos llegaría sin mandar nada.
  if (soloPrueba) {
    return responder({ ok: true, prueba: true, alcance: destinos.length }, 200, origen);
  }

  // ---------------------------------------------------------------
  // 6 · Cómo se llama a quién va, para el historial
  // ---------------------------------------------------------------
  let publicoTexto = "Todo el club";
  if (publico === "todos" && excluir.length) {
    // «Todo el club menos Montaña y El Cubo». Se escribe entero
    // porque el socio que lo abre tiene derecho a saber a quién más
    // le ha llegado lo que está leyendo.
    const lista = excluir.map((g) => `id.eq.${g}`).join(",");
    const r = await consulta(`grupos?select=nombre&or=(${encodeURIComponent(lista)})`);
    const nombres = (Array.isArray(r.datos) ? r.datos : [])
      .map((g: { nombre?: string }) => g?.nombre).filter(Boolean) as string[];
    if (nombres.length) {
      const ultimo = nombres.pop()!;
      publicoTexto = `Todo el club menos ${nombres.length ? nombres.join(", ") + " y " + ultimo : ultimo}`;
    }
  } else if (publico === "grupo") {
    const r = await consulta(`grupos?select=nombre&id=eq.${encodeURIComponent(grupoId!)}&limit=1`);
    const g = Array.isArray(r.datos) ? r.datos[0] : null;
    publicoTexto = g?.nombre ? `Grupo ${g.nombre}` : "Un grupo";
  } else if (publico === "rol") {
    const nombres: Record<string, string> = {
      admin: "Administración", coordinador: "Coordinadores",
      entrenador: "Entrenadores", atleta: "Atletas", padre: "Familias",
    };
    publicoTexto = nombres[rol!] ?? "Un papel del club";
  } else if (publico === "persona") {
    const r = await consulta(`perfiles?select=nombre,apellidos&id=eq.${encodeURIComponent(perfilId!)}&limit=1`);
    const p = Array.isArray(r.datos) ? r.datos[0] : null;
    publicoTexto = p ? `${p.nombre ?? ""} ${p.apellidos ?? ""}`.trim() : "Una persona";
  }

  // ---------------------------------------------------------------
  // 7 · A repartir · solo si además tiene que sonar en el móvil
  //     Si no, el aviso NO se pierde: se apunta igual en el historial
  //     y aparece en la app la próxima vez que la abran.
  // ---------------------------------------------------------------
  const carga = JSON.stringify({
    titulo,
    cuerpo: mensaje,
    url: enlace,
    categoria,
    nivel,
    etiqueta: `apolana-${categoria}`,
  });

  let enviados = 0, fallidos = 0;
  const muertos: string[] = [];
  const vivos: string[] = [];

  // De veinte en veinte: ni se atasca la función ni se le manda a
  // Google mil peticiones a la vez.
  const TANDA = 20;
  for (let i = 0; i < destinos.length; i += TANDA) {
    const tanda = destinos.slice(i, i + TANDA);
    const resultados = await Promise.all(tanda.map((d) => mandarA(d, carga)));
    resultados.forEach((r, j) => {
      if (r === "ok") { enviados++; vivos.push(tanda[j].id); }
      else if (r === "muerto") { fallidos++; muertos.push(tanda[j].endpoint); }
      else fallidos++;
    });
  }

  // Limpieza: los buzones que ya no existen se quitan, o el número de
  // «fallidos» crecería para siempre.
  for (const endpoint of muertos) {
    await consulta("rpc/avisos_baja_endpoint", {
      method: "POST", body: JSON.stringify({ p_endpoint: endpoint }),
    });
  }
  if (vivos.length) {
    await consulta("rpc/avisos_marcar_uso", {
      method: "POST", body: JSON.stringify({ p_ids: vivos }),
    });
  }

  // ---------------------------------------------------------------
  // 8 · Al historial
  // ---------------------------------------------------------------
  await consulta("rpc/avisos_registrar", {
    method: "POST",
    body: JSON.stringify({
      // El identificador es el mismo que ha viajado en el enlace del
      // aviso: si no, el móvil llevaría a una fila que no existe.
      p_id: idAviso,
      // Se guarda SOLO el enlace que se pidió a mano. Cuando no hay,
      // se deja vacío: el aviso lleva a su propia pantalla y no hace
      // falta apuntar una dirección que ya se sabe.
      p_titulo: titulo, p_cuerpo: mensaje, p_url: enlacePedido,
      p_publico: publico, p_categoria: categoria,
      p_grupo: grupoId, p_rol: rol, p_perfil: perfilId,
      p_texto: publicoTexto,
      p_enviados: enviados, p_fallidos: fallidos,
      p_autor: autor,
      // Lo nuevo: el nivel decide el color Y la palabra de la pantalla,
      // la caducidad permite escribir «Ya pasó» sin tachar a mano, y
      // los grupos quitados hacen que el socio de montaña no vea un
      // aviso de la piscina en su lista.
      p_nivel: nivel,
      p_caduca: caduca,
      p_movil: alMovil,
      p_excluir: excluir,
    }),
  });

  return responder({
    ok: true, enviados, fallidos, alcance: destinos.length, nivel, al_movil: alMovil,
  }, 200, origen);
});
