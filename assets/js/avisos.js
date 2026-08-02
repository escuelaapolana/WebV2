/* ============================================================
   AVISOS AL MÓVIL · Club Atletismo Apolana
   ------------------------------------------------------------
   Este módulo es lo que hace que a la gente le llegue un aviso al
   móvil cuando mañana no hay entreno, cuando sale una convocatoria
   o cuando le vuelve un recibo. No pinta pantallas por su cuenta:
   ofrece las piezas para que cualquier página las use.

   CÓMO SE USA (desde cualquier página del portal o de la app):

     <script src="../assets/js/avisos.js" defer></script>

     APOLANA_AVISOS.montar(document.getElementById('caja-avisos'));

   `montar()` mira si este aparato puede recibir avisos y, según el
   caso, pinta el botón «Avisarme», el de «Dejar de recibir avisos»,
   o una explicación honesta de por qué aquí no se puede. **Si el
   sistema todavía no está encendido, no pinta absolutamente nada**:
   nunca hay un botón que no funcione.

   TRES REGLAS QUE NO SE SALTAN
   ---------------------------------------------------------------
   1) EL PERMISO NO SE PIDE AL ENTRAR. Nunca. El navegador solo
      deja pedirlo una vez: si sale de golpe nada más abrir, la
      gente le da a «Bloquear» por reflejo y ya no hay vuelta atrás
      (hay que ir a los ajustes del móvil a mano). Por eso siempre
      hay que pulsar un botón «Avisarme» primero.
   2) AQUÍ NO HAY NINGUNA CLAVE. La clave pública la da la base de
      datos (`avisos_clave_publica()`), donde la pega el club una
      sola vez. Este archivo no la lleva escrita y no puede llevarla.
   3) EN IPHONE Y IPAD SOLO FUNCIONA CON LA APP INSTALADA en la
      pantalla de inicio. Es una limitación de Apple, no del club:
      Safari a secas no recibe avisos por mucho permiso que se dé.
      Cuando es el caso, se explica y se dice cómo instalarla.

   Necesita que se hayan cargado antes supabase-js y db.js.
   ============================================================ */
