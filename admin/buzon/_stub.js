/* Andamio de PRUEBA para ver el buzón en el navegador sin sesión ni red.
   Se borra al terminar: no forma parte de la pantalla. */
(function () {
  function dias(n) { return new Date(Date.now() - n * 86400000).toISOString(); }

  var LARGO = 'Buenos días. Tengo dos hijas de 8 y 11 años y me gustaría saber los horarios de la escuela ' +
    'para septiembre, porque el año pasado la mayor entrenaba martes y jueves y a la pequeña le tocaba ' +
    'a la misma hora en otra pista y no había manera de llevarlas a las dos.\n\n' +
    'Somos una familia de dos trabajando a turnos, así que necesito saber con bastante antelación qué ' +
    'días y a qué hora entrenaría cada una, si es en la pista de siempre o en otra, y si hay alguna ' +
    'posibilidad de que coincidan el mismo día aunque sea en grupos distintos. También querría saber ' +
    'cuánto cuesta al mes con dos hermanas, si hay algún descuento por familia, y qué material hay que ' +
    'comprar. Y si podéis decirme cuándo abrís las inscripciones, para no quedarnos fuera como el año ' +
    'pasado. Muchísimas gracias por la paciencia.';

  var DESTINOS = [
    { id: 'd1', clave: 'junta', nombre: 'La junta directiva', descripcion: 'Lo que decide el club: convenios, alquiler de instalaciones, patrocinios, permisos y quejas formales.', perfil_id: 'p1', activo: true, orden: 1 },
    { id: 'd2', clave: 'cuotas', nombre: 'Cuotas y recibos · Isabel', descripcion: 'Todo lo de dinero: recibos devueltos, cambios de cuenta, importes y devoluciones. Falta asignarle la cuenta del panel cuando la tenga.', perfil_id: null, activo: true, orden: 2 },
    { id: 'd3', clave: 'escuela', nombre: 'Coordinación de la escuela', descripcion: 'Grupos, horarios, categorías y pruebas de los peques.', perfil_id: null, activo: true, orden: 3 }
  ];

  var EQUIPO = [
    { id: 'p1', nombre: 'Adrian', apellidos: 'Onandía', rol: 'admin', email: 'escuelaapolana@gmail.com', activo: true },
    { id: 'p2', nombre: 'Cristina', apellidos: 'Herrero Lozano', rol: 'coordinador', email: 'cristina@demo.test', activo: true }
  ];

  var MENSAJES = [
    { id: 'm1', nombre: 'Nieves Aparisi', medio: 'nieves.aparisi@demo.apolana.test',
      asunto: 'Grupo de running para empezar de cero', mensaje: 'Hola, no he corrido nunca y me da un poco de vergüenza apuntarme. ¿Tenéis algo para gente que sale de cero?',
      atendido: false, created_at: dias(2),
      respondido_por: null, respondido_at: null, respondido_por_nombre: null, respondido_por_pila: null,
      derivado_destino: null, derivado_clave: null, derivado_destino_nombre: null,
      derivado_a: null, derivado_a_nombre: null, derivado_por: null, derivado_por_nombre: null,
      derivado_at: null, derivado_nota: null },
    { id: 'm2', nombre: 'Tomás Requena', medio: '666 111 222',
      asunto: 'Alquiler de la pista para un colegio', mensaje: 'Somos el AMPA del colegio San Blas y querríamos organizar una jornada de atletismo en junio. ¿Se puede alquilar la pista un sábado por la mañana?',
      atendido: false, created_at: dias(3),
      respondido_por: null, respondido_at: null, respondido_por_nombre: null, respondido_por_pila: null,
      derivado_destino: 'd1', derivado_clave: 'junta', derivado_destino_nombre: 'La junta directiva',
      derivado_a: 'p1', derivado_a_nombre: 'Adrian Onandía', derivado_por: 'p1', derivado_por_nombre: 'Adrian Onandía',
      derivado_at: dias(1), derivado_nota: 'Es del colegio San Blas, lo tiene que ver la junta.' },
    { id: 'm3', nombre: 'Marisa Bonet', medio: 'marisa.bonet@demo.apolana.test',
      asunto: 'Horarios de la escuela en septiembre y cuota de dos hermanas', mensaje: LARGO,
      atendido: false, created_at: dias(4),
      respondido_por: null, respondido_at: null, respondido_por_nombre: null, respondido_por_pila: null,
      derivado_destino: 'd2', derivado_clave: 'cuotas', derivado_destino_nombre: 'Cuotas y recibos · Isabel',
      derivado_a: null, derivado_a_nombre: null, derivado_por: 'p1', derivado_por_nombre: 'Adrian Onandía',
      derivado_at: dias(1), derivado_nota: null },
    { id: 'm4', nombre: 'Paco Server', medio: 'paco.server@demo.apolana.test',
      asunto: 'Camiseta del club talla XL', mensaje: 'Buenas, quería una camiseta del club en talla XL. ¿Quedan o hay que esperar al siguiente pedido?',
      atendido: true, created_at: dias(15),
      respondido_por: 'p1', respondido_at: dias(14), respondido_por_nombre: 'Adrian Onandía', respondido_por_pila: 'Adrian',
      derivado_destino: null, derivado_clave: null, derivado_destino_nombre: null,
      derivado_a: null, derivado_a_nombre: null, derivado_por: null, derivado_por_nombre: null,
      derivado_at: null, derivado_nota: null },
    { id: 'm5', nombre: 'Jorge Castell', medio: 'jorge@demo.test',
      asunto: 'Se me ha devuelto el recibo de julio', mensaje: 'Me ha llegado un aviso del banco. Cambié de cuenta en junio y se me olvidó decíroslo.',
      atendido: true, created_at: dias(22),
      respondido_por: 'p2', respondido_at: dias(21), respondido_por_nombre: 'Cristina Herrero Lozano', respondido_por_pila: 'Cristina',
      derivado_destino: 'd2', derivado_clave: 'cuotas', derivado_destino_nombre: 'Cuotas y recibos · Isabel',
      derivado_a: null, derivado_a_nombre: null, derivado_por: 'p1', derivado_por_nombre: 'Adrian Onandía',
      derivado_at: dias(21), derivado_nota: 'Para Isabel: cambio de cuenta.' }
  ];

  var PLANTILLAS = [
    { id: 't1', nombre: 'Buzón · recibo devuelto', asunto: 'El recibo de {{nombre}}',
      cuerpo: 'Hola:\n\nTe escribimos porque el banco nos ha devuelto el recibo de {{nombre}} de {{importe}}, el de {{mes}}.\n\nAntes de nada, tranquilidad: no hay ninguna penalización.\n\nUn saludo,\nClub Atletismo Apol-Ana',
      categoria: 'buzon', variables: ['nombre', 'importe', 'mes'],
      buzon_palabras: ['recibo', 'devuelto', 'devolucion', 'impago', 'banco', 'domiciliacion', 'cargo'], activa: true },
    { id: 't2', nombre: 'Buzón · información de grupos y horarios', asunto: 'Los grupos del club',
      cuerpo: 'Hola:\n\nEl grupo que te iría bien es {{grupo}}, que entrena {{horario}} en {{lugar}}. Lo lleva {{entrenador}}.\n\nUn saludo,\nClub Atletismo Apol-Ana',
      categoria: 'buzon', variables: ['grupo', 'horario', 'lugar', 'entrenador'],
      buzon_palabras: ['grupo', 'grupos', 'horario', 'horarios', 'apuntar', 'empezar', 'probar', 'escuela', 'correr'], activa: true },
    { id: 't3', nombre: 'Buzón · duda sobre cuotas', asunto: 'Sobre la cuota de {{nombre}}',
      cuerpo: 'Hola:\n\nLa de {{nombre}} es de {{importe}} y se pasa por domiciliación {{cuando_se_pasa}}.\n\nUn saludo,\nClub Atletismo Apol-Ana',
      categoria: 'buzon', variables: ['nombre', 'importe', 'cuando_se_pasa'],
      buzon_palabras: ['cuota', 'cuotas', 'precio', 'pago', 'tarifa', 'cuanto cuesta'], activa: true },
    { id: 't4', nombre: 'Bienvenida al club', asunto: 'Bienvenido al club, {{nombre}}',
      cuerpo: 'Hola:\n\nYa está todo listo.\n\nUn saludo,\nClub Atletismo Apol-Ana',
      categoria: 'altas', variables: ['nombre'], buzon_palabras: [], activa: true }
  ];

  var TABLAS = { buzon_bandeja: MENSAJES, mensajes: MENSAJES, plantillas_email: PLANTILLAS,
                 buzon_destinos: DESTINOS, perfiles: EQUIPO };

  function Consulta(tabla) {
    this.t = tabla; this.filtros = []; this.op = 'select'; this.datos = null;
  }
  Consulta.prototype.select = function () { return this; };
  Consulta.prototype.order  = function () { return this; };
  Consulta.prototype.eq = function (c, v) { this.filtros.push([c, v]); return this; };
  Consulta.prototype.in = function (c, v) { this.filtros.push([c, v]); return this; };
  Consulta.prototype.update = function (d) { this.op = 'update'; this.datos = d; return this; };
  Consulta.prototype.then = function (res) {
    var fuente = TABLAS[this.t] || [];
    var self = this;
    if (this.op === 'update') {
      fuente.forEach(function (f) {
        var vale = self.filtros.every(function (p) { return f[p[0]] === p[1]; });
        if (!vale) return;
        Object.keys(self.datos).forEach(function (k) { f[k] = self.datos[k]; });
        if ('atendido' in self.datos) {
          f.respondido_por_nombre = self.datos.atendido ? 'Adrian Onandía' : null;
          f.respondido_por_pila   = self.datos.atendido ? 'Adrian' : null;
          f.respondido_at         = self.datos.atendido ? new Date().toISOString() : null;
        }
        if ('derivado_a' in self.datos || 'derivado_destino' in self.datos) {
          var d = DESTINOS.filter(function (x) { return x.id === f.derivado_destino; })[0];
          f.derivado_destino_nombre = d ? d.nombre : null;
          var p = EQUIPO.filter(function (x) { return x.id === f.derivado_a; })[0];
          f.derivado_a_nombre = p ? (p.nombre + ' ' + p.apellidos) : null;
          var hay = f.derivado_a || f.derivado_destino;
          f.derivado_por_nombre = hay ? 'Adrian Onandía' : null;
          f.derivado_at = hay ? new Date().toISOString() : null;
        }
      });
      return Promise.resolve({ data: null, error: null }).then(res);
    }
    var filas = fuente.filter(function (f) {
      return self.filtros.every(function (p) {
        return Array.isArray(p[1]) ? p[1].indexOf(f[p[0]]) !== -1 : f[p[0]] === p[1];
      });
    });
    return Promise.resolve({ data: JSON.parse(JSON.stringify(filas)), error: null }).then(res);
  };

  var sb = {
    from: function (t) { return new Consulta(t); },
    auth: { getUser: function () { return Promise.resolve({ data: { user: { email: 'escuelaapolana@gmail.com' } } }); } }
  };

  window.APOLANA_ADMIN = {
    listo: function (cb) {
      document.addEventListener('DOMContentLoaded', function () {
        var barra = document.createElement('div');
        barra.className = 'adm-top';
        barra.style.cssText = 'background:#2E4256;color:#fff;min-height:60px;display:flex;align-items:center;padding:9px 24px;font-family:"Barlow Condensed",sans-serif;font-size:20px;text-transform:uppercase';
        barra.textContent = 'Panel Apolana · PRUEBA';
        document.body.insertBefore(barra, document.body.firstChild);
        cb(sb);
      });
    }
  };
})();
