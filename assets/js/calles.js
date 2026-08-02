/* ============================================================================
   CALLES DE NATACIÓN · el modelo, sin pantalla
   ----------------------------------------------------------------------------
   Aquí vive lo que hay que saber para leer una sesión de natación repartida por
   calles, y nada más: ni HTML, ni base de datos. Lo usa /portal/calles/.

   Cómo está guardada una sesión (tabla `sesiones`, columna `bloques` jsonb):

     [ { etiqueta:'Calentamiento', matiz:'Todos', filas:[…] },          ← común
       { etiqueta:'Calle 1', calle:1, matiz:'Rápidos', atletas:[uuid…],
         filas:[ { ejercicio, series, distancia, ritmo, rec, material,
                   observaciones } … ] },                              ← calle
       …
       { etiqueta:'Vuelta a la calma', filas:[…] } ]                    ← común

   El bloque que lleva `calle` es de esa calle y solo la nada quien esté en su
   lista de `atletas`. Los que no llevan `calle` son de todo el grupo. Así sale
   el modelo del diseñador: una sesión con la misma estructura, y cada calle
   sobrescribiendo lo suyo — metros, repeticiones, salida y notas.

   ---------------------------------------------------------------------------
   LOS DESCANSOS NO SE TOCAN AQUÍ
   ---------------------------------------------------------------------------
   El modelo de recuperación de las cinco disciplinas vive en
   `assets/js/descansos.js` y es el único que manda: cómo se lee, cómo se
   escribe, de qué color va la etiqueta de natación y cuánto dura la sesión.
   Este archivo no repite nada de eso — le pregunta. Si algún día no estuviera
   cargado, la pantalla se queda sin descansos y sin duración estimada, pero no
   se inventa otro modelo paralelo: dos modelos distintos serían peor que
   ninguno.
   ============================================================================ */
(function () {
  'use strict';
  if (window.APOLANA_CALLES) return;

  var DIS = 'natacion';
  function D() { return window.APOLANA_DESCANSOS || null; }

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

  /* ---------- metros ------------------------------------------------------ */

  function repeticiones(f) {
    var n = parseInt((f && f.series) != null ? f.series : '', 10);
    return (n > 0 && n <= 200) ? n : 1;
  }

  function metrosBloque(b) {
    var d = D();
    if (d && d.estimarBloque) {
      var e = d.estimarBloque(b, DIS, {});
      return (e && e.metros) || 0;
    }
    return 0;
  }

  function metrosSecuencia(lista) {
    var t = 0;
    (lista || []).forEach(function (x) { t += metrosBloque(x.b); });
    return t;
  }

  function volumen(m) {
    var d = D();
    return (d && d.fmtMetros) ? d.fmtMetros(m) : (m > 0 ? m + ' m' : '');
  }

  /* ---------- descansos · todo viene de descansos.js ---------------------- */

  /* Los dos modos de natación con su etiqueta de color, o null si ese
     ejercicio no lleva recuperación: nunca un campo vacío. */
  function etiqueta(f) {
    var d = D();
    if (!d || !d.etiquetaNatacion) return null;
    var rec = d.recDeFila ? d.recDeFila(f, DIS) : null;
    return rec ? d.etiquetaNatacion(rec) : null;
  }

  function modoDe(f) {
    var d = D();
    var rec = (d && d.recDeFila) ? d.recDeFila(f, DIS) : null;
    return (rec && rec.modo === 'salida') ? 'salida' : (rec ? 'fijo' : 'salida');
  }

  /* El separador que va DESPUÉS de un bloque, si lleva descanso escrito */
  function entreBloques(b) {
    var d = D();
    return (d && d.textoEntreBloques) ? d.textoEntreBloques(b) : '';
  }

  /* ---------- volumen y tiempo de una calle, separados -------------------- */

  /* Con la recuperación puesta ya se puede calcular la duración. Si el
     entrenador puso la duración a mano, esa manda y no lleva «~». */
  function resumenCalle(sesion, calleN) {
    var d = D();
    if (!d || !d.resumen) return { volumen: '', tiempo: '' };
    return d.resumen(sesion, { disciplina: DIS, calle: calleN });
  }

  /* ---------- cómo se lee una fila --------------------------------------- */

  /* La cifra que se compara en columna: «8 × 50» · «400 m» */
  function cifra(f) {
    var d = D();
    if (d && d.textoSerie) return d.textoSerie(f, DIS);
    if (!f) return '';
    var n = repeticiones(f), dist = String(f.distancia == null ? '' : f.distancia).trim();
    if (!dist) return n > 1 ? n + ' series' : '';
    return n > 1 ? (n + ' × ' + dist) : dist;
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
  function clave(sesionId, calleN) { return 'apolana.calles.' + sesionId + '.c' + calleN; }
  function leerProgreso(sesionId, calleN) {
    try {
      var v = window.localStorage.getItem(clave(sesionId, calleN));
      var n = v == null ? 0 : parseInt(v, 10);
      return (n > 0) ? n : 0;
    } catch (e) { return 0; }
  }
  function guardarProgreso(sesionId, calleN, hechos) {
    try { window.localStorage.setItem(clave(sesionId, calleN), String(hechos || 0)); } catch (e) {}
  }

  window.APOLANA_CALLES = {
    DISCIPLINA: DIS,
    separar: separar, secuencia: secuencia,
    repeticiones: repeticiones, metrosBloque: metrosBloque, metrosSecuencia: metrosSecuencia,
    volumen: volumen, resumenCalle: resumenCalle,
    etiqueta: etiqueta, modoDe: modoDe, entreBloques: entreBloques,
    cifra: cifra, detalle: detalle,
    iniciales: iniciales, colorNivel: colorNivel,
    leerProgreso: leerProgreso, guardarProgreso: guardarProgreso
  };
})();
