/* ============================================================
   LAS SEIS PIEZAS DEL PANEL · Club Atletismo Apolana
   ------------------------------------------------------------
   El dibujo está en `assets/css/panel-piezas.css`. Aquí está lo
   que hace falta para que usar una pieza sean dos líneas y no
   veinte, y el poco comportamiento que las piezas tienen:
   plegar, abrir el menú de la fila y la franja de guardado.

   Es el mismo reparto que ya usa el panel para los estados de
   carga: `ADM` (en `assets/js/admin-tabbar.js`) devuelve HTML y
   la pantalla lo mete donde quiera. Aquí igual, con `PZ`.

   CÓMO SE USA, DE UN VISTAZO
   --------------------------------------------------------
     <link rel="stylesheet" href="../../assets/css/panel-piezas.css">
     <script src="../../assets/js/panel-piezas.js" defer></script>

     1 · Cabecera
         caja.innerHTML = PZ.cabecera({
           titulo:   'Tarifas',
           contexto: 'Temporada 2026-27 · 14 tarifas',
           accion:   { texto: 'Nueva tarifa', accion: 'nueva' }
         });

     2 · Filtros
         caja.innerHTML = PZ.filtros({
           buscador: { id: 'busca', placeholder: 'Buscar una tarifa' },
           chips: [
             { texto: 'Todas',      cuenta: 14, activo: true, valor: '' },
             { texto: 'Sin revisar', cuenta: 3, tono: 'aviso', valor: 'revisar' }
           ],
           filtrar: { cuenta: 2 }
         });

     3 y 4 · Tabla en el escritorio, fichas en el móvil (la misma)
         caja.innerHTML = PZ.tabla({
           columnas: ['Tarifa', 'Precio', 'Temporada', 'Estado', ''],
           filas: tarifas.map(function (t) {
             return {
               id: t.id,
               principal: t.nombre,
               contexto:  t.grupo + ' · ' + t.dias,
               celdas: [ { texto: t.precio + ' €', num: true }, t.temporada ],
               estado: { texto: 'Activa', tono: 'ok' },
               menu: [ { texto: 'Editar', accion: 'editar' },
                       { texto: 'Borrar', accion: 'borrar', ojo: true } ]
             };
           })
         });
         PZ.alPulsar(caja, function (accion, id) { … });

     5 · Campo y plegable
         PZ.campo({ id: 'cuota', label: 'Cuota mensual', tipo: 'number',
                    ayuda: 'Lo que se pasa al banco cada mes.',
                    como: 'Se cobra el día 5. Si cae en fin de semana…' })
         PZ.plegable({ titulo: 'Descuentos', cuenta: '3 puestos', cuerpo: '…' })

     6 · Franja de guardado (no existe hasta que hay algo que guardar)
         var franja = PZ.franja({ raiz: '#form-tarifas', guardar: guardarTodo });
         // se cuenta sola; si prefieres llevar la cuenta a mano:
         // franja.cambios(3)  ·  franja.cambios(0) la hace desaparecer

   REGLA QUE NO SE TOCA
   Todo lo pulsable mide 44 px. Si algo se ve más pequeño (el «⋯»
   se ve a 18), es porque el dibujo es pequeño y la zona de pulsar
   no lo es.
   ============================================================ */
