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
    { texto: 'Liga Apolana',          url: '/liga/' },
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
    }).join('') + `<a href="${ruta('/portal/')}">Entrar</a>` + redesHTML();

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

/* ============================================================
   COLABORADORES
   Los gestiona el club desde el panel (tabla `colaboradores`): nombre,
   logo, enlace y si se enseña el logo, el nombre o los dos.
   Mientras la base contesta —o si no contesta— se pintan los de
   datos.js, que es como estaban antes. El pie nunca se queda cojo.
   ============================================================ */

/* Escapa un texto para poder meterlo en el HTML sin sustos.
   Nombre largo a propósito: varias páginas tienen su propio «esc» y este
   archivo se carga en todas; con un nombre corto se pisarían entre ellos. */
function escaparHTML(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/* Solo se aceptan enlaces normales (http, https) o de la propia web.
   Cualquier otra cosa se descarta y el colaborador sale sin enlazar. */
function enlaceSeguro(u) {
  const t = String(u || '').trim();
  if (!t) return '';
  if (/^https?:\/\//i.test(t)) return t;
  if (/^\/(?!\/)/.test(t) || /^\.{1,2}\//.test(t)) return t;
  return '';
}

/* Los de siempre (datos.js), como respaldo: solo nombre, sin logo. */
function colaboradoresRespaldo() {
  return ((window.APOLANA && window.APOLANA.colaboradores) || [])
    .map(n => ({ nombre: n, logo_url: null, enlace: null, mostrar: 'nombre' }));
}

/* Un colaborador, en HTML. `caja` es la clase del envoltorio, para que
   el pie y la portada compartan la misma lógica con distinta pinta. */
function colaboradorHTML(c, caja) {
  /* Si aún no tiene logo, se enseña el nombre aunque pida «solo logo»:
     antes un hueco vacío, mejor su nombre. */
  const modo = c.logo_url ? (c.mostrar || 'ambos') : 'nombre';
  let dentro = '';
  if (modo !== 'nombre') {
    /* Con el nombre a la vista el alt sobra (sería leerlo dos veces). */
    dentro += `<img src="${escaparHTML(c.logo_url)}" alt="${modo === 'logo' ? escaparHTML(c.nombre) : ''}" loading="lazy" decoding="async">`;
  }
  if (modo !== 'logo') dentro += `<span class="colab-nombre">${escaparHTML(c.nombre)}</span>`;

  const clases = `${caja} ${caja}--${modo}`;
  const url = enlaceSeguro(c.enlace);
  return url
    ? `<a class="${clases}" href="${escaparHTML(url)}" target="_blank" rel="noopener noreferrer" title="${escaparHTML(c.nombre)}">${dentro}</a>`
    : `<span class="${clases}">${dentro}</span>`;
}

/* Pinta la lista en el pie y en el bloque de la portada (si está). */
function pintarColaboradores(lista) {
  if (!lista || !lista.length) return;
  document.querySelectorAll('[data-colab-pie]').forEach(caja => {
    caja.innerHTML = lista.map(c => colaboradorHTML(c, 'colab-pie-item')).join('');
  });
  const portada = document.getElementById('colab-portada');
  if (portada) portada.innerHTML = lista.map(c => colaboradorHTML(c, 'colab-logo')).join('');
}

/* Estilos de los colaboradores. Van aquí (y no en la hoja general) para
   que cualquier página que use el pie los traiga puestos. */
(function estiloColaboradores() {
  const st = document.createElement('style');
  st.textContent = [
    '.pie-redes{display:flex;gap:10px;margin-top:4px}',
    '.pie-redes a{width:38px;height:38px;display:flex;align-items:center;justify-content:center;border:1px solid var(--linea,#EAE3D5);border-radius:10px;color:var(--navy,#2E4256);background:#fff}',
    '.pie-redes a:hover{border-color:var(--azul,#3B85C0);color:var(--azul-oscuro,#2F6FA8)}',
    '.pie-redes svg{width:19px;height:19px}',
    '.menu-movil-panel .pie-redes{margin-top:10px;padding-top:10px;border-top:1px solid var(--linea,#EAE3D5)}',
    /* --- En el pie --- */
    '.pie-colab{display:flex;flex-direction:column;gap:9px;align-items:flex-start}',
    '.colab-pie-item{display:inline-flex;align-items:center;gap:8px;color:var(--texto);text-decoration:none;line-height:1.3}',
    'a.colab-pie-item:hover{color:var(--azul-oscuro)}',
    /* Los logos, apagados para que no canten sobre el crema; al pasar por
       encima recuperan su color. */
    '.colab-pie-item img{height:24px;width:auto;max-width:120px;object-fit:contain;display:block;' +
      'filter:grayscale(1);opacity:.62;transition:filter .2s ease,opacity .2s ease}',
    'a.colab-pie-item:hover img,.colab-pie-item:hover img{filter:none;opacity:1}',
    /* En móvil el pie va a dos columnas y los colaboradores ocupan el ancho:
       ahí se ponen en línea y se reparten, en vez de hacer una lista larga. */
    '@media (max-width:700px){.pie-colab{flex-direction:row;flex-wrap:wrap;gap:10px 16px;align-items:center}',
      '.colab-pie-item img{height:22px}}'
    /* El bloque de la portada («Con la colaboración de») lleva sus propios
       estilos dentro de index.html, junto al resto de esa página. */
  ].join('');
  document.head.appendChild(st);
})();


/* --- Redes sociales del club (salen de datos.js) --- */
function redesHTML() {
  const c = (window.APOLANA && window.APOLANA.contacto) || {};
  const ic = {
    instagram: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.2" cy="6.8" r="1.1" fill="currentColor" stroke="none"/></svg>',
    facebook:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M14.5 8.5H17V5.5h-2.5A3.5 3.5 0 0 0 11 9v2H9v3h2v7h3v-7h2.2l.5-3H14V9c0-.3.2-.5.5-.5z"/></svg>',
    tiktok:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M14 4v10.5a3.5 3.5 0 1 1-3-3.46"/><path d="M14 4c.4 2.2 2 3.7 4.2 3.9"/></svg>',
    whatsapp:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M20 11.8a7.8 7.8 0 0 1-11.3 7L4 20l1.3-4.5A7.8 7.8 0 1 1 20 11.8z"/><path d="M9 9.5c0 3 2.5 5.5 5.5 5.5"/></svg>',
    email:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3.5 6.5l8.5 6 8.5-6"/></svg>'
  };
  const lista = [
    c.instagram && { k:'instagram', url:c.instagram.url, txt:'Instagram' },
    c.facebook  && { k:'facebook',  url:c.facebook.url,  txt:'Facebook' },
    c.tiktok    && { k:'tiktok',    url:c.tiktok.url,    txt:'TikTok' },
    c.whatsapp  && { k:'whatsapp',  url:c.whatsapp.url,  txt:'WhatsApp' },
    c.email     && { k:'email',     url:'mailto:'+c.email, txt:'Correo' }
  ].filter(Boolean);
  if (!lista.length) return '';
  return '<div class="pie-redes">' + lista.map(r =>
    `<a href="${r.url}" aria-label="${r.txt}" title="${r.txt}"${r.k==='email'?'':' target="_blank" rel="noopener"'}>${ic[r.k]}</a>`
  ).join('') + '</div>';
}

/* --- Pie de página (los datos salen de datos.js) --- */
class ApolanaPie extends HTMLElement {
  connectedCallback() {
    const d = window.APOLANA || {};
    const c = d.contacto || {};
    const lema = (d.club && d.club.lema) || '';
    const colab = colaboradoresRespaldo().map(x => colaboradorHTML(x, 'colab-pie-item')).join('');
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
            ${redesHTML()}
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
              <div class="pie-colab" data-colab-pie>${colab}</div>
            </div>
          </div>
        </div>
        <div class="pie-credito">© ${anio} Club Atletismo Apolana · Creada por <strong>Andrés Clavero Giménez</strong></div>
      </footer>`;
  }
}

customElements.define('apolana-cabecera', ApolanaCabecera);
customElements.define('apolana-pie', ApolanaPie);

/* --- Colaboradores de verdad: UNA consulta que sirve al pie y a la portada.
   Se lanza cuando la página ya está pintada, así que no retrasa nada; si
   falla, si no hay conexión o si todavía no hay ninguno guardado, se
   quedan los de datos.js que ya están puestos. --- */
document.addEventListener('DOMContentLoaded', async function () {
  if (!window.APOLANA_DB) return;
  try {
    const res = await window.APOLANA_DB
      .from('colaboradores')
      .select('nombre, logo_url, enlace, mostrar, orden')
      .eq('activo', true)
      .order('orden', { ascending: true })
      .order('nombre', { ascending: true });
    if (res.error || !res.data || !res.data.length) return;
    pintarColaboradores(res.data);
  } catch (e) { /* sin conexión: se quedan los de siempre */ }
});

/* --- Aviso de portada (barra superior si hay un aviso activo en la BD) --- */
document.addEventListener('DOMContentLoaded', async function () {
  if (!window.APOLANA_DB) return;
  try {
    var res = await window.APOLANA_DB
      .from('avisos')
      .select('texto, tipo, enlace, texto_enlace')
      .eq('activo', true)
      /* Si el aviso tiene fecha de caducidad, deja de salir solo al pasarla. */
      .or('fecha_fin.is.null,fecha_fin.gte.' + new Date().toISOString().slice(0, 10))
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
