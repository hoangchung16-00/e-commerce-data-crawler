import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["urlInput", "submitBtn", "resultContainer", "resultMessage"]

  async scrape(event) {
    event.preventDefault()

    const url = this.urlInputTarget.value.trim()

    if (!url) {
      this.showError("Please enter a product URL")
      return
    }

    // Disable submit button and show loading state
    this.submitBtnTarget.disabled = true
    this.submitBtnTarget.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Scraping...'

    try {
      const formData = new FormData()
      formData.append("url", url)

      const response = await fetch(this.element.action, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.getCsrfToken()
        },
        body: formData
      })

      const data = await response.json()

      if (data.success) {
        this.showSuccess(data.message, data.product)
        this.urlInputTarget.value = ""
      } else {
        this.showError(data.error)
      }
    } catch (error) {
      this.showError(`Network error: ${error.message}`)
    } finally {
      this.submitBtnTarget.disabled = false
      this.submitBtnTarget.innerHTML = 'Scrape Product'
    }
  }

  showSuccess(message, product) {
    this.resultContainerTarget.classList.remove("d-none")
    this.resultContainerTarget.classList.remove("alert-danger")
    this.resultContainerTarget.classList.add("alert-success")
    
    let html = `<strong>✓ ${message}</strong><br>`
    if (product) {
      html += `<small class="text-muted">
        <strong>${product.name}</strong><br>
        Price: <strong>${this.formatPrice(product.price)}</strong>
        ${product.discount_rate ? ` | Discount: <strong>-${product.discount_rate}%</strong>` : ""}
      </small>`
    }
    
    this.resultMessageTarget.innerHTML = html
  }

  showError(message) {
    this.resultContainerTarget.classList.remove("d-none")
    this.resultContainerTarget.classList.remove("alert-success")
    this.resultContainerTarget.classList.add("alert-danger")
    this.resultMessageTarget.innerHTML = `<strong>✗ Error:</strong> ${message}`
  }

  formatPrice(price) {
    if (!price) return "N/A"
    return new Intl.NumberFormat('vi-VN', {
      style: 'currency',
      currency: 'VND',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(price)
  }

  getCsrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ""
  }
}
