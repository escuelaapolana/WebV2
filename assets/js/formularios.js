/* ============================================================
   FORMULARIOS DE ALTA · las piezas que comparten los cuatro
   ------------------------------------------------------------
   Apuntarse a la escuela, hacerse socio, domiciliar y renovar usan
   las mismas cinco cosas, y están aquí para que se comporten igual
   en los cuatro sitios: si en una pantalla el IBAN se valida al
   salir del campo y en la de al lado mientras se escribe, parecen
   dos webs distintas.

     1. Avisar de un error diciendo QUÉ HACER, y al salir del campo.
     2. Comprobar un número de cuenta y decir de qué banco es.
     3. La caja de firmar con el dedo.
     4. Guardar lo que se lleva escrito, en el propio móvil.
     5. Hablar con la base por la puerta de las funciones.

   NO GUARDA NADA EN NINGÚN SITIO QUE NO SEA EL PROPIO MÓVIL hasta
   que la persona le da a enviar. Un formulario a medias de un menor
   no tiene por qué estar en ningún servidor.
   ============================================================ */

(function () {
  'use strict';

  var F = {};
  window.APOLANA_FORM = F;


  /* ============================================================
     1 · LOS ERRORES
     ------------------------------------------------------------
     Tres reglas, y las tres se han roto en algún formulario alguna
     vez:

       · Se valida AL SALIR del campo, no mientras se escribe. Que
         te digan «el correo está mal» cuando llevas escritas tres
         letras es de mala educación.
       · Nunca «campo inválido»: se dice qué hacer. «Al IBAN le
         faltan 4 dígitos. Son 24 en total.»
       · Nunca todo de golpe al pulsar el botón. Si al enviar hay
         algo mal, se marca y se lleva la vista al primero.
     ============================================================ */

  /* Marca un campo como mal rellenado y escribe debajo qué hacer. */
  F.mal = function (elemento, mensaje) {
    var caja = elemento.closest('.campo') || elemento.closest('.casilla');
    if (!caja) return;
    caja.classList.add('mal');
    var hueco = caja.querySelector('.error');
    if (hueco) hueco.textContent = mensaje;
    elemento.setAttribute('aria-invalid', 'true');
  };

  /* Lo contrario: se ha arreglado. */
  F.bien = function (elemento) {
    var caja = elemento.closest('.campo') || elemento.closest('.casilla');
    if (!caja) return;
    caja.classList.remove('mal');
    elemento.removeAttribute('aria-invalid');
  };

  /* Lleva la vista al primer campo mal rellenado y pone el cursor
     dentro. Sin esto, en un móvil el error puede quedar tres
     pantallas más arriba y la persona no sabe por qué no avanza. */
  F.irAlPrimerFallo = function (dentroDe) {
    var caja = (dentroDe || document).querySelector('.campo.mal, .casilla.mal');
    if (!caja) return false;
    caja.scrollIntoView({ behavior: 'smooth', block: 'center' });
    var campo = caja.querySelector('input, select, textarea');
    if (campo) { try { campo.focus({ preventScroll: true }); } catch (e) { campo.focus(); } }
    return true;
  };

  /* Engancha la comprobación al salir del campo. `comprueba`
     devuelve el mensaje de error, o nada si está bien. */
  F.vigilar = function (elemento, comprueba) {
    if (!elemento) return;
    elemento.addEventListener('blur', function () {
      var fallo = comprueba(elemento.value, elemento);
      if (fallo) F.mal(elemento, fallo); else F.bien(elemento);
    });
    /* Mientras se escribe solo se QUITA el error, nunca se pone: en
       cuanto empieza a corregir, el rojo desaparece y se nota que
       va por buen camino. */
    elemento.addEventListener('input', function () {
      var caja = elemento.closest('.campo');
      if (caja && caja.classList.contains('mal')) {
        if (!comprueba(elemento.value, elemento)) F.bien(elemento);
      }
    });
  };


  /* ============================================================
     2 · COMPROBACIONES DE CADA COSA
     ============================================================ */

  F.hayAlgo = function (valor, queEs) {
    if (String(valor || '').trim().length >= 2) return null;
    return 'Falta ' + queEs + '.';
  };

  F.correo = function (valor) {
    var v = String(valor || '').trim();
    if (!v) return 'Falta el correo. Ahí te mandamos el resumen.';
    if (v.indexOf('@') < 0) return 'Al correo le falta la arroba.';
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/.test(v)) return 'Ese correo no parece bien escrito. Míralo otra vez, por favor.';
    return null;
  };

  F.telefono = function (valor) {
    var d = String(valor || '').replace(/\D/g, '');
    if (!d) return 'Falta el teléfono.';
    if (d.length < 9) return 'Al teléfono le faltan ' + (9 - d.length) + ' número' + (9 - d.length === 1 ? '' : 's') + '. Son 9.';
    if (d.length > 12) return 'Ese teléfono tiene números de más. Son 9.';
    return null;
  };

  /* El DNI español: 8 números y una letra que sale de los números.
     Vale también el NIE, que empieza por X, Y o Z. */
  var LETRAS_DNI = 'TRWAGMYFPDXBNJZSQVHLCKE';
  F.dni = function (valor) {
    var v = String(valor || '').toUpperCase().replace(/[\s-]/g, '');
    if (!v) return 'Falta el DNI.';
    var m = /^([XYZ]?)(\d{7,8})([A-Z])$/.exec(v);
    if (!m) return 'Escribe el DNI con sus 8 números y la letra, sin espacios ni guiones.';
    var numero = ({ '': '', 'X': '0', 'Y': '1', 'Z': '2' })[m[1]] + m[2];
    if (LETRAS_DNI[parseInt(numero, 10) % 23] !== m[3]) {
      return 'La letra del DNI no cuadra con los números. Míralo otra vez.';
    }
    return null;
  };

  /* La fecha de nacimiento de un niño de la escuela. */
  F.fechaNacimiento = function (valor) {
    if (!valor) return 'Falta la fecha de nacimiento.';
    var d = new Date(valor + 'T00:00:00');
    if (isNaN(d.getTime())) return 'Esa fecha no se entiende. Ponla como día, mes y año.';
    var hoy = new Date();
    if (d > hoy) return 'Esa fecha todavía no ha llegado.';
    if (d.getFullYear() < 1920) return 'Revisa el año de nacimiento.';
    return null;
  };


  /* ============================================================
     3 · EL NÚMERO DE CUENTA
     ------------------------------------------------------------
     Un IBAN lleva dentro sus propios dígitos de control, así que se
     puede saber si está mal escrito SIN preguntarle a nadie y sin
     mandar el número a ningún sitio. Se comprueba aquí mismo, en el
     móvil.

     Y cuando está bien se dice de qué banco es. Es un detalle
     pequeño que quita mucho miedo: confirma que el número que has
     copiado es el tuyo y no el de la línea de arriba.
     ============================================================ */

  /* Los códigos de los bancos con los que se encuentra el club. Si
     uno no está en la lista NO se dice nada: es preferible callar a
     nombrar mal el banco de alguien. */
  var BANCOS = {
    '0019': 'Deutsche Bank',   '0049': 'Santander',      '0061': 'Banca March',
    '0073': 'Openbank',        '0075': 'Santander',      '0081': 'Banco Sabadell',
    '0128': 'Bankinter',       '0182': 'BBVA',           '0186': 'Banco Mediolanum',
    '0198': 'Banco Cooperativo','0216': 'Targobank',     '0234': 'Banco Caminos',
    '0238': 'Banco Pastor',    '0239': 'EVO Banco',      '0487': 'Banco Sabadell',
    '1465': 'ING',             '1491': 'Triodos Bank',   '1544': 'Andbank',
    '1550': 'Banco Caixa Geral','2038': 'CaixaBank',     '2048': 'Unicaja',
    '2080': 'Abanca',          '2085': 'Ibercaja',       '2095': 'Kutxabank',
    '2100': 'CaixaBank',       '2103': 'Unicaja',        '3025': "Caixa d'Enginyers",
    '3058': 'Cajamar',         '3081': 'Caja Rural',     '3187': 'Caja Rural'
  };

  /* Quitar espacios y poner en mayúsculas, que es como se guarda. */
  F.ibanLimpio = function (valor) {
    return String(valor || '').toUpperCase().replace(/[\s-]/g, '');
  };

  /* Escribirlo de cuatro en cuatro mientras se teclea, como viene en
     la libreta del banco. Así se compara de un vistazo. */
  F.ibanBonito = function (valor) {
    return F.ibanLimpio(valor).replace(/(.{4})/g, '$1 ').trim();
  };

  /* La cuenta del 97: se mueven los cuatro primeros al final, las
     letras se cambian por números (A=10, B=11…) y el resto de
     dividir entre 97 tiene que dar 1. */
  function cuadraElNoventaySiete(iban) {
    var movido = iban.slice(4) + iban.slice(0, 4);
    var enNumeros = movido.replace(/[A-Z]/g, function (c) { return c.charCodeAt(0) - 55; });
    var resto = 0;
    for (var i = 0; i < enNumeros.length; i++) {
      resto = (resto * 10 + parseInt(enNumeros[i], 10)) % 97;
    }
    return resto === 1;
  }

  /* Devuelve el mensaje de error, o nada si está bien. */
  F.iban = function (valor, opcional) {
    var v = F.ibanLimpio(valor);
    if (!v) return opcional ? null : 'Falta el número de cuenta.';
    if (!/^[A-Z]{2}/.test(v)) return 'El número de cuenta empieza por dos letras: en España, ES.';
    if (v[0] + v[1] === 'ES') {
      if (v.length < 24) {
        var faltan = 24 - v.length;
        return 'Al IBAN le falta' + (faltan === 1 ? '' : 'n') + ' ' + faltan +
               ' dígito' + (faltan === 1 ? '' : 's') + '. Son 24 en total.';
      }
      if (v.length > 24) return 'Ese IBAN tiene ' + (v.length - 24) + ' de más. Son 24 en total.';
    }
    if (!/^[A-Z]{2}[0-9A-Z]{13,32}$/.test(v)) return 'En el número de cuenta hay algún carácter que no debería estar.';
    if (!cuadraElNoventaySiete(v)) {
      return 'Ese número de cuenta no cuadra. Suele ser un número cambiado de sitio: míralo otra vez.';
    }
    return null;
  };

  /* De qué banco es, si lo sabemos. */
  F.bancoDe = function (valor) {
    var v = F.ibanLimpio(valor);
    if (v.slice(0, 2) !== 'ES' || v.length !== 24) return null;
    return BANCOS[v.slice(4, 8)] || null;
  };

  /* Engancha un campo de IBAN: lo escribe de cuatro en cuatro
     mientras se teclea, lo comprueba al salir y, si va bien, dice
     el banco debajo en verde. */
  F.engancharIban = function (campo, opcional) {
    if (!campo) return;
    var caja = campo.closest('.campo');
    var confirmado = caja && caja.querySelector('.confirmado');

    campo.addEventListener('input', function () {
      var cursorAlFinal = campo.selectionStart === campo.value.length;
      var bonito = F.ibanBonito(campo.value);
      if (bonito !== campo.value) {
        campo.value = bonito;
        if (cursorAlFinal) campo.setSelectionRange(bonito.length, bonito.length);
      }
      if (caja && caja.classList.contains('mal') && !F.iban(campo.value, opcional)) F.bien(campo);
      if (confirmado) confirmado.textContent = '';
    });

    campo.addEventListener('blur', function () {
      var fallo = F.iban(campo.value, opcional);
      if (fallo) {
        F.mal(campo, fallo);
        if (confirmado) confirmado.textContent = '';
        return;
      }
      F.bien(campo);
      if (!confirmado) return;
      var banco = F.bancoDe(campo.value);
      confirmado.textContent = banco ? 'Banco reconocido: ' + banco
                                     : (F.ibanLimpio(campo.value) ? 'El número de cuenta es correcto.' : '');
    });
  };


  /* ============================================================
     4 · LA FIRMA CON EL DEDO
     ------------------------------------------------------------
     Un recuadro en el que se dibuja con el dedo o con el ratón. Se
     guarda como una imagen.

     Dos cosas que parecen detalles y no lo son:
       · El lienzo se dibuja al doble de resolución, si no en un
         móvil la firma sale con los bordes de sierra y parece un
         garabato de mala calidad.
       · Mientras se firma no se puede desplazar la página con ese
         dedo (`touch-action: none` en el CSS). Sin eso, al firmar
         se va la pantalla hacia abajo y no se dibuja nada.
     ============================================================ */

  F.firma = function (lienzo) {
    if (!lienzo) return null;
    var ctx = lienzo.getContext('2d');
    var pintado = false;
    var dibujando = false;
    var ultimo = null;

    function ajustar() {
      var caja = lienzo.getBoundingClientRect();
      var escala = Math.min(window.devicePixelRatio || 1, 2);
      /* Si ya había firma, no se toca el tamaño: redimensionar
         borraría lo dibujado y quien está firmando no lo entendería. */
      if (pintado && lienzo.width) return;
      lienzo.width = Math.round(caja.width * escala);
      lienzo.height = Math.round(caja.height * escala);
      ctx.setTransform(escala, 0, 0, escala, 0, 0);
      ctx.lineWidth = 2.2;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.strokeStyle = '#2E4256';
    }

    function donde(e) {
      var caja = lienzo.getBoundingClientRect();
      var p = (e.touches && e.touches[0]) ? e.touches[0] : e;
      return { x: p.clientX - caja.left, y: p.clientY - caja.top };
    }

    function empezar(e) {
      e.preventDefault();
      ajustar();
      dibujando = true;
      ultimo = donde(e);
      /* Un punto, para que un toque corto también deje marca. */
      ctx.beginPath();
      ctx.arc(ultimo.x, ultimo.y, 1.1, 0, Math.PI * 2);
      ctx.fillStyle = '#2E4256';
      ctx.fill();
      pintado = true;
      lienzo.dispatchEvent(new CustomEvent('firmada'));
    }

    function seguir(e) {
      if (!dibujando) return;
      e.preventDefault();
      var p = donde(e);
      ctx.beginPath();
      ctx.moveTo(ultimo.x, ultimo.y);
      ctx.lineTo(p.x, p.y);
      ctx.stroke();
      ultimo = p;
      pintado = true;
    }

    function parar() { dibujando = false; }

    lienzo.addEventListener('pointerdown', empezar);
    lienzo.addEventListener('pointermove', seguir);
    window.addEventListener('pointerup', parar);
    lienzo.addEventListener('pointerleave', parar);

    window.addEventListener('resize', function () { if (!pintado) { lienzo.width = 0; ajustar(); } });
    ajustar();

    return {
      hayFirma: function () { return pintado; },
      borrar: function () {
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, lienzo.width, lienzo.height);
        pintado = false;
        lienzo.width = 0;
        ajustar();
      },
      comoImagen: function () { return pintado ? lienzo.toDataURL('image/png') : ''; }
    };
  };


  /* ============================================================
     5 · «GUARDAR Y SEGUIR LUEGO»
     ------------------------------------------------------------
     Se guarda EN EL PROPIO MÓVIL y en ningún otro sitio. Son datos
     de un menor a medio escribir: no tienen por qué estar en un
     servidor, ni hace falta decidir cuánto tiempo se conservan allí.

     Lo que sí caduca es lo del móvil: a los 30 días se borra solo al
     abrir la página. Un formulario a medias del curso pasado no le
     sirve a nadie.
     ============================================================ */

  var DIAS_QUE_DURA = 30;

  F.guardar = function (clave, datos) {
    try {
      localStorage.setItem('apolana-form-' + clave, JSON.stringify({
        cuando: Date.now(), datos: datos
      }));
      return true;
    } catch (e) { return false; }   /* navegación privada: no pasa nada */
  };

  F.recuperar = function (clave) {
    try {
      var crudo = localStorage.getItem('apolana-form-' + clave);
      if (!crudo) return null;
      var g = JSON.parse(crudo);
      if (!g || !g.cuando || Date.now() - g.cuando > DIAS_QUE_DURA * 864e5) {
        F.olvidar(clave);
        return null;
      }
      return g.datos;
    } catch (e) { return null; }
  };

  F.olvidar = function (clave) {
    try { localStorage.removeItem('apolana-form-' + clave); } catch (e) {}
  };


  /* ============================================================
     6 · HABLAR CON LA BASE
     ------------------------------------------------------------
     Todo pasa por las funciones `enviar_*`, que son las únicas que
     tienen permiso para guardar. Desde aquí NO se puede escribir
     directamente en ninguna tabla ni leer ninguna: está cerrado en
     la base, no confiando en que esta página se porte bien.
     ============================================================ */

  F.llamar = function (funcion, argumentos) {
    var db = window.APOLANA_DB;
    if (!db) {
      return Promise.resolve({ ok: false, motivo: 'sin-conexion',
        mensaje: 'Ahora mismo no se puede enviar. Vuelve a intentarlo en un rato o llámanos.' });
    }
    return db.rpc(funcion, argumentos).then(function (r) {
      if (r.error) {
        console.warn('[Apolana] ' + funcion + ':', r.error.message);
        return { ok: false, motivo: 'error',
          mensaje: 'No se ha podido enviar. Vuelve a intentarlo en un rato o llámanos.' };
      }
      return r.data || { ok: false, motivo: 'vacio', mensaje: 'No se ha podido enviar.' };
    }).catch(function (e) {
      console.warn('[Apolana] ' + funcion + ':', e);
      return { ok: false, motivo: 'red',
        mensaje: 'Parece que se ha ido la conexión. Comprueba la cobertura y vuelve a darle.' };
    });
  };

  /* Cuánto lleva la persona en la página. Se manda con el formulario
     porque nadie apunta a un hijo en seis segundos: eso es un
     programa, y la base lo descarta. */
  var ABIERTO_DESDE = Date.now();
  F.segundosDentro = function () { return Math.round((Date.now() - ABIERTO_DESDE) / 1000); };


  /* ============================================================
     7 · COSAS SUELTAS QUE SE REPITEN
     ============================================================ */

  /* Los días del turno, dichos como los dice el club. Ya existe en
     supabase.js para toda la web; aquí solo se usa. */
  F.dias = function (turno) {
    return (window.APOLANA_TURNO ? window.APOLANA_TURNO(turno) : '') || '';
  };

  /* «3 de agosto de 2026», que es como se escribe una fecha en un
     documento que se firma. */
  var MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
               'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  F.fechaLarga = function (fecha) {
    var d = fecha || new Date();
    return d.getDate() + ' de ' + MESES[d.getMonth()] + ' de ' + d.getFullYear();
  };

  /* Sacar el nombre de pila para poder decir «¿Podemos publicar
     fotos de Lucía?» en vez de «de Lucía Segura Ortiz», que suena a
     carta del banco. */
  F.nombreDePila = function (completo) {
    var t = String(completo || '').trim().split(/\s+/);
    return t[0] || '';
  };

  /* Ponerle mayúscula al principio sin tocar el resto. */
  F.escapar = function (t) {
    return String(t == null ? '' : t)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  };

})();
