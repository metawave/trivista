import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

export default class extends Controller {
  static targets = ["canvas"]
  static values = { points: Array, severities: Array }

  connect() {
    const styles = getComputedStyle(document.documentElement)
    const font = { family: styles.getPropertyValue("--font-mono").trim(), size: 11 }
    this.chart = new Chart(this.canvasTarget, {
      type: "bar",
      data: {
        labels: this.pointsValue.map((point) => point.label),
        datasets: this.severitiesValue.map((severity) => ({
          label: severity,
          data: this.pointsValue.map((point) => point.counts[severity] || 0),
          backgroundColor: styles.getPropertyValue(`--sev-${severity.toLowerCase()}`).trim(),
          maxBarThickness: 44
        }))
      },
      options: {
        maintainAspectRatio: false,
        onClick: (_event, elements) => {
          const url = elements.length && this.pointsValue[elements[0].index].url
          if (url) Turbo.visit(url)
        },
        plugins: { legend: { display: false } },
        scales: {
          x: { stacked: true, grid: { display: false }, ticks: { font } },
          y: { stacked: true, beginAtZero: true, border: { display: false }, ticks: { precision: 0, font } }
        }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
