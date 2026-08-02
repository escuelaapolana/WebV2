/* ============================================================
   RANKING DEL CLUB · /club/ranking/
   ------------------------------------------------------------
   Quién va mejor esta temporada en cada prueba. Los datos salen
   de la vista `ranking_marcas` (migración 058), que es lo ÚNICO
   que esta página puede leer: las marcas de verdad viven en una
   tabla privada y el navegador no llega a ella.

   LO QUE HACE FALTA SABER ANTES DE TOCAR NADA
   ------------------------------------------------------------
   1) LOS MENORES. La vista ya viene con el nombre VACÍO cuando
      no se puede publicar (menor sin autorización familiar
      registrada). Aquí no se decide nada de eso: si `nombre`
      llega vacío, se escribe «Atleta del club». Nunca se intenta
      reconstruir un nombre por ningún otro camino, porque no hay
      ningún otro camino: la vista no manda más datos.

   2) COMPETICIÓN Y ENTRENO NO SE MEZCLAN. Son dos rankings
      distintos y se elige uno. Un crono de un martes no compite
      contra una final.

   3) EL VERDE ES SOLO PARA UNA MEJORA. Lo marca la propia base
      (`mejora`): esa marca batió lo que esa persona ya tenía en
      la misma prueba y en el mismo contexto. Ni un verde más.

   4) EL GUION `—` SOLO SIGNIFICA «NO HAY NADIE MÁS». Si falta un
      dato (una sede sin anotar, por ejemplo) no se escribe un
      guion: no se escribe nada.
   ============================================================ */
