/* ============================================================
   FOTOS DE LA WEB · las cambia el club desde el panel
   ------------------------------------------------------------
   CÓMO FUNCIONA, en corto:

     1. En el HTML, cada foto que se puede cambiar lleva una marca:
            <img src="assets/img/hero.jpg" data-img="home.hero" alt="…">
        Esa marca ("home.hero") es el nombre del hueco.

     2. Al abrir la página, este ayudante pregunta a la base de datos
        (tabla `imagenes_web`) si el club ha elegido otra foto para
        cada uno de los huecos que hay en la página.

     3. Si la hay, la cambia, respetando el encuadre y el acercamiento
        que se eligieron en el panel.

   RESPALDO (lo importante): si la base no responde, si no hay foto
   elegida, o si no hay conexión, NO se toca nada y se queda la foto
   que ya trae el HTML. La web nunca se queda con un hueco vacío.

   Extras:
     · data-img-href="clave" en un enlace de descarga: le cambia el
       destino a la misma foto (lo usa el cartel del campus).
     · Si la marca está en algo que no es una <img>, se le pone la foto
       de fondo (background-image).

   Se carga con:
     <script src="…/assets/js/imagenes-web.js" defer></script>
   después de db.js.
   ============================================================ */
(function () {
  'use strict';

  /* ¿El recuadro que contiene la foto la recorta? Si no recorta, no se
     aplica el acercamiento: se saldría por los lados en vez de acercarse. */
  function recorta(el) {
    try {
      var p = el.parentElement;
      if (!p) return false;
      var o = window.getComputedStyle(p).overflow;
      return o === 'hidden' || o === 'clip' || o === 'auto' || o === 'scroll';
    } catch (e) { return false; }
  }

  /* Pone una foto en su hueco. `fila` es lo que hay en la base. */
  function aplicar(el, fila) {
    if (!el || !fila) return;
    var url = fila.url && String(fila.url).trim();
    if (!url) return;                     // sin foto elegida → se queda la del HTML

    var pos = fila.encuadre && String(fila.encuadre).trim();
    var zoom = parseFloat(fila.zoom);

    if (el.tagName === 'IMG') {
      el.src = url;
      if (fila.alt != null && String(fila.alt).trim()) el.alt = String(fila.alt).trim();
      if (pos) { el.style.objectPosition = pos; el.style.transformOrigin = pos; }
      if (!isNaN(zoom) && zoom > 1 && recorta(el)) el.style.transform = 'scale(' + zoom + ')';
    } else {
      /* No es una imagen: se usa de fondo. */
      el.style.backgroundImage = 'url("' + url.replace(/"/g, '%22') + '")';
      el.style.backgroundSize = 'cover';
      if (pos) el.style.backgroundPosition = pos;
    }
  }

  function arranca() {
    var nodos = document.querySelectorAll('[data-img]');
    var enlaces = document.querySelectorAll('[data-img-href]');
    if (!nodos.length && !enlaces.length) return;

    /* Sin base de datos (sin conexión, o la librería no cargó):
       no se toca nada y la página se queda con sus fotos de siempre. */
    var db = window.APOLANA_DB;
    if (!db || typeof db.from !== 'function') return;

    /* Qué huecos hay en ESTA página (sin repetir). */
    var claves = [], vistas = {};
    function anota(el, attr) {
      var k = el.getAttribute(attr);
      if (k && !vistas[k]) { vistas[k] = true; claves.push(k); }
    }
    Array.prototype.forEach.call(nodos, function (el) { anota(el, 'data-img'); });
    Array.prototype.forEach.call(enlaces, function (el) { anota(el, 'data-img-href'); });
    if (!claves.length) return;

    try {
      db.from('imagenes_web')
        .select('clave,url,encuadre,zoom,alt')
        .in('clave', claves)
        .then(function (r) {
          if (!r || r.error || !r.data || !r.data.length) return;   // respaldo
          var porClave = {};
          r.data.forEach(function (f) { porClave[f.clave] = f; });

          Array.prototype.forEach.call(nodos, function (el) {
            aplicar(el, porClave[el.getAttribute('data-img')]);
          });
          Array.prototype.forEach.call(enlaces, function (el) {
            var f = porClave[el.getAttribute('data-img-href')];
            if (f && f.url) el.href = f.url;
          });
        })
        .catch(function () { /* respaldo: se queda lo del HTML */ });
    } catch (e) { /* respaldo: se queda lo del HTML */ }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', arranca);
  } else {
    arranca();
  }
})();
