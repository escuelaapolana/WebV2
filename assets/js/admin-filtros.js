/* ============================================================
   FILTROS APLICADOS · Club Atletismo Apolana  (kit 30f)
   ------------------------------------------------------------
   «El filtro aplicado se ve siempre, como chip en crema con su
   «×», y un “Quitar filtros” al lado. Nunca “Filtrar · 0”: se
   dice qué está aplicado, no cuántos.»

   Una sola pieza para todas las pantallas de listado del panel.
   La pantalla no tiene que escribir nada: basta con marcar el
   bloque de filtros que ya tiene.

       <div class="filtros" data-chips> … </div>

   Debajo aparece la fila de chips con lo que está puesto. Cada
   chip se quita con su «×», que devuelve ese control a su valor
   neutro y avisa a la pantalla con los mismos eventos que si lo
   hubiera tocado una persona: la pantalla no se entera de que
   existen los chips y no hay que cambiarle ni una línea.

   Detalles que importan:
   · El valor neutro de un desplegable es su opción vacía («Todos
     los grupos»), no el que trae al cargar: hay pantallas que
     llegan con un filtro puesto desde la dirección web
     (?estado=lesionado) y ese filtro TIENE que salir como chip.
   · El rótulo del chip sale de `data-chip`, del <label> o, si no
     hay nada, del propio texto elegido («Activo», «Solo socios»),
     que casi siempre se lee mejor solo.
   · Si no hay ningún filtro puesto, no hay fila: ni un cero, ni
     un «sin filtros».
   ============================================================ */
