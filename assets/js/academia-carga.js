/* =====================================================================
   Academia · Carga y contenidos — motor de la primera versión (v3, 29-oct)
   ---------------------------------------------------------------------
   Reglas: docs/definiciones-carga-contenidos.md y ejemplos en
   docs/ejemplos-calculo-academia.md. Solo cuenta lo que se sabe:
     · lee cada fila del plan y PROPONE su estructura (cantidad, posición,
       objetivo, medio); lo que el entrenador declara en la sesión es
       «declarado»; lo que la app interpreta, «propuesta»;
     · cruza lo previsto con lo que apuntan el atleta y el entrenador, por
       magnitud y repetición: confirmado, no realizado, sin concretar, sin
       datos, en discrepancia, opcional y adicional;
     · nada se rellena con el plan ni se convierte en cero.
   Sin índices globales, ni recomendaciones, ni proyecciones.
   Se carga en el navegador (window.APOLANA_CARGA) y en node (pruebas).
   ===================================================================== */
(function (root) {
  'use strict';

  var POS = { calentamiento:'Calentamiento', principal:'Parte principal', recuperacion:'Recuperación entre esfuerzos', vuelta_calma:'Vuelta a la calma' };
  var OBJ = {
    aceleracion:['Aceleración','carrera'], vmax:['Velocidad máxima','carrera'], resistencia:['Resistencia a la velocidad','carrera'],
    ritmo:['Ritmo específico','carrera'], aerobico:['Aeróbico','carrera'], glucolitico:['Glucolítico (intención)','carrera'],
    calentamiento:['Calentamiento','carrera'], entrada:['Entrada progresiva','carrera'], recuperacion:['Recuperación entre esfuerzos','carrera'], tecnica_carrera:['Técnica de carrera','carrera'],
    tecnica_vallas:['Técnica de vallas','tecnica'], potencia:['Fuerza · potencia','fuerza'], fuerza:['Fuerza','fuerza'], complementaria:['Fuerza complementaria','fuerza'],
    preventivo:['Preventivo','movilidad'], movilidad:['Movilidad','movilidad']
  };
  var FAM = { carrera:'Carrera', tecnica:'Técnica', fuerza:'Fuerza', saltos:'Saltos', lanzamientos:'Lanzamientos', movilidad:'Movilidad, core y preventivos' };
  var CLASE_FAM = { carrera:'carrera', vallas:'tecnica', tecnico:'tecnica', fuerza:'fuerza', salto:'saltos', lanzamiento:'lanzamientos', movilidad:'movilidad', pendiente:'pendiente' };

  function num(s){ return s == null || s === '' ? null : Number(String(s).replace(',', '.')); }
  function norm(t){
    return String(t || '').replace(/×/g, 'x').replace(/[–—]/g, '-').replace(/[’'`]/g, '′').replace(/(\d)\s*''/g, '$1″').replace(/\s+/g, ' ').trim();
  }
  function rango(a, b){ a = num(a); b = b == null ? null : num(b); return b != null && b !== a ? [a, b] : a; }
  function minDe(v){ return Array.isArray(v) ? v[0] : v; }
  function maxDe(v){ return Array.isArray(v) ? v[1] : v; }

  /* ---------- objetivo declarado por el entrenador (el de la sesión) ----------
     Solo si nombra UN objetivo que conocemos. «Velocidad + resistencia» no
     declara nada fila a fila: las filas quedan como propuesta. */
  function objetivoSesion(texto){
    var t = String(texto || '').toLowerCase().trim();
    if (!t || /\s\+\s|\sy\s|,/.test(t)) return null;
    var m;
    if ((m = /^ritmo\s*(?:de\s*)?(\d{3,4})/.exec(t))) return { clave:'ritmo', detalle:m[1] };
    if (/^aceleraci[oó]n/.test(t)) return { clave:'aceleracion' };
    if (/^(velocidad m[aá]xima|vm[aá]x)/.test(t)) return { clave:'vmax' };
    if (/^resistencia a la velocidad/.test(t)) return { clave:'resistencia' };
    if (/^aer[oó]bico/.test(t)) return { clave:'aerobico' };
    if (/^gluc[oó]lítico|^glucolitico/.test(t)) return { clave:'glucolitico' };
    if (/^fuerza[\s-]*potencia|^potencia/.test(t)) return { clave:'potencia' };
    if (/^fuerza complementaria/.test(t)) return { clave:'complementaria' };
    if (/^fuerza/.test(t)) return { clave:'fuerza' };
    if (/^t[eé]cnica de vallas/.test(t)) return { clave:'tecnica_vallas' };
    if (/^t[eé]cnica de carrera/.test(t)) return { clave:'tecnica_carrera' };
    if (/^preventivos?/.test(t)) return { clave:'preventivo' };
    return null;
  }
  function posicionDeBloque(et){
    var t = String(et || '').toLowerCase();
    if (/calentamiento/.test(t)) return 'calentamiento';
    if (/vuelta a la calma|enfriamiento/.test(t)) return 'vuelta_calma';
    return 'principal';
  }

  /* ---------- lector de una fila: propone su estructura y dice sus dudas ---------- */
  function leerFila(fila, ctx){
    ctx = ctx || {};
    var texto = norm([fila.ejercicio, fila.detalle].filter(Boolean).join(' · '));
    var E = { fila_id:fila.id, texto:texto, posicion:ctx.posicion || 'principal', bloques:1, componentes:[], dudas:[], calzado:null, recuperacion:null, opcional_reps:0, estado:'propuesta' };
    var t = texto, m;
    // calzado al final («… // 3′ C»)
    if ((m = /\s([CZ])\s*$/.exec(t))) { E.calzado = m[1]; t = t.slice(0, m.index).trim(); }
    // descanso tras «//»
    var desc = '';
    if (t.indexOf('//') !== -1) { desc = t.slice(t.indexOf('//') + 2).trim(); t = t.slice(0, t.indexOf('//')).trim(); }
    // opcionales («+ 1 opcional», «6.º opcional»)
    if ((m = /\+\s*(\d+)\s*opcional/i.exec(t))) { E.opcional_reps = +m[1]; t = t.replace(m[0], '').trim(); }
    else if (/opcional/i.test(t)) E.dudas.push('Tiene una parte opcional: indica cuántas repeticiones son opcionales.');
    // «Bloque 1/3 a 3/3:» · «Bloque 1/2:» · «Transferencia:»
    var prefB = null;   // «Bloque k/n» dice cuántos bloques hay en ESTA fila
    if ((m = /^bloque\s*(\d+)\s*\/\s*(\d+)\s*(?:a|y)\s*(\d+)\s*\/\s*\d+\s*:\s*/i.exec(t))) { prefB = +m[3] - +m[1] + 1; t = t.slice(m[0].length); }
    else if ((m = /^bloque\s*\d+\s*\/\s*\d+\s*:\s*/i.exec(t))) { prefB = 1; t = t.slice(m[0].length); }
    if (prefB != null) E.bloques = prefB;
    var etiqueta = null;
    if ((m = /^([A-Za-zÁÉÍÓÚáéíóúñÑ ]{3,30}):\s*/.exec(t)) && !/^\d/.test(t)) { etiqueta = m[1].trim(); t = t.slice(m[0].length); }

    var comps = [];
    // 1) Carrera por minutos: «45′ CC a 4:55-5:15/km», «50-55′ CC», «15′ CC + técnica»
    if ((m = /^(\d+(?:[.,]\d+)?)(?:\s*-\s*(\d+(?:[.,]\d+)?))?\s*′\s*(cc|trote|rodaje|carrera continua)\b([^+]*)/i.exec(t))) {
      var c = { clase:'carrera', reps:1, min:rango(m[1], m[2]), texto:m[0].trim() };
      var rit = /(\d+:\d{2})\s*-\s*(\d+:\d{2})\s*\/\s*km/.exec(m[4] || '');
      if (rit) c.ritmo_km = [rit[1], rit[2]];
      comps.push(c);
      t.slice(m[0].length).split('+').map(function(x){ return x.trim(); }).filter(Boolean).forEach(function(x){ comps.push(extra(x, E)); });
    }
    // 2) Vallas: «2x primera valla», «2x tres vallas»
    else if ((m = /^(\d+)\s*x\s*(primera|una|dos|tres|cuatro|cinco|seis|\d+)\s*vallas?/i.exec(t))) {
      var NV = { primera:1, una:1, dos:2, tres:3, cuatro:4, cinco:5, seis:6 };
      var alt = /(\d[.,]\d{2,3})\s*m?/.exec(t);
      E.bloques = +m[1];
      comps.push({ clase:'vallas', reps:1, vallas:NV[m[2].toLowerCase()] || +m[2], altura_m: alt ? num(alt[1]) : null, texto:t });
      if (!alt) E.dudas.push('Faltan la altura y la separación de las vallas: sin ellas no hay metros ni comparación.');
    }
    // 3) Lanzados con entrada y tramo explícitos, o flying (a+b)
    else if ((m = /^(\d+)\s*x\s*(\d+)\s*(?:m\s*)?(?:lanzados?|flying)[^]*?entrada\s*(\d+)\s*m?\s*\+\s*tramo\s*(\d+)/i.exec(t)) ||
             (m = /^(\d+)\s*x\s*(\d+)\s*(?:m\s*)?(?:lanzados?|flying)\s*\(\s*(\d+)\s*\+\s*(\d+)\s*\)/i.exec(t))) {
      E.bloques = +m[1];
      comps.push({ clase:'carrera', reps:1, m:+m[4], entrada_m:+m[3], lanzado:true, texto:t });
      if (+m[2] !== +m[4]) E.dudas.push('El tramo del título (' + m[2] + ' m) no coincide con el del paréntesis (' + m[4] + ' m): ¿incluye la entrada?');
    }
    // 3 bis) «3x60 (20+60) lanzados»: ¿los 60 incluyen la entrada? No se calcula (B3)
    else if ((m = /^(\d+)\s*x\s*(\d+)\s*\(\s*(\d+)\s*\+\s*(\d+)\s*\)\s*(?:m\s*)?(?:lanzados?|flying)/i.exec(t))) {
      E.bloques = +m[1];
      comps.push({ clase:'pendiente', lanzado:true, texto:t });
      E.dudas.push('¿Los ' + m[2] + ' m incluyen la entrada de ' + m[3] + ' m o se suman (' + (+m[3] + +m[4]) + ' m por repetición)? No se calcula hasta aclararlo.');
    }
    // 3 ter) saltos y lanzamientos «2x10 pogos», «3x6 balón 4 kg», «2x5 saltos a una pierna/lado»
    else if ((m = /^(\d+)\s*x\s*(\d+)\s*(\/\s*(?:pierna|lado))?\s*((?:pogos|saltos?|multisaltos|comba|cmj|drop|lanzamientos?|bal[oó]n)\b.*)$/i.exec(t))) {
      if (prefB == null) E.bloques = +m[1];
      var cs = componenteEjercicio(m[4], +m[2], m[4], E);
      if (m[3]) { cs.lateralidad = 'unilateral'; cs.por_lado = true; }
      comps.push(cs);
    }
    // 4) Bloques entre paréntesis: «3x(30 m arrastre + 60 m libre)», «3x(3+2)» con fuerza+saltos
    else if ((m = /^(.*?)(\d+)\s*x\s*\(([^)]*)\)(.*)$/i.exec(t))) {
      E.bloques = +m[2];
      var antes = m[1].trim(), dentro = m[3].split('+').map(function(x){ return x.trim(); }), despues = m[4].trim();
      if (antes && /[a-zñ]/i.test(antes)) {
        // «Media sentadilla + saltos al cajón 3x(3+2) al 75-80% RM»: un ejercicio por número
        var ejs = antes.split('+').map(function(x){ return x.trim(); });
        dentro.forEach(function(n, i){ comps.push(componenteEjercicio(ejs[i] || ejs[ejs.length - 1], +n, i === 0 ? despues : '', E)); });
      } else dentro.forEach(function(x){ comps.push(componenteCarrera(x, E)); });
    }
    // 5) Fuerza «Media cargada 3x3 al 60-65% RM», «Tren superior 3x8 RIR 3»
    else if ((m = /^([A-Za-zÁÉÍÓÚáéíóúñÑ][A-Za-zÁÉÍÓÚáéíóúñÑ ]{2,40}?)\s+(\d+)\s*x\s*(\d+)(\s*\/\s*(?:pierna|lado))?\s*(.*)$/i.exec(t)) && !/\bm\b/.test(m[5].split(/al|rir/i)[0])) {
      if (prefB == null) E.bloques = +m[2];
      var cf = componenteEjercicio(m[1], +m[3], (m[4] || '') + ' ' + m[5], E);
      if (m[4]) cf.por_lado = true;
      if (prefB != null) { cf.series_en_bloque = +m[2]; E.bloques = prefB * +m[2]; }
      comps.push(cf);
    }
    // 6) Series de carrera «4x150 m al 85-90%», «5x1000 en 3:25-3:30», «2x4x120»
    else if ((m = /^(\d+)\s*x\s*(?:(\d+)\s*x\s*)?(\d+)\s*(?:m\b)?\s*(.*)$/i.exec(t))) {
      var cc = componenteCarrera(m[3] + ' m ' + m[4], E);
      if (prefB != null) { cc.reps = +m[1] * (m[2] ? +m[2] : 1); }      // «Bloque 1/2: 4x120» = 1 bloque de 4
      else { E.bloques = +m[1]; if (m[2]) cc.reps = +m[2]; }
      comps.push(cc);
    }
    // 7) Suma de tramos «200 + 150 + 100», «250 (37-38″) + 150 (21,5-22,5″)»
    else if (/^\d+[^+]*\+/.test(t) && t.split('+').every(function(x){ return /^\s*\d/.test(x); })) {
      t.split('+').forEach(function(x){ comps.push(componenteCarrera(x.trim(), E)); });
    }
    // 8) Movilidad, core, preventivos, técnica sin cantidad (cada parte por su lado)
    else t.split('+').map(function(x){ return x.trim(); }).filter(Boolean).forEach(function(x){ comps.push(extra(x, E)); });

    if (etiqueta) comps.forEach(function(c){ c.etiqueta = etiqueta; });
    // descanso: trote de recuperación (cuenta como carrera, posición recuperación) o pasivo
    if (desc) {
      var tr = /(\d+(?:[.,]\d+)?)\s*′\s*(?:de\s*)?trote/i.exec(desc);
      E.recuperacion = { texto:desc, trote_min: tr ? num(tr[1]) : null };
    }
    comps.forEach(function(c){ if (c.clase === 'carrera' && E.calzado === 'C') c.clavos = true; if (E.calzado) c.calzado = E.calzado; });
    E.componentes = comps;
    if (comps.some(function(c){ return c.clase === 'pendiente'; })) E.dudas.push('Hay una parte que no se ha podido leer: revísala.');
    clasificar(E, ctx);
    return E;
  }
  function componenteCarrera(x, E){
    var m, c = { clase:'carrera', reps:1, texto:x };
    if ((m = /^(\d+)\s*(?:m\b)?/.exec(x))) c.m = +m[1];
    if ((m = /\(\s*([\d:.,]+)\s*-\s*([\d:.,]+)\s*″?\s*\)/.exec(x))) c.tiempo_obj = [m[1], m[2]];
    if ((m = /en\s*(\d+:\d{2})\s*-\s*(\d+:\d{2})/.exec(x))) c.ritmo_km = [m[1], m[2]];
    if ((m = /al\s*(\d+)(?:\s*-\s*(\d+))?\s*%/.exec(x)) && !/rm/i.test(x)) c.pct_esfuerzo = rango(m[1], m[2]);
    if (/arrastre|trineo/i.test(x)) c.arrastre = { discos_kg:null, masa_kg:null, superficie:null, material:null };
    if (/salidas?\b|tacos/i.test(x)) c.salidas = true;
    if (/progresiv/i.test(x)) c.progresivo = true;
    if (/libre/i.test(x)) c.libre = true;
    if ((m = /\((\d+(?:[.,]\d+)?)\s*kg\)/i.exec(x)) && c.arrastre) { c.arrastre.kg_sin_aclarar = num(m[1]); E.dudas.push('«' + m[1] + ' kg» del arrastre: ¿discos añadidos o masa total? Queda pendiente.'); }
    if (c.m == null) { c.clase = 'pendiente'; }
    return c;
  }
  function componenteEjercicio(nombre, reps, resto, E){
    var n = String(nombre || '').trim(), m;
    var c = { clase:'fuerza', ejercicio:n, reps:reps, texto:(n + ' ' + reps + ' ' + (resto || '')).trim() };
    if (/^(saltos?|cajón|cajon|cmj|drop|pogos?|multisaltos?|comba)\b/i.test(n)) {
      c.clase = 'salto'; c.modalidad = /caj[oó]n/i.test(n) ? 'cajon' : /pogo/i.test(n) ? 'pogos' : /cmj/i.test(n) ? 'cmj' : /drop/i.test(n) ? 'drop_jump' : /multisalto/i.test(n) ? 'multisaltos' : 'salto';
      c.unidad = c.modalidad === 'pogos' || c.modalidad === 'comba' ? 'contactos' : c.modalidad === 'multisaltos' || c.modalidad === 'salto' ? null : 'saltos';
      c.lateralidad = /una pierna|unilateral|\/pierna|\/lado/i.test(n + ' ' + resto) ? 'unilateral' : 'bilateral';
      if (!c.unidad) E.dudas.push('«' + n + '»: ¿saltos o contactos? Fija la unidad del ejercicio.');
      if (c.modalidad === 'cajon') c.altura_cm = null;
    } else if (/bal[oó]n|lanzamiento/i.test(n)) {
      c.clase = 'lanzamiento'; c.unidad = 'lanzamientos';
      if ((m = /(\d+(?:[.,]\d+)?)\s*kg/i.exec(n + ' ' + resto))) c.peso_kg = num(m[1]); else E.dudas.push('Falta el peso del balón.');
    } else {
      if ((m = /al\s*(\d+)(?:\s*-\s*(\d+))?\s*%\s*rm/i.exec(resto || ''))) c.pct_rm = rango(m[1], m[2]);
      if ((m = /rir\s*(\d+)/i.exec(resto || ''))) c.rir = +m[1];
      if (/unilateral|búlgar|bulgar|zancada/i.test(n)) { c.unilateral = true; if (!/\/(pierna|lado)/i.test(resto || '') && !c.por_lado) E.dudas.push('«' + n + '»: ¿las repeticiones son por pierna?'); }
      if (/salto/i.test(n)) c.etiquetas = (c.etiquetas || []).concat(['con salto']);
      if (/n[oó]rdic|isquio|copenhague|preventiv/i.test(n)) c.etiquetas = ['preventivo'];
    }
    return c;
  }
  function extra(x, E){
    var t = String(x || '').toLowerCase(), m, mi = /(\d+(?:[.,]\d+)?)\s*′/.exec(x);
    var c = { clase:'pendiente', texto:x, sin_cantidad:true };
    if (/t[eé]cnica|skipping|talones|\ba-b\b|\bab\b/.test(t)) c.clase = 'tecnico';
    else if (/movilidad|core|preventiv|estiramient|rodillo|aproximaci/.test(t)) { c.clase = 'movilidad'; if (/preventiv/.test(t)) c.etiquetas = ['preventivo']; }
    if (mi) { c.min = num(mi[1]); c.sin_cantidad = false; }
    if ((m = /^(\d+)\s*x\s*(\d+)\s*pogos/i.exec(x))) { c = { clase:'salto', modalidad:'pogos', unidad:'contactos', lateralidad:'bilateral', reps:+m[2], texto:x }; E.bloques = +m[1]; }
    return c;
  }

  /* Objetivo de cada componente.
     · Declarado: el que el entrenador escribe en el BLOQUE (su etiqueta) para las
       partes de su misma clase.
     · El objetivo general de la SESIÓN no se reparte solo: es una propuesta para
       las partes principales de su clase, y calentamiento, core y fuerza conservan
       su propio tratamiento.
     · Lo demás, propuesta de la lectura del texto o pendiente. */
  function encaja(dec, c){
    var fam = CLASE_FAM[c.clase];
    return !!(dec && OBJ[dec.clave] && (OBJ[dec.clave][1] === fam || (dec.clave === 'tecnica_vallas' && c.clase === 'vallas') || (dec.clave === 'preventivo' && c.clase === 'movilidad')));
  }
  function ponObjetivo(c, dec, clasif, origen, ctx){
    c.objetivo = dec.clave; c.clasif = clasif; c.origen_objetivo = origen; if (dec.detalle) c.objetivo_detalle = dec.detalle;
    if (dec.clave === 'ritmo') { c.referencia = ctx.referenciaRitmo ? 'conocida' : 'pendiente'; c.adecuacion = 'no_evaluada'; }
  }
  function clasificar(E, ctx){
    var decB = ctx.objetivoBloque || null, decS = ctx.objetivoSesion || null;
    E.componentes.forEach(function(c){
      c.posicion = E.posicion;
      // el calentamiento es posición y función, no el objetivo de la sesión
      if (E.posicion === 'calentamiento' && c.clase === 'carrera') { c.objetivo = 'calentamiento'; c.clasif = 'declarada'; c.origen_objetivo = 'posicion'; return; }
      if (E.posicion === 'principal' && encaja(decB, c)) { ponObjetivo(c, decB, 'declarada', 'bloque', ctx); return; }
      if (E.posicion === 'principal' && encaja(decS, c) && c.clase === 'carrera') { ponObjetivo(c, decS, 'propuesta', 'sesion', ctx); return; }
      // propuestas de la app (hay que revisarlas)
      var p = null;
      if (c.clase === 'carrera') {
        if (c.lanzado) p = 'vmax';
        else if (c.salidas || c.arrastre) p = 'aceleracion';
        else if (c.libre && E.componentes.some(function(x){ return x.arrastre; })) p = 'aceleracion';
        else if (c.min != null) p = 'aerobico';
      } else if (c.clase === 'movilidad') p = c.etiquetas && c.etiquetas[0] === 'preventivo' ? 'preventivo' : 'movilidad';
      else if (c.clase === 'vallas') p = 'tecnica_vallas';
      c.objetivo = p; c.clasif = p ? 'propuesta' : 'pendiente'; if (p) c.origen_objetivo = 'texto';
    });
  }

  /* ---------- átomos: cada repetición prevista de cada componente ----------
     Un átomo es la unidad mínima que se puede confirmar: una repetición de
     carrera, una serie de fuerza, una serie de saltos, un intento de vallas… */
  function atomos(E, base){
    var A = [], seq = 0, B = E.bloques || 1;
    var oblig = B * E.componentes.reduce(function(a, c){ return a + (c.reps && c.clase === 'carrera' ? c.reps : 1); }, 0);
    for (var b = 1; b <= B; b++) {
      E.componentes.forEach(function(c, ci){
        var nr = c.clase === 'carrera' ? (c.reps || 1) : 1;
        for (var r = 1; r <= nr; r++) {
          seq++;
          A.push(Object.assign({ fila_id:E.fila_id, ci:ci, bloque:b, rep:r, seq:seq, c:c, opcional:false, recuperacion:false }, base || {}));
        }
      });
    }
    // repeticiones opcionales (al final, separadas del compromiso)
    for (var o = 1; o <= (E.opcional_reps || 0); o++) {
      var c0 = E.componentes[0]; seq++;
      A.push(Object.assign({ fila_id:E.fila_id, ci:0, bloque:B + o, rep:1, seq:seq, c:c0, opcional:true, recuperacion:false }, base || {}));
    }
    // recuperaciones con trote entre repeticiones: N − 1 previstas
    if (E.recuperacion && E.recuperacion.trote_min != null && oblig > 1) {
      for (var k = 1; k < oblig; k++) A.push(Object.assign({ fila_id:E.fila_id, ci:-1, bloque:k, rep:1, seq:1000 + k, opcional:false, recuperacion:true,
        c:{ clase:'carrera', min:E.recuperacion.trote_min, objetivo:'recuperacion', clasif:'declarada', posicion:'recuperacion', texto:E.recuperacion.texto } }, base || {}));
    }
    return A;
  }

  /* Cantidades de un átomo, por magnitud (prescritas; el kg aparte). */
  function cantidades(a){
    var c = a.c, q = {};
    if (c.clase === 'carrera') {
      if (c.m != null) q.m = c.m;                       // el tramo (con su objetivo)
      if (c.entrada_m) q.entrada_m = c.entrada_m;       // la entrada progresiva, aparte
      if (c.min != null) q.min = c.min;
    } else if (c.clase === 'fuerza') { q.series = 1; q.reps = c.reps; }
    else if (c.clase === 'salto') { q[c.unidad || 'saltos_o_contactos'] = c.reps; }
    else if (c.clase === 'lanzamiento') { q.series = 1; q.lanzamientos = c.reps; }
    else if (c.clase === 'vallas') { q.intentos = 1; q.vallas = c.vallas; }
    else if (c.sin_cantidad) q.hecho = 1;
    else if (c.min != null) q.min = c.min;
    return q;
  }

  /* ---------- ejecución: qué se sabe de cada átomo ----------
     fuentes = { reg: registro del atleta (registros_sesion), toma: datos del
     entrenador de esa sesión y atleta, regEnt: declaración del entrenador }.
     Devuelve por átomo: estado (confirmado · no_realizado · sin_concretar ·
     sin_datos · discrepancia), fuentes y lo conocido de cada magnitud. */
  function ejecutar(filas, fuentes){
    var reg = fuentes.reg || null, toma = (fuentes.toma || []).filter(function(t){ return !t.anulado_en; }), ent = fuentes.regEnt || null;
    var TR = reg && reg.tiempos_reales && typeof reg.tiempos_reales === 'object' ? reg.tiempos_reales : {};
    var globalAt = !reg ? 'sin_datos' : reg.estado === 'completo' ? 'completo' : reg.estado === 'no_hecho' ? 'no_hecho' : 'parcial';
    // «Completa» sin detalle solo se lee como declaración global si su registro está atado
    // sin dudas a la versión del plan; en registros antiguos sin esa garantía no se reparte.
    var versionSegura = !!(reg && reg.sesion_version_id && reg.version_garantia === 'exacta');
    if (globalAt === 'completo' && !versionSegura) globalAt = 'completo_sin_garantia';
    var globalEnt = !ent ? null : ent.estado;
    var out = [];
    filas.forEach(function(F){
      var E = F.estructura, A = F.atomos, tr = TR[E.fila_id] || null;
      var tomaF = toma.filter(function(x){ return x.fila_id === E.fila_id; });
      var oblig = A.filter(function(a){ return !a.recuperacion && !a.opcional; });
      A.forEach(function(a){
        var at = null, en = null, kg = null, kgEnt = null, repsDecl = null, tiempos = [], contra = false;   // cada tiempo con su fuente y su método
        // --- lo del atleta ---
        if (tr) {
          var S = Array.isArray(tr.series) ? tr.series : [];
          if (a.recuperacion) {
            var s0 = S[a.bloque - 1];
            if (s0 && s0.descanso != null && String(s0.descanso).trim() !== '') at = 'hecho';
          } else if (tr.medida === 'hecho') {
            var h = S[0] && S[0].hecha;
            if (h === true && !a.opcional) at = 'hecho';
            else if (h === false && !a.opcional) contra = true;          // desmarcado a propósito
          } else {
            // una entrada por serie (fuerza) o por repetición (carrera), en orden
            var idx = a.c.clase === 'carrera' ? (a.opcional ? oblig.length + (a.bloque - E.bloques) - 1 : oblig.indexOf(a)) : a.bloque - 1;
            var s = idx >= 0 ? S[idx] : null;
            if (s) {
              if (s.peso != null && String(s.peso).trim() !== '') kg = num(s.peso);
              if (s.reps != null && String(s.reps).trim() !== '') repsDecl = num(s.reps);
              var tieneT = s.tiempo != null && String(s.tiempo).trim() !== '';
              if (tieneT) tiempos.push({ fuente:'atleta', valor:s.tiempo, metodo:'no_consta' });
              if (s.hecha === true || repsDecl != null || tieneT) at = 'hecho';
              else if (s.hecha === false) contra = true;                   // esa serie, sin marcar
            }
          }
        }
        if (!at && !a.opcional && !a.recuperacion) {
          // la declaración global no pisa lo que la fila dice de otra manera
          if (globalAt === 'completo' && !contra) at = 'hecho_global';
          else if (globalAt === 'no_hecho') at = 'no';
        }
        if (!at && a.recuperacion && globalAt === 'no_hecho') at = 'no';
        // --- lo del entrenador (su toma, por repetición, serie o fila) ---
        var T = tomaF.filter(function(x){
          if (a.recuperacion) return false;
          if (x.alcance === 'fila' || x.alcance === 'bloque' && (x.bloque == null || +x.bloque === a.bloque)) return true;
          if (x.alcance === 'serie') return +x.serie === a.bloque;
          if (x.alcance === 'repeticion') return x.serie != null ? (+x.serie === a.bloque && +x.repeticion === a.rep) : +x.repeticion === a.seq;
          return false;
        });
        T.forEach(function(x){
          if (x.magnitud === 'estado') en = x.estado === 'no_realizado' ? 'no' : x.estado === 'realizado' ? 'hecho' : (en || 'parcial');
          else if (x.magnitud === 'carga') { kgEnt = x.valor_num; en = en || 'hecho'; }
          else if (x.magnitud === 'tiempo' || x.magnitud === 'repeticiones' || x.magnitud === 'distancia') { en = en || 'hecho'; if (x.magnitud === 'tiempo') tiempos.push({ fuente:'entrenador', valor:x.valor_texto, metodo:x.metodo || 'no_consta' }); }
        });
        if (!en && !a.opcional && !a.recuperacion && globalEnt) en = globalEnt === 'realizado' ? 'hecho_global' : globalEnt === 'no_realizado' ? 'no' : null;
        // --- una sola vez: coinciden o queda en discrepancia ---
        var hechoAt = at === 'hecho' || at === 'hecho_global', hechoEn = en === 'hecho' || en === 'hecho_global';
        var detalleAt = at === 'hecho', detalleEn = en === 'hecho';
        var estado, fuente = [];
        if (at) fuente.push(at === 'hecho_global' ? 'atleta (declaración global: sesión completa)' : 'atleta');
        if (en) fuente.push(en === 'hecho_global' ? 'entrenador (declaración global de la sesión)' : 'entrenador');
        if ((hechoAt && en === 'no') || (at === 'no' && hechoEn)) estado = 'discrepancia';
        else if (detalleAt || detalleEn) estado = 'confirmado';
        else if (hechoAt || hechoEn) estado = 'global';           // solo por «completa»: se enseña aparte
        else if (at === 'no' || en === 'no') estado = 'no_realizado';
        else if (reg || ent || tomaF.length) estado = 'sin_concretar';
        else estado = 'sin_datos';
        var nota = contra && globalAt === 'completo' ? 'la sesión dice «completa» pero esta parte está sin marcar: no se da por hecha'
                 : globalAt === 'completo_sin_garantia' && !detalleAt && !a.opcional ? 'registro sin garantía de versión: «completa» no se reparte por filas' : null;
        var kgFinal = kg != null && kgEnt != null && kg !== kgEnt ? { discrepancia:[kg, kgEnt] } : (kg != null ? kg : kgEnt);
        out.push({ a:a, estado:estado, fuentes:fuente, kg:kgFinal, reps:repsDecl, tiempos:tiempos, nota:nota,
                   solo_global: (at === 'hecho_global' && en !== 'hecho') || (en === 'hecho_global' && at !== 'hecho') });
      });
    });
    // adicionales: filas «libre» del atleta y datos del entrenador marcados como adicionales
    Object.keys(TR).forEach(function(k){
      var x = TR[k]; if (!x || typeof x !== 'object' || k.indexOf('libre') !== 0 && x.fila_id !== 'libre') return;
      (x.series || [{}]).forEach(function(s){
        var m = null, mi = null;
        if (s.distancia) m = num(s.distancia) * ((x.unidad || s.unidad) === 'km' ? 1000 : 1);
        out.push({ a:{ fila_id:'libre', adicional:true, c:{ clase:'carrera', m:m, objetivo:null, clasif:'pendiente', texto:x.ejercicio || 'Trabajo adicional' } },
                   estado:'adicional', fuentes:['atleta'], tiempos: s.tiempo ? [{ fuente:'atleta', valor:s.tiempo, metodo:'no_consta' }] : [], cantidad_declarada:{ m:m, min:mi } });
      });
    });
    toma.filter(function(x){ return x.adicional; }).forEach(function(x){
      out.push({ a:{ fila_id:x.fila_id || 'adicional', adicional:true, c:{ clase:'pendiente', texto:x.ejercicio_realizado, objetivo:null, clasif:'pendiente' } }, estado:'adicional', fuentes:['entrenador'] });
    });
    return out;
  }

  /* ---------- resumen: cada cifra con su estado y de dónde sale ---------- */
  var COLS = ['previsto','confirmado','global','opcional_previsto','opcional_confirmado','adicional','no_realizado','sin_concretar','sin_datos','discrepancia'];
  function cajon(){ var o = {}; COLS.forEach(function(k){ o[k] = 0; }); o.items = {}; COLS.forEach(function(k){ o.items[k] = []; }); return o; }
  function sumar(caja, col, v, item){ if (v == null || isNaN(v)) return; caja[col] += v; caja.items[col].push(item); }

  function resumir(ejecuciones){
    var R = { porMagnitud:{}, cobertura:{}, totales:{} };
    function K(fam, mag, obj){ var k = fam + '|' + mag + '|' + (obj || ''); return R.porMagnitud[k] || (R.porMagnitud[k] = Object.assign(cajon(), { fam:fam, mag:mag, obj:obj })); }
    ejecuciones.forEach(function(x){
      var a = x.a, c = a.c, fam = CLASE_FAM[c.clase] || 'pendiente', q = a.adicional ? (x.cantidad_declarada || {}) : cantidades(a);
      var obj = c.objetivo || 'pendiente';
      var medio = [];
      if (c.arrastre) medio.push('arrastre'); if (c.clavos) medio.push('clavos'); if (c.salidas) medio.push('salidas');
      Object.keys(q).forEach(function(mag){
        var v = q[mag]; if (Array.isArray(v)) v = v[0];
        var item = { x:x, mag:mag, v:v };
        var cols = [];
        if (a.adicional) cols.push('adicional');
        else if (a.opcional) { cols.push('opcional_previsto'); if (x.estado === 'confirmado') cols.push('opcional_confirmado'); }
        else { cols.push('previsto'); cols.push(x.estado === 'confirmado' ? 'confirmado' : x.estado); }
        // la entrada progresiva son metros de carrera con su propio apartado
        var magK = mag === 'entrada_m' ? 'm' : mag, claveObj = mag === 'entrada_m' ? 'entrada' : obj;
        // saltos y lanzamientos: por modalidad e implemento, nunca juntos
        if (fam === 'saltos') claveObj = grupoSalto(c);
        if (fam === 'lanzamientos') claveObj = grupoLanzamiento(c);
        cols.forEach(function(col){
          sumar(K(fam, magK, claveObj), col, v, item);
          if (fam === 'carrera' && (magK === 'm' || magK === 'min')) {
            sumar(K('carrera', magK + '_total', ''), col, v, item);
            if (c.posicion === 'principal' && !a.recuperacion) sumar(K('carrera', magK + '_principal', ''), col, v, item);
            medio.forEach(function(md){ sumar(K('medio', md, ''), col, magK === 'm' ? v : null, item); });
          }
          if (fam === 'carrera' && mag === 'm' && c.salidas) sumar(K('medio', 'salidas_n', ''), col, 1, item);
        });
      });
      if (c.clase === 'fuerza' && !a.adicional && !a.opcional) {
        // cargas: solo de series realizadas
        var kc = K('fuerza', 'kg_series', c.ejercicio || '');
        if (x.estado === 'confirmado') sumar(kc, 'confirmado', 1, { x:x, mag:'kg', v:x.kg });
        if (x.estado === 'confirmado' && x.kg != null && typeof x.kg === 'number') sumar(kc, 'previsto', 1, { x:x, mag:'kg', v:x.kg });
        if (x.kg && typeof x.kg === 'object') sumar(kc, 'discrepancia', 1, { x:x, mag:'kg', v:x.kg });
      }
    });
    return R;
  }

  function grupoSalto(c){ return (c.modalidad || 'salto') + (c.altura_cm != null ? ' ' + c.altura_cm + ' cm' : '') + (c.lateralidad === 'unilateral' ? ' · unilateral' : ''); }
  function grupoLanzamiento(c){ return 'balón ' + (c.peso_kg != null ? String(c.peso_kg).replace('.', ',') + ' kg' : '(peso no consta)') + (c.posicion_lanz ? ' · ' + c.posicion_lanz : ''); }

  /* Cobertura por indicador, con sus números (no porcentajes de cumplimiento). */
  function cobertura(sesiones, ejecPorSesion, opts){
    opts = opts || {};
    var C = { feedback:{ num:0, den:0, anticipados:0, items:[] }, registro_entrenador:null, resultado_reps:{ num:0, den:0 }, resultado_m:{ num:0, den:0 },
              clasificacion:{ num:0, den:0 }, cargas:{ num:0, den:0, no_realizadas:0, global:0 }, metodo:{ num:0, den:0 }, lectura:{ num:0, den:0 } };
    var modo = opts.modo || 'feedback_atleta';
    if (modo === 'registro_entrenador') C.registro_entrenador = { num:0, den:0, anticipados:0 };
    sesiones.forEach(function(S){
      if (S.futura) return;                                   // lo futuro no es carencia
      var ind = modo === 'registro_entrenador' ? C.registro_entrenador : modo === 'no_requerido' ? null : C.feedback;
      if (ind) {
        var tiene = modo === 'registro_entrenador' ? !!(S.regEnt || (S.toma && S.toma.length)) : !!S.reg;
        if (S.vencida) { ind.den++; if (tiene) ind.num++; }
        else if (tiene) ind.anticipados++;
      }
      (ejecPorSesion[S.id] || []).forEach(function(x){
        var a = x.a; if (a.adicional || a.opcional) return;
        var q = cantidades(a), conocido = x.estado === 'confirmado' || x.estado === 'no_realizado' || x.estado === 'global';
        if (!S.vencida && !conocido) return;
        var mq = q.m != null ? (Array.isArray(q.m) ? q.m[0] : q.m) + (q.entrada_m || 0) : null;
        if (mq != null) { C.resultado_m.den += mq; if (conocido) C.resultado_m.num += mq; if (x.estado === 'global') C.resultado_m.global = (C.resultado_m.global||0) + mq; }
        if (a.c.clase !== 'carrera' || a.recuperacion || q.m != null) { C.resultado_reps.den++; if (conocido) C.resultado_reps.num++; if (x.estado === 'global') C.resultado_reps.global = (C.resultado_reps.global||0) + 1; }
        if ((x.estado === 'confirmado' || x.estado === 'global') && mq != null && !a.recuperacion) { C.clasificacion.den += mq; if (a.c.clasif === 'declarada' || a.c.clasif === 'revisada') C.clasificacion.num += mq; }
        if (a.c.clase === 'fuerza' && (a.c.pct_rm || a.c.kg)) {
          // series realizadas (con detalle o por «completa»): ¿se saben sus kg?
          if (x.estado === 'confirmado' || x.estado === 'global') { C.cargas.den++; if (typeof x.kg === 'number') C.cargas.num++; if (x.estado === 'global') C.cargas.global++; }
          if (x.estado === 'no_realizado') C.cargas.no_realizadas++;
        }
        (x.tiempos || []).forEach(function(t){ C.metodo.den++; if (t.metodo && t.metodo !== 'no_consta') C.metodo.num++; });
      });
      (S.filas || []).forEach(function(F){ C.lectura.den++; if (F.estructura.estado === 'revisada' || F.estructura.estado === 'manual') C.lectura.num++; });
    });
    return C;
  }

  /* Km estimados a partir de minutos y ritmo (estimación, aparte). */
  function kmEstimados(c){
    if (!c.ritmo_km || c.min == null) return null;
    var p = function(s){ var x = String(s).split(':'); return +x[0] + (+x[1]) / 60; };
    var lo = minDe(c.min) / p(c.ritmo_km[1]), hi = maxDe(c.min) / p(c.ritmo_km[0]);
    return [Math.round(lo * 10) / 10, Math.round(hi * 10) / 10];
  }

  var API = { POS:POS, OBJ:OBJ, FAM:FAM, CLASE_FAM:CLASE_FAM, COLS:COLS, norm:norm, objetivoSesion:objetivoSesion, posicionDeBloque:posicionDeBloque,
              leerFila:leerFila, atomos:atomos, cantidades:cantidades, ejecutar:ejecutar, resumir:resumir, cobertura:cobertura, kmEstimados:kmEstimados };
  if (typeof module !== 'undefined' && module.exports) module.exports = API; else root.APOLANA_CARGA = API;
})(this);
