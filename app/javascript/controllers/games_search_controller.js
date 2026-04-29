import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "title", "platform", "genre", "developer", "release_date", "description"]

  search() {
    const query = this.queryTarget.value
    if (query.length < 3) return

    fetch(`/api/search/game?query=${encodeURIComponent(query)}`)
      .then(res => res.json())
      .then(data => {
        this.resultsTarget.innerHTML = ""
        data.forEach(game => {
          const div = document.createElement("div")
          div.className = "p-3 border-b border-gray-100 cursor-pointer hover:bg-purple-50 text-sm"
          div.textContent = game.title
          div.addEventListener("click", () => this.fill(game))
          this.resultsTarget.appendChild(div)
        })
        this.resultsTarget.classList.remove("hidden")
      })
  }

  fill(game) {
    this.titleTarget.value = game.title || ""
    this.platformTarget.value = game.platform || ""
    this.genreTarget.value = game.genre || ""
    this.release_dateTarget.value = game.release_date || ""
    this.resultsTarget.classList.add("hidden")

    fetch(`/api/search/game_detail/${game.id}`)
      .then(res => res.json())
      .then(data => {
        this.descriptionTarget.value = data.description || ""
        this.developerTarget.value = data.developer || ""
      })
  }
}
