/* ============================================================
   CABECERA Y PIE COMPARTIDOS · Club Atletismo Apolana
   Se escriben AQUÍ una sola vez. Cada página los coloca con:
     <apolana-cabecera activo="club"></apolana-cabecera>
     <apolana-pie></apolana-pie>
   Si hay que cambiar un enlace del menú o un teléfono, se cambia
   solo en este archivo y afecta a toda la web.
   ============================================================ */

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
      `<a href="${m.url}"${m.clave === activo ? ' class="activo" aria-current="page"' : ''}>${m.texto}</a>`
    ).join('');
    const enlacesMovil = MENU.map(m =>
      `<a href="${m.url}">${m.texto}</a>`
    ).join('') + '<a href="/acceso/">Entrar</a>';

    this.innerHTML = `
      <header class="cabecera">
        <div class="contenedor">
          <a class="marca" href="/">
            <img src="/assets/img/logo.png" alt="Club Atletismo Apolana">
            <span>
              <span class="nombre">Apolana</span><br>
              <span class="sub">ALICANTE · 1988</span>
            </span>
          </a>
          <nav class="menu">${enlaces}</nav>
          <div class="cabecera-acciones">
            <a class="btn btn--neutro" href="/acceso/">Entrar</a>
            <a class="btn btn--primario btn--sm" href="/inscripcion/">Inscribirse</a>
            <details class="menu-movil">
              <summary aria-label="Abrir menú">☰</summary>
              <div class="menu-movil-panel">${enlacesMovil}</div>
            </details>
          </div>
        </div>
      </header>`;
  }
}

/* --- Pie de página --- */
class ApolanaPie extends HTMLElement {
  connectedCallback() {
    this.innerHTML = `
      <footer class="pie">
        <div class="contenedor">
          <div class="pie-marca">
            <div class="fila">
              <img src="/assets/img/logo.png" alt="Club Apolana">
              <span class="nombre">Club Apolana</span>
            </div>
            <span class="lema">Atletismo, running, triatlón y natación en Alicante desde 1988.</span>
          </div>
          <div class="pie-cols">
            <div class="pie-col">
              <span class="eyebrow">Club</span>
              <a href="/">Inicio</a>
              <a href="/socio/">Hazte socio</a>
              <a href="/calendario/">Calendario</a>
              <a href="/noticias/">Noticias</a>
            </div>
            <div class="pie-col">
              <span class="eyebrow">Contacto</span>
              <a href="tel:+34625473830">625 47 38 30 · socios</a>
              <a href="tel:+34636061700">636 06 17 00 · escuela</a>
              <a href="mailto:administracion@atletismoapolana.com">administracion@atletismoapolana.com</a>
            </div>
            <div class="pie-col">
              <span class="eyebrow">Colaboran</span>
              <span>Deportes Alicante</span>
              <span>Diputación de Alicante</span>
              <span>Vithas</span>
            </div>
          </div>
        </div>
      </footer>`;
  }
}

customElements.define('apolana-cabecera', ApolanaCabecera);
customElements.define('apolana-pie', ApolanaPie);
