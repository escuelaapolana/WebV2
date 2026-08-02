/* ============================================================
   CONFIRMAR ASISTENCIA · «¿vas?» · Club Atletismo Apolana
   ------------------------------------------------------------
   Un solo sitio con toda la lógica y con el bloque de interfaz,
   para engancharlo en varias pantallas sin repetir código.

   CÓMO SE CARGA (después de db.js y del acceso de la zona):
     <script src="../../assets/js/confirmaciones.js" defer></script>

   CÓMO SE ENGANCHA EN UNA PANTALLA (lo normal):
     APOLANA_CONF.bloque(document.getElementById('donde-sea'), {
       evento_id: '…'          // o competicion_id: '…'
     });
   Si esa actividad no pide confirmación, el bloque no pinta nada y
   devuelve null: la pantalla se queda igual que estaba.

   LO DEMÁS QUE OFRECE (por si una pantalla quiere pintar lo suyo):
     APOLANA_CONF.peticion({evento_id})     → la petición o null
     APOLANA_CONF.peticiones([...ids])      → mapa clave → petición
     APOLANA_CONF.resumen(id)               → recuentos y plazas
     APOLANA_CONF.lista(id)                 → quién va (solo el club)
     APOLANA_CONF.responder(id, atleta, r)  → contestar
     APOLANA_CONF.misAtletas()              → por quién puedo contestar
     APOLANA_CONF.misRespuestas(id)         → lo que ya contesté
     APOLANA_CONF.guardarPeticion(datos)    → crear o cambiar (panel)
     APOLANA_CONF.borrarPeticion(id)        → quitar el «¿vas?» (panel)
     APOLANA_CONF.csv(filas)                → texto para exportar
     APOLANA_CONF.frase(resumen)            → «12 van · 3 no · 5 sin contestar»

   ⚠️ MENORES: la respuesta de un menor la da su familia. El módulo lo
   enseña así y, además, la base de datos lo impide por su cuenta: si
   un menor lo intenta, conf_responder() lo rechaza.

   Detrás está la migración 056: tablas «confirmaciones» y
   «confirmaciones_respuestas» y las funciones conf_*.
   ============================================================ */
