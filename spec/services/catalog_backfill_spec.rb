require "rails_helper"

# Toutes les sources sont simulées (IGDB, TMDB, Google Books, BnF, Wikidata) : aucun appel réseau
RSpec.describe CatalogBackfill do
  let(:collection) { create(:collection) }
  let(:backfill) { described_class.new(apply: true, pause: 0) }

  def game_item(title, platform: nil)
    create(:item, collection: collection, title: title, item_detailable_type: "VideoGameDetail",
                  item_detailable: create(:video_game_detail, platform: platform, description: nil))
  end

  describe "jeux" do
    let(:zelda) { { "id" => 7, "name" => "The Legend of Zelda: Breath of the Wild", "platforms" => [ { "name" => "Nintendo Switch" } ] } }

    before { allow(IgdbService).to receive(:post).with("alternative_names", anything).and_return([]) }

    it "un seul jeu au titre exact : relié à son œuvre, qui lui donne sa description française" do
      allow(IgdbService).to receive(:post).with("games", anything).and_return([ zelda, zelda.merge("id" => 8, "name" => "Zelda Breath of the Wild Expansion Pass") ])
      product = create(:product, igdb_id: 7, description: "Un monde ouvert")
      allow(ProductCatalog).to receive(:game).with(7).and_return(product)
      item = game_item("The Legend of Zelda : Breath of the Wild")

      result = backfill.run.first
      expect(result).to have_attributes(status: :linked, product: product, replaced: [ :description ])
      expect(item.reload.product).to eq(product)
      expect(item.item_detailable.description).to eq("Un monde ouvert")
    end

    it "plusieurs jeux au même titre : départagés par la plateforme de l'item, sinon laissés de côté" do
      remake = zelda.merge("id" => 9, "platforms" => [ { "name" => "Wii U" } ])
      allow(IgdbService).to receive(:post).with("games", anything).and_return([ zelda, remake ])
      allow(ProductCatalog).to receive(:game).with(9).and_return(create(:product, igdb_id: 9))
      on_wii_u = game_item("The Legend of Zelda: Breath of the Wild", platform: "Wii U")
      unknown = game_item("The Legend of Zelda: Breath of the Wild")
      other_platform = game_item("The Legend of Zelda: Breath of the Wild", platform: "PS4") # ne départage pas

      results = backfill.run.index_by(&:item)
      expect(results[on_wii_u].status).to eq(:linked)
      expect(results[unknown]).to have_attributes(status: :ambiguous, note: "2 jeux au même titre")
      expect(results[other_platform]).to have_attributes(status: :ambiguous, note: "2 jeux au même titre")
      expect(unknown.reload.product).to be_nil
    end

    it "IGDB muet (limite de débit) : signalé comme erreur à relancer, pas comme « aucun jeu »" do
      allow(IgdbService).to receive(:post).with("games", anything).and_return(nil)
      game_item("Mario & Sonic at the Olympic Winter Games")
      expect(backfill.run.first).to have_attributes(status: :error, note: "IGDB n'a pas répondu")
    end

    it "mode essai : le rapport est complet mais rien n'est enregistré, pas même l'œuvre" do
      allow(IgdbService).to receive(:post).with("games", anything).and_return([ zelda ])
      allow(IgdbService).to receive(:game).and_return(zelda)
      item = game_item("The Legend of Zelda: Breath of the Wild")

      result = described_class.new(apply: false, pause: 0).run.first
      expect(result.status).to eq(:linked)
      expect(item.reload.product).to be_nil
      expect(Product.count).to eq(0)
    end

    it "item déjà relié : ignoré (la tâche est relançable) ; erreur sur un item : signalée, les autres continuent" do
      game_item("Déjà relié").update!(product: create(:product))
      allow(IgdbService).to receive(:post).with("games", anything).and_raise(RuntimeError, "panne")
      broken = game_item("Mario Kart 8 Deluxe")

      results = backfill.run
      expect(results.map(&:item)).to eq([ broken ])
      expect(results.first).to have_attributes(status: :error, note: "RuntimeError: panne")
    end
  end

  describe "films" do
    let(:detail) { create(:movie_detail, year: 2011, description: "Résumé TMDB", director: "Olivier Nakache", studio: "Mon studio à moi") }
    let!(:item) { create(:item, collection: collection, title: "Intouchables", item_detailable_type: "MovieDetail", item_detailable: detail) }

    before do
      allow(backfill).to receive(:tmdb_get) do |path, **|
        case path
        when "search/movie" then { "results" => [ { "id" => 77338, "title" => "Intouchables", "release_date" => "2011-11-02" } ] }
        when "movie/77338" then { "overview" => "Résumé TMDB", "release_date" => "2011-11-02", "production_companies" => [ { "name" => "Gaumont" } ] }
        when "movie/77338/credits" then { "crew" => [ { "job" => "Director", "name" => "Olivier Nakache" } ] }
        end
      end
    end

    it "champs encore identiques à TMDB remplacés par le catalogue ; champ modifié par l'utilisateur gardé" do
      intouchables = create(:product, :movie, tmdb_id: 77338, description: "Résumé Wikipédia", creator: "Olivier Nakache, Éric Toledano",
                                              release_year: 2011, details: { "studios" => [ "Gaumont" ] })
      allow(ProductCatalog).to receive(:movie).with(77338).and_return(intouchables)

      result = backfill.run.first
      expect(result).to have_attributes(status: :linked, replaced: %i[description director])
      expect(detail.reload).to have_attributes(description: "Résumé Wikipédia", director: "Olivier Nakache, Éric Toledano",
                                               studio: "Mon studio à moi") # modifié à la main : intact
    end

    it "film absent de Wikidata : rien de relié ni de modifié, signalé dans le rapport" do
      allow(ProductCatalog).to receive(:movie).and_return(nil)
      expect(backfill.run.first).to have_attributes(status: :not_found, note: a_string_including("absent de Wikidata"))
      expect(detail.reload.description).to eq("Résumé TMDB")
    end
  end

  describe "livres" do
    let(:detail) { create(:book_detail, isbn: "978-2-37880-375-9", description: "Résumé Google", publisher: "Iconoclaste (L')", pages: 576) }
    let!(:item) { create(:item, collection: collection, title: "Veiller sur elle", item_detailable: detail) }
    let(:box) do
      create(:barcode_product, barcode: "9782378803759", kind: "book", source: "bnf", publisher: "l'Iconoclaste",
                               details: { "title" => "Veiller sur elle", "support" => "1 vol. (580 p.)", "creators" => { "070" => [ "Jean-Baptiste Andrea" ] } })
    end

    before do
      allow(BarcodeService).to receive(:lookup).with("9782378803759", kind: :book, bnf_only: true).and_return(box)
      allow(backfill).to receive(:google_book).and_return("description" => "Résumé Google", "publisher" => "Iconoclaste (L')", "pageCount" => 576)
    end

    it "relié à l'œuvre ; données Google remplacées par la BnF et Wikipédia" do
      veiller = create(:product, :book, wikidata_id: "Q123360390", description: "Résumé Wikipédia")
      allow(WikimediaService).to receive(:book_work_id).and_return("Q123360390")
      allow(ProductCatalog).to receive(:book).and_return(veiller)

      expect(backfill.run.first).to have_attributes(status: :linked, replaced: %i[description publisher pages])
      expect(detail.reload).to have_attributes(description: "Résumé Wikipédia", publisher: "l'Iconoclaste", pages: 580)
    end

    it "œuvre absente de Wikidata : pas reliée, mais les données Google sont quand même retirées (résumé vidé)" do
      allow(WikimediaService).to receive(:book_work_id).and_return(nil)
      expect(backfill.run.first).to have_attributes(status: :not_found, replaced: %i[description publisher pages])
      expect(detail.reload).to have_attributes(description: nil, publisher: "l'Iconoclaste", pages: 580)
    end
  end
end
