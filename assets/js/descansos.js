/* ============================================================
   DESCANSOS · Club Atletismo Apolana
   ------------------------------------------------------------
   QUÉ RESUELVE
   Hasta ahora una serie se escribía sin recuperación, y sin
   recuperación una serie no dice nada: 6×800 con 90" y 6×800 con
   3' son dos entrenamientos distintos. Este archivo pone en un
   solo sitio las tres cosas que hacen falta para arreglarlo:

     a) LA FORMA DE LOS DATOS — cómo se guarda el descanso dentro
        de `sesiones.bloques` (jsonb) sin romper nada de lo que ya
        hay escrito.
     b) EL CÁLCULO DEL TIEMPO — cuánto dura la sesión, sumando
        trabajo y recuperación. Honesto: si faltan datos no se
        inventa nada, se devuelve null y la pantalla enseña solo
        los metros.
     c) EL TEXTO EN CRISTIANO — cómo se escribe el descanso en
        cada deporte: `8 × 50 salida 1'00"`, `6 × 800 rec 2' trote`,
        `4 × 6 sentadilla desc. 2'`, `5 × subida 400 m D+ ·
        rec: bajada suave`.

   POR QUÉ AQUÍ Y NO EN CADA PÁGINA
   El descanso se ve en el portal del entrenador, en el del
   atleta, en el de la familia, en la pantalla de calles y en el
   panel. Si el texto se escribe cinco veces, se escribe distinto
   cinco veces. Aquí se escribe una y las cinco pantallas dicen lo
   mismo.

   NO HACE FALTA MIGRACIÓN
   `sesiones.bloques` ya es jsonb: los campos nuevos caben dentro
   sin tocar el esquema. Y lo que ya está escrito (el campo de
   texto libre `descanso`) se sigue entendiendo: este módulo lo
   lee y lo interpreta solo.

   CÓMO SE USA (en la página que lo pinta):
     <script src="/assets/js/descansos.js"></script>

     var D   = window.APOLANA_DESCANSOS;
     var dis = D.disciplinaDe(sesion, grupo);        // 'natacion' | 'pista' | ...
     var rec = D.recDeFila(fila, dis);               // null si no hay descanso
     if (rec) pintar(D.textoRec(rec, dis));          // "salida 1'00""
     var r   = D.resumen(sesion, { disciplina: dis });
     // r.volumen -> "2.000 m"   r.tiempo -> "~55'" (o null si no se sabe)

   REGLA DE ORO DE PINTADO
   Si un bloque no lleva recuperación, el campo DESAPARECE. Nunca
   un «—»: un guion hace dudar de si falta el dato o de si de
   verdad no hay descanso. Por eso todas las funciones de texto
   devuelven cadena vacía cuando no hay nada que decir.
   ============================================================ */
