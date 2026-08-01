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

  var css = document.createElement('style');
  css.textContent =
    /* --- tarjeta de acceso (maqueta 19b · pantalla A) --- */
    '.pt-login{max-width:420px;margin:6vh auto;background:#fff;border:1px solid #EAE3D5;border-radius:20px;padding:30px 26px 24px;box-shadow:0 26px 50px -32px rgba(46,66,86,.5)}' +
    '.pt-login .pt-logo{display:block;margin:0 auto 8px;height:58px;width:auto}' +
    '.pt-login h1{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:38px;line-height:.98;color:#2E4256;margin:0 0 6px;text-align:center}' +
    '.pt-login .lema{color:#5E5849;margin:0 0 16px;text-align:center;font-size:15px;line-height:1.5}' +
    '.pt-login label{display:block;font-size:14px;color:#6B6558;margin:12px 0 5px}' +
    '.pt-login input{width:100%;box-sizing:border-box;padding:13px 14px;border:1px solid #E0D8C8;border-radius:12px;font-size:16px;font-family:inherit;color:#2E4256;background:#fff}' +
    '.pt-login .msg{margin-top:12px;font-size:14px;color:#b3261e;text-align:center}' +
    '.pt-login .msg.ok{color:#1e7a3d}' +
    '.pt-olvido{display:block;margin:10px auto 0;background:none;border:0;padding:0;color:#2F6FA8;font-size:14px;font-family:inherit;cursor:pointer;text-decoration:none}' +
    '.pt-sep{display:flex;align-items:center;gap:12px;margin:18px 0 12px}' +
    '.pt-sep span{font-family:var(--fuente-texto);font-size:10px;letter-spacing:.03em;color:#A79F8E}' +
    '.pt-sep i{flex:1;height:1px;background:#E4DCCB;display:block}' +
    '.pt-publico{display:flex;flex-direction:column;gap:8px}' +
    '.pt-publico a{background:#fff;border:1px solid #EFE9DC;border-radius:12px;padding:12px 16px;display:flex;justify-content:space-between;align-items:center;font-size:15px;color:#2E4256;text-decoration:none}' +
    '.pt-publico a:hover{border-color:#C9D9E7}' +
    '.pt-publico a b{font-weight:400}' +
    '.pt-publico a i{color:#A79F8E;font-style:normal}' +
    '.pt-pie{margin-top:18px;padding-top:16px;border-top:1px solid #EAE3D5;display:flex;flex-direction:column;gap:8px}' +
    '.pt-pie span{font-size:14px;color:#6B6558;text-align:center}' +
    '.pt-pie a{border:1px solid #C9D9E7;color:#2F6FA8;text-align:center;padding:13px;border-radius:999px;font-size:15px;font-weight:600;text-decoration:none}' +
    '.pt-pie a:hover{background:#EAF2F9}' +
    /* Nada debe provocar scroll horizontal (era lo que dejaba la barra corta). */
    'html,body{max-width:100%;overflow-x:hidden}' +
    /* --- barra superior --- */
    '.pt-top{background:#2E4256;color:#fff;display:flex;align-items:center;justify-content:space-between;gap:10px;padding:12px clamp(14px,4vw,40px);flex-wrap:nowrap;width:100%;box-sizing:border-box}' +
    '.pt-top .izq{display:flex;align-items:center;gap:14px;min-width:0;overflow:hidden}' +
    '.pt-top .volver{display:inline-flex;align-items:center;gap:6px;flex:0 0 auto}' +
    '.pt-top .volver i{font-style:normal;font-size:17px;line-height:1}' +
    '.pt-top .marca{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:18px;color:#fff;text-decoration:none;white-space:nowrap;min-width:0;overflow:hidden;text-overflow:ellipsis}' +
    '.pt-top .der{display:flex;align-items:center;gap:10px;font-size:14px;color:#cdd6e0;min-width:0}' +
    '.pt-top .der span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:34vw}' +
    '.pt-top a{color:#cdd6e0;text-decoration:none;white-space:nowrap}' +
    '.pt-top button{background:transparent;border:1px solid rgba(255,255,255,.4);color:#fff;border-radius:999px;padding:7px 15px;cursor:pointer;font-family:inherit;font-size:14px;white-space:nowrap;flex:0 0 auto}' +
    '.pt-top button:hover{background:rgba(255,255,255,.12)}' +
    '@media(max-width:560px){.pt-top{padding:10px 14px;gap:8px}.pt-top .marca{display:none}.pt-top .volver{font-size:15px}.pt-top .der span{max-width:34vw}.pt-top button{padding:7px 13px}}' +
    /* --- hoja de cambio de perfil (maqueta 19b · pantalla C) --- */
    '.pt-hoja{position:fixed;inset:0;background:rgba(46,66,86,.45);display:flex;align-items:flex-end;justify-content:center;z-index:9000}' +
    '.pt-hoja .caja{background:#FBF9F4;width:min(460px,100%);max-height:88vh;overflow:auto;border-radius:20px 20px 0 0;padding:20px 20px 26px}' +
    '@media(min-width:640px){.pt-hoja{align-items:center}.pt-hoja .caja{border-radius:20px}}' +
    '.pt-hoja .cab{display:flex;align-items:baseline;justify-content:space-between;gap:12px;margin-bottom:14px}' +
    '.pt-hoja h2{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:26px;color:#2E4256;margin:0}' +
    '.pt-hoja .cerrar{background:none;border:0;color:#2F6FA8;font-size:15px;font-family:inherit;cursor:pointer}' +
    '.pt-hoja .fila{display:flex;align-items:center;gap:12px;background:#fff;border:1px solid #EFE9DC;border-radius:14px;padding:12px 14px;margin-bottom:8px;text-decoration:none}' +
    '.pt-hoja .fila:hover{border-color:#C9D9E7}' +
    '.pt-hoja .fila.activa{border-color:#3B85C0;background:#EAF2F9}' +
    '.pt-hoja .ini{width:36px;height:36px;flex:0 0 36px;border-radius:18px;background:#EAF2F9;color:#2F6FA8;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:600}' +
    '.pt-hoja .txt{flex:1;min-width:0}' +
    '.pt-hoja .txt b{display:block;font-size:15px;color:#2E4256;font-weight:600}' +
    '.pt-hoja .txt small{display:block;font-size:12px;color:#7A7365}' +
    '.pt-hoja .chev{color:#A79F8E}' +
    '.pt-hoja .acciones{margin-top:14px;border-top:1px solid #EAE3D5;padding-top:10px;display:flex;flex-direction:column;gap:2px}' +
    '.pt-hoja .acciones button{background:none;border:0;text-align:left;padding:11px 2px;font-size:15px;font-family:inherit;color:#2F6FA8;cursor:pointer}' +
    '.pt-hoja .nota{font-size:13px;color:#7A7365;margin:10px 2px 0}';
  document.head.appendChild(css);

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
      '<div class="pt-sep"><i></i><span>O SIN CUENTA</span><i></i></div>' +
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
      var nombre = (perfil && perfil.nombre) ? perfil.nombre : email;
      var top = document.createElement('div');
      top.className = 'pt-top';
      top.innerHTML =
        '<div class="izq">' +
          '<a class="volver" href="' + b + '" aria-label="Volver a la web"><i>←</i><span>Ir a la web</span></a>' +
          '<a class="marca" href="' + b + 'portal/">Portal Apolana</a>' +
        '</div>' +
        '<div class="der">' +
          '<button id="pt-cambiar" style="display:none">Cambiar de perfil</button>' +
          '<span>' + esc(nombre) + '</span>' +
          '<button id="pt-salir">Salir</button>' +
        '</div>';
      document.body.insertBefore(top, document.body.firstChild);
      document.getElementById('pt-salir').addEventListener('click', async function () {
        await sb.auth.signOut(); location.reload();
      });
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
       PAPELES DEL USUARIO
       Un correo = una cuenta = una fila en `perfiles` con UN rol.
       Pero una misma persona puede tener además ficha de atleta
       (atletas.perfil_id), hijos (atletas.perfil_padre_id) o
       grupos a su cargo (grupos.entrenador_id). Eso se deduce de
       los datos que la propia persona ya puede leer.
       -------------------------------------------------------- */
    var ZONAS = {
      entrenador:  { titulo: 'Entrenador',     desc: 'Tus grupos: planificar y leer el feedback.', url: b + 'portal/entrenador/',  carpeta: '/portal/entrenador/' },
      atleta:      { titulo: 'Atleta',         desc: 'Tus entrenos y tus marcas.',                 url: b + 'portal/atleta/',      carpeta: '/portal/atleta/' },
      familia:     { titulo: 'Familia',        desc: 'Ficha de tus hijos, faltas y pagos.',        url: b + 'portal/familia/',     carpeta: '/portal/familia/' },
      coordinador: { titulo: 'Coordinación',   desc: 'Los grupos de tu sección.',                  url: b + 'portal/coordinador/', carpeta: '/portal/coordinador/' },
      admin:       { titulo: 'Administración', desc: 'Cobros, contenido web y usuarios.',          url: b + 'admin/',              carpeta: '/admin/' }
    };

    async function calcularPapeles(perfil) {
      var lista = [];
      if (!perfil || !perfil.id) return lista;
      var id = perfil.id;
      var rol = perfil.rol || '';
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

      function anadir(clave, desc) {
        var z = ZONAS[clave];
        if (!z) return;
        lista.push({ clave: clave, titulo: z.titulo, desc: desc || z.desc, url: z.url, carpeta: z.carpeta });
      }
      if (esEntrenador) anadir('entrenador');
      if (esAtleta) anadir('atleta');
      if (esFamilia) anadir('familia', hijos.length ? hijos.join(', ') : null);
      if (rol === 'coordinador') anadir('coordinador');
      if (rol === 'admin') anadir('admin');
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
        var r = await sb.from('perfiles').select('id,nombre,apellidos,email,rol,seccion').eq('email', email).maybeSingle();
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
           entras con otra cuenta), te devuelve al portal para que veas la tuya. */
        if (lista.length) {
          var claves = lista.map(function (p) { return p.clave; });
          var ruta = location.pathname;
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
