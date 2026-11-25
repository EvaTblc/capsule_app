import { Controller } from "@hotwired/stimulus"
import BarcodeScanner from "lib/barcode_scanner"

// Connects to data-controller="game-pile"
export default class extends Controller {
  static targets = ["list", "submit", "scanner", "video", "searchRow", "lastFound", "typeButton", "summary"]
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
      if (this.hasLastFoundTarget) {
        this.lastFoundTarget.textContent = `✓ ${game.name}`
        this.lastFoundTarget.classList.remove("hidden")
      }
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

  startScan() {
    this.searchRowTarget.classList.add("hidden")
    this.scannerTarget.classList.remove("hidden")
    this.typeButtonTarget.classList.remove("hidden")
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
    this.lastFoundTarget.classList.add("hidden")
    this.searchRowTarget.classList.remove("hidden")
    this.typeButtonTarget.classList.add("hidden")
    this.scanner?.stop()
  }

  // « Taper un titre » pendant un scan : retour à la recherche, curseur dans le champ
  typeTitle() {
    this.stopScan()
    this.element.querySelector("[data-games-search-target='query']").focus()
  }

  render() {
    this.listTarget.innerHTML = ""
    this.games.forEach((game, index) => {
      const line = document.createElement("div")
      line.className = "flex gap-3 py-2.5 border-b border-gray-100 items-start"

      // Jaquette d'IGDB si on la connaît, sinon un emplacement gris
      const cover = document.createElement(game.cover_url ? "img" : "div")
      if (game.cover_url) {
        cover.src = game.cover_url
        cover.alt = ""
      }
      cover.className = "w-10 h-[54px] rounded-md bg-gray-100 object-cover shrink-0"
      line.appendChild(cover)

      // Colonne du milieu : titre, réglages, messages
      const body = document.createElement("div")
      body.className = "flex-1 min-w-0 flex flex-col gap-1.5"
      line.appendChild(body)

      const title = document.createElement("p")
      title.className = "text-[15px] font-semibold truncate"
      title.textContent = game.name || (game.searching ? `Recherche du code ${game.barcode}…` : `Code ${game.barcode}`)
      body.appendChild(title)

      // Réglages du jeu (seulement s'il a un nom : rien à régler sur « Recherche… » ou un code introuvable)
      if (game.name) {
        const settings = document.createElement("div")
        settings.className = "flex items-center justify-between gap-2"

        // Plateforme à gauche : en violet tant qu'elle n'est pas choisie
        const select = document.createElement("select")
        select.className = `h-[30px] rounded-full border px-2.5 text-[13px] ${game.platform ? "border-gray-200 bg-white text-gray-700" : "border-purple-500 bg-purple-50 text-purple-800 font-semibold"}`
        select.add(new Option("Plateforme ?", ""))
        const choices = game.app_platforms?.length ? game.app_platforms : this.platformsValue
        choices.forEach(platform => select.add(new Option(platform, platform)))
        select.value = game.platform || ""
        select.addEventListener("change", () => {
          game.platform = select.value
          this.save()
          this.render()
        })
        settings.appendChild(select)

        // « Complet » à droite
        const label = document.createElement("label")
        label.className = "flex items-center gap-2 text-[13px] text-gray-700"
        label.textContent = "Complet"
        const checkbox = document.createElement("input")
        checkbox.type = "checkbox"
        checkbox.setAttribute("role", "switch")
        checkbox.className = "appearance-none w-9 h-[22px] rounded-full bg-gray-300 relative cursor-pointer transition-colors checked:bg-purple-700 before:content-[''] before:absolute before:top-[3px] before:left-[3px] before:w-4 before:h-4 before:rounded-full before:bg-white before:transition-transform checked:before:translate-x-[14px]"
        checkbox.checked = game.completed || false
        checkbox.addEventListener("change", () => {
          game.completed = checkbox.checked
          this.save()
        })
        label.appendChild(checkbox)
        settings.appendChild(label)

        body.appendChild(settings)
      }

      // Sous les réglages : même jeu, même plateforme, déjà dans la collection
      const owned = this.ownedValue[game.id] || []
      if (game.platform && owned.includes(game.platform)) {
        const warning = document.createElement("p")
        warning.className = "text-xs text-amber-700"
        warning.textContent = `Déjà dans ta collection sur ${game.platform}`
        body.appendChild(warning)
      }

      const remove = document.createElement("button")
      remove.textContent = "✕"
      remove.type = "button"
      if (game.error) {
        line.classList.add("text-red-600")
        const errorMessage = document.createElement("p")
        errorMessage.className = "text-xs"
        errorMessage.textContent = game.error
        body.appendChild(errorMessage)
      }
      this.listTarget.appendChild(line)
      remove.addEventListener("click", () => {
        this.games.splice(index, 1)
        this.save()
        this.render()
      })
      line.appendChild(remove)
    })
    // Seuls les jeux trouvés partent ; les autres sont expliqués sous le bouton
    const ready = this.games.filter(game => game.name).length
    const searching = this.games.filter(game => game.searching).length
    const missing = this.games.filter(game => !game.name && !game.searching).length

    this.submitTarget.textContent = ready <= 1 ? "Ajouter le jeu" : `Ajouter les ${ready} jeux`
    this.submitTarget.classList.toggle("hidden", this.games.length === 0)
    this.submitTarget.disabled = ready === 0 || searching > 0 || this.sending
    this.summaryTarget.textContent = [
      searching > 0 && (searching === 1 ? "1 recherche en cours" : `${searching} recherches en cours`),
      missing > 0 && (missing === 1 ? "1 code introuvable ne sera pas ajouté" : `${missing} codes introuvables ne seront pas ajoutés`)
    ].filter(Boolean).join(" · ")
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
