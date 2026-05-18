import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "image"]

  connect() {
    this.urls = []
    this.currentIndex = 0
  }

  open(event) {
    const url = event.currentTarget.dataset.url

    // Récupérer toutes les URLs des images
    this.urls = Array.from(this.element.querySelectorAll("[data-url]")).map(el => el.dataset.url)
    this.currentIndex = this.urls.indexOf(url)

    this.imageTarget.src = url
    this.modalTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.imageTarget.src = ""
    document.body.style.overflow = ""
  }

  next() {
    this.currentIndex = (this.currentIndex + 1) % this.urls.length
    this.imageTarget.src = this.urls[this.currentIndex]
  }

  prev() {
    this.currentIndex = (this.currentIndex - 1 + this.urls.length) % this.urls.length
    this.imageTarget.src = this.urls[this.currentIndex]
  }
}
