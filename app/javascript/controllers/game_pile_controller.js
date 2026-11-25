import { Controller } from "@hotwired/stimulus"
import BarcodeScanner from "lib/barcode_scanner"

// Connects to data-controller="game-pile"
export default class extends Controller {
  static targets = ["list", "submit", "scanButton", "scanner", "video"]
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
    this.games.filter(game => game.searching).forEach(game => this.lookup(game))
  }

  add(event) {
    this.games.push(event.detail)
    this.save()
    this.render()
  }

  scan(code) {
    navigator.vibrate?.(100)
    const game = { barcode: code, searching: true }
    this.games.push(game)
    this.save()
    this.render()
    this.lookup(game)
  }

  // Jeu d'une boîte scannée : la ligne « Recherche… » se remplit, ou passe en rouge avec la raison
  async lookup(game) {
    const response = await fetch(`/api/search/game_barcode?ean=${encodeURIComponent(game.barcode)}`).catch(() => null)
    const data = await response?.json().catch(() => null)
    if (!response) {
      // Réseau coupé, ou page rechargée en pleine recherche : la pile enregistrée la garde « en recherche », relancée au prochain chargement
      delete game.searching
      game.error = "Recherche impossible pour le moment : elle reprendra à la prochaine ouverture du panneau."
      this.render()
      return
    }
    delete game.searching
    if (response?.ok && data) {
      Object.assign(game, data)
    } else if (response?.status === 429) {
      game.error = "Trop de scans d'un coup : attends une minute, retire ce code et rescanne la boîte."
    } else if (data?.other_kind) {
      game.error = data.error
    } else if (data?.fallback) {
      game.error = "Jeu introuvable pour ce code : retire-le et cherche le jeu par son titre."
    } else {
      game.error = "Recherche impossible pour le moment : retire ce code et rescanne la boîte."
    }
    this.save()
    this.render()
  }

  disconnect() {
    this.scanner?.stop()
  }

  async startScan() {
    this.scannerTarget.classList.remove("hidden")
    this.scanButtonTarget.classList.add("hidden")
    // Caméra et lecture du code : module commun (lecteur du navigateur, sinon lecteur de secours pour iPhone)
    this.scanner = new BarcodeScanner(this.videoTarget, {
      continuous: true,
      onDetect: code => {
        this.scan(code);
      },
      onError: message => {
        this.stopScan()
        alert(message)
      },
    })
    this.scanner.start()
  }

  stopScan() {
    this.scannerTarget.classList.add("hidden")
    this.scanButtonTarget.classList.remove("hidden")
    this.scanner?.stop()
  }

  render() {
    this.listTarget.innerHTML = ""
    this.games.forEach((game, index) => {
      const line = document.createElement("div")
      const remove = document.createElement("button")
      line.textContent = game.name || (game.searching ? `Recherche du code ${game.barcode}…` : `Code ${game.barcode}`)
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
      if (game.error) {
        line.classList.add("text-red-600")
        const errorMessage = document.createElement("p")
        errorMessage.className = "text-xs"
        errorMessage.textContent = game.error
        line.appendChild(errorMessage)
      }
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
    this.submitTarget.disabled = this.games.some(game => game.searching) || this.sending
  }

  async submit() {
    this.sending = true
    for (const game of [ ...this.games]) {
      if (!game.name) continue
      const response = await this.send(game).catch(() => null)
      if (response?.ok) {
        const owned = this.ownedValue
        owned[game.id] = [ ...(owned[game.id] || []), game.platform ]
        this.ownedValue = owned
        this.games = this.games.filter(other => other !== game)
      } else {
        const data = await response?.json().catch(() => null)
        game.error = data?.error || "Pas ajouté : vérifie ta connexion et réessaie."
      }
      this.save()
      this.render()
    }
    this.sending = false
    this.render()
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
    if (game.barcode) data.append("item[barcode]", game.barcode)
    if (game.edition) data.append("video_game_detail[edition]", game.edition)

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
