/* ============================================================
   PÁGINA DE SECCIÓN · los datos los pone el club, no el HTML
   ------------------------------------------------------------
   CÓMO FUNCIONA, en corto:

     1. La página dice qué sección es:
            <main class="sec-pagina" data-seccion="montana">

     2. Al abrirla, este ayudante le pregunta a la base de datos
        por esa sección y escribe lo que le digan:

          · contenido_secciones → foto, antetítulo, título, frase,
                                  «servicios», «a qué te comprometes»,
                                  «qué incluye» y «qué traer»
          · grupos              → nombre, días y sede, qué se hace
                                  y las pruebas que se entrenan
          · tarifas_vigentes    → precio de cada grupo y la cuota
                                  de socio, que se dice aparte
          · contactos_publicos  → las cifras de quien entrena, y
                                  saber si hay alguien o no lo hay

     SIEMPRE la vista `contactos_publicos`, nunca la tabla
     `contactos`: la vista devuelve vacíos el teléfono y el correo
     que el club ha decidido no publicar; la tabla en crudo, no.

     3. Los huecos que rellena son siempre los mismos, en el mismo
        orden, en todas las secciones. Eso es la plantilla.

   POR QUÉ NO HAY PRECIOS NI HORARIOS ESCRITOS EN EL HTML:
   porque cambian cada temporada y no se puede depender de que
   alguien se acuerde de tocar ocho páginas. El club los cambia en
   el panel y salen aquí solos.

   QUÉ PASA SI FALTA UN DATO: se dice. «Todavía sin publicar», y
   nada más. Nunca un precio de ejemplo ni un horario inventado.
   Si es la base la que no contesta, se dice otra cosa distinta:
   que no se ha podido cargar, que no es lo mismo.

   Se carga con:
     <script src="…/assets/js/seccion.js" defer></script>
   después de db.js.
   ============================================================ */