(function () {
  'use strict';

  /* ---------------------------------------------------------------
     Los cinco interruptores, en cristiano.
     Deben coincidir con las columnas de `avisos_preferencias`
     (migración 054). Todos encendidos de fábrica menos las noticias.
     --------------------------------------------------------------- */
  var TIPOS = [
    { clave: 'entrenos',      titulo: 'Entrenos',              texto: 'Cambios de última hora: lluvia, pista cerrada, cambio de sitio.', defecto: true },
    { clave: 'competiciones', titulo: 'Competiciones',         texto: 'Convocatorias, horarios de la carrera y cierres de inscripción.',  defecto: true },
    { clave: 'pagos',         titulo: 'Pagos y recibos',       texto: 'Un recibo devuelto o algo pendiente de pagar.',                    defecto: true },
    { clave: 'noticias',      titulo: 'Noticias del club',     texto: 'Lo que se publica en la web. No son urgentes.',                    defecto: false },
    { clave: 'retos',         titulo: 'Retos y logros',        texto: 'Cuando consigues una medalla o se abre un reto nuevo.',            defecto: true }
  ];

  var sb = null;
  var cacheClave = undefined;   /* undefined = sin preguntar; null = apagado */

  function db() {
    if (!sb) sb = window.APOLANA_DB || null;
    return sb;
  }

  /* ---------------------------------------------------------------
     ¿Qué aparato es este?
     --------------------------------------------------------------- */
  function esApple() {
    try {
      var ua = navigator.userAgent || '';
      if (/iPad|iPhone|iPod/.test(ua)) return true;
      /* El iPad moderno se hace pasar por un Mac: se le pilla porque
         un Mac de verdad no tiene pantalla táctil. */
      return navigator.platform === 'MacIntel' && (navigator.maxTouchPoints || 0) > 1;
    } catch (e) { return false; }
  }

  function esAppInstalada() {
    try {
      return window.navigator.standalone === true ||
        (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);
    } catch (e) { return false; }
  }

  /* Nombre corto y reconocible para que la persona sepa cuál es cuál
     en su lista de aparatos. Nada de pegar el «user agent» entero. */
  function nombreAparato() {
    var ua = navigator.userAgent || '';
    var sistema =
      /iPhone/.test(ua) ? 'iPhone' :
      /iPad/.test(ua) || (navigator.platform === 'MacIntel' && (navigator.maxTouchPoints || 0) > 1) ? 'iPad' :
      /Android/.test(ua) ? 'Android' :
      /Macintosh|Mac OS X/.test(ua) ? 'Mac' :
      /Windows/.test(ua) ? 'Windows' :
      /Linux/.test(ua) ? 'Linux' : 'Este aparato';
    if (esAppInstalada()) return sistema + ' · app instalada';
    var navegador =
      /EdgA?\//.test(ua) ? 'Edge' :
      /OPR\//.test(ua) ? 'Opera' :
      /Firefox\//.test(ua) ? 'Firefox' :
      /Chrome\//.test(ua) ? 'Chrome' :
      /Safari\//.test(ua) ? 'Safari' : 'navegador';
    return sistema + ' · ' + navegador;
  }

  /* ---------------------------------------------------------------
     La clave pública (VAPID). Sale de la base de datos, donde la
     pega el club una vez. Si el sistema está apagado, la función
     devuelve vacío y aquí nos callamos.
     --------------------------------------------------------------- */
  async function clavePublica() {
    if (cacheClave !== undefined) return cacheClave;
    /* Puerta de atrás por si algún día se prefiere ponerla en una
       variable de la página en vez de en la base. Sigue sin estar
       escrita en el repositorio. */
    if (window.APOLANA_VAPID_PUBLICA) {
      cacheClave = String(window.APOLANA_VAPID_PUBLICA).trim() || null;
      return cacheClave;
    }
    try {
      var r = await db().rpc('avisos_clave_publica');
      cacheClave = (r && !r.error && r.data) ? String(r.data).trim() : null;
    } catch (e) { cacheClave = null; }
    return cacheClave;
  }

  /* La clave viaja en base64 «de direcciones» y el navegador la pide
     en bytes. Esta es la traducción de toda la vida. */
  function claveABytes(base64) {
    var relleno = '='.repeat((4 - base64.length % 4) % 4);
    var limpia = (base64 + relleno).replace(/-/g, '+').replace(/_/g, '/');
    var crudo = window.atob(limpia);
    var bytes = new Uint8Array(crudo.length);
    for (var i = 0; i < crudo.length; i++) bytes[i] = crudo.charCodeAt(i);
    return bytes;
  }

  function aBase64(buffer) {
    var bytes = new Uint8Array(buffer), s = '';
    for (var i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    return window.btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  /* ---------------------------------------------------------------
     EN QUÉ SITUACIÓN ESTAMOS
     Devuelve siempre lo mismo: { puede, motivo, activo, texto }.
       'apagado'     → el club todavía no lo ha encendido
       'sin-sesion'  → hay que entrar en la cuenta
       'sin-soporte' → este navegador no sabe hacerlo
       'instalar'    → iPhone/iPad sin la app instalada
       'bloqueado'   → dijo que no y hay que ir a los ajustes
       'listo'       → se puede activar (falta pulsar el botón)
       'activo'      → ya le llegan avisos a este aparato
     --------------------------------------------------------------- */
  async function estado() {
    function no(motivo, texto) { return { puede: false, activo: false, motivo: motivo, texto: texto }; }

    if (!db() || !db().auth) return no('apagado', '');

    var clave = await clavePublica();
    if (!clave) {
      /* Apagado: ni una palabra en pantalla. Que el club lo encienda
         cuando tenga sus claves (docs/avisos-al-movil.md). */
      return no('apagado', '');
    }

    if (!window.isSecureContext) {
      return no('sin-soporte', 'Los avisos solo funcionan con conexión segura (https).');
    }
    if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) {
      if (esApple() && !esAppInstalada()) {
        return no('instalar',
          'En iPhone y iPad los avisos solo llegan con la app instalada en la pantalla de inicio. ' +
          'Toca el botón de compartir de Safari y elige «Añadir a pantalla de inicio».');
      }
      return no('sin-soporte', 'Este navegador no sabe recibir avisos. Prueba con Chrome, Edge, Firefox o Safari al día.');
    }
    if (esApple() && !esAppInstalada()) {
      return no('instalar',
        'En iPhone y iPad los avisos solo llegan con la app instalada en la pantalla de inicio. ' +
        'Toca el botón de compartir de Safari y elige «Añadir a pantalla de inicio».');
    }

    var sesion = null;
    try { sesion = (await db().auth.getSession()).data.session; } catch (e) { sesion = null; }
    if (!sesion) return no('sin-sesion', 'Entra en tu cuenta y podrás activar los avisos.');

    if (Notification.permission === 'denied') {
      return no('bloqueado',
        'Los avisos están bloqueados para esta web. Se quita desde los ajustes del móvil o del navegador, ' +
        'en la ficha de esta página.');
    }

    /* ¿Ya está suscrito este aparato? */
    var sus = null;
    try {
      var reg = await navigator.serviceWorker.getRegistration();
      if (reg) sus = await reg.pushManager.getSubscription();
    } catch (e) { sus = null; }

    if (sus && Notification.permission === 'granted') {
      return { puede: true, activo: true, motivo: 'activo', texto: 'Te llegarán los avisos a ' + nombreAparato() + '.' };
    }
    return { puede: true, activo: false, motivo: 'listo', texto: 'Te avisaremos de lo que pase en el club. Puedes quitarlo cuando quieras.' };
  }

  /* ---------------------------------------------------------------
     ACTIVAR · esto SOLO se llama al pulsar un botón. Jamás al cargar.
     --------------------------------------------------------------- */
  async function activar() {
    var e = await estado();
    if (!e.puede) return { ok: false, motivo: e.motivo, mensaje: e.texto || 'Aquí no se pueden activar los avisos.' };
    if (e.activo) return { ok: true, yaEstaba: true };

    var clave = await clavePublica();
    if (!clave) return { ok: false, motivo: 'apagado', mensaje: 'Los avisos todavía no están activados.' };

    /* 1 · Pedir permiso. Aquí es donde sale la ventanita del sistema,
       y sale porque la persona acaba de pulsar «Avisarme». */
    var permiso;
    try { permiso = await Notification.requestPermission(); }
    catch (err) { permiso = 'default'; }

    if (permiso === 'denied') {
      return { ok: false, motivo: 'bloqueado',
        mensaje: 'Has dicho que no. Para cambiarlo hay que ir a los ajustes del móvil, en la ficha de esta web.' };
    }
    if (permiso !== 'granted') {
      return { ok: false, motivo: 'sin-permiso', mensaje: 'No se ha dado permiso, así que no te llegará nada.' };
    }

    /* 2 · Suscribirse. El «service worker» ya lo registra db.js. */
    var reg;
    try { reg = await navigator.serviceWorker.ready; }
    catch (err) { return { ok: false, motivo: 'error', mensaje: 'No hemos podido preparar los avisos en este aparato.' }; }

    var sus;
    try {
      sus = await reg.pushManager.getSubscription();
      if (!sus) {
        sus = await reg.pushManager.subscribe({
          userVisibleOnly: true,                    /* obligatorio: nada de avisos invisibles */
          applicationServerKey: claveABytes(clave)
        });
      }
    } catch (err) {
      return { ok: false, motivo: 'error',
        mensaje: 'El navegador no ha podido suscribirse. Prueba a cerrar y abrir la app.' };
    }

    /* 3 · Guardarla. Si falla, se deshace la suscripción para no
       dejar un aparato suscrito del que el club no sabe nada. */
    var guardada = await guardar(sus);
    if (!guardada.ok) {
      try { await sus.unsubscribe(); } catch (err) { /* da igual */ }
      return guardada;
    }
    return { ok: true, mensaje: 'Listo. Te avisaremos en ' + nombreAparato() + '.' };
  }

  async function guardar(sus) {
    var datos = sus.toJSON ? sus.toJSON() : null;
    var p256dh = (datos && datos.keys && datos.keys.p256dh) || aBase64(sus.getKey('p256dh'));
    var auth   = (datos && datos.keys && datos.keys.auth)   || aBase64(sus.getKey('auth'));

    var perfil;
    try {
      var r = await db().rpc('mi_perfil_id');
      perfil = (r && !r.error) ? r.data : null;
    } catch (e) { perfil = null; }
    if (!perfil) {
      return { ok: false, motivo: 'sin-ficha',
        mensaje: 'Tu cuenta todavía no está enlazada con una ficha del club. Escríbenos y lo arreglamos.' };
    }

    var fila = {
      perfil_id: perfil,
      endpoint: sus.endpoint,
      p256dh: p256dh,
      auth: auth,
      dispositivo: nombreAparato()
    };

    var res = await db().from('avisos_suscripciones').upsert(fila, { onConflict: 'endpoint' });
    if (!res.error) return { ok: true };

    /* Caso real: el móvil de casa donde antes entró otra persona. La
       dirección del buzón es del aparato, no de la cuenta, así que la
       fila ya existe a nombre de otro y las reglas —con razón— no
       dejan tocarla. Se tira esa suscripción y se pide una nueva. */
    try {
      await sus.unsubscribe();
      var reg = await navigator.serviceWorker.ready;
      var clave = await clavePublica();
      var otra = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: claveABytes(clave)
      });
      var d2 = otra.toJSON ? otra.toJSON() : null;
      var res2 = await db().from('avisos_suscripciones').upsert({
        perfil_id: perfil,
        endpoint: otra.endpoint,
        p256dh: (d2 && d2.keys && d2.keys.p256dh) || aBase64(otra.getKey('p256dh')),
        auth: (d2 && d2.keys && d2.keys.auth) || aBase64(otra.getKey('auth')),
        dispositivo: nombreAparato()
      }, { onConflict: 'endpoint' });
      if (!res2.error) return { ok: true };
    } catch (e) { /* seguimos al mensaje de abajo */ }

    return { ok: false, motivo: 'error', mensaje: 'No hemos podido guardar el aviso. Vuelve a intentarlo.' };
  }

  /* ---------------------------------------------------------------
     DARSE DE BAJA · en este aparato
     --------------------------------------------------------------- */
  async function desactivar() {
    try {
      var reg = await navigator.serviceWorker.getRegistration();
      var sus = reg ? await reg.pushManager.getSubscription() : null;
      if (sus) {
        /* Primero se borra de la base y después del navegador: si se
           hiciera al revés y fallara lo segundo, el club seguiría
           mandando avisos a un buzón que ya no escucha nadie. */
        await db().from('avisos_suscripciones').delete().eq('endpoint', sus.endpoint);
        await sus.unsubscribe();
      }
      return { ok: true, mensaje: 'Hecho. En este aparato ya no te llegarán avisos.' };
    } catch (e) {
      return { ok: false, motivo: 'error', mensaje: 'No hemos podido quitarlo. Vuelve a intentarlo.' };
    }
  }

  /* ---------------------------------------------------------------
     LOS INTERRUPTORES DE CADA UNO
     --------------------------------------------------------------- */
  async function preferencias() {
    var salida = {};
    TIPOS.forEach(function (t) { salida[t.clave] = t.defecto; });
    try {
      var r = await db().from('avisos_preferencias').select('*').maybeSingle();
      if (r && !r.error && r.data) {
        TIPOS.forEach(function (t) {
          if (typeof r.data[t.clave] === 'boolean') salida[t.clave] = r.data[t.clave];
        });
      }
    } catch (e) { /* sin fila: valen los de fábrica */ }
    return salida;
  }

  async function guardarPreferencias(valores) {
    var perfil;
    try {
      var r = await db().rpc('mi_perfil_id');
      perfil = (r && !r.error) ? r.data : null;
    } catch (e) { perfil = null; }
    if (!perfil) return { ok: false, mensaje: 'No hemos podido identificarte.' };

    var fila = { perfil_id: perfil };
    TIPOS.forEach(function (t) {
      if (valores && typeof valores[t.clave] === 'boolean') fila[t.clave] = valores[t.clave];
    });

    var res = await db().from('avisos_preferencias').upsert(fila, { onConflict: 'perfil_id' });
    if (res.error) return { ok: false, mensaje: 'No se ha podido guardar. Vuelve a intentarlo.' };
    return { ok: true };
  }

  /* ---------------------------------------------------------------
     LA PIEZA PARA LAS PANTALLAS
     Pinta en `caja` lo que corresponda. Con el sistema apagado no
     pinta NADA y devuelve false: así ninguna pantalla enseña un
     botón muerto.
     --------------------------------------------------------------- */
  var CSS_PUESTO = false;
  function ponerEstilos() {
    if (CSS_PUESTO) return;
    CSS_PUESTO = true;
    var s = document.createElement('style');
    s.setAttribute('data-avisos', 'apolana');
    s.textContent = [
      '.avs{border:1px solid var(--linea,#EFE9DC);border-radius:14px;background:#fff;padding:16px 18px}',
      '.avs h3{font-family:var(--fuente-titulo,inherit);text-transform:uppercase;font-size:21px;line-height:1.1;',
        'color:var(--navy,#2E4256);margin:0 0 4px}',
      '.avs p{font-size:15px;line-height:1.5;color:var(--texto-suave,#6E6656);margin:0 0 12px}',
      '.avs .avs-bot{display:inline-flex;align-items:center;justify-content:center;min-height:44px;',
        'padding:13px 22px;border-radius:999px;border:0;cursor:pointer;font-family:inherit;font-size:15px;',
        'background:var(--azul,#3B85C0);color:#fff}',
      '.avs .avs-bot:hover{background:var(--azul-hover,#1E4E78)}',
      '.avs .avs-bot[disabled]{opacity:.6;cursor:default}',
      '.avs .avs-bot--borde{background:#fff;color:var(--navy,#2E4256);border:1px solid #C9C0AE}',
      '.avs .avs-bot--borde:hover{background:var(--crema,#FBF9F4)}',
      '.avs .avs-nota{font-size:13px;color:var(--texto-suave,#6E6656);margin:10px 0 0;line-height:1.5}',
      '.avs--aviso{background:var(--ambar-fondo,#FDF3E3);border-color:var(--ambar-borde,#EBD9B8)}',
      '.avs--aviso h3{color:var(--ambar,#B96F09)}',
      '@media (max-width:520px){.avs .avs-bot{width:100%}}'
    ].join('');
    document.head.appendChild(s);
  }

  function esc(s) {
    var d = document.createElement('div');
    d.textContent = (s == null ? '' : String(s));
    return d.innerHTML;
  }

  async function montar(caja, opciones) {
    opciones = opciones || {};
    if (!caja) return false;

    var e = await estado();

    /* Apagado: silencio absoluto. Ni caja, ni botón, ni explicación. */
    if (e.motivo === 'apagado') { caja.innerHTML = ''; caja.style.display = 'none'; return false; }
    caja.style.display = '';
    ponerEstilos();

    /* Casos en los que aquí no se puede: se explica, sin botón. */
    if (!e.puede) {
      var esAviso = (e.motivo === 'bloqueado' || e.motivo === 'instalar');
      caja.innerHTML =
        '<div class="avs' + (esAviso ? ' avs--aviso' : '') + '">' +
          '<h3>' + (e.motivo === 'instalar' ? 'Instala la app para recibir avisos' : 'Avisos al móvil') + '</h3>' +
          '<p>' + esc(e.texto) + '</p>' +
        '</div>';
      return false;
    }

    var titulo = opciones.titulo || 'Avisos al móvil';
    caja.innerHTML =
      '<div class="avs">' +
        '<h3>' + esc(titulo) + '</h3>' +
        '<p>' + esc(e.texto) + '</p>' +
        '<button type="button" class="avs-bot' + (e.activo ? ' avs-bot--borde' : '') + '">' +
          (e.activo ? 'Dejar de recibir avisos' : 'Avisarme') +
        '</button>' +
        '<p class="avs-nota">' +
          (e.activo
            ? 'Puedes elegir de qué te avisamos y quitarlo cuando quieras.'
            : 'Te preguntará el móvil. Si dices que no, no te llegará nada y habrá que cambiarlo en los ajustes.') +
        '</p>' +
      '</div>';

    var boton = caja.querySelector('.avs-bot');
    boton.addEventListener('click', async function () {
      boton.disabled = true;
      var antes = boton.textContent;
      boton.textContent = e.activo ? 'Quitando…' : 'Un momento…';
      var r = e.activo ? await desactivar() : await activar();
      boton.disabled = false;
      boton.textContent = antes;

      if (typeof window.apoToast === 'function') {
        window.apoToast(r.mensaje || (r.ok ? 'Hecho.' : 'No ha podido ser.'), r.ok ? 'ok' : 'error');
      }
      if (typeof opciones.alCambiar === 'function') opciones.alCambiar(r);
      montar(caja, opciones);           /* se repinta con el estado nuevo */
    });

    return true;
  }

  window.APOLANA_AVISOS = {
    TIPOS: TIPOS,
    estado: estado,
    activar: activar,                   /* SOLO desde un clic */
    desactivar: desactivar,
    preferencias: preferencias,
    guardarPreferencias: guardarPreferencias,
    montar: montar,
    nombreAparato: nombreAparato
  };
})();
