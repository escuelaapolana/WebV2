/* ============================================================
   TESORERÍA Y CONTABILIDAD · Club Atletismo Apolana
   ------------------------------------------------------------
   El reparto del dinero, en el navegador. La base ya sabe quién
   puede qué (migraciones/071_tesoreria.sql); esto solo enseña el
   botón que toca y lleva el aviso de un lado al otro.

   LA REGLA DE FONDO
     Quien decide un importe y quien lo ejecuta no son la misma
     persona, y el panel lo refleja con un aviso entre los dos,
     no con un permiso que bloquea.

       Tesorería (Adrián, Andrés)  ve todo · fija cuotas · aprueba
       Contabilidad (Isabel)       socios y adultos · gira remesas
       Junta                       sin acceso a dinero

   LOS AVISOS VAN POR TRES VÍAS
     1 · la bandeja del inicio del panel, con la acción en la fila
     2 · el aviso al móvil (función «aviso-enviar», categoría pagos)
     3 · el correo — ⚠️ TODAVÍA NO EXISTE. El enganche está puesto
         y marcado con «PENDIENTE · CORREO» más abajo, pero el club
         no manda correos automáticos. Ver docs/tesoreria.md.

   Cómo se usa desde una página del panel:
     var D = window.APOLANA_DINERO;
     var yo = await D.quienSoy();        // {papel, fija_cuotas, …}
     if (yo.fija_cuotas) D.fijarCuota(atleta);
     else                D.pedirCambio(atleta);

   Necesita: db.js (window.APOLANA_DB) y admin-tabbar.js
   (apoToast / apoConfirm). Si no están, no rompe: avisa por
   consola y las funciones devuelven null.
   ============================================================ */
