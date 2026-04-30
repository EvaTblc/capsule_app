const CACHE_NAME = "capsule-v1"

const PRECACHE_URLS = [
  "/",
  "/collections",
  "/offline"
]

// Installation — on met en cache les ressources essentielles
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(PRECACHE_URLS)
    })
  )
  self.skipWaiting()
})

// Activation — on supprime les anciens caches
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      )
    })
  )
  self.clients.claim()
})

// Fetch — stratégie Network First avec fallback cache
self.addEventListener("fetch", (event) => {
  // On ignore les requêtes non-GET et les API
  if (event.request.method !== "GET") return
  if (event.request.url.includes("/api/")) return
  if (event.request.url.includes("/users/auth/")) return

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // On met en cache la réponse fraîche
        const responseClone = response.clone()
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, responseClone)
        })
        return response
      })
      .catch(() => {
        // Pas de réseau — on cherche dans le cache
        return caches.match(event.request).then((cached) => {
          return cached || caches.match("/offline")
        })
      })
  )
})
