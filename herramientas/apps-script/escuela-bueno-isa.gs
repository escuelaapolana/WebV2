/**
 * Club Atletismo Apolana · Comprobación diaria de «BUENO ISA» (escuela)
 * ---------------------------------------------------------------------
 * Cada día a las 9:00 y a las 12:30 lee las hojas de Isa (con los COLORES de cada fila)
 * (mig 448, 27-oct: en la inscripción, ALTA = la fila ENTERA en verde; solo el nombre en
 *  verde = sigue de PRUEBA. Por eso manda también «completa», mirando toda la fila.)
 * y las manda a la app (Edge `escuela-isa-sync`, migración 402), que:
 *   · quita «de prueba» a quien está en verde,
 *   · da de baja (y saca de sus grupos) a quien está en rojo,
 *   · crea la ficha de los nuevos (sin grupo),
 *   · y manda un correo a Andrés si ha cambiado algo.
 *
 * INSTALAR (una vez, con la cuenta escuelaapolana@gmail.com):
 *   1. https://script.google.com → «Nuevo proyecto» → pegar este código.
 *   2. Poner el TOKEN (te lo pasa Andrés/Claude; NO se sube a ningún sitio).
 *   3. Elegir la función «instalar» y pulsar ▶ Ejecutar. Aceptar los permisos.
 *   4. (Opcional) Ejecutar «probarSinAplicar» y mirar el registro.
 * Las columnas se buscan por su TÍTULO, así que se pueden añadir columnas.
 */
var URL = 'https://icaxokjsvhlreuwpyxeb.supabase.co/functions/v1/escuela-isa-sync';
var TOKEN = 'PEGA_AQUI_EL_TOKEN';

var HOJAS = [
  { id: '1f2ARh3fNxOgp_ZoUWVGj2ylj3RDku8nzGlss3zCrDyc', pestana: 'BUENO ISA', hoja: 'inscripcion' },                 // Inscripción 2026/27
  { id: '1C1PotZLYTA38UeXBz_exXsX_V2L3MTCJ_4xeFZuXLRw', pestana: 'BUENA ISA', hoja: 'renovacion' },                  // Renovación 2026/27
  { id: '16J-EiXvy0qfPmXSZBV1JP2zN0OBnC7_HGm_ZW4t6BRs', pestana: 'BUENA ISA', hoja: 'municipal' },                  // Municipales atletismo
  { id: '16J-EiXvy0qfPmXSZBV1JP2zN0OBnC7_HGm_ZW4t6BRs', pestana: 'Respuestas de formulario 1', hoja: 'municipal_baja' }
];

var COLUMNAS = {
  nombre: /^nombre alumno/, ap1: /^primer apellido/, ap2: /^segundo apellido/, nacimiento: /^fecha de nacimiento/,
  turno: /^turno/, sexo: /^sexo/, dni: /^dni alumno/, tutor: /^datos del padre/, telefono: /^telefono/,
  email: /^direccion de correo/, dir: /^direccion$/, cp: /^codigo postal/, localidad: /^localidad/, obs: /^observaciones/
};

var VERDES = ['#d9ead3', '#93c47d', '#b6d7a8'];
var ROJAS = ['#f4cccc', '#e06666', '#ea9999', '#cc0000'];

