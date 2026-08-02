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
    crono: '<circle cx="12" cy="14" r="7"/><path d="M12 10.5V14l2.5 1.6M9.5 3.5h5M12 3.5V7"/>',
    lapiz: '<path d="M4 20h4l10-10-4-4L4 16v4z"/><path d="M13.5 6.5l4 4"/>'
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
    if(d === 1) return 'queda 1 día';
    if(r.periodo === 'mes') return 'quedan ' + d + ' de mes';
    if(r.periodo === 'semana') return 'quedan ' + d + ' de semana';
    return 'quedan ' + d + ' días';
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
  /* Los retos que se pone uno mismo (38b y 38c). Van aparte de los del
     club a propósito: ni dan puntos, ni suben de rango, ni los ve nadie. */
  var MIOS = [], MIOS_VAL = {}, HIST = {}, FALLO_MIOS = false, FORM = null;
  var TOPE_MIOS = 3;
  var RANKING = false;   /* la clasificación viene apagada: la enciende el club */
  /* El perfil entre socios está construido pero apagado (068). Mientras lo
     esté, no se enseña la lista del club: decirle a alguien «todavía no se
     deja ver nadie» suena a que nadie ha querido, cuando lo que pasa es que
     no está encendido. Y el interruptor de verdad vive en «Mi perfil». */
  var PERFIL_SOCIOS = false;
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

    /* La clasificación y el perfil entre socios solo se piden si el club los
       tiene encendidos. Los dos nacen apagados. */
    var rk = await sb.from('juego_ajustes').select('ranking_publico,perfil_socios').eq('id', 1).maybeSingle();
    RANKING       = !!(rk && !rk.error && rk.data && rk.data.ranking_publico);
    PERFIL_SOCIOS = !!(rk && !rk.error && rk.data && rk.data.perfil_socios);
    TABLA = RANKING ? await cargarTabla() : [];

    MIEMBROS = PERFIL_SOCIOS ? await cargarMiembros() : [];
    await cargarMios();

    await firmarFotos(MIEMBROS.map(function(x){ return x.foto_ruta; })
      .concat(TABLA.map(function(x){ return x.foto_ruta; })));
  }

  async function cargarMiembros(){
    var r = await sb.from('miembros_juego')
      .select('atleta_id,nombre,foto_ruta,puntos,medallas,retos,rango')
      .order('nombre').limit(400);
    return r.error ? [] : (r.data || []);
  }

  /* Los retos propios y cuánto llevas de cada uno. Lo que llevas NO se
     guarda en ninguna parte: se calcula cada vez con las asistencias,
     los entrenos contados y las competiciones que ya están apuntadas.
     Por eso no hay nada que marcar a mano. */
  async function cargarMios(){
    FALLO_MIOS = false;
    var r = await sb.from('retos_propios')
      .select('id,metrica,objetivo,periodo,desde,hasta')
      .eq('atleta_id', ATLETA.id).order('hasta').order('creado_en');
    if(r.error){ FALLO_MIOS = true; MIOS = []; MIOS_VAL = {}; return; }
    MIOS = r.data || [];
    MIOS_VAL = {};
    if(!MIOS.length) return;
    var p = await sb.rpc('retos_propios_progreso', { p_atleta: ATLETA.id });
    if(p.error){ FALLO_MIOS = true; return; }
    (p.data || []).forEach(function(x){ MIOS_VAL[x.reto_id] = Number(x.valor || 0); });
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
      return rotulo('Del club') + APOLANA_UI.error('No hemos podido cargar tus retos',
        'Puede ser tu conexión. Tus puntos y tus medallas siguen guardados: no se pierde nada.');
    }
    /* Se ordenan por lo que falta menos, no por fecha ni por puntos. */
    var abiertos = RETOS.filter(function(r){ return !LOGROS[r.id]; }).sort(function(a,b){
      var d = restanteDe(a) - restanteDe(b);
      if(d) return d;
      return diasQuedan(a) - diasQuedan(b);
    });
    if(!abiertos.length){
      return rotulo('Del club') + APOLANA_UI.vacio('Ahora mismo no hay ningún reto abierto',
        'El club irá proponiendo retos nuevos a lo largo de la temporada. Mientras tanto, todo lo que entrenas ' +
        'se sigue apuntando y cuenta igual.',
        APOLANA_UI.boton('Ver el calendario del club', '../../calendario/'));
    }
    /* El primero lleva borde ámbar cuando de verdad le falta poco: va por
       la mitad o más y todavía no ha caído. Eso lo convierte en un plan.
       Si nadie está cerca no se destaca ninguno: sería mentir. */
    var p0 = abiertos[0];
    var v0 = Number(PROGRESO[p0.id]||0), o0 = Number(p0.objetivo||0);
    var destacar = v0 > 0 && o0 > 0 && v0 < o0 && restanteDe(p0) <= 0.5;
    return rotulo('Del club', abiertos.length + (abiertos.length===1?' abierto':' abiertos')) +
      abiertos.map(function(r, i){ return tarjetaReto(r, destacar && i === 0); }).join('');
  }

  /* ============================================================
     LOS RETOS QUE SE PONE UNO MISMO · 38b y 38c
     ------------------------------------------------------------
     LOS TUYOS EN NAVY, LOS DEL CLUB EN ÁMBAR. Los tuyos, además, sin
     icono y sin puntos: así se distinguen de un vistazo y sin rótulos
     largos. Y no dan puntos a propósito — si los dieran, cualquiera se
     pondría «entrenar 1 día» y subiría de rango.

     QUÉ SE SABE CONTAR DE VERDAD, y por qué no están los cinco de la
     maqueta: los días de entreno, los metros a nado y las competiciones
     salen de lo que el club ya apunta. Los KILÓMETROS no: la distancia
     de cada serie se escribe a mano y mezcla minutos, metros y «40 min
     en bici», así que no hay de dónde sacar un total honesto. El
     DESNIVEL no existe en ninguna tabla. Ofrecer un contador que
     siempre marca cero es peor que no ofrecerlo.
     ============================================================ */
  var MIS_METRICAS = ['dias_entreno', 'metros_natacion', 'competiciones'];
  var MI_FMT = {
    dias_entreno:    { chip: 'Días de entreno', uno: 'día',    varios: 'días',
                       largo: 'días de entreno', largoUno: 'día de entreno', suf: '' },
    metros_natacion: { chip: 'Metros a nado',   uno: 'metro',  varios: 'metros',
                       largo: 'metros a nado',   largoUno: 'metro a nado',   suf: ' m' },
    competiciones:   { chip: 'Competiciones',   uno: 'competición', varios: 'competiciones',
                       largo: 'competiciones',   largoUno: 'competición',    suf: '' }
  };
  var MI_PLAZO   = { mes: 'Este mes',        trimestre: 'Este trimestre',        temporada: 'La temporada' };
  var MI_CUANDO  = { mes: 'este mes',        trimestre: 'este trimestre',        temporada: 'esta temporada' };
  var MI_ESTE    = { mes: 'Este mes',        trimestre: 'Este trimestre',        temporada: 'Esta temporada' };
  var MI_ANTES   = { mes: 'mes pasado',      trimestre: 'trimestre pasado',      temporada: 'temporada pasada' };
  var MI_MEJOR   = { mes: 'mes',             trimestre: 'trimestre',             temporada: 'temporada' };
  /* Un punto de partida para quien todavía no tiene historial. No es
     una recomendación de nadie: es un número redondo por el que empezar. */
  var MI_DEFECTO = {
    dias_entreno:    { mes: 8,    trimestre: 24,    temporada: 80 },
    metros_natacion: { mes: 8000, trimestre: 24000, temporada: 80000 },
    competiciones:   { mes: 1,    trimestre: 2,     temporada: 4 }
  };
  var MESES_LARGOS = ['enero','febrero','marzo','abril','mayo','junio',
                      'julio','agosto','septiembre','octubre','noviembre','diciembre'];

  function nf(n){ return Number(n || 0).toLocaleString('es-ES'); }
  function fLarga(iso){
    var p = String(iso || '').slice(0,10).split('-');
    return p.length === 3 ? (parseInt(p[2],10) + ' de ' + MESES_LARGOS[parseInt(p[1],10)-1]) : '';
  }
  /* «junio», «sep–nov» o «2025-26»: el plazo dicho como lo diría una persona. */
  function etiquetaPlazo(iso, periodo){
    var p = String(iso || '').slice(0,10).split('-');
    if(p.length !== 3) return '';
    var y = parseInt(p[0],10), m = parseInt(p[1],10) - 1;
    if(periodo === 'temporada') return y + '-' + String(y + 1).slice(2);
    if(periodo === 'trimestre') return MESES[m] + '–' + MESES[(m + 2) % 12];
    return MESES_LARGOS[m] + (y === new Date().getFullYear() ? '' : ' de ' + y);
  }

  function unidadMia(metrica, n){
    var f = MI_FMT[metrica]; if(!f) return '';
    return Number(n) === 1 ? f.largoUno : f.largo;
  }
  function tituloMio(r){
    var f = MI_FMT[r.metrica], o = Number(r.objetivo || 0);
    if(!f) return '';
    return nf(o) + ' ' + (o === 1 ? f.uno : f.varios) + ' ' + MI_CUANDO[r.periodo];
  }
  function valorMio(r){ return Number(MIOS_VAL[r.id] || 0); }
  function logradoMio(r){ return valorMio(r) >= Number(r.objetivo || 0); }
  function cerradoMio(r){ return dia(r.hasta) < hoy(); }
  function diasMio(r){ return Math.round((dia(r.hasta) - hoy()) / 86400000); }
  function quedaMio(r){
    var d = diasMio(r);
    if(d < 0) return 'se cerró el ' + fCorta(r.hasta);
    if(d === 0) return 'último día';
    if(d === 1) return 'queda 1 día';
    if(r.periodo === 'mes') return 'quedan ' + d + ' de mes';
    return 'quedan ' + d + ' días';
  }
  function restanteMio(r){
    var o = Number(r.objetivo || 0);
    if(o <= 0) return 1;
    return Math.max(0, (o - valorMio(r)) / o);
  }
  /* El historial ya pedido para esa métrica, si lo hay. */
  function hist(metrica, periodo){
    var h = HIST[metrica];
    return (h && !h.fallo && h[periodo]) ? h[periodo] : null;
  }

  function tarjetaMia(r, cerca){
    var f = MI_FMT[r.metrica];
    if(!f) return '';
    var obj = Number(r.objetivo || 0), val = valorMio(r);
    var pct = obj > 0 ? Math.max(0, Math.min(100, Math.round(val * 100 / obj))) : 0;
    var cerrado = cerradoMio(r);
    var d = hist(r.metrica, r.periodo);
    var sub = (d && Number(d.mejor) > 0)
      ? ('Tu mejor ' + MI_MEJOR[r.periodo] + ', ' + nf(d.mejor))
      : ('Desde el ' + fLarga(r.desde));

    return '<article class="rt-mio' + (cerca ? ' cerca' : '') + (cerrado ? ' cerrado' : '') + '">' +
      '<div class="cab">' +
        '<div class="tit"><h2>' + esc(tituloMio(r)) + '</h2><p>' + esc(sub) + '</p></div>' +
        '<button type="button" class="editar" data-mio="' + esc(r.id) + '" ' +
          'aria-label="Cambiar el reto: ' + esc(tituloMio(r)) + '"><i>' + ico('lapiz', 19) + '</i></button>' +
      '</div>' +
      '<span class="barra"><i style="width:' + pct + '%"></i></span>' +
      '<div class="pie"><span class="n">' + nf(val) + ' de ' + nf(obj) + esc(f.suf) + '</span>' +
        '<span class="p">' + esc(quedaMio(r)) + '</span></div>' +
    '</article>';
  }

  function pintarMios(){
    var enMarcha = MIOS.filter(function(r){ return !logradoMio(r) && !cerradoMio(r); })
                       .sort(function(a,b){ return restanteMio(a) - restanteMio(b); });
    var pasados  = MIOS.filter(function(r){ return !logradoMio(r) && cerradoMio(r); });

    /* Con tres en marcha el botón se apaga: mejor eso que dejar rellenar
       una pantalla entera para decir que no al final. El porqué va escrito
       debajo de la lista. */
    var h = '<div class="rt-rot rt-rot--boton"><b>Míos</b>' +
            '<button type="button" class="rt-nuevo" id="mi-nuevo"' +
            (enMarcha.length >= TOPE_MIOS ? ' disabled' : '') + '>+ Nuevo</button></div>';

    if(FALLO_MIOS){
      return h + APOLANA_UI.error('No hemos podido cargar tus retos',
        'Puede ser tu conexión. Los que te hayas puesto siguen guardados: no se pierde nada.');
    }

    if(!enMarcha.length && !pasados.length){
      return h + APOLANA_UI.vacio('Todavía no te has puesto ninguno',
        'Un reto tuyo es solo tuyo: no da puntos, no sube de rango y no lo ve nadie más, ni tu entrenador. ' +
        'Se cuenta solo con los entrenos y las competiciones que el club ya apunta.',
        '<button type="button" class="ap-btn" id="mi-nuevo-vacio">Ponerme un reto</button>');
    }

    h += '<p class="rt-nota-sec">Solo los ves tú. No dan puntos y no salen en ningún sitio del club.</p>';
    /* El primero, al que menos le falta, con borde navy de 2 px: es el
       que tienes más a mano y el que convierte el reto en un plan. */
    h += enMarcha.map(function(r, i){ return tarjetaMia(r, i === 0); }).join('');
    h += pasados.map(function(r){ return tarjetaMia(r, false); }).join('');
    if(enMarcha.length >= TOPE_MIOS){
      h += '<p class="rt-nota-sec">Ya llevas tres a la vez, que es el tope. Quita uno y te pones otro.</p>';
    }
    return h;
  }

  function pintarConseguidos(){
    var hechos = RETOS.filter(function(r){ return !!LOGROS[r.id]; }).sort(function(a,b){
      return String(LOGROS[b.id].completado_en).localeCompare(String(LOGROS[a.id].completado_en));
    });
    var miosHechos = MIOS.filter(logradoMio);
    if(!hechos.length && !miosHechos.length) return '';
    return rotulo('Conseguidos', String(hechos.length + miosHechos.length)) +
      '<div class="rt-filas">' +
      hechos.map(function(r){
        return '<div class="rt-fila"><span class="visto">' + ico('hecho', 16) + '</span>' +
          '<span class="t">' + esc(r.titulo) + '</span>' +
          '<span class="f">' + esc(fCorta(LOGROS[r.id].completado_en)) + '</span></div>';
      }).join('') +
      /* Los tuyos también se pueden quitar desde aquí: por eso llevan lápiz. */
      miosHechos.map(function(r){
        return '<div class="rt-fila"><span class="visto">' + ico('hecho', 16) + '</span>' +
          '<span class="t">' + esc(tituloMio(r)) + '</span>' +
          '<button type="button" class="editar" data-mio="' + esc(r.id) + '" ' +
            'aria-label="Cambiar el reto: ' + esc(tituloMio(r)) + '"><i>' + ico('lapiz', 18) + '</i></button></div>';
      }).join('') + '</div>';
  }

  /* ============================================================
     PONERME UN RETO · tres toques · 38b
     ------------------------------------------------------------
     Qué contar · cuántos · hasta cuándo. Y el objetivo se propone con
     el historial de esa persona: sin eso la gente pone un número al
     azar y falla.
     ============================================================ */
  function propuesta(metrica, periodo){
    var d = hist(metrica, periodo);
    if(!d) return MI_DEFECTO[metrica][periodo];
    var ant = Number(d.anterior || 0), mej = Number(d.mejor || 0), act = Number(d.actual || 0);
    var p;
    if(ant > 0 || mej > 0){
      /* Un poco por encima de la última vez, pero sin pedirte más de lo
         que ya has hecho alguna vez: así se pone un objetivo que se cumple. */
      p = Math.round(ant > 0 ? ant * 1.25 : mej * 0.9);
      if(mej > 0) p = Math.min(p, Math.max(mej, ant + 1));
    } else if(act > 0){
      p = Math.round(act * 1.25);              /* sin historial, pero ya llevas algo */
    } else {
      p = MI_DEFECTO[metrica][periodo];        /* nada de nada: un número por el que empezar */
    }
    /* Y nunca por debajo de lo que ya llevas hecho: un reto que nace
       cumplido no es un reto. */
    p = Math.max(p, ant + 1, act + 1, 1);
    if(metrica === 'metros_natacion') p = Math.max(100, Math.ceil(p / 100) * 100);
    return p;
  }

  function pistaHistorial(){
    var h = HIST[FORM.metrica];
    if(!h) return 'Mirando lo que llevas hecho…';
    if(h.fallo) return 'No hemos podido mirar tu historial. Pon el número que te parezca.';
    var d = h[FORM.periodo];
    if(!d) return '';
    var ant = Number(d.anterior || 0), mej = Number(d.mejor || 0), act = Number(d.actual || 0);
    if(!ant && !mej && !act){
      return 'De esto no tienes todavía nada apuntado, así que el número es solo un punto de partida.';
    }
    var t = [];
    if(ant > 0) t.push('El ' + MI_ANTES[FORM.periodo] + ' hiciste ' + nf(ant) + '.');
    if(mej > 0){
      t.push('Tu mejor ' + MI_MEJOR[FORM.periodo] + ', ' + nf(mej) +
             (d.mejor_desde ? ' (' + etiquetaPlazo(d.mejor_desde, FORM.periodo) + ')' : '') + '.');
    }
    if(act > 0) t.push(MI_ESTE[FORM.periodo] + ' llevas ' + nf(act) + '.');
    return t.join(' ');
  }

  function refrescarCuantos(){
    var inp = $('fm-objetivo');
    if(FORM && !FORM.tocado){
      FORM.objetivo = propuesta(FORM.metrica, FORM.periodo);
      if(inp) inp.value = FORM.objetivo;
    }
    var u = $('fm-unidad'); if(u) u.textContent = unidadMia(FORM.metrica, FORM.objetivo);
    var p = $('fm-pista');  if(p) p.textContent = pistaHistorial();
  }

  async function cargarHistorial(metrica){
    if(HIST[metrica]){ refrescarCuantos(); return; }
    var r = await sb.rpc('retos_propios_historial', { p_atleta: ATLETA.id, p_metrica: metrica });
    if(r.error){ HIST[metrica] = { fallo: true }; }
    else {
      var o = {};
      (r.data || []).forEach(function(x){ o[x.periodo] = x; });
      HIST[metrica] = o;
    }
    if(FORM && FORM.metrica === metrica) refrescarCuantos();
  }

  function chips(nombre, opciones, elegida){
    return '<div class="rt-chips">' + opciones.map(function(o){
      return '<button type="button" data-' + nombre + '="' + esc(o.v) + '" aria-pressed="' +
             (o.v === elegida) + '">' + esc(o.t) + '</button>';
    }).join('') + '</div>';
  }

  function pintarForm(){
    var nuevo = !FORM.id;
    var h = '<a class="rt-migas" href="./" id="fm-volver"><span class="fl" aria-hidden="true">&larr;</span>Mis retos</a>' +
            '<h1>' + (nuevo ? 'Un reto para mí' : 'Cambiar el reto') + '</h1>';

    h += '<div class="rt-campo"><span class="eti">Qué quieres contar</span>' +
      chips('metrica', MIS_METRICAS.map(function(m){ return { v: m, t: MI_FMT[m].chip }; }), FORM.metrica) +
      '</div>';

    h += '<div class="rt-campo"><span class="eti">Cuántos</span>' +
      '<div class="rt-cifra"><input type="number" id="fm-objetivo" inputmode="numeric" min="1" step="1" ' +
        'value="' + (FORM.objetivo == null ? '' : FORM.objetivo) + '" aria-label="Cuántos"> ' +
        '<span class="u" id="fm-unidad">' + esc(unidadMia(FORM.metrica, FORM.objetivo)) + '</span></div>' +
      '<p class="pista" id="fm-pista">' + esc(pistaHistorial()) + '</p>' +
      '</div>';

    h += '<div class="rt-campo"><span class="eti">Hasta cuándo</span>' +
      chips('plazo', ['mes','trimestre','temporada'].map(function(p){ return { v: p, t: MI_PLAZO[p] }; }), FORM.periodo) +
      '</div>';

    h += '<div class="rt-privado"><b>Solo lo ves tú</b>' +
      '<p>Los retos que te pones no dan puntos ni suben de rango, no los ve tu entrenador y no salen en ningún ' +
      'sitio del club. Se cuentan solos con tus entrenos y tus competiciones: no hay nada que ir marcando.</p></div>';

    h += '<div class="rt-pie">' +
      '<button type="button" class="principal" id="fm-guardar">' +
        (nuevo ? 'Ponerme el reto' : 'Guardar el cambio') + '</button>' +
      (nuevo ? '' : '<button type="button" class="quitar" id="fm-quitar">Quitar este reto</button>') +
    '</div>';

    wrap.innerHTML = h;
    engancharForm();
  }

  function abrirForm(reto){
    FORM = reto
      ? { id: reto.id, metrica: reto.metrica, objetivo: Number(reto.objetivo), periodo: reto.periodo, tocado: true }
      : { id: null, metrica: MIS_METRICAS[0], objetivo: null, periodo: 'mes', tocado: false };
    if(!FORM.tocado) FORM.objetivo = propuesta(FORM.metrica, FORM.periodo);
    pintarForm();
    window.scrollTo(0, 0);
    cargarHistorial(FORM.metrica);
  }

  function engancharForm(){
    var volver = $('fm-volver');
    if(volver) volver.addEventListener('click', function(e){ e.preventDefault(); FORM = null; pintar(); });

    Array.prototype.forEach.call(wrap.querySelectorAll('[data-metrica]'), function(b){
      b.addEventListener('click', function(){
        var m = b.getAttribute('data-metrica');
        if(m === FORM.metrica) return;
        FORM.metrica = m;
        Array.prototype.forEach.call(wrap.querySelectorAll('[data-metrica]'), function(x){
          x.setAttribute('aria-pressed', String(x.getAttribute('data-metrica') === m));
        });
        refrescarCuantos();
        cargarHistorial(m);
      });
    });

    Array.prototype.forEach.call(wrap.querySelectorAll('[data-plazo]'), function(b){
      b.addEventListener('click', function(){
        var p = b.getAttribute('data-plazo');
        if(p === FORM.periodo) return;
        FORM.periodo = p;
        Array.prototype.forEach.call(wrap.querySelectorAll('[data-plazo]'), function(x){
          x.setAttribute('aria-pressed', String(x.getAttribute('data-plazo') === p));
        });
        refrescarCuantos();
      });
    });

    var inp = $('fm-objetivo');
    if(inp) inp.addEventListener('input', function(){
      FORM.tocado = true;
      FORM.objetivo = parseInt(this.value, 10);
      var u = $('fm-unidad'); if(u) u.textContent = unidadMia(FORM.metrica, FORM.objetivo);
    });

    var g = $('fm-guardar');
    if(g) g.addEventListener('click', function(){ guardarMio(g); });

    var q = $('fm-quitar');
    if(q) q.addEventListener('click', function(){ quitarMio(FORM.id); });
  }

  async function guardarMio(btn){
    var o = parseInt(FORM.objetivo, 10);
    if(!(o > 0)){
      aviso('Escribe cuántos quieres hacer', 'error', { detalle: 'Un reto sin número no se puede contar.' });
      var i = $('fm-objetivo'); if(i) i.focus();
      return;
    }
    btn.disabled = true;
    var esNuevo = !FORM.id;
    var fila = { metrica: FORM.metrica, objetivo: o, periodo: FORM.periodo };
    var r = esNuevo
      ? await sb.from('retos_propios').insert({ atleta_id: ATLETA.id, metrica: fila.metrica,
                                                objetivo: fila.objetivo, periodo: fila.periodo })
      : await sb.from('retos_propios').update(fila).eq('id', FORM.id);
    btn.disabled = false;
    if(r.error){
      /* El tope de tres lo pone la base de datos, y lo dice con estas mismas
         palabras: se enseña tal cual en vez de inventar otro texto. Y sin
         «Reintentar», que aquí no arreglaría nada: no es un fallo, es la regla. */
      var m = String(r.error.message || '');
      if(/tres retos/.test(m)) aviso(m, 'error', { accion: { texto: 'Entendido', fn: function(){} } });
      else aviso('No hemos podido guardar el reto', 'error', { detalle: 'Puede ser tu conexión. Vuelve a intentarlo.' });
      return;
    }
    FORM = null;
    await cargarMios();
    pintar();
    aviso(esNuevo ? 'Hecho: ya tienes tu reto' : 'Hecho: reto cambiado');
    await historialesDeMisRetos();
  }

  async function quitarMio(id){
    var ok = await APX.confirm('¿Quitamos este reto? No hace falta explicar nada.',
      { aceptar: 'Quitarlo', cancelar: 'Dejarlo', peligro: true });
    if(!ok) return;
    var r = await sb.from('retos_propios').delete().eq('id', id);
    if(r.error){
      aviso('No hemos podido quitarlo', 'error', { detalle: 'Puede ser tu conexión. Vuelve a intentarlo.' });
      return;
    }
    FORM = null;
    await cargarMios();
    pintar();
    aviso('Hecho: reto quitado');
  }

  /* El historial se pide después de pintar, para que la pantalla no
     espere por él: es lo que hace que la tarjeta pueda decir «tu mejor
     mes fueron 15» en vez de solo la fecha de arranque. */
  async function historialesDeMisRetos(){
    var faltan = [];
    MIOS.forEach(function(r){
      if(!HIST[r.metrica] && faltan.indexOf(r.metrica) === -1) faltan.push(r.metrica);
    });
    if(!faltan.length) return;
    for(var i = 0; i < faltan.length; i++) await cargarHistorial(faltan[i]);
    if(!FORM) pintar();
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
    /* Apagado = no existe. Ni lista, ni estado vacío, ni explicación. */
    if(!PERFIL_SOCIOS) return '';
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
  /* UN SOLO INTERRUPTOR, Y NO ESTÁ AQUÍ.
     Antes había dos para lo mismo —este y el de «Mi perfil»—, y había que
     encender los dos para salir: se encendía uno y no pasaba nada, sin
     entender por qué. Desde 068 manda uno solo y se decide en «Mi perfil»,
     junto a la foto y el nombre, que es donde la gente ya va. Aquí queda la
     explicación y el camino, nada más. */
  function pintarAjustes(){
    var h = rotulo('Quién puede verte');
    h += '<div class="rt-ajustes"><p class="intro"><b>Tus retos son tuyos y los ves siempre.</b> ' +
      'El perfil que otros socios pueden abrir está apagado: llegará más adelante.</p>' +
      '<a class="rt-enlace" href="../perfil/"><span><b>Tu perfil entre socios</b>' +
        'Se decide en Mi perfil, junto con tu foto y tu nombre.</span>' +
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
    /* Una sola pantalla y este orden: el rango, los del club (ámbar y con
       puntos), los míos (navy, sin icono y sin puntos) y los conseguidos. */
    h += tarjetaRango() + pintarEnCurso() + pintarMios() + pintarConseguidos() + pintarEscala() +
         pintarMedallas() + pintarTabla() + pintarBuscador() + pintarAjustes() + pintarCierre();
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

    /* Ponerme un reto y cambiar uno que ya tengo. */
    ['mi-nuevo', 'mi-nuevo-vacio'].forEach(function(id){
      var b = $(id);
      if(b) b.addEventListener('click', function(){ abrirForm(null); });
    });
    Array.prototype.forEach.call(wrap.querySelectorAll('[data-mio]'), function(b){
      b.addEventListener('click', function(){
        var id = b.getAttribute('data-mio');
        for(var i=0;i<MIOS.length;i++) if(MIOS[i].id === id) abrirForm(MIOS[i]);
      });
    });

    var bs = $('bs-txt');
    if(bs) bs.addEventListener('input', function(){
      BUSCA = this.value || '';
      var lista = $('bs-lista');
      if(lista) lista.innerHTML = listaMiembros();
    });
  }

  /* ============================================================
     ARRANQUE
     ============================================================ */
  /* Sin perfil no se puede saber de quién son los retos: se dice y se sale.
     Pasa si la sesión está abierta pero su ficha de usuario no se ha podido
     leer, y sin esta guardia la pantalla se quedaría en el esqueleto. */
  if(!perfil || !perfil.id){
    wrap.innerHTML = cabecera('../', 'Portal', 'Mis retos') +
      APOLANA_UI.error('No hemos podido cargar tu cuenta',
        'Puede ser tu conexión. Vuelve a intentarlo y, si sigue igual, cierra sesión y entra otra vez.');
    return;
  }

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
  await historialesDeMisRetos();
});
