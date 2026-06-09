import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["noteForm", "eventForm", "noteBtn", "eventBtn", "noteTitle", "eventTitle"]

  showNote() {
    this.noteFormTarget.classList.remove("hidden")
    this.eventFormTarget.classList.add("hidden")
    this.noteTitleTarget.classList.remove("hidden")
    this.eventTitleTarget.classList.add("hidden")

    this.noteBtnTarget.classList.add("bg-white", "text-gray-900", "shadow-sm")
    this.noteBtnTarget.classList.remove("text-gray-400")
    this.eventBtnTarget.classList.remove("bg-white", "text-gray-900", "shadow-sm")
    this.eventBtnTarget.classList.add("text-gray-400")
  }

  showEvent() {
    this.eventFormTarget.classList.remove("hidden")
    this.noteFormTarget.classList.add("hidden")
    this.eventTitleTarget.classList.remove("hidden")
    this.noteTitleTarget.classList.add("hidden")

    this.eventBtnTarget.classList.add("bg-white", "text-gray-900", "shadow-sm")
    this.eventBtnTarget.classList.remove("text-gray-400")
    this.noteBtnTarget.classList.remove("bg-white", "text-gray-900", "shadow-sm")
    this.noteBtnTarget.classList.add("text-gray-400")
  }
}
