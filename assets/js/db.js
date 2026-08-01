/* ============================================================
   CONEXIÓN A SUPABASE · base de datos del club
   ------------------------------------------------------------
   La clave "publishable" es PÚBLICA por diseño: va en el navegador
   y no es secreta. La seguridad de verdad la dan las reglas RLS
   configuradas en Supabase (qué puede leer/escribir cada quién).
   Requiere que la librería supabase-js se haya cargado antes.
   ============================================================ */
(function () {
  var URL = "https://icaxokjsvhlreuwpyxeb.supabase.co";
  var KEY = "sb_publishable_ABwJ5L9azzN30mqKg6igxA_zq6pB3MH";

  if (!window.supabase || !window.supabase.createClient) {
    console.warn("[Apolana] supabase-js no está cargado; la web usará los datos de ejemplo.");
    return;
  }
  window.APOLANA_DB = window.supabase.createClient(URL, KEY);

  /* Devuelve la URL de una imagen: si ya es una URL (subida a Supabase)
     la usa tal cual; si es solo un nombre, la busca en /assets/img/. */
  window.APOLANA_IMG = function (v) {
    if (!v) return "";
    var b = window.APOLANA_BASE || "./";
    return /^https?:\/\//.test(v) ? v : b + "assets/img/" + v;
  };

  /* Ayudante: noticias publicadas, de más nueva a más antigua
     (o null si algo falla). Sin límite = todas. */
  window.APOLANA_DB.noticias = async function (limite) {
    try {
      var q = window.APOLANA_DB
        .from("noticias")
        .select("id, titulo, excerpt, categoria, foto_portada, fecha_publicacion")
        .eq("publicada", true)
        .order("fecha_publicacion", { ascending: false });
      if (limite) q = q.limit(limite);
      var res = await q;
      if (res.error) { console.warn("[Apolana] noticias:", res.error.message); return null; }
      return res.data;
    } catch (e) {
      console.warn("[Apolana] noticias (excepción):", e);
      return null;
    }
  };

  /* Ayudante: una noticia concreta por su id (o null si no existe/falla). */
  window.APOLANA_DB.noticiaPorId = async function (id) {
    try {
      var res = await window.APOLANA_DB
        .from("noticias")
        .select("id, titulo, excerpt, contenido, categoria, foto_portada, fotos_galeria, fecha_publicacion")
        .eq("id", id)
        .eq("publicada", true)
        .single();
      if (res.error) { console.warn("[Apolana] noticia:", res.error.message); return null; }
      return res.data;
    } catch (e) {
      console.warn("[Apolana] noticia (excepción):", e);
      return null;
    }
  };
})();

/* ============================================================
   App instalable (PWA): manifiesto, iconos de móvil y el
   "service worker" que la hace funcionar sin conexión.
   Se engancha desde aquí para no tocar cada página una a una.
   Usa APOLANA_BASE para que las rutas valgan en GitHub y en el dominio propio.
   ============================================================ */
(function () {
  try {
    var base = window.APOLANA_BASE || './';
    function enlace(rel, href, extra) {
      if (document.querySelector('link[rel="' + rel + '"]')) return;
      var l = document.createElement('link'); l.rel = rel; l.href = href;
      if (extra) for (var k in extra) l.setAttribute(k, extra[k]);
      document.head.appendChild(l);
    }
    function meta(name, content) {
      if (document.querySelector('meta[name="' + name + '"]')) return;
      var m = document.createElement('meta'); m.name = name; m.content = content;
      document.head.appendChild(m);
    }
    enlace('manifest', base + 'app.webmanifest');
    enlace('apple-touch-icon', base + 'assets/img/apple-touch-icon.png');
    meta('theme-color', '#2E4256');
    meta('apple-mobile-web-app-capable', 'yes');
    meta('apple-mobile-web-app-status-bar-style', 'default');
    meta('apple-mobile-web-app-title', 'Apolana');
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', function () {
        navigator.serviceWorker.register(base + 'sw.js').catch(function () { /* sin conexión o no soportado: no pasa nada */ });
      });
    }
  } catch (e) { /* si algo falla, la web sigue funcionando igual */ }
})();
