/* ============================================================
   UNA SOLA NAVEGACIÓN DEL PANEL · Club Atletismo Apolana
   ------------------------------------------------------------
   El dueño del club lo dijo usándolo en el móvil: «hay dos menús,
   uno abajo y otro arriba, no sé dónde están las cosas». Así que
   hay uno.

     · Por debajo de 900 px la barra lateral NO EXISTE. No se
       colapsa ni se esconde en un cajón: desaparece. La única
       navegación es la barra de cinco de abajo.
     · A partir de 900 px vuelve la lateral y la barra de abajo
       desaparece. Nunca se ven las dos a la vez.

         Inicio · Pista · Personas · Dinero · Menú

     · «Menú» va en tres capas: buscador, «las que más usas» y
       «todo, por bloques» (plegado y con su recuento).
     · El buscador vive en la cabecera navy de TODAS las páginas
       del panel, no enterrado dentro de «Menú»: enterrado está a
       dos toques, en la cabecera está a uno. Y busca pantallas y
       personas a la vez, que con 32 pantallas y 420 atletas es el
       camino más corto para todo.
     · Cada resultado dice su bloque debajo («Actividad ·
       notificaciones que se envían»), que es lo que evita
       confundir dos pantallas de nombre parecido.

   Mismo aspecto que la barra del portal (assets/js/portal-tabbar.js):
   iconos de línea de 24 px, el activo se distingue por COLOR
   (#2F6FA8 sobre #6E6656) y objetivos táctiles de 48 px.

   Solo con la sesión de administración ya abierta.
   ============================================================ */
