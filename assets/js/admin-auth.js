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
    '.adm-top{background:#2E4256;color:#fff;display:flex;align-items:center;justify-content:space-between;padding:14px clamp(16px,4vw,40px)}' +
    '.adm-top a.volver{color:#cdd6e0;text-decoration:none;font-size:14px;display:inline-block;vertical-align:middle;margin:0 14px 0 0}' +
    '.adm-top .marca{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:18px;color:#fff;display:inline-block;vertical-align:middle}' +
    '.adm-top .der{display:flex;align-items:center;gap:14px;font-size:14px;color:#cdd6e0}' +
    '.adm-top button{background:transparent;border:1px solid rgba(255,255,255,.4);color:#fff;border-radius:999px;padding:7px 16px;cursor:pointer;font-family:inherit}' +
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
        '<div><a class="volver" href="' + base() + 'admin/">← Volver al panel</a>' +
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
      if (admin.error || !admin.data) { mostrarLogin('Tu cuenta no tiene acceso de administración.'); return; }
      login.style.display = 'none';
      barra(s.data.session.user.email);
      if (cont) cont.style.display = '';
      if (_cb) _cb(sb);
    }

    arranque();
  });
})();
