import { Controller } from "@hotwired/stimulus"

// Côté long maximal recommandé pour l'analyse d'images par Claude : au-delà, l'image est réduite par l'API
// de toute façon, et une photo de téléphone brute (3 à 8 Mo) dépasserait la limite d'envoi
const MAX_SIDE = 1568
const JPEG_QUALITY = 0.85

export default class extends Controller {
  static targets = ["loader", "input", "title", "name", "series", "manufacturer", "line", "release_year"]

  async identify(event) {
    const file = event.target.files[0]
    if (!file) return

    this.showStatus("✨ Identification en cours...")

    try {
      const base64 = await this.toJpegBase64(file)

      const response = await fetch("/items/identify", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ image: base64 })
      })

      if (response.status === 429) {
        this.showStatus("Trop d'identifications d'affilée : réessaie dans une minute.", true)
        return
      }

      const data = await response.json()
      if (data.error) {
        this.showStatus(data.error, true)
        return
      }

      if (data.title) this.titleTarget.value = data.title
      if (data.name) this.nameTarget.value = data.name
      if (data.series) this.seriesTarget.value = data.series
      if (data.manufacturer) this.manufacturerTarget.value = data.manufacturer
      if (data.line) this.lineTarget.value = data.line
      if (data.release_year) this.release_yearTarget.value = data.release_year
      this.hideStatus()
    } catch (error) {
      this.showStatus(error.message === "decode"
        ? "Format de photo non pris en charge : prends la photo en JPEG ou fais une capture d'écran."
        : "Identification impossible pour le moment : remplis les champs à la main.", true)
    } finally {
      // Permet de choisir à nouveau la même photo
      event.target.value = ""
    }
  }

  // Photo → JPEG réduit, en base64 (sans le préfixe data:)
  async toJpegBase64(file) {
    let bitmap
    try {
      // from-image : applique la rotation EXIF du téléphone (sinon une photo portrait part couchée)
      bitmap = await createImageBitmap(file, { imageOrientation: "from-image" })
    } catch {
      throw new Error("decode") // ex. HEIC sur un navigateur qui ne sait pas le lire
    }

    const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height))
    const canvas = document.createElement("canvas")
    canvas.width = Math.round(bitmap.width * scale)
    canvas.height = Math.round(bitmap.height * scale)
    canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height)
    bitmap.close()

    return canvas.toDataURL("image/jpeg", JPEG_QUALITY).split(",")[1]
  }

  showStatus(text, isError = false) {
    this.loaderTarget.textContent = text
    this.loaderTarget.classList.toggle("text-red-600", isError)
    this.loaderTarget.classList.toggle("text-purple-500", !isError)
    this.loaderTarget.classList.remove("hidden")
  }

  hideStatus() {
    this.loaderTarget.classList.add("hidden")
  }
}
