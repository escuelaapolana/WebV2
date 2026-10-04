/* ============================================================
   BARRA LATERAL DE «MUNDOS» · Club Atletismo Apolana
   ------------------------------------------------------------
   El panel es un mundo superior (Administración) y dentro hay
   mundos por sección (Natación, El Cubo, Atletismo…). Esta pieza
   pinta, SOLO en PC (>=900px), la barra lateral que es el «vaso
   comunicante»: arriba se cambia de mundo de un clic, debajo va la
   navegación del mundo en el que estás. En móvil no aparece: manda
   la barra flotante de la app (no se tocan las dos a la vez).

   DOS MODOS, un mismo aspecto:
   · Portal (páginas /portal/<mundo>/…): la página declara
     `window.APOLANA_MUNDO = { world, screen, contentSel, home? }`
     ANTES de cargar este script, y aquí se envuelve el contenido en
     la rejilla [lateral | contenido]. Si `home:true`, además se pinta
     el «Resumen» del mundo (hub de tarjetas) desde el mapa.
   · Panel (páginas /admin/…): NO hay APOLANA_MUNDO. Este script solo
     EXPONE `window.APOLANA_MUNDOS_SHELL`, y `admin-tabbar.js` lo usa
     para rellenar su propia barra lateral con los mundos (el mundo se
     deduce de la URL). Así el panel viejo y los mundos son el mismo
     diseño.

   El acceso por persona (qué mundos ve cada uno) sale del RPC
   `mis_mundos`; la protección de datos la siguen haciendo las RLS.
   ============================================================ */
