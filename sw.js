/* Service worker del Club Atletismo Apolana.
   Estrategia "red primero": cuando hay internet siempre trae la última versión
   (por eso los cambios se ven al momento); si no hay conexión, sirve lo último
   que se vio. No toca las peticiones a Supabase ni a los CDN (siempre a la red,
   para que los datos y el acceso vayan en vivo). */
const CACHE = 'apolana-v2';

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
      const fresh = await fetch(req);
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
