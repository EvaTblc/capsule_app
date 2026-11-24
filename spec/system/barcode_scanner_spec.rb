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

  it "caméra inaccessible : un message dans la page (plus de fenêtre d'alerte), le scanner se ferme" do
    visit new_collection_item_path(books)
    page.execute_script("navigator.mediaDevices.getUserMedia = () => Promise.reject(new Error('refus'))")
    find("[data-type='BookDetail']").click
    find("[data-action='click->book-search#startScan']").click

    expect(page).to have_text("Impossible d'accéder à la caméra")
    expect(page).to have_css("[data-book-search-target='scanner']", visible: :hidden)
  end
end
