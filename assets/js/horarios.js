/* ============================================================
   LA SEMANA FIJA DEL CLUB · la parrilla de horarios
   ------------------------------------------------------------
   QUÉ HACE
   Lee `grupos.horario`, que el club escribe a mano y en cristiano
   («Lunes y miércoles 17:30-18:30 · Estadio Joaquín Villar»), lo
   interpreta y lo coloca en una parrilla de lunes a domingo.

   POR QUÉ VIVE AQUÍ Y NO DENTRO DE UNA PÁGINA
   Porque ahora la usan dos: /calendario/, en su pestaña «Horarios», y
   /horarios/, que se queda solo como puerta de entrada para los enlaces
   de siempre. Duplicar cuatrocientas líneas en dos archivos es garantía
   de que un día se arregla en uno y no en el otro.

   ARRANQUE
   No arranca sola: espera a que la llamen con
   `window.APOLANA_HORARIOS.pintar()`. En el calendario la parrilla
   empieza escondida y no tiene sentido calcularla hasta que alguien
   pulsa su pestaña; en /horarios/ se llama al cargar. Solo se pinta una
   vez, aunque se llame varias.
   ============================================================ */
(function () {
  'use strict';

  /* ---------- Días y meses ---------- */
  var DIAS_LARGO = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  var DIAS_CORTO = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  var MESES_CORTO = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  /* ---------- Secciones: etiqueta del chip y color del borde ----------
     El color es el del sistema visual: sutil, solo en el borde izquierdo,
     para poder escanear la semana de un vistazo. */
  /* `juntos` es el nombre que se pone cuando varios grupos de la misma
     sección coinciden en día, hora y sitio y se pintan en una sola
     tarjeta (ver `juntarIguales`). Se escribe entero y a mano en vez de
     fabricarlo con la etiqueta en minúsculas, porque cada uno lleva su
     artículo: sale «de LA escuela» y «de EL Cubo», no «de escuela» ni
     «de el cubo». */
  var SECCIONES = [
    { clave: 'escuela',     etiqueta: 'Escuela',         juntos: 'Entrenamientos de la escuela', color: '#7A9450', incluye: ['escuela', 'escuela-natacion', 'escuela_natacion'] },
    { clave: 'competicion', etiqueta: 'Atletismo pista', juntos: 'Entrenamientos de pista',      color: '#2F6FA8', incluye: ['competicion', 'pista'] },
    { clave: 'running',     etiqueta: 'Running',         juntos: 'Entrenamientos de running',    color: '#B96F09', incluye: ['running'] },
    { clave: 'natacion',    etiqueta: 'Natación',        juntos: 'Entrenamientos de natación',   color: '#4A8FA8', incluye: ['natacion'] },
    { clave: 'triatlon',    etiqueta: 'Triatlón',        juntos: 'Entrenamientos de triatlón',   color: '#9A5F7E', incluye: ['triatlon'] },
    { clave: 'montana',     etiqueta: 'Montaña',         juntos: 'Salidas de montaña',           color: '#8A6A4A', incluye: ['montana', 'montaña'] },
    { clave: 'cubo',        etiqueta: 'El Cubo',         juntos: 'Clases de El Cubo',            color: '#6B5B8A', incluye: ['cubo'] }
  ];
  var OTRA = { clave: 'otras', etiqueta: 'Otros', juntos: 'Varios entrenamientos', color: '#A79F8E' };

  function familiaDe(seccion) {
    var s = sinTildes(String(seccion || '').toLowerCase().trim());
    for (var i = 0; i < SECCIONES.length; i++) {
      for (var j = 0; j < SECCIONES[i].incluye.length; j++) {
        if (sinTildes(SECCIONES[i].incluye[j]) === s) return SECCIONES[i];
      }
    }
    return OTRA;
  }

  /* ---------- Utilidades de texto ---------- */
  /* Quita tildes SIN cambiar la longitud, para poder buscar días y horas
     en el texto normalizado y seguir recortando el texto original. */
  var MAPA_TILDES = { 'á':'a','à':'a','ä':'a','â':'a','é':'e','è':'e','ë':'e','ê':'e','í':'i','ì':'i','ï':'i','î':'i','ó':'o','ò':'o','ö':'o','ô':'o','ú':'u','ù':'u','ü':'u','û':'u','ñ':'n','ç':'c' };
  function sinTildes(s) {
    return String(s == null ? '' : s).replace(/[áàäâéèëêíìïîóòöôúùüûñç]/g, function (c) { return MAPA_TILDES[c] || c; });
  }
  function esc(s) { var d = document.createElement('div'); d.textContent = (s == null ? '' : String(s)); return d.innerHTML; }
  function escAttr(s) { return esc(s).replace(/"/g, '&quot;'); }
  function limpio(s) { return String(s == null ? '' : s).replace(/\s+/g, ' ').trim(); }

  /* ---------- Interpretación del campo "horario" ---------- */
  var DIA_RE = 'lunes|martes|miercoles|jueves|viernes|sabados?|domingos?';
  var TOKEN_RE = new RegExp(
    '\\bde\\s+(' + DIA_RE + ')\\s+a\\s+(' + DIA_RE + ')\\b' +            // 1,2 · "de lunes a viernes"
    '|\\b(' + DIA_RE + '|lun|mar|mie|jue|vie|sab|dom)\\b' +              // 3   · un día suelto
    '|(\\d{1,2}[:.]\\d{2})\\s*(?:[-–—]|a)\\s*(\\d{1,2}[:.]\\d{2})' + // 4,5 · franja
    '|(\\d{1,2}[:.]\\d{2})',                                            // 6   · hora suelta
    'gi');

  function indiceDia(token) {
    var t = sinTildes(String(token).toLowerCase()).slice(0, 3);
    var m = { lun: 0, mar: 1, mie: 2, jue: 3, vie: 4, sab: 5, dom: 6 };
    return (m[t] === undefined) ? -1 : m[t];
  }
  function hora(h) {
    var p = String(h).replace('.', ':').split(':');
    var hh = parseInt(p[0], 10), mm = p[1];
    if (isNaN(hh) || hh > 23) return null;
    return (hh < 10 ? '0' : '') + hh + ':' + mm;
  }
  function minutos(h) { var p = String(h).split(':'); return (+p[0]) * 60 + (+p[1]); }

  /* Separa el texto en "cuándo" (antes del ·) e "instalación" (después).
     Si la instalación acaba en un paréntesis ("Piscina cubierta (controles
     en sábado)"), ese matiz se guarda aparte para pintarlo en su línea. */
  function partirHorario(texto) {
    var partes = String(texto).split('·');
    if (partes.length === 1) return { cuando: partes[0], lugar: '', matiz: '' };
    var lugar = limpio(partes.slice(1).join(' · '));
    var matiz = '';
    var m = /^(.*?)\s*\(([^)]*)\)\s*$/.exec(lugar);
    if (m && limpio(m[1])) { lugar = limpio(m[1]); matiz = limpio(m[2]); }
    return { cuando: partes[0], lugar: lugar, matiz: matiz };
  }

  /* Saca "(lo que va entre paréntesis)" del principio de un trozo de texto. */
  function notaDe(trozo) {
    var m = /^[^()]*\(([^)]*)\)/.exec(trozo || '');
    return m ? limpio(m[1]) : '';
  }

  /* Devuelve una lista de franjas { dias:[0..6], inicio, fin, nota }.
     Si no consigue sacar ninguna, devuelve [] y el grupo baja a "Otros". */
  function interpretar(texto) {
    var p = partirHorario(texto);
    var original = p.cuando;
    var plano = sinTildes(original.toLowerCase());

    var tokens = [], m;
    TOKEN_RE.lastIndex = 0;
    while ((m = TOKEN_RE.exec(plano)) !== null) {
      if (m[1] && m[2]) {
        var a = indiceDia(m[1]), b = indiceDia(m[2]), dias = [];
        if (a >= 0 && b >= 0) { for (var k = a; ; k = (k + 1) % 7) { dias.push(k); if (k === b) break; if (dias.length > 7) break; } }
        tokens.push({ tipo: 'dias', dias: dias, ini: m.index, fin: m.index + m[0].length });
      } else if (m[3]) {
        var d = indiceDia(m[3]);
        if (d >= 0) tokens.push({ tipo: 'dias', dias: [d], ini: m.index, fin: m.index + m[0].length });
      } else if (m[4] && m[5]) {
        tokens.push({ tipo: 'hora', inicio: hora(m[4]), fin_h: hora(m[5]), ini: m.index, fin: m.index + m[0].length });
      } else if (m[6]) {
        tokens.push({ tipo: 'hora', inicio: hora(m[6]), fin_h: null, ini: m.index, fin: m.index + m[0].length });
      }
    }

    var franjas = [], pendientes = [];
    for (var i = 0; i < tokens.length; i++) {
      var t = tokens[i];
      if (t.tipo === 'dias') { for (var q = 0; q < t.dias.length; q++) if (pendientes.indexOf(t.dias[q]) < 0) pendientes.push(t.dias[q]); continue; }
      if (!t.inicio) { pendientes = []; continue; }
      var hasta = (i + 1 < tokens.length) ? tokens[i + 1].ini : original.length;
      franjas.push({
        dias: pendientes.slice(),
        inicio: t.inicio,
        fin: t.fin_h,
        nota: notaDe(original.slice(t.fin, hasta))
      });
      pendientes = [];
    }

    /* Si quedaron días sueltos y solo hay una franja, son de esa franja. */
    if (pendientes.length && franjas.length === 1) {
      for (var z = 0; z < pendientes.length; z++) if (franjas[0].dias.indexOf(pendientes[z]) < 0) franjas[0].dias.push(pendientes[z]);
    }

    franjas = franjas.filter(function (f) { return f.dias.length > 0; });
    return { franjas: franjas, lugar: p.lugar, matiz: p.matiz };
  }

  /* ---------- Estado de la página ---------- */
  var grupos = [];        // lo que llega de la base
  var entrenos = [];      // { dia, inicio, fin, nombre, lugar, nota, familia, crudo }
  var otros = [];         // grupos cuyo horario no se ha podido colocar
  var filtro = 'todos';

  /* ---------- Fechas ---------- */
  function hoy() { var d = new Date(); d.setHours(0, 0, 0, 0); return d; }
  function lunesDe(fecha) {
    var d = new Date(fecha.getTime());
    d.setDate(d.getDate() - ((d.getDay() + 6) % 7));
    return d;
  }
  /* Siempre la semana en curso. Antes había flechas para ir a la semana
     anterior o a la siguiente, pero el horario es el mismo todas las
     semanas: lo único que cambiaba era el número del día, así que las
     flechas prometían algo que no pasaba. Para una fecha concreta está
     el calendario. */
  function diasDeLaSemana() {
    var l = lunesDe(hoy());
    var out = [];
    for (var i = 0; i < 7; i++) { var d = new Date(l.getTime()); d.setDate(l.getDate() + i); out.push(d); }
    return out;
  }

  /* ---------- Construcción de los datos de la vista ---------- */
  function prepararDatos() {
    entrenos = [];
    otros = [];
    grupos.forEach(function (g) {
      var fam = familiaDe(g.seccion);
      var crudo = limpio(g.horario);
      /* Sin horario escrito, antes solo se decía «por confirmar». Pero de
         los grupos de la escuela sí se sabe una cosa: qué días entrenan,
         porque cada uno existe dos veces (lunes y miércoles, o martes y
         jueves) y eso es justo lo que los separa. Decir los días y que
         falta la hora es más útil, y además evita que aparezcan dos
         líneas idénticas con el mismo nombre. */
      if (!crudo) {
        var dias = window.APOLANA_TURNO ? window.APOLANA_TURNO(g.turno) : '';
        otros.push({
          nombre: g.nombre,
          texto: dias ? (dias.charAt(0).toUpperCase() + dias.slice(1) + ' · hora y sede por confirmar')
                      : 'Horario por confirmar',
          familia: fam
        });
        return;
      }
      var r = interpretar(crudo);
      if (!r.franjas.length) { otros.push({ nombre: g.nombre, texto: crudo, familia: fam }); return; }
      r.franjas.forEach(function (f) {
        f.dias.forEach(function (d) {
          entrenos.push({
            dia: d, inicio: f.inicio, fin: f.fin,
            nombre: g.nombre, lugar: r.lugar, nota: f.nota || r.matiz,
            entrenador: g.entrenador || '', familia: fam, crudo: crudo
          });
        });
      });
    });
  }

  /* ⚠️ NUEVE TARJETAS IDÉNTICAS NO SON NUEVE DATOS, SON UNO.
     La escuela tiene nueve grupos —Azul 1 a 3, Rojo 1 a 3, Verde 1 a 3—
     y los nueve entrenan a la MISMA hora, el MISMO día y en el MISMO
     sitio. La página los pintaba uno debajo de otro: una columna de
     nueve tarjetas que dicen exactamente lo mismo, cuatro veces por
     semana. Para una familia que busca su horario, eso no es más
     información: es tener que leer nueve veces «17:30 – 18:30 · Estadio
     Joaquín Villar» para acabar sabiendo lo que ponía en la primera.

     Así que lo que coincide en día, hora, sitio y sección se junta en
     una tarjeta.

     A PARTIR DE TRES, y no de dos, a propósito: con dos grupos los
     nombres caben y saber cuál es el tuyo importa. Con nueve, el nombre
     deja de ayudar y lo que hace falta es la hora.

     Y se dice CUÁNTOS grupos son, porque esa sí es información que no
     estaba: «la escuela entrena a esta hora, y son nueve grupos». */
  var MINIMO_PARA_JUNTAR = 3;

  function juntarIguales(lista) {
    var cajas = {}, orden = [];
    lista.forEach(function (e) {
      var k = e.familia.clave + '|' + e.inicio + '|' + (e.fin || '') + '|' + (e.lugar || '');
      if (!cajas[k]) { cajas[k] = []; orden.push(k); }
      cajas[k].push(e);
    });
    var out = [];
    orden.forEach(function (k) {
      var g = cajas[k];
      if (g.length < MINIMO_PARA_JUNTAR) { out = out.concat(g); return; }
      var uno = g[0];
      out.push({
        dia: uno.dia, inicio: uno.inicio, fin: uno.fin,
        nombre: uno.familia.juntos || ('Entrenamientos de ' + uno.familia.etiqueta.toLowerCase()),
        lugar: uno.lugar,
        /* El entrenador NO se hereda: son nueve grupos con entrenadores
           distintos, y poner el del primero sería decir una mentira
           pequeña que alguien va a creerse. */
        entrenador: '',
        nota: g.length + ' grupos, todos a esta hora',
        familia: uno.familia,
        /* El `title` del ratón sí lleva los nombres: quien quiera saber
           si el suyo está, lo tiene ahí sin ensuciar la tarjeta. */
        crudo: g.map(function (x) { return x.nombre; }).join(' · ')
      });
    });
    return out;
  }

  function entrenosDelDia(d) {
    var lista = entrenos.filter(function (e) {
      return e.dia === d && (filtro === 'todos' || e.familia.clave === filtro);
    }).sort(function (a, b) {
      var x = minutos(a.inicio) - minutos(b.inicio);
      return x !== 0 ? x : a.nombre.localeCompare(b.nombre, 'es');
    });
    return juntarIguales(lista);
  }

  /* ---------- Pintado ---------- */
  function htmlTarjeta(e) {
    var franja = e.fin ? (e.inicio + ' – ' + e.fin) : (e.inicio + ' h');
    return '<article class="hor-tarj" style="--c:' + e.familia.color + '" title="' + escAttr(e.crudo) + '">' +
             '<span class="hora">' + esc(franja) + '</span>' +
             '<span class="nombre">' + esc(e.nombre) + '</span>' +
             (e.lugar ? '<span class="lugar">' + esc(e.lugar) + '</span>' : '') +
             (e.entrenador ? '<span class="entrena">Con ' + esc(e.entrenador) + '</span>' : '') +
             (e.nota ? '<span class="nota">' + esc(e.nota) + '</span>' : '') +
           '</article>';
  }

  function pintarParrilla(fechas, indiceHoy) {
    var html = '';
    for (var d = 0; d < 7; d++) {
      var lista = entrenosDelDia(d);
      var esHoy = (d === indiceHoy);
      html += '<div class="hor-col' + (esHoy ? ' hoy' : '') + '">' +
                '<div class="cabecera-dia">' +
                  '<span class="dia">' + (esHoy ? 'Hoy' : DIAS_CORTO[d]) + '</span>' +
                  '<span class="num">' + (fechas[d].getDate() < 10 ? '0' : '') + fechas[d].getDate() + '</span>' +
                '</div>' +
                (lista.length ? lista.map(htmlTarjeta).join('') : '<div class="hor-vacio">Sin entrenos</div>') +
              '</div>';
    }
    document.getElementById('hor-parrilla').innerHTML = html;
  }

  function pintarAcordeon(fechas, indiceHoy) {
    var abiertoPorDefecto = (indiceHoy >= 0) ? indiceHoy : 0;
    var html = '';
    for (var d = 0; d < 7; d++) {
      var lista = entrenosDelDia(d);
      var esHoy = (d === indiceHoy);
      var cuenta = lista.length ? (lista.length + (lista.length === 1 ? ' entreno' : ' entrenos')) : 'Sin entrenos';
      html += '<details class="' + (esHoy ? 'hoy' : '') + '"' + (d === abiertoPorDefecto ? ' open' : '') + '>' +
                '<summary>' +
                  '<span class="dia">' + (esHoy ? 'Hoy' : DIAS_LARGO[d]) + '</span>' +
                  '<span class="num">' + fechas[d].getDate() + ' ' + MESES_CORTO[fechas[d].getMonth()] + '</span>' +
                  '<span class="cuenta">' + cuenta + '</span>' +
                  '<span class="caret" aria-hidden="true"></span>' +
                '</summary>' +
                '<div class="cuerpo-dia">' +
                  (lista.length ? lista.map(htmlTarjeta).join('') : '<div class="hor-vacio">Sin entrenos</div>') +
                '</div>' +
              '</details>';
    }
    document.getElementById('hor-acordeon').innerHTML = html;
  }

  function pintarChips() {
    var presentes = {};
    grupos.forEach(function (g) { presentes[familiaDe(g.seccion).clave] = true; });
    var lista = [{ clave: 'todos', etiqueta: 'Todos', color: '' }];
    SECCIONES.forEach(function (s) { if (presentes[s.clave]) lista.push(s); });
    if (presentes[OTRA.clave]) lista.push(OTRA);

    document.getElementById('hor-filtro').innerHTML = lista.map(function (s) {
      return '<button type="button" data-clave="' + escAttr(s.clave) + '" aria-pressed="' + (filtro === s.clave) + '"' +
             (s.color ? ' style="--c:' + s.color + '"' : '') + '>' +
             (s.color ? '<span class="punto" aria-hidden="true"></span>' : '') + esc(s.etiqueta) + '</button>';
    }).join('');

    document.getElementById('hor-leyenda').innerHTML =
      '<span class="eyebrow">Secciones</span>' +
      lista.filter(function (s) { return s.color; }).map(function (s) {
        return '<span class="item" style="--c:' + s.color + '"><i aria-hidden="true"></i>' + esc(s.etiqueta) + '</span>';
      }).join('');
  }

  function pintarOtros() {
    var caja = document.getElementById('hor-otros');
    var lista = otros.filter(function (o) { return filtro === 'todos' || o.familia.clave === filtro; });
    if (!lista.length) { caja.hidden = true; return; }
    document.getElementById('hor-otros-lista').innerHTML = lista.map(function (o) {
      return '<div class="fila" style="--c:' + o.familia.color + '">' +
               '<span class="nombre">' + esc(o.nombre) + '</span>' +
               '<span class="txt">' + esc(o.texto) + '</span>' +
             '</div>';
    }).join('');
    caja.hidden = false;
  }

  function pintar() {
    var fechas = diasDeLaSemana();
    var indiceHoy = (hoy().getDay() + 6) % 7;

    pintarParrilla(fechas, indiceHoy);
    pintarAcordeon(fechas, indiceHoy);
    pintarOtros();

    document.getElementById('hor-parrilla').hidden = false;
    document.getElementById('hor-acordeon').hidden = false;
    document.getElementById('hor-leyenda').hidden = false;
  }

  function estado(texto) {
    var p = document.getElementById('hor-estado');
    if (!texto) { p.hidden = true; return; }
    p.hidden = false;
    p.innerHTML = texto;
  }

  /* ---------- Interacción ---------- */
  document.getElementById('hor-filtro').addEventListener('click', function (ev) {
    var b = ev.target.closest('button[data-clave]');
    if (!b) return;
    filtro = b.getAttribute('data-clave');
    Array.prototype.forEach.call(this.querySelectorAll('button'), function (x) {
      x.setAttribute('aria-pressed', String(x.getAttribute('data-clave') === filtro));
    });
    pintar();
  });

  /* ---------- Carga ---------- */
  /* ⚠️ NO ARRANCA SOLA. En el calendario la parrilla nace escondida detrás
     de su pestaña, y calcular la semana entera de cada grupo para algo que
     quizá nadie mire es trabajo tirado en el móvil de una familia. Se llama
     cuando hace falta, y solo la primera vez. */
  var yaPintada = false;
  function arrancar() {
    if (yaPintada) return;
    yaPintada = true;
    if (!window.APOLANA_DB) {
      estado('Ahora mismo no podemos mostrar los horarios. Escríbenos y te decimos el tuyo: <a href="' + (window.APOLANA_BASE || '../') + 'contacto/">contacto</a>.');
      return;
    }
    window.APOLANA_DB
      .from('grupos')
      .select('id, nombre, seccion, horario, entrenador_id, turno')
      .eq('activo', true)
      .order('nombre')
      /* Dentro del mismo nombre, primero el turno de lunes: dos líneas
         iguales que unas veces empiezan por el lunes y otras por el
         martes se leen como un desorden. */
      .order('turno', { nullsFirst: true })
      .then(function (res) {
        if (res.error) {
          console.warn('[Apolana] horarios:', res.error.message);
          estado('Ahora mismo no podemos mostrar los horarios. Escríbenos y te decimos el tuyo: <a href="' + (window.APOLANA_BASE || '../') + 'contacto/">contacto</a>.');
          return;
        }
        grupos = res.data || [];
        if (!grupos.length) {
          estado('Todavía no hay grupos publicados. Escríbenos y te contamos: <a href="' + (window.APOLANA_BASE || '../') + 'contacto/">contacto</a>.');
          return;
        }
        /* Quién entrena cada grupo. Sale de una vista que solo enseña el
           nombre de quien lleva un grupo (nada de correos ni teléfonos).
           Si fallara, la página se pinta igual, sin esa línea. */
        window.APOLANA_DB.from('entrenadores_publicos').select('id, nombre')
          .then(function (r2) {
            if (!r2.error && r2.data) {
              var porId = {};
              r2.data.forEach(function (e) { porId[e.id] = e.nombre; });
              grupos.forEach(function (g) { g.entrenador = porId[g.entrenador_id] || ''; });
            }
          })
          .catch(function () {})
          .then(function () {
            prepararDatos();
            estado('');
            pintarChips();
            pintar();
          });
      });
  }

  window.APOLANA_HORARIOS = { pintar: arrancar };
})();
