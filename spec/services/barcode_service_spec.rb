require "rails_helper"

RSpec.describe BarcodeService do
  let(:ean) { "0045496464899" }
  let(:http) { double("http client") }

  def fake_response(status, body)
    HTTP::Response.new(status: status, body: body.to_json, version: "1.1",
                       request: HTTP::Request.new(verb: :get, uri: "https://example.com"))
  end

  describe ".product_title : UPCitemdb d'abord, EAN-DB en secours" do
    before do
      allow(HTTP).to receive(:timeout).with(10).and_return(http)
      allow(http).to receive(:auth).with("Bearer jeton").and_return(http)
      allow(http).to receive(:headers).and_return(http)
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:ean_db, :api_key).and_return("jeton")
    end

    def upcitemdb_returns(response)
      allow(http).to receive(:get).with(%r{upcitemdb.com}, params: { upc: ean }).and_return(response)
    end

    def ean_db_returns(response)
      allow(http).to receive(:get).with("https://ean-db.com/api/v2/product/#{ean}").and_return(response)
    end

    it "code connu d'UPCitemdb : son titre, sans appel à EAN-DB (payant)" do
      upcitemdb_returns(fake_response(200, { items: [ { title: "Pokemon - Diamant Edition (nintendo Ds)" } ] }))
      expect(http).not_to receive(:get).with(/ean-db/)
      expect(described_class.product_title(ean)).to eq("Pokemon - Diamant Edition (nintendo Ds)")
    end

    it "code inconnu d'UPCitemdb : titre d'EAN-DB, en français de préférence" do
      upcitemdb_returns(fake_response(200, { items: [] }))
      ean_db_returns(fake_response(200, { product: { titles: { en: "Pokemon Diamond", fr: "Pokémon Diamant" } } }))
      expect(described_class.product_title(ean)).to eq("Pokémon Diamant")
    end

    it "sans titre français : le titre anglais d'EAN-DB" do
      upcitemdb_returns(fake_response(200, { items: [] }))
      ean_db_returns(fake_response(200, { product: { titles: { nl: "Mario Kart 8 Deluxe - Nintendo Switch", en: "Nintendo Mario Kart 8 Deluxe" } } }))
      expect(described_class.product_title(ean)).to eq("Nintendo Mario Kart 8 Deluxe")
    end

    it "quota d'essai d'UPCitemdb dépassé (429) ou UPCitemdb injoignable : EAN-DB prend le relais" do
      ean_db_returns(fake_response(200, { product: { titles: { en: "Pokemon Diamond" } } }))
      upcitemdb_returns(fake_response(429, { code: "TOO_FAST" }))
      expect(described_class.product_title(ean)).to eq("Pokemon Diamond")

      allow(http).to receive(:get).with(%r{upcitemdb.com}, params: { upc: ean }).and_raise(HTTP::TimeoutError)
      expect(described_class.product_title(ean)).to eq("Pokemon Diamond")
    end

    it "code inconnu des deux services : nil" do
      upcitemdb_returns(fake_response(200, { items: [] }))
      ean_db_returns(fake_response(404, { error: { code: 404 } }))
      expect(described_class.product_title(ean)).to be_nil
    end

    it "code-barres qui n'est pas une suite de chiffres : nil, sans aucun appel" do
      expect(HTTP).not_to receive(:timeout)
      [ "../account", "123?x=1", "12", "" ].each { |code| expect(described_class.product_title(code)).to be_nil }
    end

    it "sans jeton EAN-DB : pas d'appel, nil" do
      allow(Rails.application.credentials).to receive(:dig).with(:ean_db, :api_key).and_return(nil)
      upcitemdb_returns(fake_response(200, { items: [] }))
      expect(http).not_to receive(:get).with(/ean-db/)
      expect(described_class.product_title(ean)).to be_nil
    end
  end

  describe ".product_details : ce que Claude lit dans le titre brut" do
    def claude_answers(json) = allow(AnthropicClient).to receive(:text).and_return(json)

    it "noms à chercher (titre principal puis français, sans doublon), plateforme et édition" do
      claude_answers('{"title": "Pokémon Diamond Version", "french_title": "Pokémon Diamant", "platform": "Nintendo DS", "edition": "Collector"}')
      expect(described_class.product_details("Game: Pokemon Diamant Edition Collector for Nintendo DS", kind: :game))
        .to eq(names: [ "Pokémon Diamond Version", "Pokémon Diamant" ], platform: "Nintendo DS", edition: "Collector")

      claude_answers('{"title": "Mario Kart 8 Deluxe", "french_title": "Mario Kart 8 Deluxe", "platform": "Switch", "edition": null}')
      expect(described_class.product_details("Nintendo Switch/pal-hac Mario Kart8 Deluxe Hol Ac", kind: :game))
        .to eq(names: [ "Mario Kart 8 Deluxe" ], platform: "Switch", edition: nil)
    end

    it "plateforme hors de la liste de l'appli : ignorée (le champ n'accepte que ses boutons)" do
      claude_answers('{"title": "Doom", "french_title": "Doom", "platform": "PC", "edition": null}')
      expect(described_class.product_details("Doom PC", kind: :game)[:platform]).to be_nil
    end

    it "film : format de la liste, envoie le titre brut et la consigne propre aux films" do
      expect(AnthropicClient).to receive(:text)
        .with(a_string_including('"Inception (Blu-ray Steelbook)"', "un film", "titre original", "Blu-ray"), max_tokens: anything)
        .and_return('{"title": "Inception", "french_title": "Inception", "format": "Blu-ray", "edition": "Steelbook"}')
      expect(described_class.product_details("Inception (Blu-ray Steelbook)", kind: :movie))
        .to eq(names: [ "Inception" ], format: "Blu-ray", edition: "Steelbook")
    end

    it "produit qui n'est pas du type attendu : aucun nom" do
      claude_answers('{"title": null, "french_title": null, "platform": null, "edition": null}')
      expect(described_class.product_details("Nintendo DS Lite Black", kind: :game)[:names]).to eq([])
    end

    it "échec de Claude ou réponse inattendue : BarcodeService::Error, pour que l'appelant se replie" do
      allow(AnthropicClient).to receive(:text).and_raise(AnthropicClient::Error, "API surchargée")
      expect { described_class.product_details("Zelda", kind: :game) }.to raise_error(BarcodeService::Error, /surchargée/)

      claude_answers('["Zelda"]')
      expect { described_class.product_details("Zelda", kind: :game) }.to raise_error(BarcodeService::Error, /inattendue/)
    end
  end
end
