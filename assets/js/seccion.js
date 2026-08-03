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
    if (limpio(ficha.imagen_url)) img.src = limpio(ficha.imagen_url);
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

  function pintaGrupos(caja, datos) {
    caja.textContent = '';
    if (!datos.grupos.length) {
      caja.appendChild(vacio('Todavía no hay grupos publicados en esta sección.'));
      return;
    }
    var lista = nodo('div', 'sec-grupos__lista');
    datos.grupos.forEach(function (g) {
      var t = nodo('article', 'sec-grupo');
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

      if (limpio(g.horario)) t.appendChild(nodo('span', 'cuando', limpio(g.horario)));
      else t.appendChild(nodo('span', 'cuando sec-vacio', 'Días y sede, todavía sin publicar'));

      if (limpio(g.descripcion)) t.appendChild(nodo('p', 'que', limpio(g.descripcion)));

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
  }

  /* ---------------------------------------------------------
     5 · Precio · cada tarifa y la cuota de socio, sumada aparte
     --------------------------------------------------------- */
  function pintaPrecio(caja, datos) {
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

    if (!datos.tarifas.length) {
      caja.appendChild(vacio('El precio de esta sección todavía no está publicado. Escríbenos y te lo decimos.'));
    } else {
      var lista = nodo('div', 'sec-tarifas');
      datos.tarifas.forEach(function (t) {
        var f = nodo('div', 'sec-tarifa');
        var imp = importeDe(t);
        var que = nodo('div', 'que');
        que.appendChild(nodo('span', 'concepto', conceptoCorto(t.concepto, titulo)));
        var propia = (limpio(t.notas) === notaComun) ? '' : limpio(t.notas);
        var detalle = [limpio(t.dias), hayNumero ? propia : ''].filter(Boolean).join(' · ');
        if (detalle) que.appendChild(nodo('span', 'detalle', detalle));
        f.appendChild(que);

        if (imp.texto) f.appendChild(nodo('span', 'importe' + (imp.esNumero ? '' : ' importe--texto'), imp.texto));
        else f.appendChild(nodo('span', 'importe importe--texto sec-vacio', 'Sin publicar'));

        if (t.importe_no_socio != null && t.importe_no_socio !== '') {
          var extra = nodo('span', 'detalle');
          extra.textContent = 'No socios: ' + euros(t.importe_no_socio) + (PERIODO[limpio(t.periodicidad)] || '');
          que.appendChild(extra);
        }
        lista.appendChild(f);
      });
      caja.appendChild(lista);
      if (notaComun) caja.appendChild(nodo('p', 'sec-nota', notaComun));
    }

    /* La cuota de socio no está dentro del precio del entrenamiento:
       se paga aparte, una vez al año. Se dice aquí para que nadie se
       lleve la sorpresa en septiembre. */
    if (datos.socio) {
      var suma = nodo('div', 'sec-suma');
      suma.appendChild(nodo('span', 'k', hayNumero
        ? 'Y aparte, una vez al año, la cuota de socio'
        : 'Aquí solo se paga la cuota de socio'));
      suma.appendChild(nodo('span', 'v', importeDe(datos.socio).texto));
      caja.appendChild(suma);
      if (limpio(datos.socio.notas)) caja.appendChild(nodo('p', 'sec-nota', limpio(datos.socio.notas)));
    }

    /* La letra pequeña de la sección: descuentos, quién tiene precio de
       socio, cómo se amplían los días… Lo escribe el club en Panel →
       Páginas, casilla «Nota del precio». Si está vacía, no sale nada. */
    var nota = limpio(datos.ficha && datos.ficha.precio);
    if (nota) {
      lineas(nota).forEach(function (linea) {
        caja.appendChild(nodo('p', 'sec-nota', linea));
      });
    }
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
  function listaDePuntos(titulo, puntos, marca) {
    var col = nodo('div', 'sec-banda__col');
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
    if (incluye.length) caja.appendChild(listaDePuntos('Qué incluye', incluye, '✓'));
    if (traer.length)   caja.appendChild(listaDePuntos('Qué traer', traer, '·'));
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
        .select('titulo,dirigido_a,descripcion,precio,servicios,compromisos,puntos_destacados,que_traer,imagen_url,imagen_encuadre,imagen_zoom')
        .eq('seccion', clave).limit(1),
      /* Los grupos de la escuela van por año de nacimiento, y el orden
         que entiende una familia es del más pequeño al más mayor: de
         2023 hacia atrás. Por eso se ordena por año de forma descendente
         y, dentro del mismo año (o cuando no hay año, que es lo normal
         en las secciones de adultos), por nombre. */
      db.from('grupos')
        .select('id,nombre,horario,descripcion,pruebas,nacidos_desde,nacidos_hasta')
        .eq('seccion', clave).eq('activo', true)
        .order('nacidos_desde', { ascending: false, nullsFirst: false })
        .order('nombre'),
      /* «tarifas_vigentes» y no «tarifas»: esa vista deja fuera las
         caducadas y las que todavía no han entrado en vigor. Con la tabla
         en crudo, el día que el club prepare los precios de la temporada
         que viene saldrían los dos a la vez. Es lo que ya hace /entrenar/. */
      db.from('tarifas_vigentes')
        .select('clave,ambito,concepto,grupo_id,dias,importe_socio,importe_socio_hasta,importe_no_socio,texto_importe,periodicidad,notas,orden')
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
      var propias = todas.filter(function (t) { return t.clave !== 'cuota-socio'; });

      /* La cuota de socio es de los adultos del club. En las escuelas la
         cuota de la temporada lo incluye todo y NO se es socio por
         apuntar a un hijo: sumarla aquí sería cobrar de más en la
         cabeza de quien lee. Se sabe por el ámbito de sus tarifas. */
      var deEscuela = propias.length && propias.every(function (t) { return limpio(t.ambito) === 'escuela'; });

      var datos = {
        ficha:   (rf.data || [])[0] || null,
        grupos:  rg.data || [],
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

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', arranca);
  } else {
    arranca();
  }
})();
