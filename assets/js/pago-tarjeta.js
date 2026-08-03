/* ============================================================
   PAGAR CON TARJETA · módulo reutilizable
   ------------------------------------------------------------
   Lo usa cualquier pantalla que tenga que cobrar algo con tarjeta:
   el bono de El Cubo, la licencia federativa o la ropa del club.
   Las cuotas NO: esas siguen domiciliadas en el banco.

   CÓMO SE USA (tres líneas)

     <script src="../../assets/js/pago-tarjeta.js" defer></script>

     // 1) ¿Está encendido? Si no, ni se pinta el botón.
     if (await APOLANA_PAGO.disponible()) { ... }

     // 2) Cobrar. Lleva a la página de Stripe.
     await APOLANA_PAGO.pagar({ tipo: 'bono-cubo-10', atleta_id: id });

   O, más cómodo todavía, dejando que el módulo se encargue de todo:

     APOLANA_PAGO.prepararBoton(document.getElementById('btn-bono'), {
       tipo: 'bono-cubo-10',
       atleta_id: id,
       siNoHay: 'ocultar'      // o 'texto', para explicar por qué no
     });

   Y la pantalla de confirmar entera, que es la que se enseña justo
   antes de ir a Stripe:

     APOLANA_PAGO.confirmar({
       contenedor: document.getElementById('pantalla'),
       clave: 'bono-cubo-10',
       atleta_id: id,
       aNombreDe: 'Elena Marín Ruiz',   // de quién son los usos
       pagador: { nombre: 'Andrés Pérez', email: 'andres@correo.es' },
       atleta: fichaDelAtleta,        // para saber qué cuenta enseñar
       alVolver: function () { ... }  // atrás y «Cancelar»
     });

   Es también la pantalla del pago que FALLA y la del que se deja a
   medias: la misma, con la selección intacta y un aviso ámbar arriba.
   En el texto del aviso, **esto** sale en negrita.

     APOLANA_PAGO.confirmar({
       ...
       aviso: {
         titulo: 'El pago no se ha completado',
         texto: 'Tu banco no lo ha autorizado. **No se te ha cobrado ' +
                'nada** y el bono sigue sin comprar.'
       }
     });

   LA REGLA QUE LAS ORDENA
   En cada pantalla se ve QUÉ SE COMPRA Y CUÁNTO CUESTA, la del error
   incluida. Nadie llega al banco sin haber visto el total.

   LA REGLA DE ORO: NUNCA UN BOTÓN QUE FINJA COBRAR
   El circuito se ve entero desde el primer día: se elige, se revisa
   el desglose y se llega hasta el último paso. Lo que cambia con el
   interruptor apagado es el final: en vez del botón de pagar sale una
   nota diciendo que el pago con tarjeta todavía no está en marcha, el
   botón de verdad («pedir el bono a quien lleva los pagos») y el de
   tarjeta a la vista pero apagado; debajo, cómo se paga hoy de verdad
   (transferencia o efectivo, con la cuenta y el contacto que le tocan
   a esa persona). Nadie puede llegar a creer que ha pagado sin haber
   pagado, y nada falla en silencio ni saca un error del navegador.

   LO QUE ESTE ARCHIVO NO SABE (a propósito)
   Ni el importe ni las claves. Aquí solo se dice QUÉ se quiere pagar
   ('bono-cubo-10'); cuánto vale lo decide el servidor leyéndolo de la
   base. Aunque alguien trastee esta página desde el navegador, no
   puede cambiar el precio. Los datos de la tarjeta tampoco pasan por
   aquí: se teclean en la página de Stripe.

   Necesita que se hayan cargado antes supabase-js y db.js.
   ============================================================ */
