/**
 * Club Atletismo Apolana · Solicitudes de natación (formularios de escuela y máster)
 * ---------------------------------------------------------------------------------
 * Cada día a las 9:00 lee los Excel de RESPUESTAS de los dos formularios de natación
 * y los manda a la app (Edge `natacion-form-sync`, migración 475), que:
 *   · guarda cada respuesta nueva UNA vez (las que ya había el primer día quedan
 *     como «anteriores» y no se tocan),
 *   · si el grupo que pide tiene hueco, le da de alta DE PRUEBA en esa franja,
 *   · si está completo o falta algún dato, lo deja «por revisar»,
 *   · y le manda a Andrés un correo con lo que haya que mirar.
 * Todo se lleva en Natación › Solicitudes (portal/natacion-solicitudes).
 *
 * INSTALAR (una vez, con la cuenta escuelaapolana@gmail.com):
 *   0. Los dos Excel tienen que estar compartidos con escuelaapolana@gmail.com
 *      (basta «Lector»).
 *   1. https://script.google.com → el proyecto de BUENO ISA → «+» → «Secuencia de
 *      comandos» → llámalo «natacion» → pega este código. (También vale un proyecto
 *      nuevo: los nombres no chocan con los de BUENO ISA.)
 *   2. Pon en NAT_HOJAS el enlace de cada Excel y en NAT_TOKEN el MISMO token que
 *      el script de BUENO ISA (NO se sube a ningún sitio).
 *   3. Elige la función «instalarNatacion» y pulsa ▶ Ejecutar. Acepta los permisos.
 *   4. (Opcional) Ejecuta «probarNatacion»: lo hace todo y lo deshace; mira el registro.
 * Las columnas se buscan en la app por su TÍTULO, así que se pueden añadir preguntas.
 */
var NAT_URL = 'https://icaxokjsvhlreuwpyxeb.supabase.co/functions/v1/natacion-form-sync';
var NAT_TOKEN = 'PEGA_AQUI_EL_TOKEN';

var NAT_HOJAS = [
  { origen: 'Escuela', excel: 'PEGA_AQUI_EL_ENLACE_DEL_EXCEL_DE_LA_ESCUELA' },   // pestaña: la primera (o pon pestana: '…')
  { origen: 'Máster',  excel: 'PEGA_AQUI_EL_ENLACE_DEL_EXCEL_DEL_MASTER' }
];

function natId_(s) {
  var m = String(s || '').match(/\/d\/([a-zA-Z0-9_-]{20,})/);
  return m ? m[1] : String(s || '').trim();
}

function natTxt_(v, zona) {
  if (v === null || v === undefined || v === '') return '';
  if (Object.prototype.toString.call(v) === '[object Date]') {
    var conHora = Utilities.formatDate(v, zona, 'HH:mm:ss') !== '00:00:00';
    return Utilities.formatDate(v, zona, conHora ? 'yyyy-MM-dd HH:mm:ss' : 'yyyy-MM-dd');
  }
  if (typeof v === 'number' && Math.floor(v) === v) return String(v);
  return String(v).trim();
}

function natLeer_() {
  var filas = [];
  NAT_HOJAS.forEach(function (h) {
    if (/PEGA_AQUI/.test(h.excel)) throw new Error('Falta el enlace del Excel de ' + h.origen + ' en NAT_HOJAS.');
    var libro = SpreadsheetApp.openById(natId_(h.excel));
    var zona = libro.getSpreadsheetTimeZone() || 'Europe/Madrid';
    var hoja = h.pestana ? libro.getSheetByName(h.pestana) : libro.getSheets()[0];
    if (!hoja) throw new Error('No encuentro la pestaña «' + h.pestana + '» del Excel de ' + h.origen);
    var valores = hoja.getDataRange().getValues();
    if (!valores.length) return;
    var cab = valores[0].map(function (t) { return String(t || '').trim(); });
    for (var f = 1; f < valores.length; f++) {
      var datos = [];
      for (var c = 0; c < cab.length; c++) {
        if (!cab[c]) continue;
        var t = natTxt_(valores[f][c], zona);
        if (t !== '') datos.push([cab[c], t]);
      }
      if (datos.length) filas.push({ origen: h.origen, fila: f + 1, datos: datos });
    }
  });
  return filas;
}

function natEnviar_(aplicar) {
  var filas = natLeer_();
  var r = UrlFetchApp.fetch(NAT_URL, {
    method: 'post', contentType: 'application/json', muteHttpExceptions: true,
    headers: { 'x-sync-token': NAT_TOKEN },
    payload: JSON.stringify({ filas: filas, aplicar: aplicar })
  });
  Logger.log('Filas enviadas: ' + filas.length + ' · respuesta ' + r.getResponseCode() + ': ' + r.getContentText().slice(0, 3000));
  if (r.getResponseCode() !== 200) throw new Error('La app respondió ' + r.getResponseCode() + ': ' + r.getContentText().slice(0, 300));
}

/** La que corre cada día a las 9:00. */
function comprobarNatacion() { natEnviar_(true); }

/** Para probar: la app lo hace todo y lo deshace (no da altas ni manda correo). */
function probarNatacion() { natEnviar_(false); }

/** Ejecutar UNA vez: deja programada la lectura diaria a las 9:00 (hora de Madrid).
 *  Se puede volver a ejecutar sin miedo: borra la programación anterior y la pone de nuevo. */
function instalarNatacion() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'comprobarNatacion') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('comprobarNatacion').timeBased().everyDays(1).atHour(9).nearMinute(0).inTimezone('Europe/Madrid').create();
  natLeer_();   // para que pida los permisos ahora y avise si falta algún Excel
  Logger.log('Listo: cada día sobre las 9:00.');
}
