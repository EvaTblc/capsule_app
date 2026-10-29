require "rails_helper"

RSpec.describe BarcodeService do
  let(:ean) { "0045496464899" }
  let(:http) { double("http client") }

  def fake_response(status, body)
    HTTP::Response.new(status: status, body: body.to_json, version: "1.1",
                       request: HTTP::Request.new(verb: :get, uri: "https://example.com"))
  end

  # Code inconnu de la BnF : on vérifie ici les appels réels à UPCitemdb et EAN-DB (requêtes HTTP simulées)
  describe "secours d'UPCitemdb puis d'EAN-DB (via .lookup)" do
    # Titre brut de la boîte enregistrée, nil si aucune boîte
    def title_for(code) = described_class.lookup(code, kind: :game)&.raw_title

    before do
      allow(BnfService).to receive(:find_by_ean).and_return(nil)
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
      expect(title_for(ean)).to eq("Pokemon - Diamant Edition (nintendo Ds)")
    end

    it "code inconnu d'UPCitemdb : titre d'EAN-DB, en français de préférence" do
      upcitemdb_returns(fake_response(200, { items: [] }))
      ean_db_returns(fake_response(200, { product: { titles: { en: "Pokemon Diamond", fr: "Pokémon Diamant" } } }))
      expect(title_for(ean)).to eq("Pokémon Diamant")
    end

    it "sans titre français : le titre anglais d'EAN-DB" do
      upcitemdb_returns(fake_response(200, { items: [] }))
      ean_db_returns(fake_response(200, { product: { titles: { nl: "Mario Kart 8 Deluxe - Nintendo Switch", en: "Nintendo Mario Kart 8 Deluxe" } } }))
      expect(title_for(ean)).to eq("Nintendo Mario Kart 8 Deluxe")
    end

    it "quota d'essai d'UPCitemdb dépassé (429) ou UPCitemdb injoignable : EAN-DB prend le relais" do
      ean_db_returns(fake_response(200, { product: { titles: { en: "Pokemon Diamond" } } }))
      upcitemdb_returns(fake_response(429, { code: "TOO_FAST" }))
      expect(title_for(ean)).to eq("Pokemon Diamond")

      BarcodeProduct.delete_all # sinon la boîte enregistrée serait retrouvée sans rien redemander
      allow(http).to receive(:get).with(%r{upcitemdb.com}, params: { upc: ean }).and_raise(HTTP::TimeoutError)
      expect(title_for(ean)).to eq("Pokemon Diamond")
    end

    it "code inconnu des deux services : nil" do
      upcitemdb_returns(fake_response(200, { items: [] }))
      ean_db_returns(fake_response(404, { error: { code: 404 } }))
      expect(title_for(ean)).to be_nil
    end

    it "code-barres qui n'est pas une suite de chiffres : nil, sans aucun appel" do
      expect(HTTP).not_to receive(:timeout)
      [ "../account", "123?x=1", "12", "" ].each { |code| expect(title_for(code)).to be_nil }
    end

    it "sans jeton EAN-DB : pas d'appel, nil" do
      allow(Rails.application.credentials).to receive(:dig).with(:ean_db, :api_key).and_return(nil)
      upcitemdb_returns(fake_response(200, { items: [] }))
      expect(http).not_to receive(:get).with(/ean-db/)
      expect(title_for(ean)).to be_nil
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
      claude_answers('{"title": "Super Mario Bros.", "french_title": "Super Mario Bros.", "platform": "NES", "edition": null}')
      expect(described_class.product_details("Super Mario Bros NES", kind: :game)[:platform]).to be_nil
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

  # Les trois sources sont simulées : BnfService (testé à part), UPCitemdb et EAN-DB (testés plus haut)
  describe ".lookup : boîte déjà connue, sinon BnF → UPCitemdb → EAN-DB, puis enregistrée" do
    let(:pokemon) do
      { kind: "game", bnf_ark: "ark:/12148/cb41198117k", title: "Pokémon", complement: "version diamant",
        support: "1 cartouche Nintendo DS", publisher: "Nintendo France", release_year: 2007,
        creators: { "635" => [ "Game freak" ] } }
    end
    let(:inception) do
      { kind: "movie", bnf_ark: "ark:/12148/cb45330476n", title: "Inception", complement: "ultimate edition",
        support: "2 BD vidéo (2 h 22 min)", publisher: "Warner home video", release_year: 2010, creators: {} }
    end

    def sources_return(bnf: nil, upcitemdb: nil, ean_db: nil)
      allow(BnfService).to receive(:find_by_ean).and_return(bnf)
      allow(described_class).to receive(:upcitemdb_title).and_return(upcitemdb)
      allow(described_class).to receive(:ean_db_title).and_return(ean_db)
    end

    it "code qui n'est pas une suite de chiffres : nil, sans aucune recherche" do
      expect(BnfService).not_to receive(:find_by_ean)
      expect(described_class.lookup("../x", kind: :game)).to be_nil
    end

    it "boîte déjà connue : renvoyée sans appel externe, même lue sur 12 chiffres" do
      box = create(:barcode_product, barcode: "0045496464851")
      expect(BnfService).not_to receive(:find_by_ean)
      expect(described_class.lookup("045496464851", kind: :game)).to eq(box)
    end

    describe "trouvée à la BnF" do
      it "enregistrée avec la notice : titre complet, plateforme déduite du support, éditeur, année" do
        sources_return(bnf: pokemon)
        expect(described_class).not_to receive(:upcitemdb_title)
        box = described_class.lookup("045496464851", kind: :game)
        expect(box).to be_persisted
        expect(box).to have_attributes(barcode: "0045496464851", kind: "game", source: "bnf", bnf_ark: "ark:/12148/cb41198117k",
                                       raw_title: "Pokémon : version diamant", platform: "Nintendo DS", edition: nil,
                                       publisher: "Nintendo France", release_year: 2007)
        expect(box.details).to include("support" => "1 cartouche Nintendo DS", "creators" => { "635" => [ "Game freak" ] })
      end

      it "une fois enregistrée, le scan suivant ne rappelle pas la BnF" do
        sources_return(bnf: pokemon)
        described_class.lookup("045496464851", kind: :game)
        expect(BnfService).not_to receive(:find_by_ean)
        expect { described_class.lookup("0045496464851", kind: :game) }.not_to change(BarcodeProduct, :count)
      end

      it "film : format et édition déduits (« version diamant » n'est pas une édition, « ultimate edition » si)" do
        sources_return(bnf: inception)
        expect(described_class.lookup("5051889041535", kind: :movie)).to have_attributes(format: "Blu-ray", edition: "ultimate edition")
      end

      it "plateformes : la plus précise l'emporte (PS4 et non PS1, 3DS et non DS, Game Boy Advance et non Game Boy)" do
        # Supports réels relevés dans le catalogue de la BnF (majuscules variables : la recherche les ignore)
        {
          "1 disque optique numérique (PlayStation 4)" => "PS4",
          "1 cartouche Nintendo 3DS" => "Nintendo 3DS",
          "1 cartouche Game Boy advance : coul., son. ; 6 cm" => "Game Boy Advance",
          "1 cartouche Game Boy : n. et b." => "Game Boy",
          "1 cartouche Nintendo 64 : coul. (PAL), son. ; 12 cm" => "Nintendo 64",
          "1 cartouche SEGA Mega Drive : coul. (PAL, SECAM), son." => "Mega Drive",
          "4 disques optiques numériques (DVD-ROM) : coul., son. ; 12 cm" => "PC", # jeu PC : seul le disque est nommé
          "1 disque optique numérique (DVD-ROM PlayStation 3)" => "PS3" # un nom de console l'emporte sur « DVD-ROM »
        }.each_with_index do |(support, platform), i|
          sources_return(bnf: pokemon.merge(support: support))
          expect(described_class.lookup("004549646485#{i}", kind: :game).platform).to eq(platform)
        end
      end

      it "code d'un autre type que le formulaire : la boîte est enregistrée pour ce qu'elle est vraiment" do
        sources_return(bnf: inception)
        box = described_class.lookup("5051889041535", kind: :game) # film scanné depuis le formulaire jeu
        expect(box).to have_attributes(kind: "movie", format: "Blu-ray", platform: nil)
      end

      it "livre scanné depuis le formulaire jeu : enregistré comme livre, sans plateforme" do
        sources_return(bnf: pokemon.merge(kind: "book", support: "1 vol. (non paginé [28] p.)"))
        expect(described_class.lookup("1234567890123", kind: :game)).to have_attributes(kind: "book", platform: nil)
      end

      it "ni jeu, ni film, ni livre (CD, partition...) : rien d'enregistré, et pas de recherche ailleurs" do
        sources_return(bnf: pokemon.merge(kind: nil))
        expect(described_class).not_to receive(:upcitemdb_title)
        expect { expect(described_class.lookup("0602475389637", kind: :game)).to be_nil }.not_to change(BarcodeProduct, :count)
      end
    end

    describe "inconnue de la BnF" do
      it "UPCitemdb prend le relais : titre brut enregistré, avec le type du formulaire, sans appel à EAN-DB (payant)" do
        sources_return(upcitemdb: "Pokemon Diamond Version | Nintendo DS")
        expect(described_class).not_to receive(:ean_db_title)
        expect(described_class.lookup("0045496738495", kind: :game))
          .to have_attributes(source: "upcitemdb", kind: "game", raw_title: "Pokemon Diamond Version | Nintendo DS", platform: nil)
      end

      it "puis EAN-DB" do
        sources_return(ean_db: "Nintendo Mario Kart 8 Deluxe")
        expect(described_class.lookup("0045496420253", kind: :game)).to have_attributes(source: "ean_db", raw_title: "Nintendo Mario Kart 8 Deluxe")
      end

      it "bnf_only (livres) : ni UPCitemdb ni EAN-DB (payant)" do
        sources_return(upcitemdb: "Un titre", ean_db: "Un titre")
        expect(described_class).not_to receive(:upcitemdb_title)
        expect(described_class).not_to receive(:ean_db_title)
        expect(described_class.lookup("9782378803759", kind: :book, bnf_only: true)).to be_nil
      end

      it "inconnue partout : nil, rien d'enregistré" do
        sources_return
        expect { expect(described_class.lookup("9999999999994", kind: :game)).to be_nil }.not_to change(BarcodeProduct, :count)
      end
    end
  end

  describe ".names_for : noms à chercher, extraits une fois par Claude puis gardés avec la boîte" do
    def claude_extracts(**details) = allow(described_class).to receive(:product_details).and_return({ names: [ "Pokémon Diamond Version" ] }.merge(details))

    it "garde les noms : le second appel ne rappelle pas Claude" do
      box = create(:barcode_product, source: "upcitemdb", raw_title: "Game: Pokemon Diamant Edition for Nintendo DS")
      claude_extracts(platform: "Nintendo DS")
      expect(described_class.names_for(box)).to eq([ "Pokémon Diamond Version" ])
      expect(box.reload.details["names"]).to eq([ "Pokémon Diamond Version" ])

      expect(described_class).not_to receive(:product_details)
      expect(described_class.names_for(box.reload)).to eq([ "Pokémon Diamond Version" ])
    end

    it "titre brut (UPCitemdb, EAN-DB) : Claude complète la plateforme et l'édition" do
      box = create(:barcode_product, source: "upcitemdb", raw_title: "Pokemon Diamant Collector DS")
      claude_extracts(platform: "Nintendo DS", edition: "Collector")
      described_class.names_for(box)
      expect(box.reload).to have_attributes(platform: "Nintendo DS", edition: "Collector")
    end

    it "notice BnF : sa plateforme et son édition sont gardées, Claude ne les remplace pas" do
      box = create(:barcode_product, source: "bnf", raw_title: "Inception : ultimate edition", kind: "movie", format: "Blu-ray", edition: "ultimate edition")
      claude_extracts(format: "DVD", edition: "Steelbook")
      described_class.names_for(box)
      expect(box.reload).to have_attributes(format: "Blu-ray", edition: "ultimate edition")
    end

    it "Claude indisponible : l'erreur remonte et rien n'est gardé (le prochain scan réessaiera)" do
      box = create(:barcode_product, source: "upcitemdb", raw_title: "Zelda")
      allow(described_class).to receive(:product_details).and_raise(BarcodeService::Error, "API surchargée")
      expect { described_class.names_for(box) }.to raise_error(BarcodeService::Error)
      expect(box.reload.details).not_to have_key("names")
    end
  end
end
