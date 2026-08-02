/* ============================================================
   CABECERA Y PIE COMPARTIDOS · Club Atletismo Apolana
   Se escriben AQUÍ una sola vez. Cada página los coloca con:
     <apolana-cabecera activo="club"></apolana-cabecera>
     <apolana-pie></apolana-pie>
   Si hay que cambiar un enlace del menú o un teléfono, se cambia
   solo en este archivo y afecta a toda la web.
   ============================================================ */

/* Base relativa de la web. Cada página define window.APOLANA_BASE
   ("./", "../", "../../"…) según su profundidad, para que los enlaces
   funcionen igual en local (doble clic), en GitHub y en el dominio propio. */
function base() { return window.APOLANA_BASE || './'; }
function ruta(u) { return base() + String(u).replace(/^\//, ''); }

/* Enlaces del menú principal. La "clave" sirve para marcar en azul
   la página en la que estás (con el atributo activo="..."). */
const MENU = [
  { clave: 'club', texto: 'El club', url: '/club/', sub: [
    { texto: 'Resumen',               url: '/club/' },
    { texto: 'Historia',              url: '/club/historia/' },
    { texto: 'Galería',              url: '/galeria/' },
    { texto: 'Normativa y documentos', url: '/club/normativa/' },
    { texto: 'Palmarés',              url: '/club/palmares/' },
    { texto: 'Récords',               url: '/club/records/' },
  ] },
  { clave: 'entrena', texto: 'Entrena con nosotros', url: '/competicion/', sub: [
    { texto: 'Atletismo en pista', url: '/competicion/' },
    { texto: 'Running',            url: '/running/' },
    { texto: 'Natación adultos',   url: '/natacion/' },
    { texto: 'Triatlón',           url: '/triatlon/' },
    { texto: 'Montaña',            url: '/montana/' },
    { texto: 'El Cubo',            url: '/cubo/' },
    { texto: 'Instalaciones',      url: '/instalaciones/' },
  ] },
  { clave: 'escuelas', texto: 'Escuelas', url: '/escuelas/', sub: [
    { texto: 'Todas las escuelas', url: '/escuelas/' },
    { texto: 'Escuela de atletismo', url: '/escuela/' },
    { texto: 'Escuela de natación',  url: '/escuela-natacion/' },
    { texto: 'Escuela municipal',    url: '/escuela-municipal-atletismo/' },
    { texto: 'Campus de verano',     url: '/campus/' },
  ] },
  { clave: 'familias',   texto: 'Familias',   url: '/familias/' },
  { clave: 'horarios',   texto: 'Horarios',   url: '/horarios/' },
  { clave: 'calendario', texto: 'Calendario', url: '/calendario/' },
  { clave: 'noticias',   texto: 'Noticias',   url: '/noticias/' },
  { clave: 'tienda',     texto: 'Tienda',     url: '/tienda/' },
  { clave: 'contacto',   texto: 'Contacto',   url: '/contacto/' },
];

/* --- Cabecera --- */
class ApolanaCabecera extends HTMLElement {
  connectedCallback() {
    const activo = this.getAttribute('activo') || '';
    const enlaces = MENU.map(m => {
      const act = m.clave === activo ? ' class="activo" aria-current="page"' : '';
      if (m.sub) {
        const items = m.sub.map(s => `<a href="${ruta(s.url)}">${s.texto}</a>`).join('');
        return `<div class="tiene-sub"><a class="top"${act} href="${ruta(m.url)}">${m.texto}<span class="caret" aria-hidden="true"></span></a><div class="submenu">${items}</div></div>`;
      }
      return `<a href="${ruta(m.url)}"${act}>${m.texto}</a>`;
    }).join('');
    const enlacesMovil = MENU.map(m => {
      let h = `<a href="${ruta(m.url)}">${m.texto}</a>`;
      if (m.sub) h += `<div class="sub">${m.sub.map(s => `<a href="${ruta(s.url)}">${s.texto}</a>`).join('')}</div>`;
      return h;
    }).join('') + `<a href="${ruta('/portal/')}">Entrar</a>`;

    this.innerHTML = `
      <header class="cabecera">
        <div class="contenedor">
          <a class="marca" href="${base()}">
            <img src="${ruta('/assets/img/logo.png')}" alt="Club Atletismo Apolana">
            <span class="marca-txt">
              <span class="nombre">Apolana</span>
              <span class="sub">ALICANTE · 1988</span>
            </span>
          </a>
          <nav class="menu">${enlaces}</nav>
          <div class="cabecera-acciones">
            <a class="btn btn--neutro" href="${ruta('/portal/')}">Entrar</a>
            <a class="btn btn--primario btn--sm" href="${ruta('/inscripcion/')}">Inscribirse</a>
            <details class="menu-movil">
              <summary aria-label="Abrir menú">☰</summary>
              <div class="menu-movil-panel">${enlacesMovil}</div>
            </details>
          </div>
        </div>
      </header>`;
  }
}

/* --- Pie de página (los datos salen de datos.js) --- */
class ApolanaPie extends HTMLElement {
  connectedCallback() {
    const d = window.APOLANA || {};
    const c = d.contacto || {};
    const lema = (d.club && d.club.lema) || '';
    const colab = (d.colaboradores || []).map(x => `<span>${x}</span>`).join('');
    const tel = t => t ? `<a href="tel:${t.tel}">${t.texto} · ${t.nota}</a>` : '';
    const anio = new Date().getFullYear();
    this.innerHTML = `
      <footer class="pie">
        <div class="contenedor">
          <div class="pie-marca">
            <div class="fila">
              <img src="${ruta('/assets/img/logo.png')}" alt="Club Apolana">
              <span class="nombre">Club Apolana</span>
            </div>
            <span class="lema">${lema}</span>
          </div>
          <div class="pie-cols">
            <div class="pie-col">
              <span class="eyebrow">Club</span>
              <a href="${base()}">Inicio</a>
              <a href="${ruta('/socio/')}">Hazte socio</a>
              <a href="${ruta('/calendario/')}">Calendario</a>
              <a href="${ruta('/noticias/')}">Noticias</a>
              <a href="${ruta('/tienda/')}">Tienda</a>
              <a href="${ruta('/app/')}">Instalar la app</a>
            </div>
            <div class="pie-col">
              <span class="eyebrow">Contacto</span>
              ${tel(c.tel_socios)}
              ${tel(c.tel_escuela)}
              ${c.email ? `<a href="mailto:${c.email}">${c.email}</a>` : ''}
            </div>
            <div class="pie-col">
              <span class="eyebrow">Colaboran</span>
              ${colab}
            </div>
          </div>
        </div>
        <div class="pie-credito">© ${anio} Club Atletismo Apolana · Creada por <strong>Andrés Clavero Giménez</strong></div>
      </footer>`;
  }
}

customElements.define('apolana-cabecera', ApolanaCabecera);
customElements.define('apolana-pie', ApolanaPie);

/* --- Aviso de portada (barra superior si hay un aviso activo en la BD) --- */
document.addEventListener('DOMContentLoaded', async function () {
  if (!window.APOLANA_DB) return;
  try {
    var res = await window.APOLANA_DB
      .from('avisos')
      .select('texto, tipo, enlace, texto_enlace')
      .eq('activo', true)
      .order('created_at', { ascending: false })
      .limit(1);
    if (res.error || !res.data || !res.data.length) return;
    var a = res.data[0];
    if (!a.texto) return;

    /* Tres niveles, como en la maqueta. Se admiten también los nombres
       antiguos ("info", "aviso") para que un aviso viejo no salga sin color. */
    var NIVELES = {
      informativo: 'informativo', info: 'informativo',
      importante: 'importante', aviso: 'importante',
      urgente: 'urgente'
    };
    var nivel = NIVELES[String(a.tipo || '').toLowerCase()] || 'informativo';

    var bar = document.createElement('div');
    bar.className = 'aviso-portada aviso-portada--' + nivel;
    var wrap = document.createElement('div');
    wrap.className = 'contenedor';
    var etq = document.createElement('span');
    etq.className = 'nivel';
    etq.textContent = nivel.charAt(0).toUpperCase() + nivel.slice(1);
    wrap.appendChild(etq);
    var span = document.createElement('span');
    span.className = 'texto';
    span.textContent = a.texto;
    wrap.appendChild(span);
    if (a.enlace) {
      var link = document.createElement('a');
      link.href = /^https?:\/\//.test(a.enlace) ? a.enlace : ruta(a.enlace);
      link.textContent = (a.texto_enlace || 'Más información') + ' →';
      wrap.appendChild(link);
    }
    bar.appendChild(wrap);
    /* En móvil el texto sale recortado a dos líneas; al tocarlo se ve entero. */
    bar.addEventListener('click', function (ev) {
      if (ev.target.closest('a')) return;         // los enlaces, a lo suyo
      bar.classList.toggle('abierto');
    });
    var cab = document.querySelector('apolana-cabecera');
    if (cab && cab.parentNode) cab.parentNode.insertBefore(bar, cab);
    else document.body.insertBefore(bar, document.body.firstChild);
  } catch (e) { /* si falla, no pasa nada: no se muestra aviso */ }
});

/* ==========================================================================
   BOTÓN "VOLVER" PARA LA APP INSTALADA
   Cuando la web se abre dentro de la app del club (modo standalone, sin barra
   del navegador) no hay botón atrás. Este pequeño botón deja volver al portal
   con un toque. En el navegador normal NO aparece.
   ========================================================================== */
(function () {
  function esApp() {
    try {
      return window.navigator.standalone === true ||
        (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);
    } catch (e) { return false; }
  }
  if (!esApp()) return;
  var base = window.APOLANA_BASE || '/';
  // En las páginas del portal ya hay barra propia: no hace falta el botón.
  if (/\/portal\//.test(location.pathname)) return;

  function montarVolver() {
    var b = document.createElement('button');
    b.type = 'button';
    b.setAttribute('aria-label', 'Volver a mi perfil');
    b.innerHTML = '<span aria-hidden="true">←</span> Volver a mi perfil';
    /* Barra fija ABAJO, como en las apps: no pelea con el aviso ni con la
       cabecera, y el pulgar llega mejor. Reserva su hueco al final. */
    var barra = document.createElement('div');
    barra.style.cssText = [
      'position:fixed', 'z-index:9500', 'left:0', 'right:0', 'bottom:0',
      'display:flex', 'align-items:center', 'justify-content:center',
      'background:#2E4256',
      'padding:8px 12px calc(8px + env(safe-area-inset-bottom))',
      'box-shadow:0 -2px 12px rgba(46,66,86,.25)'
    ].join(';');
    b.style.cssText = [
      'display:inline-flex', 'align-items:center', 'gap:8px',
      'background:transparent', 'color:#fff', 'border:0', 'cursor:pointer',
      'font-family:inherit', 'font-size:15px', 'font-weight:600',
      'padding:8px 10px', 'min-height:36px'
    ].join(';');
    b.addEventListener('click', function () {
      /* Directo al portal (tu perfil), no un "atrás" página a página. */
      location.assign(base + 'portal/');
    });
    barra.appendChild(b);
    document.body.appendChild(barra);
    /* Se aparta el contenido justo lo que mide la barra, para que no tape el pie. */
    function hueco() {
      document.body.style.paddingBottom = barra.getBoundingClientRect().height + 'px';
    }
    hueco();
    window.addEventListener('resize', hueco);
  }
  /* Si la página ya está montada (el script llegó tarde), se pinta ya. */
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', montarVolver);
  else montarVolver();
})();
