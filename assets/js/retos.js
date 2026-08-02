/* ============================================================
   MIS RETOS · rangos y medallas · zona del atleta
   ------------------------------------------------------------
   Maquetas 38a (mis retos y el momento de subir de rango) y 38b
   (cómo te ve otro socio). La escala de los siete rangos, con su
   disco y su número romano, es el bloque 29a.

   REGLAS DEL CLUB
     · Los retos son AUTOMÁTICOS Y PERSONALES. No hay que apuntarse
       a nada: se consiguen entrenando y la cuenta sale de lo que el
       club ya apunta cada día.
     · NO hay clasificación entre atletas. La competición del club
       es la Liga Apolana. El interruptor vive en la base de datos
       (juego_ajustes.ranking_publico) y viene apagado; esta
       pantalla solo le hace caso, nunca lo enciende.
     · Los MENORES no tienen perfil visible para otros socios, ni
       con permiso familiar: a una cuenta de menor no se le ofrece
       siquiera el interruptor. Sus medallas las ven su familia y su
       entrenador.
     · En la ficha de otra persona no se enseña ni una marca, ni un
       tiempo, ni un dato de contacto: sería una clasificación
       encubierta, que es justo lo que no se le quiere hacer a la
       Liga.

   MODO CONSULTA (la regla del móvil): fondo crema y UNA SOLA
   tarjeta navy, la del rango. La pantalla de subir de rango sí es
   navy entera, pero es otra pantalla: solo sale al subir, siete
   veces en la vida de un atleta, y sin confeti ni animación.

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
  function diasQuedan(r){
    var h = periodoHasta(r);
    return h ? Math.round((h - hoy()) / 86400000) : 99999;
  }
  function cuando(r){
    if(r.periodo === 'fechas') return 'Del ' + fCorta(r.fecha_inicio) + ' al ' + fCorta(r.fecha_fin);
    if(r.periodo === 'semana') return 'Esta semana';
    if(r.periodo === 'mes') return 'Este mes';
    if(r.periodo === 'temporada') return 'Esta temporada';
    return '';
  }
  /* «quedan 9 de mes»: lo que convierte un reto en un plan. */
  function loQueQueda(r){
    var d = diasQuedan(r);
    if(d === 99999) return '';
    if(d < 0) return 'ya se ha cerrado';
    if(d === 0) return 'último día';
    var cola = r.periodo === 'mes' ? ' de mes' : (r.periodo === 'semana' ? ' de semana' : '');
    return d === 1 ? ('queda 1 día' + cola) : ('quedan ' + d + ' días' + cola);
  }

  /* ============================================================
     LOS RANGOS
     ------------------------------------------------------------
     El emblema va pegado a `rango_clave` (I … VII), la etiqueta
     estable que guarda la base de datos, y NO al nombre: así el
     club puede renombrar un rango o mover sus puntos de corte sin
     que la medalla cambie. Si algún rango no la tuviera, se deduce
     del orden.
     ============================================================ */
  var ROMANOS = ['I','II','III','IV','V','VI','VII','VIII','IX','X'];
  function claveRango(r){
    if(!r) return '';
    if(r.rango_clave) return String(r.rango_clave);
    var n = Number(r.orden || 0);
    return (n >= 1 && n <= ROMANOS.length) ? ROMANOS[n-1] : '';
  }
  /* La medalla del rango: ámbar en trazo, con su número romano. */
  function medalla(r, tam){
    return '<span class="medalla medalla--' + (tam||'m') + '" aria-hidden="true">' + esc(claveRango(r)) + '</span>';
  }
  /* El disco de la escala: color plano, uno por rango (29a). */
  function disco(r){
    var c = claveRango(r);
    return '<span class="disco rg-' + esc(c || 'x') + '" aria-hidden="true">' + esc(c) + '</span>';
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

  async function cargarRangos(){
    var rg = await sb.from('juego_rangos').select('rango_clave,clave,nombre,desde_puntos,orden').order('desde_puntos');
    RANGOS = rg.error ? [] : (rg.data || []);
    return !rg.error;
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

    if(!(await cargarRangos())) FALLO = true;

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
     persona también sabe qué medalla pintarle sin tener que
     adivinarla por el nombre.
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
  function nombreRango(r, deReserva){ return (r && r.nombre) ? r.nombre : (deReserva || ''); }

  /* Cuánto le falta a un reto, en tanto por uno: es lo que ordena la
     lista. Primero lo que está más cerca de caer. */
  function restanteDe(r){
    if(LOGROS[r.id]) return -1;
    var obj = Number(r.objetivo||0), val = Number(PROGRESO[r.id]||0);
    if(obj <= 0) return 1;
    return Math.max(0, (obj - val) / obj);
  }

  /* ============================================================
     PINTADO
     ============================================================ */
  function cabecera(volverA, volverTxt, titulo){
    return '<a class="rt-migas" href="' + volverA + '"><span class="fl" aria-hidden="true">&larr;</span>' +
           esc(volverTxt) + '</a><h1>' + esc(titulo) + '</h1>';
  }
  function rotulo(t, der){
    return '<div class="rt-rot"><b>' + esc(t) + '</b>' +
           (der ? '<span class="cifra">' + esc(der) + '</span>' : '') + '</div>';
  }

  /* --- la única tarjeta navy: el rango, con las dos cotas escritas --- */
  function tarjetaRango(){
    var p = misPuntos(), r = rangoDe(p);
    if(!RANGOS.length) return '';
    var pct = 100, sub = 'Has llegado a lo más alto de la escala.', cotas = '';
    if(r.siguiente){
      var base = Number(r.actual ? r.actual.desde_puntos : 0), techo = Number(r.siguiente.desde_puntos||0);
      pct = techo > base ? Math.max(0, Math.min(100, Math.round((p - base) * 100 / (techo - base)))) : 0;
      var quedan = techo - p;
      sub = p + (p===1 ? ' punto · ' : ' puntos · ') + quedan + ' para ' + nombreRango(r.siguiente);
      cotas = '<div class="cotas"><span>' + esc(nombreRango(r.actual)) + ' · ' + base + '</span>' +
              '<span>' + esc(nombreRango(r.siguiente)) + ' · ' + techo + '</span></div>';
    } else {
      sub = p + (p===1 ? ' punto' : ' puntos') + ' · lo más alto de la escala';
    }
    return '<div class="rt-rango">' +
      '<div class="fila">' + medalla(r.actual, 'm') +
        '<div class="quien"><span class="nombre">' + esc(nombreRango(r.actual, 'Sin rango')) + '</span>' +
        '<span class="sub">' + esc(sub) + '</span></div>' +
      '</div>' +
      '<div><div class="barra"><i style="width:' + pct + '%"></i></div>' + cotas + '</div>' +
    '</div>';
  }

  /* --- la tarjeta de reto (38a) --- */
  function tarjetaReto(r, cerca){
    var obj = Number(r.objetivo||0);
    var val = Number(PROGRESO[r.id]||0);
    var pct = obj > 0 ? Math.max(0, Math.min(100, Math.round(val*100/obj))) : 0;
    var falta = Math.max(0, obj - val);

    var h = '<article class="rt-reto' + (cerca?' cerca':'') + '">' +
      '<div class="cab">' +
        '<span class="ic-caja">' + ico(iconoDe(r.metrica), 19) + '</span>' +
        '<div class="tit"><h2>' + esc(r.titulo) + '</h2>' +
          (r.descripcion ? '<p>' + esc(r.descripcion) + '</p>' : '<p>' + esc(cuando(r)) + '</p>') + '</div>' +
        '<span class="pts">+' + Number(r.puntos||0) + '</span>' +
      '</div>' +
      '<span class="barra"><i style="width:' + pct + '%"></i></span><div class="pie">';

    if(pct >= 100){
      h += '<span class="n">Ya está: ' + nDe(obj) + ' de ' + nDe(obj) + '</span>' +
           '<span class="p">falta que el club lo apunte</span>';
    } else if(cerca){
      h += '<span class="n">Te ' + (falta===1 ? 'falta 1 ' : ('faltan ' + nDe(falta) + ' ')) +
           esc(unidad(r.metrica, falta)) + '</span>' +
           '<span class="p">' + esc(loQueQueda(r) || cuando(r)) + '</span>';
    } else {
      h += '<span class="n">' + nDe(val) + ' de ' + nDe(obj) + ' ' + esc(unidad(r.metrica, nDe(obj))) + '</span>' +
           '<span class="p">' + esc(loQueQueda(r) || cuando(r)) + '</span>';
    }
    h += '</div>';
    if(r.premio) h += '<p class="premio"><b>Premio del club:</b> ' + esc(r.premio) + '</p>';
    return h + '</article>';
  }

  function pintarEnCurso(){
    if(FALLO){
      return rotulo('Tus retos') + APOLANA_UI.error('No hemos podido cargar tus retos',
        'Puede ser tu conexión. Tus puntos y tus medallas siguen guardados: no se pierde nada.');
    }
    /* Se ordenan por lo que falta menos, no por fecha ni por puntos. */
    var abiertos = RETOS.filter(function(r){ return !LOGROS[r.id]; }).sort(function(a,b){
      var d = restanteDe(a) - restanteDe(b);
      if(d) return d;
      return diasQuedan(a) - diasQuedan(b);
    });
    if(!abiertos.length){
      return rotulo('Tus retos') + APOLANA_UI.vacio('Ahora mismo no hay ningún reto abierto',
        'El club irá proponiendo retos nuevos a lo largo de la temporada. Mientras tanto, todo lo que entrenas ' +
        'se sigue apuntando y cuenta igual.',
        APOLANA_UI.boton('Ver el calendario del club', '../../calendario/'));
    }
    /* El primero lleva borde ámbar cuando de verdad le falta poco: está
       empezado y todavía no ha caído. Eso lo convierte en un plan. */
    var p0 = abiertos[0];
    var v0 = Number(PROGRESO[p0.id]||0), o0 = Number(p0.objetivo||0);
    var destacar = v0 > 0 && o0 > 0 && v0 < o0;
    return rotulo(destacar ? 'Te falta poco' : 'Tus retos', abiertos.length + (abiertos.length===1?' abierto':' abiertos')) +
      abiertos.map(function(r, i){ return tarjetaReto(r, destacar && i === 0); }).join('');
  }

  function pintarConseguidos(){
    var hechos = RETOS.filter(function(r){ return !!LOGROS[r.id]; }).sort(function(a,b){
      return String(LOGROS[b.id].completado_en).localeCompare(String(LOGROS[a.id].completado_en));
    });
    if(!hechos.length) return '';
    return rotulo('Conseguidos', hechos.length + ' de ' + RETOS.length) +
      '<div class="rt-filas">' + hechos.map(function(r){
        return '<div class="rt-fila"><span class="visto">' + ico('hecho', 16) + '</span>' +
          '<span class="t">' + esc(r.titulo) + '</span>' +
          '<span class="f">' + esc(fCorta(LOGROS[r.id].completado_en)) + '</span></div>';
      }).join('') + '</div>';
  }

  /* --- la escala de los siete rangos · 29a --- */
  function pintarEscala(){
    if(!RANGOS.length) return '';
    var p = misPuntos(), r = rangoDe(p);
    var h = rotulo('Los ' + (RANGOS.length === 7 ? 'siete' : RANGOS.length) + ' rangos') +
      '<ol class="rt-escala">';
    RANGOS.forEach(function(x){
      var mio = r.actual && r.actual.clave === x.clave;
      h += '<li class="' + (mio ? 'mio' : '') + (p < Number(x.desde_puntos||0) ? ' porllegar' : '') + '">' +
        disco(x) + '<span class="n">' + esc(x.nombre) + '</span>' +
        '<span class="d">' + Number(x.desde_puntos||0) + '</span>' +
        (mio ? '<span class="tuyo">tu rango</span>' : '') + '</li>';
    });
    return h + '</ol>' +
      '<div class="rt-porques">' +
        '<div><b>El rango no se pierde</b><span>Una vez alcanzado, se queda. Quien deja el club un año y vuelve, ' +
          'vuelve con el suyo.</span></div>' +
        '<div><b>El último es de varios años</b><span>No se alcanza en una temporada: es a propósito, para que ' +
          'siempre quede a dónde ir.</span></div>' +
        '<div><b>No hay clasificación</b><span>Te comparas contigo, no con los demás. La competición del club es ' +
          'la Liga Apolana.</span></div>' +
      '</div>';
  }

  /* --- medallas: rejilla de cuatro con aro ámbar (38b) --- */
  function pintarMedallas(){
    var tengo = MEDALLAS.filter(function(m){ return !!MIAS[m.id]; });
    var faltan = MEDALLAS.filter(function(m){ return !MIAS[m.id]; });
    var lista = tengo.concat(faltan);
    var h = rotulo('Medallas', MEDALLAS.length ? (tengo.length + ' de ' + MEDALLAS.length) : null);
    if(!lista.length){
      return h + APOLANA_UI.vacio('Todavía no hay medallas',
        'El club aún no ha creado ninguna. En cuanto las tenga aparecerán aquí y se irán encendiendo solas ' +
        'según vayas cumpliendo cosas.');
    }
    h += '<div class="rt-medallas">' + lista.map(function(m){
      var si = !!MIAS[m.id];
      var pie = si ? ('Conseguida el ' + fCorta(MIAS[m.id])) : (m.descripcion || '');
      return '<div class="rt-med ' + (si?'si':'no') + '" title="' + esc(pie) + '">' +
        '<span class="aro">' + ico(iconoDe(m.criterio), 22) + '</span>' +
        '<span class="n">' + esc(m.titulo) + '</span></div>';
    }).join('') + '</div>';
    if(!tengo.length) h += '<p class="rt-nota-sec">Todas se consiguen solas: no hay que pedir ninguna.</p>';
    return h;
  }

  /* --- clasificación: solo si el club enciende el interruptor --- */
  function pintarTabla(){
    if(!RANKING) return '';
    var h = rotulo('Clasificación del club');
    if(!TABLA.length){
      return h + APOLANA_UI.vacio('Todavía no hay nadie en la clasificación',
        'En cuanto la gente del club diga que quiere participar, esto se llena solo.');
    }
    var top = TABLA.slice(0, 20);
    var yoDentro = top.some(function(f){ return f.atleta_id === ATLETA.id; });
    var yoFila = null;
    for(var i=0;i<TABLA.length;i++) if(TABLA[i].atleta_id === ATLETA.id) yoFila = TABLA[i];
    function fila(f){
      var r = rangoDe(Number(f.puntos||0)).actual;
      return '<div class="rt-fila"><span class="t">' + Number(f.puesto) + '. ' + esc(f.nombre) + '</span>' +
             '<span class="f">' + esc(nombreRango(r, f.rango)) + ' · ' + Number(f.puntos) + '</span></div>';
    }
    h += '<div class="rt-filas">' + top.map(fila).join('');
    if(yoFila && !yoDentro) h += '<div class="rt-corte">Tu posición</div>' + fila(yoFila);
    return h + '</div>';
  }

  /* ============================================================
     GENTE DEL CLUB
     Solo sale quien se deja ver. Ni marcas, ni tiempos, ni datos de
     contacto: solo rango, medallas y retos.
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
      '<span class="chev" aria-hidden="true">' + ico('entrar', 20) + '</span></a>';
  }

  function pintarBuscador(){
    var h = rotulo('Gente del club');
    if(!MIEMBROS.length){
      return h + APOLANA_UI.vacio('Todavía no se deja ver nadie',
        'Aquí saldrá quien haya dicho que quiere que el resto del club pueda abrir su ficha: su rango, sus ' +
        'medallas y los retos que ha cumplido. Nada más.');
    }
    h += '<p class="rt-nota-sec">De cada persona se ve su rango, sus medallas y sus retos. Ni marcas, ni tiempos, ' +
         'ni datos de contacto.</p>' +
         '<input type="search" id="bs-txt" class="rt-buscar" placeholder="Buscar por nombre…" ' +
         'aria-label="Buscar a alguien del club" autocomplete="off" value="' + esc(BUSCA) + '">' +
         '<div class="rt-filas" id="bs-lista">' + listaMiembros() + '</div>';
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
     QUIÉN PUEDE VERTE
     A una cuenta de menor no se le ofrece el interruptor: los
     menores no tienen perfil visible para otros socios, ni con
     permiso familiar. Sus medallas las ven su familia y su
     entrenador, que es como no da problemas.
     ============================================================ */
  function pintarAjustes(){
    var menor = esMenor(ATLETA.fecha_nacimiento);
    var participa = !!(PJ && PJ.participa);
    var h = rotulo('Quién puede verte');

    if(menor){
      h += '<div class="rt-ajustes"><p class="intro"><b>Tus retos son tuyos y los ves siempre.</b> Lo que no hay ' +
        'es ficha abierta al resto del club: mientras seas menor de edad, tu nombre y tu foto no salen en ninguna ' +
        'lista de socios. Tus medallas y tus retos los ven tu familia y tu entrenador.</p>' +
        (participa
          ? '<button type="button" class="rt-btn-borde" id="aj-quitar">Quitarme de la lista del club</button>'
          : '') +
        '<div class="rt-sep"></div>' +
        '<a class="rt-enlace" href="../perfil/"><span><b>Tu foto y tu nombre</b>' +
          'Se cambian en Mi perfil, junto con el resto de tus datos.</span>' +
          '<span class="fl" aria-hidden="true">' + ico('entrar', 20) + '</span></a>' +
        '</div>';
      return h;
    }

    var visible = participa;
    h += '<div class="rt-ajustes">' +
      '<label class="sw"><span class="txt"><b>Perfil visible para otros socios</b>' +
        '<span>Ven tu nombre, tu rango y tus medallas. Nunca tus marcas, tus pagos ni tus datos.' +
        (RANKING ? ' Y saldrías en la clasificación del club.' : '') + '</span></span>' +
        '<input type="checkbox" id="aj-participa"' + (participa?' checked':'') + '><span class="palanca"></span></label>' +

      (visible
        ? '<a class="rt-btn-azul" href="?atleta=' + encodeURIComponent(ATLETA.id) + '">Ver cómo te ven ahora mismo</a>'
        : '<p class="intro" style="margin-top:12px;">Ahora mismo no sales en la lista del club: nadie puede abrir ' +
          'tu ficha.</p>') +

      '<div class="rt-sep"></div>' +

      '<a class="rt-enlace" href="../perfil/"><span><b>Tu foto y tu nombre</b>' +
        'Se cambian en Mi perfil, junto con el resto de tus datos.</span>' +
        '<span class="fl" aria-hidden="true">' + ico('entrar', 20) + '</span></a>' +
    '</div>';
    return h;
  }

  function pintarCierre(){
    return '<div class="rt-cierre"><b>Esto se cuenta solo</b>' +
      '<p>No hay que apuntarse a ningún reto ni avisar de nada: sale de las asistencias, las competiciones, ' +
      'las marcas y los tests que el club ya apunta cada día. Si algo no te cuadra, díselo a tu entrenador.</p>' +
      '<p>Aquí no se compara a nadie con nadie. La competición del club es la ' +
      '<a href="../../liga/">Liga Apolana</a>.</p></div>';
  }

  /* ============================================================
     SUBIR DE RANGO · pantalla completa
     ------------------------------------------------------------
     Solo al subir de rango: siete veces en la vida de un atleta. Un
     reto normal no interrumpe nada; si todo interrumpe, nada
     importa. Siempre dice POR QUÉ, y va sin confeti ni animación.
     ============================================================ */
  function memoriaClave(){ return 'apolana.retos.rango.' + ATLETA.id; }
  function rangoGuardado(){
    try { var v = localStorage.getItem(memoriaClave()); return v == null ? null : parseInt(v, 10); }
    catch(e){ return null; }
  }
  function guardarRango(orden){
    try { localStorage.setItem(memoriaClave(), String(orden)); } catch(e){ /* sin memoria, no se celebra y ya está */ }
  }

  function porQue(){
    var retos = Object.keys(LOGROS).length, medallas = Object.keys(MIAS).length;
    var partes = [];
    if(retos) partes.push(retos + (retos===1 ? ' reto conseguido' : ' retos conseguidos'));
    if(medallas) partes.push(medallas + (medallas===1 ? ' medalla' : ' medallas'));
    if(!partes.length) return 'Lo has ganado entrenando con el club.';
    return 'Llevas ' + partes.join(' y ') + ' con el club.';
  }

  function ultimoLogro(){
    var mejor = null;
    RETOS.forEach(function(r){
      var l = LOGROS[r.id];
      if(!l) return;
      if(!mejor || String(l.completado_en) > String(mejor.logro.completado_en)) mejor = { reto: r, logro: l };
    });
    return mejor;
  }

  function mirarSiHeSubido(){
    if(!RANGOS.length) return;
    var r = rangoDe(misPuntos()).actual;
    if(!r) return;
    var ahora = Number(r.orden || 0);
    var antes = rangoGuardado();
    guardarRango(ahora);
    /* La primera vez no se celebra nada: no se sabe de dónde viene. */
    if(antes == null || ahora <= antes) return;

    var u = ultimoLogro();
    var caja = '';
    if(u){
      caja = '<div class="caja"><span class="rot">Lo que lo ha desbloqueado</span>' +
        '<div class="reto"><span class="ic">' + ico(iconoDe(u.reto.metrica), 17) + '</span>' +
        '<span class="t">' + esc(u.reto.titulo) + '</span>' +
        '<span class="p">+' + Number(u.logro.puntos_otorgados||0) + '</span></div>' +
        '<div class="total"><span>Total</span><b>' + misPuntos() + ' puntos</b></div></div>';
    } else {
      caja = '<div class="caja"><div class="total"><span>Total</span><b>' + misPuntos() + ' puntos</b></div></div>';
    }

    var capa = document.createElement('div');
    capa.className = 'rt-subida';
    capa.setAttribute('role', 'dialog');
    capa.setAttribute('aria-modal', 'true');
    capa.innerHTML =
      '<div class="cima">' + medalla(r, 'g') +
        '<span class="eti">Has subido de rango</span>' +
        '<span class="rango">' + esc(nombreRango(r)) + '</span>' +
        '<span class="porque">' + esc(porQue()) + '</span>' +
      '</div>' + caja +
      '<div class="salida"><button type="button" id="sub-cerrar">Seguir</button></div>';
    document.body.appendChild(capa);
    var b = document.getElementById('sub-cerrar');
    b.addEventListener('click', function(){ if(capa.parentNode) capa.parentNode.removeChild(capa); });
    setTimeout(function(){ b.focus(); }, 40);
  }

  /* ============================================================
     MONTAJE
     ============================================================ */
  function pintar(){
    var h = cabecera('../atleta/#mas', 'Más', 'Mis retos');
    if(FICHAS.length > 1){
      h += '<div class="rt-quien">' + FICHAS.map(function(f){
        return '<button type="button" data-ficha="' + esc(f.id) + '" aria-pressed="' + (f.id===ATLETA.id) + '">' +
               esc(((f.nombre||'') + ' ' + (f.apellidos||'')).trim()) + '</button>';
      }).join('') + '</div>';
    }
    h += tarjetaRango() + pintarEnCurso() + pintarConseguidos() + pintarEscala() + pintarMedallas() +
         pintarTabla() + pintarBuscador() + pintarAjustes() + pintarCierre();
    wrap.innerHTML = h;
    enganchar();
    mirarSiHeSubido();
  }

  function cargando(){
    wrap.innerHTML = cabecera('../atleta/#mas', 'Más', 'Mis retos') + APOLANA_UI.cargando('tarjeta');
  }

  /* ============================================================
     FICHA DE OTRA PERSONA (?atleta=…) · 38b
     Rango, medallas y retos cumplidos. Ni una marca, ni un tiempo,
     ni un dato de contacto.
     ============================================================ */
  async function abrirFicha(id, esMia){
    wrap.innerHTML = cabecera('./', 'Mis retos', 'Ficha') + APOLANA_UI.cargando('tarjeta');
    await cargarRangos();

    var rm = await sb.from('miembros_juego')
      .select('atleta_id,nombre,foto_ruta,puntos,medallas,retos,rango').eq('atleta_id', id).maybeSingle();
    var m = (rm && !rm.error && rm.data) ? rm.data : null;
    var cab = cabecera('./', esMia ? 'Mis retos' : 'Gente del club', 'Ficha');

    if(rm && rm.error){
      wrap.innerHTML = cab + APOLANA_UI.error('No hemos podido abrir esta ficha',
        'Puede ser tu conexión. No se ha perdido nada: vuelve a intentarlo en un momento.');
      return;
    }
    if(!m){
      wrap.innerHTML = cab + APOLANA_UI.vacio('Esta ficha no se puede abrir',
        'Puede que esa persona haya preferido no dejarse ver. Las cuentas de menores no tienen ficha abierta al ' +
        'resto del club.',
        APOLANA_UI.boton('Volver a los retos', './'));
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
    var puesto = r ? (ROMANOS.indexOf(claveRango(r)) + 1) : 0;

    var h = cab;

    if(esMia){
      h += '<div class="rt-aviso"><span class="ic-caja">' + ico('aviso', 20) + '</span>' +
        '<div><b>Así te ven los demás</b><p>Esto es exactamente lo que enseña tu ficha al resto del club: ni una ' +
        'cosa más. Se apaga desde «Quién puede verte», en la pantalla anterior.</p></div></div>';
    }

    h += '<div class="rt-cabficha">' +
        '<div class="fila"><span class="cara-g">' + cara + '</span>' +
          '<div class="quien"><b>' + esc(m.nombre) + '</b>' +
          '<span>' + Number(m.retos||0) + (Number(m.retos)===1 ? ' reto cumplido' : ' retos cumplidos') + '</span></div>' +
        '</div>' +
        (r ? '<div class="caja">' + medalla(r, 's') +
          '<div><span class="n">' + esc(nombreRango(r, m.rango)) + '</span>' +
          '<span class="d">' + (puesto>0 && RANGOS.length ? ('Rango ' + puesto + ' de ' + RANGOS.length) : 'Su rango') +
          '</span></div></div>' : '') +
      '</div>';

    h += rotulo('Medallas', meds.length || null);
    h += meds.length
      ? '<div class="rt-medallas">' + meds.map(function(x){
          return '<div class="rt-med si" title="' + esc(x.descripcion||'') + '">' +
            '<span class="aro">' + ico('hecho', 22) + '</span>' +
            '<span class="n">' + esc(x.titulo) + '</span></div>';
        }).join('') + '</div>'
      : APOLANA_UI.vacio('Todavía no tiene ninguna medalla',
          'Cuando consiga la primera aparecerá aquí.');

    h += rotulo('Retos cumplidos', logs.length || null);
    h += logs.length
      ? '<div class="rt-filas">' + logs.map(function(x){
          return '<div class="rt-fila"><span class="visto">' + ico('hecho', 16) + '</span>' +
            '<span class="t">' + esc(x.titulo) + '</span>' +
            '<span class="f">' + esc(fCorta(x.completado_en)) + '</span></div>';
        }).join('') + '</div>'
      : APOLANA_UI.vacio('Todavía no ha cumplido ningún reto',
          'En cuanto el club dé por bueno el primero, saldrá en esta lista.');

    h += '<div class="rt-cierre"><p>Aquí no se ven marcas, tiempos, pagos ni datos de contacto. Solo el rango, ' +
         'las medallas y los retos cumplidos.</p></div>';

    wrap.innerHTML = h;
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
        cargando();
        await cargarTodo(); pintar();
      });
    });

    /* Un solo interruptor: se guarda al momento, sin botón de por medio. */
    var sw = $('aj-participa');
    if(sw) sw.addEventListener('change', function(){ guardarParticipa(this.checked, this); });

    var quitar = $('aj-quitar');
    if(quitar) quitar.addEventListener('click', function(){ guardarParticipa(false, null); });

    var bs = $('bs-txt');
    if(bs) bs.addEventListener('input', function(){
      BUSCA = this.value || '';
      var lista = $('bs-lista');
      if(lista) lista.innerHTML = listaMiembros();
    });
  }

  async function guardarParticipa(quiere, chk){
    if(chk) chk.disabled = true;
    var r = await sb.from('perfil_juego')
      .upsert({ atleta_id: ATLETA.id, participa: quiere }, { onConflict: 'atleta_id' })
      .select('atleta_id,participa,autoriza_parental_en,puntos').maybeSingle();
    if(chk) chk.disabled = false;
    if(r.error){
      if(chk) chk.checked = !quiere;
      aviso('No hemos podido guardar el cambio', 'error', { detalle: 'Puede ser tu conexión.' });
      return;
    }
    PJ = r.data || PJ;
    aviso(quiere ? 'Hecho: ya puedes salir en la lista del club' : 'Hecho: has dejado de salir en la lista');

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
    wrap.innerHTML = cabecera('../', 'Portal', 'Mis retos') +
      APOLANA_UI.error('No hemos podido cargar tus retos',
        'Puede ser tu conexión. No se ha perdido nada de lo que llevas conseguido.');
    return;
  }

  if(!FICHAS.length){
    wrap.innerHTML = cabecera('../', 'Portal', 'Mis retos') +
      APOLANA_UI.vacio('Esta pantalla es para los atletas del club',
        'Tu cuenta no tiene ninguna ficha de atleta asociada, y los retos se cuentan por atleta. Si crees que ' +
        'es un error, escríbele al club y lo miran.',
        APOLANA_UI.boton('Volver al portal', '../'));
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
