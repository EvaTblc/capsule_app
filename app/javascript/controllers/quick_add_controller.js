import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  open() {
    this.panelTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.panelTarget.classList.add("hidden")
    document.body.style.overflow = ""
    window.location.reload()
  }
}
