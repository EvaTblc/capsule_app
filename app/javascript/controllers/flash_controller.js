import { Controller } from "@hotwired/stimulus"

// Message flash : disparaît tout seul après quelques secondes, ou au tap
export default class extends Controller {
  static values = { delay: { type: Number, default: 4000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.add("opacity-0")
    setTimeout(() => this.element.remove(), 300)
  }
}
