/* ============================================================
   TRAINING CAMPS · i18n mínimo (EN por defecto, ES segundo)
   ------------------------------------------------------------
   Lo usan TODAS las páginas de /training-camps/ (landing, proposal,
   pay, terms). El inglés va escrito en el HTML, así la página se lee
   bien aunque no haya JS. Cada página registra su diccionario español:

     <h2 data-i18n="fac.title">Where you'll train</h2>
     <p data-i18n-html="fac.note">Indicative <b>times</b>…</p>   (innerHTML)
     <input data-i18n-attr="placeholder:f.pais.ph; aria-label:f.pais">
     <span data-tc-en="Hello" data-tc-es="Hola"></span>        (texto suelto)
     <a href="terms/" data-tc-href>…</a>          (se le añade ?lang=xx)
     <button data-tc-set="es">ES</button>          (cambia el idioma)

     TC.add({ es: { 'fac.title': 'Dónde entrenaréis' } });
     TC.t('err.required', 'This field is required.');
     TC.t('ok.text', 'Sent to {email}', { email: 'a@b.c' });
     TC.onChange(function (lang) { … });

   Idioma: ?lang=es|en → localStorage «tc-lang» → navegador (es*) → en.
   Se carga SIN defer en el <head> (es diminuto) para fijar <html lang>
   antes de pintar; TC.add() traduce al momento lo que ya existe.
   ============================================================ */
