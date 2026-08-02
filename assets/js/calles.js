/* ============================================================================
   CALLES DE NATACIÓN · el modelo, sin pantalla
   ----------------------------------------------------------------------------
   Aquí vive lo que hay que saber para leer una sesión de natación repartida por
   calles, y nada más: ni HTML, ni base de datos. Lo usa /portal/calles/.

   Cómo está guardada una sesión (tabla `sesiones`, columna `bloques` jsonb):

     [ { etiqueta:'Calentamiento', matiz:'Todos', filas:[…] },          ← común
       { etiqueta:'Calle 1', calle:1, matiz:'Rápidos', atletas:[uuid…],
         filas:[ { ejercicio, series, distancia, ritmo, descanso,
                   material:[…], observaciones } … ] },                 ← calle
       …
       { etiqueta:'Vuelta a la calma', filas:[…] } ]                    ← común

   El bloque que lleva `calle` es de esa calle y solo la nada quien esté en su
   lista de `atletas`. Los que no llevan `calle` son de todo el grupo. Así sale
   el modelo del diseñador: una sesión con la misma estructura, y cada calle
   sobrescribiendo lo suyo — metros, repeticiones, salida y notas.

   ---------------------------------------------------------------------------
   DESCANSOS · hueco reservado
   ---------------------------------------------------------------------------
   El modelo de recuperación de las cinco disciplinas vive en
   `assets/js/descansos.js`, que lo está montando otra persona. Este archivo NO
   lo duplica: si `window.APOLANA_DESCANSOS` existe, le pregunta a él; si no,
   usa el mínimo imprescindible para no dejar la pantalla coja (los dos modos de
   natación). En cuanto `descansos.js` esté, se borra `reserva()` y ya está.
   ============================================================================ */
