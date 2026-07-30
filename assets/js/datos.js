/* ============================================================
   DATOS DEL CLUB · fuente única de la verdad
   ------------------------------------------------------------
   Todo lo que se repite en varias páginas (contacto, precios,
   noticias, horarios…) se escribe UNA sola vez AQUÍ.
   Las páginas lo leen; si cambia un dato, cambia en toda la web.
   (Es el principio "un dato se escribe una vez" del proyecto.)
   Cuando conectemos Supabase, estos datos vendrán de la base de
   datos, pero el resto de la web no tendrá que cambiar.
   ============================================================ */
window.APOLANA = {

  club: {
    nombre: 'Club Atletismo Apolana',
    ciudad: 'Alicante',
    desde: 1988,
    lema: 'Atletismo, running, triatlón y natación en Alicante desde 1988.',
  },

  /* --- Contacto (aparece en el pie de TODAS las páginas) --- */
  contacto: {
    tel_socios:  { texto: '625 47 38 30', tel: '+34625473830', nota: 'socios' },
    tel_escuela: { texto: '636 06 17 00', tel: '+34636061700', nota: 'escuela' },
    email:       'administracion@atletismoapolana.com',
    email_junta: 'junta@atletismoapolana.com',
    instagram:   { usuario: '@apolana.alicante', url: 'https://instagram.com/apolana.alicante' },
  },

  colaboradores: ['Deportes Alicante', 'Comunitat Esport', 'Diputación de Alicante', 'Vithas'],

  /* --- Cuotas (el ejemplo canónico del proyecto) --- */
  tarifas: {
    socio_anual: 120,          // € al año por adulto, sin descuento
    pista_socio_3dias: 40,     // €/mes, pago trimestral
    pista_socio_5dias: 55,
    pista_no_socio: 70,
    running_madre_tierra: 40,
    running_la_tribu: 60,
    natacion_socio: [35, 45, 55],     // bonos de 4 / 8 / 12 clases
    natacion_no_socio: [50, 60, 70],
    cubo_padres: 40,
    cubo_padres_escuela: 30,
  },

  /* --- Tabla "Grupos y precios" de la home y las secciones --- */
  grupos: [
    { nombre: 'Atletismo pista',  desc: 'Federado, técnica y competición en pista, cross y ruta', dias: 'L · X · V', precio: '40-55€/mes', url: '/competicion/' },
    { nombre: 'Running',          desc: 'Madre Tierra para empezar, La Tribu para apretar',        dias: 'M · J · S', precio: '40-60€/mes', url: '/running/' },
    { nombre: 'Natación adultos', desc: 'Técnica y series en la piscina del Monte Tossal',          dias: 'L a V',     precio: '35-55€/mes', url: '/natacion/' },
    { nombre: 'Triatlón',         desc: 'Natación, bici y carrera con calendario propio',           dias: 'Según bloque', precio: 'Consultar', url: '/triatlon/' },
    { nombre: 'Montaña',          desc: 'Trail y senderismo por las sierras de Alicante',           dias: 'Fines de semana', precio: 'Consultar', url: '/montana/' },
  ],

  /* --- Entrenos de hoy (home + calendario + app) --- */
  hoy: [
    { hora: '17:30', que: 'Escuela · Benjamín', donde: 'Pista Joaquín Villar' },
    { hora: '19:00', que: 'Madre Tierra',       donde: 'Playa San Juan' },
    { hora: '19:30', que: 'La Tribu · series',  donde: 'Pista Joaquín Villar' },
    { hora: '20:30', que: 'Natación adultos',   donde: 'Monte Tossal' },
  ],

  /* --- Noticias (home + /noticias) --- */
  noticias: [
    { fecha: '27 JUL', cat: 'Competición', titulo: 'Tres podios en el Cross de Xixona', slug: 'cross-xixona',
      resumen: 'Marta Ripoll, Jorge Castell y el equipo cadete suben al cajón en una mañana redonda para el club.', foto: '/assets/img/noticia.jpg' },
    { fecha: '24 JUL', cat: 'Escuela', titulo: 'Abierta la inscripción de la escuela 2026-27', slug: 'inscripcion-escuela-2627' },
    { fecha: '19 JUL', cat: 'Club', titulo: 'Nueva equipación disponible en el container', slug: 'equipacion-container' },
    { fecha: '11 JUL', cat: 'Club', titulo: 'El club cierra la temporada con 420 atletas', slug: 'cierre-temporada' },
  ],

  /* --- Cifras del club (/club) --- */
  cifras: { fundacion: 1988, atletas: 420, socios: 175, secciones: 7, medallas: 64, anios: 38 },
};

/* ------------------------------------------------------------
   Ayudante: rellena en el HTML cualquier elemento marcado con
   data-dato="ruta.al.dato", p. ej. <span data-dato="contacto.email">.
   ------------------------------------------------------------ */
window.APOLANA.leer = function (ruta) {
  return ruta.split('.').reduce((o, k) => (o == null ? o : o[k]), window.APOLANA);
};
window.APOLANA.rellenar = function (raiz) {
  (raiz || document).querySelectorAll('[data-dato]').forEach(function (el) {
    var v = window.APOLANA.leer(el.getAttribute('data-dato'));
    if (v != null && typeof v !== 'object') el.textContent = v;
  });
};
