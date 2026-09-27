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
    user:'<circle cx="12" cy="8" r="3.4"/><path d="M5 20c0-3.6 3-6 7-6s7 2.4 7 6"/>',
    calendar:'<rect x="3.5" y="5" width="17" height="15" rx="2.2"/><path d="M3.5 9.5h17M8 3.5v3M16 3.5v3M8 13h2M14 13h2M8 16.5h2M14 16.5h2"/>',
    check:'<circle cx="12" cy="12" r="8.5"/><path d="M8.4 12.3l2.5 2.4 4.7-5"/>',
    signal:'<rect x="8" y="2.5" width="8" height="19" rx="4"/><circle cx="12" cy="7" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="17" r="1.5"/>',
    bell:'<path d="M6 9.5a6 6 0 0 1 12 0c0 4.6 1.8 5.8 1.8 5.8H4.2S6 14.1 6 9.5z"/><path d="M10 19a2 2 0 0 0 4 0"/>',
    userplus:'<circle cx="10" cy="8" r="3.2"/><path d="M3.6 20c0-3.4 2.9-5.6 6.4-5.6"/><path d="M17.5 12v6M14.5 15h6"/>',
    euro:'<circle cx="12" cy="12" r="8.5"/><path d="M15 8.7a4.2 4.2 0 1 0 0 6.6M7.6 11h6M7.6 13.3h5"/>',
    globe:'<circle cx="12" cy="12" r="8.5"/><path d="M3.6 12h16.8M12 3.5c2.4 2.3 2.4 14.7 0 17M12 3.5c-2.4 2.3-2.4 14.7 0 17"/>',
    clipboard:'<rect x="5" y="5" width="14" height="16" rx="2.2"/><rect x="9" y="3" width="6" height="4" rx="1.3"/><path d="M8.5 12h7M8.5 15.5h5"/>',
    trophy:'<path d="M7 4.5h10v4a5 5 0 0 1-10 0z"/><path d="M7 6H4.6a2.4 2.4 0 0 0 3 2.4M17 6h2.4a2.4 2.4 0 0 1-3 2.4"/><path d="M12 13.4V17M9 20.5h6M10 17.5h4"/>',
    ticket:'<path d="M4 8.5A1.8 1.8 0 0 1 5.8 6.7h12.4A1.8 1.8 0 0 1 20 8.5a1.8 1.8 0 0 0 0 3.5 1.8 1.8 0 0 0 0 3.5 1.8 1.8 0 0 1-1.8 1.8H5.8A1.8 1.8 0 0 1 4 15.5a1.8 1.8 0 0 0 0-3.5A1.8 1.8 0 0 0 4 8.5z"/>',
    chart:'<path d="M4 4v16h16M8 16v-3.5M12 16V9M16 16v-6"/>',
    newspaper:'<rect x="4" y="4.5" width="16" height="15" rx="2"/><path d="M7.5 8.5h6M7.5 12h6M7.5 15.5h4M16 8.5v7"/>',
    at:'<circle cx="12" cy="12" r="3.6"/><path d="M15.6 12v1.6a2.4 2.4 0 0 0 4.8 0V12a8.4 8.4 0 1 0-3.3 6.7"/>',
    link:'<path d="M9.5 14.5l5-5M8 12l-1.6 1.6a3 3 0 0 0 4.2 4.2L12 16.5M16 11.5l1.6-1.6a3 3 0 0 0-4.2-4.2L12 7.5"/>',
    shuffle:'<path d="M15.5 4l3.5 3.5-3.5 3.5M19 7.5H9.5A5.5 5.5 0 0 0 4 13v3.5M8.5 20l-3.5-3.5"/><path d="M15 16.5l4 3.5"/>',
    clock:'<circle cx="12" cy="12" r="8.5"/><path d="M12 7.4V12l3 2"/>',
    flag:'<path d="M6 21V4M6 4.5h10.5l-2 3 2 3H6"/>',
    box:'<path d="M3 8l9-4 9 4-9 4z"/><path d="M3 8v8l9 4 9-4V8"/>',
    run:'<circle cx="14.5" cy="5" r="2"/><path d="M7 21l3-5 3 2 1 3M13 18l-3-2 1.5-5-3.5 2v3M13 11l3-1 3 2"/>',
    sparkle:'<path d="M11.5 4l1.6 4.3L17.5 10l-4.4 1.7-1.6 4.3-1.6-4.3L5.5 10l4.4-1.7z"/>',
    inbox:'<rect x="4" y="5" width="16" height="14" rx="2"/><path d="M4 8l8 5 8-5"/>'
  };
  function ico(n){ return '<svg viewBox="0 0 24 24" '+P+'>'+(ICO[n]||ICO.grid)+'</svg>'; }
  function esc(s){ return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }

  /* ---------- Los MUNDOS (mapa aprobado). `home` = a dónde lleva el
     conmutador; `screens` = navegación del mundo (solo en el mundo
     activo hace falta el detalle; para los demás basta `home`). ----- */
  var MUNDOS = [
    { key:'general', nombre:'General · Club', dot:'#2E4256', home:B+'portal/general/',
      frase:'El club por dentro: personas, socios, dinero, la web y los avisos que se envían.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/general/'},
        {t:'Personas',        i:'people',    url:B+'admin/atletas/',     d:'Todas las fichas del club, en un sitio.'},
        {t:'Socios',          i:'user',      url:B+'admin/socios/',      d:'Altas, cuotas y estado de cada socio.'},
        {t:'Dinero',          i:'euro',      url:B+'admin/cobros/',      d:'Cobros, recibos e impagados.'},
        {t:'Avisos al móvil', i:'bell',      url:B+'admin/avisos-push/', d:'Las notificaciones que se envían a la gente.', pill:'Notificar'},
        {t:'Buzón',           i:'inbox',     url:B+'admin/buzon/',       d:'Los mensajes que llegan de contacto.'},
        {t:'La web',          i:'globe',     url:B+'admin/paginas/',     d:'Páginas, textos y fotos de la web.'},
        {t:'Datos del club',  i:'clipboard', url:B+'admin/documentos/',  d:'Documentos y datos legales.'}
      ] },
    { key:'natacion', nombre:'Natación', dot:'#2F6FA8', home:B+'portal/natacion/',
      frase:'Adultos y máster. Franjas, calles, cupos y quién falta.',
      screens:[
        {key:'resumen',    t:'Resumen',          i:'grid',     url:B+'portal/natacion/'},
        {key:'nadadores',  t:'Nadadores',        i:'people',   url:B+'portal/natacion/?p=nadadores'},
        {key:'franjas',    t:'Franjas y cupos',  i:'calendar', url:B+'portal/natacion-gestion/'},
        {key:'asistencia', t:'Asistencia',       i:'check',    url:B+'portal/natacion-asistencia/'},
        {key:'plazas',     t:'Ver en la web',    i:'signal',   url:B+'natacion/', ext:true}
      ] },
    { key:'escuela-nat', nombre:'Escuela de natación', dot:'#2E8C86', home:B+'portal/escuela-natacion/',
      frase:'Los peques del agua: franjas, cupos, asistencia y familias.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/escuela-natacion/'},
        {t:'Niños y niñas',    i:'people',   url:B+'admin/natacion/',                          d:'La lista de la escuela de natación.'},
        {t:'Franjas y cupos',  i:'calendar', url:B+'portal/natacion-gestion/?tipo=Escuela',    d:'Horarios y calles con su cupo.'},
        {t:'Asistencia',       i:'check',    url:B+'portal/natacion-asistencia/?tipo=Escuela', d:'Quién viene a cada sesión.'},
        {t:'Ver en la web',    i:'signal',   url:B+'escuela-natacion/',                        d:'El semáforo de plazas que ven las familias.', ext:true}
      ] },
    { key:'cubo', nombre:'El Cubo', dot:'#B5714A', home:B+'portal/cubo/',
      frase:'Socios que entrenan: grupos fijos, cuotas y asistencia.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/cubo/'},
        {t:'Integrantes',     i:'people',   url:B+'admin/atletas/?seccion=cubo', d:'Quién entrena en el Cubo.'},
        {t:'Grupos y turnos', i:'calendar', url:B+'admin/grupos/?seccion=cubo',  d:'Grupos fijos y sus días.'},
        {t:'Cuotas y pagos',  i:'ticket',   url:B+'admin/cubo-altas/',           d:'Cuotas mensuales, cobros y altas.'},
        {t:'Asistencia',      i:'check',    url:B+'admin/asistencia/',           d:'Quién vino a entrenar cada día.'},
        {t:'Fuerza gratis',   i:'sparkle',  url:B+'admin/cubo-prueba/',          d:'Los turnos gratis de prueba.'},
        {t:'Clases y bonos',  i:'box',      url:B+'admin/cubo/',                 d:'Clases, bonos y ocupación.'}
      ] },
    { key:'pista', nombre:'Atletismo pista', dot:'#4A5FA6', home:B+'portal/pista/',
      frase:'La pista, con la Academia AC98 dentro: atletas, grupos, tests y competición.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/pista/'},
        {t:'Atletas',          i:'people',    url:B+'admin/atletas/?seccion=competicion', d:'Los atletas de pista.'},
        {t:'Grupos',           i:'people',    url:B+'admin/grupos/?seccion=competicion',  d:'Grupos de entreno, incl. Academia AC98.'},
        {t:'Tests y pruebas',  i:'clipboard', url:B+'admin/tests/',        d:'Batería de tests y marcas.'},
        {t:'Competiciones',    i:'flag',      url:B+'admin/competiciones/', d:'Carreras e inscripciones.'},
        {t:'Quién va a ir',    i:'check',     url:B+'admin/confirmaciones/', d:'Confirmaciones para cada carrera.'},
        {t:'Liga y récords',   i:'trophy',    url:B+'admin/liga/',         d:'Liga Apolana y récords del club.'}
      ] },
    { key:'escuela-atl', nombre:'Escuela de atletismo', dot:'#3F7A4C', home:B+'portal/escuela-atletismo/',
      frase:'Los peques de la pista: grupos, altas de familias y reparto.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/escuela-atletismo/'},
        {t:'Niños y niñas',     i:'people',   url:B+'admin/atletas/?seccion=escuela', d:'Los peques inscritos.'},
        {t:'Grupos',            i:'people',   url:B+'admin/grupos/?seccion=escuela',  d:'Grupos por edad.'},
        {t:'Altas de familias', i:'userplus', url:B+'admin/altas/?tipo=escuela',      d:'Solicitudes nuevas de las familias.'},
        {t:'Repartir',          i:'shuffle',  url:B+'admin/repartir/',                d:'Colocar a cada peque en su grupo.'},
        {t:'Histórico',         i:'clock',    url:B+'admin/historico/',               d:'Temporadas anteriores.'}
      ] },
    { key:'running', nombre:'Running', dot:'#C6892F', home:B+'portal/running/',
      frase:'De momento, solo agrupa a las personas de running.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/running/'},
        {t:'Corredores', i:'run', url:B+'admin/atletas/?seccion=running', d:'Las personas del grupo de running.'}
      ] },
    { key:'comunicacion', nombre:'Comunicación', dot:'#6E5AA6', home:B+'portal/comunicacion/',
      frase:'Lo que el club cuenta hacia fuera: noticias, avisos, calendario y redes.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/comunicacion/'},
        {t:'Noticias',        i:'newspaper', url:B+'admin/#noticias',    d:'Publicar y editar noticias de la web.'},
        {t:'Avisos al móvil', i:'bell',      url:B+'admin/avisos-push/', d:'Notificaciones a la gente del club.'},
        {t:'Calendario',      i:'calendar',  url:B+'admin/eventos/',     d:'Eventos y fechas del club.'},
        {t:'Liga',            i:'chart',      url:B+'admin/liga/',        d:'Comunicar la Liga Apolana.'},
        {t:'Enlaces para compartir', i:'link', url:B+'admin/enlaces/',   d:'Los enlaces de los formularios, para copiar.'},
        {t:'Peticiones de redes',    i:'at',   url:B+'admin/redes/',     d:'Lo que proponen los socios.'}
      ] }
  ];

  function mundoActual(){ for(var i=0;i<MUNDOS.length;i++){ if(MUNDOS[i].key===CFG.world) return MUNDOS[i]; } return null; }
  var M = mundoActual();
  if (!M) return;

  /* ---------- estilos (prefijo mm-, solo PC) ---------- */
  var css = document.createElement('style');
  css.setAttribute('data-piel','mundos');
  css.textContent =
    /* FLUIDEZ · transición suave entre páginas del panel (crossfade en vez de
       recarga en blanco). La barra lateral lleva view-transition-name, así que
       se queda FIJA y solo cambia el contenido. Navegador sin soporte: navega
       normal, sin romperse. Solo entre páginas que cargan este shell. */
    '@view-transition{navigation:auto}' +
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
      '.mm-side{display:block;position:sticky;top:16px;align-self:start;view-transition-name:mm-lateral}' +
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
  /* Estilos del HUB (el «Resumen» de cada mundo: cabecera + tarjetas de las
     herramientas). Valen en todos los tamaños; el color es el del mundo. */
  css.textContent +=
    '.mh-cab{margin:2px 0 20px}' +
    '.mh-eyebrow{font-size:11px;font-weight:700;letter-spacing:.14em;text-transform:uppercase;color:var(--mm-acento,#2F6FA8);margin-bottom:8px}' +
    '.mh-cab h1{font-family:var(--fuente-titulo);text-transform:uppercase;font-size:clamp(27px,5vw,38px);line-height:1;color:var(--navy,#2E4256);margin:0;display:flex;align-items:center;gap:12px}' +
    '.mh-cab h1 .pt-g{width:15px;height:15px;border-radius:50%;background:var(--mm-acento,#2F6FA8);flex:0 0 auto;box-shadow:0 0 0 4px color-mix(in srgb, var(--mm-acento,#2F6FA8) 18%, transparent)}' +
    '.mh-cab p{font-size:15.5px;color:var(--texto-suave,#6E6656);margin:10px 0 0;max-width:64ch;line-height:1.5}' +
    '.mh-rot{font-size:12px;font-weight:700;letter-spacing:.1em;text-transform:uppercase;color:var(--texto-suave,#6E6656);margin:0 0 12px}' +
    '.mh-hub{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,250px),1fr));gap:14px}' +
    '.mh-card{display:flex;flex-direction:column;text-decoration:none;background:#fff;border-radius:var(--radio,14px);box-shadow:var(--sombra-suave,0 10px 22px -16px rgba(46,66,86,.5));padding:17px;color:inherit;transition:transform .3s cubic-bezier(.2,.7,.2,1),box-shadow .3s cubic-bezier(.2,.7,.2,1)}' +
    '.mh-card:hover{transform:translateY(-4px);box-shadow:0 1px 2px rgba(30,45,65,.06),0 12px 22px -12px rgba(30,45,65,.2),0 26px 46px -28px rgba(30,45,65,.24)}' +
    '.mh-card .ico{width:42px;height:42px;border-radius:var(--radio-dentro,10px);display:grid;place-items:center;background:var(--azul-suave,#EAF2F9);background:color-mix(in srgb, var(--mm-acento,#2F6FA8) 13%, #fff);color:var(--mm-acento,#2F6FA8);margin-bottom:13px}' +
    '.mh-card .ico svg{width:22px;height:22px}' +
    '.mh-card h3{font-family:var(--fuente-titulo);font-weight:700;text-transform:uppercase;font-size:17px;color:var(--navy,#2E4256);margin:0 0 5px;line-height:1.05}' +
    '.mh-card .d{font-size:13.5px;color:var(--texto-suave,#6E6656);line-height:1.45;margin:0;flex:1 1 auto}' +
    '.mh-card .pie{display:flex;align-items:center;gap:8px;margin-top:13px}' +
    '.mh-pill{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;font-weight:600;color:var(--mm-acento,#2F6FA8);background:var(--azul-suave,#EAF2F9);background:color-mix(in srgb, var(--mm-acento,#2F6FA8) 12%, #fff);border-radius:999px;padding:4px 11px;line-height:1}' +
    '.mh-flecha{margin-left:auto;color:var(--mm-acento,#2F6FA8);font-weight:600;font-size:13.5px}';

  document.head.appendChild(css);

  /* FLUIDEZ · precarga (solo HTML) de las páginas de natación al pasar el ratón,
     para que abran casi al instante. No ejecuta su JS ni toca datos. */
  try {
    var sr = document.createElement('script');
    sr.type = 'speculationrules';
    sr.textContent = '{"prefetch":[{"source":"document","where":{"href_matches":"/portal/natacion*"},"eagerness":"moderate"}]}';
    document.head.appendChild(sr);
  } catch (e) {}

  /* ---------- conmutador de mundos, con ACCESO POR PERSONA ----------
     El conmutador enseña solo los mundos a los que la persona puede entrar
     (RPC `mis_mundos`: admin = todos; el resto = los de sus secciones de
     responsable). Mientras llega la respuesta se enseña solo el mundo actual
     (nunca mundos que no son suyos); se cachea por sesión para que sea
     instantáneo en las siguientes páginas. Si no hay sesión/cliente, se deja
     lo que haya (la protección de datos la siguen haciendo las reglas RLS). */
  var CACHE_KEY = 'apolana-mis-mundos';
  var worldsBox = null;

  function worldRowHtml(w) {
    var act = w.key === M.key;
    return '<a class="mm-w" href="' + esc(w.home) + '" style="--pt:' + w.dot + '" ' +
      'aria-current="' + act + '"' + (act ? ' aria-label="Estás en ' + esc(w.nombre) + '"' : '') + '>' +
      '<span class="pt"></span><span class="nm">' + esc(w.nombre) + '</span></a>';
  }
  function worldsHtml(keys) {
    var list;
    if (!keys) { list = MUNDOS; }                 // null = todos (admin)
    else {
      list = MUNDOS.filter(function (w) { return keys.indexOf(w.key) !== -1; });
      if (!list.some(function (w) { return w.key === M.key; })) list = [M].concat(list); // el actual siempre
    }
    return list.map(worldRowHtml).join('');
  }
  function pintaMundos(keys) { if (worldsBox) worldsBox.innerHTML = worldsHtml(keys); }

  function leerCache() {
    try { var v = sessionStorage.getItem(CACHE_KEY); if (v === 'todos') return null; if (v) return JSON.parse(v); } catch (e) {}
    return undefined; // sin cache
  }
  function guardarCache(keys) { try { sessionStorage.setItem(CACHE_KEY, keys == null ? 'todos' : JSON.stringify(keys)); } catch (e) {} }

  var _intentos = 0;
  function cargarMisMundos() {
    var c = window.APOLANA_DB;
    if (!c || !c.rpc) { if (_intentos++ < 6) setTimeout(cargarMisMundos, 400); return; }
    var listo = (c.auth && c.auth.getSession) ? c.auth.getSession() : Promise.resolve();
    listo.then(function () { return c.rpc('mis_mundos'); }).then(function (r) {
      if (!r || r.error || !Array.isArray(r.data)) return;   // error: deja lo que haya
      var keys = r.data;
      var todas = MUNDOS.every(function (w) { return keys.indexOf(w.key) !== -1; });
      var val = todas ? null : keys;   // admin (todos) -> null, a prueba de mundos futuros
      guardarCache(val);
      pintaMundos(val);
    }).catch(function () {});
  }

  /* ---------- HUB: el «Resumen» de un mundo (cabecera + tarjetas) ----------
     Se pinta cuando la página lo pide con APOLANA_MUNDO.home = true. Sale del
     mismo mapa MUNDOS, así que un mundo nuevo es solo su entrada aquí + una
     página mínima que declare el mundo. (Natación trae su propio Resumen con
     datos en vivo, así que NO usa home.) */
  function renderHub(el) {
    var cards = (M.screens || []).filter(function (s) { return s.key !== 'resumen'; }).map(function (s) {
      return '<a class="mh-card" href="' + esc(s.url) + '"' + (s.ext ? ' target="_blank" rel="noopener"' : '') + '>' +
        '<span class="ico">' + ico(s.i) + '</span>' +
        '<h3>' + esc(s.t) + '</h3>' +
        '<p class="d">' + esc(s.d || '') + '</p>' +
        '<span class="pie">' + (s.pill ? '<span class="mh-pill">' + esc(s.pill) + '</span>' : '') +
          '<span class="mh-flecha">' + (s.ext ? 'Ver ↗' : 'Abrir →') + '</span></span></a>';
    }).join('');
    el.innerHTML =
      '<div class="mh-cab"><div class="mh-eyebrow">Mundo</div>' +
        '<h1><span class="pt-g"></span>' + esc(M.nombre.replace(/\s*·\s*Club$/, '')) + '</h1>' +
        (M.frase ? '<p>' + esc(M.frase) + '</p>' : '') + '</div>' +
      '<p class="mh-rot">Herramientas de este mundo</p>' +
      '<div class="mh-hub">' + cards + '</div>';
  }

  /* ---------- montaje ---------- */
  function montar() {
    var content = CFG.contentSel ? document.querySelector(CFG.contentSel) : null;
    if (!content) { /* sin contenedor no envolvemos: no rompemos la página */ return; }
    if (document.querySelector('.mm-layout')) return;

    if (CFG.home) renderHub(content);   // el Resumen del mundo se pinta desde el mapa

    document.body.classList.add('mm-on');
    var acento = M.dot;

    var side = document.createElement('aside');
    side.className = 'mm-side';
    side.style.setProperty('--mm-acento', acento);
    side.setAttribute('aria-label', 'Mundos del panel');

    var _cache = leerCache();
    var worlds = worldsHtml(_cache === undefined ? [M.key] : _cache);

    var navHtml = '';
    if (M.screens && M.screens.length) {
      navHtml = '<div class="mm-navt">' + esc(M.nombre) + '</div><nav class="mm-nav" aria-label="Secciones de ' + esc(M.nombre) + '">' +
        M.screens.map(function (s) {
          var act = s.key === (CFG.screen || 'resumen');
          return '<a class="mm-i" href="' + esc(s.url) + '"' +
            (s.ext ? ' target="_blank" rel="noopener"' : '') +
            ' aria-current="' + act + '">' +
            '<span class="mm-ic">' + ico(s.i) + '</span><span>' + esc(s.t) + (s.ext ? ' ↗' : '') + '</span></a>';
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

    // Acceso por persona: enseñar solo los mundos de cada uno (async).
    worldsBox = side.querySelector('.mm-worlds');
    cargarMisMundos();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', montar);
  } else {
    montar();
  }
})();
