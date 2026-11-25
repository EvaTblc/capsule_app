import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="game-pile"
export default class extends Controller {
  static targets = ["list", "submit"]
  static values = { collection: Number, platforms: Array, url: String, owned: Object }

  get storageKey() {
    return `game-pile-${this.collectionValue}`
  }

  connect() {
    try {
      this.games = JSON.parse(localStorage.getItem(this.storageKey)) || []
    } catch {
      this.games = []
    }
    this.render()
  }

  add(event) {
    this.games.push(event.detail)
    this.save()
    this.render()
  }

  render() {
    this.listTarget.innerHTML = ""
    this.games.forEach((game, index) => {
      const line = document.createElement("div")
      const remove = document.createElement("button")
      line.textContent = game.name
      const select = document.createElement("select")
      select.add(new Option("Plateforme ?", ""))
      const choices = game.app_platforms?.length ? game.app_platforms : this.platformsValue
      choices.forEach(platform => select.add(new Option(platform, platform)))
      select.value = game.platform || ""
      select.addEventListener("change", () => {
        game.platform = select.value
        this.save()
        this.render()
      })
      line.appendChild(select)
      const owned = this.ownedValue[game.id] || []
      if (game.platform && owned.includes(game.platform)) {
        const warning = document.createElement("p")
        warning.className = "text-xs text-amber-600"
        warning.textContent = `Déjà dans ta collection sur ${game.platform}`
        line.appendChild(warning)
      }
      const label = document.createElement("label")
      label.textContent = "Complet"
      const checkbox = document.createElement("input")
      checkbox.type = "checkbox"
      checkbox.checked = game.completed || false
      label.appendChild(checkbox)
      line.appendChild(label)
      checkbox.addEventListener("change", () => {
        game.completed = checkbox.checked
        this.save()
      })
      remove.textContent = "✕"
      remove.type = "button"
      line.className = "flex items-center justify-between text-sm"
      if (game.error) line.classList.add("text-red-600")
      this.listTarget.appendChild(line)
      remove.addEventListener("click", () => {
        this.games.splice(index, 1)
        this.save()
        this.render()
      })
      line.appendChild(remove)
    })
    this.submitTarget.textContent = this.games.length <= 1 ? "Ajouter le jeu" : `Ajouter les ${this.games.length} jeux`
    this.submitTarget.classList.toggle("hidden", this.games.length === 0)
  }

  async submit() {
    this.submitTarget.disabled = true
    for (const game of [ ...this.games]) {
      const response = await this.send(game).catch(() => null)
      if (response?.ok) {
        const owned = this.ownedValue
        owned[game.id] = [ ...(owned[game.id] || []), game.platform ]
        this.ownedValue = owned
        this.games = this.games.filter(other => other !== game)
      } else {
        game.error = true
      }
      this.save()
      this.render()
    }
    this.submitTarget.disabled = false
  }

  async send(game) {
    const data = new FormData()
    data.append("quick_add", "1")
    data.append("item[item_type]", "VideoGameDetail")
    data.append("item[title]", game.name)
    data.append("video_game_detail[platform]", game.platform || "")
    data.append("video_game_detail[summary_en]", game.summary || "")
    data.append("video_game_detail[genre]", game.genres || "")
    data.append("video_game_detail[release_date]", game.release_date || "")
    data.append("video_game_detail[developer]", game.developer || "")
    data.append("product[igdb_id]", game.id || "")
    if (game.completed) data.append("video_game_detail[completed]", 1)

    return fetch(this.urlValue, {
      method: "POST",
      body: data,
      headers: { "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || "" }
    })
  }

  save() {
    try {
      localStorage.setItem(this.storageKey, JSON.stringify(this.games))
    } catch {}
  }
}
