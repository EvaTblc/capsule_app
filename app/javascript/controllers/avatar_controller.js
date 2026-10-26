import { Controller } from "@hotwired/stimulus"

// Photo de profil introuvable (lien Google expiré...) : on affiche l'initiale à la place
export default class extends Controller {
  static targets = ["img", "fallback"]

  connect() {
    // L'image a pu échouer avant que Stimulus ne démarre : l'événement « error » est alors déjà passé
    if (this.hasImgTarget && this.imgTarget.complete && this.imgTarget.naturalWidth === 0) this.error()
  }

  error() {
    this.imgTarget.classList.add("hidden")
    this.fallbackTarget.classList.remove("hidden")
  }
}
