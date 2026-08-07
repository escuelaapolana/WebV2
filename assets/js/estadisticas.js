/* ==========================================================
   ESTADÍSTICAS DE UN ATLETA · lo que ha hecho, sumado
   ----------------------------------------------------------
   QUÉ PROBLEMA RESUELVE

   Todo lo que apunta un atleta —los metros de cada serie, el tiempo de
   cada repetición, cómo se sintió— vivía SOLO dentro del día en que lo
   escribió. Para saber cuánto había nadado en marzo había que abrir
   marzo día a día. Nadie lo hacía, así que el dato estaba y no servía.

   Aquí se suma. Por semanas, que es la unidad en la que se planifica y
   en la que se habla: «esta semana llevas 6.400 m» tiene sentido; «este
   mes llevas 24.000» ya no dice si vas bien o si te falta el jueves.

   ----------------------------------------------------------
   LOS TRES BLOQUES, Y POR QUÉ CADA UNO SE MIDE COMO SE MIDE

   · NATACIÓN — metros por semana, y el reparto por estilo. El volumen
     es la cifra que mira un entrenador de natación antes que ninguna
     otra, y el estilo dice si de verdad se está trabajando todo o si
     todo acaba siendo crol.

   · CARRERA — kilómetros por semana y el ritmo medio. El ritmo SOLO se
     calcula cuando la serie trae distancia Y tiempo; inventarlo desde
     una de las dos no es una estimación, es un número falso.

   · CARGA — la media de esfuerzo (RPE) de la semana y cuántos días se
     apuntó. Va junto a los días a propósito: una media de 8 con dos
     días no es una semana dura, es una semana corta y dos días duros.

   ⚠️ NO SE INVENTA LA «CARGA» MULTIPLICANDO RPE POR DURACIÓN.
   Es la fórmula de manual (sRPE = RPE × minutos), pero aquí NO se
   apunta la duración de la sesión en ningún sitio. Multiplicar por un
   número supuesto daría una cifra con pinta de científica y sin nada
   detrás. Se dice la media y punto.

   ----------------------------------------------------------
   DE QUÉ DEPORTE ES CADA SERIE

   La sesión trae `deporte` (y a veces `deporte_2`, cuando el día son
   dos). Cuando hay dos, la sesión sola no basta para saber si esos 400
   metros fueron nadando o corriendo, así que se mira el NOMBRE del
   ejercicio: «crol», «espalda», «piscina»… frente a «rodaje», «serie»,
   «cuestas». Es un apaño, y se sabe: por eso solo se usa cuando la
   sesión es de dos deportes. Si el nombre no aclara nada, manda el
   `deporte` principal.

   ----------------------------------------------------------
   NO GUARDA NADA NI PIDE NADA. Recibe las sesiones y los registros ya
   cargados y devuelve HTML. Así vale igual para el portal del atleta
   —donde el atleta se ve a sí mismo— y para la ficha del entrenador,
   sin duplicar el cálculo en dos sitios y que empiecen a discrepar.
   ========================================================== */
