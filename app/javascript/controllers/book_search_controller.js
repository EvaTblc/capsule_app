import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "author", "publisher", "pages", "genre", "isbn", "description", "scanner", "title", "barcode", "wikidataId"]

  async startScan() {
    this.scannerTarget.classList.remove("hidden")

    const video = document.getElementById("book-scanner-video")

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
          const isbn = barcodes[0].rawValue
          this.stopScan()
          this.searchByIsbn(isbn)
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

  // Livre scanné : fiche demandée au serveur par son ISBN (notice BnF, œuvre et résumé de Wikidata / Wikipédia)
  searchByIsbn(isbn) {
    this.queryTarget.value = isbn
    this.loadDetail(isbn)
  }
  search() {
    const query = this.queryTarget.value
    if (query.length < 3) return

    fetch(`/api/search/book?query=${encodeURIComponent(query)}`)
      .then(res => res.json())
      // API en panne ({ error }) ou réponse non JSON : traité comme « aucun résultat »
      .then(data => Array.isArray(data) ? data : [])
      .catch(() => [])
      .then(data => {
        this.resultsTarget.innerHTML = ""
        data.forEach(book => {
          const div = document.createElement("div")
          div.className = "p-3 border-b border-gray-100 cursor-pointer hover:bg-purple-50 text-sm"
          div.textContent = book.title + (book.author ? ` — ${book.author}` : "")
          div.addEventListener("click", () => this.fill(book))
          this.resultsTarget.appendChild(div)
        })
        this.resultsTarget.classList.remove("hidden")
      })
  }

  // Livre choisi dans la recherche : la liste vient de Google Books (affichage seulement), la fiche de la BnF.
  // Rien de Google n'est enregistré : leurs conditions interdisent d'en garder des copies
  fill(book) {
    this.resultsTarget.classList.add("hidden")
    if (!book.isbn) return this.showMessage("Fiche indisponible pour ce livre (pas d'ISBN) : complète-la à la main.")
    this.loadDetail(book.isbn)
  }

  loadDetail(isbn) {
    fetch(`/api/search/book_detail/${encodeURIComponent(isbn)}`)
      .then(res => res.json())
      .catch(() => ({ error: "Fiche indisponible pour le moment : complète-la à la main." }))
      .then(data => data.error ? this.showMessage(data.error) : this.fillFromCatalog(data))
  }

  fillFromCatalog(book) {
    const titleInput = this.element.querySelector("input[name='item[title]']")
    if (titleInput) titleInput.value = book.title || ""
    this.authorTarget.value = book.author || ""
    this.publisherTarget.value = book.publisher || ""
    this.pagesTarget.value = book.pages || ""
    this.genreTarget.value = book.genre || ""
    this.isbnTarget.value = book.isbn || ""
    this.descriptionTarget.value = book.description || ""
    if (this.hasBarcodeTarget) this.barcodeTarget.value = book.barcode || ""
    if (this.hasWikidataIdTarget) this.wikidataIdTarget.value = book.wikidata_id || ""
    this.resultsTarget.classList.add("hidden")
  }

  // Message dans la liste de résultats (textContent : aucun HTML interprété)
  showMessage(text) {
    this.resultsTarget.innerHTML = ""
    const message = document.createElement("div")
    message.className = "p-3 text-sm text-red-600"
    message.textContent = text
    this.resultsTarget.appendChild(message)
    this.resultsTarget.classList.remove("hidden")
  }
}
