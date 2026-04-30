import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "platform", "genre", "releaseDate", "description", "scanner"]

  async startScan() {
    this.scannerTarget.classList.remove("hidden")

    const video = document.getElementById("game-scanner-video")

    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment" }
      })
      video.srcObject = stream
      video.play()
      this.stream = stream
      this.detectBarcode(video)
    } catch(err) {
      alert("Impossible d'accéder à la caméra")
      this.stopScan()
    }
  }

  async detectBarcode(video) {
    if (!("BarcodeDetector" in window)) {
      alert("Votre navigateur ne supporte pas la détection de barcode")
      this.stopScan()
      return
    }

    const detector = new BarcodeDetector({ formats: ["ean_13", "ean_8"] })

    this.scanInterval = setInterval(async () => {
      try {
        const barcodes = await detector.detect(video)
        if (barcodes.length > 0) {
          const ean = barcodes[0].rawValue
          this.stopScan()
          this.searchByBarcode(ean)
        }
      } catch(err) {
        console.log(err)
      }
    }, 500)
  }

  stopScan() {
    this.scannerTarget.classList.add("hidden")
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }
    if (this.scanInterval) {
      clearInterval(this.scanInterval)
      this.scanInterval = null
    }
  }

  searchByBarcode(ean) {
    this.queryTarget.value = ean

    fetch(`/api/search/game_barcode?ean=${encodeURIComponent(ean)}`)
      .then(res => res.json())
      .then(data => {
        if (data.error) {
          alert("Aucun jeu trouvé pour ce barcode")
        } else {
          this.fill(data)
        }
      })
  }

  search() {
    const query = this.queryTarget.value
    if (query.length < 3) return

    fetch(`/api/search/search_game?query=${encodeURIComponent(query)}`)
      .then(res => res.json())
      .then(data => {
        this.resultsTarget.innerHTML = ""
        const games = data.games || []
        games.forEach(game => {
          const div = document.createElement("div")
          div.className = "p-3 border-b border-gray-100 cursor-pointer hover:bg-purple-50 text-sm"
          div.textContent = game.name + (game.release_date ? ` — ${game.release_date}` : "")
          div.addEventListener("click", () => this.fill(game))
          this.resultsTarget.appendChild(div)
        })
        this.resultsTarget.classList.remove("hidden")
      })
  }

  fill(game) {
    const nameInput = this.element.querySelector("input[name='item[name]']")
    if (nameInput) nameInput.value = game.name || ""

    if (this.hasPlatformTarget) this.platformTarget.value = game.platforms || ""
    if (this.hasGenreTarget) this.genreTarget.value = game.genres || ""
    if (this.hasReleaseDateTarget) this.releaseDateTarget.value = game.release_date || ""
    if (this.hasDescriptionTarget) this.descriptionTarget.value = game.summary || ""

    // Stocker les metadata dans un champ caché si présent
    const metadataInput = this.element.querySelector("input[name='item[metadata]']")
    if (metadataInput) metadataInput.value = JSON.stringify(game.metadata || {})

    // Stocker la cover_url
    const coverInput = this.element.querySelector("input[name='item[cover_url]']")
    if (coverInput) coverInput.value = game.cover_url || ""

    this.resultsTarget.classList.add("hidden")
  }
}
