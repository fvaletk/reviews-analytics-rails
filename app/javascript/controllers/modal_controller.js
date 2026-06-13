import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
  }

  open() {
    this.dialogTarget.setAttribute("aria-hidden", "false")
    this.dialogTarget.classList.add("modal--open")
    document.addEventListener("keydown", this.boundKeydown)
  }

  close() {
    this.dialogTarget.setAttribute("aria-hidden", "true")
    this.dialogTarget.classList.remove("modal--open")
    document.removeEventListener("keydown", this.boundKeydown)
  }

  backdropClick(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }
}
