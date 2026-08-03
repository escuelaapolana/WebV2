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

  /* --- Contacto (aparece en el pie de TODAS las páginas) ---
     ⚠️ ESTO YA NO ES DONDE SE CAMBIAN LOS TELÉFONOS.
     Desde que los contactos viven en la base de datos (tabla
     `contactos`, migración 085), lo que hay aquí abajo es el
     RESPALDO: lo que se ve mientras la base contesta, y lo que se
     queda si no contesta, para que el pie no salga mudo.

     Para cambiar un teléfono: panel → Club → «Personas de contacto».
     Cambiarlo aquí no sirve de nada, porque la base manda. */
  contacto: {
    tel_socios:  { texto: '625 47 38 30', tel: '+34625473830', nota: 'socios' },
    tel_escuela: { texto: '636 06 17 00', tel: '+34636061700', nota: 'escuela' },
    email:       'administracion@atletismoapolana.com',
    email_junta: 'junta@atletismoapolana.com',
    instagram:   { usuario: '@apolana.alicante', url: 'https://instagram.com/apolana.alicante' },
    facebook:    { usuario: 'atletismo.apolana.alicante', url: 'https://www.facebook.com/atletismo.apolana.alicante' },
    tiktok:      { usuario: '@escuela.apolana', url: 'https://www.tiktok.com/@escuela.apolana' },
    whatsapp:    { usuario: '636 06 17 00', url: 'https://wa.me/34636061700' },
  },

  /* --- Y de quién es cada uno de esos huecos ---
     Traduce el respaldo de arriba a la persona de la base que manda
     sobre él. Lo lee `contactos-web.js`, que en cuanto la base
     contesta repasa el pie de la página y deja el dato bueno (o lo
     retira, si el club ha decidido no publicarlo).

     El día que el teléfono de la escuela pase a ser de otra persona,
     se cambia la clave de aquí y ya está: el pie de las 30 páginas
     sigue solo. Las claves salen del panel, en «Personas de
     contacto» (Adrián lleva la escuela, Isabel administración). */
  contacto_desde_la_base: {
    tel_escuela: { clave: 'adrian', campo: 'telefono' },
    whatsapp:    { clave: 'adrian', campo: 'telefono' },
    tel_socios:  { clave: 'isabel', campo: 'telefono' },
    email:       { clave: 'isabel', campo: 'email'    },
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
    /* Estas dos no tienen cuota de entrenamiento porque no tienen entrenador
       asignado. Se escribe el motivo, nunca «Consultar»: «Consultar» parece un
       descuido y obliga a llamar para algo que se explica en una línea. */
    { nombre: 'Triatlón',         desc: 'Natación, bici y carrera; ahora sin entrenador de sección', dias: 'Según bloque', precio: 'Sin cuota · solo la de socio', url: '/triatlon/' },
    { nombre: 'Montaña',          desc: 'Trail y senderismo por las sierras de Alicante',           dias: 'Fines de semana', precio: 'Sin cuota · solo la de socio', url: '/montana/' },
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
   Y que los contactos de verdad lleguen a TODAS las páginas
   ------------------------------------------------------------
   Este archivo lo carga la web entera, así que es el único sitio
   desde el que se puede alcanzar el pie de las treinta páginas sin
   ir tocándolas una a una. Aquí solo se pide el ayudante que hace
   el trabajo (`contactos-web.js`); si ya viene puesto en la página,
   no se repite.

   Va con red por todos lados: si algo falla, la página se queda con
   el respaldo de arriba y no se entera nadie. Este archivo no puede
   romper nada, porque si se rompe se rompe toda la web a la vez.
   ------------------------------------------------------------ */
(function () {
  try {
    var yo = document.currentScript && document.currentScript.src;
    if (!yo) return;                                   // sin saber dónde estoy, no hago nada
    var url = yo.replace(/datos\.js(\?.*)?$/, 'contactos-web.js');
    if (url === yo) return;                            // no era este archivo
    if (document.querySelector('script[src*="contactos-web.js"]')) return;   // ya está
    var s = document.createElement('script');
    s.src = url;
    /* `async = false` pide que se ejecute en orden y no en cuanto baje.
       No siempre alcanza (el ayudante puede adelantar a `db.js`), y por
       eso él espera a que la conexión aparezca antes de preguntar. */
    s.async = false;
    document.head.appendChild(s);
  } catch (e) { /* la web se queda con el respaldo de este archivo */ }
})();

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
