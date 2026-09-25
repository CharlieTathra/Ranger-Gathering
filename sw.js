/* Ngarringilanha Ranger Gathering — offline service worker.
   Trelawney has patchy signal. Everything below is cached on first visit so the
   agenda, site map, safety page and emergency contacts still open with no bars. */

const CACHE = 'rg-v9';

// Public Supabase details. These are already in the page source of a public
// repo — the publishable key is meant to be public and is constrained by Row
// Level Security. The worker needs its own copy because it runs outside the page.
const SB_URL = 'https://jajjnrdzageznhufwpqr.supabase.co';
const SB_KEY = 'sb_publishable_6tbY8GVlsNIsk00b5UBy0g_CgPLlV7-';

// The app shell. Paths are relative so this works under the /Ranger-Gathering/
// sub-path that GitHub Pages serves from.
const SHELL = [
  './',
  './index.html',
  './manifest.json',
  './walaaybaa-artwork-hero.jpg',
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


/* ---- Push notifications ---- */
// The push arrives with no payload: it only says "something is waiting". The
// wording lives in the push_messages table, so it can be changed with one row
// instead of an app release. If the fetch fails — no signal by the time the
// push lands — fall back to the feedback ask rather than showing nothing.
self.addEventListener('push', e=>{
  e.waitUntil((async ()=>{
    let title = 'Ngarringilanha Ranger Gathering';
    let body  = 'Tap to fill in the feedback form.';
    let url   = './#feedback';

    try{
      if(e.data){
        const d = e.data.json();
        title = d.title || title; body = d.body || body; url = d.url || url;
      }else{
        const r = await fetch(
          `${SB_URL}/rest/v1/push_messages?select=title,body,url&order=created_at.desc&limit=1`,
          { headers:{ apikey:SB_KEY, Authorization:`Bearer ${SB_KEY}` } });
        if(r.ok){
          const [row] = await r.json();
          if(row){ title = row.title || title; body = row.body || body; url = row.url || url; }
        }
      }
    }catch(err){ /* keep the fallback */ }

    await self.registration.showNotification(title, {
      body,
      icon:'./icon-192.png',
      badge:'./icon-192.png',
      data:{ url },
      tag:'rg-notice',        // a second send replaces the first, never stacks
      renotify:true
    });
  })());
});

// Bring the ranger to the right screen. Reuse an open tab if there is one,
// otherwise open the app — either way land on the URL the notice carried.
self.addEventListener('notificationclick', e=>{
  e.notification.close();
  const target = (e.notification.data && e.notification.data.url) || './#feedback';
  e.waitUntil((async ()=>{
    const all = await self.clients.matchAll({ type:'window', includeUncontrolled:true });
    for(const c of all){
      if(c.url.includes(self.registration.scope)){
        await c.navigate(target).catch(()=>{});
        return c.focus();
      }
    }
    return self.clients.openWindow(target);
  })());
});
