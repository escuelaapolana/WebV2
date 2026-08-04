/* ============================================================
   CONEXIÓN A SUPABASE · base de datos del club
   ------------------------------------------------------------
   La clave "publishable" es PÚBLICA por diseño: va en el navegador
   y no es secreta. La seguridad de verdad la dan las reglas RLS
   configuradas en Supabase (qué puede leer/escribir cada quién).
   Requiere que la librería supabase-js se haya cargado antes.
   ============================================================ */
/* ============================================================
   TURNOS · cómo se dice en voz alta «el Azul 2 del martes»
   ------------------------------------------------------------
   La escuela entrena el mismo grupo dos veces por semana con niños
   distintos: hay un «Azul 2» de lunes y miércoles y otro de martes y
   jueves. El club los llama a los dos «Azul 2», así que el nombre no se
   toca; lo que los separa son los días.

   Esto vive aquí, y no repetido en cada pantalla, porque si un día se
   dice «lunes y miércoles» y en la de al lado «lun/mié», parecen dos
   cosas. Va fuera del bloque de la conexión a propósito: sirve igual
   aunque la base no conteste.
   ============================================================ */
(function () {
  var EN_PALABRAS = {
    'lunes-miercoles': 'lunes y miércoles',
    'martes-jueves':   'martes y jueves'
  };

  /* Los días del turno, tal y como se leen. Vacío si el grupo no se
     desdobla, que es lo normal fuera de la escuela. */
  window.APOLANA_TURNO = function (turno) {
    return EN_PALABRAS[turno] || '';
  };

  /* El nombre con el que hay que enseñar un grupo donde pueda haber dos
     iguales: en una lista desplegable, en una tabla, en un aviso. «Azul
     2 · martes y jueves». Si el grupo no tiene turno, es su nombre y ya
     está: no se le cuelga nada. */
  window.APOLANA_GRUPO_NOMBRE = function (g) {
    if (!g) return '';
    var nombre = (g.nombre == null ? '' : String(g.nombre)).trim();
    var dias = window.APOLANA_TURNO(g.turno);
    return dias ? nombre + ' · ' + dias : nombre;
  };
})();

(function () {
  var URL = "https://icaxokjsvhlreuwpyxeb.supabase.co";
  var KEY = "sb_publishable_ABwJ5L9azzN30mqKg6igxA_zq6pB3MH";

  if (!window.supabase || !window.supabase.createClient) {
    console.warn("[Apolana] supabase-js no está cargado; la web usará los datos de ejemplo.");
    return;
  }
  /* ------------------------------------------------------------
     DÓNDE SE GUARDA LA SESIÓN · la casilla «mantener la sesión abierta»
     ------------------------------------------------------------
     El navegador tiene dos cajones donde dejar la sesión:
       · uno que sobrevive a cerrar el navegador (localStorage)
       · otro que se vacía en cuanto se cierra   (sessionStorage)

     Hasta ahora se usaba SIEMPRE el primero, así que la casilla de
     la pantalla de acceso no habría significado nada: marcada o sin
     marcar, la sesión seguía viva al día siguiente.

     Esto se decide AQUÍ y no en la pantalla de acceso porque hay que
     elegir el cajón antes de crear la conexión, y la conexión se crea
     una sola vez para toda la web.

     Dos cosas que no cambian, a propósito:
       · Este archivo lo usan TODAS las páginas, también las públicas,
         donde no hay ninguna sesión. Para ellas esto no hace nada:
         nadie lee ni escribe nada.
       · Por defecto se sigue usando el cajón de siempre y con los
         mismos nombres, así que a quien ya estaba dentro no se le
         cierra la sesión por este cambio.
     ------------------------------------------------------------ */
  var PREF_SESION = 'apolana-mantener-sesion';   // vale 'no' solo si la persona lo pidió

  /* En navegación privada de algunos móviles, tocar estos cajones da
     error. Se pregunta con cuidado y, si no hay, se sigue sin ellos. */
  function cajon(nombre) {
    try { return window[nombre] || null; } catch (e) { return null; }
  }
  function cajonElegido() {
    var largo = cajon('localStorage');
    var corto = cajon('sessionStorage');
    var quiere = null;
    try { quiere = largo && largo.getItem(PREF_SESION); } catch (e) {}
    if (quiere === 'no' && corto) return corto;
    return largo || corto;
  }

  var ALMACEN = {
    getItem: function (k) {
      /* Se mira primero el cajón corto: quien pidió NO mantener la sesión
         la tiene ahí y solo ahí, y si mirásemos antes el largo podríamos
         resucitar una sesión vieja que ya no debería valer. */
      try { var c = cajon('sessionStorage'); var v = c && c.getItem(k); if (v != null) return v; } catch (e) {}
      try { var l = cajon('localStorage'); var w = l && l.getItem(k); return (w == null ? null : w); } catch (e) {}
      return null;
    },
    setItem: function (k, v) {
      var donde = cajonElegido();
      try { if (donde) donde.setItem(k, v); } catch (e) {}
      /* Y se borra del otro cajón: si quedaran las dos, mandaría la que
         no toca y la casilla volvería a no servir de nada. */
      try {
        var otro = (donde === cajon('sessionStorage')) ? cajon('localStorage') : cajon('sessionStorage');
        if (otro) otro.removeItem(k);
      } catch (e) {}
    },
    removeItem: function (k) {
      /* Al salir se limpian los dos, sin preguntar. */
      try { var l = cajon('localStorage'); if (l) l.removeItem(k); } catch (e) {}
      try { var c = cajon('sessionStorage'); if (c) c.removeItem(k); } catch (e) {}
    }
  };

  /* Lo que la pantalla de acceso apunta aquí justo antes de entrar. */
  window.APOLANA_SESION = {
    mantener: function (si) {
      try {
        var l = cajon('localStorage');
        if (!l) return;
        if (si) l.removeItem(PREF_SESION); else l.setItem(PREF_SESION, 'no');
      } catch (e) {}
    },
    seMantiene: function () {
      try { var l = cajon('localStorage'); return !(l && l.getItem(PREF_SESION) === 'no'); }
      catch (e) { return true; }
    }
  };

  window.APOLANA_DB = window.supabase.createClient(URL, KEY, { auth: { storage: ALMACEN } });

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
