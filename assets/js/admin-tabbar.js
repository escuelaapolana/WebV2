/* ============================================================
   BARRA INFERIOR DEL PANEL · Club Atletismo Apolana
   ------------------------------------------------------------
   En el móvil, para cambiar de sección del panel había que
   volver atrás al panel y abrir el menú. Esta barra pone las
   cuatro pantallas del día a día siempre a mano y deja el resto
   del panel a un toque, en «Menú».

       Inicio · Pista · Personas · Dinero · Menú

   Mismo aspecto que la barra del portal (assets/js/portal-tabbar.js):
   - Iconos de línea de 24 px, trazo único de 1,9 px, sin relleno.
   - El activo se distingue por COLOR (#2F6FA8 sobre #6E6656),
     nunca por una píldora de fondo ni engordando el trazo.
   - Etiquetas de 13 px y objetivos táctiles de 48 px.
   - Respeta el hueco de los móviles con barra de gestos.

   Solo aparece en móvil (≤760 px) y solo con la sesión de
   administración ya abierta. Si la página se pinta su propia
   barra (`.tabbar`, como «En la pista»), este componente se
   aparta y no pinta nada.
   ============================================================ */
(function () {
  'use strict';

  var ALTO = 78;   /* hueco que se reserva al final del contenido */

  if (location.pathname.indexOf('/admin/') === -1) return;

  function base() { return window.APOLANA_BASE || '../../'; }
  function raiz() { return base() + 'admin/'; }

  /* ---------- iconos (línea de 24 px, sin relleno) ---------- */
  function svg(p) {
    return '<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
           'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>';
  }
  var IC = {
    inicio:   svg('<path d="M3 10.5L12 3l9 7.5"/><path d="M5.5 9.5V20h13V9.5"/>'),
    pista:    svg('<circle cx="12" cy="13.5" r="7.5"/><path d="M12 13.5V9M9.5 2h5M18.5 7l1.5-1.5"/>'),
    personas: svg('<circle cx="9" cy="8" r="3.3"/><path d="M2.8 20c0-3.4 2.8-5.5 6.2-5.5s6.2 2.1 6.2 5.5"/><path d="M16.5 5.6a3.3 3.3 0 0 1 0 6.3M18 14.9c2 .7 3.3 2.4 3.3 4.6"/>'),
    dinero:   svg('<rect x="2.5" y="5.5" width="19" height="13" rx="2.5"/><circle cx="12" cy="12" r="2.6"/><path d="M6 12h.01M18 12h.01"/>'),
    menu:     '<svg class="ic" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' +
              '<circle cx="5" cy="12" r="1.9"/><circle cx="12" cy="12" r="1.9"/><circle cx="19" cy="12" r="1.9"/></svg>'
  };

  /* ---------- estilos ---------- */
  var css = document.createElement('style');
  css.textContent =
    '.at-tabbar,.at-hoja,.at-fondo{display:none}' +
    '@media (max-width:760px){' +
      /* hueco al final del contenido para que la barra no tape nada */
      'body.at-con-tabbar{padding-bottom:calc(' + ALTO + 'px + env(safe-area-inset-bottom))}' +
      '.at-tabbar{display:flex;align-items:stretch;position:fixed;left:0;right:0;bottom:0;z-index:600;' +
        'box-sizing:border-box;max-width:100%;' +
        'background:rgba(255,255,255,.97);-webkit-backdrop-filter:saturate(1.3) blur(10px);backdrop-filter:saturate(1.3) blur(10px);' +
        'border-top:1px solid var(--linea,#EAE3D5);' +
        'padding:10px 6px calc(10px + env(safe-area-inset-bottom))}' +
      '.at-tabbar a,.at-tabbar button{flex:1 1 0;min-width:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;' +
        'min-height:48px;padding:0 2px;text-decoration:none;color:var(--texto-suave,#6E6656);' +
        'background:none;border:0;cursor:pointer;' +
        'font-family:inherit;font-size:13px;font-weight:400;line-height:1.2;letter-spacing:normal;text-transform:none;' +
        '-webkit-tap-highlight-color:transparent}' +
      '.at-tabbar span{display:block;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.at-tabbar .ic{width:24px;height:24px;flex:0 0 24px}' +
      /* el activo cambia de color, nunca de grosor de trazo */
      '.at-tabbar .activo{color:var(--azul-oscuro,#2F6FA8)}' +
      '.at-tabbar .activo span{font-weight:600}' +

      /* --- hoja con todas las secciones --- */
      '.at-fondo{display:block;position:fixed;inset:0;z-index:700;background:rgba(46,66,86,.45);' +
        'opacity:0;transition:opacity .18s ease}' +
      '.at-fondo.ver{opacity:1}' +
      '.at-hoja{display:flex;flex-direction:column;position:fixed;left:0;right:0;bottom:0;z-index:701;' +
        'box-sizing:border-box;max-width:100%;max-height:82vh;' +
        'background:var(--crema,#FBF9F4);border-top-left-radius:14px;border-top-right-radius:14px;' +
        'box-shadow:0 -20px 44px -22px rgba(46,66,86,.55);' +
        'transform:translateY(100%);transition:transform .22s ease}' +
      '.at-hoja.ver{transform:none}' +
      '.at-hoja .cab{flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;gap:12px;' +
        'padding:14px 18px 10px;border-bottom:1px solid var(--linea,#EAE3D5)}' +
      '.at-hoja .cab h2{margin:0;font-family:var(--fuente-titulo,inherit);text-transform:uppercase;' +
        'font-size:21px;line-height:1.1;color:var(--navy,#2E4256)}' +
      '.at-hoja .cerrar{flex:0 0 auto;min-height:44px;min-width:44px;border:0;background:none;cursor:pointer;' +
        'font-size:15px;font-family:inherit;color:var(--texto-suave,#5E5849);padding:0 6px;' +
        '-webkit-tap-highlight-color:transparent}' +
      '.at-hoja .cuerpo{flex:1 1 auto;overflow-y:auto;-webkit-overflow-scrolling:touch;' +
        'padding:6px 18px calc(20px + env(safe-area-inset-bottom))}' +
      '.at-hoja .grupo{margin-top:14px}' +
      /* rótulo de bloque: 13 px, minúscula y sin espaciado (kit, punto 0) */
      '.at-hoja .grupo h3{margin:0 0 6px;font-family:inherit;font-size:13px;font-weight:600;' +
        'letter-spacing:normal;text-transform:none;color:var(--texto-suave,#6E6656)}' +
      '.at-hoja .enlaces{display:grid;grid-template-columns:1fr 1fr;gap:8px}' +
      '.at-hoja .enlaces a{display:flex;align-items:center;min-height:48px;box-sizing:border-box;' +
        'padding:10px 12px;border:1px solid var(--linea-marcada,#E4DCCB);border-radius:10px;background:#fff;' +
        'text-decoration:none;color:var(--navy,#2E4256);font-size:15px;line-height:1.25;' +
        '-webkit-tap-highlight-color:transparent}' +
      '.at-hoja .enlaces a.aqui{border-color:var(--azul-oscuro,#2F6FA8);color:var(--azul-oscuro,#2F6FA8);font-weight:600}' +
      '.at-hoja .enlaces a.ancho{grid-column:1 / -1}' +
      'body.at-hoja-abierta{overflow:hidden}' +
      /* el aviso queda 16 px por encima de la barra de pestañas (kit 30g) */
      'body.at-con-tabbar .apx-host{bottom:calc(16px + ' + ALTO + 'px + env(safe-area-inset-bottom))}' +
    '}';
  document.head.appendChild(css);

  /* ---------- pestañas ---------- */
  function pestanas() {
    var r = raiz();
    return [
      { id: 'inicio',   txt: 'Inicio',   ic: IC.inicio,   url: r },
      { id: 'pista',    txt: 'Pista',    ic: IC.pista,    url: r + 'campo/' },
      { id: 'personas', txt: 'Personas', ic: IC.personas, url: r + 'atletas/' },
      { id: 'dinero',   txt: 'Dinero',   ic: IC.dinero,   url: r + 'cobros/' }
    ];
  }

  /* Todas las secciones del panel, agrupadas igual que la barra lateral. */
  function bloques() {
    var r = raiz();
    return [
      { t: '', enlaces: [
        { txt: 'Inicio del panel', url: r, ancho: true },
        { txt: 'En la pista', url: r + 'campo/', ancho: true }
      ] },
      { t: 'Personas', enlaces: [
        { txt: 'Atletas', url: r + 'atletas/' },
        { txt: 'Importar personas', url: r + 'importar/' },
        { txt: 'Grupos', url: r + 'grupos/' },
        { txt: 'Usuarios y permisos', url: r + 'usuarios/' }
      ] },
      { t: 'Dinero', enlaces: [
        { txt: 'Cobros y recibos', url: r + 'cobros/' },
        { txt: 'Tarifas', url: r + 'tarifas/' },
        { txt: 'Pedidos de ropa', url: r + 'pedidos/' },
        { txt: 'Pagos con tarjeta', url: r + 'pagos-online/' }
      ] },
      { t: 'Análisis de datos', enlaces: [
        { txt: 'Estadísticas del club', url: r + 'estadisticas/' },
        { txt: 'Informes y datos', url: r + 'informes/' },
        { txt: 'Histórico de la escuela', url: r + 'historico/' }
      ] },
      { t: 'Actividad', enlaces: [
        { txt: 'Calendario y eventos', url: r + 'eventos/' },
        { txt: 'Competiciones', url: r + 'competiciones/' },
        { txt: 'Liga Apolana', url: r + 'liga/' },
        { txt: 'Retos y medallas', url: r + 'retos/' },
        { txt: 'El Cubo', url: r + 'cubo/' },
        { txt: 'Batería de tests', url: r + 'tests/' },
        { txt: 'Catálogo de pruebas', url: r + 'pruebas/' }
      ] },
      { t: 'La web', enlaces: [
        { txt: 'Noticias', url: r + '#noticias' },
        { txt: 'Avisos de portada', url: r + '#avisos' },
        { txt: 'Tienda', url: r + '#tienda' },
        { txt: 'Páginas', url: r + 'paginas/' },
        { txt: 'Textos de las páginas', url: r + 'contenido/' },
        { txt: 'Fotos de la web', url: r + 'imagenes/' },
        { txt: 'Biblioteca de fotos', url: r + 'biblioteca/' },
        { txt: 'Colaboradores', url: r + 'colaboradores/' },
        { txt: 'Documentos', url: r + 'documentos/' },
        { txt: 'Peticiones de redes', url: r + 'redes/' },
        { txt: 'Mapa de contenido', url: r + 'mapa/' }
      ] },
      { t: 'Club', enlaces: [
        { txt: 'Buzón', url: r + '#buzon' },
        { txt: 'Plantillas de email', url: r + 'plantillas/' },
        { txt: 'Récords', url: r + 'records/' },
        { txt: 'Palmarés', url: r + 'palmares/' }
      ] }
    ];
  }

  /* ---------- en qué página estamos ---------- */
  function carpeta() {
    /* «/admin/cobros/index.html» → «cobros»; «/admin/» → «» */
    var r = location.pathname.replace(/\/[^/]*\.html?$/, '/');
    var i = r.lastIndexOf('/admin/');
    if (i === -1) return '';
    return r.slice(i + 7).replace(/\/+$/, '');
  }
  function activa() {
    var c = carpeta();
    if (c === '') return 'inicio';
    if (c === 'campo') return 'pista';
    if (c === 'atletas') return 'personas';
    if (c === 'cobros') return 'dinero';
    return 'menu';   /* el resto del panel se abre desde «Menú» */
  }

  function esc(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  /* ---------- la hoja con todo el panel ---------- */
  var fondo = null, hoja = null, abierta = false, ultimoFoco = null, botonMenu = null;

  function avisarBoton() {
    if (botonMenu) botonMenu.setAttribute('aria-expanded', abierta ? 'true' : 'false');
  }

  function crearHoja() {
    if (hoja) return;
    var aqui = carpeta();

    fondo = document.createElement('div');
    fondo.className = 'at-fondo';
    fondo.hidden = true;

    hoja = document.createElement('div');
    hoja.className = 'at-hoja';
    hoja.setAttribute('role', 'dialog');
    hoja.setAttribute('aria-modal', 'true');
    hoja.setAttribute('aria-label', 'Todas las secciones del panel');
    hoja.hidden = true;

    var html = '<div class="cab"><h2>Todo el panel</h2>' +
               '<button type="button" class="cerrar">Cerrar</button></div><div class="cuerpo">';
    bloques().forEach(function (b) {
      html += '<div class="grupo">';
      if (b.t) html += '<h3>' + esc(b.t) + '</h3>';
      html += '<div class="enlaces">';
      b.enlaces.forEach(function (e) {
        var m = e.url.match(/admin\/([^#]*)$/);
        var carp = m ? m[1].replace(/\/+$/, '') : null;
        var clases = [];
        if (e.ancho) clases.push('ancho');
        if (e.url.indexOf('#') === -1 && carp === aqui) clases.push('aqui');
        html += '<a href="' + esc(e.url) + '"' +
                (clases.length ? ' class="' + clases.join(' ') + '"' : '') +
                '>' + esc(e.txt) + '</a>';
      });
      html += '</div></div>';
    });
    html += '</div>';
    hoja.innerHTML = html;

    document.body.appendChild(fondo);
    document.body.appendChild(hoja);

    fondo.addEventListener('click', cerrar);
    hoja.querySelector('.cerrar').addEventListener('click', cerrar);
  }

  function abrir() {
    crearHoja();
    if (abierta) return;
    abierta = true;
    ultimoFoco = document.activeElement;
    fondo.hidden = false;
    hoja.hidden = false;
    document.body.classList.add('at-hoja-abierta');
    avisarBoton();
    /* un cuadro de espera para que la transición se vea */
    requestAnimationFrame(function () {
      fondo.classList.add('ver');
      hoja.classList.add('ver');
    });
    var primero = hoja.querySelector('.cerrar');
    if (primero) primero.focus();
  }

  function cerrar() {
    if (!abierta) return;
    abierta = false;
    fondo.classList.remove('ver');
    hoja.classList.remove('ver');
    document.body.classList.remove('at-hoja-abierta');
    avisarBoton();
    setTimeout(function () {
      if (abierta) return;
      fondo.hidden = true;
      hoja.hidden = true;
    }, 220);
    if (ultimoFoco && ultimoFoco.focus) ultimoFoco.focus();
  }

  document.addEventListener('keydown', function (e) {
    if (abierta && (e.key === 'Escape' || e.key === 'Esc')) { e.preventDefault(); cerrar(); }
  });

  /* ---------- pintado ---------- */
  var nodo = null;
  function pintar() {
    if (nodo) return;
    /* La página se pinta su propia barra («En la pista»): no ponemos otra. */
    if (document.querySelector('.tabbar')) return;

    var act = activa();
    var html = pestanas().map(function (t) {
      return '<a href="' + t.url + '"' + (t.id === act ? ' class="activo" aria-current="page"' : '') + '>' +
             t.ic + '<span>' + t.txt + '</span></a>';
    }).join('');
    html += '<button type="button" class="at-menu' + (act === 'menu' ? ' activo' : '') + '" ' +
            'aria-haspopup="dialog" aria-expanded="false">' + IC.menu + '<span>Menú</span></button>';

    nodo = document.createElement('nav');
    nodo.className = 'at-tabbar';
    nodo.setAttribute('aria-label', 'Secciones del panel');
    nodo.innerHTML = html;
    document.body.appendChild(nodo);
    document.body.classList.add('at-con-tabbar');

    botonMenu = nodo.querySelector('.at-menu');
    botonMenu.addEventListener('click', function () {
      if (abierta) cerrar(); else abrir();
    });
  }

  /* ---------- arranque ----------
     La barra solo aparece con la sesión de administración abierta: la
     señal es la barra superior que pinta admin-auth.js cuando ya se ha
     comprobado que quien entra es del equipo. */
  function arrancar() {
    var t0 = Date.now();
    (function mira() {
      /* En las subpáginas la señal es la barra de admin-auth.js (.adm-top);
         en el inicio del panel, su propia barra (.admin-top) al dejar de
         estar oculta. Cualquiera de las dos significa "sesión abierta". */
      var propia = document.querySelector('.admin-top');
      if (document.querySelector('.adm-top') ||
          (propia && !propia.classList.contains('oculto'))) { pintar(); return; }
      if (Date.now() - t0 > 20000) return;   /* sin sesión: no se pinta nada */
      setTimeout(mira, 120);
    })();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', arrancar);
  } else {
    arrancar();
  }
})();


/* ============================================================
   PIEL DEL PANEL · Club Atletismo Apolana
   ------------------------------------------------------------
   Las reglas del kit v3 (Fundamentos 28a-28g + Kit 30a-30i) que
   valen para las 26 pantallas del panel, en un solo sitio:

     · rótulos de 13 px, minúscula y sin espaciado
     · tres radios (14 contenedor · 10 contenido · 999 píldora)
     · tablas sin líneas verticales ni filas alternas
     · por debajo de 720 px la tabla es ficha, nunca se arrastra
     · más de 20 filas: «Ver más». Más de 30: buscador
     · los cuatro estados: esqueleto, vacío, con datos y error
     · un solo sistema de avisos, el de la app (navy, abajo)

   Se pinta al terminar de leer la página, así que va después de
   los estilos propios de cada pantalla y manda sobre ellos.
   ============================================================ */
(function () {
  'use strict';
  if (location.pathname.indexOf('/admin/') === -1) return;

  var P = 'body.adm-piel ';   /* prefijo: gana a los estilos de cada página */

  var CSS = [
    /* --- tres radios y ni uno más (kit 30b) --- */
    'body.adm-piel{--radio:14px;--radio-grande:14px}',

    /* --- rótulos: 13 px, minúscula, sin espaciado (fundamentos, punto 0) --- */
    P + 'table th{font-family:var(--fuente-texto);font-size:13px;font-weight:600;line-height:1.4;' +
      'letter-spacing:normal;text-transform:none;color:var(--texto-suave)}',
    P + '.et,' + P + '.cuenta,' + P + '.eyebrow,' + P + '.eyebrow-mono,' + P + '.paso,' + P + '.t-lab{' +
      'font-family:var(--fuente-texto);font-size:13px;letter-spacing:normal;text-transform:none;color:var(--texto-suave)}',
    P + '.pill,' + P + '.pill-estado,' + P + '.chip,' + P + '.etq,' + P + '.pastilla,' + P + '.chip-var,' + P + '.chip-g{' +
      'font-size:13px;letter-spacing:normal;text-transform:none}',
    P + 'td::before{font-size:13px;letter-spacing:normal;text-transform:none;color:var(--texto-suave)}',

    /* --- tabla de escritorio: separadores horizontales y nada más (kit 30e) --- */
    P + 'table td,' + P + 'table th{border-left:0;border-right:0}',
    /* en el panel caben tablas densas: el botón manda su altura, no el aire */
    P + 'table tbody td{padding-top:6px;padding-bottom:6px}',
    P + 'table tbody tr:nth-child(even){background:none}',
    P + 'td.num,' + P + 'td.importe,' + P + 'td.dato{text-align:right;font-family:var(--fuente-dato);' +
      'font-variant-numeric:tabular-nums;white-space:nowrap}',
    P + 'th.num{text-align:right;font-family:var(--fuente-texto)}',

    /* --- zona pulsable de 44 px con letra de 15: crece el relleno --- */
    P + '.btn,' + P + '.bmini,' + P + '.chip,' + P + '.toggle,' + P + '.btn--mini{min-height:44px;' +
      'display:inline-flex;align-items:center;justify-content:center}',
    /* tres niveles de botón y ni uno más (kit 30f) */
    P + '.btn--fantasma,' + P + '.bmini,' + P + '.toggle{border-color:#C9C0AE;color:var(--navy)}',
    /* chips: el activo relleno navy, el resto con borde */
    P + '.chip{border:1px solid var(--linea-borde,#D4CBB9);background:#fff;color:var(--texto)}',
    P + '.chip.activo,' + P + '.chip[aria-selected="true"],' + P + '.chip.sel{' +
      'background:var(--navy);border-color:var(--navy);color:#fff}',

    /* --- 1 · cargando: bloques con la forma del dato, nunca «Cargando…» en gris --- */
    '@keyframes adm-brillo{0%{background-position:200% 0}100%{background-position:-200% 0}}',
    '.adm-esq{display:block;height:12px;border-radius:999px;margin:9px 0;' +
      'background:linear-gradient(90deg,#EFE9DC 25%,#F7F3EA 50%,#EFE9DC 75%);background-size:200% 100%;' +
      'animation:adm-brillo 1.25s linear infinite}',
    '.adm-esq--corto{width:38%}.adm-esq--medio{width:64%}.adm-esq--largo{width:86%}',
    '.adm-cargando{padding:4px 0}',
    '@media (prefers-reduced-motion:reduce){.adm-esq{animation:none}}',

    /* --- 2 · vacío: se explica y se ofrece algo que hacer, nunca un guión --- */
    '.adm-vacio{text-align:center;padding:28px 18px;max-width:46ch;margin-inline:auto}',
    '.adm-vacio svg{display:block;margin:0 auto 12px;color:var(--texto-suave)}',
    '.adm-vacio .adm-vacio-tit{font-family:var(--fuente-texto);font-size:17px;font-weight:600;' +
      'color:var(--navy);margin:0 0 4px;line-height:1.35}',
    '.adm-vacio .adm-vacio-txt{font-size:15px;line-height:1.5;color:var(--texto-suave);margin:0 0 14px}',

    /* --- 4 · error: ámbar, nunca rojo, y siempre con reintentar --- */
    '.adm-error{display:flex;flex-wrap:wrap;align-items:center;gap:10px 14px;text-align:left;' +
      'background:var(--ambar-fondo,#FDF3E3);border:1px solid var(--ambar-borde,#EBD9B8);' +
      'border-radius:14px;padding:14px 16px;margin:8px 0}',
    '.adm-error .adm-error-txt{flex:1 1 240px;min-width:0;font-size:15px;line-height:1.45;color:var(--texto)}',
    '.adm-error .adm-error-txt b{display:block;color:var(--ambar,#B96F09);font-weight:600}',
    '.adm-error button{flex:0 0 auto;min-height:44px;padding:10px 20px;border-radius:999px;cursor:pointer;' +
      'border:1px solid #C9C0AE;background:#fff;color:var(--navy);font-family:inherit;font-size:15px}',
    '.adm-error button:hover{background:var(--crema,#FBF9F4)}',

    /* --- 3 · con datos: veinte filas, «Ver más» y buscador a partir de treinta --- */
    '.adm-mas{display:flex;justify-content:center;margin:12px 0 2px}',
    '.adm-mas button{min-height:44px;padding:11px 22px;border-radius:999px;cursor:pointer;' +
      'border:1px solid #C9C0AE;background:#fff;color:var(--navy);font-family:inherit;font-size:15px}',
    '.adm-mas button:hover{background:var(--crema,#FBF9F4)}',
    '.adm-buscador{display:flex;align-items:center;gap:8px;margin:0 0 10px}',
    '.adm-buscador input{flex:1 1 260px;max-width:340px;min-height:44px;box-sizing:border-box;' +
      'padding:11px 14px;border:1px solid var(--linea-borde,#D4CBB9);border-radius:10px;' +
      'font-family:inherit;font-size:15px;color:var(--navy);background:#fff}',
    '.adm-buscador .adm-buscador-n{font-size:13px;color:var(--texto-suave);font-family:var(--fuente-dato)}',
    /* el recuento, al lado del título y en mono (kit 30h) */
    '.adm-cuenta-tit:not(:empty){font-family:var(--fuente-dato);font-size:14px;font-weight:400;' +
      'letter-spacing:normal;text-transform:none;color:var(--texto-suave);margin-left:11px;' +
      'vertical-align:baseline}',

    /* --- 5 · por debajo de 720 px la tabla es ficha: nunca se arrastra (kit 30e) --- */
    '@media (max-width:720px){',
    P + '.adm-envoltorio{overflow-x:visible!important;max-width:100%}',
    P + 'table.adm-tabla,' + P + 'table.adm-tabla tbody,' + P + 'table.adm-tabla tr,' +
      P + 'table.adm-tabla td{display:block;width:auto;min-width:0}',
    P + 'table.adm-tabla{min-width:0!important}',
    P + 'table.adm-tabla thead{display:none}',
    P + 'table.adm-tabla tbody tr{position:relative;border:1px solid var(--linea-marcada,#E4DCCB);' +
      'border-radius:14px;background:#fff;margin:0 0 12px;padding:13px 16px}',
    P + 'table.adm-tabla tbody td{border:0;padding:2px 0;font-size:15px;line-height:1.4}',
    P + 'table.adm-tabla tbody td:empty{display:none}',
    /* el resto de columnas, en una línea de datos: rótulo y valor seguidos */
    P + 'table.adm-tabla tbody td::before{content:attr(data-etiqueta);display:inline;font-size:13px;' +
      'color:var(--texto-suave);margin-right:7px}',
    P + 'table.adm-tabla tbody td.sin-etiqueta::before,' +
      P + 'table.adm-tabla tbody td[data-etiqueta=""]::before{content:none}',
    /* la columna que más dice hace de título de la ficha */
    P + 'table.adm-tabla tbody td.adm-titulo{font-size:17px;font-weight:600;color:var(--navy);' +
      'padding:0 92px 5px 0;line-height:1.3}',
    P + 'table.adm-tabla tbody td.adm-titulo::before{content:none}',
    /* y el estado, arriba a la derecha */
    P + 'table.adm-tabla tbody td.adm-estado{position:absolute;top:12px;right:14px;padding:0;' +
      'max-width:88px;text-align:right}',
    P + 'table.adm-tabla tbody td.adm-estado::before{content:none}',
    P + 'table.adm-tabla tbody td.adm-acciones{display:flex;flex-wrap:wrap;gap:8px;padding-top:9px}',
    '}',

    /* --- 7 · aviso unificado: el de la app, navy y abajo (kit 30g) --- */
    '.apx-host{position:fixed;left:0;right:auto;bottom:20px;z-index:9999;display:flex;' +
      'padding-left:24px;padding-right:24px;pointer-events:none}',
    '.apx{pointer-events:auto;display:flex;align-items:flex-start;gap:10px;max-width:min(420px,calc(100vw - 48px));' +
      'background:#2E4256;color:#fff;border-radius:14px;padding:13px 16px;font-size:15px;line-height:1.4;' +
      'box-shadow:0 18px 34px -20px rgba(46,66,86,.75);animation:adm-aviso-sube .18s ease}',
    '@keyframes adm-aviso-sube{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}',
    '.apx .apx-ic{flex:0 0 20px;width:20px;height:20px;margin-top:1px}',
    '.apx .apx-txt{flex:1 1 auto;min-width:0}',
    '.apx button{flex:0 0 auto;margin:-4px -6px -4px 4px;padding:6px 10px;min-height:32px;border:0;' +
      'background:none;color:#9FC7E8;font-family:inherit;font-size:15px;font-weight:600;cursor:pointer;' +
      'border-radius:999px}',
    '.apx button:hover{background:rgba(255,255,255,.12);color:#fff}',
    '@media (max-width:760px){.apx-host{left:0;right:0;justify-content:center;padding-left:16px;padding-right:16px}',
      '.apx{max-width:100%;width:100%}}',
    '@media (prefers-reduced-motion:reduce){.apx{animation:none}}',

    /* la ventana de confirmar comparte radios y botones con el resto */
    '.apo-modal{border-radius:14px}',
    '.apo-modal-botones button{min-height:44px;border-radius:999px}'
  ].join('\n');

  function ponerEstilos() {
    var s = document.createElement('style');
    s.setAttribute('data-piel', 'panel');
    s.textContent = CSS;
    document.head.appendChild(s);
    document.body.classList.add('adm-piel');
  }

  /* ---------- utilidades ---------- */
  function esc(s) {
    var d = document.createElement('div');
    d.textContent = (s == null ? '' : String(s));
    return d.innerHTML;
  }
  function icono(trazo, ancho) {
    return '<svg viewBox="0 0 24 24" width="34" height="34" fill="none" stroke="currentColor" ' +
      'stroke-width="' + (ancho || 1.9) + '" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
      trazo + '</svg>';
  }

  /* ============================================================
     Los cuatro estados
     ============================================================ */
  var ADM = {
    /* Esqueletos con la forma del dato: la página no salta al llegar. */
    esqueleto: function (lineas) {
      var n = lineas || 3, h = '';
      var anchos = ['adm-esq--largo', 'adm-esq--medio', 'adm-esq--corto'];
      for (var i = 0; i < n; i++) h += '<span class="adm-esq ' + anchos[i % 3] + '"></span>';
      return '<div class="adm-cargando" aria-live="polite" aria-label="Cargando">' + h + '</div>';
    },
    filaCargando: function (columnas, lineas) {
      return '<tr><td class="sin-etiqueta" colspan="' + (columnas || 1) + '">' +
        ADM.esqueleto(lineas || 3) + '</td></tr>';
    },
    /* Vacío: explica y ofrece algo que hacer. Nunca un guión ni un cero suelto. */
    vacio: function (titulo, texto, accion, trazo) {
      return '<div class="adm-vacio">' +
        (trazo ? icono(trazo) : '') +
        '<p class="adm-vacio-tit">' + esc(titulo) + '</p>' +
        (texto ? '<p class="adm-vacio-txt">' + esc(texto) + '</p>' : '') +
        (accion || '') + '</div>';
    },
    filaVacia: function (columnas, titulo, texto, accion, trazo) {
      return '<tr><td class="sin-etiqueta" colspan="' + (columnas || 1) + '">' +
        ADM.vacio(titulo, texto, accion, trazo) + '</td></tr>';
    },
    /* Error: ámbar, nunca rojo, y siempre con un botón de reintentar. */
    error: function (mensaje, reintentar) {
      var id = 'adm-rei-' + (++contador);
      if (typeof reintentar === 'function') reintentos[id] = reintentar;
      return '<div class="adm-error" role="alert"><div class="adm-error-txt">' +
        '<b>No hemos podido cargar esta parte</b>' + (mensaje ? esc(mensaje) : 'Puede ser la conexión.') +
        '</div><button type="button" data-adm-reintentar="' + id + '">Volver a intentarlo</button></div>';
    },
    filaError: function (columnas, mensaje, reintentar) {
      return '<tr><td class="sin-etiqueta" colspan="' + (columnas || 1) + '">' +
        ADM.error(mensaje, reintentar) + '</td></tr>';
    },
    /* Deja un elemento en estado «cargando» sin escribir «Cargando…» en gris. */
    cargando: function (el, lineas) {
      var n = (typeof el === 'string') ? document.getElementById(el) : el;
      if (n) n.innerHTML = ADM.esqueleto(lineas || 2);
    }
  };
  var reintentos = {}, contador = 0;

  document.addEventListener('click', function (e) {
    var b = e.target.closest ? e.target.closest('[data-adm-reintentar]') : null;
    if (!b) return;
    var f = reintentos[b.getAttribute('data-adm-reintentar')];
    if (typeof f === 'function') { b.disabled = true; f(); } else { location.reload(); }
  });

  window.ADM = ADM;

  /* Un esqueleto no se queda para siempre: a los dos segundos y medio se
     convierte en error, con su botón de volver a intentarlo (kit 28f). */
  var ESPERA = 2500;
  setInterval(function () {
    var ahora = Date.now();
    Array.prototype.forEach.call(document.querySelectorAll('.adm-cargando'), function (n) {
      if (!n.__desde) { n.__desde = ahora; return; }
      if (ahora - n.__desde < ESPERA) return;
      var caja = document.createElement('div');
      caja.innerHTML = ADM.error('Está tardando más de la cuenta. Puede ser la conexión.');
      n.replaceWith(caja.firstChild);
    });
  }, 1000);

  /* ============================================================
     Un solo sistema de avisos: el de la app (kit 30g)
     Navy, radio 14, uno a la vez. Abajo a la izquierda en el
     escritorio; abajo y sobre la barra, en el móvil.
     ============================================================ */
  var VISTO  = '<svg class="apx-ic" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4" ' +
               'stroke-linecap="round" stroke-linejoin="round"><path d="m5 12.5 4.5 4.5L19 7.5"/></svg>';
  var AVISO  = '<svg class="apx-ic" viewBox="0 0 24 24" fill="none" stroke="#F0B968" stroke-width="1.9" ' +
               'stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8.6"/>' +
               '<path d="M12 7.6v5"/><path d="M12 16.1h.01"/></svg>';

  var host = null, vivo = null, reloj = null;
  function hueco() {
    if (!host) {
      host = document.createElement('div');
      host.className = 'apx-host';
      host.setAttribute('aria-live', 'polite');
      document.body.appendChild(host);
    }
    return host;
  }
  function quitar() {
    if (reloj) { clearTimeout(reloj); reloj = null; }
    if (vivo && vivo.parentNode) vivo.parentNode.removeChild(vivo);
    vivo = null;
  }

  /* apoToast(mensaje, tipo, opciones)
       tipo: 'ok' | 'error' | 'info'
       opciones: { deshacer: fn, reintentar: fn }          */
  window.apoToast = function (mensaje, tipo, opciones) {
    tipo = tipo || 'info';
    opciones = opciones || {};
    quitar();                                  /* uno a la vez, nunca apilados */

    var esError = (tipo === 'error');
    var t = document.createElement('div');
    t.className = 'apx';
    t.setAttribute('role', esError ? 'alert' : 'status');
    t.innerHTML = (esError ? AVISO : (tipo === 'ok' ? VISTO : '')) +
      '<div class="apx-txt"></div>';
    t.querySelector('.apx-txt').textContent = mensaje;

    var extra = null, accion = null;
    if (esError && typeof opciones.reintentar === 'function') { extra = 'Reintentar'; accion = opciones.reintentar; }
    else if (!esError && typeof opciones.deshacer === 'function') { extra = 'Deshacer'; accion = opciones.deshacer; }
    if (extra) {
      var b = document.createElement('button');
      b.type = 'button';
      b.textContent = extra;
      b.addEventListener('click', function () { quitar(); accion(); });
      t.appendChild(b);
    }

    hueco().appendChild(t);
    vivo = t;
    /* La confirmación se va sola a los cuatro segundos; el error se queda
       hasta que se toca, que para eso hay algo que hacer. */
    if (esError) t.addEventListener('click', quitar);
    else reloj = setTimeout(quitar, 4000);
    return t;
  };

  /* La ventana de confirmar sigue siendo una ventana (no es un aviso):
     lo que cambia es que comparte radios, botones y colores. */
  window.apoConfirm = function (opciones) {
    opciones = opciones || {};
    return new Promise(function (resolve) {
      var fondo = document.createElement('div');
      fondo.className = 'apo-modal-fondo';
      var modal = document.createElement('div');
      modal.className = 'apo-modal';
      modal.setAttribute('role', 'dialog');
      modal.setAttribute('aria-modal', 'true');

      var h = document.createElement('h3');
      h.textContent = opciones.titulo || 'Confirmar';
      modal.appendChild(h);
      if (opciones.texto) {
        var p = document.createElement('p');
        p.textContent = opciones.texto;
        modal.appendChild(p);
      }
      var bots = document.createElement('div');
      bots.className = 'apo-modal-botones';
      var bc = document.createElement('button');
      bc.type = 'button'; bc.className = 'apo-btn-cancelar';
      bc.textContent = opciones.cancelar || 'Cancelar';
      var bo = document.createElement('button');
      bo.type = 'button';
      bo.className = 'apo-btn-ok' + (opciones.peligro ? ' apo-peligro' : '');
      bo.textContent = opciones.confirmar || (opciones.peligro ? 'Borrar' : 'Aceptar');
      bots.appendChild(bc); bots.appendChild(bo);
      modal.appendChild(bots);
      fondo.appendChild(modal);
      document.body.appendChild(fondo);

      var prev = document.activeElement;
      bo.focus();

      function cerrar(val) {
        document.removeEventListener('keydown', onKey, true);
        if (fondo.parentNode) fondo.parentNode.removeChild(fondo);
        if (prev && prev.focus) { try { prev.focus(); } catch (err) {} }
        resolve(val);
      }
      function onKey(e) {
        if (e.key === 'Escape') { e.preventDefault(); cerrar(false); }
        else if (e.key === 'Enter') { e.preventDefault(); cerrar(true); }
        else if (e.key === 'Tab') {
          var f = [bc, bo], i = f.indexOf(document.activeElement);
          e.preventDefault();
          var n = e.shiftKey ? (i <= 0 ? f.length - 1 : i - 1) : (i >= f.length - 1 ? 0 : i + 1);
          f[n].focus();
        }
      }
      document.addEventListener('keydown', onKey, true);
      bc.addEventListener('click', function () { cerrar(false); });
      bo.addEventListener('click', function () { cerrar(true); });
      fondo.addEventListener('click', function (e) { if (e.target === fondo) cerrar(false); });
    });
  };

  /* ============================================================
     Listas largas: ficha en móvil, «Ver más» y buscador
     ============================================================ */
  var TOPE = 20, DESDE_BUSCADOR = 30;

  function filasReales(tabla) {
    var tb = tabla.tBodies[0];
    if (!tb) return [];
    return Array.prototype.filter.call(tb.rows, function (f) {
      return f.cells.length > 1;   /* las filas de aviso llevan un solo hueco */
    });
  }

  /* Cuál es la columna que manda: la que lleva el nombre de la cosa. Si
     ninguna cabecera lo dice, la que trae más texto en la primera fila. */
  var MANDA = /(nombre|t[ií]tulo|atleta|socio|persona|concepto|prueba|grupo|carrera|evento|documento|p[áa]gina|plantilla|art[ií]culo|producto|noticia|foto)/i;

  function columnaTitulo(cab, fila) {
    for (var i = 0; i < cab.length; i++) if (MANDA.test(cab[i])) return i;
    var mejor = 0, largo = -1;
    Array.prototype.forEach.call(fila.cells, function (c, i) {
      var n = (c.textContent || '').trim().length;
      if (c.querySelector('button,input,a.btn')) return;   /* la de acciones no */
      if (n > largo) { largo = n; mejor = i; }
    });
    return mejor;
  }

  function etiquetar(tabla) {
    var cab = tabla.tHead && tabla.tHead.rows.length
      ? Array.prototype.map.call(tabla.tHead.rows[tabla.tHead.rows.length - 1].cells,
          function (c) { return (c.textContent || '').trim(); })
      : [];
    if (!cab.length) return;
    var filas = filasReales(tabla);
    if (!filas.length) return;
    var iTit = columnaTitulo(cab, filas[0]);
    filas.forEach(function (f) {
      Array.prototype.forEach.call(f.cells, function (c, i) {
        if (!c.hasAttribute('data-etiqueta') && cab[i]) c.setAttribute('data-etiqueta', cab[i]);
        if (i === iTit) { c.classList.add('adm-titulo'); return; }
        /* la pastilla de estado —solo esa— va arriba a la derecha */
        var soloPastilla = c.children.length === 1 &&
          /(^|\s)(pill|pill-estado|estado|etq|pastilla)(\s|$)/.test(c.children[0].className || '');
        if (soloPastilla && /estado|situaci|publicad|activ/i.test(cab[i] || '')) {
          c.classList.add('adm-estado');
          return;
        }
        if (c.querySelector('button,a.btn')) c.classList.add('adm-acciones');
      });
    });
  }

  function estado(tabla) {
    if (!tabla.__adm) tabla.__adm = { tope: TOPE, texto: '' };
    return tabla.__adm;
  }

  function repintar(tabla) {
    var e = estado(tabla);
    var filas = filasReales(tabla);
    var texto = e.texto.trim().toLowerCase();
    var vistas = 0, coinciden = 0;
    filas.forEach(function (f) {
      var vale = !texto || (f.textContent || '').toLowerCase().indexOf(texto) !== -1;
      if (!vale) { f.style.display = 'none'; return; }
      coinciden++;
      if (vistas < e.tope) { f.style.display = ''; vistas++; }
      else f.style.display = 'none';
    });

    /* «Ver más» */
    var mas = tabla.__mas;
    var restan = coinciden - vistas;
    if (restan > 0) {
      if (!mas) {
        mas = document.createElement('div');
        mas.className = 'adm-mas';
        mas.innerHTML = '<button type="button"></button>';
        mas.querySelector('button').addEventListener('click', function () {
          e.tope += TOPE;
          repintar(tabla);
        });
        (tabla.parentNode || tabla).insertBefore(mas, tabla.nextSibling);
        tabla.__mas = mas;
      }
      mas.style.display = '';
      mas.querySelector('button').textContent =
        'Ver ' + Math.min(TOPE, restan) + ' más  ·  quedan ' + restan;
    } else if (mas) {
      mas.style.display = 'none';
    }

    if (tabla.__cuenta) {
      tabla.__cuenta.textContent = texto ? (coinciden + ' de ' + filas.length) : (filas.length + '');
    }
    cuentaEnElTitulo(tabla, filas.length);
  }

  /* El recuento va al lado del título de la pantalla y en mono (kit 30h),
     no como una tarjeta aparte. Solo para la lista principal de la página. */
  var TITULO = null, YA_TITULO = false;
  function cuentaEnElTitulo(tabla, n) {
    if (!YA_TITULO) {
      YA_TITULO = true;
      var raiz = document.getElementById('admin-contenido') || document.body;
      TITULO = raiz.querySelector('.cab h1') || raiz.querySelector('h1') ||
               raiz.querySelector('.panel h2, .card h2, h2');
      if (TITULO) {
        var s = document.createElement('span');
        s.className = 'adm-cuenta-tit';
        TITULO.appendChild(s);
        TITULO.__cuenta = s;
        TITULO.__tabla = tabla;
      }
    }
    if (TITULO && TITULO.__cuenta && TITULO.__tabla === tabla) {
      TITULO.__cuenta.textContent = n ? String(n) : '';
    }
  }

  function buscador(tabla) {
    if (tabla.__buscador) return;
    /* si la pantalla ya trae su propio buscador, no ponemos otro */
    var caja = tabla.closest ? tabla.closest('.panel, section, .card, .caja, .admin-wrap') : null;
    if (caja && caja.querySelector('input[type="search"]')) { tabla.__buscador = true; return; }

    var b = document.createElement('div');
    b.className = 'adm-buscador';
    var i = document.createElement('input');
    i.type = 'search';
    i.placeholder = 'Buscar en la lista…';
    i.setAttribute('aria-label', 'Buscar en la lista');
    var n = document.createElement('span');
    n.className = 'adm-buscador-n';
    b.appendChild(i); b.appendChild(n);
    i.addEventListener('input', function () {
      var e = estado(tabla);
      e.texto = i.value;
      e.tope = TOPE;
      repintar(tabla);
    });
    var padre = tabla.parentNode;
    padre.insertBefore(b, tabla);
    tabla.__cuenta = n;
    tabla.__buscador = b;
  }

  function repasar(tabla) {
    if (!tabla.tHead || !tabla.tBodies.length) return;
    tabla.classList.add('adm-tabla');
    if (tabla.parentNode && tabla.parentNode.nodeType === 1) {
      tabla.parentNode.classList.add('adm-envoltorio');
    }
    etiquetar(tabla);
    var filas = filasReales(tabla);
    if (filas.length >= DESDE_BUSCADOR) buscador(tabla);
    estado(tabla).tope = TOPE;
    repintar(tabla);
  }

  function vigilar(tabla) {
    if (tabla.__visto) return;
    tabla.__visto = true;
    repasar(tabla);
    var tb = tabla.tBodies[0];
    if (!tb || !window.MutationObserver) return;
    var pendiente = null;
    new MutationObserver(function () {
      clearTimeout(pendiente);
      pendiente = setTimeout(function () { repasar(tabla); }, 40);
    }).observe(tb, { childList: true });
  }

  function barrer() {
    var raiz = document.getElementById('admin-contenido') ||
               document.getElementById('vista-panel') || document.body;
    Array.prototype.forEach.call(raiz.querySelectorAll('table'), vigilar);
  }

  function arrancar() {
    ponerEstilos();
    barrer();
    /* las pantallas pintan sus tablas cuando llegan los datos */
    setTimeout(barrer, 600);
    setTimeout(barrer, 2000);
    if (window.MutationObserver) {
      var espera = null;
      new MutationObserver(function () {
        clearTimeout(espera);
        espera = setTimeout(barrer, 150);
      }).observe(document.body, { childList: true, subtree: true });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', arrancar);
  } else {
    arrancar();
  }
})();
