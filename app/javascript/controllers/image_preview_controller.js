import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview"]

  preview(event) {
    const files = Array.from(event.target.files)
    files.forEach(file => {
      const reader = new FileReader()
      reader.onload = (e) => {
        const div = document.createElement("div")
        div.className = "relative h-24 rounded-xl overflow-hidden"
        div.innerHTML = `<img src="${e.target.result}" class="w-full h-full object-cover">`
        this.previewTarget.appendChild(div)
      }
      reader.readAsDataURL(file)
    })
  }
}
