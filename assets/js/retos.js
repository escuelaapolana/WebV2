/* ============================================================
   RETOS, RANGOS Y MEDALLAS · zona del atleta
   ------------------------------------------------------------
   Maqueta 29a (los siete rangos, disco y número romano) y 29b
   (la tarjeta de reto en sus estados). Reglas del club:

     · Los retos son AUTOMÁTICOS Y PERSONALES. No hay que
       apuntarse a nada: se consiguen entrenando y la cuenta sale
       de lo que el club ya apunta cada día.
     · NO hay clasificación entre atletas. La competición del club
       es la Liga Apolana. El interruptor vive en la base de datos
       (juego_ajustes.ranking_publico) y viene apagado; esta
       pantalla solo le hace caso, nunca lo enciende.
     · Los MENORES no salen en ninguna lista pública del club sin
       la autorización de su familia registrada. Eso lo garantiza
       la base de datos; aquí, además, se explica.

   El color, como manda el sistema:
     · ÁMBAR = el club como institución (rangos, puntos, medallas),
       siempre en texto o en trazo, NUNCA en bloque de fondo, que
       es como se dibujan los avisos.
     · AZUL  = solo lo que se pulsa. Un botón azul por pantalla.
     · VERDE = solo «conseguido».
     · NAVY  = títulos y datos.

   Los cuatro estados (esqueleto, vacío, error y con datos) salen
   del módulo compartido APOLANA_UI, que vive en portal-auth.js.
   ============================================================ */
