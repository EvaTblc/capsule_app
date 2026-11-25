// Lecture de codes-barres avec la caméra, commune aux scans de jeux, de films et de livres.
//
// Lecteur : celui du navigateur s'il sait lire les EAN (Chrome sur Android...), sinon un lecteur de secours
// (ZXing compilé en WebAssembly) chargé seulement à ce moment-là : Safari sur iPhone, Firefox. Les deux ont la même
// interface (BarcodeDetector). L'image ne quitte jamais l'appareil : seul le numéro lu est renvoyé.

// Moteur du lecteur de secours, servi par l'appli (version dans le nom : jamais un ancien fichier en cache)
const ZXING_WASM_URL = "/zxing/zxing_reader-3.1.6.wasm"
// EAN-13 (Europe), EAN-8, UPC (jeux et films importés d'Amérique du Nord)
const FORMATS = ["ean_13", "ean_8", "upc_a", "upc_e"]

let detectorClassPromise = null

// Classe de lecteur à utiliser, déterminée une seule fois par page
export function barcodeDetectorClass() {
  detectorClassPromise ||= (async () => {
    if ("BarcodeDetector" in window) {
      try {
        // Certains navigateurs exposent BarcodeDetector sans savoir lire aucun format (Chrome sur Linux, Windows)
        const supported = await window.BarcodeDetector.getSupportedFormats()
        if (supported.includes("ean_13")) return window.BarcodeDetector
      } catch (e) { /* lecteur intégré inutilisable : secours */ }
    }
    const { BarcodeDetector, prepareZXingModule } = await import("barcode-detector/ponyfill")
    prepareZXingModule({
      overrides: { locateFile: (path, prefix) => (path.endsWith(".wasm") ? ZXING_WASM_URL : prefix + path) }
    })
    return BarcodeDetector
  })()
  // Échec du chargement (réseau coupé...) : on réessaiera à la prochaine ouverture du scanner
  detectorClassPromise.catch(() => { detectorClassPromise = null })
  return detectorClassPromise
}

export default class BarcodeScanner {
  // onDetect(code) : un code lu (scanner arrêté, sauf en mode continu : il continue de lire)
  // onError(message) : message à afficher, scanner arrêté
  constructor(video, { onDetect, onError, continuous = false }) {
    this.video = video
    this.onDetect = onDetect
    this.onError = onError
    this.continuous = continuous
  }

  async start() {
    this.running = true
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" }, audio: false })
    } catch (e) {
      return this.fail("Impossible d'accéder à la caméra : autorise-la dans les réglages du navigateur, ou tape le titre.")
    }
    if (!this.running) return this.stop() // fermé pendant la demande d'autorisation

    // iPhone : sans playsinline ni muted, la vidéo s'ouvre en plein écran ou ne démarre pas
    this.video.setAttribute("playsinline", "")
    this.video.muted = true
    this.video.srcObject = this.stream
    try { await this.video.play() } catch (e) { /* lecture relancée par le navigateur dès que possible */ }

    let Detector
    try {
      Detector = await barcodeDetectorClass()
    } catch (e) {
      return this.fail("Le lecteur de codes-barres n'a pas pu se charger : vérifie ta connexion, ou tape le titre.")
    }
    if (!this.running) return
    this.detector = new Detector({ formats: FORMATS })
    this.tick()
  }

  // Une lecture à la fois (le lecteur de secours peut mettre plus de temps que l'intervalle)
  async tick() {
    if (!this.running) return
    try {
      const codes = await this.detector.detect(this.video)
      if (this.running && codes.length > 0) {
        const code = codes[0].rawValue
        if (!this.continuous) {
          this.stop()
          this.onDetect(code)
          return
        }
        const now = Date.now()
        if (code !== this.lastCode || now - this.lastSeen > 3000) this.onDetect(code)
        this.lastCode = code
        this.lastSeen = now
      }
    } catch (e) { /* image pas encore prête : on réessaie */ }
    this.timer = setTimeout(() => this.tick(), 250)
  }

  stop() {
    this.running = false
    clearTimeout(this.timer)
    this.stream?.getTracks().forEach(track => track.stop())
    this.stream = null
    this.video.srcObject = null
  }

  fail(message) {
    this.stop()
    this.onError(message)
  }
}
