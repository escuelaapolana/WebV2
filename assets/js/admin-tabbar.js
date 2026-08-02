/* ============================================================
   BARRA INFERIOR DEL PANEL · Club Atletismo Apolana
   ------------------------------------------------------------
   En el móvil, para cambiar de sección del panel había que
   volver atrás al panel y abrir el menú. Esta barra pone las
   cuatro pantallas del día a día siempre a mano y deja el resto
   del panel a un toque, en «Menú».

       Inicio · Pista · Personas · Dinero · Menú

   Mismo aspecto que la barra del portal (assets/js/portal-tabbar.js):
   - Iconos de línea de 24 px, sin relleno.
   - El activo se distingue por color (#2F6FA8) y peso, nunca
     por una píldora de fondo.
   - Etiquetas de 11 px y objetivos táctiles de 48 px.
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
           'stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>';
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
        'min-height:48px;padding:0 2px;text-decoration:none;color:var(--texto-tenue,#A79F8E);' +
        'background:none;border:0;cursor:pointer;' +
        'font-family:inherit;font-size:11px;font-weight:400;line-height:1.2;letter-spacing:.01em;text-transform:none;' +
        '-webkit-tap-highlight-color:transparent}' +
      '.at-tabbar span{display:block;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.at-tabbar .ic{width:24px;height:24px;flex:0 0 24px}' +
      '.at-tabbar .activo{color:var(--azul-oscuro,#2F6FA8)}' +
      '.at-tabbar .activo span{font-weight:600}' +
      '.at-tabbar .activo .ic{stroke-width:2}' +

      /* --- hoja con todas las secciones --- */
      '.at-fondo{display:block;position:fixed;inset:0;z-index:700;background:rgba(46,66,86,.45);' +
        'opacity:0;transition:opacity .18s ease}' +
      '.at-fondo.ver{opacity:1}' +
      '.at-hoja{display:flex;flex-direction:column;position:fixed;left:0;right:0;bottom:0;z-index:701;' +
        'box-sizing:border-box;max-width:100%;max-height:82vh;' +
        'background:var(--crema,#FBF9F4);border-top-left-radius:20px;border-top-right-radius:20px;' +
        'box-shadow:0 -20px 44px -22px rgba(46,66,86,.55);' +
        'transform:translateY(100%);transition:transform .22s ease}' +
      '.at-hoja.ver{transform:none}' +
      '.at-hoja .cab{flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;gap:12px;' +
        'padding:14px 18px 10px;border-bottom:1px solid var(--linea,#EAE3D5)}' +
      '.at-hoja .cab h2{margin:0;font-family:var(--fuente-titulo,inherit);text-transform:uppercase;' +
        'font-size:19px;line-height:1;color:var(--navy,#2E4256)}' +
      '.at-hoja .cerrar{flex:0 0 auto;min-height:44px;min-width:44px;border:0;background:none;cursor:pointer;' +
        'font-size:15px;font-family:inherit;color:var(--texto-suave,#5E5849);padding:0 6px;' +
        '-webkit-tap-highlight-color:transparent}' +
      '.at-hoja .cuerpo{flex:1 1 auto;overflow-y:auto;-webkit-overflow-scrolling:touch;' +
        'padding:6px 18px calc(20px + env(safe-area-inset-bottom))}' +
      '.at-hoja .grupo{margin-top:14px}' +
      '.at-hoja .grupo h3{margin:0 0 6px;font-family:inherit;font-size:12px;font-weight:600;' +
        'letter-spacing:.06em;text-transform:uppercase;color:var(--texto-tenue,#A79F8E)}' +
      '.at-hoja .enlaces{display:grid;grid-template-columns:1fr 1fr;gap:8px}' +
      '.at-hoja .enlaces a{display:flex;align-items:center;min-height:48px;box-sizing:border-box;' +
        'padding:10px 12px;border:1px solid var(--linea,#EAE3D5);border-radius:12px;background:#fff;' +
        'text-decoration:none;color:var(--navy,#2E4256);font-size:14px;line-height:1.25;' +
        '-webkit-tap-highlight-color:transparent}' +
      '.at-hoja .enlaces a.aqui{border-color:var(--azul-oscuro,#2F6FA8);color:var(--azul-oscuro,#2F6FA8);font-weight:600}' +
      '.at-hoja .enlaces a.ancho{grid-column:1 / -1}' +
      'body.at-hoja-abierta{overflow:hidden}' +
      /* los avisos flotantes del panel no se quedan debajo de la barra */
      'body.at-con-tabbar .apx-host{bottom:calc(14px + ' + ALTO + 'px + env(safe-area-inset-bottom))}' +
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
        { txt: 'Pedidos de ropa', url: r + 'pedidos/' }
      ] },
      { t: 'Análisis de datos', enlaces: [
        { txt: 'Estadísticas del club', url: r + 'estadisticas/' },
        { txt: 'Informes y datos', url: r + 'informes/' },
        { txt: 'Histórico de la escuela', url: r + 'historico/' }
      ] },
      { t: 'Actividad', enlaces: [
        { txt: 'Calendario y eventos', url: r + 'eventos/' },
        { txt: 'Competiciones', url: r + 'competiciones/' },
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
