import { Controller } from "@hotwired/stimulus"

let pdfGeneratorPromise

async function loadPdfGenerator() {
  if (!pdfGeneratorPromise) {
    pdfGeneratorPromise = import("ksef_pdf_generator").catch((error) => {
      pdfGeneratorPromise = null
      throw error
    })
  }

  return pdfGeneratorPromise
}

export default class extends Controller {
  static values = {
    downloadName: String,
    nrKsef: String,
    xmlUrl: String
  }

  connect() {
    this.defaultLabel = this.element.textContent.trim()
  }

  async download(event) {
    event.preventDefault()
    if (this.element.disabled) return

    this.setLoadingState(true)

    try {
      const xmlContent = await this.fetchXml()
      const xmlFile = new File([xmlContent], `${this.downloadNameValue}.xml`, { type: "application/xml" })
      const { generateInvoice } = await loadPdfGenerator()
      const pdfBlob = await generateInvoice(xmlFile, { nrKSeF: this.nrKsefValue }, "blob")

      this.downloadBlob(pdfBlob)
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error"
      alert(`Failed to download PDF: ${message}`)
    } finally {
      this.setLoadingState(false)
    }
  }

  async fetchXml() {
    const response = await fetch(this.xmlUrlValue, {
      credentials: "same-origin",
      headers: { Accept: "application/xml" }
    })

    if (!response.ok) {
      const body = (await response.text()).trim()
      throw new Error(body || `Request failed with status ${response.status}`)
    }

    return response.text()
  }

  downloadBlob(blob) {
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")

    link.href = url
    link.download = `${this.downloadNameValue}.pdf`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
  }

  setLoadingState(isLoading) {
    this.element.disabled = isLoading
    this.element.textContent = isLoading ? "Generating PDF..." : this.defaultLabel
  }
}
