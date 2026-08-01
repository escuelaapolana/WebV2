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
  window.APOLANA_ADMIN = { listo: function (cb) { _cb = cb; } };

  function base() { return window.APOLANA_BASE || '../../'; }
  function esc(s) { var d = document.createElement('div'); d.textContent = (s == null ? '' : String(s)); return d.innerHTML; }

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
    /* El correo solo cabe bien en pantallas anchas; en móvil manda el título. */
    '@media(max-width:900px){.adm-top .der span{display:none}}' +
    '@media(max-width:560px){.adm-top{padding:8px 14px;gap:8px;min-height:56px}.adm-top a.volver .txt{display:none}.adm-top a.volver{padding:10px}.adm-top .sep{display:none}.adm-top .marca{font-size:18px}.adm-top button{padding:10px 15px}}' +
    /* --- Caja de acceso: mismo aire que la del portal --- */
    '.adm-login{max-width:420px;margin:6vh auto;background:#fff;border:1px solid #EAE3D5;border-radius:20px;padding:30px 26px 26px;box-shadow:0 26px 50px -32px rgba(46,66,86,.5)}' +
    '.adm-login .adm-logo{display:block;margin:0 auto 8px;height:58px;width:auto}' +
    '.adm-login h1{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:38px;line-height:.98;color:#2E4256;margin:0 0 6px;text-align:center}' +
    '.adm-login .lema{color:#5E5849;margin:0 0 16px;text-align:center;font-size:15px;line-height:1.5}' +
    '.adm-login label{display:block;font-size:14px;font-weight:400;color:#6B6558;margin:12px 0 5px}' +
    '.adm-login input{width:100%;box-sizing:border-box;padding:13px 14px;border:1px solid #E0D8C8;border-radius:12px;font-size:16px;font-family:inherit;color:#2E4256;background:#fff}' +
    '.adm-login input:focus{outline:2px solid #3B85C0;border-color:#3B85C0}' +
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
        '<div class="der"><span>' + esc(email) + '</span><button id="adm-salir">Salir</button></div>';
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
      var r = await sb.auth.signInWithPassword({
        email: document.getElementById('adm-email').value.trim(),
        password: document.getElementById('adm-pass').value
      });
      if (r.error) { document.getElementById('adm-msg').textContent = 'No se pudo entrar: ' + r.error.message; return; }
      arranque();
    });

    async function arranque() {
      var s = await sb.auth.getSession();
      if (!s.data.session) { mostrarLogin(); return; }
      var admin = await sb.rpc('es_admin');
      if (admin.error) { mostrarLogin('No se pudo comprobar tu acceso. Inténtalo de nuevo.'); return; }
      if (!admin.data) {
        /* Hay sesión pero no es admin (p. ej. un entrenador que acabó en una
           página de /admin/ cacheada en la app): al portal, que es su zona. */
        location.replace(base() + 'portal/');
        return;
      }
      login.style.display = 'none';
      barra(s.data.session.user.email);
      if (cont) cont.style.display = '';
      if (_cb) _cb(sb);
    }

    arranque();
  });
})();

/* ============================================================
   AVISOS Y CONFIRMACIONES NO BLOQUEANTES
   ------------------------------------------------------------
   window.apoToast(mensaje, tipo)  → tipo: 'ok' | 'error' | 'info'
     Muestra un aviso suave arriba a la derecha que se va solo.
   window.apoConfirm(opciones) → Promise<boolean>
     Diálogo propio para confirmar (nunca bloquea la pestaña).
     opciones: { titulo, texto, confirmar, cancelar, peligro }
   Sustituyen a alert()/confirm(), que congelan el navegador.
   ============================================================ */
(function () {
  if (window.apoToast) return;

  function contenedor() {
    var c = document.querySelector('.apo-toasts');
    if (!c) {
      c = document.createElement('div');
      c.className = 'apo-toasts';
      c.setAttribute('aria-live', 'polite');
      document.body.appendChild(c);
    }
    return c;
  }

  window.apoToast = function (mensaje, tipo) {
    tipo = tipo || 'info';
    var t = document.createElement('div');
    t.className = 'apo-toast apo-toast--' + tipo;
    t.setAttribute('role', tipo === 'error' ? 'alert' : 'status');
    t.textContent = mensaje;
    contenedor().appendChild(t);
    function quitar() {
      if (!t.parentNode) return;
      t.classList.add('apo-saliendo');
      setTimeout(function () { if (t.parentNode) t.parentNode.removeChild(t); }, 300);
    }
    var tmr = setTimeout(quitar, tipo === 'error' ? 6000 : 4000);
    t.addEventListener('click', function () { clearTimeout(tmr); quitar(); });
    return t;
  };

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
        if (prev && prev.focus) { try { prev.focus(); } catch (e) {} }
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
})();
