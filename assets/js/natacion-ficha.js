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
  function franjaLabel(f){ return f ? (DIAS[f.dia]+' '+hhmm(f.hora)+(f.grupo?' · '+f.grupo:'')) : '—'; }

  var cssHecho = false;
  function css(){
    if (cssHecho) return; cssHecho = true;
    var s = document.createElement('style'); s.setAttribute('data-piel','nat-ficha');
    s.textContent =
      '.nfi-bg{position:fixed;inset:0;z-index:9000;background:rgba(46,66,86,.5);display:flex;align-items:flex-start;justify-content:center;' +
        'padding:clamp(12px,5vh,52px) 12px;overflow:auto;-webkit-backdrop-filter:blur(2px);backdrop-filter:blur(2px);}' +
      '.nfi-bg[hidden]{display:none}' +
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
      '.nfi-msg.err{color:#B23B3B}';
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
    var dir = null;
    if (acc.atleta_id){ try { var rd = await sb.rpc('natacion_get_direccion', { p_atleta: acc.atleta_id }); if (rd && !rd.error) dir = rd.data || null; } catch(e){} }
    return { codigo:codigo, nombre:acc.nombre, acceso_id:acc.id, atleta_id:acc.atleta_id, ins:ins, tipo:tipo, direccion:dir };
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
      '<div style="margin:14px 0 2px"><label style="display:block;font-size:11.5px;text-transform:uppercase;letter-spacing:.5px;color:var(--texto-tenue,#9A927F);font-weight:700;margin-bottom:6px">Dirección (opcional)</label>' +
        '<input type="text" class="nfi-dir-in" value="'+esc(e.direccion||'')+'" placeholder="Calle, nº, CP y localidad"'+(e.atleta_id?'':' disabled')+' style="width:100%;font:inherit;font-size:14px;color:var(--navy,#26374B);border:1px solid var(--linea-borde,#C9C0AE);border-radius:9px;padding:9px 11px;box-sizing:border-box"></div>' +
      '<div class="nfi-rot">Sus franjas</div>' + filas + add +
      '<button type="button" class="nfi-enviar">✉ Enviar acceso a la familia</button>' +
      '<button type="button" class="nfi-baja">Dar de baja de natación (ya no nada)</button>' +
      '<p class="nfi-msg"></p>' +
    '</div>';
  }

  async function recargar(){ estado = await cargar(estado.codigo) || estado; render(); if (onCambio) { try { onCambio(); } catch(e){} } }

  async function guardar(prom, ok){
    msg('Guardando…');
    var r = await prom;
    if (r && r.error){ msg('No se pudo guardar: '+r.error.message, true); return false; }
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
      msg((e && e.message) || 'No se pudo enviar. Comprueba que tenga correo guardado.', true);
    }
  }

  async function darDeBaja(){
    if (!confirm('¿Dar de baja a ' + (estado.nombre || 'esta persona') + ' de natación?\n\n' +
      'Se quitará de TODAS sus franjas y dejará de aparecer en las listas. Se puede volver a dar de alta más adelante.')) return;
    msg('Dando de baja…');
    var r = await sb.from('natacion_inscripciones').update({ activa:false }).eq('acceso_id', estado.acceso_id).eq('activa', true);
    if (r && r.error){ msg('No se pudo dar de baja: '+r.error.message, true); return; }
    // por si quedara alguna fila atada solo por ficha (sin código)
    if (estado.atleta_id){ try { await sb.from('natacion_inscripciones').update({ activa:false }).eq('atleta_id', estado.atleta_id).eq('activa', true); } catch(e){} }
    if (onCambio){ try { await onCambio(); } catch(e){} }
    cerrar();
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
      if (t.classList.contains('nfi-dir-in')){
        if (!estado.atleta_id){ msg('Esta ficha aún no está enlazada a una cuenta', true); return; }
        estado.direccion = t.value;
        msg('Guardando…');
        sb.rpc('natacion_set_direccion', { p_atleta: estado.atleta_id, p_direccion: t.value })
          .then(function(r){ msg(r && r.error ? 'No se pudo guardar la dirección' : 'Dirección guardada', !!(r && r.error)); });
        return;
      }
    });
    document.addEventListener('keydown', function(ev){ if (ev.key==='Escape' && bg) cerrar(); });
    document.body.appendChild(bg);
  }

  window.APOLANA_NAT_FICHA = {
    init: function(client){ sb = client; },
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
    }
  };
})();
