/* Arnés de prueba local: datos reales, sin credenciales. TEMPORAL. */
(function () {
  var D = window.__DATOS__;
  function clon(x) { return JSON.parse(JSON.stringify(x)); }
  function Q(tabla) {
    var filas = clon(D[tabla] || []);
    var b = {
      _f: filas, _single: 0,
      select: function () { return b; },
      order: function (col, o) {
        var asc = !o || o.ascending !== false;
        b._f = b._f.slice().sort(function (x, y) {
          var a = x[col], c = y[col];
          if (a == null && c == null) return 0;
          if (a == null) return 1; if (c == null) return -1;
          return (a > c ? 1 : a < c ? -1 : 0) * (asc ? 1 : -1);
        });
        return b;
      },
      eq: function (c, v) { b._f = b._f.filter(function (r) { return String(r[c]) === String(v); }); return b; },
      in: function (c, vs) { b._f = b._f.filter(function (r) { return vs.indexOf(r[c]) !== -1; }); return b; },
      maybeSingle: function () { b._single = 1; return b; },
      single: function () { b._single = 2; return b; },
      update: function () { b._noop = 1; return b; },
      insert: function () { b._noop = 1; return b; },
      delete: function () { b._noop = 1; return b; },
      upsert: function () { b._noop = 1; return b; },
      then: function (res) {
        var out;
        if (b._noop) out = { data: null, error: null };
        else if (b._single) out = { data: b._f[0] || null, error: b._f.length || b._single === 1 ? (b._f[0] || null) : null };
        else out = { data: b._f, error: null };
        if (b._single) out = { data: b._f[0] || null, error: null };
        setTimeout(function () { res(out); }, 5);
        return { catch: function () {} };
      }
    };
    return b;
  }
  var sb = { from: Q };
  window.APOLANA_ADMIN = { listo: function (cb) { window.__CB__ = cb; } };
  document.addEventListener('DOMContentLoaded', function () {
    var top = document.createElement('div');
    top.className = 'adm-top';
    top.innerHTML = '<div class="izq"><a class="volver" href="../"><i>&larr;</i><span class="txt">Panel</span></a>' +
      '<span class="sep">·</span><span class="marca">' + (document.title.split('·')[0].trim()) + '</span></div>' +
      '<div class="der"><span>prueba@local</span><button>Salir</button></div>';
    var css = document.createElement('style');
    css.textContent = '.adm-top{background:#2E4256;color:#fff;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:9px clamp(14px,4vw,40px);min-height:60px;width:100%;box-sizing:border-box}' +
      '.adm-top .izq{display:flex;align-items:center;gap:10px;min-width:0;overflow:hidden}' +
      '.adm-top a.volver{color:#cdd6e0;text-decoration:none;font-size:15px;display:inline-flex;align-items:center;gap:7px;padding:10px 12px;border-radius:10px;min-height:44px;box-sizing:border-box}' +
      '.adm-top .marca{font-family:"Barlow Condensed",sans-serif;font-weight:700;text-transform:uppercase;font-size:20px;color:#fff}' +
      '.adm-top .der{display:flex;align-items:center;gap:12px;font-size:14px;color:#cdd6e0}' +
      '.adm-top button{background:transparent;border:1px solid rgba(255,255,255,.4);color:#fff;border-radius:999px;padding:10px 18px;min-height:44px;font-size:14px;font-family:inherit}' +
      'html,body{max-width:100%;overflow-x:hidden}';
    document.head.appendChild(css);
    document.body.insertBefore(top, document.body.firstChild);
    setTimeout(function () { if (window.__CB__) window.__CB__(sb); }, 30);
  });
})();
