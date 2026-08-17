/* ============================================================
   EDITAR LA PÁGINA ENCIMA DE LA PÁGINA · Club Atletismo Apolana
   ------------------------------------------------------------
   QUÉ ES, EN CRISTIANO
   Andrés lo pidió así: «que editar las páginas fuese más fácil, como
   una vista fantasma y poder escribir encima, como WordPress». Esto es
   eso: entras en la web como administración, le das a «Editar», y los
   textos y las fotos de la página se pueden cambiar ahí mismo, viendo
   cómo van a quedar de verdad.

   POR QUÉ SE PUEDE HACER SIN REHACER NADA
   Porque el texto y las fotos de estas páginas YA salían de la base:
   `contenido_secciones` guarda lo que dice cada sección e `imagenes_web`
   qué foto va en cada hueco. Lo que estaba escrito en el HTML es solo
   el respaldo por si la consulta falla. O sea que aquí no se inventa un
   sistema de contenido: se le pone una puerta al que ya había.

   ⚠️ LO QUE ESTO NO ES, Y CONVIENE DECIRLO ANTES DE QUE ALGUIEN LO PIDA
   No es WordPress. No se pueden mover bloques, ni cambiar el diseño, ni
   crear páginas nuevas. Eso en WordPress se puede porque la web ES
   WordPress; ésta está hecha a medida, y por eso va rápida y se ve como
   se ve. Aquí se cambia LO QUE DICE cada hueco, no dónde está.

   ------------------------------------------------------------
   TRES DECISIONES QUE EXPLICAN CÓMO ESTÁ HECHO

   1 · A QUIEN NO ES ADMINISTRACIÓN NO LE CUESTA NADA.
       El archivo se carga en todas las páginas, así que lo primero que
       hace es preguntar `es_admin()`. Si no lo eres —o no hay sesión—
       no pinta nada, no pide nada más y se acaba. Una visita normal no
       nota que esto existe.

   2 · LOS TEXTOS SUELTOS SE ESCRIBEN ENCIMA; LAS LISTAS, EN UN PANEL.
       El título o la entradilla son un texto: se editan en su sitio con
       `contenteditable`, que es lo que pidió. Pero «Servicios» o «Qué
       traer» no son un texto: son una LISTA, y en la base se guardan
       con un elemento por línea. Editar un <ul> a mano con el cursor es
       incómodo y se rompe en cuanto alguien borra un <li>. Así que esas
       se tocan en un panel con un recuadro de texto, una línea por
       punto, que es exactamente como están guardadas.

   3 · GUARDAR ES UN BOTÓN Y NO PASA SOLO.
       Nada se escribe en la base hasta que se pulsa «Guardar». Un
       guardado automático en la web pública significa publicar un
       error de dedo en directo.
   ============================================================ */
