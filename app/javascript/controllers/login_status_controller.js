import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["state", "errorBox"]
  static values = { url: String }

  connect() {
    this.poll()
    this.interval = setInterval(() => this.poll(), 1500)
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) {
        this.showError("Could not check login status.")
        return
      }

      const payload = await response.json()
      this.stateTarget.textContent = this.humanStatus(payload.status)

      if (payload.status === "succeeded" && payload.finalize_url) {
        this.disconnect()
        window.location.assign(payload.finalize_url)
      } else if (payload.status === "failed") {
        this.disconnect()
        this.showError(payload.error_message || "Authentication failed.")
      }
    } catch (_error) {
      this.showError("Temporary connection issue while checking status.")
    }
  }

  humanStatus(status) {
    switch (status) {
      case "pending":
        return "Waiting for KSeF..."
      case "succeeded":
        return "Completed. Redirecting..."
      case "failed":
        return "Authentication failed."
      default:
        return "Processing..."
    }
  }

  showError(message) {
    this.errorBoxTarget.textContent = message
    this.errorBoxTarget.classList.remove("hidden")
    this.stateTarget.textContent = "Failed."
  }
}
