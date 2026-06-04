import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "title", "brand", "scale", "material", "loader"]

  async identify(event) {
    const file = event.target.files[0]
    if (!file) return

    this.loaderTarget.classList.remove("hidden")

    const base64 = await this.toBase64(file)

    const response = await fetch("/items/identify", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ image: base64 })
    })

    const data = await response.json()

    if (data.title)    this.titleTarget.value    = data.title
    if (data.brand)    this.brandTarget.value    = data.brand
    if (data.scale)    this.scaleTarget.value    = data.scale
    if (data.material) this.materialTarget.value = data.material

    this.loaderTarget.classList.add("hidden")
  }

  toBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = () => resolve(reader.result.split(",")[1])
      reader.onerror = reject
      reader.readAsDataURL(file)
    })
  }
}
