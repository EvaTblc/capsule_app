import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["img", "fallback"]

  error() {
    this.imgTarget.classList.add("hidden")
    this.fallbackTarget.classList.remove("hidden")
  }
}
