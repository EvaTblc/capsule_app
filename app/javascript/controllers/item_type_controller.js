import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "input", "form"]

  connect() {
    const currentType = this.inputTarget.value
    if (currentType) {
      const card = this.cardTargets.find(c => c.dataset.type === currentType)
      if (card) {
        card.classList.remove("border-gray-100", "bg-white")
        card.classList.add("border-purple-500", "bg-purple-50")
        const form = this.element.querySelector(`[data-form="${currentType}"]`)
        if (form) {
          form.classList.remove("hidden")
          form.style.display = "flex"
          form.style.flexDirection = "column"
          form.style.gap = "1rem"
        }
      }
    }
  }

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
      form.style.display = ""
    })

    const targetForm = this.element.querySelector(`[data-form="${type}"]`)
    if (targetForm) {
      targetForm.classList.remove("hidden")
      targetForm.style.display = "flex"
      targetForm.style.flexDirection = "column"
      targetForm.style.gap = "1rem"
    }
  }
}