(function () {
  'use strict';
  var IDIOMAS = ['en', 'es'];
  var CLAVE = 'tc-lang';
  var dic = { en: {}, es: {} };
  var oyentes = [];

  function norm(l) {
    l = String(l || '').toLowerCase().slice(0, 2);
    return IDIOMAS.indexOf(l) > -1 ? l : '';
  }
  function deUrl() {
    try { return norm(new URLSearchParams(location.search).get('lang')); } catch (e) { return ''; }
  }
  function deAlmacen() {
    try { return norm(window.localStorage.getItem(CLAVE)); } catch (e) { return ''; }
  }
  function guardar(l) {
    try { window.localStorage.setItem(CLAVE, l); } catch (e) { /* modo privado: da igual */ }
  }
  function deNavegador() {
    try {
      var n = (navigator.languages && navigator.languages[0]) || navigator.language || '';
      return String(n).toLowerCase().indexOf('es') === 0 ? 'es' : 'en';
    } catch (e) { return 'en'; }
  }

  var actual = (function () {
    var u = deUrl();
    if (u) { guardar(u); return u; }
    return deAlmacen() || deNavegador();
  })();

  var html = document.documentElement;
  html.lang = actual;
  html.classList.add('tc-js');

  function cada(raiz, sel, fn) {
    if (!raiz) return;
    if (raiz.nodeType === 1 && raiz.matches && raiz.matches(sel)) fn(raiz);
    if (raiz.querySelectorAll) {
      var l = raiz.querySelectorAll(sel);
      for (var i = 0; i < l.length; i++) fn(l[i]);
    }
  }
  function valor(k) {
    var v = actual === 'es' ? dic.es[k] : dic.en[k];
    return v == null ? null : v;
  }
  function conLang(href) {
    try {
      var u = new URL(href, location.href);
      u.searchParams.set('lang', actual);
      return u.origin === location.origin ? u.pathname + u.search + u.hash : u.href;
    } catch (e) { return href; }
  }

  /* Traduce un trozo del DOM (o todo). El inglés original se guarda la
     primera vez, para poder volver a él al cambiar de idioma. */
  function aplicar(raiz) {
    raiz = raiz || document;
    cada(raiz, '[data-i18n]', function (el) {
      if (el._tcEn === undefined) el._tcEn = el.textContent;
      var v = valor(el.getAttribute('data-i18n'));
      el.textContent = v != null ? v : el._tcEn;
    });
    cada(raiz, '[data-i18n-html]', function (el) {
      if (el._tcEn === undefined) el._tcEn = el.innerHTML;
      var v = valor(el.getAttribute('data-i18n-html'));
      el.innerHTML = v != null ? v : el._tcEn;
    });
    cada(raiz, '[data-i18n-attr]', function (el) {
      if (!el._tcEnAttr) el._tcEnAttr = {};
      el.getAttribute('data-i18n-attr').split(/\s*[;,]\s*/).forEach(function (par) {
        var i = par.indexOf(':');
        if (i < 1) return;
        var at = par.slice(0, i).trim(), k = par.slice(i + 1).trim();
        if (!(at in el._tcEnAttr)) el._tcEnAttr[at] = el.getAttribute(at);
        var v = valor(k);
        if (v == null) v = el._tcEnAttr[at];
        if (v == null) el.removeAttribute(at); else el.setAttribute(at, v);
      });
    });
    cada(raiz, '[data-tc-en]', function (el) {
      var v = el.getAttribute(actual === 'es' ? 'data-tc-es' : 'data-tc-en');
      if (v == null) v = el.getAttribute('data-tc-en');
      el.textContent = v;
    });
    cada(raiz, '[data-tc-set]', function (b) {
      var on = b.getAttribute('data-tc-set') === actual;
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
      b.classList.toggle('is-on', on);
    });
    cada(raiz, 'a[data-tc-href]', function (a) {
      if (!a._tcHref) a._tcHref = a.getAttribute('href');
      a.setAttribute('href', conLang(a._tcHref));
    });
  }

  function t(k, fb, vars) {
    var v = valor(k);
    if (v == null) v = dic.en[k] != null ? dic.en[k] : (fb != null ? fb : k);
    if (vars) {
      v = String(v).replace(/\{(\w+)\}/g, function (m, n) { return vars[n] != null ? vars[n] : m; });
    }
    return v;
  }

  function add(d) {
    d = d || {};
    IDIOMAS.forEach(function (l) {
      if (!d[l]) return;
      for (var k in d[l]) if (Object.prototype.hasOwnProperty.call(d[l], k)) dic[l][k] = d[l][k];
    });
    aplicar(document);
  }

  function setLang(l) {
    l = norm(l) || 'en';
    var cambia = l !== actual;
    actual = l;
    guardar(l);
    html.lang = l;
    try {
      var u = new URL(location.href);
      u.searchParams.set('lang', l);
      history.replaceState(history.state, '', u.pathname + u.search + u.hash);
    } catch (e) {}
    aplicar(document);
    if (cambia) oyentes.slice().forEach(function (fn) { try { fn(l); } catch (e) { console.error(e); } });
  }

  function onChange(fn) { if (typeof fn === 'function') oyentes.push(fn); }

  /* Fechas: «2026-11-12» → «12 Nov 2026» / «12 nov 2026», sin líos de zona
     horaria (se construye a mediodía local). */
  function locale() { return actual === 'es' ? 'es-ES' : 'en-GB'; }
  function fecha(iso, opts) {
    var m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(iso || ''));
    if (!m) return String(iso || '');
    var d = new Date(+m[1], +m[2] - 1, +m[3], 12);
    try {
      return d.toLocaleDateString(locale(), opts || { day: 'numeric', month: 'short', year: 'numeric' });
    } catch (e) { return m[3] + '/' + m[2] + '/' + m[1]; }
  }

  /* Botones de idioma: cualquier [data-tc-set] de la página, por delegación. */
  document.addEventListener('click', function (ev) {
    var b = ev.target && ev.target.closest && ev.target.closest('[data-tc-set]');
    if (!b) return;
    ev.preventDefault();
    setLang(b.getAttribute('data-tc-set'));
  });
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { aplicar(document); });
  }

  window.TC = {
    lang: function () { return actual; },
    setLang: setLang,
    t: t,
    add: add,
    onChange: onChange,
    apply: aplicar,
    locale: locale,
    date: fecha
  };
})();
