// Règle : on ne met en cache que ce qui est identique pour tout le monde (page hors ligne, assets).
// Les pages HTML contiennent les données de l'utilisateur connecté : elles ne sont jamais stockées,
// sinon elles resteraient lisibles hors ligne après une déconnexion (appareil partagé).
//
// Changer CACHE_NAME vide les anciens caches à l'activation : la v1 contenait des pages privées.
const CACHE_NAME = "capsule-v2"
const OFFLINE_URL = "/offline"

// Installation — seule la page hors ligne (publique, styles intégrés) est mise en cache d'avance
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.add(new Request(OFFLINE_URL, { cache: "reload" })))
  )
  self.skipWaiting()
})

// Activation — on supprime les anciens caches (dont la v1 et ses pages privées)
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) =>
      Promise.all(cacheNames.filter((name) => name !== CACHE_NAME).map((name) => caches.delete(name)))
    )
  )
  self.clients.claim()
})

// Assets versionnés par Propshaft (empreinte dans le nom) : leur contenu ne change jamais pour une URL donnée
function isStaticAsset(url) {
  return url.origin === self.location.origin && url.pathname.startsWith("/assets/")
}

self.addEventListener("fetch", (event) => {
  const request = event.request
  if (request.method !== "GET") return

  const url = new URL(request.url)

  // Navigation (pages HTML) : réseau uniquement, page hors ligne si le réseau échoue — jamais stockée
  if (request.mode === "navigate") {
    event.respondWith(fetch(request).catch(() => caches.match(OFFLINE_URL)))
    return
  }

  // CSS, JS, images de l'appli : cache d'abord, puis réseau (et mise en cache des réponses valides)
  if (isStaticAsset(url)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached
        return fetch(request).then((response) => {
          if (response.ok) {
            const copy = response.clone()
            caches.open(CACHE_NAME).then((cache) => cache.put(request, copy))
          }
          return response
        })
      })
    )
  }

  // Tout le reste (API, Turbo Streams, photos des items...) : comportement normal du navigateur, aucun cache
})
