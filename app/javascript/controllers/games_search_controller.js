import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "platform", "genre", "releaseDate", "description", "scanner", "title"]

  connect() {
    this.closeResults = (e) => {
      if (!this.element.contains(e.target)) {
        this.resultsTarget.classList.add("hidden")
      }
    }
    document.addEventListener("click", this.closeResults)
  }

  disconnect() {
    document.removeEventListener("click", this.closeResults)
  }

  search() {
    const query = this.queryTarget.value
    if (query.length < 4) return

    clearTimeout(this.searchTimeout)

    // Annuler la requête précédente si elle est encore en cours
    if (this.abortController) {
      this.abortController.abort()
    }

    this.searchTimeout = setTimeout(() => {
      this.abortController = new AbortController()

      fetch(`/api/search/search_game?query=${encodeURIComponent(query)}`, {
        signal: this.abortController.signal
      })
        .then(res => res.json())
        .then(data => {
          this.resultsTarget.innerHTML = ""
          const games = data.games || []
          games.forEach(game => {
            const div = document.createElement("div")
            div.className = "p-3 border-b border-gray-100 cursor-pointer hover:bg-purple-50 text-sm"
            div.textContent = game.name + (game.release_date ? ` — ${game.release_date}` : "")
            // Titre d'origine en petit quand le titre affiché est le titre français
            if (game.original_name) {
              const original = document.createElement("p")
              original.className = "text-xs text-gray-400"
              original.textContent = game.original_name
              div.appendChild(original)
            }
            div.addEventListener("click", () => this.fill(game))
            this.resultsTarget.appendChild(div)
          })
          this.resultsTarget.classList.remove("hidden")
        })
        .catch(err => {
          if (err.name !== "AbortError") console.log(err)
        })
    }, 400)
  }

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
    // Code-barres → nom → IGDB → traduction : plusieurs secondes, on le montre
    this.showMessage(`Recherche du code-barres ${ean}…`)
    fetch(`/api/search/game_barcode?ean=${encodeURIComponent(ean)}`)
      .then(res => res.json())
      // Réseau coupé ou réponse non JSON (ex : 429 du rate limit) : même traitement qu'un jeu non trouvé
      .catch(() => ({ error: true }))
      .then(data => {
        if (data.error) {
          this.queryTarget.value = ""
          this.queryTarget.placeholder = "Tape le nom du jeu..."
          // premium : compte free, le serveur refuse le scan (403)
          const message = data.premium ? `${data.error} Tape le nom du jeu ci-dessus.`
            : data.fallback ? "Jeu introuvable pour ce code-barres : tape son nom ci-dessus."
            : "Recherche indisponible pour le moment : tape le nom du jeu ci-dessus."
          this.showMessage(message, true)
          this.queryTarget.focus()
        } else {
          this.fill(data)
        }
      })
  }

  // Message dans la liste de résultats (textContent : aucun HTML interprété)
  showMessage(text, isError = false) {
    this.resultsTarget.innerHTML = ""
    const message = document.createElement("div")
    message.className = `p-3 text-sm ${isError ? "text-red-600" : "text-gray-500"}`
    message.textContent = text
    this.resultsTarget.appendChild(message)
    this.resultsTarget.classList.remove("hidden")
  }

  selectPlatform(event) {
    const selected = event.currentTarget.dataset.platform
    this.platformTarget.value = selected
    const buttons = event.currentTarget.closest('.flex').querySelectorAll('button')
    buttons.forEach(btn => {
      if (btn.dataset.platform === selected) {
        btn.classList.add('bg-purple-100', 'border-purple-400', 'text-purple-600')
        btn.classList.remove('bg-white', 'border-gray-200', 'text-gray-500')
      } else {
        btn.classList.remove('bg-purple-100', 'border-purple-400', 'text-purple-600')
        btn.classList.add('bg-white', 'border-gray-200', 'text-gray-500')
      }
    })
  }

  fill(game) {
    if (this.hasTitleTarget) this.titleTarget.value = game.name || ""
    if (this.hasPlatformTarget) this.platformTarget.value = game.platforms || ""
    if (this.hasGenreTarget) this.genreTarget.value = game.genres || ""
    if (this.hasReleaseDateTarget) this.releaseDateTarget.value = game.release_date || ""
    if (this.hasDescriptionTarget) this.descriptionTarget.value = game.summary || ""
    if (this.hasQueryTarget) this.queryTarget.value = game.name || ""

    const metadataInput = this.element.querySelector("input[name='item[metadata]']")
    if (metadataInput) metadataInput.value = JSON.stringify(game.metadata || {})

    const coverInput = this.element.querySelector("input[name='item[cover_url]']")
    if (coverInput) coverInput.value = game.cover_url || ""

    this.resultsTarget.classList.add("hidden")
  }
}
