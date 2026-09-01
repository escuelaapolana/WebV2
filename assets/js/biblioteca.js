/* ============================================================
   LA BIBLIOTECA DE FOTOS · guardar no es publicar
   ------------------------------------------------------------
   Esto lo usan las cuatro pantallas del panel que tocan fotos del
   club: la Biblioteca, «Fotos de la web», «Páginas» y
   «Colaboradores». Está aquí y no repetido en cada una para que el
   día que cambie la regla, cambie en las cuatro a la vez.

   LA IDEA, EN DOS FRASES
   La biblioteca vive en un almacén PRIVADO. Estar en la biblioteca no
   publica nada: para verla hace falta ser administrador, y desde fuera
   no se llega ni sabiendo la dirección.

   Publicar es otra cosa, y pasa en otro momento: cuando alguien elige
   una foto para un hueco de la web y guarda. En ese instante se hace
   una COPIA en el almacén público, y esa copia es lo único que existe
   fuera. Si esa foto se quita del hueco y no está en ningún otro, la
   copia se borra y el original se queda tan tranquilo en la biblioteca.

   POR QUÉ UNA COPIA Y NO MOVER EL ARCHIVO
   Porque la misma foto puede estar en la portada y en la galería a la
   vez. Si se moviera, quitarla de un sitio dejaría el otro con un
   hueco. Con copia, el original nunca se toca.

   LOS ENLACES QUE CADUCAN
   Como el almacén es privado no hay dirección fija: hay que pedir un
   enlace temporal para cada foto, y ese enlace caduca. Dura una hora,
   se piden todos de golpe (no de uno en uno) y se vuelven a pedir solos
   diez minutos antes de que venzan. Así, quien deje la pantalla abierta
   toda la mañana no se encuentra la rejilla llena de fotos rotas.
   ============================================================ */
