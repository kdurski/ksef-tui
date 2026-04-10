import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["state", "errorBox"]
  static values = {
    loginRequestId: Number,
    statusUrl: String
  }

  connect() {
    this.active = true
    this.completed = false
    this.startSubscription()
    this.checkStatus()
  }

  disconnect() {
    this.active = false
    this.stopFallback()
    this.subscription?.unsubscribe()
  }

  startSubscription() {
    this.subscription = consumer.subscriptions.create(
      { channel: "LoginRequestStatusChannel", login_request_id: this.loginRequestIdValue },
      {
        connected: () => {
          this.stopFallback()
        },
        disconnected: () => {
          if (!this.active || this.completed) return
          this.startFallback()
        },
        received: (payload) => {
          this.handlePayload(payload)
        }
      }
    )
  }

  startFallback() {
    if (this.fallbackTimer) return

    this.fallbackTimer = setInterval(() => {
      if (!this.active || this.completed) return
      this.checkStatus()
    }, 2000)
  }

  stopFallback() {
    if (!this.fallbackTimer) return

    clearInterval(this.fallbackTimer)
    this.fallbackTimer = null
  }

  async checkStatus() {
    try {
      const response = await fetch(this.statusUrlValue, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) {
        this.showError("Could not check login status.")
        return
      }

      const payload = await response.json()
      this.handlePayload(payload)
    } catch (_error) {
      this.showError("Temporary connection issue while checking status.")
    }
  }

  handlePayload(payload) {
    this.stateTarget.textContent = this.humanStatus(payload.status)

    if (payload.status === "succeeded" && payload.finalize_url) {
      this.completed = true
      this.stopFallback()
      window.location.assign(payload.finalize_url)
      return
    }

    if (payload.status === "failed") {
      this.completed = true
      this.stopFallback()
      this.showError(payload.error_message || "Authentication failed.")
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
