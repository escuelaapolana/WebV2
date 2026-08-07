/* ============================================================
   EN QUÉ PAPEL ESTOY · Club Atletismo Apolana
   ------------------------------------------------------------
   Maqueta: maquetas/v3/App Apolana papeles.dc.html · bloque 47a
   Decisiones: maquetas/v3/DECISIONES-Y-PAPELES.md · apartado 9

   Andrés es atleta, entrenador, tesorero y administrador. Esto es
   la franja que dice en cuál está y el selector para cambiar.

   LAS SEIS REGLAS DE LA MAQUETA
     1 · Franja permanente, no aviso. Pegada arriba en todas las
         pantallas y NO se puede cerrar: «un aviso que se cierra deja
         de responder ¿en qué papel estoy? justo cuando hace falta».
     2 · El color de la franja identifica el papel. Crema en atleta y
         entrenador; ámbar en tesorero y administrador, que son los
         papeles con permisos sobre otras personas. El color avisa
         antes de leer.
     3 · Cada papel dice qué tiene pendiente («14 por pasar lista»),
         para elegir por el trabajo y no por el nombre. Los recuentos
         son de verdad: los calcula la base (papeles_pendientes()).
         Lo que no se puede contar sale sin recuento; no se inventa.
     4 · Dos sitios para cambiar: el «Cambiar» de la franja, que es el
         de uso diario, y una fila en Mi perfil.
     5 · Administrador y tesorero son papeles DISTINTOS aunque la
         persona tenga los dos. Tesorero entra en cobros y cuotas;
         administrador, en contenido, Liga, fotos y personas.
     6 · No es suplantar: cambias lo que ves, no quién eres. Todo se
         sigue guardando a tu nombre. Aquí no se entra en la cuenta de
         nadie — solo se elige entre los papeles propios.

   Se carga sola desde admin-auth.js y portal-auth.js, y con una
   etiqueta <script> en admin/index.html. Necesita db.js.
   ============================================================ */
