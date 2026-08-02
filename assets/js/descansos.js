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
      return { modo: 'distancia', segundos: null, metros: met, forma: forma, texto: rec.texto || null };
    }
    if (modo === 'salida' || modo === 'fijo' || modo === 'tiempo') {
      if (!(seg > 0)) return rec.texto ? interpretarDescanso(rec.texto, disciplina) : null;
      return { modo: modo, segundos: seg, metros: null, forma: forma, texto: rec.texto || null };
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

    /* Recuperación en metros: «200 m», «rec 200m», «vuelta de 300 m». */
    var mm = bajo.match(/(\d+(?:[.,]\d+)?)\s*(km|m)\b(?!in)/);
    if (mm && !/\bmin\b/.test(bajo)) {
      var met = parseFloat(mm[1].replace(',', '.')) * (mm[2] === 'km' ? 1000 : 1);
      if (met > 0) return { modo: 'distancia', segundos: null, metros: Math.round(met), forma: forma, texto: null };
    }

    var seg = segundosDeTexto(bajo);
    if (seg > 0) {
      var modo = (disciplina === 'natacion') ? 'fijo' : 'tiempo';
      return { modo: modo, segundos: seg, metros: null, forma: forma,
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

    /* Rango «3-4 min» / «2 a 3 min»: se toma el punto medio. */
    var rango = t.match(/(\d+(?:[.,]\d+)?)\s*(?:-|–|a)\s*(\d+(?:[.,]\d+)?)\s*(min|minutos|'|s|seg|segundos|")/);
    if (rango) {
      var a = parseFloat(rango[1].replace(',', '.')), b = parseFloat(rango[2].replace(',', '.'));
      var mult = /min|'/.test(rango[3]) ? 60 : 1;
      return Math.round(((a + b) / 2) * mult);
    }

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

    var seg = /\bmin\b|\bminutos?\b|\bseg\b|\bsegundos?\b|:|'|"/.test(t) ? segundosDeTexto(t) : null;
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
    if (r.modo === 'fijo')   return 'descanso ' + fmtSegundos(r.segundos);

    if (r.modo === 'bajada') {
      var comoBaja = r.forma && r.forma !== 'parado' ? r.forma : 'suave';
      return 'rec: bajada ' + comoBaja;
    }
    if (r.modo === 'texto') return 'rec ' + (r.texto || '');

    var etiq = (disciplina === 'cubo') ? 'desc. ' : 'rec ';
    if (r.modo === 'distancia') return etiq + fmtMetros(r.metros) + (r.forma ? ' ' + r.forma : '');
    if (r.modo === 'tiempo')    return etiq + fmtSegundos(r.segundos) + (r.forma ? ' ' + r.forma : '');
    return '';
  }

  /* Lo mismo pero sin la palabra de delante, para guardarlo en el
     campo de texto libre `descanso` de siempre (que las pantallas
     viejas ya pintan precedido de «rec» o «desc.»). */
  function textoRecPlano(rec, disciplina) {
    var r = normalizarRec(rec, disciplina);
    if (!r || r.modo === 'ninguna') return '';
    if (r.modo === 'salida')    return 'salida ' + fmtSalida(r.segundos);
    if (r.modo === 'fijo')      return fmtSegundos(r.segundos);
    if (r.modo === 'bajada')    return 'bajada ' + (r.forma && r.forma !== 'parado' ? r.forma : 'suave');
    if (r.modo === 'texto')     return r.texto || '';
    if (r.modo === 'distancia') return fmtMetros(r.metros) + (r.forma ? ' ' + r.forma : '');
    if (r.modo === 'tiempo')    return fmtSegundos(r.segundos) + (r.forma ? ' ' + r.forma : '');
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
     7 · AYUDAS SUELTAS
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
    medidaDeDistancia: medidaDeDistancia,
    ritmoDeTexto: ritmoDeTexto,

    fmtSegundos: fmtSegundos,
    fmtSalida: fmtSalida,
    fmtMetros: fmtMetros,
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
