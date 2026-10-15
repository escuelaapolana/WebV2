/* ============================================================
   NUEVO COBRO · asistente de admin/dinero (mig 380)
   ------------------------------------------------------------
   4 pasos + resumen:  ¿A quién? · ¿Qué? · ¿Cada cuánto? · ¿Cómo se paga?
   No inventa circuitos: la base (cobro_asistente_crear) reparte en los que
   ya existen:
     · una vez / remesa / efectivo → recibos en `pagos` (cobro_grupo_lineas)
     · recurrente + SEPA / tarjeta → `cuotas_entreno` (suscripción de Stripe,
       enlace por correo con entreno-enlace)
   El resumen se calcula EN LA BASE (simular: true) antes de crear nada.
   «Enviar los enlaces por correo» va aparte y con su confirmación.

   Uso:  APOLANA_NUEVO_COBRO.abrir(sb, { alCrear: function (res) {} })
   Necesita admin-tabbar.js (apoConfirm / apoToast) y panel-piezas.css.
   ============================================================ */
(function () {
  'use strict';

  var MESES = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
  var FREC = {
    unica:      { t: 'Una sola vez', d: 'Un único cobro.', paso: 0 },
    mensual:    { t: 'Mensual',      d: 'Cada mes, hasta la fecha de fin.', paso: 1 },
    trimestral: { t: 'Trimestral',   d: 'Cada 3 meses, hasta la fecha de fin.', paso: 3 },
    anual:      { t: 'Anual',        d: 'Una vez al año, hasta la fecha de fin.', paso: 12 }
  };
  var METODO = {
    tarjeta:  { t: 'Tarjeta',               d: 'La persona paga desde su app o con el enlace del correo. Cobro al momento.' },
    sepa:     { t: 'Domiciliación SEPA',    d: 'Mete su IBAN una vez (Stripe) y se cobra sola. El adeudo tarda unos días.' },
    remesa:   { t: 'Remesa de Isa',         d: 'Recibo domiciliado que pasa Isa por el banco. La familia no lo ve en la app.' },
    efectivo: { t: 'Efectivo',              d: 'Te pagan en mano y lo marcas tú como pagado en Dinero.' }
  };
  var SECCION = {
    escuela: 'Escuela de atletismo', cubo: 'El Cubo', natacion: 'Natación', 'escuela-natacion': 'Escuela de natación',
    competicion: 'Pista / competición', running: 'Running', socios: 'Socios'
  };

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function eur(n) {
    var v = Number(n) || 0, dec = Math.round(v * 100) % 100 !== 0;
    return v.toLocaleString('es-ES', { minimumFractionDigits: dec ? 2 : 0, maximumFractionDigits: 2 }) + ' €';
  }
  function num(v) { var n = Number(String(v == null ? '' : v).replace(',', '.')); return isFinite(n) ? Math.round(n * 100) / 100 : NaN; }
  function pad(n) { return String(n).padStart(2, '0'); }
  function hoy() { var d = new Date(); return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function masDias(iso, n) { var d = new Date(iso + 'T12:00:00'); d.setDate(d.getDate() + n); return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function mesTxt(k) { if (!k) return ''; var p = String(k).split('-'); return MESES[(+p[1]) - 1] + ' ' + p[0]; }
  function mesCorto(k) { var p = String(k).split('-'); return MESES[(+p[1]) - 1].slice(0, 3) + (p[0] !== hoy().slice(0, 4) ? ' ' + p[0].slice(2) : ''); }
  function fechaLarga(iso) { if (!iso) return ''; var p = String(iso).slice(0, 10).split('-'); return (+p[2]) + ' de ' + MESES[(+p[1]) - 1] + ' de ' + p[0]; }
  function sumaMeses(k, n) { var p = k.split('-'), y = +p[0], m = +p[1] - 1 + n; return (y + Math.floor(m / 12)) + '-' + pad((m % 12 + 12) % 12 + 1); }
  function finDeMes(k) { var p = k.split('-'); var d = new Date(+p[0], +p[1], 0); return k + '-' + pad(d.getDate()); }
  function finTemporada(k) { var p = k.split('-'); var y = +p[1] >= 7 ? +p[0] + 1 : +p[0]; return y + '-06-30'; }
  function nombre(p) { return ((p.nombre || '') + ' ' + (p.apellidos || '')).trim() || 'Sin nombre'; }
  function toast(m, t) { if (window.apoToast) window.apoToast(m, t || 'info'); }
  async function confirmar(o) { if (window.apoConfirm) return window.apoConfirm(o); return window.confirm((o.titulo ? o.titulo + '\n\n' : '') + (o.texto || '')); }

  /* Plazos (meses YYYY-MM) igual que la base: inicio + k·paso mientras ≤ fin. */
  function plazos(S) {
    if (!S.inicio) return [];
    if (S.frecuencia === 'unica') return [S.inicio];
    if (!S.fin) return [];
    var out = [], k = S.inicio, paso = FREC[S.frecuencia].paso;
    while ((k + '-01') <= S.fin && out.length < 40) { out.push(k); k = sumaMeses(k, paso); }
    return out;
  }
  var esStripe = function (S) { return S.frecuencia !== 'unica' && (S.metodo === 'sepa' || S.metodo === 'tarjeta'); };

  /* ============================================================ ESTILOS */
  function estilos() {
    if (document.getElementById('nc-estilos')) return;
    var st = document.createElement('style');
    st.id = 'nc-estilos';
    st.textContent = [
      '.nc-fondo{position:fixed;inset:0;z-index:9990;background:rgba(46,66,86,.45);display:flex;align-items:flex-start;justify-content:center;padding:4vh 16px;overflow-y:auto;}',
      '.nc-caja{background:#fff;border:1px solid var(--linea-marcada);border-radius:16px;box-shadow:var(--sombra-hero);width:100%;max-width:780px;overflow:hidden;display:flex;flex-direction:column;}',
      '.nc-cab{background:var(--crema-banda);border-bottom:1px solid var(--crema-media);padding:14px 18px;display:flex;align-items:center;gap:12px;}',
      '.nc-cab h2{margin:0;font-family:var(--fuente-titulo);font-size:21px;color:var(--navy);text-transform:uppercase;letter-spacing:-.01em;}',
      '.nc-cerrar{margin-left:auto;border:0;background:transparent;font-size:22px;line-height:1;color:var(--texto-suave);cursor:pointer;min-width:44px;min-height:44px;border-radius:10px;}',
      '.nc-cerrar:hover{background:#fff;color:var(--navy);}',
      '.nc-pasos{display:flex;gap:4px;padding:10px 18px 0;flex-wrap:wrap;}',
      '.nc-pasos span{font-size:13px;font-weight:600;color:var(--texto-suave);padding:6px 10px;border-radius:999px;background:#F6F3EC;white-space:nowrap;}',
      '.nc-pasos span.hecho{color:var(--verde);background:var(--verde-fondo);}',
      '.nc-pasos span.aqui{color:#fff;background:var(--azul);}',
      '.nc-cuerpo{padding:16px 18px 6px;}',
      '.nc-cuerpo h3{margin:4px 0 12px;font-family:var(--fuente-texto);font-size:18px;color:var(--navy);}',
      '.nc-ayuda{font-size:13.5px;color:var(--texto-suave);line-height:1.5;margin:6px 0 0;}',
      '.nc-seg{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:14px;}',
      '.nc-seg button{flex:1 1 150px;min-height:44px;border:1px solid var(--linea-marcada);background:#fff;border-radius:12px;font:inherit;font-size:15px;font-weight:600;color:var(--navy);cursor:pointer;padding:8px 12px;}',
      '.nc-seg button[aria-pressed="true"]{border-color:var(--azul);background:var(--azul-suave);color:var(--azul-hover);box-shadow:inset 0 0 0 1px var(--azul);}',
      '.nc-in,.nc-sel{width:100%;min-height:46px;box-sizing:border-box;border:1px solid var(--pz-borde,#C6BEAE);border-radius:10px;background:#fff;font:inherit;font-size:16px;color:var(--navy);padding:9px 12px;}',
      '.nc-in:focus,.nc-sel:focus{outline:2px solid var(--azul);outline-offset:1px;border-color:var(--azul);}',
      '.nc-lab{display:block;font-size:13.5px;font-weight:600;color:var(--texto-suave);margin:12px 0 5px;}',
      '.nc-fila{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:4px 14px;}',
      '.nc-lista{border:1px solid var(--linea-marcada);border-radius:12px;margin-top:10px;max-height:320px;overflow-y:auto;background:#fff;}',
      '.nc-item{display:flex;align-items:center;gap:10px;padding:9px 12px;border-bottom:1px solid var(--crema-media);min-height:44px;box-sizing:border-box;}',
      '.nc-item:last-child{border-bottom:0;}',
      'button.nc-item{width:100%;border-left:0;border-right:0;border-top:0;background:#fff;font:inherit;text-align:left;cursor:pointer;}',
      'button.nc-item:hover{background:var(--azul-suave);}',
      '.nc-item .c{display:block;flex:1;min-width:0;}',
      '.nc-item b{display:block;color:var(--navy);font-weight:600;font-size:15px;overflow-wrap:anywhere;}',
      '.nc-item small{display:block;color:var(--texto-suave);font-size:13px;margin-top:1px;}',
      '.nc-item input[type=checkbox]{width:20px;height:20px;accent-color:var(--azul);flex:0 0 auto;}',
      '.nc-item .imp{width:110px;flex:0 0 110px;min-height:40px;}',
      '.nc-item .x{border:0;background:transparent;color:var(--texto-suave);font-size:18px;min-width:40px;min-height:40px;border-radius:8px;cursor:pointer;}',
      '.nc-item .x:hover{background:#FBF0ED;color:var(--rojo);}',
      '.nc-chip{display:inline-flex;align-items:center;gap:4px;font-size:12px;font-weight:600;padding:2px 8px;border-radius:999px;margin-left:6px;background:#FDF6EA;color:#8A5207;border:1px solid #EBD9B8;vertical-align:middle;}',
      '.nc-tarjetas{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:10px;}',
      '.nc-op{display:block;text-align:left;border:1px solid var(--linea-marcada);background:#fff;border-radius:14px;padding:12px 14px;cursor:pointer;font:inherit;box-shadow:var(--sombra-suave);min-height:44px;}',
      '.nc-op b{display:block;color:var(--navy);font-size:15.5px;}',
      '.nc-op span{display:block;color:var(--texto-suave);font-size:13px;line-height:1.4;margin-top:3px;}',
      '.nc-op:hover{border-color:var(--azul);}',
      '.nc-op[aria-pressed="true"]{border-color:var(--azul);background:var(--azul-suave);box-shadow:inset 0 0 0 1px var(--azul),var(--sombra-suave);}',
      '.nc-op[disabled]{opacity:.5;cursor:not-allowed;box-shadow:none;}',
      '.nc-total{margin-top:12px;padding:11px 14px;border-radius:12px;background:#FDFCF9;border:1px solid var(--crema-media);font-size:14.5px;color:var(--texto);line-height:1.5;}',
      '.nc-total b{color:var(--navy);}',
      '.nc-aviso{margin-top:12px;padding:11px 14px;border-radius:12px;background:#FDF6EA;border:1px solid #EBD9B8;color:#6B4A12;font-size:14px;line-height:1.5;}',
      '.nc-error{margin-top:10px;padding:10px 14px;border-radius:12px;background:#FBF0ED;border:1px solid #EBD2CB;color:var(--rojo);font-size:14px;}',
      '.nc-error:empty{display:none;}',
      '.nc-res{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin-bottom:12px;}',
      '.nc-res div{background:#fff;border:1px solid var(--linea-marcada);border-radius:12px;padding:10px 12px;box-shadow:var(--sombra-suave);}',
      '.nc-res .k{display:block;font-size:11.5px;font-weight:600;letter-spacing:.03em;text-transform:uppercase;color:var(--texto-suave);}',
      '.nc-res .v{display:block;font-family:var(--fuente-dato);font-weight:700;font-size:18px;color:var(--navy);margin-top:2px;font-variant-numeric:tabular-nums;}',
      '.nc-res .s{display:block;font-size:12.5px;color:var(--texto-suave);margin-top:2px;}',
      '.nc-que{font-size:14.5px;line-height:1.6;color:var(--texto);margin:0 0 6px;}',
      '.nc-que li{margin:3px 0;}',
      '.nc-pie{display:flex;gap:10px;align-items:center;flex-wrap:wrap;padding:14px 18px;border-top:1px solid var(--crema-media);background:#FDFCF9;margin-top:12px;}',
      '.nc-pie .der{margin-left:auto;display:flex;gap:10px;flex-wrap:wrap;}',
      '.nc-check{display:flex;gap:10px;align-items:flex-start;margin-top:12px;font-size:14.5px;color:var(--texto);cursor:pointer;}',
      '.nc-check input{width:20px;height:20px;accent-color:var(--azul);margin-top:1px;}',
      '.nc-ok{padding:12px 14px;border-radius:12px;background:var(--verde-fondo);border:1px solid var(--verde-borde);color:var(--verde);font-size:15px;line-height:1.5;margin-bottom:12px;}',
      '@media (max-width:640px){.nc-fondo{padding:0;}.nc-caja{border-radius:0;min-height:100%;border:0;}.nc-pie{position:sticky;bottom:0;}.nc-pie .der{width:100%;}.nc-pie .der .pz-btn{flex:1 1 auto;}.nc-item .imp{width:92px;flex-basis:92px;}}'
    ].join('\n');
    document.head.appendChild(st);
  }

  /* ============================================================ ASISTENTE */
  function abrir(sb, opciones) {
    opciones = opciones || {};
    estilos();
    var mesHoy = hoy().slice(0, 7);
    var S = {
      paso: 1, modo: 'grupo', personas: [], quitar: {}, grupo: '', resultados: [],
      concepto: '', igual: true, importe: '', importes: {},
      frecuencia: 'unica', inicio: mesHoy, fin: finTemporada(mesHoy), finAuto: true, vencimiento: masDias(hoy(), 14),
      metodo: '', cuenta: '', dia: 5, notas: '', guardar: false, guardarTocado: false,
      datos: null, sim: null, creado: null, ocupado: false
    };
    var previo = document.activeElement;
    var fondo = document.createElement('div');
    fondo.className = 'nc-fondo';
    fondo.innerHTML = '<div class="nc-caja" role="dialog" aria-modal="true" aria-labelledby="nc-tit">' +
      '<div class="nc-cab"><h2 id="nc-tit">Nuevo cobro</h2><button type="button" class="nc-cerrar" aria-label="Cerrar">✕</button></div>' +
      '<div class="nc-pasos" id="nc-pasos"></div><div class="nc-cuerpo" id="nc-cuerpo"></div>' +
      '<div class="nc-error" id="nc-error" role="alert" style="margin:0 18px"></div>' +
      '<div class="nc-pie" id="nc-pie"></div></div>';
    document.body.appendChild(fondo);
    document.documentElement.style.overflow = 'hidden';
    var $ = function (sel) { return fondo.querySelector(sel); };

    function cerrarYa() {
      document.removeEventListener('keydown', alTeclado, true);
      document.documentElement.style.overflow = '';
      if (fondo.parentNode) fondo.parentNode.removeChild(fondo);
      if (previo && previo.focus) { try { previo.focus(); } catch (e) {} }
    }
    async function cerrar() {
      if (S.creado || (S.paso === 1 && !activas().length)) { cerrarYa(); return; }
      var ok = await confirmar({ titulo: 'Cerrar sin crear', texto: 'Todavía no se ha creado nada. ¿Cerrar el asistente?', confirmar: 'Cerrar' });
      if (ok) cerrarYa();
    }
    function alTeclado(e) { if (e.key === 'Escape' && !document.querySelector('.apo-modal-fondo')) { e.preventDefault(); cerrar(); } }
    document.addEventListener('keydown', alTeclado, true);
    $('.nc-cerrar').addEventListener('click', cerrar);
    fondo.addEventListener('click', function (e) {
      var a = e.target.closest && e.target.closest('a[data-nav]');
      if (a) cerrarYa();   // la navegación la hace la página (Dinero)
    });

    function error(m) { $('#nc-error').textContent = m || ''; }
    function activas() { return S.personas.filter(function (p) { return !S.quitar[p.id]; }); }
    function importeDe(p) { return S.igual ? num(S.importe) : num(S.importes[p.id]); }
    function lineas() {
      return activas().map(function (p) { return { atleta_id: p.id, importe: importeDe(p) }; })
        .filter(function (l) { return l.importe > 0; });
    }
    function seccionMayoria() {
      var c = {}; activas().forEach(function (p) { c[p.seccion || ''] = (c[p.seccion || ''] || 0) + 1; });
      return Object.keys(c).sort(function (a, b) { return c[b] - c[a]; })[0] || '';
    }

    /* ---------------- pasos ---------------- */
    var NOMBRES = ['¿A quién?', '¿Qué?', '¿Cada cuánto?', '¿Cómo se paga?', 'Resumen'];
    function pintar() {
      error('');
      $('#nc-pasos').innerHTML = NOMBRES.map(function (n, i) {
        var k = i + 1;
        return '<span class="' + (k === S.paso ? 'aqui' : k < S.paso ? 'hecho' : '') + '"' + (k === S.paso ? ' aria-current="step"' : '') + '>' + k + ' · ' + esc(n) + '</span>';
      }).join('');
      [null, paso1, paso2, paso3, paso4, paso5][S.paso]();
      pie();
    }
    function pie() {
      var html = '';
      if (S.creado) {
        html = '<div class="der"><button type="button" class="pz-btn pz-btn--borde" data-a="cerrar">Cerrar</button></div>';
      } else {
        html = (S.paso > 1 ? '<button type="button" class="pz-btn pz-btn--borde" data-a="atras">← Atrás</button>' : '') +
          '<div class="der">' + (S.paso < 5
            ? '<button type="button" class="pz-btn" data-a="sig">Siguiente →</button>'
            : '<button type="button" class="pz-btn" data-a="crear"' + (S.sim && S.sim.creados > 0 && !S.ocupado ? '' : ' disabled') + '>Crear</button>') +
          '</div>';
      }
      $('#nc-pie').innerHTML = html;
      $('#nc-pie').querySelectorAll('[data-a]').forEach(function (b) {
        b.addEventListener('click', function () {
          var a = b.getAttribute('data-a');
          if (a === 'cerrar') cerrarYa();
          else if (a === 'atras') { S.paso--; S.sim = null; pintar(); }
          else if (a === 'sig') siguiente();
          else if (a === 'crear') crear(b);
        });
      });
    }
    function siguiente() {
      var m = validar(S.paso);
      if (m) { error(m); return; }
      S.paso++;
      pintar();
      var f = $('#nc-cuerpo input, #nc-cuerpo select, #nc-cuerpo button');
      if (f && S.paso < 5) try { f.focus({ preventScroll: true }); } catch (e) {}
    }
    function validar(k) {
      if (k === 1 && !activas().length) return 'Elige al menos a una persona.';
      if (k === 2) {
        if (!S.concepto.trim()) return 'Falta el concepto (lo que verá la persona en su recibo).';
        if (S.igual && !(num(S.importe) > 0)) return 'Pon el importe.';
        if (num(S.importe) > 5000 || activas().some(function (p) { return importeDe(p) > 5000; })) return 'Hay un importe de más de 5.000 €: revísalo.';
        if (!lineas().length) return 'Pon el importe de al menos una persona.';
      }
      if (k === 3) {
        if (!/^\d{4}-\d{2}$/.test(S.inicio || '')) return 'Elige el mes de inicio.';
        if (S.frecuencia !== 'unica') {
          if (!S.fin) return 'Pon la fecha de fin: la cuota se para sola ese día.';
          if (S.fin < S.inicio + '-01') return 'La fecha de fin es anterior al mes de inicio.';
          if (plazos(S).length > 36) return 'Demasiados plazos (máx. 36).';
        }
      }
      if (k === 4) {
        if (!S.metodo) return 'Elige cómo se paga.';
        if (S.frecuencia === 'unica' && S.metodo === 'sepa') return 'Una sola vez no va por SEPA: elige tarjeta, remesa o efectivo.';
        if (S.metodo === 'remesa' && !S.cuenta) return 'Di a qué cuenta va la remesa (escuela o club).';
        if (esStripe(S) && S.inicio < mesHoy) return 'Con tarjeta o SEPA el mes de inicio no puede ser un mes pasado (vuelve al paso 3).';
        if (esStripe(S) && S.fin < hoy()) return 'La fecha de fin ya ha pasado (vuelve al paso 3).';
      }
      return '';
    }

    /* ---------------- 1 · ¿A quién? ---------------- */
    function filaPersona(p, extra) {
      var sub = [SECCION[p.seccion] || p.seccion, p.grupo].filter(Boolean).join(' · ');
      var chips = (p.tiene_correo ? '' : '<span class="nc-chip">sin correo</span>') + (p.tiene_cuenta ? '' : '<span class="nc-chip">sin cuenta en la app</span>');
      return '<span class="c"><b>' + esc(nombre(p)) + chips + '</b><small>' + esc(sub || 'Sin grupo') + (p.estado === 'prueba' ? ' · de prueba' : '') + '</small></span>' + (extra || '');
    }
    function paso1() {
      var c = $('#nc-cuerpo');
      c.innerHTML = '<h3>¿A quién le cobras?</h3>' +
        '<div class="nc-seg" role="group" aria-label="A quién">' +
          ['persona', 'grupo', 'varias'].map(function (m) {
            return '<button type="button" data-m="' + m + '" aria-pressed="' + (S.modo === m) + '">' + { persona: 'Una persona', grupo: 'Un grupo', varias: 'Varias personas' }[m] + '</button>';
          }).join('') + '</div><div id="nc-p1"></div>';
      c.querySelectorAll('[data-m]').forEach(function (b) {
        b.addEventListener('click', function () {
          var m = b.getAttribute('data-m');
          if (m === S.modo) return;
          S.modo = m; S.personas = []; S.quitar = {}; S.grupo = ''; S.resultados = []; S.importes = {};
          paso1();
        });
      });
      var d = $('#nc-p1');
      if (S.modo === 'grupo') {
        var gs = (S.datos && S.datos.grupos) || [];
        var porSec = {};
        gs.forEach(function (g) { (porSec[g.seccion || ''] = porSec[g.seccion || ''] || []).push(g); });
        d.innerHTML = '<label class="nc-lab" for="nc-grupo">Grupo</label>' +
          '<select class="nc-sel" id="nc-grupo"><option value="">— Elige un grupo —</option>' +
          Object.keys(porSec).sort().map(function (s) {
            return '<optgroup label="' + esc(SECCION[s] || s || 'Otros') + '">' + porSec[s].map(function (g) {
              return '<option value="' + esc(g.clave) + '"' + (g.clave === S.grupo ? ' selected' : '') + '>' + esc(g.nombre) + ' (' + g.n + ')</option>';
            }).join('') + '</optgroup>';
          }).join('') + '</select>' +
          '<p class="nc-ayuda">Natación sale por sus inscripciones (escuela por nivel y máster). Puedes quitar a quien no deba pagar.</p>' +
          '<div id="nc-gente"></div>';
        $('#nc-grupo').addEventListener('change', function () { S.grupo = this.value; S.quitar = {}; S.importes = {}; cargarGrupo(); });
        pintarGente();
      } else {
        d.innerHTML = '<label class="nc-lab" for="nc-q">Buscar por nombre</label>' +
          '<input class="nc-in" type="search" id="nc-q" autocomplete="off" placeholder="Escribe un nombre: Lucía, García…">' +
          '<div id="nc-resul"></div>' +
          (S.modo === 'varias' ? '<div id="nc-gente"></div>' : '<div id="nc-elegida"></div>');
        var t = null;
        $('#nc-q').addEventListener('input', function () { var v = this.value; clearTimeout(t); t = setTimeout(function () { buscar(v); }, 250); });
        pintarGente();
      }
    }
    async function cargarGrupo() {
      S.personas = [];
      var g = $('#nc-gente');
      if (!S.grupo) { pintarGente(); return; }
      if (g) g.innerHTML = '<p class="nc-ayuda">Cargando personas…</p>';
      var r = await sb.rpc('cobro_asistente_personas', { p_q: null, p_grupo: S.grupo, p_ids: null });
      if (r.error) { error('No se pudieron leer las personas: ' + r.error.message); return; }
      S.personas = r.data || [];
      pintarGente();
    }
    async function buscar(q) {
      var caja = $('#nc-resul'); if (!caja) return;
      q = String(q || '').trim();
      if (q.length < 2) { caja.innerHTML = ''; return; }
      var r = await sb.rpc('cobro_asistente_personas', { p_q: q, p_grupo: null, p_ids: null });
      if (r.error) { caja.innerHTML = '<p class="nc-error">' + esc(r.error.message) + '</p>'; return; }
      var ya = {}; S.personas.forEach(function (p) { ya[p.id] = 1; });
      var lista = (r.data || []).filter(function (p) { return !ya[p.id]; });
      S.resultados = lista;
      caja.innerHTML = lista.length
        ? '<div class="nc-lista" role="listbox" aria-label="Resultados">' + lista.map(function (p, i) {
            return '<button type="button" class="nc-item" data-i="' + i + '">' + filaPersona(p, '<span class="pz-btn--texto" style="font-weight:600;color:var(--azul)">' + (S.modo === 'persona' ? 'Elegir' : '+ Añadir') + '</span>') + '</button>';
          }).join('') + '</div>'
        : '<p class="nc-ayuda">Nadie con «' + esc(q) + '».</p>';
      caja.querySelectorAll('[data-i]').forEach(function (b) {
        b.addEventListener('click', function () {
          var p = S.resultados[+b.getAttribute('data-i')];
          if (S.modo === 'persona') { S.personas = [p]; caja.innerHTML = ''; $('#nc-q').value = ''; }
          else { S.personas.push(p); b.remove(); }
          pintarGente();
        });
      });
    }
    function pintarGente() {
      if (S.modo === 'persona') {
        var e = $('#nc-elegida'); if (!e) return;
        e.innerHTML = S.personas.length ? '<div class="nc-lista">' + '<div class="nc-item">' + filaPersona(S.personas[0], '<button type="button" class="x" aria-label="Quitar">✕</button>') + '</div></div>' : '';
        var x = e.querySelector('.x'); if (x) x.addEventListener('click', function () { S.personas = []; pintarGente(); });
        return;
      }
      var g = $('#nc-gente'); if (!g) return;
      if (!S.personas.length) { g.innerHTML = S.modo === 'grupo' && S.grupo ? '<p class="nc-ayuda">Este grupo no tiene personas activas.</p>' : ''; return; }
      var n = activas().length;
      g.innerHTML = '<div class="nc-total"><b>' + n + '</b> de ' + S.personas.length + (S.personas.length === 1 ? ' persona' : ' personas') + ' seleccionadas' +
        (S.modo === 'grupo' ? ' · <a href="#" id="nc-todas" style="color:var(--azul)">todas</a> · <a href="#" id="nc-ninguna" style="color:var(--azul)">ninguna</a>' : '') + '</div>' +
        '<div class="nc-lista">' + S.personas.map(function (p) {
          return S.modo === 'grupo'
            ? '<label class="nc-item"><input type="checkbox" data-id="' + esc(p.id) + '"' + (S.quitar[p.id] ? '' : ' checked') + '>' + filaPersona(p) + '</label>'
            : '<div class="nc-item">' + filaPersona(p, '<button type="button" class="x" data-x="' + esc(p.id) + '" aria-label="Quitar a ' + esc(nombre(p)) + '">✕</button>') + '</div>';
        }).join('') + '</div>';
      g.querySelectorAll('input[data-id]').forEach(function (c) {
        c.addEventListener('change', function () { if (c.checked) delete S.quitar[c.getAttribute('data-id')]; else S.quitar[c.getAttribute('data-id')] = 1; pintarGente(); });
      });
      g.querySelectorAll('[data-x]').forEach(function (b) {
        b.addEventListener('click', function () { var id = b.getAttribute('data-x'); S.personas = S.personas.filter(function (p) { return p.id !== id; }); pintarGente(); });
      });
      var t = $('#nc-todas'), nn = $('#nc-ninguna');
      if (t) t.addEventListener('click', function (e) { e.preventDefault(); S.quitar = {}; pintarGente(); });
      if (nn) nn.addEventListener('click', function (e) { e.preventDefault(); S.personas.forEach(function (p) { S.quitar[p.id] = 1; }); pintarGente(); });
    }

    /* ---------------- 2 · ¿Qué? ---------------- */
    function paso2() {
      var c = $('#nc-cuerpo');
      var gente = activas();
      if (gente.length === 1) S.igual = true;
      // Precarga del importe recordado en la ficha (cuota_importe).
      gente.forEach(function (p) { if (S.importes[p.id] == null && p.cuota_importe != null) S.importes[p.id] = String(p.cuota_importe); });
      if (S.importe === '' && gente.length) {
        var vals = gente.map(function (p) { return p.cuota_importe; }).filter(function (v) { return v != null; });
        if (vals.length === gente.length && vals.every(function (v) { return Number(v) === Number(vals[0]); })) S.importe = String(vals[0]);
      }
      c.innerHTML = '<h3>¿Qué se cobra?</h3>' +
        '<label class="nc-lab" for="nc-con">Concepto</label>' +
        '<input class="nc-in" id="nc-con" maxlength="120" placeholder="Cuota de entrenamiento · temporada 2026/27" value="' + esc(S.concepto) + '">' +
        '<p class="nc-ayuda">Es lo que verá la persona en su recibo o en la pantalla de pago.</p>' +
        (gente.length > 1 ? '<div class="nc-seg" role="group" aria-label="Importe" style="margin-top:14px">' +
          '<button type="button" data-ig="1" aria-pressed="' + S.igual + '">El mismo importe para todos</button>' +
          '<button type="button" data-ig="0" aria-pressed="' + !S.igual + '">Distinto por persona</button></div>' : '') +
        '<div id="nc-imp"></div><div id="nc-tot"></div>';
      $('#nc-con').addEventListener('input', function () { S.concepto = this.value; });
      c.querySelectorAll('[data-ig]').forEach(function (b) {
        b.addEventListener('click', function () { S.igual = b.getAttribute('data-ig') === '1'; paso2(); });
      });
      var d = $('#nc-imp');
      if (S.igual) {
        d.innerHTML = '<label class="nc-lab" for="nc-im">Importe por persona (€)' + (S.frecuencia !== 'unica' ? ', en cada cobro' : '') + '</label>' +
          '<input class="nc-in" id="nc-im" type="number" inputmode="decimal" step="0.01" min="0" style="max-width:220px" value="' + esc(S.importe) + '">';
        $('#nc-im').addEventListener('input', function () { S.importe = this.value; total(); });
      } else {
        d.innerHTML = '<p class="nc-ayuda" style="margin-top:4px">Sale el importe que tienen guardado en su ficha. Deja vacío a quien no deba pagar.</p>' +
          '<div class="nc-lista">' + gente.map(function (p) {
            return '<div class="nc-item"><div class="c"><b>' + esc(nombre(p)) + '</b><small>' + esc([p.grupo, p.cuota_periodicidad ? 'ficha: ' + eur(p.cuota_importe) + ' ' + p.cuota_periodicidad : ''].filter(Boolean).join(' · ')) + '</small></div>' +
              '<input class="nc-in imp" type="number" inputmode="decimal" step="0.01" min="0" placeholder="€" data-id="' + esc(p.id) + '" value="' + esc(S.importes[p.id] == null ? '' : S.importes[p.id]) + '" aria-label="Importe de ' + esc(nombre(p)) + '"></div>';
          }).join('') + '</div>';
        d.querySelectorAll('input[data-id]').forEach(function (i) {
          i.addEventListener('input', function () { S.importes[i.getAttribute('data-id')] = i.value; total(); });
        });
      }
      total();
    }
    function total() {
      var t = $('#nc-tot'); if (!t) return;
      var ls = lineas();
      var sum = ls.reduce(function (s, l) { return s + l.importe; }, 0);
      var sin = activas().length - ls.length;
      t.innerHTML = '<div class="nc-total"><b>' + ls.length + '</b> ' + (ls.length === 1 ? 'persona' : 'personas') + ' · <b>' + eur(sum) + '</b> en total' + (S.frecuencia !== 'unica' ? ' en cada cobro' : '') +
        (sin > 0 ? ' · ' + sin + ' sin importe (no se les cobra)' : '') + '</div>';
    }

    /* ---------------- 3 · ¿Cada cuánto? ---------------- */
    function paso3() {
      var c = $('#nc-cuerpo');
      c.innerHTML = '<h3>¿Cada cuánto?</h3><div class="nc-tarjetas" role="group" aria-label="Cada cuánto">' +
        Object.keys(FREC).map(function (k) {
          return '<button type="button" class="nc-op" data-f="' + k + '" aria-pressed="' + (S.frecuencia === k) + '"><b>' + FREC[k].t + '</b><span>' + FREC[k].d + '</span></button>';
        }).join('') + '</div><div id="nc-cuando"></div>';
      c.querySelectorAll('[data-f]').forEach(function (b) {
        b.addEventListener('click', function () {
          S.frecuencia = b.getAttribute('data-f');
          if (S.frecuencia === 'anual') S.fin = finDeMes(sumaMeses(S.inicio, 11));
          else if (S.frecuencia !== 'unica' && (!S.fin || S.fin < S.inicio + '-01' || S.finAuto)) S.fin = finTemporada(S.inicio);
          S.finAuto = true;
          if (!S.guardarTocado) S.guardar = S.frecuencia !== 'unica';
          if (S.frecuencia === 'unica' && S.metodo === 'sepa') S.metodo = '';
          paso3();
        });
      });
      var d = $('#nc-cuando');
      var html = '<div class="nc-fila"><div><label class="nc-lab" for="nc-ini">' + (S.frecuencia === 'unica' ? 'Mes del cobro' : 'Mes de inicio') + '</label>' +
        '<input class="nc-in" type="month" id="nc-ini" value="' + esc(S.inicio) + '"></div>';
      if (S.frecuencia === 'unica') {
        html += '<div><label class="nc-lab" for="nc-ven">Fecha límite (en remesa, fecha del cargo)</label><input class="nc-in" type="date" id="nc-ven" value="' + esc(S.vencimiento) + '"></div></div>' +
          '<p class="nc-ayuda">Pasada la fecha límite, en Dinero sale como «fuera de plazo».</p>';
      } else {
        html += '<div><label class="nc-lab" for="nc-fin">Fecha de fin (se para sola)</label><input class="nc-in" type="date" id="nc-fin" value="' + esc(S.fin) + '"></div></div>';
        var pz = plazos(S);
        html += '<div class="nc-total">' + (pz.length
          ? '<b>' + pz.length + (pz.length === 1 ? ' cobro' : ' cobros') + '</b>: ' + pz.map(mesCorto).join(', ') + '. Tras el ' + esc(fechaLarga(S.fin)) + ' no se cobra nada más.'
          : 'Con esas fechas no sale ningún cobro.') + '</div>' +
          '<p class="nc-ayuda">Con tarjeta o SEPA, si el mes de inicio es el actual, el primer cobro se hace al pagar o domiciliar y luego cada periodo en esa fecha; si es un mes futuro, el día 1 de ese mes.</p>';
      }
      d.innerHTML = html;
      $('#nc-ini').addEventListener('change', function () {
        S.inicio = this.value;
        if (S.frecuencia === 'anual' && S.finAuto) S.fin = finDeMes(sumaMeses(S.inicio, 11));
        else if (S.frecuencia !== 'unica' && S.finAuto) S.fin = finTemporada(S.inicio);
        paso3();
      });
      if ($('#nc-ven')) $('#nc-ven').addEventListener('change', function () { S.vencimiento = this.value; });
      if ($('#nc-fin')) $('#nc-fin').addEventListener('change', function () { S.fin = this.value; S.finAuto = false; paso3(); });
    }

    /* ---------------- 4 · ¿Cómo se paga? ---------------- */
    function paso4() {
      var c = $('#nc-cuerpo');
      if (S.metodo === 'remesa' && !S.cuenta) S.cuenta = seccionMayoria() === 'escuela' ? 'escuela' : 'club';
      c.innerHTML = '<h3>¿Cómo se paga?</h3><div class="nc-tarjetas" role="group" aria-label="Cómo se paga">' +
        Object.keys(METODO).map(function (k) {
          var no = k === 'sepa' && S.frecuencia === 'unica';
          return '<button type="button" class="nc-op" data-me="' + k + '" aria-pressed="' + (S.metodo === k) + '"' + (no ? ' disabled title="Para una sola vez: tarjeta, remesa o efectivo"' : '') + '><b>' + METODO[k].t + '</b><span>' +
            (no ? 'Solo para cuotas que se repiten.' : METODO[k].d) + '</span></button>';
        }).join('') + '</div><div id="nc-como"></div>';
      c.querySelectorAll('[data-me]').forEach(function (b) {
        b.addEventListener('click', function () { if (b.disabled) return; S.metodo = b.getAttribute('data-me'); paso4(); });
      });
      var d = $('#nc-como'), html = '';
      if (S.metodo === 'remesa') {
        html += '<div class="nc-fila"><div><label class="nc-lab" for="nc-cta">Cuenta</label><select class="nc-sel" id="nc-cta">' +
          '<option value="escuela"' + (S.cuenta === 'escuela' ? ' selected' : '') + '>Escuela</option>' +
          '<option value="club"' + (S.cuenta === 'club' ? ' selected' : '') + '>Club / socios</option></select></div>';
        html += S.frecuencia !== 'unica' ? '<div><label class="nc-lab" for="nc-dia">Día del cargo de cada plazo</label><input class="nc-in" type="number" id="nc-dia" min="1" max="28" value="' + esc(S.dia) + '"></div>' : '';
        html += '</div>';
      } else if (S.metodo === 'efectivo' && S.frecuencia !== 'unica') {
        html += '<div class="nc-fila"><div><label class="nc-lab" for="nc-dia">Fecha límite de cada plazo (día del mes)</label><input class="nc-in" type="number" id="nc-dia" min="1" max="28" value="' + esc(S.dia) + '"></div></div>';
      }
      if (S.metodo) {
        html += '<label class="nc-lab" for="nc-not">Notas (opcional, solo para el club)</label><input class="nc-in" id="nc-not" maxlength="200" value="' + esc(S.notas) + '">';
        html += '<label class="nc-check"><input type="checkbox" id="nc-guarda"' + (S.guardar ? ' checked' : '') + '> <span>Recordar este importe en la ficha de cada persona (para la próxima vez).</span></label>';
      }
      var sinCuenta = activas().filter(function (p) { return !p.tiene_cuenta; }).length;
      var sinCorreo = activas().filter(function (p) { return !p.tiene_correo; }).length;
      var cfg = (S.datos && S.datos.config) || {};
      if (S.metodo === 'tarjeta' && S.frecuencia === 'unica' && sinCuenta)
        html += '<div class="nc-aviso"><b>' + sinCuenta + '</b> ' + (sinCuenta === 1 ? 'persona no tiene' : 'personas no tienen') + ' cuenta en la app: el recibo con tarjeta se paga desde la app, así que no podrán pagarlo hasta tenerla.</div>';
      if (esStripe(S) && sinCorreo)
        html += '<div class="nc-aviso"><b>' + sinCorreo + '</b> sin correo en su ficha: no se les crea la cuota (no les llegaría el enlace). Ponles el correo y vuelve a crearla.</div>';
      if (S.metodo === 'tarjeta' && cfg.activo === false)
        html += '<div class="nc-aviso">El pago con tarjeta está <b>apagado</b> en la configuración de pagos online: nadie podrá pagar hasta encenderlo.</div>';
      if ((S.metodo === 'tarjeta' || S.metodo === 'sepa') && cfg.modo && cfg.modo !== 'real')
        html += '<div class="nc-aviso">Los pagos están en <b>modo prueba</b>: no se cobrará dinero de verdad.</div>';
      d.innerHTML = html;
      if ($('#nc-cta')) $('#nc-cta').addEventListener('change', function () { S.cuenta = this.value; });
      if ($('#nc-dia')) $('#nc-dia').addEventListener('input', function () { S.dia = Math.min(28, Math.max(1, parseInt(this.value, 10) || 5)); });
      if ($('#nc-not')) $('#nc-not').addEventListener('input', function () { S.notas = this.value; });
      if ($('#nc-guarda')) $('#nc-guarda').addEventListener('change', function () { S.guardar = this.checked; S.guardarTocado = true; });
    }

    /* ---------------- 5 · Resumen (simulado EN LA BASE) ---------------- */
    function cuerpoRPC(simular) {
      return {
        concepto: S.concepto.trim(), frecuencia: S.frecuencia, metodo: S.metodo,
        inicio: S.inicio, fin: S.frecuencia === 'unica' ? null : S.fin,
        vencimiento: S.frecuencia === 'unica' ? (S.vencimiento || null) : null,
        dia_cargo: S.dia, cuenta: S.metodo === 'remesa' ? S.cuenta : null,
        notas: S.notas.trim() || null, guardar_cuota: !!S.guardar,
        lineas: lineas(), simular: !!simular
      };
    }
    function queVaAPasar(r) {
      var n = (r.plazos || []).length;
      var cada = { mensual: 'cada mes', trimestral: 'cada 3 meses', anual: 'cada año' }[S.frecuencia];
      var cfg = (S.datos && S.datos.config) || {};
      var li = [];
      if (S.frecuencia === 'unica' && S.metodo === 'tarjeta') {
        li.push('Se crea un <b>recibo pendiente</b> por persona. Lo paga con tarjeta desde su app (Inicio → «Pagar con tarjeta»).');
        li.push('Si quieres, al terminar puedes mandarles el aviso por correo (aparte, con confirmación).');
        li.push('Comisión de Stripe: la paga el club.');
      } else if (S.metodo === 'remesa') {
        li.push('Se ' + (n > 1 ? 'crean <b>' + n + ' recibos domiciliados</b> por persona (uno por plazo, cargo el día ' + S.dia + ')' : 'crea un <b>recibo domiciliado</b> por persona') + ' para la <b>remesa de Isa</b> (cuenta ' + esc(S.cuenta) + ').');
        li.push('La familia no lo ve en la app. En Dinero sale como «Remesa de Isa» (informativo, no deuda).');
      } else if (S.metodo === 'efectivo') {
        li.push('Se ' + (n > 1 ? 'crean <b>' + n + ' recibos</b> por persona (uno por plazo)' : 'crea un <b>recibo pendiente</b> por persona') + '.');
        li.push('Cuando te paguen en mano: Dinero → Todos los pagos → «Marcar pagado (efectivo)». La persona lo ve como pendiente en su app.');
      } else {
        var tar = S.metodo === 'tarjeta';
        li.push('Cada persona recibe un <b>enlace</b> para ' + (tar ? 'meter su <b>tarjeta</b>' : 'domiciliar su <b>IBAN</b> (SEPA)') + ' una sola vez; también lo ve en el Inicio de su app.');
        li.push((S.inicio > hoy().slice(0, 7) ? 'El primer cobro, el <b>1 de ' + esc(mesTxt(S.inicio)) + '</b>' : 'El primer cobro, al ' + (tar ? 'pagar' : 'domiciliar')) + '; después ' + cada + '. <b>Se para sola el ' + esc(fechaLarga(S.fin)) + '</b>.');
        if (!tar) li.push('SEPA: el adeudo tarda unos 5 días hábiles; mientras, en Dinero sale «en camino».');
        li.push('Comisión de Stripe: ' + (tar && cfg.repercutir_comision ? 'se suma al importe de quien paga (así está configurado el club).' : 'la paga el club.'));
        li.push('Las cuotas se crean <b>sin enviar nada</b>: los correos se mandan aparte, cuando tú lo digas.');
      }
      return '<ul class="nc-que">' + li.map(function (x) { return '<li>' + x + '</li>'; }).join('') + '</ul>';
    }
    async function paso5() {
      var c = $('#nc-cuerpo');
      c.innerHTML = '<h3>Resumen</h3><p class="nc-ayuda">Comprobando en la base…</p>';
      S.sim = null;
      var r = await sb.rpc('cobro_asistente_crear', { p: cuerpoRPC(true) });
      if (S.paso !== 5) return;
      if (r.error) { c.innerHTML = '<h3>Resumen</h3>'; error(r.error.message); pie(); return; }
      S.sim = r.data || {};
      var ls = lineas();
      var imps = ls.map(function (l) { return l.importe; });
      var mn = Math.min.apply(null, imps), mx = Math.max.apply(null, imps);
      var n = (S.sim.plazos || []).length;
      var porId = {}; S.personas.forEach(function (p) { porId[p.id] = nombre(p); });
      var omit = S.sim.omitidos_detalle || [];
      c.innerHTML = '<h3>Resumen</h3>' +
        '<div class="nc-res">' +
          '<div><span class="k">Personas</span><span class="v">' + (S.sim.modo === 'cuotas' ? S.sim.creados : ls.length) + '</span><span class="s">' +
            (S.sim.modo === 'cuotas' && S.sim.creados < ls.length ? 'de ' + ls.length + ' · ' : '') + esc(S.concepto.trim()) + '</span></div>' +
          '<div><span class="k">Importe</span><span class="v">' + (mn === mx ? eur(mn) : eur(mn) + '–' + eur(mx)) + '</span><span class="s">' + (S.frecuencia === 'unica' ? 'una vez' : 'en cada cobro') + '</span></div>' +
          '<div><span class="k">Cobros</span><span class="v">' + n + '</span><span class="s">' + esc(FREC[S.frecuencia].t) + (n > 1 ? ' · ' + mesCorto(S.sim.plazos[0]) + '–' + mesCorto(S.sim.plazos[n - 1]) : ' · ' + esc(mesTxt(S.inicio))) + '</span></div>' +
          '<div><span class="k">Cómo</span><span class="v" style="font-family:var(--fuente-texto);font-size:16px">' + esc(METODO[S.metodo].t) + '</span><span class="s">' + (S.metodo === 'remesa' ? 'cuenta ' + esc(S.cuenta) : '') + '</span></div>' +
          '<div><span class="k">Total previsto</span><span class="v">' + eur(S.sim.total) + '</span><span class="s">' + S.sim.creados + (S.sim.modo === 'cuotas' ? (S.sim.creados === 1 ? ' cuota' : ' cuotas') : (S.sim.creados === 1 ? ' recibo' : ' recibos')) + '</span></div>' +
        '</div>' + queVaAPasar(S.sim) +
        (S.sim.omitidos ? '<div class="nc-aviso"><b>' + S.sim.omitidos + '</b> no se ' + (S.sim.omitidos === 1 ? 'crea' : 'crean') + ':' +
          '<ul style="margin:6px 0 0;padding-left:20px">' + omit.slice(0, 12).map(function (o) {
            return '<li>' + esc(o.persona || porId[o.atleta_id] || '—') + (o.periodo ? ' (' + esc(mesTxt(o.periodo)) + ')' : '') + ': ' + esc(o.motivo) + '</li>';
          }).join('') + (omit.length > 12 ? '<li>…y ' + (omit.length - 12) + ' más</li>' : '') + '</ul></div>' : '') +
        (S.sim.creados ? '' : '<div class="nc-error">No hay nada nuevo que crear.</div>');
      pie();
    }

    /* ---------------- Crear ---------------- */
    async function crear(btn) {
      if (S.ocupado || !S.sim || !S.sim.creados) return;
      // Cuotas por Stripe: la Edge entreno-pagar tiene que saber de tarjeta,
      // anual y mes de inicio (versión 380). Si no, no se crea nada.
      if (S.sim.modo === 'cuotas') {
        try {
          var pg = await sb.functions.invoke('entreno-pagar', { body: { ping: true } });
          if (!(pg && pg.data && pg.data.tarjeta === true)) throw new Error('vieja');
        } catch (e) {
          error('Falta desplegar la versión nueva de entreno-pagar (mig 380). No se ha creado nada.');
          return;
        }
      }
      var ok = await confirmar({
        titulo: 'Crear ' + S.sim.creados + (S.sim.modo === 'cuotas' ? (S.sim.creados === 1 ? ' cuota' : ' cuotas') : (S.sim.creados === 1 ? ' recibo' : ' recibos')),
        texto: '«' + S.concepto.trim() + '» · ' + METODO[S.metodo].t + ' · total previsto ' + eur(S.sim.total) + '. No se envía ningún correo.',
        confirmar: 'Crear'
      });
      if (!ok) return;
      S.ocupado = true; btn.disabled = true; btn.textContent = 'Creando…';
      var r = await sb.rpc('cobro_asistente_crear', { p: cuerpoRPC(false) });
      S.ocupado = false;
      if (r.error) { btn.disabled = false; btn.textContent = 'Crear'; error('No se pudo crear: ' + r.error.message); return; }
      S.creado = r.data || {};
      pintarCreado();
      if (typeof opciones.alCrear === 'function') { try { opciones.alCrear(S.creado); } catch (e) {} }
    }
    function enlacesQueSeMandan() {
      var R = S.creado || {};
      if (R.modo === 'cuotas') return { fn: 'entreno-enlace', ids: R.cuotas || [], cuerpo: function (id) { return { cuota_id: id }; } };
      if (R.modo === 'recibos' && S.metodo === 'tarjeta') return { fn: 'recibo-aviso', ids: R.pagos || [], cuerpo: function (id) { return { pago_id: id }; } };
      return null;
    }
    function pintarCreado() {
      var R = S.creado;
      $('#nc-pasos').innerHTML = NOMBRES.map(function (n, i) { return '<span class="hecho">' + (i + 1) + ' · ' + esc(n) + '</span>'; }).join('');
      var cuantos = R.creados + (R.modo === 'cuotas' ? (R.creados === 1 ? ' cuota creada' : ' cuotas creadas') : (R.creados === 1 ? ' recibo creado' : ' recibos creados'));
      var ver = R.modo === 'cuotas' ? '?v=cuotas'
        : (R.lote ? '?v=pagos&grupo=' + encodeURIComponent('lote:' + R.lote) + '&mes=todos' : '?v=unicos');
      var env = enlacesQueSeMandan();
      $('#nc-cuerpo').innerHTML = '<h3>Hecho</h3><div class="nc-ok"><b>' + esc(cuantos) + '</b> · ' + eur(R.total) + ' previstos' +
          (R.omitidos ? ' · ' + R.omitidos + ' no se crearon (ya los tenían o sin correo)' : '') + '.</div>' +
        '<p class="nc-que">Ya está en Dinero. <a data-nav href="' + ver + '" style="color:var(--azul);font-weight:600">Verlo →</a></p>' +
        (env && env.ids.length
          ? '<section style="margin-top:14px;border:1px solid var(--linea-marcada);border-radius:14px;overflow:hidden;box-shadow:var(--sombra-suave)">' +
              '<div style="background:var(--crema-banda);border-bottom:1px solid var(--crema-media);padding:10px 14px;font-size:13.5px;font-weight:600;letter-spacing:.04em;text-transform:uppercase;color:var(--texto-suave)">Correos (opcional)</div>' +
              '<div style="padding:12px 14px"><p class="nc-que" style="margin:0 0 10px">' +
                (R.modo === 'cuotas' ? 'Manda a cada persona el enlace para ' + (S.metodo === 'tarjeta' ? 'activar su cuota con tarjeta' : 'domiciliar su cuota') + '.' : 'Manda a cada persona el aviso de que tiene un recibo para pagar con tarjeta en su app.') +
              '</p><button type="button" class="pz-btn" id="nc-enviar">Enviar los enlaces por correo (' + env.ids.length + ')</button>' +
              '<div id="nc-env-res" class="nc-ayuda"></div></div></section>'
          : '');
      var b = $('#nc-enviar'); if (b) b.addEventListener('click', function () { enviar(b, env); });
      pie();
    }
    async function enviar(btn, env) {
      var res = $('#nc-env-res');
      if (env.fn === 'entreno-enlace') {
        // Solo con la versión nueva (correo para tarjeta/SEPA y cualquier
        // periodicidad); la vieja mandaría el texto de la trimestral.
        try {
          var pr = await sb.functions.invoke('entreno-enlace', { body: { ping: true } });
          if (!(pr && pr.data && pr.data.generico === true)) throw new Error('vieja');
        } catch (e) {
          res.innerHTML = '<span style="color:var(--rojo)">Falta desplegar la versión nueva de entreno-enlace (mig 380). No se ha enviado nada.</span>';
          return;
        }
      }
      var n = env.ids.length;
      var ok = await confirmar({
        titulo: 'Enviar ' + n + (n === 1 ? ' correo' : ' correos'),
        texto: 'Se enviará un correo a cada una de las ' + n + (n === 1 ? ' persona' : ' personas') + ' de este cobro («' + S.concepto.trim() + '»). Les llega de verdad y no se puede deshacer.',
        confirmar: 'Enviar ' + n
      });
      if (!ok) return;
      var t0 = btn.textContent, bien = 0, fallos = [];
      btn.disabled = true;
      for (var i = 0; i < n; i++) {
        btn.textContent = 'Enviando ' + (i + 1) + '/' + n + '…';
        try {
          var r = await sb.functions.invoke(env.fn, { body: env.cuerpo(env.ids[i]) });
          if (r && !r.error && r.data && r.data.ok) bien++;
          else fallos.push((r && r.data && r.data.motivo) || (r && r.error && r.error.message) || 'no se envió');
        } catch (e) { fallos.push((e && e.message) || String(e)); }
      }
      btn.textContent = t0;
      res.innerHTML = '<b>' + bien + '</b> enviado' + (bien === 1 ? '' : 's') + (fallos.length ? ' · ' + fallos.length + ' sin enviar: ' + esc(fallos.slice(0, 5).join(' · ')) : '') + '.';
      btn.textContent = 'Enviados';
      toast(bien + (bien === 1 ? ' correo enviado' : ' correos enviados'), fallos.length ? 'info' : 'ok');
    }

    /* ---------------- arranque ---------------- */
    $('#nc-cuerpo').innerHTML = '<p class="nc-ayuda">Cargando…</p>';
    sb.rpc('cobro_asistente_datos').then(function (r) {
      if (r.error) {
        var m = r.error.message || '';
        $('#nc-cuerpo').innerHTML = /cobro_asistente|schema cache|Could not find/i.test(m)
          ? '<div class="nc-error">El asistente necesita la migración <b>380</b> aplicada en la base.</div>'
          : '<div class="nc-error">' + esc(m) + '</div>';
        $('#nc-pie').innerHTML = '';
        return;
      }
      S.datos = r.data || {};
      if (opciones.modo && /^(persona|grupo|varias)$/.test(opciones.modo)) S.modo = opciones.modo;
      pintar();
      var f = $('#nc-cuerpo button[aria-pressed="true"]'); if (f) try { f.focus({ preventScroll: true }); } catch (e) {}
    });
  }

  window.APOLANA_NUEVO_COBRO = { abrir: abrir };
})();
