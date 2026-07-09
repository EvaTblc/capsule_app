import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "title", "year", "description", "director", "studio", "scanner"]

  search() {
    const query = this.queryTarget.value
    if (query.length < 3) return

    fetch(`/api/search/movie?query=${encodeURIComponent(query)}`)
      .then(res => res.json())
      .then(data => {
        this.resultsTarget.innerHTML = ""
        data.forEach(movie => {
          const div = document.createElement("div")
          div.className = "p-3 border-b border-gray-100 cursor-pointer hover:bg-purple-50 text-sm"
          div.textContent = movie.title + (movie.year ? ` (${movie.year})` : "")
          div.addEventListener("click", () => this.fill(movie))
          this.resultsTarget.appendChild(div)
        })
        this.resultsTarget.classList.remove("hidden")
      })
  }

    async startScan() {
    this.scannerTarget.classList.remove("hidden")
    const video = document.getElementById("movie-scanner-video")
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
    fetch(`/api/search/movie_barcode?ean=${encodeURIComponent(ean)}`)
      .then(res => res.json())
      .then(data => {
        if (data.error) {
          this.queryTarget.value = ""
          this.queryTarget.placeholder = "Film non trouvé, recherche manuelle..."
          this.queryTarget.focus()
        } else {
          this.fill(data)
        }
      })
  }

  fill(movie) {
    this.titleTarget.value = movie.title || ""
    this.yearTarget.value = movie.year || ""
    this.descriptionTarget.value = movie.description || ""
    this.resultsTarget.classList.add("hidden")

    // Si director/studio déjà dans la réponse (barcode), pas besoin du deuxième fetch
    if (movie.director || movie.studio) {
      this.directorTarget.value = movie.director || ""
      this.studioTarget.value = movie.studio || ""
    } else if (movie.id) {
      fetch(`/api/search/movie_detail/${movie.id}`)
        .then(res => res.json())
        .then(data => {
          this.directorTarget.value = data.director || ""
          this.studioTarget.value = data.studio || ""
        })
    }
  }
}