(function () {
  'use strict';

  var FUNCION = 'pago-crear';

  /* Se pregunta una vez y se recuerda: si hay cinco botones en la
     misma pantalla, no tiene sentido preguntar cinco veces. */
  var cacheConfig = null;
  var cachePromesa = null;

  function sb() { return window.APOLANA_DB || null; }

  function texto(s) { return (s == null ? '' : String(s)); }

  function esc(s) {
    var d = document.createElement('div');
    d.textContent = (s == null ? '' : String(s));
    return d.innerHTML;
  }

  /* Lo mismo, para meterlo dentro de un atributo entre comillas. */
  function escA(s) { return esc(s).replace(/"/g, '&quot;'); }

  /* 5500 → «55,00 €» */
  function euros(centimos) {
    var n = Number(centimos);
    if (!isFinite(n)) return '';
    try {
      return (n / 100).toLocaleString('es-ES', { style: 'currency', currency: 'EUR' });
    } catch (e) {
      return (n / 100).toFixed(2).replace('.', ',') + ' €';
    }
  }

  /* 5000 → «50 €» · 4550 → «45,50 €»
     El redondo se enseña sin céntimos donde es un rótulo (la tarjeta de
     la opción, el botón). En el desglose y en el total van completos,
     que ahí sí es una cuenta. */
  function eurosCorto(centimos) {
    var n = Number(centimos);
    if (!isFinite(n)) return '';
    if (n % 100 === 0) return (n / 100) + ' €';
    return euros(centimos);
  }

  /* Fechas en cristiano: '2027-08-03' → «3 de agosto de 2027». */
  var MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
               'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

  function comoFecha(f) {
    if (f instanceof Date) return f;
    var s = String(f || '').slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
    var p = s.split('-');
    return new Date(+p[0], +p[1] - 1, +p[2]);
  }

  function fechaLarga(f, conAnio) {
    var x = comoFecha(f);
    if (!x || isNaN(x.getTime())) return '';
    return x.getDate() + ' de ' + MESES[x.getMonth()] +
           (conAnio === false ? '' : ' de ' + x.getFullYear());
  }

  /* Hoy + N días, para decir cuándo caducará un bono que aún no existe. */
  function dentroDe(dias) {
    var x = new Date();
    x.setHours(0, 0, 0, 0);
    x.setDate(x.getDate() + Number(dias || 0));
    return x;
  }

  /* Texto escapado en el que **esto** sale en negrita. Lo justo para
     poder resaltar «no se te ha cobrado nada» sin abrir la puerta a
     meter HTML desde fuera. */
  function conNegritas(s) {
    return esc(s).replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>');
  }

  /* ---------------------------------------------------------------
     ¿ESTÁ ENCENDIDO?
     Se pregunta a la base con una función que solo devuelve sí o no.
     Si algo falla (sin conexión, sin permisos, lo que sea) la
     respuesta es NO: más vale no enseñar el botón que enseñarlo roto.
     --------------------------------------------------------------- */
  async function cargarConfig() {
    var base = sb();
    if (!base) return { activo: false, motivo: 'sin-conexion' };

    try {
      var r = await base.rpc('pagos_disponible');
      if (r.error || r.data !== true) {
        return { activo: false, motivo: 'apagado' };
      }
    } catch (e) {
      return { activo: false, motivo: 'sin-conexion' };
    }

    /* Encendido. Se intentan traer los detalles (modo, texto de ayuda),
       que solo puede leer quien tiene sesión. Si no se pueden, no pasa
       nada: lo importante ya lo sabemos. */
    var extra = { modo: null, texto_ayuda: null, repercutir_comision: false };
    try {
      var c = await base.from('pagos_config')
        .select('modo,texto_ayuda,repercutir_comision').eq('id', 1).single();
      if (!c.error && c.data) extra = c.data;
    } catch (e) { /* da igual */ }

    return {
      activo: true,
      motivo: null,
      modo: extra.modo,
      texto_ayuda: extra.texto_ayuda,
      repercutir_comision: !!extra.repercutir_comision
    };
  }

  function config() {
    if (cacheConfig) return Promise.resolve(cacheConfig);
    if (!cachePromesa) {
      cachePromesa = cargarConfig().then(function (c) {
        cacheConfig = c;
        cachePromesa = null;
        return c;
      });
    }
    return cachePromesa;
  }

  async function disponible() {
    var c = await config();
    return !!c.activo;
  }

  /* ---------------------------------------------------------------
     EL CATÁLOGO · qué se puede pagar y a cuánto, ya con el precio
     resuelto. Sirve para pintar «Bono de 10 usos · 55,00 €» sin
     escribir el precio en el HTML (que es como se queda desfasado).
     --------------------------------------------------------------- */
  async function catalogo(tipo) {
    var base = sb();
    if (!base) return [];
    try {
      var q = base.from('pagos_catalogo')
        .select('clave,tipo,titulo,descripcion,importe_centimos,bono_usos,bono_caducidad_dias,exige_atleta,orden')
        .order('orden', { ascending: true });
      if (tipo) q = q.eq('tipo', tipo);
      var r = await q;
      if (r.error) { console.warn('[Apolana] catálogo de pagos:', r.error.message); return []; }
      return r.data || [];
    } catch (e) {
      console.warn('[Apolana] catálogo de pagos (excepción):', e);
      return [];
    }
  }

  /* Mis pagos con tarjeta (cada uno ve los suyos; el club, todos). */
  async function misPagos(limite) {
    var base = sb();
    if (!base) return [];
    try {
      var q = base.from('pagos_online')
        .select('referencia,concepto,tipo,importe_centimos,estado,creado_en,pagado_en')
        .order('creado_en', { ascending: false });
      if (limite) q = q.limit(limite);
      var r = await q;
      if (r.error) { console.warn('[Apolana] mis pagos:', r.error.message); return []; }
      return r.data || [];
    } catch (e) { return []; }
  }

  /* Un solo artículo del catálogo, con el precio ya resuelto. */
  async function articulo(clave) {
    var lista = await catalogo();
    for (var i = 0; i < lista.length; i++) {
      if (lista[i].clave === clave) return lista[i];
    }
    return null;
  }

  /* ---------------------------------------------------------------
     LA COMISIÓN DE LA TARJETA
     ---------------------------------------------------------------
     El club decidió pagarla él (`repercutir_comision = false`), así
     que en la pantalla se dice con todas las letras y el total es el
     precio limpio: se ve que el club no cobra de más por pagar con
     tarjeta.

     Si algún día se cambia de idea, esta es la misma cuenta que hace
     la base en `pagos_con_comision()`, para que lo que se enseña y lo
     que se cobra no puedan separarse: (importe + 25) / 0,985.
     --------------------------------------------------------------- */
  function conComision(centimos) {
    return Math.ceil((Number(centimos) + 25) / 0.985);
  }

  /* ---------------------------------------------------------------
     LA PANTALLA DE CONFIRMAR · maqueta «comprar un bono», pantalla 2
     ---------------------------------------------------------------
     Qué se compra, el desglose y el total, y de ahí a Stripe. Se
     pinta dentro del contenedor que se le pase, así que sirve igual
     para el bono de El Cubo, la licencia o la ropa.

     Es TAMBIÉN la pantalla del pago que falla y la del pago que se
     deja a medias: la misma, con la selección intacta y un aviso
     ámbar arriba. Nunca una pantalla en blanco ni volver al principio.

       contenedor  → dónde se pinta (obligatorio)
       clave       → qué se paga ('bono-cubo-10')
       atleta_id   → para quién es
       aNombreDe   → de quién son los usos (el atleta)
       pagador     → { nombre, email } de quien pone la tarjeta
       atleta      → su ficha, para saber qué cuenta y qué contacto
                     le tocan si hay que pagar por transferencia
       aviso       → { titulo, texto } del aviso ámbar de arriba.
                     En el texto, **esto** sale en negrita.
       alVolver    → qué hacer al pulsar «atrás» y «Cancelar»
       titulo      → rótulo de la cabecera (por defecto «Confirmar»)
     --------------------------------------------------------------- */
  async function confirmar(o) {
    o = o || {};
    var cont = o.contenedor;
    if (!cont) return false;

    estilosConfirmar();

    /* 1 · Cargando: con la forma que va a tener, para que no salte. */
    cont.innerHTML = marco(o, '<div class="pgc-esq" role="status">' +
      '<span style="width:60%"></span><span style="width:88%"></span>' +
      '<span style="width:44%"></span><span class="pgc-oculto">Cargando…</span></div>');
    conectarAtras(cont, o);

    var cfg = null, art = null;
    try {
      var todo = await Promise.all([config(), articulo(texto(o.clave).trim())]);
      cfg = todo[0]; art = todo[1];
    } catch (e) { cfg = null; art = null; }

    /* 2 · Error: el artículo no está o no tiene precio. Ámbar y salida. */
    if (!art) {
      cont.innerHTML = marco(o, avisoAmbar({
        titulo: 'No hemos podido preparar este pago',
        texto: 'Puede ser tu conexión, o que el club haya cambiado los bonos mientras estabas aquí. ' +
               '**No se te ha cobrado nada.**'
      }) + '<div class="pgc-pie">' +
        '<button type="button" class="pgc-btn" data-pgc="reintentar">Volver a intentarlo</button>' +
      '</div>');
      conectarAtras(cont, o);
      var rb = cont.querySelector('[data-pgc="reintentar"]');
      if (rb) rb.addEventListener('click', function () { confirmar(o); });
      return false;
    }

    /* 3 · Con datos. El importe sale del catálogo de la base, que es
       de donde lo lee también el servidor al cobrar. */
    var repercute = !!(cfg && cfg.repercutir_comision);
    var base = Number(art.importe_centimos);
    var total = repercute ? conComision(base) : base;
    var encendido = !!(cfg && cfg.activo);

    /* «Bono de 10 usos · El Cubo» → titular y contexto. */
    var partes = texto(art.titulo).split(' · ');
    var nombre = partes.shift();
    var contexto = partes.join(' · ');
    if (art.bono_caducidad_dias) {
      contexto += (contexto ? ' · ' : '') + 'caduca el ' + fechaLarga(dentroDe(art.bono_caducidad_dias));
    }

    var cuerpo = '';

    if (o.aviso) cuerpo += avisoAmbar(o.aviso);

    /* La tarjeta: qué se compra, qué se añade y el total. */
    cuerpo += '<div class="pgc-tarjeta">' +
      '<div class="pgc-fila pgc-fila--titulo">' +
        '<span class="pgc-concepto">' + esc(nombre) + '</span>' +
        '<span class="pgc-imp">' + esc(euros(base)) + '</span>' +
      '</div>' +
      (contexto ? '<p class="pgc-contexto">' + esc(contexto) + '</p>' : '') +
      '<div class="pgc-fila pgc-fila--linea">' +
        '<span class="pgc-et">Gastos de gestión</span>' +
        (repercute
          ? '<span class="pgc-imp">' + esc(euros(total - base)) + '</span>'
          /* Sin importe y en verde: es una buena noticia, no una línea de factura. */
          : '<span class="pgc-club">Los paga el club</span>') +
      '</div>' +
      '<div class="pgc-fila pgc-fila--total">' +
        '<span class="pgc-total-et">Total</span>' +
        '<span class="pgc-total-imp">' + esc(euros(total)) + '</span>' +
      '</div>' +
    '</div>';

    /* Quién paga y para quién es. */
    var pagador = o.pagador || {};
    var quienPaga = [texto(pagador.nombre).trim(), texto(pagador.email).trim()]
      .filter(Boolean).join(' · ');
    if (quienPaga) {
      cuerpo += '<div class="pgc-quien"><span class="pgc-rot">Pagas como</span>' +
        '<span class="pgc-quien-val">' + esc(quienPaga) + '</span></div>';
    }
    if (o.aNombreDe) {
      cuerpo += '<div class="pgc-quien"><span class="pgc-rot">' +
        (art.bono_usos ? 'Los usos son para' : 'A nombre de') + '</span>' +
        '<span class="pgc-quien-val">' + esc(o.aNombreDe) + '</span></div>';
    }

    /* La cuenta y el contacto de verdad salen de la base (info_pagos):
       nunca están escritos en el repositorio. Se piden ANTES de armar
       el pie, que es quien necesita saber a quién se le pide el bono. */
    var comoSePaga = await bloqueComoSePaga(o, false);

    /* El pie cambia entero según haya pasarela o no. */
    var pie = '';

    if (encendido) {
      if (art.bono_usos) {
        cuerpo += '<p class="pgc-nota">Los ' + art.bono_usos + ' usos se añaden a tu bono en cuanto se ' +
                  'confirme el pago. No hay que esperar al banco.</p>';
      } else if (art.descripcion) {
        cuerpo += '<p class="pgc-nota">' + esc(art.descripcion) + '</p>';
      }
      if (cfg.texto_ayuda) cuerpo += '<p class="pgc-nota">' + esc(cfg.texto_ayuda) + '</p>';
      if (cfg.modo === 'prueba') {
        cuerpo += avisoAmbar({
          titulo: 'Modo de pruebas',
          texto: 'El club está probando el pago con tarjeta. Aquí no se mueve dinero de verdad.'
        });
      }
      cuerpo += '<p class="pgc-nota pgc-nota--pie">El cobro lo hace Stripe. ' +
                'El club no guarda los datos de tu tarjeta.</p>';

      if (o.aviso) {
        /* Después de un intento que no ha salido, el botón dice lo que
           hace ahora («probar otra vez») y al lado está la salida de
           verdad por si vuelve a fallar. */
        var otroQuien = contactoDe(o);
        if (otroQuien.nombre) {
          cuerpo += '<p class="pgc-nota">Si vuelve a fallar, escribe a ' + esc(otroQuien.nombre) +
                    ' y lo arreglamos por transferencia.</p>';
        }
        pie = '<button type="button" class="pgc-btn" data-pgc="pagar">Probar otra vez</button>' +
              '<a class="pgc-btn-txt" href="' + escA(otroQuien.url) + '"' +
                (otroQuien.fuera ? ' target="_blank" rel="noopener"' : '') + '>' +
                (otroQuien.nombre ? 'Escribir a ' + esc(otroQuien.nombre) : 'Escribir al club') + '</a>';
      } else {
        pie = '<button type="button" class="pgc-btn" data-pgc="pagar">Pagar ' + esc(eurosCorto(total)) + '</button>' +
              '<button type="button" class="pgc-btn-txt" data-pgc="cancelar">Cancelar</button>';
      }
    } else {
      /* Apagado: el circuito se ve entero, pero el último paso no
         finge cobrar. Se dice qué pasa, cuál es la vía de verdad, y
         el botón de tarjeta se queda a la vista pero apagado, para
         que se entienda que va a existir. */
      var quien = contactoDe(o);
      var pedir = art.bono_usos
        ? (quien.nombre ? 'Pedir el bono a ' + quien.nombre : 'Pedir el bono al club')
        : (quien.nombre ? 'Escribir a ' + quien.nombre : 'Escribir al club');

      cuerpo += '<div class="pgc-provisional" id="pgc-provisional">' +
        '<b>Todavía no se puede pagar aquí</b>' +
        '<p>Estamos terminando de conectar el pago con tarjeta. Mientras tanto lo hacemos por ' +
        'transferencia y te cargamos el bono a mano.</p>' +
      '</div>';

      pie = '<a class="pgc-btn" href="' + escA(quien.url) + '"' +
              (quien.fuera ? ' target="_blank" rel="noopener"' : '') + '>' + esc(pedir) + '</a>' +
            '<button type="button" class="pgc-btn-apagado" disabled ' +
              'aria-describedby="pgc-provisional">Pagar con tarjeta</button>';
    }

    cuerpo += '<div class="pgc-pie">' + pie + '</div>';
    cuerpo += comoSePaga;

    cont.innerHTML = marco(o, cuerpo);
    conectarAtras(cont, o);
    if (window.APOLANA_INFO_PAGOS) window.APOLANA_INFO_PAGOS.activar(cont);

    /* Si se llega con un aviso, se lee en voz alta y se ve el primero. */
    var caja = cont.querySelector('.pgc-aviso');
    if (caja) { try { caja.focus(); } catch (e) { /* da igual */ } }

    var cancelar = cont.querySelector('[data-pgc="cancelar"]');
    if (cancelar) cancelar.addEventListener('click', function () {
      if (typeof o.alVolver === 'function') o.alVolver(); else history.back();
    });

    var btn = cont.querySelector('[data-pgc="pagar"]');
    if (btn) {
      var ocupado = false;
      btn.addEventListener('click', async function () {
        if (ocupado) return;
        ocupado = true;
        btn.disabled = true;
        btn.setAttribute('aria-busy', 'true');
        btn.textContent = 'Un momento…';

        var res = await pagar({
          clave: art.clave,
          atleta_id: o.atleta_id || null,
          nota: o.nota || null
        });

        /* Si salió bien, el navegador ya se está yendo a Stripe.
           Si no, es exactamente la pantalla del pago que falla: la
           misma, con la selección intacta y el aviso ámbar arriba. */
        if (!res.ok) {
          var otra = {};
          for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) otra[k] = o[k];
          otra.aviso = {
            titulo: 'El pago no se ha completado',
            texto: res.mensaje + ' **No se te ha cobrado nada** y el bono sigue sin comprar.'
          };
          confirmar(otra);
        }
      });
    }
    return encendido;
  }

  /* El aviso ámbar de arriba. Ámbar y no rojo: un pago que falla no es
     una emergencia, y es la misma regla que los avisos del club. */
  function avisoAmbar(a) {
    return '<div class="pgc-aviso" role="alert" tabindex="-1">' +
      '<b>' + esc(a.titulo) + '</b>' +
      '<p>' + conNegritas(a.texto) + '</p>' +
    '</div>';
  }

  /* La cabecera y el hueco: siempre el mismo, cambie lo que cambie
     dentro. Así la pantalla no baila entre «cargando» y «listo». */
  function marco(o, dentro) {
    return '<div class="pgc">' +
      '<div class="pgc-cab">' +
        '<button type="button" class="pgc-atras" data-pgc="atras" aria-label="Volver">' +
          '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" ' +
          'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 6l-6 6 6 6"/></svg>' +
        '</button>' +
        '<h2 class="pgc-tit">' + esc(o.titulo || 'Confirmar') + '</h2>' +
      '</div>' +
      '<div class="pgc-cuerpo">' + dentro + '</div>' +
    '</div>';
  }

  function conectarAtras(cont, o) {
    var a = cont.querySelector('[data-pgc="atras"]');
    if (a) a.addEventListener('click', function () {
      if (typeof o.alVolver === 'function') o.alVolver();
      else history.back();
    });
  }

  /* A quién se le pide mientras no haya tarjeta. Sale de `info_pagos`,
     que es donde el club tiene sus contactos: aquí no hay ni un
     teléfono ni un nombre escrito a mano. */
  function contactoDe(o) {
    var salida = { nombre: '', url: (window.APOLANA_BASE || '../../') + 'contacto/', fuera: false };
    var mod = window.APOLANA_INFO_PAGOS;
    if (!mod) return salida;

    var filas = mod.filas() || [];
    if (!filas.length) return salida;

    var clave = o.clavePago || (o.atleta ? mod.claveDe(o.atleta) : null);
    var f = null;
    for (var i = 0; i < filas.length; i++) {
      if (!clave || filas[i].clave === clave) { f = filas[i]; break; }
    }
    if (!f) f = filas[0];

    salida.nombre = texto(f.contacto_nombre).split('·')[0].trim();
    var tel = texto(f.contacto_tel).replace(/[^\d+]/g, '');
    var mail = texto(f.contacto_email).trim();
    if (tel) {
      salida.url = 'https://wa.me/' + tel.replace(/^\+/, '');
      salida.fuera = true;
    } else if (mail) {
      salida.url = 'mailto:' + mail;
    }
    return salida;
  }

  /* «Cómo se paga» de verdad, con los datos de la base. Si no se
     puede cargar (o no hay nada puesto), no se inventa nada: se
     devuelve cadena vacía y la pantalla no enseña ese bloque. */
  async function bloqueComoSePaga(o, abierto) {
    var mod = window.APOLANA_INFO_PAGOS;
    var base = sb();
    if (!mod || !base) return '';
    try {
      await mod.cargar(base);
      var clave = o.clavePago || (o.atleta ? mod.claveDe(o.atleta) : null);
      return mod.bloque({ clave: clave, plegado: !abierto, margen: true });
    } catch (e) { return ''; }
  }

  /* ---------------------------------------------------------------
     EL ASPECTO · se inyecta una vez
     Crema, una sola tarjeta blanca, diseño plano (ni sombras ni
     degradados). Los importes NO van en monoespaciada: el total en
     Barlow Condensed, que es la cifra que se mira, y los de línea de
     lista en la tipografía de texto. Móvil primero: a 375 px nada se
     sale, y todo lo que se pulsa mide 44 px o más.
     --------------------------------------------------------------- */
  function estilosConfirmar() {
    if (document.getElementById('pgc-css')) return;
    var s = document.createElement('style');
    s.id = 'pgc-css';
    s.textContent =
      '.pgc{font-family:var(--fuente-texto,system-ui);color:var(--texto,#4A4437)}' +
      /* cabecera de navegación: 50 px y filete, como el resto de la app */
      '.pgc-cab{display:flex;align-items:center;gap:8px;min-height:50px;padding:0 6px 0 4px;' +
        'border-bottom:1px solid var(--linea-marcada,#E4DCCB)}' +
      '.pgc-atras{flex:none;display:inline-flex;align-items:center;justify-content:center;width:44px;height:44px;' +
        'background:none;border:0;cursor:pointer;color:var(--azul,#2F6FA8);-webkit-tap-highlight-color:transparent}' +
      '.pgc-atras:hover{color:var(--azul-hover,#1E4E78)}' +
      '.pgc-atras:focus-visible{outline:2px solid var(--azul-filete,#3B85C0);outline-offset:-2px;border-radius:10px}' +
      '.pgc-tit{margin:0;font-family:var(--fuente-titulo,"Barlow Condensed",sans-serif);font-weight:700;' +
        'font-size:21px;line-height:1;text-transform:uppercase;color:var(--navy,#2E4256)}' +
      '.pgc-cuerpo{display:flex;flex-direction:column;gap:14px;padding:18px 16px 28px}' +
      /* el aviso ámbar: el error nunca es rojo */
      '.pgc-aviso{background:#FDF6EA;border:1px solid var(--ambar-borde,#EBD9B8);' +
        'border-left:5px solid #E08A18;border-radius:12px;padding:15px 16px;display:flex;flex-direction:column;gap:7px}' +
      '.pgc-aviso:focus{outline:none}' +
      '.pgc-aviso:focus-visible{outline:2px solid var(--azul-filete,#3B85C0);outline-offset:2px}' +
      '.pgc-aviso b{font-weight:600;font-size:16px;line-height:1.35;color:var(--navy,#2E4256)}' +
      '.pgc-aviso p{margin:0;font-size:15px;line-height:1.45;color:var(--texto,#4A4437)}' +
      /* la tarjeta única: qué se compra, qué se añade y el total */
      '.pgc-tarjeta{background:#fff;border:1px solid var(--linea-marcada,#E4DCCB);border-radius:14px;' +
        'padding:17px 18px;display:flex;flex-direction:column;gap:13px}' +
      '.pgc-fila{display:flex;align-items:baseline;justify-content:space-between;gap:12px}' +
      '.pgc-concepto{font-size:17px;font-weight:500;line-height:1.3;color:var(--navy,#2E4256)}' +
      '.pgc-imp{font-size:16px;line-height:1.3;color:var(--navy,#2E4256);white-space:nowrap}' +
      '.pgc-contexto{margin:-8px 0 0;font-size:14px;line-height:1.4;color:var(--texto-suave,#6E6656)}' +
      '.pgc-fila--linea,.pgc-fila--total{padding-top:12px;border-top:1px solid var(--crema-media,#EFE9DC)}' +
      '.pgc-et{font-size:15px;line-height:1.3;color:var(--texto,#4A4437)}' +
      '.pgc-club{font-size:15px;font-weight:500;line-height:1.3;color:var(--verde,#3F7A4C)}' +
      '.pgc-total-et{font-family:var(--fuente-titulo,"Barlow Condensed",sans-serif);font-weight:700;font-size:24px;' +
        'line-height:1;text-transform:uppercase;color:var(--navy,#2E4256)}' +
      '.pgc-total-imp{font-family:var(--fuente-titulo,"Barlow Condensed",sans-serif);font-weight:700;font-size:30px;' +
        'line-height:1;color:var(--navy,#2E4256);white-space:nowrap}' +
      /* quién paga y para quién es */
      '.pgc-quien{display:flex;flex-direction:column;gap:5px;padding:0 2px}' +
      '.pgc-rot{font-size:12px;font-weight:500;line-height:1;letter-spacing:.09em;text-transform:uppercase;' +
        'color:var(--texto-suave,#6E6656)}' +
      '.pgc-quien-val{font-size:15px;line-height:1.4;color:var(--navy,#2E4256);overflow-wrap:anywhere}' +
      /* notas */
      '.pgc-nota{margin:0;font-size:14px;line-height:1.55;color:var(--texto,#4A4437);padding:0 2px}' +
      '.pgc-nota--pie{font-size:13px;line-height:1.5;color:var(--texto-suave,#6E6656)}' +
      /* mientras no haya pasarela */
      '.pgc-provisional{background:var(--crema-banda,#F1EADC);border:1px solid #E0D7C4;border-radius:12px;' +
        'padding:15px 16px;display:flex;flex-direction:column;gap:7px}' +
      '.pgc-provisional b{font-weight:600;font-size:16px;line-height:1.35;color:var(--navy,#2E4256)}' +
      '.pgc-provisional p{margin:0;font-size:15px;line-height:1.45;color:var(--texto,#4A4437)}' +
      /* pie de botones */
      '.pgc-pie{display:flex;flex-direction:column;gap:10px;padding-top:2px}' +
      '.pgc-btn{display:flex;align-items:center;justify-content:center;min-height:52px;padding:14px 22px;' +
        'box-sizing:border-box;border:0;border-radius:999px;background:var(--azul,#2F6FA8);color:#fff;' +
        'font:inherit;font-size:16px;font-weight:500;text-align:center;text-decoration:none;cursor:pointer;' +
        '-webkit-tap-highlight-color:transparent}' +
      '.pgc-btn:hover{background:var(--azul-hover,#1E4E78);color:#fff}' +
      '.pgc-btn[disabled]{opacity:.65;cursor:default}' +
      /* visible pero apagado: se entiende que va a existir */
      '.pgc-btn-apagado{min-height:52px;padding:14px 22px;box-sizing:border-box;border:1.5px solid #DCD3C0;' +
        'border-radius:999px;background:transparent;color:#8C8474;font:inherit;font-size:16px;font-weight:500;' +
        'cursor:not-allowed}' +
      '.pgc-btn-txt{display:flex;align-items:center;justify-content:center;min-height:44px;padding:11px 16px;' +
        'box-sizing:border-box;border:0;background:none;color:var(--azul,#2F6FA8);font:inherit;font-size:15px;' +
        'text-align:center;text-decoration:none;cursor:pointer}' +
      '.pgc-btn-txt:hover{color:var(--azul-hover,#1E4E78)}' +
      '.pgc-btn:focus-visible,.pgc-btn-txt:focus-visible,.pgc-btn-apagado:focus-visible' +
        '{outline:2px solid var(--azul-filete,#3B85C0);outline-offset:2px}' +
      /* cargando: la forma del dato que va a llegar */
      '.pgc-esq{background:#fff;border:1px solid var(--linea,#EAE3D5);border-radius:14px;padding:18px;' +
        'display:flex;flex-direction:column;gap:10px}' +
      '.pgc-esq>span{height:14px;border-radius:10px;background:var(--crema-media,#EFE9DC)}' +
      '.pgc-oculto{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}';
    document.head.appendChild(s);
  }

  /* ---------------------------------------------------------------
     PAGAR
     ---------------------------------------------------------------
     opciones = {
       tipo        → la clave de lo que se paga ('bono-cubo-10').
                     También vale escribir `clave`, es lo mismo.
       atleta_id   → para quién es (obligatorio en los bonos).
       concepto    → solo informativo; el de verdad lo pone el servidor.
       referencia  → nota libre que se guarda con el pago (talla, nº de
                     pedido…). La referencia OFICIAL la genera el
                     servidor y se devuelve en el resultado.
       redirigir   → false si prefieres llevar tú a la pasarela.
     }

     Devuelve { ok:true, url, referencia, importe_centimos } o
     { ok:false, error, mensaje } con un mensaje ya escrito para
     enseñárselo a una persona. NUNCA lanza una excepción suelta.
     --------------------------------------------------------------- */
  async function pagar(opciones) {
    opciones = opciones || {};
    var clave = texto(opciones.clave || opciones.tipo).trim();
    var base = sb();

    if (!base) {
      return fallo('sin-conexion', 'No hemos podido conectar. Comprueba la conexión y vuelve a intentarlo.');
    }
    if (!clave) {
      return fallo('sin-clave', 'No sabemos qué quieres pagar.');
    }

    var cfg = await config();
    if (!cfg.activo) {
      return fallo('no-activado', mensajeApagado(cfg));
    }

    /* Hay que haber entrado: el pago va atado a una persona. */
    var sesion = null;
    try { sesion = (await base.auth.getSession()).data.session; } catch (e) { sesion = null; }
    if (!sesion) {
      return fallo('sin-sesion', 'Entra en tu cuenta para poder pagar.');
    }

    var cuerpo = {
      clave: clave,
      atleta_id: opciones.atleta_id || null,
      nota: opciones.referencia || opciones.nota || null
    };

    var datos = null, fallo_http = null;
    try {
      var r = await base.functions.invoke(FUNCION, { body: cuerpo });
      datos = r.data;
      fallo_http = r.error;
    } catch (e) {
      return fallo('red', 'No hemos podido conectar con la pasarela de pago. Inténtalo en un minuto.');
    }

    /* Cuando el servidor contesta con un error, supabase-js esconde el
       cuerpo dentro de `error.context`. Ahí está nuestro mensaje bien
       escrito, así que merece la pena ir a buscarlo. */
    if (fallo_http) {
      var detalle = null;
      try { detalle = await fallo_http.context.json(); } catch (e) { detalle = null; }
      if (detalle && detalle.error === 'no_activado') {
        cacheConfig = null;                       // igual lo acaban de apagar
        return fallo('no-activado', detalle.mensaje || mensajeApagado(cfg));
      }
      return fallo(
        (detalle && detalle.error) || 'error',
        (detalle && detalle.mensaje) || 'No se ha podido preparar el pago. Vuelve a intentarlo.'
      );
    }

    if (!datos || !datos.url) {
      return fallo('error', 'No se ha podido preparar el pago. Vuelve a intentarlo.');
    }

    if (opciones.redirigir !== false) {
      window.location.href = datos.url;
    }
    return {
      ok: true,
      url: datos.url,
      referencia: datos.referencia,
      importe_centimos: datos.importe_centimos,
      concepto: datos.concepto
    };
  }

  function fallo(codigo, mensaje) {
    return { ok: false, error: codigo, mensaje: mensaje };
  }

  function mensajeApagado(cfg) {
    if (cfg && cfg.texto_ayuda) return cfg.texto_ayuda;
    return 'El pago con tarjeta todavía no está disponible. De momento se paga por transferencia: ' +
           'lo tienes explicado en tu zona, en «Cómo se paga».';
  }

  /* ---------------------------------------------------------------
     PREPARAR UN BOTÓN · para no repetir lo mismo en cada pantalla
     ---------------------------------------------------------------
     Deja el botón listo: si el pago está apagado lo esconde (o lo
     sustituye por una explicación), y si está encendido lo engancha
     para que al pulsarlo lleve a la pasarela, con su «Un momento…»
     y sin poder pulsarlo dos veces.
     --------------------------------------------------------------- */
  function prepararBoton(el, opciones) {
    if (!el) return Promise.resolve(false);
    opciones = opciones || {};

    var siNoHay = opciones.siNoHay || 'ocultar';   // 'ocultar' | 'texto'
    var original = el.textContent;
    var ocupado = false;

    el.setAttribute('aria-busy', 'false');
    el.hidden = true;                              // hasta saber si se puede

    return config().then(function (cfg) {
      if (!cfg.activo) {
        if (siNoHay === 'texto') {
          var aviso = document.createElement('p');
          aviso.className = opciones.claseAviso || 'pago-aviso';
          aviso.textContent = mensajeApagado(cfg);
          if (el.parentNode) el.parentNode.insertBefore(aviso, el);
        }
        el.hidden = true;                          // nada de botones muertos
        return false;
      }

      el.hidden = false;
      el.addEventListener('click', async function (ev) {
        ev.preventDefault();
        if (ocupado) return;
        ocupado = true;
        el.disabled = true;
        el.setAttribute('aria-busy', 'true');
        el.textContent = 'Un momento…';

        var res = await pagar(opciones);

        if (!res.ok) {
          ocupado = false;
          el.disabled = false;
          el.setAttribute('aria-busy', 'false');
          el.textContent = original;
          if (typeof opciones.alFallar === 'function') opciones.alFallar(res);
          else alert(res.mensaje);
        }
        /* Si salió bien, el navegador ya se está yendo a Stripe:
           el botón se queda apagado a propósito. */
      });
      return true;
    });
  }

  /* Olvidar lo que se preguntó (útil en el panel, después de encender
     o apagar el interruptor, para que se note al momento). */
  function refrescar() { cacheConfig = null; cachePromesa = null; return config(); }

  window.APOLANA_PAGO = {
    disponible: disponible,
    config: config,
    catalogo: catalogo,
    articulo: articulo,
    misPagos: misPagos,
    pagar: pagar,
    confirmar: confirmar,
    conComision: conComision,
    prepararBoton: prepararBoton,
    refrescar: refrescar,
    euros: euros,
    eurosCorto: eurosCorto,
    fechaLarga: fechaLarga,
    dentroDe: dentroDe
  };
})();
