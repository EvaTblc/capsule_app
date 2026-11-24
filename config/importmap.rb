# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "mapbox-gl", to: "https://ga.jspm.io/npm:mapbox-gl@3.1.2/dist/mapbox-gl.js"
pin "process", to: "https://ga.jspm.io/npm:@jspm/core@2.1.0/nodelibs/browser/process-production.js"
# Lecteur de codes-barres de secours (Safari iPhone, Firefox : pas de BarcodeDetector intégré). Copié dans
# vendor/javascript, chargé seulement à l'ouverture du scanner (preload: false) ; moteur WebAssembly dans public/zxing
pin "barcode-detector/ponyfill", to: "barcode-detector--ponyfill.js", preload: false
pin "barcode-detector/zxing-exported", to: "barcode-detector--zxing-exported.js", preload: false
pin_all_from "app/javascript/lib", under: "lib", preload: false
