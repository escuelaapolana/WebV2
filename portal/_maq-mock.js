/* ============================================================
   ANDAMIO LOCAL DE MAQUETACIÓN · NO FORMA PARTE DE LA WEB
   ------------------------------------------------------------
   Sustituye el cliente de Supabase por uno de mentira que sirve
   filas REALES volcadas de la base, para poder mirar las
   pantallas del portal a 375 px sin abrir sesión.
   Este archivo se borra al terminar la revisión.
   ============================================================ */
(function () {
  var DATOS = window.__DATOS__ || {};
  var MAQ = window.__MAQ__ || {};

  /* Hoy es domingo y ese día no hay entreno. Para poder mirar la tarjeta navy
     de Inicio con datos REALES —sin recolocar nada— el andamio se coloca en un
     miércoles de esa misma semana, que sí tiene entreno publicado. */
  if (MAQ.fecha) {
    var _D = Date, off = new _D(MAQ.fecha + 'T10:00:00').getTime() - _D.now();
    var F = function (a, b, c, d, e, f, g) {
      if (!(this instanceof F)) return new _D(_D.now() + off).toString();
      if (arguments.length === 0) return new _D(_D.now() + off);
      if (arguments.length === 1) return new _D(a);
      return new _D(a, b, c === undefined ? 1 : c, d || 0, e || 0, f || 0, g || 0);
    };
    F.now = function () { return _D.now() + off; };
    F.parse = _D.parse; F.UTC = _D.UTC; F.prototype = _D.prototype;
    window.Date = F;
  }
  if (MAQ.rango) {
    var aid = (DATOS.atletas && DATOS.atletas[0] && DATOS.atletas[0].id) || null;
    if (!DATOS.perfil_juego || !DATOS.perfil_juego.length) DATOS.perfil_juego = [{ atleta_id: aid, participa: true, puntos: 168 }];
    DATOS.perfil_juego[0].participa = true;
  }

  function filas(t) { return (DATOS[t] || []).slice(); }

  function Q(t) { this.t = t; this.f = []; this.ord = null; this.lim = null; this.uno = false; }
  Q.prototype.select = function () { return this; };
  Q.prototype.eq = function (c, v) { this.f.push(function (r) { return String(r[c]) === String(v); }); return this; };
  Q.prototype.neq = function (c, v) { this.f.push(function (r) { return String(r[c]) !== String(v); }); return this; };
  Q.prototype.gte = function (c, v) { this.f.push(function (r) { return r[c] != null && String(r[c]) >= String(v); }); return this; };
  Q.prototype.lte = function (c, v) { this.f.push(function (r) { return r[c] != null && String(r[c]) <= String(v); }); return this; };
  Q.prototype.gt = function (c, v) { this.f.push(function (r) { return r[c] != null && String(r[c]) > String(v); }); return this; };
  Q.prototype.lt = function (c, v) { this.f.push(function (r) { return r[c] != null && String(r[c]) < String(v); }); return this; };
  Q.prototype.is = function (c, v) { this.f.push(function (r) { return v === null ? r[c] == null : r[c] === v; }); return this; };
  Q.prototype.in = function (c, a) { this.f.push(function (r) { return (a || []).indexOf(r[c]) > -1; }); return this; };
  Q.prototype.or = function () { return this; };
  Q.prototype.order = function (c, o) { this.ord = { c: c, asc: !o || o.ascending !== false }; return this; };
  Q.prototype.limit = function (n) { this.lim = n; return this; };
  Q.prototype.maybeSingle = function () { this.uno = true; return this; };
  Q.prototype.single = function () { this.uno = true; return this; };
  Q.prototype.resolver = function () {
    var d = filas(this.t);
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
  Q.prototype.catch = function (f) { return Promise.resolve(this.resolver()).catch(f); };

  function tabla(t) {
    return {
      select: function () { return new Q(t); },
      insert: function () { return Promise.resolve({ data: null, error: null }); },
      upsert: function () { return Promise.resolve({ data: null, error: null }); },
      update: function () { var q = new Q(t); q.then = function (r) { return Promise.resolve({ data: null, error: null }).then(r); }; return q; },
      delete: function () { var q = new Q(t); q.then = function (r) { return Promise.resolve({ data: null, error: null }).then(r); }; return q; }
    };
  }

  var email = (DATOS.perfiles && DATOS.perfiles[0] && DATOS.perfiles[0].email) || 'atleta2@apolana.test';
  var id = (DATOS.perfiles && DATOS.perfiles[0] && DATOS.perfiles[0].id) || '00000000-0000-0000-0000-000000000000';

  window.APOLANA_DB = {
    from: tabla,
    rpc: function () { return Promise.resolve({ data: null, error: null }); },
    auth: {
      getSession: function () { return Promise.resolve({ data: { session: { user: { id: id, email: email } } }, error: null }); },
      getUser: function () { return Promise.resolve({ data: { user: { id: id, email: email } }, error: null }); },
      signOut: function () { return Promise.resolve({ error: null }); },
      resetPasswordForEmail: function () { return Promise.resolve({ error: null }); },
      onAuthStateChange: function () { return { data: { subscription: { unsubscribe: function () {} } } }; }
    },
    storage: {
      from: function () {
        return {
          upload: function () { return Promise.resolve({ error: null }); },
          remove: function () { return Promise.resolve({ error: null }); },
          createSignedUrl: function () { return Promise.resolve({ data: null, error: { message: 'andamio' } }); }
        };
      }
    }
  };
})();
