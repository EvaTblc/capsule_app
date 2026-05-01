import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "image"]

  open(event) {
    const url = event.currentTarget.dataset.url
    this.imageTarget.src = url
    this.modalTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.imageTarget.src = ""
    document.body.style.overflow = ""
  }
}
