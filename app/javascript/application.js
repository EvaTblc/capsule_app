// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Service worker (PWA) : enregistré ici plutôt que par un script en ligne dans la page. Un script en ligne
// a besoin du nonce CSP, qui change quand la session est vidée (déconnexion) : Turbo afficherait alors
// la page suivante avec un nonce inconnu du navigateur, et le script serait bloqué
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker")
}