function norm_(s) { return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ').trim(); }
function txt_(v) {
  if (v === null || v === undefined || v === '') return null;
  if (Object.prototype.toString.call(v) === '[object Date]') return Utilities.formatDate(v, 'Europe/Madrid', 'yyyy-MM-dd');
  if (typeof v === 'number' && Math.floor(v) === v) return String(v);
  return String(v).trim() || null;
}

function leerFilas_() {
  var filas = [];
  HOJAS.forEach(function (h) {
    var hoja = SpreadsheetApp.openById(h.id).getSheetByName(h.pestana);
    if (!hoja) throw new Error('No encuentro la pestaña «' + h.pestana + '» (' + h.hoja + ')');
    var rango = hoja.getDataRange();
    var valores = rango.getValues(), fondos = rango.getBackgrounds();
    var cab = valores[0].map(norm_), col = {};
    // Ancho de la tabla: hasta la última columna con título (para mirar la fila ENTERA).
    var ancho = 0; for (var k = 0; k < cab.length; k++) if (cab[k]) ancho = k + 1;
    Object.keys(COLUMNAS).forEach(function (k) {
      for (var i = 0; i < cab.length; i++) if (COLUMNAS[k].test(cab[i])) { col[k] = i; break; }
    });
    for (var f = 1; f < valores.length; f++) {
      var v = valores[f];
      var g = function (k) { return col[k] === undefined ? null : txt_(v[col[k]]); };
      if (!g('nombre') && !g('ap1')) continue;
      var colores = fondos[f].slice(0, 12).filter(function (c) { return c && c.toLowerCase() !== '#ffffff'; });
      // (mig 448) Cómo está la fila ENTERA: alta = toda en verde; baja = toda en rojo;
      // con solo unas celdas pintadas (p. ej. el nombre) sigue de prueba.
      var fila = fondos[f].slice(0, ancho).map(function (c) { return String(c || '').toLowerCase(); });
      var pintadas = fila.filter(function (c) { return c && c !== '#ffffff'; }).length;
      var verdes = fila.filter(function (c) { return VERDES.indexOf(c) !== -1; }).length;
      var rojas = fila.filter(function (c) { return ROJAS.indexOf(c) !== -1; }).length;
      var completa = rojas > 0 && rojas >= ancho - 3 ? 'rojo'
        : pintadas === ancho ? (verdes * 2 >= ancho ? 'verde' : 'otro')
        : pintadas > 0 ? 'parcial' : 'nada';
      filas.push({
        hoja: h.hoja, fila: f + 1, nombre: g('nombre'), ap1: g('ap1'), ap2: g('ap2'), nacimiento: g('nacimiento'),
        colores: colores, turno: g('turno'), sexo: g('sexo'), dni: g('dni'), tutor: g('tutor'), telefono: g('telefono'),
        email: g('email'), direccion: [g('dir'), g('cp'), g('localidad')].filter(String).join(', ') || null, obs: g('obs'),
        completa: completa
      });
    }
  });
  return filas;
}

function enviar_(aplicar) {
  var filas = leerFilas_();
  var r = UrlFetchApp.fetch(URL, {
    method: 'post', contentType: 'application/json', muteHttpExceptions: true,
    headers: { 'x-sync-token': TOKEN },
    payload: JSON.stringify({ filas: filas, aplicar: aplicar })
  });
  Logger.log('Filas enviadas: ' + filas.length + ' · respuesta ' + r.getResponseCode() + ': ' + r.getContentText().slice(0, 2000));
  if (r.getResponseCode() !== 200) throw new Error('La app respondió ' + r.getResponseCode() + ': ' + r.getContentText().slice(0, 300));
}

/** La que corre cada día a las 12:30. */
function comprobarEscuela() { enviar_(true); }

/** Para probar: lee y manda, pero la app NO cambia nada (sí puede llegar el correo con lo que haría). */
function probarSinAplicar() { enviar_(false); }

/** Ejecutar UNA vez: deja programada la comprobación diaria a las 9:00 y a las 12:30 (hora de Madrid).
 *  Se puede volver a ejecutar sin miedo: borra las programaciones anteriores y las pone de nuevo. */
function instalar() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'comprobarEscuela') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('comprobarEscuela').timeBased().everyDays(1).atHour(9).nearMinute(0).inTimezone('Europe/Madrid').create();
  ScriptApp.newTrigger('comprobarEscuela').timeBased().everyDays(1).atHour(12).nearMinute(30).inTimezone('Europe/Madrid').create();
  leerFilas_();   // para que pida los permisos ahora y avise si falta alguna pestaña
  Logger.log('Listo: cada día sobre las 9:00 y las 12:30.');
}
