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
     · data-img-movil="clave" JUNTO a data-img: segunda foto solo para
       pantallas estrechas (hasta 700 px). Es opcional y hoy solo la usa
       la portada. Si ese hueco está vacío, no pasa nada: se sigue
       usando la foto de escritorio con el recorte que le da el CSS.
       Al girar el móvil o cambiar el ancho, se recoloca sola.

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

  /* Hasta aquí llega «el móvil». Es el mismo corte que usa la portada en
     su CSS, para que la foto y el encuadre cambien a la vez. */
  var ANCHO_MOVIL = '(max-width: 700px)';
  function esMovil() {
    try { return window.matchMedia(ANCHO_MOVIL).matches; } catch (e) { return false; }
  }

  /* Pone una foto en su hueco. `fila` es lo que hay en la base.
     `propia` = la foto está hecha para esta pantalla (es la del hueco de
     móvil), así que manda ella y se anula el recorte que el CSS hacía
     para aproximar con la de escritorio. */
  function aplicar(el, fila, propia) {
    if (!el || !fila) return;
    var url = fila.url && String(fila.url).trim();
    if (!url) return;                     // sin foto elegida → se queda la del HTML

    var pos = fila.encuadre && String(fila.encuadre).trim();
    var zoom = parseFloat(fila.zoom);

    if (el.tagName === 'IMG') {
      el.src = url;
      if (fila.alt != null && String(fila.alt).trim()) el.alt = String(fila.alt).trim();
      if (pos) { el.style.objectPosition = pos; el.style.transformOrigin = pos; }
      else if (propia) { el.style.objectPosition = 'center'; el.style.transformOrigin = 'center'; }
      if (!isNaN(zoom) && zoom > 1 && recorta(el)) el.style.transform = 'scale(' + zoom + ')';
      else if (propia) el.style.transform = 'none';
    } else {
      /* No es una imagen: se usa de fondo. */
      el.style.backgroundImage = 'url("' + url.replace(/"/g, '%22') + '")';
      el.style.backgroundSize = 'cover';
      if (pos) el.style.backgroundPosition = pos;
      else if (propia) el.style.backgroundPosition = 'center';
    }
  }

  /* Deja el hueco como venía del HTML, para poder repintarlo de cero
     cuando la pantalla cambia de ancho (girar el móvil, por ejemplo). */
  function desnudar(el, original) {
    el.style.objectPosition = '';
    el.style.transformOrigin = '';
    el.style.transform = '';
    el.style.backgroundImage = '';
    el.style.backgroundSize = '';
    el.style.backgroundPosition = '';
    if (el.tagName === 'IMG' && original) {
      if (el.getAttribute('src') !== original.src) el.src = original.src;
      if (el.getAttribute('alt') !== original.alt) el.alt = original.alt;
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
    Array.prototype.forEach.call(nodos, function (el) { anota(el, 'data-img'); anota(el, 'data-img-movil'); });
    Array.prototype.forEach.call(enlaces, function (el) { anota(el, 'data-img-href'); });
    if (!claves.length) return;

    /* La foto que trae el HTML, guardada antes de tocar nada: es a lo que
       se vuelve si la de móvil deja de tocar (o si nunca la hubo). */
    var deSiempre = [];
    Array.prototype.forEach.call(nodos, function (el) {
      deSiempre.push(el.tagName === 'IMG'
        ? { src: el.getAttribute('src') || '', alt: el.getAttribute('alt') || '' }
        : null);
    });

    try {
      db.from('imagenes_web')
        .select('clave,url,encuadre,zoom,alt')
        .in('clave', claves)
        .then(function (r) {
          if (!r || r.error || !r.data || !r.data.length) return;   // respaldo
          var porClave = {};
          r.data.forEach(function (f) { porClave[f.clave] = f; });

          function pinta() {
            Array.prototype.forEach.call(nodos, function (el, i) {
              var escritorio = porClave[el.getAttribute('data-img')];
              var movil = el.hasAttribute('data-img-movil')
                ? porClave[el.getAttribute('data-img-movil')] : null;
              /* La de móvil solo entra si existe, tiene foto y la pantalla
                 es estrecha. En cualquier otro caso manda la de siempre. */
              var usaMovil = !!(movil && movil.url && String(movil.url).trim() && esMovil());
              desnudar(el, deSiempre[i]);
              aplicar(el, usaMovil ? movil : escritorio, usaMovil);
            });
            Array.prototype.forEach.call(enlaces, function (el) {
              var f = porClave[el.getAttribute('data-img-href')];
              if (f && f.url) el.href = f.url;
            });
          }

          pinta();

          /* Si algún hueco tiene versión de móvil, se vuelve a decidir al
             girar el aparato o al cambiar el ancho de la ventana. */
          var hayMovil = Array.prototype.some.call(nodos, function (el) {
            var k = el.getAttribute('data-img-movil');
            return !!(k && porClave[k] && porClave[k].url);
          });
          if (hayMovil) {
            try {
              var mq = window.matchMedia(ANCHO_MOVIL);
              if (mq.addEventListener) mq.addEventListener('change', pinta);
              else if (mq.addListener) mq.addListener(pinta);   // navegadores viejos
            } catch (e) { /* sin matchMedia: se queda como se pintó */ }
          }
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