(function () {
  'use strict';

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

  /* ---------- Los MUNDOS (mapa aprobado) ---------- */
  var MUNDOS = [
    { key:'general', nombre:'General · Club', dot:'#2E4256', home:B+'portal/general/',
      frase:'El club por dentro: personas, socios, dinero, la web y los avisos que se envían.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/general/'},
        {key:'calendario', t:'Calendario del club', i:'calendar', url:B+'portal/calendario-club/', d:'Todas las sesiones por día, con apuntados; cancelar festivos y cierres.'},
        {t:'Personas',        i:'people',    url:B+'admin/atletas/',     d:'Todas las fichas del club, en un sitio.'},
        {t:'Socios',          i:'user',      url:B+'admin/socios/',      d:'Altas, cuotas y estado de cada socio.'},
        {t:'Dinero',          i:'euro',      url:B+'admin/cobros/',      d:'Cobros, recibos e impagados.'},
        {key:'pagos', t:'Resumen de pagos', i:'chart', url:B+'portal/pagos-resumen/', d:'Cuánto entra: Cubo, cobros online, recibos y socios.'},
        {t:'Pedidos de la tienda', i:'box', url:B+'admin/pedidos/', d:'Los pedidos de ropa y su estado.'},
        {t:'Avisos al móvil', i:'bell',      url:B+'admin/avisos-push/', d:'Las notificaciones que se envían a la gente.', pill:'Notificar'},
        {t:'Buzón',           i:'inbox',     url:B+'admin/buzon/',       d:'Los mensajes que llegan de contacto.'},
        {t:'La web',          i:'globe',     url:B+'admin/paginas/',     d:'Páginas, textos y fotos de la web.'},
        {t:'Datos del club',  i:'clipboard', url:B+'admin/documentos/',  d:'Documentos y datos legales.'},
        {t:'Acceso a los mundos', i:'shuffle', url:B+'admin/mundos/',    d:'Quién entra a cada mundo (Natación, Cubo…).'},
        {t:'Enlaces para compartir', i:'link', url:B+'admin/enlaces/',   d:'Los enlaces de los formularios, para copiar y mandar.'}
      ] },
    { key:'natacion', nombre:'Natación', dot:'#2F6FA8', home:B+'portal/natacion/',
      frase:'Adultos y máster. Franjas, calles, cupos y quién falta.',
      screens:[
        {key:'resumen',    t:'Resumen',          i:'grid',     url:B+'portal/natacion/'},
        {key:'nadadores',  t:'Nadadores',        i:'people',   url:B+'portal/natacion/?p=nadadores'},
        {key:'franjas',    t:'Franjas y cupos',  i:'calendar', url:B+'portal/natacion-gestion/'},
        {key:'asistencia', t:'Asistencia',       i:'check',    url:B+'portal/natacion-asistencia/'},
        {key:'reservas',   t:'Reservas y abono', i:'ticket',   url:B+'portal/natacion-reservas/'},
        {key:'calendario', t:'Calendario',       i:'calendar', url:B+'portal/calendario-club/?world=natacion'},
        {key:'plazas',     t:'Ver en la web',    i:'signal',   url:B+'natacion/', ext:true}
      ] },
    { key:'escuela-nat', nombre:'Escuela de natación', dot:'#2E8C86', home:B+'portal/escuela-natacion/',
      frase:'Los peques del agua: franjas, cupos, asistencia y familias.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/escuela-natacion/'},
        {key:'ninos', t:'Niños y niñas', i:'people', url:B+'portal/escuela-natacion/?p=ninos', d:'La lista de la escuela de natación.'},
        {t:'Franjas y cupos',  i:'calendar', url:B+'portal/natacion-gestion/?tipo=Escuela',    d:'Horarios y calles con su cupo.'},
        {t:'Asistencia',       i:'check',    url:B+'portal/natacion-asistencia/?tipo=Escuela', d:'Quién viene a cada sesión.'},
        {t:'Ver en la web',    i:'signal',   url:B+'escuela-natacion/',                        d:'El semáforo de plazas que ven las familias.', ext:true}
      ] },
    { key:'cubo', nombre:'El Cubo', dot:'#B5714A', home:B+'portal/cubo/',
      frase:'Socios que entrenan: grupos fijos, cuotas y asistencia.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/cubo/'},
        {key:'calendario', t:'Calendario', i:'calendar', url:B+'portal/calendario-club/?world=cubo', d:'Las sesiones del Cubo por día; cancelar festivos.'},
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
        {t:'Peticiones de redes',    i:'at',   url:B+'admin/redes/',     d:'Lo que proponen los socios.'}
      ] }
  ];
  function mundoPorClave(k){ for(var i=0;i<MUNDOS.length;i++){ if(MUNDOS[i].key===k) return MUNDOS[i]; } return null; }

  /* ---------- estilos (una vez) ---------- */
  var _cssDone = false;
  function injectCSS() {
    if (_cssDone) return; _cssDone = true;
    var css = document.createElement('style');
    css.setAttribute('data-piel', 'mundos');
    css.textContent =
      '@view-transition{navigation:auto}' +
      /* La barra lateral NO se anima en la transición: se queda quieta (sin
         deslizarse). Solo el contenido hace crossfade. */
      '::view-transition-group(mm-lateral){animation:none}' +
      '.mm-side{display:none}' +
      /* Dentro de un mundo (admin), la barra INFERIOR personal del portal se
         oculta EN TODOS LOS TAMAÑOS: en móvil se colaba (Inicio/Calendario/
         Mensajes de tu zona personal mezclados con el panel, que despistaba).
         Para salir del panel o ir a tu zona personal está la barra de ARRIBA
         (tu nombre → «Cambiar de vista»). */
      'body.mm-on .pt-tabbar{display:none !important}' +
      'body.mm-on.pt-con-tabbar{padding-bottom:24px !important}' +
      '@media (min-width:900px){' +
        '.mm-layout{display:grid;grid-template-columns:262px minmax(0,1fr);gap:26px;' +
          'max-width:1460px;margin:0;padding:20px clamp(18px,3vw,34px) 48px;align-items:start}' +
        '.mm-layout>.mm-main{min-width:0}' +
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
        /* la lateral de mundos DENTRO del panel viejo (.at-side de admin-tabbar) */
        '.at-side .at-mundos{display:flex;flex-direction:column;gap:2px}' +
      '}' +
      /* HUB (Resumen de un mundo) — todos los tamaños */
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
      '.mh-flecha{margin-left:auto;color:var(--mm-acento,#2F6FA8);font-weight:600;font-size:13.5px}' +
      /* tira de cifras en vivo del mundo (encima del hub); si no hay, no ocupa */
      '.mh-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:13px;margin:0 0 24px}' +
      '.mh-stats:empty{display:none;margin:0}' +
      '.mh-stat{background:#fff;border-radius:var(--radio,14px);box-shadow:var(--sombra-suave,0 10px 22px -16px rgba(46,66,86,.5));padding:16px 18px 14px;position:relative;overflow:hidden}' +
      '.mh-stat::before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:var(--mm-acento,#2F6FA8);opacity:.9}' +
      '.mh-stat b{font-family:var(--fuente-titulo);font-weight:700;font-size:clamp(26px,3vw,34px);color:var(--navy,#2E4256);line-height:1;display:block}' +
      '.mh-stat span{font-size:12.5px;color:var(--texto-suave,#6E6656);margin-top:5px;display:block}';

    /* --- NAVEGACIÓN DE MUNDOS EN MÓVIL (<900px) ---------------------------
       La lateral es solo de PC. En el móvil, dentro de un mundo, hacía falta
       una barra para moverse: a otra sección del mundo, cambiar de mundo o
       salir a tu portal. Antes no había NINGUNA y en una subpágina (p. ej.
       «Asistencia») te quedabas sin salida. Solo aparece en páginas de mundo
       del portal (body.mm-on); en el panel viejo (/admin/) manda su barra. */
    css.textContent +=
      '.mm-tab{display:none}' +
      '.mm-sheet-bg{display:none;position:fixed;inset:0;z-index:700;background:rgba(46,66,86,.45);opacity:0;transition:opacity .18s ease}' +
      '.mm-sheet-bg.ver{opacity:1}' +
      '.mm-sheet{position:fixed;left:0;right:0;bottom:0;z-index:701;box-sizing:border-box;max-height:86vh;overflow:auto;' +
        '-webkit-overflow-scrolling:touch;background:var(--crema,#FBF9F4);border-top-left-radius:16px;border-top-right-radius:16px;' +
        'box-shadow:0 -20px 44px -22px rgba(46,66,86,.55);transform:translateY(100%);transition:transform .22s ease;' +
        'padding:16px 16px calc(20px + env(safe-area-inset-bottom))}' +
      '.mm-sheet.ver{transform:none}' +
      '.mm-sheet-cab{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:2px}' +
      '.mm-sheet-cab h2{margin:0;font-family:var(--fuente-titulo,inherit);text-transform:uppercase;font-size:21px;line-height:1.1;color:var(--navy,#2E4256)}' +
      '.mm-sheet-x{flex:0 0 auto;width:40px;height:40px;border-radius:50%;border:1px solid var(--linea-borde,#D4CBB9);background:#fff;color:var(--texto-suave,#6E6656);font-family:inherit;font-size:16px;line-height:1;cursor:pointer}' +
      '.mm-srot{font-size:11px;font-weight:700;letter-spacing:.1em;text-transform:uppercase;color:var(--texto-suave,#6E6656);margin:16px 2px 8px}' +
      '.mm-row,.mm-wrow{display:flex;align-items:center;gap:12px;min-height:48px;box-sizing:border-box;padding:10px 13px;background:#fff;' +
        'border:1px solid var(--linea-marcada,#E4DCCB);border-radius:13px;margin-bottom:8px;text-decoration:none;color:var(--navy,#2E4256);' +
        'font-size:15px;line-height:1.2;box-shadow:0 5px 14px -12px rgba(46,66,86,.32)}' +
      '.mm-row .mm-ic{flex:0 0 22px;width:22px;height:22px;display:grid;place-items:center;color:var(--mm-acento,#2F6FA8)}' +
      '.mm-row .mm-ic svg{width:20px;height:20px}' +
      '.mm-row .mm-rt,.mm-wrow .mm-rt{flex:1 1 auto;min-width:0}' +
      '.mm-row.act{border-color:var(--mm-acento,#2F6FA8);background:color-mix(in srgb, var(--mm-acento,#2F6FA8) 8%, #fff)}' +
      '.mm-row.act .mm-rt{font-weight:700}' +
      '.mm-wrow .pt{flex:0 0 auto;width:12px;height:12px;border-radius:50%;background:var(--pt);box-shadow:0 0 0 3px color-mix(in srgb, var(--pt) 16%, transparent)}' +
      '.mm-wrow.act{border-color:var(--pt);background:color-mix(in srgb, var(--pt) 10%, #fff)}' +
      '.mm-wrow.act .mm-rt{font-weight:700}' +
      '.mm-salir{display:block;width:100%;text-align:center;margin-top:16px;padding:12px;background:none;border:0;' +
        'font-family:inherit;font-size:14px;font-weight:600;color:var(--azul-oscuro,#2F6FA8);text-decoration:underline;cursor:pointer}' +
      '@media (max-width:899px){' +
        'body.mm-on.pt-con-tabbar,body.mm-on{padding-bottom:calc(80px + env(safe-area-inset-bottom)) !important}' +
        'body.mm-on .mm-tab{display:flex;align-items:stretch;gap:2px;position:fixed;left:50%;transform:translateX(-50%);' +
          'bottom:calc(14px + env(safe-area-inset-bottom));z-index:600;box-sizing:border-box;max-width:calc(100% - 20px);' +
          'background:rgba(255,255,255,.9);-webkit-backdrop-filter:saturate(1.4) blur(16px);backdrop-filter:saturate(1.4) blur(16px);' +
          'border:1px solid rgba(30,45,65,.08);border-radius:26px;padding:6px;' +
          'box-shadow:0 10px 26px -8px rgba(30,45,65,.28),0 2px 6px rgba(30,45,65,.10)}' +
        '.mm-tab .mm-tb{flex:1 1 0;min-width:70px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;' +
          'min-height:52px;padding:7px 10px;border-radius:20px;text-decoration:none;color:var(--texto-suave,#6E6656);' +
          'background:none;border:0;cursor:pointer;font-family:inherit}' +
        '.mm-tab .mm-tb .mm-ti{display:grid;place-items:center}' +
        '.mm-tab .mm-tb svg{width:23px;height:23px}' +
        '.mm-tab .mm-tb span:not(.mm-ti){font-size:10.5px;font-weight:600;line-height:1.1}' +
        '.mm-tab .mm-tb.act{background:var(--mm-acento,#2E4256);color:#fff}' +
      '}' +
      '@media (min-width:900px){.mm-tab,.mm-sheet,.mm-sheet-bg{display:none !important}}';
    document.head.appendChild(css);
  }

  function injectPrefetch() {
    try {
      if (document.querySelector('script[data-mm-prefetch]')) return;
      var sr = document.createElement('script');
      sr.type = 'speculationrules'; sr.setAttribute('data-mm-prefetch', '1');
      sr.textContent = '{"prefetch":[{"source":"document","where":{"href_matches":"/portal/natacion*"},"eagerness":"moderate"}]}';
      document.head.appendChild(sr);
    } catch (e) {}
  }

  /* ---------- render de la barra (compartido por los dos modos) ---------- */
  function worldRowHtml(w, activeKey) {
    var act = w.key === activeKey;
    return '<a class="mm-w" href="' + esc(w.home) + '" style="--pt:' + w.dot + '" ' +
      'aria-current="' + act + '"' + (act ? ' aria-label="Estás en ' + esc(w.nombre) + '"' : '') + '>' +
      '<span class="pt"></span><span class="nm">' + esc(w.nombre) + '</span></a>';
  }
  function worldsHtml(keys, activeKey) {
    var list;
    if (!keys) { list = MUNDOS; }                                   // null = todos (admin)
    else {
      list = MUNDOS.filter(function (w) { return keys.indexOf(w.key) !== -1; });
      if (!list.some(function (w) { return w.key === activeKey; })) {
        var actual = mundoPorClave(activeKey);
        if (actual) list = [actual].concat(list);                   // el actual siempre visible
      }
    }
    return list.map(function (w) { return worldRowHtml(w, activeKey); }).join('');
  }
  function navHtml(M, esActivo) {
    if (!M.screens || !M.screens.length) return '';
    return '<div class="mm-navt">' + esc(M.nombre) + '</div><nav class="mm-nav" aria-label="Secciones de ' + esc(M.nombre) + '">' +
      M.screens.map(function (s, idx) {
        var act = esActivo(s, idx);
        return '<a class="mm-i" href="' + esc(s.url) + '"' + (s.ext ? ' target="_blank" rel="noopener"' : '') +
          ' aria-current="' + act + '">' +
          '<span class="mm-ic">' + ico(s.i) + '</span><span>' + esc(s.t) + (s.ext ? ' ↗' : '') + '</span></a>';
      }).join('') + '</nav>';
  }
  function sideInnerHtml(M, esActivo, keys) {
    return '<div class="mm-rotulo">Mundos <span class="q">· cambia de un clic</span></div>' +
      '<div class="mm-worlds">' + worldsHtml(keys, M.key) + '</div>' +
      '<div class="mm-sep"></div>' +
      navHtml(M, esActivo) +
      '<p class="mm-nota">Entras en los mundos para los que tienes permiso. Cada persona ve los suyos.</p>';
  }
  function hubCardsHtml(M) {
    return (M.screens || []).filter(function (s) { return s.key !== 'resumen'; }).map(function (s) {
      return '<a class="mh-card" href="' + esc(s.url) + '"' + (s.ext ? ' target="_blank" rel="noopener"' : '') + '>' +
        '<span class="ico">' + ico(s.i) + '</span>' +
        '<h3>' + esc(s.t) + '</h3>' +
        '<p class="d">' + esc(s.d || '') + '</p>' +
        '<span class="pie">' + (s.pill ? '<span class="mh-pill">' + esc(s.pill) + '</span>' : '') +
          '<span class="mh-flecha">' + (s.ext ? 'Ver ↗' : 'Abrir →') + '</span></span></a>';
    }).join('');
  }
  function renderHub(el, M) {
    el.innerHTML =
      '<div class="mh-cab"><div class="mh-eyebrow">Mundo</div>' +
        '<h1><span class="pt-g"></span>' + esc(M.nombre.replace(/\s*·\s*Club$/, '')) + '</h1>' +
        (M.frase ? '<p>' + esc(M.frase) + '</p>' : '') + '</div>' +
      '<div class="mh-stats" data-mh-stats></div>' +
      '<p class="mh-rot">Herramientas de este mundo</p>' +
      '<div class="mh-hub">' + hubCardsHtml(M) + '</div>';
    // cifras en vivo del mundo (si hay cliente/sesión); si no, se queda sin tira
    var c = window.APOLANA_DB;
    if (c && c.rpc) {
      (c.auth && c.auth.getSession ? c.auth.getSession() : Promise.resolve())
        .then(function () { return c.rpc('mundo_stats', { p_world: M.key }); })
        .then(function (r) {
          if (!r || r.error || !Array.isArray(r.data) || !r.data.length) return;
          var box = el.querySelector('[data-mh-stats]'); if (!box) return;
          box.innerHTML = r.data.map(function (s) {
            return '<div class="mh-stat"><b>' + esc(s.n) + '</b><span>' + esc(s.l) + '</span></div>';
          }).join('');
        }).catch(function () {});
    }
  }

  /* ---------- acceso por persona (RPC mis_mundos) ---------- */
  var CACHE_KEY = 'apolana-mis-mundos';
  function leerCache() {
    try { var v = sessionStorage.getItem(CACHE_KEY); if (v === 'todos') return null; if (v) return JSON.parse(v); } catch (e) {}
    return undefined;
  }
  function guardarCache(keys) { try { sessionStorage.setItem(CACHE_KEY, keys == null ? 'todos' : JSON.stringify(keys)); } catch (e) {} }
  function cargarMisMundos(onData) {
    var intentos = 0;
    (function go() {
      var c = window.APOLANA_DB;
      if (!c || !c.rpc) { if (intentos++ < 6) setTimeout(go, 400); return; }
      var listo = (c.auth && c.auth.getSession) ? c.auth.getSession() : Promise.resolve();
      listo.then(function () { return c.rpc('mis_mundos'); }).then(function (r) {
        if (!r || r.error || !Array.isArray(r.data)) return;
        var keys = r.data;
        var todas = MUNDOS.every(function (w) { return keys.indexOf(w.key) !== -1; });
        var val = todas ? null : keys;   // admin (todos) -> null, a prueba de mundos futuros
        guardarCache(val); onData(val);
      }).catch(function () {});
    })();
  }

  /* ---------- resolver el mundo/pantalla desde una URL del panel ---------- */
  function folderKey(u) {
    var s = String(u || '');
    var i = s.indexOf('/admin/');
    if (i !== -1) s = s.slice(i + 7);
    else { i = s.indexOf('admin/'); if (i === -1) return ''; s = s.slice(i + 6); }
    if (s.indexOf('#') !== -1) return '';   // pestañas del inicio (#noticias…): no mapean
    var q = '', qi = s.indexOf('?');
    if (qi !== -1) {
      try { var p = new URLSearchParams(s.slice(qi)); var sec = p.get('seccion'), tipo = p.get('tipo');
        if (sec) q = '?seccion=' + sec.toLowerCase(); else if (tipo) q = '?tipo=' + tipo.toLowerCase(); } catch (e) {}
      s = s.slice(0, qi);
    }
    s = s.replace(/index\.html?$/i, '').replace(/\/+$/, '');
    var folder = (s.split('/')[0] || '');
    return folder ? folder + q : '';
  }
  var _idx = null;
  function urlIndex() {
    if (_idx) return _idx; _idx = {};
    MUNDOS.forEach(function (w) {
      (w.screens || []).forEach(function (s, i) {
        var k = folderKey(s.url);
        if (k && !(k in _idx)) _idx[k] = { world: w.key, idx: i };
      });
    });
    return _idx;
  }
  var COARSE = {
    atletas:'general', socios:'general', cobros:'general', tarifas:'general', 'pagos-online':'general', 'cubo-pagos':'general', pedidos:'general',
    paginas:'general', contenido:'general', imagenes:'general', biblioteca:'general', colaboradores:'general', mapa:'general',
    documentos:'general', estadisticas:'general', informes:'general', usuarios:'general', importar:'general', contactos:'general',
    grupos:'general', mundos:'general', campo:'general', buzon:'general', automatizaciones:'general',
    cubo:'cubo', 'cubo-altas':'cubo', 'cubo-prueba':'cubo', asistencia:'cubo',
    natacion:'natacion',
    tests:'pista', pruebas:'pista', competiciones:'pista', confirmaciones:'pista', liga:'pista', records:'pista', palmares:'pista', retos:'pista',
    repartir:'escuela-atl', historico:'escuela-atl', altas:'general',
    eventos:'comunicacion', enlaces:'general', redes:'comunicacion', plantillas:'comunicacion', noticias:'comunicacion', 'avisos-push':'comunicacion'
  };
  function resolverURL() {
    if (location.pathname.indexOf('/admin/') === -1) return null;
    var cur = folderKey(location.pathname + location.search);
    var map = urlIndex();
    if (cur && map[cur]) return { world: map[cur].world, screenIdx: map[cur].idx };
    var folderOnly = cur.split('?')[0];
    if (folderOnly && map[folderOnly]) return { world: map[folderOnly].world, screenIdx: map[folderOnly].idx };
    var sec = '';
    try { sec = (new URLSearchParams(location.search).get('seccion') || '').toLowerCase(); } catch (e) {}
    var bySec = { cubo:'cubo', escuela:'escuela-atl', competicion:'pista', running:'running' };
    if (bySec[sec]) return { world: bySec[sec], screenIdx: -1 };
    return { world: (COARSE[folderOnly] || 'general'), screenIdx: -1 };
  }

  /* ============================================================
     API compartida (la usa admin-tabbar.js para el panel)
     ============================================================ */
  window.APOLANA_MUNDOS_SHELL = {
    MUNDOS: MUNDOS,
    injectCSS: injectCSS,
    resolverURL: resolverURL,
    /* HTML del hub de un mundo (tarjetas de herramientas), para páginas que
       pintan su propio Resumen y quieren añadir el hub debajo. */
    hubHTML: function (worldKey) {
      var M = mundoPorClave(worldKey);
      return M ? '<div class="mh-hub">' + hubCardsHtml(M) + '</div>' : '';
    },
    /* Rellena un elemento (la .at-side del panel) con la barra de mundos.
       `screenIdx` marca la pantalla activa por índice (-1 = ninguna). */
    montarEn: function (el, worldKey, screenIdx) {
      if (!el) return;
      injectCSS();
      var M = mundoPorClave(worldKey) || MUNDOS[0];
      el.style.setProperty('--mm-acento', M.dot);
      var esActivo = function (s, idx) { return idx === screenIdx; };
      var cache = leerCache();
      var initKeys = (cache === undefined) ? [worldKey] : cache;
      el.innerHTML = sideInnerHtml(M, esActivo, initKeys);
      var box = el.querySelector('.mm-worlds');
      cargarMisMundos(function (val) { if (box) box.innerHTML = worldsHtml(val, worldKey); });
    }
  };

  /* ============================================================
     Modo PORTAL (auto-montaje) — solo si la página declara el mundo
     ============================================================ */
  var CFG = window.APOLANA_MUNDO;
  if (!CFG || !CFG.world) return;              // panel: solo exponemos la API
  var M = mundoPorClave(CFG.world);
  if (!M) return;

  injectCSS();
  injectPrefetch();

  function montar() {
    var content = CFG.contentSel ? document.querySelector(CFG.contentSel) : null;
    if (!content) return;
    if (document.querySelector('.mm-layout')) return;

    if (CFG.home) renderHub(content, M);

    document.body.classList.add('mm-on');
    var acento = M.dot;

    var side = document.createElement('aside');
    side.className = 'mm-side';
    side.style.setProperty('--mm-acento', acento);
    side.setAttribute('aria-label', 'Mundos del panel');

    var esActivo = function (s) { return s.key === (CFG.screen || 'resumen'); };
    var cache = leerCache();
    var initKeys = (cache === undefined) ? [M.key] : cache;
    side.innerHTML = '<div class="mm-isla">' + sideInnerHtml(M, esActivo, initKeys) + '</div>';

    var layout = document.createElement('div');
    layout.className = 'mm-layout';
    layout.style.setProperty('--mm-acento', acento);
    content.parentNode.insertBefore(layout, content);
    var main = document.createElement('div');
    main.className = 'mm-main';
    main.appendChild(content);
    layout.appendChild(side);
    layout.appendChild(main);

    var box = side.querySelector('.mm-worlds');
    cargarMisMundos(function (val) { if (box) box.innerHTML = worldsHtml(val, M.key); });

    montarBarraMovil(M);   // en móvil, la barra de navegación del mundo
  }

  /* ---------- barra de mundo para MÓVIL (<900px) ----------
     Tres pestañas: el Resumen del mundo (sus tarjetas), «Secciones» (una hoja
     con todas las pantallas del mundo + cambiar de mundo + salir a tu portal)
     y tu portal personal. Reemplaza a la barra personal, que aquí se oculta. */
  var _menuIco = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' +
    '<circle cx="5" cy="12" r="1.9"/><circle cx="12" cy="12" r="1.9"/><circle cx="19" cy="12" r="1.9"/></svg>';
  function montarBarraMovil(M) {
    if (document.querySelector('.mm-tab')) return;
    var acento = M.dot, salir = B + 'portal/';

    var bar = document.createElement('nav');
    bar.className = 'mm-tab';
    bar.style.setProperty('--mm-acento', acento);
    bar.setAttribute('aria-label', 'Navegación de ' + M.nombre);
    bar.innerHTML =
      '<a class="mm-tb act" href="' + esc(M.home) + '"><span class="mm-ti">' + ico('grid') + '</span><span>Mundo</span></a>' +
      '<button type="button" class="mm-tb mm-menu" aria-haspopup="dialog"><span class="mm-ti">' + _menuIco + '</span><span>Secciones</span></button>' +
      '<a class="mm-tb" href="' + esc(salir) + '"><span class="mm-ti">' + ico('user') + '</span><span>Mi portal</span></a>';
    document.body.appendChild(bar);

    var bg = document.createElement('div'); bg.className = 'mm-sheet-bg';
    var sheet = document.createElement('div');
    sheet.className = 'mm-sheet';
    sheet.setAttribute('role', 'dialog'); sheet.setAttribute('aria-modal', 'true');
    sheet.setAttribute('aria-label', 'Secciones de ' + M.nombre);
    sheet.style.setProperty('--mm-acento', acento);

    function screensSheet() {
      return (M.screens || []).map(function (s) {
        var act = s.key === (CFG.screen || 'resumen');
        return '<a class="mm-row' + (act ? ' act' : '') + '" href="' + esc(s.url) + '"' +
          (s.ext ? ' target="_blank" rel="noopener"' : '') + '>' +
          '<span class="mm-ic">' + ico(s.i) + '</span>' +
          '<span class="mm-rt">' + esc(s.t) + (s.ext ? ' ↗' : '') + '</span></a>';
      }).join('');
    }
    function worldsSheet(keys) {
      var list = (!keys) ? MUNDOS : MUNDOS.filter(function (w) { return keys.indexOf(w.key) !== -1; });
      if (!list.some(function (w) { return w.key === M.key; })) {
        var a = mundoPorClave(M.key); if (a) list = [a].concat(list);
      }
      return list.map(function (w) {
        var act = w.key === M.key;
        return '<a class="mm-wrow' + (act ? ' act' : '') + '" href="' + esc(w.home) + '" style="--pt:' + w.dot + '">' +
          '<span class="pt"></span><span class="mm-rt">' + esc(w.nombre) + '</span></a>';
      }).join('');
    }
    function pinta(keys) {
      sheet.innerHTML =
        '<div class="mm-sheet-cab"><h2>' + esc(M.nombre.replace(/\s*·\s*Club$/, '')) + '</h2>' +
          '<button type="button" class="mm-sheet-x" aria-label="Cerrar">✕</button></div>' +
        '<div class="mm-srot">Secciones</div>' + screensSheet() +
        '<div class="mm-srot">Cambiar de mundo</div>' + worldsSheet(keys) +
        '<a class="mm-salir" href="' + esc(salir) + '">Salir a mi portal</a>';
      var x = sheet.querySelector('.mm-sheet-x'); if (x) x.addEventListener('click', cerrar);
    }
    var cache = leerCache();
    pinta(cache === undefined ? [M.key] : cache);
    cargarMisMundos(function (val) { pinta(val); });

    document.body.appendChild(bg);
    document.body.appendChild(sheet);

    function abrir() {
      bg.style.display = 'block';
      void bg.offsetWidth;                       // fuerza el reflow para que la transición se vea
      bg.classList.add('ver'); sheet.classList.add('ver');
      document.body.style.overflow = 'hidden';
    }
    function cerrar() {
      bg.classList.remove('ver'); sheet.classList.remove('ver');
      document.body.style.overflow = '';
      setTimeout(function () { bg.style.display = 'none'; }, 220);
    }
    bar.querySelector('.mm-menu').addEventListener('click', abrir);
    bg.addEventListener('click', cerrar);
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') cerrar(); });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', montar);
  else montar();
})();
