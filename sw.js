/* Service worker del Club Atletismo Apolana.
   Estrategia "red primero": cuando hay internet siempre trae la última versión
   (por eso los cambios se ven al momento); si no hay conexión, sirve lo último
   que se vio. No toca las peticiones a Supabase ni a los CDN (siempre a la red,
   para que los datos y el acceso vayan en vivo). */
const CACHE = 'apolana-v8';

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
  e.respondWith((async function () {
    try {
      /* Se salta la caché del navegador SIEMPRE, no solo en las navegaciones:
         GitHub Pages manda todo con `max-age=600`, así que un JS o un CSS recién
         publicado tardaba hasta diez minutos en verse aunque el service worker
         fuera «red primero» (el navegador le colaba su copia cacheada). Las
         páginas se piden con `reload` (descarga entera) y los demás recursos con
         `no-cache` (revalida con la red: si no ha cambiado, 304 y listo). Sin
         conexión, el `catch` de abajo sirve lo último guardado. */
      const fresh = await fetch(req, { cache: req.mode === 'navigate' ? 'reload' : 'no-cache' });
      // Solo se guarda lo que ha venido bien: si un día la web contesta con un
      // error, no queremos que se quede pegado y se sirva sin conexión.
      if (fresh && fresh.ok && fresh.type === 'basic') {
        const cache = await caches.open(CACHE);
        cache.put(req, fresh.clone());
      }
      return fresh;
    } catch (err) {
      const cached = await caches.match(req);
      if (cached) return cached;
      if (req.mode === 'navigate') {
        const home = await caches.match(self.registration.scope + 'portal/');
        if (home) return home;
      }
      throw err;
    }
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