(function () {
  'use strict';

  /* ==========================================================
     1 · LA FORMA DE LOS DATOS
     ----------------------------------------------------------
     Un bloque de `sesiones.bloques` es hoy:

       { etiqueta, matiz, calle, atletas, filas: [ ... ] }

     y una fila:

       { ejercicio, series, distancia, ritmo, descanso, material,
         calzado, carga, detalle, observaciones }

     Se añade, sin quitar nada:

       fila.rec = {                 // recuperación DENTRO de la serie
         modo:     'salida' | 'fijo' | 'tiempo' | 'distancia' | 'bajada' | 'ninguna',
         segundos: 90,              // si el modo va en tiempo
         metros:   200,             // si el modo va en metros
         forma:    'trote' | 'parado' | 'andando' | 'suave' | 'trotando' |
                   'bici' | 'bastones' | null,
         texto:    'lo que escribió el entrenador'   // solo si no encaja en nada
       }

       fila.desnivel_m = 400        // montaña: metros de desnivel de la subida

       bloque.rec_bloque    = { segundos: 180 }   // descanso DESPUÉS del bloque
       bloque.rec_ejercicios= { segundos: 180 }   // El Cubo: entre ejercicios

     `fila.descanso` (texto libre) NO se toca: se sigue escribiendo
     siempre, con el texto bonito que genera este módulo. Así, si
     una pantalla vieja guarda una fila y se deja `rec` por el
     camino, el dato no se pierde: al volver a leerla, este módulo
     lo interpreta otra vez desde el texto.
     ========================================================== */

  var VERSION = '1.0';

  var DISCIPLINAS = ['natacion', 'pista', 'running', 'cubo', 'montana'];

  /* Qué modos de recuperación admite cada deporte, en orden de
     preferencia (el primero es el que ofrece el formulario por
     defecto). El diseñador lo fijó así en la maqueta 25d. */
  var MODOS = {
    natacion: ['salida', 'fijo'],
    pista:    ['tiempo', 'distancia'],
    running:  ['tiempo', 'distancia'],
    cubo:     ['tiempo'],
    montana:  ['bajada', 'tiempo']
  };

  /* En natación salida y descanso se confunden y son cosas
     distintas, así que van con etiqueta de color. Colores del kit
     (azul del club para la salida; tierra para el descanso, que
     el ámbar está reservado a los avisos). */
  var COLORES = {
    salida:   { texto: '#1F5C8F', fondo: '#E7F0F8', borde: '#C7DDF0' },
    descanso: { texto: '#6B5227', fondo: '#F7EFDD', borde: '#E6D4AE' }
  };

  /* Cuáles son de verdad obligatorios: en pista y running una
     serie sin recuperación no se entiende. En rodajes y tiradas
     (una sola repetición) no hay nada que recuperar y el campo se
     oculta; de eso se encarga `pideRec()`. */
  function pideRec(fila, disciplina) {
    var n = numero(fila && fila.series);
    if (!n || n < 2) return false;                 // rodaje, tirada, ejercicio suelto
    return disciplina === 'pista' || disciplina === 'running';
  }

  /* ----------------------------------------------------------
     De qué deporte estamos hablando
     La tabla `sesiones` tiene `tipo` (natacion, pista, gym,
     continuo…) y el grupo tiene `seccion` (montana, running,
     cubo, triatlon…). La disciplina que manda el formato del
     descanso sale de las dos: la sección afina lo que el tipo
     deja a medias (un `continuo` de la sección montaña se escribe
     por desnivel, no por series).
     -------------------------------------------------------- */
  function disciplinaDe(sesion, grupo) {
    var tipo = (sesion && sesion.tipo || '').toLowerCase();
    var sec = '';
    if (grupo && grupo.seccion) sec = String(grupo.seccion).toLowerCase();
    else if (sesion && sesion.seccion) sec = String(sesion.seccion).toLowerCase();

    if (tipo === 'natacion' || sec === 'natacion' || sec === 'escuela-natacion') return 'natacion';
    if (tipo === 'gym' || sec === 'cubo') return 'cubo';
    if (sec === 'montana') return 'montana';
    if (tipo === 'pista') return 'pista';
    if (sec === 'running') return 'running';
    if (tipo === 'continuo') return 'running';
    return 'pista';
  }

  /* ==========================================================
     2 · LEER Y ESCRIBIR EL DESCANSO
     ========================================================== */

  /* Devuelve la recuperación de una fila, ya normalizada, o null
     si esa fila no lleva descanso. Primero mira el campo nuevo
     `rec`; si no está, interpreta el texto libre de siempre. */
  function recDeFila(fila, disciplina) {
    if (!fila) return null;
    if (fila.rec && typeof fila.rec === 'object') {
      var r = normalizarRec(fila.rec, disciplina);
      if (r) return r;
    }
    return interpretarDescanso(fila.descanso, disciplina);
  }

  /* Guarda la recuperación en la fila: el objeto `rec` y, a la
     vez, el texto de siempre en `descanso`, para que ninguna
     pantalla se quede sin el dato. */
  function ponerRec(fila, rec, disciplina) {
    if (!fila) return fila;
    var r = normalizarRec(rec, disciplina);
    if (!r || r.modo === 'ninguna') return quitarRec(fila);
    fila.rec = r;
    fila.descanso = textoRecPlano(r, disciplina);
    return fila;
  }

  function quitarRec(fila) {
    if (!fila) return fila;
    delete fila.rec;
    delete fila.descanso;                          // el campo desaparece, no se queda en «—»
    return fila;
  }

  /* Descanso entre bloques (el separador que hoy no existe en
     ningún deporte) y, en El Cubo, entre ejercicios. */
  function recEntreBloques(bloque) { return segDeCampo(bloque && bloque.rec_bloque); }
  function recEntreEjercicios(bloque) { return segDeCampo(bloque && bloque.rec_ejercicios); }

  function ponerRecEntreBloques(bloque, segundos) {
    if (!bloque) return bloque;
    if (segundos > 0) bloque.rec_bloque = { segundos: Math.round(segundos) };
    else delete bloque.rec_bloque;
    return bloque;
  }
  function ponerRecEntreEjercicios(bloque, segundos) {
    if (!bloque) return bloque;
    if (segundos > 0) bloque.rec_ejercicios = { segundos: Math.round(segundos) };
    else delete bloque.rec_ejercicios;
    return bloque;
  }

  function segDeCampo(v) {
    if (v == null) return null;
    if (typeof v === 'number') return v > 0 ? v : null;
    if (typeof v === 'string') return segundosDeTexto(v);
    if (typeof v === 'object') {
      if (v.segundos > 0) return v.segundos;
      if (v.texto) return segundosDeTexto(v.texto);
    }
    return null;
  }

  /* Pone en orden un objeto rec venga como venga. */
  function normalizarRec(rec, disciplina) {
    if (!rec) return null;
    if (typeof rec === 'string' || typeof rec === 'number') {
      return interpretarDescanso(String(rec), disciplina);
    }
    var modo = (rec.modo || '').toLowerCase();
    var seg = rec.segundos != null ? numero(rec.segundos) : segundosDeTexto(rec.valor || rec.texto);
    var met = rec.metros != null ? numero(rec.metros) : null;
    var forma = rec.forma ? String(rec.forma).toLowerCase() : null;
    /* Lo que el entrenador escribió y no se puede reinterpretar: si
       puso un rango, sigue siendo un rango; si puso kilómetros,
       siguen siendo kilómetros. Se arrastran por aquí o se pierden
       en el primer viaje de ida y vuelta. */
    var rango = rec.rango || null;
    var unidad = rec.unidad || null;
    var valor = rec.valor != null && !isNaN(parseFloat(rec.valor)) ? numero(rec.valor) : null;

    if (!modo) {
      if (met > 0) modo = 'distancia';
      else if (seg > 0) modo = (disciplina === 'natacion' ? 'fijo' : 'tiempo');
      else if (rec.texto) return interpretarDescanso(rec.texto, disciplina);
      else return null;
    }
    if (modo === 'ninguna') return { modo: 'ninguna', segundos: null, metros: null, forma: null, texto: null };
    if (modo === 'bajada') {
      return { modo: 'bajada', segundos: seg > 0 ? seg : null, metros: null, forma: forma || 'suave', texto: rec.texto || null };
    }
    if (modo === 'distancia') {
      if (!(met > 0)) return null;
      return { modo: 'distancia', segundos: null, metros: met, valor: valor, unidad: unidad,
               forma: forma, texto: rec.texto || null };
    }
    if (modo === 'salida' || modo === 'fijo' || modo === 'tiempo') {
      if (!(seg > 0)) return rec.texto ? interpretarDescanso(rec.texto, disciplina) : null;
      return { modo: modo, segundos: seg, metros: null, rango: rango, forma: forma, texto: rec.texto || null };
    }
    return interpretarDescanso(rec.texto || rec.valor, disciplina);
  }

  /* ----------------------------------------------------------
     Interpretar el texto libre que ya hay escrito en la base
     («2 min trote», «bajada andando», «1:30», «vuelta andando»,
     «200 m», «salida 1'10"»…). Todo lo que no se entienda se
     guarda tal cual en `texto` y se pinta tal cual: no se pierde
     nada y no se inventa nada.
     -------------------------------------------------------- */
  function interpretarDescanso(txt, disciplina) {
    if (txt == null) return null;
    var t = String(txt).trim();
    if (!t) return null;
    var bajo = quitarTildes(t.toLowerCase());

    if (/^(sin descanso|sin recuperacion|nada|ninguno|ninguna|no)$/.test(bajo)) {
      return { modo: 'ninguna', segundos: null, metros: null, forma: null, texto: null };
    }

    var forma = formaDeTexto(bajo);

    /* Montaña / cuestas: la recuperación es la bajada. */
    if (/\bbajada\b|\bbajando\b/.test(bajo)) {
      return { modo: 'bajada', segundos: segundosDeTexto(bajo), metros: null,
               forma: forma || 'suave', texto: t };
    }
    /* «vuelta andando», «subida andando»: es una vuelta al sitio,
       no un tiempo. Se guarda como texto y se pinta igual. */
    if (/\bvuelta\b|\bsubida andando\b|\bal trote de vuelta\b/.test(bajo) && !/\d/.test(bajo)) {
      return { modo: 'texto', segundos: null, metros: null, forma: forma, texto: t };
    }

    /* Salida cada X (natación). */
    if (/\bsalida\b|\bsale cada\b|\bcada\b/.test(bajo)) {
      var segS = segundosDeTexto(bajo);
      if (segS > 0) return { modo: 'salida', segundos: segS, metros: null, forma: null, texto: null };
    }

    /* Recuperación en metros: «200 m», «rec 200m», «vuelta de 300 m».
       La UNIDAD se guarda tal como la escribió el entrenador: si
       puso «1 km» se enseña «1 km», no «1.000 m». Los metros se
       calculan igual, porque sumar volumen sí necesita una unidad
       común, pero para pintar manda lo que él escribió. */
    var mm = bajo.match(/(\d+(?:[.,]\d+)?)\s*(km|m)\b(?!in)/);
    if (mm && !/\bmin\b/.test(bajo)) {
      var val = parseFloat(mm[1].replace(',', '.'));
      var uni = (mm[2] === 'km') ? 'km' : 'm';
      var met = val * (uni === 'km' ? 1000 : 1);
      if (met > 0) return { modo: 'distancia', segundos: null, metros: Math.round(met),
                            valor: val, unidad: uni, forma: forma, texto: null };
    }

    var seg = segundosDeTexto(bajo);
    if (seg > 0) {
      var modo = (disciplina === 'natacion') ? 'fijo' : 'tiempo';
      /* Si venía un rango, se guarda que lo era: al pintarlo se
         enseña el rango entero y no el promedio, que es un número
         que el entrenador no escribió. */
      var rg = rangoDeTexto(bajo);
      return { modo: modo, segundos: seg, metros: null, forma: forma, rango: rg ? rg.texto : null,
               texto: /[a-z]{3}/.test(bajo.replace(/min|seg|segundos|minutos|s\b|m\b/g, '')) ? t : null };
    }

    /* No se entiende: se respeta tal cual. */
    return { modo: 'texto', segundos: null, metros: null, forma: forma, texto: t };
  }

  function formaDeTexto(bajo) {
    if (/\btrotando\b/.test(bajo)) return 'trotando';
    if (/\btrote\b|\btrotar\b/.test(bajo)) return 'trote';
    if (/\bandando\b|\bcaminando\b|\bpaseo\b/.test(bajo)) return 'andando';
    if (/\bparad[oa]s?\b|\bquiet[oa]\b|\bcompleta\b/.test(bajo)) return 'parado';
    if (/\ben bici\b|\bbici\b/.test(bajo)) return 'bici';
    if (/\bbastones\b/.test(bajo)) return 'bastones';
    if (/\bsuave\b|\bflojo\b/.test(bajo)) return 'suave';
    return null;
  }

  /* ==========================================================
     3 · LEER NÚMEROS DE TEXTOS ESCRITOS A MANO
     ========================================================== */

  /* «2 min» → 120 · «1:30» → 90 · «90"» → 90 · «1'30"» → 90
     «45 s» → 45 · «2 min 30 s» → 150 · «3-4 min» → 210 (media) */
  function segundosDeTexto(txt) {
    if (txt == null) return null;
    if (typeof txt === 'number') return txt > 0 ? txt : null;
    var t = quitarTildes(String(txt).toLowerCase()).replace(/\s+/g, ' ').trim();
    if (!t) return null;

    /* Rango «3-4 min» / «45-60 s»: para CALCULAR se toma el punto
       medio, que para estimar cuánto dura la sesión es razonable.
       Para ENSEÑARLO no: «45-60 s» no se escribe «53"», porque 53
       no lo dijo nadie. De eso se encarga `rangoDeTexto()`, que
       usan las funciones de texto para pintar el rango entero. */
    var rango = rangoDeTexto(t);
    if (rango) return Math.round(((rango.a + rango.b) / 2) * rango.mult);

    /* «1:30» o «1:30.5» → mm:ss */
    var reloj = t.match(/(\d{1,2})\s*:\s*(\d{1,2})(?:[.,]\d+)?/);
    if (reloj) return parseInt(reloj[1], 10) * 60 + parseInt(reloj[2], 10);

    /* «1'30"» / «1' 30» */
    var mmss = t.match(/(\d+)\s*'\s*(\d{1,2})\s*"?/);
    if (mmss) return parseInt(mmss[1], 10) * 60 + parseInt(mmss[2], 10);

    var total = 0, visto = false;
    var min = t.match(/(\d+(?:[.,]\d+)?)\s*(?:min\b|minutos?\b|m\s*in\b|')/);
    if (min) { total += parseFloat(min[1].replace(',', '.')) * 60; visto = true; }
    var sg = t.match(/(\d+(?:[.,]\d+)?)\s*(?:seg\b|segundos?\b|s\b|")/);
    if (sg) { total += parseFloat(sg[1].replace(',', '.')); visto = true; }
    if (visto) return Math.round(total);

    /* Un número pelado: en descansos se lee como segundos. */
    var solo = t.match(/^(\d+(?:[.,]\d+)?)$/);
    if (solo) return Math.round(parseFloat(solo[1].replace(',', '.')));
    return null;
  }

  /* ¿El entrenador escribió un rango? «45-60 s», «3-4 min», «2 a 3
     min». Devuelve los dos extremos y cómo se escribe el rango
     entero, para poder enseñarlo tal cual.

     POR QUÉ ESTO EXISTE: un rango es una INDICACIÓN («entre 45 y 60
     segundos, según cómo vayas»), y al promediarlo se convierte en
     una orden falsa («53 segundos»). El entrenador escribió un
     rango a propósito; enseñarlo es respetarlo. */
  function rangoDeTexto(txt) {
    if (txt == null) return null;
    var t = quitarTildes(String(txt).toLowerCase()).replace(/\s+/g, ' ').trim();
    var m = t.match(/(\d+(?:[.,]\d+)?)\s*(?:-|–|—|a)\s*(\d+(?:[.,]\d+)?)\s*(min|minutos?|'|s|seg|segundos?|")/);
    if (!m) return null;
    var a = parseFloat(m[1].replace(',', '.')), b = parseFloat(m[2].replace(',', '.'));
    if (!(a > 0) || !(b > 0)) return null;
    var enMinutos = /min|'/.test(m[3]);
    return {
      a: a, b: b,
      mult: enMinutos ? 60 : 1,
      unidad: enMinutos ? 'min' : 's',
      /* Se escribe con el símbolo corto, que es como se lee de un
         vistazo a pie de pista: «45-60"», «3-4'». */
      texto: numTxt(a) + '-' + numTxt(b) + (enMinutos ? '\'' : '"')
    };
  }

  function numTxt(n) { return String(n).replace('.', ','); }

  /* Qué mide el campo `distancia` de una fila, que unas veces son
     metros («400 m», «1.000 m», «18 km»), otras tiempo («10 min»,
     «45 seg», «8 min de subida») y otras repeticiones («6», en
     El Cubo). Se devuelve lo que se ha entendido y nada más. */
  function medidaDeDistancia(txt) {
    var vacio = { metros: null, segundos: null, reps: null, texto: null };
    if (txt == null) return vacio;
    var t = quitarTildes(String(txt).toLowerCase()).trim();
    if (!t) return vacio;

    /* A veces el entrenador mete la serie entera en el campo de la
       distancia: «4 x 25 m» son 100 m, no 25. */
    var serie = t.match(/^(\d+)\s*[x×]\s*(\d+(?:[.,]\d+)?)\s*m\b(?!in)/);
    if (serie) {
      return { metros: Math.round(parseInt(serie[1], 10) * parseFloat(serie[2].replace(',', '.'))),
               segundos: null, reps: null, texto: txt };
    }

    var km = t.match(/(\d+(?:[.,]\d+)?)\s*km\b/);
    if (km) return { metros: Math.round(parseFloat(km[1].replace(',', '.')) * 1000), segundos: null, reps: null, texto: txt };

    /* Metros: ojo con el punto de los miles («1.000 m» son 1000). */
    var m = t.match(/(\d{1,3}(?:\.\d{3})+|\d+(?:,\d+)?)\s*m\b(?!in)/);
    if (m) {
      var n = parseFloat(m[1].replace(/\./g, '').replace(',', '.'));
      return { metros: Math.round(n), segundos: null, reps: null, texto: txt };
    }

    /* «40 s» y «45 s por pie» también son tiempo: la «s» suelta
       entraba antes por ninguna parte y esas filas se leían como si
       no midieran nada. Va detrás del bloque de metros a propósito,
       para que «50 m» siga siendo metros. */
    var seg = /\bmin\b|\bminutos?\b|\bseg\b|\bsegundos?\b|\d\s*s\b|:|'|"/.test(t) ? segundosDeTexto(t) : null;
    if (seg > 0) return { metros: null, segundos: seg, reps: null, texto: txt };

    var solo = t.match(/^(\d+)$/);
    if (solo) return { metros: null, segundos: null, reps: parseInt(solo[1], 10), texto: txt };

    return { metros: null, segundos: null, reps: null, texto: txt };
  }

  /* El ritmo solo sirve para el cálculo si de verdad es un ritmo:
     «3:30/km», «1'05"/100», «4:00 min/km». Un «90-95%» o un
     «por sensaciones» no son ritmos y aquí se devuelven como
     desconocidos: es preferible no dar tiempo a dar uno falso. */
  function ritmoDeTexto(txt) {
    if (txt == null) return null;
    var t = quitarTildes(String(txt).toLowerCase()).replace(/\s+/g, ' ').trim();
    if (!t || /%/.test(t)) return null;

    var ref = t.match(/(?:\/|\bpor\b|\bcada\b|\bal\b)\s*(\d{2,4})\s*m?\b/);     // .../100 m, /100, /400 m
    var porKm = /\/\s*km|\bpor km\b|\bmin\/km\b|\bkm\b/.test(t);
    var seg = segundosDeTexto(t);
    if (!(seg > 0)) return null;

    var referencia = ref ? parseInt(ref[1], 10) : (porKm ? 1000 : null);
    if (!referencia) return null;
    return { segundos_por_metro: seg / referencia, referencia_m: referencia, segundos: seg };
  }

  /* ==========================================================
     4 · FORMATO (cómo se escriben los números)
     ========================================================== */

  /* 45 → 45"  ·  120 → 2'  ·  90 → 90"  ·  150 → 2'30" */
  function fmtSegundos(s) {
    if (!(s > 0)) return '';
    s = Math.round(s);
    if (s % 60 === 0) return (s / 60) + '\'';
    if (s < 120) return s + '"';
    var m = Math.floor(s / 60), r = s % 60;
    return m + '\'' + (r < 10 ? '0' + r : r) + '"';
  }

  /* La salida de natación siempre en minuto y segundos, que es
     como se canta en el borde de la piscina: 60 → 1'00", 80 →
     1'20", 55 → 55". */
  function fmtSalida(s) {
    if (!(s > 0)) return '';
    s = Math.round(s);
    if (s < 60) return s + '"';
    var m = Math.floor(s / 60), r = s % 60;
    return m + '\'' + (r < 10 ? '0' + r : r) + '"';
  }

  /* 2000 → «2.000 m» (punto de miles, como se escribe en español) */
  function fmtMetros(m) {
    if (!(m > 0)) return '';
    return miles(Math.round(m)) + ' m';
  }

  /* Una distancia escrita CON LA UNIDAD QUE PUSO EL ENTRENADOR.
     «12 km» se enseña «12 km», no «12.000 m»: convertir por detrás
     es donde aparecen los errores de mil, y además «12 km» es como
     lo dice un entrenador y «12.000 m» no lo dice nadie. Si no
     consta la unidad original, se cae a metros, que es lo
     mayoritario en pista. */
  function fmtDistancia(r) {
    if (!r) return '';
    if (r.unidad === 'km' && r.valor > 0) return numTxt(r.valor) + ' km';
    return fmtMetros(r.metros);
  }

  function miles(n) {
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  }

  /* 55 → «55'» · 85 → «1 h 25'» */
  function fmtDuracion(min) {
    if (!(min > 0)) return '';
    min = Math.round(min);
    if (min < 60) return min + '\'';
    var h = Math.floor(min / 60), r = min % 60;
    return h + ' h' + (r ? ' ' + r + '\'' : '');
  }

  /* El tiempo estimado siempre lleva la tilde de «más o menos»:
     es una estimación y se dice que lo es. */
  function fmtEstimado(min) {
    var d = fmtDuracion(min);
    return d ? '~' + d : '';
  }

  /* ==========================================================
     5 · EL TEXTO EN CRISTIANO, DEPORTE A DEPORTE
     ========================================================== */

  /* El descanso de una fila, ya escrito:
       natación  salida  →  «salida 1'00"»
       natación  fijo    →  «descanso 20"»
       pista/run tiempo  →  «rec 2' trote»
       pista/run metros  →  «rec 200 m»
       El Cubo           →  «desc. 2'»
       montaña           →  «rec: bajada suave»
     Si no hay descanso devuelve '' y la pantalla no pinta nada. */
  function textoRec(rec, disciplina) {
    var r = normalizarRec(rec, disciplina);
    if (!r || r.modo === 'ninguna') return '';

    if (r.modo === 'salida') return 'salida ' + fmtSalida(r.segundos);
    if (r.modo === 'fijo')   return 'descanso ' + (r.rango || fmtSegundos(r.segundos));

    if (r.modo === 'bajada') {
      var comoBaja = r.forma && r.forma !== 'parado' ? r.forma : 'suave';
      return 'rec: bajada ' + comoBaja;
    }
    if (r.modo === 'texto') return 'rec ' + (r.texto || '');

    var etiq = (disciplina === 'cubo') ? 'desc. ' : 'rec ';
    if (r.modo === 'distancia') return etiq + fmtDistancia(r) + (r.forma ? ' ' + r.forma : '');
    /* El rango manda sobre el número: si el entrenador escribió
       «45-60 s», eso es lo que se lee, no el promedio. */
    if (r.modo === 'tiempo')    return etiq + (r.rango || fmtSegundos(r.segundos)) + (r.forma ? ' ' + r.forma : '');
    return '';
  }

  /* Lo mismo pero sin la palabra de delante, para guardarlo en el
     campo de texto libre `descanso` de siempre (que las pantallas
     viejas ya pintan precedido de «rec» o «desc.»). */
  function textoRecPlano(rec, disciplina) {
    var r = normalizarRec(rec, disciplina);
    if (!r || r.modo === 'ninguna') return '';
    if (r.modo === 'salida')    return 'salida ' + fmtSalida(r.segundos);
    if (r.modo === 'fijo')      return r.rango || fmtSegundos(r.segundos);
    if (r.modo === 'bajada')    return 'bajada ' + (r.forma && r.forma !== 'parado' ? r.forma : 'suave');
    if (r.modo === 'texto')     return r.texto || '';
    if (r.modo === 'distancia') return fmtDistancia(r) + (r.forma ? ' ' + r.forma : '');
    if (r.modo === 'tiempo')    return (r.rango || fmtSegundos(r.segundos)) + (r.forma ? ' ' + r.forma : '');
    return '';
  }

  /* En natación, salida y descanso se confunden y son cosas
     distintas: cada una con su etiqueta de color. Devuelve null
     en el resto de deportes y cuando no hay descanso. */
  function etiquetaNatacion(rec) {
    var r = normalizarRec(rec, 'natacion');
    if (!r) return null;
    if (r.modo === 'salida') {
      return { clave: 'salida', texto: 'salida', valor: fmtSalida(r.segundos),
               ayuda: 'Nadar y descansar caben dentro del intervalo.',
               color: COLORES.salida.texto, fondo: COLORES.salida.fondo, borde: COLORES.salida.borde };
    }
    if (r.modo === 'fijo') {
      return { clave: 'descanso', texto: 'descanso', valor: fmtSegundos(r.segundos),
               ayuda: 'Segundos parado al tocar la pared, tardes lo que tardes.',
               color: COLORES.descanso.texto, fondo: COLORES.descanso.fondo, borde: COLORES.descanso.borde };
    }
    return null;
  }

  /* La serie escrita, sin el nombre del ejercicio: «8 × 50»,
     «6 × 800 m», «4 × 6», «subida 400 m D+», «12 km». Una sola
     repetición no se escribe «1 × 12 km», se escribe «12 km». */
  function textoSerie(fila, disciplina) {
    if (!fila) return '';
    var series = numero(fila.series);
    var med = medidaDeDistancia(fila.distancia);

    if (disciplina === 'montana' && esSubida(fila)) {
      var desnivel = numero(fila.desnivel_m) || (med.metros || null);
      var cuerpo = 'subida' + (desnivel ? ' ' + miles(desnivel) + ' m D+' : (med.texto ? ' ' + med.texto : ''));
      return series > 1 ? series + ' × ' + cuerpo : cuerpo;
    }
    if (disciplina === 'cubo') {
      if (series > 1 && med.reps) return series + ' × ' + med.reps;      // 4 × 6
      if (series > 1 && fila.distancia) return series + ' × ' + fila.distancia;
      if (series > 1) return series + ' series';
      return fila.distancia ? String(fila.distancia) : '';
    }
    if (series > 1 && fila.distancia) return series + ' × ' + fila.distancia;
    if (series > 1) return series + ' series';
    return fila.distancia ? String(fila.distancia) : '';
  }

  /* Las piezas de una fila, ya escritas y en orden, para que la
     pantalla las pinte como quiera (chips, texto seguido…). El
     nombre del ejercicio NO va aquí: las pantallas ya lo pintan
     aparte, en negrita. Nunca hay piezas vacías: lo que no hay,
     no aparece. */
  function partesFila(fila, disciplina) {
    if (!fila) return [];
    var p = [];
    var serie = textoSerie(fila, disciplina);
    if (serie) p.push(serie);

    if (fila.ritmo && disciplina !== 'cubo') p.push('ritmo ' + fila.ritmo);
    if (fila.carga && disciplina === 'cubo') p.push(String(fila.carga));

    /* El RIR objetivo, en su propia pieza y SIEMPRE que el entrenador lo haya
       escrito —no según la disciplina—: es él quien decide dónde aplica, y en
       un mismo día conviven «RIR 2-3» en un ejercicio y «nada al fallo» en
       otro. Va aquí, con la serie y el descanso, porque es de la misma
       familia: define cómo se hace el ejercicio, no es un comentario. */
    var rir = textoRir(rirDeFila(fila));
    if (rir) p.push(rir);

    var rec = recDeFila(fila, disciplina);
    var t = textoRec(rec, disciplina);
    if (t) p.push(t);                                  // si no hay descanso, no hay pieza: nunca un «—»

    return p;
  }

  /* La fila entera en una línea, tal y como la escribió el
     diseñador:
       «8 × 50 salida 1'00"»
       «6 × 800 rec 2' trote»
       «4 × 6 sentadilla desc. 2'»
       «5 × subida 400 m D+ · rec: bajada suave»
     En El Cubo el nombre del ejercicio va DENTRO de la línea
     («4 × 6 sentadilla»), porque ahí la serie sin el ejercicio no
     significa nada. En el resto de deportes el nombre lo pinta la
     pantalla por su cuenta. */
  function textoFila(fila, disciplina) {
    var p = partesFila(fila, disciplina);
    if (disciplina === 'cubo' && fila && fila.ejercicio) {
      var serie = textoSerie(fila, disciplina);
      p = p.slice();
      if (serie) p[0] = serie + ' ' + fila.ejercicio;
      else p.unshift(fila.ejercicio);
    }
    if (!p.length) return '';
    /* En montaña la recuperación es una frase («rec: bajada
       suave») y pide su propio punto separador. En el resto va
       pegada a la serie: es parte de la serie, no un dato aparte. */
    if (disciplina === 'montana') return p.join(' · ');
    return p.join(' ');
  }

  function esSubida(fila) {
    var t = quitarTildes(((fila && fila.ejercicio || '') + ' ' + (fila && fila.distancia || '')).toLowerCase());
    return numero(fila && fila.desnivel_m) > 0 || /\bsubida\b|\bcuesta\b|\brampa\b|\bpuerto\b/.test(t);
  }

  /* El separador de descanso entre bloques, que hoy no existe en
     ningún deporte. Devuelve '' si ese bloque no lleva descanso
     detrás. */
  function textoEntreBloques(bloque) {
    var s = recEntreBloques(bloque);
    return s > 0 ? fmtSegundos(s) + ' de descanso' : '';
  }

  /* El Cubo: el descanso entre ejercicios es otra cosa que el
     descanso entre series y se dice aparte. */
  function textoEntreEjercicios(bloque) {
    var s = recEntreEjercicios(bloque);
    return s > 0 ? fmtSegundos(s) + ' entre ejercicios' : '';
  }

  /* ==========================================================
     6 · EL CÁLCULO DEL TIEMPO ESTIMADO
     ----------------------------------------------------------
     CÓMO SE CUENTA (y por qué así)

     · Natación, «salida cada X»: nadar y descansar caben dentro
       del intervalo, así que 8 × 50 al 1'00" son 8 minutos
       clavados. No hace falta saber el ritmo: es el único caso en
       que el tiempo se sabe seguro.
     · Descanso fijo, tiempo o metros: hay que sumar el trabajo
       más el descanso. El descanso va ENTRE repeticiones, o sea
       (series − 1) veces: el de después de la última es el
       descanso del bloque.
     · El trabajo se sabe si la fila trae el tiempo escrito
       («10 min») o si trae metros Y un ritmo de verdad
       («1'40"/100»). Un «al 90%» no es un ritmo y no se usa.
     · Entre bloques se suma `rec_bloque` de todos menos el
       último. En El Cubo, además, `rec_ejercicios` entre filas.

     SI FALTA ALGO, NO SE INVENTA. El resultado trae `completo` en
     false, `minutos` en null y una lista de por qué. La pantalla
     entonces enseña solo el volumen, que es lo honesto.
     ========================================================== */

  function estimarFila(fila, disciplina, opts) {
    opts = opts || {};
    var out = { segundos: null, metros: 0, completo: false, motivo: null, sin_metros: false };
    if (!fila) return out;

    var series = numero(fila.series) || 1;
    var med = medidaDeDistancia(fila.distancia);
    var rec = recDeFila(fila, disciplina);

    if (med.metros > 0) out.metros = med.metros * series;
    else out.sin_metros = true;   /* filas medidas en tiempo o en repeticiones:
                                     no suman metros y el volumen queda parcial */

    /* Caso redondo: salida cada X. El intervalo lo incluye todo. */
    if (rec && rec.modo === 'salida' && rec.segundos > 0) {
      out.segundos = rec.segundos * series;
      out.completo = true;
      return out;
    }

    /* Cuánto se tarda en hacer UNA repetición. */
    var trabajo = null;
    if (med.segundos > 0) trabajo = med.segundos;
    else if (med.metros > 0) {
      var rit = ritmoDeTexto(fila.ritmo);
      if (!rit && opts.ritmo_s_por_m > 0) rit = { segundos_por_metro: opts.ritmo_s_por_m, supuesto: true };
      if (rit) {
        trabajo = med.metros * rit.segundos_por_metro;
        if (rit.supuesto) out.supuesto = true;
      }
    }
    if (trabajo == null) {
      out.motivo = 'sin tiempo ni ritmo en «' + (fila.ejercicio || fila.distancia || 'una fila') + '»';
      return out;
    }

    var total = trabajo * series;

    /* El descanso entre repeticiones: (series − 1) veces. */
    if (series > 1 && rec) {
      if (rec.modo === 'fijo' || rec.modo === 'tiempo') {
        total += rec.segundos * (series - 1);
      } else if (rec.modo === 'distancia') {
        /* Los metros de recuperación se hacen trotando o andando:
           sin un ritmo de recuperación no se sabe cuánto duran. */
        var rr = opts.ritmo_rec_s_por_m;
        if (!(rr > 0)) {
          out.motivo = 'recuperación en metros sin ritmo de recuperación';
          return out;
        }
        total += rec.metros * rr * (series - 1);
        out.supuesto = true;
      } else if (rec.modo === 'bajada' || rec.modo === 'texto') {
        /* La bajada dura lo que dura: no hay dato. En montaña, si
           el entrenador escribe el tiempo de bajada, se usa. */
        if (rec.segundos > 0) total += rec.segundos * (series - 1);
        else { out.motivo = 'la bajada no lleva tiempo'; return out; }
      }
    }

    out.segundos = total;
    out.completo = true;
    return out;
  }

  function estimarBloque(bloque, disciplina, opts) {
    opts = opts || {};
    var res = { segundos: 0, metros: 0, completo: true, faltan: [], supuesto: false, sin_metros: 0 };
    var filas = (bloque && bloque.filas) || [];
    filas.forEach(function (f) {
      var e = estimarFila(f, disciplina, opts);
      res.metros += e.metros || 0;
      if (e.sin_metros) res.sin_metros++;
      if (e.supuesto) res.supuesto = true;
      if (e.completo) res.segundos += e.segundos;
      else { res.completo = false; if (e.motivo) res.faltan.push(e.motivo); }
    });

    /* El Cubo: descanso entre ejercicios, tantas veces como huecos. */
    var entreEj = recEntreEjercicios(bloque);
    if (entreEj > 0 && filas.length > 1) res.segundos += entreEj * (filas.length - 1);

    return res;
  }

  /* La sesión entera. En natación con calles, cada nadador hace
     los bloques comunes MÁS los de su calle, no los de todas:
     por eso `opts.calle` decide qué se suma. */
  function estimarSesion(sesion, opts) {
    opts = opts || {};
    var disciplina = opts.disciplina || disciplinaDe(sesion, opts.grupo);
    var bloques = (sesion && sesion.bloques) || [];
    var calle = opts.calle != null ? Number(opts.calle) : null;

    var usados = bloques.filter(function (b) {
      if (b.calle == null) return true;                 // bloque común: lo hace todo el mundo
      return calle == null ? false : Number(b.calle) === calle;
    });

    var res = { disciplina: disciplina, segundos: 0, minutos: null, metros: 0,
                completo: true, faltan: [], supuesto: false, bloques: usados.length,
                sin_metros: 0, volumen_parcial: false,
                tiene_calles: bloques.some(function (b) { return b.calle != null; }),
                calle: calle };

    usados.forEach(function (b, i) {
      var e = estimarBloque(b, disciplina, opts);
      res.metros += e.metros;
      res.sin_metros += e.sin_metros;
      if (e.supuesto) res.supuesto = true;
      if (e.completo) res.segundos += e.segundos;
      else { res.completo = false; e.faltan.forEach(function (m) { if (res.faltan.indexOf(m) < 0) res.faltan.push(m); }); }
      var entre = recEntreBloques(b);
      if (entre > 0 && i < usados.length - 1) res.segundos += entre;
    });

    res.volumen_parcial = res.sin_metros > 0;
    if (res.completo && res.segundos > 0) res.minutos = Math.round(res.segundos / 60);
    else { res.minutos = null; res.segundos = null; }
    return res;
  }

  /* Natación con calles: una estimación por calle, que es como se
     mira desde el bordillo (calle 1 · 1.400 m · ~48'). */
  function estimarPorCalles(sesion, opts) {
    var bloques = (sesion && sesion.bloques) || [];
    var calles = [];
    bloques.forEach(function (b) {
      if (b.calle != null && calles.indexOf(Number(b.calle)) < 0) calles.push(Number(b.calle));
    });
    calles.sort(function (a, b) { return a - b; });
    return calles.map(function (c) {
      var e = estimarSesion(sesion, Object.assign({}, opts || {}, { calle: c }));
      e.calle = c;
      return e;
    });
  }

  /* ----------------------------------------------------------
     Lo que va en la pantalla: volumen y tiempo, SEPARADOS. Las
     familias planifican con el tiempo, no con los metros.
       resumen(sesion) → { volumen: '2.000 m', tiempo: '~55'',
                           estimado: true, ... }
     Si el entrenador ya puso la duración de la sesión
     (`sesiones.duracion_min`), esa manda y no lleva tilde: es un
     dato, no una estimación.
     -------------------------------------------------------- */
  function resumen(sesion, opts) {
    var e = estimarSesion(sesion, opts);
    var puesta = numero(sesion && sesion.duracion_min);

    var out = {
      disciplina: e.disciplina,
      metros: e.metros || 0,
      volumen: e.metros > 0 ? fmtMetros(e.metros) : '',
      volumen_parcial: e.volumen_parcial,     /* hay filas medidas en tiempo o en
                                                 repeticiones: los metros no lo
                                                 cuentan todo */
      tiene_calles: e.tiene_calles,           /* natación: hay que pedir la calle
                                                 con opts.calle o usar
                                                 estimarPorCalles() */
      calle: e.calle,
      minutos: null,
      tiempo: '',
      estimado: false,
      supuesto: e.supuesto,
      completo: e.completo,
      faltan: e.faltan
    };

    if (puesta > 0) {
      out.minutos = puesta;
      out.tiempo = fmtDuracion(puesta);
      out.estimado = false;
    } else if (e.minutos > 0) {
      out.minutos = e.minutos;
      out.tiempo = fmtEstimado(e.minutos);
      out.estimado = true;
    }
    return out;
  }

  /* ==========================================================
     7 · QUÉ SE APUNTA EN CADA EJERCICIO, Y CON QUÉ UNIDAD
     ----------------------------------------------------------
     EL PROBLEMA
     La pantalla del atleta pedía «apuntar el tiempo» en TODOS los
     ejercicios. En una sentadilla nadie apunta un tiempo: apunta
     los kilos y las repeticiones que ha hecho. La pantalla daba
     por hecho que todo era atletismo.

     LA UNIDAD LA PONE EL SISTEMA, NO EL ATLETA
     Un número sin unidad no es un dato: dentro de seis meses,
     «200» no dice si eran metros, segundos o kilos. Nadie tiene
     que escribir la unidad ni elegirla de un desplegable: con el
     deporte del entrenamiento y lo que el entrenador escribió en
     la fila, ya se sabe.

     Y MANDA LO QUE ESCRIBIÓ EL ENTRENADOR, no el deporte. Un día
     puede ser de dos deportes (pesas y luego series), y una fila
     que pone «6 × 200 m» pide un tiempo aunque el entrenamiento
     esté marcado como fuerza. Se mira primero la fila, y el
     deporte solo decide cuando la fila no lo aclara.
     ========================================================== */

  /* Las tres cosas que un atleta puede apuntar de una serie. */
  var CAMPO_PESO = { k: 'peso', etiqueta: 'peso',  unidad: 'kg',  decimal: true,  ph: '60' };
  var CAMPO_REPS = { k: 'reps', etiqueta: 'reps',  unidad: 'rep', decimal: false, ph: '10' };
  var CAMPO_TIEMPO = { k: 'tiempo', etiqueta: 'tiempo', unidad: null, decimal: true, ph: '' };
  var CAMPO_DIST = { k: 'distancia', etiqueta: 'distancia', unidad: 'm', decimal: true, ph: '' };

  /* ==========================================================
     RIR · REPETICIONES EN RESERVA
     ----------------------------------------------------------
     Es CÓMO ESTE CLUB REGULA LA FUERZA. Su programa de ocho
     semanas lo lleva en todas partes y es el eje de la
     progresión: «semana 1 a RIR 3-4», «semanas 2-6 la mayoría a
     RIR 1-3», «semana 7 sin fallo en básicos», «semana 8 volver a
     RIR 3-4».

     NO ES EL RPE, y no se puede mezclar con él. El RPE dice lo
     duro que se te hizo (del 1 al 10, y ya está en la app). El
     RIR dice CUÁNTAS REPETICIONES TE QUEDABAN. Un entrenador de
     fuerza manda con el segundo: si el objetivo era RIR 2 y el
     atleta apunta RIR 0, se pasó; si apunta RIR 4, se quedó corto
     y toca subir peso.

     ⚠️ EL RIR VA AL REVÉS QUE EL ESFUERZO: más RIR es MÁS SUAVE
     (te sobraban repeticiones) y RIR 0 es el fallo. Quien lea
     estos números pensando que más es más duro los entenderá al
     revés.

     Se escribe como lo escriben ellos: «2», «RIR 2», «2-3»,
     «RIR 3-4», «sin fallo», «nada al fallo». Se guarda el texto
     tal cual en `fila.rir` y aquí se interpreta para pintarlo.
     ========================================================== */
  var RIR_SIN_FALLO = /\b(sin\s+fallo|nada\s+al\s+fallo|no\s+al\s+fallo|sin\s+llegar\s+al\s+fallo)\b/;

  function rirDeFila(fila) {
    if (!fila || fila.rir == null || String(fila.rir).trim() === '') return null;
    var crudo = String(fila.rir).trim();
    var t = quitarTildes(crudo.toLowerCase());
    if (RIR_SIN_FALLO.test(t)) return { sinFallo: true, min: null, max: null, texto: crudo };
    /* Un rango, que es como lo escriben la mitad de las veces. */
    var rango = t.match(/(\d+)\s*(?:-|–|—|\s+a\s+)\s*(\d+)/);
    if (rango) {
      var a = parseInt(rango[1], 10), b = parseInt(rango[2], 10);
      if (!isNaN(a) && !isNaN(b)) return { sinFallo: false, min: Math.min(a, b), max: Math.max(a, b), texto: crudo };
    }
    var uno = t.match(/(\d+)/);
    if (uno) {
      var n = parseInt(uno[1], 10);
      /* Más de 10 repeticiones en reserva no es una serie de fuerza: es un
         error de tecleo, y vale más no enseñar nada que enseñar «RIR 25». */
      if (!isNaN(n) && n >= 0 && n <= 10) return { sinFallo: false, min: n, max: n, texto: crudo };
    }
    /* No se entiende: se respeta tal cual, como con los descansos. Lo que
       escribe el entrenador se enseña, aunque el sistema no lo sepa leer. */
    return { sinFallo: false, min: null, max: null, texto: crudo };
  }

  /* «RIR 2» · «RIR 2-3» · «sin llegar al fallo» */
  function textoRir(rir) {
    if (!rir) return '';
    if (rir.sinFallo) return 'sin llegar al fallo';
    if (rir.min == null) return String(rir.texto || '');
    return 'RIR ' + (rir.min === rir.max ? rir.min : rir.min + '-' + rir.max);
  }

  /* ¿El RIR que apuntó el atleta cae dentro de lo que se le pidió?
     Devuelve 'dentro' · 'paso' (se pasó, menos reserva de la pedida) ·
     'corto' (le sobró) · null si no hay con qué comparar.
     No lo usa la pantalla del atleta: sirve para que el ENTRENADOR lea de
     un vistazo la semana y decida la siguiente. */
  function rirComparado(rirObjetivo, valor) {
    if (!rirObjetivo || valor == null || valor === '') return null;
    var v = numero(valor);
    if (isNaN(v)) return null;
    if (rirObjetivo.sinFallo) return v <= 0 ? 'paso' : 'dentro';
    if (rirObjetivo.min == null) return null;
    if (v < rirObjetivo.min) return 'paso';
    if (v > rirObjetivo.max) return 'corto';
    return 'dentro';
  }

  function esFuerza(dep) { return dep === 'fuerza' || dep === 'cubo'; }

  /* ¿La fila lleva carga escrita por el entrenador? «80% RM»,
     «con 20 kg», «disco de 10»: cualquier cosa con un número. */
  function llevaCarga(fila) {
    return !!(fila && fila.carga && /\d/.test(String(fila.carga)));
  }

  /* SALTOS, VALLAS Y SPRINTS: LO QUE NO LLEVA KILOS
     ----------------------------------------------------------
     El club lo dijo con estas palabras cuando pidió que El Cubo
     también apuntase kilos: «si hay alguno que no son kilos o que
     es diferente, porque son sprints o saltos a vallas, pues nada,
     ahí que no se ponga nada».

     Un sprint ya se resuelve solo: «30 m» lleva metros y entonces
     lo que se apunta es el tiempo. Pero «6 saltos» o «5 vallas» no
     llevan ni metros ni segundos, y sin esto caían en la regla de
     abajo del todo —«no lo aclara la fila, decide el deporte»— y
     acababan pidiendo kilos en un salto al cajón. Pedir kilos
     donde no hay kilos no es solo ruido: es un hueco vacío que
     invita a escribir un número inventado.

     Se mira lo que ESCRIBIÓ EL ENTRENADOR, no una lista de
     ejercicios: si él puso «saltos con carga» y además escribió la
     carga, entonces sí hay kilos que apuntar y esta regla se
     aparta. */
  var SIN_KILOS = /\b(salto|saltos|valla|vallas|minivalla|minivallas|sprint|sprints|multisalto|multisaltos|bounding|pliometr|escalera|escaleras|cajon|cuesta|cuestas|arrancada|arrancadas|salida|salidas)\b/;
  /* …salvo que el propio nombre diga que lleva peso. «Saltos con carga» y
     «Zancadas con lastre» son saltos, pero de esos SÍ se apuntan los kilos:
     lo dice el entrenador en el nombre, y manda él. */
  var CON_PESO = /\b(carga|cargas|lastre|lastres|lastrad\w*|con\s+peso|con\s+disco|con\s+barra|con\s+mancuerna\w*)\b/;

  /* CUÁNDO UNOS MINUTOS SÍ SON UNA DISTANCIA
     ----------------------------------------------------------
     Solo en un rodaje: el entrenador da los minutos y lo que
     aporta el atleta es cuánto recorrió. Los nombres salen del
     catálogo del club (los de tipo «continuo» y categoría
     «resistencia»): Continuo suave, Carrera en umbral, Carrera
     progresiva, Fartlek, Tempo, Trote suave.

     RECUPERA gana siempre, porque hay nombres que llevan las dos
     señales: «Trote de vuelta a la calma» es un trote, pero de
     esos no se apunta la distancia, se marca y ya. Estirar,
     rodar el foam, el masaje o el baño frío tampoco recorren
     metros. */
  /* «Trote» NO está aquí, y es a propósito. El entrenador lo dijo mirando su
     entrenamiento: «Trote suave es por tiempo». Un trote es un calentamiento
     o una vuelta a la calma —en el catálogo del club son justo eso—, y de
     esos no se apuntan metros: el entrenador ya ha dicho los minutos y lo
     único que aporta el atleta es que lo hizo. Un rodaje de verdad se llama
     «Continuo», «Carrera», «Tempo», «Fartlek» o «Rodaje». */
  var DE_RODAJE = /\b(rodaje|rodajes|continuo|continua|carrera|correr|tempo|fartlek|umbral|progresiv\w*|marcha|caminar|sendero)\b/;
  var RECUPERA  = /\b(calma|estiramiento|estiramientos|estirar|stretching|movilidad|foam|masaje|crioterapia|electro|recuperaci\w*|descarga|respiraci\w*|propiocep\w*)\b|ba(n|ñ)o\s+frio/;

  /* Qué se le pide al atleta en ESTA fila:

       peso_reps  →  «60 kg × 11»       (sentadilla, dominadas…)
       peso       →  «10 kg»            (plancha con disco 40 s: el
                                         tiempo lo manda el entrenador,
                                         lo que varía es el peso)
       tiempo     →  «68.2»             (6 × 400 m, 8 × 50 m)
       distancia  →  «12 km» / «800 m»  (un rodaje: el entrenador dice
                                         los minutos, el atleta cuánto hizo)

     `unidades` sale con dos valores solo cuando de verdad hay que
     poder elegir: en atletismo conviven «6 × 150 m» y «rodaje de
     12 km», y adivinarlo por el tamaño del número acertaría casi
     siempre y fallaría justo en los casos raros, que son los que
     se notan. Mejor que lo diga quien escribe. En fuerza y en
     natación no hay nada que elegir: kilos y metros, y punto.

     ------------------------------------------------------------
     Y ENCIMA DE TODO ESO, EL RIR, que viaja en la medida pero NO
     como un campo más de cada serie.

     ⚠️ SE PROBÓ POR SERIE Y NO CABE. Con kilos, repeticiones y RIR,
     la fila de una serie se sale de la tarjeta a 375 px: el «RIR»
     desaparece y el número se queda colgando: `apolana.css` lleva
     `overflow-x:hidden` y lo recorta sin que salte ninguna barra,
     así que ni siquiera se ve que falta algo. Los huecos del peso
     y de las repeticiones son de ancho fijo a propósito (para que
     el «kg» quede pegado al número) y no hay de dónde sacar sitio.

     Así que EL RIR ES POR EJERCICIO, que es además como se juzga:
     no se piensa serie a serie, se piensa «este ejercicio lo dejé
     a 2». Y sigue siendo por ejercicio y no por sesión, que es lo
     que pidió el club: el RIR de la sentadilla no es el del press
     banca.

     No se pide en `tiempo` ni en `distancia`: unas repeticiones en
     reserva en un 400 m no significan nada. Y en `hecho` tampoco,
     porque ahí no hay repeticiones que reservar. */
  function medidaDeFila(fila, opts) {
    /* «Solo marcar»: el entrenador ha dicho que en este ejercicio no se apunta
       nada —calentamiento, pliometría, core, movilidad—, solo se marca que se
       ha hecho. Así el atleta ve un ✓ y no una casilla pidiendo un tiempo que
       no existe. En la parte principal, donde sí hay series, no se pone y se
       apuntan los tiempos como siempre. */
    if (fila && fila.solo_marcar) {
      return { clave: 'hecho', campos: [], unidades: null, unidad: null, referencia: '' };
    }
    var med = medidaBase(fila, opts);
    var rir = rirDeFila(fila);
    if (rir && (med.clave === 'peso_reps' || med.clave === 'peso' || med.clave === 'reps')) {
      return {
        clave: med.clave, campos: med.campos, unidades: med.unidades,
        unidad: med.unidad, referencia: med.referencia, rir: rir
      };
    }
    return med;
  }

  function medidaBase(fila, opts) {
    opts = opts || {};
    var dep = (opts.deporte || '').toLowerCase();
    var med = medidaDeDistancia(fila && fila.distancia);
    var txt = quitarTildes(String((fila && fila.distancia) || '').toLowerCase());
    /* El nombre del ejercicio cuenta tanto como la casilla de la
       serie: en El Cubo la fila se llama «Saltos al cajón» y la
       serie pone «3 × 8 rep», y lo que dice que ahí no hay kilos
       es el nombre, no el «8 rep». */
    var nom = quitarTildes(String((fila && (fila.ejercicio || fila.nombre)) || '').toLowerCase());
    var hayReps = /\brep\b|\breps\b|\brepetici/.test(txt);
    var deSalto = !llevaCarga(fila) && !CON_PESO.test(nom)
                  && (SIN_KILOS.test(nom) || SIN_KILOS.test(txt));

    /* 0 · SALTOS, VALLAS Y SPRINTS SIN CARGA: aquí no hay kilos que
           apuntar y no se piden. Si la fila dice repeticiones, se
           apuntan las repeticiones; si no dice nada que se pueda
           contar, basta con el ✓ y se repite al lado lo que mandó
           el entrenador. Va lo PRIMERO porque manda sobre todo lo
           demás: un «8 rep» en unos saltos al cajón sigue sin
           llevar kilos.
           Ojo: un sprint escrito «30 m» ni siquiera llega hasta
           aquí, lo coge la regla 2 y pide el tiempo, que es lo que
           interesa de un sprint. */
    if (esFuerza(dep) && deSalto && !(med.metros > 0)) {
      if (hayReps || med.segundos <= 0) {
        return hayReps
          ? { clave: 'reps', campos: [CAMPO_REPS], unidades: null, unidad: 'rep',
              referencia: String((fila && fila.distancia) || '') }
          : { clave: 'hecho', campos: [], unidades: null, unidad: null,
              referencia: String((fila && fila.distancia) || '') };
      }
    }

    /* 1 · «12 rep», «3 rep»: lo dice la propia fila y no hay más que hablar. */
    if (hayReps) {
      return { clave: 'peso_reps', campos: [CAMPO_PESO, CAMPO_REPS], unidades: null, unidad: 'kg' };
    }

    /* 2 · La fila va en metros o kilómetros: se corre, y lo que se
           apunta es el tiempo. El «200 m» de al lado ya dice de qué
           distancia es ese tiempo. */
    if (med.metros > 0) {
      return { clave: 'tiempo', campos: [CAMPO_TIEMPO], unidades: null, unidad: null,
               referencia: String(fila.distancia || '') };
    }

    /* 3 · La fila va en tiempo («40 s», «8 min»). Lo que apunta el
           atleta depende de para qué: en sala, el peso que usó; a la
           calle, cuánto le dio tiempo a hacer. */
    if (med.segundos > 0) {
      if (esFuerza(dep)) {
        /* Con carga, el peso: en una plancha con disco el tiempo lo
           manda el entrenador y lo que cambia semana a semana es el
           disco. Sin carga —movilidad, respiración, estiramientos—
           no hay nada que apuntar y pedir kilos sería pedir un dato
           que no existe: basta con decir si se hizo. */
        if (llevaCarga(fila)) {
          return { clave: 'peso', campos: [CAMPO_PESO], unidades: null, unidad: 'kg' };
        }
        return { clave: 'hecho', campos: [], unidades: null, unidad: null,
                 referencia: String((fila && fila.distancia) || '') };
      }
      /* FUERA DE LA SALA, «15 min» TAMPOCO ES UNA DISTANCIA POR DEFECTO.
         ----------------------------------------------------------
         Esto pedía metros SIEMPRE que la fila fuera en minutos, y así
         «Vuelta a la calma post-competición · 15 min» y «Estiramientos
         estáticos · 10 min» salían con el conmutador m / km. Nadie
         recorre metros estirando: era pedir un dato que no existe, y
         encima uno que el entrenador no había pedido.

         La excepción de verdad es el RODAJE, y solo esa: ahí el
         entrenador da los minutos y lo que aporta el atleta es cuánto
         llegó a recorrer. Así que la distancia hay que GANÁRSELA con
         una señal en el nombre del ejercicio; sin señal, basta el ✓,
         igual que en la sala. Manda lo que escribió el entrenador.

         Y la señal de recuperación PISA a la de rodaje, porque hay
         nombres que llevan las dos: «Trote de vuelta a la calma» es un
         trote, pero de esos no se apunta la distancia. */
      var nomT = quitarTildes(String((fila && (fila.ejercicio || fila.nombre)) || '').toLowerCase());
      if (RECUPERA.test(nomT) || !DE_RODAJE.test(nomT)) {
        return { clave: 'hecho', campos: [], unidades: null, unidad: null,
                 referencia: String((fila && fila.distancia) || '') };
      }
      return { clave: 'distancia', campos: [CAMPO_DIST], unidades: ['m', 'km'], unidad: 'm' };
    }

    /* 4 · La fila no lo aclara: entonces sí decide el deporte del
           día. Los saltos y las vallas ya se han quedado arriba, en
           la regla 0. */
    if (esFuerza(dep)) return { clave: 'peso_reps', campos: [CAMPO_PESO, CAMPO_REPS], unidades: null, unidad: 'kg' };
    if (dep === 'natacion') return { clave: 'tiempo', campos: [CAMPO_TIEMPO], unidades: null, unidad: null };
    return { clave: 'tiempo', campos: [CAMPO_TIEMPO], unidades: null, unidad: null };
  }

  /* Una serie ya apuntada, escrita con su unidad pegada al número:
     «60 kg × 11», «12 km», «68.2». Pegada y no en la cabecera de la
     columna a propósito: en el móvil se hace scroll y la cabecera
     se pierde de vista, y entonces el número vuelve a quedarse sin
     unidad. */
  function textoSerieHecha(serie, medida) {
    if (!serie || !medida) return '';
    /* Un ejercicio que solo se marca no tiene número que enseñar: el
       dato es el ✓, y decirlo con palabras es más claro que un hueco. */
    if (medida.clave === 'hecho') return serie.hecha ? 'hecha' : '';
    var p = [];
    if (medida.clave === 'peso_reps' || medida.clave === 'peso' || medida.clave === 'reps') {
      if (serie.peso != null && serie.peso !== '') p.push(numTxt(serie.peso) + ' kg');
      if (serie.reps != null && serie.reps !== '') p.push(numTxt(serie.reps) + ' rep');
      var linea = p.join(' × ');
      /* «60 kg × 11 · RIR 2», que es como lo diría un entrenador en voz alta.
         Con punto medio y no con «×»: el RIR no multiplica nada, es otra cosa
         que se dice de la misma serie. */
      if (serie.rir != null && serie.rir !== '') {
        linea = (linea ? linea + ' · ' : '') + 'RIR ' + numTxt(serie.rir);
      }
      return linea;
    }
    if (medida.clave === 'distancia') {
      if (serie.distancia == null || serie.distancia === '') return '';
      return numTxt(serie.distancia) + ' ' + (serie.unidad || medida.unidad || 'm');
    }
    return serie.tiempo != null ? String(serie.tiempo) : '';
  }

  /* ==========================================================
     7 bis · EL PORCENTAJE DE PESO, QUE NO SE CALCULA COMO EL DE PISTA
     ----------------------------------------------------------
     ⚠️ ESTO ES LO MÁS FÁCIL DE HACER AL REVÉS DE TODO EL MÓDULO,
     y hacerlo al revés no da un error: da un número creíble.

       · EN PISTA el porcentaje es de ESFUERZO. Correr «al 85 %»
         es ir MÁS LENTO que tu mejor marca. Se DIVIDE:
         38,1 s / 0,85 = 44,8 s.
       · EN PESAS el porcentaje es de CARGA. Levantar «al 85 %» es
         levantar MENOS peso que tu máximo. Se MULTIPLICA:
         80 kg × 0,85 = 68 kg.

     Si en pesas se dividiera, un RM de 80 kg daría 94 kg al 85 %.
     Noventa y cuatro kilos es un peso de gimnasio perfectamente
     normal: nadie sospecharía, y alguien se pondría un 118 % de su
     máximo creyendo que hace una serie suave.

     De dónde sale el porcentaje: de lo que el entrenador escribió
     en la casilla de CARGA de la fila («80% RM», «70-80 % RM»).
     Ahí es donde lo pone el planificador y donde lo deja el
     importador de texto. Si no hay «RM» escrito, no se toca nada:
     un «80 %» suelto en una fila de correr es otra cosa.
     ========================================================== */

  /* Los porcentajes de RM de una fila, de menor a mayor.
     null si esa fila no habla de RM. */
  function pctsRMdeFila(fila) {
    if (!fila) return null;
    var txt = quitarTildes(String(fila.carga || '').toLowerCase());
    /* La casilla de ritmo también vale si allí escribieron el RM:
       el club tiene entrenamientos importados de años distintos y
       no todos usan la misma casilla. Lo que NO vale es un «85 %»
       sin la palabra RM al lado, porque eso en pista es otra cosa
       y calcularlo como carga sería inventarse un peso. */
    if (!/%\s*rm\b|\brm\s*\d{2,3}\s*%|\brm\b/.test(txt)) {
      txt = quitarTildes(String(fila.ritmo || '').toLowerCase());
      if (!/%\s*rm\b|\brm\b/.test(txt)) return null;
    }
    /* Un rango se escribe «70-80 % RM» y el símbolo va UNA vez, al
       final: buscando solo «número seguido de %» se perdería el 70
       y saldría un peso fijo donde el entrenador dio margen. */
    var crudos = [];
    txt.replace(/(\d{2,3})\s*[-–—a]\s*(\d{2,3})\s*%/g, function (_, a, b) {
      crudos.push(a); crudos.push(b); return '';
    });
    var sueltos = txt.match(/(\d{2,3})\s*%/g);
    if (sueltos) crudos = crudos.concat(sueltos);
    if (!crudos.length) return null;
    var nums = [];
    for (var i = 0; i < crudos.length; i++) {
      var n = parseFloat(crudos[i]);
      /* Por debajo del 30 % no se entrena la fuerza y por encima
         del 110 % no se levanta: un número fuera de ahí es un
         error de tecleo y vale más no enseñar nada. */
      if (n >= 30 && n <= 110 && nums.indexOf(n) === -1) nums.push(n);
    }
    if (!nums.length) return null;
    nums.sort(function (a, b) { return a - b; });
    return nums;
  }

  /* El peso que le toca a ESTE atleta. SE MULTIPLICA. */
  function pesoDesdeRM(rmKg, pct) {
    var rm = numero(rmKg), p = numero(pct);
    if (rm <= 0 || p <= 0) return null;
    var kg = rm * p / 100;
    /* Se redondea al medio kilo: en una barra no se pueden poner
       70,125 kg, y un número con tres decimales hace pensar que la
       cuenta es más fina de lo que es. */
    return Math.round(kg * 2) / 2;
  }

  /* «68 kg» · «60–68 kg», ya escrito para la pantalla. */
  function textoPesosRM(rmKg, pcts) {
    if (!pcts || !pcts.length) return '';
    var kgs = [], i;
    for (i = 0; i < pcts.length; i++) {
      var v = pesoDesdeRM(rmKg, pcts[i]);
      if (v == null) return '';
      kgs.push(v);
    }
    kgs.sort(function (a, b) { return a - b; });
    if (kgs.length === 1) return numTxt(kgs[0]) + ' kg';
    return numTxt(kgs[0]) + '–' + numTxt(kgs[kgs.length - 1]) + ' kg';
  }

  /* «85 %» · «70–80 %», los porcentajes tal como se leen. */
  function textoPctRM(pcts) {
    if (!pcts || !pcts.length) return '';
    return (pcts.length === 1 ? String(pcts[0]) : pcts[0] + '–' + pcts[pcts.length - 1]) + ' %';
  }

  /* ==========================================================
     8 · EL RESUMEN DE LA TARJETA, DEPORTE A DEPORTE
     ----------------------------------------------------------
     La tarjeta de inicio resumía un full body de ocho ejercicios
     como «3 × 10-12 rep · 2' recuperación». Eso es el PRIMER
     ejercicio, no el entrenamiento: con ocho ejercicios distintos,
     resumir por el primero engaña.

     Lo que resume de verdad no es lo mismo en cada deporte:

       · En FUERZA, el volumen y qué se trabaja. «8 ejercicios ·
         Tren superior y core» dice de qué va el día; la primera
         sentadilla no.
       · En ATLETISMO y NATACIÓN, la serie principal SÍ tiene
         sentido: un día de 6 × 800 se llama «6 × 800», y el resto
         es calentar y soltar.

     Y SI NO HAY UN RESUMEN HONESTO, NO SE PONE NINGUNO. Un hueco
     no engaña a nadie; un resumen que miente, sí.
     ========================================================== */

  /* Etiquetas de bloque que no dicen QUÉ se trabaja, solo CUÁNDO:
     no sirven para resumir de qué va el día. */
  var ETIQUETA_ESTRUCTURAL = /^(parte\s*(inicial|principal|final)?|bloque\s*\d*|calentamiento|vuelta a la calma|activacion|principal|inicial|final|soltar|estiramientos?)$/;

  function etiquetasDeTrabajo(bloques) {
    var out = [];
    (bloques || []).forEach(function (b) {
      var e = String((b && b.etiqueta) || '').trim();
      if (!e) return;
      if (ETIQUETA_ESTRUCTURAL.test(quitarTildes(e.toLowerCase()))) return;
      if (!(b.filas || []).length) return;
      if (out.indexOf(e) < 0) out.push(e);
    });
    return out;
  }

  function cuentaEjercicios(bloques) {
    var n = 0;
    (bloques || []).forEach(function (b) {
      (b.filas || []).forEach(function (f) { if (f && (f.ejercicio || f.nombre)) n++; });
    });
    return n;
  }

  function cuentaSeries(bloques) {
    var n = 0;
    (bloques || []).forEach(function (b) {
      (b.filas || []).forEach(function (f) {
        var s = parseInt(f && f.series, 10);
        if (s > 0 && s <= 30) n += s;
      });
    });
    return n;
  }

  /* La fila que manda en un día de correr o nadar: la del bloque
     principal que lleva series o ritmo. */
  function filaClave(bloques) {
    var principal = null;
    (bloques || []).forEach(function (b) { if (!principal && /principal/i.test(b.etiqueta || '')) principal = b; });
    var filas = [];
    (principal ? [principal] : (bloques || [])).forEach(function (b) {
      (b.filas || []).forEach(function (f) { filas.push(f); });
    });
    var f = null;
    filas.forEach(function (x) { if (!f && (x.series || x.ritmo)) f = x; });
    return f || filas[0] || null;
  }

  /* El resumen de una línea. Devuelve '' cuando no hay nada honesto
     que decir, y entonces la tarjeta no pinta resumen. */
  function resumenCorto(sesion, opts) {
    opts = opts || {};
    var bloques = (sesion && Array.isArray(sesion.bloques)) ? sesion.bloques : [];
    if (!bloques.length) return '';
    var dep = (opts.deporte || (sesion && sesion.deporte) || '').toLowerCase();
    var dis = opts.disciplina || disciplinaDe(sesion, opts.grupo);

    if (esFuerza(dep)) {
      var n = cuentaEjercicios(bloques);
      if (!n) return '';
      var p = [n === 1 ? '1 ejercicio' : n + ' ejercicios'];
      /* Las etiquetas las escribió el entrenador: «Tren superior y
         core», «Tobillo y pie». No se deducen de los nombres de los
         ejercicios, que sería inventar. Dos como mucho: la tercera
         ya no se lee. */
      etiquetasDeTrabajo(bloques).slice(0, 2).forEach(function (e) { p.push(e); });
      return p.join(' · ');
    }

    var f = filaClave(bloques);
    if (!f) return '';
    var linea = textoFila(f, dis);
    if (!linea) return '';
    return (f.ejercicio && dis !== 'cubo') ? f.ejercicio + ' · ' + linea : linea;
  }

  /* Los datos sueltos de la tarjeta, ya con su etiqueta: en fuerza,
     el volumen; en atletismo y natación, la serie que manda. */
  function cifrasDe(sesion, opts) {
    opts = opts || {};
    var bloques = (sesion && Array.isArray(sesion.bloques)) ? sesion.bloques : [];
    if (!bloques.length) return [];
    var dep = (opts.deporte || (sesion && sesion.deporte) || '').toLowerCase();
    var dis = opts.disciplina || disciplinaDe(sesion, opts.grupo);
    var out = [];

    if (esFuerza(dep)) {
      var ne = cuentaEjercicios(bloques), ns = cuentaSeries(bloques);
      if (ne) out.push({ v: String(ne), l: ne === 1 ? 'ejercicio' : 'ejercicios' });
      if (ns) out.push({ v: String(ns), l: ns === 1 ? 'serie' : 'series' });
      return out;
    }

    var f = filaClave(bloques);
    if (!f) return [];
    var serie = textoSerie(f, dis);
    /* ⚠️ «SERIES» SOLO SI LAS HAY. Un nado continuo de 1.200 m es UNA serie de
       1.200, y la tarjeta lo cantaba como «1200 · series», que se lee como mil
       doscientas series. Con una sola repetición lo que hay es una distancia,
       y así se dice. */
    if (serie) {
      var reps = parseInt(f.series, 10);
      out.push({ v: serie, l: (reps > 1 ? 'series' : (dis === 'natacion' ? 'metros' : 'distancia')) });
    }
    if (f.ritmo) out.push({ v: String(f.ritmo), l: 'ritmo' });
    var rec = textoRecPlano(recDeFila(f, dis), dis);
    if (rec) out.push({ v: rec, l: 'recuperación' });
    return out.slice(0, 3);
  }

  /* ==========================================================
     9 · AYUDAS SUELTAS
     ========================================================== */

  function numero(v) {
    if (v == null || v === '') return 0;
    var n = parseFloat(String(v).replace(',', '.'));
    return isNaN(n) ? 0 : n;
  }

  function quitarTildes(s) {
    return String(s).normalize ? String(s).normalize('NFD').replace(/[\u0300-\u036f]/g, '') : String(s);
  }

  /* ========================================================== */

  var API = {
    VERSION: VERSION,
    DISCIPLINAS: DISCIPLINAS,
    MODOS: MODOS,
    COLORES: COLORES,

    disciplinaDe: disciplinaDe,
    pideRec: pideRec,

    recDeFila: recDeFila,
    ponerRec: ponerRec,
    quitarRec: quitarRec,
    recEntreBloques: recEntreBloques,
    recEntreEjercicios: recEntreEjercicios,
    ponerRecEntreBloques: ponerRecEntreBloques,
    ponerRecEntreEjercicios: ponerRecEntreEjercicios,

    interpretarDescanso: interpretarDescanso,
    segundosDeTexto: segundosDeTexto,
    rangoDeTexto: rangoDeTexto,
    medidaDeDistancia: medidaDeDistancia,
    ritmoDeTexto: ritmoDeTexto,

    /* Qué se apunta en cada ejercicio y con qué unidad */
    medidaDeFila: medidaDeFila,
    textoSerieHecha: textoSerieHecha,

    /* RIR · repeticiones en reserva. OJO: más RIR es MÁS SUAVE */
    rirDeFila: rirDeFila,
    textoRir: textoRir,
    rirComparado: rirComparado,

    /* El % de RM: EN PESAS SE MULTIPLICA (ver el aviso de arriba) */
    pctsRMdeFila: pctsRMdeFila,
    pesoDesdeRM: pesoDesdeRM,
    textoPesosRM: textoPesosRM,
    textoPctRM: textoPctRM,

    /* El resumen honesto de la tarjeta */
    resumenCorto: resumenCorto,
    cifrasDe: cifrasDe,
    filaClave: filaClave,
    cuentaEjercicios: cuentaEjercicios,
    cuentaSeries: cuentaSeries,

    fmtSegundos: fmtSegundos,
    fmtSalida: fmtSalida,
    fmtMetros: fmtMetros,
    fmtDistancia: fmtDistancia,
    fmtDuracion: fmtDuracion,
    fmtEstimado: fmtEstimado,

    textoRec: textoRec,
    textoRecPlano: textoRecPlano,
    etiquetaNatacion: etiquetaNatacion,
    textoSerie: textoSerie,
    partesFila: partesFila,
    textoFila: textoFila,
    textoEntreBloques: textoEntreBloques,
    textoEntreEjercicios: textoEntreEjercicios,

    estimarFila: estimarFila,
    estimarBloque: estimarBloque,
    estimarSesion: estimarSesion,
    estimarPorCalles: estimarPorCalles,
    resumen: resumen
  };

  if (typeof window !== 'undefined') {
    window.APOLANA_DESCANSOS = API;
    window.Descansos = API;                 // atajo corto para las páginas
  }
  if (typeof module !== 'undefined' && module.exports) module.exports = API;
})();
