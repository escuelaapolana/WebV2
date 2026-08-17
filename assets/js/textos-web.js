/* ============================================================
   TEXTOS SUELTOS DE LA WEB · los cambia el club desde la página
   ------------------------------------------------------------
   CÓMO FUNCIONA, en corto:

     1. En el HTML, cada trozo de texto que se puede cambiar lleva una
        marca con el nombre del hueco:
            <p data-texto="club.junta.pie">Lo que diga hoy</p>

     2. Al abrir la página, este ayudante pregunta a la base (tabla
        `textos_web`) si el club ha escrito otra cosa en esos huecos.

     3. Si la hay, la pone. Si no, no toca nada.

   RESPALDO, que es lo importante: si la base no contesta, si no hay
   conexión o si ese hueco no está escrito, se queda LO QUE TRAE EL
   HTML. Una web estática que se queda en blanco porque una base no
   responde no es una web estática. Por eso el texto sigue estando
   escrito en el HTML aunque se pueda cambiar desde el panel: no es
   duplicar, es tener suelo.

   POR QUÉ SE PIDE TODO DE UNA VEZ
   Una consulta por página, con la lista de huecos que hay en ella.
   Pedir uno por uno serían quince viajes para pintar quince frases.

   POR QUÉ NO SE ACEPTA HTML
   Se escribe con nodos de texto, nunca con `innerHTML`. Lo que el club
   escribe en el editor es texto y solo texto: si algún día alguien
   pegara ahí una etiqueta, se vería escrita en la página en vez de
   ejecutarse. En una web con panel de administración eso no es
   quisquillosería, es la diferencia entre un texto y un agujero.

   Se carga con:
     <script src="…/assets/js/textos-web.js" defer></script>
   después de db.js.
   ============================================================ */
(function () {
  'use strict';

  /* Escribe el texto respetando los saltos de línea. Varios titulares
     grandes vienen partidos a mano en el HTML («Un club de<br>socios»)
     porque así caen bien; con `textContent` a secas ese corte se perdería
     en cuanto alguien tocara el título desde el editor, y el titular se
     descolocaría sin que nadie entendiese por qué.

     Los saltos se montan con nodos de verdad, uno a uno. NO con
     `innerHTML`: lo que viene de la base es texto del club, no código, y
     aquí no se ejecuta nada de lo que llegue. */
  function ponerTexto(el, texto) {
    var lineas = texto.split('\n');
    if (lineas.length === 1) { el.textContent = texto; return; }
    el.textContent = '';
    lineas.forEach(function (l, i) {
      if (i) el.appendChild(document.createElement('br'));
      el.appendChild(document.createTextNode(l));
    });
  }

  function arranca() {
    var nodos = document.querySelectorAll('[data-texto]');
    if (!nodos.length) return;

    /* Sin base de datos no se toca nada: la página se queda con sus
       textos de siempre, que es exactamente lo que debe pasar. */
    var db = window.APOLANA_DB;
    if (!db || typeof db.from !== 'function') return;

    /* Qué huecos hay en ESTA página, sin repetir. */
    var claves = [], vistas = {};
    Array.prototype.forEach.call(nodos, function (el) {
      var k = (el.getAttribute('data-texto') || '').trim();
      if (k && !vistas[k]) { vistas[k] = true; claves.push(k); }
    });
    if (!claves.length) return;

    try {
      db.from('textos_web')
        .select('clave,texto')
        .in('clave', claves)
        .then(function (r) {
          if (!r || r.error || !r.data || !r.data.length) return;   // respaldo
          var porClave = {};
          r.data.forEach(function (f) { porClave[f.clave] = f; });

          Array.prototype.forEach.call(nodos, function (el) {
            var f = porClave[(el.getAttribute('data-texto') || '').trim()];
            if (!f) return;
            var t = (f.texto == null ? '' : String(f.texto)).trim();
            /* Un hueco escrito en blanco NO vacía la página. Si el club
               quiere que algo no salga, se quita del HTML; dejar el campo
               vacío sin querer es mucho más fácil que quererlo. */
            if (!t) return;
            ponerTexto(el, t);
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