(function () {
  'use strict';

  /* Si la pantalla se ha dejado el <link>, se pone solo: más vale una
     petición de más que una pantalla sin forma. */
  (function hoja() {
    var ya = document.querySelector('link[href*="panel-piezas.css"]');
    if (ya) return;
    var yo = document.querySelector('script[src*="panel-piezas.js"]');
    var url = yo ? yo.getAttribute('src').replace(/js\/panel-piezas\.js.*$/, 'css/panel-piezas.css')
                 : (window.APOLANA_BASE || '../../') + 'assets/css/panel-piezas.css';
    var l = document.createElement('link');
    l.rel = 'stylesheet';
    l.href = url;
    document.head.appendChild(l);
  })();

  /* ---------- utilidades ---------- */

  /* Todo lo que viene de la base pasa por aquí antes de ser HTML.
     Un nombre con «<» no puede romper una pantalla. */
  function esc(s) {
    var d = document.createElement('div');
    d.textContent = (s == null ? '' : String(s));
    return d.innerHTML;
  }
  function attr(n, v) { return (v == null || v === '') ? '' : ' ' + n + '="' + esc(v) + '"'; }
  /* Igual, pero el vacío también cuenta: el chip «Todas» vale «» y ese
     vacío es su valor de filtro, no una ausencia. */
  function attrVacio(n, v) { return ' ' + n + '="' + esc(v == null ? '' : v) + '"'; }
  function nodo(x) { return (typeof x === 'string') ? document.querySelector(x) : x; }

  var FLECHA = '<svg class="pz-flecha" viewBox="0 0 24 24" width="16" height="16" fill="none" ' +
    'stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round" ' +
    'aria-hidden="true"><path d="m6 9.5 6 6 6-6"/></svg>';

  /* «1 cambio» / «3 cambios»: el plural bien hecho, que se nota. */
  function plural(n, uno, varios) { return n + ' ' + (n === 1 ? uno : varios); }

  /* ============================================================
     1 · CABECERA DE PANTALLA
     ============================================================ */
  function botonHTML(b, clase) {
    if (!b) return '';
    var c = 'pz-btn' + (clase ? ' ' + clase : '');
    var extra = attr('data-pz-accion', b.accion) + attr('id', b.id) +
                (b.desactivado ? ' disabled' : '');
    if (b.href) return '<a class="' + c + '" href="' + esc(b.href) + '"' + extra + '>' + esc(b.texto) + '</a>';
    return '<button type="button" class="' + c + '"' + extra + '>' + esc(b.texto) + '</button>';
  }

  /* PZ.cabecera({ titulo, contexto, accion, secundaria })
     `contexto` es la línea con las cifras («Temporada 2026-27 · 14
     tarifas»). Es lo que sustituye a la fila de tarjetas de resumen. */
  function cabecera(o) {
    o = o || {};
    return '<div class="pz-cab">' +
      '<div class="pz-cab-txt">' +
        '<h1 class="pz-cab-tit">' + esc(o.titulo) + '</h1>' +
        (o.contexto ? '<p class="pz-cab-ctx">' + esc(o.contexto) + '</p>' : '') +
      '</div>' +
      ((o.accion || o.secundaria)
        ? '<div class="pz-cab-acciones">' +
            botonHTML(o.secundaria, 'pz-btn--borde') +
            botonHTML(o.accion) +
          '</div>'
        : '') +
    '</div>';
  }

  /* ============================================================
     2 · BARRA DE FILTROS
     ============================================================ */

  /* PZ.chip({ texto, cuenta, activo, tono, valor })
     La cifra va DENTRO. Nunca en una tarjeta de resumen aparte. */
  function chip(c) {
    if (!c) return '';
    var clase = 'pz-chip' + (c.tono === 'aviso' ? ' pz-chip--aviso' : '') +
                (c.activo ? ' pz-chip--activo' : '');
    return '<button type="button" class="' + clase + '" aria-pressed="' + (c.activo ? 'true' : 'false') + '"' +
      attrVacio('data-pz-filtro', c.valor == null ? c.texto : c.valor) +
      attr('data-pz-accion', c.accion || 'filtro') + '>' +
      esc(c.texto) +
      (c.cuenta == null ? '' : '<span class="pz-n">' + esc(c.cuenta) + '</span>') +
    '</button>';
  }

  /* PZ.filtros({ buscador, chips, filtrar })
     Una fila y solo una. `filtrar` es el cajón del resto de filtros:
     lleva su cuenta porque es lo único que no se ve desde fuera. */
  function filtros(o) {
    o = o || {};
    var h = '<div class="pz-filtros" data-chips>';

    if (o.buscador !== false) {
      var b = o.buscador || {};
      /* `data-chip-omitir` es para `admin-filtros.js`: lo que hay escrito en el
         buscador ya se ve en el propio buscador, así que no hace falta que
         salga otra vez como chip debajo. Los filtros del cajón «Filtrar» sí
         salen, que son los que no se ven desde fuera. */
      h += '<input type="search" class="pz-busca" data-chip-omitir' +
        attr('id', b.id) +
        attr('placeholder', b.placeholder || 'Buscar') +
        attr('aria-label', b.etiqueta || b.placeholder || 'Buscar') +
        attr('value', b.valor) + '>';
    }

    (o.chips || []).forEach(function (c) { h += chip(c); });

    if (o.filtrar) {
      var n = o.filtrar.cuenta || 0;
      h += '<button type="button" class="pz-chip pz-filtrar"' +
        attr('data-pz-accion', o.filtrar.accion || 'filtrar') + '>' +
        esc(o.filtrar.texto || 'Filtrar') +
        (n ? '<span class="pz-n">' + n + '</span>' : '') +
      '</button>';
    }

    return h + '</div>';
  }

  /* ============================================================
     3 y 4 · FILA DE TABLA Y FICHA DE MÓVIL
     Se escriben una vez. La misma marca es tabla por encima de
     720 px y ficha por debajo; lo hace la hoja de estilos.
     ============================================================ */

  function celdaHTML(c) {
    if (c == null) return { texto: '', num: false };
    if (typeof c === 'object') return { texto: c.html || esc(c.texto), num: !!c.num, crudo: !!c.html };
    return { texto: esc(c), num: false };
  }

  function menuHTML(id, opciones) {
    var h = '<div class="pz-menu" hidden role="menu"' + attr('id', 'pz-menu-' + id) + '>';
    (opciones || []).forEach(function (op) {
      var c = 'pz-menu-op' + (op.ojo ? ' pz-menu--ojo' : '');
      if (op.href) h += '<a class="' + c + '" role="menuitem" href="' + esc(op.href) + '"' + attr('data-pz-id', id) + '>' + esc(op.texto) + '</a>';
      else h += '<button type="button" class="' + c + '" role="menuitem"' +
                attr('data-pz-accion', op.accion) + attr('data-pz-id', id) + '>' + esc(op.texto) + '</button>';
    });
    return h + '</div>';
  }

  /* PZ.fila(fila, columnas) → el <tr>
     `columnas` sirve para rotular los pares etiqueta/valor de la
     ficha de móvil: el rótulo sale del encabezado de su columna, así
     que no hay que escribirlo dos veces. */
  var contador = 0;
  function fila(f, columnas) {
    f = f || {};
    columnas = columnas || [];
    var id = f.id == null ? ('pz' + (++contador)) : f.id;
    var h = '<tr class="pz-fila' + (f.clase ? ' ' + f.clase : '') + '"' + attr('data-pz-id', id) + '>';

    /* la columna que más dice: dato principal y su línea de contexto */
    h += '<td class="pz-td-principal">' +
      '<span class="pz-dato">' + esc(f.principal) + '</span>' +
      (f.contexto ? '<span class="pz-ctx">' + esc(f.contexto) + '</span>' : '') +
    '</td>';

    /* el resto de columnas */
    (f.celdas || []).forEach(function (c, i) {
      var d = celdaHTML(c);
      var col = columnas[i + 1];
      var rot = col ? (typeof col === 'object' ? col.texto : col) : '';
      h += '<td' + (d.num ? ' class="pz-num"' : '') + attr('data-rotulo', rot) + '>' +
           '<span>' + d.texto + '</span></td>';
    });

    /* el estado, en chip */
    if (f.estado) {
      var e = (typeof f.estado === 'object') ? f.estado : { texto: f.estado };
      var tono = e.tono ? ' pz-estado--' + e.tono : '';
      var chipEstado = '<span class="pz-estado' + tono + '">' + esc(e.texto) + '</span>';
      h += '<td class="pz-td-estado">' + chipEstado + '</td>';
      /* El pie de la ficha: el mismo chip a la izquierda y «Más
         detalles» a la derecha. En el escritorio no se ve, y lo que
         está en `display:none` tampoco lo lee un lector de pantalla,
         así que el estado no se dice dos veces. */
      h += '<td class="pz-td-pie">' + chipEstado + detallesHTML(f) + '</td>';
    } else if (tieneDetalles(f)) {
      h += '<td class="pz-td-pie"><span></span>' + detallesHTML(f) + '</td>';
    }

    /* UN SOLO «⋯» al final */
    if (f.menu && f.menu.length) {
      h += '<td class="pz-td-menu">' +
        '<button type="button" class="pz-mas" aria-haspopup="menu" aria-expanded="false"' +
        attr('data-pz-menu', 'pz-menu-' + id) +
        ' aria-label="Más acciones de ' + esc(f.principal) + '">' +
        /* «⋯» de verdad (U+22EF): tres puntos sueltos se ven caídos y
           desiguales según la letra que tenga cada ordenador. */
        '<span aria-hidden="true">⋯</span></button>' +
        menuHTML(id, f.menu) +
      '</td>';
    }

    return h + '</tr>';
  }

  function tieneDetalles(f) { return !!(f.celdas && f.celdas.length); }

  function detallesHTML(f) {
    if (!tieneDetalles(f)) return '<span></span>';
    return '<button type="button" class="pz-detalles" aria-expanded="false">' +
      '<span class="pz-detalles-txt">Más detalles</span>' + FLECHA + '</button>';
  }

  /* PZ.tabla({ columnas, filas, etiqueta })
     `columnas` admite texto suelto o { texto, ancho, num }. El ancho
     fijo es a propósito: si las columnas se recalculan al filtrar, la
     tabla salta y hay que volver a buscar dónde estaba cada cosa. */
  function tabla(o) {
    o = o || {};
    var columnas = o.columnas || [];
    var h = '<div class="pz-envoltorio">' +
      '<table class="pz-tabla"' + attr('aria-label', o.etiqueta) + '>';

    if (columnas.length) {
      h += '<colgroup>';
      columnas.forEach(function (c) {
        var a = (typeof c === 'object' && c.ancho) ? c.ancho : '';
        h += '<col' + (a ? ' style="width:' + esc(a) + '"' : '') + '>';
      });
      h += '</colgroup><thead><tr>';
      columnas.forEach(function (c) {
        var t = (typeof c === 'object') ? c.texto : c;
        var num = (typeof c === 'object' && c.num) ? ' class="pz-num"' : '';
        /* la columna del «⋯» no tiene nombre, pero sí lo tiene para
           quien navega con lector de pantalla */
        h += '<th scope="col"' + num + '>' + (t ? esc(t) : '<span class="pz-oculto">Acciones</span>') + '</th>';
      });
      h += '</tr></thead>';
    }

    h += '<tbody>';
    (o.filas || []).forEach(function (f) { h += fila(f, columnas); });
    return h + '</tbody></table></div>';
  }

  /* PZ.alPulsar(caja, fn) — una sola línea para escuchar todo lo que
     se pulse dentro: chips, botones de cabecera y opciones del «⋯».
     fn(accion, id, boton) */
  function alPulsar(caja, fn) {
    var c = nodo(caja) || document;
    c.addEventListener('click', function (e) {
      var b = e.target.closest ? e.target.closest('[data-pz-accion]') : null;
      if (!b || !c.contains(b)) return;
      cerrarTodo();
      fn(b.getAttribute('data-pz-accion'), b.getAttribute('data-pz-id'), b, e);
    });
  }

  /* PZ.editar(fila, sí/no) — la fila se tiñe, el aire baja y «Editar»
     pasa a «Hecho». Los campos los pone la pantalla con class="pz-editar". */
  function editar(f, si) {
    var tr = nodo(f);
    if (!tr) return;
    if (tr.tagName !== 'TR' && tr.closest) tr = tr.closest('tr');
    if (!tr) return;
    var abierto = (si == null) ? !tr.classList.contains('pz-editando') : !!si;
    tr.classList.toggle('pz-editando', abierto);
    Array.prototype.forEach.call(tr.querySelectorAll('[data-pz-accion="editar"]'), function (b) {
      b.textContent = abierto ? 'Hecho' : 'Editar';
    });
    if (abierto) {
      var primero = tr.querySelector('.pz-editar');
      if (primero) primero.focus();
    }
    return abierto;
  }

  /* ============================================================
     5 · CAMPO Y BLOQUE PLEGABLE
     ============================================================ */

  /* PZ.campo({ id, label, tipo, valor, ayuda, como, opciones, … })
     `ayuda` es la línea corta de debajo. `como` es la explicación
     larga: no se deja abierta ocupando pantalla, se pone tras un
     «¿Cómo funciona?» que abre encima cuando alguien pregunta. */
  function campo(o) {
    o = o || {};
    var id = o.id || ('pz-campo-' + (++contador));
    var tipo = o.tipo || 'text';
    var ayudaId = o.ayuda ? id + '-ayuda' : '';

    var control;
    if (tipo === 'textarea') {
      control = '<textarea' + attr('id', id) + attr('name', o.nombre || o.id) +
        attr('placeholder', o.placeholder) + attr('aria-describedby', ayudaId) +
        (o.requerido ? ' required' : '') + '>' + esc(o.valor) + '</textarea>';
    } else if (tipo === 'select') {
      control = '<select' + attr('id', id) + attr('name', o.nombre || o.id) +
        attr('aria-describedby', ayudaId) + (o.requerido ? ' required' : '') + '>' +
        (o.opciones || []).map(function (op) {
          var v = (typeof op === 'object') ? op.valor : op;
          var t = (typeof op === 'object') ? op.texto : op;
          return '<option' + attr('value', v) + (String(v) === String(o.valor) ? ' selected' : '') + '>' + esc(t) + '</option>';
        }).join('') + '</select>';
    } else {
      control = '<input' + attr('type', tipo) + attr('id', id) + attr('name', o.nombre || o.id) +
        attr('value', o.valor) + attr('placeholder', o.placeholder) +
        attr('aria-describedby', ayudaId) + (o.requerido ? ' required' : '') + '>';
    }

    var cartelId = id + '-como';
    return '<div class="pz-campo pz-como-caja">' +
      '<div class="pz-campo-lab">' +
        '<label for="' + esc(id) + '">' + esc(o.label) + '</label>' +
        (o.como
          ? '<button type="button" class="pz-como" aria-expanded="false" aria-controls="' + esc(cartelId) + '">¿Cómo funciona?</button>'
          : '') +
      '</div>' +
      (o.como
        ? '<div class="pz-cartel" id="' + esc(cartelId) + '" hidden role="dialog" aria-label="Cómo funciona">' +
            '<button type="button" class="pz-cartel-cerrar" aria-label="Cerrar">×</button>' +
            '<p>' + esc(o.como) + '</p></div>'
        : '') +
      control +
      (o.ayuda ? '<p class="pz-ayuda" id="' + esc(ayudaId) + '">' + esc(o.ayuda) + '</p>' : '') +
    '</div>';
  }

  /* PZ.plegable({ titulo, cuenta, cuerpo, abierto })
     Es un <details> de toda la vida: se abre sin JavaScript, el
     teclado lo entiende solo y el buscador del navegador encuentra
     lo de dentro. `cuenta` dice lo que hay dentro sin abrirlo. */
  function plegable(o) {
    o = o || {};
    return '<details class="pz-plegable"' + (o.abierto ? ' open' : '') + attr('id', o.id) + '>' +
      '<summary><span>' + esc(o.titulo) +
        (o.cuenta == null ? '' : ' <span class="pz-n">' + esc(o.cuenta) + '</span>') +
      '</span>' + FLECHA + '</summary>' +
      '<div class="pz-plegable-cuerpo">' + (o.cuerpo || '') + '</div>' +
    '</details>';
  }

  /* ============================================================
     6 · FRANJA DE GUARDADO
     No existe hasta que hay algo que guardar.
     ============================================================ */
  var CAMPOS = 'input, select, textarea';

  function valor(c) { return (c.type === 'checkbox' || c.type === 'radio') ? (c.checked ? '1' : '') : String(c.value); }

  /* PZ.franja({ raiz, guardar, descartar, texto })
     Con `raiz`, la franja se cuenta sola: guarda cómo estaba cada
     campo al empezar y compara. Es lo mismo que hace `admin-filtros.js`
     con los chips: la pantalla no tiene que llevar la cuenta a mano ni
     acordarse de avisar. Sin `raiz`, se lleva con franja.cambios(n). */
  function franja(o) {
    o = o || {};
    var raiz = o.raiz ? nodo(o.raiz) : null;
    var inicial = null;

    var barra = document.createElement('div');
    barra.className = 'pz-franja';
    barra.hidden = true;
    barra.setAttribute('role', 'status');
    barra.innerHTML =
      '<p class="pz-franja-txt"></p>' +
      '<div class="pz-franja-botones">' +
        '<button type="button" class="pz-descartar">Descartar</button>' +
        '<button type="button" class="pz-guardar">' + esc(o.textoGuardar || 'Guardar') + '</button>' +
      '</div>';
    document.body.appendChild(barra);

    var txt = barra.querySelector('.pz-franja-txt');
    var bGuardar = barra.querySelector('.pz-guardar');

    function foto() {
      if (!raiz) return null;
      var m = {};
      Array.prototype.forEach.call(raiz.querySelectorAll(CAMPOS), function (c, i) {
        m[c.id || c.name || ('c' + i)] = valor(c);
      });
      return m;
    }

    function cuenta() {
      if (!raiz || !inicial) return 0;
      var n = 0;
      Array.prototype.forEach.call(raiz.querySelectorAll(CAMPOS), function (c, i) {
        var k = c.id || c.name || ('c' + i);
        if (inicial[k] !== undefined && inicial[k] !== valor(c)) n++;
      });
      return n;
    }

    function pintar(n) {
      if (!n) {
        barra.hidden = true;
        document.body.classList.remove('pz-con-franja');
        return;
      }
      txt.textContent = o.texto ? o.texto(n) : (plural(n, 'cambio', 'cambios') + ' sin guardar');
      barra.hidden = false;
      document.body.classList.add('pz-con-franja');
    }

    function repasar() { pintar(cuenta()); }

    if (raiz) {
      inicial = foto();
      raiz.addEventListener('input', repasar);
      raiz.addEventListener('change', repasar);
    }

    barra.querySelector('.pz-descartar').addEventListener('click', function () {
      if (raiz && inicial) {
        /* Devolver cada campo a como estaba y avisar a la pantalla con
           los mismos eventos que si lo hubiera tocado una persona: así
           lo que dependa de un campo se entera sin cambiar nada. */
        Array.prototype.forEach.call(raiz.querySelectorAll(CAMPOS), function (c, i) {
          var k = c.id || c.name || ('c' + i);
          if (inicial[k] === undefined) return;
          if (c.type === 'checkbox' || c.type === 'radio') c.checked = (inicial[k] === '1');
          else c.value = inicial[k];
          c.dispatchEvent(new Event('input', { bubbles: true }));
          c.dispatchEvent(new Event('change', { bubbles: true }));
        });
      }
      if (typeof o.descartar === 'function') o.descartar();
      pintar(0);
    });

    bGuardar.addEventListener('click', function () {
      if (typeof o.guardar !== 'function') { pintar(0); return; }
      bGuardar.disabled = true;
      var fin = function (bien) {
        bGuardar.disabled = false;
        if (bien !== false) { inicial = foto(); pintar(0); }
      };
      var r = o.guardar(fin);
      /* si la pantalla devuelve una promesa, no hace falta que llame a fin() */
      if (r && typeof r.then === 'function') r.then(function () { fin(true); }, function () { fin(false); });
    });

    var api = {
      cambios: function (n) { pintar(n || 0); return api; },
      repasar: repasar,
      /* vuelve a tomar la foto: se usa después de recargar los datos */
      partirDeCero: function () { inicial = foto(); pintar(0); return api; },
      quitar: function () {
        barra.remove();
        document.body.classList.remove('pz-con-franja');
      },
      nodo: barra
    };
    return api;
  }

  /* ============================================================
     El poco comportamiento que tienen las piezas.
     Un solo oyente para toda la página, como hace `ADM` con el
     botón de reintentar: así funciona también con lo que se pinta
     después de cargar los datos.
     ============================================================ */
  function cerrarTodo(menos) {
    Array.prototype.forEach.call(document.querySelectorAll('.pz-menu:not([hidden])'), function (m) {
      if (m === menos) return;
      m.hidden = true;
      var b = document.querySelector('[data-pz-menu="' + m.id + '"]');
      if (b) b.setAttribute('aria-expanded', 'false');
    });
    Array.prototype.forEach.call(document.querySelectorAll('.pz-cartel:not([hidden])'), function (c) {
      if (c === menos) return;
      c.hidden = true;
      var b = document.querySelector('[aria-controls="' + c.id + '"]');
      if (b) b.setAttribute('aria-expanded', 'false');
    });
  }

  document.addEventListener('click', function (e) {
    var t = e.target;
    if (!t || !t.closest) return;

    /* «Más detalles ▾» de la ficha de móvil */
    var d = t.closest('.pz-detalles');
    if (d) {
      var tr = d.closest('tr');
      var abierta = tr.classList.toggle('pz-abierta');
      d.setAttribute('aria-expanded', abierta ? 'true' : 'false');
      var et = d.querySelector('.pz-detalles-txt');
      if (et) et.textContent = abierta ? 'Menos detalles' : 'Más detalles';
      return;
    }

    /* el «⋯» de la fila */
    var m = t.closest('[data-pz-menu]');
    if (m) {
      var caja = document.getElementById(m.getAttribute('data-pz-menu'));
      if (caja) {
        var abrir = caja.hidden;
        cerrarTodo(caja);
        caja.hidden = !abrir;
        m.setAttribute('aria-expanded', abrir ? 'true' : 'false');
        if (abrir) colocar(caja, m);
      }
      return;
    }

    /* «¿Cómo funciona?» */
    var c = t.closest('.pz-como');
    if (c) {
      var cartel = document.getElementById(c.getAttribute('aria-controls'));
      if (cartel) {
        var ab = cartel.hidden;
        cerrarTodo(cartel);
        cartel.hidden = !ab;
        c.setAttribute('aria-expanded', ab ? 'true' : 'false');
        if (ab) encima(cartel, c);
      }
      return;
    }

    if (t.closest('.pz-cartel-cerrar')) { cerrarTodo(); return; }

    /* fuera de un menú abierto: se cierra */
    if (!t.closest('.pz-menu') && !t.closest('.pz-cartel')) cerrarTodo();
  });

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') cerrarTodo();
  });

  /* El menú se coloca pegado a su «⋯», y si no cabe por abajo sale
     hacia arriba: en una tabla larga la última fila queda al borde. */
  function colocar(caja, boton) {
    caja.style.top = '';
    caja.style.bottom = '';
    caja.style.right = '';
    caja.style.left = '';
    var r = boton.getBoundingClientRect();
    /* Se mide el menú de verdad, no un número a ojo: uno de seis opciones
       mide el doble que uno de dos, y con 200 fijos el último se salía por
       debajo de la pantalla. */
    var alto = caja.offsetHeight || 200;
    var cabe = (window.innerHeight - r.bottom) > (alto + 16);
    caja.style.right = '0';
    if (cabe) caja.style.top = (boton.offsetTop + boton.offsetHeight + 4) + 'px';
    else caja.style.bottom = (boton.offsetHeight + 4) + 'px';
    var primera = caja.querySelector('button, a');
    if (primera) primera.focus();
  }

  /* «¿Cómo funciona?» abre ENCIMA del campo, no debajo: si abre
     debajo tapa justo el campo del que habla. */
  function encima(cartel, boton) {
    cartel.style.top = '';
    cartel.style.bottom = '';
    var caja = boton.closest('.pz-como-caja');
    if (!caja) return;
    var r = caja.getBoundingClientRect();
    if (r.top > 220) cartel.style.bottom = (caja.offsetHeight - boton.offsetTop + 6) + 'px';
    else cartel.style.top = (boton.offsetTop + boton.offsetHeight + 6) + 'px';
  }

  /* ---------- lo que se ofrece a las pantallas ---------- */
  window.PZ = {
    cabecera: cabecera,
    boton:    botonHTML,
    filtros:  filtros,
    chip:     chip,
    tabla:    tabla,
    fila:     fila,
    campo:    campo,
    plegable: plegable,
    franja:   franja,
    editar:   editar,
    alPulsar: alPulsar,
    esc:      esc
  };
})();
