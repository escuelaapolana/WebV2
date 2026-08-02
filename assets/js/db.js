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
      /* La app se actualiza SOLA. Antes solo se registraba y se
         quedaba pegada a la versión que se guardó la primera vez, y
         la gente tenía que borrar y reinstalar la app para ver los
         cambios. Eso no lo va a hacer nadie. Ahora:
           · al abrir la app y cada vez que se vuelve a ella, se
             pregunta al servidor si hay una versión nueva;
           · si la hay, el service worker nuevo se activa y toma el
             control, y la página se recarga UNA vez, sola.
         Con internet, abrir la app ya trae lo último. */
      var teniaControl = !!navigator.serviceWorker.controller;
      var yaRecargado = false;
      navigator.serviceWorker.addEventListener('controllerchange', function () {
        /* Solo recargamos si ya había una versión antes (una
           actualización de verdad), no en la primera instalación, y
           nunca dos veces. */
        if (yaRecargado || !teniaControl) return;
        yaRecargado = true;
        window.location.reload();
      });
      window.addEventListener('load', function () {
        navigator.serviceWorker.register(base + 'sw.js').then(function (reg) {
          function comprobar() { try { reg.update(); } catch (e) { /* sin conexión: se comprueba a la próxima */ } }
          comprobar();
          /* Cada vez que la app vuelve a primer plano, se mira si hay
             algo nuevo. Es cuando la gente abre la app, que es cuando
             toca traer lo último. */
          document.addEventListener('visibilitychange', function () {
            if (document.visibilityState === 'visible') comprobar();
          });
        }).catch(function () { /* sin conexión o no soportado: no pasa nada */ });
      });
    }
  } catch (e) { /* si algo falla, la web sigue funcionando igual */ }
})();

/* ==========================================================================
   TIRAR PARA RECARGAR (solo en la app instalada)
   En una app instalada (standalone) el navegador no tiene su "tirar para
   recargar", así que lo montamos nosotros: si estás arriba del todo y tiras
   hacia abajo, se recarga la página (y como el service worker va "red
   primero", trae la última versión).
   ========================================================================== */
(function () {
  function esApp() {
    try { return window.navigator.standalone === true ||
      (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches); } catch (e) { return false; }
  }
  if (!esApp()) return;

  var ind, startY = null, pull = 0, activo = false, UMBRAL = 70;
  function arriba() { return (window.pageYOffset || document.documentElement.scrollTop || 0) <= 0; }

  document.addEventListener('DOMContentLoaded', function () {
    var st = document.createElement('style');
    st.textContent = '@keyframes apo-ptr-rot{to{transform:rotate(360deg)}}.apo-ptr-anim{animation:apo-ptr-rot .7s linear infinite}';
    document.head.appendChild(st);
    ind = document.createElement('div');
    ind.setAttribute('aria-hidden', 'true');
    ind.style.cssText = 'position:fixed;top:0;left:0;right:0;display:flex;align-items:center;justify-content:center;height:0;overflow:hidden;z-index:9999;pointer-events:none;transition:height .18s ease;';
    ind.innerHTML = '<div class="apo-ptr-s" style="width:22px;height:22px;margin:10px 0;border:2.5px solid rgba(46,66,86,.25);border-top-color:#2E4256;border-radius:50%"></div>';
    document.body.appendChild(ind);
  });

  window.addEventListener('touchstart', function (e) {
    if (arriba() && e.touches.length === 1) { startY = e.touches[0].clientY; activo = true; pull = 0; }
    else activo = false;
  }, { passive: true });

  window.addEventListener('touchmove', function (e) {
    if (!activo || startY === null) return;
    var dy = e.touches[0].clientY - startY;
    if (dy > 0 && arriba()) {
      pull = Math.min(dy * 0.5, 90);
      if (ind) { ind.style.transition = 'none'; ind.style.height = pull + 'px'; var s = ind.firstChild; if (s) s.style.transform = 'rotate(' + (pull * 4) + 'deg)'; }
      if (dy > 6) e.preventDefault();
    } else { activo = false; }
  }, { passive: false });

  window.addEventListener('touchend', function () {
    if (!activo) return;
    activo = false;
    if (ind) ind.style.transition = 'height .18s ease';
    if (pull >= UMBRAL) {
      if (ind) { ind.style.height = '52px'; var s = ind.firstChild; if (s) s.classList.add('apo-ptr-anim'); }
      location.reload();
    } else if (ind) { ind.style.height = '0'; }
    startY = null; pull = 0;
  }, { passive: true });
})();
