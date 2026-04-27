import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "input"]

  select(event) {
    const selected = event.currentTarget

    this.cardTargets.forEach(card => {
      card.classList.remove("border-purple-500", "bg-purple-50")
      card.classList.add("border-gray-100", "bg-white")
    })

    selected.classList.remove("border-gray-100", "bg-white")
    selected.classList.add("border-purple-500", "bg-purple-50")

    this.inputTarget.value = selected.dataset.category
  }
}