(function () {
  'use strict';
  if (window.APOLANA_CALLES) return;

  /* ---------- números y unidades ----------------------------------------- */

  /* Metros de un texto: «25 m» → 25 · «1.500 m» → 1500 · «1 km» → 1000 */
  function metros(txt) {
    var t = String(txt == null ? '' : txt).trim();
    if (!t) return 0;
    var m = t.match(/(\d[\d.\s]*(?:,\d+)?)\s*(km|k|m)?\b/i);
    if (!m) return 0;
    var n = parseFloat(m[1].replace(/[.\s]/g, '').replace(',', '.'));
    if (isNaN(n)) return 0;
    return /^k/i.test(m[2] || '') ? Math.round(n * 1000) : Math.round(n);
  }

  /* Repeticiones de una fila. Sin número, es una sola vez. */
  function repeticiones(f) {
    var n = parseInt((f && f.series) != null ? f.series : '', 10);
    return (n > 0 && n <= 200) ? n : 1;
  }

  /* Segundos de un texto de tiempo: 1'40" · 1:40 · «1 min» · «45 s» · «90» */
  function segundos(txt) {
    var t = String(txt == null ? '' : txt).trim();
    if (!t) return null;
    var m = t.match(/^(\d+)\s*['´:]\s*(\d{1,2})?/);
    if (m) return (+m[1]) * 60 + (+(m[2] || 0));
    var seg = 0, hay = false;
    var mm = t.match(/(\d+(?:[.,]\d+)?)\s*(?:minutos|minuto|min|mn)\b/i);
    if (mm) { seg += parseFloat(mm[1].replace(',', '.')) * 60; hay = true; }
    var ss = t.match(/(\d+)\s*(?:segundos|segundo|seg|s)\b/i);
    if (ss) { seg += parseInt(ss[1], 10); hay = true; }
    if (!hay) { var solo = t.match(/^(\d+)$/); if (solo) { seg = +solo[1]; hay = true; } }
    return hay ? Math.round(seg) : null;
  }

  /* Cómo se escribe un tiempo de natación: 20" · 1'00" · 1'40" */
  function reloj(seg) {
    if (seg == null || isNaN(seg)) return '';
    seg = Math.round(seg);
    if (seg < 60) return seg + '"';
    var m = Math.floor(seg / 60), s = seg % 60;
    return m + "'" + (s < 10 ? '0' : '') + s + '"';
  }

  /* Volumen: siempre en metros, nunca en kilómetros (regla del diseñador) */
  function volumen(m) {
    m = Math.round(m || 0);
    return String(m).replace(/\B(?=(\d{3})+(?!\d))/g, '.') + ' m';
  }

  /* ---------- descansos · dos modos, y se distinguen por color ------------ */

  /* El mínimo de natación mientras no esté `descansos.js`. Se borra entonces. */
  var RESERVA = {
    salida: { clave: 'salida', etiqueta: 'salida', color: '#2F6FA8', nota: 'nadar y descansar dentro' },
    fijo:   { clave: 'fijo',   etiqueta: 'descanso', color: '#6B5B8A', nota: 'al tocar la pared' }
  };

  function modoDe(f) {
    var m = f && (f.descanso_modo || f.modo_descanso);
    if (m === 'salida' || m === 'fijo') return m;
    /* Sin campo guardado se deduce del texto: «salida cada 1'10"» es salida.
       Lo demás es descanso al tocar pared, que es como se escribía antes. */
    return /salida|sale\b|cada\b/i.test(String((f && f.descanso) || '')) ? 'salida' : 'fijo';
  }

  function reserva(f) {
    var txt = f && f.descanso;
    /* Nunca un campo vacío: si no hay descanso, no hay nada que pintar */
    if (txt == null || !String(txt).trim()) return null;
    var modo = modoDe(f), seg = segundos(txt), base = RESERVA[modo];
    return {
      modo: modo,
      etiqueta: base.etiqueta,
      color: base.color,
      nota: base.nota,
      valor: seg != null ? (modo === 'salida' ? 'cada ' + reloj(seg) : 'fijo ' + reloj(seg))
                         : String(txt).trim(),
      segundos: seg
    };
  }

  /* Punto único de entrada. Cuando `descansos.js` esté, manda él. */
  function descanso(f) {
    var motor = window.APOLANA_DESCANSOS;
    if (motor) {
      var fn = motor.natacion || motor.leer || motor.de;
      if (typeof fn === 'function') {
        try { return fn.call(motor, f, 'natacion') || null; } catch (e) { /* sigue la reserva */ }
      }
    }
    return reserva(f);
  }

  /* Descanso entre este bloque y el anterior, si está escrito */
  function descansoPrevio(b) {
    var t = b && (b.descanso_previo || b.descanso_antes);
    if (t == null || !String(t).trim()) return null;
    var seg = segundos(t);
    return seg != null ? reloj(seg) + ' entre bloques' : String(t).trim() + ' entre bloques';
  }

  /* ---------- leer la sesión --------------------------------------------- */

  /* Parte los bloques en «de todos» y «de una calle», conservando la posición
     original: el orden del vaso importa (calentamiento, técnica, principal…). */
  function separar(bloques) {
    var comunes = [], calles = [];
    (Array.isArray(bloques) ? bloques : []).forEach(function (b, i) {
      if (!b || typeof b !== 'object') return;
      var n = parseInt(b.calle, 10);
      if (n > 0) calles.push({ n: n, idx: i, b: b });
      else comunes.push({ n: 0, idx: i, b: b });
    });
    calles.sort(function (a, c) { return a.n - c.n; });
    return { comunes: comunes, calles: calles };
  }

  /* La sesión que ve una calle: lo común más lo suyo, en el orden del vaso.
     Cada pieza dice si es propia de la calle o de todo el grupo. */
  function secuencia(sep, calleN) {
    var mia = null;
    sep.calles.forEach(function (c) { if (c.n === calleN) mia = c; });
    var lista = sep.comunes.map(function (c) { return { idx: c.idx, b: c.b, propio: false }; });
    if (mia) lista.push({ idx: mia.idx, b: mia.b, propio: true });
    lista.sort(function (a, c) { return a.idx - c.idx; });
    return lista;
  }

  function metrosFila(f) {
    if (!f) return 0;
    var d = metros(f.distancia);
    if (!d) return 0;
    return d * repeticiones(f);
  }

  function metrosBloque(b) {
    var t = 0;
    ((b && b.filas) || []).forEach(function (f) { t += metrosFila(f); });
    return t;
  }

  function metrosSecuencia(lista) {
    var t = 0;
    (lista || []).forEach(function (x) { t += metrosBloque(x.b); });
    return t;
  }

  /* Duración estimada. Con la recuperación puesta ya se puede calcular, que es
     justo lo que pedía el diseñador: la familia planifica con el tiempo, no con
     los metros. Dos casos:
       · salida cada X  → el bloque dura repeticiones × salida, exacto
       · descanso fijo  → nado + descansos, con un ritmo de referencia
     RITMO_BASE es una referencia de club (1'50" cada 100 m) y por eso el
     resultado se enseña siempre con «~». */
  var RITMO_BASE = 110; /* segundos por 100 m */

  function segundosBloque(b) {
    var t = 0;
    ((b && b.filas) || []).forEach(function (f) {
      var n = repeticiones(f), d = metros(f.distancia), r = descanso(f);
      var salida = (r && r.modo === 'salida') ? r.segundos : null;
      if (salida) { t += n * salida; return; }
      t += (d * n / 100) * RITMO_BASE;
      if (r && r.segundos) t += Math.max(0, n - 1) * r.segundos;
    });
    var prev = b && (b.descanso_previo || b.descanso_antes);
    if (prev) t += (segundos(prev) || 0);
    return t;
  }

  function duracion(lista) {
    var t = 0;
    (lista || []).forEach(function (x) { t += segundosBloque(x.b); });
    if (t <= 0) return '';
    var min = Math.round(t / 60 / 5) * 5;
    if (min < 5) min = 5;
    return '~' + min + "'";
  }

  /* ---------- cómo se lee una fila --------------------------------------- */

  /* La cifra que se compara en columna: «8 × 50» · «400» */
  function cifra(f) {
    if (!f) return '';
    var n = repeticiones(f), d = String((f.distancia == null ? '' : f.distancia)).trim().replace(/\s*m$/i, '');
    if (!d) return n > 1 ? n + ' series' : '';
    return n > 1 ? (n + ' × ' + d) : d;
  }

  /* Todo lo que acompaña a la cifra y se lee como frase */
  function detalle(f) {
    var p = [];
    if (f && f.ejercicio) p.push(String(f.ejercicio).trim());
    if (f && f.ritmo) p.push('ritmo ' + String(f.ritmo).trim());
    return p.join(' · ');
  }

  /* ---------- gente ------------------------------------------------------- */

  function iniciales(nombre, apellidos) {
    var a = String(nombre || '').trim(), b = String(apellidos || '').trim();
    var x = a ? a[0] : '', y = b ? b[0] : (a.split(' ')[1] ? a.split(' ')[1][0] : '');
    return (x + (y || '')).toUpperCase() || '·';
  }

  /* La calle es un nivel: del más suave al más fuerte, de claro a navy. */
  var RAMPA = ['#8FC0E8', '#6FAEDD', '#5FA0D3', '#3B85C0', '#2F6FA8', '#2A5F91', '#26527C', '#2E4256'];
  function colorNivel(i, total) {
    total = total || 4;
    if (total <= 1) return RAMPA[3];
    var p = Math.round(i * (RAMPA.length - 1) / (total - 1));
    return RAMPA[Math.max(0, Math.min(RAMPA.length - 1, p))];
  }

  /* ---------- estado de los bloques (hecho / en curso / pendiente) --------
     Todavía no hay dónde guardarlo en la base, así que vive en este móvil.
     Está pendiente una columna en `sesiones` para que lo vean los dos
     entrenadores de la misma sesión: se dice en el resumen del encargo. */
  function claveProgreso(sesionId, calleN) {
    return 'apolana.calles.' + sesionId + '.c' + calleN;
  }
  function leerProgreso(sesionId, calleN) {
    try {
      var v = window.localStorage.getItem(claveProgreso(sesionId, calleN));
      var n = v == null ? 0 : parseInt(v, 10);
      return (n > 0) ? n : 0;
    } catch (e) { return 0; }
  }
  function guardarProgreso(sesionId, calleN, hechos) {
    try { window.localStorage.setItem(claveProgreso(sesionId, calleN), String(hechos || 0)); } catch (e) {}
  }

  window.APOLANA_CALLES = {
    metros: metros, repeticiones: repeticiones, segundos: segundos, reloj: reloj, volumen: volumen,
    descanso: descanso, descansoPrevio: descansoPrevio, modoDe: modoDe,
    separar: separar, secuencia: secuencia,
    metrosFila: metrosFila, metrosBloque: metrosBloque, metrosSecuencia: metrosSecuencia,
    duracion: duracion, cifra: cifra, detalle: detalle,
    iniciales: iniciales, colorNivel: colorNivel,
    leerProgreso: leerProgreso, guardarProgreso: guardarProgreso
  };
})();