(function () {
  'use strict';

  /* Cuántas filas se enseñan antes de «clasificación completa».
     El podio se lleva las tres primeras, así que la tabla va del
     puesto 4 al 15 y el resto se despliega. */
  var DESDE_TABLA = 4;
  var HASTA_TABLA = 15;

  /* Si la base tarda más que esto, se pasa al estado de error con
     su botón de reintentar en vez de dejar la página colgada. */
  var ESPERA_MAXIMA = 10000;

  var MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
               'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  var CONTEXTOS = [
    { id: 'competicion', texto: 'Competición' },
    { id: 'entreno',     texto: 'Entrenamiento' }
  ];

  var SEXOS = { hombre: 'Hombres', mujer: 'Mujeres', otro: 'Otros' };

  /* --- Estado de la página --------------------------------- */
  var filas = [];                    // todas las marcas publicables
  var filtro = { prueba: '', temporada: '', categoria: '', sexo: '', contexto: 'competicion' };
  var desplegado = false;            // ¿está abierta la clasificación completa?

  /* --- Ayudantes ------------------------------------------- */
  function $(id) { return document.getElementById(id); }

  function esc(s) {
    var d = document.createElement('div');
    d.textContent = (s === null || s === undefined) ? '' : String(s);
    return d.innerHTML;
  }

  function fechaCorta(iso) {
    if (!iso) return '';
    var p = String(iso).split('-');
    if (p.length < 3) return '';
    var mes = MESES[parseInt(p[1], 10) - 1] || '';
    return parseInt(p[2], 10) + ' ' + mes + ' ' + p[0];
  }

  /* La marca tal y como se guardó. A los saltos y lanzamientos se
     les pone el metro, que en la base no está. A los tiempos no se
     les toca nada: 4:02.14 se lee solo.

     La unidad («m», «puntos») sale en letra normal y más pequeña:
     la monoespaciada es para la cifra, que es lo que se compara en
     columna. Un «m» tan grande como el número descuadra la lectura. */
  function marcaHTML(f) {
    var t = (f.marca === null || f.marca === undefined) ? '' : String(f.marca).trim();
    if (!t) return '';
    if (f.unidad === 'distancia' && !/\s?m$/i.test(t)) t += ' m';
    var partes = t.match(/^(.*?[\d)])\s*([A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)$/);
    if (partes) return esc(partes[1]) + '<span class="uni">' + esc(partes[2]) + '</span>';
    return esc(t);
  }

  function nombreDe(f) { return (f.nombre && String(f.nombre).trim()) || ''; }

  /* Nombre para pintar. Sin nombre publicable, la categoría es lo
     que le da cuerpo a la fila: «Atleta del club · Sub-16». */
  function quienDe(f) {
    var n = nombreDe(f);
    if (n) return { texto: n, anonimo: false };
    return { texto: 'Atleta del club', anonimo: true };
  }

  function mejorQue(a, b, masEsMejor) {
    return masEsMejor ? (a > b) : (a < b);
  }

  function numero(v) { var n = Number(v); return isFinite(n) ? n : null; }

  /* --- Traer los datos ------------------------------------- */
  var COLUMNAS = 'clave,nombre,categoria,sexo,prueba,disciplina,ambito,unidad,' +
                 'mas_es_mejor,orden_prueba,temporada,contexto,valor,marca,fecha,sede,mejora';

  function traer() {
    return new Promise(function (resolve, reject) {
      if (!window.APOLANA_DB) { reject(new Error('sin conexión a la base')); return; }

      var reloj = setTimeout(function () { reject(new Error('la base tarda demasiado')); }, ESPERA_MAXIMA);

      (async function () {
        var todas = [], desde = 0, paso = 1000;
        /* De mil en mil: hoy son unos cientos de marcas, pero cada
           temporada añade las suyas y esto no hay que volver a mirarlo. */
        for (;;) {
          var r = await window.APOLANA_DB
            .from('ranking_marcas')
            .select(COLUMNAS)
            .order('orden_prueba', { ascending: true })
            .order('fecha', { ascending: false })
            .range(desde, desde + paso - 1);
          if (r.error) throw new Error(r.error.message);
          var lote = r.data || [];
          todas = todas.concat(lote);
          if (lote.length < paso) break;
          desde += paso;
        }
        return todas;
      })().then(function (d) { clearTimeout(reloj); resolve(d); },
                function (e) { clearTimeout(reloj); reject(e); });
    });
  }

  /* --- Los cuatro estados ---------------------------------- */
  function mostrar(cual) {
    var mapa = {
      cargando: 'rk-esqueleto',
      datos:    'rk-resultado',
      vacio:    'rk-vacio',
      error:    'rk-error'
    };
    Object.keys(mapa).forEach(function (k) {
      var el = $(mapa[k]);
      if (el) el.hidden = (k !== cual);
    });
    /* El título de la prueba solo acompaña a una clasificación de
       verdad. En vacío y en error, el propio cartel ya lleva el
       suyo, y dejar el anterior colgado confunde. */
    var t = $('rk-titulo-fila');
    if (t) t.hidden = (cual !== 'datos');
  }

  /* --- Cabecera: el dato duro ------------------------------ */
  function pintarDatoDuro() {
    var cont = $('rk-datos');
    if (!cont) return;
    /* Una fila de ceros en la primera pantalla transmite abandono.
       Sin marcas todavía, se dice con palabras. */
    if (!filas.length) {
      cont.innerHTML = '<p class="rk-sin-dato">El ranking arranca en cuanto se anoten las primeras marcas de la temporada.</p>';
      return;
    }
    var atletas = {}, pruebas = {};
    filas.forEach(function (f) { atletas[f.clave] = 1; pruebas[f.prueba] = 1; });
    var trozos = [
      [filas.length, filas.length === 1 ? 'marca' : 'marcas'],
      [Object.keys(atletas).length, 'atletas'],
      [Object.keys(pruebas).length, 'pruebas']
    ];
    cont.innerHTML = trozos.map(function (t) {
      return '<div class="rk-dato"><b>' + t[0] + '</b><span>' + t[1] + '</span></div>';
    }).join('');
  }

  /* --- Los desplegables ------------------------------------ */

  /* Qué filas pasan cada filtro. Se separa por pasos para poder
     preguntar «¿qué categorías hay?» sin la categoría puesta. */
  function pasaBase(f) {
    return f.temporada === filtro.temporada && f.contexto === filtro.contexto;
  }
  function pasaPrueba(f) { return pasaBase(f) && f.prueba === filtro.prueba; }
  function pasaTodo(f) {
    return pasaPrueba(f) &&
      (!filtro.categoria || f.categoria === filtro.categoria) &&
      (!filtro.sexo || f.sexo === filtro.sexo);
  }

  function opcionesPrueba() {
    /* Solo las pruebas que de verdad tienen marcas con la
       temporada y el contexto elegidos. Un desplegable con
       cuarenta pruebas vacías no ayuda a nadie. */
    var mapa = {};
    filas.filter(pasaBase).forEach(function (f) {
      var k = f.prueba;
      if (!mapa[k]) mapa[k] = { prueba: f.prueba, ambito: f.ambito, orden: f.orden_prueba, atletas: {} };
      mapa[k].atletas[f.clave] = 1;
    });
    return Object.keys(mapa).map(function (k) {
      var o = mapa[k];
      o.cuantos = Object.keys(o.atletas).length;
      return o;
    }).sort(function (a, b) { return (a.orden - b.orden) || a.prueba.localeCompare(b.prueba, 'es'); });
  }

  var NOMBRE_AMBITO = { atletismo: 'Atletismo', natacion: 'Natación' };

  function pintarSelectPrueba() {
    var sel = $('rk-prueba');
    if (!sel) return;
    var ops = opcionesPrueba();

    if (!ops.length) { sel.innerHTML = ''; return; }
    /* Si la prueba elegida ya no existe con estos filtros, se pasa
       a la que más gente tiene: siempre hay algo que mirar. */
    if (!ops.some(function (o) { return o.prueba === filtro.prueba; })) {
      filtro.prueba = ops.slice().sort(function (a, b) { return b.cuantos - a.cuantos; })[0].prueba;
    }

    var grupos = [];
    ops.forEach(function (o) {
      var etiqueta = NOMBRE_AMBITO[o.ambito] || (o.ambito || 'Otras');
      var g = grupos[grupos.length - 1];
      if (!g || g.etiqueta !== etiqueta) { g = { etiqueta: etiqueta, items: [] }; grupos.push(g); }
      g.items.push(o);
    });

    sel.innerHTML = grupos.map(function (g) {
      var items = g.items.map(function (o) {
        var sufijo = o.cuantos === 1 ? ' · 1 atleta' : ' · ' + o.cuantos + ' atletas';
        return '<option value="' + esc(o.prueba) + '"' +
               (o.prueba === filtro.prueba ? ' selected' : '') + '>' +
               esc(o.prueba + sufijo) + '</option>';
      }).join('');
      return grupos.length > 1
        ? '<optgroup label="' + esc(g.etiqueta) + '">' + items + '</optgroup>'
        : items;
    }).join('');
  }

  function pintarSelectTemporada() {
    var sel = $('rk-temporada'), campo = $('rk-campo-temporada');
    if (!sel || !campo) return;
    var vistas = {};
    filas.forEach(function (f) { if (f.temporada) vistas[f.temporada] = 1; });
    var lista = Object.keys(vistas).sort().reverse();
    /* Con una sola temporada el desplegable no elige nada: se
       queda escrito abajo, en la fila de lo aplicado. */
    campo.hidden = lista.length < 2;
    sel.innerHTML = lista.map(function (t) {
      return '<option value="' + esc(t) + '"' + (t === filtro.temporada ? ' selected' : '') + '>' +
             esc('Temporada ' + t) + '</option>';
    }).join('');
  }

  function pintarSelectCategoria() {
    var sel = $('rk-categoria'), campo = $('rk-campo-categoria');
    if (!sel || !campo) return;
    var vistas = {};
    filas.filter(pasaPrueba).forEach(function (f) { if (f.categoria) vistas[f.categoria] = 1; });
    var lista = Object.keys(vistas).sort(function (a, b) { return a.localeCompare(b, 'es'); });
    campo.hidden = lista.length < 2;
    if (filtro.categoria && lista.indexOf(filtro.categoria) === -1) filtro.categoria = '';
    sel.innerHTML = '<option value="">Todas las categorías</option>' +
      lista.map(function (c) {
        return '<option value="' + esc(c) + '"' + (c === filtro.categoria ? ' selected' : '') + '>' + esc(c) + '</option>';
      }).join('');
  }

  function pintarSelectSexo() {
    var sel = $('rk-sexo'), campo = $('rk-campo-sexo');
    if (!sel || !campo) return;
    var vistas = {};
    filas.forEach(function (f) { if (f.sexo) vistas[f.sexo] = 1; });
    var lista = Object.keys(vistas);
    /* Mientras las fichas no traigan el sexo, este filtro no se
       dibuja. Un desplegable que no filtra nada estorba. */
    campo.hidden = lista.length < 2;
    if (campo.hidden) { filtro.sexo = ''; return; }
    sel.innerHTML = '<option value="">Todos</option>' +
      lista.map(function (s) {
        return '<option value="' + esc(s) + '"' + (s === filtro.sexo ? ' selected' : '') + '>' +
               esc(SEXOS[s] || s) + '</option>';
      }).join('');
  }

  function pintarContexto() {
    var cont = $('rk-contexto');
    if (!cont) return;
    var cuenta = {};
    filas.forEach(function (f) {
      if (f.temporada !== filtro.temporada) return;
      cuenta[f.contexto] = (cuenta[f.contexto] || 0) + 1;
    });
    cont.innerHTML = CONTEXTOS.map(function (c) {
      var n = cuenta[c.id] || 0;
      return '<button type="button" data-ctx="' + c.id + '" aria-pressed="' +
        (filtro.contexto === c.id ? 'true' : 'false') + '">' + esc(c.texto) +
        '<span class="cuenta">' + n + '</span></button>';
    }).join('');
  }

  function pintarAplicado() {
    var cont = $('rk-aplicado');
    if (!cont) return;
    var trozos = [];

    /* La temporada se enseña siempre, aunque solo haya una: es la
       primera pregunta de quien entra («¿esto es de este año?»). */
    if (filtro.temporada) {
      trozos.push('<span class="rk-marca-filtro fija">Temporada ' + esc(filtro.temporada) + '</span>');
    }
    if (filtro.categoria) {
      trozos.push('<span class="rk-marca-filtro">' + esc(filtro.categoria) +
        '<button type="button" data-quitar="categoria" aria-label="Quitar el filtro de categoría">×</button></span>');
    }
    if (filtro.sexo) {
      trozos.push('<span class="rk-marca-filtro">' + esc(SEXOS[filtro.sexo] || filtro.sexo) +
        '<button type="button" data-quitar="sexo" aria-label="Quitar el filtro de sexo">×</button></span>');
    }
    if (filtro.categoria || filtro.sexo) {
      trozos.push('<button type="button" class="rk-quitar" data-quitar="todo">Quitar filtros</button>');
    }
    cont.innerHTML = trozos.join('');
  }

  /* --- El ranking ------------------------------------------ */

  /* Una fila por persona: su mejor marca con los filtros puestos.
     Si empata consigo misma, manda la que hizo antes. */
  function construirRanking() {
    var elegidas = filas.filter(pasaTodo);
    var mejor = {};
    elegidas.forEach(function (f) {
      var v = numero(f.valor);
      if (v === null) return;
      var actual = mejor[f.clave];
      if (!actual) { mejor[f.clave] = f; return; }
      var va = numero(actual.valor);
      if (mejorQue(v, va, f.mas_es_mejor) || (v === va && f.fecha < actual.fecha)) mejor[f.clave] = f;
    });

    var lista = Object.keys(mejor).map(function (k) { return mejor[k]; });
    lista.sort(function (a, b) {
      var va = numero(a.valor), vb = numero(b.valor);
      if (va !== vb) return a.mas_es_mejor ? (vb - va) : (va - vb);
      return String(a.fecha).localeCompare(String(b.fecha));
    });
    return lista;
  }

  function insigniaMejora(f, dentroDelPodio) {
    if (!f.mejora) return '';
    var t = dentroDelPodio ? 'mejora su marca' : 'mejora';
    return '<span class="rk-mejora">' + t + '</span>';
  }

  /* La sede solo va en el podio. En la ficha de móvil se pierde a
     propósito: es la columna menos importante y sin ella la línea
     de datos cabe entera. */
  function metaDe(f, conSede) {
    var trozos = [];
    if (f.categoria) trozos.push(esc(f.categoria));
    if (f.fecha) trozos.push(esc(fechaCorta(f.fecha)));
    /* Si no hay sede anotada no se pone nada: un guion aquí
       significaría «no ha corrido», y sí ha corrido. */
    if (conSede && f.sede) trozos.push(esc(f.sede));
    return trozos.join(' · ');
  }

  function pintarPodio(lista) {
    var cont = $('rk-podio');
    if (!cont) return;
    var tarjetas = [];

    for (var i = 0; i < 3; i++) {
      var f = lista[i];
      if (!f) {
        /* Guion legítimo: no es que falte el dato, es que no hay
           nadie más que haya hecho esta prueba. */
        tarjetas.push(
          '<div class="rk-pod rk-pod--hueco">' +
            '<span class="nada" aria-hidden="true">—</span>' +
            '<span class="meta">Nadie más ha hecho esta prueba esta temporada</span>' +
          '</div>');
        continue;
      }
      var q = quienDe(f);
      tarjetas.push(
        '<div class="rk-pod rk-pod--' + (i + 1) + '">' +
          '<span class="puesto">' + (i + 1) + '</span>' +
          '<span class="quien' + (q.anonimo ? ' sin-nombre' : '') + '">' + esc(q.texto) + '</span>' +
          '<span class="marca">' + marcaHTML(f) + '</span>' +
          '<span class="meta">' + metaDe(f, true) + '</span>' +
          insigniaMejora(f, true) +
        '</div>');
    }
    cont.innerHTML = tarjetas.join('');
  }

  function pintarTabla(lista) {
    var cont = $('rk-tabla'), mas = $('rk-mas');
    if (!cont) return;

    var resto = lista.slice(DESDE_TABLA - 1);
    if (!resto.length) {
      cont.innerHTML = '';
      if (mas) { mas.hidden = true; mas.innerHTML = ''; }
      return;
    }

    var tope = desplegado ? resto.length : Math.min(resto.length, HASTA_TABLA - DESDE_TABLA + 1);
    var visibles = resto.slice(0, tope);

    var filasHTML = visibles.map(function (f, i) {
      var q = quienDe(f);
      return '<div class="rk-fila">' +
        '<span class="c-puesto">' + (DESDE_TABLA + i) + '</span>' +
        '<span class="c-atleta' + (q.anonimo ? ' sin-nombre' : '') + '">' + esc(q.texto) + '</span>' +
        '<span class="c-cat">' + (f.categoria ? esc(f.categoria) : '') + '</span>' +
        '<span class="c-marca">' + marcaHTML(f) + '</span>' +
        '<span class="c-fecha">' + esc(fechaCorta(f.fecha)) + '</span>' +
        '<span class="c-meta">' + metaDe(f, false) + '</span>' +
        insigniaMejora(f, false) +
      '</div>';
    }).join('');

    cont.innerHTML =
      '<div class="rk-cab">' +
        '<span>Puesto</span><span>Atleta</span><span>Categoría</span><span>Marca</span><span>Fecha</span>' +
      '</div>' + filasHTML;

    if (mas) {
      var quedan = resto.length - tope;
      if (quedan > 0) {
        mas.hidden = false;
        mas.innerHTML = '<button type="button" id="rk-ver-mas">Ver la clasificación completa' +
          '<span class="cuenta">+' + quedan + '</span></button>';
      } else if (desplegado && resto.length > (HASTA_TABLA - DESDE_TABLA + 1)) {
        mas.hidden = false;
        mas.innerHTML = '<button type="button" id="rk-ver-menos">Ver solo los primeros</button>';
      } else {
        mas.hidden = true;
        mas.innerHTML = '';
      }
    }
  }

  function pintarTitulo(lista) {
    var t = $('rk-titulo'), s = $('rk-sub');
    if (t) t.textContent = filtro.prueba || 'Ranking';
    if (!s) return;
    var ctx = filtro.contexto === 'entreno' ? 'marcas de entrenamiento' : 'marcas de competición';
    var trozos = ['<b>' + lista.length + '</b> ' + (lista.length === 1 ? 'atleta' : 'atletas'), ctx];
    if (filtro.categoria) trozos.push(esc(filtro.categoria));
    if (filtro.sexo) trozos.push(esc(SEXOS[filtro.sexo] || filtro.sexo));
    trozos.push('temporada ' + esc(filtro.temporada));
    s.innerHTML = trozos.join(' · ');
  }

  function pintarVacio() {
    var tit = $('rk-vacio-tit'), txt = $('rk-vacio-txt');
    var hayAlgo = filas.some(pasaPrueba);
    if (tit) {
      tit.textContent = hayAlgo
        ? 'Nadie con esos filtros'
        : (filtro.contexto === 'entreno'
            ? 'Todavía no hay marcas de entrenamiento aquí'
            : 'Todavía no hay marcas de competición aquí');
    }
    if (txt) {
      txt.textContent = hayAlgo
        ? 'En ' + filtro.prueba + ' hay marcas esta temporada, pero ninguna de esa categoría. Quita el filtro y las verás todas.'
        : 'En cuanto alguien del club haga esta prueba y su marca entre en el sistema, aparecerá aquí sola.';
    }
  }

  /* --- Repintar todo --------------------------------------- */
  function pintar() {
    pintarSelectTemporada();
    pintarContexto();
    pintarSelectPrueba();
    pintarSelectCategoria();
    pintarSelectSexo();
    pintarAplicado();

    var filtrosCaja = $('rk-filtros');
    if (filtrosCaja) filtrosCaja.hidden = false;

    var lista = construirRanking();
    if (!lista.length) { pintarVacio(); mostrar('vacio'); return; }

    pintarTitulo(lista);
    pintarPodio(lista);
    pintarTabla(lista);
    mostrar('datos');
  }

  /* --- Arranque -------------------------------------------- */
  function primerosFiltros() {
    var temporadas = {};
    filas.forEach(function (f) { if (f.temporada) temporadas[f.temporada] = 1; });
    filtro.temporada = Object.keys(temporadas).sort().reverse()[0] || '';

    /* Si esa temporada no tiene ni una marca de competición, se
       abre por entrenamiento: mejor eso que una página vacía. */
    var hayComp = filas.some(function (f) {
      return f.temporada === filtro.temporada && f.contexto === 'competicion';
    });
    filtro.contexto = hayComp ? 'competicion' : 'entreno';

    /* Se abre por la prueba con más gente: es la que mejor enseña
       para qué sirve esta página. */
    var ops = opcionesPrueba().sort(function (a, b) { return b.cuantos - a.cuantos; });
    filtro.prueba = ops.length ? ops[0].prueba : '';
  }

  function cargar() {
    mostrar('cargando');
    traer().then(function (datos) {
      filas = (datos || []).filter(function (f) { return f && f.prueba && numero(f.valor) !== null; });
      pintarDatoDuro();
      if (!filas.length) {
        var c = $('rk-filtros'); if (c) c.hidden = true;
        var tit = $('rk-vacio-tit'), txt = $('rk-vacio-txt');
        if (tit) tit.textContent = 'El ranking arranca en cuanto haya marcas';
        if (txt) txt.textContent = 'Todavía no hay ninguna marca publicable en el sistema. En cuanto el club empiece a anotarlas, esta página se llena sola.';
        /* Sin nada que listar, «ver todas las pruebas» no lleva a
           ninguna parte: la única salida útil es los récords. */
        var quitar = $('rk-vacio-reset');
        if (quitar) quitar.hidden = true;
        mostrar('vacio');
        return;
      }
      primerosFiltros();
      desplegado = false;
      pintar();
    }).catch(function (e) {
      if (window.console && console.warn) console.warn('[Apolana] ranking:', e && e.message);
      mostrar('error');
    });
  }

  /* --- Escuchas -------------------------------------------- */
  function engancharse() {
    var prueba = $('rk-prueba'), temporada = $('rk-temporada'),
        categoria = $('rk-categoria'), sexo = $('rk-sexo');

    if (prueba) prueba.addEventListener('change', function () {
      filtro.prueba = this.value; desplegado = false; pintar();
    });
    if (temporada) temporada.addEventListener('change', function () {
      filtro.temporada = this.value; desplegado = false; pintar();
    });
    if (categoria) categoria.addEventListener('change', function () {
      filtro.categoria = this.value; desplegado = false; pintar();
    });
    if (sexo) sexo.addEventListener('change', function () {
      filtro.sexo = this.value; desplegado = false; pintar();
    });

    var ctx = $('rk-contexto');
    if (ctx) ctx.addEventListener('click', function (ev) {
      var b = ev.target.closest('button[data-ctx]');
      if (!b) return;
      filtro.contexto = b.getAttribute('data-ctx');
      desplegado = false;
      pintar();
    });

    var aplicado = $('rk-aplicado');
    if (aplicado) aplicado.addEventListener('click', function (ev) {
      var b = ev.target.closest('[data-quitar]');
      if (!b) return;
      var que = b.getAttribute('data-quitar');
      if (que === 'todo') { filtro.categoria = ''; filtro.sexo = ''; }
      else { filtro[que] = ''; }
      desplegado = false;
      pintar();
    });

    var mas = $('rk-mas');
    if (mas) mas.addEventListener('click', function (ev) {
      if (ev.target.closest('#rk-ver-mas'))  { desplegado = true;  pintar(); }
      if (ev.target.closest('#rk-ver-menos')) { desplegado = false; pintar(); }
    });

    var reset = $('rk-vacio-reset');
    if (reset) reset.addEventListener('click', function () {
      filtro.categoria = ''; filtro.sexo = '';
      var ops = opcionesPrueba().sort(function (a, b) { return b.cuantos - a.cuantos; });
      if (ops.length) filtro.prueba = ops[0].prueba;
      desplegado = false;
      pintar();
    });

    var reintentar = $('rk-reintentar');
    if (reintentar) reintentar.addEventListener('click', cargar);
  }

  document.addEventListener('DOMContentLoaded', function () {
    if (!$('rk-podio')) return;   // no es esta página
    engancharse();
    cargar();
  });
})();
