/* Kindred service worker.
   - App shell: served from cache instantly, refreshed in the background (stale-while-revalidate).
   - Pages: network first with a 3s timeout, so slow 3G still opens the app from cache.
   - Profile photos: cache first (they never change once uploaded), capped at 300 files.
   - Supabase API, auth and realtime: never cached; that data is private and must be fresh. */
const VERSION = "kindred-v1";
const SHELL = `${VERSION}-shell`, STATIC = `${VERSION}-static`, IMAGES = `${VERSION}-img`;
const SHELL_FILES = [
  "./", "index.html", "styles.css", "app.js", "backend-demo.js", "backend-live.js", "config.js",
  "icon.svg", "logo.svg", "manifest.webmanifest", "icons/icon-192.png", "icons/apple-touch-icon.png",
];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(SHELL).then(c => Promise.all(SHELL_FILES.map(f => c.add(f).catch(() => {})))).then(() => self.skipWaiting()));
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => !k.startsWith(VERSION)).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

async function trim(cacheName, max) {
  const c = await caches.open(cacheName);
  const keys = await c.keys();
  for (let i = 0; i < keys.length - max; i++) await c.delete(keys[i]);
}

async function staleWhileRevalidate(req, cacheName) {
  const c = await caches.open(cacheName);
  const hit = await c.match(req);
  const net = fetch(req).then(res => { if (res && (res.ok || res.type === "opaque")) c.put(req, res.clone()); return res; }).catch(() => hit);
  return hit || net;
}

async function cacheFirst(req, cacheName, max) {
  const c = await caches.open(cacheName);
  const hit = await c.match(req);
  if (hit) return hit;
  const res = await fetch(req);
  if (res && (res.ok || res.type === "opaque")) { c.put(req, res.clone()); trim(cacheName, max); }
  return res;
}

async function networkFirst(req) {
  const c = await caches.open(SHELL);
  try {
    const res = await Promise.race([fetch(req), new Promise((_, rej) => setTimeout(() => rej(new Error("timeout")), 3000))]);
    if (res.ok) c.put("index.html", res.clone());
    return res;
  } catch {
    return (await c.match("index.html")) || (await c.match("./")) || Response.error();
  }
}

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);

  if (url.hostname.endsWith(".supabase.co") || url.hostname.endsWith(".supabase.in")) {
    if (url.pathname.startsWith("/storage/v1/object/public/")) e.respondWith(cacheFirst(req, IMAGES, 300));
    return; // API, auth and realtime go straight to the network
  }
  if (req.mode === "navigate" && url.origin === location.origin) { e.respondWith(networkFirst(req)); return; }
  if (url.origin === location.origin) { e.respondWith(staleWhileRevalidate(req, SHELL)); return; }
  if (/fonts\.(googleapis|gstatic)\.com$|cdn\.jsdelivr\.net$/.test(url.hostname)) { e.respondWith(staleWhileRevalidate(req, STATIC)); return; }
});
