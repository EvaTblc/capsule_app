import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "author", "publisher", "pages", "genre", "isbn", "description", "scanner"]

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

  searchByIsbn(isbn) {
    this.queryTarget.value = isbn
    fetch(`/api/search/book?query=${encodeURIComponent(isbn)}`)
      .then(res => res.json())
      .then(data => {
        if (data.length > 0) {
          this.fill(data[0])
        } else {
          alert("Aucun livre trouvé pour ce barcode")
        }
      })
  }
  search() {
    const query = this.queryTarget.value
    if (query.length < 3) return

    fetch(`/api/search/book?query=${encodeURIComponent(query)}`)
      .then(res => res.json())
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



  fill(book) {
    const titleInput = this.element.querySelector("input[name='item[title]']")
    if (titleInput) titleInput.value = book.title || ""
    this.titleTarget.value = book.title || ""
    this.authorTarget.value = book.author || ""
    this.publisherTarget.value = book.publisher || ""
    this.pagesTarget.value = book.pages || ""
    this.genreTarget.value = book.genre || ""
    this.isbnTarget.value = book.isbn || ""
    this.descriptionTarget.value = book.description || ""
    this.resultsTarget.classList.add("hidden")
  }
}
