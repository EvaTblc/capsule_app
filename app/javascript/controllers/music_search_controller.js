import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "title", "artist", "year", "label", "format", "genre"]

  search() {
    const query = this.queryTarget.value
    if (query.length < 3) return

    fetch(`/api/search/music?query=${encodeURIComponent(query)}`)
      .then(res => res.json())
      .then(data => {
        this.resultsTarget.innerHTML = ""
        data.forEach(release => {
          const div = document.createElement("div")
          div.className = "p-3 border-b border-gray-100 cursor-pointer hover:bg-purple-50 text-sm"
          div.textContent = release.title + (release.year ? ` (${release.year})` : "")
          div.addEventListener("click", () => this.fill(release))
          this.resultsTarget.appendChild(div)
        })
        this.resultsTarget.classList.remove("hidden")
      })
  }

  fill(release) {
    this.titleTarget.value = release.title || ""
    this.yearTarget.value = release.year || ""
    this.labelTarget.value = release.label || ""
    this.formatTarget.value = release.format || ""
    this.genreTarget.value = release.genre || ""
    this.resultsTarget.classList.add("hidden")

    fetch(`/api/search/music_detail/${release.id}`)
      .then(res => res.json())
      .then(data => {
        this.artistTarget.value = data.artist || ""
      })
  }
}
