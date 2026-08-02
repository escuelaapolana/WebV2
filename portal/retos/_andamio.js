/* ANDAMIO LOCAL DE REVISIÓN · NO FORMA PARTE DE LA WEB · se borra al terminar.
   Sustituye el cliente de Supabase por uno de mentira alimentado con filas
   REALES volcadas de la base, para poder mirar la pantalla a 375 px sin
   abrir sesión. Los retos propios sí se crean, editan y borran de verdad
   contra una lista en memoria, con el tope de tres y el plazo puesto por
   «la base», igual que hace el disparador de la migración 067. */
(function () {
  var D = window.__DATOS__ || {};
  var ATL = D.atletas[0].id;
  var PLAZOS = {};
  (D.plazos || []).forEach(function (p) { PLAZOS[p.periodo] = p; });

  var PROPIOS = [];
  var seq = 1;
  (D.retos || []).forEach(function (r) { r.activo = true; r.created_at = r.id; });
  (D.medallas || []).forEach(function (m) { m.activa = true; });
  (D.juego_ajustes || []).forEach(function (a) { a.perfil_socios = !!window.__PERFIL_SOCIOS__; });

  function valorDe(metrica, periodo) {
    var h = (D.historial[metrica] || []).filter(function (x) { return x.periodo === periodo; })[0];
    return h ? Number(h.actual || 0) : 0;
  }

  var TABLAS = {
    perfiles: [{ id: 'perfil-prueba', nombre: 'prueba 2', apellidos: 'jeje',
                 email: 'atleta2@apolana.test', rol: 'atleta', seccion: null }],
    grupos: [],
    atletas: D.atletas,
    juego_rangos: D.juego_rangos,
    retos: D.retos,
    reto_logros: D.reto_logros,
    medallas: D.medallas,
    atleta_medallas: D.atleta_medallas,
    perfil_juego: D.perfil_juego,
    juego_ajustes: D.juego_ajustes,
    miembros_juego: D.miembros_juego,
    clasificacion_retos: [],
    medallas_publicas: [],
    logros_publicos: [],
    retos_propios: PROPIOS
  };

  function Q(t) { this.t = t; this.f = []; this.ord = null; this.lim = null; this.uno = false; }
  Q.prototype.select = function () { return this; };
  Q.prototype.eq = function (c, v) { this.f.push(function (r) { return String(r[c]) === String(v); }); return this; };
  Q.prototype.or = function () { return this; };
  Q.prototype.order = function (c, o) { if (!this.ord) this.ord = { c: c, asc: !o || o.ascending !== false }; return this; };
  Q.prototype.limit = function (n) { this.lim = n; return this; };
  Q.prototype.maybeSingle = function () { this.uno = true; return this; };
  Q.prototype.single = function () { this.uno = true; return this; };
  Q.prototype.resolver = function () {
    var d = (TABLAS[this.t] || []).slice();
    this.f.forEach(function (fn) { d = d.filter(fn); });
    if (this.ord) {
      var c = this.ord.c, asc = this.ord.asc;
      d.sort(function (a, b) {
        var x = a[c], y = b[c];
        if (x === y) return 0;
        if (x == null) return 1; if (y == null) return -1;
        return (x < y ? -1 : 1) * (asc ? 1 : -1);
      });
    }
    if (this.lim != null) d = d.slice(0, this.lim);
    return this.uno ? { data: d[0] || null, error: null } : { data: d, error: null };
  };
  Q.prototype.then = function (res, rej) { return Promise.resolve(this.resolver()).then(res, rej); };

  function hoyISO() { return new Date().toISOString().slice(0, 10); }

  function tabla(t) {
    return {
      select: function () { return new Q(t); },
      upsert: function () { return Promise.resolve({ data: null, error: null }); },
      insert: function (fila) {
        if (t !== 'retos_propios') return Promise.resolve({ data: null, error: null });
        var enMarcha = PROPIOS.filter(function (r) {
          return r.hasta >= hoyISO() && valorDe(r.metrica, r.periodo) < Number(r.objetivo);
        });
        if (enMarcha.length >= 3) {
          return Promise.resolve({ data: null, error: { message: 'Ya llevas tres retos en marcha. Quita uno y te pones este.' } });
        }
        var p = PLAZOS[fila.periodo];
        PROPIOS.push({
          id: 'mio-' + (seq++), atleta_id: ATL, metrica: fila.metrica,
          objetivo: Number(fila.objetivo), periodo: fila.periodo,
          desde: p.desde, hasta: p.hasta, creado_en: new Date().toISOString()
        });
        return Promise.resolve({ data: null, error: null });
      },
      update: function (fila) {
        return {
          eq: function (c, v) {
            PROPIOS.forEach(function (r) {
              if (String(r[c]) !== String(v)) return;
              if (fila.metrica) r.metrica = fila.metrica;
              if (fila.objetivo != null) r.objetivo = Number(fila.objetivo);
              if (fila.periodo && fila.periodo !== r.periodo) {
                r.periodo = fila.periodo;
                r.desde = PLAZOS[fila.periodo].desde;
                r.hasta = PLAZOS[fila.periodo].hasta;
              }
            });
            return Promise.resolve({ data: null, error: null });
          }
        };
      },
      delete: function () {
        return {
          eq: function (c, v) {
            for (var i = PROPIOS.length - 1; i >= 0; i--) if (String(PROPIOS[i][c]) === String(v)) PROPIOS.splice(i, 1);
            return Promise.resolve({ data: null, error: null });
          }
        };
      }
    };
  }

  window.APOLANA_DB = {
    from: tabla,
    rpc: function (nombre, args) {
      if (nombre === 'retos_progreso_atleta') return Promise.resolve({ data: D.progreso, error: null });
      if (nombre === 'retos_propios_progreso') {
        return Promise.resolve({
          data: PROPIOS.map(function (r) { return { reto_id: r.id, valor: valorDe(r.metrica, r.periodo) }; }),
          error: null
        });
      }
      if (nombre === 'retos_propios_historial') {
        return Promise.resolve({ data: D.historial[args.p_metrica] || [], error: null });
      }
      return Promise.resolve({ data: null, error: null });
    },
    auth: {
      getSession: function () { return Promise.resolve({ data: { session: { user: { id: 'x', email: 'atleta2@apolana.test' } } }, error: null }); },
      getUser: function () { return Promise.resolve({ data: { user: { id: 'x', email: 'atleta2@apolana.test' } }, error: null }); },
      signOut: function () { return Promise.resolve({ error: null }); },
      onAuthStateChange: function () { return { data: { subscription: { unsubscribe: function () {} } } }; }
    },
    storage: { from: function () { return { createSignedUrls: function () { return Promise.resolve({ data: [], error: null }); } }; } }
  };
})();