(function () {
  'use strict';

  var ALTO  = 78;    /* hueco que se reserva al final del contenido */
  var CORTE = 899;   /* hasta aquí manda la barra de abajo; a partir de 900, la lateral */

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
              '<circle cx="5" cy="12" r="1.9"/><circle cx="12" cy="12" r="1.9"/><circle cx="19" cy="12" r="1.9"/></svg>',
    lupa:     '<svg class="lupa" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" ' +
              'stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="6.6"/><path d="M16 16l4.5 4.5"/></svg>'
  };

  /* ---------- estilos ---------- */
  var css = document.createElement('style');
  css.setAttribute('data-piel', 'navegacion');
  css.textContent =
    /* la barra de abajo solo existe en móvil; la hoja y el buscador, en las dos */
    '.at-tabbar{display:none}' +
    '.at-hoja[hidden],.at-fondo[hidden],.at-tabbar[hidden]{display:none !important}' +

    /* --- buscador de la cabecera navy (todas las páginas del panel) --- */
    '.adm-top,.admin-top{flex-wrap:wrap}' +
    '.adm-top .izq,.admin-top .marca{order:1}' +
    '.adm-top .der,.admin-top .sesion{order:3}' +
    '.adm-top .at-busca-cab,.admin-top .at-busca-cab{order:2;display:flex;align-items:center;gap:11px;box-sizing:border-box;' +
      /* `min-width:0` es imprescindible: sin él, un título largo como
         «Biblioteca de imágenes» empuja el buscador y la cabecera se
         sale por la derecha. */
      'flex:1 1 160px;min-width:0;max-width:380px;margin:0 12px;min-height:44px;padding:10px 15px;' +
      'border:0;border-radius:999px;background:rgba(255,255,255,.12);cursor:pointer;text-align:left;' +
      'font-family:inherit;font-size:15px;line-height:1.2;color:rgba(255,255,255,.72);' +
      '-webkit-tap-highlight-color:transparent}' +
    '.adm-top .at-busca-cab:hover,.admin-top .at-busca-cab:hover{background:rgba(255,255,255,.2);color:#fff}' +
    '.adm-top .at-busca-cab:focus-visible,.admin-top .at-busca-cab:focus-visible{outline:2px solid #9FC7E8;outline-offset:2px}' +
    '.adm-top .at-busca-cab .lupa,.admin-top .at-busca-cab .lupa{flex:0 0 18px;width:18px;height:18px}' +
    /* Antes de que llegue a apretarse, el buscador se baja solo a su
       propia línea. Vale para pantallas medianas y también para quien
       tiene el navegador con la letra muy grande. */
    '@media (max-width:1024px){' +
      '.adm-top .at-busca-cab,.admin-top .at-busca-cab{order:3;flex:1 1 100%;max-width:none;margin:6px 0 0}' +
      '.adm-top .der,.admin-top .sesion{order:2}' +
    '}' +
    '.adm-top .at-busca-cab span,.admin-top .at-busca-cab span{flex:1 1 auto;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +

    /* --- la hoja: buscador, las que más usas y todo por bloques --- */
    '.at-fondo{display:block;position:fixed;inset:0;z-index:700;background:rgba(46,66,86,.45);' +
      'opacity:0;transition:opacity .18s ease}' +
    '.at-fondo.ver{opacity:1}' +
    '.at-hoja{display:flex;flex-direction:column;position:fixed;left:0;right:0;bottom:0;z-index:701;' +
      'box-sizing:border-box;max-width:100%;max-height:86vh;' +
      'background:var(--crema,#FBF9F4);border-top-left-radius:14px;border-top-right-radius:14px;' +
      'box-shadow:0 -20px 44px -22px rgba(46,66,86,.55);' +
      'transform:translateY(100%);transition:transform .22s ease}' +
    '.at-hoja.ver{transform:none}' +
    '.at-hoja .cab{flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;gap:12px;' +
      'padding:14px 18px 10px}' +
    '.at-hoja .cab h2{margin:0;font-family:var(--fuente-titulo,inherit);text-transform:uppercase;' +
      'font-size:21px;line-height:1.1;color:var(--navy,#2E4256)}' +
    '.at-hoja .cerrar{flex:0 0 auto;min-height:44px;min-width:44px;border:0;background:none;cursor:pointer;' +
      'font-size:15px;font-weight:600;font-family:inherit;color:var(--azul-oscuro,#2F6FA8);padding:0 6px;' +
      '-webkit-tap-highlight-color:transparent}' +
    '.at-hoja .buscar{flex:0 0 auto;position:relative;padding:0 18px 12px}' +
    '.at-hoja .buscar .lupa{position:absolute;left:33px;top:50%;margin-top:-15px;width:18px;height:18px;' +
      'color:var(--texto-suave,#6E6656);pointer-events:none}' +
    '.at-hoja .buscar input{box-sizing:border-box;width:100%;min-height:44px;padding:11px 15px 11px 40px;' +
      'border:1px solid var(--linea-borde,#D4CBB9);border-radius:999px;background:#fff;' +
      'font-family:inherit;font-size:16px;color:var(--navy,#2E4256)}' +
    '.at-hoja .buscar input:focus{outline:2px solid var(--azul-filete, #3B85C0);border-color:var(--azul-filete, #3B85C0)}' +
    '.at-hoja .cuerpo{flex:1 1 auto;overflow-y:auto;-webkit-overflow-scrolling:touch;' +
      'padding:0 18px calc(20px + env(safe-area-inset-bottom))}' +

    /* rótulo de bloque: 13 px, minúscula y sin espaciado (kit, punto 0) */
    '.at-hoja h3{margin:0 0 7px;font-family:inherit;font-size:13px;font-weight:600;' +
      'letter-spacing:normal;text-transform:none;color:var(--texto-suave,#6E6656)}' +
    '.at-hoja .seccion{padding-top:13px;margin-top:13px;border-top:1px solid var(--linea-marcada,#E4DCCB)}' +
    '.at-hoja .seccion:first-child{padding-top:0;margin-top:0;border-top:0}' +
    '.at-hoja .seccion[hidden]+.seccion{padding-top:0;margin-top:0;border-top:0}' +
    '.at-hoja .nota{margin:9px 2px 0;font-size:14px;line-height:1.45;color:var(--texto-suave,#6E6656)}' +

    /* resultados: nombre y, debajo, su bloque */
    '.at-hoja .lista{background:#fff;border:1px solid var(--linea-marcada,#E4DCCB);border-radius:14px;overflow:hidden}' +
    '.at-hoja .lista a{display:flex;align-items:center;gap:12px;min-height:48px;box-sizing:border-box;' +
      'padding:11px 15px;border-top:1px solid var(--crema-media,#EFE9DC);text-decoration:none;' +
      'color:var(--navy,#2E4256);-webkit-tap-highlight-color:transparent}' +
    '.at-hoja .lista a:first-child{border-top:0}' +
    '.at-hoja .lista a:hover{background:var(--crema,#FBF9F4)}' +
    '.at-hoja .lista a .txt{flex:1 1 auto;min-width:0;display:flex;flex-direction:column;gap:1px}' +
    '.at-hoja .lista a .t{font-size:15px;line-height:1.3;color:var(--navy,#2E4256)}' +
    '.at-hoja .lista a .b{font-size:14px;line-height:1.3;color:var(--texto-suave,#6E6656)}' +
    '.at-hoja .lista a .chev{flex:0 0 auto;font-style:normal;font-size:19px;line-height:1;color:var(--texto-suave,#6E6656)}' +
    '.at-hoja .lista a.aqui .t{font-weight:600;color:var(--azul-oscuro,#2F6FA8)}' +

    /* «Las que más usas»: rejilla de dos */
    '.at-hoja .atajos{display:grid;grid-template-columns:1fr 1fr;gap:9px}' +
    '.at-hoja .atajos a{display:flex;align-items:center;min-height:48px;box-sizing:border-box;' +
      'padding:10px 14px;border:1px solid var(--linea-marcada,#E4DCCB);border-radius:12px;background:#fff;' +
      'text-decoration:none;color:var(--navy,#2E4256);font-size:15px;line-height:1.25;' +
      '-webkit-tap-highlight-color:transparent}' +
    '.at-hoja .atajos a:hover{border-color:var(--azul-filete, #3B85C0)}' +

    /* «Todo, por bloques»: plegados y con su recuento al lado */
    '.at-hoja .bloque{border-top:1px solid var(--crema-media,#EFE9DC)}' +
    '.at-hoja .bloque:first-of-type{border-top:0}' +
    '.at-hoja .bloque > summary{list-style:none;cursor:pointer;user-select:none;display:flex;align-items:center;' +
      'gap:12px;min-height:48px;box-sizing:border-box;padding:11px 2px;font-size:15px;color:var(--navy,#2E4256);' +
      '-webkit-tap-highlight-color:transparent}' +
    '.at-hoja .bloque > summary::-webkit-details-marker{display:none}' +
    '.at-hoja .bloque > summary .nom{flex:1 1 auto;min-width:0}' +
    '.at-hoja .bloque > summary .n{font-family:var(--fuente-dato,inherit);font-size:14px;color:var(--texto-suave,#6E6656)}' +
    '.at-hoja .bloque > summary .fl{flex:0 0 auto;width:7px;height:7px;margin-right:4px;' +
      'border-right:2px solid var(--texto-suave,#6E6656);border-bottom:2px solid var(--texto-suave,#6E6656);' +
      'transform:rotate(45deg) translate(-2px,-2px);transition:transform .18s ease}' +
    '.at-hoja .bloque[open] > summary .fl{transform:rotate(-135deg) translate(-2px,-2px)}' +
    '.at-hoja .bloque > .lista{margin:0 0 12px}' +
    '.at-hoja .oculto-busca{display:none !important}' +
    'body.at-hoja-abierta{overflow:hidden}' +

    /* --- de 900 px para arriba la hoja es una ventana centrada arriba --- */
    '@media (min-width:' + (CORTE + 1) + 'px){' +
      '.at-hoja{left:50%;right:auto;bottom:auto;top:7vh;width:min(620px,calc(100vw - 48px));' +
        'max-height:76vh;border-radius:14px;box-shadow:0 30px 70px -25px rgba(46,66,86,.6);' +
        'transform:translate(-50%,14px);opacity:0}' +
      '.at-hoja.ver{transform:translate(-50%,0);opacity:1}' +
      '.at-hoja .cuerpo{padding-bottom:20px}' +
    '}' +

    /* --- de 899 px para abajo: barra de cinco y ni rastro de la lateral --- */
    '@media (max-width:' + CORTE + 'px){' +
      'body.at-con-tabbar{padding-bottom:calc(' + ALTO + 'px + 20px + env(safe-area-inset-bottom))}' +
      /* Barra flotante en píldora, como la maqueta de admin (con texto bajo el
         icono, que la maqueta de admin sí lo lleva: Resumen/Socios/Compes/Más). */
      '.at-tabbar{display:flex;align-items:stretch;gap:2px;position:fixed;left:50%;transform:translateX(-50%);right:auto;bottom:calc(14px + env(safe-area-inset-bottom));z-index:600;' +
        'box-sizing:border-box;max-width:calc(100% - 20px);' +
        'background:rgba(255,255,255,.9);-webkit-backdrop-filter:saturate(1.4) blur(16px);backdrop-filter:saturate(1.4) blur(16px);' +
        'border:1px solid rgba(30,45,65,.08);border-radius:26px;' +
        'padding:6px;box-shadow:0 10px 26px -8px rgba(30,45,65,.28),0 2px 6px rgba(30,45,65,.10)}' +
      '.at-tabbar a,.at-tabbar button{flex:1 1 0;min-width:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;' +
        'min-height:48px;padding:6px 4px;border-radius:18px;text-decoration:none;color:var(--texto-suave,#6E6656);' +
        'background:none;border:0;cursor:pointer;' +
        'font-family:inherit;font-size:12px;font-weight:400;line-height:1.2;letter-spacing:normal;text-transform:none;' +
        '-webkit-tap-highlight-color:transparent}' +
      '.at-tabbar span{display:block;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.at-tabbar .ic{width:23px;height:23px;flex:0 0 23px}' +
      /* el activo va en píldora navy, como las demás zonas */
      '.at-tabbar .activo{background:var(--navy,#2E4256);color:#fff}' +
      '.at-tabbar .activo span{font-weight:600}' +
      /* el buscador de la cabecera pasa a su propia línea, a ancho completo,
         y la sesión se queda arriba con el nombre de la pantalla */
      '.adm-top .der,.admin-top .sesion{order:2}' +
      '.adm-top .at-busca-cab,.admin-top .at-busca-cab{order:3;flex:1 1 100%;max-width:none;margin:2px 0 0}' +
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

  /* ============================================================
     El panel entero, en un solo sitio
     ------------------------------------------------------------
     Cada pantalla trae su bloque y una línea de qué hace: es lo
     que sale debajo de cada resultado del buscador y lo que evita
     confundir «Avisos al móvil» con «Franja informativa».

     `panel: true` marca lo que NO es un destino: son pestañas de
     contenido dentro del inicio del panel (#noticias, #avisos,
     #tienda, #buzon). Se buscan, porque hay que poder llegar,
     pero no salen en «Todo, por bloques»: el menú solo lleva a
     destinos reales.
     ============================================================ */
  function mapa() {
    var r = raiz();
    return [
      { t: '', enlaces: [
        { txt: 'Inicio del panel', url: r,           desc: 'lo que hay que resolver hoy', ancho: true },
        { txt: 'En la pista',      url: r + 'campo/', desc: 'pasar lista y ver los grupos', ancho: true }
      ] },
      { t: 'Personas', enlaces: [
        { txt: 'Atletas',                 url: r + 'atletas/',        desc: 'las fichas de los socios' },
        { txt: 'Importar personas',       url: r + 'importar/',       desc: 'altas en bloque desde un archivo' },
        { txt: 'Grupos de entrenamiento', url: r + 'grupos/',         desc: 'horarios, entrenador y cuota' },
        { txt: 'Quién entra al panel',    url: r + 'usuarios/',       desc: 'cuentas, roles y permisos' },
        { txt: 'Quién va a ir',           url: r + 'confirmaciones/', desc: 'confirmaciones para una carrera' }
      ] },
      { t: 'Dinero', enlaces: [
        /* Las altas van en Dinero y no en Personas por quién las trabaja:
           en septiembre las revisa el tesorero, y el tesorero solo ve este
           bloque. Además un alta trae la forma de pago y el número de
           cuenta, que es por donde empieza el recibo. */
        { txt: 'Altas que entran',  url: r + 'altas/',        desc: 'lo que rellenan las familias en la web' },
        { txt: 'Cobros y recibos',  url: r + 'cobros/',       desc: 'remesas, devueltos e impagados' },
        { txt: 'Tarifas',           url: r + 'tarifas/',      desc: 'los precios de cada cuota' },
        { txt: 'Pedidos de ropa',   url: r + 'pedidos/',      desc: 'equipación pedida y entregada' },
        { txt: 'Pagos con tarjeta', url: r + 'pagos-online/', desc: 'lo que se cobra por internet' }
      ] },
      { t: 'Actividad', enlaces: [
        { txt: 'Calendario y eventos', url: r + 'eventos/',       desc: 'las fechas del club' },
        { txt: 'Competiciones',        url: r + 'competiciones/', desc: 'carreras e inscripciones' },
        { txt: 'Liga Apolana',         url: r + 'liga/',          desc: 'clasificación y puntos' },
        { txt: 'El Cubo',              url: r + 'cubo/',          desc: 'clases de fuerza y bonos' },
        { txt: 'Batería de tests',     url: r + 'tests/',         desc: 'pruebas físicas y marcas' },
        { txt: 'Retos y medallas',     url: r + 'retos/',         desc: 'los logros de los atletas' },
        { txt: 'Catálogo de pruebas',  url: r + 'pruebas/',       desc: 'distancias y pruebas' },
        { txt: 'Avisos al móvil',      url: r + 'avisos-push/',   desc: 'notificaciones que se envían' }
      ] },
      /* Esta no es del panel, es del portal, pero se busca desde aquí:
         quien quiere que le lleguen los avisos a SU teléfono entra al
         panel a buscarlo y no lo encuentra, porque desde el panel se
         mandan, no se reciben. */
      { t: 'Tu cuenta', enlaces: [
        { txt: 'Recibir avisos en mi móvil', url: base() + 'portal/avisos/',
          desc: 'activarlos en tu propio teléfono' },
        { txt: 'Mi perfil',                  url: base() + 'portal/perfil/',
          desc: 'tu foto, tu nombre y tu contraseña' },
        { txt: 'Ver la app como socio',      url: base() + 'portal/',
          desc: 'el portal, lo que ve la gente del club' }
      ] },
      { t: 'La web', enlaces: [
        { txt: 'Franja informativa',    url: r + '#avisos',   desc: 'el aviso de la portada', panel: true },
        { txt: 'Noticias',              url: r + '#noticias', desc: 'lo que se publica en la web', panel: true },
        { txt: 'Tienda',                url: r + '#tienda',   desc: 'los productos del club', panel: true },
        { txt: 'Páginas',               url: r + 'paginas/',      desc: 'las páginas de la web' },
        { txt: 'Textos de las páginas', url: r + 'contenido/',    desc: 'lo que pone en cada una' },
        { txt: 'Fotos de la web',       url: r + 'imagenes/',     desc: 'las imágenes de cada página' },
        { txt: 'Biblioteca de fotos',   url: r + 'biblioteca/',   desc: 'todas las fotos subidas' },
        { txt: 'Colaboradores',         url: r + 'colaboradores/', desc: 'patrocinadores y logos' },
        { txt: 'Documentos',            url: r + 'documentos/',   desc: 'papeles y autorizaciones' },
        { txt: 'Peticiones de redes',   url: r + 'redes/',        desc: 'lo que proponen los socios' },
        { txt: 'Mapa de contenido',     url: r + 'mapa/',         desc: 'qué hay en cada página' }
      ] },
      { t: 'Club', enlaces: [
        { txt: 'Personas de contacto',     url: r + 'contactos/',        desc: 'quién lleva cada sección y su teléfono' },
        { txt: 'Buzón',                    url: r + 'buzon/',            desc: 'mensajes de contacto' },
        { txt: 'Buzón',                    url: r + '#buzon',            desc: 'solicitudes de inscripción', panel: true },
        { txt: 'Se pone solo',             url: r + 'automatizaciones/', desc: 'lo que se publica sin tocar nada' },
        { txt: 'Plantillas de email',      url: r + 'plantillas/',       desc: 'respuestas ya escritas' },
        { txt: 'Récords',                  url: r + 'records/',          desc: 'las mejores marcas del club' },
        { txt: 'Palmarés',                 url: r + 'palmares/',         desc: 'medallas y podios' },
        { txt: 'Estadísticas del club',    url: r + 'estadisticas/',     desc: 'los números del club' },
        { txt: 'Informes y datos',         url: r + 'informes/',         desc: 'informes para exportar' },
        { txt: 'Histórico de la escuela',  url: r + 'historico/',        desc: 'las temporadas pasadas' }
      ] }
    ];
  }

  /* Todas las pantallas en una lista plana, con su bloque ya puesto. */
  var PLANO = null;
  function plano() {
    if (PLANO) return PLANO;
    PLANO = [];
    mapa().forEach(function (b) {
      b.enlaces.forEach(function (e) {
        PLANO.push({
          txt: e.txt, url: e.url, desc: e.desc || '', panel: !!e.panel,
          bloque: b.t || 'El panel',
          clave: clave(e.url),
          busca: palabras(e.txt, b.t, e.desc)
        });
      });
    });
    return PLANO;
  }

  /* La llave con la que se cuenta el uso: la carpeta («atletas») o
     el panel («#avisos»). No sale del navegador de cada persona. */
  function clave(url) {
    var h = url.indexOf('#');
    if (h !== -1) return url.slice(h);
    var m = url.match(/admin\/(.*)$/);
    return m ? m[1].replace(/\/+$/, '') : '';
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

  /* ============================================================
     Lo que abre cada persona
     ------------------------------------------------------------
     «En la práctica cada uno usa cinco o seis pantallas de las 32».
     El recuento se guarda en el propio navegador: no hace falta
     base de datos y no sale de ahí.
     ============================================================ */
  var LLAVE_USO = 'apolana-panel-uso';
  function uso() {
    try { return JSON.parse(localStorage.getItem(LLAVE_USO) || '{}') || {}; }
    catch (e) { return {}; }
  }
  function anotar(k) {
    if (k === null || k === undefined) return;
    try {
      var u = uso();
      u[k] = (u[k] || 0) + 1;
      localStorage.setItem(LLAVE_USO, JSON.stringify(u));
    } catch (e) {}
  }

  /* Las cuatro de arriba. Al principio no hay historial, así que se
     arranca con cuatro sensatas y se dice que van a cambiar solas:
     una rejilla vacía no le sirve a nadie el primer día. */
  var PRIMERAS = ['atletas', 'cobros', 'buzon', 'liga'];
  function masUsadas() {
    var u = uso(), todas = plano();
    var con = todas.filter(function (e) { return e.clave !== '' && u[e.clave] > 0; })
      .sort(function (a, b) { return u[b.clave] - u[a.clave]; });
    var elegidas = con.slice(0, 4);
    var faltan = 4 - elegidas.length;
    if (faltan > 0) {
      PRIMERAS.forEach(function (k) {
        if (faltan <= 0) return;
        var e = todas.filter(function (x) { return x.clave === k; })[0];
        if (!e) return;
        if (elegidas.indexOf(e) !== -1) return;
        elegidas.push(e); faltan--;
      });
    }
    return { lista: elegidas, estrenando: con.length < 4 };
  }

  /* ============================================================
     Sinónimos: cada pantalla se busca por su nombre y por como la
     llama la gente. Nadie escribe «avisos-push»: escribe
     «notificaciones» o «avisar».
     ============================================================ */
  var SINONIMOS = {
    'avisos al móvil':        'notificaciones push avisar movil telefono alertas mandar enviar',
    'recibir avisos en mi móvil': 'activar avisos notificaciones push permiso mi movil mi telefono ' +
                                  'avisarme configuracion ajustes suscribirme alertas',
    'mi perfil':              'cuenta contrasena foto nombre datos configuracion ajustes',
    'ver la app como socio':  'portal app atleta socio ver como probar',
    'franja informativa':     'avisos de portada banner franja barra aviso web arriba',
    'noticias':               'blog articulos web publicar',
    'tienda':                 'ropa productos venta equipacion',
    'altas que entran':       'altas inscripciones apuntarse matricula formulario socios escuela ' +
                              'familias nuevas revisar pendientes solicitudes renovar domiciliacion sepa',
    'cobros y recibos':       'dinero pagos recibos domiciliacion remesas banco impagados devueltos',
    'tarifas':                'precios cuotas dinero',
    'pagos con tarjeta':      'stripe tarjeta online dinero',
    'pedidos de ropa':        'tienda equipacion camiseta ropa',
    'atletas':                'personas fichas socios ninos alumnos',
    'importar personas':      'altas csv excel importar',
    'grupos de entrenamiento':'grupos horarios entrenos secciones entrenador',
    'quién entra al panel':   'usuarios permisos cuentas acceso contrasenas roles administradores',
    'en la pista':            'asistencia pasar lista campo entrenamiento',
    'quién va a ir':          'confirmar asistencia carrera desplazamiento plazas autobus',
    'calendario y eventos':   'agenda fechas eventos',
    'competiciones':          'carreras pruebas inscripciones',
    'liga apolana':           'liga clasificacion puntos',
    'retos y medallas':       'juego rangos medallas logros',
    'el cubo':                'fuerza bonos clases',
    'batería de tests':       'pruebas fisicas tests marcas',
    'catálogo de pruebas':    'pruebas distancias catalogo',
    'estadísticas del club':  'datos analisis metricas graficas',
    'informes y datos':       'informes exportar datos pdf',
    'histórico de la escuela':'historico temporadas pasadas',
    'páginas':                'web contenido paginas',
    'textos de las páginas':  'contenido textos web copys',
    'fotos de la web':        'imagenes fotos web',
    'biblioteca de fotos':    'imagenes fotos galeria mediateca',
    'colaboradores':          'patrocinadores logos empresas',
    'documentos':             'papeles normativa autorizaciones pdf',
    'peticiones de redes':    'instagram propuestas socios redes',
    'mapa de contenido':      'mapa web estructura',
    'personas de contacto':   'contactos telefonos correos responsables junta directiva presidente ' +
                              'secretario tesorero movil publicar privacidad quien lleva seccion',
    'buzón':                  'mensajes correo dudas contacto solicitudes inscripcion',
    'se pone solo':           'automatizaciones automatico solo publica',
    'plantillas de email':    'correos plantillas respuestas',
    'récords':                'marcas historicas records',
    'palmarés':               'medallas podios historico'
  };
  function sinTildes(s) {
    return String(s || '').toLowerCase()
      .normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  }
  function palabras(titulo, grupo, desc) {
    return sinTildes(titulo + ' ' + (grupo || '') + ' ' + (desc || '') + ' ' +
                     (SINONIMOS[String(titulo).toLowerCase()] || ''));
  }

  /* ============================================================
     Las personas del club
     ------------------------------------------------------------
     Salen de la base con la sesión de quien está mirando, así que
     cada uno ve lo que le dejan ver las reglas de acceso: aquí no
     se monta ninguna lista aparte que se las salte.
     ============================================================ */
  var GENTE = null, PIDIENDO = false;
  function gente(cuando) {
    if (GENTE) { cuando(GENTE); return; }
    if (PIDIENDO) return;
    var sb = window.APOLANA_DB;
    if (!sb || !sb.from) { GENTE = []; cuando(GENTE); return; }
    PIDIENDO = true;
    sb.from('atletas').select('id,nombre,apellidos,categoria,estado').order('apellidos').limit(1200)
      .then(function (r) {
        PIDIENDO = false;
        GENTE = (r && !r.error && r.data ? r.data : []).map(function (a) {
          var n = ((a.nombre || '') + ' ' + (a.apellidos || '')).replace(/\s+/g, ' ').trim();
          return { id: a.id, nombre: n, cat: a.categoria || '', estado: a.estado || '', busca: sinTildes(n) };
        });
        cuando(GENTE);
      }, function () { PIDIENDO = false; GENTE = []; cuando(GENTE); });
  }

  /* ============================================================
     La hoja: buscador, «las que más usas» y «todo, por bloques»
     ============================================================ */
  var fondo = null, hoja = null, abierta = false, ultimoFoco = null, botonMenu = null;
  var campo = null, cajaRes = null, cajaAtajos = null, cajaTodo = null;

  function avisarBoton() {
    if (botonMenu) botonMenu.setAttribute('aria-expanded', abierta ? 'true' : 'false');
  }

  function itemHTML(txt, sub, url, aqui) {
    return '<a href="' + esc(url) + '"' + (aqui ? ' class="aqui"' : '') + ' data-clave="' + esc(clave(url)) + '">' +
           '<span class="txt"><span class="t">' + esc(txt) + '</span>' +
           '<span class="b">' + esc(sub) + '</span></span>' +
           '<i class="chev" aria-hidden="true">›</i></a>';
  }

  function pintarAtajos() {
    var m = masUsadas(), aqui = carpeta();
    var html = '<h3>Las que más usas</h3><div class="atajos">';
    m.lista.forEach(function (e) {
      html += '<a href="' + esc(e.url) + '" data-clave="' + esc(e.clave) + '"' +
              (!e.panel && e.clave === aqui ? ' class="aqui"' : '') + '>' + esc(e.txt) + '</a>';
    });
    html += '</div>';
    if (m.estrenando) {
      html += '<p class="nota">Todavía no sabemos cuáles usas tú: estas cuatro son el punto de partida. ' +
              'Según vayas abriendo pantallas, se cambian solas.</p>';
    }
    cajaAtajos.innerHTML = html;
  }

  function pintarTodo() {
    var aqui = carpeta();
    var html = '<h3>Todo, por bloques</h3>';
    mapa().forEach(function (b) {
      var reales = b.enlaces.filter(function (e) { return !e.panel; });
      if (!reales.length) return;
      if (!b.t) {
        html += '<div class="lista" style="margin-bottom:12px">';
        reales.forEach(function (e) {
          html += itemHTML(e.txt, e.desc, e.url, clave(e.url) === aqui);
        });
        html += '</div>';
        return;
      }
      var dentro = reales.some(function (e) { return clave(e.url) === aqui; });
      html += '<details class="bloque"' + (dentro ? ' open' : '') + '>' +
              '<summary><span class="nom">' + esc(b.t) + '</span>' +
              '<span class="n">' + reales.length + '</span><i class="fl" aria-hidden="true"></i></summary>' +
              '<div class="lista">';
      reales.forEach(function (e) {
        html += itemHTML(e.txt, e.desc, e.url, clave(e.url) === aqui);
      });
      html += '</div></details>';
    });
    cajaTodo.innerHTML = html;
  }

  /* Filtra mientras se escribe: pantallas y personas a la vez. */
  var TOPE_PANTALLAS = 8, TOPE_PERSONAS = 6;
  function filtrar(texto) {
    var q = sinTildes(texto).trim();
    var trozos = q ? q.split(/\s+/) : [];
    if (!trozos.length) {
      cajaRes.hidden = true;
      cajaRes.innerHTML = '';
      cajaAtajos.hidden = false;
      cajaTodo.hidden = false;
      return;
    }
    cajaAtajos.hidden = false;
    cajaTodo.hidden = false;
    cajaRes.hidden = false;

    var pantallas = plano().filter(function (e) {
      return trozos.every(function (t) { return e.busca.indexOf(t) !== -1; });
    });

    function pinta(personas) {
      var html = '<h3>Resultados</h3>';
      var total = pantallas.length + personas.length;
      if (!total) {
        html += '<p class="nota" style="margin-top:0">No hay ninguna pantalla ni ninguna persona con eso. ' +
                'Prueba con una palabra suelta: cobros, grupos, fotos, avisos…</p>';
        cajaRes.innerHTML = html;
        aLaVista();
        return;
      }
      html += '<div class="lista">';
      pantallas.slice(0, TOPE_PANTALLAS).forEach(function (e) {
        html += itemHTML(e.txt, e.bloque + ' · ' + e.desc, e.url, false);
      });
      personas.slice(0, TOPE_PERSONAS).forEach(function (p) {
        var sub = 'Personas · ' + (p.cat ? 'ficha de ' + p.cat : 'ficha del atleta');
        html += itemHTML(p.nombre, sub, raiz() + 'atletas/?ficha=' + encodeURIComponent(p.id), false);
      });
      html += '</div>';
      var mas = (pantallas.length - Math.min(pantallas.length, TOPE_PANTALLAS)) +
                (personas.length - Math.min(personas.length, TOPE_PERSONAS));
      if (mas > 0) html += '<p class="nota">Y ' + mas + ' más. Escribe un poco más para afinar.</p>';
      cajaRes.innerHTML = html;
      aLaVista();
    }

    /* Las personas tardan lo que tarde la base: las pantallas salen ya. */
    pinta(coincidenPersonas(GENTE || [], trozos));
    gente(function (lista) {
      if (campo && sinTildes(campo.value).trim() !== q) return;   /* ya se escribió otra cosa */
      pinta(coincidenPersonas(lista, trozos));
    });
  }

  function coincidenPersonas(lista, trozos) {
    if (!lista || !lista.length) return [];
    return lista.filter(function (p) {
      return trozos.every(function (t) { return p.busca.indexOf(t) !== -1; });
    });
  }

  /* ============================================================
     El teclado no puede tapar los resultados
     ------------------------------------------------------------
     «Al buscar y escribir avisos, los resultados quedan abajo y
     son tapados por el teclado.» En el móvil el teclado se come
     el 40-45 % del alto, y en iOS `vh` NO baja cuando sale: una
     hoja de 82vh anclada abajo queda medio tapada.

     Así que el alto no se le pregunta a `vh`: se le pregunta a
     `visualViewport`, que es lo único que sabe qué se ve de
     verdad. La hoja se sube por encima del teclado y los
     resultados se quedan pegados al buscador, con su propio
     desplazamiento si no caben.
     ============================================================ */
  function ajustar() {
    if (!hoja || hoja.hidden) return;
    var vv = window.visualViewport;
    var ancha = window.innerWidth > CORTE;
    if (!vv) { hoja.style.bottom = ''; hoja.style.top = ''; hoja.style.maxHeight = ''; return; }

    /* lo que queda tapado por debajo: el teclado, casi siempre */
    var tapado = Math.max(0, Math.round(window.innerHeight - vv.height - vv.offsetTop));
    var visible = Math.round(vv.height);

    if (ancha) {
      /* ventana centrada arriba: basta con no pasarse de alto */
      hoja.style.bottom = '';
      hoja.style.top = Math.round(vv.offsetTop + Math.min(visible * 0.07, 56)) + 'px';
      hoja.style.maxHeight = Math.max(260, visible - 96) + 'px';
    } else {
      /* hoja de abajo: se apoya en el borde de arriba del teclado */
      hoja.style.top = '';
      hoja.style.bottom = tapado + 'px';
      hoja.style.maxHeight = Math.max(240, visible - 12) + 'px';
    }
  }

  /* Al escribir, el primer resultado tiene que verse sin arrastrar. */
  function aLaVista() {
    if (!hoja || hoja.hidden) return;
    ajustar();
    var cuerpo = hoja.querySelector('.cuerpo');
    if (cuerpo) cuerpo.scrollTop = 0;
    var primero = cajaRes && !cajaRes.hidden ? cajaRes.querySelector('.lista a') : null;
    if (primero && primero.scrollIntoView) {
      try { primero.scrollIntoView({ block: 'nearest' }); } catch (e) {}
    }
  }

  var mirandoTeclado = false;
  function mirarTeclado(si) {
    var vv = window.visualViewport;
    if (!vv || mirandoTeclado === si) return;
    mirandoTeclado = si;
    if (si) { vv.addEventListener('resize', ajustar); vv.addEventListener('scroll', ajustar); }
    else    { vv.removeEventListener('resize', ajustar); vv.removeEventListener('scroll', ajustar); }
  }

  function crearHoja() {
    if (hoja) return;

    fondo = document.createElement('div');
    fondo.className = 'at-fondo';
    fondo.hidden = true;

    hoja = document.createElement('div');
    hoja.className = 'at-hoja';
    hoja.setAttribute('role', 'dialog');
    hoja.setAttribute('aria-modal', 'true');
    hoja.setAttribute('aria-label', 'Menú y buscador del panel');
    hoja.hidden = true;
    hoja.innerHTML =
      '<div class="cab"><h2>Menú</h2><button type="button" class="cerrar">Cerrar</button></div>' +
      '<div class="buscar">' + IC.lupa +
        '<input type="search" id="at-buscar" autocomplete="off" ' +
        'placeholder="Buscar una pantalla o una persona" ' +
        'aria-label="Buscar una pantalla del panel o una persona del club"></div>' +
      '<div class="cuerpo">' +
        '<div class="seccion" id="at-res" hidden></div>' +
        '<div class="seccion" id="at-atajos"></div>' +
        '<div class="seccion" id="at-todo"></div>' +
      '</div>';

    document.body.appendChild(fondo);
    document.body.appendChild(hoja);

    campo      = hoja.querySelector('#at-buscar');
    cajaRes    = hoja.querySelector('#at-res');
    cajaAtajos = hoja.querySelector('#at-atajos');
    cajaTodo   = hoja.querySelector('#at-todo');

    pintarAtajos();
    pintarTodo();

    fondo.addEventListener('click', cerrar);
    hoja.querySelector('.cerrar').addEventListener('click', cerrar);
    campo.addEventListener('input', function () { filtrar(campo.value); });
    /* al enfocar sube el teclado: se vuelve a medir lo que se ve de verdad */
    campo.addEventListener('focus', function () {
      ajustar(); setTimeout(ajustar, 150); setTimeout(ajustar, 450);
    });
    campo.addEventListener('blur', function () { setTimeout(ajustar, 150); });
    window.addEventListener('resize', ajustar);
    window.addEventListener('orientationchange', function () { setTimeout(ajustar, 260); });
    /* Enter con un solo resultado a la vista: se entra directamente. */
    campo.addEventListener('keydown', function (e) {
      if (e.key !== 'Enter') return;
      var vivos = cajaRes.hidden ? [] : cajaRes.querySelectorAll('.lista a');
      if (vivos.length === 1) { e.preventDefault(); vivos[0].click(); }
    });
    /* Lo que se abre desde aquí también cuenta para «las que más usas». */
    hoja.addEventListener('click', function (e) {
      var a = e.target.closest ? e.target.closest('a[data-clave]') : null;
      if (!a) return;
      anotar(a.getAttribute('data-clave'));
      /* ⚠️ Y SE CIERRA EL MENÚ. Las entradas que llevan a otra pantalla lo
         cerraban solas —al cargar la página nueva, el menú desaparecía con
         ella—, pero las que solo cambian el «#» de la dirección no recargan
         nada: la sección se abría DEBAJO y el menú se quedaba encima,
         tapándola. Desde fuera parecía que pulsar no hacía nada. Pasó de
         verdad con «Franja informativa». */
      cerrar();
    });
  }

  function abrir(conFoco) {
    crearHoja();
    if (!abierta) {
      abierta = true;
      ultimoFoco = document.activeElement;
      pintarAtajos();
      fondo.hidden = false;
      hoja.hidden = false;
      document.body.classList.add('at-hoja-abierta');
      avisarBoton();
      /* un cuadro de espera para que la transición se vea */
      ajustar();
      mirarTeclado(true);
      /* un cuadro de espera para que la transición se vea. Con la pestaña
         en segundo plano no hay cuadros, así que el reloj hace de red: la
         hoja nunca se queda a medio abrir. */
      var ensenar = function () {
        if (!abierta) return;
        fondo.classList.add('ver');
        hoja.classList.add('ver');
      };
      requestAnimationFrame(ensenar);
      setTimeout(ensenar, 40);
    }
    var primero = conFoco ? campo : hoja.querySelector('.cerrar');
    if (primero) { try { primero.focus({ preventScroll: true }); } catch (e) { primero.focus(); } }
    /* iOS tarda un momento en levantar el teclado: se vuelve a medir después */
    setTimeout(ajustar, 120);
    setTimeout(ajustar, 420);
  }

  function cerrar() {
    if (!abierta) return;
    abierta = false;
    fondo.classList.remove('ver');
    hoja.classList.remove('ver');
    document.body.classList.remove('at-hoja-abierta');
    avisarBoton();
    mirarTeclado(false);
    if (campo) campo.blur();
    setTimeout(function () {
      if (abierta) return;
      fondo.hidden = true;
      hoja.hidden = true;
      hoja.style.top = ''; hoja.style.bottom = ''; hoja.style.maxHeight = '';
    }, 240);
    if (ultimoFoco && ultimoFoco.focus) { try { ultimoFoco.focus(); } catch (e) {} }
  }

  document.addEventListener('keydown', function (e) {
    if (abierta && (e.key === 'Escape' || e.key === 'Esc')) { e.preventDefault(); cerrar(); }
  });

  /* ---------- el buscador de la cabecera navy ---------- */
  function buscadorArriba() {
    var top = document.querySelector('.adm-top') || document.querySelector('.admin-top');
    if (!top || top.querySelector('.at-busca-cab')) return;
    var b = document.createElement('button');
    b.type = 'button';
    b.className = 'at-busca-cab';
    b.setAttribute('aria-haspopup', 'dialog');
    b.innerHTML = IC.lupa + '<span>Buscar una pantalla o una persona</span>';
    b.addEventListener('click', function () { abrir(true); });
    top.appendChild(b);
  }

  /* ---------- pintado ---------- */
  var nodo = null, ya = false;
  function pintar() {
    if (ya) return;
    ya = true;

    buscadorArriba();
    anotar(carpeta());   /* esta pantalla, para «las que más usas» */

    /* Si la página se pinta de verdad su propia barra, no ponemos otra.
       Un `<nav class="tabbar" hidden></nav>` vacío no cuenta: eso deja la
       página sin ninguna navegación. */
    var propia = document.querySelector('.tabbar');
    if (propia && !propia.hidden && propia.children.length) return;

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
      if (abierta) cerrar(); else abrir(false);
    });
  }

  /* Dentro del inicio del panel los paneles se cambian con el hash:
     si alguien llega con «#avisos», eso también es una pantalla usada. */
  if (carpeta() === '' && location.hash) anotar(location.hash);

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
    P + 'table tbody td{padding-top:6px;padding-bottom:6px;vertical-align:middle}',
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
    var caja = document.getElementById('admin-contenido') || document.body;
    /* Las pantallas con la cabecera nueva ya dicen la cifra en su línea de
       contexto («14 tarifas»). Colgarla otra vez del título sería decir el
       mismo número dos veces, que es justo lo que pide arreglar el club.
       Se mira en cada pasada porque esa cabecera se pinta con los datos, o
       sea después de que esto haya elegido un título. */
    if (caja.querySelector('.pz-cab-tit')) {
      if (TITULO && TITULO.__cuenta) { TITULO.__cuenta.remove(); TITULO.__cuenta = null; }
      return;
    }
    if (!YA_TITULO) {
      YA_TITULO = true;
      var raiz = caja;
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
    /* Las tablas de las piezas nuevas (`pz-tabla`) ya traen su propia ficha de
       móvil, sus rótulos y su recuento. Si esta parte también las tocara,
       pondría el nombre de la columna delante del dato principal y cortaría la
       lista a veinte filas por su cuenta. Se dejan en paz. */
    if (tabla.classList.contains('pz-tabla')) { tabla.__visto = true; return; }
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