(function () {
  'use strict';
  if (window.APOLANA_CONF) return;

  var RESPUESTAS = [
    { id: 'voy',      txt: 'Voy' },
    { id: 'no_voy',   txt: 'No voy' },
    { id: 'no_lo_se', txt: 'Aún no lo sé' }
  ];

  /* ---------- utilidades ---------- */
  function db() { return window.APOLANA_DB; }
  function esc(s) { var d = document.createElement('div'); d.textContent = (s == null ? '' : String(s)); return d.innerHTML; }
  function aviso(mensaje, tipo, opciones) {
    if (window.APX && typeof window.APX.toast === 'function') return window.APX.toast(mensaje, tipo, opciones);
    if (typeof window.apoToast === 'function') return window.apoToast(mensaje, tipo, opciones);
    if (tipo === 'error') console.warn('[Apolana] ' + mensaje);
  }
  function plural(n, uno, varios) { return n + ' ' + (n === 1 ? uno : varios); }

  var MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
               'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  var DIAS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];

  function fechaFrase(iso, conHora) {
    if (!iso) return '';
    var d = new Date(iso);
    if (isNaN(d.getTime())) return '';
    var t = DIAS[d.getDay()] + ' ' + d.getDate() + ' de ' + MESES[d.getMonth()];
    if (conHora !== false && (d.getHours() || d.getMinutes())) {
      t += ' a las ' + d.getHours() + (d.getMinutes() ? ':' + (d.getMinutes() < 10 ? '0' : '') + d.getMinutes() : '');
    }
    return t;
  }
  function pasado(iso) { if (!iso) return false; var d = new Date(iso); return !isNaN(d.getTime()) && d.getTime() <= Date.now(); }

  function esMenor(atleta) {
    if (!atleta || !atleta.fecha_nacimiento) return false;
    var d = new Date(atleta.fecha_nacimiento);
    if (isNaN(d.getTime())) return false;
    var limite = new Date();
    limite.setFullYear(limite.getFullYear() - 18);
    return d.getTime() > limite.getTime();
  }

  /* ============================================================
     DATOS
     ============================================================ */
  var CAMPOS = 'id,evento_id,competicion_id,pregunta,nota_club,fecha_limite,plazas,publico,grupos,permite_nota,abierta,created_at';

  /* La petición de una actividad. Acepta {id}, {evento_id} o {competicion_id}. */
  async function peticion(opts) {
    opts = opts || {};
    var sb = db(); if (!sb) return null;
    try {
      var q = sb.from('confirmaciones').select(CAMPOS);
      if (opts.id) q = q.eq('id', opts.id);
      else if (opts.evento_id) q = q.eq('evento_id', opts.evento_id);
      else if (opts.competicion_id) q = q.eq('competicion_id', opts.competicion_id);
      else return null;
      var r = await q.maybeSingle();
      if (r.error) { console.warn('[Apolana] confirmación:', r.error.message); return null; }
      return r.data || null;
    } catch (e) { console.warn('[Apolana] confirmación:', e); return null; }
  }

  /* Varias de golpe, para pintar una lista sin una consulta por fila.
     Devuelve un mapa: 'evento:<id>' y 'competicion:<id>' → petición.   */
  async function peticiones(filtro) {
    var sb = db(); var mapa = {};
    if (!sb) return mapa;
    try {
      var q = sb.from('confirmaciones').select(CAMPOS);
      if (filtro && filtro.eventos && filtro.eventos.length) q = q.in('evento_id', filtro.eventos);
      else if (filtro && filtro.competiciones && filtro.competiciones.length) q = q.in('competicion_id', filtro.competiciones);
      var r = await q;
      if (r.error) { console.warn('[Apolana] confirmaciones:', r.error.message); return mapa; }
      (r.data || []).forEach(function (p) {
        if (p.evento_id) mapa['evento:' + p.evento_id] = p;
        if (p.competicion_id) mapa['competicion:' + p.competicion_id] = p;
        mapa[p.id] = p;
      });
      return mapa;
    } catch (e) { console.warn('[Apolana] confirmaciones:', e); return mapa; }
  }

  /* Recuentos y plazas. Los ve cualquiera que haya entrado: son cifras,
     no nombres. */
  async function resumen(id) {
    var sb = db(); if (!sb || !id) return null;
    try {
      var r = await sb.rpc('conf_resumen', { p_confirmacion: id });
      if (r.error) { console.warn('[Apolana] resumen:', r.error.message); return null; }
      return r.data || null;
    } catch (e) { console.warn('[Apolana] resumen:', e); return null; }
  }

  /* Quién va, quién no y quién falta por contestar. Solo el club:
     un entrenador ve a los suyos, administración ve a todos. */
  async function lista(id) {
    var sb = db(); if (!sb || !id) return { error: 'Sin conexión', filas: [] };
    try {
      var r = await sb.rpc('conf_lista', { p_confirmacion: id });
      if (r.error) return { error: r.error.message, filas: [] };
      return { error: null, filas: r.data || [] };
    } catch (e) { return { error: String(e), filas: [] }; }
  }

  /* Contestar. La base de datos es la que reparte plaza o lista de
     espera, y la que impide que un menor conteste por su cuenta. */
  async function responder(id, atletaId, respuesta, nota) {
    var sb = db();
    if (!sb) return { error: 'No hay conexión con la base de datos.' };
    try {
      var r = await sb.rpc('conf_responder', {
        p_confirmacion: id, p_atleta: atletaId, p_respuesta: respuesta,
        p_nota: (nota == null ? null : String(nota).slice(0, 140))
      });
      if (r.error) return { error: r.error.message };
      return { error: null, datos: r.data };
    } catch (e) { return { error: String(e) }; }
  }

  /* Mi perfil (el de la sesión), cacheado. */
  var _perfilId = null;
  async function miPerfilId() {
    if (_perfilId) return _perfilId;
    var sb = db(); if (!sb) return null;
    try {
      var r = await sb.rpc('mi_perfil_id');
      if (!r.error && r.data) { _perfilId = r.data; return _perfilId; }
    } catch (e) { /* seguimos por el otro camino */ }
    try {
      var s = await sb.auth.getUser();
      var email = s && s.data && s.data.user ? s.data.user.email : null;
      if (!email) return null;
      var p = await sb.from('perfiles').select('id').eq('email', email).maybeSingle();
      if (!p.error && p.data) _perfilId = p.data.id;
    } catch (e) { /* nada */ }
    return _perfilId;
  }

  /* Por quién puedo contestar: mi propia ficha (si soy mayor) y la de
     mis hijos. Cada uno viene con quién tiene que contestar. */
  var _mios = null;
  async function misAtletas() {
    if (_mios) return _mios;
    var sb = db(); if (!sb) return [];
    var yo = await miPerfilId();
    if (!yo) return [];
    try {
      var r = await sb.from('atletas')
        .select('id,nombre,apellidos,nombre_corto,fecha_nacimiento,perfil_id,perfil_padre_id,grupo_id,estado')
        .or('perfil_id.eq.' + yo + ',perfil_padre_id.eq.' + yo);
      if (r.error) { console.warn('[Apolana] mis atletas:', r.error.message); return []; }
      _mios = (r.data || [])
        .filter(function (a) { return (a.estado || 'activo') !== 'baja'; })
        .map(function (a) {
          var menor = esMenor(a);
          var soyFamilia = (a.perfil_padre_id === yo);
          return {
            id: a.id,
            nombre: a.nombre_corto || a.nombre,
            nombreLargo: ((a.nombre || '') + ' ' + (a.apellidos || '')).trim(),
            menor: menor,
            quienResponde: menor ? (a.perfil_padre_id ? 'familia' : 'club') : 'atleta',
            puedoResponder: soyFamilia || (!menor && a.perfil_id === yo)
          };
        });
      return _mios;
    } catch (e) { console.warn('[Apolana] mis atletas:', e); return []; }
  }

  /* Lo ya contestado (las que la sesión tiene permiso de ver). */
  async function misRespuestas(id, atletaIds) {
    var sb = db(); var mapa = {};
    if (!sb || !id) return mapa;
    try {
      var q = sb.from('confirmaciones_respuestas')
        .select('atleta_id,respuesta,nota,en_espera,respondido_en')
        .eq('confirmacion_id', id);
      if (atletaIds && atletaIds.length) q = q.in('atleta_id', atletaIds);
      var r = await q;
      if (r.error) { console.warn('[Apolana] respuestas:', r.error.message); return mapa; }
      (r.data || []).forEach(function (x) { mapa[x.atleta_id] = x; });
      return mapa;
    } catch (e) { console.warn('[Apolana] respuestas:', e); return mapa; }
  }

  /* ---------- panel ---------- */
  async function guardarPeticion(datos) {
    var sb = db(); if (!sb) return { error: 'Sin conexión' };
    var fila = {
      evento_id: datos.evento_id || null,
      competicion_id: datos.competicion_id || null,
      pregunta: datos.pregunta || null,
      nota_club: datos.nota_club || null,
      fecha_limite: datos.fecha_limite || null,
      plazas: (datos.plazas === '' || datos.plazas == null) ? null : parseInt(datos.plazas, 10),
      publico: datos.publico || 'club',
      grupos: (datos.publico === 'grupos') ? (datos.grupos || []) : null,
      permite_nota: datos.permite_nota !== false,
      abierta: datos.abierta !== false
    };
    try {
      var r;
      if (datos.id) {
        delete fila.evento_id; delete fila.competicion_id;   /* la actividad no se cambia */
        r = await sb.from('confirmaciones').update(fila).eq('id', datos.id).select(CAMPOS).single();
      } else {
        r = await sb.from('confirmaciones').insert(fila).select(CAMPOS).single();
      }
      if (r.error) return { error: r.error.message };
      return { error: null, peticion: r.data };
    } catch (e) { return { error: String(e) }; }
  }

  async function borrarPeticion(id) {
    var sb = db(); if (!sb) return { error: 'Sin conexión' };
    try {
      var r = await sb.from('confirmaciones').delete().eq('id', id);
      return { error: r.error ? r.error.message : null };
    } catch (e) { return { error: String(e) }; }
  }

  /* Texto separado por punto y coma, que es lo que abre bien el Excel
     en español. Con la coma decimal no hace falta nada raro aquí. */
  function csv(filas) {
    var cab = ['Atleta', 'Grupo', 'Categoría', 'Respuesta', 'Plaza', 'Nota', 'Contestó', 'Cuándo'];
    var texto = [cab.join(';')];
    (filas || []).forEach(function (f) {
      texto.push([
        ((f.nombre || '') + ' ' + (f.apellidos || '')).trim(),
        f.grupo || '',
        f.categoria || '',
        etiqueta(f.respuesta),
        f.respuesta === 'voy' ? (f.en_espera ? 'lista de espera' : 'con plaza') : '',
        (f.nota || '').replace(/[;\r\n]+/g, ' '),
        f.respondido_por || '',
        f.respondido_en ? new Date(f.respondido_en).toLocaleString('es-ES') : ''
      ].join(';'));
    });
    return texto.join('\n');
  }

  function etiqueta(r) {
    if (r === 'voy') return 'Voy';
    if (r === 'no_voy') return 'No voy';
    if (r === 'no_lo_se') return 'Aún no lo sé';
    return 'Sin contestar';
  }

  /* «12 van · 3 no van · 5 sin contestar» */
  function frase(r) {
    if (!r) return '';
    var p = [];
    p.push(r.voy + ' ' + (r.voy === 1 ? 'va' : 'van'));
    if (r.en_espera) p.push(plural(r.en_espera, 'en lista de espera', 'en lista de espera'));
    p.push(r.no_voy + ' no ' + (r.no_voy === 1 ? 'va' : 'van'));
    if (r.no_lo_se) p.push(r.no_lo_se + ' sin decidir');
    p.push(plural(r.faltan, 'sin contestar', 'sin contestar'));
    return p.join(' · ');
  }

  /* «Quedan 3 plazas de 20» / «Completo, con lista de espera» */
  function fraseplazas(r) {
    if (!r || r.plazas == null) return '';
    if (r.libres > 0) return (r.libres === 1 ? 'Queda ' : 'Quedan ') + plural(r.libres, 'plaza', 'plazas') + ' de ' + r.plazas;
    return 'Sin plazas libres (' + r.plazas + '). Quien diga que va entra en lista de espera';
  }

  /* ============================================================
     EL BLOQUE · lo que se engancha en una pantalla
     ============================================================ */
  var CSS = [
    '.cf{border:1px solid var(--linea-marcada,#E4DCCB);border-radius:14px;background:#fff;',
      'padding:16px 18px;margin:14px 0;font-family:var(--fuente-texto,system-ui);color:var(--texto,#4A4437)}',
    '.cf.cf--crema{background:var(--crema,#FBF9F4)}',
    '.cf-eti{font-size:13px;line-height:1.4;color:var(--texto-suave,#6E6656);margin:0 0 2px}',
    '.cf-preg{font-size:17px;line-height:1.35;color:var(--navy,#2E4256);margin:0 0 6px;font-weight:600}',
    '.cf-recado{font-size:15px;line-height:1.5;margin:0 0 8px}',
    '.cf-meta{font-size:14px;line-height:1.45;color:var(--texto-suave,#6E6656);margin:0 0 12px}',
    '.cf-meta b{color:var(--navy,#2E4256);font-weight:600}',
    '.cf-persona{border-top:1px solid var(--linea,#EAE3D5);padding-top:12px;margin-top:12px}',
    '.cf-persona:first-of-type{border-top:0;padding-top:0;margin-top:0}',
    '.cf-quien{font-size:15px;font-weight:600;color:var(--navy,#2E4256);margin:0 0 8px}',
    '.cf-ops{display:flex;flex-wrap:wrap;gap:8px}',
    '.cf-op{flex:1 1 auto;min-width:88px;min-height:44px;padding:11px 14px;border-radius:999px;cursor:pointer;',
      'border:1px solid var(--linea-borde,#D4CBB9);background:#fff;color:var(--navy,#2E4256);',
      'font-family:inherit;font-size:15px;line-height:1.2;display:inline-flex;align-items:center;justify-content:center}',
    '.cf-op:hover{border-color:#B9AE99}',
    '.cf-op[aria-pressed="true"]{background:var(--navy,#2E4256);border-color:var(--navy,#2E4256);color:#fff}',
    '.cf-op[disabled]{opacity:.55;cursor:default}',
    '.cf-estado{font-size:14px;line-height:1.45;margin:9px 0 0;color:var(--texto-suave,#6E6656)}',
    '.cf-estado.cf-espera{color:var(--ambar,#B96F09)}',
    '.cf-nota{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-top:10px}',
    '.cf-nota label{flex:1 1 100%;font-size:13px;line-height:1.4;color:var(--texto-suave,#6E6656)}',
    '.cf-nota input{flex:1 1 200px;min-width:0;min-height:44px;box-sizing:border-box;padding:11px 14px;',
      'border:1px solid var(--linea-borde,#D4CBB9);border-radius:10px;background:#fff;',
      'font-family:inherit;font-size:15px;color:var(--navy,#2E4256)}',
    '.cf-nota button{flex:0 0 auto;min-height:44px;padding:11px 14px;border:0;background:none;cursor:pointer;',
      'font-family:inherit;font-size:15px;color:var(--azul-oscuro,#2F6FA8);border-radius:999px}',
    '.cf-nota button:hover{background:var(--azul-suave,#EAF2F9)}',
    '.cf-cerrado{font-size:14px;line-height:1.45;color:var(--texto-suave,#6E6656);margin:8px 0 0}',
    '.cf-error{background:var(--ambar-fondo,#FDF3E3);border:1px solid var(--ambar-borde,#EBD9B8);',
      'border-radius:14px;padding:14px 16px;display:flex;flex-wrap:wrap;gap:10px 14px;align-items:center}',
    '.cf-error p{flex:1 1 220px;margin:0;font-size:15px;line-height:1.45}',
    '.cf-error b{display:block;color:var(--ambar,#B96F09);font-weight:600}',
    '.cf-error button{min-height:44px;padding:10px 20px;border-radius:999px;cursor:pointer;',
      'border:1px solid #C9C0AE;background:#fff;color:var(--navy,#2E4256);font-family:inherit;font-size:15px}',
    '@keyframes cf-brillo{0%{background-position:200% 0}100%{background-position:-200% 0}}',
    '.cf-esq{display:block;height:12px;border-radius:999px;margin:10px 0;',
      'background:linear-gradient(90deg,#EFE9DC 25%,#F7F3EA 50%,#EFE9DC 75%);background-size:200% 100%;',
      'animation:cf-brillo 1.25s linear infinite}',
    '.cf-esq--l{width:82%}.cf-esq--m{width:60%}.cf-esq--c{width:38%}',
    '@media (prefers-reduced-motion:reduce){.cf-esq{animation:none}}',
    '@media (max-width:380px){.cf{padding:14px 16px}}'
  ].join('');

  function ponerCss() {
    if (document.getElementById('cf-estilos')) return;
    var s = document.createElement('style');
    s.id = 'cf-estilos';
    s.textContent = CSS;
    document.head.appendChild(s);
  }

  function esqueleto() {
    return '<div class="cf" aria-live="polite" aria-label="Cargando la confirmación">' +
      '<span class="cf-esq cf-esq--m"></span><span class="cf-esq cf-esq--l"></span>' +
      '<span class="cf-esq cf-esq--c"></span></div>';
  }
  function errorHtml(mensaje) {
    return '<div class="cf cf-error" role="alert"><p><b>No hemos podido cargar el «¿vas?»</b>' +
      esc(mensaje || 'Puede ser tu conexión.') + '</p>' +
      '<button type="button" data-cf-reintentar>Volver a intentarlo</button></div>';
  }

  /* bloque(destino, opciones)
       destino  · elemento o id donde se pinta
       opciones · { evento_id | competicion_id | peticion,
                    atletas: [...],        (por omisión, los míos)
                    titulo: 'confirmación',
                    alCambiar: function (resultado) {} }
     Devuelve { peticion, recargar() } o null si esa actividad no pide
     confirmación (entonces no pinta nada y la pantalla sigue igual). */
  async function bloque(destino, opciones) {
    opciones = opciones || {};
    var caja = (typeof destino === 'string') ? document.getElementById(destino) : destino;
    if (!caja) return null;
    ponerCss();
    caja.innerHTML = esqueleto();

    var pet = opciones.peticion || await peticion(opciones);
    if (!pet) { caja.innerHTML = ''; return null; }

    var atletas = opciones.atletas || await misAtletas();
    var estado = { pet: pet, atletas: atletas, res: null, respuestas: {} };

    async function refrescar() {
      var r1 = resumen(pet.id);
      var r2 = misRespuestas(pet.id, atletas.map(function (a) { return a.id; }));
      estado.res = await r1;
      estado.respuestas = await r2;
      /* Sin recuentos no se puede decir ni si quedan plazas: mejor el
         aviso en ámbar con su botón que un bloque a medias. */
      if (!estado.res) { caja.innerHTML = errorHtml('Puede ser tu conexión.'); return; }
      pinta();
    }

    function pinta() {
      caja.innerHTML = html(estado, opciones);
    }

    caja.addEventListener('click', async function (ev) {
      var b = ev.target.closest ? ev.target.closest('[data-cf-r]') : null;
      if (b) {
        var atleta = b.getAttribute('data-cf-atleta');
        var r = b.getAttribute('data-cf-r');
        var botones = caja.querySelectorAll('[data-cf-atleta="' + atleta + '"]');
        for (var i = 0; i < botones.length; i++) botones[i].disabled = true;
        var res = await responder(pet.id, atleta, r, null);
        if (res.error) {
          aviso(res.error, 'error');
          for (var j = 0; j < botones.length; j++) botones[j].disabled = false;
          return;
        }
        var enEspera = res.datos && res.datos.en_espera;
        aviso(r === 'voy'
          ? (enEspera ? 'Apuntado en la lista de espera' : 'Hecho, cuentan contigo')
          : (r === 'no_voy' ? 'Avisado: no vas' : 'Guardado: aún no lo sabes'), 'ok');
        if (typeof opciones.alCambiar === 'function') opciones.alCambiar(res.datos);
        await refrescar();
        return;
      }
      var g = ev.target.closest ? ev.target.closest('[data-cf-nota]') : null;
      if (g) { guardarNota(g.getAttribute('data-cf-nota')); return; }
      var re = ev.target.closest ? ev.target.closest('[data-cf-reintentar]') : null;
      if (re) { refrescar(); }
    });

    caja.addEventListener('keydown', function (ev) {
      if (ev.key !== 'Enter') return;
      var i = ev.target.getAttribute && ev.target.getAttribute('data-cf-nota-de');
      if (i) { ev.preventDefault(); guardarNota(i); }
    });

    async function guardarNota(atletaId) {
      var campo = caja.querySelector('[data-cf-nota-de="' + atletaId + '"]');
      if (!campo) return;
      var actual = estado.respuestas[atletaId];
      if (!actual) { aviso('Primero dinos si vas.', 'error'); return; }
      var res = await responder(pet.id, atletaId, actual.respuesta, campo.value);
      if (res.error) { aviso(res.error, 'error'); return; }
      aviso('Nota guardada', 'ok');
      await refrescar();
    }

    await refrescar();
    return {
      peticion: pet,
      recargar: refrescar,
      get resumen() { return estado.res; }
    };
  }

  /* El HTML del bloque, por si una pantalla lo quiere pintar a mano. */
  function html(estado, opciones) {
    opciones = opciones || {};
    var pet = estado.pet, res = estado.res || {};
    var abierto = res.en_plazo !== false;
    var h = '<div class="cf' + (opciones.sobreBlanco ? ' cf--crema' : '') + '">';

    h += '<p class="cf-eti">' + esc(opciones.titulo || 'confirmación') + '</p>';
    h += '<p class="cf-preg">' + esc(pet.pregunta || '¿Vas?') + '</p>';
    if (pet.nota_club) h += '<p class="cf-recado">' + esc(pet.nota_club) + '</p>';

    var meta = [];
    if (pet.fecha_limite) {
      meta.push(pasado(pet.fecha_limite)
        ? 'El plazo terminó el ' + fechaFrase(pet.fecha_limite)
        : 'Contesta antes del <b>' + esc(fechaFrase(pet.fecha_limite)) + '</b>');
    }
    if (res.plazas != null) meta.push(esc(fraseplazas(res)));
    if (meta.length) h += '<p class="cf-meta">' + meta.join(' · ') + '</p>';

    if (!estado.atletas.length) {
      h += '<p class="cf-cerrado">Tu cuenta todavía no está enlazada a ninguna ficha de atleta, ' +
           'así que no puedes contestar desde aquí. Avísanos y la enlazamos.</p></div>';
      return h;
    }

    estado.atletas.forEach(function (a) {
      var mia = estado.respuestas[a.id];
      h += '<div class="cf-persona">';
      if (estado.atletas.length > 1) h += '<p class="cf-quien">' + esc(a.nombre) + '</p>';

      var puedo = (a.puedoResponder !== false) && abierto;
      h += '<div class="cf-ops" role="group" aria-label="' + esc('¿Va ' + a.nombre + '?') + '">';
      RESPUESTAS.forEach(function (op) {
        var puesta = mia && mia.respuesta === op.id;
        h += '<button type="button" class="cf-op" data-cf-r="' + op.id + '" data-cf-atleta="' + esc(a.id) + '"' +
             ' aria-pressed="' + (puesta ? 'true' : 'false') + '"' + (puedo ? '' : ' disabled') + '>' +
             esc(op.txt) + '</button>';
      });
      h += '</div>';

      if (mia && mia.respuesta === 'voy' && mia.en_espera) {
        h += '<p class="cf-estado cf-espera">Estás en la lista de espera. Si se cae alguien, entras tú ' +
             'y te lo decimos.</p>';
      } else if (mia && mia.respuesta === 'voy' && res.plazas != null) {
        h += '<p class="cf-estado">Tienes plaza.</p>';
      }

      if (a.quienResponde === 'familia' && a.puedoResponder === false) {
        h += '<p class="cf-estado">Esto lo contesta tu familia.</p>';
      } else if (a.quienResponde === 'club' && a.puedoResponder === false) {
        h += '<p class="cf-estado">Al ser menor, contesta su familia. Todavía no hay ninguna cuenta ' +
             'de familia enlazada: avisa al club.</p>';
      } else if (!abierto) {
        h += '<p class="cf-estado">El plazo ya está cerrado. Si te ha surgido algo, avisa a tu entrenador.</p>';
      }

      if (pet.permite_nota !== false && mia && puedo) {
        h += '<div class="cf-nota">' +
             '<label for="cf-n-' + esc(a.id) + '">Nota corta para el club (opcional)</label>' +
             '<input id="cf-n-' + esc(a.id) + '" type="text" maxlength="140" data-cf-nota-de="' + esc(a.id) + '"' +
             ' value="' + esc(mia.nota || '') + '" placeholder="Voy con mi coche, llevo 3 sitios">' +
             '<button type="button" data-cf-nota="' + esc(a.id) + '">Guardar</button></div>';
      }
      h += '</div>';
    });

    h += '</div>';
    return h;
  }

  /* ============================================================ */
  window.APOLANA_CONF = {
    RESPUESTAS: RESPUESTAS,
    peticion: peticion,
    peticiones: peticiones,
    resumen: resumen,
    lista: lista,
    responder: responder,
    misAtletas: misAtletas,
    misRespuestas: misRespuestas,
    miPerfilId: miPerfilId,
    guardarPeticion: guardarPeticion,
    borrarPeticion: borrarPeticion,
    bloque: bloque,
    html: html,
    css: ponerCss,
    csv: csv,
    frase: frase,
    fraseplazas: fraseplazas,
    etiqueta: etiqueta,
    fechaFrase: fechaFrase,
    esMenor: esMenor
  };
})();
