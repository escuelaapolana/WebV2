/* ============================================================
   BARRA INFERIOR DEL PORTAL · Club Atletismo Apolana
   ------------------------------------------------------------
   Una sola barra de pestañas para TODAS las pantallas del
   portal. Antes solo la tenían las tres zonas (atleta,
   entrenador y familia), así que al entrar en Calendario, El
   Cubo, Documentos o Mensajes la barra desaparecía y se perdía
   la sensación de app.

   Sigue la maqueta v3 (22c):
   - Atleta y familia:  Inicio · Entreno · Calendario · Marcas · Más
   - Entrenador:        Inicio · Lista · Calendario · Feedback · Más
   - Iconos de línea de 24 px sin relleno.
   - El activo se distingue por color (#2F6FA8) y peso, nunca
     por una píldora de fondo.
   - Objetivos táctiles de 48 px y etiquetas de 11 px.

   Se carga con defer en las pantallas del portal que NO tienen
   barra propia. Si la página ya pinta una `.tabbar` (las tres
   zonas), este componente se aparta y no pinta nada.
   ============================================================ */
(function () {
  'use strict';

  var ALTO = 78;                       /* hueco que se reserva al final del contenido */
  var CLAVE_ZONA = 'apolana-zona';     /* recuerdo de la zona mientras dura la visita */

  function base() { return window.APOLANA_BASE || '../../'; }

  /* ---------- ¿esta página tiene barra propia? ---------- */
  var ZONAS_CON_BARRA = ['/portal/atleta/', '/portal/entrenador/', '/portal/familia/'];
  function tieneBarraPropia() {
    var r = location.pathname;
    for (var i = 0; i < ZONAS_CON_BARRA.length; i++) {
      if (r.indexOf(ZONAS_CON_BARRA[i]) !== -1) return true;
    }
    return !!document.querySelector('.tabbar');
  }
  if (location.pathname.indexOf('/portal/') === -1) return;
  if (tieneBarraPropia()) return;

  /* ---------- iconos (línea de 24 px, sin relleno) ---------- */
  function svg(p) {
    return '<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
           'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>';
  }
  var IC = {
    inicio:  svg('<path d="M3 10.5L12 3l9 7.5"/><path d="M5.5 9.5V20h13V9.5"/>'),
    entreno: svg('<circle cx="15.5" cy="4.8" r="2"/><path d="M7 21l3-5.5 3.5-2.5-1-4.5-4 2-1.5 3"/><path d="M13.5 13l3.5 2 1.5 4"/>'),
    agenda:  svg('<rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/>'),
    marcas:  svg('<path d="M4 19V9M10 19V5M16 19v-7M22 19H2"/>'),
    lista:   svg('<rect x="4" y="4" width="16" height="17" rx="2"/><path d="M8 3v3M16 3v3M8 11l2 2 3.5-3.5M8 16h6"/>'),
    feedback: svg('<path d="M20 15a2 2 0 0 1-2 2H8l-4 4V6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2z"/><path d="M8 10h8M8 13h5"/>'),
    mensajes: svg('<path d="M20 12a7 7 0 0 1-10 6.3L4 20l1.7-4.2A7 7 0 1 1 20 12z"/>'),
    docs:    svg('<path d="M7 3h8l4 4v14H7z"/><path d="M15 3v4h4M10 12h6M10 16h4"/>'),
    mas:     '<svg class="ic" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' +
             '<circle cx="5" cy="12" r="1.9"/><circle cx="12" cy="12" r="1.9"/><circle cx="19" cy="12" r="1.9"/></svg>'
  };

  /* ---------- estilos ---------- */
  var css = document.createElement('style');
  css.textContent =
    '.pt-tabbar{display:none}' +
    '@media (max-width:760px){' +
      /* hueco al final del contenido para que la barra no tape nada */
      'body.pt-con-tabbar{padding-bottom:calc(' + ALTO + 'px + env(safe-area-inset-bottom))}' +
      '.pt-tabbar{display:flex;align-items:stretch;position:fixed;left:0;right:0;bottom:0;z-index:600;' +
        'box-sizing:border-box;max-width:100%;' +
        'background:rgba(251,249,244,.96);-webkit-backdrop-filter:saturate(1.3) blur(10px);backdrop-filter:saturate(1.3) blur(10px);' +
        'border-top:1px solid var(--linea,#EAE3D5);' +
        'padding:10px 6px calc(10px + env(safe-area-inset-bottom))}' +
      '.pt-tabbar a{flex:1 1 0;min-width:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;' +
        'min-height:48px;padding:0 2px;text-decoration:none;color:var(--texto-suave,#6E6656);' +
        'font-family:inherit;font-size:11px;font-weight:400;line-height:1.2;text-transform:none;' +
        '-webkit-tap-highlight-color:transparent}' +
      '.pt-tabbar a span{display:block;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.pt-tabbar .ic{width:24px;height:24px;flex:0 0 24px}' +
      '.pt-tabbar a.activo{color:#2F6FA8}' +
      '.pt-tabbar a.activo span{font-weight:600}' +
            /* los avisos flotantes suben por encima de la barra en vez de quedar debajo */
    '}';
  document.head.appendChild(css);

  /* ---------- ¿en qué zona está la persona? ----------
     1) Si la propia página es una zona (coordinación), esa.
     2) Si viene de una zona (la página anterior), esa.
     3) Si no, la última que se usó en esta visita.
     4) Si nada de eso se sabe, atleta.                    */
  function zonaDeRuta(r) {
    if (!r) return null;
    if (r.indexOf('/portal/entrenador/') !== -1) return 'entrenador';
    if (r.indexOf('/portal/atleta/') !== -1) return 'atleta';
    if (r.indexOf('/portal/familia/') !== -1) return 'familia';
    if (r.indexOf('/portal/coordinador/') !== -1) return 'coordinador';
    return null;
  }
  function recordada() {
    try { return sessionStorage.getItem(CLAVE_ZONA); } catch (e) { return null; }
  }
  function recordar(z) {
    try { sessionStorage.setItem(CLAVE_ZONA, z); } catch (e) { /* modo privado */ }
  }
  function rutaAnterior() {
    try { return document.referrer ? new URL(document.referrer).pathname : ''; } catch (e) { return ''; }
  }

  function resolverZona(claves) {
    claves = claves || [];
    function vale(z) { return z && (!claves.length || claves.indexOf(z) !== -1); }
    var z = zonaDeRuta(location.pathname);
    if (!vale(z)) z = zonaDeRuta(rutaAnterior());
    if (!vale(z)) z = recordada();
    if (!vale(z)) {
      /* Con varios papeles y sin pista, manda el de atleta. */
      var orden = ['atleta', 'familia', 'entrenador', 'coordinador'];
      z = null;
      for (var i = 0; i < orden.length && !z; i++) {
        if (claves.indexOf(orden[i]) !== -1) z = orden[i];
      }
    }
    if (!z) z = 'atleta';
    if (claves.indexOf(z) !== -1) recordar(z);
    return z;
  }

  /* ---------- pestañas de cada zona ---------- */
  var SECCION_ENTRENO = { atleta: 'entreno', familia: 'entrenos' };

  function pestanas(zona, claves) {
    var b = base();
    var tengoZona = claves.indexOf(zona) !== -1;
    var urlZona = tengoZona ? (b + 'portal/' + zona + '/') : (b + 'portal/');
    var deportivo = (zona === 'entrenador' || zona === 'coordinador');
    var tengoEntrenador = claves.indexOf('entrenador') !== -1;
    var urlEntrenador = b + 'portal/entrenador/';
    var lista;

    if (deportivo) {
      lista = [
        { id: 'inicio',     txt: 'Inicio',     ic: IC.inicio,   url: urlZona },
        { id: 'lista',      txt: 'Lista',      ic: IC.lista,    url: urlEntrenador + '#lista',    hay: tengoEntrenador },
        { id: 'calendario', txt: 'Calendario', ic: IC.agenda,   url: b + 'portal/calendario/' },
        { id: 'feedback',   txt: 'Feedback',   ic: IC.feedback, url: urlEntrenador + '#feedback', hay: tengoEntrenador },
        { id: 'mas',        txt: 'Más',        ic: IC.mas,      url: tengoEntrenador ? (urlEntrenador + '#mas') : (b + 'portal/') }
      ];
    } else {
      var sec = SECCION_ENTRENO[zona] || 'entreno';
      lista = [
        { id: 'inicio',     txt: 'Inicio',     ic: IC.inicio,  url: urlZona },
        { id: 'entreno',    txt: 'Entreno',    ic: IC.entreno, url: urlZona + '#' + sec, hay: tengoZona },
        { id: 'calendario', txt: 'Calendario', ic: IC.agenda,  url: b + 'portal/calendario/' },
        { id: 'marcas',     txt: 'Marcas',     ic: IC.marcas,  url: urlZona + '#marcas',  hay: tengoZona },
        { id: 'mas',        txt: 'Más',        ic: IC.mas,     url: tengoZona ? (urlZona + '#mas') : (b + 'portal/') }
      ];
    }

    /* Si a alguien le falta la zona de una pestaña (por ejemplo, coordinación
       sin grupos a su cargo) no se deja un enlace roto: se sustituye por una
       pantalla del portal que sí puede abrir. */
    var recambios = [
      { id: 'mensajes',   txt: 'Mensajes',   ic: IC.mensajes, url: b + 'portal/mensajes/' },
      { id: 'documentos', txt: 'Documentos', ic: IC.docs,     url: b + 'portal/documentos/' }
    ];
    var salida = [];
    lista.forEach(function (t) {
      if (t.hay === false) {
        var r = recambios.shift();
        if (r) salida.push(r);
        return;
      }
      salida.push(t);
    });
    return salida;
  }

  /* ---------- qué pestaña queda encendida ---------- */
  function activa(zona, tabs) {
    var r = location.pathname;
    var id = null;
    if (r.indexOf('/portal/calendario/') !== -1) id = 'calendario';
    else if (r.indexOf('/portal/mensajes/') !== -1 && tienePestana(tabs, 'mensajes')) id = 'mensajes';
    else if (r.indexOf('/portal/documentos/') !== -1 && tienePestana(tabs, 'documentos')) id = 'documentos';
    else if (zonaDeRuta(r) === zona) id = 'inicio';
    /* El resto de pantallas (El Cubo, Documentos, Mensajes, Tests, Lesiones,
       Carga, Calles, Competiciones, Redes) se abren desde «Más»: es la que
       se queda encendida, igual que hace la zona de atleta con Pagos. */
    return id || 'mas';
  }
  function tienePestana(tabs, id) {
    for (var i = 0; i < tabs.length; i++) { if (tabs[i].id === id) return true; }
    return false;
  }

  /* ---------- pintado ---------- */
  var nodo = null;
  function pintar(zona, claves) {
    if (document.querySelector('.tabbar')) { quitar(); return; }   /* la página se pintó su propia barra */
    var tabs = pestanas(zona, claves);
    var act = activa(zona, tabs);
    var html = tabs.map(function (t) {
      return '<a href="' + t.url + '"' + (t.id === act ? ' class="activo" aria-current="page"' : '') + '>' +
             t.ic + '<span>' + t.txt + '</span></a>';
    }).join('');
    if (!nodo) {
      nodo = document.createElement('nav');
      nodo.className = 'pt-tabbar';
      nodo.setAttribute('aria-label', 'Secciones del club');
      document.body.appendChild(nodo);
      document.body.classList.add('pt-con-tabbar');
    }
    nodo.innerHTML = html;
  }
  function quitar() {
    if (nodo && nodo.parentNode) nodo.parentNode.removeChild(nodo);
    nodo = null;
    document.body.classList.remove('pt-con-tabbar');
  }

  /* ---------- arranque ----------
     La barra solo aparece con la sesión abierta: la señal es la barra
     superior que pinta portal-auth.js cuando ya hay usuario. */
  function esperarSesion(cb) {
    var t0 = Date.now();
    (function mira() {
      if (document.querySelector('.pt-top')) { cb(); return; }
      if (Date.now() - t0 > 20000) return;      /* sin sesión: no se pinta nada */
      setTimeout(mira, 120);
    })();
  }
  function esperarPapeles(cb) {
    var t0 = Date.now();
    (function mira() {
      var P = window.APOLANA_PORTAL;
      if (P && typeof P.papeles === 'function') {
        P.papeles().then(function (l) { cb(l || []); }, function () { cb([]); });
        return;
      }
      if (Date.now() - t0 > 20000) { cb([]); return; }
      setTimeout(mira, 120);
    })();
  }

  function arrancar() {
    esperarSesion(function () {
      /* Pintado inmediato con la zona que ya se venía usando, para que la
         barra no aparezca de golpe a mitad de lectura. */
      var previa = recordada();
      if (previa) pintar(resolverZona([previa]), [previa]);

      esperarPapeles(function (lista) {
        var claves = (lista || []).map(function (p) { return p.clave; });
        pintar(resolverZona(claves), claves);
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', arrancar);
  } else {
    arrancar();
  }
})();