(function () {
  'use strict';

  var CUBO_PRIVADO   = 'imagenes-club';   // la biblioteca de trabajo: no se ve desde fuera
  var CUBO_PUBLICO   = 'imagenes';        // lo que ve el visitante de la web
  var CARPETA_BIBLIO = 'biblioteca';      // dentro del almacén privado
  var CARPETA_PUB    = 'publicadas';      // dentro del público: solo copias de fotos publicadas

  var FIRMA_S   = 3600;        // lo que dura un enlace temporal: una hora
  var MARGEN_MS = 10 * 60000;  // se renueva diez minutos antes de que caduque

  /* Las secciones del club. Estaban copiadas en cuatro pantallas, y
     bastaba con que una se quedara atrás para que la misma foto
     apareciera en un sitio como «Montaña» y en otro sin sección. */
  var CATS = [
    { v: 'escuela',          t: 'Escuela' },
    { v: 'escuela-natacion', t: 'Escuela de natación' },
    { v: 'escuela-municipal',t: 'Escuela municipal' },
    { v: 'competicion',      t: 'Competición' },
    { v: 'running',          t: 'Running' },
    { v: 'natacion',         t: 'Natación' },
    { v: 'triatlon',         t: 'Triatlón' },
    { v: 'montana',          t: 'Montaña' },
    { v: 'cubo',             t: 'El Cubo' },
    { v: 'campus',           t: 'Campus' },
    { v: 'instalaciones',    t: 'Instalaciones' },
    { v: 'club',             t: 'Club / general' },
    { v: 'eventos',          t: 'Eventos' },
    { v: 'equipacion',       t: 'Equipación' },
    { v: 'otras',            t: 'Otras' }
  ];
  var SIN = 'Sin sección';

  function etiquetaCat(v) {
    if (!v) return SIN;
    for (var i = 0; i < CATS.length; i++) if (CATS[i].v === v) return CATS[i].t;
    return v;
  }

  function esc(s) { var d = document.createElement('div'); d.textContent = (s == null ? '' : String(s)); return d.innerHTML; }

  /* ------------------------------------------------------------
     LOS ENLACES TEMPORALES
     ------------------------------------------------------------ */
  var FIRMAS = {};   // ruta -> { url, hasta }

  function vigente(ruta) {
    var f = FIRMAS[ruta];
    return f && f.url && (f.hasta - Date.now()) > MARGEN_MS ? f.url : '';
  }

  /* Pide de una tacada los enlaces que falten. Devuelve cuántos se han
     quedado sin firmar, que es lo que hay que enseñar si algo va mal:
     «no hemos podido cargar 3 miniaturas» dice más que una rejilla
     medio vacía sin explicación. */
  async function firmar(sb, rutas) {
    var faltan = [], vistas = {};
    (rutas || []).forEach(function (r) {
      if (!r || vistas[r] || vigente(r)) return;
      vistas[r] = true;
      faltan.push(r);
    });
    if (!faltan.length) return 0;

    var sinFirmar = 0;
    /* Por tandas: pedir 155 enlaces en una sola llamada es pedirle al
       almacén una respuesta enorme, y si falla se caen los 155. */
    for (var i = 0; i < faltan.length; i += 60) {
      var tanda = faltan.slice(i, i + 60);
      try {
        var r = await sb.storage.from(CUBO_PRIVADO).createSignedUrls(tanda, FIRMA_S);
        if (r.error) { sinFirmar += tanda.length; continue; }
        (r.data || []).forEach(function (x) {
          if (x && x.signedUrl && x.path) FIRMAS[x.path] = { url: x.signedUrl, hasta: Date.now() + FIRMA_S * 1000 };
          else sinFirmar++;
        });
      } catch (e) { sinFirmar += tanda.length; }
    }
    return sinFirmar;
  }

  /* La dirección con la que se enseña una foto en el panel, según de
     dónde venga. Son tres orígenes distintos que conviven a propósito
     (lo explica la migración 140):
       · 'imagenes-club' → biblioteca privada: enlace temporal
       · 'imagenes'      → las viejas del almacén público: dirección fija
       · 'sitio'         → un archivo de la propia web (assets/...)      */
  function miniatura(sb, foto) {
    if (!foto) return '';
    var ruta = String(foto.ruta || '');
    if (/^(https?:)?\/\//i.test(ruta) || /^data:/i.test(ruta)) return ruta;

    if (foto.cubo === 'sitio' || /^\.?\/?assets\//.test(ruta)) {
      var limpia = ruta.replace(/^\.?\//, '');
      var b = window.APOLANA_BASE || '../../';
      try { return new URL(b + limpia, location.href).href; } catch (e) { return b + limpia; }
    }
    if (foto.cubo === 'imagenes') return urlPublicaDe(sb, ruta);
    return vigente(ruta) || (FIRMAS[ruta] && FIRMAS[ruta].url) || '';
  }

  function urlPublicaDe(sb, ruta) {
    return sb.storage.from(CUBO_PUBLICO).getPublicUrl(ruta).data.publicUrl;
  }

  /* Vuelve a poner la dirección en las miniaturas ya pintadas, sin
     repintar la rejilla entera: repintar perdería el scroll y las
     casillas marcadas justo cuando la persona está trabajando. */
  function refrescarImagenes(sb, raiz) {
    var imgs = (raiz || document).querySelectorAll('img[data-ruta]');
    for (var i = 0; i < imgs.length; i++) {
      var ruta = imgs[i].getAttribute('data-ruta');
      var u = miniatura(sb, { ruta: ruta, cubo: imgs[i].getAttribute('data-cubo') || CUBO_PRIVADO });
      if (u && imgs[i].getAttribute('src') !== u) imgs[i].setAttribute('src', u);
    }
  }

  /* Se llama una vez por pantalla. Cada pocos minutos mira si a algún
     enlace le queda poco y lo renueva. Sin esto, la pantalla abierta
     media hora sigue bien, pero la abierta hora y pico no. */
  function vigilarCaducidad(sb, dameRutas, raiz) {
    setInterval(async function () {
      var rutas = [];
      try { rutas = dameRutas() || []; } catch (e) { return; }
      var caducan = rutas.filter(function (r) { return r && !vigente(r); });
      if (!caducan.length) return;
      await firmar(sb, caducan);
      refrescarImagenes(sb, raiz);
    }, 5 * 60000);
  }

  /* ------------------------------------------------------------
     LEER LA BIBLIOTECA
     ------------------------------------------------------------ */
  var COLUMNAS = 'id,ruta,cubo,nombre,titulo,categoria,favorita,grupo,fecha_foto,publicada_ruta,publicada_en,en_galeria,created_at';

  async function cargar(sb) {
    var r = await sb.from('biblioteca_fotos').select(COLUMNAS)
      .order('fecha_foto', { ascending: false, nullsFirst: false })
      .order('created_at', { ascending: false });
    if (r.error) return { error: r.error, fotos: [] };
    var fotos = r.data || [];
    /* Solo hay que pedir enlace temporal para las del almacén privado;
       las otras dos clases ya tienen dirección propia. */
    var privadas = fotos.filter(function (f) { return f.cubo === CUBO_PRIVADO; })
                        .map(function (f) { return f.ruta; });
    var sinFirmar = await firmar(sb, privadas);
    return { error: null, fotos: fotos, sinFirmar: sinFirmar };
  }

  /* ------------------------------------------------------------
     PUBLICAR
     ------------------------------------------------------------ */
  function extensionDe(ruta) {
    var m = String(ruta || '').match(/\.([a-z0-9]+)$/i);
    return m ? '.' + m[1].toLowerCase() : '.jpg';
  }

  /* La copia pública se llama siempre igual para la misma foto (lleva
     el identificador de su ficha). Así, publicar dos veces la misma no
     deja dos archivos, y la dirección que ya esté puesta en una página
     sigue valiendo. */
  function rutaPublicaDe(foto) {
    return CARPETA_PUB + '/' + foto.id + extensionDe(foto.ruta);
  }

  /* Devuelve { url } con la dirección pública definitiva, o { error }.
     Es lo que hay que llamar justo antes de guardar un hueco de la web. */
  async function publicar(sb, foto) {
    if (!foto) return { error: { message: 'No hay foto elegida.' } };

    /* Las que no viven en el almacén privado ya son públicas de por sí:
       las viejas del almacén público y los archivos del propio sitio.
       Publicarlas es solo apuntar que están puestas; no se copia nada,
       porque copiarlas duplicaría archivos sin ganar nada. */
    if (foto.cubo !== CUBO_PRIVADO) {
      var url = miniatura(sb, foto);
      if (!foto.publicada_ruta && foto.cubo === CUBO_PUBLICO) {
        await sb.from('biblioteca_fotos')
          .update({ publicada_ruta: foto.ruta, publicada_en: new Date().toISOString() })
          .eq('id', foto.id);
        foto.publicada_ruta = foto.ruta;
      }
      return { url: url };
    }

    var destino = foto.publicada_ruta || rutaPublicaDe(foto);

    /* Si ya estaba publicada, la copia existe y vale: no se vuelve a
       subir. Es el caso de la foto que está en dos huecos a la vez. */
    if (!foto.publicada_ruta) {
      var copiada = false;
      try {
        var c = await sb.storage.from(CUBO_PRIVADO)
          .copy(foto.ruta, destino, { destinationBucket: CUBO_PUBLICO });
        copiada = !c.error;
        /* Que ya exista no es un fallo: quiere decir que la copia estaba
           de antes (por ejemplo, se publicó y la ficha no se llegó a
           apuntar). Se aprovecha. */
        if (c.error && /exist|duplicate|resource already/i.test(c.error.message || '')) copiada = true;
      } catch (e) {}

      /* Si el almacén no sabe copiar de un sitio a otro, se hace a la
         antigua: se baja la foto y se vuelve a subir. Es más lento pero
         no deja a nadie sin poder publicar. */
      if (!copiada) {
        var dl = await sb.storage.from(CUBO_PRIVADO).download(foto.ruta);
        if (dl.error) return { error: dl.error };
        var up = await sb.storage.from(CUBO_PUBLICO).upload(destino, dl.data, {
          cacheControl: '3600', upsert: true, contentType: dl.data.type || 'image/jpeg'
        });
        if (up.error) return { error: up.error };
      }
    }

    var r = await sb.from('biblioteca_fotos')
      .update({ publicada_ruta: destino, publicada_en: foto.publicada_en || new Date().toISOString() })
      .eq('id', foto.id);
    /* Si la copia se subió pero la ficha no se pudo apuntar, se retira
       la copia: dejarla sería una foto publicada que el panel no sabe
       que lo está, y nadie podría despublicarla. */
    if (r.error) {
      if (!foto.publicada_ruta) { try { await sb.storage.from(CUBO_PUBLICO).remove([destino]); } catch (e) {} }
      return { error: r.error };
    }

    foto.publicada_ruta = destino;
    if (!foto.publicada_en) foto.publicada_en = new Date().toISOString();
    return { url: urlPublicaDe(sb, destino) };
  }

  /* ------------------------------------------------------------
     DESPUBLICAR (solo si ya no la usa nadie)
     ------------------------------------------------------------
     Se le pasa la dirección que ESTABA puesta en el hueco antes de
     cambiarla. Si esa foto sigue puesta en otro sitio, no se toca. */
  async function despublicarSiSobra(sb, urlAntigua) {
    var url = String(urlAntigua || '');
    if (!url) return { retirada: false };

    var m = url.match(/\/object\/public\/imagenes\/(.+)$/);
    if (!m) return { retirada: false };
    var ruta = decodeURIComponent(m[1].split('?')[0]);

    var usos = await sb.rpc('biblioteca_usos', { p_ruta: ruta });
    /* Si no se puede preguntar, no se borra nada. Equivocarse por no
       borrar deja un archivo de más; equivocarse por borrar deja una
       página con un hueco. */
    if (usos.error) return { retirada: false, error: usos.error };
    if ((usos.data || 0) > 0) return { retirada: false, enUso: usos.data };

    /* AQUÍ ESTÁ EL CUIDADO IMPORTANTE:
       solo se borra el archivo si es una COPIA de las que hace este
       mecanismo (viven en `publicadas/`). Las fotos viejas viven en
       `biblioteca/` del almacén público y ESE ES SU ÚNICO ARCHIVO:
       borrarlo sería perder la foto, no despublicarla. De esas solo se
       quita la marca. */
    var esCopia = ruta.indexOf(CARPETA_PUB + '/') === 0;
    if (esCopia) {
      var d = await sb.storage.from(CUBO_PUBLICO).remove([ruta]);
      if (d.error) return { retirada: false, error: d.error };
    }
    await sb.from('biblioteca_fotos')
      .update({ publicada_ruta: null, publicada_en: null })
      .eq('publicada_ruta', ruta);
    return { retirada: esCopia, desmarcada: true };
  }

  /* ------------------------------------------------------------
     ENCONTRAR UNA FOTO ENTRE CIENTOS
     ------------------------------------------------------------
     Con quince fotos vale una rejilla y ya. Con ciento cincuenta, no:
     en un móvil es un rollo de scroll infinito. Las históricas traen el
     acontecimiento y el día en el nombre, así que se agrupan solas:
     «Gala 36 años (47)», «Cross de Castellón (3)»… y lo que no tiene
     acontecimiento cae en un grupo del final.                        */
  var MESES = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];

  function fechaLarga(d) {
    if (!d) return '';
    var p = String(d).slice(0, 10).split('-');
    if (p.length !== 3) return '';
    return Number(p[2]) + ' de ' + (MESES[Number(p[1]) - 1] || '') + ' de ' + p[0];
  }

  function agrupar(lista) {
    var grupos = [], indice = {};
    (lista || []).forEach(function (f) {
      var clave = f.grupo || (f.categoria ? '__cat:' + f.categoria : '__sueltas');
      if (!indice[clave]) {
        indice[clave] = {
          clave: clave,
          titulo: f.grupo || (f.categoria ? etiquetaCat(f.categoria) : 'Fotos sueltas'),
          fecha: f.fecha_foto || '',
          fotos: []
        };
        grupos.push(indice[clave]);
      }
      var g = indice[clave];
      g.fotos.push(f);
      // Del grupo se enseña el día más reciente que tenga.
      if (f.fecha_foto && (!g.fecha || f.fecha_foto > g.fecha)) g.fecha = f.fecha_foto;
    });
    /* Primero lo que tiene fecha, de lo más nuevo a lo más viejo; luego
       lo suelto. Así lo de este año se ve sin buscar. */
    grupos.sort(function (a, b) {
      if (!!a.fecha !== !!b.fecha) return a.fecha ? -1 : 1;
      if (a.fecha !== b.fecha) return a.fecha < b.fecha ? 1 : -1;
      return String(a.titulo).localeCompare(String(b.titulo), 'es');
    });
    return grupos;
  }

  function sinTildes(s) {
    return String(s == null ? '' : s).toLowerCase()
      .replace(/[áàäâã]/g, 'a').replace(/[éèëê]/g, 'e').replace(/[íìïî]/g, 'i')
      .replace(/[óòöôõ]/g, 'o').replace(/[úùüû]/g, 'u').replace(/ñ/g, 'n');
  }

  /* Filtro común de las cuatro pantallas: sección, favoritas, texto y
     —nuevo— «solo las publicadas», que es la pregunta que se hace
     cuando alguien quiere saber qué se está viendo hoy en la web. */
  function filtrar(lista, f) {
    var q = sinTildes((f.busca || '').trim());
    return (lista || []).filter(function (x) {
      if (f.favoritas && !x.favorita) return false;
      if (f.publicadas && !x.publicada_ruta) return false;
      if (f.categoria === '__sin') { if (x.categoria) return false; }
      else if (f.categoria && x.categoria !== f.categoria) return false;
      if (q) {
        var texto = sinTildes((x.titulo || '') + ' ' + (x.nombre || '') + ' ' + (x.grupo || '') + ' ' + (x.fecha_foto || ''));
        if (texto.indexOf(q) === -1) return false;
      }
      return true;
    });
  }

  window.APOLANA_BIBLIO = {
    CUBO_PRIVADO: CUBO_PRIVADO,
    CUBO_PUBLICO: CUBO_PUBLICO,
    CARPETA_BIBLIO: CARPETA_BIBLIO,
    CARPETA_PUB: CARPETA_PUB,
    CATS: CATS,
    SIN: SIN,
    etiquetaCat: etiquetaCat,
    cargar: cargar,
    firmar: firmar,
    miniatura: miniatura,
    urlPublicaDe: urlPublicaDe,
    refrescarImagenes: refrescarImagenes,
    vigilarCaducidad: vigilarCaducidad,
    publicar: publicar,
    despublicarSiSobra: despublicarSiSobra,
    agrupar: agrupar,
    filtrar: filtrar,
    fechaLarga: fechaLarga,
    esc: esc
  };
})();