(function () {
  'use strict';

  function sb() { return window.APOLANA_DB; }
  function esc(s) {
    var d = document.createElement('div');
    d.textContent = (s == null ? '' : String(s));
    return d.innerHTML;
  }
  function aviso(msg, tipo, opts) {
    if (typeof window.apoToast === 'function') return window.apoToast(msg, tipo, opts);
    if (tipo === 'error') console.error(msg); else console.log(msg);
  }
  function eur(n) {
    if (n === null || n === undefined || n === '') return '—';
    return Number(n).toLocaleString('es-ES', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €';
  }
  function nombreDe(a) {
    return (String(a && a.nombre || '') + ' ' + String(a && a.apellidos || '')).trim();
  }

  /* ------------------------------------------------------------
     Estilo propio. Va aquí y no en apolana.css porque es de estas
     dos ventanas y de nada más. Respeta el kit: cuerpo 15 px,
     etiquetas 13 px en minúscula y sin espaciado, radios 14/10/999,
     44 px de alto y un solo botón azul por ventana.
     ------------------------------------------------------------ */
  var CSS =
    '.dnr-fondo{position:fixed;inset:0;z-index:9998;background:rgba(46,66,86,.45);' +
      'display:flex;align-items:flex-start;justify-content:center;padding:clamp(14px,5vh,54px) 14px;overflow:auto}' +
    '.dnr-caja{background:#fff;border:1px solid var(--linea,#EAE3D5);border-radius:14px;' +
      'box-shadow:0 30px 70px -25px rgba(46,66,86,.55);width:min(640px,100%);padding:22px 22px 18px;box-sizing:border-box}' +
    '.dnr-caja h3{font-family:var(--fuente-titulo,"Barlow Condensed",sans-serif);text-transform:uppercase;' +
      'font-size:23px;line-height:1.05;color:var(--navy,#2E4256);margin:0 0 6px}' +
    '.dnr-caja .dnr-sub{font-size:15px;line-height:1.5;color:var(--texto,#4A4437);margin:0 0 16px}' +
    '.dnr-et{display:block;font-size:13px;font-weight:400;text-transform:none;letter-spacing:0;' +
      'color:var(--texto-suave,#6B6558);margin:12px 0 5px}' +
    '.dnr-caja input[type=text],.dnr-caja input[type=number],.dnr-caja textarea{width:100%;box-sizing:border-box;' +
      'padding:11px 13px;border:1px solid var(--linea-borde,#E0D8C8);border-radius:10px;' +
      'font-family:var(--fuente-texto,inherit);font-size:15px;color:var(--navy,#2E4256);background:#fff}' +
    '.dnr-caja textarea{min-height:82px;resize:vertical}' +
    '.dnr-caja input:focus,.dnr-caja textarea:focus{outline:2px solid var(--azul-filete, #3B85C0);border-color:var(--azul-filete, #3B85C0)}' +
    /* El dato que se compara va en monoespaciada: es un importe */
    '.dnr-mono{font-family:var(--fuente-mono,ui-monospace,SFMono-Regular,Menlo,monospace);font-variant-numeric:tabular-nums}' +
    /* Nota de contexto: fondo crema, sin radio de tarjeta grande */
    '.dnr-nota{background:var(--crema-media,#F5F0E4);border-radius:10px;padding:12px 14px;font-size:14px;' +
      'line-height:1.5;color:var(--texto,#4A4437);margin:14px 0 0}' +
    '.dnr-pie{display:flex;justify-content:flex-end;gap:10px;flex-wrap:wrap;margin-top:18px;' +
      'padding-top:14px;border-top:1px solid var(--crema-media,#F5F0E4)}' +
    '.dnr-pie .dnr-cuenta{margin-right:auto;align-self:center;font-size:14px;color:var(--texto-suave,#6B6558)}' +
    '.dnr-b{font-family:var(--fuente-texto,inherit);font-size:15px;font-weight:600;border-radius:999px;' +
      'padding:11px 22px;min-height:44px;cursor:pointer;border:1px solid var(--linea-borde,#E0D8C8);' +
      'background:transparent;color:var(--texto,#4A4437)}' +
    '.dnr-b:hover{background:var(--crema-media,#F5F0E4)}' +
    '.dnr-b--azul{background:var(--azul, #2F6FA8);color:#fff;border-color:transparent}' +
    '.dnr-b--azul:hover{background:var(--azul-hover, #1E4E78)}' +
    '.dnr-b[disabled]{opacity:.5;cursor:default}' +
    /* Lista de fichas por etiquetar: un contenedor con separadores, no diez tarjetas */
    '.dnr-lista{border:1px solid var(--linea,#EAE3D5);border-radius:10px;max-height:46vh;overflow:auto;margin-top:10px}' +
    '.dnr-fila{display:flex;align-items:center;gap:12px;min-height:48px;padding:9px 12px;' +
      'border-bottom:1px solid var(--crema-media,#F5F0E4)}' +
    '.dnr-fila:last-child{border-bottom:0}' +
    '.dnr-fila .dnr-quien{flex:1;min-width:0}' +
    '.dnr-fila .dnr-quien b{display:block;font-weight:600;font-size:15px;color:var(--navy,#2E4256);' +
      'white-space:nowrap;overflow:hidden;text-overflow:ellipsis}' +
    '.dnr-fila .dnr-quien span{display:block;font-size:13px;color:var(--texto-suave,#6B6558)}' +
    '.dnr-ops{display:flex;gap:6px;flex:0 0 auto}' +
    '.dnr-op{border:1px solid var(--linea-borde,#D4CBB9);background:transparent;border-radius:999px;' +
      'padding:8px 14px;min-height:44px;font-size:14px;font-family:var(--fuente-texto,inherit);' +
      'color:var(--texto,#4A4437);cursor:pointer}' +
    '.dnr-op[aria-pressed="true"]{background:var(--navy,#2E4256);border-color:var(--navy,#2E4256);color:#fff;font-weight:600}' +
    '.dnr-vacio{padding:26px 16px;text-align:center;font-size:15px;color:var(--texto-suave,#6B6558)}' +
    '@media(max-width:520px){.dnr-fila{flex-wrap:wrap}.dnr-ops{width:100%}.dnr-op{flex:1}' +
      '.dnr-pie{flex-direction:column-reverse}.dnr-pie .dnr-b{width:100%}' +
      '.dnr-pie .dnr-cuenta{margin:6px 0 0;text-align:center}}';

  var puesto = false;
  function ponerEstilo() {
    if (puesto) return;
    puesto = true;
    var s = document.createElement('style');
    s.textContent = CSS;
    document.head.appendChild(s);
  }

  /* ------------------------------------------------------------
     Una ventana encima, con escape, foco y clic fuera.
     ------------------------------------------------------------ */
  function ventana(html) {
    ponerEstilo();
    var fondo = document.createElement('div');
    fondo.className = 'dnr-fondo';
    var caja = document.createElement('div');
    caja.className = 'dnr-caja';
    caja.setAttribute('role', 'dialog');
    caja.setAttribute('aria-modal', 'true');
    caja.innerHTML = html;
    fondo.appendChild(caja);
    document.body.appendChild(fondo);

    var previo = document.activeElement;
    function cerrar() {
      document.removeEventListener('keydown', tecla, true);
      if (fondo.parentNode) fondo.parentNode.removeChild(fondo);
      if (previo && previo.focus) { try { previo.focus(); } catch (e) {} }
    }
    function tecla(e) { if (e.key === 'Escape') { e.preventDefault(); cerrar(); } }
    document.addEventListener('keydown', tecla, true);
    fondo.addEventListener('click', function (e) { if (e.target === fondo) cerrar(); });
    return { fondo: fondo, caja: caja, cerrar: cerrar, $: function (s) { return caja.querySelector(s); } };
  }

  /* ============================================================
     QUIÉN SOY PARA EL DINERO
     Una sola llamada por carga de página; el resto se sirve de
     la copia. Devuelve siempre un objeto, nunca null, para que
     ninguna pantalla tenga que comprobar si falló.
     ============================================================ */
  var YO = null;
  var NADIE = { papel: null, ve_dinero: false, fija_cuotas: false,
                gira_remesas: false, es_admin: false, solo_lo_mio: false, seccion: null };

  async function quienSoy() {
    if (YO) return YO;
    if (!sb() || !sb().rpc) { YO = NADIE; return YO; }
    try {
      var r = await sb().rpc('dinero_quien_soy');
      YO = (r.error || !r.data) ? NADIE : r.data;
    } catch (e) { YO = NADIE; }
    return YO;
  }
  function olvidarQuienSoy() { YO = null; }

  /* ============================================================
     LA BANDEJA · los avisos de dinero que esperan a alguien
     ============================================================ */
  async function bandeja() {
    if (!sb() || !sb().rpc) return [];
    var r = await sb().rpc('dinero_bandeja');
    return (r.error || !r.data) ? [] : r.data;
  }

  /* Cómo se lee cada aviso en la fila de la bandeja. */
  function textoDe(f) {
    var quien = f.atleta || 'una ficha sin nombre';
    if (f.tipo === 'cambio_cuota') {
      return { texto: 'Contabilidad pide cambiar la cuota de ' + quien,
               sub: eur(f.importe_actual) + ' → ' + eur(f.importe_propuesto) +
                    (f.motivo ? ' · ' + f.motivo : '') };
    }
    if (f.tipo === 'cuota_fijada') {
      return { texto: 'Tesorería ha cambiado la cuota de ' + quien,
               sub: eur(f.importe_actual) + ' → ' + eur(f.importe_propuesto) +
                    ' · tenlo en cuenta en la remesa' };
    }
    return { texto: 'Excepción pedida para ' + quien, sub: f.motivo || '' };
  }

  /* Convierte las filas de la base en las alertas de la bandeja del
     inicio, con la forma que ya usa `admin/index.html`. */
  async function alertas() {
    var filas = await bandeja();
    return filas.map(function (f) {
      var t = textoDe(f);
      var esParaTesoreria = (f.para === 'tesoreria');
      return {
        tipo: 'CUOTA',
        papel: 'dinero',
        seccion: f.seccion,                    /* 'escuela' | 'club' | null */
        texto: t.texto,
        sub: t.sub + (f.seccion ? '' : ' · sin etiquetar'),
        accion: esParaTesoreria ? 'Resolver' : 'Enterado',
        alPulsar: function () { return abrirAviso(f); }
      };
    });
  }

  /* ------------------------------------------------------------
     Resolver un aviso: tesorería aprueba o rechaza; contabilidad
     solo da por visto. Al aprobar, la cuota se cambia de verdad y
     el aviso vuelve al otro lado.
     ------------------------------------------------------------ */
  async function abrirAviso(f) {
    var yo = await quienSoy();
    var t = textoDe(f);
    var esParaTesoreria = (f.para === 'tesoreria');

    if (!esParaTesoreria) {
      var ok = await window.apoConfirm({
        titulo: 'Cambio de cuota',
        texto: t.texto + '\n' + t.sub + '\n\nAl darlo por visto sale de tu bandeja.',
        confirmar: 'Enterado'
      });
      if (!ok) return false;
      var r0 = await sb().rpc('dinero_resolver', { p_id: f.id, p_estado: 'visto' });
      if (r0.error) { aviso('No se ha podido: ' + r0.error.message, 'error'); return false; }
      aviso('Fuera de tu bandeja', 'ok');
      return true;
    }

    if (!yo.fija_cuotas) {
      aviso('Aprobar un cambio de cuota es cosa de tesorería.', 'error');
      return false;
    }

    var v = ventana(
      '<h3>Cambio de cuota</h3>' +
      '<p class="dnr-sub">' + esc(t.texto) + '</p>' +
      '<div class="dnr-nota">' +
        '<b>Ahora:</b> <span class="dnr-mono">' + esc(eur(f.importe_actual)) + '</span><br>' +
        '<b>Piden:</b> <span class="dnr-mono">' + esc(eur(f.importe_propuesto)) + '</span>' +
        (f.motivo ? '<br><b>Motivo:</b> ' + esc(f.motivo) : '') +
      '</div>' +
      '<label class="dnr-et" for="dnr-resp">Una línea para contabilidad (se ve en su bandeja)</label>' +
      '<textarea id="dnr-resp" placeholder="Vale, desde el recibo de octubre."></textarea>' +
      '<div class="dnr-pie">' +
        '<button type="button" class="dnr-b" data-cerrar>Cancelar</button>' +
        '<button type="button" class="dnr-b" data-no>Rechazar</button>' +
        '<button type="button" class="dnr-b dnr-b--azul" data-si>Aprobar el cambio</button>' +
      '</div>'
    );
    v.$('[data-cerrar]').addEventListener('click', v.cerrar);
    v.$('#dnr-resp').focus();

    return new Promise(function (resolve) {
      async function mandar(estado) {
        var bs = v.caja.querySelectorAll('.dnr-b');
        Array.prototype.forEach.call(bs, function (b) { b.disabled = true; });
        var r = await sb().rpc('dinero_resolver', {
          p_id: f.id, p_estado: estado, p_respuesta: v.$('#dnr-resp').value
        });
        if (r.error) {
          Array.prototype.forEach.call(bs, function (b) { b.disabled = false; });
          aviso('No se ha podido: ' + r.error.message, 'error');
          return;
        }
        v.cerrar();
        if (estado === 'aprobado') {
          aviso('Cuota cambiada. Contabilidad ya lo tiene.', 'ok');
          avisarMovil('contabilidad', {
            titulo: 'Cambio de cuota aprobado',
            cuerpo: (f.atleta || 'Una ficha') + ': ' + eur(f.importe_actual) + ' → ' + eur(f.importe_propuesto) +
                    '. Tenlo en cuenta en la remesa.',
            enlace: 'admin/cobros/',
            avisoId: (typeof r.data === 'string' ? r.data : null)
          });
        } else {
          aviso('Rechazado. Contabilidad lo verá en su bandeja.', 'ok');
        }
        resolve(true);
      }
      v.$('[data-si]').addEventListener('click', function () { mandar('aprobado'); });
      v.$('[data-no]').addEventListener('click', function () { mandar('rechazado'); });
      v.fondo.addEventListener('click', function (e) { if (e.target === v.fondo) resolve(false); });
    });
  }

  /* ============================================================
     LA CUOTA DE UNA FICHA
     Dos ventanas para la misma cosa, según quién entra:
       · tesorería  → «Cambiar la cuota», el campo es editable
       · el resto   → «Pedir cambio a tesorería», genera el aviso
     La que hay que abrir la dice `quienSoy().fija_cuotas`; para no
     tener que preguntarlo dos veces está `cuota()`, que elige sola.
     ============================================================ */
  async function cuota(atleta) {
    var yo = await quienSoy();
    if (!yo.ve_dinero) { aviso('Esto es de tesorería y contabilidad.', 'error'); return false; }
    return yo.fija_cuotas ? fijarCuota(atleta) : pedirCambio(atleta);
  }

  function ventanaCuota(atleta, opts) {
    var quien = nombreDe(atleta) || 'esta ficha';
    var actual = (atleta && atleta.cuota_mensual !== undefined) ? atleta.cuota_mensual : null;
    var v = ventana(
      '<h3>' + esc(opts.titulo) + '</h3>' +
      '<p class="dnr-sub">' + esc(quien) + ' · ahora paga <span class="dnr-mono">' + esc(eur(actual)) + '</span> al mes</p>' +
      '<label class="dnr-et" for="dnr-imp">' + esc(opts.etImporte) + '</label>' +
      '<input type="number" id="dnr-imp" step="0.01" min="0" inputmode="decimal" placeholder="40,00">' +
      '<label class="dnr-et" for="dnr-mot">' + esc(opts.etMotivo) + '</label>' +
      '<textarea id="dnr-mot" placeholder="' + esc(opts.pistaMotivo) + '"></textarea>' +
      '<div class="dnr-nota">' + opts.nota + '</div>' +
      '<div class="dnr-pie">' +
        '<button type="button" class="dnr-b" data-cerrar>Cancelar</button>' +
        '<button type="button" class="dnr-b dnr-b--azul" data-ok>' + esc(opts.boton) + '</button>' +
      '</div>'
    );
    v.$('[data-cerrar]').addEventListener('click', v.cerrar);
    if (actual !== null && actual !== undefined) v.$('#dnr-imp').value = actual;
    v.$('#dnr-imp').focus();
    return v;
  }

  /* Tesorería: el campo es editable y el cambio se aplica. */
  async function fijarCuota(atleta) {
    var yo = await quienSoy();
    if (!yo.fija_cuotas) return pedirCambio(atleta);

    var v = ventanaCuota(atleta, {
      titulo: 'Cambiar la cuota',
      etImporte: 'cuota al mes, en euros',
      etMotivo: 'por qué cambia (lo verá contabilidad)',
      pistaMotivo: 'Hermano de la escuela, 10 % menos.',
      boton: 'Guardar la cuota',
      nota: 'Al guardarla le llega un aviso a contabilidad para que lo tenga en cuenta en la remesa. ' +
            'La cuota la fija tesorería; la remesa la gira contabilidad.'
    });

    return new Promise(function (resolve) {
      v.$('[data-ok]').addEventListener('click', async function () {
        var b = v.$('[data-ok]');
        var imp = v.$('#dnr-imp').value === '' ? null : Number(v.$('#dnr-imp').value);
        if (imp !== null && (isNaN(imp) || imp < 0)) { aviso('Ese importe no vale.', 'error'); return; }
        b.disabled = true;
        var r = await sb().rpc('dinero_fijar_cuota', {
          p_atleta: atleta.id, p_importe: imp, p_nota: v.$('#dnr-mot').value
        });
        if (r.error) { b.disabled = false; aviso('No se ha podido: ' + r.error.message, 'error'); return; }
        v.cerrar();
        aviso('Cuota guardada. Contabilidad ya lo tiene.', 'ok');
        avisarMovil('contabilidad', {
          titulo: 'Cambio de cuota',
          cuerpo: (nombreDe(atleta) || 'Una ficha') + ' pasa a ' + eur(imp) + ' al mes.',
          enlace: 'admin/cobros/',
          avisoId: (typeof r.data === 'string' ? r.data : null)
        });
        resolve(true);
      });
      v.fondo.addEventListener('click', function (e) { if (e.target === v.fondo) resolve(false); });
    });
  }

  /* Contabilidad: el campo se ve, pero el cambio se pide. */
  async function pedirCambio(atleta) {
    var v = ventanaCuota(atleta, {
      titulo: 'Pedir cambio a tesorería',
      etImporte: 'cuota que debería tener, en euros',
      etMotivo: 'por qué (lo leerá tesorería)',
      pistaMotivo: 'Se ha dado de baja de un día de entreno.',
      boton: 'Pedir el cambio',
      nota: 'La cuota la fija tesorería. Esto no la cambia: manda un aviso a Adrián y a Andrés, ' +
            'y en cuanto uno lo apruebe te vuelve a ti.'
    });

    return new Promise(function (resolve) {
      v.$('[data-ok]').addEventListener('click', async function () {
        var b = v.$('[data-ok]');
        var imp = v.$('#dnr-imp').value === '' ? null : Number(v.$('#dnr-imp').value);
        if (imp === null || isNaN(imp) || imp < 0) { aviso('Escribe el importe que debería tener.', 'error'); return; }
        b.disabled = true;
        var r = await sb().rpc('dinero_pedir_cambio_cuota', {
          p_atleta: atleta.id, p_importe: imp, p_motivo: v.$('#dnr-mot').value
        });
        if (r.error) { b.disabled = false; aviso('No se ha podido: ' + r.error.message, 'error'); return; }
        v.cerrar();
        aviso('Pedido. Tesorería lo tiene en su bandeja.', 'ok');
        avisarMovil('tesoreria', {
          titulo: 'Cambio de cuota por aprobar',
          cuerpo: 'Contabilidad pide cambiar la cuota de ' + (nombreDe(atleta) || 'una ficha') +
                  ' a ' + eur(imp) + '.',
          enlace: 'admin/',
          avisoId: (typeof r.data === 'string' ? r.data : null)
        });
        resolve(true);
      });
      v.fondo.addEventListener('click', function (e) { if (e.target === v.fondo) resolve(false); });
    });
  }

  /* ============================================================
     VÍA 2 · EL AVISO AL MÓVIL
     Va por la función `aviso-enviar`, categoría «pagos», una
     llamada por persona. La lista de destinatarios la calcula la
     base (`dinero_destinatarios`): desde aquí nunca se ve un
     correo ni un teléfono, solo el identificador del perfil.

     Si falla, NO se le dice nada a quien está delante: el aviso
     ya está en la bandeja del otro, que es la vía que manda. Un
     error de push no puede parecer que el cambio no se guardó.
     ============================================================ */
  async function avisarMovil(para, o) {
    try {
      var d = await sb().rpc('dinero_destinatarios', { p_para: para });
      if (d.error || !d.data || !d.data.length) return 0;

      var base = (function () {
        var b = window.APOLANA_BASE || '../';
        var u = new URL(b, location.href);
        return u.href;
      })();

      var n = 0;
      for (var i = 0; i < d.data.length; i++) {
        var r = await sb().functions.invoke('aviso-enviar', {
          body: {
            titulo: o.titulo,
            cuerpo: o.cuerpo,
            url: base + (o.enlace || 'admin/'),
            publico: 'persona',
            categoria: 'pagos',
            perfil_id: d.data[i].perfil_id
          }
        });
        if (!r.error) n++;
      }
      if (n && o.avisoId) await sb().rpc('dinero_marcar_movil', { p_id: o.avisoId });

      /* ============================================================
         PENDIENTE · CORREO — LA TERCERA VÍA, QUE NO EXISTE
         ------------------------------------------------------------
         El club decidió que estos avisos van por tres vías: bandeja,
         móvil y correo. Las dos primeras están arriba. La tercera NO
         se puede montar todavía porque el club no manda ni un correo
         automático: no hay proveedor de envío ni función que lo haga.

         Aquí es donde iría, y esto es todo lo que falta:

           1 · Dar de alta un proveedor de envío (Resend, Postmark,
               Brevo…) y verificar el dominio del club.
           2 · Guardar su clave como secreto en Supabase, igual que
               se hizo con VAPID_PRIVATE_KEY para los avisos al móvil
               (docs/avisos-al-movil.md, paso 2).
           3 · Crear la función `correo-enviar` en
               supabase/functions/, con la misma forma que
               `aviso-enviar`: recibe a quién, asunto y texto, y
               devuelve cuántos salieron.
           4 · Descomentar la llamada de abajo. La tabla ya tiene las
               dos columnas donde queda el registro:
               dinero_avisos.correo_en y dinero_avisos.correo_error.

         Se deja SIN llamar a propósito. Montar un envío que no
         funciona es peor que no tenerlo: el panel diría «avisado»
         y no habría avisado a nadie.

         // await sb().functions.invoke('correo-enviar', {
         //   body: { para: para, asunto: o.titulo, texto: o.cuerpo,
         //           enlace: base + (o.enlace || 'admin/'),
         //           aviso_id: o.avisoId }
         // });
         ============================================================ */

      return n;
    } catch (e) { return 0; }
  }

  /* ============================================================
     ESCUELA O SOCIO · la etiqueta se pone, no se adivina
     ------------------------------------------------------------
     Decisión del club: cada persona lleva su etiqueta puesta al
     darla de alta. Mientras no la tenga se dice «sin etiquetar»,
     nunca se deduce.

     Como hay 206 fichas de antes, esta ventana las pone en una
     lista con dos botones por fila. El año de nacimiento se
     enseña como SUGERENCIA y hay un botón para volcarla en las
     que se ven, pero no guarda nada: guardar es un acto aparte.
     ============================================================ */
  async function sinEtiquetaCuantos() {
    if (!sb() || !sb().rpc) return 0;
    var r = await sb().rpc('atletas_sin_etiqueta_cuantos');
    return (r.error || !r.data) ? 0 : Number(r.data);
  }

  async function etiquetar() {
    var yo = await quienSoy();
    if (!yo.ve_dinero) { aviso('Esto es de tesorería y contabilidad.', 'error'); return false; }

    var r = await sb().rpc('atletas_sin_etiqueta');
    if (r.error) { aviso('No se ha podido leer la lista: ' + r.error.message, 'error'); return false; }
    var todos = r.data || [];

    var v = ventana(
      '<h3>Escuela o socio</h3>' +
      '<p class="dnr-sub">Quedan <b class="dnr-mono" id="dnr-quedan">' + todos.length + '</b> fichas sin etiquetar. ' +
        'La etiqueta dice a qué cuenta va el recibo, así que se pone a mano: no se saca del grupo ni de la tarifa.</p>' +
      (todos.length >= 30
        ? '<label class="dnr-et" for="dnr-buscar">buscar por nombre</label>' +
          '<input type="text" id="dnr-buscar" placeholder="Escribe un nombre" autocomplete="off">'
        : '') +
      '<div class="dnr-lista" id="dnr-lista"></div>' +
      '<div class="dnr-nota">El año de nacimiento solo se enseña como pista: la etiqueta la pones tú. ' +
        'Si pulsas aquí se marcan las que se ven según su año, pero sigue sin guardarse nada hasta que pulses «Guardar».' +
        '<button type="button" class="dnr-b" style="display:block;width:100%;margin-top:10px" data-sugerir>' +
        'Marcar las que se ven según su año</button></div>' +
      '<div class="dnr-pie">' +
        '<span class="dnr-cuenta" id="dnr-marcadas">ninguna marcada</span>' +
        '<button type="button" class="dnr-b" data-cerrar>Cerrar</button>' +
        '<button type="button" class="dnr-b dnr-b--azul" data-guardar disabled>Guardar</button>' +
      '</div>'
    );
    v.$('[data-cerrar]').addEventListener('click', v.cerrar);

    var elegido = {};        /* id → 'escuela' | 'socio' */
    var aLaVista = 40;

    function filtrados() {
      var q = (v.$('#dnr-buscar') ? v.$('#dnr-buscar').value : '').trim().toLowerCase();
      if (!q) return todos;
      return todos.filter(function (a) {
        return (nombreDe(a)).toLowerCase().indexOf(q) !== -1;
      });
    }

    function pintar() {
      var lista = filtrados();
      var caja = v.$('#dnr-lista');
      if (!lista.length) {
        caja.innerHTML = '<p class="dnr-vacio">No queda ninguna sin etiquetar.</p>';
      } else {
        var visibles = lista.slice(0, aLaVista);
        caja.innerHTML = visibles.map(function (a) {
          var anio = a.fecha_nacimiento ? String(a.fecha_nacimiento).slice(0, 4) : null;
          var pista = [anio, a.grupo].filter(Boolean).join(' · ') || 'sin año ni grupo';
          var e = elegido[a.id] || '';
          return '<div class="dnr-fila" data-id="' + esc(a.id) + '">' +
            '<span class="dnr-quien"><b>' + esc(nombreDe(a) || 'Sin nombre') + '</b><span>' + esc(pista) + '</span></span>' +
            '<span class="dnr-ops">' +
              '<button type="button" class="dnr-op" data-poner="escuela" aria-pressed="' + (e === 'escuela') + '">Escuela</button>' +
              '<button type="button" class="dnr-op" data-poner="socio" aria-pressed="' + (e === 'socio') + '">Socio</button>' +
            '</span></div>';
        }).join('');
        if (lista.length > visibles.length) {
          caja.innerHTML += '<div class="dnr-fila"><span class="dnr-quien"><b>' +
            (lista.length - visibles.length) + ' más</b><span>' + visibles.length + ' de ' + lista.length + '</span></span>' +
            '<span class="dnr-ops"><button type="button" class="dnr-op" data-mas>Ver más</button></span></div>';
        }
      }
      var n = Object.keys(elegido).length;
      v.$('#dnr-marcadas').textContent = n ? (n === 1 ? '1 marcada' : n + ' marcadas') : 'ninguna marcada';
      v.$('[data-guardar]').disabled = !n;
    }

    v.$('#dnr-lista').addEventListener('click', function (e) {
      if (e.target.hasAttribute('data-mas')) { aLaVista += 40; pintar(); return; }
      var b = e.target.closest('[data-poner]');
      if (!b) return;
      var id = b.closest('.dnr-fila').getAttribute('data-id');
      var q = b.getAttribute('data-poner');
      if (elegido[id] === q) delete elegido[id]; else elegido[id] = q;
      pintar();
    });
    if (v.$('#dnr-buscar')) {
      v.$('#dnr-buscar').addEventListener('input', function () { aLaVista = 40; pintar(); });
    }
    v.$('[data-sugerir]').addEventListener('click', function () {
      filtrados().slice(0, aLaVista).forEach(function (a) {
        if (a.sugerencia) elegido[a.id] = (a.sugerencia === 'escuela' ? 'escuela' : 'socio');
      });
      pintar();
    });

    pintar();

    return new Promise(function (resolve) {
      v.$('[data-guardar]').addEventListener('click', async function () {
        var b = v.$('[data-guardar]');
        b.disabled = true;
        var porTipo = { escuela: [], socio: [] };
        Object.keys(elegido).forEach(function (id) { porTipo[elegido[id]].push(id); });
        var total = 0, fallo = null;
        for (var k in porTipo) {
          if (!porTipo[k].length) continue;
          var rr = await sb().rpc('atletas_etiquetar', { p_ids: porTipo[k], p_tipo: k });
          if (rr.error) { fallo = rr.error.message; break; }
          total += Number(rr.data || 0);
        }
        if (fallo) { b.disabled = false; aviso('No se ha podido: ' + fallo, 'error'); return; }
        v.cerrar();
        aviso(total === 1 ? 'Una ficha etiquetada' : total + ' fichas etiquetadas', 'ok');
        resolve(total);
      });
      v.fondo.addEventListener('click', function (e) { if (e.target === v.fondo) resolve(0); });
    });
  }

  /* ============================================================
     Repartir papeles, en un clic. Solo administración.
     Es lo que hará falta el día que Isabel tenga cuenta:
       APOLANA_DINERO.ponerRoles(idDeIsabel, ['contabilidad'])
     y deja de estar vacío el papel de contabilidad.
     Se pasa la lista ENTERA de papeles de esa persona, no uno: es
     una lista, y así no hay dos verdades sobre qué tiene.
     ============================================================ */
  async function ponerRoles(perfilId, roles) {
    var r = await sb().rpc('perfil_roles_poner', { p_perfil: perfilId, p_roles: roles });
    if (r.error) { aviso('No se ha podido: ' + r.error.message, 'error'); return false; }
    olvidarQuienSoy();
    aviso('Papeles guardados: ' + (roles || []).join(', '), 'ok');
    return true;
  }

  window.APOLANA_DINERO = {
    quienSoy: quienSoy,
    olvidarQuienSoy: olvidarQuienSoy,
    bandeja: bandeja,
    alertas: alertas,
    abrirAviso: abrirAviso,
    cuota: cuota,
    fijarCuota: fijarCuota,
    pedirCambio: pedirCambio,
    avisarMovil: avisarMovil,
    sinEtiquetaCuantos: sinEtiquetaCuantos,
    etiquetar: etiquetar,
    ponerRoles: ponerRoles,
    eur: eur
  };
})();
