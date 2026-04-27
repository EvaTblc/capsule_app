import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "input", "form"]

  select(event) {
    const selected = event.currentTarget
    const type = selected.dataset.type

    this.cardTargets.forEach(card => {
      card.classList.remove("border-purple-500", "bg-purple-50")
      card.classList.add("border-gray-100", "bg-white")
    })

    selected.classList.remove("border-gray-100", "bg-white")
    selected.classList.add("border-purple-500", "bg-purple-50")

    this.inputTarget.value = type

    this.formTargets.forEach(form => {
      form.classList.add("hidden")
    })

    const targetForm = this.element.querySelector(`[data-form="${type}"]`)
    if (targetForm) targetForm.classList.remove("hidden")
  }
}
