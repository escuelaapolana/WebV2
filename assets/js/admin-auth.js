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

  // CSS mínimo del login y la barra superior (para no depender de nada más)
  var css = document.createElement('style');
  css.textContent =
    'html,body{max-width:100%;overflow-x:hidden}' +
    '.adm-top{background:#2E4256;color:#fff;display:flex;align-items:center;justify-content:space-between;gap:10px;padding:12px clamp(14px,4vw,40px);flex-wrap:nowrap;width:100%;box-sizing:border-box}' +
    '.adm-top .izq{display:flex;align-items:center;gap:14px;min-width:0;overflow:hidden}' +
    '.adm-top a.volver{color:#cdd6e0;text-decoration:none;font-size:14px;display:inline-flex;align-items:center;gap:6px;flex:0 0 auto}' +
    '.adm-top a.volver i{font-style:normal;font-size:17px;line-height:1}' +
    '.adm-top .marca{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:18px;color:#fff;white-space:nowrap;min-width:0;overflow:hidden;text-overflow:ellipsis}' +
    '.adm-top .der{display:flex;align-items:center;gap:10px;font-size:14px;color:#cdd6e0;min-width:0}' +
    '.adm-top .der span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:30vw}' +
    '.adm-top button{background:transparent;border:1px solid rgba(255,255,255,.4);color:#fff;border-radius:999px;padding:7px 15px;cursor:pointer;font-family:inherit;white-space:nowrap;flex:0 0 auto}' +
    '@media(max-width:560px){.adm-top{padding:10px 14px;gap:8px}.adm-top a.volver .txt{display:none}.adm-top .marca{font-size:16px}.adm-top .der span{max-width:28vw}.adm-top button{padding:7px 13px}}' +
    '.adm-login{max-width:400px;margin:8vh auto;background:#fff;border:1px solid #EAE3D5;border-radius:20px;padding:36px;box-shadow:0 26px 50px -32px rgba(46,66,86,.5)}' +
    '.adm-login h1{font-family:"Barlow Condensed",sans-serif;text-transform:uppercase;font-size:30px;color:#2E4256;margin:0 0 6px}' +
    '.adm-login p{color:#5E5849;margin:0 0 18px}' +
    '.adm-login label{display:block;font-size:13px;font-weight:600;color:#2E4256;margin:12px 0 5px}' +
    '.adm-login input{width:100%;box-sizing:border-box;padding:11px 13px;border:1px solid #E0D8C8;border-radius:10px;font-size:15px;font-family:inherit}' +
    '.adm-login .msg{margin-top:12px;font-size:14px;color:#b3261e}';
  document.head.appendChild(css);

  document.addEventListener('DOMContentLoaded', function () {
    var sb = window.APOLANA_DB;
    var cont = document.getElementById('admin-contenido');
    if (cont) cont.style.display = 'none';

    var login = document.createElement('div');
    login.className = 'adm-login';
    login.style.display = 'none';
    login.innerHTML =
      '<h1>Panel Apolana</h1><p>Acceso solo para administración.</p>' +
      '<form id="adm-form"><label>Correo</label><input type="email" id="adm-email" required>' +
      '<label>Contraseña</label><input type="password" id="adm-pass" required>' +
      '<div style="margin-top:18px"><button class="btn btn--primario" type="submit" style="width:100%">Entrar</button></div>' +
      '<div class="msg" id="adm-msg"></div></form>';
    document.body.insertBefore(login, document.body.firstChild);

    function barra(email) {
      var top = document.createElement('div');
      top.className = 'adm-top';
      top.innerHTML =
        '<div class="izq"><a class="volver" href="' + base() + 'admin/"><i>←</i><span class="txt">Volver al panel</span></a>' +
        '<span class="marca">Panel Apolana</span></div>' +
        '<div class="der"><span>' + email + '</span><button id="adm-salir">Salir</button></div>';
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
