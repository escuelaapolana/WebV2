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
  { clave: 'club',       texto: 'El club',              url: '/club/' },
  { clave: 'entrena',    texto: 'Entrena con nosotros', url: '/competicion/' },
  { clave: 'escuelas',   texto: 'Escuelas',             url: '/escuela/' },
  { clave: 'calendario', texto: 'Calendario',           url: '/calendario/' },
  { clave: 'noticias',   texto: 'Noticias',             url: '/noticias/' },
  { clave: 'contacto',   texto: 'Contacto',             url: '/contacto/' },
];

/* --- Cabecera --- */
class ApolanaCabecera extends HTMLElement {
  connectedCallback() {
    const activo = this.getAttribute('activo') || '';
    const enlaces = MENU.map(m =>
      `<a href="${ruta(m.url)}"${m.clave === activo ? ' class="activo" aria-current="page"' : ''}>${m.texto}</a>`
    ).join('');
    const enlacesMovil = MENU.map(m =>
      `<a href="${ruta(m.url)}">${m.texto}</a>`
    ).join('') + `<a href="${ruta('/acceso/')}">Entrar</a>`;

    this.innerHTML = `
      <header class="cabecera">
        <div class="contenedor">
          <a class="marca" href="${base()}">
            <img src="${ruta('/assets/img/logo.png')}" alt="Club Atletismo Apolana">
            <span>
              <span class="nombre">Apolana</span><br>
              <span class="sub">ALICANTE · 1988</span>
            </span>
          </a>
          <nav class="menu">${enlaces}</nav>
          <div class="cabecera-acciones">
            <a class="btn btn--neutro" href="${ruta('/acceso/')}">Entrar</a>
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
      </footer>`;
  }
}

customElements.define('apolana-cabecera', ApolanaCabecera);
customElements.define('apolana-pie', ApolanaPie);
