import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.closeOnOutsideClick = (e) => {
      if (!this.element.contains(e.target)) {
        this.panelTarget.classList.add("hidden")
      }
    }
    document.addEventListener("click", this.closeOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
  }

  toggle() {
    this.panelTarget.classList.toggle("hidden")
  }
}
