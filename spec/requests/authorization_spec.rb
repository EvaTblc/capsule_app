require "rails_helper"

# Un utilisateur ne doit jamais pouvoir lire ni modifier les données d'un autre en changeant un id dans l'URL
RSpec.describe "Autorisations", type: :request do
  let(:eva) { create(:user) }
  let(:intrus) { create(:user) }
  let(:collection) do
    Collection.create!(title: "Privée", category: "books").tap do |c|
      UserCollection.create!(user: eva, collection: c, role: "owner")
    end
  end
  let!(:item) { create(:item, collection: collection) }
  let!(:note) { create(:note, user: eva) }
  let!(:event) { create(:event, user: eva) }

  context "utilisateur connecté qui n'est pas membre" do
    before { sign_in intrus }

    it("ne voit pas la collection") { get collection_path(collection); expect(response).to have_http_status(404) }
    it("ne voit pas l'item") { get collection_item_path(collection, item); expect(response).to have_http_status(404) }
    it("ne peut pas éditer l'item") { get edit_collection_item_path(collection, item); expect(response).to have_http_status(404) }
    it("ne peut pas estimer l'item") { post estimate_item_path(item); expect(response).to have_http_status(404) }
    it("ne voit pas la note") { get note_path(note); expect(response).to have_http_status(404) }
    it("ne voit pas l'événement") { get event_path(event); expect(response).to have_http_status(404) }

    it "ne peut pas supprimer l'item" do
      expect { delete collection_item_path(collection, item) }.not_to change(Item, :count)
    end

    it "ne peut pas ajouter d'item" do
      expect {
        post collection_items_path(collection), params: { item: { title: "Spam", item_type: "BookDetail" } }
      }.not_to change(Item, :count)
    end

    it "ne peut pas supprimer la note" do
      expect { delete note_path(note) }.not_to change(Note, :count)
    end
  end

  describe "amitiés" do
    let!(:demande) { create(:friendship, requester: eva, receiver: intrus, status: "pending") }

    it "l'expéditeur ne peut pas accepter sa propre demande" do
      sign_in eva
      patch accept_friendship_path(demande)
      expect(response).to have_http_status(404)
      expect(demande.reload).to be_pending
    end

    it "un tiers ne peut ni accepter ni supprimer une amitié" do
      sign_in create(:user)
      expect { delete friendship_path(demande) }.not_to change(Friendship, :count)
    end
  end

  describe "partage" do
    it "on ne peut partager une note qu'avec un ami" do
      sign_in eva
      expect { post share_note_path(note), params: { friend_id: intrus.id } }.not_to change(Note, :count)
      expect(response).to have_http_status(404)
    end

    it "une note ne peut pas être rattachée à la collection d'un autre" do
      sign_in intrus
      expect {
        post notes_path, params: { note: { title: "Spam", collection_id: collection.id } }
      }.not_to change(Note, :count)
      expect(response).to have_http_status(422)
    end
  end

  describe "sans connexion" do
    it("les événements demandent une connexion") { get event_path(event); expect(response).to redirect_to(new_user_session_path) }
    it("les amitiés demandent une connexion") { patch accept_friendship_path(1); expect(response).to redirect_to(new_user_session_path) }

    it "l'API de recherche est fermée" do
      get "/api/search/movie", params: { query: "x" }, headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(401)
    end
  end

  describe "injections" do
    before { sign_in eva }

    it "les paramètres de détail ignorent les colonnes techniques (plus de permit!)" do
      autre = create(:book_detail)
      post collection_items_path(collection), params: {
        item: { title: "Dune", item_type: "BookDetail" }, book_detail: { id: autre.id, author: "Herbert", description: "x" }
      }
      expect(Item.last.item_detailable_id).not_to eq(autre.id)
    end

    it "un item_type inconnu est refusé (pas de constantize arbitraire)" do
      post collection_items_path(collection), params: { item: { title: "x", item_type: "User" } }
      expect(response).to have_http_status(400)
    end

    it "le titre de l'ajout rapide est échappé (XSS)" do
      post collection_items_path(collection), as: :turbo_stream, params: {
        item: { title: "<img src=x onerror=alert(1)>", item_type: "BookDetail" }, book_detail: { description: "x" }
      }
      expect(response.body).to include("&lt;img src=x")
      expect(response.body).not_to include("<img src=x")
    end
  end
end
