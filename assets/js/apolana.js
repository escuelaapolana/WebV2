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
   la página en la que estás (con el atributo activo="...").

   SIETE entradas y ni una más: nueve no caben en 1100 px y esconderlas
   tras el botón de menú hace que la web parezca una app. Se agrupa:
   «Entrena con nosotros» se queda con los adultos, «Escuelas» con los
   niños, y «Club» con todo lo que no es «cómo me apunto». Liga va
   suelta, junto a Calendario y Noticias: es lo que está pasando. */
const MENU = [
  /* «Entrenar», el nombre corto: cuatro sílabas menos y no pierde nada.
     Quien busca dónde entrenar lo entiende igual, y deja holgura en la barra. */
  /* El nombre del menú lleva a la lanzadera, no a una de sus hijas:
     antes «Entrenar» caía en atletismo en pista y parecía que el club
     solo hacía eso. Igual que «Escuelas» abre en «Todas las escuelas». */
  { clave: 'entrena', texto: 'Entrenar', url: '/entrenar/', sub: [
    { texto: 'Todas las secciones', url: '/entrenar/' },
    { texto: 'Atletismo en pista',  url: '/competicion/' },
    { texto: 'Running',             url: '/running/' },
    { texto: 'Natación adultos',    url: '/natacion/' },
    { texto: 'Montaña',             url: '/montana/' },
    { texto: 'Triatlón',            url: '/triatlon/' },
    { texto: 'Deporte adaptado',    url: '/escuela-municipal-atletismo/#otros' },
    { texto: 'Programas municipales', url: '/escuela-municipal-atletismo/' },
    /* El Cubo, el último: es el único que va por bonos de uso y no por
       cuota mensual, así que se separa del resto a propósito. */
    { texto: 'El Cubo · por bonos de uso', url: '/cubo/' },
  ] },
  { clave: 'escuelas', texto: 'Escuelas', url: '/escuelas/', sub: [
    { texto: 'Todas las escuelas',   url: '/escuelas/' },
    { texto: 'Escuela de atletismo', url: '/escuela/' },
    { texto: 'Escuela de natación',  url: '/escuela-natacion/' },
    { texto: 'Campus de verano',     url: '/campus/' },
  ] },
  /* Calendario primero: es la pantalla que manda («qué hay ese día»).
     Horarios va detrás y contesta la otra pregunta, la de la semana fija
     («¿a qué hora entreno los martes?»). */
  { clave: 'calendario', texto: 'Calendario', url: '/calendario/' },
  { clave: 'horarios',   texto: 'Horarios',   url: '/horarios/' },
  /* «Liga» va en ámbar: es un nombre propio del club, no una categoría. */
  { clave: 'liga', texto: 'Liga', url: '/liga/', marca: true },
  { clave: 'noticias',   texto: 'Noticias',   url: '/noticias/' },
  { clave: 'club', texto: 'Club', url: '/club/', sub: [
    { texto: 'El club',          url: '/club/' },
    { texto: 'Historia',         url: '/club/historia/' },
    { texto: 'Junta directiva',  url: '/club/#junta' },
    /* Récords y Ranking van juntos a propósito: uno es lo mejor de la
       historia y el otro quién va mejor esta temporada. */
    { texto: 'Récords',          url: '/club/records/' },
    { texto: 'Ranking',          url: '/club/ranking/' },
    { texto: 'Instalaciones',    url: '/instalaciones/' },
    { texto: 'Familias',         url: '/familias/' },
    { texto: 'Galería',          url: '/galeria/' },
    { texto: 'Tienda',           url: '/tienda/' },
    { texto: 'Patrocinadores',   url: '/#colaboradores' },
    { texto: 'Contacto',         url: '/contacto/' },
  ] },
];

/* --- Iconos de las redes (un solo grosor, 24 px de caja) --- */
const ICONO = {
  instagram: '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3.5" y="3.5" width="17" height="17" rx="5" stroke="currentColor" stroke-width="1.9"/><circle cx="12" cy="12" r="4" stroke="currentColor" stroke-width="1.9"/><circle cx="17" cy="7" r="1.2" fill="currentColor"/></svg>',
  tiktok:    '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M14 3.5v10.8a3.7 3.7 0 11-3.7-3.7c.4 0 .8.06 1.2.18" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/><path d="M14 3.5c.5 2.4 2.3 4 4.7 4.2" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>',
  facebook:  '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M14.5 21v-8h2.8l.4-3.2h-3.2V7.9c0-.9.3-1.5 1.6-1.5h1.7V3.5c-.3 0-1.3-.1-2.4-.1-2.4 0-4 1.4-4 4.1v2.3H8.6V13h2.8v8h3.1z" fill="currentColor"/></svg>',
  whatsapp:  '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 20l1.3-3.9A8 8 0 1120 12a8 8 0 01-12.1 6.9L4 20z" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>'
};

