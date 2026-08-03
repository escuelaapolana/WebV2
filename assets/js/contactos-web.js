/* ============================================================
   QUIÉN LLEVA QUÉ · los responsables del club, desde el panel
   ------------------------------------------------------------
   CÓMO FUNCIONA, en corto:

     1. En el HTML, cada sitio donde sale una persona lleva una marca
        con QUIÉN es y QUÉ se enseña de ella:

            <span data-contacto="natacion"
                  data-contacto-dato="nombre_corto,telefono">Mario Clavero · 600 00 00 00</span>

        «natacion» es a quién se pregunta. Vale de dos maneras:
          · la clave de la persona  ('mario', 'andres'…), o
          · la sección de la que es responsable ('natacion', 'pista'…),
            que es lo bueno: la página NO se sabe el nombre, así que
            el día que cambie el responsable no hay que tocarla.

     2. Al abrir la página, este ayudante pregunta a la base de datos
        (vista `contactos_publicos`) por las personas que hacen falta
        en ESTA página, y escribe lo que le digan.

   RESPALDO (lo importante): si la base no responde, si no hay
   conexión, o si esa persona no está dada de alta, NO se toca nada y
   se queda lo que ya trae el HTML escrito a mano. La web nunca se
   queda con un hueco vacío. Es el mismo trato que hace
   `imagenes-web.js` con las fotos.

   ⚠️ PERO OJO CON UNA COSA, QUE ES LA QUE IMPORTA:
   Si la base SÍ responde y dice que ese teléfono no se publica, el
   texto escrito a mano SE BORRA. Tiene que ser así: si no, apagar el
   interruptor en el panel no serviría de nada, porque el móvil se
   seguiría leyendo en el HTML. «No contesta» y «no se publica» son
   dos cosas distintas y se tratan distinto.
   Cuando no queda nada que enseñar, el trozo entero se esconde, para
   que no se vea un «Responsable» con el hueco en blanco al lado.

   El teléfono y el correo no viajan siquiera: la vista de la base
   los devuelve vacíos si no se publican, así que no hay nada que
   espiar desde la consola del navegador.

   MARCAS QUE ENTIENDE
     data-contacto          · a quién (clave o sección). Obligatoria.
     data-contacto-dato     · qué se enseña, separado por comas:
                              nombre · nombre_corto · cargo ·
                              cargo_detalle · telefono · email
                              Se unen con « · » y los vacíos se saltan.
                              Si no se pone, se usa «nombre_corto».
     data-contacto-prefijo  · texto fijo delante («Escribirle · »).
     data-contacto-href     · «tel» o «mailto»: además del texto, le
                              pone el destino al enlace.

   Se carga con:
     <script src="…/assets/js/contactos-web.js" defer></script>
   después de db.js.
   ============================================================ */
