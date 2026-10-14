/* Service worker ringkas Badal Haji MKM: membolehkan app dipasang dan membuka halaman yang pernah dibuka ketika tiada internet.
   Hanya halaman (navigasi) dalam laman ini disimpan. Permintaan ke Supabase dan pelayan lain TIDAK disentuh. */
const CACHE = "bh-pages-v1";
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(
  caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith("bh-pages-") && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())
));
self.addEventListener("fetch", e => {
  const r = e.request;
  if(r.method !== "GET" || r.mode !== "navigate" || new URL(r.url).origin !== self.location.origin) return;
  e.respondWith(
    fetch(r).then(res => {
      if(res && res.ok){ const copy = res.clone(); caches.open(CACHE).then(c => c.put(r, copy)).catch(() => {}); }
      return res;
    }).catch(() => caches.match(r, { ignoreSearch: false }).then(m => m || caches.match(r, { ignoreSearch: true })).then(m => m || Response.error()))
  );
});
