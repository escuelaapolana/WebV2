/* ============================================================
   CUOTA DEL CUBO · módulo compartido
   ------------------------------------------------------------
   La cuota mensual del Cubo (pago con Stripe + solicitar baja).
   Es el MISMO flujo que vivía dentro de portal/cubo-atleta (#mas);
   se extrae aquí para que la página «Más» del portal unificado lo
   use SIN reescribir el flujo de dinero (una sola implementación).

   Uso:
     APOLANA_CUBO_CUOTA.render(sb, perfil, el)
        → carga la cuota de la persona, pinta la tarjeta dentro de
          `el` y engancha los botones (pagar / solicitar baja).
          Devuelve una promesa que resuelve a `true` si la persona
          tiene alta en el Cubo (para saber si mostrar la sección).

   NO cambia nada de la base: lee `cubo_altas` y `cubo_config`,
   llama a la Edge `cubo-pagar` y a la RPC `cubo_baja_solicitar`,
   exactamente igual que antes.
   ============================================================ */
(function () {
  'use strict';

  var MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
               'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fechaLarga(iso) {
    if (!iso) return '';
    var p = String(iso).slice(0, 10).split('-');
    return (+p[2]) + ' de ' + MESES[(+p[1]) - 1] + ' de ' + p[0];
  }

  /* Estados posibles de la tarjeta: sin alta, lista de espera, cobro no abierto,
     activa (con próximo/último pago y opción de baja) y pendiente/impago (con
     botón de pago). Copia fiel de cubo-atleta. */
  function bloqueCuota(alta, abierto) {
    if (!alta) {
      return '<div class="cuota"><h2>Tu cuota mensual</h2>' +
        '<p>Aún no vemos tu alta en El Cubo. Si acabas de apuntarte, dale un momento y recarga; ' +
        'si no, habla con el club.</p></div>';
    }
    var precio = alta.precio_mes;
    var estado = alta.suscripcion_estado;

    if (alta.lista_espera && estado !== 'activa') {
      return '<div class="cuota"><h2>Tu cuota mensual</h2>' +
        '<p><b>Estás en lista de espera.</b> Tu grupo está completo ahora mismo. En cuanto haya un ' +
        'sitio te avisamos y podrás activar tu cuota (' + esc(precio) + ' € al mes). De momento no ' +
        'tienes que hacer nada.</p></div>';
    }

    if (!abierto && estado !== 'activa') {
      return '<div class="cuota"><h2>Tu cuota mensual</h2>' +
        '<p>Tu cuota será de <b>' + esc(precio) + ' € al mes</b>, <b>con tarjeta</b> (no por domiciliación). ' +
        'El pago se <b>abrirá muy pronto</b>; te avisaremos cuando puedas activarlo. ' +
        'No tienes que hacer nada todavía.</p></div>';
    }

    if (estado === 'activa') {
      var prox = alta.proximo_cobro ? fechaLarga(alta.proximo_cobro) : '';
      var ini = '2026-09-21';
      var ult = (alta.ultimo_cobro && String(alta.ultimo_cobro).slice(0, 10) >= ini)
        ? fechaLarga(alta.ultimo_cobro) : '';
      var baja = alta.baja_solicitada
        ? '<p class="fina">Has pedido la baja. El club la tramitará y dejará de cobrarte. Si fue un error, escríbenos.</p>'
        : '<p class="fina">¿Cambiar de tarjeta? Escríbenos. ¿Quieres darte de baja? Pídela con al menos <b>15 días de antelación</b> al siguiente cobro y el club la tramita. ' +
          '<button type="button" class="enlace" id="cb-baja">Solicitar la baja</button></p>' +
          '<p class="pago-msg" id="cb-baja-msg" hidden></p>';
      return '<div class="cuota"><h2>Tu cuota mensual</h2>' +
        '<p><b>Cuota activa.</b> ' + esc(precio) + ' € al mes. ' +
          'Se cobra sola con tu tarjeta; no tienes que hacer nada.</p>' +
        '<div class="pagos">' +
          '<div class="pago"><span>Próximo pago</span><b>' + (prox ? esc(prox) : 'Por confirmar') + '</b></div>' +
          (ult ? '<div class="pago"><span>Último pago</span><b>' + esc(ult) + '</b></div>' : '') +
        '</div>' + baja +
      '</div>';
    }

    var primerEur = (alta.primer_pago_cent > 0)
      ? (Number(alta.primer_pago_cent) / 100).toFixed(2).replace('.', ',') : '';
    var texto = estado === 'impago'
      ? '<p>Tu último recibo no se ha podido cobrar. Vuelve a activar la cuota con una tarjeta al día.</p>'
      : '<p>Al activar harás tu <b>primer pago' + (primerEur ? ' de ' + esc(primerEur) + ' €' : '') +
        '</b> y tu tarjeta queda guardada. A partir del <b>día 5 de cada mes</b> se cobra sola tu cuota de <b>' +
        esc(precio) + ' € al mes</b>; no tendrás que hacer nada.</p>';
    return '<div class="cuota"><h2>Tu cuota mensual</h2>' + texto +
      '<button type="button" class="btn activo" id="cb-pagar">' +
        (estado === 'impago' ? 'Reactivar la cuota' : 'Pagar la cuota') + '</button>' +
      '<p class="pago-msg" id="cb-pago-msg" hidden></p>' +
      '<p class="fina"><b>El Cubo se paga con tarjeta, aquí mismo</b> — no hace falta domiciliación bancaria. La tarjeta se teclea en la página segura de Stripe; el club no la ve.</p>' +
    '</div>';
  }

  function engancharPago(sb, el) {
    var bp = el.querySelector('#cb-pagar');
    if (!bp) return;
    bp.addEventListener('click', function () {
      var txt = bp.textContent;
      bp.disabled = true;
      bp.textContent = 'Abriendo el pago…';
      var msg = el.querySelector('#cb-pago-msg');
      var fallo = function (t) {
        bp.disabled = false; bp.textContent = txt;
        if (msg) { msg.hidden = false; msg.textContent = t; }
      };
      sb.functions.invoke('cubo-pagar', { body: {} }).then(function (r) {
        if (r.error) {
          var ctx = r.error.context;
          return (ctx && ctx.json ? ctx.json() : Promise.resolve(null))
            .catch(function () { return null; })
            .then(function (d) { fallo((d && d.mensaje) || 'No hemos podido abrir el pago. Inténtalo en un minuto.'); });
        }
        if (!r.data || !r.data.url) { fallo('No hemos podido abrir el pago. Inténtalo de nuevo.'); return; }
        window.location.href = r.data.url; // a la pasarela de Stripe
      }).catch(function (e) {
        fallo('No hemos podido conectar con la pasarela. Inténtalo en un minuto.');
        if (window.console) console.warn('[Apolana] cubo-pagar:', e && e.message ? e.message : e);
      });
    });
  }

  // Solicitar la baja: la pide la persona, el club la tramita.
  function engancharBaja(sb, perfil, el) {
    var b = el.querySelector('#cb-baja');
    if (!b) return;
    b.addEventListener('click', function () {
      if (!confirm('¿Seguro que quieres solicitar la baja de tu cuota? Es una SOLICITUD: el club la tramita. Recuerda pedirla con al menos 15 días de antelación al siguiente cobro; si no, puede entrarte el próximo recibo.')) return;
      var msg = el.querySelector('#cb-baja-msg');
      b.disabled = true; b.textContent = 'Enviando…';
      sb.rpc('cubo_baja_solicitar').then(function (r) {
        if (r.error || (r.data && r.data.ok === false)) {
          b.disabled = false; b.textContent = 'Solicitar la baja';
          if (msg) { msg.hidden = false; msg.textContent = 'No se ha podido. Vuelve a intentarlo o escríbenos.'; }
          return;
        }
        render(sb, perfil, el);   // repinta con la baja ya reflejada
      }).catch(function () {
        b.disabled = false; b.textContent = 'Solicitar la baja';
        if (msg) { msg.hidden = false; msg.textContent = 'No se ha podido conectar. Inténtalo de nuevo.'; }
      });
    });
  }

  async function cargar(sb, perfil) {
    var r = await sb.from('cubo_altas')
      .select('id,precio_mes,primer_pago_cent,suscripcion_estado,proximo_cobro,ultimo_cobro,baja_solicitada,lista_espera,cobro_abierto')
      .eq('perfil_id', perfil.id)
      .order('created_at', { ascending: false })
      .limit(1);
    var alta = (r && r.data && r.data[0]) || null;
    // El cobro del Cubo es POR PERSONA: cada quien puede pagar cuando el club
    // le ha abierto SU cobro (cubo_altas.cobro_abierto), NO un interruptor
    // global. Antes esto miraba cubo_config.cobro_abierto (global); estando en
    // OFF, nadie veía «Pagar la cuota» aunque tuviera el cobro abierto en el
    // panel → no podían pagar. Ahora manda el cobro de su propia alta.
    var abierto = !!(alta && alta.cobro_abierto);
    return { alta: alta, abierto: abierto };
  }

  async function render(sb, perfil, el) {
    if (!el) return false;
    var d = await cargar(sb, perfil);
    el.innerHTML = bloqueCuota(d.alta, d.abierto);
    engancharPago(sb, el);
    engancharBaja(sb, perfil, el);
    return !!d.alta;
  }

  window.APOLANA_CUBO_CUOTA = { render: render, cargar: cargar };
})();
