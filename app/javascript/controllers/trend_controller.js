import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

export default class extends Controller {
  static targets = ["canvas"]
  static values = { points: Array, severities: Array }

  connect() {
    const styles = getComputedStyle(document.documentElement)
    this.chart = new Chart(this.canvasTarget, {
      type: "bar",
      data: {
        labels: this.pointsValue.map((point) => point.label),
        datasets: this.severitiesValue.map((severity) => ({
          label: severity,
          data: this.pointsValue.map((point) => point.counts[severity] || 0),
          backgroundColor: styles.getPropertyValue(`--${severity.toLowerCase()}`).trim()
        }))
      },
      options: {
        scales: { x: { stacked: true }, y: { stacked: true, beginAtZero: true, ticks: { precision: 0 } } }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
