/* The web app moved to /app/. This replaces the old root service worker so earlier visitors
   stop getting the cached app at "/": it clears its caches and unregisters itself. */
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil((async () => {
  for (const k of await caches.keys()) if (!k.includes("-app-")) await caches.delete(k);
  await self.registration.unregister();
  for (const c of await self.clients.matchAll({ type: "window" })) c.navigate(c.url);
})()));
