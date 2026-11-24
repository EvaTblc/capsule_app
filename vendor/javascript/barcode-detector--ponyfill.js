// barcode-detector 3.2.3 (MIT, https://github.com/Sec-ant/barcode-detector) : dist/es/ponyfill.js.
// Seule modification : import du module voisin par son nom dans l'importmap (au lieu de "./zxing-exported.js").
export { t as BarcodeDetector, s as ZXING_CPP_COMMIT, a as ZXING_WASM_SHA256, o as ZXING_WASM_VERSION, i as prepareZXingModule, r as purgeZXingModule, n as setZXingModuleOverrides } from "barcode-detector/zxing-exported";
