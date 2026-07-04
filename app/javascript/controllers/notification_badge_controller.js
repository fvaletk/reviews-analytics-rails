import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Connects to data-controller="notification-badge"
export default class extends Controller {
  static targets = ["count"]

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "NotificationChannel" },
      { received: (data) => this.received(data) }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.consumer.subscriptions.remove(this.subscription)
      this.subscription = null
    }
  }

  received(data) {
    this.updateCount(data.unread_count)
  }

  updateCount(count) {
    if (this.hasCountTarget) {
      this.countTarget.textContent = count
    }

    if (count > 0) {
      this.element.classList.remove("is-hidden")
    } else {
      this.element.classList.add("is-hidden")
    }
  }
}
