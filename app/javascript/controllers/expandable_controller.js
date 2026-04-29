import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "button"]

  toggle() {
    this.contentTarget.classList.toggle("line-clamp-3")
    this.buttonTarget.textContent = this.contentTarget.classList.contains("line-clamp-3") ? "Voir plus" : "Voir moins"
  }
}
