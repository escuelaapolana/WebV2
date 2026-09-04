/* ============================================================
   ACCESO A LOS PORTALES · Club Atletismo Apolana
   ------------------------------------------------------------
   Login para CUALQUIER usuario del club (atleta, familia,
   entrenador, coordinación, admin). Cuando hay sesión, busca su
   perfil (nombre + rol) y llama a la función registrada con
   APOLANA_PORTAL.listo(function(sb, perfil){ ... }).
   Requiere supabase-js + db.js cargados antes. Cárgalo SIN defer.

   CÓMO SE ENTRA (decidido por el club, verano de 2026)
   - Por delante, correo y contraseña. Como en cualquier otro sitio,
     y con la casilla de «mantener la sesión abierta».
   - El enlace al correo ya no es la forma de entrar: es la forma de
     darse de alta la primera vez, y la salida del que no se acuerda
     de su contraseña. Va debajo, con su explicación.
   - Quien llega del correo sin tener contraseña se pone una ANTES de
     ver el portal. A quien ya la tiene no se le pregunta nunca.

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
    /* Cuando ya hay sesión se añaden aquí abajo, y las pantallas del
       portal pueden usarlas para NO volver a pedir lo que esta
       pantalla de acceso ya ha pedido:
         papeles()     promesa · las zonas que puede abrir
         misAtletas()  promesa · { error, data } con su ficha, las de
                       sus hijos y las de los atletas que entrena
         grupos()      promesa · { error, data } con todos los grupos
       Las dos últimas devuelven filas COMPARTIDAS: se leen, no se
       tocan. Quien necesite cambiar un campo, que copie la fila. */
  };
  function base() { return window.APOLANA_BASE || '../'; }
  function esc(s) { var d = document.createElement('div'); d.textContent = (s == null ? '' : String(s)); return d.innerHTML; }

  /* --------------------------------------------------------------
     LO QUE TRAE EL ENLACE DEL CORREO · se mira YA, aquí arriba
     --------------------------------------------------------------
     Cuando alguien pulsa el enlace que le ha llegado, vuelve al
     portal con la respuesta colgada del final de la dirección
     (después de la almohadilla). Si todo ha ido bien, ahí viene la
     sesión; si el enlace ha caducado, viene el motivo.

     Esto se lee AHORA, en cuanto se carga el archivo, porque
     supabase-js coge esa parte de la dirección, la usa y la borra en
     cuanto arranca. Si esperásemos a que la pantalla estuviera
     pintada, ya no quedaría nada que leer y el que llega tarde solo
     vería la pantalla de entrar otra vez, sin saber por qué.

     Este archivo se carga SIN «defer» y db.js CON «defer», así que
     esto pasa antes de que exista el cliente. Es a propósito.
     -------------------------------------------------------------- */
  var _delEnlace = null;   // el enlace ya no valía: por qué
  var _acabaDeEntrar = false;  // ha entrado AHORA, pulsando el enlace
  var _tipoEnlace = '';    // qué enlace era: 'recovery' si venía de «cambiar la contraseña»
  (function () {
    var h = (location.hash || '').replace(/^#/, '');
    if (!h || h.indexOf('=') === -1) return;
    var p = new URLSearchParams(h);
    var err = p.get('error_code') || p.get('error');
    if (err) { _delEnlace = { codigo: String(err) }; return; }
    if (p.get('access_token')) {
      _acabaDeEntrar = true;
      _tipoEnlace = p.get('type') || '';
    }
  })();

  /* Lo que se le dice a alguien cuyo enlace ya no vale. En cristiano
     y sin una palabra en inglés: el enlace caduca a la hora y solo
     sirve una vez, así que el que lo abre el jueves un correo del
     lunes acaba aquí, y lo único que necesita saber es que puede
     pedir otro. */
  function motivoDelEnlace(codigo) {
    if (/expired/i.test(codigo)) {
      return 'Ese enlace ya ha caducado. Escribe tu correo y te mandamos uno nuevo.';
    }
    if (/used|already/i.test(codigo)) {
      return 'Ese enlace ya se había usado. Escribe tu correo y te mandamos uno nuevo.';
    }
    return 'Ese enlace ya no vale. Escribe tu correo y te mandamos uno nuevo.';
  }

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
  /* Carga `assets/js/papeles.js` una vez y avisa cuando está. Ya NO pinta
     la franja de «Estás como…»: eso lo dice ahora la píldora de la barra,
     y dos sitios diciendo lo mismo era justo el problema. En el panel la
     franja sigue puesta hasta que su barra se cambie también. */
  function conPapeles(cuando) {
    if (window.APOLANA_PAPELES) { cuando(); return; }
    var s = document.createElement('script');
    s.src = base() + 'assets/js/papeles.js';
    s.async = true;
    s.addEventListener('load', cuando);
    s.addEventListener('error', function () { /* sin píldora, pero el portal sigue vivo */ });
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
    '.pt-olvido{display:flex;align-items:center;justify-content:center;min-height:44px;margin:6px auto 0;background:none;border:0;padding:0 8px;color:#2F6FA8;font-size:15px;font-family:inherit;cursor:pointer;text-decoration:none;text-align:center;line-height:1.35}' +
    '.pt-olvido[hidden]{display:none}' +
    '.pt-olvido:disabled{color:#8C8577;cursor:default}' +
    /* --- la contraseña, con «Ver» dentro del propio recuadro -----------
       Un solo campo y un botón para leer lo que se ha escrito. Dos campos
       («repítela») obligan a teclear a ciegas dos veces lo mismo en un
       móvil pequeño, y no demuestran que esté bien: solo que se ha
       tecleado igual dos veces. Leerla sí lo demuestra. */
    '.pt-login .pt-campo{position:relative;display:block}' +
    '.pt-login .pt-campo input{padding-right:96px}' +
    '.pt-ojo{position:absolute;right:4px;top:50%;transform:translateY(-50%);display:inline-flex;' +
      'align-items:center;justify-content:center;min-height:44px;min-width:44px;padding:0 12px;' +
      'border:0;border-radius:8px;background:none;color:#2F6FA8;font-family:inherit;font-size:14px;' +
      'font-weight:600;line-height:1.2;cursor:pointer;-webkit-tap-highlight-color:transparent}' +
    '.pt-ojo:hover{background:#EAF2F9}' +
    /* --- «mantener la sesión abierta» ---------------------------------
       La fila entera se pulsa, no solo el cuadradito: a 375 px un cuadro
       de 22 px es imposible de acertar con el pulgar. */
    '.pt-login label.pt-check{display:flex;align-items:center;gap:11px;min-height:44px;' +
      'margin:12px 0 0;font-size:15px;line-height:1.35;color:#4A4437;cursor:pointer}' +
    /* La casilla vuelve a ser la casilla del móvil: el recuadro blanco con
       borde de los campos de texto se la comía. */
    '.pt-login .pt-check input{-webkit-appearance:auto;appearance:auto;width:22px;height:22px;' +
      'flex:0 0 22px;margin:0;padding:0;border:0;border-radius:0;background:none;accent-color:#2F6FA8}' +
    '.pt-login .pt-check span{min-width:0}' +
    /* --- la otra puerta: pedir un enlace ------------------------------
       Deja de ser la forma de entrar y pasa a ser la forma de darse de
       alta (y la salida para quien no se acuerda de la contraseña). */
    '.pt-otra{margin-top:16px;padding-top:14px;border-top:1px solid #EAE3D5;text-align:center}' +
    '.pt-otra[hidden]{display:none}' +
    '.pt-otra .pt-nota{margin:0}' +
    /* La casilla que hay que rellenar se enciende un momento. Decir «escribe tu
       correo arriba» y no señalar dónde es lo que dejó a la primera persona que
       lo probó dando vueltas por la pantalla. */
    '.pt-hay-que-mirar{border-color:#B96F09!important;box-shadow:0 0 0 3px #FDF3E3!important}' +
    '.pt-btn2{display:flex;align-items:center;justify-content:center;width:100%;box-sizing:border-box;' +
      'min-height:44px;margin-top:9px;padding:11px 14px;border:1px solid #C9D9E7;border-radius:999px;' +
      'background:#fff;color:#2F6FA8;font-family:inherit;font-size:15px;font-weight:600;line-height:1.25;' +
      'cursor:pointer}' +
    '.pt-btn2:hover{background:#EAF2F9}' +
    '.pt-btn2:disabled{color:#8C8577;border-color:#E0D8C8;background:#fff;cursor:default}' +
    /* --- ponerse una contraseña la primera vez ------------------------
       Va en la MISMA tarjeta que el acceso, con el mismo ancho, la misma
       letra y los mismos botones: es la misma casa, no otra pantalla. */
    '.pt-clave[hidden]{display:none}' +
    /* Ocupa el sitio del titular «Club Apolana», que se aparta: dos rótulos
       en mayúsculas y condensada, uno encima de otro, compiten y no se lee
       ninguno. El escudo ya dice de quién es esta pantalla. */
    '.pt-clave h2{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;' +
      'font-size:34px;line-height:1;color:#2E4256;margin:0 0 8px;text-align:center}' +
    '.pt-clave-txt{margin:0;font-size:15px;line-height:1.5;color:#5E5849;text-align:center}' +
    '.pt-clave-txt b{font-weight:600;overflow-wrap:anywhere}' +
    '.pt-pista{margin:9px 0 0;font-size:13.5px;line-height:1.45;color:#6E6656}' +
    /* --- entrar con un enlace ---------------------------------------
       La frase de debajo del botón explica en una línea qué va a
       pasar. Sin ella, «Enviarme un enlace para entrar» deja a medio
       mundo esperando en esta pantalla a que ocurra algo. */
    '.pt-nota{margin:8px 0 0;font-size:13.5px;line-height:1.45;color:#6E6656;text-align:center}' +
    /* La espera ocupa el sitio del formulario, con el mismo ancho y
       el mismo aire: no es otra pantalla, es la misma tarjeta
       contando lo que acaba de hacer. */
    '.pt-espera{text-align:center;padding:6px 0 2px}' +
    '.pt-espera[hidden]{display:none}' +
    '.pt-sobre{width:56px;height:56px;margin:2px auto 12px;border-radius:50%;background:#EAF2F9;color:#2F6FA8;display:flex;align-items:center;justify-content:center}' +
    '.pt-espera-tit{margin:0 0 8px;font-size:16px;line-height:1.45;color:#2E4256}' +
    /* El correo, partido si hace falta: hay direcciones largas y a
       375 px una sola palabra sin cortes empuja la tarjeta afuera. */
    '.pt-espera-tit b{font-weight:600;overflow-wrap:anywhere}' +
    '.pt-espera-txt{margin:0 0 8px;font-size:14.5px;line-height:1.5;color:#5E5849}' +
    '.pt-espera-fina{color:#6E6656;font-size:13.5px}' +
    '.pt-espera .msg{margin-top:10px}' +
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
    /* --- LA BARRA ÚNICA ---------------------------------------------
       Antes había DOS barras pegadas: «Estás como atleta · Cambiar» y
       debajo otra oscura con «Cambiar de perfil · nombre · Ir a la web ·
       Salir». De ahí el «no sé dónde están las cosas»: cambiar de PAPEL
       y cambiar de PERFIL son dos cosas distintas y competían en el
       mismo sitio.

       Ahora es una sola barra de 52 px con dos controles a la derecha y
       ni uno más:
         · la píldora del papel — lo que estás haciendo ahora;
         · el avatar — lo tuyo: perfil, hijos, ir a la web y salir.

       A la izquierda, escudo y APOLANA, y NO se pulsan. El club quitó de
       esa esquina la flecha «← Ir a la web» porque es donde el móvil pone
       el gesto de volver atrás y la gente la pulsaba sin mirar; el sitio
       se queda ocupado por el escudo, que no hace nada al tocarlo.
       ----------------------------------------------------------------- */
    '.pt-top{position:relative;background:linear-gradient(180deg,#35506E,#20303F);color:#fff;display:flex;align-items:center;justify-content:space-between;' +
      'gap:10px;min-height:52px;padding:4px clamp(14px,4vw,40px);flex-wrap:nowrap;width:100%;box-sizing:border-box;' +
      'box-shadow:0 4px 16px rgba(20,30,42,.28);border-bottom:1px solid rgba(255,255,255,.06);' +
      'user-select:none;-webkit-user-select:none}' +
    '.pt-top .izq{display:flex;align-items:center;gap:10px;min-width:0;overflow:hidden}' +
    /* El escudo es azul oscuro con el detalle fino, y sobre la banda navy se
       perdía: se veía una mancha. Va sobre un disco blanco, que es como está
       impreso en las camisetas y en el papel del club. */
    '.pt-top .escudo{width:30px;height:30px;flex:0 0 30px;object-fit:contain;display:block;' +
      'background:#fff;border-radius:999px;padding:3px;box-sizing:border-box}' +
    '.pt-top .marca{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;' +
      'font-size:18px;letter-spacing:.03em;color:#fff;white-space:nowrap;min-width:0;overflow:hidden;text-overflow:ellipsis}' +
    '.pt-top .der{display:flex;align-items:center;gap:9px;flex:0 0 auto}' +

    /* La píldora del papel. Dice DE QUÉ («Entrenador · Verde 1 y Verde 2»):
       sin eso, alguien con cuatro papeles no sabe cuál abre qué. */
    '.pt-papel{display:none;align-items:center;gap:7px;box-sizing:border-box;min-height:44px;' +
      'padding:8px 14px;border:0;border-radius:999px;background:rgba(255,255,255,.14);' +
      'font-family:inherit;font-size:14px;font-weight:500;line-height:1.2;color:#fff;cursor:pointer;' +
      'max-width:min(52vw,420px);white-space:nowrap;overflow:hidden;-webkit-tap-highlight-color:transparent}' +
    '.pt-papel.ver{display:inline-flex}' +
    '.pt-papel:hover{background:rgba(255,255,255,.22)}' +
    '.pt-papel .pt-txt{overflow:hidden;text-overflow:ellipsis}' +
    '.pt-papel .pt-fl{flex:0 0 auto;opacity:.85}' +
    /* La del avatar va más pequeña y pegada abajo a la derecha del círculo:
       tiene que decir «esto se abre» sin competir con las iniciales. */
    /* La flecha va FUERA del círculo, a su derecha, igual que la del papel de
       al lado. El primer intento la puso encima de las iniciales y quedaba un
       triángulo tapando las letras. Se anulan a mano el ancho y el fondo
       porque justo debajo hay una regla para «el span del avatar» que es la
       de las iniciales. */
    '.pt-fl-av{width:auto;height:auto;background:none;border-radius:0;' +
      'font-size:10px;line-height:1;opacity:.75;color:#fff;flex:0 0 auto;margin-left:1px}' +

    /* El avatar. Se ve a 32 px y se pulsa en 44. */
    /* Un poco más ancho que alto: el círculo mide lo de siempre y lo que crece
       es el hueco de la flecha, que va al lado y no encima. */
    '.pt-avatar{display:inline-flex;align-items:center;justify-content:center;gap:1px;width:auto;min-width:52px;height:44px;' +
      'flex:0 0 auto;padding:0 3px 0 0;border:0;border-radius:999px;background:none;cursor:pointer;' +
      'user-select:none;-webkit-user-select:none;-webkit-tap-highlight-color:transparent}' +
    '.pt-avatar span{display:flex;align-items:center;justify-content:center;width:32px;height:32px;' +
      'border-radius:999px;background:#8FC0E8;color:#1E4E78;font-family:inherit;font-size:13px;font-weight:600;line-height:1}' +
    '.pt-avatar:hover span{background:#A9D0F0}' +
    '.pt-papel:focus-visible,.pt-avatar:focus-visible{outline:2px solid #fff;outline-offset:2px}' +
    /* Pastilla «Web» y nombre en el avatar, como la maqueta */
    '.pt-web{display:inline-flex;align-items:center;gap:6px;color:#fff;text-decoration:none;font-size:13px;font-weight:600;' +
      'background:rgba(255,255,255,.10);border:1px solid rgba(255,255,255,.18);border-radius:999px;padding:0 13px;min-height:44px;' +
      'box-sizing:border-box;-webkit-tap-highlight-color:transparent}' +
    '.pt-web:hover{background:rgba(255,255,255,.18)}' +
    '.pt-web svg{flex:0 0 auto}' +
    '.pt-avatar .pt-nom{width:auto;height:auto;min-width:0;border-radius:0;background:none;color:#fff;' +
      'font-size:13.5px;font-weight:600;padding:0 0 0 2px;white-space:nowrap;max-width:120px;overflow:hidden;text-overflow:ellipsis}' +
    '.pt-avatar .pt-rol{width:auto;height:auto;min-width:0;border-radius:0;background:none;color:rgba(255,255,255,.62);' +
      'font-size:13px;font-weight:400;padding:0 3px 0 5px;white-space:nowrap;max-width:150px;overflow:hidden;text-overflow:ellipsis}' +
    /* En móvil NO se ocultan los textos: «Web» y el nombre+rol se ven
       siempre (igual que en el admin). Solo se aprieta el espaciado y se
       recorta el ancho del nombre para que la barra no se parta en dos filas. */
    '@media(max-width:440px){.pt-web{padding-left:8px;padding-right:8px;gap:5px}' +
      '.pt-avatar .pt-nom{max-width:84px}.pt-avatar .pt-rol{max-width:96px;padding-left:4px}}' +
    '@media(max-width:360px){.pt-avatar .pt-nom{max-width:64px}.pt-avatar .pt-rol{max-width:72px}}' +

    /* Lo tuyo, colgando del avatar. Va pegado a él, no en el centro de la
       pantalla: lo que se pulsa y lo que aparece tienen que estar juntos. */
    /* Va en `fixed`, no en `absolute`: el `overflow-x:hidden` que lleva el
       body para que nada desborde a lo ancho recorta lo que se sale por
       abajo, y en una pantalla corta el menú se quedaba sin «Salir». */
    '.pt-menu{position:fixed;z-index:9100;right:clamp(14px,4vw,40px);min-width:236px;max-width:calc(100vw - 28px);' +
      'padding:6px;border:1px solid #E4DCCB;border-radius:14px;background:#fff;' +
      'box-shadow:0 18px 40px -22px rgba(46,66,86,.6)}' +
    '.pt-menu[hidden]{display:none}' +
    '.pt-menu .pt-quien{display:block;padding:9px 13px 10px;border-bottom:1px solid #EFE9DC;margin-bottom:5px}' +
    '.pt-menu .pt-quien b{display:block;font-size:15px;font-weight:600;color:#2E4256;line-height:1.3}' +
    '.pt-menu .pt-quien small{display:block;font-size:13px;color:#6E6656;line-height:1.4;word-break:break-all}' +
    '.pt-menu a,.pt-menu button{display:flex;align-items:center;width:100%;box-sizing:border-box;min-height:44px;' +
      'padding:10px 13px;border:0;border-radius:8px;background:none;color:#4A4437;font-family:inherit;' +
      'font-size:15px;text-align:left;text-decoration:none;cursor:pointer;white-space:nowrap}' +
    '.pt-menu a:hover,.pt-menu button:hover{background:#EFE9DC;color:#2E4256}' +
    '.pt-menu .pt-salir{gap:10px;margin-top:6px;padding-top:12px;border-top:1px solid #EFE9DC;' +
      'border-radius:0;color:#2F6FA8;font-weight:600}' +
    '.pt-menu .pt-salir svg{flex:0 0 19px}' +
    '.pt-menu .pt-salir:hover{background:#EAF2F9;color:#1E4E78}' +

    /* En un móvil estrecho la píldora dice el papel y se calla de qué: el
       detalle está a un toque, en el selector, y así la barra nunca se
       parte en dos filas ni siquiera con cuatro papeles. */
    '@media(max-width:560px){.pt-top{padding:4px 14px}' +
      '.pt-papel{max-width:none;padding:8px 12px}' +
      '.pt-papel .pt-dequé{display:none}}' +
    /* Con solo dos mandos a la derecha, APOLANA cabe hasta en un móvil de
       375 px aunque tengas cuatro papeles: antes eran tres o cuatro mandos
       y la barra se partía en dos filas. Si aun así no cupiera —un móvil de
       320 px—, lo que se aparta es el nombre; el escudo no se quita nunca. */
    '@media(max-width:340px){.pt-top.pt-mas-mandos .marca{display:none}}' +
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
    },
    /* La vuelta al portal, definida UNA sola vez: misma flecha, mismas
       palabras y mismo aspecto en todas las pantallas. Antes cada estado
       vacío se lo escribía por su cuenta y unos llevaban flecha y otros no. */
    volver: function (texto, href) {
      return '<a class="ap-btn" href="' + (href || '../') + '">← ' + esc(texto || 'Volver al portal') + '</a>';
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
      '<p class="lema" id="pt-lema">Entra con tu correo y tu contraseña.</p>' +
      /* --------------------------------------------------------
         LA PUERTA DE SIEMPRE, A LA VISTA
         Correo y contraseña, como en cualquier otro sitio: es lo
         primero que se ve, sin nada escondido detrás de un botón.
         El enlace al correo no ha desaparecido, pero ya no es la
         forma de entrar: es la forma de darse de alta la primera
         vez y la salida para quien no se acuerda. Por eso está
         debajo, con su raya y con su explicación.
         -------------------------------------------------------- */
      '<form id="pt-form" novalidate>' +
        '<label for="pt-email">Tu correo</label>' +
        '<input type="email" id="pt-email" autocomplete="username" inputmode="email" ' +
               'autocapitalize="none" autocorrect="off" spellcheck="false" required>' +
        '<label for="pt-pass">Tu contraseña</label>' +
        '<div class="pt-campo">' +
          '<input type="password" id="pt-pass" autocomplete="current-password" ' +
                 'autocapitalize="none" autocorrect="off" spellcheck="false">' +
          '<button type="button" class="pt-ojo" id="pt-ver" aria-pressed="false" ' +
                  'aria-controls="pt-pass" aria-label="Ver la contraseña">Ver</button>' +
        '</div>' +
        /* Marcada de salida: es lo que hacía la web hasta hoy, y es lo que
           quiere casi todo el mundo en su propio móvil. Quien entre desde
           un móvil prestado la desmarca. */
        '<label class="pt-check" for="pt-mantener">' +
          '<input type="checkbox" id="pt-mantener" checked>' +
          '<span>Mantener la sesión abierta</span>' +
        '</label>' +
        '<div style="margin-top:16px"><button class="btn btn--primario" type="submit" id="pt-enviar" style="width:100%">Entrar</button></div>' +
        '<div class="msg" id="pt-msg" role="status" aria-live="polite"></div>' +
      '</form>' +
      '<div class="pt-otra" id="pt-otra">' +
        /* ⚠️ ESTE TEXTO LO ESCRIBIÓ UNA PRIMERA VEZ DE VERDAD. Ponía «¿Primera
           vez, o no te acuerdas de la contraseña?», y quien entra por primera
           vez NO TIENE contraseña: ve el formulario de arriba, no sabe qué
           poner, y no relaciona ese botón con lo que le pasa. Ahora se dice lo
           que hay que hacer y en qué orden —tu correo arriba, este botón, te
           llega un enlace— porque el paso que se saltaba era escribir el correo
           en una casilla que parecía parte de «entrar con contraseña». */
        '<p class="pt-nota"><b>¿Es tu primera vez?</b> Todavía no tienes contraseña. ' +
          'Escribe tu correo en la casilla de arriba y pulsa aquí: te llega un enlace y entras con él.</p>' +
        '<button type="button" class="pt-btn2" id="pt-pedir">Enviarme un enlace al correo</button>' +
      '</div>' +
      /* --------------------------------------------------------
         LA ESPERA · lo que se ve mientras el correo va de camino
         Ocupa el sitio del formulario, y no se pone debajo, para
         que no queden a la vez «Entrar» y «te hemos enviado un
         enlace»: eso hace que la gente vuelva a pulsar.
         -------------------------------------------------------- */
      '<div class="pt-espera" id="pt-espera" hidden role="status" aria-live="polite">' +
        '<div class="pt-sobre" aria-hidden="true">' +
          '<svg viewBox="0 0 24 24" width="30" height="30" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' +
            '<rect x="2.5" y="5" width="19" height="14" rx="2.5"></rect><path d="M3 7l9 6 9-6"></path>' +
          '</svg>' +
        '</div>' +
        '<p class="pt-espera-tit">Te hemos enviado un enlace a <b id="pt-espera-mail"></b></p>' +
        '<p class="pt-espera-txt">Ábrelo en el móvil donde vayas a usar la app. Al pulsarlo entras y lo primero que harás es ponerte una contraseña.</p>' +
        '<p class="pt-espera-txt pt-espera-fina">Tarda un minuto en llegar. Si no aparece, mira en la carpeta de correo no deseado.</p>' +
        '<button type="button" class="pt-olvido" id="pt-reenviar">No me ha llegado, mándalo otra vez</button>' +
        '<button type="button" class="pt-olvido" id="pt-otro">Volver</button>' +
        '<div class="msg" id="pt-msg2"></div>' +
      '</div>' +
      /* --------------------------------------------------------
         PONTE UNA CONTRASEÑA · lo primero al entrar por el enlace
         Ocupa el sitio del formulario, en la misma tarjeta. Aquí no
         se enseñan los accesos públicos ni «Inscribirme»: esta
         persona ya está dentro, y lo único que tiene que hacer
         ahora es esto.
         -------------------------------------------------------- */
      '<div class="pt-clave" id="pt-clave" hidden>' +
        '<h2>Ponte una contraseña</h2>' +
        '<p class="pt-clave-txt">Será la que uses de ahora en adelante para entrar, junto con tu correo <b id="pt-clave-mail"></b>.</p>' +
        '<form id="pt-clave-form" novalidate>' +
          '<label for="pt-clave-1">Tu contraseña</label>' +
          '<div class="pt-campo">' +
            '<input type="password" id="pt-clave-1" autocomplete="new-password" ' +
                   'autocapitalize="none" autocorrect="off" spellcheck="false">' +
            '<button type="button" class="pt-ojo" id="pt-clave-ver" aria-pressed="false" ' +
                    'aria-controls="pt-clave-1" aria-label="Ver la contraseña">Ver</button>' +
          '</div>' +
          '<p class="pt-pista">Al menos 6 letras o números. Elige algo que puedas recordar; pulsa «Ver» para leer lo que escribes.</p>' +
          '<div style="margin-top:16px"><button class="btn btn--primario" type="submit" id="pt-clave-ok" style="width:100%">Guardar y entrar</button></div>' +
          '<div class="msg" id="pt-clave-msg" role="status" aria-live="polite"></div>' +
        '</form>' +
        '<button type="button" class="pt-olvido" id="pt-clave-salir">Salir y hacerlo en otro momento</button>' +
      '</div>' +
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
      if (document.querySelector('.pt-top')) return;
      var nombre = (perfil && perfil.nombre) ? perfil.nombre : email;
      var primerNom = String(nombre).trim().split(/\s+/)[0] || nombre;
      var ini = iniciales(perfil, email);
      var top = document.createElement('div');
      top.className = 'pt-top';
      top.innerHTML =
        '<div class="izq">' +
          '<img class="escudo" src="' + b + 'assets/img/logo.png" alt="" aria-hidden="true">' +
          '<span class="marca">Apolana</span>' +
        '</div>' +
        '<div class="der">' +
          /* Pastilla «Web» a la web pública del club (como la maqueta). */
          '<a class="pt-web" href="' + b + '" title="Ir a la web del club">' +
            '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">' +
              '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.6 2.5 15.4 0 18M12 3c-2.5 2.6-2.5 15.4 0 18"/></svg>' +
            '<span>Web</span></a>' +
          /* La píldora nace escondida: si solo tienes un papel no aparece
             nunca, y la mayoría del club está en ese caso. */
          '<button type="button" class="pt-papel" id="pt-papel" aria-haspopup="dialog">' +
            '<span class="pt-txt"></span>' +
            '<span class="pt-fl" aria-hidden="true">&#9662;</span>' +
          '</button>' +
          '<button type="button" class="pt-avatar" id="pt-avatar" aria-haspopup="menu" ' +
            'aria-expanded="false" aria-controls="pt-menu" aria-label="Lo tuyo: perfil y salir">' +
            /* Las iniciales son el respaldo. Si la persona ha puesto foto en
               su perfil, se pinta encima en cuanto llega: se subía, se
               guardaba, se veía en el perfil y en los retos, y aquí seguían
               saliendo las letras como si no existiera. */
            '<span aria-hidden="true">' + esc(ini) + '</span>' +
            /* El nombre, DESPUÉS del círculo (como la maqueta) y después del
               span de las iniciales, porque la foto de perfil se pinta sobre
               el PRIMER span del avatar: si el nombre fuera el primero, la
               foto le borraría el texto. */
            '<span class="pt-nom">' + esc(primerNom) + '</span>' +
            /* El papel activo, dentro de la misma píldora (como la maqueta:
               «Andrés · Atleta»). Lo rellena ponerPildora(); nace vacío. */
            '<span class="pt-rol" id="pt-rol"></span>' +
            /* La misma flechita que lleva el papel de al lado. Sin ella, el
               círculo con las iniciales parece una foto de perfil y no algo
               que se pulse: hay que descubrir por casualidad que abre un
               menú. Y justo al lado hay otro botón que sí la lleva, así que
               la diferencia se nota. */
            '<span class="pt-fl pt-fl-av" aria-hidden="true">&#9662;</span>' +
          '</button>' +
        '</div>' +
        '<div class="pt-menu" id="pt-menu" hidden role="menu">' +
          '<span class="pt-quien"><b>' + esc(nombre) + '</b><small>' + esc(email) + '</small></span>' +
          '<a role="menuitem" href="' + b + 'portal/perfil/">Mi perfil</a>' +
          '<a role="menuitem" class="pt-hijos" href="' + b + 'portal/familia/" hidden>Mis hijos</a>' +
          /* Cambiar de papel: solo aparece si la persona tiene más de un papel.
             Lo activa ponerPildora(). Antes vivía en una pastilla aparte. */
          '<button type="button" role="menuitem" class="pt-cambiar" id="pt-cambiar" hidden>Cambiar de papel</button>' +
          '<a role="menuitem" href="' + b + '">Ir a la web</a>' +
          /* Cerrar sesión se busca con prisa —un móvil prestado, la cuenta de
             otro— así que va apartado del resto, con su raya y su icono, y
             es lo único del menú que no es un sitio al que ir. «Cambiar la
             contraseña» no está aquí: vive en Mi perfil, que es donde se
             buscan los ajustes, y una entrada menos hace que esta se vea. */
          '<button type="button" role="menuitem" class="pt-salir" id="pt-salir">' +
            '<svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="currentColor" ' +
              'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
              '<path d="M15 17v2a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v2"/>' +
              '<path d="M19 12H9m10 0-3.2-3.2M19 12l-3.2 3.2"/></svg>' +
            'Salir</button>' +
        '</div>';
      document.body.insertBefore(top, document.body.firstChild);

      /* --- el menú del avatar --- */
      var bAvatar = document.getElementById('pt-avatar');

      /* La foto del perfil, si la hay. Va aparte y sin hacer ruido: el almacén
         es privado y hay que pedir un enlace firmado, así que tarda un poco.
         Mientras llega -o si no llega- se quedan las iniciales, que es lo que
         se veía hasta ahora. */
      (function () {
        var ruta = perfil && perfil.foto_ruta;
        if (!ruta || !bAvatar) return;
        var pintar = function (url) {
          if (!url) return;
          var hueco = bAvatar.querySelector('span');
          if (!hueco) return;
          hueco.style.backgroundImage = 'url("' + url.replace(/"/g, '\\"') + '")';
          hueco.style.backgroundSize = 'cover';
          hueco.style.backgroundPosition = 'center';
          hueco.textContent = '';            /* la foto sustituye a las letras */
        };
        if (/^(https?:|data:)/.test(ruta)) { pintar(ruta); return; }
        try {
          sb.storage.from('fotos-perfil').createSignedUrl(ruta, 3600).then(function (r) {
            if (r && !r.error && r.data && r.data.signedUrl) pintar(r.data.signedUrl);
          }, function () { /* sin foto, las iniciales */ });
        } catch (e) { /* igual */ }
      })();
      var menu = document.getElementById('pt-menu');
      function cerrarMenu() {
        menu.hidden = true;
        bAvatar.setAttribute('aria-expanded', 'false');
      }
      bAvatar.addEventListener('click', function (e) {
        e.stopPropagation();
        var abrir = menu.hidden;
        menu.hidden = !abrir;
        bAvatar.setAttribute('aria-expanded', abrir ? 'true' : 'false');
        if (abrir) {
          /* Colgado del avatar, no en el centro de la pantalla: lo que se
             pulsa y lo que aparece tienen que estar juntos. */
          menu.style.top = (bAvatar.getBoundingClientRect().bottom + 4) + 'px';
          var primero = menu.querySelector('a,button');
          if (primero) primero.focus();
        }
      });
      /* La barra se va con el scroll; el menú, que es fijo, se quedaría
         flotando solo. Se cierra. */
      window.addEventListener('scroll', function () { if (!menu.hidden) cerrarMenu(); }, { passive: true });
      window.addEventListener('resize', function () { if (!menu.hidden) cerrarMenu(); });
      document.addEventListener('click', function (e) {
        if (!menu.hidden && !menu.contains(e.target)) cerrarMenu();
      });
      document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape' && !menu.hidden) { cerrarMenu(); bAvatar.focus(); }
      });

      document.getElementById('pt-salir').addEventListener('click', async function () {
        await sb.auth.signOut(); location.reload();
      });
      /* «Mis hijos» solo si los hay: un menú con una puerta que no lleva a
         ninguna parte es peor que un menú corto. */
      if (perfil && perfil.id) {
        misAtletas(perfil.id).then(function (r) {
          var hijos = (r.data || []).filter(function (a) { return a.perfil_padre_id === perfil.id; });
          var el = menu.querySelector('.pt-hijos');
          if (el && hijos.length) el.hidden = false;
        });
      }

      /* La píldora sale cuando se sabe en qué papel estás. Si solo tienes
         uno, no sale nunca: la mayoría del club está en ese caso y para
         ellos la barra es escudo y avatar. */
      conPapeles(function () {
        if (!window.APOLANA_PAPELES) return;
        window.APOLANA_PAPELES.cargar().then(function (d) {
          if (!d || (d.roles || []).length < 2) return;
          ponerPildora(perfil, window.APOLANA_PAPELES.titulo(d.activo), d.activo, function () {
            window.APOLANA_PAPELES.abrir();
          });
        });
      });
    }

    /* ------------------------------------------------------------
       LA PÍLDORA DEL PAPEL · «lo que estás haciendo ahora»
       Dice de qué: «Entrenador · Verde 1 y Verde 2», «Familia · Lucía
       y Pablo». Los nombres salen de lo que ya se ha pedido para la
       página (las fichas y los grupos), así que no cuesta ni una
       petición más.
       ------------------------------------------------------------ */
    var pildoraPuesta = false;

    function unirNombres(lista) {
      if (!lista.length) return '';
      if (lista.length === 1) return lista[0];
      if (lista.length === 2) return lista[0] + ' y ' + lista[1];
      return lista.slice(0, 2).join(', ') + ' y ' + (lista.length - 2) + ' más';
    }

    async function deQue(rol, perfil) {
      if (!perfil || !perfil.id) return '';
      try {
        if (rol === 'entrenador') {
          var g = await grupos();
          return unirNombres((g.data || [])
            .filter(function (x) { return x.entrenador_id === perfil.id; })
            .map(function (x) {
              return (x.turno && window.APOLANA_GRUPO_NOMBRE) ? window.APOLANA_GRUPO_NOMBRE(x) : x.nombre;
            }));
        }
        if (rol === 'padre') {
          var a = await misAtletas(perfil.id);
          return unirNombres((a.data || [])
            .filter(function (x) { return x.perfil_padre_id === perfil.id; })
            .map(function (x) { return x.nombre; }));
        }
        if (rol === 'coordinador') return perfil.seccion || '';
      } catch (e) { /* sin detalle, la píldora dice solo el papel */ }
      return '';
    }

    /* Pinta la píldora con el papel activo. `alPulsar` es lo que abre:
       el selector de papeles si los hay, y si no la hoja de zonas. */
    async function ponerPildora(perfil, titulo, rol, alPulsar) {
      /* La píldora enseña SOLO el nombre («Andrés»), igual en toda la app
         (portal y panel): el papel ya no se escribe aquí (antes ponía «· Atleta»).
         El cambio de vista es una entrada del menú del avatar. */
      var rolEl = document.getElementById('pt-rol');
      if (rolEl) rolEl.textContent = '';
      var camb = document.getElementById('pt-cambiar');
      if (camb) {
        camb.hidden = false;
        camb.onclick = function () {
          var m = document.getElementById('pt-menu');
          if (m) m.hidden = true;
          var av = document.getElementById('pt-avatar');
          if (av) av.setAttribute('aria-expanded', 'false');
          if (typeof alPulsar === 'function') alPulsar();
        };
      }
      pildoraPuesta = true;
    }

    /* Lo de «o sin cuenta»: el separador, los cuatro accesos públicos y
       «Inscribirme». Se apartan mientras alguien está poniéndose la
       contraseña, porque esa persona YA está dentro y ofrecerle a la vez
       «Inscribirme» solo la hace dudar. */
    function extras(ver) {
      ['.pt-sep', '.pt-publico', '.pt-pie'].forEach(function (s) {
        var e = login.querySelector(s);
        if (e) e.style.display = ver ? '' : 'none';
      });
    }

    /* La dirección completa del portal, calculada desde donde estamos.
       Sirve para que los correos de «contraseña nueva» vuelvan aquí y no
       a la portada de la web, que no sabe qué hacer con ellos. */
    function alPortal() {
      try { return new URL(b + 'portal/', location.href).href; }
      catch (e) { return location.href; }
    }

    function mostrarLogin(m) {
      login.style.display = '';
      var elC = document.getElementById('pt-clave');
      if (elC) elC.hidden = true;
      var elL = document.getElementById('pt-lema');
      if (elL) elL.hidden = false;
      var elT = login.querySelector('h1');
      if (elT) elT.hidden = false;
      extras(true);
      /* Si viene de un enlace que ya no vale, eso manda sobre
         cualquier otro mensaje: es lo que ha pasado de verdad. */
      if (_delEnlace) {
        m = motivoDelEnlace(_delEnlace.codigo);
        _delEnlace = null;
        /* Y se limpia la dirección: si se queda el motivo colgado del
           final, al recargar vuelve a salir «ese enlace ha caducado»
           aunque ya esté pidiendo uno nuevo. */
        try { history.replaceState(null, '', location.pathname + location.search); } catch (e) {}
      }
      if (m) { var e = document.getElementById('pt-msg'); if (e) e.textContent = m; }
    }

    if (!sb || !sb.auth) { mostrarLogin('No se pudo conectar con la base de datos.'); return; }

    /* ==========================================================
       ENTRAR
       ----------------------------------------------------------
       A la vista, correo y contraseña. Debajo, la otra puerta: que
       te manden un enlace al correo. Esa segunda es la de la
       primera vez —cuando todavía no hay ninguna contraseña que
       escribir— y la de quien no se acuerda de la suya.
       ========================================================== */
    var correoEnviado = '';   // a dónde se mandó, para poder repetirlo
    var vecesEnviado = 0;     // para no dejar pedirlo sin parar
    var esperandoHasta = 0;   // hasta cuándo el botón de repetir está dormido

    var elForm     = document.getElementById('pt-form');
    var elEmail    = document.getElementById('pt-email');
    var elPass     = document.getElementById('pt-pass');
    var elEnviar   = document.getElementById('pt-enviar');
    var elMantener = document.getElementById('pt-mantener');
    var elOtra     = document.getElementById('pt-otra');
    var elPedir    = document.getElementById('pt-pedir');
    var elEspera   = document.getElementById('pt-espera');
    var elReenviar = document.getElementById('pt-reenviar');
    var elClave    = document.getElementById('pt-clave');
    var elClave1   = document.getElementById('pt-clave-1');
    var elClaveOk  = document.getElementById('pt-clave-ok');

    /* El botón «Ver» de un campo de contraseña. Escribir a ciegas en un
       móvil pequeño es donde se pierde media hora del club por teléfono. */
    function ojo(campo, boton) {
      if (!campo || !boton) return;
      boton.addEventListener('click', function () {
        var aVerla = campo.type === 'password';
        campo.type = aVerla ? 'text' : 'password';
        boton.textContent = aVerla ? 'Ocultar' : 'Ver';
        boton.setAttribute('aria-pressed', aVerla ? 'true' : 'false');
        boton.setAttribute('aria-label', aVerla ? 'Ocultar la contraseña' : 'Ver la contraseña');
        try { campo.focus(); } catch (e) {}
      });
    }
    ojo(elPass,   document.getElementById('pt-ver'));
    ojo(elClave1, document.getElementById('pt-clave-ver'));

    /* Antes de entrar hay que decir DÓNDE se guarda la sesión, porque
       después ya está guardada. Marcada, sigue viva al cerrar el
       navegador; sin marcar, se va con él. Lo de verdad lo hace db.js. */
    function apuntarMantener() {
      try {
        if (window.APOLANA_SESION) window.APOLANA_SESION.mantener(!!(elMantener && elMantener.checked));
      } catch (e) {}
    }

    /* Se apunta en la cuenta que esta persona YA tiene contraseña, para
       no volver a pedírsela nunca más. No se guarda la contraseña, claro:
       solo un sí. Si falla, no pasa nada grave: como mucho se le volverá
       a ofrecer ponerla la próxima vez que entre por el enlace. */
    function apuntarQueTieneClave(usuario) {
      /* Si ya está apuntado, no se vuelve a escribir: son doscientas
         familias entrando cada día y esto sería una petición de más por
         cada una y cada vez. */
      var d = (usuario && usuario.user_metadata) || null;
      if (d && d.clave_puesta === true) return;
      try { sb.auth.updateUser({ data: { clave_puesta: true } }); } catch (e) {}
    }

    /* Por qué no ha podido entrar, en cristiano. El mensaje que devuelve
       la base viene en inglés y no lo puede leer nadie del club. */
    function porQueNoEntra(err) {
      var m = (err && err.message) || '';
      if (/invalid login credentials|invalid_credentials/i.test(m)) {
        return 'El correo o la contraseña no son correctos. Si es tu primera vez, pídenos un enlace aquí abajo.';
      }
      if (/email not confirmed|not_confirmed/i.test(m)) {
        return 'Todavía no has confirmado el correo. Pídenos un enlace aquí abajo y entrarás.';
      }
      if (/too many|rate limit/i.test(m)) {
        return 'Demasiados intentos seguidos. Espera un minuto y vuelve a probar.';
      }
      return 'No hemos podido entrar. Puede ser tu conexión: vuelve a intentarlo en un momento.';
    }

    /* Un correo con pinta de correo. No vale de nada afinar más: quien
       decide de verdad si existe es la base, y a propósito no lo
       cuenta. Esto solo evita el «no me llega» del que se ha dejado
       la arroba. */
    function pareceCorreo(v) { return /^[^\s@,;]+@[^\s@,;]+\.[a-zA-Z]{2,}$/.test(v); }

    /* Pide el enlace. Conteste lo que conteste, se enseña LO MISMO:
       que el correo va de camino. Da igual que el correo exista o no
       exista, que tenga derecho a entrar o no lo tenga. Es la única
       forma de que nadie pueda averiguar, probando correos, quién
       está apuntado en el club.

       Las únicas dos excepciones son cuando el fallo NO tiene nada
       que ver con el correo que se ha escrito —le pasaría igual a
       cualquiera—, y por eso se pueden contar sin chivar nada:

         'apagado'  el club todavía no ha terminado de configurarlo
                    (a la función le faltan las claves: contesta 503).
         'sinllegar' no se ha podido ni hablar con ella: no hay
                    conexión, o la función no está subida a Supabase.
                    Desde el navegador esos dos casos se ven igual,
                    porque una función que no existe ni llega a
                    contestar con permiso para leer su respuesta.

       Callarse en estos dos casos sería dejar a una familia mirando
       el buzón para siempre. */
    async function pedirEnlace(email) {
      try {
        var r = await sb.functions.invoke('acceso-enlace', { body: { email: email } });
        if (!r || !r.error) return 'enviado';
        var estado = r.error.context && r.error.context.status;
        if (estado === 503) return 'apagado';
        if (!estado) return 'sinllegar';
      } catch (e) { return 'sinllegar'; }
      return 'enviado';
    }

    function verEspera(email) {
      document.getElementById('pt-espera-mail').textContent = email;
      document.getElementById('pt-msg2').textContent = '';
      elForm.hidden = true;
      elOtra.hidden = true;
      elEspera.hidden = false;
      /* «Entra con tu correo y tu contraseña» sobra aquí: lo que toca
         ahora es mirar el buzón, no escribir nada. */
      var elL = document.getElementById('pt-lema');
      if (elL) elL.hidden = true;
      dormirRepetir(45);
    }

    /* El botón de repetir se duerme un rato: el correo tarda, y quien
       lo pulsa tres veces en diez segundos acaba con tres enlaces, de
       los que solo vale el último. Eso confunde más de lo que ayuda. */
    function dormirRepetir(segundos) {
      esperandoHasta = Date.now() + segundos * 1000;
      (function tic() {
        var quedan = Math.ceil((esperandoHasta - Date.now()) / 1000);
        if (quedan > 0) {
          elReenviar.disabled = true;
          elReenviar.textContent = 'Puedes pedirlo otra vez en ' + quedan + ' s';
          setTimeout(tic, 500);
        } else {
          elReenviar.disabled = false;
          elReenviar.textContent = 'No me ha llegado, mándalo otra vez';
        }
      })();
    }

    elReenviar.addEventListener('click', async function () {
      var msg = document.getElementById('pt-msg2');
      msg.className = 'msg';
      /* Tres y se acabó, que es lo mismo que aguanta la base. Al
         cuarto, el problema no es el correo: es el correo. */
      if (vecesEnviado >= 3) {
        msg.textContent = 'Ya van tres. Si no ha llegado, seguramente ese no es el correo que tiene el club. '
          + 'Escribe a escuelaapolana@gmail.com y te damos acceso.';
        return;
      }
      elReenviar.disabled = true;
      msg.textContent = 'Enviando…';
      vecesEnviado++;
      var como = await pedirEnlace(correoEnviado);
      if (como === 'enviado') {
        msg.className = 'msg ok';
        msg.textContent = 'Enviado otra vez a ' + correoEnviado + '.';
      } else {
        msg.textContent = 'No hemos podido enviarlo ahora mismo. Vuelve a probar en un minuto.';
      }
      dormirRepetir(60);
    });

    document.getElementById('pt-otro').addEventListener('click', function () {
      elEspera.hidden = true;
      elForm.hidden = false;
      elOtra.hidden = false;
      var elL = document.getElementById('pt-lema');
      if (elL) elL.hidden = false;
      vecesEnviado = 0;
      elEmail.focus();
    });

    /* ---- La puerta principal: correo y contraseña ---- */
    elForm.addEventListener('submit', async function (e) {
      e.preventDefault();
      var msg = document.getElementById('pt-msg');
      var email = elEmail.value.trim();
      msg.className = 'msg';

      if (!pareceCorreo(email)) {
        msg.textContent = 'Ese correo no está bien escrito. Míralo y vuelve a probar.';
        elEmail.focus();
        return;
      }
      if (!elPass.value) { msg.textContent = 'Escribe tu contraseña.'; elPass.focus(); return; }

      apuntarMantener();
      elEnviar.disabled = true;
      msg.textContent = 'Entrando…';
      var r;
      try { r = await sb.auth.signInWithPassword({ email: email, password: elPass.value }); }
      catch (err) { r = { error: err }; }
      elEnviar.disabled = false;      /* pase lo que pase, se puede volver a probar */
      if (!r || r.error) { msg.textContent = porQueNoEntra(r && r.error); elPass.focus(); return; }
      /* Si ha entrado con contraseña es que la tiene: queda apuntado para
         que la pantalla de «ponte una contraseña» no le salga nunca. */
      apuntarQueTieneClave(r.data && r.data.user);
      /* «Al entrar, abrir en»: si esa persona ha fijado un papel de
         arranque, se le pone ahora; si no, se queda con el último que
         usó. Si falla, se entra con el último y ya está. */
      try { await sb.rpc('rol_al_entrar_aplicar'); } catch (e) {}
      arranque();
    });

    /* ---- La otra puerta: que te manden un enlace al correo ----
       Es la de la primera vez y la del que no se acuerda. Por debajo es
       exactamente lo mismo que había antes: la función `acceso-enlace`,
       que comprueba en el servidor que ese correo esté en la base del
       club y que contesta siempre lo mismo, exista o no exista. */
    elPedir.addEventListener('click', async function () {
      var msg = document.getElementById('pt-msg');
      var email = elEmail.value.trim();
      msg.className = 'msg';
      if (!pareceCorreo(email)) {
        /* ⚠️ La primera vez, aquí es donde se atasca la gente. Llega alguien
           que NO tiene contraseña, ve un formulario de contraseña, encuentra
           este botón, lo pulsa… y le contestaban «escribe tu correo aquí
           arriba» sin decirle dónde es «aquí arriba». Ahora el campo se lleva
           el foco, se rueda hasta él y se marca en ámbar, que es lo que
           convierte una frase en una instrucción. */
        msg.textContent = 'Primero escribe tu correo en la casilla de arriba: el enlace te llega ahí.';
        msg.className = 'msg error';
        try { elEmail.scrollIntoView({ behavior: 'smooth', block: 'center' }); } catch (e) { /* da igual */ }
        elEmail.focus();
        elEmail.classList.add('pt-hay-que-mirar');
        setTimeout(function () { elEmail.classList.remove('pt-hay-que-mirar'); }, 2600);
        return;
      }
      apuntarMantener();
      elPedir.disabled = true;
      msg.textContent = 'Enviando…';
      var como = await pedirEnlace(email);
      elPedir.disabled = false;
      if (como === 'apagado') {
        msg.textContent = 'Enviar el enlace todavía no está activado. '
          + 'Escribe a escuelaapolana@gmail.com y te damos acceso.';
        return;
      }
      if (como === 'sinllegar') {
        msg.textContent = 'No hemos podido enviar el enlace. Mira si tienes conexión y vuelve a probar. '
          + 'Si sigue igual, escribe a escuelaapolana@gmail.com.';
        return;
      }
      msg.textContent = '';
      correoEnviado = email;
      vecesEnviado = 1;
      verEspera(email);
    });

    /* ==========================================================
       PONTE UNA CONTRASEÑA · lo primero al llegar del correo
       ----------------------------------------------------------
       Solo la ve quien acaba de pulsar el enlace y todavía no
       tiene ninguna contraseña, y quien ha pedido cambiarla. A
       quien ya la tiene no se le pregunta nunca.
       ========================================================== */
    async function tocaPonerClave(usuario, recienLlegado) {
      if (!recienLlegado) return false;            /* solo al llegar del correo */
      if (_tipoEnlace === 'recovery') return true; /* la ha pedido cambiar: siempre */
      /* Se lo preguntamos a la base, que es donde está el dato de verdad.
         Antes se adivinaba por una marca que se guarda al ponerla desde la
         web: sirve para quien la puso aquí, pero no para las cuentas a las
         que el club les puso contraseña a mano, que no llevan marca y se
         encontraban pidiéndoles una que ya tenían. */
      try {
        var r = await sb.rpc('tengo_contrasena');
        if (!r.error && typeof r.data === 'boolean') return !r.data;
      } catch (e) { /* sin respuesta, se usa lo de siempre */ }
      var d = (usuario && usuario.user_metadata) || {};
      return d.clave_puesta !== true;
    }

    function pedirClave(email) {
      login.style.display = '';
      elForm.hidden = true;
      elEspera.hidden = true;
      elOtra.hidden = true;
      elClave.hidden = false;
      var elL = document.getElementById('pt-lema');
      if (elL) elL.hidden = true;
      var elT = login.querySelector('h1');
      if (elT) elT.hidden = true;
      extras(false);
      document.getElementById('pt-clave-mail').textContent = email;
      document.getElementById('pt-clave-msg').textContent = '';
      try { elClave1.focus(); } catch (e) {}
    }

    /* Guardada (o ya la tenía): se recoge esta pantalla y sigue el portal
       como si nada. */
    function seguirAlPortal() {
      elClave.hidden = true;
      elClave1.value = '';
      elClave1.type = 'password';
      elForm.hidden = false;
      elOtra.hidden = false;
      var elL = document.getElementById('pt-lema');
      if (elL) elL.hidden = false;
      var elT = login.querySelector('h1');
      if (elT) elT.hidden = false;
      extras(true);
      arranque();
    }

    document.getElementById('pt-clave-form').addEventListener('submit', async function (e) {
      e.preventDefault();
      var msg = document.getElementById('pt-clave-msg');
      var clave = elClave1.value;
      msg.className = 'msg';

      if (clave.length < 6) {
        msg.textContent = 'Un poco más larga: al menos 6 letras o números.';
        elClave1.focus();
        return;
      }

      elClaveOk.disabled = true;
      msg.textContent = 'Guardando…';
      var r;
      try { r = await sb.auth.updateUser({ password: clave, data: { clave_puesta: true } }); }
      catch (err) { r = { error: err }; }
      /* El botón se suelta SIEMPRE, salga bien o salga mal: una pantalla
         que se queda muerta con la contraseña a medias es lo peor que
         puede pasarle aquí a una familia. */
      elClaveOk.disabled = false;

      if (r && r.error) {
        var m = (r.error && r.error.message) || '';
        /* Ya tenía puesta esta misma: no hay nada que cambiar, adentro. */
        if (/same.{0,4}password|should be different/i.test(m)) {
          apuntarQueTieneClave();
          seguirAlPortal();
          return;
        }
        if (/least|short|characters|length|weak/i.test(m)) {
          msg.textContent = 'Hazla un poco más larga y vuelve a pulsar «Guardar y entrar».';
        } else if (/session|jwt|expired|token|not authenticated/i.test(m)) {
          msg.textContent = 'El enlace ha caducado mientras lo hacías. Pídenos otro y lo dejamos hecho.';
        } else {
          msg.textContent = 'No hemos podido guardarla. Puede ser tu conexión: vuelve a pulsar «Guardar y entrar».';
        }
        try { elClave1.focus(); } catch (e) {}
        return;
      }

      seguirAlPortal();
      try { window.APX.toast('Contraseña guardada', null, { detalle: 'La próxima vez entra con tu correo y esta contraseña.' }); } catch (e) {}
    });

    /* Nunca un callejón sin salida: si en ese momento no puede o no
       quiere, se sale y se vuelve a entrar por el enlace otro día. */
    document.getElementById('pt-clave-salir').addEventListener('click', async function () {
      try { await sb.auth.signOut(); } catch (e) {}
      location.reload();
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

    /* --------------------------------------------------------
       LO QUE SE PREGUNTA UNA SOLA VEZ

       Al entrar en el portal se preguntaba dos veces lo mismo: esta
       misma pantalla de acceso pedía las fichas de atleta y los
       grupos para saber qué puertas ofrecer, y acto seguido la
       pantalla de familia (o la de atleta) volvía a pedir
       exactamente eso. Dos viajes a la base para el mismo dato, en
       el momento en que la pantalla todavía está en blanco.

       Ahora se pide UNA vez, aquí, y quien lo necesite lo lee de
       estas dos funciones. La petición sale nada más entrar y no
       espera a nadie: cuando la pantalla la pide, muchas veces ya
       está de vuelta.

       Las dos devuelven siempre { error: sí/no, data: [...] }.
       El `error` importa: una lista vacía porque no hay hijos y una
       lista vacía porque se ha caído la conexión NO se pueden
       contar igual. Con la primera se dice «todavía no hay nadie
       enlazado»; con la segunda, «no hemos podido cargar».

       Las filas que devuelven se comparten con las pantallas: quien
       las lea que NO las modifique. Si necesita cambiar algo (por
       ejemplo añadir los días al nombre del grupo), que se haga una
       copia.
       -------------------------------------------------------- */
    var _atletasProm = null, _gruposProm = null;

    /* Las fichas de atleta que le tocan a quien ha entrado: la suya,
       las de sus hijos y las de los atletas que entrena. Los campos
       son la suma de lo que piden las pantallas de familia y atleta,
       para que a ninguna le falte nada y no tenga que volver a
       preguntar. */
    /* Ninguna consulta puede colgar la app para siempre. Un try/catch NO salva
       de un cuelgue (la promesa nunca resuelve, así que nunca se lanza el
       catch): en móvil, tras cambiar de zona o volver desde la web, una query
       se puede quedar esperando sin fin. Con esto, si en 9 s no responde, se
       resuelve como «error» y la app sigue —vacía o con su aviso—, en vez de
       quedarse cargando eternamente (era la raíz del cuelgue al cambiar de rol). */
    function conTiempo(promesa) {
      return Promise.race([
        Promise.resolve(promesa),
        new Promise(function (res) { setTimeout(function () { res({ error: true, data: [], _tiempo: true }); }, 9000); })
      ]);
    }

    function misAtletas(id) {
      if (_atletasProm) return _atletasProm;
      _atletasProm = (async function () {
        if (!id) return { error: false, data: [] };
        try {
          var r = await conTiempo(sb.from('atletas')
            .select('id,nombre,apellidos,categoria,estado,grupo_id,fecha_nacimiento,tipo_membresia,especialidades,perfil_id,perfil_padre_id,entrenador_id')
            .or('perfil_id.eq.' + id + ',perfil_padre_id.eq.' + id + ',entrenador_id.eq.' + id)
            .order('nombre'));
          if (r && r.error) return { error: true, data: [] };
          return { error: false, data: (r && r.data) || [] };
        } catch (e) { return { error: true, data: [] }; }
      })();
      return _atletasProm;
    }

    /* Todos los grupos del club. Son cuarenta y siete y su lectura es
       pública: cabe entero en una sola petición y así vale para todo
       (saber si esta persona lleva algún grupo, y poner el nombre y el
       horario del grupo de un hijo sin preguntar otra vez). */
    function grupos() {
      if (_gruposProm) return _gruposProm;
      _gruposProm = (async function () {
        try {
          var r = await conTiempo(sb.from('grupos')
            .select('id,nombre,horario,turno,seccion,entrenador_id'));
          if (r && r.error) return { error: true, data: [] };
          return { error: false, data: (r && r.data) || [] };
        } catch (e) { return { error: true, data: [] }; }
      })();
      return _gruposProm;
    }

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

      /* Las fichas y los grupos NO se piden aquí: se piden una sola vez
         al arrancar (ver `misAtletas()` y `grupos()` más abajo) y esta
         función se limita a leer lo que ya viene de camino. */
      var r = await misAtletas(id);
      if (!r.error) {
        r.data.forEach(function (a) {
          if (a.perfil_id === id) esAtleta = true;
          if (a.perfil_padre_id === id) { esFamilia = true; if (a.nombre) hijos.push(a.nombre); }
          if (a.entrenador_id === id) esEntrenador = true;
        });
      }

      var g = await grupos();
      if (!g.error) {
        for (var iG = 0; iG < g.data.length; iG++) {
          if (g.data[iG].entrenador_id === id) { esEntrenador = true; break; }
        }
      }

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
      /* La app se queda con 4 vistas: atleta, entrenador, El Cubo y admin.
         Familia y coordinación se retiran como vistas del portal. */
      var OK4 = ['atleta', 'entrenador', 'cubo', 'admin'];
      return lista.filter(function (p) { return OK4.indexOf(p.clave) !== -1; });
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
          /* El correo tiene que traer de vuelta AL PORTAL: es la única
             pantalla que sabe pedir la contraseña nueva. Si se deja que
             Supabase elija, el enlace acaba en la portada de la web y
             allí no pasa nada, que es lo que pasaba hasta hoy. */
          var r = await sb.auth.resetPasswordForEmail(email, { redirectTo: alPortal() });
          m.textContent = (r && r.error)
            ? 'No se pudo enviar: ' + r.error.message
            : 'Te hemos enviado un correo a ' + email + ' para poner una contraseña nueva.';
        } catch (e) { m.textContent = 'No se pudo enviar el correo.'; }
      });
    }

    /* ¿Queda algún token de sesión guardado en el aparato? Supabase lo guarda
       bajo una clave «sb-…-auth-token». Si NO hay ninguno, de verdad no has
       entrado y el login sale ya, sin esperas. Si SÍ lo hay, aunque getSession
       aún no lo dé, es que está tardando en cargar: se espera. */
    function hayTokenGuardado() {
      function busca(st) {
        try {
          if (!st) return false;
          for (var i = 0; i < st.length; i++) {
            var k = st.key(i);
            if (k && /-auth-token(\.\d+)?$/.test(k) && st.getItem(k)) return true;
          }
        } catch (e) {}
        return false;
      }
      return busca(window.localStorage) || busca(window.sessionStorage);
    }

    async function arranque() {
      /* Ninguna llamada del arranque puede colgar la app: si tarda demasiado se
         resuelve con un valor por defecto y se sigue (login, reintento o zona
         vacía) en vez de quedarse cargando para siempre. Era la raíz del
         cuelgue al volver de la web (la sesión, en mitad de un refresco de
         token, dejaba getSession/la consulta del perfil esperando sin fin). */
      function conLimite(promesa, ms, siTarda) {
        return Promise.race([
          Promise.resolve(promesa),
          new Promise(function (res) { setTimeout(function () { res(siTarda); }, ms || 8000); })
        ]);
      }
      var s = await conLimite(sb.auth.getSession(), 8000, { data: { session: null } });
      if (!s.data || !s.data.session) {
        /* Sin sesión a la primera NO es «no has entrado». Al abrir la app en
           frío, getSession puede tardar en devolver la sesión guardada, y
           enseñar el login ahí provoca el pantallazo de «iniciar sesión» que
           aparece un segundo y luego entra. Así que: si NO hay ni rastro de
           token, login ya; si SÍ lo hay, se espera (refrescando y reintentando
           en silencio, con el login oculto) hasta ~2,5 s antes de rendirse. */
        if (!hayTokenGuardado()) { mostrarLogin(); return; }
        var recuperada = null;
        try {
          var rs = await conLimite(sb.auth.refreshSession(), 8000, { data: { session: null } });
          if (rs && rs.data && rs.data.session) recuperada = rs.data.session;
        } catch (e) { /* seguimos reintentando con getSession */ }
        for (var intento = 0; !recuperada && intento < 12; intento++) {
          await new Promise(function (r) { setTimeout(r, 200); });
          var g = await conLimite(sb.auth.getSession(), 5000, { data: { session: null } });
          if (g.data && g.data.session) recuperada = g.data.session;
        }
        if (!recuperada) { mostrarLogin(); return; }
        s = { data: { session: recuperada } };
      }
      var usuario = s.data.session.user;
      var email = usuario.email;

      /* Quien acaba de entrar pulsando el enlace del correo no ha
         pasado por el formulario, así que aquí es donde le toca el
         «al entrar, abrir en»: si tiene un papel de arranque fijado,
         se le pone antes de pintar nada. Solo la primera vez; al
         recargar la página ya no. */
      var recienLlegado = _acabaDeEntrar;
      if (_acabaDeEntrar) {
        _acabaDeEntrar = false;
        try { await sb.rpc('rol_al_entrar_aplicar'); } catch (e) {}
      }

      /* Y aquí, antes que nada: quien llega del correo y todavía no
         tiene contraseña se pone una. Es lo primero que hace en su vida
         dentro de la app, y no ve el portal hasta que está hecho. Al
         guardarla se vuelve por aquí y esta vez sí se sigue. */
      if (await tocaPonerClave(usuario, recienLlegado)) { pedirClave(email); return; }

      /* SALTO RÁPIDO A TU ZONA — lo que hacía lento abrir la app. La página
         del hub (portal/index.html) solo existe para reenviarte, pero pedía
         perfil, atletas y grupos ANTES de hacerlo, y la pantalla destino
         volvía a pedirlo todo. Si ya sabemos tu zona (la guardó el hub la
         primera vez, por correo), se salta aquí mismo, en cuanto hay sesión
         y sin pedir nada más. Solo en el hub y solo si no acabas de entrar
         por el enlace del correo. Si tienes varios papeles, el recuerdo se
         borra solo y vuelves a ver el hub. */
      /* SALTO DIRECTO DESACTIVADO: el hub siempre se muestra (elegir rol al
         entrar). Antes, al abrir en el hub se saltaba a la zona recordada antes
         de pintar; ese salto provocaba cuelgues/bucles al volver de la web,
         sobre todo en la app instalada. Ahora se entra por el hub, que se pinta
         al instante, y desde ahí se elige. */

      var perfil = null;
      try {
        var r = await conLimite(sb.from('perfiles')
          .select('id,nombre,apellidos,email,rol,roles,rol_activo,seccion,foto_ruta')
          .eq('email', email).maybeSingle(), 8000, { error: true, data: null });
        if (!r.error) perfil = r.data;
      } catch (e) { /* si aún no hay permisos de lectura, perfil queda null */ }

      /* Hay sesión pero la ficha no ha cargado (la consulta se cortó por tiempo
         o falló). Sin ficha, ni la barra ni las pantallas pueden pintarse: en
         vez de petar en blanco, se ofrece recargar (casi siempre lo arregla).
         Antes esto dejaba la app colgada al volver de la web con la sesión en
         mitad de un refresco de token. */
      if (!perfil) {
        login.style.display = 'none';
        var ovF = document.createElement('div');
        ovF.setAttribute('role', 'alert');
        ovF.style.cssText = 'position:fixed;inset:0;z-index:99999;display:flex;flex-direction:column;' +
          'align-items:center;justify-content:center;gap:15px;text-align:center;padding:28px;' +
          'background:var(--app-fondo,#FDFDFB);font-family:inherit;color:#2E4256';
        ovF.innerHTML =
          '<div style="font-family:var(--fuente-titulo,inherit);font-weight:700;text-transform:uppercase;font-size:22px;line-height:1.1">No hemos podido cargar tu ficha</div>' +
          '<div style="max-width:320px;font-size:15px;line-height:1.5;color:#6E6656">Puede ser un tirón de conexión. Vuelve a cargar y suele entrar.</div>' +
          '<button type="button" style="min-height:48px;padding:12px 24px;border:0;border-radius:12px;background:#2E4256;color:#fff;font:inherit;font-weight:600;font-size:15px;cursor:pointer">Volver a cargar</button>';
        ovF.querySelector('button').addEventListener('click', function () { location.reload(); });
        (document.body || document.documentElement).appendChild(ovF);
        return;
      }

      login.style.display = 'none';
      barra(perfil, email);
      if (cont) cont.style.display = '';

      /* Las fichas y los grupos se piden YA, antes de dar paso a la
         pantalla, y en paralelo: así van de camino mientras la
         pantalla se pinta, y cuando ella los pida ya están. Se piden
         una sola vez para toda la página. */
      window.APOLANA_PORTAL.misAtletas = function () { return misAtletas(perfil && perfil.id); };
      window.APOLANA_PORTAL.grupos = grupos;
      misAtletas(perfil && perfil.id);
      grupos();

      /* Los papeles se calculan en paralelo: la promesa está disponible
         desde el primer momento, pero no retrasa el pintado de la página. */
      _papeles = calcularPapeles(perfil);
      window.APOLANA_PORTAL.papeles = function () { return _papeles; };

      /* Auto-arreglo del «salto directo a tu zona» (portal/index.html): si
         resulta que tienes VARIOS papeles, se borra el recuerdo de zona
         única —lo mira cualquier pantalla del portal, no solo el hub—, para
         que la próxima vez que abras la app vuelvas al hub a elegir. Si solo
         tienes uno, no se toca y el salto directo se mantiene. */
      _papeles.then(function (lista) {
        try {
          if (lista && lista.length > 1 && email) localStorage.removeItem('apolana.zona.' + email);
        } catch (e) {}
      }).catch(function () {});

      if (_cb) _cb(sb, perfil);

      /* ------------------------------------------------------------
         LLEVAR LOS RECADOS QUE HAYAN QUEDADO SIN MANDAR
         ------------------------------------------------------------
         La base apunta los toques al móvil —«te han pedido plaza»,
         «tienes plaza»— pero no puede mandarlos ella sola. Los manda
         quien pasa por delante. Las dos pantallas que provocan el
         recado ya lo llevan en el momento; esto es la red de abajo,
         para los que se hayan quedado colgados: los que se decidieron
         de noche y esperan a la mañana, o los de un móvil que se
         quedó sin cobertura en ese segundo.

         Como mucho una vez cada diez minutos por navegador: abrir seis
         pantallas del portal seguidas es una llamada, no seis. Y en
         silencio: si falla, el recado sigue en la cola.
         ------------------------------------------------------------ */
      try { if (sb.functions) window.APOLANA_DB.empujarAvisos(600); } catch (e) { /* nada */ }

      /* ------------------------------------------------------------
         OFRECER LOS AVISOS AL MÓVIL, UNA VEZ
         ------------------------------------------------------------
         Estaban montados enteros y no los tenía nadie: había UN móvil
         dado de alta en toda la base. El botón para activarlos solo
         vive en `portal/avisos/`, y a esa pantalla no llega nadie por
         su cuenta.

         Se ofrece desde AQUÍ y no desde cada pantalla porque este es
         el único sitio por el que pasa todo el mundo, entre a la zona
         que entre. Así también le llega a quien abre directamente su
         zona sin pasar por el vestíbulo.

         No pide el permiso del móvil: pinta una hoja del club que
         explica para qué sirve, y la ventana del sistema solo sale si
         la persona pulsa «Activar los avisos». La hoja se enseña una
         sola vez y ella misma decide si toca (`saludar`, en
         avisos.js).

         El archivo se carga aparte y solo aquí: son unos kilobytes que
         no tienen por qué viajar en cada pantalla del portal.

         El respiro de dos segundos es para que la hoja no compita con
         el primer pintado de la pantalla —y para que, si esta página
         va a mandar a otra zona, salga allí y no aquí—.
         ------------------------------------------------------------ */
      if (perfil) {
        setTimeout(function () {
          function saluda() {
            try { window.APOLANA_AVISOS.saludar({ perfil: perfil }); } catch (e) { /* nada */ }
          }
          if (window.APOLANA_AVISOS && window.APOLANA_AVISOS.saludar) { saluda(); return; }
          var s = document.createElement('script');
          s.src = b + 'assets/js/avisos.js';
          s.onload = saluda;
          s.onerror = function () { /* sin avisos: la pantalla sigue igual */ };
          document.head.appendChild(s);
        }, 2000);
      }

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
        /* Quien no tiene varios papeles concedidos pero SÍ varias zonas
           deducidas de sus datos (ficha propia e hijos, por ejemplo) sigue
           teniendo dónde cambiar: la misma píldora, abriendo la hoja de
           zonas de siempre. Si ya la ha puesto el selector de papeles, que
           es el que trae los pendientes, manda ese y este no la pisa. */
        if (lista.length < 2 || pildoraPuesta) return;
        var actual = papelActivo(lista);
        var zona = lista.filter(function (z) { return z.clave === actual; })[0] || lista[0];
        ponerPildora(perfil, zona.titulo, zona.clave, function () {
          abrirHoja(lista, perfil, email);
        });
      });
    }

    /* ------------------------------------------------------------
       RED DE SEGURIDAD CONTRA EL «BLANCO ETERNO»
       ------------------------------------------------------------
       Al cambiar de rol (o con una red mala) la página a veces se
       queda cargando sin pintar nunca el contenido. Antes se quedaba
       en blanco para siempre. Ahora: si a los 14 s hay sesión guardada
       (o sea, deberías ver tu zona) pero #portal-contenido sigue vacío,
       se ofrece «Volver a cargar». Un observer lo cancela en cuanto
       aparece contenido de verdad, así que no molesta si todo va bien. */
    (function watchdog() {
      if (!cont) return;
      var resuelto = false, obs = null, transicion = null;

      /* Si venimos de «cambiar de vista», la pantalla de transición se enseña
         YA (cubriendo el blanco de la carga) y se retira en cuanto hay
         contenido. Así el cambio de rol es una transición, no un parpadeo. */
      (function pintarTransicion() {
        var quien = null;
        try { quien = sessionStorage.getItem('apolana.cambiando'); sessionStorage.removeItem('apolana.cambiando'); } catch (e) {}
        if (!quien) return;
        transicion = document.createElement('div');
        transicion.setAttribute('role', 'status');
        transicion.style.cssText = 'position:fixed;inset:0;z-index:100000;display:flex;flex-direction:column;' +
          'align-items:center;justify-content:center;gap:18px;text-align:center;padding:28px;' +
          'background:var(--app-fondo,#FDFDFB);font-family:inherit;color:#2E4256';
        transicion.innerHTML =
          '<div style="width:38px;height:38px;border-radius:50%;border:3px solid #E4DCCB;border-top-color:#2E4256;animation:ptSpin .8s linear infinite"></div>' +
          '<div style="font-family:var(--fuente-titulo,inherit);font-weight:700;text-transform:uppercase;font-size:20px;line-height:1.1">' +
            (quien === '1' ? 'Cambiando de vista…' : ('Cargando ' + quien + '…')) + '</div>';
        var st = document.createElement('style');
        st.textContent = '@keyframes ptSpin{to{transform:rotate(360deg)}}';
        document.head.appendChild(st);
        (document.body || document.documentElement).appendChild(transicion);
      })();
      function quitarTransicion() {
        if (transicion && transicion.parentNode) transicion.parentNode.removeChild(transicion);
        transicion = null;
      }

      function hayContenido() {
        try { return cont.getElementsByTagName('*').length > 4; } catch (e) { return true; }
      }
      function hayToken() {
        try {
          var sts = [window.localStorage, window.sessionStorage];
          for (var s = 0; s < sts.length; s++) {
            var st = sts[s]; if (!st) continue;
            for (var i = 0; i < st.length; i++) {
              var k = st.key(i);
              if (k && /-auth-token(\.\d+)?$/.test(k) && st.getItem(k)) return true;
            }
          }
        } catch (e) {}
        return false;
      }
      try {
        obs = new MutationObserver(function () {
          if (hayContenido()) { resuelto = true; if (obs) obs.disconnect(); quitarTransicion(); }
        });
        obs.observe(cont, { childList: true, subtree: true });
      } catch (e) {}
      /* Reinicio del contador anti-bucle del hub, pero SOLO si la página se
         queda quieta 5 s (no en el primer pintado): si en ese rato la pantalla
         salta/recarga, este setTimeout muere con ella y el contador se conserva,
         así el bucle de saltos se corta a los 2 en vez de reiniciarse sin fin. */
      setTimeout(function () {
        try { sessionStorage.removeItem('apolana.zona.salto'); } catch (e) {}
      }, 5000);
      /* Si por lo que sea nunca llega a haber MutationObserver, la transición
         no se queda pegada para siempre: a los 8 s se quita igual. */
      setTimeout(function () { if (hayContenido()) quitarTransicion(); }, 8000);
      setTimeout(function () {
        if (obs) obs.disconnect();
        if (resuelto || hayContenido() || !hayToken()) { quitarTransicion(); return; }
        quitarTransicion();
        var ov = document.createElement('div');
        ov.setAttribute('role', 'alert');
        ov.style.cssText = 'position:fixed;inset:0;z-index:99999;display:flex;flex-direction:column;' +
          'align-items:center;justify-content:center;gap:15px;text-align:center;padding:28px;' +
          'background:var(--app-fondo,#FDFDFB);font-family:inherit;color:#2E4256';
        ov.innerHTML =
          '<div style="font-family:var(--fuente-titulo,inherit);font-weight:700;text-transform:uppercase;font-size:22px;line-height:1.1">La app tarda más de lo normal</div>' +
          '<div style="max-width:320px;font-size:15px;line-height:1.5;color:#6E6656">A veces pasa justo después de cambiar de vista. Vuelve a cargar y ya está.</div>' +
          '<button type="button" style="min-height:48px;padding:12px 24px;border:0;border-radius:12px;background:#2E4256;color:#fff;font:inherit;font-weight:600;font-size:15px;cursor:pointer">Volver a cargar</button>';
        ov.querySelector('button').addEventListener('click', function () { location.reload(); });
        document.body.appendChild(ov);
      }, 14000);
    })();

    arranque();
  });
})();
