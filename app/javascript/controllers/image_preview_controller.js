import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview"]

  connect() {
    this.allFiles = new DataTransfer()
  }

  preview(event) {
    const files = Array.from(event.target.files)

    // Ajouter les nouveaux fichiers au DataTransfer global
    files.forEach(file => {
      this.allFiles.items.add(file)

      const reader = new FileReader()
      reader.onload = (e) => {
        const div = document.createElement("div")
        div.className = "relative h-24 rounded-xl overflow-hidden"
        div.innerHTML = `<img src="${e.target.result}" class="w-full h-full object-cover">`
        this.previewTarget.appendChild(div)
      }
      reader.readAsDataURL(file)
    })

    // Synchroniser tous les fichiers sur l'input galerie
    const galleryInput = document.getElementById("gallery-input")
    galleryInput.files = this.allFiles.files

    // Vider l'input caméra pour éviter les doublons
    event.target.value = ""
  }
}
