/* ============================================================
   CÓMO SE PAGA · Club Atletismo Apolana
   ------------------------------------------------------------
   QUÉ RESUELVE
   Hasta ahora, en el portal se veían los recibos pendientes pero
   no se decía en ninguna parte cómo ni dónde pagarlos. Este
   archivo pinta el bloque «Cómo se paga» que va debajo de los
   recibos en las tres zonas donde se ven: la del atleta, la de la
   familia y la del socio. Al estar aquí y no repetido en cada
   página, cualquier arreglo o cambio de texto entra en las tres a
   la vez.

   ⚠️ DE DÓNDE SALEN LOS DATOS (y por qué)
   El número de cuenta, el titular y el resto NO están escritos en
   este archivo ni en ningún otro del repositorio: el repositorio
   de la web es PÚBLICO. Viven en la tabla `info_pagos` de la base
   de datos (migración 052), que solo pueden leer los usuarios con
   sesión iniciada. Un visitante sin cuenta no ve nada de esto,
   porque la propia base de datos se lo niega.
   Si alguna vez hay que cambiar un dato bancario: se cambia en el
   panel (Cobros → «Cómo se paga»), nunca aquí.

   CÓMO SE USA (en la página que lo pinta):
     await APOLANA_INFO_PAGOS.cargar(sb);              // lee la tabla
     var clave = APOLANA_INFO_PAGOS.claveDe(atleta);   // 'escuela' | 'club' | null
     cont.innerHTML = APOLANA_INFO_PAGOS.bloque({
       clave: clave,          // qué cuenta enseñar; null = las dos
       pendientes: 2,         // recibos sin cobrar (0 → bloque discreto)
       devueltos: 1,          // recibos impagados o devueltos
       plegado: false         // forzar plegado o desplegado
     });
     APOLANA_INFO_PAGOS.activar(cont);                 // botones de copiar

   Requiere supabase-js y db.js cargados antes. `datos.js` es
   opcional: si está, el contacto general del club sale de ahí
   (fuente única de la verdad); si no, se enlaza a /contacto/.
   ============================================================ */
