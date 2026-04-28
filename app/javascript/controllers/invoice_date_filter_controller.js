import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "trigger", "icon"]
  static values = { open: Boolean }

  connect() {
    this.syncState()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.openValue = !this.openValue
  }

  close() {
    if (!this.openValue) return

    this.openValue = false
  }

  hide(event) {
    if (!this.openValue) return
    if (this.element.contains(event.target)) return

    this.close()
  }

  openValueChanged() {
    this.syncState()
  }

  syncState() {
    this.panelTarget.classList.toggle("hidden", !this.openValue)
    this.triggerTarget.setAttribute("aria-expanded", String(this.openValue))

    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-180", this.openValue)
    }
  }
}
