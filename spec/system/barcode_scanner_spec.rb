require "rails_helper"

# Lecteur de codes-barres : celui du navigateur, sinon le lecteur de secours (ZXing en WebAssembly) — le seul
# disponible sur Safari iPhone et Firefox. Ici, sans caméra : on lit une vraie image de code-barres EAN-13
RSpec.describe "Lecteur de codes-barres (navigateur)", type: :system do
  let(:user) { create(:user, :premium) }
  let(:books) do
    Collection.create!(title: "Livres", category: "books").tap { |c| UserCollection.create!(user: user, collection: c, role: "owner") }
  end
  let(:ean_image) { "data:image/png;base64,#{Base64.strict_encode64(file_fixture('ean13_9782070360024.png').binread)}" }

  before { sign_in user }

  it "lecteur de secours (comme sur iPhone) : lit un EAN-13, avec la CSP de l'appli" do
    visit new_collection_item_path(books)
    result = page.evaluate_async_script(<<~JS, ean_image)
      const [src, done] = arguments
      ;(async () => {
        delete window.BarcodeDetector // comme Safari et Firefox : pas de lecteur intégré
        const { barcodeDetectorClass } = await import("lib/barcode_scanner")
        const Detector = await barcodeDetectorClass()
        const image = new Image()
        image.src = src
        await image.decode()
        const codes = await new Detector({ formats: ["ean_13"] }).detect(image)
        done({ codes: codes.map(code => code.rawValue) })
      })().catch(error => done({ error: String(error) }))
    JS
    expect(result).to eq("codes" => [ "9782070360024" ])
  end

  # Faux lecteur : chaque lecture renvoie le code suivant de la liste (null : aucun code), une seconde après la précédente
  def scanned_codes(reads, continuous:)
    visit new_collection_item_path(books)
    page.evaluate_async_script(<<~JS, reads, continuous)
      const [reads, continuous, done] = arguments
      ;(async () => {
        const { default: BarcodeScanner } = await import("lib/barcode_scanner")
        let index = 0
        let clock = 0
        Date.now = () => clock
        const detected = []
        const scanner = new BarcodeScanner(document.createElement("video"), { continuous, onDetect: code => detected.push(code), onError: () => {} })
        scanner.detector = {
          detect: async () => {
            clock = index * 1000
            const code = reads[index++]
            if (index > reads.length) scanner.stop() // liste finie
            return code ? [ { rawValue: code } ] : []
          }
        }
        scanner.running = true
        scanner.tick()
        // Fin : scanner arrêté (par lui-même en mode normal, en fin de liste en continu)
        const wait = setInterval(() => { if (!scanner.running) { clearInterval(wait); done({ detected, reads: Math.min(index, reads.length) }) } }, 50)
      })().catch(error => done({ error: String(error) }))
    JS
  end

  it "mode normal : arrêt au premier code lu" do
    result = scanned_codes([ "111", "222" ], continuous: false)
    expect(result).to eq("detected" => [ "111" ], "reads" => 1)
  end

  it "mode continu (rafale) : une boîte restée devant la caméra ne compte qu'une fois, revue après 3 s d'absence elle recompte" do
    reads = [ "111", "111", "111", "111", "111", # 5 s devant la caméra : une seule fois
              "222",                             # autre boîte
              nil, nil, nil, nil,                # plus rien pendant 4 s
              "222",                             # la même revient : deuxième exemplaire
              "111" ]                            # code différent du précédent : compté
    result = scanned_codes(reads, continuous: true)
    expect(result).to eq("detected" => [ "111", "222", "222", "111" ], "reads" => reads.size)
  end

  it "caméra inaccessible : un message dans la page (plus de fenêtre d'alerte), le scanner se ferme" do
    visit new_collection_item_path(books)
    page.execute_script("navigator.mediaDevices.getUserMedia = () => Promise.reject(new Error('refus'))")
    find("[data-type='BookDetail']").click
    find("[data-action='click->book-search#startScan']").click

    expect(page).to have_text("Impossible d'accéder à la caméra")
    expect(page).to have_css("[data-book-search-target='scanner']", visible: :hidden)
  end
end
