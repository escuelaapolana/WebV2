/* ============================================================
   PÁGINAS LANZADERA · los textos y los precios los pone el club
   ------------------------------------------------------------
   CÓMO FUNCIONA, en corto:

     1. Cada tarjeta de la página dice de qué sección habla:
            <a class="lanz-card" href="../running/" data-sec="running">

     2. Al abrirla, este ayudante pregunta a la base por esas
        secciones y escribe lo que le digan:

          · contenido_secciones → antetítulo, título, frase y foto
          · tarifas_vigentes    → el «desde X €/mes» de cada una

     3. La cuota de socio, que es la misma para todas, se dice una
        sola vez debajo de la rejilla, en el hueco `id="lanz-socio"`.

   POR QUÉ `tarifas_vigentes` Y NO `tarifas`: porque esa vista deja
   fuera las tarifas caducadas y las que todavía no han entrado en
   vigor. Con la tabla en crudo, el día que el club prepare los
   precios de la temporada que viene saldrían los dos a la vez.

   RESPALDO: si la base no contesta, se queda lo que trae el HTML,
   que es texto y nunca un precio. Nadie ve una cifra equivocada.

   SIN PRECIO NO HAY HUECO: cuando una sección no tiene cuota de
   entrenamiento, el sitio del precio se queda vacío y desaparece.
   La razón se explica dentro de su página; un «Consultar» aquí
   parecería un descuido.

   Se carga con:
     <script src="…/assets/js/lanzadera.js" defer></script>
   después de db.js.
   ============================================================ */
(function () {
  'use strict';

  var PERIODO = {
    'mensual': '/mes', 'trimestral': '/trimestre', 'anual': '/año',
    'temporada': '/temporada', 'semanal': '/semana',
    'pago único': ' (pago único)', 'por sesión': '/sesión', 'bono': ' (bono)'
  };

  function limpio(v) { return (v == null ? '' : String(v)).trim(); }

  /* 40.00 → «40 €» · 40.5 → «40,50 €» (nunca «40.5 €»). */
  function euros(n) {
    var v = Number(n);
    if (!isFinite(v)) return '';
    var entero = Math.round(v * 100) % 100 === 0;
    return (entero ? String(Math.round(v)) : v.toFixed(2).replace('.', ',')) + ' €';
  }

  function importe(t) {
    if (t.importe_socio == null || t.importe_socio === '') return '';
    return euros(t.importe_socio) + (PERIODO[limpio(t.periodicidad)] || '');
  }

  function arranca() {
    var tarjetas = document.querySelectorAll('[data-sec]');
    if (!tarjetas.length) return;

    var db = window.APOLANA_DB;
    if (!db || typeof db.from !== 'function') return;   // respaldo: lo del HTML

    var claves = [];
    Array.prototype.forEach.call(tarjetas, function (el) {
      var k = limpio(el.getAttribute('data-sec'));
      if (k && claves.indexOf(k) === -1) claves.push(k);
    });

    Promise.all([
      db.from('contenido_secciones')
        .select('seccion,titulo,dirigido_a,descripcion,imagen_url,imagen_encuadre,imagen_zoom')
        .in('seccion', claves),
      db.from('tarifas_vigentes')
        .select('seccion,clave,importe_socio,periodicidad')
    ]).then(function (res) {
      var fichas  = (res[0] && !res[0].error && res[0].data) || [];
      var tarifas = (res[1] && !res[1].error && res[1].data) || [];

      /* --- Texto y foto de cada tarjeta --- */
      fichas.forEach(function (f) {
        var caja = document.querySelector('[data-sec="' + f.seccion + '"]');
        if (!caja) return;
        /* `data-fijo` = este texto lo decide la página y no la base. Lo usa
           la banda de El Cubo, que no cuenta lo mismo que su ficha: aquí
           tiene que explicar por qué va aparte (bonos de uso, no cuota). */
        var pon = function (sel, valor) {
          var el = caja.querySelector(sel);
          if (el && !el.hasAttribute('data-fijo') && limpio(valor)) el.textContent = limpio(valor);
        };
        pon('h2', f.titulo);
        pon('.lanz-quien', f.dirigido_a);
        pon('p', f.descripcion);

        var img = caja.querySelector('img');
        if (!img) return;
        /* Se descarga por detrás y solo se cambia cuando está entera, como
           en el resto de la web. Cambiar `src` a pelo vacía el hueco y deja
           fuera la del respaldo: se veía la vieja, un hueco y la buena.
           Andrés: «cuando pincho en entrenar las fotos cambian de nuevo». */
        /* Si la foto es un hueco de biblioteca, la pone imagenes-web.js y
           aquí no se toca: dos ayudantes escribiendo el mismo `src` es una
           carrera, y quien gana depende de cuál conteste antes. */
        if (limpio(f.imagen_url) && !img.hasAttribute('data-img')) {
          (function (url, destino) {
            var previa = new Image();
            previa.onload = function () { destino.src = url; };
            previa.onerror = function () { /* se queda la del respaldo */ };
            previa.src = url;
            if (previa.complete && previa.naturalWidth) destino.src = url;
          }(limpio(f.imagen_url), img));
        }
        /* El encuadre lo elige el club en el panel; aquí no se decide nada. */
        if (limpio(f.imagen_encuadre)) {
          img.style.objectPosition = limpio(f.imagen_encuadre);
          img.style.transformOrigin = limpio(f.imagen_encuadre);
        }
        if (f.imagen_zoom > 1) img.style.transform = 'scale(' + f.imagen_zoom + ')';
      });

      /* --- «desde X €/mes» en cada tarjeta --- */
      claves.forEach(function (clave) {
        var hueco = document.querySelector('[data-sec="' + clave + '"] .lanz-desde');
        if (!hueco) return;                     // esta tarjeta no quiere precio
        var conCifra = tarifas.filter(function (t) {
          return t.seccion === clave && t.clave !== 'cuota-socio' &&
                 t.importe_socio != null && t.importe_socio !== '';
        });
        if (!conCifra.length) return;           // sin cifra, el hueco se esconde solo
        var barato = conCifra.slice().sort(function (a, b) { return a.importe_socio - b.importe_socio; })[0];
        hueco.textContent = (conCifra.length > 1 ? 'desde ' : '') + importe(barato);
      });

      /* --- La cuota de socio, una vez y para todas --- */
      var linea = document.getElementById('lanz-socio');
      if (!linea) return;
      var socio = tarifas.filter(function (t) { return t.clave === 'cuota-socio'; })[0];
      if (!socio || !importe(socio)) return;
      linea.textContent = '';
      linea.appendChild(document.createTextNode(limpio(linea.getAttribute('data-antes')) || 'La cuota de socio es la misma para todas las secciones: '));
      var b = document.createElement('b');
      b.textContent = importe(socio);
      linea.appendChild(b);
      linea.appendChild(document.createTextNode(', una vez al año y aparte del entrenamiento.'));
    }).catch(function () { /* respaldo: se queda lo del HTML */ });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', arranca);
  } else {
    arranca();
  }
})();