(function () {
  'use strict';

  // ---------- utilidades pequeñas y propias ----------
  // Propias a posta: este archivo lo cargan dos páginas que no comparten
  // ninguna función, y depender de una de ellas lo ataría a esa.
  function esc(t) {
    return String(t == null ? '' : t)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
  function num(v) {
    if (v == null || v === '') return null;
    var n = parseFloat(String(v).replace(',', '.').replace(/[^\d.\-]/g, ''));
    return isNaN(n) ? null : n;
  }
  function coma(n, dec) {
    return Number(n).toFixed(dec == null ? 0 : dec).replace('.', ',');
  }
  function miles(n) {
    return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  }
  // Sin tildes y en minúsculas, para comparar nombres escritos a mano.
  function llano(t) {
    return String(t || '').toLowerCase()
      .normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  }
  /* ⚠️ NADA DE `toISOString()` AQUÍ. `new Date('2026-08-03T00:00:00')` es la
     medianoche LOCAL, y en España eso son las 22:00 del día 2 en UTC: pasarlo
     por `toISOString()` devuelve «2026-08-02». O sea que cada semana se
     etiquetaba con el domingo anterior y los lunes se iban a la semana de
     antes. Se escribe la fecha a mano desde el año, el mes y el día locales,
     que es lo que se ha calculado. */
  function isoDe(d) {
    var m = d.getMonth() + 1, dd = d.getDate();
    return d.getFullYear() + '-' + (m < 10 ? '0' : '') + m + '-' + (dd < 10 ? '0' : '') + dd;
  }
  function lunesDe(iso) {
    var d = new Date(iso + 'T00:00:00');
    if (isNaN(d.getTime())) return '';
    var w = (d.getDay() + 6) % 7;          // 0 = lunes, 6 = domingo
    d.setDate(d.getDate() - w);
    return isoDe(d);
  }
  function diaMes(iso) {
    var d = new Date(iso + 'T00:00:00');
    if (isNaN(d.getTime())) return '';
    return d.getDate() + '/' + (d.getMonth() + 1);
  }

  /* Un tiempo escrito como lo escribe la gente: «1:32.4», «92», «1:32,40».
     Devuelve segundos. Lo que no se entienda devuelve null y no se usa:
     más vale una serie sin ritmo que un ritmo mal leído. */
  function aSegundos(txt) {
    if (txt == null || txt === '') return null;
    var t = String(txt).trim().replace(',', '.');
    if (!/^\d{1,2}(:\d{1,2}){0,2}(\.\d+)?$/.test(t)) return null;
    var p = t.split(':').map(parseFloat);
    if (p.some(isNaN)) return null;
    if (p.length === 1) return p[0];
    if (p.length === 2) return p[0] * 60 + p[1];
    return p[0] * 3600 + p[1] * 60 + p[2];
  }
  function minSeg(seg) {
    var m = Math.floor(seg / 60), s = Math.round(seg - m * 60);
    if (s === 60) { s = 0; m++; }
    return m + ':' + (s < 10 ? '0' : '') + s;
  }

  /* Los metros de una serie. La unidad la trae la propia serie («m» o
     «km»); si no la trae se asume metros, que es como se apunta el 95 %
     de las veces y es lo que dice la etiqueta del formulario. */
  function metrosDe(serie) {
    var d = num(serie && serie.distancia);
    if (d == null || d <= 0) return 0;
    var u = llano(serie.unidad || 'm');
    if (u === 'km') return d * 1000;
    return d;
  }

  // ---------- de qué deporte es un ejercicio ----------
  var PALABRAS_NATACION = ['crol', 'libre', 'espalda', 'braza', 'mariposa', 'estilos',
    'pull', 'palas', 'aleta', 'tabla', 'piscina', 'nadar', 'nado', 'buceo', 'viraje', 'salida de poyete'];
  var PALABRAS_CARRERA = ['rodaje', 'trote', 'carrera', 'correr', 'cuesta', 'tempo',
    'progresivo', 'fartlek', 'lanzado', 'pista', 'tartan', 'zancada', 'talon'];

  function deporteDeEjercicio(nombre, sesion) {
    var uno = (sesion && sesion.deporte) || '';
    var dos = (sesion && sesion.deporte_2) || '';
    if (!dos) return uno;                    // un solo deporte: no hay nada que decidir
    var n = llano(nombre);
    var esNat = PALABRAS_NATACION.some(function (p) { return n.indexOf(p) >= 0; });
    var esCar = PALABRAS_CARRERA.some(function (p) { return n.indexOf(p) >= 0; });
    if (esNat && !esCar) return 'natacion';
    if (esCar && !esNat) return 'atletismo';
    return uno;                              // no aclara nada: manda el principal
  }

  /* El estilo, del nombre del ejercicio. No hay campo «estilo» en la base:
     se escribe dentro del nombre, que es como lo dicta el entrenador
     («4×100 crol RC3»). «Libres» y «crol» son lo mismo y se cuentan juntos.
     Lo que no diga estilo va a «sin indicar» y se enseña como tal: fingir
     que todo lo demás es crol falsearía justo el dato que se viene a ver. */
  var ESTILOS = [
    { et: 'Crol', pal: ['crol', 'libre', 'libres'] },
    { et: 'Espalda', pal: ['espalda'] },
    { et: 'Braza', pal: ['braza'] },
    { et: 'Mariposa', pal: ['mariposa', 'fly'] },
    { et: 'Estilos', pal: ['estilos'] }
  ];
  function estiloDe(nombre) {
    var n = llano(nombre);
    // «Estilos» primero: «100 estilos» no es crol aunque lleve la palabra dentro.
    for (var i = ESTILOS.length - 1; i >= 0; i--) {
      for (var j = 0; j < ESTILOS[i].pal.length; j++) {
        if (n.indexOf(ESTILOS[i].pal[j]) >= 0) return ESTILOS[i].et;
      }
    }
    return 'Sin indicar';
  }

  /* ==========================================================
     EL CÁLCULO
     ----------------------------------------------------------
     Entra:
       sesiones  [{ id, fecha, deporte, deporte_2 }]
       registros [{ sesion_id, tiempos_reales, rpe, sensacion_general }]
     Sale un objeto con las semanas ordenadas de la más vieja a la más
     nueva, para que las gráficas se lean de izquierda a derecha.
     ========================================================== */
  function resumir(sesiones, registros, semanas) {
    semanas = semanas || 8;
    var porId = {};
    (sesiones || []).forEach(function (s) { if (s && s.id) porId[s.id] = s; });

    var sem = {};   // { lunes: {...} }
    function caja(lunes) {
      if (!sem[lunes]) sem[lunes] = {
        lunes: lunes, natacion: 0, carrera: 0, dias: {},
        rpes: [], sensaciones: [], estilos: {}, ritmos: []
      };
      return sem[lunes];
    }

    (registros || []).forEach(function (r) {
      if (!r) return;
      var s = porId[r.sesion_id];
      var fecha = (s && s.fecha) || String(r.created_at || '').slice(0, 10);
      if (!fecha) return;
      var L = lunesDe(fecha); if (!L) return;
      var c = caja(L);
      c.dias[fecha] = true;
      if (r.rpe != null) c.rpes.push(Number(r.rpe));
      if (r.sensacion_general != null) c.sensaciones.push(Number(r.sensacion_general));

      var tr = r.tiempos_reales;
      if (!tr || typeof tr !== 'object') return;
      Object.keys(tr).forEach(function (k) {
        var e = tr[k];
        if (!e || !Array.isArray(e.series)) return;
        var nom = String(e.ejercicio || '');
        var dep = deporteDeEjercicio(nom, s);
        e.series.forEach(function (x) {
          /* SOLO LO QUE SE MARCÓ COMO HECHO. Una serie escrita y no marcada
             es una serie planeada: contarla sería sumar kilómetros que no
             ha corrido nadie. */
          if (!x || !x.hecha) return;
          var m = metrosDe(x);
          if (m <= 0) return;
          if (dep === 'natacion') {
            c.natacion += m;
            var es = estiloDe(nom);
            c.estilos[es] = (c.estilos[es] || 0) + m;
          } else if (dep === 'atletismo') {
            c.carrera += m;
            /* El ritmo solo si la serie trae las dos cosas. Y solo desde
               400 m: cronometrar 60 m y pasarlo a min/km da ritmos de
               récord del mundo que no significan nada. */
            var seg = aSegundos(x.tiempo);
            if (seg != null && seg > 0 && m >= 400) {
              c.ritmos.push({ seg: seg / (m / 1000), m: m });
            }
          }
        });
      });
    });

    var claves = Object.keys(sem).sort();
    if (claves.length > semanas) claves = claves.slice(claves.length - semanas);
    var lista = claves.map(function (k) {
      var c = sem[k];
      c.diasN = Object.keys(c.dias).length;
      c.rpeMedio = c.rpes.length
        ? c.rpes.reduce(function (a, b) { return a + b; }, 0) / c.rpes.length : null;
      c.sensMedia = c.sensaciones.length
        ? c.sensaciones.reduce(function (a, b) { return a + b; }, 0) / c.sensaciones.length : null;
      /* El ritmo de la semana se pondera por distancia: un 4×400 rápido no
         puede pesar lo mismo que un rodaje de 10 km al hacer la media. */
      if (c.ritmos.length) {
        var tm = 0, td = 0;
        c.ritmos.forEach(function (p) { tm += p.seg * p.m; td += p.m; });
        c.ritmoMedio = tm / td;
      } else c.ritmoMedio = null;
      return c;
    });

    return {
      semanas: lista,
      hayNatacion: lista.some(function (c) { return c.natacion > 0; }),
      hayCarrera: lista.some(function (c) { return c.carrera > 0; }),
      hayCarga: lista.some(function (c) { return c.rpeMedio != null; })
    };
  }

  /* ==========================================================
     LAS BARRAS
     ----------------------------------------------------------
     Barras y no línea: el volumen semanal es una cantidad, no una
     evolución continua, y una línea que baja a cero en la semana de
     descanso se lee como un bajón cuando es un descanso planificado.

     La cifra va ENCIMA de cada barra. Sin eje de la Y: un eje obliga a
     mirar dos sitios para leer un número que cabe en la propia barra.
     ========================================================== */
  function barras(datos, opts) {
    opts = opts || {};
    /* padT = 40 y no 30: la cifra va ENCIMA de la barra, y la barra más alta
       llega justo al techo del área. Con 30 esa cifra se subía a la línea del
       título y se leían las dos encima. */
    var W = 340, H = 158, padL = 6, padR = 6, padT = 40, padB = 26;
    var max = 0;
    datos.forEach(function (d) { if (d.v > max) max = d.v; });
    if (max <= 0) return '';
    var plotW = W - padL - padR, plotH = H - padT - padB;
    var hueco = plotW / datos.length;
    var ancho = Math.min(34, hueco * 0.62);
    var base = padT + plotH;

    var barrasHTML = datos.map(function (d, i) {
      var x = padL + hueco * i + (hueco - ancho) / 2;
      var h = Math.max(2, plotH * (d.v / max));
      var y = base - h;
      var ult = (i === datos.length - 1);
      return '<rect x="' + x.toFixed(1) + '" y="' + y.toFixed(1) + '" width="' + ancho.toFixed(1) +
        '" height="' + h.toFixed(1) + '" rx="3" fill="var(--azul)" opacity="' + (ult ? '1' : '0.42') + '"></rect>' +
        '<text x="' + (x + ancho / 2).toFixed(1) + '" y="' + (y - 6).toFixed(1) +
        '" text-anchor="middle" font-size="10.5" font-weight="700" fill="var(--navy)">' + esc(d.disp) + '</text>' +
        '<text x="' + (x + ancho / 2).toFixed(1) + '" y="' + (H - 8) +
        '" text-anchor="middle" font-size="8.5" fill="#9a958c">' + esc(d.et) + '</text>';
    }).join('');

    return '<svg viewBox="0 0 ' + W + ' ' + H + '" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="' +
      esc(opts.alt || 'Por semanas') + '">' +
      '<line x1="' + padL + '" y1="' + base + '" x2="' + (W - padR) + '" y2="' + base +
      '" stroke="var(--linea)" stroke-width="1.6"></line>' +
      barrasHTML +
      '<text x="' + padL + '" y="17" font-size="12.5" font-weight="700" fill="var(--navy)">' + esc(opts.titulo || '') + '</text>' +
      (opts.derecha ? '<text x="' + (W - padR) + '" y="17" text-anchor="end" font-size="10.5" font-weight="700" fill="var(--azul-oscuro)">' + esc(opts.derecha) + '</text>' : '') +
      '</svg>';
  }

  // Una fila de reparto con su barrita de proporción.
  function fila(nombre, dato, prop) {
    return '<div class="es-fila">' +
      '<span class="es-nom">' + esc(nombre) + '</span>' +
      '<span class="es-prop"><i style="width:' + Math.max(2, Math.round(prop * 100)) + '%"></i></span>' +
      '<span class="es-dato">' + esc(dato) + '</span></div>';
  }

  function caja(titulo, contenido, pie) {
    return '<div class="es-caja">' +
      '<div class="es-tit">' + esc(titulo) + '</div>' + contenido +
      (pie ? '<p class="es-pie">' + esc(pie) + '</p>' : '') + '</div>';
  }

  /* ==========================================================
     EL HTML
     ----------------------------------------------------------
     Devuelve '' cuando no hay NADA que enseñar. Un apartado vacío con
     «todavía no hay datos» repetido tres veces ocupa media pantalla
     para no decir nada.
     ========================================================== */
  function html(datos, opts) {
    opts = opts || {};
    if (!datos || !datos.semanas.length) return '';
    var S = datos.semanas, out = '';
    var etiqueta = function (c) { return diaMes(c.lunes); };

    // ---- NATACIÓN ----
    if (datos.hayNatacion) {
      var totalNat = S.reduce(function (a, c) { return a + c.natacion; }, 0);
      var conNat = S.filter(function (c) { return c.natacion > 0; });
      var mediaNat = conNat.length ? totalNat / conNat.length : 0;
      var g = barras(S.map(function (c) {
        return { v: c.natacion, disp: c.natacion ? miles(c.natacion) : '', et: etiqueta(c) };
      }), {
        titulo: 'Natación · metros por semana',
        derecha: 'media ' + miles(mediaNat) + ' m',
        alt: 'Metros nadados por semana'
      });
      // Reparto por estilo, sumando todas las semanas: por semana suelta
      // son cuatro números diminutos que no dicen nada.
      var est = {};
      S.forEach(function (c) {
        Object.keys(c.estilos).forEach(function (k) { est[k] = (est[k] || 0) + c.estilos[k]; });
      });
      var claves = Object.keys(est).sort(function (a, b) { return est[b] - est[a]; });
      var maxEst = claves.length ? est[claves[0]] : 1;
      var reparto = claves.map(function (k) {
        return fila(k, miles(est[k]) + ' m · ' + Math.round(est[k] / totalNat * 100) + ' %', est[k] / maxEst);
      }).join('');
      out += caja('Natación', g + (reparto ? '<div class="es-lista">' + reparto + '</div>' : ''),
        est['Sin indicar'] ? 'El estilo sale del nombre del ejercicio. Lo que no lo dice va a «sin indicar».' : '');
    }

    // ---- CARRERA ----
    if (datos.hayCarrera) {
      var totalKm = S.reduce(function (a, c) { return a + c.carrera; }, 0) / 1000;
      var conCar = S.filter(function (c) { return c.carrera > 0; });
      var mediaKm = conCar.length ? totalKm / conCar.length : 0;
      var g2 = barras(S.map(function (c) {
        return { v: c.carrera, disp: c.carrera ? coma(c.carrera / 1000, c.carrera < 10000 ? 1 : 0) : '', et: etiqueta(c) };
      }), {
        titulo: 'Carrera · kilómetros por semana',
        derecha: 'media ' + coma(mediaKm, 1) + ' km',
        alt: 'Kilómetros corridos por semana'
      });
      /* El ritmo, solo de las semanas que lo tienen. Y se dice de cuántas
         series sale: un ritmo medio calculado sobre una sola serie es esa
         serie, no un ritmo medio. */
      var conRitmo = S.filter(function (c) { return c.ritmoMedio != null; });
      var ritmoHTML = '';
      if (conRitmo.length) {
        var nSeries = S.reduce(function (a, c) { return a + c.ritmos.length; }, 0);
        var maxR = Math.max.apply(null, conRitmo.map(function (c) { return c.ritmoMedio; }));
        ritmoHTML = '<div class="es-lista">' + conRitmo.map(function (c) {
          // Más rápido = barra más larga, que es como se lee «mejor».
          return fila('Semana ' + diaMes(c.lunes), minSeg(c.ritmoMedio) + ' /km',
            1 - (c.ritmoMedio / maxR) * 0.55);
        }).join('') + '</div>';
        ritmoHTML = '<div class="es-sub">Ritmo medio · ' + nSeries + (nSeries === 1 ? ' serie' : ' series') + ' con distancia y tiempo</div>' + ritmoHTML;
      }
      out += caja('Carrera', g2 + ritmoHTML,
        conRitmo.length ? 'Solo entran las series de 400 m o más que llevan tiempo apuntado.'
          : 'Cuando apuntes distancia y tiempo en la misma serie, verás aquí tu ritmo.');
    }

    // ---- CARGA ----
    if (datos.hayCarga) {
      var g3 = barras(S.map(function (c) {
        return { v: c.rpeMedio || 0, disp: c.rpeMedio != null ? coma(c.rpeMedio, 1) : '', et: etiqueta(c) };
      }), {
        titulo: 'Esfuerzo · media de la semana',
        derecha: '1 suave · 10 al límite',
        alt: 'Esfuerzo medio por semana'
      });
      /* El esfuerzo NO se repite aquí: ya está en la gráfica de arriba, y
         puesto también en la fila la línea se pasaba de ancho y se cortaba
         justo por donde iba el dato. Aquí van los DÍAS —que es lo que la
         gráfica no dice— y la sensación, que es otra cosa que el esfuerzo:
         se puede acabar molido y contento. */
      var dias = '<div class="es-lista">' + S.slice(-4).map(function (c) {
        var partes = [c.diasN + (c.diasN === 1 ? ' día' : ' días')];
        if (c.sensMedia != null) partes.push('sens. ' + coma(c.sensMedia, 1));
        return fila('Semana ' + diaMes(c.lunes), partes.join(' · '), c.diasN / 7);
      }).join('') + '</div>';
      out += caja('Cómo se ha sentido', g3 + dias,
        'La media del esfuerzo sale de los días que apuntó. Mírala junto a cuántos días son: un 8 con dos días no es una semana dura.');
    }

    if (!out) return '';
    return '<div class="es-bloque">' +
      (opts.titulo ? '<div class="es-cabecera">' + esc(opts.titulo) + '</div>' : '') +
      out + '</div>';
  }

  /* Las reglas de estilo, una vez y desde aquí: las dos páginas que usan
     esto no comparten hoja, y copiarlas en las dos garantiza que dentro de
     un mes se vean distinto. Los colores salen de `apolana.css`, que sí
     cargan las dos. */
  var CSS = [
    '.es-bloque{margin:0 0 18px;}',
    '.es-cabecera{font-size:14px;color:var(--texto-suave);margin:0 0 7px;padding:0 2px;}',
    '.es-caja{background:#fff;border:1px solid var(--linea);border-radius:14px;padding:12px 14px 10px;margin-bottom:12px;}',
    '.es-tit{font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--texto-suave);margin:0 0 6px;}',
    '.es-caja svg{display:block;width:100%;height:auto;}',
    '.es-sub{font-size:13px;color:var(--texto-suave);margin:10px 0 4px;}',
    '.es-lista{margin-top:8px;}',
    '.es-fila{display:flex;align-items:center;gap:10px;padding:5px 0;border-top:1px solid var(--linea);}',
    '.es-fila:first-child{border-top:none;}',
    '.es-nom{flex:none;width:116px;font-size:14px;color:var(--navy);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}',
    '.es-prop{flex:1;min-width:24px;height:7px;border-radius:4px;background:var(--crema,#F3EFE7);overflow:hidden;}',
    '.es-prop i{display:block;height:100%;border-radius:4px;background:var(--azul);opacity:.55;}',
    '.es-dato{flex:none;font-family:var(--fuente-dato);font-size:13px;color:var(--navy);white-space:nowrap;}',
    '.es-caja .es-fila{overflow:hidden;}',
    '.es-pie{margin:8px 0 0;font-size:13px;color:var(--texto-suave);line-height:1.45;}',
    '@media (max-width:420px){.es-nom{width:94px;font-size:13px;}.es-dato{font-size:12px;}}'
  ].join('');

  function ponerEstilos() {
    if (document.getElementById('es-estilos')) return;
    var st = document.createElement('style');
    st.id = 'es-estilos';
    st.textContent = CSS;
    document.head.appendChild(st);
  }

  window.APOLANA_ESTADISTICAS = {
    resumir: resumir,
    html: function (datos, opts) { ponerEstilos(); return html(datos, opts); },
    // Sueltas, por si alguna pantalla quiere solo una parte.
    lunesDe: lunesDe,
    estiloDe: estiloDe
  };
})();

/* ==========================================================
   LO QUE ESTO NO HACE
   ----------------------------------------------------------
   · No cuenta la fuerza. Los kilos ya tienen su gráfica por ejercicio en
     el portal del atleta, y sumar «kilos totales levantados» premia hacer
     muchas series flojas: es un número que sube cuando entrenas peor.
   · No compara con lo PLANIFICADO. Haría falta leer `bloques` de cada
     sesión y decidir qué cuenta como «lo mismo» cuando el atleta cambia
     una serie. Se puede hacer, pero es otra cosa.
   · No sabe de umbrales ni de zonas. Para eso hace falta un test, y el
     club no lo pasa.
   ========================================================== */
