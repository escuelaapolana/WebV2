/* ============================================================
   FICHA DE NADADOR (natación) · panel editable compartido
   ------------------------------------------------------------
   Lo usan las listas «Niños y niñas» (portal/escuela-natacion) y
   «Nadadores» (portal/natacion): al tocar a una persona se abre su
   ficha para ver y CAMBIAR desde ahí mismo sus franjas (día), su
   nivel y su calle, moverla de día, quitarla o añadirla a otra
   franja; y enviar el correo de acceso a la familia.

   Solo escribe quien puede (RLS: soy_gestor_natacion()).

   Uso:
     APOLANA_NAT_FICHA.init(sb);                       // una vez
     APOLANA_NAT_FICHA.abrir({ codigo:'ABC123', nombre:'...', onCambio:fn });
   ============================================================ */
(function () {
  'use strict';
  var sb = null, FR = {}, FR_LIST = [], estado = null, bg = null, onCambio = null;
  var DIAS = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  var NIVELES = ['Iniciación', 'Desarrollo', 'Perfeccionamiento'];

  function esc(s){ return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];}); }
  function hhmm(h){ return String(h==null?'':h).slice(0,5); }
  function callesDe(f){ var c=[]; for (var k=1;k<=((f&&f.calles)||1);k++) c.push('C'+k); if (f&&f.tiene_vaso) c.push('Vaso'); return c; }
  function opciones(lista, val){ return lista.map(function(o){ return '<option value="'+esc(o)+'"'+(o===val?' selected':'')+'>'+esc(o)+'</option>'; }).join(''); }
  // Errores en cristiano (nunca «permission denied», «RLS», «Supabase»…).
  function humano(e, accion){
    var m = String((e && (e.message || e.msg || e.mensaje)) || e || '');
    if (/JWT expired|jwt|sin_sesion/i.test(m)) return 'Tu sesión ha caducado. Sal y vuelve a entrar.';
    if (/^(Solo |No encuentro|Falta|Nivel no|Ese correo|El correo|Este nadador|No hay ning)/.test(m)) return m;
    if ((e && e.code === '42501') || /permission denied|row-level security|sin_permiso|no_permiso|not allowed/i.test(m))
      return 'No tienes permiso para ' + (accion || 'hacer esto') + '. Si crees que deberías poder, díselo a Andrés.';
    if (/Failed to fetch|NetworkError|Load failed|network|timeout/i.test(m)) return 'Sin conexión. Revisa internet y vuelve a intentarlo.';
    if (/non-2xx|Edge Function|FunctionsHttpError|FunctionsFetchError/i.test(m)) return 'El correo no ha salido. Vuelve a intentarlo en un rato.';
    if (/duplicate key|already exists/i.test(m)) return 'Eso ya estaba guardado.';
    if (/check constraint/i.test(m)) return 'Algún dato no es válido (revisa nivel o calle).';
    if (/supabase|postgres|PGRST|relation |column |does not exist|syntax|no lo lleva el entrenador/i.test(m))
      return 'Algo ha fallado al guardar. Recarga la página y vuelve a intentarlo; si sigue, avisa a Andrés.';
    return m || 'No se pudo hacer. Vuelve a intentarlo.';
  }
  function franjaLabel(f){ return f ? (DIAS[f.dia]+' '+hhmm(f.hora)+(f.grupo?' · '+f.grupo:'')) : '—'; }

  var cssHecho = false;
  function css(){
    if (cssHecho) return; cssHecho = true;
    var s = document.createElement('style'); s.setAttribute('data-piel','nat-ficha');
    s.textContent =
      '.nfi-bg{position:fixed;inset:0;z-index:9000;background:rgba(46,66,86,.5);display:flex;align-items:flex-start;justify-content:center;' +
        'padding:clamp(12px,5vh,52px) 12px;overflow:auto;-webkit-backdrop-filter:blur(2px);backdrop-filter:blur(2px);}' +
      '.nfi-bg[hidden]{display:none}' +
      '.nfi-asis-saldo{margin:2px 0 8px;font-size:14px}.nfi-mes{border:1px solid #e3e6ea;border-radius:10px;margin:0 0 6px;background:#fff}' +
      '.nfi-mes summary{cursor:pointer;padding:9px 12px;display:flex;justify-content:space-between;gap:8px;font-size:14px;list-style:none}.nfi-mes summary::-webkit-details-marker{display:none}' +
      '.nfi-mes summary span{color:#5f6874;font-size:13px}.nfi-mes ul{list-style:none;margin:0;padding:0 12px 8px}' +
      '.nfi-d{font-size:13.5px;padding:4px 0;border-top:1px dashed #edf0f2}.nfi-d span{display:inline-block;min-width:54px;font-weight:600}.nfi-d small{color:#8a929c;margin-left:4px}' +
      '.nfi-d.vino{color:#2f6b45}.nfi-d.aviso{color:#9a6a12}.nfi-d.falta{color:#a33a3a}.nfi-d.reserva,.nfi-d.sinlista{color:#5f6874}' +
      '.nfi-caja{background:#fff;border-radius:16px;box-shadow:0 30px 70px -25px rgba(46,66,86,.6);width:min(560px,100%);padding:18px 18px 20px;' +
        "font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;}" +
      '.nfi-cab{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;margin-bottom:6px}' +
      ".nfi-cab h2{font-family:'Bricolage Grotesque',system-ui,sans-serif;text-transform:uppercase;font-size:21px;line-height:1.05;color:var(--navy,#26374B);margin:0}" +
      '.nfi-cod{font-size:12px;color:var(--texto-suave,#6E6656);font-family:ui-monospace,monospace}' +
      '.nfi-x{flex:0 0 auto;width:38px;height:38px;border-radius:50%;border:1px solid var(--linea-borde,#C9C0AE);background:#fff;color:var(--texto-suave,#6E6656);font-size:15px;cursor:pointer}' +
      '.nfi-rot{font-size:11.5px;text-transform:uppercase;letter-spacing:.5px;color:var(--texto-tenue,#9A927F);font-weight:700;margin:16px 0 8px}' +
      '.nfi-fila{border:1px solid var(--linea-marcada,#E4DCCB);border-radius:12px;padding:10px 12px;margin-bottom:9px}' +
      '.nfi-dh{font-size:14.5px;font-weight:600;color:var(--navy,#26374B);margin-bottom:8px}' +
      '.nfi-ctrl{display:flex;flex-wrap:wrap;gap:9px;align-items:flex-end}' +
      '.nfi-ctrl label{display:flex;flex-direction:column;gap:3px;font-size:11px;color:var(--texto-suave,#6E6656);font-weight:600}' +
      '.nfi-ctrl select{font:inherit;font-size:14px;color:var(--navy,#26374B);border:1px solid var(--linea-borde,#C9C0AE);border-radius:9px;padding:7px 9px;background:#fff}' +
      '.nfi-quitar{font:inherit;font-size:12.5px;color:#B3261E;background:#FBE3E1;border:1px solid #F1C7C3;border-radius:9px;padding:8px 11px;cursor:pointer;margin-left:auto}' +
      '.nfi-vacio{font-size:13.5px;color:var(--texto-suave,#6E6656);padding:4px 0 2px}' +
      '.nfi-add{border-top:1px solid var(--linea,#EFEAE0);margin-top:6px;padding-top:12px;display:flex;flex-wrap:wrap;gap:8px;align-items:center}' +
      '.nfi-add h4{width:100%;font-size:11.5px;text-transform:uppercase;letter-spacing:.5px;color:var(--texto-tenue,#9A927F);font-weight:700;margin:0 0 2px}' +
      '.nfi-add select{font:inherit;font-size:14px;color:var(--navy,#26374B);border:1px solid var(--linea-borde,#C9C0AE);border-radius:9px;padding:7px 9px;background:#fff}' +
      '.nfi-add select:first-of-type{flex:1 1 150px}' +
      '.nfi-btn{font:inherit;font-weight:600;font-size:14px;background:var(--navy,#26374B);color:#fff;border:none;border-radius:10px;padding:9px 15px;cursor:pointer}' +
      '.nfi-enviar{display:block;width:100%;margin-top:16px;font:inherit;font-weight:600;font-size:14px;background:#2E7D6B;color:#fff;border:none;border-radius:10px;padding:11px;cursor:pointer}' +
      '.nfi-enviar:disabled{opacity:.6;cursor:default}' +
      '.nfi-enviar.ok{background:#E6F4EA;color:#1E7A3D;border:1px solid #BfE3C8}' +
      '.nfi-baja{display:block;width:100%;margin-top:10px;background:none;border:0;color:#B23B3B;font:inherit;font-size:13px;cursor:pointer;text-decoration:underline}' +
      '.nfi-msg{font-size:13px;color:var(--texto-suave,#6E6656);margin:10px 2px 0;min-height:1em}' +
      '.nfi-msg.err{color:#B23B3B}' +
      '.nfi-cto{display:grid;grid-template-columns:1fr 1fr;gap:9px}' +
      '.nfi-cto label{display:flex;flex-direction:column;gap:3px;font-size:11px;color:var(--texto-suave,#6E6656);font-weight:600;min-width:0}' +
      '.nfi-cto label.ancho{grid-column:1/-1}' +
      '.nfi-cto input{font:inherit;font-size:14px;color:var(--navy,#26374B);border:1px solid var(--linea-borde,#C9C0AE);border-radius:9px;padding:8px 10px;box-sizing:border-box;width:100%}' +
      '.nfi-nota{font-size:12.5px;color:var(--texto-suave,#6E6656);margin:6px 0 0}';
    document.head.appendChild(s);
  }

  async function franjas(){
    if (FR_LIST.length) return;
    var r = await sb.from('natacion_franjas').select('id,dia,hora,grupo,calles,tiene_vaso').order('dia').order('hora');
    FR_LIST = (r && !r.error && r.data) ? r.data : [];
    FR = {}; FR_LIST.forEach(function(f){ FR[f.id] = f; });
  }

  async function cargar(codigo){
    var ra = await sb.from('natacion_accesos').select('id,atleta_id,nombre').eq('codigo', codigo).maybeSingle();
    var acc = (ra && !ra.error) ? ra.data : null;
    if (!acc) return null;
    var ri = await sb.from('natacion_inscripciones').select('id,franja_id,nivel,calle,tipo').eq('acceso_id', acc.id).eq('activa', true);
    var ins = (ri && !ri.error && ri.data) ? ri.data : [];
    ins.sort(function(a,b){ var fa=FR[a.franja_id]||{}, fb=FR[b.franja_id]||{}; return ((fa.dia||0)-(fb.dia||0)) || (hhmm(fa.hora)<hhmm(fb.hora)?-1:1); });
    var tipo = ins.some(function(x){ return x.tipo==='Máster'; }) ? 'Máster' : 'Escuela';
    var cto = null;
    if (acc.atleta_id){
      try { var rc = await sb.rpc('natacion_contacto_de', { p_atleta: acc.atleta_id }); if (rc && !rc.error && rc.data && rc.data[0]) cto = rc.data[0]; } catch(e){}
    }
    return { codigo:codigo, nombre:acc.nombre, acceso_id:acc.id, atleta_id:acc.atleta_id, ins:ins, tipo:tipo,
             direccion: cto ? cto.direccion : null, cto: cto };
  }

  function msg(t, err){ var m = bg && bg.querySelector('.nfi-msg'); if (m){ m.textContent = t||''; m.className = 'nfi-msg'+(err?' err':''); } }

  function render(){
    var e = estado;
    var filas = e.ins.map(function(m){
      var f = FR[m.franja_id], calles = f ? callesDe(f) : ['C1','C2','C3','C4'];
      var mover = FR_LIST.filter(function(x){ return x.id!==m.franja_id; })
        .map(function(x){ return '<option value="'+esc(x.id)+'">'+esc(franjaLabel(x))+'</option>'; }).join('');
      return '<div class="nfi-fila">' +
        '<div class="nfi-dh">'+esc(franjaLabel(f))+'</div>' +
        '<div class="nfi-ctrl">' +
          '<label>Nivel<select class="nfi-nivel" data-id="'+esc(m.id)+'">'+opciones(NIVELES, m.nivel)+'</select></label>' +
          '<label>Calle<select class="nfi-calle" data-id="'+esc(m.id)+'">'+opciones(calles, m.calle)+'</select></label>' +
          '<label>Mover<select class="nfi-mover" data-id="'+esc(m.id)+'"><option value="">a otro día…</option>'+mover+'</select></label>' +
          '<button type="button" class="nfi-quitar" data-id="'+esc(m.id)+'">Quitar</button>' +
        '</div></div>';
    }).join('') || '<p class="nfi-vacio">Todavía no está en ninguna franja.</p>';

    var addFr = FR_LIST.map(function(x){ return '<option value="'+esc(x.id)+'">'+esc(franjaLabel(x))+'</option>'; }).join('');
    var add = '<div class="nfi-add"><h4>Añadir a una franja</h4>' +
      '<select class="nfi-add-franja">'+addFr+'</select>' +
      '<select class="nfi-add-nivel">'+opciones(NIVELES, e.tipo==='Máster'?NIVELES[2]:NIVELES[0])+'</select>' +
      '<select class="nfi-add-calle">'+opciones(['C1','C2','C3','C4'], e.tipo==='Máster'?'C2':'C1')+'</select>' +
      '<button type="button" class="nfi-btn nfi-add-btn">Añadir</button></div>';

    bg.innerHTML = '<div class="nfi-caja">' +
      '<div class="nfi-cab"><div><h2>'+esc(e.nombre||'Nadador')+'</h2>' +
        (e.codigo?'<span class="nfi-cod">'+esc(e.codigo)+' · '+esc(e.tipo)+'</span>':'') + '</div>' +
        '<button type="button" class="nfi-x" aria-label="Cerrar">✕</button></div>' +
      contactoHtml(e) +
      '<div class="nfi-rot">Sus franjas</div>' + filas + add +
      '<div class="nfi-rot">Asistencia por meses</div><div class="nfi-asis">' + (e.asisHtml || '<p class="nfi-vacio">Cargando…</p>') + '</div>' +
      '<button type="button" class="nfi-enviar">✉ Enviar acceso a la familia</button>' +
      '<button type="button" class="nfi-baja">Dar de baja de natación (ya no nada)</button>' +
      '<p class="nfi-msg"></p>' +
    '</div>';
  }

  /* ===== Asistencia por meses (26-nov-2026, petición de Mario) =====
     Los días que ha venido cada mes, sin puntear: su día fijo, las
     recuperaciones (días reservados con bono), los avisos de que no va y las
     faltas que puso el monitor; cuántas sesiones fijas le tocaban ese mes y lo
     que le queda por recuperar (saldo del bono, Máster).
     Se deduce igual que en Pasar lista: un día cuenta como «vino» si esa
     franja tiene la lista pasada y él no está en natacion_ausencias. Las
     plazas quitadas también cuentan para los meses de atrás. */
  var MES_N = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
  var DIA_C = ['dom','lun','mar','mié','jue','vie','sáb'];
  function pad2(n){ return (n<10?'0':'')+n; }
  function isoD(d){ return d.getFullYear()+'-'+pad2(d.getMonth()+1)+'-'+pad2(d.getDate()); }
  function dParse(s){ var p = String(s).split('-'); return new Date(+p[0], +p[1]-1, +p[2]); }
  async function cargarAsistencia(e){
    var hoy = new Date(), hoyS = isoD(hoy), d0 = new Date(hoy.getFullYear(), hoy.getMonth()-3, 1), desde = isoD(d0);
    var rr = await Promise.all([
      sb.from('natacion_inscripciones').select('franja_id,activa,desde,created_at').eq('acceso_id', e.acceso_id),
      sb.from('natacion_reservas').select('fecha,franja_id,estado').eq('acceso_id', e.acceso_id).gte('fecha', desde),
      sb.from('natacion_ausencias').select('fecha,franja_id,origen').eq('acceso_id', e.acceso_id).gte('fecha', desde),
      sb.from('natacion_abonos').select('saldo').eq('acceso_id', e.acceso_id).maybeSingle()
    ]);
    if (rr[0].error && rr[1].error && rr[2].error) return '<p class="nfi-vacio">No se ha podido leer la asistencia.</p>';
    var ins = rr[0].data || [], res = (rr[1].data || []).filter(function(r){ return r.estado !== 'cancelada'; }), aus = rr[2].data || [];
    var saldo = rr[3] && !rr[3].error && rr[3].data ? rr[3].data.saldo : null;
    // Plaza quitada (activa=false): no se guarda cuándo se quitó, así que solo
    // cuenta como su día fijo hasta el último aviso o falta en esa franja (la
    // prueba de que seguía yendo ese día). Sin avisos, no cuenta.
    var finAus = {}; aus.forEach(function(a){ if (a.franja_id && (!finAus[a.franja_id] || a.fecha > finAus[a.franja_id])) finAus[a.franja_id] = a.fecha; });
    var ini = {}, fin = {};
    ins.forEach(function(x){
      if (!x.activa && !finAus[x.franja_id]) return;
      var i0 = x.desde || String(x.created_at||'').slice(0,10);
      if (!ini[x.franja_id] || i0 < ini[x.franja_id]) ini[x.franja_id] = i0;
      if (x.activa) fin[x.franja_id] = '9999'; else if (fin[x.franja_id] !== '9999' && (!fin[x.franja_id] || finAus[x.franja_id] > fin[x.franja_id])) fin[x.franja_id] = finAus[x.franja_id];
    });
    var frs = {}; ins.forEach(function(x){ frs[x.franja_id] = 1; }); res.forEach(function(r){ frs[r.franja_id] = 1; });
    var ids = Object.keys(frs), listas = [];
    if (ids.length){ var rl = await sb.from('natacion_lista').select('franja_id,fecha').in('franja_id', ids).gte('fecha', desde).lte('fecha', hoyS); listas = (rl && !rl.error && rl.data) || []; }
    var ausK = {}; aus.forEach(function(a){ ausK[a.fecha+'|'+(a.franja_id||'')] = a; });
    var resK = {}; res.forEach(function(r){ resK[r.fecha+'|'+r.franja_id] = r; });
    var ev = [], usados = {};
    listas.forEach(function(l){
      var k = l.fecha+'|'+l.franja_id, fijo = !!(ini[l.franja_id] && ini[l.franja_id] <= l.fecha && l.fecha <= fin[l.franja_id] && !resK[k]), rv = resK[k];
      if (!fijo && !rv) return;
      var a = ausK[k] || ausK[l.fecha+'|'];
      if (a){ usados[a.fecha+'|'+(a.franja_id||'')] = 1; ev.push({ f:l.fecha, t: a.origen==='monitor' ? 'falta' : 'aviso', rec:!!rv, fr:l.franja_id }); }
      else ev.push({ f:l.fecha, t:'vino', rec:!!rv, fr:l.franja_id });
      if (rv) usados['r|'+k] = 1;
    });
    aus.forEach(function(a){ var k = a.fecha+'|'+(a.franja_id||''); if (!usados[k]) ev.push({ f:a.fecha, t: a.origen==='monitor' ? 'falta' : 'aviso', fr:a.franja_id }); });
    res.forEach(function(r){ var k = r.fecha+'|'+r.franja_id; if (!usados['r|'+k]) ev.push({ f:r.fecha, t: r.fecha >= hoyS ? 'reserva' : 'sinlista', rec:true, fr:r.franja_id }); });
    // Sesiones fijas que le tocaban cada mes (solo plazas activas, desde que empezó)
    var activas = ins.filter(function(x){ return x.activa; });
    function tocaban(y, m){
      var n = 0, fin = new Date(y, m+1, 0).getDate();
      for (var dd = 1; dd <= fin; dd++){ var dt = new Date(y, m, dd), ds = isoD(dt), wd = dt.getDay() || 7;
        activas.forEach(function(x){ var f = FR[x.franja_id]; if (f && f.dia === wd && (!ini[x.franja_id] || ini[x.franja_id] <= ds)) n++; }); }
      return n;
    }
    var meses = [];
    for (var i = 0; i < 4; i++){ var dm = new Date(hoy.getFullYear(), hoy.getMonth()-i, 1); meses.push({ y:dm.getFullYear(), m:dm.getMonth() }); }
    var ETQ = { vino:'vino', aviso:'avisó que no iba', falta:'faltó', reserva:'reservado', sinlista:'reservado · sin lista pasada' };
    var h = '';
    if (saldo != null) h += '<p class="nfi-asis-saldo">'+(saldo===1?'Le queda':'Le quedan')+' <b>'+saldo+'</b> '+(saldo===1?'sesión':'sesiones')+' por recuperar (bono).</p>';
    if (!activas.length) h += '<p class="nfi-nota">Ahora no tiene plaza fija activa: abajo salen igual los días que vino.</p>';
    meses.forEach(function(M, i){
      var pre = M.y+'-'+pad2(M.m+1), L = ev.filter(function(x){ return x.f.slice(0,7) === pre; }).sort(function(a,b){ return a.f < b.f ? -1 : 1; });
      var vino = L.filter(function(x){ return x.t==='vino'; }).length, toc = activas.length ? tocaban(M.y, M.m) : null;
      if (!L.length && i > 0) return;
      h += '<details class="nfi-mes"'+(i===0?' open':'')+'><summary><b>'+MES_N[M.m]+(M.y!==hoy.getFullYear()?' '+M.y:'')+'</b><span>vino '+vino+(toc!=null?' · le tocaban '+toc:'')+'</span></summary>'+
        (L.length ? '<ul>'+L.map(function(x){ var dt = dParse(x.f), f = FR[x.fr];
          return '<li class="nfi-d '+x.t+'"><span>'+DIA_C[dt.getDay()]+' '+dt.getDate()+'</span>'+esc(ETQ[x.t])+(x.rec && x.t!=='reserva' && x.t!=='sinlista' ? ' · recupera' : '')+(f?' <small>'+esc(DIAS[f.dia].slice(0,3).toLowerCase()+' '+hhmm(f.hora))+'</small>':'')+'</li>'; }).join('')+'</ul>'
          : '<p class="nfi-vacio">Sin listas pasadas este mes.</p>')+'</details>';
    });
    return h || '<p class="nfi-vacio">Sin datos de asistencia.</p>';
  }
  async function pintarAsistencia(){
    var e = estado; if (!e || !e.acceso_id) return;
    var html; try { html = await cargarAsistencia(e); } catch(x){ html = '<p class="nfi-vacio">No se ha podido leer la asistencia.</p>'; }
    if (estado !== e) return;
    e.asisHtml = html;
    var c = bg && bg.querySelector('.nfi-asis'); if (c) c.innerHTML = html;
  }

  // Datos de contacto (se guardan al salir de cada casilla). Escuela: los del
  // tutor; máster: los del propio nadador. Sin ficha unida no hay dónde guardar.
  function contactoHtml(e){
    var c = e.cto || {};
    var dis = e.atleta_id ? '' : ' disabled';
    function campo(k, lab, val, tipo, ancho){
      return '<label'+(ancho?' class="ancho"':'')+'>'+esc(lab)+'<input type="'+(tipo||'text')+'" class="nfi-cto-in" data-k="'+k+'" value="'+esc(val||'')+'"'+dis+'></label>';
    }
    var campos = e.tipo === 'Máster'
      ? campo('p_email', 'Correo', c.email, 'email') + campo('p_telefono', 'Teléfono', c.telefono, 'tel')
      : campo('p_nombre_tutor', 'Tutor/a', c.nombre_tutor) + campo('p_telefono_tutor', 'Teléfono del tutor', c.telefono_tutor, 'tel') +
        campo('p_email_tutor', 'Correo del tutor', c.email_tutor, 'email', true);
    campos += campo('p_direccion', 'Dirección (opcional)', c.direccion, 'text', true);
    return '<div class="nfi-rot">Contacto</div><div class="nfi-cto">' + campos + '</div>' +
      (e.atleta_id ? (c.familia_con_cuenta ? '<p class="nfi-nota">La familia ya tiene cuenta en la app.</p>' : '<p class="nfi-nota">La familia aún no tiene cuenta: «Enviar acceso» le manda el enlace para crearla.</p>')
                   : '<p class="nfi-nota">Esta persona no está unida a su ficha: únela desde Natación › Franjas y cupos («🔗 Unir a su ficha»).</p>');
  }

  async function recargar(){ var prevAs = estado && estado.asisHtml; estado = await cargar(estado.codigo) || estado; if (prevAs && !estado.asisHtml) estado.asisHtml = prevAs; render(); pintarAsistencia(); if (onCambio) { try { onCambio(); } catch(e){} } }

  async function guardar(prom, ok){
    msg('Guardando…');
    var r = await prom;
    if (r && r.error){ msg(humano(r.error, 'cambiar esto'), true); return false; }
    await recargar(); msg(ok||'');
    return true;
  }

  async function enviarAcceso(btn){
    btn.disabled = true; var t = btn.textContent; btn.textContent = 'Enviando…'; msg('');
    try {
      var pr = await sb.rpc('natacion_familia_preparar', { p_codigo: estado.codigo });
      if (pr.error) throw pr.error;
      var info = pr.data || {}, r, ok;
      if (info.ya_tiene_cuenta){
        r = await sb.functions.invoke('correo-natacion-horarios', { body:{ codigo: estado.codigo } });
        ok = r && r.data && r.data.ok;
        if (!ok) throw new Error((r && r.data && r.data.mensaje) || 'No se pudo enviar.');
        btn.textContent = '✓ Horarios enviados';
      } else {
        r = await sb.functions.invoke('familia-invitar', { body:{ modo:'real', publico:(info.tipo==='Máster'?'master':'familia'), solo_a: info.email, forzar:true, confirmar:true } });
        ok = r && r.data && r.data.ok;
        if (!ok) throw new Error((r && r.data && (r.data.msg||r.data.mensaje)) || 'No se pudo enviar la invitación.');
        btn.textContent = '✓ Invitación enviada';
      }
      btn.classList.add('ok');
    } catch(e){
      btn.disabled = false; btn.textContent = t;
      msg(humano(e, 'enviar correos') || 'No se pudo enviar. Comprueba que tenga correo guardado.', true);
    }
  }

  async function darDeBaja(){
    if (!confirm('¿Dar de baja a ' + (estado.nombre || 'esta persona') + ' de natación?\n\n' +
      'Se quitará de TODAS sus franjas, su código de acceso dejará de valer y se anulan sus reservas futuras. ' +
      'Si no está en nada más del club, su ficha queda «de baja». Se puede volver a dar de alta más adelante.')) return;
    msg('Dando de baja…');
    // Baja COMPLETA en la base (franjas + código + reservas + lista de espera
    // + ficha si no está en otra cosa). Antes solo se apagaban las franjas y
    // el código seguía vivo (caso Mounir).
    var r = await sb.rpc('natacion_dar_baja', { p_acceso: estado.acceso_id, p_atleta: estado.atleta_id || null });
    if (r && r.error){ msg(humano(r.error, 'dar bajas'), true); return; }
    var d = (r && r.data) || {};
    var txt = (estado.nombre || 'Baja') + ' dado/a de baja de natación.' +
      (d.sigue_en ? ' Su ficha sigue activa porque también está en: ' + d.sigue_en + '.' : '');
    if (onCambio){ try { await onCambio(); } catch(e){} }
    cerrar();
    try { alert(txt); } catch(e){}
  }

  function cerrar(){ if (bg){ bg.remove(); bg = null; } estado = null; }

  function montar(){
    bg = document.createElement('div'); bg.className = 'nfi-bg';
    bg.addEventListener('click', function(ev){
      if (ev.target === bg){ cerrar(); return; }
      var t = ev.target;
      if (t.closest('.nfi-x')){ cerrar(); return; }
      if (t.closest('.nfi-enviar')){ enviarAcceso(t.closest('.nfi-enviar')); return; }
      if (t.closest('.nfi-baja')){ darDeBaja(); return; }
      if (t.closest('.nfi-quitar')){
        var qid = t.closest('.nfi-quitar').getAttribute('data-id');
        if (confirm('¿Quitar a esta persona de esta franja?'))
          guardar(sb.from('natacion_inscripciones').update({ activa:false }).eq('id', qid), 'Quitada de la franja');
        return;
      }
      if (t.closest('.nfi-add-btn')){
        var caja = bg.querySelector('.nfi-caja');
        var fr = caja.querySelector('.nfi-add-franja').value;
        var niv = caja.querySelector('.nfi-add-nivel').value;
        var cal = caja.querySelector('.nfi-add-calle').value;
        if (!fr){ msg('Elige una franja', true); return; }
        if (estado.ins.some(function(x){ return x.franja_id===fr; })){ msg('Ya está en esa franja', true); return; }
        guardar(sb.from('natacion_inscripciones').insert({
          franja_id: fr, nombre: estado.nombre, tipo: estado.tipo, nivel: niv, calle: cal,
          acceso_id: estado.acceso_id, atleta_id: estado.atleta_id, activa: true
        }), 'Añadida a la franja');
        return;
      }
    });
    bg.addEventListener('change', function(ev){
      var t = ev.target;
      if (t.classList.contains('nfi-nivel')){ guardar(sb.from('natacion_inscripciones').update({ nivel: t.value }).eq('id', t.getAttribute('data-id')), 'Nivel guardado'); return; }
      if (t.classList.contains('nfi-calle')){ guardar(sb.from('natacion_inscripciones').update({ calle: t.value }).eq('id', t.getAttribute('data-id')), 'Calle guardada'); return; }
      if (t.classList.contains('nfi-mover') && t.value){ guardar(sb.from('natacion_inscripciones').update({ franja_id: t.value }).eq('id', t.getAttribute('data-id')), 'Movida de día'); return; }
      if (t.classList.contains('nfi-cto-in')){
        if (!estado.atleta_id){ msg('Esta persona no está unida a su ficha: únela desde Franjas y cupos', true); return; }
        var k = t.getAttribute('data-k'), args = { p_atleta: estado.atleta_id };
        args[k] = t.value.trim();          // '' = borrar ese dato
        msg('Guardando…');
        sb.rpc('natacion_guardar_contacto', args).then(function(r){
          if (r && r.error){ msg(humano(r.error, 'cambiar los datos de contacto'), true); return; }
          if (estado.cto) estado.cto[k.replace(/^p_/, '')] = t.value.trim();
          msg('Guardado ✓');
        });
        return;
      }
    });
    document.addEventListener('keydown', function(ev){ if (ev.key==='Escape' && bg) cerrar(); });
    document.body.appendChild(bg);
  }

  window.APOLANA_NAT_FICHA = {
    init: function(client){ sb = client; },
    /* Para portal/natacion-historial: la asistencia por meses de un acceso, sin abrir la ficha. */
    asistenciaHTML: async function(accesoId){ if (!sb) return ''; css(); await franjas(); return cargarAsistencia({ acceso_id: accesoId }); },
    abrir: async function(opts){
      opts = opts || {};
      if (!sb){ return; }
      css(); await franjas();
      onCambio = (typeof opts.onCambio === 'function') ? opts.onCambio : null;
      estado = await cargar(opts.codigo);
      if (!estado){ alert('No se encontró la ficha de esta persona.'); return; }
      if (opts.nombre && !estado.nombre) estado.nombre = opts.nombre;
      if (!bg) montar();
      render();
      pintarAsistencia();
    }
  };
})();
