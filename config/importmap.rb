# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# Bundled build from https://cdn.jsdelivr.net/npm/chart.js@4.5.1/+esm with its @kurkle/color import pointed at the pin below.
pin "chart.js" # @4.5.1
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
