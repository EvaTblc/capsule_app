import { Controller } from "@hotwired/stimulus"
import BarcodeScanner from "lib/barcode_scanner"

export default class extends Controller {
  static targets = ["query", "results", "title", "year", "description", "director", "studio", "format", "edition", "barcode", "tmdbId", "scanner"]

  search() {
    const query = this.queryTarget.value
    if (query.length < 3) return

    fetch(`/api/search/movie?query=${encodeURIComponent(query)}`)
      .then(res => res.json())
      // API en panne ({ error }) ou réponse non JSON : traité comme « aucun résultat »
      .then(data => Array.isArray(data) ? data : [])
      .catch(() => [])
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
    // Caméra et lecture du code : module commun (lecteur du navigateur, sinon lecteur de secours pour iPhone)
    this.scanner = new BarcodeScanner(document.getElementById("movie-scanner-video"), {
      onDetect: code => {
        this.scannerTarget.classList.add("hidden")
        this.searchByBarcode(code)
      },
      onError: message => {
        this.scannerTarget.classList.add("hidden")
        this.showMessage(message, true)
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

  searchByBarcode(ean) {
    this.queryTarget.value = ean
    this.showMessage(`Recherche du code-barres ${ean}…`)
    fetch(`/api/search/movie_barcode?ean=${encodeURIComponent(ean)}`)
      .then(res => res.json())
      // Réseau coupé ou réponse non JSON (ex : 429 du rate limit) : même traitement qu'un film non trouvé
      .catch(() => ({ error: true }))
      .then(data => {
        if (data.error) {
          this.queryTarget.value = ""
          this.queryTarget.placeholder = "Tape le titre du film..."
          // premium : compte free, le serveur refuse le scan (403)
          // other_kind : code d'un autre type (livre scanné ici...), le serveur explique lequel
          // unavailable : film reconnu mais absent du catalogue, à compléter à la main
          const message = data.other_kind || data.unavailable ? data.error
            : data.premium ? `${data.error} Tape le titre du film ci-dessus.`
            : data.fallback ? "Film introuvable pour ce code-barres : tape son titre ci-dessus."
            : "Recherche indisponible pour le moment : tape le titre du film ci-dessus."
          this.showMessage(message, true)
          this.queryTarget.focus()
        } else {
          this.fillFromCatalog(data)
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

  // Film choisi dans la recherche : la liste vient de TMDB (affichage seulement), la fiche du catalogue
  // (Wikidata, Wikipédia) est demandée au serveur. Rien de TMDB n'est enregistré : leurs conditions l'interdisent
  fill(movie) {
    this.resultsTarget.classList.add("hidden")
    this.queryTarget.value = movie.title || ""
    fetch(`/api/search/movie_detail/${movie.id}`)
      .then(res => res.json())
      .catch(() => ({ error: "Fiche indisponible pour le moment : complète-la à la main." }))
      .then(data => data.error ? this.showMessage(data.error, true) : this.fillFromCatalog(data))
  }

  // Fiche du catalogue (réponse de movie_detail ou du scan) ; tmdb_id repart avec le formulaire pour relier l'œuvre
  fillFromCatalog(movie) {
    this.titleTarget.value = movie.title || ""
    this.yearTarget.value = movie.year || ""
    this.descriptionTarget.value = movie.description || ""
    this.directorTarget.value = movie.director || ""
    this.studioTarget.value = movie.studio || ""
    if (this.hasTmdbIdTarget) this.tmdbIdTarget.value = movie.tmdb_id || ""
    // Lus sur la boîte au scan (absents d'une recherche par titre : on ne touche pas à la saisie)
    if (movie.format) this.formatTarget.value = movie.format
    if (movie.edition) this.editionTarget.value = movie.edition
    if (this.hasBarcodeTarget && movie.barcode) this.barcodeTarget.value = movie.barcode
    this.resultsTarget.classList.add("hidden")
  }
}
