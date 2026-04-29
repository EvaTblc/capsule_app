import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "title", "year", "description", "director", "studio"]

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

  fill(movie) {
    this.titleTarget.value = movie.title || ""
    this.yearTarget.value = movie.year || ""
    this.descriptionTarget.value = movie.description || ""
    this.resultsTarget.classList.add("hidden")

    fetch(`/api/search/movie_detail/${movie.id}`)
      .then(res => res.json())
      .then(data => {
        this.directorTarget.value = data.director || ""
        this.studioTarget.value = data.studio || ""
      })
  }
}
