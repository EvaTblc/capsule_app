require "rails_helper"

RSpec.describe "Items", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :premium) }
  def collection_of(category)
    Collection.create!(title: "Collec", category: category).tap do |c|
      UserCollection.create!(user: user, collection: c, role: "owner")
    end
  end
  before { sign_in user }

  describe "POST /collections/:id/items" do
    let(:games) { collection_of("video_games") }
    let(:books) { collection_of("books") }

    # Turbo soumet TOUS les formulaires avec cet en-tête : les deux formulaires doivent le supporter
    let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" } }

    it "ajout rapide : confirmation dans le panneau" do
      post collection_items_path(games), headers: turbo_headers,
           params: { quick_add: "1", item: { title: "Zelda", item_type: "VideoGameDetail" }, video_game_detail: { platform: "Switch" } }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("quick-add-list").and include("✓ Zelda")
    end

    it "ajout rapide sans titre : 422, message dans le panneau, rien de créé" do
      expect {
        post collection_items_path(games), headers: turbo_headers,
             params: { quick_add: "1", item: { title: "", item_type: "VideoGameDetail" }, video_game_detail: { platform: "Switch" } }
      }.not_to change(Item, :count)
      expect(response).to have_http_status(422)
      expect(response.body).to include("quick-add-list").and include("Le titre ne peut pas être vide")
    end

    it "formulaire complet soumis par Turbo : redirige vers la fiche du nouvel item (et non plus un Turbo Stream sans effet)" do
      post collection_items_path(books), headers: turbo_headers,
           params: { item: { title: "Dune", item_type: "BookDetail" }, book_detail: { description: "x" } }
      expect(response).to redirect_to(collection_item_path(books, Item.last))
    end

    it "formulaire complet invalide soumis par Turbo : formulaire réaffiché avec l'erreur" do
      post collection_items_path(books), headers: turbo_headers,
           params: { item: { title: "", item_type: "BookDetail" }, book_detail: { description: "x" } }
      expect(response).to have_http_status(422)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("Le titre ne peut pas être vide")
      expect(response.body).not_to include("quick-add-list")
    end

    it "détail invalide : formulaire avec l'erreur (et non plus une 500), rien de créé" do
      expect {
        post collection_items_path(games),
             params: { item: { title: "Okami", item_type: "VideoGameDetail" }, video_game_detail: { release_date: "24" } }
      }.not_to change(VideoGameDetail, :count)
      expect(response).to have_http_status(422)
      expect(response.body).to include("L&#39;année de sortie doit être une année à 4 chiffres")
    end

    it "ajout rapide : le résumé anglais envoyé dans summary_en est conservé et mis en traduction" do
      expect {
        post collection_items_path(games), headers: turbo_headers, params: {
          quick_add: "1", item: { title: "Zelda", item_type: "VideoGameDetail" },
          video_game_detail: { platform: "Switch", summary_en: "An epic adventure" }
        }
      }.to have_enqueued_job(TranslationJob)
      expect(Item.last.item_detailable.summary_en).to eq("An epic adventure")
    end

    it "jeu vidéo : la description part dans summary_en et la traduction est mise en file" do
      expect {
        post collection_items_path(games),
             params: { item: { title: "Zelda", item_type: "VideoGameDetail" }, video_game_detail: { description: "A game" } }
      }.to have_enqueued_job(TranslationJob)
      expect(Item.last.item_detailable.summary_en).to eq("A game")
    end

    it "livre sans description : réponse immédiate, résumé généré en arrière-plan" do
      expect(AnthropicClient).not_to receive(:text)
      expect {
        post collection_items_path(books),
             params: { item: { title: "Dune", item_type: "BookDetail" }, book_detail: { author: "Frank Herbert", description: "" } }
      }.to have_enqueued_job(BookDescriptionJob)
      expect(response).to redirect_to(collection_item_path(books, Item.last))
    end

    it "film scanné : code-barres, format et édition enregistrés" do
      movies = collection_of("movies")
      post collection_items_path(movies), params: {
        item: { title: "Inception", item_type: "MovieDetail", barcode: "5051889004601" },
        movie_detail: { format: "Blu-ray", edition: "Steelbook" }
      }
      expect(Item.last).to have_attributes(barcode: "5051889004601")
      expect(Item.last.item_detailable).to have_attributes(format: "Blu-ray", edition: "Steelbook")
    end

    it "livre avec description : pas de génération" do
      expect {
        post collection_items_path(books),
             params: { item: { title: "Dune", item_type: "BookDetail" }, book_detail: { description: "Mon résumé" } }
      }.not_to have_enqueued_job(BookDescriptionJob)
    end
  end

  describe "GET /collections/:id/items/new" do
    it "affiche le formulaire d'ajout" do
      get new_collection_item_path(collection_of("books"))
      expect(response).to have_http_status(200)
    end
  end

  describe "DELETE /collections/:id/items/:id" do
    it "supprime l'item avec son détail, et revient à la collection" do
      books = collection_of("books")
      item = create(:item, collection: books)
      expect { delete collection_item_path(books, item) }.to change(Item, :count).by(-1).and change(BookDetail, :count).by(-1)
      expect(response).to redirect_to(collection_path(books))
    end
  end

  describe "GET /collections/:id/items/:id" do
    it "sans description française (compte free, traduction échouée) : affiche le résumé anglais, signalé comme tel" do
      games = collection_of("video_games")
      detail = create(:video_game_detail, summary_en: "An epic adventure", description: nil)
      item = create(:item, collection: games, item_detailable: detail, item_detailable_type: "VideoGameDetail")
      get collection_item_path(games, item)
      expect(response.body).to include("An epic adventure", "Description (en anglais)")
    end

    it "affiche la description française, jamais le résumé anglais interne" do
      games = collection_of("video_games")
      detail = create(:video_game_detail, summary_en: "An epic adventure", description: "Une aventure épique")
      item = create(:item, collection: games, item_detailable: detail, item_detailable_type: "VideoGameDetail")
      get collection_item_path(games, item)
      expect(response.body).to include("Une aventure épique")
      expect(response.body).not_to include("An epic adventure")
    end
  end

  describe "POST /items/:id/estimate" do
    let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" } }
    let!(:item) { create(:item, collection: collection_of("books")) }

    it "compte free : 403, message à la place du bouton, sans appel à Claude" do
      user.free!
      expect(EstimationService).not_to receive(:estimate)
      post estimate_item_path(item), headers: turbo_headers
      expect(response).to have_http_status(403)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("estimation", "réservée aux comptes Premium")
    end

    it "compte premium : estimation affichée" do
      allow(EstimationService).to receive(:estimate).and_return("price" => "12 €", "explanation" => "Bon état")
      post estimate_item_path(item), headers: turbo_headers
      expect(response).to have_http_status(200)
      expect(response.body).to include("12 €")
    end
  end

  describe "PATCH /collections/:id/items/:id" do
    let(:books) { collection_of("books") }
    let!(:item) { create(:item, collection: books, title: "Dune") }

    it "changement de type vers un détail invalide : 422 et l'ancien détail est intact" do
      old_detail = item.item_detailable
      patch collection_item_path(books, item),
            params: { item: { title: "Dune", item_type: "VideoGameDetail" }, video_game_detail: { platform: "Bidon" } }
      expect(response).to have_http_status(422)
      expect(response.body).to include("Cette plateforme n&#39;est pas dans la liste")
      expect(response.body).not_to include("Platform n")
      expect(item.reload.item_detailable).to eq(old_detail)
      expect(BookDetail.exists?(old_detail.id)).to be true
    end

    it "changement de type vers un type masqué (figurine) : refusé, l'ancien détail est intact" do
      patch collection_item_path(books, item),
            params: { item: { title: "Dune", item_type: "FigurineDetail" }, figurine_detail: { edition: "Standard" } }
      expect(response).to have_http_status(422)
      expect(item.reload.item_detailable_type).to eq("BookDetail")
    end

    it "ajouter une image conserve les images existantes" do
      item.images.attach(io: StringIO.new("a"), filename: "a.jpg", content_type: "image/jpeg")
      patch collection_item_path(books, item), params: {
        item: { title: "Dune", item_type: "BookDetail", images: [ Rack::Test::UploadedFile.new(StringIO.new("b"), "image/jpeg", original_filename: "b.jpg") ] }
      }
      expect(item.reload.images.count).to eq(2)
    end
  end

  describe "type masqué (figurine, en refonte)" do
    let(:mixed) { collection_of("mixed") }

    it "le formulaire ne le propose plus" do
      get new_collection_item_path(mixed)
      expect(response.body).not_to include('data-type="FigurineDetail"')
      expect(response.body).to include('data-type="VideoGameDetail"')
    end

    it "une requête fabriquée ne crée rien" do
      expect {
        post collection_items_path(mixed), params: { item: { title: "Pikachu", item_type: "FigurineDetail" },
                                                    figurine_detail: { edition: "Standard", condition_box: "Neuf" } }
      }.not_to change(Item, :count)
      expect(response).to have_http_status(422)
      expect(response.body).to include("Ce type d&#39;item n&#39;est pas disponible pour le moment.")
      expect(FigurineDetail.count).to eq(0)
    end

    it "une figurine déjà en base reste visible et modifiable" do
      detail = FigurineDetail.new(edition: "Standard", condition_box: "Neuf").tap { |d| d.save!(validate: false) }
      figurine = Item.create!(title: "Pikachu", collection: mixed, item_detailable: detail)
      get edit_collection_item_path(mixed, figurine)
      expect(response.body).to include('data-type="FigurineDetail"')
      patch collection_item_path(mixed, figurine), params: { item: { title: "Pikachu Pop!", item_type: "FigurineDetail" } }
      expect(figurine.reload.title).to eq("Pikachu Pop!")
    end
  end

  describe "GET fiche : image d'en-tête" do
    let(:games) { collection_of("video_games") }
    let(:diamant) { create(:product, igdb_id: 1560, details: { "cover_image_id" => "co1zht" }) }
    let(:cover_url) { "https://images.igdb.com/igdb/image/upload/t_cover_big_2x/co1zht.jpg" }

    def header_html
      Nokogiri::HTML(response.body).at_css("h1").ancestors("div.rounded-3xl").first.to_html
    end

    it "jeu sans photo relié au catalogue : sa jaquette IGDB (grand format), voile sombre et texte blanc" do
      item = Item.create!(title: "Pokémon Diamant", collection: games, product: diamant, item_detailable: VideoGameDetail.create!)
      get collection_item_path(games, item)
      expect(header_html).to include("background-image: url('#{cover_url}')", "bg-black opacity-40", "text-white")
    end

    it "avec photo : la photo passe avant la jaquette" do
      item = Item.create!(title: "Pokémon Diamant", collection: games, product: diamant, item_detailable: VideoGameDetail.create!)
      item.images.attach(io: File.open(Rails.root.join("spec/fixtures/files/figurine.jpg")), filename: "photo.jpg", content_type: "image/jpeg")
      get collection_item_path(games, item)
      expect(header_html).to include("background-image", "/rails/active_storage/")
      expect(header_html).not_to include("images.igdb.com")
    end

    it "sans photo ni jaquette (livre) : fond coloré du type, sans image" do
      item = create(:item, collection: collection_of("books"))
      get collection_item_path(item.collection, item)
      expect(header_html).not_to include("background-image", "text-white")
      expect(header_html).to include("bg-emerald-50")
    end
  end

  it "GET fiche : la page est abonnée aux mises à jour de son item (rafraîchie après la traduction)" do
    games = collection_of("video_games")
    item = Item.create!(title: "Okami", collection: games, item_detailable: VideoGameDetail.create!)
    get collection_item_path(games, item)
    source = Nokogiri::HTML(response.body).at_css("turbo-cable-stream-source")
    expect(source).to be_present
    expect(Turbo::StreamsChannel.verified_stream_name(source["signed-stream-name"])).to eq(item.to_gid_param)
  end

  describe "GET fiche : ordre des champs" do
    def labels
      Nokogiri::HTML(response.body).css("div.bg-white.border p.uppercase").map { |label| label.text.strip }
    end

    it "jeu : plateforme, édition, complet, année, développeur, genre, puis la description en dernier" do
      games = collection_of("video_games")
      detail = VideoGameDetail.create!(platform: "PS5", genre: "Aventure", developer: "Clover", release_date: 2006,
                                       description: "Amaterasu…", completed: true, edition: "Standard")
      item = Item.create!(title: "Okami", collection: games, item_detailable: detail)
      get collection_item_path(games, item)
      expect(labels.first(7)).to eq([ "Plateforme", "Édition", "Jeu complet", "Année de sortie", "Développeur", "Genre", "Description" ])
    end

    it "jeu : chaque champ affichable a sa place dans l'ordre (aucun oublié en fin de fiche)" do
      shown = VideoGameDetail.column_names - %w[id created_at updated_at summary_en]
      expect(shown - VideoGameDetail::SHOW_ORDER).to be_empty
    end
  end
end
