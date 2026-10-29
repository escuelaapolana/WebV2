/* =========================================================================
   Academia · Análisis del atleta — motor de la primera versión (29-oct)
   Reglas: docs/definiciones-analisis-atleta.md
   Solo lee y ordena lo registrado: no puntúa, no diagnostica, no propone
   decisiones y no rellena huecos. Cada resultado lleva sus casos y su límite.
   Se carga en el navegador (window.APOLANA_ANALISIS) y en node (pruebas).
   ========================================================================= */
(function(root){
  'use strict';

  var METODO = { electronico_competicion:'electrónico de competición', fotocelulas:'fotocélulas', manual:'manual', video:'vídeo', otro:'otro', no_consta:'método no consta' };
  var VIENTO_MAX = 2.0;
  function n2(x){ return Math.round(x * 100) / 100; }
  function coma(x, dec){ return x == null ? '—' : (dec != null ? Number(x).toFixed(dec) : String(n2(x))).replace('.', ','); }
  function canon(o){
    if (!o || typeof o !== 'object') return '';
    return Object.keys(o).filter(function(k){ return o[k] != null && o[k] !== ''; }).sort().map(function(k){ return k + '=' + o[k]; }).join(';');
  }
  function num(v){ if (v == null || v === '') return null; var x = typeof v === 'number' ? v : parseFloat(String(v).replace(',', '.')); return isFinite(x) ? x : null; }

  /* ---------- 1 · Marcas comparables ----------
     Misma prueba (la llamada ya filtra), mismo tipo de cronometraje, oficial o no,
     mismas condiciones y viento legal donde cuenta. Lo demás va aparte, con motivo. */
  function puntos(g){ return (g.oficial === true ? 2 : 0) + (g.metodo === 'electronico_competicion' ? 2 : g.metodo === 'fotocelulas' ? 1 : 0); }
  function marcasComparables(marcas, opts){
    opts = opts || {};
    var vc = !!opts.vientoCuenta, menos = opts.menosEsMejor !== false;
    var grupos = {}, aparte = [];
    (marcas || []).forEach(function(m){
      var v = num(m.tiempo_segundos);
      if (v == null) { aparte.push({ m:m, motivo:'sin valor' }); return; }
      if (vc && m.viento != null && +m.viento > VIENTO_MAX) { aparte.push({ m:m, motivo:'viento +' + coma(+m.viento, 1) + ' m/s (más de +2,0): no es comparable' }); return; }
      var met = m.metodo || 'no_consta';
      var of = m.oficial === true ? 'oficial' : m.oficial === false ? 'no_oficial' : 'oficial_no_consta';
      var k = met + '|' + of + '|' + canon(m.condiciones);
      var pc = [];
      if (vc && m.viento == null) pc.push('viento no consta');
      if (met === 'no_consta') pc.push('método no consta');
      (grupos[k] = grupos[k] || { clave:k, metodo:met, oficial:m.oficial, condiciones:m.condiciones || {}, marcas:[] }).marcas.push({ m:m, v:v, por_confirmar:pc });
    });
    var L = Object.keys(grupos).map(function(k){ return grupos[k]; });
    var ult = function(g){ return g.marcas.map(function(x){ return x.m.fecha || ''; }).sort().pop() || ''; };
    L.sort(function(a, b){ return puntos(b) - puntos(a) || b.marcas.length - a.marcas.length || ult(b).localeCompare(ult(a)); });
    var P = L[0] || null;
    L.slice(1).forEach(function(g){
      var por = g.metodo !== P.metodo ? 'cronometraje distinto (' + (METODO[g.metodo] || g.metodo) + '): no se mezcla'
              : g.oficial !== P.oficial ? (g.oficial === false ? 'no oficial' : 'oficial no consta') + ': va aparte'
              : 'condiciones distintas: va aparte';
      g.marcas.forEach(function(x){ aparte.push({ m:x.m, motivo:por }); });
    });
    if (P) {
      P.marcas.sort(function(a, b){ return String(a.m.fecha || '').localeCompare(String(b.m.fecha || '')); });
      P.mejor = P.marcas.reduce(function(b, x){ return !b || (menos ? x.v < b.v : x.v > b.v) ? x : b; }, null);
      P.n = P.marcas.length;
      P.evolucion = P.n >= 3 ? 'descriptiva' : 'insuficiente';
      P.etiqueta = (METODO[P.metodo] || P.metodo) + ' · ' + (P.oficial === true ? 'oficial' : P.oficial === false ? 'no oficial' : 'oficial no consta') + (canon(P.condiciones) ? ' · ' + canon(P.condiciones) : '');
    }
    aparte.sort(function(a, b){ return String(a.m.fecha || '').localeCompare(String(b.m.fecha || '')); });
    return { principal:P, aparte:aparte };
  }

  /* ---------- 2 · Parciales frente al modelo ----------
     Tramos principales = los que no están dentro de otro (las subdivisiones no se
     suman dos veces). Los «pasos» desde 0 se convierten en tramos. */
  function principales(L){
    return L.filter(function(x){
      return !L.some(function(y){ return y !== x && y.desde_m <= x.desde_m && y.hasta_m >= x.hasta_m && !(y.desde_m === x.desde_m && y.hasta_m === x.hasta_m); });
    }).sort(function(a, b){ return a.desde_m - b.desde_m; });
  }
  function tramosDe(rows){
    var tr = [];
    (rows || []).forEach(function(r){ if ((r.medida || 'tramo') === 'tramo' && num(r.tiempo_s) != null) tr.push({ desde_m:+r.desde_m, hasta_m:+r.hasta_m, t:num(r.tiempo_s) }); });
    var pasos = (rows || []).filter(function(r){ return r.medida === 'paso' && +r.desde_m === 0 && num(r.tiempo_s) != null; }).sort(function(a, b){ return a.hasta_m - b.hasta_m; });
    var d = 0, t0 = 0;
    pasos.forEach(function(p){
      var h = +p.hasta_m, t = num(p.tiempo_s);
      if (!tr.some(function(x){ return x.desde_m === d && x.hasta_m === h; })) tr.push({ desde_m:d, hasta_m:h, t:n2(t - t0), de_pasos:true });
      d = h; t0 = t;
    });
    return tr;
  }
  function acumulados(F, campo){
    var out = [], fin = 0, s = 0, roto = false;
    F.forEach(function(f){
      if (f.desde_m !== fin || f[campo] == null) roto = true;
      s += f[campo] || 0; fin = f.hasta_m;
      out.push({ hasta_m:f.hasta_m, t: roto ? null : n2(s) });
    });
    return out;
  }
  function parcialesFrenteModelo(rows, modelo){
    var R = principales(tramosDe(rows));
    var M = modelo ? principales((modelo.tramos || []).map(function(x){ return { desde_m:+x.desde_m, hasta_m:+x.hasta_m, t:num(x.tiempo_s) }; })) : [];
    var filas = R.map(function(r){
      var m = M.filter(function(x){ return x.desde_m === r.desde_m && x.hasta_m === r.hasta_m; })[0];
      return { desde_m:r.desde_m, hasta_m:r.hasta_m, real:r.t, modelo: m ? m.t : null, dif: m && m.t != null ? n2(r.t - m.t) : null, de_pasos:!!r.de_pasos };
    });
    var sinPar = M.filter(function(m){ return !R.some(function(r){ return r.desde_m === m.desde_m && r.hasta_m === m.hasta_m; }); });
    var conDif = filas.filter(function(f){ return f.dif != null; });
    var mayor = conDif.reduce(function(b, f){ return !b || Math.abs(f.dif) > Math.abs(b.dif) ? f : b; }, null);
    var unicoMayor = mayor && conDif.filter(function(f){ return Math.abs(f.dif) === Math.abs(mayor.dif); }).length === 1;
    var fm = filas.map(function(f){ return { desde_m:f.desde_m, hasta_m:f.hasta_m, modelo:f.modelo }; });
    return { filas:filas, pasosReal:acumulados(filas, 'real'), pasosModelo:acumulados(fm, 'modelo'),
             sumaReal: filas.length ? n2(filas.reduce(function(s, f){ return s + (f.real || 0); }, 0)) : null,
             sumaModelo: M.length ? n2(M.reduce(function(s, f){ return s + (f.t || 0); }, 0)) : null,
             mayor: unicoMayor ? mayor : null, sinPar:sinPar,
             modelo: modelo ? { estado:modelo.estado, origen:modelo.origen, aprobado: modelo.estado === 'vigente' && !!modelo.aprobado_en, version:modelo.version } : null };
  }

  /* ---------- 3 · Sesiones comparables ----------
     Se compara la fila (bloque o ejercicio) relevante por su prescripción leída, no
     por el título, la nota ni el número de versión. Las condiciones se miran aparte:
     si alguna falta, «comparabilidad por confirmar»; si dos conocidas difieren, no se
     comparan como iguales. */
  var CONDS = {
    carrera:     ['salida', 'calzado', 'superficie', 'metodo'],
    vallas:      ['altura', 'separacion', 'salida', 'calzado', 'superficie', 'metodo'],
    fuerza:      ['variante', 'recorrido'],
    salto:       ['altura'],
    lanzamiento: ['superficie']
  };
  var COND_TXT = { salida:'salida', calzado:'calzado', superficie:'superficie', metodo:'método de medición', variante:'variante', recorrido:'recorrido', altura:'altura', separacion:'separaciones' };
  function normTxt(t){ return String(t || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9%:,.\/-]+/g, ' ').trim(); }
  function clavePrescripcion(E){
    var comps = (E.componentes || []).filter(function(c){ return c.clase && c.clase !== 'pendiente'; });
    if (!comps.length) return null;
    var parte = comps.map(function(c){
      return [c.clase, c.m, c.reps, c.tiempo_obj && c.tiempo_obj.join('-'), c.ritmo_km && c.ritmo_km.join('-'), c.pct_esfuerzo && JSON.stringify(c.pct_esfuerzo),
              c.pct_rm && JSON.stringify(c.pct_rm), c.rir, c.clase === 'fuerza' ? normTxt(c.ejercicio) : '', c.modalidad, c.salidas ? 'salidas' : '', c.arrastre ? 'arrastre' : '',
              c.progresivo ? 'prog' : '', c.peso_kg, c.vallas, c.entrada_m].map(function(v){ return v == null ? '' : String(v); }).join('/');
    }).join('+');
    var rec = E.recuperacion ? normTxt(E.recuperacion.texto).replace(/\s*[zc]$/, '') : '';
    // «Bloque 1/2» y «Bloque 2/2» son bloques distintos: cada uno se compara con el suyo
    var bq = /^\s*bloque\s*(\d+)\s*\/\s*(\d+)/i.exec(E.texto || '');
    return (bq ? 'b' + bq[1] + '/' + bq[2] + ':' : '') + (E.bloques || 1) + '×[' + parte + ']·rec:' + rec;
  }
  function condicionesDe(E, fila, reg, X){
    var c0 = (E.componentes || [])[0] || {}, txt = normTxt((fila && (fila.ejercicio + ' ' + (fila.detalle || ''))) || E.texto);
    var calz = E.calzado || (fila && fila.calzado) || null;
    var salida = c0.salidas ? 'tacos' : /lanzad/.test(txt) ? 'lanzada' : /de pie/.test(txt) ? 'de pie' : /tacos/.test(txt) ? 'tacos' : null;
    var tiempos = []; (X || []).forEach(function(x){ (x.tiempos || []).forEach(function(t){ tiempos.push(t); }); });
    var mets = tiempos.map(function(t){ return t.fuente === 'entrenador' && t.metodo && t.metodo !== 'no_consta' ? t.metodo : null; });
    var metodo = !tiempos.length ? null : mets.every(function(x){ return x; }) ? mets[0] : mets.some(function(x){ return x; }) ? mets.filter(Boolean)[0] : null;
    return { salida:salida, calzado: calz ? String(calz).toUpperCase() : null, superficie: reg && reg.superficie || null, metodo:metodo,
             variante:null, recorrido:null, altura: c0.altura_m != null ? c0.altura_m : (c0.altura_cm != null ? c0.altura_cm : null), separacion: c0.separacion_m != null ? c0.separacion_m : null };
  }
  /* sesiones: [{ s:{id,fecha,titulo}, reg, vencida, futura, filas:[{estructura, fila, bloque}], X:[ejecutados] }] */
  function sesionesComparables(sesiones){
    var G = {};
    (sesiones || []).forEach(function(S){
      if (S.futura) return;
      (S.filas || []).forEach(function(F){
        var E = F.estructura || {};
        var comps = (E.componentes || []).filter(function(c){ return c.clase && c.clase !== 'pendiente'; });
        var clase = comps.length ? comps[0].clase : null;
        if (!clase || !CONDS[clase] || E.posicion === 'calentamiento' || E.posicion === 'vuelta_calma') return;
        var k = clavePrescripcion(E); if (!k) return;
        var X = (S.X || []).filter(function(x){ return x.a && x.a.fila_id === E.fila_id && !x.a.recuperacion && !x.a.opcional; });
        var hechos = X.filter(function(x){ return x.estado === 'confirmado' || x.estado === 'global'; }).length;
        var conocidos = X.filter(function(x){ return x.estado === 'confirmado' || x.estado === 'global' || x.estado === 'no_realizado'; }).length;
        var tiempos = []; X.forEach(function(x, i){ (x.tiempos || []).forEach(function(t){ tiempos.push({ rep:i + 1, m:x.a.c && x.a.c.m, valor:t.valor, num:num(t.valor), fuente:t.fuente, metodo:t.metodo }); }); });
        var g = G[k] = G[k] || { clave:k, clase:clase, texto:E.texto, casos:[] };
        g.casos.push({ sid:S.s.id, fecha:S.s.fecha, titulo:S.s.titulo, fila_id:E.fila_id, texto:E.texto, cond:condicionesDe(E, F.fila, S.reg, X),
                       registro: !!(S.reg || S.regEnt || (S.toma || []).length), vencida:!!S.vencida,
                       hechas:hechos, conocidas:conocidos, previstas:X.length, tiempos:tiempos,
                       rpe: S.reg && S.reg.rpe != null ? S.reg.rpe : null, comentario: S.reg ? (S.reg.notas_atleta || S.reg.como_me_siento || null) : null });
      });
    });
    var out = Object.keys(G).map(function(k){ return G[k]; }).filter(function(g){
      var dias = {}; g.casos.forEach(function(c){ dias[c.sid] = 1; }); return Object.keys(dias).length >= 2;
    });
    out.forEach(function(g){
      g.casos.sort(function(a, b){ return String(a.fecha).localeCompare(String(b.fecha)); });
      var cs = CONDS[g.clase], faltan = [], distintas = [];
      cs.forEach(function(k){
        var vals = g.casos.filter(function(c){ return c.registro || c.tiempos.length; }).map(function(c){ return c.cond[k]; });
        if (!vals.length) return;
        var conocidos = vals.filter(function(v){ return v != null; });
        if (conocidos.length < vals.length) faltan.push(COND_TXT[k]);
        var dist = conocidos.filter(function(v, i, L){ return L.indexOf(v) === i; });
        if (dist.length > 1) distintas.push(COND_TXT[k] + ' (' + dist.join(' / ') + ')');
      });
      g.faltan = faltan; g.distintas = distintas;
      g.estado = distintas.length ? 'condiciones_distintas' : faltan.length ? 'por_confirmar' : 'comparable';
      g.conDatos = g.casos.filter(function(c){ return c.conocidas > 0 || c.tiempos.length; }).length;
      g.intentos = g.casos.reduce(function(s, c){ return s + c.hechas; }, 0);
      g.evolucion = g.conDatos >= 3 ? 'descriptiva' : 'insuficiente';
    });
    out.sort(function(a, b){ return b.conDatos - a.conDatos || b.casos.length - a.casos.length; });
    return out;
  }

  /* ---------- 4 · Revisiones de decisiones ----------
     «Vencida»: la fecha de revisión ya ha llegado. «Próxima»: dentro de los días del
     grupo. Ninguna cierra la decisión: sigue vigente hasta que alguien la revisa. */
  function sumarDias(iso, n){ var d = new Date(iso + 'T12:00:00'); d.setDate(d.getDate() + n); return d.toISOString().slice(0, 10); }
  function revisiones(decisiones, hoy, dias){
    dias = dias || 21;
    var lim = sumarDias(hoy, dias), V = [], P = [], S = [];
    (decisiones || []).filter(function(d){ return d.estado === 'vigente'; }).forEach(function(d){
      if (!d.revision) S.push(d);
      else if (d.revision <= hoy) V.push(d);
      else if (d.revision <= lim) P.push(d);
    });
    var f = function(a, b){ return String(a.revision).localeCompare(String(b.revision)); };
    return { vencidas:V.sort(f), proximas:P.sort(f), sinFecha:S, dias:dias, hasta:lim };
  }

  /* ---------- 5 · Cobertura: siempre N de M y porcentaje, sin umbral ---------- */
  function pct(n, d){ return d ? Math.round(n * 100 / d) : null; }
  function cobTxt(n, d, unidad){
    if (!d) return 'sin nada que medir';
    var f = function(x){ return unidad === 'm' ? String(Math.round(x)).replace(/\B(?=(\d{3})+(?!\d))/g, '.') + ' m' : String(Math.round(x * 10) / 10).replace('.', ','); };
    return f(n) + ' de ' + f(d) + ' (' + pct(n, d) + ' %)';
  }

  var API = { METODO:METODO, CONDS:CONDS, COND_TXT:COND_TXT, coma:coma, marcasComparables:marcasComparables, parcialesFrenteModelo:parcialesFrenteModelo,
              tramosDe:tramosDe, principales:principales, clavePrescripcion:clavePrescripcion, sesionesComparables:sesionesComparables,
              revisiones:revisiones, sumarDias:sumarDias, pct:pct, cobTxt:cobTxt };
  if (typeof module !== 'undefined' && module.exports) module.exports = API; else root.APOLANA_ANALISIS = API;
})(this);
