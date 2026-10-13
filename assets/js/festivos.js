/* ============================================================
   FESTIVOS Y CIERRES · lo que se cae del calendario
   ------------------------------------------------------------
   Lee los días marcados en `calendario_excepciones` (admin «Se pone
   solo», calendario del club, «cancelar día» de natación) con la RPC
   pública `excepciones_rango(desde, hasta)` (mig 320) y dice si una
   actividad concreta se cae ese día.

   LA REGLA es la de la base (`_excepcion_aplica`, mig 320) y aquí va
   su espejo exacto. Si se cambia allí, se cambia aquí:
     · grupo_id  NULL o el del grupo de la actividad
     · seccion   NULL, la de la actividad, o 'natacion' cuando la
                 actividad es 'escuela-natacion'
     · lugar     NULL o contenido en el lugar de la actividad (sin
                 tildes ni mayúsculas). Sin lugar conocido, no cae lo
                 que está limitado a un lugar.

   USO
     APOLANA_FESTIVOS.cargar(sb, '2026-10-01', '2026-10-31')
       .then(function (F) {
         var e = F.de('2026-10-12', { seccion:'escuela', grupo_id:id, lugar:'Estadio…' });
         if (e) … e.motivo, e.tipo …
         F.delDia('2026-10-12')   // todas las de ese día
         F.delClub('2026-10-12')  // la de todo el club (sin sección/grupo/lugar), o null
       });
   Nunca falla: si la consulta no sale, devuelve un objeto vacío (nada
   se cae) y la pantalla se pinta como siempre.
   ============================================================ */
(function () {
  'use strict';

  var MAPA = { 'á':'a','à':'a','ä':'a','â':'a','é':'e','è':'e','ë':'e','ê':'e','í':'i','ì':'i','ï':'i','î':'i','ó':'o','ò':'o','ö':'o','ô':'o','ú':'u','ù':'u','ü':'u','û':'u','ñ':'n','ç':'c' };
  function plano(s) {
    return String(s == null ? '' : s).toLowerCase().replace(/[áàäâéèëêíìïîóòöôúùüûñç]/g, function (c) { return MAPA[c] || c; });
  }

  /* Espejo de public._excepcion_aplica */
  function aplica(e, ctx) {
    ctx = ctx || {};
    if (e.grupo_id && e.grupo_id !== ctx.grupo_id) return false;
    if (e.seccion && e.seccion !== ctx.seccion &&
        !(e.seccion === 'natacion' && ctx.seccion === 'escuela-natacion')) return false;
    var l = String(e.lugar || '').trim();
    if (l && plano(ctx.lugar).indexOf(plano(l)) < 0) return false;
    return true;
  }

  function envolver(filas) {
    var porDia = {};
    (filas || []).forEach(function (f) {
      if (!f || !f.fecha) return;
      var k = String(f.fecha).slice(0, 10);
      (porDia[k] = porDia[k] || []).push(f);
    });
    return {
      filas: filas || [],
      delDia: function (fecha) { return porDia[String(fecha).slice(0, 10)] || []; },
      /* La primera que cae sobre esa actividad. Vienen ordenadas de lo más
         concreto (grupo) a lo más general (todo el club). */
      de: function (fecha, ctx) {
        var l = porDia[String(fecha).slice(0, 10)] || [];
        for (var i = 0; i < l.length; i++) if (aplica(l[i], ctx)) return l[i];
        return null;
      },
      delClub: function (fecha) {
        var l = porDia[String(fecha).slice(0, 10)] || [];
        for (var i = 0; i < l.length; i++) {
          if (!l[i].seccion && !l[i].grupo_id && !l[i].lugar) return l[i];
        }
        return null;
      }
    };
  }

  function cargar(sb, desde, hasta) {
    if (!sb || !desde || !hasta) return Promise.resolve(envolver([]));
    try {
      return Promise.resolve(sb.rpc('excepciones_rango', { p_desde: desde, p_hasta: hasta }))
        .then(function (r) { return envolver(r && !r.error && Array.isArray(r.data) ? r.data : []); },
              function () { return envolver([]); });
    } catch (e) { return Promise.resolve(envolver([])); }
  }

  /* «Festivo · sin entreno» / «Cierre · sin entreno», y el motivo aparte. */
  function rotulo(e, que) {
    var t = (e && e.tipo === 'cierre') ? 'Cierre' : 'Festivo';
    return t + ' · sin ' + (que || 'entreno');
  }
  function motivo(e) {
    var m = e && e.motivo ? String(e.motivo).trim() : '';
    return (m && m.toLowerCase() !== 'festivo') ? m : '';
  }

  /* Estilo mínimo compartido, para no tocar el CSS de cada página:
     .apo-fest      → etiqueta ámbar «Festivo · sin entreno»
     .apo-fest-off  → actividad que se cae (atenuada y tachada)
     .apo-fest-dia  → franja de aviso de día entero */
  function estilo() {
    if (document.getElementById('apo-festivos-css')) return;
    var s = document.createElement('style');
    s.id = 'apo-festivos-css';
    s.textContent =
      '.apo-fest{display:inline-block;font-size:10.5px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;' +
        'line-height:1.3;color:#8A4B12;background:#FCEBD3;border:1px solid #F1D2A6;border-radius:6px;padding:2px 7px;' +
        'margin:2px 0 0;text-decoration:none!important;white-space:normal;vertical-align:middle}' +
      '.apo-fest-off{opacity:.62}' +
      '.apo-fest-off .tit,.apo-fest-off .et,.apo-fest-off b,.apo-fest-off .nombre,.apo-fest-off .qq,.apo-fest-off .hh,.apo-fest-off .hora{text-decoration:line-through;text-decoration-thickness:1px}' +
      '.apo-fest-dia{display:flex;gap:8px;align-items:baseline;flex-wrap:wrap;background:#FFF6E8;border:1px solid #F1D2A6;' +
        'border-left:4px solid #D98A2B;border-radius:10px;padding:9px 12px;margin:6px 0 10px;font-size:13.5px;color:#6B3C0E;line-height:1.35}' +
      '.apo-fest-dia b{font-weight:700;color:#6B3C0E}';
    (document.head || document.documentElement).appendChild(s);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', estilo); else estilo();

  window.APOLANA_FESTIVOS = { cargar: cargar, aplica: aplica, rotulo: rotulo, motivo: motivo, estilo: estilo };
})();
