/* ============================================================
   ACCESO A LOS PORTALES · Club Atletismo Apolana
   ------------------------------------------------------------
   Login para CUALQUIER usuario del club (atleta, familia,
   entrenador, coordinación, admin). Cuando hay sesión, busca su
   perfil (nombre + rol) y llama a la función registrada con
   APOLANA_PORTAL.listo(function(sb, perfil){ ... }).
   Requiere supabase-js + db.js cargados antes. Cárgalo SIN defer.

   Además:
   - La pantalla de entrada sigue la maqueta 19b: titular del club,
     accesos públicos «sin cuenta» y llamada a inscripción.
   - La barra de arriba deja cambiar de perfil sin cerrar sesión
     cuando un mismo correo tiene varios papeles (por ejemplo, una
     madre que además tiene ficha de atleta).
   ============================================================ */
(function () {
  var _cb = null;
  var _papeles = null;      // promesa cacheada con los papeles del usuario
  window.APOLANA_PORTAL = {
    listo: function (cb) { _cb = cb; }
    /* papeles() se añade más abajo, cuando ya hay sesión */
  };
  function base() { return window.APOLANA_BASE || '../'; }
  function esc(s) { var d = document.createElement('div'); d.textContent = (s == null ? '' : String(s)); return d.innerHTML; }

  /* ------------------------------------------------------------
     EL INTERRUPTOR DE PAPELES
     Una persona del club puede llevar varios papeles a la vez
     («soy tesorero, admin, entrenador y atleta»). El interruptor
     para cambiar entre LOS SUYOS vive en assets/js/papeles.js y se
     trae desde aquí, en vez de meterle una etiqueta <script> a las
     18 pantallas del portal.

     Si el archivo no llega (sin conexión, caché vieja), no pasa
     nada: la pantalla sigue funcionando exactamente igual que hoy.
     ------------------------------------------------------------ */
  function montarPapeles() {
    function hazlo() {
      if (!window.APOLANA_PAPELES) return;
      try { window.APOLANA_PAPELES.montar(); } catch (e) {}
    }
    if (window.APOLANA_PAPELES) { hazlo(); return; }
    var s = document.createElement('script');
    s.src = base() + 'assets/js/papeles.js';
    s.async = true;
    s.addEventListener('load', hazlo);
    s.addEventListener('error', function () { /* sin interruptor, pero el portal sigue vivo */ });
    document.head.appendChild(s);
  }

  var css = document.createElement('style');
  css.textContent =
    /* --- tarjeta de acceso (maqueta 19b · pantalla A) --- */
    '.pt-login{max-width:420px;margin:6vh auto;background:#fff;border:1px solid #EAE3D5;border-radius:14px;padding:30px 26px 24px;box-shadow:0 26px 50px -32px rgba(46,66,86,.5)}' +
    '.pt-login .pt-logo{display:block;margin:0 auto 8px;height:58px;width:auto}' +
    '.pt-login h1{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:36px;line-height:1;color:#2E4256;margin:0 0 6px;text-align:center}' +
    '.pt-login .lema{color:#5E5849;margin:0 0 16px;text-align:center;font-size:15px;line-height:1.5}' +
    '.pt-login label{display:block;font-size:13px;line-height:1.4;color:#6E6656;margin:12px 0 5px}' +
    '.pt-login input{width:100%;box-sizing:border-box;padding:13px 14px;border:1px solid #E0D8C8;border-radius:10px;font-size:16px;font-family:inherit;color:#2E4256;background:#fff}' +
    '.pt-login .msg{margin-top:12px;font-size:14px;color:#b3261e;text-align:center}' +
    '.pt-login .msg.ok{color:#1e7a3d}' +
    '.pt-olvido{display:flex;align-items:center;justify-content:center;min-height:44px;margin:6px auto 0;background:none;border:0;padding:0 8px;color:#2F6FA8;font-size:15px;font-family:inherit;cursor:pointer;text-decoration:none}' +
    '.pt-sep{display:flex;align-items:center;gap:12px;margin:18px 0 12px}' +
    '.pt-sep span{font-family:var(--fuente-texto);font-size:13px;color:#6E6656}' +
    '.pt-sep i{flex:1;height:1px;background:#E4DCCB;display:block}' +
    '.pt-publico{display:flex;flex-direction:column;gap:8px}' +
    '.pt-publico a{background:#fff;border:1px solid #E4DCCB;border-radius:10px;padding:10px 16px;min-height:44px;box-sizing:border-box;display:flex;justify-content:space-between;align-items:center;font-size:15px;color:#2E4256;text-decoration:none}' +
    '.pt-publico a:hover{border-color:#C9D9E7}' +
    '.pt-publico a b{font-weight:400}' +
    '.pt-publico a i{color:#6E6656;font-style:normal}' +
    '.pt-pie{margin-top:18px;padding-top:16px;border-top:1px solid #EAE3D5;display:flex;flex-direction:column;gap:8px}' +
    '.pt-pie span{font-size:14px;color:#4A4437;text-align:center}' +
    '.pt-pie a{border:1px solid #C9D9E7;color:#2F6FA8;text-align:center;padding:13px;border-radius:999px;font-size:15px;font-weight:600;text-decoration:none}' +
    '.pt-pie a:hover{background:#EAF2F9}' +
    /* Nada debe provocar scroll horizontal (era lo que dejaba la barra corta). */
    'html,body{max-width:100%;overflow-x:hidden}' +
    /* --- barra superior --- */
    '.pt-top{background:#2E4256;color:#fff;display:flex;align-items:center;justify-content:space-between;gap:10px;padding:7px clamp(14px,4vw,40px);flex-wrap:nowrap;width:100%;box-sizing:border-box}' +
    '.pt-top .izq{display:flex;align-items:center;gap:14px;min-width:0;overflow:hidden}' +
    /* «Ir a la web» va a la DERECHA, junto a «Salir», y sin flecha. En la
       esquina de arriba a la izquierda el móvil tiene el gesto de volver
       atrás: una flecha ahí que además te saca del portal se pulsa sola.
       Se distingue de «Salir» por el peso: esta es texto suelto, «Salir»
       es un botón perfilado. Nunca dos botones iguales al lado, porque uno
       de los dos cierra la sesión. */
    '.pt-top .aweb{display:inline-flex;align-items:center;justify-content:center;min-height:44px;' +
      'padding:0 10px;flex:0 0 auto;border-radius:999px;font-size:15px;color:#cdd6e0}' +
    '.pt-top .aweb:hover{background:rgba(255,255,255,.12);color:#fff}' +
    '.pt-top .marca{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:18px;color:#fff;text-decoration:none;white-space:nowrap;min-width:0;overflow:hidden;text-overflow:ellipsis}' +
    '.pt-top .der{display:flex;align-items:center;gap:10px;font-size:14px;color:#cdd6e0;min-width:0}' +
    '.pt-top .der span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:34vw}' +
    '.pt-top a{color:#cdd6e0;text-decoration:none;white-space:nowrap}' +
    '.pt-top button{display:inline-flex;align-items:center;min-height:44px;background:transparent;border:1px solid rgba(255,255,255,.4);color:#fff;border-radius:999px;padding:0 16px;cursor:pointer;font-family:inherit;font-size:15px;white-space:nowrap;flex:0 0 auto}' +
    '.pt-top button:hover{background:rgba(255,255,255,.12)}' +
    /* Un nombre cortado a «Andr…» no dice quién eres: parece que la barra
       está rota. Cuando no cabe entero, se quita — igual que hace la barra
       del panel (assets/js/admin-auth.js). Quién eres sigue estando en la
       franja de debajo y en Mi perfil. */
    '@media(max-width:900px){.pt-top .der span{display:none}}' +
    /* En un móvil estrecho, quien tiene varios papeles lleva tres mandos a la
       derecha (Cambiar de perfil · Ir a la web · Salir). Se deja envolver
       antes que recortar: la página tiene overflow-x oculto, así que sin
       esto «Salir» se cortaría por el borde. */
    '@media(max-width:560px){.pt-top{padding:6px 14px;gap:8px;flex-wrap:wrap;row-gap:2px}' +
      '.pt-top .marca{display:none}.pt-top .aweb{padding:0 8px}.pt-top button{padding:0 13px}' +
      '.pt-top .der{flex:1 1 auto;justify-content:flex-end}}' +
    /* --- hoja de cambio de perfil (maqueta 19b · pantalla C) --- */
    '.pt-hoja{position:fixed;inset:0;background:rgba(46,66,86,.45);display:flex;align-items:flex-end;justify-content:center;z-index:9000}' +
    '.pt-hoja .caja{background:#FBF9F4;width:min(460px,100%);max-height:88vh;overflow:auto;border-radius:14px 14px 0 0;padding:20px 20px 26px}' +
    '@media(min-width:640px){.pt-hoja{align-items:center}.pt-hoja .caja{border-radius:14px}}' +
    '.pt-hoja .cab{display:flex;align-items:baseline;justify-content:space-between;gap:12px;margin-bottom:14px}' +
    '.pt-hoja h2{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:28px;line-height:1.05;color:#2E4256;margin:0}' +
    '.pt-hoja .cerrar{display:inline-flex;align-items:center;min-height:44px;background:none;border:0;padding:0 4px;color:#2F6FA8;font-size:15px;font-family:inherit;cursor:pointer}' +
    '.pt-hoja .fila{display:flex;align-items:center;gap:12px;min-height:44px;background:#fff;border:1px solid #E4DCCB;border-radius:14px;padding:12px 14px;margin-bottom:8px;text-decoration:none}' +
    '.pt-hoja .fila:hover{border-color:#C9D9E7}' +
    '.pt-hoja .fila.activa{border-color:#3B85C0;background:#EAF2F9}' +
    '.pt-hoja .ini{width:36px;height:36px;flex:0 0 36px;border-radius:50%;background:#EAF2F9;color:#2F6FA8;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:600}' +
    '.pt-hoja .txt{flex:1;min-width:0}' +
    '.pt-hoja .txt b{display:block;font-size:15px;color:#2E4256;font-weight:600}' +
    '.pt-hoja .txt small{display:block;font-size:13px;line-height:1.4;color:#6E6656}' +
    '.pt-hoja .chev{color:#6E6656}' +
    '.pt-hoja .acciones{margin-top:14px;border-top:1px solid #EAE3D5;padding-top:10px;display:flex;flex-direction:column;gap:2px}' +
    '.pt-hoja .acciones button{display:block;width:100%;min-height:44px;background:none;border:0;text-align:left;padding:11px 2px;font-size:15px;font-family:inherit;color:#2F6FA8;cursor:pointer}' +
    '.pt-hoja .nota{font-size:13px;color:#6E6656;margin:10px 2px 0}' +
    /* --- los cuatro estados de cualquier bloque (fundamentos 28f) --- */
    '.ap-esq{display:block}' +
    '.ap-esq .ap-l{display:block;border-radius:10px;background:var(--crema-media,#EFE9DC);' +
      'animation:ap-pulso 1.5s ease-in-out infinite}' +
    '.ap-esq .ap-l+.ap-l{margin-top:8px}' +
    '.ap-esq .ap-fila{display:flex;align-items:center;gap:14px;padding:13px 0;border-bottom:1px solid var(--linea,#EAE3D5)}' +
    '.ap-esq .ap-fila:first-child{padding-top:4px}' +
    '.ap-esq .ap-fila:last-child{border-bottom:0}' +
    '.ap-esq .ap-col{flex:1;min-width:0}' +
    '.ap-esq .ap-cifras{display:flex;gap:26px;flex-wrap:wrap}' +
    '.ap-esq .ap-cif{display:flex;flex-direction:column}' +
    '@keyframes ap-pulso{0%,100%{opacity:1}50%{opacity:.5}}' +
    '@media(prefers-reduced-motion:reduce){.ap-esq .ap-l{animation:none}}' +
    '.ap-vacio{background:var(--crema-banda,#F1EADC);border-radius:14px;padding:18px 20px;' +
      'display:flex;flex-direction:column;gap:10px;align-items:flex-start}' +
    '.ap-vacio b{font-size:15px;font-weight:600;line-height:1.35;color:var(--navy,#2E4256)}' +
    '.ap-vacio p{margin:0;font-size:14px;line-height:1.5;color:var(--texto,#4A4437);max-width:58ch}' +
    '.ap-vacio .ap-btn{background:#fff;border:1px solid var(--linea-borde,#D4CBB9);color:var(--navy,#2E4256)}' +
    '.ap-vacio .ap-btn:hover{background:var(--crema,#FBF9F4)}' +
    /* El error va en ámbar: el rojo se reserva para lo que el usuario ha hecho mal */
    '.ap-error{background:var(--ambar-fondo,#FDF3E3);border:1px solid var(--ambar-borde,#EBD9B8);' +
      'border-radius:14px;padding:16px 18px;display:flex;flex-direction:column;gap:10px;align-items:flex-start}' +
    '.ap-error b{font-size:15px;font-weight:600;line-height:1.35;color:#6B5227}' +
    '.ap-error p{margin:0;font-size:14px;line-height:1.5;color:#6B5227;max-width:58ch}' +
    '.ap-error .ap-btn{background:#fff;border:1px solid #E0CDA8;color:#6B5227}' +
    '.ap-btn{display:inline-flex;align-items:center;justify-content:center;min-height:44px;' +
      'padding:10px 18px;box-sizing:border-box;border-radius:999px;font-family:inherit;font-size:15px;' +
      'font-weight:600;line-height:1.2;cursor:pointer;text-decoration:none}' +
    '.ap-oculto{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}';
  document.head.appendChild(css);

  /* ============================================================
     ESTADOS DE UN BLOQUE QUE LEE DATOS · fundamentos 28f
     ------------------------------------------------------------
     1) Cargando: bloques con la forma del dato, nunca «Cargando…»
        en gris. Si pasan de dos segundos, se convierte en error.
     2) Vacío: explica y ofrece algo que hacer. Nunca un guion.
     4) Error: ámbar y con botón de reintentar.

     Se usa de dos maneras, y las dos dan el mismo resultado:
       · en el HTML de la página  <div class="ap-esq" data-esq="filas"></div>
       · desde JavaScript          APOLANA_UI.cargando('filas', 4)
     ============================================================ */
  var ANCHOS = ['62%', '78%', '54%', '70%', '58%'];
  function lin(w, h) { return '<span class="ap-l" style="width:' + w + ';height:' + h + 'px"></span>'; }

  function formaDe(tipo, n) {
    var h = '', i;
    if (tipo === 'cifras') {
      n = n || 3;
      h = '<span class="ap-cifras">';
      for (i = 0; i < n; i++) h += '<span class="ap-cif">' + lin((36 + i * 9) + 'px', 24) + lin((56 + i * 12) + 'px', 11) + '</span>';
      h += '</span>';
    } else if (tipo === 'texto') {
      n = n || 3;
      for (i = 0; i < n; i++) h += lin(ANCHOS[i % 5], 13);
    } else if (tipo === 'tarjeta') {
      h = lin('44%', 19) + lin('88%', 13) + lin('66%', 13);
    } else { /* filas · el caso normal: una lista o una tabla */
      n = n || 3;
      for (i = 0; i < n; i++) {
        h += '<span class="ap-fila"><span class="ap-col">' + lin(ANCHOS[i % 5], 14) + lin('34%', 11) +
             '</span>' + lin('58px', 14) + '</span>';
      }
    }
    return h + '<span class="ap-oculto">Cargando…</span>';
  }

  function llenar(e) {
    var v = (e.getAttribute('data-esq') || 'filas').split(':');
    e.innerHTML = formaDe(v[0] || 'filas', v[1] ? parseInt(v[1], 10) : 0);
    e.setAttribute('role', 'status');
    e.setAttribute('data-t', Date.now());
  }

  function bloque(clase, titulo, texto, accion) {
    return '<div class="' + clase + '"><b>' + esc(titulo) + '</b>' +
           (texto ? '<p>' + esc(texto) + '</p>' : '') + (accion || '') + '</div>';
  }

  window.APOLANA_UI = {
    /* Marcador con la forma del dato que va a llegar */
    cargando: function (tipo, n) {
      return '<div class="ap-esq" data-esq="' + (tipo || 'filas') + '" role="status" data-t="' + Date.now() + '">' +
             formaDe(tipo || 'filas', n) + '</div>';
    },
    /* Estado vacío: qué pasa y qué se puede hacer */
    vacio: function (titulo, texto, accion) { return bloque('ap-vacio', titulo, texto, accion); },
    /* Estado de error, en ámbar y con salida */
    error: function (titulo, texto, accion) {
      return bloque('ap-error', titulo || 'No hemos podido cargar esta parte',
        texto || 'Puede ser tu conexión.',
        accion === null ? '' : (accion || '<button type="button" class="ap-btn ap-reintentar">Volver a intentarlo</button>'));
    },
    /* Botón para un estado vacío */
    boton: function (texto, href) {
      return href ? '<a class="ap-btn" href="' + href + '">' + esc(texto) + '</a>'
                  : '<button type="button" class="ap-btn">' + esc(texto) + '</button>';
    }
  };

  /* Un solo vigilante para toda la página: llena los marcadores que
     escribe el HTML y, pasados seis segundos, los pasa a error. Si los
     datos llegan después, la propia página reescribe el bloque.

     Seis y no dos: en la pista, al aire libre, la cobertura va justa y a
     los dos segundos saltaba el aviso aunque todo fuera bien. Un aviso
     que se equivoca a diario enseña a no hacer caso de los avisos. */
  setInterval(function () {
    var l = document.querySelectorAll('.ap-esq');
    if (!l.length) return;
    var ahora = Date.now();
    for (var i = 0; i < l.length; i++) {
      var e = l[i];
      /* Mientras la pantalla está oculta (esperando a la sesión) el reloj no
         corre: si no, el esqueleto pasaría a error sin haberse llegado a ver. */
      if (e.offsetParent === null) { e.removeAttribute('data-t'); continue; }
      if (!e.getAttribute('data-t')) { llenar(e); continue; }
      if (ahora - (+e.getAttribute('data-t')) > 6000) {
        var caja = document.createElement('div');
        caja.innerHTML = window.APOLANA_UI.error('Está tardando más de lo normal',
          'Puede ser tu conexión. Si no aparece en unos segundos, vuelve a intentarlo.');
        if (e.parentNode) e.parentNode.replaceChild(caja.firstChild, e);
      }
    }
  }, 400);

  document.addEventListener('click', function (ev) {
    var b = ev.target && ev.target.closest ? ev.target.closest('.ap-reintentar') : null;
    if (b) location.reload();
  });

  /* ============================================================
     ICONOGRAFÍA · kit 30a
     Lienzo 24×24, trazo único de 1,9 px, puntas y uniones
     redondas, sin relleno. Excepciones macizas: los tres puntos
     de «Más» y el punto del aviso. El visto de confirmación va a
     2,4 px porque a 1,9 se pierde.
     ============================================================ */
  var TRAZOS = {
    inicio:  '<path d="M3 10.5L12 3l9 7.5"/><path d="M5.5 9.5V20h13V9.5"/>',
    entreno: '<circle cx="15.5" cy="4.8" r="2"/><path d="M7 21l3-5.5 3.5-2.5-1-4.5-4 2-1.5 3"/><path d="M13.5 13l3.5 2 1.5 4"/>',
    calendario: '<rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/>',
    marcas:  '<path d="M4 19V9M10 19V5M16 19v-7M22 19H2"/>',
    natacion: '<path d="M3 15c2-1.5 3.5-1.5 5.5 0s3.5 1.5 5.5 0 3.5-1.5 5.5 0"/><path d="M3 19c2-1.5 3.5-1.5 5.5 0s3.5 1.5 5.5 0 3.5-1.5 5.5 0"/><circle cx="16" cy="6.5" r="2"/><path d="M5 11l4-2 4.5 1.5"/>',
    pista:   '<ellipse cx="12" cy="12" rx="9" ry="6"/><ellipse cx="12" cy="12" rx="4" ry="2.2"/>',
    montana: '<path d="M3 18l5.5-8 3.5 4.5 2.5-3L21 18H3z"/><circle cx="17.5" cy="6.5" r="1.6"/>',
    triatlon: '<circle cx="6" cy="17" r="3.4"/><circle cx="18" cy="17" r="3.4"/><path d="M6 17l4-8h5l3 8"/><path d="M9 9h5"/>',
    cubo:    '<path d="M4 9v6M20 9v6M7 7v10M17 7v10M7 12h10"/>',
    escuela: '<circle cx="12" cy="6" r="2.6"/><path d="M12 8.6V15M8 11l4-1.4 4 1.4M9.5 21l2.5-6 2.5 6"/>',
    aviso:   '<circle cx="12" cy="12" r="8.6"/><path d="M12 8v4.5"/><circle cx="12" cy="16" r="1.2" fill="currentColor" stroke="none"/>',
    copiar:  '<rect x="8" y="8" width="12" height="13" rx="2.5"/><path d="M16 5.5H6.5A2.5 2.5 0 004 8v9.5"/>',
    buscar:  '<circle cx="11" cy="11" r="6.6"/><path d="M16 16l4.5 4.5"/>',
    filtrar: '<path d="M4 6.5h16M7 12h10M10 17.5h4"/>',
    descargar: '<path d="M12 4v11M7.5 10.5L12 15l4.5-4.5M5 19.5h14"/>',
    mensaje: '<path d="M4 20l1.3-3.9A8 8 0 1120 12a8 8 0 01-12.1 6.9L4 20z"/>',
    entrar:  '<path d="M9 6l6 6-6 6"/>'
  };
  function icono(nombre, tam) {
    var t = tam || 24;
    if (nombre === 'mas') {
      return '<svg class="ic" width="' + t + '" height="' + t + '" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' +
             '<circle cx="5" cy="12" r="1.9"/><circle cx="12" cy="12" r="1.9"/><circle cx="19" cy="12" r="1.9"/></svg>';
    }
    if (nombre === 'hecho') {
      return '<svg class="ic" width="' + t + '" height="' + t + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
             'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>';
    }
    return '<svg class="ic" width="' + t + '" height="' + t + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
           'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
           (TRAZOS[nombre] || '') + '</svg>';
  }
  window.APOLANA_UI.icono = icono;

  /* ============================================================
     AVISO UNIFICADO · kit 30g
     Uno solo para todo el portal: fondo navy siempre, radio 14.
     · confirmación — visto blanco, se va a los 4 s, con «Deshacer»
     · error        — icono ámbar, se queda hasta que se toca,
                      con «Reintentar». El bloque NO cambia de color
     Uno a la vez, abajo, 16 px por encima de la barra de pestañas.
     Se define aquí para que las copias sueltas de las páginas
     (que empiezan con «if (window.APX) return;») se aparten.
     ============================================================ */
  var apxCss = document.createElement('style');
  apxCss.textContent =
    '.apx-host{position:fixed;left:0;right:0;bottom:16px;z-index:9999;display:flex;justify-content:center;' +
      'pointer-events:none;padding:0 14px}' +
    '@media(min-width:761px){.apx-host{justify-content:flex-start;padding-left:24px}}' +
    '.apx-toast{pointer-events:auto;display:flex;align-items:center;gap:13px;max-width:460px;' +
      'background:var(--navy,#2E4256);color:#fff;font-family:var(--fuente-texto,system-ui);border-radius:14px;' +
      'padding:14px 16px;box-shadow:0 16px 34px -18px rgba(46,66,86,.7);opacity:0;transform:translateY(10px);' +
      'transition:opacity .25s,transform .25s}' +
    '.apx-toast.apx-in{opacity:1;transform:none}' +
    '.apx-toast .apx-ic{flex:0 0 22px;width:22px;height:22px}' +
    '.apx-toast.apx-error .apx-ic{color:#F0B968}' +
    '.apx-toast .apx-txt{flex:1;min-width:0;display:flex;flex-direction:column;gap:1px}' +
    '.apx-toast .apx-txt b{font-size:15px;font-weight:400;line-height:1.4}' +
    '.apx-toast .apx-txt small{font-size:14px;line-height:1.4;color:rgba(255,255,255,.7)}' +
    '.apx-toast .apx-acc{flex:0 0 auto;background:none;border:0;font-family:inherit;font-size:14px;' +
      'font-weight:600;color:#8FC0E8;cursor:pointer;padding:6px 2px;min-height:32px}' +
    /* diálogo de confirmar */
    '.apx-ov{position:fixed;inset:0;z-index:10000;background:rgba(30,42,56,.5);display:flex;align-items:center;' +
      'justify-content:center;padding:18px;opacity:0;transition:opacity .2s}' +
    '.apx-ov.apx-in{opacity:1}' +
    '.apx-dlg{background:var(--crema,#FBF9F4);border:1px solid var(--linea,#EAE3D5);border-radius:14px;' +
      'box-shadow:0 34px 60px -30px rgba(46,66,86,.6);max-width:400px;width:100%;padding:22px 22px 18px;' +
      'transform:translateY(8px) scale(.98);transition:transform .2s}' +
    '.apx-ov.apx-in .apx-dlg{transform:none}' +
    '.apx-dlg-msg{margin:0 0 18px;font-family:var(--fuente-texto,system-ui);font-size:15px;line-height:1.5;color:var(--texto,#4A4437)}' +
    '.apx-dlg-btns{display:flex;gap:10px;justify-content:flex-end;flex-wrap:wrap}' +
    '.apx-btn{display:inline-flex;align-items:center;justify-content:center;font-family:var(--fuente-texto,system-ui);' +
      'font-size:15px;font-weight:600;padding:11px 22px;border-radius:999px;border:1px solid #C9C0AE;background:#fff;' +
      'color:var(--navy,#2E4256);cursor:pointer;min-height:44px}' +
    '.apx-btn:hover{border-color:#C9D9E7}' +
    '.apx-btn.apx-ok{background:var(--azul,#2F6FA8);border-color:var(--azul,#2F6FA8);color:#fff}' +
    /* el hover tiene que ser MÁS oscuro que el botón: --azul-oscuro vale
       ahora lo mismo que --azul, así que el hover no se notaría */
    '.apx-btn.apx-ok:hover{background:var(--azul-hover,#1E4E78)}' +
    '.apx-btn.apx-danger{background:#B0563A;border-color:#B0563A;color:#fff}' +
    '.apx-btn.apx-danger:hover{background:#8f4229}' +
    '@media(max-width:420px){.apx-dlg-btns{flex-direction:column-reverse}.apx-btn{width:100%}}';
  (document.head || document.documentElement).appendChild(apxCss);

  var apxHost = null, apxVivo = null, apxReloj = null;
  function apxSitio() {
    if (!apxHost) { apxHost = document.createElement('div'); apxHost.className = 'apx-host'; document.body.appendChild(apxHost); }
    /* 16 px por encima de la barra de pestañas, sea la común o la de la zona */
    var bar = document.querySelector('.pt-tabbar,.tabbar');
    var alto = 0;
    try { if (bar && getComputedStyle(bar).display !== 'none') alto = bar.offsetHeight; } catch (e) {}
    apxHost.style.bottom = (16 + alto) + 'px';
    return apxHost;
  }
  function apxQuitar(yaMismo) {
    if (apxReloj) { clearTimeout(apxReloj); apxReloj = null; }
    var el = apxVivo; apxVivo = null;
    if (!el) return;
    /* Al sustituirlo por otro se retira de golpe: nunca dos a la vez en pantalla */
    if (yaMismo === true) { if (el.parentNode) el.parentNode.removeChild(el); return; }
    el.classList.remove('apx-in');
    setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 300);
  }
  /* toast(mensaje, tipo, opciones)
     tipo: 'error' se queda hasta que se toca; cualquier otro se va a los 4 s.
     opciones: { detalle, accion:{texto,fn} }                              */
  function toast(msg, tipo, opts) {
    opts = opts || {};
    apxQuitar(true);                           /* uno a la vez: el nuevo sustituye */
    var esError = (tipo === 'error');
    var el = document.createElement('div');
    el.className = 'apx-toast' + (esError ? ' apx-error' : '');
    el.setAttribute('role', esError ? 'alert' : 'status');
    var accTxt = (opts.accion && opts.accion.texto) || (esError ? 'Reintentar' : (opts.deshacer ? 'Deshacer' : ''));
    el.innerHTML =
      '<span class="apx-ic">' + icono(esError ? 'aviso' : 'hecho', 22) + '</span>' +
      '<span class="apx-txt"><b>' + esc(msg) + '</b>' +
        (opts.detalle ? '<small>' + esc(opts.detalle) + '</small>' : '') + '</span>' +
      (accTxt ? '<button type="button" class="apx-acc">' + esc(accTxt) + '</button>' : '');
    apxSitio().appendChild(el);
    apxVivo = el;
    requestAnimationFrame(function () { el.classList.add('apx-in'); });
    var acc = el.querySelector('.apx-acc');
    if (acc) {
      acc.addEventListener('click', function () {
        var f = (opts.accion && opts.accion.fn) || opts.deshacer || (esError ? function () { location.reload(); } : null);
        apxQuitar();
        if (f) f();
      });
    }
    if (esError) { el.addEventListener('click', function (e) { if (e.target === el) apxQuitar(); }); }
    else { apxReloj = setTimeout(apxQuitar, 4000); }
    return el;
  }
  function confirmar(msg, opts) {
    opts = opts || {};
    return new Promise(function (resolve) {
      var ov = document.createElement('div'); ov.className = 'apx-ov';
      var dlg = document.createElement('div'); dlg.className = 'apx-dlg';
      dlg.setAttribute('role', 'dialog'); dlg.setAttribute('aria-modal', 'true');
      var p = document.createElement('p'); p.className = 'apx-dlg-msg'; p.textContent = msg; dlg.appendChild(p);
      var btns = document.createElement('div'); btns.className = 'apx-dlg-btns';
      var bc = document.createElement('button'); bc.type = 'button'; bc.className = 'apx-btn'; bc.textContent = opts.cancelar || 'Cancelar';
      var bo = document.createElement('button'); bo.type = 'button'; bo.className = 'apx-btn apx-ok'; bo.textContent = opts.aceptar || 'Aceptar';
      if (opts.peligro) { bo.classList.remove('apx-ok'); bo.classList.add('apx-danger'); }
      btns.appendChild(bc); btns.appendChild(bo); dlg.appendChild(btns); ov.appendChild(dlg);
      document.body.appendChild(ov);
      requestAnimationFrame(function () { ov.classList.add('apx-in'); });
      function cerrar(v) {
        ov.classList.remove('apx-in');
        document.removeEventListener('keydown', onkey);
        setTimeout(function () { if (ov.parentNode) ov.parentNode.removeChild(ov); }, 200);
        resolve(v);
      }
      function onkey(e) {
        if (e.key === 'Escape') { e.preventDefault(); cerrar(false); }
        else if (e.key === 'Enter') { e.preventDefault(); cerrar(true); }
      }
      bc.addEventListener('click', function () { cerrar(false); });
      bo.addEventListener('click', function () { cerrar(true); });
      ov.addEventListener('click', function (e) { if (e.target === ov) cerrar(false); });
      document.addEventListener('keydown', onkey);
      setTimeout(function () { bo.focus(); }, 40);
    });
  }
  window.APX = { toast: toast, confirm: confirmar, quitar: apxQuitar };

  document.addEventListener('DOMContentLoaded', function () {
    var sb = window.APOLANA_DB;
    var cont = document.getElementById('portal-contenido');
    if (cont) cont.style.display = 'none';

    var b = base();
    var login = document.createElement('div');
    login.className = 'pt-login';
    login.style.display = 'none';
    login.innerHTML =
      '<img class="pt-logo" src="' + b + 'assets/img/logo.png" alt="Club Apolana">' +
      '<h1>Club Apolana</h1>' +
      '<p class="lema">Entra con tu cuenta o mira el club sin registrarte.</p>' +
      '<form id="pt-form">' +
        '<label for="pt-email">Email</label>' +
        '<input type="email" id="pt-email" autocomplete="username" required>' +
        '<label for="pt-pass">Contraseña</label>' +
        '<input type="password" id="pt-pass" autocomplete="current-password" required>' +
        '<div style="margin-top:16px"><button class="btn btn--primario" type="submit" style="width:100%">Entrar</button></div>' +
        '<button type="button" class="pt-olvido" id="pt-olvido">He olvidado la contraseña</button>' +
        '<div class="msg" id="pt-msg"></div>' +
      '</form>' +
      '<div class="pt-sep"><i></i><span>o sin cuenta</span><i></i></div>' +
      '<div class="pt-publico">' +
        '<a href="' + b + 'noticias/"><b>Noticias y calendario del club</b><i>&rsaquo;</i></a>' +
        '<a href="' + b + '"><b>Grupos, horarios y precios</b><i>&rsaquo;</i></a>' +
        '<a href="' + b + 'competicion/"><b>Probar cuatro entrenamientos</b><i>&rsaquo;</i></a>' +
        '<a href="' + b + 'app/"><b>Instalar como app en el móvil</b><i>&rsaquo;</i></a>' +
      '</div>' +
      '<div class="pt-pie">' +
        '<span>¿Aún no estás en el club?</span>' +
        '<a href="' + b + 'inscripcion/">Inscribirme</a>' +
      '</div>';
    document.body.insertBefore(login, document.body.firstChild);

    function barra(perfil, email) {
      /* Nunca dos barras: si ya hay una pintada, no se pinta otra. Esto
         evita el «barra, franja, barra» que salía al entrar en algunas
         pantallas (la función se llamaba más de una vez). */
      if (document.querySelector('.pt-top')) { montarPapeles(); return; }
      var nombre = (perfil && perfil.nombre) ? perfil.nombre : email;
      var top = document.createElement('div');
      top.className = 'pt-top';
      top.innerHTML =
        '<div class="izq">' +
          '<a class="marca" href="' + b + 'portal/">Portal Apolana</a>' +
        '</div>' +
        '<div class="der">' +
          '<button id="pt-cambiar" style="display:none">Cambiar de perfil</button>' +
          '<span>' + esc(nombre) + '</span>' +
          '<a class="aweb" href="' + b + '">Ir a la web</a>' +
          '<button id="pt-salir">Salir</button>' +
        '</div>';
      document.body.insertBefore(top, document.body.firstChild);
      document.getElementById('pt-salir').addEventListener('click', async function () {
        await sb.auth.signOut(); location.reload();
      });
      /* La franja «Estás como …», pegada arriba de todo y sin cerrar. */
      montarPapeles();
    }

    function mostrarLogin(m) { login.style.display = ''; if (m) { var e = document.getElementById('pt-msg'); if (e) e.textContent = m; } }

    if (!sb || !sb.auth) { mostrarLogin('No se pudo conectar con la base de datos.'); return; }

    document.getElementById('pt-form').addEventListener('submit', async function (e) {
      e.preventDefault();
      var msg = document.getElementById('pt-msg');
      msg.className = 'msg';
      msg.textContent = 'Entrando…';
      var r = await sb.auth.signInWithPassword({
        email: document.getElementById('pt-email').value.trim(),
        password: document.getElementById('pt-pass').value
      });
      if (r.error) { msg.textContent = 'No se pudo entrar: ' + r.error.message; return; }
      /* «Al entrar, abrir en»: si esa persona ha fijado un papel de
         arranque, se le pone ahora; si no, se queda con el último que
         usó. Si falla, se entra con el último y ya está. */
      try { await sb.rpc('rol_al_entrar_aplicar'); } catch (e) {}
      arranque();
    });

    document.getElementById('pt-olvido').addEventListener('click', async function () {
      var msg = document.getElementById('pt-msg');
      var em = document.getElementById('pt-email').value.trim();
      msg.className = 'msg';
      if (!em) { msg.textContent = 'Escribe tu correo arriba y vuelve a pulsar.'; return; }
      msg.textContent = 'Enviando…';
      try {
        var r = await sb.auth.resetPasswordForEmail(em);
        if (r && r.error) { msg.textContent = 'No se pudo enviar: ' + r.error.message; return; }
        msg.className = 'msg ok';
        msg.textContent = 'Te hemos enviado un correo para poner una contraseña nueva.';
      } catch (err) {
        msg.textContent = 'No se pudo enviar el correo. Inténtalo más tarde.';
      }
    });

    /* --------------------------------------------------------
       ZONAS DEL USUARIO
       Un correo = una cuenta = una fila en `perfiles`. La persona
       puede tener varios papeles concedidos (`perfiles.roles`) y
       actúa con uno cada vez (`perfiles.rol_activo`); además puede
       tener ficha de atleta (atletas.perfil_id), hijos
       (atletas.perfil_padre_id) o grupos a su cargo
       (grupos.entrenador_id), que se deducen de los datos que ella
       misma ya puede leer.

       ⚠️ Coordinación y administración se miran por el papel
       ACTIVO, no por el principal: si está probando el club como
       atleta, ofrecerle la puerta del panel sería mentirle — la
       base no le va a dejar entrar. Para volver está la banda de
       arriba, que en ese caso sale siempre (assets/js/papeles.js).
       -------------------------------------------------------- */
    var ZONAS = {
      entrenador:  { titulo: 'Entrenador',     desc: 'Tus grupos: planificar y leer el feedback.', url: b + 'portal/entrenador/',  carpeta: '/portal/entrenador/' },
      atleta:      { titulo: 'Atleta',         desc: 'Tus entrenamientos y tus marcas.',           url: b + 'portal/atleta/',      carpeta: '/portal/atleta/' },
      familia:     { titulo: 'Familia',        desc: 'Ficha de tus hijos, faltas y pagos.',        url: b + 'portal/familia/',     carpeta: '/portal/familia/' },
      coordinador: { titulo: 'Coordinación',   desc: 'Los grupos de tu sección.',                  url: b + 'portal/coordinador/', carpeta: '/portal/coordinador/' },
      admin:       { titulo: 'Administración', desc: 'Cobros, contenido web y usuarios.',          url: b + 'admin/',              carpeta: '/admin/' }
    };

    async function calcularPapeles(perfil) {
      var lista = [];
      if (!perfil || !perfil.id) return lista;
      var id = perfil.id;
      /* El papel con el que está actuando ahora mismo. Si no ha
         elegido ninguno, el suyo de siempre. */
      var rol = perfil.rol_activo || perfil.rol || '';
      var esAtleta = (rol === 'atleta');
      var esFamilia = (rol === 'padre');
      var esEntrenador = (rol === 'entrenador');
      var hijos = [];

      try {
        var r = await sb.from('atletas')
          .select('id,nombre,apellidos,perfil_id,perfil_padre_id,entrenador_id')
          .or('perfil_id.eq.' + id + ',perfil_padre_id.eq.' + id + ',entrenador_id.eq.' + id);
        if (r && !r.error && r.data) {
          r.data.forEach(function (a) {
            if (a.perfil_id === id) esAtleta = true;
            if (a.perfil_padre_id === id) { esFamilia = true; if (a.nombre) hijos.push(a.nombre); }
            if (a.entrenador_id === id) esEntrenador = true;
          });
        }
      } catch (e) { /* sin permisos: se queda con el rol del perfil */ }

      try {
        var g = await sb.from('grupos').select('id').eq('entrenador_id', id);
        if (g && !g.error && g.data && g.data.length) esEntrenador = true;
      } catch (e) { /* grupos es de lectura pública; si falla, da igual */ }

      /* Quien lleva varios papeles actúa con UNO cada vez, y el activo manda
         también aquí. Los datos de arriba dicen qué papeles PODRÍA usar esta
         persona (tiene ficha, tiene hijos, lleva grupos); no dicen en cuál
         está ahora. Sin este filtro, quien lleva grupos veía la zona del
         entrenador —con «Pasar lista» y los borradores de sus sesiones—
         mientras la franja de arriba decía «Estás como atleta».
         La base ya lo hacía bien: `es_admin()` y `es_staff()` miran
         `coalesce(rol_activo, rol)`. Esto es lo mismo, en la pantalla.
         Con un solo papel concedido no hay nada que elegir: mandan los datos. */
      var concedidos = (perfil.roles && perfil.roles.length) ? perfil.roles : [];
      if (concedidos.length > 1) {
        esAtleta     = esAtleta     && (rol === 'atleta');
        esFamilia    = esFamilia    && (rol === 'padre');
        esEntrenador = esEntrenador && (rol === 'entrenador');
      }

      function anadir(clave, desc) {
        var z = ZONAS[clave];
        if (!z) return;
        lista.push({ clave: clave, titulo: z.titulo, desc: desc || z.desc, url: z.url, carpeta: z.carpeta });
      }
      if (esEntrenador) anadir('entrenador');
      if (esAtleta) anadir('atleta');
      if (esFamilia) anadir('familia', hijos.length ? hijos.join(', ') : null);
      if (rol === 'coordinador') anadir('coordinador');
      /* Administración, tesorería, contabilidad y junta entran por la
         misma puerta: el panel. Lo que ven dentro lo deciden las reglas
         de la base, no esta lista. */
      if (rol === 'admin' || rol === 'tesoreria' || rol === 'contabilidad' || rol === 'junta') anadir('admin');
      return lista;
    }

    function papelActivo(lista) {
      var ruta = location.pathname;
      for (var i = 0; i < lista.length; i++) {
        if (ruta.indexOf(lista[i].carpeta) !== -1) return lista[i].clave;
      }
      return null;
    }

    function iniciales(perfil, email) {
      var n = (perfil && perfil.nombre) ? perfil.nombre : (email || '');
      var a = (perfil && perfil.apellidos) ? perfil.apellidos : '';
      var x = (n.charAt(0) || '') + (a.charAt(0) || '');
      return (x || n.substring(0, 2)).toUpperCase();
    }

    function abrirHoja(lista, perfil, email) {
      var activo = papelActivo(lista);
      var ini = iniciales(perfil, email);
      var hoja = document.createElement('div');
      hoja.className = 'pt-hoja';
      var filas = lista.map(function (p) {
        var act = (p.clave === activo);
        return '<a class="fila' + (act ? ' activa' : '') + '" href="' + p.url + '">' +
               '<span class="ini">' + esc(ini) + '</span>' +
               '<span class="txt"><b>' + esc(p.titulo) + '</b><small>' + esc(p.desc) + '</small></span>' +
               '<span class="chev">' + (act ? '✓' : '&rsaquo;') + '</span></a>';
      }).join('');
      hoja.innerHTML =
        '<div class="caja">' +
          '<div class="cab"><h2>Cambiar de perfil</h2><button class="cerrar" id="pt-hoja-cerrar">Cerrar</button></div>' +
          filas +
          '<p class="nota">Cambias de panel sin cerrar sesión: es la misma cuenta.</p>' +
          '<div class="acciones">' +
            '<button id="pt-hoja-pass">Cambiar contraseña</button>' +
            '<button id="pt-hoja-salir">Cerrar sesión</button>' +
          '</div>' +
          '<p class="nota" id="pt-hoja-msg"></p>' +
        '</div>';
      document.body.appendChild(hoja);

      function cerrar() { if (hoja.parentNode) hoja.parentNode.removeChild(hoja); }
      hoja.addEventListener('click', function (ev) { if (ev.target === hoja) cerrar(); });
      document.getElementById('pt-hoja-cerrar').addEventListener('click', cerrar);
      document.getElementById('pt-hoja-salir').addEventListener('click', async function () {
        await sb.auth.signOut(); location.reload();
      });
      document.getElementById('pt-hoja-pass').addEventListener('click', async function () {
        var m = document.getElementById('pt-hoja-msg');
        m.textContent = 'Enviando…';
        try {
          var r = await sb.auth.resetPasswordForEmail(email);
          m.textContent = (r && r.error)
            ? 'No se pudo enviar: ' + r.error.message
            : 'Te hemos enviado un correo a ' + email + ' para poner una contraseña nueva.';
        } catch (e) { m.textContent = 'No se pudo enviar el correo.'; }
      });
    }

    async function arranque() {
      var s = await sb.auth.getSession();
      if (!s.data.session) { mostrarLogin(); return; }
      var email = s.data.session.user.email;
      var perfil = null;
      try {
        var r = await sb.from('perfiles')
          .select('id,nombre,apellidos,email,rol,roles,rol_activo,seccion')
          .eq('email', email).maybeSingle();
        if (!r.error) perfil = r.data;
      } catch (e) { /* si aún no hay permisos de lectura, perfil queda null */ }
      login.style.display = 'none';
      barra(perfil, email);
      if (cont) cont.style.display = '';

      /* Los papeles se calculan en paralelo: la promesa está disponible
         desde el primer momento, pero no retrasa el pintado de la página. */
      _papeles = calcularPapeles(perfil);
      window.APOLANA_PORTAL.papeles = function () { return _papeles; };

      if (_cb) _cb(sb, perfil);

      _papeles.then(function (lista) {
        lista = lista || [];
        /* Guardia de zona: si has acabado en la zona de un rol que no es tuyo
           (p. ej. una página de entrenador que quedó cacheada en la app y luego
           entras con otra cuenta), te devuelve al portal para que veas la tuya.
           Se comprueba SIEMPRE, aunque no se hayan podido deducir papeles (lista
           vacía): así nadie se queda atrapado en una zona ajena. Excepción: el
           admin puede ver cualquier zona. Nunca redirige desde /portal/ ni desde
           /admin/, para no crear bucles de redirección. */
        var claves = lista.map(function (p) { return p.clave; });
        var ruta = location.pathname;
        if (claves.indexOf('admin') === -1 && ruta.indexOf('/admin/') === -1) {
          for (var k in ZONAS) {
            if (!ZONAS.hasOwnProperty(k) || k === 'admin') continue;
            if (ruta.indexOf(ZONAS[k].carpeta) !== -1 && claves.indexOf(k) === -1) {
              location.replace(b + 'portal/');
              return;
            }
          }
        }
        if (lista.length < 2) return;
        var bt = document.getElementById('pt-cambiar');
        if (!bt) return;
        bt.style.display = '';
        bt.addEventListener('click', function () { abrirHoja(lista, perfil, email); });
      });
    }

    arranque();
  });
})();
