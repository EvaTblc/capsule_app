import { Controller } from "@hotwired/stimulus"

// Bouton œil d'un champ mot de passe : afficher / masquer ce qu'on tape (utile sur téléphone)
export default class extends Controller {
  static targets = ["input", "button"]

  toggle() {
    const show = this.inputTarget.type === "password"
    this.inputTarget.type = show ? "text" : "password"
    this.buttonTarget.setAttribute("aria-pressed", show)
    this.buttonTarget.setAttribute("aria-label", show ? "Masquer le mot de passe" : "Afficher le mot de passe")
  }
}