(function () {
  'use strict';

  /* Los huecos de texto de una página de sección. El `campo` es la
     columna de `contenido_secciones`; el `tipo` decide cómo se edita. */
  var TEXTOS = [
    { sel: '#cs-eyebrow', campo: 'dirigido_a',        tipo: 'linea',   nombre: 'Rótulo de arriba' },
    { sel: '#cs-titulo',  campo: 'titulo',            tipo: 'linea',   nombre: 'Título' },
    { sel: '#cs-intro',   campo: 'descripcion',       tipo: 'parrafo', nombre: 'Entradilla' },
    { sel: '#cs-servicios',  campo: 'servicios',      tipo: 'lista',   nombre: 'Servicios' },
    { sel: '#cs-compromiso', campo: 'compromisos',    tipo: 'lista',   nombre: '¿A qué te comprometes?' },
    { sel: '#cs-incluye',    campo: 'puntos_destacados', tipo: 'lista', nombre: 'Qué incluye' },

    /* --- LA PORTADA ---
       Usa la misma fila de `contenido_secciones` (seccion = 'home') y las
       mismas columnas, pero con otros nombres en pantalla y otros huecos:
       lo que en una sección es «entradilla», en la portada es el lema bajo
       el titular. Como cada hueco se busca por su selector y el que no está
       se salta, las dos listas pueden convivir en la misma tabla. */
    { sel: '#cs-lema',   campo: 'descripcion', tipo: 'parrafo', nombre: 'Frase bajo el titular' },
    { sel: '#cs-boton',  campo: 'horarios',    tipo: 'linea',   nombre: 'Texto del botón' },
    /* El enlace se pinta con una flecha detrás que NO está en la base. Si se
       editara tal cual, la flecha se guardaría dentro del texto y a la vuelta
       saldrían dos. Se quita al leer y se vuelve a poner al pintar. */
    { sel: '#cs-enlace', campo: 'grupos',      tipo: 'linea',   nombre: 'Enlace de al lado', sufijo: ' →' },
    /* Las tres cifras grandes (420 atletas, 175 socios, 38 años). En la base
       son una línea por cifra, «420 · Atletas»; en pantalla no son una lista
       sino tres bloques con el número y su rótulo aparte. */
    { sel: '#cs-cifras', campo: 'puntos_destacados', tipo: 'lista', nombre: 'Las tres cifras', forma: 'cifras' }
  ];

  var sb = null;
  var seccion = '';
  var editando = false;
  var cambios = {};        // { campo: valorNuevo }
  var cambiosFoto = {};    // { clave: url }
  /* Los huecos sueltos, los que llevan data-texto. Van aparte de
     `cambios` porque no son columnas de una fila: son filas de
     `textos_web`, una por hueco, y se guardan de otra manera. */
  var cambiosSueltos = {};  // { clave: texto }
  var biblioteca = null;   // se pide una sola vez, y solo si hace falta

  // ---------- utilidades ----------
  function $(sel, dentro) { return (dentro || document).querySelector(sel); }
  function esc(t) {
    return String(t == null ? '' : t)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function limpio(t) { return String(t == null ? '' : t).trim(); }

  /* «club.enlace.historia.titulo» → «Enlace · historia · titulo». Es lo
     que sale en el rótulo flotante mientras se edita. No es perfecto,
     pero es infinitamente mejor que enseñar la clave en crudo, y no
     obliga a mantener una lista de nombres a mano que se quedaría vieja
     en cuanto alguien añadiera un hueco. */
  function nombreDeClave(clave) {
    var p = clave.split('.');
    if (p.length > 1) p.shift();          // la primera parte es la página
    var txt = p.join(' · ').replace(/[-_]/g, ' ');
    return txt.charAt(0).toUpperCase() + txt.slice(1);
  }

  /* El texto que ve el usuario dentro de una lista ya pintada, para
     poder rellenar el recuadro con lo que hay ahora mismo en pantalla
     sin volver a pedirlo a la base. */
  function lineasDe(caja, conf) {
    /* Las cifras de la portada no son una lista: son bloques con el número
       en <b> y el rótulo en <span>. Se rehace la línea como está guardada. */
    if (conf && conf.forma === 'cifras') {
      return Array.prototype.map.call(caja.querySelectorAll('.stat'), function (st) {
        var b = st.querySelector('b'), s = st.querySelector('span');
        return limpio((b ? b.textContent : '') + ' · ' + (s ? s.textContent : ''));
      }).filter(Boolean).join('\n');
    }
    var items = caja.querySelectorAll('li');
    if (!items.length) return '';
    return Array.prototype.map.call(items, function (li) {
      /* La marca «✓» es decoración y no forma parte del dato. */
      var m = li.querySelector('.marca');
      if (m) m.remove ? null : null;
      var t = li.textContent.replace(/^\s*[✓·•-]\s*/, '');
      return limpio(t);
    }).filter(Boolean).join('\n');
  }

  // ---------- la barra de abajo ----------
  function barra() {
    var b = document.createElement('div');
    b.className = 'edv-barra';
    b.innerHTML =
      '<span class="edv-que">Estás como administración</span>' +
      '<button type="button" class="edv-btn" id="edv-toggle">Editar esta página</button>' +
      '<button type="button" class="edv-btn edv-btn--guardar" id="edv-guardar" hidden>Guardar</button>' +
      '<button type="button" class="edv-btn edv-btn--texto" id="edv-cancelar" hidden>Cancelar</button>' +
      '<span class="edv-msg" id="edv-msg"></span>';
    document.body.appendChild(b);
    document.body.classList.add('edv-hay-barra');
    return b;
  }

  function aviso(txt, clase) {
    var m = $('#edv-msg');
    if (!m) return;
    m.textContent = txt || '';
    m.className = 'edv-msg' + (clase ? ' ' + clase : '');
  }

  // ---------- encender y apagar el modo edición ----------
  function encender() {
    editando = true;
    document.body.classList.add('edv-editando');
    $('#edv-toggle').textContent = 'Dejar de editar';
    $('#edv-guardar').hidden = false;
    $('#edv-cancelar').hidden = false;
    aviso('Toca cualquier texto o foto marcada para cambiarla.');

    TEXTOS.forEach(function (t) {
      var el = $(t.sel);
      if (!el) return;
      el.classList.add('edv-campo');
      el.setAttribute('data-edv-nombre', t.nombre);
      if (t.tipo === 'lista') {
        el.addEventListener('click', abrirLista);
      } else {
        if (t.sufijo) {
          var sin = limpio(el.textContent);
          if (sin.slice(-t.sufijo.length) === t.sufijo) el.textContent = limpio(sin.slice(0, -t.sufijo.length));
        }
        el.setAttribute('contenteditable', 'plaintext-only');
        el.addEventListener('input', function () { cambios[t.campo] = limpio(el.textContent); marcarSucio(el); });
      }
    });

    /* Los huecos sueltos de las páginas que no son de sección: las
       tarjetas de /club/, las cifras, los rótulos… Cada uno es una fila
       de `textos_web` con su clave, así que aquí no hay que saber nada
       de la página: se editan todos igual.

       Los saltos de línea se guardan como saltos de verdad. Un titular
       partido a mano en el HTML («Un club de<br>socios») se lee aquí
       como dos líneas y se vuelve a partir al pintarlo. */
    document.querySelectorAll('[data-texto]').forEach(function (el) {
      var clave = limpio(el.getAttribute('data-texto'));
      if (!clave) return;
      el.classList.add('edv-campo');
      el.setAttribute('data-edv-nombre', nombreDeClave(clave));
      el.setAttribute('contenteditable', 'plaintext-only');
      el.addEventListener('input', function () {
        cambiosSueltos[clave] = limpio(el.innerText);
        marcarSucio(el);
      });
    });

    /* ⚠️ LA FOTO GRANDE DE ARRIBA NO ES COMO LAS DEMÁS, Y POR ESO NO SE
       PODÍA CAMBIAR. Las fotos normales de la web viven en `imagenes_web`
       y se marcan con `data-img="clave"`. La cabecera de una sección no:
       sale de `contenido_secciones.imagen_url`, la misma fila que su
       texto. Como no lleva `data-img`, el editor pasaba de largo — y es
       justo la que uno quiere cambiar. Andrés: «fotos no puedo cambiar
       desde fantasma».
       Se le pone el botón igual, pero lo que elija va al campo de la
       sección, no a `imagenes_web`. */
    var hero = $('#cs-hero-img') || $('.pag-hero-foto');
    if (hero && hero.tagName === 'IMG') ponerBotonFoto(hero, function (url) {
      cambios.imagen_url = url;
      hero.src = url;
      marcarSucio(hero);
    });

    /* Un hueco de foto no siempre es una <img>. Los retratos de la junta
       que todavía no tienen foto son un recuadro con las iniciales, y ahí
       la foto va de fondo. Andrés lo pilló mirando la página: «no puedo
       cambiar la foto de los que no la tienen puesta, debería poder». Y
       es justo al revés de lo que uno esperaría: los que MENOS foto
       tienen son los que más falta hace poder cambiar. */
    document.querySelectorAll('[data-img]').forEach(function (hueco) {
      var clave = hueco.getAttribute('data-img');
      var esImagen = hueco.tagName === 'IMG';
      ponerBotonFoto(hueco, function (url) {
        cambiosFoto[clave] = url;
        if (esImagen) {
          hueco.src = url;
        } else {
          hueco.style.backgroundImage = 'url("' + url.replace(/"/g, '%22') + '")';
          hueco.style.backgroundSize = 'cover';
          hueco.classList.add('tiene-foto');
        }
        marcarSucio(hueco);
      });
    });
  }

  /* El botón «Cambiar foto» sobre una imagen. `alElegir` decide dónde va
     lo elegido: la cabecera guarda en la ficha de la sección y las demás
     en `imagenes_web`. */
  function ponerBotonFoto(img, alElegir) {
    img.classList.add('edv-foto');
    /* En una <img> el botón va sobre el marco que la contiene. En un hueco
       que lleva la foto de fondo, ese marco ES el hueco: colgarlo del padre
       lo dejaría flotando encima del nombre de la persona. */
    var envoltorio = (img.tagName === 'IMG') ? img.parentElement : img;
    if (!envoltorio || envoltorio.querySelector('.edv-cambiar')) return;
    if (getComputedStyle(envoltorio).position === 'static') envoltorio.style.position = 'relative';
    var b = document.createElement('button');
    b.type = 'button'; b.className = 'edv-cambiar'; b.textContent = 'Cambiar foto';
    b.addEventListener('click', function (ev) { ev.preventDefault(); abrirFotos(alElegir); });
    envoltorio.appendChild(b);
  }

  function apagar(recargar) {
    if (recargar) { location.reload(); return; }
    editando = false;
    cambios = {}; cambiosFoto = {}; cambiosSueltos = {};
    document.body.classList.remove('edv-editando');
    $('#edv-toggle').textContent = 'Editar esta página';
    $('#edv-guardar').hidden = true;
    $('#edv-cancelar').hidden = true;
    aviso('');
    document.querySelectorAll('.edv-campo').forEach(function (el) {
      el.classList.remove('edv-campo', 'edv-sucio');
      el.removeAttribute('contenteditable');
    });
    document.querySelectorAll('.edv-cambiar').forEach(function (b) { b.remove(); });
    document.querySelectorAll('.edv-foto').forEach(function (i) { i.classList.remove('edv-foto', 'edv-sucio'); });
  }

  function marcarSucio(el) { el.classList.add('edv-sucio'); aviso('Hay cambios sin guardar.', 'ojo'); }

  // ---------- panel lateral ----------
  function panel(titulo, cuerpo, alGuardar) {
    cerrarPanel();
    var p = document.createElement('div');
    p.className = 'edv-panel';
    p.innerHTML =
      '<div class="edv-panel-cab"><b>' + esc(titulo) + '</b>' +
        '<button type="button" class="edv-x" aria-label="Cerrar">✕</button></div>' +
      '<div class="edv-panel-cuerpo"></div>' +
      '<div class="edv-panel-pie">' +
        '<button type="button" class="edv-btn edv-btn--guardar edv-ok">Usar esto</button>' +
      '</div>';
    $('.edv-panel-cuerpo', p).appendChild(cuerpo);
    $('.edv-x', p).addEventListener('click', cerrarPanel);
    $('.edv-ok', p).addEventListener('click', function () { alGuardar(); cerrarPanel(); });
    document.body.appendChild(p);
    return p;
  }
  function cerrarPanel() {
    var p = $('.edv-panel');
    if (p) p.remove();
  }

  // ---------- editar una lista ----------
  function abrirLista(ev) {
    if (!editando) return;
    ev.preventDefault();
    var caja = ev.currentTarget;
    var conf = TEXTOS.filter(function (t) { return caja.matches(t.sel); })[0];
    if (!conf) return;

    var cuerpo = document.createElement('div');
    var ta = document.createElement('textarea');
    ta.className = 'edv-area';
    ta.value = (cambios[conf.campo] != null) ? cambios[conf.campo] : lineasDe(caja, conf);
    var pista = document.createElement('p');
    pista.className = 'edv-pista';
    pista.textContent = 'Un punto por línea. Se guarda tal cual lo escribas.';
    cuerpo.appendChild(ta);
    cuerpo.appendChild(pista);

    panel(conf.nombre, cuerpo, function () {
      cambios[conf.campo] = limpio(ta.value);
      repintarLista(caja, limpio(ta.value), conf);
      marcarSucio(caja);
    });
    ta.focus();
  }

  /* ⚠️ LA VISTA PREVIA CLONA LO QUE HAY; NO MONTA <li> A MANO.
     La primera versión repintaba con `'<li>'+texto+'</li>'`, y eso se
     cargaba el «✓» de Servicios y las clases de cada punto: escribías
     una línea nueva y el resto perdía la marca. Lo vio Andrés a la
     primera, escribiendo «hola» para probar.

     El motivo de fondo es que cada bloque tiene su propia forma —
     Servicios lleva `<span class="marca">✓</span>` y `<span
     class="texto">`, Compromisos es un punto pelado— y esto no puede
     saberlas todas. Así que no las adivina: coge el primer <li> como
     molde, lo clona por cada línea y solo le cambia el texto. Lo que
     traiga puesto ese molde se mantiene, sea lo que sea.

     Es una vista previa: lo que se guarda de verdad es `cambios`. */
  function repintarLista(caja, texto, conf) {
    if (conf && conf.forma === 'cifras') {
      var molde0 = caja.querySelector('.stat');
      if (!molde0) return;
      molde0 = molde0.cloneNode(true);
      caja.textContent = '';
      texto.split('\n').map(limpio).filter(Boolean).forEach(function (l) {
        var st = molde0.cloneNode(true);
        var par = l.split('·');
        var b = st.querySelector('b'), s = st.querySelector('span');
        if (b) { b.textContent = limpio(par[0]); b.removeAttribute('data-desde'); }
        /* El rótulo se enseña en minúscula aunque en el panel se escriba con
           mayúscula: es una etiqueta, no un título. Igual que al cargar. */
        if (s) s.textContent = limpio(par.slice(1).join('·')).toLowerCase();
        caja.appendChild(st);
      });
      return;
    }
    var ul = caja.querySelector('ul') || caja;
    var molde = ul.querySelector('li');
    var lineas = texto.split('\n').map(limpio).filter(Boolean);
    if (!molde) {
      ul.innerHTML = lineas.map(function (l) { return '<li>' + esc(l) + '</li>'; }).join('');
      return;
    }
    molde = molde.cloneNode(true);
    ul.textContent = '';
    lineas.forEach(function (l) {
      var li = molde.cloneNode(true);
      /* El texto vive en `.texto` si el bloque lo separa de la marca; si
         no, es el propio <li>. Se cambia SOLO eso. */
      var donde = li.querySelector('.texto');
      if (donde) donde.textContent = l;
      else li.textContent = l;
      ul.appendChild(li);
    });
  }

  // ---------- cambiar una foto ----------
  async function abrirFotos(alElegir) {
    var cuerpo = document.createElement('div');
    cuerpo.innerHTML = '<p class="edv-pista">Cargando la biblioteca…</p>';
    var elegida = { url: '' };

    panel('Elegir foto', cuerpo, function () {
      if (elegida.url) alElegir(elegida.url);
    });

    if (!biblioteca) {
      var r = await sb.from('biblioteca_fotos')
        .select('id,ruta,titulo,nombre,publicada_ruta')
        .order('created_at', { ascending: false }).limit(60);
      biblioteca = (r && !r.error && r.data) ? r.data : [];
    }
    if (!biblioteca.length) {
      cuerpo.innerHTML = '<p class="edv-pista">No hay fotos en la biblioteca todavía. ' +
        'Súbelas desde <a href="' + (window.APOLANA_BASE || '../') + 'admin/biblioteca/">Biblioteca</a>.</p>';
      return;
    }
    cuerpo.innerHTML = '<div class="edv-fotos"></div>' +
      '<p class="edv-pista">Las 60 últimas de la biblioteca. Para subir una nueva, ' +
      '<a href="' + (window.APOLANA_BASE || '../') + 'admin/biblioteca/">ve a Biblioteca</a>.</p>';
    var rej = $('.edv-fotos', cuerpo);
    biblioteca.forEach(function (f) {
      var url = window.APOLANA_IMG ? window.APOLANA_IMG(f.publicada_ruta || f.ruta) : '';
      if (!url) return;
      var b = document.createElement('button');
      b.type = 'button'; b.className = 'edv-mini';
      b.title = f.titulo || f.nombre || '';
      b.innerHTML = '<img src="' + esc(url) + '" alt="" loading="lazy">';
      b.addEventListener('click', function () {
        rej.querySelectorAll('.edv-mini').forEach(function (x) { x.classList.remove('sel'); });
        b.classList.add('sel');
        elegida.url = url;
      });
      rej.appendChild(b);
    });
  }

  var SIN_PERMISO = 'la base no ha dejado guardar. Suele ser que la sesión ha caducado: ' +
                    'entra otra vez en el panel y vuelve a probar.';

  // ---------- guardar ----------
  async function guardar() {
    var nTex = Object.keys(cambios).length, nFot = Object.keys(cambiosFoto).length;
    var nSue = Object.keys(cambiosSueltos).length;
    if (!nTex && !nFot && !nSue) { aviso('No has cambiado nada.'); return; }
    var boton = $('#edv-guardar');
    boton.disabled = true;
    aviso('Guardando…');
    try {
      /* ⚠️ NO BASTA CON QUE NO HAYA ERROR: HAY QUE MIRAR CUÁNTAS FILAS
         CAMBIARON. Esta es la trampa de las reglas de acceso de Postgres,
         y me pilló de lleno: un UPDATE que la regla NO permite no da
         error —da cero filas y éxito—. La primera versión decía
         «Guardado» y recargaba la página, y como al recargar volvía a
         salir el texto de antes, parecía que se había perdido.
         Pasó de verdad: Andrés guardó, la base seguía con el texto del 2
         de agosto y la pantalla le había dicho que sí.
         Con `.select()` la respuesta trae las filas tocadas, y si vienen
         cero se dice lo que pasa de verdad. */
      if (nTex) {
        if (!seccion) throw new Error('esta página no tiene sección');
        var r = await sb.from('contenido_secciones')
          .update(cambios).eq('seccion', seccion).select('seccion');
        if (r.error) throw r.error;
        if (!r.data || !r.data.length) throw new Error(SIN_PERMISO);
      }
      for (var clave in cambiosFoto) {
        var r2 = await sb.from('imagenes_web')
          .update({ url: cambiosFoto[clave] }).eq('clave', clave).select('clave');
        if (r2.error) throw r2.error;
        if (!r2.data || !r2.data.length) throw new Error(SIN_PERMISO);
      }
      /* `upsert` y no `update`: la fila puede no existir todavía. El
         hueco vive en el HTML desde el primer día y la fila solo nace
         cuando alguien escribe ahí por primera vez — así la tabla no se
         llena de claves vacías esperando a que alguien las use. */
      if (nSue) {
        var filas = Object.keys(cambiosSueltos).map(function (clave) {
          return { clave: clave, texto: cambiosSueltos[clave], pagina: clave.split('.')[0] };
        });
        var r3 = await sb.from('textos_web')
          .upsert(filas, { onConflict: 'clave' }).select('clave');
        if (r3.error) throw r3.error;
        if (!r3.data || r3.data.length !== filas.length) throw new Error(SIN_PERMISO);
      }
      aviso('Guardado. Recargando para verlo como queda…', 'ok');
      setTimeout(function () { location.reload(); }, 900);
    } catch (e) {
      aviso('No se ha podido guardar: ' + (e.message || e), 'mal');
      boton.disabled = false;
    }
  }

  // ---------- estilos ----------
  var CSS = [
    '.edv-barra{position:fixed;left:0;right:0;bottom:0;z-index:9000;display:flex;align-items:center;gap:10px;',
      'padding:10px clamp(12px,3vw,24px);background:#2E4256;color:#fff;',
      'font-family:var(--fuente-texto,system-ui);font-size:14px;flex-wrap:wrap;',
      'box-shadow:0 -6px 20px -12px rgba(0,0,0,.5)}',
    '.edv-hay-barra{padding-bottom:64px}',
    '.edv-que{opacity:.72;flex:1;min-width:120px}',
    '.edv-btn{min-height:40px;padding:0 16px;border-radius:999px;border:1px solid rgba(255,255,255,.4);',
      'background:transparent;color:#fff;font:inherit;font-weight:600;cursor:pointer}',
    '.edv-btn:hover{background:rgba(255,255,255,.14)}',
    '.edv-btn--guardar{background:#3B85C0;border-color:#3B85C0}',
    '.edv-btn--guardar:hover{background:#2F6FA8}',
    '.edv-btn--texto{border-color:transparent;opacity:.8}',
    '.edv-msg{flex-basis:100%;font-size:13px;opacity:.85}',
    '.edv-msg.ok{color:#9BD3A8}.edv-msg.mal{color:#F0B4AE}.edv-msg.ojo{color:#F3D08A}',
    /* Lo editable se marca con un trazo discontinuo: se ve que se puede
       tocar sin cambiar cómo está maquetado. */
    '.edv-editando .edv-campo{outline:2px dashed rgba(59,133,192,.75);outline-offset:4px;',
      'border-radius:4px;cursor:text;position:relative}',
    '.edv-editando .edv-campo:hover{outline-color:#3B85C0;background:rgba(59,133,192,.06)}',
    '.edv-editando .edv-sucio{outline-color:#B96F09;outline-style:solid}',
    '.edv-cambiar{position:absolute;left:8px;bottom:8px;z-index:20;min-height:34px;padding:0 12px;',
      'border-radius:999px;border:0;background:rgba(46,66,86,.92);color:#fff;font:inherit;font-size:13px;',
      'font-weight:600;cursor:pointer}',
    '.edv-cambiar:hover{background:#2E4256}',
    /* El panel entra DESLIZÁNDOSE desde el borde derecho, que es de donde
       viene. Antes aparecía de golpe y no se entendía de dónde salía: la
       curva y el lado son toda la explicación que hace falta.
       `@starting-style` para que anime al entrar sin necesitar JS, y la
       curva es la de cajones de la casa. */
    '.edv-panel{position:fixed;right:0;top:0;bottom:0;width:min(420px,92vw);z-index:9100;background:#fff;',
      'display:flex;flex-direction:column;box-shadow:-10px 0 30px -18px rgba(0,0,0,.5);',
      'font-family:var(--fuente-texto,system-ui);',
      'transform:translateX(0);opacity:1;',
      'transition:transform 280ms var(--ease-panel,cubic-bezier(.32,.72,0,1)),opacity 200ms ease}',
    '@starting-style{.edv-panel{transform:translateX(100%);opacity:0}}',
    '@media (prefers-reduced-motion:reduce){.edv-panel{transition-duration:80ms}}',
    '.edv-panel-cab{display:flex;align-items:center;justify-content:space-between;gap:12px;',
      'padding:14px 16px;border-bottom:1px solid #E4DCCB;font-size:16px;color:#2E4256}',
    '.edv-x{border:0;background:none;font-size:16px;cursor:pointer;color:#6B6558;min-height:40px;min-width:40px}',
    '.edv-panel-cuerpo{flex:1;overflow:auto;padding:16px}',
    '.edv-panel-pie{padding:14px 16px;border-top:1px solid #E4DCCB;display:flex;justify-content:flex-end}',
    '.edv-panel-pie .edv-btn{color:#fff}',
    '.edv-area{width:100%;min-height:220px;box-sizing:border-box;padding:12px;border:1px solid #E0D8C8;',
      'border-radius:10px;font:inherit;font-size:15px;line-height:1.6;color:#2E4256;resize:vertical}',
    '.edv-pista{margin:10px 0 0;font-size:13px;color:#6B6558;line-height:1.5}',
    '.edv-fotos{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}',
    '.edv-mini{padding:0;border:2px solid transparent;border-radius:10px;overflow:hidden;background:#F1EADC;',
      'cursor:pointer;aspect-ratio:1;display:block}',
    '.edv-mini img{width:100%;height:100%;object-fit:cover;display:block}',
    '.edv-mini.sel{border-color:#3B85C0}'
  ].join('');

  function ponerEstilos() {
    if (document.getElementById('edv-estilos')) return;
    var s = document.createElement('style');
    s.id = 'edv-estilos'; s.textContent = CSS;
    document.head.appendChild(s);
  }

  // ---------- arranque ----------
  async function arranca() {
    var pagina = document.querySelector('[data-seccion]');
    seccion = pagina ? limpio(pagina.getAttribute('data-seccion')) : '';
    /* Sin sección y sin fotos gestionables, aquí no hay nada que editar. */
    /* Una página entra en el editor si tiene ficha de sección, fotos
       cambiables o huecos sueltos. Antes solo valían las dos primeras, y
       por eso /club/ o /familias/ no tenían ni el botón. */
    if (!seccion && !document.querySelector('img[data-img]')
        && !document.querySelector('[data-texto]')) return;

    sb = window.APOLANA_DB;
    if (!sb || typeof sb.from !== 'function' || !sb.auth) return;

    /* ⚠️ LA PUERTA. Si no hay sesión no se pregunta nada más: una visita
       normal no debe gastar ni una llamada en esto. */
    var ses = await sb.auth.getSession();
    if (!ses || !ses.data || !ses.data.session) return;
    var r = await sb.rpc('es_admin');
    if (r.error || !r.data) return;

    ponerEstilos();
    barra();
    $('#edv-toggle').addEventListener('click', function () { editando ? apagar(false) : encender(); });

    /* Se llega aquí desde «Páginas» del panel, que abre la página con
       ?editar=1. Sin esto habría que darle a «Editar» otra vez nada más
       llegar, que es justo el paso que se quería quitar. La marca se borra
       de la barra de direcciones para que al recargar o al compartir el
       enlace no arranque en modo edición sin querer. */
    try {
      var url = new URL(window.location.href);
      if (url.searchParams.get('editar') === '1') {
        encender();
        url.searchParams.delete('editar');
        history.replaceState(null, '', url.pathname + (url.search || '') + url.hash);
      }
    } catch (e) { /* navegador sin URL(): se entra a mano y ya está */ }
    $('#edv-guardar').addEventListener('click', guardar);
    $('#edv-cancelar').addEventListener('click', function () {
      if (Object.keys(cambios).length || Object.keys(cambiosFoto).length
          || Object.keys(cambiosSueltos).length) apagar(true);
      else apagar(false);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { setTimeout(arranca, 400); });
  } else {
    setTimeout(arranca, 400);
  }
})();

/* ============================================================
   LO QUE FALTA, Y SE SABE
   ------------------------------------------------------------
   · Subir una foto nueva desde aquí. Ahora se elige de la biblioteca;
     para subir hay que ir a /admin/biblioteca/. Se puede añadir, pero
     subir al almacén desde esta pantalla necesita su propio cuidado con
     los tamaños y no es lo que se pidió primero.
   · El encuadre y el zoom de la foto siguen ajustándose en
     /admin/imagenes/. Aquí se elige CUÁL, no CÓMO se recorta.
   · Solo funciona en las páginas de sección, que son las que tienen
     `data-seccion` y sacan su texto de `contenido_secciones`. La
     portada y las páginas sueltas llevan el texto en el HTML, y eso no
     se puede editar desde el navegador: habría que moverlo a la base
     primero.
   ============================================================ */
