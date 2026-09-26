// ============================================================
// calendario-google · lee un Google Calendar (iCal público) y devuelve
// los próximos eventos ya limpios, para pintarlos con el diseño de la web.
// ------------------------------------------------------------
// QUÉ HACE
//   El club tiene un Google Calendar con competiciones/eventos. Aquí se
//   lee su «dirección pública en formato iCal» (una URL .ics), se parsea
//   y se devuelven los eventos FUTUROS ordenados. La web los pinta con su
//   estilo (no se ve la interfaz de Google). Es SOLO LECTURA.
//
// CONFIGURACIÓN (variable de entorno de Supabase; la pone Andrés):
//   GOOGLE_CAL_ICS_URL   la dirección .ics pública del calendario.
//   (Opcional) se puede pasar ?url=<ics> para probar otro calendario.
//
//   supabase functions deploy calendario-google --no-verify-jwt
// ============================================================

const ICS_URL = (Deno.env.get("GOOGLE_CAL_ICS_URL") ?? "").trim();

function cors(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Cache-Control": "public, max-age=600", // 10 min: no machacamos a Google
  };
}
function responder(cuerpo: unknown, estado: number): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { ...cors(), "Content-Type": "application/json; charset=utf-8" },
  });
}

// Desdobla las líneas plegadas del iCal (RFC 5545: continúa la anterior si
// empieza por espacio o tab).
function desdoblar(texto: string): string[] {
  const brutas = texto.replace(/\r\n/g, "\n").split("\n");
  const salida: string[] = [];
  for (const l of brutas) {
    if ((l.startsWith(" ") || l.startsWith("\t")) && salida.length) {
      salida[salida.length - 1] += l.slice(1);
    } else {
      salida.push(l);
    }
  }
  return salida;
}

// Escapes de texto iCal (\, ; , \n).
function limpiarTexto(v: string): string {
  return v.replace(/\\n/gi, "\n").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\").trim();
}

// Convierte un valor de fecha iCal a ISO. Soporta:
//   DATE:            20260315                 (día completo)
//   DATE-TIME UTC:   20260315T090000Z
//   DATE-TIME local: 20260315T090000  (con o sin TZID; se trata como local)
function aISO(valor: string, params: Record<string, string>): { iso: string; diaCompleto: boolean } | null {
  const v = valor.trim();
  const soloFecha = /^(\d{4})(\d{2})(\d{2})$/;
  const conHora = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$/;
  let m = v.match(soloFecha);
  if (m || params["VALUE"] === "DATE") {
    m = m ?? v.match(/^(\d{4})(\d{2})(\d{2})/);
    if (!m) return null;
    return { iso: `${m[1]}-${m[2]}-${m[3]}`, diaCompleto: true };
  }
  m = v.match(conHora);
  if (m) {
    const base = `${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}`;
    // Con Z es UTC; sin Z lo dejamos como hora local (Google ya suele mandar el TZID).
    return { iso: m[7] ? `${base}Z` : base, diaCompleto: false };
  }
  return null;
}

interface Evento {
  titulo: string; inicio: string; fin: string | null;
  lugar: string; descripcion: string; dia_completo: boolean; url: string;
}

function parsear(ics: string): Evento[] {
  const lineas = desdoblar(ics);
  const eventos: Evento[] = [];
  let dentro = false;
  let ev: Record<string, unknown> = {};
  for (const linea of lineas) {
    if (linea === "BEGIN:VEVENT") { dentro = true; ev = {}; continue; }
    if (linea === "END:VEVENT") {
      dentro = false;
      const ini = ev.inicio as { iso: string; diaCompleto: boolean } | undefined;
      if (ini) {
        const descHtml = (ev.descripcion as string) || "";
        // El enlace de la carrera suele venir DENTRO de la descripción como
        // <a href="...">, no en la propiedad URL. Se saca de ahí si hace falta.
        let url = (ev.url as string) || "";
        if (!url) {
          const m = descHtml.match(/href=["']?(https?:\/\/[^"'>\s]+)/i) ||
                    descHtml.match(/(https?:\/\/[^\s"'<>]+)/i);
          if (m) url = m[1];
        }
        // Descripción para mostrar: sin etiquetas HTML.
        const descTexto = descHtml.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
        eventos.push({
          titulo: (ev.titulo as string) || "(sin título)",
          inicio: ini.iso,
          fin: (ev.fin as { iso: string } | undefined)?.iso ?? null,
          lugar: (ev.lugar as string) || "",
          descripcion: descTexto,
          dia_completo: ini.diaCompleto,
          url,
        });
      }
      continue;
    }
    if (!dentro) continue;
    const idx = linea.indexOf(":");
    if (idx < 0) continue;
    const izq = linea.slice(0, idx);
    const valor = linea.slice(idx + 1);
    const partes = izq.split(";");
    const nombre = partes[0].toUpperCase();
    const params: Record<string, string> = {};
    for (let i = 1; i < partes.length; i++) {
      const [k, v2] = partes[i].split("=");
      if (k) params[k.toUpperCase()] = v2 ?? "";
    }
    if (nombre === "SUMMARY") ev.titulo = limpiarTexto(valor);
    else if (nombre === "LOCATION") ev.lugar = limpiarTexto(valor);
    else if (nombre === "DESCRIPTION") ev.descripcion = limpiarTexto(valor);
    else if (nombre === "URL") ev.url = valor.trim();
    else if (nombre === "DTSTART") ev.inicio = aISO(valor, params);
    else if (nombre === "DTEND") ev.fin = aISO(valor, params);
  }
  return eventos;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors() });
  if (req.method !== "GET" && req.method !== "POST") return responder({ error: "Método no admitido." }, 405);

  // SSRF: se IGNORA cualquier ?url= del cliente. Solo se lee el calendario
  // configurado (GOOGLE_CAL_ICS_URL); antes esta función era un proxy abierto y
  // un oráculo de red (devolvía el status/el error de conexión de la URL pedida).
  const url = ICS_URL;
  if (!url) return responder({ error: "sin_configurar", mensaje: "Falta la dirección del calendario (GOOGLE_CAL_ICS_URL)." }, 200);

  let ics = "";
  try {
    const r = await fetch(url, { headers: { "User-Agent": "Apolana-web" } });
    if (!r.ok) return responder({ error: "google", mensaje: "No hemos podido leer el calendario." }, 200);
    ics = await r.text();
  } catch (e) {
    console.error("[calendario-google]", String(e));
    return responder({ error: "conexion", mensaje: "No hemos podido conectar con Google." }, 200);
  }

  const todos = parsear(ics);
  // Solo futuros (desde ayer, por si un evento de hoy ya empezó) y ordenados.
  const desde = Date.now() - 24 * 60 * 60 * 1000;
  const proximos = todos
    .filter((e) => {
      const t = Date.parse(e.dia_completo ? e.inicio + "T23:59:59" : e.inicio);
      return Number.isFinite(t) && t >= desde;
    })
    .sort((a, b) => Date.parse(a.inicio) - Date.parse(b.inicio));

  return new Response(JSON.stringify({ eventos: proximos, total: proximos.length }), {
    status: 200,
    headers: { ...cors(), "Content-Type": "application/json; charset=utf-8" },
  });
});