(function () {
  'use strict';
  if (window.APOLANA_PAPELES) return;   /* una sola vez por página */

  /* Cada papel: cómo se llama delante de una persona, qué hace, dónde
     vive y de qué color va su franja.
     `mando: true` = tiene permisos sobre otras personas → franja ámbar. */
  var PAPEL = {
    admin:        { titulo: 'Administrador', que: 'Contenido, Liga, fotos, personas y grupos.',    va: 'admin/',              mando: true },
    tesoreria:    { titulo: 'Tesorero',      que: 'Cobros, cuotas, remesas y excepciones.',        va: 'admin/',              mando: true },
    contabilidad: { titulo: 'Contable',      que: 'Socios y adultos: remesas y transferencias.',   va: 'admin/',              mando: true },
    coordinador:  { titulo: 'Coordinación',  que: 'Los grupos de tu sección.',                     va: 'portal/coordinador/', mando: true },
    junta:        { titulo: 'Junta',         que: 'El club, sin la parte del dinero.',             va: 'admin/',              mando: false },
    entrenador:   { titulo: 'Entrenador',    que: 'Tus grupos: planificar y pasar lista.',         va: 'portal/entrenador/',  mando: false },
    atleta:       { titulo: 'Atleta',        que: 'Tus entrenamientos, tus marcas y tus recibos.', va: 'portal/atleta/',      mando: false },
    padre:        { titulo: 'Familia',       que: 'La ficha de tus hijos, faltas y pagos.',        va: 'portal/familia/',     mando: false },
    /* Estos dos existen en la base desde las migraciones 109 y 144 y no
       estaban aquí: quien los llevaba veía «cubo» y «escuela» en crudo en
       la franja de arriba, en minúscula y sin explicar qué abren. */
    escuela:      { titulo: 'Escuela',       que: 'Altas, niños y grupos de la escuela, y la ropa.', va: 'admin/',           mando: true },
    cubo:         { titulo: 'El Cubo',       que: 'Clases, reservas y bonos de El Cubo.',          va: 'admin/cubo/',         mando: true }
  };
  var ORDEN = ['atleta', 'padre', 'entrenador', 'coordinador', 'escuela', 'cubo', 'tesoreria', 'contabilidad', 'admin', 'junta'];

  function titulo(r) { return (PAPEL[r] && PAPEL[r].titulo) || r; }
  function base() { return window.APOLANA_BASE || '../'; }
  function sb() { return window.APOLANA_DB; }
  function esc(s) {
    var d = document.createElement('div');
    d.textContent = (s == null ? '' : String(s));
    return d.innerHTML;
  }

  /* ------------------------------------------------------------
     Estilo. Va aquí porque esto se pinta en las 50 pantallas y no
     puede depender de que cada una traiga su CSS. Los colores salen
     de las variables del sistema (así el cambio de azul llega solo);
     detrás va el valor de la maqueta por si alguna pantalla suelta
     no ha cargado apolana.css.
     ------------------------------------------------------------ */
  var CSS =
    /* --- LA FRANJA · pegada arriba, sin radio, y no se cierra --- */
    '.pap-franja{position:sticky;top:0;z-index:70;display:flex;align-items:center;gap:10px;' +
      'padding:9px clamp(14px,4vw,40px);border-bottom:1px solid var(--linea-marcada,#E4DCCB);' +
      'background:var(--crema-banda,#F1EADC);font-family:var(--fuente-texto,inherit);' +
      'box-sizing:border-box;width:100%}' +
    /* Ámbar en los papeles con permisos sobre otras personas */
    '.pap-franja--mando{background:var(--ambar-fondo,#FDF3E3);border-bottom-color:var(--ambar-borde,#EBD9B8)}' +
    '.pap-franja .pap-punto{width:7px;height:7px;border-radius:999px;background:var(--azul,#2F6FA8);flex-shrink:0}' +
    '.pap-franja--mando .pap-punto{background:var(--ambar,#B96F09)}' +
    '.pap-franja .pap-dice{flex:1;min-width:0;font-size:14px;color:var(--texto,#4A4437);' +
      'overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
    '.pap-franja .pap-dice b{color:var(--navy,#2E4256);font-weight:600}' +
    '.pap-franja button{flex-shrink:0;border:1px solid var(--linea-borde,#C9C0AE);border-radius:999px;' +
      'min-height:34px;padding:0 13px;background:transparent;font-family:inherit;font-size:14px;' +
      'font-weight:600;color:var(--navy,#2E4256);cursor:pointer;line-height:1}' +
    '.pap-franja button:hover{background:rgba(255,255,255,.6)}' +

    /* --- EL SELECTOR --- */
    '.pap-fondo{position:fixed;inset:0;z-index:9997;background:rgba(46,66,86,.45);display:flex;' +
      'align-items:flex-start;justify-content:center;padding:clamp(12px,5vh,52px) 12px;overflow:auto;' +
      'font-family:var(--fuente-texto,inherit)}' +
    '.pap-caja{background:var(--crema,#FBF9F4);border:1px solid var(--linea,#EAE3D5);border-radius:14px;' +
      'width:min(430px,100%);box-shadow:0 30px 70px -25px rgba(46,66,86,.55);' +
      'padding:18px 16px 16px;box-sizing:border-box}' +
    '.pap-cab{display:flex;align-items:flex-end;justify-content:space-between;gap:12px;margin-bottom:12px}' +
    '.pap-cab .pap-quien{font-size:14px;color:var(--texto-suave,#6E6656);display:block}' +
    '.pap-cab h3{font-family:var(--fuente-titulo,"Barlow Condensed",sans-serif);font-weight:700;' +
      'font-size:28px;line-height:1;text-transform:uppercase;color:var(--navy,#2E4256);margin:2px 0 0}' +
    '.pap-cab .pap-x{background:transparent;border:0;font-family:inherit;font-size:15px;font-weight:600;' +
      'color:var(--azul-oscuro,#2F6FA8);cursor:pointer;padding:8px 4px;min-height:44px}' +
    '.pap-op{display:flex;align-items:center;gap:13px;width:100%;box-sizing:border-box;text-align:left;' +
      'background:#fff;border:1px solid var(--linea-marcada,#E4DCCB);border-radius:14px;padding:14px 16px;' +
      'font-family:inherit;cursor:pointer;margin-bottom:10px}' +
    '.pap-op:hover{border-color:var(--linea-borde,#C9C0AE)}' +
    '.pap-op[aria-current="true"]{border:2px solid var(--azul,#2F6FA8);padding:13px 15px;cursor:default}' +
    '.pap-op .pap-ico{width:38px;height:38px;border-radius:10px;background:var(--crema-media,#EFEAE0);' +
      'display:flex;align-items:center;justify-content:center;flex-shrink:0;color:var(--texto,#4A4437)}' +
    '.pap-op[aria-current="true"] .pap-ico{background:var(--azul-suave,#EAF2F9);color:var(--azul-oscuro,#2F6FA8)}' +
    '.pap-op .pap-t{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}' +
    '.pap-op .pap-t b{font-size:16px;font-weight:600;color:var(--navy,#2E4256)}' +
    '.pap-op .pap-t span{font-size:14px;color:var(--texto-suave,#6E6656)}' +
    '.pap-op .pap-t span.pap-pdte{color:#8A5307}' +
    '.pap-op .pap-ahora{font-size:14px;font-weight:600;color:var(--azul-oscuro,#2F6FA8);flex-shrink:0}' +
    '.pap-op .pap-chev{flex-shrink:0;color:var(--texto-suave,#6E6656)}' +
    '.pap-nota{background:var(--crema-banda,#F1EADC);border-radius:12px;padding:12px 14px;' +
      'display:flex;flex-direction:column;gap:4px;margin-bottom:10px}' +
    '.pap-nota b{font-size:15px;font-weight:600;color:var(--navy,#2E4256)}' +
    '.pap-nota span{font-size:14px;line-height:1.45;color:var(--texto,#4A4437)}' +
    '.pap-abrir{display:flex;flex-direction:column;gap:7px;border-top:1px solid var(--linea-marcada,#E4DCCB);padding-top:10px}' +
    '.pap-abrir .pap-et{font-size:14px;color:var(--texto-suave,#6E6656);padding-left:2px}' +
    '.pap-abrir select{width:100%;box-sizing:border-box;min-height:44px;border:1px solid var(--linea-borde,#D4CBB9);' +
      'background:#fff;border-radius:10px;padding:10px 13px;font-family:inherit;font-size:15px;' +
      'color:var(--navy,#2E4256);cursor:pointer}' +
    '.pap-abrir select:disabled{opacity:.6;cursor:default}' +
    /* La fila en la que ya estás no se pulsa, pero se lee igual de bien:
       apagarla sería apagar justo la que contesta a la pregunta. */
    '.pap-op[disabled]:not([aria-current="true"]){opacity:.55}' +

    /* --- La fila de Mi perfil --- */
    '.pap-fila{display:flex;align-items:center;gap:12px;width:100%;box-sizing:border-box;min-height:48px;' +
      'padding:12px 14px;background:transparent;border:1px solid var(--linea,#EAE3D5);border-radius:10px;' +
      'font-family:inherit;text-align:left;cursor:pointer;margin-top:10px}' +
    '.pap-fila:hover{background:var(--crema,#FBF9F4)}' +
    '.pap-fila .pap-t{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}' +
    '.pap-fila .pap-t b{font-size:15px;font-weight:600;color:var(--navy,#2E4256)}' +
    '.pap-fila .pap-t span{font-size:13px;color:var(--texto-suave,#6E6656)}';

  var estiloPuesto = false;
  function ponerEstilo() {
    if (estiloPuesto) return;
    estiloPuesto = true;
    var s = document.createElement('style');
    s.textContent = CSS;
    document.head.appendChild(s);
  }

  /* Iconos del juego del kit: 24×24, trazo 1,9, puntas redondas. */
  function ic(trazo) {
    return '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
      'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + trazo + '</svg>';
  }
  var ICO = {
    atleta:       ic('<circle cx="15.5" cy="4.8" r="2"/><path d="M7 21l3-5.5 3.5-2.5-1-4.5-4 2-1.5 3"/><path d="M13.5 13l3.5 2 1.5 4"/>'),
    padre:        ic('<circle cx="9" cy="8" r="3.2"/><path d="M3 20a6 6 0 0112 0"/><path d="M16 6.5a3 3 0 010 5.5"/>'),
    entrenador:   ic('<ellipse cx="12" cy="12" rx="9" ry="6"/><ellipse cx="12" cy="12" rx="4" ry="2.2"/>'),
    coordinador:  ic('<circle cx="12" cy="8" r="3.4"/><path d="M5 20a7 7 0 0114 0"/>'),
    tesoreria:    ic('<rect x="3.5" y="6.5" width="17" height="11" rx="2.5"/><path d="M3.5 10.5h17"/>'),
    contabilidad: ic('<rect x="3.5" y="6.5" width="17" height="11" rx="2.5"/><path d="M3.5 10.5h17"/>'),
    admin:        ic('<path d="M4 6.5h16M7 12h10M10 17.5h4"/>'),
    junta:        ic('<path d="M4 20V9l8-5 8 5v11"/><path d="M9 20v-6h6v6"/>')
  };
  var CHEV = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
    'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>';

  var DATOS = null;       /* mis_papeles() */
  var PENDIENTE = null;   /* papeles_pendientes() */

  async function cargar() {
    if (DATOS) return DATOS;
    if (!sb() || !sb().rpc) return null;
    try {
      var r = await sb().rpc('mis_papeles');
      DATOS = (r.error || !r.data) ? null : r.data;
    } catch (e) { DATOS = null; }
    return DATOS;
  }

  /* Lo que tiene pendiente cada papel. Se pide aparte y sin bloquear:
     la franja no puede esperar a una cuenta. Si falla, las filas salen
     sin recuento, que es mejor que un número inventado. */
  async function pendientes() {
    if (PENDIENTE) return PENDIENTE;
    try {
      var r = await sb().rpc('papeles_pendientes');
      PENDIENTE = (r.error || !r.data) ? {} : r.data;
    } catch (e) { PENDIENTE = {}; }
    return PENDIENTE;
  }

  function olvidar() { DATOS = null; PENDIENTE = null; }

  /* ------------------------------------------------------------
     Cambiar de papel. Se guarda en la base —no en el navegador— y se
     recarga: el panel y el portal leen el papel AL ENTRAR, así que
     sin recargar se quedarían creyendo que sigue siendo lo de antes.
     Si el papel nuevo vive en otro sitio (un atleta no pinta en el
     panel), se va derecho a su zona.
     ------------------------------------------------------------ */
  function decir(msg, tipo) {
    if (typeof window.apoToast === 'function') return window.apoToast(msg, tipo);
    if (window.APX && window.APX.toast) return window.APX.toast(msg, tipo);
    alert(msg);
  }

  async function cambiar(rol) {
    var r = await sb().rpc('rol_activo_poner', { p_rol: rol || null });
    if (r.error) { decir('No se ha podido cambiar: ' + r.error.message, 'error'); return false; }
    olvidar();
    var destino = (PAPEL[r.data] && PAPEL[r.data].va) || null;
    if (destino && location.pathname.indexOf('/' + destino) === -1) location.href = base() + destino;
    else location.reload();
    return true;
  }

  /* ------------------------------------------------------------
     EL SELECTOR · cuatro filas, cada una con lo que tiene pendiente
     ------------------------------------------------------------ */
  function abrir(d) {
    ponerEstilo();
    var roles = (d.roles || []).slice().sort(function (a, b) {
      return ORDEN.indexOf(a) - ORDEN.indexOf(b);
    });

    var fondo = document.createElement('div');
    fondo.className = 'pap-fondo';
    fondo.innerHTML =
      '<div class="pap-caja" role="dialog" aria-modal="true" aria-label="Cambiar de papel">' +
        '<div class="pap-cab">' +
          '<div><span class="pap-quien">' + esc(d.nombre || '') + '</span><h3>Cambiar de papel</h3></div>' +
          '<button type="button" class="pap-x" data-cerrar>Cerrar</button>' +
        '</div>' +
        '<div id="pap-filas">' +
          roles.map(function (r) {
            var p = PAPEL[r] || { titulo: r, que: '' };
            var act = (r === d.activo);
            return '<button type="button" class="pap-op" data-rol="' + esc(r) + '"' +
              ' aria-current="' + act + '"' + (act ? ' disabled' : '') + '>' +
              '<span class="pap-ico">' + (ICO[r] || ICO.admin) + '</span>' +
              '<span class="pap-t"><b>' + esc(p.titulo) + '</b>' +
                '<span data-pdte="' + esc(r) + '">' + esc(p.que) + '</span></span>' +
              (act ? '<span class="pap-ahora">Ahora</span>' : '<span class="pap-chev">' + CHEV + '</span>') +
            '</button>';
          }).join('') +
        '</div>' +
        '<div class="pap-nota">' +
          '<b>Son tus papeles, no otras cuentas</b>' +
          '<span>Cambias lo que ves, no quién eres. Todo se sigue guardando a tu nombre.</span>' +
        '</div>' +
        /* Esto de aquí abajo NO cambia de papel: elige por dónde se abre
           la próxima vez. Antes era otra fila de botones con los mismos
           nombres que los de arriba, y pasaba lo que tenía que pasar:
           se pulsaba «Administrador» aquí esperando entrar como
           administrador, y la ventana hacía justo lo que se le pedía,
           o sea nada visible. Parecía que el cambio de papel estaba
           roto. Un desplegable no se confunde con un botón. */
        '<div class="pap-abrir">' +
          '<label class="pap-et" for="pap-al-entrar">Al entrar, abrir en</label>' +
          '<select id="pap-al-entrar">' +
            '<option value=""' + (!d.al_entrar ? ' selected' : '') + '>El último que usé</option>' +
            roles.map(function (r) {
              return '<option value="' + esc(r) + '"' +
                (d.al_entrar === r ? ' selected' : '') + '>' + esc(titulo(r)) + '</option>';
            }).join('') +
          '</select>' +
        '</div>' +
      '</div>';

    document.body.appendChild(fondo);
    var previo = document.activeElement;
    function cerrar() {
      document.removeEventListener('keydown', tecla, true);
      if (fondo.parentNode) fondo.parentNode.removeChild(fondo);
      if (previo && previo.focus) { try { previo.focus(); } catch (e) {} }
    }
    function tecla(e) { if (e.key === 'Escape') { e.preventDefault(); cerrar(); } }
    document.addEventListener('keydown', tecla, true);
    fondo.addEventListener('click', function (e) { if (e.target === fondo) cerrar(); });
    fondo.querySelector('[data-cerrar]').addEventListener('click', cerrar);

    /* Los recuentos llegan cuando llegan y sustituyen a la descripción.
       El que no se pueda calcular se queda con su frase: fila sin
       recuento, que es lo acordado. */
    pendientes().then(function (p) {
      roles.forEach(function (r) {
        var e = fondo.querySelector('[data-pdte="' + r + '"]');
        if (e && p && p[r]) { e.textContent = p[r]; e.className = 'pap-pdte'; }
      });
    });

    fondo.addEventListener('click', function (e) {
      var b = e.target.closest('[data-rol]');
      if (b && !b.disabled) {
        /* Se apagan los botones mientras se cambia, para que nadie pulse dos
           papeles seguidos. Pero si el cambio falla —basta un momento de mala
           cobertura— hay que volver a encenderlos: si no, la ventana se queda
           muerta y solo se arregla cerrándola y abriéndola otra vez. */
        var apagados = Array.prototype.slice.call(fondo.querySelectorAll('button'));
        apagados.forEach(function (x) { x.disabled = true; });
        function reactivar() {
          apagados.forEach(function (x) {
            /* La fila del papel en el que ya estás sigue sin poder pulsarse. */
            if (x.getAttribute('aria-current') !== 'true') x.disabled = false;
          });
        }
        cambiar(b.getAttribute('data-rol')).then(function (ok) {
          if (!ok) reactivar();
        }, function () {
          decir('No se ha podido cambiar de papel. Vuelve a intentarlo.', 'error');
          reactivar();
        });
        return;
      }
    });

    /* El desplegable guarda solo al soltarlo. Se apunta lo que había: si
       la base dice que no, se devuelve a su sitio, que si no queda
       enseñando una opción que no es la guardada. */
    var sel = fondo.querySelector('#pap-al-entrar');
    if (sel) {
      var antes = sel.value;
      sel.addEventListener('change', function () {
        var rol = sel.value || null;
        sel.disabled = true;
        sb().rpc('rol_al_entrar_poner', { p_rol: rol }).then(function (r) {
          sel.disabled = false;
          if (r.error) { sel.value = antes; decir('No se ha podido guardar: ' + r.error.message, 'error'); return; }
          antes = sel.value;
          if (DATOS) DATOS.al_entrar = rol;
          decir(rol ? 'Al entrar se abrirá en ' + titulo(rol) : 'Al entrar se abrirá en el último que uses', 'ok');
        }, function () {
          sel.disabled = false; sel.value = antes;
          decir('No se ha podido guardar. Vuelve a intentarlo.', 'error');
        });
      });
    }

    var primero = fondo.querySelector('.pap-op:not([disabled])');
    if (primero) primero.focus();
  }

  /* ------------------------------------------------------------
     LA FRANJA · permanente, pegada arriba, sin botón de cerrar.
     El color dice el papel antes de que nadie lea nada.
     ------------------------------------------------------------ */
  function ponerFranja(d) {
    if (document.querySelector('.pap-franja')) return;
    ponerEstilo();
    /* Que no se pinte dos veces: si ya hay franja, fuera la vieja. Así
       aunque montar() se llame más de una vez, nunca se apilan. */
    var vieja = document.querySelector('.pap-franja');
    if (vieja) vieja.parentNode.removeChild(vieja);
    var manda = !!(PAPEL[d.activo] && PAPEL[d.activo].mando);
    var f = document.createElement('div');
    f.className = 'pap-franja' + (manda ? ' pap-franja--mando' : '');
    f.setAttribute('role', 'status');
    f.innerHTML =
      '<span class="pap-punto" aria-hidden="true"></span>' +
      '<span class="pap-dice">Estás como <b>' + esc(titulo(d.activo).toLowerCase()) + '</b></span>' +
      '<button type="button">Cambiar</button>';
    f.querySelector('button').addEventListener('click', function () { abrir(DATOS || d); });
    document.body.insertBefore(f, document.body.firstChild);
  }

  /* ------------------------------------------------------------
     LA FILA DE MI PERFIL · el segundo sitio para cambiar, para quien
     lo busque donde se buscan los ajustes. Abre lo mismo.
     ------------------------------------------------------------ */
  function ponerFila(destino) {
    var caja = (typeof destino === 'string') ? document.querySelector(destino) : destino;
    if (!caja || !DATOS) return null;
    ponerEstilo();
    var b = document.createElement('button');
    b.type = 'button';
    b.className = 'pap-fila';
    b.innerHTML =
      '<span class="pap-ico" style="width:38px;height:38px;border-radius:10px;background:var(--crema-media,#EFEAE0);' +
        'display:flex;align-items:center;justify-content:center;flex-shrink:0;color:var(--texto,#4A4437)">' +
        (ICO[DATOS.activo] || ICO.admin) + '</span>' +
      '<span class="pap-t"><b>Estás como ' + esc(titulo(DATOS.activo).toLowerCase()) + '</b>' +
      '<span>Tienes ' + (DATOS.roles || []).length + ' papeles. Cambias lo que ves, no quién eres.</span></span>' +
      '<span class="pap-chev" style="color:var(--texto-suave,#6E6656)">' + CHEV + '</span>';
    b.addEventListener('click', function () { abrir(DATOS); });
    caja.appendChild(b);
    return b;
  }

  /* ------------------------------------------------------------
     Montarlo. Se llama una vez por página, cuando ya hay sesión.
     Si la persona solo tiene un papel no se pinta nada: una franja
     que siempre dice lo mismo es ruido.
     ------------------------------------------------------------ */
  async function montar() {
    var d = await cargar();
    if (!d) return null;
    if ((d.roles || []).length > 1) ponerFranja(d);
    return d;
  }

  window.APOLANA_PAPELES = {
    montar: montar,
    cargar: cargar,
    pendientes: pendientes,
    cambiar: cambiar,
    abrir: function () { return cargar().then(function (d) { if (d) abrir(d); }); },
    ponerFila: ponerFila,
    titulo: titulo,
    PAPEL: PAPEL
  };
})();
