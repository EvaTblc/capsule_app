require "rails_helper"

RSpec.describe "Items", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
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
             params: { item: { title: "Goku", item_type: "FigurineDetail" }, figurine_detail: { edition: "Bidon", condition_box: "Neuf" } }
      }.not_to change(FigurineDetail, :count)
      expect(response).to have_http_status(422)
      expect(response.body).to include("Edition")
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

    it "livre avec description : pas de génération" do
      expect {
        post collection_items_path(books),
             params: { item: { title: "Dune", item_type: "BookDetail" }, book_detail: { description: "Mon résumé" } }
      }.not_to have_enqueued_job(BookDescriptionJob)
    end
  end

  describe "PATCH /collections/:id/items/:id" do
    let(:books) { collection_of("books") }
    let!(:item) { create(:item, collection: books, title: "Dune") }

    it "changement de type vers un détail invalide : 422 et l'ancien détail est intact" do
      old_detail = item.item_detailable
      patch collection_item_path(books, item),
            params: { item: { title: "Dune", item_type: "FigurineDetail" }, figurine_detail: { edition: "Bidon" } }
      expect(response).to have_http_status(422)
      expect(item.reload.item_detailable).to eq(old_detail)
      expect(BookDetail.exists?(old_detail.id)).to be true
    end

    it "ajouter une image conserve les images existantes" do
      item.images.attach(io: StringIO.new("a"), filename: "a.jpg", content_type: "image/jpeg")
      patch collection_item_path(books, item), params: {
        item: { title: "Dune", item_type: "BookDetail", images: [ Rack::Test::UploadedFile.new(StringIO.new("b"), "image/jpeg", original_filename: "b.jpg") ] }
      }
      expect(item.reload.images.count).to eq(2)
    end
  end
end
