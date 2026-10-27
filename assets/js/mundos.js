/* ============================================================
   BARRA LATERAL DE «MUNDOS» · Club Atletismo Apolana
   ------------------------------------------------------------
   El panel es un mundo superior (Administración) y dentro hay
   mundos por sección (Natación, El Cubo, Atletismo…). Esta pieza
   pinta, SOLO en PC (>=900px), la barra lateral que es el «vaso
   comunicante», en DOS COLUMNAS (como SportMember): una tira estrecha con
   los mundos (cambias de un clic; abajo Buscar · Web · Salir) y a su lado
   el panel del mundo en el que estás, con sus pantallas en apartados
   plegables (`g` en cada pantalla). El panel entero se puede plegar. En móvil no aparece: manda
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
    mail:'<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3.5 7l8.5 6 8.5-6"/>',
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
    bottle:'<path d="M10 2.5h4M10.5 2.5v3.2c0 .9-2.5 2-2.5 4.3V20a1.5 1.5 0 0 0 1.5 1.5h5A1.5 1.5 0 0 0 16 20V10c0-2.3-2.5-3.4-2.5-4.3V2.5"/><path d="M8 12.5h8"/>',
    run:'<circle cx="14.5" cy="5" r="2"/><path d="M7 21l3-5 3 2 1 3M13 18l-3-2 1.5-5-3.5 2v3M13 11l3-1 3 2"/>',
    sparkle:'<path d="M11.5 4l1.6 4.3L17.5 10l-4.4 1.7-1.6 4.3-1.6-4.3L5.5 10l4.4-1.7z"/>',
    inbox:'<rect x="4" y="5" width="16" height="14" rx="2"/><path d="M4 8l8 5 8-5"/>',
    /* iconos de los MUNDOS (tira de la izquierda) y de la lateral nueva */
    club:'<path d="M4 20h16M6 20V9.5l6-4.5 6 4.5V20"/><path d="M10 20v-5h4v5"/>',
    swim:'<circle cx="16.5" cy="6.5" r="2"/><path d="M4.5 12.5l4.5-3 3 2.5 3.5-2"/><path d="M3 17c1.5 0 1.5-1.2 3-1.2s1.5 1.2 3 1.2 1.5-1.2 3-1.2 1.5 1.2 3 1.2 1.5-1.2 3-1.2 1.5 1.2 3 1.2"/>',
    float:'<circle cx="12" cy="9.5" r="5"/><circle cx="12" cy="9.5" r="2"/><path d="M3 18.5c1.5 0 1.5-1.2 3-1.2s1.5 1.2 3 1.2 1.5-1.2 3-1.2 1.5 1.2 3 1.2 1.5-1.2 3-1.2 1.5 1.2 3 1.2"/>',
    dumbbell:'<path d="M6.5 7v10M17.5 7v10M3.5 9.5v5M20.5 9.5v5M6.5 12h11"/>',
    stopwatch:'<circle cx="12" cy="13.5" r="7"/><path d="M12 13.5V9.8M10 3.5h4M12 3.5v3M18.2 7.3l1.3-1.3"/>',
    sprout:'<path d="M12 20v-8"/><path d="M12 12c0-3.5-2.5-6-6.5-6 0 3.8 2.6 6 6.5 6z"/><path d="M12 14c0-3.2 2.3-5.5 6-5.5 0 3.5-2.4 5.5-6 5.5z"/>',
    megaphone:'<path d="M4 10v4h3l7 4V6l-7 4H4z"/><path d="M17.5 9a4 4 0 0 1 0 6"/>',
    shirt:'<path d="M8 4l-4 3 2 3 2-1v11h8V9l2 1 2-3-4-3c-.5 1.5-2 2.5-4 2.5S8.5 5.5 8 4z"/>',
    bank:'<path d="M3.5 9.5L12 4.5l8.5 5"/><path d="M5 10v7M9.7 10v7M14.3 10v7M19 10v7M3.5 20h17"/>',
    repeat:'<path d="M4 11a7 7 0 0 1 12.2-4.7l2.3 2.2M19.5 4.5v4h-4"/><path d="M20 13a7 7 0 0 1-12.2 4.7l-2.3-2.2M4.5 19.5v-4h4"/>',
    upload:'<path d="M12 15V4.5M7.5 9L12 4.5 16.5 9M5 15v3.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V15"/>',
    key:'<circle cx="8" cy="15" r="3.5"/><path d="M10.5 12.5L19 4M16 7l2.5 2.5M14 9l2 2"/>',
    search:'<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>',
    logout:'<path d="M14 4.5h3.5A1.5 1.5 0 0 1 19 6v12a1.5 1.5 0 0 1-1.5 1.5H14"/><path d="M10 8l-4 4 4 4M6 12h9"/>',
    chevl:'<path d="M14.5 6l-6 6 6 6"/>',
    chevr:'<path d="M9.5 6l6 6-6 6"/>'
  };
  function ico(n){ return '<svg viewBox="0 0 24 24" '+P+'>'+(ICO[n]||ICO.grid)+'</svg>'; }
  function esc(s){ return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }

  /* ---------- Los MUNDOS (mapa aprobado) ---------- */
  /* Cada mundo: `i` = icono de la tira, `corto` = nombre en la tira (2 líneas
     máx.; ­ = guion suave si no cabe). Cada pantalla puede llevar:
       g        → el apartado plegable de la lateral en el que va
                  (sin `g`: suelta; Resumen y Calendario siempre arriba)
       hub:false → solo en la lateral/buscador, NO como tarjeta del Resumen
       side:false → solo tarjeta del Resumen, NO en la lateral */
  var MUNDOS = [
    { key:'general', nombre:'General · Club', corto:'General', i:'club', dot:'#2E4256', home:B+'portal/general/',
      frase:'El club por dentro: personas, socios, dinero, la web y los avisos que se envían.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/general/'},
        {key:'calendario', t:'Calendario del club', i:'calendar', url:B+'portal/calendario-club/', d:'Todas las sesiones por día, con apuntados; cancelar festivos y cierres.'},
        {g:'Personas', t:'Personas',        i:'people',    url:B+'admin/atletas/',     d:'Todas las fichas del club, en un sitio.'},
        {g:'Personas', t:'Socios',          i:'user',      url:B+'admin/socios/',      d:'Altas, cuotas y estado de cada socio.'},
        {g:'Personas', t:'Altas de socio',  i:'userplus',  url:B+'admin/altas/?tipo=socio', d:'Las solicitudes de socio por revisar.', hub:false},
        {g:'Personas', t:'Entrenadores',    i:'user',      url:B+'admin/entrenadores/', d:'Los monitores: su ficha y a qué grupo llevan.', hub:false},
        {g:'Personas', t:'Importar personas', i:'upload',  url:B+'admin/importar/',    d:'Altas en bloque desde un archivo.', hub:false},
        {g:'Personas', t:'Revisión de datos', i:'check',  url:B+'admin/revision-datos/', d:'Fichas con datos raros para limpiar antes de cobrar.', hub:false},
        // La tarjeta «Dinero» del Resumen; en la lateral manda el apartado Dinero (pestañas ?v=).
        {t:'Dinero',          i:'euro',      url:B+'admin/dinero/',      d:'Todo el dinero en un sitio: te deben, ha entrado, en camino y «¿ha pagado…?».', pill:'Empieza aquí', side:false},
        {g:'Dinero', t:'Resumen',         i:'chart',  url:B+'admin/dinero/?v=resumen',  d:'Dinero: te deben, ha entrado y en camino.', hub:false},
        {g:'Dinero', t:'Cuotas',          i:'repeat', url:B+'admin/dinero/?v=cuotas',   d:'Dinero: las cuotas que se repiten.', hub:false},
        {g:'Dinero', t:'Cobros únicos',   i:'ticket', url:B+'admin/dinero/?v=unicos',   d:'Dinero: cobros de una sola vez.', hub:false},
        {g:'Dinero', t:'Todos los pagos', i:'euro',   url:B+'admin/dinero/?v=pagos',    d:'Dinero: cada pago, con su estado.', hub:false},
        {g:'Dinero', t:'Próximos',        i:'clock',  url:B+'admin/dinero/?v=proximos', d:'Dinero: lo que se va a cobrar.', hub:false},
        {g:'Dinero', t:'Al banco',        i:'bank',   url:B+'admin/dinero/?v=banco',    d:'Dinero: lo que llega al banco.', hub:false},
        {g:'Dinero', t:'Tarifas',         i:'clipboard', url:B+'admin/tarifas/',     d:'Los precios de cada cuota.'},
        // ?tipo=dinero: desde General se queda en General (sin él, Cuotas de entreno es de Pista).
        {g:'Dinero', t:'Cuotas domiciliadas', i:'euro',    url:B+'admin/cuotas-entreno/?tipo=dinero', d:'Cuotas por domiciliación SEPA (entreno trimestral y casos mensuales, como natación). Antes: Velocidad/Academia.'},
        {g:'Dinero', t:'Cobros y recibos', i:'euro',     url:B+'admin/cobros/',      d:'Recibos, remesas, devueltos e impagados.'},
        {g:'Dinero', t:'Pagos con tarjeta', i:'ticket',  url:B+'admin/pagos-online/', d:'Todo lo que se cobra por internet (tienda, recibos, bonos).'},
        {g:'Informes', key:'pagos', t:'Resumen de pagos', i:'chart', url:B+'portal/pagos-resumen/', d:'Cuánto entra: Cubo, cobros online, recibos y socios.'},
        {g:'Informes', key:'payouts', t:'Payouts de Stripe', i:'bank', url:B+'portal/payouts/', d:'Las transferencias de Stripe al banco y su desglose (para Isa).'},
        {g:'Informes', t:'Estadísticas del club', i:'chart', url:B+'admin/estadisticas/', d:'Los números del club.', hub:false},
        {g:'Informes', t:'Informes y datos', i:'clipboard', url:B+'admin/informes/',   d:'Informes para exportar.', hub:false},
        {g:'Comunicación', t:'Avisos al móvil', i:'bell',      url:B+'admin/avisos-push/', d:'Las notificaciones que se envían a la gente.', pill:'Notificar'},
        {g:'Comunicación', t:'Correo a un grupo', i:'mail',     url:B+'admin/correo-grupo/', d:'Un correo con el diseño del club a un grupo, desde info@.'},
        {g:'Comunicación', t:'Buzón',           i:'inbox',     url:B+'admin/buzon/',       d:'Los mensajes que llegan de contacto.'},
        {g:'Comunicación', t:'Enlaces para compartir', i:'link', url:B+'admin/enlaces/',   d:'Los enlaces de los formularios, para copiar y mandar.'},
        {g:'Web y tienda', t:'La web',          i:'globe',     url:B+'admin/paginas/',     d:'Páginas, textos y fotos de la web.'},
        {g:'Web y tienda', t:'Pedidos de la tienda', i:'box', url:B+'admin/pedidos/', d:'Los encargos de ropa: su estado y si ya se pagaron en la oficina.'},
        {g:'Web y tienda', t:'Nevera',          i:'bottle',    url:B+'admin/nevera/',      d:'Las bebidas pagadas con el QR: ventas, precios y el QR para imprimir.'},
        {g:'Accesos y datos', t:'Acceso a los mundos', i:'shuffle', url:B+'admin/mundos/',    d:'Quién entra a cada mundo (Natación, Cubo…).'},
        {g:'Accesos y datos', t:'Quién entra al panel', i:'key', url:B+'admin/usuarios/',  d:'Cuentas, roles y permisos.', hub:false},
        {g:'Accesos y datos', t:'Datos del club',  i:'clipboard', url:B+'admin/documentos/',  d:'Documentos y datos legales.'}
      ] },
    { key:'natacion', nombre:'Natación', corto:'Natación', i:'swim', dot:'#2F6FA8', home:B+'portal/natacion/',
      frase:'Adultos y máster. Franjas, calles, cupos y quién falta.',
      screens:[
        {key:'resumen',    t:'Resumen',          i:'grid',     url:B+'portal/natacion/'},
        {key:'alta',       t:'Dar de alta',      i:'userplus', url:B+'portal/natacion-alta/?tipo=M%C3%A1ster', d:'Un nadador nuevo, paso a paso: datos, días, calle y cuota. Le llega el acceso por correo.', pill:'Empieza aquí'},
        {key:'nadadores',  g:'Nadadores', t:'Nadadores',        i:'people',   url:B+'portal/natacion/?p=nadadores'},
        {key:'franjas',    g:'Horarios y asistencia', t:'Franjas y cupos',  i:'calendar', url:B+'portal/natacion-gestion/'},
        {key:'asistencia', g:'Horarios y asistencia', t:'Asistencia',       i:'check',    url:B+'portal/natacion-asistencia/'},
        {key:'reservas',   g:'Nadadores', t:'Reservas y abono', i:'ticket',   url:B+'portal/natacion-reservas/'},
        {key:'cuotas',     g:'Nadadores', t:'Cuotas y cobros',  i:'euro',     url:B+'portal/natacion-cuotas/', d:'La cuota de cada nadador y su enlace para domiciliarla (sin correos automáticos).'},
        {key:'avisos',     t:'Avisos',           i:'megaphone', url:B+'portal/natacion-avisos/', d:'Un aviso a una franja, a la escuela, al máster o a todos: llega en la app y por correo.'},
        {key:'equipacion', t:'Equipación',       i:'shirt',    url:B+'portal/natacion-equipacion/', d:'El pedido de ropa de natación de cada familia: tallas, nuevos, ha llegado, pagado y entregado.'},
        {key:'calendario', t:'Calendario',       i:'calendar', url:B+'portal/calendario-club/?world=natacion'},
        {key:'plazas',     t:'Ver en la web',    i:'signal',   url:B+'natacion/', ext:true}
      ] },
    { key:'escuela-nat', nombre:'Escuela de natación', corto:'Escuela natación', i:'float', dot:'#2E8C86', home:B+'portal/escuela-natacion/',
      frase:'Los peques del agua: franjas, cupos, asistencia y familias.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/escuela-natacion/'},
        {key:'alta', t:'Dar de alta', i:'userplus', url:B+'portal/natacion-alta/?tipo=Escuela', d:'Un niño o niña nuevo, paso a paso: datos, días, calle y cuota. A la familia le llega el acceso.', pill:'Empieza aquí'},
        {key:'calendario', t:'Calendario', i:'calendar', url:B+'portal/calendario-club/?world=escuela-nat'},
        {key:'ninos', t:'Niños y niñas', i:'people', url:B+'portal/escuela-natacion/?p=ninos', d:'La lista de la escuela de natación.'},
        {key:'cuotas', t:'Cuotas y cobros', i:'euro', url:B+'portal/natacion-cuotas/?tipo=Escuela', d:'La cuota de cada niño y el enlace para que la familia la domicilie.'},
        {key:'avisos', t:'Avisos a las familias', i:'megaphone', url:B+'portal/natacion-avisos/?tipo=Escuela', d:'Un aviso a una franja o a toda la escuela: llega en la app y por correo a cada familia.'},
        {key:'equipacion', t:'Equipación', i:'shirt', url:B+'portal/natacion-equipacion/', d:'El pedido de ropa de natación de cada familia: tallas, nuevos, ha llegado, pagado y entregado.'},
        {key:'competiciones', t:'Competiciones', i:'trophy', url:B+'portal/natacion-competiciones/', d:'Jornadas y controles: quién entra en cada categoría, convocatoria, respuesta de las familias y datos de licencia.'},
        {g:'Horarios y asistencia', t:'Franjas y cupos',  i:'calendar', url:B+'portal/natacion-gestion/?tipo=Escuela',    d:'Horarios y calles con su cupo.'},
        {g:'Horarios y asistencia', t:'Asistencia',       i:'check',    url:B+'portal/natacion-asistencia/?tipo=Escuela', d:'Quién viene a cada sesión.'},
        {t:'Ver en la web',    i:'signal',   url:B+'escuela-natacion/',                        d:'El semáforo de plazas que ven las familias.', ext:true}
      ] },
    { key:'cubo', nombre:'El Cubo', corto:'El Cubo', i:'dumbbell', dot:'#B5714A', home:B+'portal/cubo/',
      frase:'Socios que entrenan: grupos fijos, cuotas y asistencia.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/cubo/'},
        {key:'calendario', t:'Calendario', i:'calendar', url:B+'portal/calendario-club/?world=cubo', d:'Las sesiones del Cubo por día; cancelar festivos.'},
        {g:'Socios del Cubo', t:'Integrantes',     i:'people',   url:B+'admin/atletas/?seccion=cubo', d:'Quién entrena en el Cubo.'},
        {g:'Socios del Cubo', t:'Grupos y turnos', i:'calendar', url:B+'admin/grupos/?seccion=cubo',  d:'Grupos fijos y sus días.'},
        {g:'Socios del Cubo', t:'Cuotas y pagos',  i:'ticket',   url:B+'admin/cubo-altas/',           d:'Cuotas mensuales, cobros y altas.'},
        {g:'Entrenos', t:'Asistencia',      i:'check',    url:B+'admin/asistencia/',           d:'Quién vino a entrenar cada día.'},
        {g:'Entrenos', t:'Fuerza gratis',   i:'sparkle',  url:B+'admin/cubo-prueba/',          d:'Los turnos gratis de prueba.'},
        {g:'Entrenos', t:'Clases y bonos',  i:'box',      url:B+'admin/cubo/',                 d:'Clases, bonos y ocupación.'}
      ] },
    { key:'pista', nombre:'Atletismo pista', corto:'Atletismo pista', i:'stopwatch', dot:'#4A5FA6', home:B+'portal/pista/',
      frase:'La pista, con la Academia AC98 dentro: atletas, grupos, tests y competición.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/pista/'},
        {key:'calendario', t:'Calendario', i:'calendar', url:B+'portal/calendario-club/?world=pista'},
        {g:'Atletas y grupos', t:'Atletas',          i:'people',    url:B+'admin/atletas/?seccion=competicion', d:'Los atletas de pista.'},
        {g:'Atletas y grupos', t:'Pruebas de pista', i:'sparkle',   url:B+'admin/pista-pruebas/', d:'Quién pide venir a probar y su seguimiento.'},
        {g:'Atletas y grupos', t:'Grupos',           i:'people',    url:B+'admin/grupos/?seccion=competicion',  d:'Grupos de entreno, incl. Academia AC98.'},
        {g:'Atletas y grupos', t:'Cuotas domiciliadas', i:'euro',     url:B+'admin/cuotas-entreno/', d:'Cuotas por domiciliación SEPA: trimestral de Velocidad/Academia y mensuales (natación).'},
        {g:'Competición y tests', t:'Tests y pruebas',  i:'clipboard', url:B+'admin/tests/',        d:'Batería de tests y marcas.'},
        {g:'Competición y tests', t:'Competiciones',    i:'flag',      url:B+'admin/competiciones/', d:'Carreras e inscripciones.'},
        {g:'Competición y tests', t:'Quién va a ir',    i:'check',     url:B+'admin/confirmaciones/', d:'Confirmaciones para cada carrera.'},
        {g:'Competición y tests', t:'Liga y récords',   i:'trophy',    url:B+'admin/liga/',         d:'Liga Apolana y récords del club.'}
      ] },
    { key:'escuela-atl', nombre:'Escuela de atletismo', corto:'Escuela atletismo', i:'sprout', dot:'#3F7A4C', home:B+'portal/escuela-atletismo/',
      frase:'Los peques de la pista: grupos, altas de familias y reparto.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/escuela-atletismo/'},
        {key:'calendario', t:'Calendario', i:'calendar', url:B+'portal/calendario-club/?world=escuela-atl'},
        {g:'Niños y grupos', t:'Grupos y listas',   i:'clipboard', url:B+'admin/escuela-grupos/',         d:'Martes y jueves: mover niños de grupo, bajas y entrenadores.'},
        {g:'Niños y grupos', t:'Niños y niñas',     i:'people',   url:B+'admin/atletas/?seccion=escuela', d:'Los peques inscritos.'},
        {g:'Niños y grupos', t:'Editar grupos',     i:'people',   url:B+'admin/grupos/?seccion=escuela',  d:'Nombre, horario, años y plazas de cada grupo.'},
        {g:'Altas y pruebas', t:'Altas de familias', i:'userplus', url:B+'admin/altas/?tipo=escuela',      d:'Solicitudes nuevas de las familias.'},
        {g:'Altas y pruebas', t:'Pruebas de pista',  i:'sparkle',  url:B+'admin/pista-pruebas/',           d:'Peques (y adultos) que piden venir a probar.'},
        {g:'Niños y grupos', t:'Repartir',          i:'shuffle',  url:B+'admin/repartir/',                d:'Colocar a cada peque en su grupo.'},
        {g:'Niños y grupos', t:'Histórico',         i:'clock',    url:B+'admin/historico/',               d:'Temporadas anteriores.'}
      ] },
    { key:'running', nombre:'Running', corto:'Running', i:'run', dot:'#C6892F', home:B+'portal/running/',
      frase:'De momento, solo agrupa a las personas de running.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/running/'},
        {key:'calendario', t:'Calendario', i:'calendar', url:B+'portal/calendario-club/?world=running'},
        {t:'Corredores', i:'run', url:B+'admin/atletas/?seccion=running', d:'Las personas del grupo de running.'}
      ] },
    { key:'comunicacion', nombre:'Comunicación', corto:'Comuni­cación', i:'megaphone', dot:'#6E5AA6', home:B+'portal/comunicacion/',
      frase:'Lo que el club cuenta hacia fuera: noticias, avisos, calendario y redes.',
      screens:[
        {key:'resumen', t:'Resumen', i:'grid', url:B+'portal/comunicacion/'},
        {g:'Publicar', t:'Noticias',        i:'newspaper', url:B+'admin/#noticias',    d:'Publicar y editar noticias de la web.'},
        {g:'Publicar', t:'Avisos al móvil', i:'bell',      url:B+'admin/avisos-push/', d:'Notificaciones a la gente del club.'},
        {key:'calendario', t:'Calendario',      i:'calendar',  url:B+'admin/eventos/',     d:'Eventos y fechas del club.'},
        {g:'Publicar', t:'Competiciones',   i:'flag',       url:B+'admin/competiciones/', d:'Crear y corregir las competiciones que salen en el calendario.'},
        {g:'Publicar', t:'Liga',            i:'chart',      url:B+'admin/liga/',        d:'Comunicar la Liga Apolana.'},
        {g:'Publicar', t:'Se pone solo',    i:'sparkle',    url:B+'admin/automatizaciones/', d:'Lo que se publica sin tocar nada.', hub:false},
        {g:'Contacto y redes', t:'Peticiones de redes',    i:'at',   url:B+'admin/redes/',     d:'Lo que proponen los socios.'},
        {g:'Contacto y redes', t:'Plantillas de email', i:'inbox', url:B+'admin/plantillas/', d:'Respuestas ya escritas.', hub:false},
        {g:'Contacto y redes', t:'Personas de contacto', i:'user', url:B+'admin/contactos/',  d:'Quién lleva cada sección y su teléfono.', hub:false}
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
      /* --- LATERAL DE ESCRITORIO EN DOS COLUMNAS (>=900px) ---------------
         Como SportMember: a la izquierda una TIRA estrecha con los mundos
         (icono + nombre corto) y abajo Buscar · Web · Salir; a su lado el
         PANEL del mundo activo, con sus pantallas en apartados plegables.
         El panel entero se puede plegar (se recuerda). Móvil: no cambia. */
      '@media (min-width:900px){' +
        '.mm-layout{display:grid;grid-template-columns:auto minmax(0,1fr);gap:24px;' +
          'max-width:1520px;margin:0;padding:20px clamp(18px,3vw,34px) 48px;align-items:start}' +
        '.mm-layout>.mm-main{min-width:0}' +
        '.mm-layout>.mm-main>*{max-width:none !important;margin-left:0 !important;margin-right:0 !important;padding-left:0 !important;padding-right:0 !important}' +
        'body.mm-on .pt-tabbar{display:none !important}' +
        'body.mm-on .at-side{display:none !important}' +
        'body.mm-on.pt-con-tabbar{padding-bottom:24px !important}' +
        '.mm-side{display:block;position:sticky;top:16px;align-self:start;width:316px;view-transition-name:mm-lateral}' +
        '.mm-side.mm-plegado{width:76px}' +
        '.mm-dos{display:flex;align-items:flex-start;gap:10px;--mm-azul:#2F6FA8;--mm-azul-suave:#EAF2FA}' +
        /* tira de mundos */
        '.mm-tira{flex:0 0 76px;width:76px;box-sizing:border-box;display:flex;flex-direction:column;gap:2px;' +
          'background:#fff;border-radius:16px;box-shadow:var(--sombra-suave,0 10px 22px -16px rgba(46,66,86,.5));' +
          'padding:7px 5px;min-height:min(640px,calc(100vh - 120px));max-height:calc(100vh - 32px);overflow-y:auto;scrollbar-width:none}' +
        '.mm-tira::-webkit-scrollbar{display:none}' +
        '.mm-tira-mundos{display:flex;flex-direction:column;gap:2px}' +
        '.mm-t{display:flex;flex-direction:column;align-items:center;gap:4px;width:100%;box-sizing:border-box;padding:7px 2px 6px;' +
          'border-radius:12px;border:0;background:none;text-decoration:none;color:var(--texto,#4A4437);font-family:inherit;cursor:pointer}' +
        '.mm-t .mm-tq{width:34px;height:34px;border-radius:10px;display:grid;place-items:center;flex:0 0 auto;' +
          'background:var(--crema-media,#EFE9DC);background:color-mix(in srgb, var(--pt,#2E4256) 13%, #fff);color:var(--pt,#2E4256)}' +
        '.mm-t .mm-tq svg{width:19px;height:19px}' +
        '.mm-t .mm-tn{font-size:10.5px;font-weight:600;line-height:1.15;text-align:center;max-width:66px;' +
          'display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;overflow-wrap:break-word}' +
        '.mm-t:hover{background:var(--crema,#FBF9F4)}' +
        '.mm-t[aria-current="true"]{background:var(--mm-azul-suave);color:var(--mm-azul)}' +
        '.mm-t[aria-current="true"] .mm-tq{background:var(--pt);color:#fff;box-shadow:0 6px 12px -8px var(--pt)}' +
        '.mm-t[aria-current="true"] .mm-tn{font-weight:700}' +
        '.mm-tira-pie{margin-top:auto;padding-top:6px;border-top:1px solid var(--linea-marcada,#E4DCCB);display:flex;flex-direction:column;gap:1px}' +
        '.mm-tira-pie .mm-t{padding:6px 2px 5px}' +
        '.mm-tira-pie .mm-t .mm-tq,.mm-abrir .mm-tq{width:30px;height:24px;background:none;color:var(--texto-suave,#6E6656)}' +
        '.mm-tira-pie .mm-t:hover .mm-tq,.mm-abrir:hover .mm-tq{color:var(--mm-azul)}' +
        '.mm-abrir{display:none !important}' +
        '.mm-plegado .mm-abrir{display:flex !important;margin-bottom:4px;border-bottom:1px solid var(--linea-marcada,#E4DCCB);border-radius:12px 12px 0 0}' +
        '.mm-plegado .mm-panel{display:none}' +
        /* panel del mundo */
        '.mm-panel{flex:0 0 230px;width:230px;box-sizing:border-box;background:#fff;border-radius:16px;' +
          'box-shadow:var(--sombra-suave,0 10px 22px -16px rgba(46,66,86,.5));max-height:calc(100vh - 32px);overflow-y:auto;overflow-x:hidden}' +
        '.mm-pcab{display:flex;align-items:center;gap:9px;padding:12px 10px 11px 15px;background:var(--crema,#FBF9F4);' +
          'border-bottom:1px solid var(--linea-marcada,#E4DCCB);position:sticky;top:0;z-index:1}' +
        '.mm-pcab .pt{width:10px;height:10px;border-radius:50%;flex:0 0 auto;background:var(--mm-acento);' +
          'box-shadow:0 0 0 3px color-mix(in srgb, var(--mm-acento) 18%, transparent)}' +
        '.mm-pcab .nm{flex:1 1 auto;min-width:0;font-family:var(--fuente-titulo,inherit);font-weight:700;text-transform:uppercase;' +
          'font-size:16px;line-height:1.05;color:var(--navy,#2E4256)}' +
        '.mm-plegar{flex:0 0 auto;width:30px;height:30px;padding:0;border-radius:9px;border:1px solid var(--linea-borde,#D4CBB9);' +
          'background:#fff;color:var(--texto-suave,#6E6656);display:grid;place-items:center;cursor:pointer}' +
        '.mm-plegar svg{width:16px;height:16px}' +
        '.mm-plegar:hover{color:var(--mm-azul);border-color:var(--mm-azul)}' +
        '.mm-nav{display:flex;flex-direction:column;gap:1px;padding:8px}' +
        '.mm-i{display:flex;align-items:center;gap:10px;width:100%;box-sizing:border-box;text-decoration:none;text-align:left;' +
          'font-family:inherit;font-size:14px;font-weight:500;color:var(--texto,#4A4437);line-height:1.2;' +
          'padding:8px 10px;min-height:38px;border-radius:10px;border-left:3px solid transparent}' +
        '.mm-i .mm-ic{width:20px;height:20px;flex:0 0 auto;display:grid;place-items:center;color:var(--texto-suave,#6E6656)}' +
        '.mm-i .mm-ic svg{width:18px;height:18px}' +
        '.mm-i:hover{background:var(--crema,#FBF9F4)}' +
        '.mm-i[aria-current="true"]{background:var(--mm-azul-suave);color:var(--navy,#2E4256);font-weight:600;border-left-color:var(--mm-azul)}' +
        '.mm-i[aria-current="true"] .mm-ic{color:var(--mm-azul)}' +
        '.mm-gsep{height:1px;background:var(--linea-marcada,#E4DCCB);margin:6px 4px}' +
        '.mm-gh{display:flex;align-items:center;gap:8px;width:100%;box-sizing:border-box;min-height:38px;padding:8px 8px 8px 13px;' +
          'border:0;border-radius:10px;background:none;font-family:inherit;font-size:13.5px;font-weight:700;color:var(--navy,#2E4256);text-align:left;cursor:pointer}' +
        '.mm-gh:hover{background:var(--crema,#FBF9F4)}' +
        '.mm-gh .nm{flex:1 1 auto;min-width:0}' +
        '.mm-gh .pm{flex:0 0 20px;width:20px;height:20px;border-radius:6px;display:grid;place-items:center;' +
          'background:var(--crema-media,#EFE9DC);color:var(--texto-suave,#6E6656)}' +
        '.mm-gh .pm svg{width:11px;height:11px}' +
        '.mm-gh[aria-expanded="true"] .pm .v{display:none}' +
        '.mm-gh[aria-expanded="true"] .pm{background:var(--mm-azul-suave);color:var(--mm-azul)}' +
        '.mm-gl{display:flex;flex-direction:column;gap:1px;padding:1px 0 5px 6px}' +
        '.mm-gl[hidden]{display:none}' +
        '.mm-gl .mm-i{min-height:36px;font-size:13.5px}' +
        '.mm-dos a:focus-visible,.mm-dos button:focus-visible{outline:2px solid var(--mm-azul);outline-offset:2px}' +
        /* la lateral de mundos DENTRO del panel viejo (.at-side de admin-tabbar) */
        '.at-side .at-mundos{display:block}' +
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
      '.mm-busca{position:relative;margin:6px 0 10px}' +
      '.mm-busca svg{position:absolute;left:13px;top:50%;margin-top:-9px;width:18px;height:18px;color:var(--texto-suave,#6E6656);pointer-events:none}' +
      '.mm-busca-inp{box-sizing:border-box;width:100%;min-height:46px;padding:12px 14px 12px 40px;border:1px solid var(--linea-borde,#D4CBB9);border-radius:12px;background:#fff;font-family:inherit;font-size:15px;color:var(--navy,#2E4256)}' +
      '.mm-busca-inp:focus{outline:2px solid var(--azul-filete,#3B85C0);border-color:var(--azul-filete,#3B85C0)}' +
      '.mm-row .mm-rt small{display:block;font-size:12px;font-weight:400;color:var(--texto-suave,#6E6656);margin-top:1px}' +
      '.mm-pers,.mm-nada-busca{padding:11px 13px;font-size:13.5px;color:var(--texto-suave,#6E6656)}' +
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
      // En escritorio la barra de pestañas de móvil (.mm-tab) no va; pero la HOJA
      // de secciones sí debe poder abrirse (es lo que abre el botón «Buscar» del
      // lateral). Antes se ocultaba también la hoja, y por eso el buscador del
      // lateral no hacía nada en PC. Cerrada, la hoja ya queda fuera (transform)
      // y su fondo en display:none, así que no estorba.
      '@media (min-width:900px){.mm-tab{display:none !important}}';
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
  /* estado recordado (localStorage; en modo privado puede fallar → por defecto) */
  var K_PLEG = 'apo-mm-plegado', K_GRUPOS = 'apo-mm-grupos';
  function lsGet(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function lsSet(k, v) { try { if (v == null) localStorage.removeItem(k); else localStorage.setItem(k, v); } catch (e) {} }
  function estaPlegado() { return lsGet(K_PLEG) === '1'; }
  function gruposGuardados() { try { return JSON.parse(lsGet(K_GRUPOS) || '{}') || {}; } catch (e) { return {}; } }
  function guardarGrupo(id, abierto) { var g = gruposGuardados(); g[id] = abierto ? 1 : 0; lsSet(K_GRUPOS, JSON.stringify(g)); }

  function nombreMundo(w) { return w.nombre.replace(/\s*·\s*Club$/, ''); }
  /* Un mundo en la TIRA: cuadradito con su icono y color + nombre corto. */
  function worldRowHtml(w, activeKey) {
    var act = w.key === activeKey, nom = nombreMundo(w);
    return '<a class="mm-t" href="' + esc(w.home) + '" style="--pt:' + w.dot + '" title="' + esc(nom) + '" ' +
      'aria-current="' + act + '" aria-label="' + (act ? 'Estás en ' : '') + esc(nom) + '">' +
      '<span class="mm-tq" aria-hidden="true">' + ico(w.i) + '</span>' +
      '<span class="mm-tn" aria-hidden="true">' + esc(w.corto || nom) + '</span></a>';
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
  var PM = '<svg viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">' +
    '<path d="M2.5 6h7"/><path class="v" d="M6 2.5v7"/></svg>';
  function itemHtml(s, idx, act) {
    return '<a class="mm-i" data-i="' + idx + '" href="' + esc(s.url) + '"' + (s.ext ? ' target="_blank" rel="noopener"' : '') +
      ' aria-current="' + act + '">' +
      '<span class="mm-ic" aria-hidden="true">' + ico(s.i) + '</span><span>' + esc(s.t) + (s.ext ? ' ↗' : '') + '</span></a>';
  }
  /* Las pantallas del mundo: Resumen y Calendario sueltos arriba; el resto, en
     el orden del mapa, agrupado por `g` en apartados plegables. El apartado de
     la pantalla activa se abre solo; los demás, como los dejó la persona. */
  function navHtml(M, esActivo) {
    var all = (M.screens || []).map(function (s, idx) { return { s: s, idx: idx, act: !!esActivo(s, idx) }; })
      .filter(function (o) { return o.s.side !== false; });
    if (!all.length) return '';
    /* Mundos pequeños (≤ 10 pantallas): todo a la vista, sin apartados. Plegar
       en un mundo de 7 pantallas solo escondía cosas (Andrés, 15-oct). Los
       apartados quedan para los mundos grandes, como General. */
    if (all.length <= 10) {
      return '<nav class="mm-nav" aria-label="Pantallas de ' + esc(nombreMundo(M)) + '">' +
        all.map(function (o) { return itemHtml(o.s, o.idx, o.act); }).join('') + '</nav>';
    }
    var arriba = function (o) { return !o.s.g && (o.s.key === 'resumen' || o.s.key === 'calendario'); };
    var guard = gruposGuardados(), hechos = {}, n = 0, sep = false, html = '';
    all.filter(arriba).forEach(function (o) { html += itemHtml(o.s, o.idx, o.act); });
    all.filter(function (o) { return !arriba(o); }).forEach(function (o) {
      var g = o.s.g;
      if (!g) { html += itemHtml(o.s, o.idx, o.act); return; }
      if (hechos[g]) return; hechos[g] = 1;
      var miembros = all.filter(function (x) { return x.s.g === g; });
      var gid = M.key + '|' + g;
      var abierto = miembros.some(function (x) { return x.act; }) || guard[gid] === 1;
      var id = 'mm-g-' + M.key + '-' + (n++);
      if (!sep) { html += '<div class="mm-gsep" role="presentation"></div>'; sep = true; }
      html += '<div class="mm-g"><button type="button" class="mm-gh" data-g="' + esc(gid) + '" aria-expanded="' + abierto + '" aria-controls="' + id + '">' +
          '<span class="nm">' + esc(g) + '</span><span class="pm">' + PM + '</span></button>' +
        '<div class="mm-gl" id="' + id + '" role="group" aria-label="' + esc(g) + '"' + (abierto ? '' : ' hidden') + '>' +
          miembros.map(function (x) { return itemHtml(x.s, x.idx, x.act); }).join('') + '</div></div>';
    });
    return '<nav class="mm-nav" aria-label="Pantallas de ' + esc(nombreMundo(M)) + '">' + html + '</nav>';
  }
  /* La lateral entera: [tira de mundos | panel del mundo]. */
  function sideHtml(M, esActivo, keys) {
    var abierto = !estaPlegado(), nom = esc(nombreMundo(M));
    return '<div class="mm-dos" style="--mm-acento:' + M.dot + '">' +
      '<div class="mm-tira">' +
        '<button type="button" class="mm-t mm-abrir mm-plegar-sw" aria-expanded="' + abierto + '" aria-controls="mm-panel" ' +
          'aria-label="Mostrar el menú de ' + nom + '" title="Mostrar el menú">' +
          '<span class="mm-tq" aria-hidden="true">' + ico('chevr') + '</span><span class="mm-tn" aria-hidden="true">Menú</span></button>' +
        '<nav class="mm-tira-mundos" aria-label="Mundos">' + worldsHtml(keys, M.key) + '</nav>' +
        '<div class="mm-tira-pie">' +
          '<button type="button" class="mm-t mm-t-buscar" aria-haspopup="dialog" title="Buscar una pantalla o una persona">' +
            '<span class="mm-tq" aria-hidden="true">' + ico('search') + '</span><span class="mm-tn">Buscar</span></button>' +
          '<a class="mm-t" href="' + esc(B) + '" title="Ir a la web del club">' +
            '<span class="mm-tq" aria-hidden="true">' + ico('globe') + '</span><span class="mm-tn">Web</span></a>' +
          '<button type="button" class="mm-t mm-t-salir" title="Cerrar sesión">' +
            '<span class="mm-tq" aria-hidden="true">' + ico('logout') + '</span><span class="mm-tn">Salir</span></button>' +
        '</div></div>' +
      '<div class="mm-panel" id="mm-panel">' +
        '<div class="mm-pcab"><span class="pt" aria-hidden="true"></span><span class="nm">' + nom + '</span>' +
          '<button type="button" class="mm-plegar mm-plegar-sw" aria-expanded="' + abierto + '" aria-controls="mm-panel" ' +
            'aria-label="Ocultar el menú" title="Ocultar el menú">' + ico('chevl') + '</button></div>' +
        navHtml(M, esActivo) +
      '</div></div>';
  }
  function contenedor(root) { return (root.closest && root.closest('.at-side,.mm-side')) || root; }
  function ponerPlegado(root, pleg) {
    contenedor(root).classList.toggle('mm-plegado', !!pleg);
    Array.prototype.forEach.call(root.querySelectorAll('.mm-plegar-sw'), function (b) { b.setAttribute('aria-expanded', String(!pleg)); });
  }
  /* Cerrar sesión: igual que la hoja de papeles (papeles.js). */
  function salir(btn) {
    if (btn) { btn.disabled = true; var tn = btn.querySelector('.mm-tn'); if (tn) tn.textContent = 'Saliendo…'; }
    var ir = function () { location.href = B; };
    try {
      var PREF = ['apo-perfil-', 'apo-atletas-', 'apo-grupos', 'apo-barra', 'apo-foto', 'apo-clave-', 'apolana-mis-mundos', 'apo-mundo'], borrar = [];
      for (var i = 0; i < sessionStorage.length; i++) {
        var k = sessionStorage.key(i);
        if (k && PREF.some(function (p) { return k.indexOf(p) === 0; })) borrar.push(k);
      }
      borrar.forEach(function (k) { sessionStorage.removeItem(k); });
    } catch (e) {}
    var c = window.APOLANA_DB;
    try { if (c && c.auth && c.auth.signOut) c.auth.signOut().then(ir, ir); else ir(); } catch (e) { ir(); }
  }
  /* Clics de la lateral (delegados: sobreviven a repintar la tira). */
  function bindSide(root, opts) {
    if (root._mmBound) return; root._mmBound = true;
    ponerPlegado(root, estaPlegado());
    root.addEventListener('click', function (e) {
      var t = e.target; if (!t || !t.closest) return;
      var gh = t.closest('.mm-gh');
      if (gh) {
        var ab = gh.getAttribute('aria-expanded') !== 'true';
        gh.setAttribute('aria-expanded', String(ab));
        var l = document.getElementById(gh.getAttribute('aria-controls')); if (l) l.hidden = !ab;
        guardarGrupo(gh.getAttribute('data-g'), ab);
        return;
      }
      if (t.closest('.mm-plegar-sw')) {
        var p = !contenedor(root).classList.contains('mm-plegado');
        ponerPlegado(root, p); lsSet(K_PLEG, p ? '1' : null);
        var otro = root.querySelector(p ? '.mm-abrir' : '.mm-plegar');
        if (otro) { try { otro.focus(); } catch (e2) {} }
        return;
      }
      if (t.closest('.mm-t-buscar')) { if (opts && opts.onBuscar) opts.onBuscar(); return; }
      var sl = t.closest('.mm-t-salir'); if (sl) salir(sl);
    });
  }
  /* Marca la pantalla activa sin repintar (cuando una página cambia de
     pestaña con history.pushState, p. ej. Dinero ?v=…). */
  function marcar(root, screenIdx) {
    Array.prototype.forEach.call(root.querySelectorAll('.mm-i[data-i]'), function (a) {
      var act = +a.getAttribute('data-i') === screenIdx;
      a.setAttribute('aria-current', String(act));
      if (!act) return;
      var gl = a.closest('.mm-gl');
      if (gl && gl.hidden) {
        gl.hidden = false;
        var gh = root.querySelector('[aria-controls="' + gl.id + '"]'); if (gh) gh.setAttribute('aria-expanded', 'true');
      }
    });
  }
  function vigilarRuta(cb) {
    try {
      ['pushState', 'replaceState'].forEach(function (m) {
        var o = history[m]; if (!o || o._mm) return;
        var f = function () { var r = o.apply(this, arguments); try { window.dispatchEvent(new Event('apolana:ruta')); } catch (e) {} return r; };
        f._mm = 1; history[m] = f;
      });
    } catch (e) {}
    window.addEventListener('apolana:ruta', cb);
    window.addEventListener('popstate', cb);
  }
  function hubCardsHtml(M) {
    return (M.screens || []).filter(function (s) { return s.key !== 'resumen' && s.hub !== false; }).map(function (s) {
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
      // ?v= = pestaña dentro de una página (p. ej. Dinero ?v=cuotas)
      try { var p = new URLSearchParams(s.slice(qi)); var sec = p.get('seccion'), tipo = p.get('tipo'), v = p.get('v');
        if (sec) q = '?seccion=' + sec.toLowerCase(); else if (tipo) q = '?tipo=' + tipo.toLowerCase();
        else if (v) q = '?v=' + v.toLowerCase(); } catch (e) {}
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
        if (s.side === false) return;           // solo tarjeta del Resumen: no se marca en la lateral
        var k = folderKey(s.url);
        if (k && !(k in _idx)) _idx[k] = { world: w.key, idx: i };
      });
    });
    return _idx;
  }
  var COARSE = {
    atletas:'general', socios:'general', dinero:'general', cobros:'general', tarifas:'general', 'pagos-online':'general', 'cubo-pagos':'general', pedidos:'general', nevera:'general',
    paginas:'general', contenido:'general', imagenes:'general', biblioteca:'general', colaboradores:'general', mapa:'general',
    documentos:'general', estadisticas:'general', informes:'general', usuarios:'general', importar:'general', contactos:'general',
    grupos:'general', mundos:'general', campo:'general', buzon:'general', automatizaciones:'general',
    cubo:'cubo', 'cubo-altas':'cubo', 'cubo-prueba':'cubo', asistencia:'cubo',
    natacion:'natacion',
    tests:'pista', pruebas:'pista', competiciones:'pista', confirmaciones:'pista', liga:'pista', records:'pista', palmares:'pista', retos:'pista', 'cuotas-entreno':'pista',
    repartir:'escuela-atl', historico:'escuela-atl', 'escuela-grupos':'escuela-atl', altas:'general',
    eventos:'comunicacion', enlaces:'general', redes:'comunicacion', plantillas:'comunicacion', noticias:'comunicacion', 'avisos-push':'comunicacion'
  };
  // Mundo «pegajoso»: una vez dentro de un mundo, moverte por sus páginas NO
  // debe cambiar la barra, aunque una página compartida (atletas, grupos) pierda
  // el ?seccion. Se recuerda el último mundo resuelto y se usa de respaldo en
  // esas páginas compartidas cuando la URL no dice de qué mundo vienen.
  var SHARED = { atletas: 1, grupos: 1 };
  function guardarMundo(w) { try { if (w) sessionStorage.setItem('apo-mundo', w); } catch (e) {} }
  function mundoGuardado() { try { return sessionStorage.getItem('apo-mundo') || ''; } catch (e) { return ''; } }
  function resolverURL() {
    if (location.pathname.indexOf('/admin/') === -1) return null;
    var cur = folderKey(location.pathname + location.search);
    var map = urlIndex();
    var res = null;
    if (cur && map[cur]) res = { world: map[cur].world, screenIdx: map[cur].idx };
    if (!res) {
      var folderOnly = cur.split('?')[0];
      // Página con pestañas ?v= abierta sin ?v (o con una desconocida): la 1.ª pestaña del mapa.
      var primeraV = null;
      if (folderOnly) Object.keys(map).some(function (k) { if (k.indexOf(folderOnly + '?v=') === 0) { primeraV = map[k]; return true; } return false; });
      if (folderOnly && map[folderOnly]) res = { world: map[folderOnly].world, screenIdx: map[folderOnly].idx };
      else if (primeraV) res = { world: primeraV.world, screenIdx: primeraV.idx };
      else {
        var sec = '';
        try { sec = (new URLSearchParams(location.search).get('seccion') || '').toLowerCase(); } catch (e) {}
        var bySec = { cubo:'cubo', escuela:'escuela-atl', competicion:'pista', running:'running' };
        if (bySec[sec]) res = { world: bySec[sec], screenIdx: -1 };
        // Página compartida sin seccion → mantén el mundo donde estabas.
        else if (SHARED[folderOnly]) res = { world: (mundoGuardado() || 'general'), screenIdx: -1 };
        else res = { world: (COARSE[folderOnly] || mundoGuardado() || 'general'), screenIdx: -1 };
      }
    }
    if (res) guardarMundo(res.world);
    return res;
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
    /* Rellena un elemento (dentro de la .at-side del panel) con la lateral
       de dos columnas. `screenIdx` marca la pantalla activa por índice
       (-1 = ninguna). `opts.onBuscar`: qué abre el botón «Buscar». */
    montarEn: function (el, worldKey, screenIdx, opts) {
      if (!el) return;
      injectCSS();
      var M = mundoPorClave(worldKey) || MUNDOS[0];
      el.style.setProperty('--mm-acento', M.dot);
      var esActivo = function (s, idx) { return idx === screenIdx; };
      var cache = leerCache();
      var initKeys = (cache === undefined) ? [M.key] : cache;
      el.innerHTML = sideHtml(M, esActivo, initKeys);
      bindSide(el, opts);
      var box = el.querySelector('.mm-tira-mundos');
      cargarMisMundos(function (val) { if (box) box.innerHTML = worldsHtml(val, M.key); });
      vigilarRuta(function () {
        var r = resolverURL();
        if (r && r.world === M.key) marcar(el, r.screenIdx);
      });
    },
    /* Lo que dice la lateral sobre su estado (para que admin-tabbar reserve
       el ancho antes de montarla y no haya salto). */
    plegado: estaPlegado
  };

  /* ---------- admin con otra vista → General (mig 447) ----------
     Un admin «de verdad» que va con otra vista (Atleta, Entrenador…) ve todos
     los mundos (mis_mundos), pero la base no le trata como admin (es_admin mira
     rol_activo) y General no le cargaría. Al ir a General —por la barra, la hoja
     del móvil o entrando directo— se le devuelve antes a la vista de admin.
     Resuelve true si ha cambiado algo (hay que recargar). */
  function volverAAdmin() {
    var c = window.APOLANA_DB;
    if (!c || !c.rpc) return Promise.resolve(false);
    return Promise.all([c.rpc('soy_admin_de_verdad'), c.rpc('es_admin')]).then(function (r) {
      if (!(r[0] && r[0].data === true) || (r[1] && r[1].data === true)) return false;
      return c.rpc('rol_activo_poner', { p_rol: null }).then(function (x) {
        if (!x || x.error) return false;
        try { sessionStorage.removeItem(CACHE_KEY); } catch (e) {}
        return true;
      });
    }).catch(function () { return false; });
  }
  document.addEventListener('click', function (ev) {
    var a = ev.target.closest && ev.target.closest('a[href]'), g = mundoPorClave('general');
    if (!a || !g || ev.defaultPrevented || ev.metaKey || ev.ctrlKey || ev.shiftKey) return;
    var destino;
    try { destino = new URL(g.home, location.href).href; } catch (e) { return; }
    if (a.href.split(/[?#]/)[0] !== destino) return;
    ev.preventDefault();
    volverAAdmin().then(function () { location.href = a.href; });
  }, true);

  /* ============================================================
     Modo PORTAL (auto-montaje) — solo si la página declara el mundo
     ============================================================ */
  var CFG = window.APOLANA_MUNDO;
  if (!CFG || !CFG.world) return;              // panel: solo exponemos la API
  var M = mundoPorClave(CFG.world);
  if (!M) return;
  // Las páginas de portal declaran su mundo: lo recordamos para que, al volver
  // a una página compartida del admin, la barra conserve el mundo.
  guardarMundo(CFG.world);
  // Entrando directo a General con otra vista: volver a admin y recargar una vez.
  if (M.key === 'general') {
    (function esperarDb(n) {
      if (!(window.APOLANA_DB && window.APOLANA_DB.rpc)) { if (n < 20) setTimeout(function () { esperarDb(n + 1); }, 150); return; }
      volverAAdmin().then(function (cambio) { if (cambio) location.reload(); });
    })(0);
  }

  injectCSS();
  injectPrefetch();

  // La hoja de «Secciones» (la monta montarBarraMovil) sirve para buscar/ir a
  // una pantalla; aquí la reutiliza el botón «Buscar» del lateral en escritorio.
  var _abrirSecciones = null;

  function montar() {
    var content = CFG.contentSel ? document.querySelector(CFG.contentSel) : null;
    if (!content) return;
    if (document.querySelector('.mm-layout')) return;

    if (CFG.home) renderHub(content, M);

    document.body.classList.add('mm-on');
    var acento = M.dot;

    var side = document.createElement('aside');
    side.className = 'mm-side' + (estaPlegado() ? ' mm-plegado' : '');
    side.style.setProperty('--mm-acento', acento);
    side.setAttribute('aria-label', 'Navegación del panel');

    var esActivo = function (s) { return s.key === (CFG.screen || 'resumen'); };
    var cache = leerCache();
    var initKeys = (cache === undefined) ? [M.key] : cache;
    side.innerHTML = sideHtml(M, esActivo, initKeys);
    // «Buscar» (escritorio) abre la hoja de secciones/buscador de montarBarraMovil.
    bindSide(side, { onBuscar: function () { if (_abrirSecciones) _abrirSecciones(); } });

    var layout = document.createElement('div');
    layout.className = 'mm-layout';
    layout.style.setProperty('--mm-acento', acento);
    content.parentNode.insertBefore(layout, content);
    var main = document.createElement('div');
    main.className = 'mm-main';
    main.appendChild(content);
    layout.appendChild(side);
    layout.appendChild(main);

    var box = side.querySelector('.mm-tira-mundos');
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
      return (M.screens || []).filter(function (s) { return s.side !== false; }).map(function (s) {
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
    // ---- buscador de la hoja: páginas (de TODOS los mundos) + personas ----
    function norm(s){ return String(s == null ? '' : s).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, ''); }
    var _pant = null, _personas = null, _personasW = null;
    function flatPantallas(){
      var out = [];
      MUNDOS.forEach(function (w) {
        var mundo = w.nombre.replace(/\s*·\s*Club$/, '');
        (w.screens || []).forEach(function (s) {
          if (!s.t || !s.url) return;
          var donde = s.g ? mundo + ' · ' + s.g : mundo;   // «Resumen» suelto no dice nada: «General · Dinero»
          out.push({ t: s.t, url: s.url, i: s.i, ext: s.ext, mundo: donde, k: norm(s.t + ' ' + (s.d || '') + ' ' + donde) });
        });
      });
      return out;
    }
    function cargarPersonas(cb){
      if (_personas) { cb(_personas); return; }
      if (_personasW) { _personasW.push(cb); return; }
      _personasW = [cb];
      var fin = function (lista) { _personas = lista || []; var ws = _personasW; _personasW = null; ws.forEach(function (f) { f(_personas); }); };
      var c = window.APOLANA_DB;
      if (!c || !c.from) { fin([]); return; }
      try {
        c.from('atletas').select('id,nombre,apellidos,telefono,telefono_tutor').limit(3000).then(
          function (r) { fin(((r && !r.error && r.data) ? r.data : []).filter(function (x) { return (x.nombre || '').indexOf('(duplicado)') === -1; })); },
          function () { fin([]); }
        );
      } catch (e) { fin([]); }
    }
    /* Resumen de cada persona (sección, grupo, días y hora) sin abrir la ficha
       (mig 373). Se pide solo para las que salen y se guarda. */
    var _resumen = {};
    function filaPersona(a){
      var nom = ((a.nombre || '') + ' ' + (a.apellidos || '')).trim();
      var r = _resumen[a.id];
      return '<a class="mm-row" href="' + esc(B + 'admin/atletas/?ficha=' + encodeURIComponent(a.id)) + '">' +
        '<span class="mm-ic">' + ico('user') + '</span><span class="mm-rt">' + esc(nom) +
        '<small class="mm-resu" data-id="' + esc(a.id) + '">' + (r ? esc(r) : (r === '' ? 'Sin grupo ni horario' : '…')) + '</small></span></a>';
    }
    function rellenarResumenes(ids){
      var falta = ids.filter(function (id) { return !(id in _resumen); });
      var pinta = function () {
        ids.forEach(function (id) {
          var el = sheet.querySelector('.mm-resu[data-id="' + id + '"]');
          if (el) el.textContent = _resumen[id] ? _resumen[id] : 'Sin grupo ni horario';
        });
      };
      var c = window.APOLANA_DB;
      if (!falta.length || !c || !c.rpc) { pinta(); return; }
      c.rpc('buscador_personas_resumen', { p_ids: falta }).then(function (r) {
        (r && !r.error && r.data ? r.data : []).forEach(function (x) { _resumen[x.atleta_id] = x.resumen || ''; });
        falta.forEach(function (id) { if (!(id in _resumen) || _resumen[id] == null) _resumen[id] = ''; });
        pinta();
      }, function () { falta.forEach(function (id) { _resumen[id] = ''; }); pinta(); });
    }
    function buscar(q){
      var res = sheet.querySelector('.mm-res'), def = sheet.querySelector('.mm-def');
      if (!res || !def) return;
      var nq = norm(q).trim();
      if (!nq) { res.hidden = true; res.innerHTML = ''; def.hidden = false; return; }
      def.hidden = true; res.hidden = false;
      if (!_pant) _pant = flatPantallas();
      var pags = _pant.filter(function (p) { return p.k.indexOf(nq) !== -1; }).slice(0, 8);
      var htmlP = pags.map(function (p) {
        return '<a class="mm-row" href="' + esc(p.url) + '"' + (p.ext ? ' target="_blank" rel="noopener"' : '') + '>' +
          '<span class="mm-ic">' + ico(p.i) + '</span>' +
          '<span class="mm-rt">' + esc(p.t) + '<small>' + esc(p.mundo) + '</small></span></a>';
      }).join('');
      res.innerHTML =
        (htmlP ? '<div class="mm-srot">Páginas</div>' + htmlP : '') +
        '<div class="mm-srot">Personas</div><div class="mm-pers">Buscando…</div>';
      cargarPersonas(function (lista) {
        var inp = sheet.querySelector('.mm-busca-inp');
        if (inp && norm(inp.value).trim() !== nq) return;   // el texto ya cambió
        var box = res.querySelector('.mm-pers'); if (!box) return;
        // Un teléfono («626 14 83 33», «+34…») busca por el móvil o el del tutor.
        var cif = nq.replace(/[\s+]/g, '');
        var porTel = /^\d{6,}$/.test(cif);
        if (porTel && cif.length > 9) cif = cif.slice(-9);
        var tel9 = function (s) { var d = String(s || '').replace(/\D/g, ''); return d.length > 9 ? d.slice(-9) : d; };
        var pers = lista.filter(function (a) {
          if (porTel) return (tel9(a.telefono) + ' ' + tel9(a.telefono_tutor)).indexOf(cif) !== -1;
          return norm((a.nombre || '') + ' ' + (a.apellidos || '')).indexOf(nq) !== -1;
        }).slice(0, 10);
        box.outerHTML = pers.length ? pers.map(filaPersona).join('') : '<div class="mm-nada-busca">' + (porTel ? 'Nadie con ese teléfono.' : 'Nadie con ese nombre.') + '</div>';
        if (pers.length) rellenarResumenes(pers.map(function (a) { return a.id; }));
      });
    }

    function pinta(keys) {
      sheet.innerHTML =
        '<div class="mm-sheet-cab"><h2>' + esc(M.nombre.replace(/\s*·\s*Club$/, '')) + '</h2>' +
          '<button type="button" class="mm-sheet-x" aria-label="Cerrar">✕</button></div>' +
        '<div class="mm-busca">' +
          '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>' +
          '<input type="search" class="mm-busca-inp" placeholder="Buscar páginas o personas…" autocomplete="off" autocapitalize="off" spellcheck="false" aria-label="Buscar"></div>' +
        '<div class="mm-res" hidden></div>' +
        '<div class="mm-def">' +
          '<div class="mm-srot">Secciones</div>' + screensSheet() +
          '<div class="mm-srot">Cambiar de mundo</div>' + worldsSheet(keys) +
          '<a class="mm-salir" href="' + esc(salir) + '">Salir a mi portal</a>' +
        '</div>';
      var x = sheet.querySelector('.mm-sheet-x'); if (x) x.addEventListener('click', cerrar);
      var inp = sheet.querySelector('.mm-busca-inp');
      if (inp) inp.addEventListener('input', function () { buscar(inp.value); });
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
      // En escritorio, el foco al buscador para poder escribir ya mismo (en
      // móvil no, para no abrir el teclado de golpe al mirar las secciones).
      if (window.innerWidth >= 900) {
        var _i = sheet.querySelector('.mm-busca-inp');
        if (_i) setTimeout(function () { try { _i.focus(); } catch (e) {} }, 80);
      }
    }
    function cerrar() {
      bg.classList.remove('ver'); sheet.classList.remove('ver');
      document.body.style.overflow = '';
      setTimeout(function () { bg.style.display = 'none'; }, 220);
    }
    bar.querySelector('.mm-menu').addEventListener('click', abrir);
    _abrirSecciones = abrir;   // para el botón «Buscar» del lateral en escritorio
    bg.addEventListener('click', cerrar);
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') cerrar(); });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', montar);
  else montar();
})();
