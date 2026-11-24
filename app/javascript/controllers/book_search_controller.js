import { Controller } from "@hotwired/stimulus"
import BarcodeScanner from "lib/barcode_scanner"

export default class extends Controller {
  static targets = ["query", "searchButton", "results", "author", "publisher", "pages", "genre", "isbn", "description", "scanner", "title", "barcode", "wikidataId"]

  connect() {
    this.requestId = 0 // seule la réponse de la dernière demande est affichée
  }

  async startScan() {
    this.scannerTarget.classList.remove("hidden")
    // Caméra et lecture du code : module commun (lecteur du navigateur, sinon lecteur de secours pour iPhone)
    this.scanner = new BarcodeScanner(document.getElementById("book-scanner-video"), {
      onDetect: code => {
        this.scannerTarget.classList.add("hidden")
        this.searchByIsbn(code)
      },
      onError: message => {
        this.scannerTarget.classList.add("hidden")
        this.showMessage(message)
      }
    })
    this.scanner.start()
  }

  stopScan() {
    this.scannerTarget.classList.add("hidden")
    this.scanner?.stop()
  }

  // Formulaire quitté (Turbo) scanner ouvert : la caméra est rendue
  disconnect() {
    this.scanner?.stop()
  }

  // Livre scanné : fiche demandée au serveur par son ISBN (notice BnF, œuvre et résumé de Wikidata / Wikipédia)
  searchByIsbn(isbn) {
    this.queryTarget.value = isbn
    this.loadDetail(isbn)
  }
  // Recherche lancée par le bouton « Chercher » ou la touche Entrée (pas à chaque lettre : la BnF peut être lente).
  // ISBN tapé (13 chiffres, tirets acceptés) : fiche directe ; sinon liste des éditions de la BnF
  search() {
    const query = this.queryTarget.value.trim()
    const isbn = query.replace(/[\s-]/g, "")
    if (/^97[89]\d{10}$/.test(isbn)) return this.loadDetail(isbn)
    if (query.length < 2) return this.showMessage("Tape au moins 2 lettres du titre.", { info: true })

    const request = ++this.requestId
    this.showMessage("Recherche à la BnF…", { info: true })
    this.setBusy(true)
    fetch(`/api/search/book?query=${encodeURIComponent(query)}`)
      .then(res => res.json())
      .catch(() => ({ error: "Recherche indisponible pour le moment : réessaie, ou complète la fiche à la main." }))
      .then(data => {
        if (request !== this.requestId) return // une recherche plus récente a été lancée entre-temps
        this.setBusy(false)
        if (!Array.isArray(data)) return this.showMessage(data.error || "Recherche indisponible pour le moment.")
        if (data.length === 0) return this.showMessage(`Aucun livre trouvé à la BnF pour « ${query} » : vérifie le titre, ou complète la fiche à la main.`)
        this.showResults(data)
      })
  }

  // Une ligne par édition : « L'atelier des sorciers, tome 10 », puis « Kamome Shirahama · Pika édition, 2022 »
  showResults(books) {
    this.resultsTarget.innerHTML = ""
    books.forEach(book => {
      const line = document.createElement("div")
      line.className = "p-3 border-b border-gray-100 cursor-pointer hover:bg-purple-50 text-sm"
      const title = document.createElement("div")
      title.textContent = book.title + (book.volume ? `, tome ${book.volume}` : "")
      const details = document.createElement("div")
      details.className = "text-xs text-gray-500"
      details.textContent = [book.author, [book.publisher, book.year].filter(Boolean).join(", ")].filter(Boolean).join(" · ")
      line.append(title, details)
      line.addEventListener("click", () => this.loadDetail(book.isbn))
      this.resultsTarget.appendChild(line)
    })
    this.resultsTarget.classList.remove("hidden")
  }

  // Fiche d'une édition par son ISBN : notice de la BnF, œuvre et résumé de Wikidata / Wikipédia
  loadDetail(isbn) {
    const request = ++this.requestId
    this.showMessage("Chargement de la fiche…", { info: true })
    fetch(`/api/search/book_detail/${encodeURIComponent(isbn)}`)
      .then(res => res.json())
      .catch(() => ({ error: "Fiche indisponible pour le moment : complète-la à la main." }))
      .then(data => {
        if (request !== this.requestId) return
        data.error ? this.showMessage(data.error) : this.fillFromCatalog(data)
      })
  }

  setBusy(busy) {
    if (!this.hasSearchButtonTarget) return
    this.searchButtonTarget.disabled = busy
    this.searchButtonTarget.textContent = busy ? "…" : "Chercher"
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

  // Message dans la liste de résultats (textContent : aucun HTML interprété) ; info : attente, en gris
  showMessage(text, { info = false } = {}) {
    this.resultsTarget.innerHTML = ""
    const message = document.createElement("div")
    message.className = `p-3 text-sm ${info ? "text-gray-500" : "text-red-600"}`
    message.textContent = text
    this.resultsTarget.appendChild(message)
    this.resultsTarget.classList.remove("hidden")
  }
}
