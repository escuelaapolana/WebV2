/* ============================================================
   QUIÉN LLEVA QUÉ · los responsables del club, desde el panel
   ------------------------------------------------------------
   CÓMO FUNCIONA, en corto:

     1. En el HTML, cada sitio donde sale una persona lleva una marca
        con QUIÉN es y QUÉ se enseña de ella:

            <span data-contacto="natacion"
                  data-contacto-dato="nombre_corto,telefono">Mario Clavero · 666 03 30 44</span>

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
       entero en vez de dejar un rótulo huérfano. */
    if (!texto) {
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

  function arranca() {
    var nodos = document.querySelectorAll('[data-contacto]');
    if (!nodos.length) return;

    /* Sin base de datos (sin conexión, o la librería no cargó):
       no se toca nada y la página se queda con lo suyo de siempre. */
    var db = window.APOLANA_DB;
    if (!db || typeof db.from !== 'function') return;

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
