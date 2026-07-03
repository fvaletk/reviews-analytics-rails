import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

const IN_PROGRESS_LABELS = {
  pending: "Pending…",
  fetching: "Fetching reviews…",
  analyzing: "Analyzing…"
}

// Connects to data-controller="report-status"
export default class extends Controller {
  static values = {
    reportId: Number,
    viewReportUrl: String,
    retryUrl: String
  }

  static targets = ["label"]

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "ReportChannel", report_id: this.reportIdValue },
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
    switch (data.status) {
      case "complete":
        this.renderComplete()
        break
      case "failed":
        this.renderFailed(data.failure_reason)
        break
      default:
        this.updateLabel(data.status)
        break
    }
  }

  updateLabel(status) {
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = IN_PROGRESS_LABELS[status] || status
    }
  }

  renderComplete() {
    this.element.innerHTML = `<a href="${this.viewReportUrlValue}" class="report-status-view-link">View Report</a>`
  }

  renderFailed(failureReason) {
    const reason = this.escapeHtml(failureReason || "Report generation failed.")

    this.element.innerHTML = `
      <div class="report-status-failed">
        <p class="report-status-failed-reason">${reason}</p>
        <form method="post" action="${this.retryUrlValue}" class="report-status-retry-form">
          <button type="submit" class="report-status-retry-button">Retry</button>
        </form>
      </div>
    `
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
