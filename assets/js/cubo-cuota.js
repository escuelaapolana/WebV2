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
   [mig 360] «Pausar un mes»: con la cuota ACTIVA, lee `cubo_pausa_mia()` y
   deja pedir la pausa (`cubo_pausa_solicitar`) o retirarla
   (`cubo_pausa_anular`). La aprueba el club (Edge cubo-pausa).
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
  function bloqueCuota(alta, abierto, pausa) {
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
      // [360] Si el próximo recibo cae en un mes EN PAUSA, el pago de verdad es el siguiente.
      var pAprob = pausaAprobada(pausa);
      if (pAprob && alta.proximo_cobro && String(alta.proximo_cobro).slice(0, 7) === String(pAprob.mes).slice(0, 7)) {
        prox = fechaLarga(mesMas(pAprob.mes, 1).slice(0, 8) + '05');
      }
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
        '</div>' + (alta.baja_solicitada ? '' : bloquePausa(pausa)) + baja +
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

  /* ===== [360] PAUSAR UN MES =====
     Reglas (las impone la base, aquí solo se pintan): se pide con la cuota
     activa, como tarde el día 20 del mes anterior (15 días antes del cobro
     del día 5), un mes por temporada; el club la aprueba; se guarda la plaza. */
  function mesMas(iso, n) {                 // 'YYYY-MM-..' + n meses → 'YYYY-MM-01'
    var p = String(iso).slice(0, 7).split('-'), y = +p[0], m = +p[1] - 1 + n;
    y += Math.floor(m / 12); m = ((m % 12) + 12) % 12;
    return y + '-' + (m < 9 ? '0' : '') + (m + 1) + '-01';
  }
  function nombreMes(iso) { return MESES[(+String(iso).slice(5, 7)) - 1] || ''; }
  function hoyMes() { var d = new Date(); return d.getFullYear() + '-' + (d.getMonth() < 9 ? '0' : '') + (d.getMonth() + 1); }
  function pausaAprobada(pausa) {
    var l = (pausa && pausa.pausas) || [];
    return l.filter(function (x) { return x.estado === 'aprobada' && String(x.mes).slice(0, 7) >= hoyMes(); })[0] || null;
  }
  function estiloPausa() {
    if (document.getElementById('cb-pausa-css')) return;
    var st = document.createElement('style'); st.id = 'cb-pausa-css';
    st.textContent =
      '.cb-pausa{margin:12px 0 0;padding:12px 14px;border-radius:12px;background:#F1EADC;color:#26374B;font-size:13.5px;line-height:1.5}' +
      '.cb-pausa b{color:#26374B}.cb-pausa.ok{background:#E8F3EA}.cb-pausa.no{background:#F7E4DE}' +
      '.cb-pausa-elige{margin:10px 0 0;padding:12px 14px;border:1px solid #E4DCCB;border-radius:12px;background:#fff}' +
      '.cb-pausa-elige label{display:flex;gap:9px;align-items:flex-start;padding:7px 0;font-size:14px;color:#26374B;cursor:pointer}' +
      '.cb-pausa-elige label small{display:block;color:#6E6656;font-size:12.5px}' +
      '.cb-pausa-elige input{margin-top:3px;accent-color:#2F6FA8}' +
      '.cb-pausa-acc{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin-top:8px}' +
      '.cb-pausa-acc .cb-pedir{min-height:42px;padding:0 18px;border-radius:999px;border:0;background:#2F6FA8;color:#fff;font:inherit;font-weight:600;font-size:14px;cursor:pointer}' +
      '.cb-pausa-acc .cb-pedir:disabled{opacity:.6;cursor:progress}';
    document.head.appendChild(st);
  }
  function bloquePausa(pausa) {
    if (!pausa) return '';
    var l = pausa.pausas || [];
    var ap = pausaAprobada(pausa);
    if (ap) {
      return '<div class="cb-pausa ok">⏸️ <b>Cuota de ' + esc(nombreMes(ap.mes)) + ' en pausa.</b> Ese mes no se te cobra y ' +
        '<b>tu plaza se mantiene</b>. El <b>5 de ' + esc(nombreMes(mesMas(ap.mes, 1))) + '</b> se vuelve a cobrar solo.</div>';
    }
    var sol = l.filter(function (x) { return x.estado === 'solicitada'; })[0];
    if (sol) {
      return '<div class="cb-pausa">Has pedido <b>pausar ' + esc(nombreMes(sol.mes)) + '</b>. El club la revisará y te llegará un correo. ' +
        '<button type="button" class="enlace" id="cb-pausa-anular" data-id="' + esc(sol.id) + '">Retirar la solicitud</button></div>' +
        '<p class="pago-msg" id="cb-pausa-msg" hidden></p>';
    }
    var rech = l.filter(function (x) { return x.estado === 'rechazada' && String(x.mes).slice(0, 7) >= hoyMes(); })[0];
    var avisoRech = rech
      ? '<div class="cb-pausa no">El club no ha podido aprobar la pausa de <b>' + esc(nombreMes(rech.mes)) + '</b>' +
          (rech.motivo_rechazo ? ': ' + esc(rech.motivo_rechazo) : '') + '. Si quieres, escríbenos.</div>'
      : '';
    if (!pausa.puede) return avisoRech;
    var opciones = (pausa.meses || []).map(function (m, i) {
      return '<label><input type="radio" name="cb-pausa-mes" value="' + esc(m.mes) + '"' + (i === 0 ? ' checked' : '') + '>' +
        '<span><b>' + esc(nombreMes(m.mes).charAt(0).toUpperCase() + nombreMes(m.mes).slice(1)) + '</b>' +
        '<small>Pídela como tarde el ' + esc(fechaLarga(m.limite).replace(/ de \d{4}$/, '')) + '</small></span></label>';
    }).join('');
    return avisoRech +
      '<p class="fina">¿No vas a venir un mes? Puedes <b>pausar un mes</b> tu cuota (uno por temporada): no se cobra ese mes y <b>se te guarda la plaza</b>. ' +
        'Pídela con al menos <b>15 días de antelación</b> al cobro de ese mes (el día 5). ' +
        '<button type="button" class="enlace" id="cb-pausa">Pausar un mes</button></p>' +
      '<div class="cb-pausa-elige" id="cb-pausa-elige" hidden>' +
        '<p class="fina" style="margin:0 0 4px">¿Qué mes no vas a venir?</p>' + opciones +
        '<div class="cb-pausa-acc"><button type="button" class="cb-pedir" id="cb-pausa-pedir">Pedir la pausa</button>' +
          '<button type="button" class="enlace" id="cb-pausa-cancelar">Cancelar</button></div>' +
        '<p class="fina" style="margin-top:8px">Es una <b>solicitud</b>: el club la aprueba y te llega un correo.</p>' +
      '</div>' +
      '<p class="pago-msg" id="cb-pausa-msg" hidden></p>';
  }
  function engancharPausa(sb, perfil, el) {
    var msg = function (t) { var m = el.querySelector('#cb-pausa-msg'); if (m) { m.hidden = false; m.textContent = t; } };
    var abrir = el.querySelector('#cb-pausa'), caja = el.querySelector('#cb-pausa-elige');
    if (abrir && caja) abrir.addEventListener('click', function () { caja.hidden = !caja.hidden; });
    var canc = el.querySelector('#cb-pausa-cancelar');
    if (canc && caja) canc.addEventListener('click', function () { caja.hidden = true; });
    var pedir = el.querySelector('#cb-pausa-pedir');
    if (pedir) pedir.addEventListener('click', function () {
      var r = el.querySelector('input[name="cb-pausa-mes"]:checked');
      if (!r) return;
      pedir.disabled = true; pedir.textContent = 'Enviando…';
      sb.rpc('cubo_pausa_solicitar', { p_mes: r.value }).then(function (x) {
        if (x.error || (x.data && x.data.ok === false)) {
          pedir.disabled = false; pedir.textContent = 'Pedir la pausa';
          msg((x.data && x.data.error) || 'No se ha podido. Vuelve a intentarlo o escríbenos.');
          return;
        }
        render(sb, perfil, el);
      }).catch(function () {
        pedir.disabled = false; pedir.textContent = 'Pedir la pausa';
        msg('No se ha podido conectar. Inténtalo de nuevo.');
      });
    });
    var anu = el.querySelector('#cb-pausa-anular');
    if (anu) anu.addEventListener('click', function () {
      if (!confirm('¿Retirar tu solicitud de pausa?')) return;
      anu.disabled = true;
      sb.rpc('cubo_pausa_anular', { p_id: anu.getAttribute('data-id') }).then(function (x) {
        if (x.error || (x.data && x.data.ok === false)) { anu.disabled = false; msg((x.data && x.data.error) || 'No se ha podido.'); return; }
        render(sb, perfil, el);
      }).catch(function () { anu.disabled = false; msg('No se ha podido conectar.'); });
    });
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
      .order('created_at', { ascending: false });
    var filas = (r && r.data) || [];
    // Se queda con la alta que DE VERDAD manda: la que ya paga (activa) > la que
    // tiene el cobro abierto > la más reciente. Así una alta DUPLICADA reciente
    // y vacía (p.ej. quien se reapunta por error tras haber pagado) no hace que
    // le salga «sin pagar».
    var alta = filas.filter(function (a) { return a.suscripcion_estado === 'activa'; })[0]
            || filas.filter(function (a) { return a.cobro_abierto; })[0]
            || filas[0] || null;
    // El cobro del Cubo es POR PERSONA: cada quien puede pagar cuando el club
    // le ha abierto SU cobro (cubo_altas.cobro_abierto), NO un interruptor
    // global. Antes esto miraba cubo_config.cobro_abierto (global); estando en
    // OFF, nadie veía «Pagar la cuota» aunque tuviera el cobro abierto en el
    // panel → no podían pagar. Ahora manda el cobro de su propia alta.
    var abierto = !!(alta && alta.cobro_abierto);
    // [360] Pausar un mes: solo con la cuota activa. Si la RPC aún no existe
    // (web subida antes que la migración) o falla, simplemente no se pinta.
    var pausa = null;
    if (alta && alta.suscripcion_estado === 'activa') {
      try {
        var rp = await sb.rpc('cubo_pausa_mia');
        if (rp && !rp.error && rp.data && rp.data.ok) pausa = rp.data;
      } catch (e) { pausa = null; }
    }
    return { alta: alta, abierto: abierto, pausa: pausa };
  }

  async function render(sb, perfil, el) {
    if (!el) return false;
    var d = await cargar(sb, perfil);
    if (d.pausa) estiloPausa();
    el.innerHTML = bloqueCuota(d.alta, d.abierto, d.pausa);
    engancharPago(sb, el);
    engancharBaja(sb, perfil, el);
    engancharPausa(sb, perfil, el);
    return !!d.alta;
  }

  window.APOLANA_CUBO_CUOTA = { render: render, cargar: cargar };
})();
