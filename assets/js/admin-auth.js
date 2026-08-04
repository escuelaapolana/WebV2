/* ============================================================
   ACCESO COMPARTIDO DEL PANEL · Club Atletismo Apolana
   ------------------------------------------------------------
   Reutilizable por cualquier página de /admin/. Muestra un login
   si no hay sesión de administrador; cuando la hay, revela el
   contenido de la página (el elemento con id="admin-contenido")
   y llama a la función registrada con APOLANA_ADMIN.listo(cb).
   Requiere que se hayan cargado antes: supabase-js y db.js.
   ============================================================ */
(function () {
  var _cb = null;

  /* Pantallas del panel que son herramienta de campo y usa el equipo
     técnico, no solo administración. Pasar lista es la primera: un
     entrenador tiene que poder hacerlo desde el borde de la pista.
     Todo lo demás del panel sigue siendo solo de administración. */
  var DEL_EQUIPO = /\/admin\/campo\//;
  /* El Cubo tiene quien lo lleve sin ser administración del club: monta
     las clases, vende los bonos y apunta a la gente. Antes había que
     hacerle administrador para eso, y entonces veía los recibos de
     todas las familias y las notas de los críos. Ahora entra por aquí,
     y esta es la única pantalla que se le abre. */
  var DEL_CUBO = /\/admin\/cubo\//;
  window.APOLANA_ADMIN = { listo: function (cb) { _cb = cb; } };

  function base() { return window.APOLANA_BASE || '../../'; }
  function esc(s) { var d = document.createElement('div'); d.textContent = (s == null ? '' : String(s)); return d.innerHTML; }

  /* ------------------------------------------------------------
     EL INTERRUPTOR DE PAPELES
     Una persona del club puede llevar varios papeles a la vez
     («soy tesorero, admin, entrenador y atleta»). El interruptor
     para cambiar entre LOS SUYOS vive en assets/js/papeles.js y se
     trae aquí, en vez de meterle una etiqueta <script> a las 32
     pantallas del panel.

     Se carga después de pintar la barra, y nunca antes de saber
     que hay sesión: sin sesión no hay papeles que enseñar. Si el
     archivo no llega (sin conexión, caché vieja), no pasa nada:
     la página sigue funcionando exactamente igual que hoy.
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
    s.addEventListener('error', function () { /* sin interruptor, pero la página entera sigue viva */ });
    document.head.appendChild(s);
  }

  /* Título de la página para la barra: "Atletas · Panel Apolana" → "Atletas". */
  function tituloPagina() {
    var t = (document.title || '').split('·')[0].replace(/\s+$/, '').replace(/^\s+/, '');
    return t || 'Panel';
  }

  // CSS mínimo del login y la barra superior (para no depender de nada más)
  var css = document.createElement('style');
  css.textContent =
    'html,body{max-width:100%;overflow-x:hidden}' +
    /* --- Barra superior: misma altura, tipografía y colores que la del panel principal --- */
    '.adm-top{background:#2E4256;color:#fff;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:9px clamp(14px,4vw,40px);min-height:60px;flex-wrap:nowrap;width:100%;box-sizing:border-box}' +
    '.adm-top .izq{display:flex;align-items:center;gap:10px;min-width:0;overflow:hidden}' +
    '.adm-top a.volver{color:#cdd6e0;text-decoration:none;font-size:15px;display:inline-flex;align-items:center;gap:7px;flex:0 0 auto;padding:10px 12px;margin-left:-12px;border-radius:10px;min-height:44px;box-sizing:border-box}' +
    '.adm-top a.volver:hover{background:rgba(255,255,255,.12);color:#fff}' +
    '.adm-top a.volver i{font-style:normal;font-size:19px;line-height:1}' +
    '.adm-top .sep{color:rgba(255,255,255,.4);flex:0 0 auto}' +
    '.adm-top .marca{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:20px;line-height:1.15;color:#fff;white-space:nowrap;min-width:0;overflow:hidden;text-overflow:ellipsis}' +
    '.adm-top .der{display:flex;align-items:center;gap:12px;font-size:14px;color:#cdd6e0;min-width:0;flex:0 0 auto}' +
    '.adm-top .der span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:26vw}' +
    '.adm-top button{background:transparent;border:1px solid rgba(255,255,255,.4);color:#fff;border-radius:999px;padding:10px 18px;min-height:44px;font-size:14px;cursor:pointer;font-family:inherit;white-space:nowrap;flex:0 0 auto}' +
    '.adm-top button:hover{background:rgba(255,255,255,.12)}' +
    /* «Ir a la web» va a la derecha, junto a «Salir», y con menos peso que él:
       uno lleva a un sitio y el otro cierra la sesión. Mismo criterio que en
       el portal. En la esquina de arriba a la izquierda no va nunca: ahí el
       móvil pone el gesto de volver atrás y se pulsa sin mirar. */
    '.adm-top a.ir-web{flex:0 0 auto;display:inline-flex;align-items:center;min-height:44px;padding:10px 10px;border-radius:10px;color:rgba(255,255,255,.72);text-decoration:none;font-size:14px;white-space:nowrap}' +
    '.adm-top a.ir-web:hover{background:rgba(255,255,255,.12);color:#fff}' +
    /* El correo solo cabe bien en pantallas anchas; en móvil manda el título. */
    '@media(max-width:900px){.adm-top .der span{display:none}}' +
    '@media(max-width:560px){.adm-top{padding:8px 14px;gap:8px;min-height:56px}.adm-top .der{gap:4px}.adm-top a.volver .txt{display:none}.adm-top a.volver{padding:10px}.adm-top .sep{display:none}.adm-top .marca{font-size:18px}.adm-top button{padding:10px 15px}.adm-top a.ir-web{padding:10px 6px}}' +
    /* --- Caja de acceso: mismo aire que la del portal --- */
    '.adm-login{max-width:420px;margin:6vh auto;background:#fff;border:1px solid #EAE3D5;border-radius:20px;padding:30px 26px 26px;box-shadow:0 26px 50px -32px rgba(46,66,86,.5)}' +
    '.adm-login .adm-logo{display:block;margin:0 auto 8px;height:58px;width:auto}' +
    '.adm-login h1{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:38px;line-height:.98;color:#2E4256;margin:0 0 6px;text-align:center}' +
    '.adm-login .lema{color:#5E5849;margin:0 0 16px;text-align:center;font-size:15px;line-height:1.5}' +
    '.adm-login label{display:block;font-size:14px;font-weight:400;color:#6B6558;margin:12px 0 5px}' +
    '.adm-login input{width:100%;box-sizing:border-box;padding:13px 14px;border:1px solid #E0D8C8;border-radius:12px;font-size:16px;font-family:inherit;color:#2E4256;background:#fff}' +
    '.adm-login input:focus{outline:2px solid #3B85C0;border-color:#3B85C0}' +
    /* «Mantener la sesión abierta», igual que en el portal: misma casilla,
       mismas palabras y la fila entera se pulsa. Dos puertas distintas
       contando lo mismo de dos maneras es justo lo que hay que evitar. */
    '.adm-login label.adm-check{display:flex;align-items:center;gap:11px;min-height:44px;' +
      'margin:12px 0 0;font-size:15px;font-weight:400;line-height:1.35;color:#4A4437;cursor:pointer}' +
    '.adm-login .adm-check input{-webkit-appearance:auto;appearance:auto;width:22px;height:22px;' +
      'flex:0 0 22px;margin:0;padding:0;border:0;border-radius:0;background:none;accent-color:#2F6FA8}' +
    '.adm-login .msg{margin-top:12px;font-size:14px;color:#b3261e;text-align:center}';
  document.head.appendChild(css);

  document.addEventListener('DOMContentLoaded', function () {
    var sb = window.APOLANA_DB;
    var cont = document.getElementById('admin-contenido');
    if (cont) cont.style.display = 'none';

    var login = document.createElement('div');
    login.className = 'adm-login';
    login.style.display = 'none';
    login.innerHTML =
      '<img class="adm-logo" src="' + base() + 'assets/img/logo.png" alt="Club Apolana">' +
      '<h1>Panel Apolana</h1>' +
      '<p class="lema">Acceso para administración.</p>' +
      '<form id="adm-form"><label for="adm-email">Correo</label><input type="email" id="adm-email" autocomplete="username" required>' +
      '<label for="adm-pass">Contraseña</label><input type="password" id="adm-pass" autocomplete="current-password" required>' +
      '<label class="adm-check" for="adm-mantener">' +
        '<input type="checkbox" id="adm-mantener" checked>' +
        '<span>Mantener la sesión abierta</span></label>' +
      '<div style="margin-top:16px"><button class="btn btn--primario" type="submit" style="width:100%">Entrar</button></div>' +
      '<div class="msg" id="adm-msg"></div></form>';
    document.body.insertBefore(login, document.body.firstChild);

    function barra(email) {
      var top = document.createElement('div');
      top.className = 'adm-top';
      top.innerHTML =
        '<div class="izq"><a class="volver" href="' + base() + 'admin/"><i>←</i><span class="txt">Panel</span></a>' +
        '<span class="sep">·</span>' +
        '<span class="marca">' + esc(tituloPagina()) + '</span></div>' +
        '<div class="der"><span>' + esc(email) + '</span>' +
        '<a class="ir-web" href="' + base() + '">Ir a la web</a>' +
        '<button id="adm-salir">Salir</button></div>';
      document.body.insertBefore(top, document.body.firstChild);
      document.getElementById('adm-salir').addEventListener('click', async function () {
        await sb.auth.signOut(); location.reload();
      });
    }

    function mostrarLogin(mensaje) {
      login.style.display = '';
      if (mensaje) { var m = document.getElementById('adm-msg'); if (m) m.textContent = mensaje; }
    }

    if (!sb || !sb.auth) { mostrarLogin('No se pudo conectar con la base de datos.'); return; }

    document.getElementById('adm-form').addEventListener('submit', async function (e) {
      e.preventDefault();
      document.getElementById('adm-msg').textContent = 'Entrando…';
      /* Antes de entrar hay que decir dónde se guarda la sesión, porque
         después ya está guardada. Marcada, sigue viva al cerrar el
         navegador; sin marcar, se va con él. Lo hace de verdad db.js. */
      try {
        var casilla = document.getElementById('adm-mantener');
        if (window.APOLANA_SESION) window.APOLANA_SESION.mantener(!!(casilla && casilla.checked));
      } catch (e2) {}
      var r = await sb.auth.signInWithPassword({
        email: document.getElementById('adm-email').value.trim(),
        password: document.getElementById('adm-pass').value
      });
      if (r.error) { document.getElementById('adm-msg').textContent = 'No se pudo entrar: ' + r.error.message; return; }
      /* Si ha entrado con contraseña es que la tiene: queda apuntado para
         que el portal no le ofrezca ponerse una. Es el mismo apunte que
         hace portal-auth.js, para que las dos puertas cuenten lo mismo.
         Si ya estaba apuntado, no se reescribe. */
      try {
        var yo = r.data && r.data.user;
        if (!(yo && yo.user_metadata && yo.user_metadata.clave_puesta === true)) {
          sb.auth.updateUser({ data: { clave_puesta: true } });
        }
      } catch (e3) {}
      /* «Al entrar, abrir en»: si esa persona ha fijado un papel de
         arranque, se le pone ahora. Si no ha fijado ninguno, se queda
         con el último que usó, que es lo que ya estaba guardado.
         Si falla, no pasa nada: se entra con el último. */
      try { await sb.rpc('rol_al_entrar_aplicar'); } catch (e) {}
      arranque();
    });

    async function arranque() {
      var s = await sb.auth.getSession();
      if (!s.data.session) { mostrarLogin(); return; }
      var admin = await sb.rpc('es_admin');
      if (admin.error) { mostrarLogin('No se pudo comprobar tu acceso. Inténtalo de nuevo.'); return; }
      if (!admin.data) {
        /* No es administración. Al panel entran también los papeles del
           club: tesorero, contable y junta. Tesorero y administrador son
           papeles distintos a propósito, así que uno no vale por el otro. */
        var q = await sb.rpc('dinero_quien_soy');
        var delClub = !q.error && q.data && !!q.data.papel;
        if (!delClub) {
          /* Y aún hay pantallas del panel que son herramienta de campo y
             las tiene que usar el equipo técnico: pasar lista es la
             primera. Lo que ve dentro lo deciden las reglas de acceso de
             la base de datos, que solo le enseñan sus atletas — esto no
             abre datos, solo abre la puerta. */
          var staff = await sb.rpc('es_staff');
          var suya = !staff.error && staff.data && DEL_EQUIPO.test(location.pathname);
          if (!suya && DEL_CUBO.test(location.pathname)) {
            var delCubo = await sb.rpc('cubo_es_gestor');
            suya = !delCubo.error && !!delCubo.data;
          }
          if (!suya) {
            /* Ni administración, ni papel del club, ni equipo técnico en
               una pantalla suya (p. ej. alguien que está mirando el club
               como atleta y llega a una página de /admin/ que se quedó
               guardada en la app): al portal, que es su zona. Allí le
               espera la franja de arriba para volver a cambiarse. */
            location.replace(base() + 'portal/');
            return;
          }
        }
      }
      login.style.display = 'none';
      barra(s.data.session.user.email);
      /* La franja «Estás como …», pegada arriba y sin botón de cerrar. */
      montarPapeles();
      if (cont) cont.style.display = '';
      if (_cb) _cb(sb);
    }

    arranque();
  });
})();

/* ============================================================
   AVISOS Y CONFIRMACIONES
   ------------------------------------------------------------
   Ya no viven aquí. El panel y la app comparten un solo sistema
   —el de la app: navy, abajo, radio 14— y se define una única
   vez en assets/js/admin-tabbar.js («Piel del panel», kit 30g).
   Ahí están window.apoToast() y window.apoConfirm().
   ============================================================ */
