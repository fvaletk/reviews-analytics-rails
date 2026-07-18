import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { Turbo } from "@hotwired/turbo-rails"

const IN_PROGRESS_LABELS = {
  pending: "Pending…",
  fetching: "Fetching reviews…",
  analyzing: "Analyzing…"
}

// Connects to data-controller="report-status"
//
// Lives on the #report_status wrapper, which contains both the live status
// label AND the three report-generation buttons (Generate Report, Re-analyze,
// Refresh). Whenever the server creates a new report, the whole wrapper is
// swapped in fresh via `turbo_stream.replace "report_status"` (see
// reports/create.turbo_stream.erb) — that new copy is already server-rendered
// with the buttons disabled, and this controller reconnects and opens a new
// ActionCable subscription against the new report's id.
export default class extends Controller {
  static values = {
    reportId: Number,
    hadCompletedReport: Boolean
  }

  // "button" targets are the two secondary buttons (Re-analyze, Refresh),
  // which BRA-74 also gates on whether a report has ever completed.
  // "primaryButton" is "Generate Report", which BRA-74 never gated — it only
  // ever gets disabled by this ticket's in-progress condition, so it's always
  // safe to re-enable once generation stops.
  static targets = ["label", "statusIndicator", "button", "primaryButton"]

  connect() {
    if (!this.hasReportIdValue) return

    this.disableButtons()

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
        // Multiple regions of the page depend on report state (the "Last
        // report" date, the report history list, the buttons). Rather than
        // hand-patch each one, do a full Turbo-powered reload so everything
        // reflects the new server state at once.
        Turbo.visit(window.location, { action: "replace" })
        break
      case "failed":
        this.renderFailed(data.failure_reason)
        this.enableButtonsAfterFailure()
        break
      default:
        this.updateLabel(data.status)
        this.disableButtons()
        break
    }
  }

  updateLabel(status) {
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = IN_PROGRESS_LABELS[status] || status
    }
  }

  renderFailed(failureReason) {
    if (this.hasStatusIndicatorTarget) {
      const reason = this.escapeHtml(failureReason || "Report generation failed.")
      this.statusIndicatorTarget.innerHTML = `<span class="report-status-label report-status-label--failed">${reason}</span>`
    }
  }

  disableButtons() {
    this.buttonTargets.forEach((button) => { button.disabled = true })
    if (this.hasPrimaryButtonTarget) this.primaryButtonTarget.disabled = true
  }

  // "Generate Report" is only ever disabled by this ticket's in-progress
  // condition, so it always re-enables once a report fails. The two
  // secondary buttons are also gated by BRA-74 ("no report has ever
  // completed") — that condition didn't change just because this attempt
  // failed, so only re-enable them if a completed report already existed
  // before this attempt started.
  enableButtonsAfterFailure() {
    if (this.hasPrimaryButtonTarget) this.primaryButtonTarget.disabled = false

    if (this.hadCompletedReportValue) {
      this.buttonTargets.forEach((button) => { button.disabled = false })
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
