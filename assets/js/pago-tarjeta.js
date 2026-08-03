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

   Y la pantalla de confirmar entera (la de la maqueta 27b), que es
   la que se enseña justo antes de ir a Stripe:

     APOLANA_PAGO.confirmar({
       contenedor: document.getElementById('pantalla'),
       clave: 'bono-cubo-10',
       atleta_id: id,
       aNombreDe: 'Elena Marín Ruiz',
       atleta: fichaDelAtleta,        // para saber qué cuenta enseñar
       alVolver: function () { ... }  // atrás
     });

   LA REGLA DE ORO: NUNCA UN BOTÓN QUE FINJA COBRAR
   El circuito se ve entero desde el primer día: se elige, se revisa
   el desglose y se llega hasta el último paso. Lo que cambia con el
   interruptor apagado es el final: en vez del botón de pagar sale un
   aviso diciendo que el pago con tarjeta todavía no está en marcha,
   y debajo cómo se paga hoy de verdad (transferencia o efectivo, con
   la cuenta y el contacto que le tocan a esa persona). Nadie puede
   llegar a creer que ha pagado sin haber pagado, y nada falla en
   silencio ni saca un error del navegador.

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
     LA PANTALLA DE CONFIRMAR · maqueta 27b
     ---------------------------------------------------------------
     Qué se compra, el desglose y el total, y de ahí a Stripe.
     Se pinta dentro del contenedor que se le pase, así que sirve
     igual para el bono de El Cubo, la licencia o la ropa.

       contenedor  → dónde se pinta (obligatorio)
       clave       → qué se paga ('bono-cubo-10')
       atleta_id   → para quién es
       aNombreDe   → nombre que se enseña en la tarjeta
       atleta      → su ficha, para saber qué cuenta enseñar si toca
                     pagar por transferencia (escuela o club)
       alVolver    → qué hacer al pulsar «atrás»
       paso        → rótulo de la cabecera («paso 2 de 2»)
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
      cont.innerHTML = marco(o, '<div class="pgc-fallo">' +
        '<b>No hemos podido preparar este pago</b>' +
        '<p>Puede ser tu conexión, o que el club haya cambiado los bonos mientras estabas aquí. ' +
        'No se ha cobrado nada.</p>' +
        '<button type="button" class="pgc-btn-borde" data-pgc="reintentar">Volver a intentarlo</button>' +
      '</div>');
      conectarAtras(cont, o);
      var rb = cont.querySelector('[data-pgc="reintentar"]');
      if (rb) rb.addEventListener('click', function () { confirmar(o); });
      return false;
    }

    /* 3 · Con datos. */
    var repercute = !!(cfg && cfg.repercutir_comision);
    var base = Number(art.importe_centimos);
    var total = repercute ? conComision(base) : base;

    var cuerpo = '';

    cuerpo += '<div class="pgc-tarjeta">' +
      '<span class="pgc-et">qué se paga</span>' +
      '<h3 class="pgc-concepto">' + esc(art.titulo) + '</h3>' +
      (o.aNombreDe ? '<span class="pgc-quien">A nombre de ' + esc(o.aNombreDe) + '</span>' : '') +
      '<div class="pgc-desglose">' +
        '<div class="pgc-fila"><span>' + esc(art.bono_usos
            ? art.bono_usos + (art.bono_usos === 1 ? ' uso' : ' usos')
            : 'Precio') + '</span>' +
          '<span class="pgc-imp">' + esc(euros(base)) + '</span></div>' +
        '<div class="pgc-fila"><span>Gastos de gestión</span>' +
          (repercute
            ? '<span class="pgc-imp">' + esc(euros(total - base)) + '</span>'
            : '<span class="pgc-club">los paga el club</span>') +
        '</div>' +
      '</div>' +
      '<div class="pgc-total"><span class="pgc-total-et">Total</span>' +
        '<span class="pgc-total-imp">' + esc(euros(total)) + '</span></div>' +
    '</div>';

    if (art.bono_usos) {
      cuerpo += '<p class="pgc-nota">Los ' + art.bono_usos + ' usos se añaden a tu bono en cuanto se ' +
                'confirme el pago. No hay que esperar al banco.</p>';
    } else if (art.descripcion) {
      cuerpo += '<p class="pgc-nota">' + esc(art.descripcion) + '</p>';
    }

    if (cfg && cfg.activo) {
      cuerpo += '<div class="pgc-stripe">' +
        '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" ' +
        'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '<rect x="4" y="10" width="16" height="10" rx="2.5"/><path d="M8 10V7a4 4 0 018 0v3"/></svg>' +
        '<span>El pago se hace en Stripe. El club no guarda tu tarjeta.</span></div>';
      if (cfg.texto_ayuda) cuerpo += '<p class="pgc-nota">' + esc(cfg.texto_ayuda) + '</p>';
      if (cfg.modo === 'prueba') {
        cuerpo += '<div class="pgc-previa"><b>Modo de pruebas</b>' +
          '<p>El club está probando el pago con tarjeta. Aquí no se mueve dinero de verdad.</p></div>';
      }
    } else {
      /* Apagado: el circuito se ve entero, pero el último paso no
         finge cobrar. Se dice qué pasa y cómo se paga hoy. */
      cuerpo += '<div class="pgc-previa">' +
        '<b>El pago con tarjeta todavía no está en marcha</b>' +
        '<p>La pantalla ya está montada: es exactamente la que verás cuando el club abra su cuenta. ' +
        'De momento desde aquí no se cobra nada, así que esto se sigue pagando como hasta ahora, ' +
        'por transferencia o en efectivo. Aquí abajo tienes la cuenta, el concepto que hay que poner ' +
        'y a quién preguntar.</p>' +
      '</div>';
    }

    /* El bloque «Cómo se paga» sale de la base (info_pagos): la cuenta
       y el contacto que le tocan a esa persona, nunca los dos. */
    var comoSePaga = await bloqueComoSePaga(o, !(cfg && cfg.activo));
    cuerpo += comoSePaga;

    /* El pie. Un solo botón azul, y solo si de verdad cobra. */
    var pie;
    if (cfg && cfg.activo) {
      pie = '<button type="button" class="pgc-btn" data-pgc="pagar">Pagar ' + esc(euros(total)) + '</button>' +
            (comoSePaga ? '<button type="button" class="pgc-btn-txt" data-pgc="otras">Otras formas de pago</button>' : '');
    } else {
      pie = '<button type="button" class="pgc-btn-borde" data-pgc="volver">Volver a los bonos</button>';
    }
    cuerpo += '<div class="pgc-pie">' + pie + '</div>';

    cont.innerHTML = marco(o, cuerpo);
    conectarAtras(cont, o);
    if (window.APOLANA_INFO_PAGOS) window.APOLANA_INFO_PAGOS.activar(cont);

    var otras = cont.querySelector('[data-pgc="otras"]');
    if (otras) otras.addEventListener('click', function () {
      var det = cont.querySelector('details.ipg');
      if (det) { det.open = true; det.scrollIntoView({ block: 'nearest' }); }
    });

    var volver = cont.querySelector('[data-pgc="volver"]');
    if (volver && typeof o.alVolver === 'function') {
      volver.addEventListener('click', function () { o.alVolver(); });
    }

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

        if (!res.ok) {
          ocupado = false;
          btn.disabled = false;
          btn.setAttribute('aria-busy', 'false');
          btn.textContent = 'Pagar ' + euros(total);
          var caja = cont.querySelector('[data-pgc="aviso"]');
          if (!caja) {
            caja = document.createElement('div');
            caja.className = 'pgc-fallo';
            caja.setAttribute('data-pgc', 'aviso');
            caja.setAttribute('role', 'status');
            btn.parentNode.insertBefore(caja, btn);
          }
          caja.innerHTML = '<b>No se ha podido abrir el pago</b><p>' + esc(res.mensaje) +
                           '</p><p>No se te ha cobrado nada.</p>';
        }
        /* Si salió bien, el navegador ya se está yendo a Stripe. */
      });
    }
    return !!(cfg && cfg.activo);
  }

  /* La cabecera y el hueco: siempre el mismo, cambie lo que cambie
     dentro. Así la pantalla no baila entre «cargando» y «listo». */
  function marco(o, dentro) {
    return '<div class="pgc">' +
      '<div class="pgc-cab">' +
        '<button type="button" class="pgc-atras" data-pgc="atras">' +
          '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" ' +
          'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 6l-6 6 6 6"/></svg>' +
          '<span>' + esc(o.paso || 'paso 2 de 2') + '</span>' +
        '</button>' +
        '<h2 class="pgc-tit">Revisa el pago</h2>' +
      '</div>' + dentro +
    '</div>';
  }

  function conectarAtras(cont, o) {
    var a = cont.querySelector('[data-pgc="atras"]');
    if (a) a.addEventListener('click', function () {
      if (typeof o.alVolver === 'function') o.alVolver();
      else history.back();
    });
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
     Modo consulta: crema, una sola tarjeta, diseño plano (ni sombras
     ni degradados). Cuerpo 15 px, rótulos 13 px en minúscula, radios
     14 / 10 / 999 y 44 px de zona pulsable. Móvil primero.
     --------------------------------------------------------------- */
  function estilosConfirmar() {
    if (document.getElementById('pgc-css')) return;
    var s = document.createElement('style');
    s.id = 'pgc-css';
    s.textContent =
      '.pgc{display:flex;flex-direction:column;gap:12px;padding:0 16px 28px;' +
        'font-family:var(--fuente-texto,system-ui);color:var(--texto,#4A4437)}' +
      '.pgc-cab{display:flex;flex-direction:column;gap:2px;padding:4px 0 6px}' +
      '.pgc-atras{align-self:flex-start;display:inline-flex;align-items:center;gap:6px;min-height:44px;' +
        'padding:0 8px 0 0;background:none;border:0;cursor:pointer;font:inherit;font-size:13px;' +
        'color:var(--texto-suave,#6E6656);-webkit-tap-highlight-color:transparent}' +
      '.pgc-atras:hover{color:var(--azul,#2F6FA8)}' +
      '.pgc-atras:focus-visible{outline:2px solid var(--azul-filete,#3B85C0);outline-offset:2px;border-radius:10px}' +
      '.pgc-tit{margin:0;font-family:var(--fuente-titulo,"Barlow Condensed",sans-serif);font-weight:700;' +
        'font-size:28px;line-height:1.05;text-transform:uppercase;color:var(--navy,#2E4256)}' +
      /* la tarjeta única */
      '.pgc-tarjeta{background:#fff;border:1px solid var(--linea,#EAE3D5);border-radius:14px;padding:16px 18px;' +
        'display:flex;flex-direction:column;gap:10px}' +
      '.pgc-et{font-size:13px;line-height:1.4;color:var(--texto-suave,#6E6656)}' +
      '.pgc-concepto{margin:0;font-family:var(--fuente-titulo,"Barlow Condensed",sans-serif);font-weight:700;' +
        'font-size:21px;line-height:1.1;text-transform:uppercase;color:var(--navy,#2E4256)}' +
      '.pgc-quien{font-size:14px;line-height:1.45;color:var(--texto,#4A4437);margin-top:-6px}' +
      '.pgc-desglose{border-top:1px solid var(--linea,#EAE3D5);padding-top:11px;display:flex;' +
        'flex-direction:column;gap:8px}' +
      '.pgc-fila{display:flex;align-items:baseline;justify-content:space-between;gap:12px;font-size:15px;' +
        'line-height:1.45;color:var(--texto,#4A4437)}' +
      /* importes: cifra que se compara en columna, en mono */
      '.pgc-imp{font-family:var(--fuente-dato,ui-monospace,monospace);font-size:15px;color:var(--navy,#2E4256);' +
        'white-space:nowrap}' +
      '.pgc-club{font-size:15px;color:var(--verde,#3F7A4C)}' +
      '.pgc-total{border-top:1px solid var(--linea-marcada,#E4DCCB);padding-top:12px;display:flex;' +
        'align-items:baseline;justify-content:space-between;gap:12px}' +
      '.pgc-total-et{font-family:var(--fuente-titulo,"Barlow Condensed",sans-serif);font-weight:700;font-size:21px;' +
        'line-height:1.1;text-transform:uppercase;color:var(--navy,#2E4256)}' +
      '.pgc-total-imp{font-family:var(--fuente-dato,ui-monospace,monospace);font-weight:700;font-size:26px;' +
        'line-height:1;color:var(--navy,#2E4256);white-space:nowrap}' +
      /* notas y avisos */
      '.pgc-nota{margin:0;font-size:14px;line-height:1.55;color:var(--texto,#4A4437);padding:0 2px}' +
      '.pgc-stripe{display:flex;align-items:center;gap:10px;padding:0 2px;font-size:13px;line-height:1.45;' +
        'color:var(--texto-suave,#6E6656)}' +
      '.pgc-stripe svg{flex:none}' +
      '.pgc-previa{background:var(--ambar-fondo,#FDF3E3);border:1px solid var(--ambar-borde,#EBD9B8);' +
        'border-radius:14px;padding:14px 16px;display:flex;flex-direction:column;gap:5px}' +
      '.pgc-previa b{font-size:15px;font-weight:600;color:var(--navy,#2E4256)}' +
      '.pgc-previa p{margin:0;font-size:14px;line-height:1.55;color:var(--texto,#4A4437)}' +
      '.pgc-fallo{background:var(--ambar-fondo,#FDF3E3);border:1px solid var(--ambar-borde,#EBD9B8);' +
        'border-radius:14px;padding:14px 16px;display:flex;flex-direction:column;gap:8px;align-items:flex-start}' +
      '.pgc-fallo b{font-size:15px;font-weight:600;color:var(--navy,#2E4256)}' +
      '.pgc-fallo p{margin:0;font-size:14px;line-height:1.55;color:var(--texto,#4A4437)}' +
      /* pie: un solo botón azul, y solo cuando de verdad cobra */
      '.pgc-pie{display:flex;flex-direction:column;gap:6px;padding-top:4px}' +
      '.pgc-btn{min-height:44px;padding:13px 22px;border:0;border-radius:999px;background:var(--azul,#2F6FA8);' +
        'color:#fff;font:inherit;font-size:15px;font-weight:600;cursor:pointer;' +
        '-webkit-tap-highlight-color:transparent}' +
      '.pgc-btn:hover{background:var(--azul-hover,#1E4E78)}' +
      '.pgc-btn[disabled]{opacity:.65;cursor:default}' +
      '.pgc-btn-borde{min-height:44px;padding:13px 22px;border:1px solid var(--linea-borde,#D4CBB9);' +
        'border-radius:999px;background:#fff;color:var(--navy,#2E4256);font:inherit;font-size:15px;' +
        'cursor:pointer;-webkit-tap-highlight-color:transparent}' +
      '.pgc-btn-borde:hover{background:var(--crema,#FBF9F4)}' +
      '.pgc-btn-txt{min-height:44px;padding:11px 16px;border:0;background:none;color:var(--azul,#2F6FA8);' +
        'font:inherit;font-size:15px;cursor:pointer}' +
      '.pgc-btn-txt:hover{color:var(--azul-hover,#1E4E78)}' +
      '.pgc-btn:focus-visible,.pgc-btn-borde:focus-visible,.pgc-btn-txt:focus-visible' +
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
    euros: euros
  };
})();