(function () {
  'use strict';

  var FILAS = null;      // caché de la consulta: una sola por página
  var CARGANDO = null;

  function esc(s) {
    var d = document.createElement('div');
    d.textContent = (s == null ? '' : String(s));
    return d.innerHTML;
  }
  function escA(s) { return esc(s).replace(/"/g, '&quot;'); }
  function limpio(s) { return (s == null ? '' : String(s)).trim(); }

  /* ------------------------------------------------------------
     ESCUELA O CLUB · a quién le toca cada cuenta
     Es el mismo criterio que ya usa el panel de atletas y el de
     informes, para que no haya dos verdades: manda lo que el club
     haya fijado a mano en la ficha (tipo_membresia) y, si está en
     blanco, se deduce por el año de nacimiento (2009 o después =
     escuela). Si no hay ni una cosa ni la otra, devuelve null y la
     pantalla enseña las dos cuentas con su título, que es mejor
     que arriesgarse a enseñar la equivocada.
     ------------------------------------------------------------ */
  var ANIO_CORTE_ESCUELA = 2009;
  function claveDe(a) {
    if (!a) return null;
    if (a.tipo_membresia === 'escuela') return 'escuela';
    if (a.tipo_membresia === 'socio') return 'club';
    var y = parseInt(String(a.fecha_nacimiento || '').slice(0, 4), 10);
    if (!y) return null;
    return y >= ANIO_CORTE_ESCUELA ? 'escuela' : 'club';
  }
  /* Varias personas a la vez (una familia, un hogar): si todas van a
     la misma cuenta, esa; si están repartidas o no se sabe, null. */
  function claveDeVarios(lista) {
    var vistas = {}, n = 0;
    (lista || []).forEach(function (a) {
      var k = claveDe(a);
      if (k && !vistas[k]) { vistas[k] = 1; n++; }
    });
    if (n !== 1) return null;
    for (var k in vistas) { if (vistas.hasOwnProperty(k)) return k; }
    return null;
  }

  /* ------------------------------------------------------------
     LA CONSULTA
     Si falla (sin permisos, sin internet) o la tabla está vacía,
     devuelve una lista vacía y el bloque sencillamente no se pinta:
     nunca se enseña información de pago a medias.
     ------------------------------------------------------------ */
  function cargar(sb) {
    if (FILAS) return Promise.resolve(FILAS);
    if (CARGANDO) return CARGANDO;
    CARGANDO = (async function () {
      try {
        var r = await sb.from('info_pagos')
          .select('clave,titulo,titular,iban,banco,metodo,cuando,otros_pagos,' +
                  'concepto_transferencia,ejemplos_concepto,texto_devuelto,' +
                  'contacto_nombre,contacto_tel,contacto_email,' +
                  'contacto_alt_nombre,contacto_alt_tel,contacto_alt_email,nota,orden')
          .eq('activo', true)
          .order('orden', { ascending: true });
        FILAS = (r && !r.error && r.data) ? r.data : [];
      } catch (e) { FILAS = []; }
      return FILAS;
    })();
    return CARGANDO;
  }

  /* ------------------------------------------------------------
     PRESENTACIÓN DEL NÚMERO DE CUENTA
     Se enseña en grupos de cuatro, como lo escriben los bancos, que
     es la única forma de comprobarlo a ojo sin equivocarse. Lo que
     se COPIA, en cambio, va sin espacios: es como lo quieren las
     aplicaciones del banco.
     ------------------------------------------------------------ */
  function ibanCompacto(v) { return limpio(v).replace(/\s+/g, '').toUpperCase(); }
  function ibanBonito(v) {
    var c = ibanCompacto(v);
    return c ? c.replace(/(.{4})/g, '$1 ').trim() : '';
  }

  /* Un ejemplo por línea, sin líneas en blanco ni viñetas de más. */
  function lineas(txt) {
    return limpio(txt).split('\n')
      .map(function (l) { return l.replace(/^[-·•*]\s*/, '').trim(); })
      .filter(Boolean);
  }

  /* Botón de copiar: siempre 44 px de alto, con su confirmación. */
  function botonCopiar(valor, queEs) {
    /* Icono del juego del kit (30a): lienzo 24, trazo 1,9, sin relleno */
    var ic = '<svg class="ipg-c-ic" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
             'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
             '<rect x="8" y="8" width="12" height="13" rx="2.5"/><path d="M16 5.5H6.5A2.5 2.5 0 004 8v9.5"/></svg>';
    return '<button type="button" class="ipg-copiar" data-copiar="' + escA(valor) + '"' +
           ' aria-label="Copiar ' + escA(queEs || '') + '">' + ic +
           '<span class="ipg-c-txt">Copiar</span></button>';
  }

  /* ------------------------------------------------------------
     EL CONTACTO PARA DUDAS
     Primero quien lleva los pagos, luego el segundo escalón
     (responsable de sección o presidencia) y, si el club no ha
     rellenado ninguno, el contacto general que ya está publicado
     en la web (datos.js). Así nunca hace falta inventarse un
     teléfono ni dejarlo escrito en el código.
     ------------------------------------------------------------ */
  function persona(nombre, tel, mail) {
    nombre = limpio(nombre); tel = limpio(tel); mail = limpio(mail);
    if (!nombre && !tel && !mail) return '';
    var vias = [];
    if (tel) vias.push('<a href="tel:' + escA(tel.replace(/\s+/g, '')) + '">' + esc(tel) + '</a>');
    if (mail) vias.push('<a href="mailto:' + escA(mail) + '">' + esc(mail) + '</a>');
    return '<span class="ipg-persona">' +
      (nombre ? '<b>' + esc(nombre) + '</b>' : '') +
      (vias.length ? '<span>' + vias.join(' · ') + '</span>' : '') +
      '</span>';
  }

  function contactoGeneral(clave, base) {
    var d = (window.APOLANA && window.APOLANA.contacto) || null;
    var enlaceContacto = '<a href="' + base + 'contacto/">Escribir al club</a>';
    if (!d) return enlaceContacto;
    var t = (clave === 'escuela') ? d.tel_escuela : d.tel_socios;
    var vias = [];
    if (t && t.tel) vias.push('<a href="tel:' + escA(t.tel) + '">' + esc(t.texto) + '</a>');
    if (d.email) vias.push('<a href="mailto:' + escA(d.email) + '">' + esc(d.email) + '</a>');
    return vias.length ? vias.join(' · ') : enlaceContacto;
  }

  /* ------------------------------------------------------------
     UNA CUENTA, PINTADA
     ------------------------------------------------------------ */
  function unaCuenta(f, opts) {
    var base = opts.base;
    var conTitulo = opts.conTitulo;
    var h = '';

    if (conTitulo) h += '<h4 class="ipg-cuenta-tit">' + esc(f.titulo || f.clave) + '</h4>';

    /* 1 · La cuota: método y calendario. Es lo primero que se pregunta. */
    var metodo = limpio(f.metodo);
    var cuando = limpio(f.cuando);
    if (metodo || cuando) {
      h += '<div class="ipg-linea">' +
        '<span class="ipg-et">La cuota</span>' +
        '<span class="ipg-val">' +
          (metodo ? '<b>' + esc(metodo) + '</b>' : '') +
          (cuando ? '<span class="ipg-sub">' + esc(cuando) + '</span>' : '') +
        '</span></div>';
    }

    /* 2 · Lo que no es la cuota: licencia, ropa, bonos… Aquí es donde
       hace falta el número de cuenta, y por eso va con su botón. */
    var iban = ibanCompacto(f.iban);
    var otros = limpio(f.otros_pagos);
    var ejemplos = lineas(f.ejemplos_concepto);
    if (iban || otros || ejemplos.length) {
      /* La etiqueta va corta y fija; lo que el club escriba en «otros pagos»
         se lee como una frase normal, no como un pie de página diminuto. */
      h += '<div class="ipg-transf">' +
        '<span class="ipg-et">Lo que no es la cuota</span>' +
        '<p class="ipg-otros">' + esc(otros ||
          'La licencia federativa, la ropa y los bonos se pagan aparte, por transferencia o con tarjeta.') + '</p>';

      if (limpio(f.titular)) {
        h += '<div class="ipg-dato"><span class="ipg-d-et">A nombre de</span>' +
             '<span class="ipg-d-val">' + esc(f.titular) + '</span></div>';
      }
      if (iban) {
        h += '<div class="ipg-dato ipg-dato--cuenta"><span class="ipg-d-et">Número de cuenta</span>' +
             '<span class="ipg-d-val ipg-iban">' + esc(ibanBonito(f.iban)) + '</span>' +
             botonCopiar(iban, 'el número de cuenta') + '</div>';
      }
      if (limpio(f.banco)) {
        h += '<div class="ipg-dato"><span class="ipg-d-et">Banco</span>' +
             '<span class="ipg-d-val">' + esc(f.banco) + '</span></div>';
      }
      if (ejemplos.length) {
        h += '<div class="ipg-conceptos">' +
          '<span class="ipg-d-et">' + esc(limpio(f.concepto_transferencia) ||
            'Pon esto en el concepto, según para qué sea el pago') + '</span>' +
          '<ul class="ipg-lista">' + ejemplos.map(function (e) {
            return '<li><span class="ipg-ej">' + esc(e) + '</span>' + botonCopiar(e, 'el concepto') + '</li>';
          }).join('') + '</ul>' +
          '<p class="ipg-pista">Cambia «nombre» por el nombre y los apellidos de quien entrena: es lo que nos deja cuadrar el pago con la persona.</p>' +
        '</div>';
      }
      h += '</div>';
    }

    if (limpio(f.nota)) h += '<p class="ipg-nota">' + esc(f.nota) + '</p>';

    /* 3 · Recibo devuelto. Solo se enseña a quien tiene un recibo sin
       cobrar: al resto no le hace falta y solo mete ruido. */
    if (opts.devueltos > 0) {
      var txt = limpio(f.texto_devuelto) ||
        'Si el banco ha devuelto tu recibo, no pasa nada: te escribimos para ver qué ha podido ser y ' +
        'lo arreglamos de una de estas dos maneras, la que te venga mejor: volvemos a pasar el recibo, ' +
        'o lo pagas por transferencia a la cuenta de arriba.';
      h += '<div class="ipg-devuelto">' +
        '<span class="ipg-dv-tit">¿Te ha vuelto un recibo?</span>' +
        '<p>' + esc(txt) + '</p>' +
        '<a class="ipg-dv-btn" href="' + base + 'contacto/">Contar qué ha pasado</a>' +
      '</div>';
    }

    /* 4 · A quién preguntar. */
    var p1 = persona(f.contacto_nombre, f.contacto_tel, f.contacto_email);
    var p2 = persona(f.contacto_alt_nombre, f.contacto_alt_tel, f.contacto_alt_email);
    h += '<div class="ipg-contacto"><span class="ipg-et">Dudas con un pago</span>' +
      ((p1 || p2)
        ? '<span class="ipg-val">' + p1 + p2 + '</span>'
        : '<span class="ipg-val">' + contactoGeneral(f.clave, base) + '</span>') +
      '</div>';

    return h;
  }

  /* ------------------------------------------------------------
     EL BLOQUE ENTERO
     ------------------------------------------------------------ */
  function bloque(o) {
    o = o || {};
    var filas = FILAS || [];
    if (!filas.length) return '';                 // sin datos cargados, no se pinta nada

    var base = o.base || window.APOLANA_BASE || '../../';
    var pendientes = o.pendientes || 0;
    var devueltos = o.devueltos || 0;

    /* Qué cuenta enseñar. Si no se sabe de quién es, se enseñan las
       dos con su título: mejor dos que la equivocada. */
    var elegidas = [];
    if (o.clave) elegidas = filas.filter(function (f) { return f.clave === o.clave; });
    if (!elegidas.length) elegidas = filas;
    var conTitulo = elegidas.length > 1;

    var cuerpo = elegidas.map(function (f) {
      return '<div class="ipg-cuenta">' +
        unaCuenta(f, { base: base, conTitulo: conTitulo, devueltos: devueltos }) +
        '</div>';
    }).join('');

    /* La línea de futuro: sin prometer fechas. */
    cuerpo += '<p class="ipg-futuro">Más adelante se podrá pagar directamente desde la app, ' +
      'sin salir de tu zona. Cuando esté, lo verás aquí.</p>';

    /* Con recibos pendientes el bloque va abierto y con voz; al día,
       se queda plegado en una línea para no dar la matraca. */
    var abierto = (o.plegado === false) || (o.plegado == null && pendientes > 0);
    var resumen = pendientes > 0
      ? (pendientes === 1 ? 'Tienes 1 recibo por cobrar' : 'Tienes ' + pendientes + ' recibos por cobrar')
      : 'Domiciliación, transferencias y a quién preguntar';

    /* `margen:false` lo deja pegado, para cuando ya va dentro de una lista
       que reparte ella misma la separación (la del socio, por ejemplo). */
    return '<details class="ipg' + (o.margen === false ? ' ipg--pegado' : '') + '" ' + (abierto ? 'open' : '') + '>' +
      '<summary class="ipg-cab">' +
        '<span class="ipg-cab-txt"><b>Cómo se paga</b><small>' + esc(resumen) + '</small></span>' +
        '<span class="ipg-cab-fl" aria-hidden="true"></span>' +
      '</summary>' +
      '<div class="ipg-cuerpo">' + cuerpo + '</div>' +
      '<span class="ipg-vivo" role="status" aria-live="polite"></span>' +
    '</details>';
  }

  /* ------------------------------------------------------------
     LOS BOTONES DE COPIAR
     Confirman a la vista (el botón se pone verde y dice «Copiado»)
     y en voz alta para quien navega con lector de pantalla.
     ------------------------------------------------------------ */
  /* El camino normal. Va con cronómetro a propósito: si la ventana ha
     perdido el foco, hay navegadores que dejan esta promesa colgada para
     siempre en vez de fallar, y entonces el botón se quedaba mudo, sin decir
     ni que sí ni que no. Al segundo y pico se da por perdida y se prueba el
     respaldo, que es lo que de verdad no puede fallar. */
  function porPortapapeles(t) {
    if (!(navigator.clipboard && navigator.clipboard.writeText)) return Promise.reject();
    return Promise.race([
      navigator.clipboard.writeText(t),
      new Promise(function (_, mal) { setTimeout(function () { mal(new Error('sin respuesta')); }, 1200); })
    ]);
  }

  /* Respaldo de toda la vida: una caja de texto invisible, seleccionar y
     copiar. Funciona en navegadores viejos y cuando no hay permiso. */
  function porCajaDeTexto(t) {
    try {
      var ta = document.createElement('textarea');
      ta.value = t;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed';
      ta.style.top = '0';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      ta.setSelectionRange(0, t.length);
      var hecho = document.execCommand('copy');
      document.body.removeChild(ta);
      return !!hecho;
    } catch (e) { return false; }
  }

  function copiarTexto(t) {
    return porPortapapeles(t).catch(function () {
      return porCajaDeTexto(t) ? Promise.resolve() : Promise.reject();
    });
  }

  function activar(raiz) {
    raiz = raiz || document;
    if (raiz.dataset && raiz.dataset.ipgActivo === '1') return;
    if (raiz.dataset) raiz.dataset.ipgActivo = '1';
    raiz.addEventListener('click', function (ev) {
      var b = ev.target && ev.target.closest ? ev.target.closest('.ipg-copiar') : null;
      if (!b) return;
      ev.preventDefault();
      var valor = b.getAttribute('data-copiar') || '';
      var txt = b.querySelector('.ipg-c-txt');
      var vivo = b.closest('.ipg') && b.closest('.ipg').querySelector('.ipg-vivo');
      copiarTexto(valor).then(function () {
        b.classList.add('copiado');
        if (txt) txt.textContent = 'Copiado';
        if (vivo) vivo.textContent = 'Copiado: ' + valor;
        clearTimeout(b._ipgT);
        b._ipgT = setTimeout(function () {
          b.classList.remove('copiado');
          if (txt) txt.textContent = 'Copiar';
          if (vivo) vivo.textContent = '';
        }, 2200);
      }).catch(function () {
        b.classList.add('fallo');
        if (txt) txt.textContent = 'Cópialo a mano';
        if (vivo) vivo.textContent = 'No se ha podido copiar. Selecciona el texto y cópialo a mano.';
        clearTimeout(b._ipgT);
        b._ipgT = setTimeout(function () {
          b.classList.remove('fallo');
          if (txt) txt.textContent = 'Copiar';
        }, 3200);
      });
    });
  }

  /* ------------------------------------------------------------
     EL ASPECTO · se inyecta una sola vez
     Crema, azul y navy del resto de la web; titulares en Barlow
     Condensed mayúsculas y las etiquetas en tipografía normal.
     Móvil primero: a 375 px nada se sale ni obliga a mover la
     pantalla de lado, y todo lo que se toca mide 44 px o más.
     ------------------------------------------------------------ */
  function estilos() {
    if (document.getElementById('ipg-css')) return;
    var s = document.createElement('style');
    s.id = 'ipg-css';
    s.textContent =
      '.ipg{background:#fff;border:1px solid var(--linea,#EAE3D5);border-radius:14px;' +
        'box-shadow:var(--sombra-suave,0 10px 22px -16px rgba(46,66,86,.5));margin:18px 0 0;overflow:hidden}' +
      '.ipg--pegado{margin:0}' +
      '.ipg>summary::-webkit-details-marker{display:none}' +
      '.ipg>summary::marker{content:""}' +
      '.ipg-cab{list-style:none;display:flex;align-items:center;gap:12px;min-height:56px;' +
        'padding:12px clamp(14px,3vw,20px);box-sizing:border-box;cursor:pointer;-webkit-tap-highlight-color:transparent}' +
      '.ipg-cab:hover{background:var(--crema,#FBF9F4)}' +
      '.ipg-cab:focus-visible{outline:2px solid var(--azul,#3B85C0);outline-offset:-2px}' +
      '.ipg-cab-txt{flex:1 1 auto;min-width:0;display:flex;flex-direction:column;gap:2px}' +
      '.ipg-cab-txt b{font-family:var(--fuente-titulo,"Barlow Condensed",sans-serif);text-transform:uppercase;' +
        'font-weight:700;font-size:21px;line-height:1.1;color:var(--navy,#2E4256)}' +
      '.ipg-cab-txt small{font-size:13px;line-height:1.4;color:var(--texto-suave,#6E6656)}' +
      '.ipg-cab-fl{flex:none;width:11px;height:11px;border-right:2px solid var(--texto-suave,#6E6656);' +
        'border-bottom:2px solid var(--texto-suave,#6E6656);transform:rotate(45deg);margin-right:4px;transition:transform .15s}' +
      '.ipg[open] .ipg-cab-fl{transform:rotate(-135deg)}' +
      '.ipg[open] .ipg-cab{border-bottom:1px solid var(--linea,#EAE3D5)}' +
      '.ipg-cuerpo{padding:4px clamp(14px,3vw,20px) clamp(14px,3vw,18px)}' +
      '.ipg-cuenta+.ipg-cuenta{margin-top:18px;padding-top:16px;border-top:1px solid var(--linea,#EAE3D5)}' +
      '.ipg-cuenta-tit{font-family:var(--fuente-titulo,"Barlow Condensed",sans-serif);text-transform:uppercase;' +
        'font-weight:700;font-size:21px;line-height:1.1;color:var(--navy,#2E4256);margin:14px 0 2px}' +
      /* etiqueta + valor */
      '.ipg-et{display:block;font-size:13px;line-height:1.4;color:var(--texto-suave,#6E6656);margin-bottom:3px}' +
      '.ipg-linea{padding:12px 0;border-bottom:1px solid var(--linea,#EAE3D5)}' +
      '.ipg-val{display:flex;flex-direction:column;gap:3px;font-size:15px;color:var(--navy,#2E4256)}' +
      '.ipg-val b{font-weight:600}' +
      '.ipg-sub{font-size:14px;color:var(--texto,#4A4437);line-height:1.5}' +
      /* bloque de transferencia */
      '.ipg-transf{background:var(--crema,#FBF9F4);border:1px solid var(--linea,#EAE3D5);border-radius:14px;' +
        'padding:13px 14px;margin:14px 0 0}' +
      '.ipg-otros{margin:0 0 4px;font-size:14px;line-height:1.5;color:var(--texto,#4A4437)}' +
      '.ipg-dato{display:flex;flex-wrap:wrap;align-items:center;gap:6px 10px;padding:9px 0;' +
        'border-bottom:1px solid var(--linea,#EAE3D5)}' +
      '.ipg-dato:last-child{border-bottom:0}' +
      '.ipg-d-et{display:block;flex:1 0 100%;font-size:13px;line-height:1.4;color:var(--texto-suave,#6E6656)}' +
      '.ipg-d-val{flex:1 1 auto;min-width:0;font-size:15px;color:var(--navy,#2E4256);overflow-wrap:anywhere}' +
      /* El número de cuenta, grande y en grupos de cuatro: se comprueba de un vistazo */
      '.ipg-iban{font-family:var(--fuente-dato,ui-monospace,monospace);font-size:16px;font-weight:600;line-height:1.45;color:var(--navy,#2E4256)}' +
      /* conceptos */
      '.ipg-conceptos{padding-top:11px}' +
      '.ipg-lista{list-style:none;margin:7px 0 0;padding:0;display:flex;flex-direction:column;gap:7px}' +
      '.ipg-lista li{display:flex;flex-wrap:wrap;align-items:center;gap:8px;background:#fff;' +
        'border:1px solid var(--linea,#EAE3D5);border-radius:10px;padding:9px 11px}' +
      '.ipg-ej{flex:1 1 140px;min-width:0;font-family:var(--fuente-dato,ui-monospace,monospace);font-size:14px;color:var(--navy,#2E4256);overflow-wrap:anywhere}' +
      '.ipg-pista{font-size:13px;color:var(--texto-suave,#6E6656);margin:9px 0 0;line-height:1.5}' +
      /* botón de copiar: 44 px reales, y confirma que ha copiado */
      '.ipg-copiar{flex:0 0 auto;min-height:44px;min-width:96px;display:inline-flex;align-items:center;' +
        'justify-content:center;gap:6px;padding:10px 16px;box-sizing:border-box;border-radius:999px;' +
        'border:1px solid var(--azul,#3B85C0);background:#fff;color:var(--azul-oscuro,#2F6FA8);' +
        'font:inherit;font-size:14px;line-height:1;cursor:pointer;transition:background .12s,color .12s,border-color .12s;' +
        '-webkit-tap-highlight-color:transparent}' +
      '.ipg-copiar:hover{background:var(--azul-suave,#EAF2F9)}' +
      '.ipg-copiar.copiado{background:var(--verde-fondo,#EDF5EE);border-color:var(--verde-borde,#CBE0CE);color:var(--verde,#3F7A4C);font-weight:600}' +
      '.ipg-copiar.copiado .ipg-c-txt::before{content:"✓ "}' +
      '.ipg-copiar .ipg-c-ic{flex:0 0 18px}' +
      '.ipg-copiar.copiado .ipg-c-ic{display:none}' +
      '.ipg-copiar.fallo{background:var(--ambar-fondo,#FDF3E3);border-color:var(--ambar-borde,#EBD9B8);color:#6B5227}' +
      /* recibo devuelto: avisa sin sonar a morosidad */
      '.ipg-devuelto{margin:14px 0 0;background:var(--aviso-fondo,#FDF5DF);border:1px solid var(--aviso-borde,#EBDCAE);' +
        'border-radius:14px;padding:13px 14px}' +
      '.ipg-dv-tit{display:block;font-family:var(--fuente-titulo,"Barlow Condensed",sans-serif);text-transform:uppercase;' +
        'font-weight:700;font-size:21px;line-height:1.1;color:var(--navy,#2E4256);margin-bottom:4px}' +
      '.ipg-devuelto p{margin:0 0 11px;font-size:14px;line-height:1.55;color:var(--aviso-texto,#4A4335)}' +
      '.ipg-dv-btn{display:inline-flex;align-items:center;min-height:44px;padding:11px 20px;box-sizing:border-box;' +
        'border-radius:999px;background:var(--azul,#3B85C0);color:#fff;font-size:15px;text-decoration:none}' +
      '.ipg-dv-btn:hover{background:var(--azul-oscuro,#2F6FA8);color:#fff}' +
      /* contacto */
      '.ipg-contacto{padding:13px 0 2px;margin-top:4px;border-top:1px solid var(--linea,#EAE3D5)}' +
      '.ipg-persona{display:flex;flex-direction:column;gap:1px;padding:3px 0}' +
      '.ipg-persona b{font-weight:600;font-size:15px;color:var(--navy,#2E4256)}' +
      '.ipg-persona span,.ipg-contacto .ipg-val{font-size:14px;color:var(--texto,#4A4437);overflow-wrap:anywhere}' +
      '.ipg-nota{font-size:13px;color:var(--texto-suave,#6E6656);margin:12px 0 0;line-height:1.5}' +
      '.ipg-futuro{font-size:13px;color:var(--texto-suave,#6E6656);margin:15px 0 0;line-height:1.55}' +
      '.ipg-vivo{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}' +
      /* Móvil: el botón de copiar baja a su propia línea y ocupa el ancho */
      '@media(max-width:420px){' +
        '.ipg-dato--cuenta .ipg-copiar,.ipg-lista li .ipg-copiar{flex:1 1 100%;width:100%}' +
        '.ipg-iban{font-size:16px}' +
      '}';
    document.head.appendChild(s);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', estilos);
  } else { estilos(); }

  window.APOLANA_INFO_PAGOS = {
    cargar: cargar,
    claveDe: claveDe,
    claveDeVarios: claveDeVarios,
    bloque: bloque,
    activar: activar,
    filas: function () { return FILAS || []; }
  };
})();
