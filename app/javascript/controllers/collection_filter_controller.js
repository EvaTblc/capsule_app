import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="collection-filter"
export default class extends Controller {
  static targets = ["search", "pills", "list"]
  static values = { category: String }

  connect() {
    this.activeFilters = {};
    this.buildPills();
  }

  buildPills() {
    const filterConfig = {
      video_games:   ["condition", "platform", "completed"],
      books:         ["condition", "genre"],
      movies:        ["condition", "format"],
      music:         ["condition", "format", "genre"],
      figurines:     ["condition"],
      trading_cards: ["condition"],
      board_games:   ["condition"],
      mixed:         ["condition"],
      other:         ["condition"]
    }
      const category = this.categoryValue
      const filters = filterConfig[category] || ["condition"]

      filters.forEach(filterType => {
        const values = this.getUniqueValues(filterType)
        if (values.length > 0) {
          this.renderPillGroup(filterType, values)
        }
      })
    }

    getUniqueValues(attribute) {
      const items = this.listTarget.querySelectorAll("a[data-title]")
      const values = new Set()

      items.forEach(item => {
        const val = item.dataset[attribute]
        if (val && val !== "") values.add(val)
      })

      return Array.from(values).sort()
    }

    renderPillGroup(filterType, values) {
      const labels = {
        condition: "État",
        platform:  "Plateforme",
        completed: "Complétude",
        genre:     "Genre",
        format:    "Format"
      }

      const displayValues = {
        completed: { true: "Complet", false: "Incomplet" }
      }

      const wrapper = document.createElement("div")
      wrapper.className = "mb-3"

      const label = document.createElement("p")
      label.textContent = labels[filterType] || filterType
      label.className = "text-xs font-semibold text-gray-400 uppercase tracking-widest mb-2"
      wrapper.appendChild(label)

      const group = document.createElement("div")
      group.className = "flex gap-2 flex-wrap"

      values.forEach(value => {
        const pill = document.createElement("button")
        pill.type = "button"

        const display = displayValues[filterType]?.[value] || value
        pill.textContent = display

        pill.className = "px-4 py-2 rounded-full text-xs font-medium border border-gray-200 text-gray-500 bg-white whitespace-nowrap transition-colors duration-150"

        pill.addEventListener("click", () => {
          this.toggleFilter(filterType, value, pill)
        })

        pill.dataset.filterType = filterType
        pill.dataset.filterValue = value

        group.appendChild(pill)
      })

      wrapper.appendChild(group)
      this.pillsTarget.appendChild(wrapper)
    }

    toggleFilter(filterType, value, pill) {
      if (this.activeFilters[filterType] === value) {
        delete this.activeFilters[filterType]
        pill.classList.remove("bg-purple-100", "border-purple-400", "text-purple-600")
        pill.classList.add("bg-white", "border-gray-200", "text-gray-500")
      } else {
        const previousValue = this.activeFilters[filterType]
        if (previousValue) {
          const previousPill = this.pillsTarget.querySelector(
            `button[data-filter-type="${filterType}"][data-filter-value="${previousValue}"]`
          )
          if (previousPill) {
            previousPill.classList.remove("bg-purple-100", "border-purple-400", "text-purple-600")
            previousPill.classList.add("bg-white", "border-gray-200", "text-gray-500")
          }
        }

        this.activeFilters[filterType] = value
        pill.classList.add("bg-purple-100", "border-purple-400", "text-purple-600")
        pill.classList.remove("bg-white", "border-gray-200", "text-gray-500")
      }

      this.filter()
    }

    filter() {
      const query = this.searchTarget.value.toLowerCase().trim()
      const items = this.listTarget.querySelectorAll("a[data-title]")

      items.forEach(item => {
        let visible = true

        if (query && !item.dataset.title.includes(query)) {
          visible = false
        }

        Object.entries(this.activeFilters).forEach(([filterType, value]) => {
          const itemValue = item.dataset[filterType]
          if (itemValue !== value) {
            visible = false
          }
        })

        item.style.display = visible ? "" : "none"
      })
    }
  }
