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

  resetForm(event) {
    if (event.detail.success) {
      const form = this.element.querySelector("form")
      const queryInput = this.element.querySelector("[data-games-search-target='query']")
      const titleInput = this.element.querySelector("[data-games-search-target='title']")
      const platformInput = this.element.querySelector("[data-games-search-target='platform']")
      const results = this.element.querySelector("[data-games-search-target='results']")

      if (queryInput) queryInput.value = ""
      if (titleInput) titleInput.value = ""
      if (platformInput) platformInput.value = ""
      if (results) results.classList.add("hidden")

      // Reset pills plateforme
      this.element.querySelectorAll("[data-platform]").forEach(btn => {
        btn.classList.remove("bg-purple-600", "text-white", "border-purple-600")
        btn.classList.add("border-gray-200", "text-gray-500", "bg-white")
      })
    }
  }
}
