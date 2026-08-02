/* ANDAMIO LOCAL DE MAQUETACIÓN · NO FORMA PARTE DE LA WEB · se borra al terminar */
(function () {
  var DATOS = window.__DATOS__ || {};
  var MAQ = window.__MAQ__ || {};
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
  function tabla(t) {
    return {
      select: function () { return new Q(t); },
      insert: function () { return Promise.resolve({ data: null, error: null }); },
      upsert: function () { return Promise.resolve({ data: null, error: null }); },
      update: function () { var q = new Q(t); q.then = function (r) { return Promise.resolve({ data: null, error: null }).then(r); };
                            q.eq = function () { return q; }; q.select = function () { return q; }; q.maybeSingle = function () { return q; }; return q; },
      delete: function () { var q = new Q(t); q.then = function (r) { return Promise.resolve({ data: null, error: null }).then(r); }; q.eq = function () { return q; }; return q; }
    };
  }
  var P0 = (DATOS.perfiles && DATOS.perfiles[0]) || {};
  window.APOLANA_DB = {
    from: tabla,
    rpc: function (n, args) {
      if (n === 'juego_es_menor') {
        var f = args && args.p_fnac;
        return Promise.resolve({ data: !f || (new Date(f + 'T00:00:00') > new Date(new Date().setFullYear(new Date().getFullYear() - 18))), error: null });
      }
      return Promise.resolve({ data: null, error: null });
    },
    auth: {
      getSession: function () { return Promise.resolve({ data: { session: { user: { id: P0.id, email: P0.email } } }, error: null }); },
      signOut: function () { return Promise.resolve({ error: null }); },
      resetPasswordForEmail: function () { return Promise.resolve({ error: null }); },
      onAuthStateChange: function () { return { data: { subscription: { unsubscribe: function () {} } } }; }
    },
    storage: { from: function () { return {
      upload: function () { return Promise.resolve({ error: null }); },
      remove: function () { return Promise.resolve({ error: null }); },
      createSignedUrl: function () { return Promise.resolve({ data: null, error: { message: 'andamio' } }); }
    }; } }
  };
})();