APOLANA_PORTAL.listo(async function (sb, perfil) {
  "use strict";

  var wrap = document.getElementById('rt-wrap');
  function $(id){ return document.getElementById(id); }
  function esc(s){ var d=document.createElement('div'); d.textContent=(s==null?'':String(s)); return d.innerHTML; }
  function aviso(m,t,o){ if(window.APX) APX.toast(m,t,o); }

  /* ============================================================
     UTILIDADES DE TEXTO Y FECHA
     ============================================================ */
  var MESES = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
  function fCorta(iso){
    if(!iso) return '';
    var p = String(iso).slice(0,10).split('-');
    return p.length===3 ? (parseInt(p[2],10)+' '+MESES[parseInt(p[1],10)-1]) : String(iso);
  }
  function nDe(v){ var n = Number(v||0); return Math.round(n*100)/100; }
  function dia(iso){ var p=String(iso).slice(0,10).split('-'); return new Date(+p[0], +p[1]-1, +p[2]); }
  function hoy(){ var d=new Date(); d.setHours(0,0,0,0); return d; }
  function inicialesTxt(t){
    var p = String(t||'').trim().split(/\s+/);
    return ((p[0]?p[0][0]:'')+(p[1]?p[1][0]:'')).toUpperCase() || '·';
  }

  /* ============================================================
     ICONOS · kit 30a
     Los del juego común los pone APOLANA_UI. Aquí solo se dibujan
     los dos que el kit todavía no tiene, con el mismo lienzo de
     24×24 y el mismo trazo de 1,9 px.
     ============================================================ */
  var EXTRA = {
    racha: '<path d="M4 12h16"/><circle cx="5.5" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="18.5" cy="12" r="1.8"/>',
    crono: '<circle cx="12" cy="14" r="7"/><path d="M12 10.5V14l2.5 1.6M9.5 3.5h5M12 3.5V7"/>'
  };
  function ico(nombre, tam){
    if(EXTRA[nombre]){
      return '<svg class="ic" width="' + (tam||24) + '" height="' + (tam||24) + '" viewBox="0 0 24 24" fill="none" ' +
             'stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
             EXTRA[nombre] + '</svg>';
    }
    return APOLANA_UI.icono(nombre, tam);
  }

  /* Qué se mide en cada reto, dicho en cristiano y con su icono. */
  var UNIDAD = {
    asistencias:          ['entreno','entrenos','entreno'],
    racha_asistencias:    ['entreno seguido','entrenos seguidos','racha'],
    entrenos_registrados: ['entreno contado','entrenos contados','mensaje'],
    cubo_clases:          ['clase de El Cubo','clases de El Cubo','cubo'],
    competiciones:        ['competición','competiciones','pista'],
    marcas:               ['marca','marcas','marcas'],
    mejores_personales:   ['mejor marca','mejores marcas','marcas'],
    tests:                ['batería de tests','baterías de tests','crono'],
    retos_completados:    ['reto','retos','hecho'],
    puntos:               ['punto','puntos','marcas']
  };
  function unidad(metrica, n){
    var u = UNIDAD[metrica] || ['','',''];
    return n === 1 ? u[0] : u[1];
  }
  function iconoDe(metrica){ return (UNIDAD[metrica] || ['','','entreno'])[2] || 'entreno'; }

  /* De qué día a qué día cuenta un reto. Es la misma cuenta que hace
     la base de datos en reto_rango(): semana de lunes a domingo, mes
     natural y temporada de septiembre a agosto. */
  function periodoHasta(r){
    if(r.fecha_fin) return dia(r.fecha_fin);
    var h = hoy();
    if(r.periodo === 'semana'){
      var d = (h.getDay() + 6) % 7;                    /* 0 = lunes */
      return new Date(h.getFullYear(), h.getMonth(), h.getDate() - d + 6);
    }
    if(r.periodo === 'mes') return new Date(h.getFullYear(), h.getMonth() + 1, 0);
    if(r.periodo === 'temporada'){
      var y = h.getMonth() >= 8 ? h.getFullYear() + 1 : h.getFullYear();
      return new Date(y, 7, 31);
    }
    return null;
  }
  function cuando(r){
    if(r.periodo === 'fechas') return 'Del ' + fCorta(r.fecha_inicio) + ' al ' + fCorta(r.fecha_fin);
    if(r.periodo === 'semana') return 'Esta semana';
    if(r.periodo === 'mes') return 'Este mes';
    if(r.periodo === 'temporada') return 'Esta temporada';
    return '';
  }
  /* «quedan 9 días de mes»: lo que convierte un reto en un plan. */
  function loQueQueda(r){
    var h = periodoHasta(r);
    if(!h) return '';
    var dias = Math.round((h - hoy()) / 86400000);
    if(dias < 0) return 'ya se ha cerrado';
    if(dias === 0) return 'último día';
    var cola = r.periodo === 'mes' ? ' de mes' : (r.periodo === 'semana' ? ' de semana' : '');
    return dias === 1 ? ('queda 1 día' + cola) : ('quedan ' + dias + ' días' + cola);
  }

  /* ============================================================
     LOS SIETE RANGOS · maqueta 29a
     ------------------------------------------------------------
     El disco va pegado a `rango_clave` (I … VII), la etiqueta
     estable que guarda la base de datos, y NO al nombre: así el
     club puede renombrar un rango o mover sus puntos de corte sin
     que el emblema cambie. Si algún rango no la tuviera, se
     deduce del orden.
     ============================================================ */
  var ROMANOS = ['I','II','III','IV','V','VI','VII','VIII','IX','X'];
  function claveRango(r){
    if(!r) return '';
    if(r.rango_clave) return String(r.rango_clave);
    var n = Number(r.orden || 0);
    return (n >= 1 && n <= ROMANOS.length) ? ROMANOS[n-1] : '';
  }
  /* Color plano y número romano: ni dorados brillantes ni degradados. */
  function disco(r, tam, sobreOscuro){
    var c = claveRango(r);
    return '<span class="disco disco--' + (tam||'m') + ' rg-' + esc(c || 'x') + (sobreOscuro?' rg-oscuro':'') +
           '" aria-hidden="true">' + esc(c) + '</span>';
  }

  /* ============================================================
     ESTADO
     ============================================================ */
  var FICHAS = [], ATLETA = null;
  var RETOS = [], PROGRESO = {}, LOGROS = {}, MEDALLAS = [], MIAS = {}, RANGOS = [], TABLA = [], PJ = null;
  var MIEMBROS = [], BUSCA = '';
  var RANKING = false;   /* la clasificación viene apagada: la enciende el club */
  var FALLO = false;     /* si lo importante no ha llegado, se dice y se ofrece salida */

  /* LAS FOTOS · vienen de «Mi perfil», que las guarda en un almacén
     privado: no hay URL fija, hay que pedir una firmada que caduca a la
     hora. Se piden todas de una vez y se guardan aquí, para que pintar
     una lista siga siendo instantáneo. Sin foto se ven las iniciales. */
  var CUBO_FOTOS = 'fotos-perfil', FIRMA_S = 3600, FOTOS = {};

  async function firmarFotos(rutas){
    var faltan = [];
    (rutas || []).forEach(function(r){
      if(r && !FOTOS[r] && !/^(https?:|data:)/.test(r) && faltan.indexOf(r) === -1) faltan.push(r);
    });
    if(!faltan.length) return;
    try {
      var r = await sb.storage.from(CUBO_FOTOS).createSignedUrls(faltan, FIRMA_S);
      if(!r.error) (r.data || []).forEach(function(x){ if(x && x.signedUrl) FOTOS[x.path] = x.signedUrl; });
    } catch(e){ /* si el almacén no contesta, se ven las iniciales y ya está */ }
  }
  function fotoUrl(v){
    if(!v) return '';
    if(/^(https?:|data:)/.test(v)) return v;
    return FOTOS[v] || '';
  }
  function esMenor(fnac){
    if(!fnac) return true;                       /* sin fecha, se protege */
    var f = dia(fnac), limite = new Date();
    limite.setFullYear(limite.getFullYear()-18);
    return f > limite;
  }

  /* ============================================================
     CARGA
     ============================================================ */
  async function cargarFichas(){
    var r = await sb.from('atletas').select('id,nombre,apellidos,fecha_nacimiento')
      .or('perfil_id.eq.' + perfil.id + ',perfil_padre_id.eq.' + perfil.id)
      .order('nombre');
    FICHAS = r.error ? [] : (r.data || []);
    return !r.error;
  }

  async function cargarTodo(){
    var id = ATLETA.id;
    FALLO = false;

    var rr = await sb.from('retos')
      .select('id,titulo,descripcion,metrica,objetivo,periodo,fecha_inicio,fecha_fin,puntos,premio')
      .eq('activo', true).order('created_at');
    if(rr.error) FALLO = true;
    RETOS = rr.error ? [] : (rr.data || []);

    PROGRESO = {};
    var rp = await sb.rpc('retos_progreso_atleta', { p_atleta: id });
    if(rp.error) FALLO = true;
    else (rp.data || []).forEach(function(x){ PROGRESO[x.reto_id] = Number(x.valor || 0); });

    LOGROS = {};
    var rl = await sb.from('reto_logros').select('reto_id,valor_alcanzado,completado_en,puntos_otorgados').eq('atleta_id', id);
    if(rl.error) FALLO = true;
    else (rl.data || []).forEach(function(x){ LOGROS[x.reto_id] = x; });

    var rm = await sb.from('medallas').select('id,clave,titulo,descripcion,criterio,umbral,orden')
      .eq('activa', true).order('orden');
    MEDALLAS = rm.error ? [] : (rm.data || []);

    MIAS = {};
    var ra = await sb.from('atleta_medallas').select('medalla_id,conseguida_en').eq('atleta_id', id);
    if(!ra.error) (ra.data || []).forEach(function(x){ MIAS[x.medalla_id] = x.conseguida_en; });

    /* La escala entera, con su etiqueta de emblema. */
    var rg = await sb.from('juego_rangos').select('rango_clave,clave,nombre,desde_puntos,orden').order('desde_puntos');
    if(rg.error) FALLO = true;
    RANGOS = rg.error ? [] : (rg.data || []);

    var rj = await sb.from('perfil_juego')
      .select('atleta_id,participa,autoriza_parental_en,puntos').eq('atleta_id', id).maybeSingle();
    PJ = (rj && !rj.error && rj.data) ? rj.data : null;

    /* La clasificación solo se pide si el club la tiene encendida. */
    var rk = await sb.from('juego_ajustes').select('ranking_publico').eq('id', 1).maybeSingle();
    RANKING = !!(rk && !rk.error && rk.data && rk.data.ranking_publico);
    TABLA = RANKING ? await cargarTabla() : [];

    MIEMBROS = await cargarMiembros();

    await firmarFotos(MIEMBROS.map(function(x){ return x.foto_ruta; })
      .concat(TABLA.map(function(x){ return x.foto_ruta; })));
  }

  async function cargarMiembros(){
    var r = await sb.from('miembros_juego')
      .select('atleta_id,nombre,foto_ruta,puntos,medallas,retos,rango')
      .order('nombre').limit(400);
    return r.error ? [] : (r.data || []);
  }

  async function cargarTabla(){
    var rc = await sb.from('clasificacion_retos')
      .select('atleta_id,nombre,foto_ruta,puntos,medallas,rango,puesto')
      .order('puntos', { ascending: false }).limit(60);
    return rc.error ? [] : (rc.data || []);
  }

  /* ============================================================
     PUNTOS Y RANGO
     ------------------------------------------------------------
     El rango se saca SIEMPRE de los puntos contra la escala, que es
     exactamente lo que hace la base de datos. Así la ficha de otra
     persona también sabe qué disco pintarle sin tener que adivinarlo
     por el nombre.
     ============================================================ */
  function misPuntos(){
    if(PJ && PJ.puntos != null) return Number(PJ.puntos);
    var s = 0;
    for(var k in LOGROS) if(Object.prototype.hasOwnProperty.call(LOGROS,k)) s += Number(LOGROS[k].puntos_otorgados||0);
    return s;
  }
  function rangoDe(p){
    var actual = RANGOS.length ? RANGOS[0] : null, siguiente = null;
    for(var i=0;i<RANGOS.length;i++){
      if(p >= Number(RANGOS[i].desde_puntos||0)) actual = RANGOS[i];
      else { siguiente = RANGOS[i]; break; }
    }
    return { actual: actual, siguiente: siguiente };
  }
  function nombreRango(r, deReserva){
    return (r && r.nombre) ? r.nombre : (deReserva || '');
  }

  /* ============================================================
     BANDAS · la regla del ritmo
     ------------------------------------------------------------
     Cabecera oscura a sangre con el dato duro, secciones alternando
     crema flojo y crema fuerte, y cierre oscuro abajo. Ninguna banda
     lleva radio: una banda no es una tarjeta.
     ============================================================ */
  var _tono = 0;
  function banda(html, clase){
    if(!html) return '';
    var t = clase || (_tono++ % 2 ? 'rt-b2' : 'rt-b1');
    return '<section class="rt-banda ' + t + '"><div class="rt-dentro">' + html + '</div></section>';
  }
  function titulo(t, cuenta){
    return '<h2 class="rt-h">' + esc(t) +
      (cuenta != null ? '<span class="cuenta">' + esc(String(cuenta)) + '</span>' : '') + '</h2>';
  }

  /* ============================================================
     PINTADO · la cabecera oscura
     ============================================================ */
  function pintarCabecera(){
    var p = misPuntos(), r = rangoDe(p);
    var hechos = Object.keys(LOGROS).length;
    var medallas = Object.keys(MIAS).length;
    var enCurso = RETOS.filter(function(x){ return !LOGROS[x.id]; }).length;

    var pct = 100, falta = 'Has llegado a lo más alto de la escala. Ahora toca mantenerlo.';
    if(r.siguiente){
      var base = Number(r.actual ? r.actual.desde_puntos : 0), techo = Number(r.siguiente.desde_puntos||0);
      pct = techo > base ? Math.max(0, Math.min(100, Math.round((p - base) * 100 / (techo - base)))) : 0;
      var quedan = techo - p;
      falta = 'Te ' + (quedan===1 ? 'queda 1 punto' : ('quedan ' + quedan + ' puntos')) +
              ' para ' + nombreRango(r.siguiente) + '.';
    } else if(!RANGOS.length){
      pct = 0; falta = '';
    }

    var h = '<a class="rt-volver" href="../atleta/#mas"><i aria-hidden="true">&larr;</i>Volver</a>' +
      '<h1>Mis retos</h1>' +
      '<p class="rt-lema">El club propone y la cuenta se lleva sola con lo que ya queda apuntado: ' +
      'no hay que apuntarse a nada. Esto es cosa tuya.</p>';

    if(FICHAS.length > 1){
      h += '<div class="rt-quien">' + FICHAS.map(function(f){
        return '<button type="button" data-ficha="' + esc(f.id) + '" aria-pressed="' + (f.id===ATLETA.id) + '">' +
               esc(((f.nombre||'') + ' ' + (f.apellidos||'')).trim()) + '</button>';
      }).join('') + '</div>';
    }

    h += '<div class="rt-rango">' +
        disco(r.actual, 'g', true) +
        '<div class="rt-rango-txt">' +
          '<span class="eti">tu rango</span>' +
          '<span class="nombre">' + esc(nombreRango(r.actual, 'Sin rango')) + '</span>' +
        '</div>' +
        '<div class="rt-rango-pts"><span class="eti">puntos</span><b>' + p + '</b></div>' +
      '</div>' +
      (RANGOS.length ? '<div class="rt-progreso"><i style="width:' + pct + '%"></i></div>' : '') +
      (falta ? '<p class="rt-falta">' + esc(falta) + '</p>' : '') +
      '<div class="rt-datos">' +
        '<div><b>' + enCurso + '</b><span>' + (enCurso===1?'reto abierto':'retos abiertos') + '</span></div>' +
        '<div><b>' + hechos + '</b><span>' + (hechos===1?'conseguido':'conseguidos') + '</span></div>' +
        '<div><b>' + medallas + '</b><span>' + (medallas===1?'medalla':'medallas') + '</span></div>' +
      '</div>';

    return '<header class="rt-banda rt-cab"><div class="rt-dentro">' + h + '</div></header>';
  }

  /* ============================================================
     LA TARJETA DE RETO · maqueta 29b
     ------------------------------------------------------------
     Cuatro estados. El que hace volver es el segundo: no dice «67 %»,
     dice qué falta exactamente y cuánto tiempo queda para hacerlo.
     El azul se reserva para lo que se pulsa, así que ese estado se
     marca con trazo navy de 3 px, que es la voz de los datos.
     ============================================================ */
  function tarjetaReto(r, hecho){
    var obj = Number(r.objetivo||0);
    var val = hecho ? Math.max(Number(LOGROS[r.id].valor_alcanzado||0), obj) : Number(PROGRESO[r.id]||0);
    var pct = obj > 0 ? Math.max(0, Math.min(100, Math.round(val*100/obj))) : 0;
    var falta = Math.max(0, obj - val);
    /* «Te queda poco»: empezado, cerca y todavía a tiempo. */
    var cerca = !hecho && pct >= 60 && pct < 100;
    var clase = 'rt-reto' + (hecho ? ' hecho' : (cerca ? ' cerca' : ''));

    var h = '<article class="' + clase + '">' +
      '<div class="cab">' +
        '<span class="ic-caja">' + ico(hecho ? 'hecho' : iconoDe(r.metrica), 20) + '</span>' +
        '<div class="tit"><h3>' + esc(r.titulo) + '</h3>' +
          (r.descripcion ? '<p>' + esc(r.descripcion) + '</p>' : '<p>' + esc(cuando(r)) + '</p>') + '</div>' +
        '<span class="pts">+' + Number(r.puntos||0) + '</span>' +
      '</div>';

    if(hecho){
      h += '<p class="hecho-pie"><b>Conseguido</b> · ' + esc(fCorta(LOGROS[r.id].completado_en)) + '</p>';
    } else {
      h += '<div class="rt-progreso"><i style="width:' + pct + '%"></i></div><div class="pie">';
      if(pct >= 100){
        h += '<span class="n">Ya está: ' + nDe(obj) + ' de ' + nDe(obj) + '</span>' +
             '<span class="p">falta que el club lo apunte</span>';
      } else if(cerca){
        h += '<span class="n">Te ' + (falta===1 ? 'falta 1 ' : ('faltan ' + nDe(falta) + ' ')) +
             esc(unidad(r.metrica, falta)) + '</span>' +
             '<span class="p">' + esc(loQueQueda(r)) + '</span>';
      } else {
        h += '<span class="n">' + nDe(val) + ' de ' + nDe(obj) + ' ' + esc(unidad(r.metrica, nDe(obj))) + '</span>' +
             '<span class="p">' + esc(loQueQueda(r) || cuando(r)) + '</span>';
      }
      h += '</div>';
    }

    if(r.premio) h += '<p class="premio"><b>Premio del club:</b> ' + esc(r.premio) + '</p>';
    return h + '</article>';
  }

  function pintarEnCurso(){
    if(FALLO){
      return titulo('En curso') + APOLANA_UI.error('No hemos podido cargar tus retos',
        'Puede ser tu conexión. Tus puntos y tus medallas siguen guardados: no se pierde nada.');
    }
    var enCurso = RETOS.filter(function(r){ return !LOGROS[r.id]; });
    return titulo('En curso', enCurso.length || null) + (enCurso.length
      ? enCurso.map(function(r){ return tarjetaReto(r, false); }).join('')
      : APOLANA_UI.vacio('Ahora mismo no hay ningún reto abierto',
          'El club irá proponiendo retos nuevos a lo largo de la temporada. Mientras tanto, todo lo que ' +
          'entrenas se sigue apuntando y cuenta igual.',
          APOLANA_UI.boton('Ver el calendario del club', '../../calendario/')));
  }

  function pintarConseguidos(){
    var hechos = RETOS.filter(function(r){ return !!LOGROS[r.id]; });
    if(!hechos.length) return '';
    return titulo('Conseguidos', hechos.length) + hechos.map(function(r){ return tarjetaReto(r, true); }).join('');
  }

  /* ============================================================
     LA ESCALA · maqueta 29a
     ============================================================ */
  function pintarEscala(){
    if(!RANGOS.length) return '';
    var p = misPuntos(), r = rangoDe(p);
    var h = titulo('Los ' + (RANGOS.length === 7 ? 'siete' : RANGOS.length) + ' rangos') +
      '<p class="rt-nota-sec">Los puntos de cada reto suben de rango. El rango no se pierde nunca.</p>' +
      '<ol class="rt-escala">';
    RANGOS.forEach(function(x){
      var mio = r.actual && r.actual.clave === x.clave;
      h += '<li class="' + (mio ? 'mio' : '') + (p < Number(x.desde_puntos||0) ? ' porllegar' : '') + '">' +
        disco(x, 'm') +
        '<span class="n">' + esc(x.nombre) + '</span>' +
        '<span class="d">' + Number(x.desde_puntos||0) + '</span>' +
        (mio ? '<span class="tuyo">tu rango</span>' : '') + '</li>';
    });
    h += '</ol>' +
      '<div class="rt-porques">' +
        '<div><b>El rango no se pierde</b><span>Una vez alcanzado, se queda. Quien deja el club un año y vuelve, ' +
          'vuelve con el suyo.</span></div>' +
        '<div><b>Leyenda es de varios años</b><span>El último rango no se alcanza en una temporada: es a propósito, ' +
          'para que siempre quede a dónde ir.</span></div>' +
        '<div><b>No hay clasificación</b><span>Te comparas contigo, no con los demás. La competición del club es la ' +
          'Liga Apolana.</span></div>' +
      '</div>';
    return h;
  }

  /* ============================================================
     MEDALLAS
     Ámbar y en trazo, nunca en bloque de fondo: así no se confunden
     con un aviso. Ni dorados ni medallas de emoji.
     ============================================================ */
  function pintarMedallas(){
    var tengo = MEDALLAS.filter(function(m){ return !!MIAS[m.id]; });
    var faltan = MEDALLAS.filter(function(m){ return !MIAS[m.id]; });
    var lista = tengo.concat(faltan);
    var h = titulo('Medallas', MEDALLAS.length ? (tengo.length + ' de ' + MEDALLAS.length) : null);
    if(!lista.length){
      return h + APOLANA_UI.vacio('Todavía no hay medallas',
        'El club aún no ha creado ninguna. En cuanto las tenga aparecerán aquí y se irán encendiendo solas ' +
        'según vayas cumpliendo cosas.');
    }
    h += '<div class="rt-medallas">' + lista.map(function(m){
      var si = !!MIAS[m.id];
      return '<div class="rt-med ' + (si?'si':'no') + '">' +
        '<span class="disco-med">' + ico(iconoDe(m.criterio), 22) + '</span>' +
        '<span class="n">' + esc(m.titulo) + '</span>' +
        '<span class="d">' + esc(si ? ('Conseguida el ' + fCorta(MIAS[m.id])) : (m.descripcion||'')) + '</span></div>';
    }).join('') + '</div>';
    if(!tengo.length){
      h += '<p class="rt-nota-sec">Todas se consiguen solas: no hay que pedir ninguna.</p>';
    }
    return h;
  }

  /* ============================================================
     CLASIFICACIÓN
     Solo existe si el club enciende el interruptor en la base de
     datos. Apagado —que es como viene— esta sección no se pinta.
     ============================================================ */
  function filaTabla(f, yo){
    var foto = fotoUrl(f.foto_ruta);
    var cara = foto ? '<img src="' + esc(foto) + '" alt="">' : esc(inicialesTxt(f.nombre));
    var r = rangoDe(Number(f.puntos||0)).actual;
    return '<div class="rt-fila' + (yo?' yo':'') + '">' +
      '<span class="pos">' + Number(f.puesto) + '</span>' +
      '<span class="cara">' + cara + '</span>' +
      '<span class="qui"><b>' + esc(f.nombre) + '</b><span>' +
        (r ? '<i class="rg">' + esc(nombreRango(r, f.rango)) + '</i>' : esc(f.rango||'')) +
        (Number(f.medallas)>0 ? ' · ' + f.medallas + (Number(f.medallas)===1?' medalla':' medallas') : '') +
      '</span></span>' +
      '<span class="num">' + Number(f.puntos) + '</span></div>';
  }

  function pintarTabla(){
    if(!RANKING) return '';
    var h = titulo('Clasificación del club');
    if(!TABLA.length){
      return h + APOLANA_UI.vacio('Todavía no hay nadie en la clasificación',
        'En cuanto la gente del club diga que quiere participar, esto se llena solo.');
    }
    var top = TABLA.slice(0, 20);
    var yoDentro = top.some(function(f){ return f.atleta_id === ATLETA.id; });
    var yoFila = null;
    for(var i=0;i<TABLA.length;i++) if(TABLA[i].atleta_id === ATLETA.id) yoFila = TABLA[i];
    h += '<div class="rt-lista">' + top.map(function(f){ return filaTabla(f, f.atleta_id===ATLETA.id); }).join('');
    if(yoFila && !yoDentro) h += '<div class="rt-corte">Tu posición</div>' + filaTabla(yoFila, true);
    return h + '</div>';
  }

  /* ============================================================
     GENTE DEL CLUB
     Solo sale quien se deja ver, y un menor solo si consta la
     autorización de su familia. Eso lo decide la base de datos.
     ============================================================ */
  function filaMiembro(m){
    var foto = fotoUrl(m.foto_ruta);
    var cara = foto ? '<img src="' + esc(foto) + '" alt="">' : esc(inicialesTxt(m.nombre));
    var r = rangoDe(Number(m.puntos||0)).actual;
    var bajo = [];
    if(Number(m.medallas) > 0) bajo.push(m.medallas + (Number(m.medallas)===1 ? ' medalla' : ' medallas'));
    if(Number(m.retos) > 0) bajo.push(m.retos + (Number(m.retos)===1 ? ' reto' : ' retos'));
    return '<a class="rt-fila" href="?atleta=' + encodeURIComponent(m.atleta_id) + '">' +
      '<span class="cara">' + cara + '</span>' +
      '<span class="qui"><b>' + esc(m.nombre) + '</b><span>' +
        '<i class="rg">' + esc(nombreRango(r, m.rango)) + '</i>' +
        (bajo.length ? ' · ' + esc(bajo.join(' · ')) : '') + '</span></span>' +
      (r ? disco(r, 's') : '') +
      '<span class="chev" aria-hidden="true">' + ico('entrar', 20) + '</span></a>';
  }

  function pintarBuscador(){
    var h = titulo('Gente del club') +
      '<p class="rt-nota-sec">Mira las medallas y los retos de quien ha dicho que quiere dejarse ver. Nada más: ' +
      'ni contacto, ni marcas, ni pagos.</p>';
    if(!MIEMBROS.length){
      return h + APOLANA_UI.vacio('Todavía no se deja ver nadie',
        'Nadie del club ha dicho aún que quiera que le abran la ficha. Puedes ser la primera persona: se ' +
        'activa aquí abajo, en «Quién puede verte».');
    }
    h += '<input type="search" id="bs-txt" class="rt-buscar" placeholder="Buscar por nombre…" ' +
         'aria-label="Buscar a alguien del club" autocomplete="off" value="' + esc(BUSCA) + '">' +
         '<div class="rt-lista" id="bs-lista">' + listaMiembros() + '</div>';
    return h;
  }

  function listaMiembros(){
    var t = BUSCA.trim().toLowerCase();
    var lista = t
      ? MIEMBROS.filter(function(m){ return String(m.nombre||'').toLowerCase().indexOf(t) !== -1; })
      : MIEMBROS;
    if(!lista.length) return '<div class="rt-corte">Nadie con ese nombre.</div>';
    return lista.slice(0, 20).map(filaMiembro).join('') +
      (lista.length > 20 ? '<div class="rt-corte">Hay ' + (lista.length-20) + ' más. Afina la búsqueda.</div>' : '');
  }

  /* ============================================================
     AJUSTES · quién puede verte
     ============================================================ */
  function pintarAjustes(){
    var menor = esMenor(ATLETA.fecha_nacimiento);
    var autorizado = !!(PJ && PJ.autoriza_parental_en);
    var participa = !!(PJ && PJ.participa);
    var visible = participa && (!menor || autorizado);

    var h = titulo('Quién puede verte');

    if(menor && !autorizado){
      h += '<div class="rt-aviso"><span class="ic-caja">' + ico('aviso', 20) + '</span>' +
        '<div><b>Falta el permiso de tu familia</b>' +
        '<p>Eres menor de edad, así que tu nombre y tu foto no salen en ninguna lista del club hasta que tu ' +
        'padre, tu madre o quien te tutele lo autorice. Díselo al club y lo dejan registrado en un momento. ' +
        'Mientras tanto tus retos, tus puntos y tus medallas cuentan igual para ti.</p></div></div>';
    }

    h += '<div class="rt-ajustes">' +
      '<p class="intro">Tus retos son tuyos y los ves siempre. Esto solo decide si el resto del club puede ' +
      'abrir tu ficha. Se apaga cuando quieras y desapareces al momento.</p>' +

      '<label class="rt-sw"><span class="txt"><b>Que otros socios puedan ver mi perfil</b>' +
        '<span>Verían tu nombre, tu foto, tu rango, tus medallas y los retos que has cumplido. Nada más.' +
        (RANKING ? ' Y saldrías en la clasificación del club.' : '') + '</span></span>' +
        '<input type="checkbox" id="aj-participa"' + (participa?' checked':'') + '><span class="palanca"></span></label>' +

      (visible
        ? '<button type="button" class="rt-btn-azul" id="aj-ver">Ver mi ficha como la ven los demás</button>'
        : '<p class="intro" style="margin:14px 0 0;">Ahora mismo tu ficha no se puede abrir: no sales en la ' +
          'lista del club.</p>') +

      '<div class="rt-sep"></div>' +

      '<a class="rt-enlace" href="../perfil/"><span><b>Tu foto y tu nombre</b>' +
        'Se cambian en Mi perfil, junto con el resto de tus datos.</span>' +
        '<span class="fl" aria-hidden="true">' + ico('entrar', 20) + '</span></a>' +
    '</div>';
    return h;
  }

  /* ============================================================
     CIERRE OSCURO
     ============================================================ */
  function pintarCierre(){
    return '<footer class="rt-banda rt-cierre"><div class="rt-dentro">' +
      '<h2>Esto se cuenta solo</h2>' +
      '<p>No hay que apuntarse a ningún reto ni avisar de nada: sale de las asistencias, las competiciones, ' +
      'las marcas y los tests que el club ya apunta cada día. Si algo no te cuadra, díselo a tu entrenador.</p>' +
      '<p class="fino">Aquí no se compara a nadie con nadie. La competición del club es la ' +
      '<a href="../../liga/">Liga Apolana</a>.</p>' +
      '</div></footer>';
  }

  /* ============================================================
     MONTAJE
     ============================================================ */
  function pintar(){
    _tono = 0;
    var partes = [
      pintarEnCurso(), pintarConseguidos(), pintarEscala(), pintarMedallas(),
      pintarTabla(), pintarBuscador(), pintarAjustes()
    ];
    /* Dos secciones seguidas nunca comparten fondo: el tono se reparte
       sobre las que de verdad se pintan, no sobre las que se saltan. */
    wrap.innerHTML = pintarCabecera() +
      partes.map(function(p){ return banda(p); }).join('') +
      pintarCierre();
    enganchar();
  }

  /* ============================================================
     FICHA DE UNA PERSONA (?atleta=…)
     Se enseña lo que esa persona ha elegido enseñar y nada más.
     ============================================================ */
  async function abrirFicha(id, esMia){
    wrap.innerHTML = '<div class="rt-banda rt-b1"><div class="rt-dentro">' + APOLANA_UI.cargando('tarjeta') + '</div></div>';

    var rg = await sb.from('juego_rangos').select('rango_clave,clave,nombre,desde_puntos,orden').order('desde_puntos');
    RANGOS = rg.error ? [] : (rg.data || []);

    var rm = await sb.from('miembros_juego')
      .select('atleta_id,nombre,foto_ruta,puntos,medallas,retos,rango').eq('atleta_id', id).maybeSingle();
    var m = (rm && !rm.error && rm.data) ? rm.data : null;
    var volver = '<a class="rt-volver" href="./"><i aria-hidden="true">&larr;</i>' +
                 (esMia ? 'Volver a mis retos' : 'Volver a los retos') + '</a>';

    if(rm && rm.error){
      wrap.innerHTML = '<header class="rt-banda rt-cab"><div class="rt-dentro">' + volver + '<h1>Ficha</h1></div></header>' +
        '<section class="rt-banda rt-b1"><div class="rt-dentro">' +
        APOLANA_UI.error('No hemos podido abrir esta ficha',
          'Puede ser tu conexión. No se ha perdido nada: vuelve a intentarlo en un momento.') + '</div></section>';
      return;
    }

    if(!m){
      wrap.innerHTML = '<header class="rt-banda rt-cab"><div class="rt-dentro">' + volver + '<h1>Ficha</h1></div></header>' +
        '<section class="rt-banda rt-b1"><div class="rt-dentro">' +
        APOLANA_UI.vacio('Esta ficha no se puede abrir',
          'Puede que esa persona haya preferido no dejarse ver, o que sea menor de edad y todavía no conste el ' +
          'permiso de su familia.',
          APOLANA_UI.boton('Volver a los retos', './')) + '</div></section>';
      return;
    }

    await firmarFotos([m.foto_ruta]);

    var rmed = await sb.from('medallas_publicas')
      .select('medalla_id,titulo,descripcion,orden,conseguida_en').eq('atleta_id', id).order('orden');
    var meds = (rmed && !rmed.error) ? (rmed.data || []) : [];

    var rlog = await sb.from('logros_publicos')
      .select('reto_id,titulo,descripcion,puntos_otorgados,completado_en')
      .eq('atleta_id', id).order('completado_en', { ascending:false });
    var logs = (rlog && !rlog.error) ? (rlog.data || []) : [];

    var foto = fotoUrl(m.foto_ruta);
    var cara = foto ? '<img src="' + esc(foto) + '" alt="">' : esc(inicialesTxt(m.nombre));
    var r = rangoDe(Number(m.puntos||0)).actual;

    var cab = '<header class="rt-banda rt-cab"><div class="rt-dentro">' + volver +
      '<div class="rt-ficha">' +
        '<span class="cara-g">' + cara + '</span>' +
        '<div class="quien"><h1>' + esc(m.nombre) + '</h1>' +
          '<span class="rg">' + esc(nombreRango(r, m.rango)) + '</span></div>' +
        (r ? disco(r, 'm', true) : '') +
      '</div>' +
      '<div class="rt-datos">' +
        '<div><b>' + Number(m.puntos||0) + '</b><span>puntos</span></div>' +
        '<div><b>' + Number(m.medallas||0) + '</b><span>' + (Number(m.medallas)===1?'medalla':'medallas') + '</span></div>' +
        '<div><b>' + Number(m.retos||0) + '</b><span>' + (Number(m.retos)===1?'reto':'retos') + '</span></div>' +
      '</div></div></header>';

    _tono = 0;
    var partes = [];

    if(esMia){
      partes.push('<div class="rt-aviso"><span class="ic-caja">' + ico('aviso', 20) + '</span>' +
        '<div><b>Así te ven los demás</b><p>Esto es exactamente lo que enseña tu ficha al resto del club: ni una ' +
        'cosa más. Se cambia o se apaga desde «Quién puede verte», en la pantalla anterior.</p></div></div>');
    }

    partes.push(titulo('Medallas', meds.length || null) + (meds.length
      ? '<div class="rt-medallas">' + meds.map(function(x){
          return '<div class="rt-med si">' +
            '<span class="disco-med">' + ico('hecho', 22) + '</span>' +
            '<span class="n">' + esc(x.titulo) + '</span>' +
            '<span class="d">' + esc('Conseguida el ' + fCorta(x.conseguida_en)) + '</span></div>';
        }).join('') + '</div>'
      : APOLANA_UI.vacio('Todavía no tiene ninguna medalla',
          'Cuando consiga la primera aparecerá aquí, con el día en que la ganó.')));

    partes.push(titulo('Retos cumplidos', logs.length || null) + (logs.length
      ? logs.map(function(x){
          return '<article class="rt-reto hecho"><div class="cab">' +
            '<span class="ic-caja">' + ico('hecho', 20) + '</span>' +
            '<div class="tit"><h3>' + esc(x.titulo) + '</h3>' +
              (x.descripcion ? '<p>' + esc(x.descripcion) + '</p>' : '') + '</div>' +
            '<span class="pts">+' + Number(x.puntos_otorgados||0) + '</span></div>' +
            '<p class="hecho-pie"><b>Conseguido</b> · ' + esc(fCorta(x.completado_en)) + '</p></article>';
        }).join('')
      : APOLANA_UI.vacio('Todavía no ha cumplido ningún reto',
          'En cuanto el club dé por bueno el primero, saldrá en esta lista con los puntos que sumó.')));

    wrap.innerHTML = cab + partes.map(function(p){ return banda(p); }).join('') + pintarCierre();
  }

  /* ============================================================
     INTERACCIÓN
     ============================================================ */
  function enganchar(){
    Array.prototype.forEach.call(wrap.querySelectorAll('[data-ficha]'), function(b){
      b.addEventListener('click', async function(){
        var id = b.getAttribute('data-ficha');
        if(id === ATLETA.id) return;
        for(var i=0;i<FICHAS.length;i++) if(FICHAS[i].id === id) ATLETA = FICHAS[i];
        wrap.innerHTML = '<div class="rt-banda rt-b1"><div class="rt-dentro">' + APOLANA_UI.cargando('tarjeta') + '</div></div>';
        await cargarTodo(); pintar();
      });
    });

    /* Un solo interruptor: se guarda al momento, sin botón de por medio. */
    var sw = $('aj-participa');
    if(sw) sw.addEventListener('change', function(){ guardarParticipa(this); });

    var ver = $('aj-ver');
    if(ver) ver.addEventListener('click', function(){ location.href = '?atleta=' + encodeURIComponent(ATLETA.id); });

    var bs = $('bs-txt');
    if(bs) bs.addEventListener('input', function(){
      BUSCA = this.value || '';
      var lista = $('bs-lista');
      if(lista) lista.innerHTML = listaMiembros();
    });
  }

  async function guardarParticipa(chk){
    var quiere = chk.checked;
    chk.disabled = true;
    var r = await sb.from('perfil_juego')
      .upsert({ atleta_id: ATLETA.id, participa: quiere }, { onConflict: 'atleta_id' })
      .select('atleta_id,participa,autoriza_parental_en,puntos').maybeSingle();
    chk.disabled = false;
    if(r.error){
      chk.checked = !quiere;
      aviso('No hemos podido guardar el cambio', 'error', { detalle: 'Puede ser tu conexión.' });
      return;
    }
    PJ = r.data || PJ;
    aviso(quiere ? 'Hecho: ya puedes salir en el club' : 'Hecho: has dejado de ser visible');

    /* Lo que se deja ver cambia al momento: se vuelven a pedir las listas. */
    if(RANKING) TABLA = await cargarTabla();
    MIEMBROS = await cargarMiembros();
    await firmarFotos(MIEMBROS.map(function(x){ return x.foto_ruta; })
      .concat(TABLA.map(function(x){ return x.foto_ruta; })));
    pintar();
  }

  /* ============================================================
     ARRANQUE
     ============================================================ */
  var hayFichas = await cargarFichas();

  if(!hayFichas){
    wrap.innerHTML = '<header class="rt-banda rt-cab"><div class="rt-dentro">' +
      '<a class="rt-volver" href="../"><i aria-hidden="true">&larr;</i>Volver al portal</a>' +
      '<h1>Mis retos</h1></div></header>' +
      '<section class="rt-banda rt-b1"><div class="rt-dentro">' +
      APOLANA_UI.error('No hemos podido cargar tus retos',
        'Puede ser tu conexión. No se ha perdido nada de lo que llevas conseguido.') + '</div></section>';
    return;
  }

  if(!FICHAS.length){
    wrap.innerHTML = '<header class="rt-banda rt-cab"><div class="rt-dentro">' +
      '<a class="rt-volver" href="../"><i aria-hidden="true">&larr;</i>Volver al portal</a>' +
      '<h1>Mis retos</h1></div></header>' +
      '<section class="rt-banda rt-b1"><div class="rt-dentro">' +
      APOLANA_UI.vacio('Esta pantalla es para los atletas del club',
        'Tu cuenta no tiene ninguna ficha de atleta asociada, y los retos se cuentan por atleta. Si crees que ' +
        'es un error, escríbele al club y lo miran.',
        APOLANA_UI.boton('Volver al portal', '../')) + '</div></section>';
    return;
  }
  ATLETA = FICHAS[0];

  /* ¿Venimos a ver la ficha de alguien? Entonces solo eso. */
  var pedido = new URLSearchParams(location.search).get('atleta');
  if(pedido){
    var mia = FICHAS.some(function(f){ return f.id === pedido; });
    await abrirFicha(pedido, mia);
    return;
  }

  await cargarTodo();
  pintar();
});
