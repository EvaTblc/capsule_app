import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results", "title", "author", "publisher", "pages", "genre", "isbn", "description"]

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
