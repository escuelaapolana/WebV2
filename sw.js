/* Service worker del Club Atletismo Apolana.
   Estrategia "caché primero" (modelo app-shell): el esqueleto de la app —páginas,
   JS, CSS, fuentes— se sirve AL INSTANTE desde la caché del móvil y se revalida
   por detrás para la próxima vez. Así la app abre rápido sin esperar a descargar
   e interpretar ~450 KB de JavaScript cada vez.
   · Los DATOS (Supabase) y los CDN NO pasan por aquí: siempre a la red, así que lo
     que ves sigue siendo en vivo. Lo único cacheado es el código de la web.
   · La frescura del código la avisa `version.txt` + el botón «Actualiza» (ver
     assets/js/db.js): al pulsarlo se limpia la caché y se recarga, trayendo lo
     último. `version.txt` se pide SIEMPRE a la red para que ese aviso funcione. */
const CACHE = 'apolana-v9';

self.addEventListener('install', function () { self.skipWaiting(); });

self.addEventListener('activate', function (e) {
  e.waitUntil((async function () {
    const keys = await caches.keys();
    await Promise.all(keys.filter(function (k) { return k !== CACHE; }).map(function (k) { return caches.delete(k); }));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', function (e) {
  const req = e.request;
  if (req.method !== 'GET') return;                         // no tocar envíos de datos
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;          // Supabase / CDN: siempre a la red

  /* version.txt SIEMPRE a la red: el aviso de «Actualiza» depende de leerlo fresco.
     (Además llega con ?t= único, así que tampoco tendría sentido cachearlo.) */
  if (url.pathname.slice(-11) === 'version.txt') {
    e.respondWith(fetch(req).catch(function () { return new Response('', { status: 504 }); }));
    return;
  }

  /* CACHÉ PRIMERO + revalidación en segundo plano (stale-while-revalidate). */
  e.respondWith((async function () {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(req);

    // Pide la versión nueva y actualiza la caché para la PRÓXIMA vez. No bloquea.
    const revalidar = fetch(req, { cache: 'no-cache' }).then(function (fresh) {
      if (fresh && fresh.ok && fresh.type === 'basic') { cache.put(req, fresh.clone()); }
      return fresh;
    }).catch(function () { return null; });

    // Si está en caché, se sirve YA (instantáneo) y se revalida por detrás.
    if (cached) { revalidar; return cached; }

    // Primera vez (no estaba en caché): se espera a la red.
    const fresh = await revalidar;
    if (fresh) return fresh;

    // Sin red y sin caché: en una navegación, el portal como último recurso.
    if (req.mode === 'navigate') {
      const home = await cache.match(self.registration.scope + 'portal/');
      if (home) return home;
    }
    return new Response('', { status: 504, statusText: 'sin conexion' });
  })());
});

/* ============================================================
   AVISOS AL MÓVIL
   ------------------------------------------------------------
   Estos dos trozos son los que hacen que un aviso salga en la
   pantalla aunque la app esté cerrada. El móvil despierta este
   archivo un segundo, pinta el aviso y lo vuelve a dormir.
   Lo manda la función `aviso-enviar` (ver docs/avisos-al-movil.md).
   ============================================================ */

/* 1 · Llega un aviso → se pinta. */
self.addEventListener('push', function (e) {
  var d = {};
  try { d = e.data ? e.data.json() : {}; }
  catch (err) { d = { titulo: 'Club Apolana', cuerpo: e.data ? e.data.text() : '' }; }

  var destino = d.url || (self.registration.scope + 'portal/');

  /* `showNotification` es obligatorio: si llega un aviso y no se
     pinta nada, el navegador acaba retirándole el permiso a la web. */
  e.waitUntil(self.registration.showNotification(d.titulo || 'Club Apolana', {
    body:  d.cuerpo || '',
    icon:  self.registration.scope + 'assets/img/app-icon-192.png',
    badge: self.registration.scope + 'assets/img/app-icon-192.png',
    lang:  'es',
    /* Misma etiqueta = el aviso nuevo sustituye al viejo en vez de
       apilarse. Nadie quiere ocho avisos del club en la pantalla. */
    tag: d.etiqueta || 'apolana',
    renotify: true,
    data: { url: destino }
  }));
});

/* 2 · Se toca el aviso → se abre la app donde toca. */
self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  var destino = (e.notification.data && e.notification.data.url) ||
                (self.registration.scope + 'portal/');

  e.waitUntil((async function () {
    /* Si la app ya está abierta, se aprovecha esa ventana: abrir otra
       deja al usuario con dos apps iguales y sin saber cuál es cuál. */
    var abiertas = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (var i = 0; i < abiertas.length; i++) {
      var c = abiertas[i];
      if (c.url.indexOf(self.registration.scope) === 0 && 'focus' in c) {
        await c.focus();
        if ('navigate' in c) { try { await c.navigate(destino); } catch (err) { /* da igual */ } }
        return;
      }
    }
    if (self.clients.openWindow) await self.clients.openWindow(destino);
  })());
});
