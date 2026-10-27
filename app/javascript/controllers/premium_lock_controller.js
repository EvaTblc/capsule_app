import { Controller } from "@hotwired/stimulus"

// Fonction payante vue par un compte free : rien ne part au serveur, le clic affiche juste l'explication
export default class extends Controller {
  static targets = ["message"]

  explain() {
    this.messageTarget.classList.toggle("hidden")
  }
}
