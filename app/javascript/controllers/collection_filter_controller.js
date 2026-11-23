import { Controller } from "@hotwired/stimulus"

// Page d'une collection : recherche instantanée, filtres rapides, tri, et affichage en grille ou en liste.
// Tout se passe dans la page : chaque item porte ses valeurs en data-* (calculées par CollectionFiltersHelper),
// on masque, réordonne ou change de vue sans recharger. Tri et vue sont retenus par le navigateur.
export default class extends Controller {
  static targets = ["search", "list", "gridButton", "listButton", "facetChip", "completeChip", "count", "sort"]

  connect() {
    this.facet = ""
    this.completeOnly = false
    if (!this.hasListTarget) return // collection vide : rien à filtrer ni à afficher

    this.total = this.items().length
    this.applyView(this.load("collection-view") === "list" ? "list" : "grid")
    const savedSort = this.load("collection-sort")
    if (this.hasSortTarget && [...this.sortTarget.options].some(option => option.value === savedSort)) {
      this.sortTarget.value = savedSort
      this.sort()
    }
  }

  items() {
    return [...this.listTarget.querySelectorAll("a[data-search]")]
  }

  // --- Filtres ---

  pickFacet(event) {
    this.facet = event.currentTarget.dataset.facet
    this.facetChipTargets.forEach(chip => chip.setAttribute("aria-pressed", chip === event.currentTarget))
    this.filter()
  }

  toggleComplete() {
    this.completeOnly = !this.completeOnly
    this.completeChipTarget.setAttribute("aria-pressed", this.completeOnly)
    this.filter()
  }

  filter() {
    const words = this.hasSearchTarget ? this.normalize(this.searchTarget.value).split(/\s+/).filter(Boolean) : []
    let visible = 0

    this.items().forEach(item => {
      const shown = words.every(word => item.dataset.search.includes(word)) &&
        (this.facet === "" || item.dataset.facet === this.facet) &&
        (!this.completeOnly || item.dataset.complete === "true")
      item.hidden = !shown
      if (shown) visible++
    })

    this.updateCount(visible)
    this.toggleEmptyMessage(visible === 0)
  }

  // « Pokémon Épée » et « pokemon epee » se retrouvent (comme item_search_text côté serveur)
  normalize(text) {
    return text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase().trim()
  }

  updateCount(visible) {
    if (!this.hasCountTarget) return
    const label = count => `${count} item${count > 1 ? "s" : ""}`
    this.countTarget.textContent = visible === this.total ? label(this.total) : `${label(visible)} sur ${this.total}`
  }

  toggleEmptyMessage(empty) {
    let message = this.listTarget.querySelector(".no-results")
    if (empty && !message) {
      message = document.createElement("div")
      message.className = "no-results col-span-full py-12 text-center"
      const title = document.createElement("p")
      title.className = "text-sm font-semibold text-gray-600"
      title.textContent = "Aucun résultat"
      const hint = document.createElement("p")
      hint.className = "text-xs text-gray-500 mt-1"
      hint.textContent = "Essaie d'autres mots ou d'autres filtres"
      message.append(title, hint)
      this.listTarget.appendChild(message)
    } else if (!empty && message) {
      message.remove()
    }
  }

  // --- Tri ---

  sort() {
    const by = this.sortTarget.value
    const compare = {
      title: (a, b) => a.dataset.position - b.dataset.position, // ordre naturel calculé par le serveur
      recent: (a, b) => b.dataset.added - a.dataset.added,
      secondary: (a, b) => a.dataset.secondary.localeCompare(b.dataset.secondary, "fr") || a.dataset.position - b.dataset.position
    }[by] || ((a, b) => a.dataset.position - b.dataset.position)

    const message = this.listTarget.querySelector(".no-results")
    this.items().sort(compare).forEach(item => this.listTarget.appendChild(item))
    if (message) this.listTarget.appendChild(message)
    this.save("collection-sort", by)
  }

  // --- Grille ou liste ---

  showGrid() { this.applyView("grid", { save: true }) }
  showList() { this.applyView("list", { save: true }) }

  applyView(view, { save = false } = {}) {
    this.listTarget.dataset.view = view
    if (this.hasGridButtonTarget) this.gridButtonTarget.setAttribute("aria-pressed", view === "grid")
    if (this.hasListButtonTarget) this.listButtonTarget.setAttribute("aria-pressed", view === "list")
    if (save) this.save("collection-view", view)
  }

  // Préférences du navigateur : peuvent être indisponibles (navigation privée), l'appli marche quand même
  load(key) {
    try { return localStorage.getItem(`capsule:${key}`) } catch (e) { return null }
  }

  save(key, value) {
    try { localStorage.setItem(`capsule:${key}`, value) } catch (e) { /* non retenu */ }
  }
}