(function () {
  'use strict';

  /* Los nombres propios del club van en ámbar. La lista es cerrada
     y la misma que documenta apolana.css: un nombre genérico
     («Montaña», «Triatlón») se queda en navy a propósito, porque
     enseña qué tiene identidad y qué es una categoría. */
  var NOMBRES_PROPIOS = [
    'La Tribu', 'Madre Tierra', 'El Cubo', 'Kilómetro Cero',
    'Vertical Apolana', 'Familia Apolana', 'Liga Apolana'
  ];

  /* Cómo se lee cada periodicidad de la base. */
  var PERIODO = {
    'mensual':     '/mes',
    'trimestral':  '/trimestre',
    'anual':       '/año',
    'temporada':   '/temporada',
    'semanal':     '/semana',
    'pago único':  ' (pago único)',
    'por sesión':  '/sesión',
    'bono':        ' (bono)'
  };

  function limpio(v) { return (v == null ? '' : String(v)).trim(); }

  /* Una lista escrita en el panel, un elemento por línea. Se admite
     también la barra vertical, porque hay fichas antiguas que la usan. */
  function lineas(txt) {
    return limpio(txt).split(/[\n|]/).map(limpio).filter(Boolean);
  }

  function esNombrePropio(nombre) {
    var n = limpio(nombre).toLowerCase();
    return NOMBRES_PROPIOS.some(function (p) { return p.toLowerCase() === n; });
  }

  function nodo(etiqueta, clase, texto) {
    var el = document.createElement(etiqueta);
    if (clase) el.className = clase;
    if (texto != null) el.textContent = texto;
    return el;
  }

  /* 40.00 → «40 €» · 40.5 → «40,50 €» (nunca «40.5 €»). */
  function euros(n) {
    var v = Number(n);
    if (!isFinite(v)) return '';
    var entero = Math.round(v * 100) % 100 === 0;
    return (entero ? String(Math.round(v)) : v.toFixed(2).replace('.', ',')) + ' €';
  }

  /* El importe de una tarifa, tal y como se lee en voz alta:
     «40 €/mes», «40-55 €/mes», «120 €/año» o el texto que haya
     escrito el club cuando no hay número. */
  function importeDe(t) {
    var desde = t.importe_socio, hasta = t.importe_socio_hasta;
    if (desde == null || desde === '') return { texto: limpio(t.texto_importe), esNumero: false };
    var cifra = euros(desde);
    if (hasta != null && hasta !== '' && Number(hasta) > Number(desde)) {
      cifra = euros(desde).replace(' €', '') + '-' + euros(hasta);
    }
    return { texto: cifra + (PERIODO[limpio(t.periodicidad)] || ''), esNumero: true };
  }

  /* «Running · Madre Tierra» en la página de Running es, simplemente,
     «Madre Tierra». El prefijo con el nombre de la sección sobra. */
  function conceptoCorto(concepto, titulo) {
    var c = limpio(concepto), t = limpio(titulo);
    if (!t) return c;
    /* Se prueba con el título entero («El Cubo · alquiler a grupos») y
       también con su primera palabra, porque en la base las tarifas de la
       escuela se llaman «Escuela · nacidos 2016 – 2023» y el título de la
       página es «Escuela de atletismo». Y con la última, porque las de
       pista se llaman «Pista · Velocidad A» y la página, «Atletismo en
       pista»: sin esto, el precio salía con el prefijo puesto. */
    var palabras = t.split(' ');
    var prefijos = [t, palabras[0], palabras[palabras.length - 1]];
    for (var i = 0; i < prefijos.length; i++) {
      var p = prefijos[i];
      if (!p || c.toLowerCase().indexOf(p.toLowerCase() + ' · ') !== 0) continue;
      var resto = c.slice(p.length + 3).trim();
      if (resto) return resto.charAt(0).toUpperCase() + resto.slice(1);
    }
    return c;
  }

  function vacio(texto) { return nodo('p', 'sec-vacio', texto); }

  /* «Cómo se llega a la sede»: una tarjeta con chincheta, coherente con el
     resto de tarjetas de la página (grupos, precio, «De un vistazo»). Antes
     era un recuadro crema plano y parecía un pegote. El estilo lo pone
     apolana.css (.sec-acceso); aquí solo se arma la caja con su icono. */
  function tarjetaAcceso(texto) {
    var caja = nodo('div', 'sec-acceso');
    var ic = nodo('span', 'ic');
    ic.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11z"/><circle cx="12" cy="10" r="2.6"/></svg>';
    caja.appendChild(ic);
    caja.appendChild(nodo('span', 'tx', texto));
    return caja;
  }

  /* Pone `url` en la imagen, pero solo cuando ya está descargada entera.
     Si nunca llega, la imagen se queda con la foto que trae el HTML. Es la
     misma idea que en imagenes-web.js; no se comparte porque cada archivo
     vive en su propio ámbito y una función de siete líneas no justifica
     inventar un sitio común. */
  function cuandoCargue(url, img) {
    var previa = new Image();
    previa.onload = function () { img.src = url; };
    previa.onerror = function () { /* se queda la del respaldo */ };
    previa.src = url;
    if (previa.complete && previa.naturalWidth) img.src = url;
  }

  /* ---------------------------------------------------------
     1 y 2 · Foto, antetítulo, título y frase
     --------------------------------------------------------- */
  function pintaCabecera(ficha) {
    if (!ficha) return;
    [['cs-eyebrow', ficha.dirigido_a], ['cs-titulo', ficha.titulo], ['cs-intro', ficha.descripcion]]
      .forEach(function (par) {
        var el = document.getElementById(par[0]);
        if (el && limpio(par[1])) el.textContent = limpio(par[1]);
      });

    /* La foto de la cabecera es #cs-hero-img en las páginas que la traen en
       su propio HTML, y .pag-hero-foto en las que usan la cabecera oscura
       compartida. Se busca la de siempre y, si no está, la de la cabecera:
       así vale para las dos formas sin tocar nada más. */
    var img = document.getElementById('cs-hero-img') || document.querySelector('.pag-hero-foto');
    if (!img) return;
    /* ⚠️ Se descarga por detrás antes de ponerla. Cambiar `src` a pelo vacía
       el hueco al instante y deja fuera la del respaldo, así que se veía la
       foto del HTML, luego un hueco, y luego la buena: tres estados para una
       sola foto. Andrés: «no me gusta eso de que entres a una página y esté
       cambiando fotos». Si la nueva no llega, no se toca nada y se queda la
       del HTML — que ahora es la misma, así que casi nunca hay nada que
       cambiar. Ver la nota de `cuandoCargue`. */
    if (limpio(ficha.imagen_url)) cuandoCargue(limpio(ficha.imagen_url), img);
    /* El encuadre lo elige el club en el panel; aquí no se decide nada. */
    if (limpio(ficha.imagen_encuadre)) {
      img.style.objectPosition = limpio(ficha.imagen_encuadre);
      img.style.transformOrigin = limpio(ficha.imagen_encuadre);
    }
    if (ficha.imagen_zoom > 1) img.style.transform = 'scale(' + ficha.imagen_zoom + ')';
  }

  /* ---------------------------------------------------------
     3 · De un vistazo · para quién, grupos, precio y cuota
     --------------------------------------------------------- */
  function fila(clave, valor, azul) {
    var f = nodo('div', 'fila');
    f.appendChild(nodo('span', 'k', clave));
    var v = nodo('span', 'v' + (azul ? ' v--azul' : ''));
    if (typeof valor === 'string') v.textContent = valor;
    else v.appendChild(valor);
    f.appendChild(v);
    return f;
  }

  function nombresDeGrupos(grupos) {
    var caja = document.createDocumentFragment();
    grupos.forEach(function (g, i) {
      if (i) caja.appendChild(document.createTextNode(i === grupos.length - 1 ? ' y ' : ', '));
      var s = nodo('span', esNombrePropio(g.nombre) ? 'nombre-propio' : null, limpio(g.nombre));
      caja.appendChild(s);
    });
    return caja;
  }

  function pintaVistazo(caja, datos) {
    var ancla = caja.querySelector('.eyebrow');
    var trozos = document.createDocumentFragment();

    /* «Para quién» no se repite aquí: ya lo dice el antetítulo, dos dedos
       más arriba. Cada cosa se dice una vez. */
    /* Hasta tres grupos caben con su nombre; de cuatro en adelante la fila
       se convierte en un párrafo y deja de ser «de un vistazo». Entonces
       se dice cuántos son y punto: los nombres están dos dedos más abajo. */
    if (datos.grupos.length && datos.grupos.length <= 3) {
      trozos.appendChild(fila(datos.grupos.length === 1 ? 'Grupo' : 'Grupos', nombresDeGrupos(datos.grupos)));
    } else if (datos.grupos.length) {
      trozos.appendChild(fila('Grupos', datos.grupos.length + ' grupos por nivel'));
    }

    /* Entrenamiento: el precio más bajo de la sección, o el texto que
       el club haya escrito cuando no hay número (por ejemplo, cuando
       la sección no tiene entrenador y por eso no tiene cuota). */
    var conNumero = datos.tarifas.filter(function (t) { return importeDe(t).esNumero; });
    if (conNumero.length) {
      var barato = conNumero.slice().sort(function (a, b) { return a.importe_socio - b.importe_socio; })[0];
      var texto = importeDe(barato).texto;
      trozos.appendChild(fila('Entrenamiento', (conNumero.length > 1 ? 'desde ' : '') + texto, true));
    } else if (datos.tarifas.length && limpio(datos.tarifas[0].texto_importe)) {
      trozos.appendChild(fila('Entrenamiento', limpio(datos.tarifas[0].texto_importe)));
    }

    if (datos.socio) {
      trozos.appendChild(fila('Cuota de socio', importeDe(datos.socio).texto));
    }

    /* La razón escrita, cuando la sección no tiene cuota de entrenamiento.
       Un «Consultar» parece un descuido y obliga a llamar; la razón se
       entiende y ya está. La escribe el club en las notas de la tarifa. */
    if (!conNumero.length && datos.tarifas.length && limpio(datos.tarifas[0].notas)) {
      trozos.appendChild(nodo('p', 'sec-nota', limpio(datos.tarifas[0].notas)));
    }

    /* Se cuelgan detrás del rótulo «De un vistazo», por delante de lo que
       ya trae el HTML (quién lleva la sección), que se queda el último. */
    if (ancla) ancla.after(trozos);
    else caja.appendChild(trozos);
  }

  /* ---------------------------------------------------------
     4 · Grupos · días, sede y qué se hace en cada uno
     --------------------------------------------------------- */
  /* «Nacidos en 2023», o «Nacidos en 2022 y 2023» cuando el club junta
     dos años en un grupo. En atletismo la edad va por año de nacimiento:
     cumplir años a mitad de curso no cambia a nadie de grupo, así que
     aquí no se calcula ninguna edad. */
  function aniosDeNacimiento(g) {
    var desde = parseInt(g.nacidos_desde, 10);
    var hasta = parseInt(g.nacidos_hasta, 10);
    if (isNaN(desde) && isNaN(hasta)) return '';
    if (isNaN(desde)) desde = hasta;
    if (isNaN(hasta)) hasta = desde;
    if (hasta < desde) { var x = desde; desde = hasta; hasta = x; }
    if (desde === hasta) return 'Nacidos en ' + desde;
    if (hasta - desde === 1) return 'Nacidos en ' + desde + ' y ' + hasta;
    return 'Nacidos de ' + desde + ' a ' + hasta;
  }

  /* La escuela tiene el mismo grupo dos veces: el «Azul 2» de lunes y
     miércoles y el «Azul 2» de martes y jueves. Por dentro son dos
     grupos distintos y tienen que serlo (los niños no son los mismos y
     cada uno pasa su lista), pero en la web serían dos tarjetas idénticas
     una encima de otra, con el mismo nombre, el mismo año y el mismo
     precio. Quien lee no entiende qué las diferencia y se pregunta si se
     ha equivocado de página.

     Así que se enseñan como una sola tarjeta que dice los dos días:
     «Azul 2 · lunes y miércoles o martes y jueves». Es una manera de
     enseñarlo, no un dato escrito a mano: los días siguen saliendo del
     turno de cada grupo.

     Solo se juntan si coinciden en todo lo demás. El día que el club
     escriba un horario distinto para cada turno —porque uno entrene a
     otra hora, por ejemplo— se separan solas en dos tarjetas, cada una
     con lo suyo. */
  /* Un horario del club se escribe siempre igual: primero los días, luego
     la hora y detrás del punto el sitio. «Lunes y miércoles 17:30-18:30 ·
     Estadio Joaquín Villar». Los dos turnos de un mismo grupo solo se
     diferencian en el trozo de delante, así que para poder juntarlos en
     una tarjeta hay que quedarse con lo de detrás: la hora y el sitio,
     que en los dos es lo mismo.

     Si después de quitar los días de delante todavía queda algún día
     suelto por el medio (un grupo que entrena martes y jueves y además
     los sábados, por ejemplo), esto devuelve vacío y el grupo se queda
     con su tarjeta entera. Más vale una tarjeta de más que un horario
     recortado por la mitad. */
  var RE_DIA_SUELTO = /(lunes|martes|mi[ée]rcoles|jueves|viernes|s[áa]bado|domingo)/i;
  var RE_DIAS_DELANTE = /^(?:\s|,|y\b|o\b|lunes|martes|mi[ée]rcoles|jueves|viernes|s[áa]bados?|domingos?)+/i;
  function horaYSitio(horario) {
    var t = limpio(horario);
    if (!t) return '';
    var resto = t.replace(RE_DIAS_DELANTE, '').trim();
    if (!resto || resto === t) return '';       // no empezaba por días: no se toca
    if (RE_DIA_SUELTO.test(resto)) return '';   // quedan más días detrás
    return resto;
  }

  function juntaTurnos(grupos) {
    var salida = [], vistos = {};
    grupos.forEach(function (g) {
      if (!g.turno) { salida.push(g); return; }
      /* Con horario escrito, dos turnos solo se juntan si la hora y el
         sitio salen limpios y coinciden. Si de un horario no se puede
         separar el «cuándo» del «dónde», ese grupo va por su cuenta: se
         le da su propio id como clave y así no se junta con nadie. */
      var resto = horaYSitio(g.horario);
      var comun = (!limpio(g.horario) || resto) ? resto : g.id;
      var clave = [limpio(g.nombre).toLowerCase(), g.nacidos_desde, g.nacidos_hasta,
                   comun, limpio(g.descripcion)].join('|');
      if (vistos[clave]) { vistos[clave].turnos.push(g.turno); return; }
      var copia = {};
      for (var k in g) { if (Object.prototype.hasOwnProperty.call(g, k)) copia[k] = g[k]; }
      copia.turnos = [g.turno];
      vistos[clave] = copia;
      salida.push(copia);
    });
    return salida;
  }

  /* ============================================================
     NUEVE TARJETAS QUE ERAN UNA TABLA
     ------------------------------------------------------------
     La escuela tiene un grupo por año de nacimiento: Rojo 1 (2023),
     Rojo 2 (2022)… hasta Verde 3 (2015). Nueve tarjetas con la misma
     hora, la misma sede y los mismos turnos, donde lo único que cambia
     es el año. Andrés: «no quiero ver todos los grupos de rojo 1,
     rojo 2, rojo 3… veo demasiada info que dice lo mismo. A la gente
     le da igual el nombre de los grupos: le importa al que irá su
     hijo». Eso no son nueve tarjetas, es UNA tabla de año → grupo.

     Solo se pliegan los que son de un único año y comparten días, hora,
     sitio, descripción y pruebas — y solo si salen tres o más, para que
     ninguna otra sección cambie por accidente. Si a un grupo se le pone
     una descripción propia, se descuelga solo de la tabla y vuelve a
     ser tarjeta: no se pierde nada en silencio. */
  function juntaAniosEnTabla(grupos) {
    var montones = {}, salida = [], puestos = {};
    grupos.forEach(function (g) {
      var d = parseInt(g.nacidos_desde, 10), h = parseInt(g.nacidos_hasta, 10);
      if (isNaN(d) || d !== h) return;
      var clave = [diasDeTurnos(g), horaYSitio(g.horario) || limpio(g.horario),
                   limpio(g.descripcion), limpio(g.pruebas)].join('|');
      (montones[clave] = montones[clave] || []).push(g);
    });
    var tablas = {};
    for (var k in montones) {
      if (montones[k].length < 3) continue;
      montones[k].forEach(function (g) { tablas[g.id] = k; });
    }
    var pintadas = {};
    grupos.forEach(function (g) {
      var k = tablas[g.id];
      if (!k) { salida.push(g); return; }
      /* La cabecera nace ya con la lista COMPLETA de su montón: los demás
         del mismo montón solo se saltan. (Aquí hubo un push de más y cada
         año salía dos veces en la tabla: una vez por venir en la lista y
         otra por añadirse al pasar. Se vio contando filas en pantalla.) */
      if (pintadas[k]) return;
      var lista = montones[k].slice().sort(function (a, b) {
        /* Del año más reciente al más antiguo: el padre del pequeño es el
           que llega nuevo y busca; el del mayor ya sabe cómo va esto. */
        return parseInt(b.nacidos_desde, 10) - parseInt(a.nacidos_desde, 10);
      });
      var cabeza = {};
      for (var c in g) { if (Object.prototype.hasOwnProperty.call(g, c)) cabeza[c] = g[c]; }
      cabeza.nombre = 'Un grupo por cada año';
      cabeza.nacidos_desde = lista[lista.length - 1].nacidos_desde;
      cabeza.nacidos_hasta = lista[0].nacidos_hasta;
      cabeza.tabla = lista;
      pintadas[k] = cabeza;
      salida.push(cabeza);
    });
    return salida;
  }

  /* Los días de un grupo: «Lunes y miércoles o martes y jueves». Vacío
     en las secciones de mayores, donde no hay turnos.

     Siempre en el orden de la semana, y no en el que vengan de la base:
     si una tarjeta empieza por el lunes y la de abajo por el martes,
     quien las lee se para a comparar creyendo que dicen cosas distintas
     cuando dicen la misma. */
  var ORDEN_TURNOS = ['lunes-miercoles', 'martes-jueves'];
  function diasDeTurnos(g) {
    var dias = (g.turnos || (g.turno ? [g.turno] : []))
      .slice()
      .sort(function (a, b) { return ORDEN_TURNOS.indexOf(a) - ORDEN_TURNOS.indexOf(b); })
      .map(function (t) { return window.APOLANA_TURNO ? window.APOLANA_TURNO(t) : ''; })
      .filter(function (t) { return !!t; });
    if (!dias.length) return '';
    var texto = dias.join(' o ');
    return texto.charAt(0).toUpperCase() + texto.slice(1);
  }

  /* Qué tarifa le corresponde a un grupo. Primero se mira si el club la
     ha colgado del grupo en Panel → Tarifas: eso es una decisión escrita
     y no se discute. Solo si no lo está se recurre a que los nombres
     cuadren, que es como funcionaba antes y falla en cuanto alguien
     renombra un grupo. */
  function tarifaDelGrupo(grupo, tarifas, titulo) {
    if (grupo.id) {
      var atada = tarifas.filter(function (t) { return t.grupo_id === grupo.id; })[0];
      if (atada) return atada;
    }
    var n = limpio(grupo.nombre).toLowerCase();
    return tarifas.filter(function (t) {
      return conceptoCorto(t.concepto, titulo).toLowerCase() === n;
    })[0] || null;
  }

  /* ============================================================
     ESCUELA · vista específica (NO toca el resto de secciones)
     ------------------------------------------------------------
     Andrés (sep 2026): en la escuela la familia no quiere ver todos
     los grupos, quiere el de SU hijo. Filtro por banda de edad
     (primera hora / segunda hora) → horario + grupo. Y las cuotas,
     en tarjetas. Solo se usa cuando datos.esEscuela es true.
     ============================================================ */
  function colorEscuela(nombre) {
    var n = limpio(nombre).toLowerCase();
    if (/\brojo\b/.test(n)) return 'rojo';
    if (/\bazul\b/.test(n)) return 'azul';
    if (/\bverde\b/.test(n)) return 'verde';
    return 'azul';
  }
  function partesHorario(h) {
    h = limpio(h);
    if (!h) return null;
    var trozos = h.split(' · ');
    var sede = '';
    if (trozos.length > 1 && /estadio|sede|pista|pabell|piscina|polideport/i.test(trozos[trozos.length - 1])) {
      sede = trozos.pop();
    }
    var cuerpo = trozos.join(' · ');
    var m = cuerpo.match(/^([^\d]*?)([\d].*)$/);
    var dias = m ? limpio(m[1]).replace(/[·\-–\s]+$/, '') : cuerpo;
    var hora = m ? limpio(m[2]) : '';
    return { dias: dias || cuerpo, hora: hora, sede: sede };
  }
  function tarjetaHorario(p, clase) {
    var c = nodo('div', clase || 'eg-hor');
    c.appendChild(nodo('b', null, p.dias));
    if (p.hora) c.appendChild(nodo('span', 'hh', p.hora));
    if (p.sede) c.appendChild(nodo('small', null, p.sede));
    return c;
  }
  function horariosUnicos(grupos) {
    var vistos = {}, out = [];
    grupos.forEach(function (g) {
      var p = partesHorario(g.horario);
      if (!p) return;
      var k = (p.dias + '|' + p.hora).toLowerCase();
      if (vistos[k]) return; vistos[k] = 1; out.push(p);
    });
    return out;
  }
  function pintaGruposEscuela(caja, datos) {
    caja.textContent = '';
    var raw = datos.gruposRaw || [];
    if (!raw.length) { caja.appendChild(vacio('Todavía no hay grupos publicados.')); return; }

    var esB1 = function (g) { return g.nacidos_desde && g.nacidos_desde >= 2015; };
    var b1 = raw.filter(esB1);
    var b2 = raw.filter(function (g) { return !esB1(g); });

    function rango(gr) {
      var a = [];
      gr.forEach(function (g) {
        if (g.nacidos_desde) a.push(g.nacidos_desde);
        if (g.nacidos_hasta) a.push(g.nacidos_hasta);
      });
      if (!a.length) return '';
      return Math.max.apply(null, a) + ' – ' + Math.min.apply(null, a);
    }

    var wrap = nodo('div', 'eg');
    var sel = nodo('div', 'eg-bandas');
    var btn1 = nodo('button', 'eg-banda on'); btn1.type = 'button';
    btn1.appendChild(nodo('span', 'et', 'Primera hora'));
    btn1.appendChild(nodo('span', 'an', rango(b1) || '2023 – 2015'));
    /* Fuera «Los pequeños» / «Los mayores»: Andrés no los quiere en las
       tarjetas de primera y segunda hora. Se queda el rótulo y el rango de años. */
    var btn2 = nodo('button', 'eg-banda'); btn2.type = 'button';
    btn2.appendChild(nodo('span', 'et', 'Segunda hora'));
    btn2.appendChild(nodo('span', 'an', rango(b2) || '2014 – 2009'));
    sel.appendChild(btn1); sel.appendChild(btn2);
    wrap.appendChild(sel);

    // Panel 1 · pequeños
    var p1 = nodo('div', 'eg-panel');
    if (horariosUnicos(b1).length) {
      p1.appendChild(nodo('p', 'eg-rot', 'Cuándo entrenan'));
      var h1 = nodo('div', 'eg-horarios');
      horariosUnicos(b1).forEach(function (p) { h1.appendChild(tarjetaHorario(p)); });
      p1.appendChild(h1);
    }
    /* "Tu grupo según el año" se quitó a propósito (Andrés, sep 2026): el
       grupo se lo dice el club a cada familia al inscribirse, no hace falta
       la tabla año→grupo en la web. La banda de pequeños deja solo el horario. */
    wrap.appendChild(p1);

    // Panel 2 · mayores
    var p2 = nodo('div', 'eg-panel'); p2.hidden = true;
    var hor2 = horariosUnicos(b2);
    if (hor2.length) {
      p2.appendChild(nodo('p', 'eg-rot', 'Cuándo entrenan'));
      var h2 = nodo('div', 'eg-horarios');
      hor2.forEach(function (p) { h2.appendChild(tarjetaHorario(p, 'eg-hor eg-hor--verde')); });
      p2.appendChild(h2);
    }
    var hayRecre = b2.some(function (g) { return /recreac/i.test(g.nombre); });
    var hayCompe = b2.some(function (g) { return /competic/i.test(g.nombre); });
    if (hayRecre || hayCompe) {
      p2.appendChild(nodo('p', 'eg-rot', 'Elige tu grupo'));
      var gs = nodo('div', 'eg-grupos');
      if (hayRecre) {
        var r = nodo('div', 'eg-gru eg-azul');
        r.appendChild(nodo('h4', null, 'Recreación'));
        r.appendChild(nodo('p', null, 'Para disfrutar del atletismo y mejorar, sin la exigencia de competir.'));
        gs.appendChild(r);
      }
      if (hayCompe) {
        var cc = nodo('div', 'eg-gru eg-rojo');
        cc.appendChild(nodo('h4', null, 'Competición'));
        cc.appendChild(nodo('p', null, 'Para quien quiere competir federado, con planificación por pruebas.'));
        gs.appendChild(cc);
      }
      p2.appendChild(gs);
    }
    wrap.appendChild(p2);

    var acceso = limpio(datos.ficha && datos.ficha.acceso);
    if (acceso) wrap.appendChild(tarjetaAcceso(acceso));
    caja.appendChild(wrap);

    function ver(n) {
      btn1.classList.toggle('on', n === 1);
      btn2.classList.toggle('on', n === 2);
      p1.hidden = n !== 1; p2.hidden = n !== 2;
    }
    btn1.addEventListener('click', function () { ver(1); });
    btn2.addEventListener('click', function () { ver(2); });
  }

  function pintaCuotasEscuela(caja, datos) {
    caja.textContent = '';
    var tarifas = (datos.tarifas || []).slice();
    if (!tarifas.length) { caja.appendChild(vacio('El precio todavía no está publicado. Escríbenos y te lo decimos.')); return; }

    var grid = nodo('div', 'ec-bandas');
    var condiciones = '';
    var colores = ['rojo', 'azul', 'verde', 'azul', 'rojo'];
    tarifas.forEach(function (t, i) {
      var card = nodo('div', 'ec-bc ec-' + (colores[i] || 'azul'));
      if (t.id) { card.setAttribute('data-editable-tarifa', t.id); card._apoTarifa = t; }
      var et = conceptoCorto(t.concepto, datos.ficha && datos.ficha.titulo).replace(/^escuela\s*·?\s*/i, '');
      card.appendChild(nodo('span', 'et', et));
      var pr = nodo('div', 'precio');
      pr.appendChild(nodo('span', 'n', euros(t.importe_socio)));
      pr.appendChild(nodo('span', 'u', '/ temporada'));
      card.appendChild(pr);
      var m = limpio(t.notas).match(/dos pagos:\s*([\d.,]+)\s*€\s*al inscribirse\s*y\s*([\d.,]+)\s*€\s*en diciembre\.?\s*(.*)$/i);
      if (m) {
        var pagos = nodo('div', 'pagos');
        pagos.appendChild(nodo('span', 'lb', 'Dos pagos'));
        var l1 = nodo('div', null); l1.appendChild(nodo('b', null, m[1] + ' €')); l1.appendChild(document.createTextNode(' al inscribirse'));
        var l2 = nodo('div', null); l2.appendChild(nodo('b', null, m[2] + ' €')); l2.appendChild(document.createTextNode(' en diciembre'));
        pagos.appendChild(l1); pagos.appendChild(l2);
        card.appendChild(pagos);
        if (!condiciones && m[3]) condiciones = limpio(m[3]);
      }
      grid.appendChild(card);
    });
    caja.appendChild(grid);

    if (condiciones) {
      caja.appendChild(nodo('p', 'eg-rot', 'Lo que hay que saber'));
      var cond = nodo('div', 'ec-cond');
      condiciones.split(/\.\s+/).map(limpio).filter(Boolean).forEach(function (frase) {
        var cd = nodo('div', 'ec-cd');
        cd.appendChild(nodo('p', null, frase.replace(/\.$/, '')));
        cond.appendChild(cd);
      });
      caja.appendChild(cond);
    }

    var nota = limpio(datos.ficha && datos.ficha.precio);
    if (nota) {
      var av = nodo('div', 'ec-avisos');
      lineas(nota).forEach(function (linea) { av.appendChild(nodo('div', 'ec-av', linea)); });
      caja.appendChild(av);
    }
  }

  function pintaGrupos(caja, datos) {
    if (datos.esEscuela) { pintaGruposEscuela(caja, datos); return; }
    caja.textContent = '';
    if (!datos.grupos.length) {
      caja.appendChild(vacio('Todavía no hay grupos publicados en esta sección.'));
      return;
    }
    var lista = nodo('div', 'sec-grupos__lista');
    datos.grupos.forEach(function (g) {
      var t = nodo('article', 'sec-grupo');
      /* Para el editor de la página: qué fila de `grupos` es esta tarjeta.
         La tarjeta-resumen de la escuela (g.tabla) no es un registro suelto,
         así que esa no se marca. El editor lee `_apoGrupo` al encenderse. */
      if (g.id && !g.tabla) { t.setAttribute('data-editable-grupo', g.id); t._apoGrupo = g; }
      var cab = nodo('div', 'cab');
      cab.appendChild(nodo('span', 'nombre' + (esNombrePropio(g.nombre) ? ' nombre-propio' : ''), limpio(g.nombre)));
      /* Solo se pone el precio si es un número. Cuando la sección no tiene
         cuota, la razón ya está escrita arriba: no hace falta repetirla en
         cada tarjeta. */
      var tar = tarifaDelGrupo(g, datos.tarifas, datos.ficha && datos.ficha.titulo);
      if (tar && importeDe(tar).esNumero) cab.appendChild(nodo('span', 'precio', importeDe(tar).texto));
      t.appendChild(cab);

      /* El año de nacimiento de los grupos de la escuela. Para un padre
         es el dato que decide: «Rojo 1» no le dice nada, «nacidos en
         2023» sí. Va antes que los días porque es lo primero que se
         busca. En las secciones de adultos el campo está vacío y aquí
         no aparece nada. */
      var anos = aniosDeNacimiento(g);
      if (anos) t.appendChild(nodo('span', 'nacidos', anos));

      /* Cuándo entrena. En una tarjeta que vale para los dos turnos, los
         días los ponen los turnos y la hora y el sitio salen del horario
         que ha escrito el club: «Lunes y miércoles o martes y jueves
         17:30-18:30 · Estadio Joaquín Villar». En los grupos que no se
         desdoblan manda el horario tal cual, que ya lo dice todo. Y si no
         hay nada escrito, se dice que falta: un hueco mudo parece un
         error de la página. */
      var dias = diasDeTurnos(g);
      var resto = horaYSitio(g.horario);
      var cuando = (dias && resto) ? (dias + ' ' + resto)
                                   : (limpio(g.horario) || dias);
      if (cuando) t.appendChild(nodo('span', 'cuando', cuando));
      else t.appendChild(nodo('span', 'cuando sec-vacio', 'Días y sede, todavía sin publicar'));

      if (limpio(g.descripcion)) t.appendChild(nodo('p', 'que', limpio(g.descripcion)));

      /* La tabla de año → grupo, cuando la tarjeta resume varios. El año va
         primero y en firme; el nombre del grupo, detrás y en suave: es lo
         que se dice en la pista («los Rojo 1, a la recta»), pero no es el
         dato con el que un padre decide. */
      if (g.tabla) {
        var filasT = nodo('div', 'sec-anios');
        g.tabla.forEach(function (x) {
          var fila = nodo('span', 'sec-anio');
          fila.appendChild(nodo('b', null, String(x.nacidos_desde)));
          fila.appendChild(nodo('span', null, limpio(x.nombre)));
          filasT.appendChild(fila);
        });
        t.appendChild(filasT);
      }

      /* Las pruebas que entrena el grupo, en pastillas. Es lo que hace que
         «Velocidad A» signifique algo para quien no es del mundillo. Lo
         escribe el club en Panel → Grupos; vacío, no sale nada. */
      var pruebas = lineas(g.pruebas);
      if (pruebas.length) {
        var chips = nodo('div', 'sec-chips');
        pruebas.forEach(function (p) { chips.appendChild(nodo('span', 'chip', p)); });
        t.appendChild(chips);
      }

      lista.appendChild(t);
    });
    caja.appendChild(lista);

    /* Cómo se entra a la sede. Va una sola vez, debajo de todos los
       grupos, porque es igual para todos: repetirlo en cada tarjeta
       cargaría justo lo que hay que leer de un vistazo (qué grupo le
       toca a mi hijo y cuándo). Lo escribe el club en Panel → Páginas,
       casilla «Cómo se llega»; vacía, no aparece nada. */
    var acceso = limpio(datos.ficha && datos.ficha.acceso);
    if (acceso) caja.appendChild(tarjetaAcceso(acceso));
  }

  /* ---------------------------------------------------------
     5 · Precio · cada tarifa y la cuota de socio, sumada aparte
     --------------------------------------------------------- */
  function pintaPrecio(caja, datos) {
    if (datos.esEscuela) { pintaCuotasEscuela(caja, datos); return; }
    caja.textContent = '';
    var titulo = datos.ficha && datos.ficha.titulo;

    /* ¿Esta sección tiene algún precio con números? Si no lo tiene, la nota
       de la tarifa es la razón por la que no lo hay, y esa razón ya está
       escrita arriba, en «De un vistazo»: aquí sonaría a repetición. */
    var hayNumero = datos.tarifas.some(function (t) { return importeDe(t).esNumero; });

    /* Cuando todas las tarifas repiten la MISMA nota («recibo domiciliado
       del 1 al 5»), se dice una vez debajo de la tabla y no tres veces
       seguidas, que es como se lee en un contrato y no en una web. */
    var notas = datos.tarifas.map(function (t) { return limpio(t.notas); });
    var notaComun = (datos.tarifas.length > 1 && notas[0] && notas.every(function (n) { return n === notas[0]; }))
      ? notas[0] : '';

    /* La cabecera «Precio» de la sección se mete DENTRO de la tarjeta (maqueta
       A, aprobada) y se esconde la de fuera para no duplicarla. */
    var cabFuera = caja.parentNode ? caja.parentNode.querySelector('.sec-cab') : null;
    var tituloTxt = 'Precio', notaTxt = 'Lo que se paga, sin letra pequeña';
    if (cabFuera) {
      var _h = cabFuera.querySelector('h2'); if (_h && limpio(_h.textContent)) tituloTxt = limpio(_h.textContent);
      var _n = cabFuera.querySelector('.nota'); if (_n && limpio(_n.textContent)) notaTxt = limpio(_n.textContent);
      cabFuera.style.display = 'none';
    }

    /* Una cifra «40-60 €» con su periodo («al mes») debajo, en pequeño. */
    function cifra(texto, esNumero, tenue, etiqueta) {
      var span = nodo('span', 'sp-val' + (tenue ? ' ns' : '') + (esNumero ? '' : ' tenue'));
      if (etiqueta) span.setAttribute('data-et', etiqueta);   /* en móvil se enseña como rótulo */
      var m = esNumero ? String(texto).match(/^(.*?€)\s*\/?\s*(mes|año|temporada|semana|clase)?/i) : null;
      if (m) {
        span.appendChild(document.createTextNode(m[1]));
        var per = (m[2] || '').toLowerCase();
        var pt = per === 'mes' ? 'al mes' : per === 'año' ? 'al año' : per === 'temporada' ? 'por temporada'
               : per === 'semana' ? 'a la semana' : per === 'clase' ? 'por clase' : '';
        if (pt) span.appendChild(nodo('small', null, pt));
      } else { span.textContent = texto; }
      return span;
    }

    var tarjeta = nodo('div', 'sp-precio');
    var cb = nodo('div', 'sp-cab');
    cb.appendChild(nodo('h2', null, tituloTxt));
    cb.appendChild(nodo('span', 'n', notaTxt));
    tarjeta.appendChild(cb);

    if (!datos.tarifas.length) {
      tarjeta.appendChild(vacio('El precio de esta sección todavía no está publicado. Escríbenos y te lo decimos.'));
    } else {
      var hayNoSocio = datos.tarifas.some(function (t) { return t.importe_no_socio != null && t.importe_no_socio !== ''; });
      var tp = nodo('div', 'sp-tp ' + (hayNoSocio ? 'tres' : 'dos'));
      var enc = nodo('div', 'sp-fila sp-enc');
      enc.appendChild(nodo('span', null, 'Si entrenas en…'));
      enc.appendChild(nodo('span', null, hayNoSocio ? 'Socio' : 'Precio'));
      if (hayNoSocio) enc.appendChild(nodo('span', null, 'No socio'));
      tp.appendChild(enc);

      datos.tarifas.forEach(function (t) {
        var f = nodo('div', 'sp-fila');
        if (t.id) { f.setAttribute('data-editable-tarifa', t.id); f._apoTarifa = t; }
        var concepto = nodo('span', 'sp-concepto', conceptoCorto(t.concepto, titulo));
        var dias = limpio(t.dias);
        if (dias) concepto.appendChild(nodo('small', null, dias));
        f.appendChild(concepto);

        var imp = importeDe(t);
        f.appendChild(cifra(imp.texto || 'Sin publicar', imp.esNumero, false, hayNoSocio ? 'Socio' : 'Precio'));

        if (hayNoSocio) {
          if (t.importe_no_socio != null && t.importe_no_socio !== '') {
            var cifraNS = euros(t.importe_no_socio);
            if (t.importe_no_socio_hasta != null && t.importe_no_socio_hasta !== ''
                && Number(t.importe_no_socio_hasta) > Number(t.importe_no_socio)) {
              cifraNS = euros(t.importe_no_socio).replace(' €', '') + '-' + euros(t.importe_no_socio_hasta);
            }
            f.appendChild(cifra(cifraNS + (PERIODO[limpio(t.periodicidad)] || ''), true, true, 'No socio'));
          } else {
            f.appendChild(cifra('—', false, true, 'No socio'));
          }
        }
        tp.appendChild(f);
      });
      tarjeta.appendChild(tp);
    }

    /* Cuota de socio: su propia tarjeta dentro del bloque (maqueta A). */
    if (datos.socio) {
      var cuota = nodo('div', 'sp-cuota');
      var ic = nodo('span', 'ic');
      ic.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="5" width="20" height="14" rx="2.5"/><path d="M2 10h20"/></svg>';
      cuota.appendChild(ic);
      var tx = nodo('span', 'tx');
      tx.appendChild(nodo('b', null, hayNumero ? 'Cuota de socio · una vez al año' : 'Solo la cuota de socio'));
      var subCuota = 'A partir del segundo año, 110 €. Se cobra en noviembre.';
      if (limpio(datos.socio.notas)) subCuota = 'A partir del segundo año, 110 €. ' + limpio(datos.socio.notas);
      tx.appendChild(nodo('small', null, subCuota));
      cuota.appendChild(tx);
      cuota.appendChild(nodo('span', 'imp', importeDe(datos.socio).texto));
      tarjeta.appendChild(cuota);
    }

    /* Notas al pie: la común de las tarifas, la letra pequeña de la sección y
       —solo en atletismo en pista— la franja de edad. */
    var pies = [];
    if (notaComun) pies.push(notaComun);
    var elSec = document.querySelector('[data-seccion]');
    if (datos.socio && elSec && elSec.getAttribute('data-seccion') === 'competicion') {
      pies.push('Desde 2008 en adelante (año de nacimiento).');
    }
    var notaSec = limpio(datos.ficha && datos.ficha.precio);
    if (notaSec) lineas(notaSec).forEach(function (l) { pies.push(l); });
    if (pies.length) {
      var nz = nodo('div', 'sp-notas');
      pies.forEach(function (p) { nz.appendChild(nodo('p', null, p)); });
      tarjeta.appendChild(nz);
    }

    caja.appendChild(tarjeta);
  }

  /* ---------------------------------------------------------
     5 y 6 · Servicios · y a qué te comprometes
     ------------------------------------------------------------
     Las dos mitades del trato: lo que pone el club y lo que pone
     el atleta. Las dos listas las escribe el club en Panel →
     Páginas, una cosa por línea.

     Los dos bloques NACEN ESCONDIDOS en el HTML y solo aparecen si
     hay algo escrito. Así, si la base no contesta, no se queda un
     título con el hueco debajo: sencillamente no hay bloque. Es lo
     mismo que hacen «Qué incluye» y «Quién entrena».
     --------------------------------------------------------- */
  function bloqueSuelto(caja, selector, texto, dibuja) {
    var bloque = caja.closest(selector);
    var puntos = lineas(texto);
    if (!puntos.length) { if (bloque) bloque.hidden = true; return; }
    caja.textContent = '';
    dibuja(caja, puntos);
    if (bloque) bloque.hidden = false;
  }

  function pintaServicios(caja, ficha) {
    bloqueSuelto(caja, '.sec-servicios', ficha && ficha.servicios, function (c, puntos) {
      var lista = nodo('ul', 'sec-servicios__lista');
      puntos.forEach(function (p) {
        var li = nodo('li', 'sec-servicio');
        var m = nodo('span', 'marca', '✓');
        m.setAttribute('aria-hidden', 'true');
        li.appendChild(m);
        li.appendChild(nodo('span', 'texto', p));
        lista.appendChild(li);
      });
      c.appendChild(lista);
    });
  }

  function pintaCompromiso(caja, ficha) {
    bloqueSuelto(caja, '.sec-compromiso', ficha && ficha.compromisos, function (c, puntos) {
      var lista = nodo('ul', 'sec-compromiso__caja');
      puntos.forEach(function (p) {
        lista.appendChild(nodo('li', 'sec-compromiso__punto', p));
      });
      c.appendChild(lista);
    });
  }

  /* ---------------------------------------------------------
     8 · Qué incluye
     --------------------------------------------------------- */
  function listaDePuntos(titulo, puntos, marca, campo) {
    var col = nodo('div', 'sec-banda__col');
    /* De qué columna de la base sale esta columna de la pantalla. Lo usa el
       editor de la página: las dos listas viven dentro del mismo recuadro
       (#cs-incluye) y sin esto no hay forma de saber cuál es cuál. */
    if (campo) col.setAttribute('data-campo', campo);
    col.appendChild(nodo('h2', 'titulo titulo--grande', titulo));
    var lista = nodo('div', 'sec-banda__lista');
    puntos.forEach(function (p) {
      var f = nodo('div', 'sec-punto');
      var m = nodo('span', 'marca', marca);
      m.setAttribute('aria-hidden', 'true');
      f.appendChild(m);
      f.appendChild(nodo('span', null, p));
      lista.appendChild(f);
    });
    col.appendChild(lista);
    return col;
  }

  function pintaIncluye(caja, datos) {
    var incluye = lineas(datos.ficha && datos.ficha.puntos_destacados);
    var traer   = lineas(datos.ficha && datos.ficha.que_traer);
    var banda = caja.closest('.sec-banda');

    /* Sin nada que decir, el bloque entero desaparece. Ni recuadro vacío
       ni «pendiente»: si el club no lo ha escrito, aquí no hay bloque. */
    if (!incluye.length && !traer.length) { if (banda) banda.hidden = true; return; }
    if (banda) banda.hidden = false;

    caja.textContent = '';
    caja.classList.toggle('sec-banda__dos', incluye.length > 0 && traer.length > 0);
    if (incluye.length) caja.appendChild(listaDePuntos('Qué incluye', incluye, '✓', 'puntos_destacados'));
    if (traer.length)   caja.appendChild(listaDePuntos('Qué traer', traer, '·', 'que_traer'));
  }

  /* ---------------------------------------------------------
     7 · Quién entrena · las cifras, y quitar al que no está
     ------------------------------------------------------------
     El nombre, el cargo, la trayectoria y el teléfono los escribe
     `contactos-web.js` leyendo la vista `contactos_publicos`. Aquí
     se hacen las dos cosas que ese ayudante no puede hacer:

       · las CIFRAS (`datos`), que no son una línea de texto sino
         varias, cada una con su número y su rótulo;
       · quitar de en medio a quien no existe. Una ficha sin nombre
         no es una ficha de nadie, así que se retira; y si no queda
         ninguna, el bloque entero desaparece. Nada de «pendiente».

     Lo que ya venía escrito a mano de antes (el nombre y el correo
     de quien lleva montaña o triatlón, que todavía no están en la
     base) se queda: eso es un nombre visible y cuenta como ficha.
     --------------------------------------------------------- */
  function pintaDatos(caja, texto) {
    caja.textContent = '';
    lineas(texto).forEach(function (l) {
      /* «+400: atletas entrenados» → el número grande y el rótulo debajo. */
      var corte = l.indexOf(':');
      if (corte < 1) return;
      var stat = nodo('div', 'stat');
      stat.appendChild(nodo('b', null, l.slice(0, corte).trim()));
      stat.appendChild(nodo('span', null, l.slice(corte + 1).trim()));
      caja.appendChild(stat);
    });
  }

  function pintaEquipo(personas) {
    var fichas = document.querySelectorAll('.sec-persona');
    if (!fichas.length) return;

    var porClave = {}, porSeccion = {};
    personas.forEach(function (p) {
      if (p.clave) porClave[p.clave] = p;
      /* Si hay varias personas en la misma sección manda la responsable;
         si ninguna lo es, la primera que llegue, que viene por orden. */
      if (p.seccion && (!porSeccion[p.seccion] || p.es_responsable)) porSeccion[p.seccion] = p;
    });

    var quedan = 0;
    Array.prototype.forEach.call(fichas, function (ficha) {
      var quien = limpio(ficha.getAttribute('data-persona'));
      var fila = porClave[quien] || porSeccion[quien] || null;

      /* ¿Trae esta ficha un nombre escrito de antes que se vea? */
      var nombre = ficha.querySelector('.nombre');
      var aMano = !!(nombre && !nombre.hidden && limpio(nombre.textContent));

      if (!fila && !aMano) { ficha.remove(); return; }
      quedan++;

      var caja = ficha.querySelector('.sec-datos');
      if (caja && fila && limpio(fila.datos)) pintaDatos(caja, fila.datos);
    });

    if (!quedan) {
      var bloque = document.querySelector('.sec-equipo');
      if (bloque) bloque.hidden = true;
    }
  }

  /* --------------------------------------------------------- */
  function noSePudo(caja) {
    if (!caja) return;
    caja.textContent = '';
    caja.appendChild(vacio('No hemos podido cargar estos datos ahora mismo. Recarga la página o escríbenos.'));
  }

  function arranca() {
    var pagina = document.querySelector('[data-seccion]');
    if (!pagina) return;
    var clave = limpio(pagina.getAttribute('data-seccion'));
    if (!clave) return;

    var cajaVistazo = document.getElementById('cs-vistazo');
    var cajaGrupos  = document.getElementById('cs-grupos');
    var cajaPrecio  = document.getElementById('cs-precio');
    var cajaServ    = document.getElementById('cs-servicios');
    var cajaComp    = document.getElementById('cs-compromiso');
    var cajaIncluye = document.getElementById('cs-incluye');

    var db = window.APOLANA_DB;
    if (!db || typeof db.from !== 'function') {
      [cajaGrupos, cajaPrecio].forEach(noSePudo);
      if (cajaIncluye && cajaIncluye.closest('.sec-banda')) cajaIncluye.closest('.sec-banda').hidden = true;
      return;
    }

    Promise.all([
      /* `servicios` y `compromisos` los crea la migración 094. Si se sube
         esta web sin haberla lanzado, la base contesta que esas columnas
         no existen y la página se queda sin grupos ni precios. O sea: la
         migración va SIEMPRE antes que el despliegue. */
      db.from('contenido_secciones')
        .select('titulo,dirigido_a,descripcion,precio,servicios,compromisos,puntos_destacados,que_traer,acceso,imagen_url,imagen_encuadre,imagen_zoom')
        .eq('seccion', clave).limit(1),
      /* Los grupos de la escuela van por año de nacimiento, y el orden
         que entiende una familia es del más pequeño al más mayor: de
         2023 hacia atrás. Por eso se ordena por año de forma descendente
         y, dentro del mismo año (o cuando no hay año, que es lo normal
         en las secciones de adultos), por nombre. */
      db.from('grupos')
        .select('id,nombre,horario,descripcion,pruebas,nacidos_desde,nacidos_hasta,turno')
        .eq('seccion', clave).eq('activo', true)
        /* La Academia AC98 (antes «Grupo A») sigue siendo un grupo por dentro
           —sus atletas usan la app igual—, pero de cara al público es una
           academia aparte, con su propia página /academia/. Así que NO sale en
           la lista de grupos de atletismo en pista. Se excluye por id. */
        .neq('id', 'c288b979-cd00-4abb-96da-30fa997ef297')
        .order('nacidos_desde', { ascending: false, nullsFirst: false })
        .order('nombre'),
      /* «tarifas_vigentes» y no «tarifas»: esa vista deja fuera las
         caducadas y las que todavía no han entrado en vigor. Con la tabla
         en crudo, el día que el club prepare los precios de la temporada
         que viene saldrían los dos a la vez. Es lo que ya hace /entrenar/. */
      db.from('tarifas_vigentes')
        .select('id,clave,ambito,concepto,grupo_id,dias,importe_socio,importe_socio_hasta,importe_no_socio,importe_no_socio_hasta,texto_importe,periodicidad,notas,orden,vigente_desde')
        .or('seccion.eq.' + clave + ',clave.eq.cuota-socio').order('orden'),
      /* SIEMPRE la vista, nunca la tabla `contactos`: la vista devuelve
         vacíos el teléfono y el correo que el club ha decidido NO
         publicar, y la tabla en crudo no. */
      db.from('contactos_publicos')
        .select('clave,seccion,es_responsable,datos')
        .order('orden')
    ]).then(function (res) {
      var rf = res[0], rg = res[1], rt = res[2], rp = res[3];
      if (rf.error || rg.error || rt.error) throw new Error('lectura');

      var todas = rt.data || [];
      /* Igual que en la lista de grupos: la Academia AC98 (antes «Grupo A»)
         tampoco sale en el precio público de atletismo en pista. Su tarifa es
         `pista-velocidad-a` (y por si acaso, también se excluye por su grupo_id).
         Así en pista solo quedan Velocidad y Fondo y medio fondo. */
      var propias = todas.filter(function (t) {
        return t.clave !== 'cuota-socio'
          && t.clave !== 'pista-velocidad-a'
          && t.grupo_id !== 'c288b979-cd00-4abb-96da-30fa997ef297';
      });

      /* La cuota de socio es de los adultos del club. En las escuelas la
         cuota de la temporada lo incluye todo y NO se es socio por
         apuntar a un hijo: sumarla aquí sería cobrar de más en la
         cabeza de quien lee. Se sabe por el ámbito de sus tarifas. */
      var deEscuela = propias.length && propias.every(function (t) { return limpio(t.ambito) === 'escuela'; });

      var datos = {
        ficha:   (rf.data || [])[0] || null,
        grupos:  juntaAniosEnTabla(juntaTurnos(rg.data || [])),
        gruposRaw: rg.data || [],
        esEscuela: clave === 'escuela',
        tarifas: propias,
        socio:   deEscuela ? null : (todas.filter(function (t) { return t.clave === 'cuota-socio'; })[0] || null)
      };

      pintaCabecera(datos.ficha);
      if (cajaVistazo) pintaVistazo(cajaVistazo, datos);
      if (cajaGrupos)  pintaGrupos(cajaGrupos, datos);
      if (cajaPrecio)  pintaPrecio(cajaPrecio, datos);
      if (cajaServ)    pintaServicios(cajaServ, datos.ficha);
      if (cajaComp)    pintaCompromiso(cajaComp, datos.ficha);
      if (cajaIncluye) pintaIncluye(cajaIncluye, datos);
      pintaEquipo((rp && !rp.error && rp.data) || []);
    }).catch(function () {
      [cajaGrupos, cajaPrecio].forEach(noSePudo);
      if (cajaIncluye && cajaIncluye.closest('.sec-banda')) cajaIncluye.closest('.sec-banda').hidden = true;
    });
  }

  /* ============================================================
     LO ÚLTIMO EN LA SECCIÓN
     ------------------------------------------------------------
     Una página de sección se leía entera de una pasada y se acababa en
     «ven a probarlo»: nada de lo que pasa en el club llegaba hasta
     ahí, aunque la base tenga cien crónicas publicadas. Este bloque
     trae las tres últimas de ESA sección.

     Se activa poniendo `data-ultimas="running"` en un <section> que
     lleve dentro un `.ult-grid`. La página que no lo lleve no cambia
     en nada, así que se puede ir sección por sección.

     ⚠️ EL BLOQUE NACE `hidden` Y SOLO SE ENSEÑA SI HAY NOTICIAS.
     Si la consulta falla, o esa sección todavía no tiene ninguna, se
     queda escondido. Un apartado que dice «aún no hay nada» pinta un
     club parado, que es justo lo contrario de para lo que está.
     ============================================================ */
  function fechaCorta(iso) {
    var d = new Date(String(iso || '').slice(0, 10) + 'T00:00:00');
    if (isNaN(d.getTime())) return '';
    var M = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return d.getDate() + ' ' + M[d.getMonth()] + ' ' + d.getFullYear();
  }

  function ultimasDeLaSeccion() {
    var caja = document.querySelector('[data-ultimas]');
    if (!caja) return;
    var rejilla = caja.querySelector('.ult-grid');
    var seccion = caja.getAttribute('data-ultimas');
    var db = window.APOLANA_DB;
    if (!rejilla || !seccion || !db || typeof db.from !== 'function') return;

    db.from('noticias')
      .select('id,titulo,excerpt,foto_portada,fecha_publicacion,secciones')
      .eq('publicada', true)
      .contains('secciones', [seccion])
      .order('fecha_publicacion', { ascending: false })
      .limit(3)
      .then(function (r) {
        if (!r || r.error || !r.data || !r.data.length) return;   // se queda oculto
        var base = window.APOLANA_BASE || '../';
        rejilla.innerHTML = r.data.map(function (n) {
          var foto = n.foto_portada && window.APOLANA_IMG ? window.APOLANA_IMG(n.foto_portada) : '';
          return '<a class="ult-card" href="' + base + 'noticias/articulo/?id=' + encodeURIComponent(n.id) + '">' +
                   (foto ? '<div class="marco"><img src="' + escAttr(foto) + '" alt="" loading="lazy" decoding="async"></div>' : '') +
                   '<div class="cuerpo">' +
                     '<span class="fecha">' + escHtml(fechaCorta(n.fecha_publicacion)) + '</span>' +
                     '<span class="tit">' + escHtml(n.titulo || '') + '</span>' +
                   '</div>' +
                 '</a>';
        }).join('');
        caja.hidden = false;
      })
      .catch(function () { /* se queda oculto */ });
  }

  function escHtml(t) {
    return String(t == null ? '' : t)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }
  function escAttr(t) { return escHtml(t).replace(/"/g, '&quot;'); }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { arranca(); ultimasDeLaSeccion(); });
  } else {
    arranca(); ultimasDeLaSeccion();
  }
})();
