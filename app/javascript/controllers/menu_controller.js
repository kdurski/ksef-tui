import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "icon"]
  static values = { open: Boolean }

  connect() {
    console.log("Dropdown controller connected")
    // Initial state: ensure hidden if closed
    if (!this.openValue) {
      this.menuTarget.classList.add("hidden")
      this.menuTarget.classList.add("opacity-0", "scale-95")
      this.menuTarget.classList.remove("opacity-100", "scale-100")
    }
  }

  toggle(event) {
    console.log("Toggle clicked")
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    this.openValue = !this.openValue
  }

  close() {
    this.openValue = false
  }

  openValueChanged() {
    console.log("Open value changed:", this.openValue)
    if (this.openValue) {
      this.showMenu()
    } else {
      this.hideMenu()
    }
  }

  showMenu() {
    console.log("Showing menu")
    this.menuTarget.classList.remove("hidden")

    // Small delay to ensure browser paints 'display: block' before transitioning opacity
    setTimeout(() => {
      this.menuTarget.classList.add("opacity-100", "scale-100")
      this.menuTarget.classList.remove("opacity-0", "scale-95")
      if (this.hasIconTarget) this.iconTarget.classList.add("rotate-180")
    }, 10)
  }

  hideMenu() {
    console.log("Hiding menu")
    this.menuTarget.classList.remove("opacity-100", "scale-100")
    this.menuTarget.classList.add("opacity-0", "scale-95")

    if (this.hasIconTarget) this.iconTarget.classList.remove("rotate-180")

    setTimeout(() => {
      if (!this.openValue) {
        this.menuTarget.classList.add("hidden")
      }
    }, 200)
  }

  hide(event) {
    if (this.element.contains(event.target) === false && this.openValue) {
      this.close()
    }
  }
}
