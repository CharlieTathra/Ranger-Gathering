/* Ngarringilanha Ranger Gathering — offline service worker.
   Trelawney has patchy signal. Everything below is cached on first visit so the
   agenda, site map, safety page and emergency contacts still open with no bars. */

const CACHE = 'rg-v1';

// The app shell. Paths are relative so this works under the /Ranger-Gathering/
// sub-path that GitHub Pages serves from.
const SHELL = [
  './',
  './index.html',
  './manifest.json',
  './walaaybaa-rangers-logo.jpg',
  './icon-192.png',
  './icon-512.png',
  './apple-touch-icon.png'
];

self.addEventListener('install', e=>{
  e.waitUntil(
    caches.open(CACHE)
      // addAll fails the whole install if any one file 404s, so add individually.
      .then(c=>Promise.all(SHELL.map(u=>c.add(u).catch(err=>console.warn('skip',u,err)))))
      .then(()=>self.skipWaiting())
  );
});

self.addEventListener('activate', e=>{
  e.waitUntil(
    caches.keys()
      .then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))))
      .then(()=>self.clients.claim())
  );
});

self.addEventListener('fetch', e=>{
  const req = e.request;
  if(req.method !== 'GET') return;

  const url = new URL(req.url);

  // Never cache Supabase or the CDN — photos and feedback must hit the network,
  // and the app already falls back to on-phone storage when they cannot.
  if(url.origin !== self.location.origin) return;

  // Navigations: try the network so people get updates, fall back to the cached
  // page when there is no signal.
  if(req.mode === 'navigate'){
    e.respondWith(
      fetch(req)
        .then(res=>{
          const copy = res.clone();
          caches.open(CACHE).then(c=>c.put('./index.html', copy));
          return res;
        })
        .catch(()=>caches.match('./index.html').then(r=>r || caches.match('./')))
    );
    return;
  }

  // Everything else same-origin: cache first, then network.
  e.respondWith(
    caches.match(req).then(hit=>
      hit || fetch(req).then(res=>{
        if(res && res.status === 200 && res.type === 'basic'){
          const copy = res.clone();
          caches.open(CACHE).then(c=>c.put(req, copy));
        }
        return res;
      }).catch(()=>hit)
    )
  );
});
