/* ============================================================
   BARRA LATERAL DE «MUNDOS» · Club Atletismo Apolana
   ------------------------------------------------------------
   El panel es un mundo superior (Administración) y dentro hay
   mundos por sección (Natación, El Cubo, Atletismo…). Esta pieza
   pinta, SOLO en PC (>=900px), la barra lateral que es el «vaso
   comunicante»: arriba se cambia de mundo de un clic, debajo va la
   navegación del mundo en el que estás. En móvil no aparece: manda
   la barra flotante de la app (no se tocan las dos a la vez).

   Es ADITIVA y opt-in: una página entra en un mundo declarando,
   ANTES de cargar este script:

     window.APOLANA_MUNDO = { world:'natacion', screen:'resumen',
                              contentSel:'#nat' };

   `contentSel` = el contenedor de contenido de la página, que se
   envuelve en la rejilla [lateral | contenido]. Si la página aún no
   lo tiene al cargar (lo pinta su JS después), el contenedor debe
   existir vacío en el HTML.

   No depende de la sesión: los enlaces son a páginas reales; quién
   entra a cada mundo lo deciden las reglas de acceso de cada página.
   ============================================================ */
(function () {
  'use strict';

  var CFG = window.APOLANA_MUNDO;
  if (!CFG || !CFG.world) return;

  function base() { return window.APOLANA_BASE || '../../'; }
  var B = base();

  /* ---------- iconos (línea 24px) ---------- */
  var P = 'fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"';
  var ICO = {
    grid:'<circle cx="9" cy="8" r="3.1"/><path d="M3.6 19c0-3 2.4-5 5.4-5s5.4 2 5.4 5"/><circle cx="17" cy="9" r="2.3"/><path d="M15.6 14.1c2.5.2 4.4 2.1 4.4 4.7"/>',
    people:'<circle cx="9" cy="8" r="3.1"/><path d="M3.6 19c0-3 2.4-5 5.4-5s5.4 2 5.4 5"/><circle cx="17" cy="9" r="2.3"/><path d="M15.6 14.1c2.5.2 4.4 2.1 4.4 4.7"/>',
    calendar:'<rect x="3.5" y="5" width="17" height="15" rx="2.2"/><path d="M3.5 9.5h17M8 3.5v3M16 3.5v3M8 13h2M14 13h2M8 16.5h2M14 16.5h2"/>',
    check:'<circle cx="12" cy="12" r="8.5"/><path d="M8.4 12.3l2.5 2.4 4.7-5"/>',
    signal:'<rect x="8" y="2.5" width="8" height="19" rx="4"/><circle cx="12" cy="7" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="17" r="1.5"/>',
    bell:'<path d="M6 9.5a6 6 0 0 1 12 0c0 4.6 1.8 5.8 1.8 5.8H4.2S6 14.1 6 9.5z"/><path d="M10 19a2 2 0 0 0 4 0"/>',
    userplus:'<circle cx="10" cy="8" r="3.2"/><path d="M3.6 20c0-3.4 2.9-5.6 6.4-5.6"/><path d="M17.5 12v6M14.5 15h6"/>'
  };
  function ico(n){ return '<svg viewBox="0 0 24 24" '+P+'>'+(ICO[n]||ICO.grid)+'</svg>'; }
  function esc(s){ return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }

  /* ---------- Los MUNDOS (mapa aprobado). `home` = a dónde lleva el
     conmutador; `screens` = navegación del mundo (solo en el mundo
     activo hace falta el detalle; para los demás basta `home`). ----- */
  var MUNDOS = [
    { key:'general',     nombre:'General · Club',        dot:'#2E4256', home:B+'admin/' },
    { key:'natacion',    nombre:'Natación',              dot:'#2F6FA8', home:B+'portal/natacion/',
      screens:[
        {key:'resumen',    t:'Resumen',          i:'grid',     url:B+'portal/natacion/'},
        {key:'nadadores',  t:'Nadadores',        i:'people',   url:B+'portal/natacion/?p=nadadores'},
        {key:'franjas',    t:'Franjas y cupos',  i:'calendar', url:B+'portal/natacion-gestion/'},
        {key:'asistencia', t:'Asistencia',       i:'check',    url:B+'portal/natacion-asistencia/'},
        {key:'plazas',     t:'Plazas en la web', i:'signal',   url:B+'natacion/'}
      ] },
    { key:'escuela-nat', nombre:'Escuela de natación',   dot:'#2E8C86', home:B+'portal/natacion/' },
    { key:'cubo',        nombre:'El Cubo',               dot:'#B5714A', home:B+'admin/cubo/' },
    { key:'pista',       nombre:'Atletismo pista',       dot:'#4A5FA6', home:B+'admin/atletas/?seccion=competicion' },
    { key:'escuela-atl', nombre:'Escuela de atletismo',  dot:'#3F7A4C', home:B+'admin/atletas/?seccion=escuela' },
    { key:'running',     nombre:'Running',               dot:'#C6892F', home:B+'admin/atletas/' },
    { key:'comunicacion',nombre:'Comunicación',          dot:'#6E5AA6', home:B+'admin/' }
  ];

  function mundoActual(){ for(var i=0;i<MUNDOS.length;i++){ if(MUNDOS[i].key===CFG.world) return MUNDOS[i]; } return null; }
  var M = mundoActual();
  if (!M) return;

  /* ---------- estilos (prefijo mm-, solo PC) ---------- */
  var css = document.createElement('style');
  css.setAttribute('data-piel','mundos');
  css.textContent =
    /* Oculta por defecto (móvil); el @media de abajo la muestra en PC.
       Mismo selector .mm-side en ambos sitios para que gane el de la media
       query por orden, no por especificidad. */
    '.mm-side{display:none}' +
    '@media (min-width:900px){' +
      /* En PC: rejilla lateral + contenido, y fuera la barra flotante. */
      /* Pegada a la izquierda (no centrada): la lateral vive junto al borde,
         como en un panel. El ancho se limita para que el contenido no se
         estire de más en pantallas muy anchas; el hueco queda a la derecha. */
      '.mm-layout{display:grid;grid-template-columns:262px minmax(0,1fr);gap:26px;' +
        'max-width:1460px;margin:0;padding:20px clamp(18px,3vw,34px) 48px;align-items:start}' +
      '.mm-layout>.mm-main{min-width:0}' +
      /* el contenido de la página, ya sin su propio centrado/ancho */
      '.mm-layout>.mm-main>*{max-width:none !important;margin-left:0 !important;margin-right:0 !important;padding-left:0 !important;padding-right:0 !important}' +
      'body.mm-on .pt-tabbar{display:none !important}' +
      'body.mm-on .at-side{display:none !important}' +
      'body.mm-on.pt-con-tabbar{padding-bottom:24px !important}' +
      '.mm-side{display:block;position:sticky;top:16px;align-self:start}' +
      '.mm-isla{background:#fff;border-radius:var(--radio,14px);box-shadow:var(--sombra-suave,0 10px 22px -16px rgba(46,66,86,.5));padding:16px 12px}' +
      '.mm-rotulo{font-size:11px;font-weight:700;letter-spacing:.14em;text-transform:uppercase;color:var(--texto-suave,#6E6656);padding:2px 8px 8px;display:flex;gap:8px;align-items:center}' +
      '.mm-rotulo .q{font-weight:500;letter-spacing:.02em;text-transform:none;color:var(--texto-tenue,#6E6656);font-size:11px}' +
      '.mm-worlds{display:flex;flex-direction:column;gap:2px}' +
      '.mm-w{display:flex;align-items:center;gap:11px;width:100%;text-decoration:none;text-align:left;' +
        'font-family:inherit;font-size:14.5px;font-weight:600;color:var(--texto,#4A4437);line-height:1.15;' +
        'padding:9px 11px;min-height:42px;border-radius:var(--radio-dentro,10px);border-left:3px solid transparent}' +
      '.mm-w .pt{width:11px;height:11px;border-radius:50%;flex:0 0 auto;background:var(--pt);box-shadow:0 0 0 3px color-mix(in srgb, var(--pt) 16%, transparent)}' +
      '.mm-w .nm{flex:1 1 auto;min-width:0}' +
      '.mm-w:hover{background:var(--crema-media,#EFE9DC)}' +
      '.mm-w[aria-current="true"]{background:var(--crema-media,#EFE9DC);background:color-mix(in srgb, var(--pt) 16%, #fff);' +
        'border-left-color:var(--pt);color:var(--navy,#2E4256);font-weight:700;' +
        'box-shadow:0 6px 14px -12px color-mix(in srgb, var(--pt) 70%, transparent)}' +
      '.mm-w[aria-current="true"] .pt{box-shadow:0 0 0 3px color-mix(in srgb, var(--pt) 30%, transparent)}' +
      '.mm-sep{height:1px;background:var(--linea-marcada,#E4DCCB);margin:14px 6px;border-radius:2px}' +
      '.mm-navt{font-size:11px;font-weight:700;letter-spacing:.12em;text-transform:uppercase;color:var(--mm-acento);padding:2px 8px 8px}' +
      '.mm-nav{display:flex;flex-direction:column;gap:1px}' +
      '.mm-i{display:flex;align-items:center;gap:10px;width:100%;text-decoration:none;text-align:left;' +
        'font-family:inherit;font-size:14px;font-weight:500;color:var(--texto,#4A4437);line-height:1.2;' +
        'padding:8px 11px;min-height:40px;border-radius:var(--radio-dentro,10px);border-left:3px solid transparent}' +
      '.mm-i .mm-ic{width:20px;height:20px;flex:0 0 auto;display:grid;place-items:center;color:var(--texto-suave,#6E6656)}' +
      '.mm-i .mm-ic svg{width:18px;height:18px}' +
      '.mm-i:hover{background:var(--crema-media,#EFE9DC)}' +
      '.mm-i[aria-current="true"]{background:var(--crema-media,#EFE9DC);background:color-mix(in srgb, var(--mm-acento) 12%, #fff);' +
        'color:var(--navy,#2E4256);font-weight:600;border-left-color:var(--mm-acento)}' +
      '.mm-i[aria-current="true"] .mm-ic{color:var(--mm-acento)}' +
      '.mm-nota{margin:14px 8px 2px;padding-top:12px;border-top:1px solid var(--linea-marcada,#E4DCCB);' +
        'font-size:11.5px;line-height:1.45;color:var(--texto-tenue,#6E6656)}' +
      '.mm-nota b{color:var(--texto-suave,#6E6656)}' +
    '}';
  document.head.appendChild(css);

  /* ---------- montaje ---------- */
  function montar() {
    var content = CFG.contentSel ? document.querySelector(CFG.contentSel) : null;
    if (!content) { /* sin contenedor no envolvemos: no rompemos la página */ return; }
    if (document.querySelector('.mm-layout')) return;

    document.body.classList.add('mm-on');
    var acento = M.dot;

    var side = document.createElement('aside');
    side.className = 'mm-side';
    side.style.setProperty('--mm-acento', acento);
    side.setAttribute('aria-label', 'Mundos del panel');

    var worlds = MUNDOS.map(function (w) {
      var act = w.key === M.key;
      return '<a class="mm-w" href="' + esc(w.home) + '" style="--pt:' + w.dot + '" ' +
        'aria-current="' + act + '"' + (act ? ' aria-label="Estás en ' + esc(w.nombre) + '"' : '') + '>' +
        '<span class="pt"></span><span class="nm">' + esc(w.nombre) + '</span></a>';
    }).join('');

    var navHtml = '';
    if (M.screens && M.screens.length) {
      navHtml = '<div class="mm-navt">' + esc(M.nombre) + '</div><nav class="mm-nav" aria-label="Secciones de ' + esc(M.nombre) + '">' +
        M.screens.map(function (s) {
          var act = s.key === (CFG.screen || 'resumen');
          return '<a class="mm-i" href="' + esc(s.url) + '" aria-current="' + act + '"' + (act ? ' aria-current="page"' : '') + '>' +
            '<span class="mm-ic">' + ico(s.i) + '</span><span>' + esc(s.t) + '</span></a>';
        }).join('') + '</nav>';
    }

    side.innerHTML = '<div class="mm-isla">' +
      '<div class="mm-rotulo">Mundos <span class="q">· cambia de un clic</span></div>' +
      '<div class="mm-worlds">' + worlds + '</div>' +
      (navHtml ? '<div class="mm-sep"></div>' + navHtml : '') +
      '<p class="mm-nota">Entras en los mundos para los que tienes permiso. Cada persona ve los suyos.</p>' +
    '</div>';

    // Envolver: [ lateral | (contenido) ] dentro de .mm-layout, en el sitio del contenido.
    var layout = document.createElement('div');
    layout.className = 'mm-layout';
    layout.style.setProperty('--mm-acento', acento);
    content.parentNode.insertBefore(layout, content);
    var main = document.createElement('div');
    main.className = 'mm-main';
    main.appendChild(content);
    layout.appendChild(side);
    layout.appendChild(main);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', montar);
  } else {
    montar();
  }
})();
