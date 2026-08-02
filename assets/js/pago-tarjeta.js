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

   LA REGLA DE ORO: NINGÚN BOTÓN MUERTO
   Mientras el pago con tarjeta esté apagado (o falte configurar algo,
   o la persona no haya entrado en su cuenta), este módulo NO deja
   pintado un botón que no lleva a ningún sitio: o lo esconde, o lo
   cambia por una explicación. Un botón que no hace nada al pulsarlo
   es peor que no tener botón.

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
    misPagos: misPagos,
    pagar: pagar,
    prepararBoton: prepararBoton,
    refrescar: refrescar,
    euros: euros
  };
})();
