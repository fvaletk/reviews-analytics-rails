import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop"]

  open() {
    this.backdropTarget.classList.add("delete-modal-backdrop--visible")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.backdropTarget.classList.remove("delete-modal-backdrop--visible")
    document.body.style.overflow = ""
  }
}
