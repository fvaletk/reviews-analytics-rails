import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundClickOutside = this.clickOutside.bind(this)
  }

  toggle() {
    this.element.classList.toggle("open")

    if (this.element.classList.contains("open")) {
      document.addEventListener("click", this.boundClickOutside)
    } else {
      document.removeEventListener("click", this.boundClickOutside)
    }
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.element.classList.remove("open")
      document.removeEventListener("click", this.boundClickOutside)
    }
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }
}
