/* ============================================================
   PAYOUTS DE STRIPE · lo que Stripe manda al banco del club
   ------------------------------------------------------------
   Una sola pieza para las dos pantallas que lo enseñan:
     · portal/payouts/          (la de siempre, para cuadrar con Isa)
     · admin/dinero/?v=banco    (pestaña «Al banco»)
   Los datos salen de la Edge `stripe-payout-export` (lista + desglose
   de cada payout, cruzado con la base); aquí solo se pinta y se
   descarga el Excel. El Excel usa SheetJS (cdnjs), que se carga solo
   cuando hace falta.

   Uso:
     APOLANA_PAYOUTS.montar(contenedor, sb, { titulo: true|false })
   ============================================================ */
(function () {
  'use strict';

  var XLSX_URL = 'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js';
  var ESTADO = {
    paid:       ['spx-ok',  'En el banco'],
    in_transit: ['spx-cur', 'En camino'],
    pending:    ['spx-cur', 'Pendiente'],
    canceled:   ['spx-err', 'Cancelado'],
    failed:     ['spx-err', 'Fallido']
  };
  var MESES = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]; }); }
  function eur(n) { return Number(n || 0).toLocaleString('es-ES', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €'; }
  function fecha(iso) {
    if (!iso) return '';
    var p = String(iso).slice(0, 10).split('-');
    if (p.length < 3) return iso;
    return (+p[2]) + ' ' + MESES[(+p[1]) - 1].slice(0, 3) + ' ' + p[0];
  }

  function estilos() {
    if (document.getElementById('spx-css')) return;
    var st = document.createElement('style');
    st.id = 'spx-css';
    st.textContent =
      '.spx-lista{display:flex;flex-direction:column;gap:8px;margin-bottom:16px}' +
      '.spx-po{display:grid;grid-template-columns:minmax(0,1fr) auto auto;align-items:center;gap:6px 12px;background:#fff;' +
        'border:1px solid var(--linea-marcada,#E4DCCB);border-radius:12px;padding:10px 12px 10px 15px;box-shadow:0 1px 2px rgba(30,45,65,.05)}' +
      '.spx-po.on{border-color:var(--navy,#26374B);box-shadow:0 0 0 1px var(--navy,#26374B) inset}' +
      '.spx-po .que{min-width:0}' +
      '.spx-po .imp{font-family:var(--fuente-dato,monospace);font-size:18px;font-weight:700;color:var(--navy,#26374B);font-variant-numeric:tabular-nums}' +
      '.spx-po .meta{display:block;font-size:13.5px;color:var(--texto-suave,#6E6656);margin-top:2px}' +
      '.spx-po .meta b{color:var(--texto,#333)}' +
      '.spx-po .acc{display:flex;gap:6px;flex-wrap:wrap;justify-content:flex-end}' +
      '.spx-b{min-height:40px;padding:0 14px;border-radius:10px;font:inherit;font-size:14px;font-weight:600;cursor:pointer;' +
        'border:1px solid var(--linea-marcada,#C6BEAE);background:#fff;color:var(--navy,#26374B)}' +
      '.spx-b:hover{border-color:var(--azul,#2F6FA8);color:var(--azul,#2F6FA8)}' +
      '.spx-b.xl{background:var(--azul,#2F6FA8);border-color:var(--azul,#2F6FA8);color:#fff}' +
      '.spx-b.xl:hover{background:var(--azul-hover,#245B8C);color:#fff}' +
      '.spx-b[disabled]{opacity:.5;cursor:default}' +
      '.spx-pill{display:inline-block;font-size:12px;font-weight:600;border-radius:999px;padding:3px 10px;white-space:nowrap;border:1px solid transparent}' +
      '.spx-ok{background:var(--verde-fondo,#EDF5EE);border-color:var(--verde-borde,#CBE0CE);color:var(--verde,#3F7A4C)}' +
      '.spx-cur{background:var(--azul-suave,#EAF2F9);border-color:#CFE0EE;color:var(--azul-hover,#245B8C)}' +
      '.spx-err{background:#FBF0ED;border-color:#EBD2CB;color:var(--rojo,#B0563A)}' +
      '.spx-det{background:#fff;border:1px solid var(--linea-marcada,#E4DCCB);border-radius:14px;padding:14px 15px;margin:-2px 0 6px;overflow-x:auto}' +
      '.spx-det h3{font-size:15px;color:var(--navy,#26374B);margin:0 0 3px}' +
      '.spx-tot{font-size:13.5px;color:var(--texto-suave,#6E6656);margin:0 0 10px;line-height:1.5}' +
      '.spx-tabla{width:100%;border-collapse:collapse;font-size:13.5px}' +
      '.spx-tabla th{text-align:left;font-size:11.5px;text-transform:uppercase;letter-spacing:.03em;color:var(--texto-suave,#8A816E);padding:6px 8px;border-bottom:1px solid var(--linea,#EDE6D7)}' +
      '.spx-tabla td{padding:7px 8px;border-bottom:1px solid var(--linea,#F3EEE2);color:var(--texto,#333);vertical-align:top}' +
      '.spx-tabla td.num{font-family:var(--fuente-dato,monospace);text-align:right;white-space:nowrap}' +
      '.spx-tabla .neto{color:var(--verde,#3F7A4C);font-weight:600}' +
      '.spx-vacio{color:var(--texto-suave,#8A816E);text-align:center;padding:26px 10px;font-size:14.5px}' +
      '@media (max-width:560px){.spx-po{grid-template-columns:minmax(0,1fr) auto}.spx-po .acc{grid-column:1/-1;justify-content:flex-start}}';
    document.head.appendChild(st);
  }

  var _xlsx = null;
  function cargarXlsx() {
    if (window.XLSX) return Promise.resolve(window.XLSX);
    if (_xlsx) return _xlsx;
    _xlsx = new Promise(function (ok, ko) {
      var s = document.createElement('script');
      s.src = XLSX_URL; s.async = true;
      s.onload = function () { window.XLSX ? ok(window.XLSX) : ko(new Error('No se pudo cargar el Excel')); };
      s.onerror = function () { _xlsx = null; ko(new Error('No se pudo cargar el Excel')); };
      document.head.appendChild(s);
    });
    return _xlsx;
  }

  async function mensajeError(r, porDefecto) {
    var d = null;
    try { if (r && r.error && r.error.context && r.error.context.json) d = await r.error.context.json(); } catch (e) {}
    var msg = (d && (d.msg || d.error)) || (r && r.data && r.data.msg) || porDefecto;
    if (msg === 'Solo administración.' || msg === 'sin_permiso') msg = 'Los payouts de Stripe solo los ve administración.';
    return msg;
  }

  async function lista(sb) {
    var r = await sb.functions.invoke('stripe-payout-export', { body: { accion: 'lista' } });
    if (r.error || !r.data || r.data.ok === false) throw new Error(await mensajeError(r, 'No se pudieron cargar los payouts.'));
    return r.data.payouts || [];
  }

  async function detalle(sb, id) {
    var r = await sb.functions.invoke('stripe-payout-export', { body: { accion: 'detalle', payout: id } });
    if (r.error || !r.data || r.data.ok === false) throw new Error(await mensajeError(r, 'No se pudo cargar el desglose.'));
    return r.data;
  }

  /* El mismo Excel que se le pasa a Isa (columnas de siempre). */
  async function excel(det, po) {
    var X = await cargarXlsx();
    po = po || {};
    var fechaPayout = det.fecha_llegada || po.fecha_llegada || po.creado || '';
    var aoa = [['Nombre','Teléfono','Correo','DNI','Sección / Equipo','Concepto','Importe','Comisión','Total (neto)','Pagado el día','Llegó al banco']];
    (det.lineas || []).forEach(function (l) {
      aoa.push([l.nombre || '', l.telefono || '', l.email || '', l.dni || '', l.seccion || '', l.concepto || '',
                l.importe, l.comision, l.neto, l.fecha_cargo || '', l.fecha_llegada || fechaPayout]);
    });
    var t = det.totales || {};
    aoa.push([]); aoa.push(['TOTAL', '', '', '', '', (t.lineas || 0) + ' cobros', t.importe, t.comision, t.neto, '', fechaPayout]);
    var ws = X.utils.aoa_to_sheet(aoa);
    ws['!cols'] = [{wch:26},{wch:14},{wch:26},{wch:12},{wch:22},{wch:30},{wch:10},{wch:10},{wch:11},{wch:13},{wch:13}];
    var wb = X.utils.book_new(); X.utils.book_append_sheet(wb, ws, 'Payout');
    X.writeFile(wb, 'payout-' + (fechaPayout || 'stripe') + '.xlsx');
  }

  function montar(el, sb, opciones) {
    opciones = opciones || {};
    estilos();
    var POS = [], sel = null, DET = {}, avisar = opciones.avisar || function (m) { window.alert(m); };

    function tablaDet(det) {
      var t = det.totales || {};
      var filas = (det.lineas || []).map(function (l) {
        return '<tr><td><b>' + esc(l.nombre || '—') + '</b>' + (l.seccion ? '<br><small style="color:var(--texto-suave,#8A816E)">' + esc(l.seccion) + '</small>' : '') + '</td>' +
          '<td>' + esc(l.concepto || '') + '</td>' +
          '<td class="num">' + eur(l.importe) + '</td><td class="num">' + eur(l.comision) + '</td>' +
          '<td class="num neto">' + eur(l.neto) + '</td><td class="num">' + esc(fecha(l.fecha_cargo)) + '</td></tr>';
      }).join('');
      return '<div class="spx-det"><h3>Qué lleva este ingreso</h3>' +
        '<p class="spx-tot"><b>' + (t.lineas || 0) + '</b> cobros · Bruto ' + eur(t.importe) + ' · Comisión ' + eur(t.comision) +
        ' · <b>Neto ' + eur(t.neto) + '</b> · llega al banco el <b>' + esc(fecha(det.fecha_llegada)) + '</b></p>' +
        (filas ? '<table class="spx-tabla"><thead><tr><th>Quién</th><th>Concepto</th><th>Importe</th><th>Comisión</th><th>Neto</th><th>Pagado el</th></tr></thead><tbody>' + filas + '</tbody></table>'
               : '<p class="spx-vacio">Este ingreso no tiene cobros detallados (puede ser un ajuste).</p>') +
      '</div>';
    }

    function pintar() {
      if (!POS.length) { el.innerHTML = '<div class="spx-vacio">Stripe todavía no ha hecho ningún ingreso al banco.</div>'; return; }
      el.innerHTML = '<div class="spx-lista">' + POS.map(function (p) {
        var e = ESTADO[p.estado] || ['spx-cur', p.estado];
        var abierto = sel === p.id;
        return '<div class="spx-po' + (abierto ? ' on' : '') + '">' +
            '<div class="que"><span class="imp">' + eur(p.importe) + '</span>' +
              '<span class="meta">Llega el <b>' + esc(fecha(p.fecha_llegada || p.creado)) + '</b>' + (p.creado && p.creado !== p.fecha_llegada ? ' · creado el ' + esc(fecha(p.creado)) : '') + '</span></div>' +
            '<span class="spx-pill ' + e[0] + '">' + esc(e[1]) + '</span>' +
            '<div class="acc">' +
              '<button type="button" class="spx-b" data-ver="' + esc(p.id) + '" aria-expanded="' + abierto + '">' + (abierto ? 'Ocultar' : 'Qué lleva') + '</button>' +
              '<button type="button" class="spx-b xl" data-xl="' + esc(p.id) + '">Excel</button>' +
            '</div>' +
          '</div>' +
          (abierto ? (DET[p.id] ? tablaDet(DET[p.id]) : '<div class="spx-det"><div class="spx-vacio">Cargando el desglose…</div></div>') : '');
      }).join('') + '</div>';
    }

    async function det(id) {
      if (!DET[id]) DET[id] = await detalle(sb, id);
      return DET[id];
    }

    el.addEventListener('click', async function (ev) {
      var b = ev.target.closest ? ev.target.closest('button') : null;
      if (!b || !el.contains(b)) return;
      var id = b.getAttribute('data-ver');
      if (id) {
        sel = (sel === id) ? null : id; pintar();
        if (sel && !DET[id]) {
          try { await det(id); } catch (e) { avisar(e.message, 'error'); sel = null; }
          pintar();
        }
        return;
      }
      id = b.getAttribute('data-xl');
      if (id) {
        var t0 = b.textContent; b.disabled = true; b.textContent = 'Preparando…';
        try {
          var d = await det(id);
          if (!(d.lineas || []).length) avisar('Este ingreso no tiene cobros detallados: el Excel sale solo con el total.', 'info');
          await excel(d, POS.filter(function (p) { return p.id === id; })[0]);
        } catch (e) { avisar(e.message || String(e), 'error'); }
        b.disabled = false; b.textContent = t0;
      }
    });

    el.innerHTML = '<div class="spx-vacio">Preguntando a Stripe por los ingresos al banco…</div>';
    return lista(sb).then(function (p) { POS = p; pintar(); })
      .catch(function (e) { el.innerHTML = '<div class="spx-vacio">' + esc(e.message || e) + '</div>'; });
  }

  window.APOLANA_PAYOUTS = { montar: montar, lista: lista, detalle: detalle, excel: excel };
})();
