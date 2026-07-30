/* ============================================================
   ACCESO A LOS PORTALES · Club Atletismo Apolana
   ------------------------------------------------------------
   Login para CUALQUIER usuario del club (atleta, familia,
   entrenador, coordinación, admin). Cuando hay sesión, busca su
   perfil (nombre + rol) y llama a la función registrada con
   APOLANA_PORTAL.listo(function(sb, perfil){ ... }).
   Requiere supabase-js + db.js cargados antes. Cárgalo SIN defer.
   ============================================================ */
(function () {
  var _cb = null;
  window.APOLANA_PORTAL = { listo: function (cb) { _cb = cb; } };
  function base() { return window.APOLANA_BASE || '../'; }

  var css = document.createElement('style');
  css.textContent =
    '.pt-login{max-width:400px;margin:8vh auto;background:#fff;border:1px solid #EAE3D5;border-radius:20px;padding:36px;box-shadow:0 26px 50px -32px rgba(46,66,86,.5)}' +
    '.pt-login h1{font-family:"Barlow Condensed",sans-serif;text-transform:uppercase;font-size:30px;color:#2E4256;margin:0 0 6px}' +
    '.pt-login p{color:#5E5849;margin:0 0 18px}' +
    '.pt-login label{display:block;font-size:13px;font-weight:600;color:#2E4256;margin:12px 0 5px}' +
    '.pt-login input{width:100%;box-sizing:border-box;padding:11px 13px;border:1px solid #E0D8C8;border-radius:10px;font-size:15px;font-family:inherit}' +
    '.pt-login .msg{margin-top:12px;font-size:14px;color:#b3261e}' +
    '.pt-top{background:#2E4256;color:#fff;display:flex;align-items:center;justify-content:space-between;padding:14px clamp(16px,4vw,40px)}' +
    '.pt-top .marca{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:18px;color:#fff}' +
    '.pt-top .der{display:flex;align-items:center;gap:14px;font-size:14px;color:#cdd6e0}' +
    '.pt-top a{color:#cdd6e0;text-decoration:none}' +
    '.pt-top button{background:transparent;border:1px solid rgba(255,255,255,.4);color:#fff;border-radius:999px;padding:7px 16px;cursor:pointer;font-family:inherit}';
  document.head.appendChild(css);

  document.addEventListener('DOMContentLoaded', function () {
    var sb = window.APOLANA_DB;
    var cont = document.getElementById('portal-contenido');
    if (cont) cont.style.display = 'none';

    var login = document.createElement('div');
    login.className = 'pt-login';
    login.style.display = 'none';
    login.innerHTML =
      '<h1>Portal del club</h1><p>Entra con tu correo y contraseña.</p>' +
      '<form id="pt-form"><label>Correo</label><input type="email" id="pt-email" required>' +
      '<label>Contraseña</label><input type="password" id="pt-pass" required>' +
      '<div style="margin-top:18px"><button class="btn btn--primario" type="submit" style="width:100%">Entrar</button></div>' +
      '<div class="msg" id="pt-msg"></div>' +
      '<p style="margin-top:16px;font-size:13px;color:#7A7365">¿Aún no tienes cuenta? Se crea al completar la inscripción.</p></form>';
    document.body.insertBefore(login, document.body.firstChild);

    function barra(perfil, email) {
      var nombre = (perfil && perfil.nombre) ? perfil.nombre : email;
      var top = document.createElement('div');
      top.className = 'pt-top';
      top.innerHTML =
        '<div><a href="' + base() + '">← Ir a la web</a> &nbsp; <span class="marca">Portal Apolana</span></div>' +
        '<div class="der"><span>' + nombre + '</span><button id="pt-salir">Salir</button></div>';
      document.body.insertBefore(top, document.body.firstChild);
      document.getElementById('pt-salir').addEventListener('click', async function () {
        await sb.auth.signOut(); location.reload();
      });
    }

    function mostrarLogin(m) { login.style.display = ''; if (m) { var e = document.getElementById('pt-msg'); if (e) e.textContent = m; } }

    if (!sb || !sb.auth) { mostrarLogin('No se pudo conectar con la base de datos.'); return; }

    document.getElementById('pt-form').addEventListener('submit', async function (e) {
      e.preventDefault();
      document.getElementById('pt-msg').textContent = 'Entrando…';
      var r = await sb.auth.signInWithPassword({
        email: document.getElementById('pt-email').value.trim(),
        password: document.getElementById('pt-pass').value
      });
      if (r.error) { document.getElementById('pt-msg').textContent = 'No se pudo entrar: ' + r.error.message; return; }
      arranque();
    });

    async function arranque() {
      var s = await sb.auth.getSession();
      if (!s.data.session) { mostrarLogin(); return; }
      var email = s.data.session.user.email;
      var perfil = null;
      try {
        var r = await sb.from('perfiles').select('id,nombre,apellidos,email,rol,seccion').eq('email', email).maybeSingle();
        if (!r.error) perfil = r.data;
      } catch (e) { /* si aún no hay permisos de lectura, perfil queda null */ }
      login.style.display = 'none';
      barra(perfil, email);
      if (cont) cont.style.display = '';
      if (_cb) _cb(sb, perfil);
    }

    arranque();
  });
})();