(function () {
  'use strict';
  if (location.pathname.indexOf('/admin/') === -1) return;

  var CAMPOS = 'select, input[type=search], input[type=text], input[type=date], ' +
               'input[type=month], input[type=number], input[type=checkbox]';

  /* ---------- estilos ---------- */
  var CSS = [
    '.apf-chips{display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin:2px 0 12px}',
    '.apf-chips:empty{display:none}',
    '.apf-chip{display:inline-flex;align-items:center;gap:2px;min-height:40px;box-sizing:border-box;',
      'padding:6px 6px 6px 15px;border:1px solid var(--linea-borde,#D4CBB9);border-radius:999px;',
      'background:var(--crema,#FBF9F4);color:var(--texto,#4A4437);font-family:inherit;font-size:14px;',
      'line-height:1.3;max-width:100%}',
    '.apf-chip .apf-txt{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:34ch}',
    '.apf-chip .apf-txt b{font-weight:600;color:var(--navy,#2E4256)}',
    /* la «×» es su propio objetivo: no se quita el filtro sin querer */
    '.apf-chip button{flex:0 0 auto;width:30px;height:30px;margin:0;padding:0;border:0;border-radius:999px;',
      'background:none;color:var(--texto-suave,#6E6656);font-family:inherit;font-size:17px;line-height:1;',
      'cursor:pointer;display:inline-flex;align-items:center;justify-content:center;',
      '-webkit-tap-highlight-color:transparent}',
    '.apf-chip button:hover{background:#EFE9DC;color:var(--navy,#2E4256)}',
    '.apf-chip button:focus-visible{outline:2px solid var(--azul-oscuro,#2F6FA8);outline-offset:2px}',
    /* «Quitar filtros» es el tercer nivel de botón: solo texto en azul */
    '.apf-quitar{min-height:40px;padding:8px 10px;border:0;border-radius:999px;background:none;',
      'color:var(--azul-oscuro,#2F6FA8);font-family:inherit;font-size:14px;font-weight:600;cursor:pointer;',
      '-webkit-tap-highlight-color:transparent}',
    '.apf-quitar:hover{background:#EFE9DC}',
    '@media (max-width:620px){.apf-chip .apf-txt{max-width:22ch}}'
  ].join('');

  var puesto = false;
  function estilos() {
    if (puesto) return;
    puesto = true;
    var s = document.createElement('style');
    s.setAttribute('data-piel', 'filtros');
    s.textContent = CSS;
    document.head.appendChild(s);
  }

  /* ---------- utilidades ---------- */
  function esc(s) {
    var d = document.createElement('div');
    d.textContent = (s == null ? '' : String(s));
    return d.innerHTML;
  }

  /* El valor neutro: el que significa «sin filtrar». */
  function neutro(c) {
    if (c.type === 'checkbox') return c.defaultChecked;
    if (c.tagName === 'SELECT') {
      for (var i = 0; i < c.options.length; i++) if (c.options[i].value === '') return '';
      return c.options.length ? c.options[0].value : '';
    }
    return '';
  }

  function puesta(c) {
    if (c.type === 'checkbox') return c.checked !== neutro(c);
    var v = (c.value == null ? '' : String(c.value)).trim();
    return v !== '' && v !== String(neutro(c));
  }

  /* Cómo se llama este filtro. Si la pantalla no lo dice, casi
     siempre se lee mejor solo el valor elegido. */
  function rotulo(c) {
    var d = c.getAttribute('data-chip');
    if (d !== null) return d.trim();
    var l = c.id ? document.querySelector('label[for="' + c.id.replace(/"/g, '\\"') + '"]') : null;
    if (!l && c.closest) l = c.closest('label');
    if (l) {
      var t = (l.textContent || '').replace(/\s+/g, ' ').trim().replace(/[:·]$/, '').trim();
      if (t) return t;
    }
    return '';
  }

  /* Qué pone el chip. */
  function texto(c) {
    var rot = rotulo(c);
    if (c.type === 'checkbox') return rot || (c.getAttribute('aria-label') || c.id || 'Activado');
    if (c.tagName === 'SELECT') {
      var o = c.options[c.selectedIndex];
      var v = o ? (o.textContent || '').replace(/\s+/g, ' ').trim() : c.value;
      return rot ? rot + ': ' + v : v;
    }
    var val = String(c.value).trim();
    if (c.type === 'search' || c.type === 'text') return rot ? rot + ': ' + val : 'Busca «' + val + '»';
    return rot ? rot + ': ' + val : val;
  }

  /* Devolver un control a su sitio y avisar a la pantalla como si lo
     hubiera tocado una persona: la pantalla no cambia nada. */
  function limpiar(c) {
    if (c.type === 'checkbox') c.checked = neutro(c);
    else c.value = neutro(c);
    c.dispatchEvent(new Event('input',  { bubbles: true }));
    c.dispatchEvent(new Event('change', { bubbles: true }));
  }

  /* ---------- pintado ---------- */
  function fila(caja) {
    if (caja.__apf && caja.__apf.parentNode) return caja.__apf;
    var f = document.createElement('div');
    f.className = 'apf-chips';
    f.setAttribute('role', 'group');
    f.setAttribute('aria-label', 'Filtros aplicados');
    if (caja.nextSibling) caja.parentNode.insertBefore(f, caja.nextSibling);
    else caja.parentNode.appendChild(f);
    caja.__apf = f;

    f.addEventListener('click', function (e) {
      var b = e.target.closest ? e.target.closest('button') : null;
      if (!b) return;
      if (b.classList.contains('apf-quitar')) {
        activos(caja).forEach(limpiar);
      } else {
        var c = f.__mapa ? f.__mapa[b.getAttribute('data-apf')] : null;
        if (c) limpiar(c);
      }
      pintar(caja);
    });
    return f;
  }

  function activos(caja) {
    return Array.prototype.filter.call(caja.querySelectorAll(CAMPOS), function (c) {
      return !c.hasAttribute('data-chip-omitir') && !c.disabled && puesta(c);
    });
  }

  var n = 0;
  function pintar(caja) {
    var f = fila(caja);
    var cs = activos(caja);
    if (!cs.length) { f.innerHTML = ''; f.__mapa = {}; return; }

    var mapa = {}, html = '';
    cs.forEach(function (c) {
      var clave = c.id || ('apf' + (++n));
      mapa[clave] = c;
      var t = texto(c);
      html += '<span class="apf-chip"><span class="apf-txt">' + esc(t) + '</span>' +
              '<button type="button" data-apf="' + esc(clave) + '" ' +
              'aria-label="Quitar el filtro ' + esc(t) + '">×</button></span>';
    });
    html += '<button type="button" class="apf-quitar">Quitar filtros</button>';
    f.innerHTML = html;
    f.__mapa = mapa;
  }

  /* ---------- arranque ---------- */
  function montar(caja) {
    if (caja.__apfVisto) { pintar(caja); return; }
    caja.__apfVisto = true;
    estilos();
    caja.addEventListener('change', function () { pintar(caja); });
    caja.addEventListener('input',  function () { pintar(caja); });
    /* los desplegables se rellenan cuando llegan los datos */
    if (window.MutationObserver) {
      var espera = null;
      new MutationObserver(function () {
        clearTimeout(espera);
        espera = setTimeout(function () { pintar(caja); }, 60);
      }).observe(caja, { childList: true, subtree: true, attributes: true, attributeFilter: ['value', 'selected'] });
    }
    pintar(caja);
  }

  function barrer() {
    Array.prototype.forEach.call(document.querySelectorAll('[data-chips]'), montar);
  }

  window.APOLANA_FILTROS = { repasar: barrer, pintar: pintar };

  function arrancar() {
    barrer();
    setTimeout(barrer, 400);
    setTimeout(barrer, 1500);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', arrancar);
  else arrancar();
})();