/* --- Enlace de WhatsApp de la cabecera ---
   Sale dos veces a propósito (aquí y en el pie): arriba no es una red
   social, es cómo pregunta la gente. Solo texto e icono, SIN fondo verde:
   un botón verde de WhatsApp en la cabecera se lee como publicidad. */
function whatsappCabeceraHTML() {
  const w = (window.APOLANA && window.APOLANA.contacto && window.APOLANA.contacto.whatsapp) || null;
  if (!w || !w.url) return '';
  return `<a class="cab-whatsapp" href="${w.url}" target="_blank" rel="noopener"
             title="Escríbenos por WhatsApp al ${escaparHTML(w.usuario || '')}">
            ${ICONO.whatsapp}<span>Pregúntanos</span></a>`;
}

/* --- Cabecera --- */
class ApolanaCabecera extends HTMLElement {
  connectedCallback() {
    const activo = this.getAttribute('activo') || '';
    const enlaces = MENU.map(m => {
      const clases = [m.clave === activo ? 'activo' : '', m.marca ? 'marca-club' : ''].filter(Boolean);
      const act = (clases.length ? ` class="${clases.join(' ')}"` : '') +
                  (m.clave === activo ? ' aria-current="page"' : '');
      if (m.sub) {
        const items = m.sub.map(s => `<a href="${ruta(s.url)}">${s.texto}</a>`).join('');
        const clasesTop = ['top'].concat(clases).join(' ');
        return `<div class="tiene-sub"><a class="${clasesTop}"${m.clave === activo ? ' aria-current="page"' : ''} href="${ruta(m.url)}">${m.texto}<span class="caret" aria-hidden="true"></span></a><div class="submenu">${items}</div></div>`;
      }
      return `<a href="${ruta(m.url)}"${act}>${m.texto}</a>`;
    }).join('');
    /* En el móvil, los grupos van PLEGADOS. Antes se abría el menú y salían
       los treinta enlaces de golpe: para llegar a «Historia», que está en el
       último grupo, había que pasar por delante de todo lo demás. Ahora se
       pincha «Club» y se abre lo suyo.

       El nombre del grupo deja de ser un enlace y pasa a abrir el grupo, y no
       se pierde nada: cada uno lleva dentro su propia puerta —«Todas las
       secciones», «Todas las escuelas», «El club»— que va al mismo sitio al
       que iba el título.

       Y el grupo de la página en la que estás sale abierto: si vienes de
       Natación y abres el menú, lo lógico es ver a sus hermanas al lado. */
    const enlacesMovil = MENU.map(m => {
      if (!m.sub) return `<a href="${ruta(m.url)}">${m.texto}</a>`;
      const abierto = (m.clave && m.clave === activo) ? ' open' : '';
      return `<details class="men-gr"${abierto}>` +
        `<summary>${m.texto}<span class="men-fl" aria-hidden="true">&#9662;</span></summary>` +
        `<div class="sub">${m.sub.map(s => `<a href="${ruta(s.url)}">${s.texto}</a>`).join('')}</div>` +
      `</details>`;
    }).join('') +
      `<a href="${ruta('/portal/')}">Acceso</a>` +
      `<a href="${ruta('/inscripcion/')}">Inscribirse</a>` +
      /* En móvil WhatsApp va aquí dentro y en la página de contacto: flotando
         encima del contenido molesta. */
      redesFilasHTML('menu-redes');

    this.innerHTML = `
      <header class="cabecera">
        <div class="contenedor">
          <a class="marca" href="${base()}">
            <img src="${ruta('/assets/img/logo.png')}" alt="Club Atletismo Apolana">
            <span class="marca-txt">
              <span class="nombre">Apolana</span>
              <span class="sub">Alicante · 1988</span>
            </span>
          </a>
          <nav class="menu">${enlaces}</nav>
          <div class="cabecera-acciones">
            ${whatsappCabeceraHTML()}
            <a class="btn btn--neutro" href="${ruta('/portal/')}">Acceso</a>
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

/* Estilos de la cabecera nueva, las redes y los colaboradores. Van aquí
   (y no en la hoja general) para que cualquier página que use la cabecera
   o el pie los traiga puestos sin tocar nada. */
(function estiloCabeceraYPie() {
  const st = document.createElement('style');
  st.textContent = [
    /* ============ CABECERA ============
       Siete entradas van justas de sitio: el logotipo compacto y el menú
       algo más apretado para que quepan sin recortar nada. */
    '.cabecera .contenedor{gap:20px}',
    '.cabecera .menu{gap:20px}',
    '.cabecera .marca img{height:38px}',
    '.cabecera .marca{gap:10px}',
    '.cabecera .marca .nombre{font-size:19px}',
    '.cabecera .marca .sub{font-size:11px;letter-spacing:0;text-transform:none;color:var(--texto-suave)}',
    /* Ámbar = el club como institución (Liga, récords, nombres propios de
       grupo). El azul se reserva para lo que se pulsa, así que aquí va en
       texto y nunca en bloque de fondo: no se confunde con un aviso. */
    '.menu a.marca-club{color:#8A5307}',
    '.menu a.marca-club:hover{color:#6F4206}',
    '.menu a.marca-club.activo{color:#8A5307;font-weight:600}',

    /* WhatsApp arriba: solo texto e icono, sin fondo verde. */
    '.cab-whatsapp{display:inline-flex;align-items:center;gap:7px;min-height:44px;padding:0 6px;' +
      'font-size:15px;font-weight:600;color:var(--verde,#3F7A4C);white-space:nowrap}',
    '.cab-whatsapp:hover{color:#2F5C3A}',
    '.cab-whatsapp svg{width:18px;height:18px;flex:none}',

    /* El botón de acceso no se esconde nunca: es la única puerta al portal. */
    '.cabecera-acciones .btn--neutro{display:inline-flex}',

    /* Aprietes progresivos antes de rendirse al menú de hamburguesa. */
    '@media (max-width:1300px){.cabecera .menu{gap:15px;font-size:14.5px}.cabecera .marca .sub{display:none}}',
    '@media (max-width:1120px){.cabecera .menu{gap:11px;font-size:14px}.cab-whatsapp span{display:none}.cab-whatsapp{padding:0 4px}}',
    /* En móvil WhatsApp se queda dentro del menú, no flotando arriba.
       Y las acciones se van a la derecha del todo: sin el menú horizontal
       en medio se quedaban pegadas al logotipo, con un hueco a la derecha. */
    '@media (max-width:950px){.cabecera-acciones .cab-whatsapp{display:none}' +
      '.cabecera-acciones{margin-left:auto}}',
    /* En el móvil la cabecera va compacta: escudo a 28 px y «Apolana». Cuanto
       menos ocupe aquí arriba, más pantalla queda para lo que importa. */
    '@media (max-width:700px){.cabecera .contenedor{gap:10px;padding-block:10px}' +
      '.cabecera .marca img{height:28px}.cabecera .marca{gap:9px}' +
      '.cabecera .marca .nombre{font-size:19px}.cabecera-acciones{gap:8px}}',

    /* El menú activo se marca con un subrayado de 2 px, no solo con color:
       un cambio de tono sobre crema no se ve a pie de pista. */
    '.menu a.activo{box-shadow:inset 0 -2px 0 currentColor}',

    /* ============ CABECERA DE PÁGINA INTERIOR ============
       Franja a sangre y sin radio: navy si no hay foto, foto con velo si
       la hay. Siempre con el dato duro a la derecha. */
    '.pag-hero{position:relative;background:var(--navy,#2E4256);color:#fff;overflow:hidden}',
    '.pag-hero .contenedor{position:relative;display:flex;align-items:flex-end;' +
      'justify-content:space-between;gap:24px;flex-wrap:wrap;padding-block:30px}',
    '.pag-hero-txt{display:flex;flex-direction:column;gap:9px;max-width:620px;min-width:0}',
    '.pag-hero-txt .encima{font-size:14px;color:rgba(255,255,255,0.6)}',
    /* 46 px y a dos líneas: es un titular de interior, no el de portada. */
    '.pag-hero h1{font-family:var(--fuente-titulo);font-weight:700;font-size:46px;' +
      'line-height:0.96;text-transform:uppercase;color:#fff;margin:0;overflow-wrap:anywhere}',
    '.pag-hero p{margin:0;font-size:17px;line-height:1.45;color:rgba(255,255,255,0.82);max-width:560px}',
    '.pag-hero-dato{display:flex;align-items:baseline;gap:8px;flex:none}',
    '.pag-hero-dato b{font-family:var(--fuente-dato);font-size:34px;font-weight:700;line-height:1;color:#fff}',
    '.pag-hero-dato span{font-size:15px;color:rgba(255,255,255,0.7)}',
    /* Con foto: a sangre, sin esquinas, con velo en diagonal. */
    '.pag-hero-foto{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:center 42%}',
    '.pag-hero-velo{position:absolute;inset:0;background:linear-gradient(96deg,' +
      'rgba(22,31,40,0.90) 0%,rgba(22,31,40,0.74) 40%,rgba(22,31,40,0.28) 100%)}',
    '.pag-hero--foto .contenedor{padding-block:52px}',
    '@media (max-width:700px){.pag-hero h1{font-size:34px}',
      '.pag-hero .contenedor{padding-block:22px;align-items:flex-start}',
      '.pag-hero--foto .contenedor{padding-block:34px}',
      '.pag-hero p{font-size:15px}.pag-hero-dato b{font-size:26px}}',

    /* Secciones que alternan crema flojo y crema fuerte, a sangre y sin
       radio: dos secciones seguidas nunca comparten fondo. */
    '.seccion--banda{background:var(--crema-banda,#F1EADC);border-radius:0}',

    /* ============ CIERRE OSCURO ============
       A sangre y sin radio: es una banda, no una tarjeta gigante. Va pegado
       al pie, que también es navy, para que no quede crema entre los dos. */
    '.cierre{background:var(--navy,#2E4256);color:#fff}',
    '.cierre .contenedor{display:flex;align-items:center;justify-content:space-between;' +
      'gap:24px;flex-wrap:wrap;padding-block:34px}',
    '.cierre-txt{display:flex;flex-direction:column;gap:6px;min-width:260px}',
    '.cierre-tit{font-family:var(--fuente-titulo);font-weight:700;font-size:36px;' +
      'line-height:1;text-transform:uppercase;color:#fff}',
    '.cierre-sub{font-size:15px;line-height:1.5;color:rgba(255,255,255,0.78);max-width:520px}',
    '.cierre-acc{display:flex;gap:12px;flex-wrap:wrap}',
    '.cierre .btn--claro{background:transparent;color:#fff;border-color:rgba(255,255,255,0.45);font-weight:600}',
    '.cierre .btn--claro:hover{background:rgba(255,255,255,0.14);color:#fff}',
    /* En móvil los dos botones no caben en fila: van apilados y a ancho
       completo, que es como se pulsa con una mano. */
    '@media (max-width:700px){.cierre .contenedor{padding-block:26px}.cierre-tit{font-size:28px}',
      '.cierre-txt{min-width:0}',
      '.cierre-acc{width:100%;flex-direction:column;gap:9px}.cierre-acc .btn{width:100%}}',

    /* ============ EL PIE ES LA BANDA ============
       Navy a sangre y sin radio, pegado al cierre de arriba. Nada de
       tarjeta interior flotando dentro del crema: el pie entero es la
       masa oscura que cierra la página. */
    /* ⚠️ `footer.pie`, NO `.pie` A SECAS, Y ESTO FUE UN FALLO DE VERDAD.
       «pie» se usa en la web con dos sentidos: el PIE DE PÁGINA (esta
       banda navy) y el PIE DE UN DATO —el renglón pequeño debajo de una
       cifra o de una foto—. Como esta regla decía `.pie` sin más, pintaba
       de navy los pies de dato: en «Familias · Las reglas» salían cuatro
       rectángulos azul oscuro detrás de un texto gris, ilegibles y
       partidos en dos líneas. Andrés: «este subrayado no se ve bien, está
       mal destacado». Y no era un subrayado: era el pie de página
       pisándole el fondo a otra cosa.
       Con `footer.pie` solo entra el pie de página de verdad, que es
       siempre un `<footer>`. Los otros trece sitios que usan la clase
       —galería, tests, biblioteca, buzón, los documentos del portal— se
       quedan como estaban. */
    'footer.pie{background:var(--navy,#2E4256);color:rgba(255,255,255,0.85);' +
      'margin-top:0;border-top:0;border-radius:0}',
    /* Cuatro columnas en una sola rejilla: identidad · Club · Contacto · Síguenos. */
    '.pie .contenedor{display:grid;grid-template-columns:1.2fr 1fr 1fr 1.1fr;' +
      'gap:30px;padding-block:34px 26px;align-items:start}',
    '.pie-col{display:flex;flex-direction:column;gap:8px;min-width:0}',
    '.pie-rotulo{font-size:14px;color:rgba(255,255,255,0.55);margin-bottom:2px}',
    '.pie-col a{color:rgba(255,255,255,0.85);min-height:28px;display:flex;align-items:center;overflow-wrap:anywhere}',
    '.pie-col a:hover{color:#fff}',
    /* La identidad va dentro del navy y ocupa la primera columna. */
    '.pie-col--marca{gap:10px}',
    '.pie-col--marca .fila{display:flex;align-items:center;gap:10px}',
    '.pie-col--marca img{height:36px;width:auto;filter:brightness(0) invert(1)}',
    '.pie-col--marca .nombre{font-family:var(--fuente-titulo);font-weight:700;font-size:21px;' +
      'text-transform:uppercase;line-height:1;color:#fff}',
    '.pie-col--marca .lema{font-size:14px;line-height:1.5;color:rgba(255,255,255,0.7)}',

    /* ============ REDES: icono + cuenta, sin caja detrás ============
       Sobre el navy el icono ya contrasta; un cuadrado de fondo solo
       añadía ruido. */
    '.redes-filas{display:flex;flex-direction:column;gap:2px}',
    '.red-fila{display:flex;align-items:center;gap:10px;min-height:44px;' +
      'text-decoration:none;color:rgba(255,255,255,0.85)}',
    '.red-fila:hover{color:#fff}',
    '.red-icono{width:20px;height:20px;flex:none;display:flex;align-items:center;justify-content:center}',
    '.red-icono svg{width:18px;height:18px}',
    '.red-cuenta{flex:1;min-width:0;font-size:14px;overflow-wrap:anywhere}',
    /* El nombre de la red se queda para el menú de móvil, donde no hay
       rótulo de columna que lo explique. */
    '.pie .red-nombre{display:none}',

    /* --- Colaboradores: una fila final, separada con una línea --- */
    '.pie-colab-fila{border-top:1px solid rgba(255,255,255,0.14);padding-top:16px;' +
      'padding-bottom:20px;display:flex;flex-direction:column;gap:10px}',
    '.pie-colab{display:flex;flex-wrap:wrap;align-items:center;gap:10px 22px}',
    '.colab-pie-item{display:inline-flex;align-items:center;gap:8px;min-height:26px;' +
      'color:rgba(255,255,255,0.82);text-decoration:none;font-size:13px;line-height:1.35}',
    'a.colab-pie-item:hover{color:#fff}',
    /* Todos a 26 px y en un solo tono: se leen como un conjunto. */
    '.colab-pie-item img{height:26px;width:auto;max-width:120px;object-fit:contain;display:block;' +
      'filter:brightness(0) invert(1);opacity:.85;transition:opacity .2s ease}',
    'a.colab-pie-item:hover img{opacity:1}',
    '.colab-pie-item--ambos{flex-direction:column;align-items:flex-start;gap:4px}',

    /* --- Fila legal: aviso, privacidad, condiciones y cookies ---
       Van juntas y en su propia fila, encima del crédito. Es donde
       las busca todo el mundo, y son las únicas cuatro páginas de
       la web que la ley obliga a tener a mano desde cualquier sitio.
       44 px de alto: aquí se pulsa con el pulgar y con prisa. */
    '.pie-legal{border-top:1px solid rgba(255,255,255,0.14);display:flex;flex-wrap:wrap;' +
      'justify-content:center;gap:0 26px;padding:4px 20px}',
    '.pie-legal a{color:rgba(255,255,255,0.72);font-size:13px;' +
      'min-height:44px;display:flex;align-items:center}',
    '.pie-legal a:hover{color:#fff}',

    /* El crédito ya no lleva línea propia: la de arriba la pone la
       fila legal, y dos filetes seguidos se ven como un error. */
    '.pie-credito{border-top:0;color:rgba(255,255,255,0.6);letter-spacing:0;padding-top:0}',
    '.pie-credito strong{color:rgba(255,255,255,0.85)}',

    /* --- Las redes dentro del menú de móvil (ahí sí, sobre crema) --- */
    '.menu-movil-panel .menu-redes{margin-top:10px;padding-top:10px;border-top:1px solid var(--linea,#EAE3D5)}',
    '.menu-movil-panel .red-fila{border-bottom:1px solid var(--linea,#EAE3D5);color:var(--texto)}',
    '.menu-movil-panel .red-icono{width:24px;height:24px;color:var(--navy,#2E4256)}',
    '.menu-movil-panel .red-nombre{font-size:14px;color:var(--texto-suave,#6E6656)}',

    /* En móvil, dos columnas: es lo que ya funcionaba y se respeta. */
    '@media (max-width:700px){.pie .contenedor{grid-template-columns:minmax(0,1fr) minmax(0,1fr);' +
      'gap:22px 18px;padding-block:26px 20px}',
      '.pie-col--marca{grid-column:1 / -1}',
      '.pie-col a,.pie-col .red-cuenta{font-size:13.5px;line-height:1.35}',
      '.pie-colab-fila{padding-bottom:16px}}'
    /* El bloque de la portada («Con la colaboración de») lleva sus propios
       estilos dentro de index.html, junto al resto de esa página. */
  ].join('');
  document.head.appendChild(st);
})();


/* --- Redes sociales del club (salen de datos.js) ---
   Cuatro filas de 44 px: icono + la cuenta + el nombre de la red. Nada de
   fila de iconos sueltos: un icono sin la cuenta al lado no dice a dónde
   lleva, y arriba robaba el sitio que necesita la navegación. */
function redesFilasHTML(clase) {
  const c = (window.APOLANA && window.APOLANA.contacto) || {};
  const lista = [
    c.instagram && { k:'instagram', url:c.instagram.url, cuenta:c.instagram.usuario || '@apolana.alicante', red:'Instagram' },
    c.tiktok    && { k:'tiktok',    url:c.tiktok.url,    cuenta:c.tiktok.usuario    || '@escuela.apolana',  red:'TikTok' },
    c.facebook  && { k:'facebook',  url:c.facebook.url,  cuenta:'/' + String(c.facebook.usuario || '').replace(/^\//, ''), red:'Facebook' },
    c.whatsapp  && { k:'whatsapp',  url:c.whatsapp.url,  cuenta:c.whatsapp.usuario  || '',                  red:'WhatsApp' }
  ].filter(Boolean);
  if (!lista.length) return '';
  return `<div class="redes-filas ${clase || ''}">` + lista.map(r =>
    `<a class="red-fila" href="${escaparHTML(r.url)}" target="_blank" rel="noopener">` +
      `<span class="red-icono">${ICONO[r.k]}</span>` +
      `<span class="red-cuenta">${escaparHTML(r.cuenta)}</span>` +
      `<span class="red-nombre">${escaparHTML(r.red)}</span>` +
    '</a>'
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
    /* Cierre oscuro pegado al pie: la página termina en dos masas oscuras
       seguidas, sin crema entre medias. Es lo que le da ritmo —oscuro,
       claro, oscuro— en vez de dejarlo todo flotando sobre el mismo crema.
       Una página puede quitarlo con <apolana-pie sin-cierre>. */
    const cierre = this.hasAttribute('sin-cierre') ? '' : `
      <section class="cierre">
        <div class="contenedor">
          <div class="cierre-txt">
            <span class="cierre-tit">Ven a probar cuatro días</span>
            <span class="cierre-sub">Gratis y sin compromiso, a cualquier edad. Te decimos qué grupo te encaja.</span>
          </div>
          <div class="cierre-acc">
            <a class="btn btn--primario" href="${ruta('/inscripcion/')}">Prueba 4 días gratis</a>
            <a class="btn btn--claro" href="${ruta('/horarios/')}">Ver los horarios</a>
          </div>
        </div>
      </section>`;

    this.innerHTML = `
      ${cierre}
      <!-- El pie ES la banda: todo dentro del navy, a sangre y sin radio.
           Cuatro columnas en una sola rejilla, para que nada quede
           desalineado ni flotando en una tarjeta interior. -->
      <footer class="pie">
        <div class="contenedor">
          <div class="pie-col pie-col--marca">
            <div class="fila">
              <img src="${ruta('/assets/img/logo.png')}" alt="Club Apolana">
              <span class="nombre">Club Apolana</span>
            </div>
            <span class="lema">${lema}</span>
          </div>
          <div class="pie-col">
            <span class="pie-rotulo">Club</span>
            <a href="${base()}">Inicio</a>
            <a href="${ruta('/socio/')}">Hazte socio</a>
            <a href="${ruta('/calendario/')}">Calendario</a>
            <a href="${ruta('/noticias/')}">Noticias</a>
            <a href="${ruta('/tienda/')}">Tienda</a>
            <a href="${ruta('/app/')}">Instalar la app</a>
          </div>
          <div class="pie-col">
            <span class="pie-rotulo">Contacto</span>
            ${tel(c.tel_socios)}
            ${tel(c.tel_escuela)}
            ${c.email ? `<a href="mailto:${c.email}">${c.email}</a>` : ''}
          </div>
          <div class="pie-col">
            <span class="pie-rotulo">Síguenos</span>
            ${redesFilasHTML('pie-redes-filas')}
          </div>
        </div>
        <!-- Los colaboradores, en una fila final separada por una línea: a la
             misma altura y en un solo tono se leen como un conjunto y no como
             cuatro pegatinas. -->
        <div class="contenedor pie-colab-fila">
          <span class="pie-rotulo">Con la colaboración de</span>
          <div class="pie-colab" data-colab-pie>${colab}</div>
        </div>
        <!-- Las páginas legales, en todas las páginas: es el sitio donde
             se buscan y donde la ley pide que estén siempre a mano. -->
        <div class="pie-legal">
          <a href="${ruta('/legal/aviso-legal/')}">Aviso legal</a>
          <a href="${ruta('/legal/privacidad/')}">Privacidad</a>
          <a href="${ruta('/legal/condiciones/')}">Condiciones de uso</a>
          <a href="${ruta('/legal/cookies/')}">Cookies</a>
        </div>
        <div class="pie-credito">© ${anio} Club Atletismo Apolana · Creada por <strong>Andrés Clavero Giménez</strong></div>
      </footer>`;
  }
}

/* ============================================================
   CABECERA DE PÁGINA INTERIOR
   Una franja a sangre con el título, una frase y el dato que importa.
   Antes el título de una interior era texto navy sobre crema y no se
   distinguía de un título de sección: la página entera flotaba.

   Se usa así, y con eso basta:
     <apolana-hero titulo="Escuelas" frase="…" dato="4" rotulo="escuelas">
     <apolana-hero titulo="…" foto="/assets/img/x.jpg">   ← con foto y velo

   El dato se puede rellenar después desde la página (cuando llega de la
   base) con:  document.querySelector('apolana-hero').dato(27, 'grupos')
   ============================================================ */
class ApolanaHero extends HTMLElement {
  connectedCallback() {
    const t = a => escaparHTML(this.getAttribute(a) || '');
    const foto = this.getAttribute('foto');
    const dato = this.getAttribute('dato');
    const rotulo = this.getAttribute('rotulo');
    const frase = this.getAttribute('frase');
    const encima = this.getAttribute('encima');

    this.innerHTML = `
      <section class="pag-hero${foto ? ' pag-hero--foto' : ''}">
        ${foto ? `<img class="pag-hero-foto" src="${escaparHTML(ruta(foto))}" alt=""${
          this.getAttribute('foto-hueco') ? ` data-img="${t('foto-hueco')}"` : ''}>
          <div class="pag-hero-velo"></div>` : ''}
        <div class="contenedor">
          <div class="pag-hero-txt">
            ${encima ? `<span class="encima"${this.getAttribute('id-encima') ? ` id="${t('id-encima')}"` : ''}>${t('encima')}</span>` : ''}
            <h1${this.getAttribute('id-titulo') ? ` id="${t('id-titulo')}"` : ''}>${t('titulo')}</h1>
            ${frase ? `<p${this.getAttribute('id-frase') ? ` id="${t('id-frase')}"` : ''}>${t('frase')}</p>` : ''}
          </div>
          <div class="pag-hero-dato" data-dato${dato ? '' : ' hidden'}>
            <b>${dato ? t('dato') : ''}</b><span>${rotulo ? t('rotulo') : ''}</span>
          </div>
        </div>
      </section>`;
  }
  /* Para rellenar el dato duro cuando llega de la base. Con cero o sin
     número no se enseña un «0»: se esconde y ya está. */
  dato(valor, rotulo) {
    const caja = this.querySelector('[data-dato]');
    if (!caja) return;
    const n = parseInt(valor, 10);
    if (!n) { caja.hidden = true; return; }
    caja.querySelector('b').textContent = n;
    caja.querySelector('span').textContent = rotulo || '';
    caja.hidden = false;
  }
}

customElements.define('apolana-cabecera', ApolanaCabecera);
customElements.define('apolana-hero', ApolanaHero);
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

/* --- Aviso de portada -------------------------------------------------
   Puede haber varios avisos activos a la vez y la franja solo pinta UNO.
   El orden de preferencia, dicho a las claras:
     1º  el urgente, si lo hay (y si hay dos urgentes, el que caduque antes);
     2º  entre los normales, el que caduque antes —es el que corre prisa—;
     3º  a igualdad de todo, el más recién escrito.
   Un aviso sin fecha de caducidad no corre prisa, así que va el último.
   ---------------------------------------------------------------------- */
document.addEventListener('DOMContentLoaded', async function () {
  if (!window.APOLANA_DB) return;
  try {
    var res = await window.APOLANA_DB
      .from('avisos')
      .select('texto, tipo, enlace, texto_enlace, urgente, fecha_inicio, fecha_fin, created_at')
      .eq('activo', true);
    if (res.error || !res.data || !res.data.length) return;

    /* El día de hoy en el calendario de aquí, no en el de Londres: un aviso
       programado para mañana tiene que entrar a las 00:00 de España. */
    var d = new Date();
    var hoy = d.getFullYear() + '-' +
      String(d.getMonth() + 1).padStart(2, '0') + '-' +
      String(d.getDate()).padStart(2, '0');

    /* Ventana de fechas: las dos son opcionales. Sin fecha de inicio, el
       aviso vale desde ya; sin fecha de fin, no caduca. */
    var vigentes = res.data.filter(function (v) {
      if (!v.texto) return false;
      if (v.fecha_inicio && v.fecha_inicio > hoy) return false;   // aún no toca
      if (v.fecha_fin && v.fecha_fin < hoy) return false;         // ya pasó
      return true;
    });
    if (!vigentes.length) return;

    /* Un aviso es urgente por su casilla. Se admite además el nivel
       "urgente" de toda la vida, para que los que ya estuvieran puestos así
       no se caigan de arriba al aplicar el cambio. */
    function esUrgente(v) {
      return v.urgente === true || String(v.tipo || '').toLowerCase() === 'urgente';
    }
    vigentes.sort(function (x, y) {
      if (esUrgente(x) !== esUrgente(y)) return esUrgente(x) ? -1 : 1;
      var fx = x.fecha_fin || '9999-12-31', fy = y.fecha_fin || '9999-12-31';
      if (fx !== fy) return fx < fy ? -1 : 1;
      return String(y.created_at || '').localeCompare(String(x.created_at || ''));
    });

    var a = vigentes[0];
    var urgente = esUrgente(a);

    /* Tres niveles, como en la maqueta. Se admiten también los nombres
       antiguos ("info", "aviso") para que un aviso viejo no salga sin color. */
    var NIVELES = {
      informativo: 'informativo', info: 'informativo',
      importante: 'importante', aviso: 'importante',
      urgente: 'urgente'
    };
    var nivel = NIVELES[String(a.tipo || '').toLowerCase()] || 'informativo';
    /* Un aviso urgente sale en rojo aunque el nivel diga otra cosa: si algo
       manda subir arriba del todo, el color tiene que decir lo mismo. */
    if (urgente) nivel = 'urgente';

    /* Un aviso normal NO va arriba del todo: una franja a todo el ancho por
       encima del logotipo manda demasiado para lo que dice. Si la página
       ofrece un hueco dentro de la portada, se coloca ahí, en su sitio.
       El urgente se salta el hueco y se va arriba, que es de lo que se trata. */
    var hueco = document.getElementById('aviso-en-hero');
    if (hueco && !urgente) {
      var t = document.createElement('span');
      t.className = 'texto';
      t.textContent = a.texto;
      hueco.appendChild(t);
      if (a.enlace) {
        var b = document.createElement('a');
        b.href = /^https?:\/\//.test(a.enlace) ? a.enlace : ruta(a.enlace);
        b.textContent = a.texto_enlace || 'Ver más';
        hueco.appendChild(b);
      }
      hueco.hidden = false;
      return;
    }

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
    /* La franja se mete DESPUÉS de pintar la página, y el navegador compensa
       solo lo que se cuela por encima para que no salte lo que estás leyendo
       («scroll anchoring»): el resultado es que la franja nace justo fuera de
       la pantalla. Si el visitante estaba arriba del todo —acaba de entrar—,
       se le devuelve arriba y así la ve. Si ya había bajado, no se le mueve. */
    var estabaArriba = window.scrollY <= 1;
    var cab = document.querySelector('apolana-cabecera');
    if (cab && cab.parentNode) cab.parentNode.insertBefore(bar, cab);
    else document.body.insertBefore(bar, document.body.firstChild);
    if (estabaArriba && window.scrollY > 0) window.scrollTo(0, 0);
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
