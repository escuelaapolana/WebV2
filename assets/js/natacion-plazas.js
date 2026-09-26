/* Cuadro de PLAZAS de natación por franja y nivel.
   Lee la vista pública `natacion_vacantes` (agregada, sin nombres) y pinta un
   semáforo por franja: 🟢 admite / 🟠 consultar / 🔴 completo. No hace nada si
   la página no tiene el contenedor #cs-plazas-nat. */
(function () {
  var DIAS = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  var SEM = {
    verde: { t: 'Admite plazas', c: 'verde' },
    ambar: { t: 'Consultar', c: 'ambar' },
    rojo:  { t: 'Completo', c: 'rojo' }
  };
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"]/g, function (m) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[m];
    });
  }
  function hhmm(h) { return String(h).slice(0, 5); }

  function estilos() {
    if (document.getElementById('nat-plazas-css')) return;
    var css = document.createElement('style');
    css.id = 'nat-plazas-css';
    css.textContent =
      '.nat-plazas{margin-top:8px}' +
      '.nat-leyenda{display:flex;flex-wrap:wrap;gap:10px;margin-bottom:18px}' +
      '.nat-pill{display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600;padding:3px 10px;border-radius:999px;white-space:nowrap}' +
      '.nat-pill::before{content:"";width:9px;height:9px;border-radius:50%;background:currentColor;display:inline-block}' +
      '.nat-pill.verde{color:#2E7D32;background:#E7F4E8}' +
      '.nat-pill.ambar{color:#B26A00;background:#FBEFD6}' +
      '.nat-pill.rojo{color:#B3261E;background:#FBE3E1}' +
      '.nat-dia{margin-bottom:16px}' +
      '.nat-dia h3{font-size:15px;text-transform:uppercase;letter-spacing:.4px;color:var(--navy,#26374B);margin:0 0 8px}' +
      '.nat-dia ul{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:8px}' +
      '.nat-dia li{display:flex;align-items:center;flex-wrap:wrap;gap:10px 14px;background:#fff;border:1px solid var(--linea-marcada,#E4DCCB);border-radius:12px;padding:11px 14px}' +
      '.nat-hora{font-family:var(--fuente-dato,monospace);font-weight:700;color:var(--azul-oscuro,#2F6FA8);min-width:52px}' +
      '.nat-grupo{font-size:13px;color:var(--texto-suave,#6E6656);min-width:96px}' +
      '.nat-niveles{display:flex;flex-wrap:wrap;gap:6px;margin-left:auto}' +
      '.nat-nivel{font-size:12px;font-weight:600;color:var(--navy,#26374B);background:var(--crema,#F4EEE1);border-radius:999px;padding:2px 9px}' +
      '.nat-nota{margin-top:14px;font-size:13.5px;color:var(--texto-suave,#6E6656)}';
    document.head.appendChild(css);
  }

  function pintar(cont, filas) {
    if (!filas.length) { cont.innerHTML = ''; return; }
    estilos();
    var porDia = {};
    filas.forEach(function (f) { (porDia[f.dia] = porDia[f.dia] || []).push(f); });
    var out = ['<div class="nat-plazas">',
      '<div class="nat-leyenda">' +
        '<span class="nat-pill verde">Admite plazas</span>' +
        '<span class="nat-pill ambar">Consultar</span>' +
        '<span class="nat-pill rojo">Completo</span></div>'];
    Object.keys(porDia).map(Number).sort(function (a, b) { return a - b; }).forEach(function (d) {
      out.push('<div class="nat-dia"><h3>' + esc(DIAS[d] || '') + '</h3><ul>');
      porDia[d].forEach(function (f) {
        var s = SEM[f.semaforo] || { t: f.semaforo || '—', c: '' };
        var niveles = (f.admite_niveles || []).map(function (n) {
          return '<span class="nat-nivel">' + esc(n) + '</span>';
        }).join('');
        out.push('<li>' +
          '<span class="nat-hora">' + esc(hhmm(f.hora)) + '</span>' +
          '<span class="nat-grupo">' + esc(f.grupo) + '</span>' +
          '<span class="nat-pill ' + s.c + '">' + esc(s.t) + '</span>' +
          '<span class="nat-niveles">' + niveles + '</span>' +
          '</li>');
      });
      out.push('</ul></div>');
    });
    out.push('<p class="nat-nota">Escuela = niños y niñas · Máster = adultos. Las plazas se ajustan al nivel de cada franja; para inscribirte, escribe al club.</p>');
    out.push('</div>');
    cont.innerHTML = out.join('');
  }

  /* Filtra las franjas según el data-filtro del contenedor:
       'escuela' → franjas de la escuela (grupo con "Escuela")
       'master'  → franjas de adultos (grupo con "Máster" o "Perfeccionamiento")
       (sin filtro) → todas. Las mixtas (Escuela + Máster) salen en ambas. */
  function filtrar(filas, filtro) {
    if (filtro === 'escuela') return filas.filter(function (f) { return /escuela/i.test(f.grupo || ''); });
    if (filtro === 'master')  return filas.filter(function (f) { var g = f.grupo || ''; return /m[aá]ster|perfeccion/i.test(g) && !/escuela/i.test(g); });
    return filas;
  }

  function init() {
    var cont = document.getElementById('cs-plazas-nat');
    if (!cont) return;
    var filtro = (cont.getAttribute('data-filtro') || '').toLowerCase();
    var db = window.APOLANA_DB;
    if (!db) { return setTimeout(init, 80); }  // esperar a db.js (defer)
    db.from('natacion_vacantes')
      .select('dia,hora,grupo,calles,tiene_vaso,semaforo,admite_niveles,criterio')
      .order('dia', { ascending: true }).order('hora', { ascending: true })
      .then(function (res) {
        if (res.error || !res.data) { cont.innerHTML = ''; return; }
        pintar(cont, filtrar(res.data, filtro));
      })
      .catch(function () { cont.innerHTML = ''; });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