(function () {
  'use strict';

  /* Este ayudante puede llegar por dos caminos: puesto a mano en la
     página, o pedido por datos.js (que lo carga la web entera). Si
     llegan los dos, se hace el trabajo una sola vez. */
  if (window.__APOLANA_CONTACTOS) return;
  window.__APOLANA_CONTACTOS = true;

  var CAMPOS = ['nombre', 'nombre_corto', 'cargo', 'cargo_detalle',
                'descripcion', 'telefono', 'email'];

  function limpio(s) { return (s == null ? '' : String(s)).trim(); }

  /* Qué campos pide este trozo de HTML. Si no pide ninguno o los pide
     mal escritos, se enseña el nombre corto, que es lo más probable. */
  function camposDe(el) {
    var pedido = limpio(el.getAttribute('data-contacto-dato'));
    if (!pedido) return ['nombre_corto'];
    var lista = pedido.split(',').map(function (c) { return c.trim().toLowerCase(); })
      .filter(function (c) { return CAMPOS.indexOf(c) !== -1; });
    return lista.length ? lista : ['nombre_corto'];
  }

  /* El teléfono para un enlace: sin espacios y con el prefijo de país,
     que es lo que hace que al pulsarlo desde el móvil llame de verdad.
     Si ya trae prefijo o no es un móvil español de nueve cifras, se
     deja tal cual: más vale respetarlo que estropearlo. */
  function telEnlace(v) {
    var t = limpio(v).replace(/[\s.\-()]/g, '');
    if (!t) return '';
    if (t.charAt(0) === '+') return t;
    return /^[6789]\d{8}$/.test(t) ? '+34' + t : t;
  }

  /* Escribe una persona en su trozo de HTML. */
  function aplicar(el, fila) {
    var partes = camposDe(el).map(function (c) { return limpio(fila[c]); })
      .filter(Boolean);
    var texto = partes.join(' · ');

    /* Nada que enseñar: o esa persona no tiene ese dato, o el club ha
       decidido no publicarlo. En los dos casos se retira el trozo
       entero en vez de dejar un rótulo huérfano.

       ⚠️ Y NO BASTA CON ESCONDERLO. Esconder el trozo lo quita de la
       vista, pero el correo o el móvil escritos a mano en el HTML se
       siguen leyendo en el código fuente de la página, que es donde
       miran los robots que recogen direcciones. Así que se borra el
       texto Y el destino del enlace: si el club apaga el interruptor,
       el dato no queda en ningún sitio. */
    if (!texto) {
      el.textContent = '';
      if (el.hasAttribute('data-contacto-href')) el.removeAttribute('href');
      el.hidden = true;
      el.setAttribute('aria-hidden', 'true');
      return;
    }
    el.hidden = false;
    el.removeAttribute('aria-hidden');

    var prefijo = el.getAttribute('data-contacto-prefijo');
    el.textContent = (prefijo || '') + texto;

    var como = limpio(el.getAttribute('data-contacto-href')).toLowerCase();
    if (!como) return;
    if (como === 'tel') {
      var t = telEnlace(fila.telefono);
      if (t) el.setAttribute('href', 'tel:' + t);
    } else if (como === 'mailto') {
      var m = limpio(fila.email);
      if (m) el.setAttribute('href', 'mailto:' + m);
    }
  }

  /* ============================================================
     EL PIE Y LA CABECERA · que los pinta apolana.js
     ------------------------------------------------------------
     El pie de TODAS las páginas y el botón de WhatsApp de la
     cabecera los dibuja `apolana.js` leyendo `datos.js`, y lo hace
     nada más cargar la página, antes de que la base conteste. Como
     ese archivo no se toca, lo que se hace es repasar lo que ya ha
     dejado escrito en cuanto llegan los datos buenos.

     Qué dato de la base le toca a cada hueco lo dice `datos.js` en
     `contacto_desde_la_base`, que es donde el club puede leerlo.

     Si un dato deja de publicarse, aquí NO basta con cambiarlo: hay
     que quitar el enlace entero del pie. Si no, apagar el
     interruptor en el panel dejaría el teléfono puesto abajo, en
     todas las páginas, que es justo lo que veníamos a arreglar.
     ============================================================ */

  function telLimpio(v) { return limpio(v).replace(/[\s.\-()+]/g, ''); }

  /* Los enlaces que apuntan a este dato, buscando SOLO entre los de su
     clase. Es importante que no se mezclen: el teléfono de la escuela
     y el de WhatsApp son el mismo número, y si el de WhatsApp tocara
     también el enlace del pie le borraría el « · escuela» de detrás. */
  var DONDE = {
    tel:  'a[href^="tel:"]',
    mail: 'a[href^="mailto:"]',
    wa:   'a[href*="wa.me/"]'
  };
  function enlacesCon(tipo, valor) {
    var v = (tipo === 'mail') ? limpio(valor).toLowerCase() : telLimpio(valor);
    if (!v) return [];
    return Array.prototype.filter.call(document.querySelectorAll(DONDE[tipo]), function (a) {
      var h = a.getAttribute('href') || '';
      return (tipo === 'mail' ? h.toLowerCase() : telLimpio(h)).indexOf(v) !== -1;
    });
  }

  /* Se quita el enlace y, si estaba dentro de una fila de redes o de
     una fila del pie que se queda vacía, también el envoltorio. */
  function retirar(a) {
    var fila = a.closest && a.closest('.red-fila');
    (fila || a).remove();
  }

  function repasarPie(porClave) {
    var A = window.APOLANA;
    var C = A && A.contacto;
    var MAPA = A && A.contacto_desde_la_base;
    if (!C || !MAPA) return;

    Object.keys(MAPA).forEach(function (hueco) {
      var m = MAPA[hueco] || {};
      var fila = porClave[m.clave];
      if (!fila) return;                       // respaldo: no se toca

      var nuevo = limpio(fila[m.campo]);
      var esTel = (m.campo === 'telefono');
      var actual = C[hueco];
      var tipo = (hueco === 'whatsapp') ? 'wa' : (esTel ? 'tel' : 'mail');

      /* El valor que apolana.js dejó escrito, para poder encontrarlo. */
      var viejo = (typeof actual === 'string')
        ? actual
        : (actual && (actual.texto || actual.usuario)) || '';
      var enlaces = enlacesCon(tipo, viejo);

      if (!nuevo) {
        /* El club ha dejado de publicarlo: fuera de todas las páginas. */
        enlaces.forEach(retirar);
        if (typeof actual === 'string') C[hueco] = '';
        else if (actual) { actual.texto = ''; actual.tel = ''; actual.usuario = ''; actual.url = ''; }
        return;
      }

      /* Se actualiza el objeto de datos.js, por si algo lo lee luego. */
      if (typeof actual === 'string') {
        C[hueco] = nuevo;
      } else if (actual) {
        if (hueco === 'whatsapp') {
          actual.usuario = nuevo;
          actual.url = 'https://wa.me/34' + telLimpio(nuevo).replace(/^34/, '');
        } else {
          actual.texto = nuevo;
          actual.tel = '+34' + telLimpio(nuevo).replace(/^34/, '');
        }
      }

      enlaces.forEach(function (a) {
        var h = a.getAttribute('href') || '';
        if (h.indexOf('wa.me/') !== -1) {
          /* Se respeta el mensaje ya escrito que llevan algunos enlaces. */
          var cola = h.indexOf('?');
          a.setAttribute('href', 'https://wa.me/34' + telLimpio(nuevo).replace(/^34/, '') +
            (cola !== -1 ? h.slice(cola) : ''));
          if (a.hasAttribute('title')) {
            a.setAttribute('title', 'Escríbenos por WhatsApp al ' + nuevo);
          }
          var cuenta = a.querySelector('.red-cuenta');
          if (cuenta) cuenta.textContent = nuevo;
          return;
        }
        a.setAttribute('href', (esTel ? 'tel:+34' + telLimpio(nuevo).replace(/^34/, '') : 'mailto:' + nuevo));
        /* En el pie el enlace pone «600 00 00 00 · socios»: se cambia
           el número y se respeta lo que iba detrás. */
        var nota = (actual && actual.nota) ? ' · ' + actual.nota : '';
        if (!a.querySelector('*')) a.textContent = nuevo + (viejo && nota ? nota : '');
      });
    });
  }

  function arranca() {
    var nodos = document.querySelectorAll('[data-contacto]');
    var hayPie = !!(window.APOLANA && window.APOLANA.contacto_desde_la_base);
    if (!nodos.length && !hayPie) return;

    /* La conexión puede no estar lista todavía: este ayudante lo carga
       `datos.js` sin esperar a nadie, así que unas veces llega antes
       que `db.js` y otras después. Se espera un rato corto en vez de
       rendirse a la primera; si al final no aparece (sin conexión, la
       librería no cargó), no se toca nada y la página se queda con lo
       que lleva escrito. */
    esperarBase(function (db) { consultar(db, nodos); });
  }

  function esperarBase(cuando) {
    var t0 = Date.now();
    (function mira() {
      var db = window.APOLANA_DB;
      if (db && typeof db.from === 'function') { cuando(db); return; }
      if (Date.now() - t0 > 8000) return;      // se queda el respaldo
      setTimeout(mira, 60);
    })();
  }

  function consultar(db, nodos) {
    try {
      db.from('contactos_publicos')
        .select('clave,nombre,nombre_corto,cargo,cargo_detalle,seccion,es_responsable,descripcion,datos,telefono,email')
        .then(function (r) {
          if (!r || r.error || !r.data || !r.data.length) return;   // respaldo

          /* Se puede preguntar por la clave de la persona o por la
             sección que lleva. La clave manda, por si alguna vez
             coinciden.

             En una sección puede haber varias personas (los dos
             entrenadores de running, por ejemplo). Cuando se pregunta
             por la sección a secas se contesta con QUIEN RESPONDE de
             ella, que es lo que espera una página que pone
             «Responsable». Si no hay ninguno marcado, se coge el
             primero por orden, para no dejar el hueco vacío. */
          var porClave = {}, porSeccion = {};
          r.data.forEach(function (f) {
            if (f.clave) porClave[f.clave] = f;
            if (!f.seccion) return;
            var ya = porSeccion[f.seccion];
            if (!ya || (f.es_responsable && !ya.es_responsable)) porSeccion[f.seccion] = f;
          });

          Array.prototype.forEach.call(nodos, function (el) {
            var quien = limpio(el.getAttribute('data-contacto'));
            var fila = porClave[quien] || porSeccion[quien];
            if (!fila) return;          // respaldo: se queda lo del HTML
            aplicar(el, fila);
          });

          /* Y el pie, que es de todas las páginas a la vez. */
          try { repasarPie(porClave); } catch (e) { /* respaldo */ }
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
