require "rails_helper"

RSpec.describe "Collections", type: :request do
  let(:owner) { create(:user) }

  def collection_for(user, title: "Collec", **attributes)
    Collection.create!(title: title, category: "video_games", **attributes).tap do |c|
      UserCollection.create!(user: user, collection: c, role: "owner")
    end
  end

  def count_queries
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:sql] =~ /\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/ }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    queries
  end

  describe "GET /collections" do
    before { sign_in owner }

    it "trie les collections dans l'ordre naturel (accents, majuscules, nombres)" do
      ["Tome 10", "Tome 2", "Élan", "arbre", "Zelda"].each { |title| collection_for(owner, title: title) }
      get collections_path
      expect(assigns(:collections).map(&:title)).to eq(["arbre", "Élan", "Tome 2", "Tome 10", "Zelda"])
    end

    it "n'affiche que les 6 items les plus récents, et le bon nombre d'items par collection" do
      collection = collection_for(owner)
      8.times { |i| create(:item, collection: collection, title: "Item #{i}", created_at: i.minutes.ago) }
      get collections_path
      expect(assigns(:recent_items).map(&:title)).to eq((0..5).map { |i| "Item #{i}" })
      expect(response.body).to include("8 items")
    end

    it "fait un nombre de requêtes constant, quel que soit le nombre de collections" do
      add_collections = ->(n) { n.times { |i| create(:item, collection: collection_for(owner, title: "C#{i}#{rand(1000)}")) } }
      add_collections.(8)
      get collections_path # chauffe : la 1re requête de test ne recharge pas l'utilisateur depuis la session
      with_8 = count_queries { get collections_path }
      add_collections.(6)
      with_14 = count_queries { get collections_path }
      expect(with_14).to eq(with_8)
    end
  end

  describe "collection publique (lecture seule via lien)" do
    let(:visitor) { create(:user) }
    let(:public_collection) { collection_for(owner, public: true) }
    let!(:item) { create(:item, collection: public_collection, title: "Zelda") }
    before { create(:note, user: owner, title: "Note perso", collection: public_collection) }

    context "visiteur connecté" do
      before { sign_in visitor }

      it "voit la collection, sans édition, invitation, ajout ni notes" do
        get collection_path(public_collection)
        expect(response).to have_http_status(200)
        expect(response.body).to include("Zelda")
        expect(response.body).not_to include(public_collection.invite_token) # le lien d'invitation donne les droits de membre
        expect(response.body).not_to include(edit_collection_path(public_collection))
        expect(response.body).not_to include(new_collection_item_path(public_collection))
        expect(response.body).not_to include("Note perso")
      end

      it "voit la fiche d'un item, sans édition ni estimation" do
        get collection_item_path(public_collection, item)
        expect(response).to have_http_status(200)
        expect(response.body).not_to include(edit_collection_item_path(public_collection, item))
        expect(response.body).not_to include("Estimer la valeur")
      end

      it("ne peut pas éditer la collection") { get edit_collection_path(public_collection); expect(response).to have_http_status(404) }
      it("ne peut pas éditer l'item") { get edit_collection_item_path(public_collection, item); expect(response).to have_http_status(404) }

      it "ne peut pas supprimer d'item" do
        expect { delete collection_item_path(public_collection, item) }.not_to change(Item, :count)
      end

      it "ne voit pas une collection privée" do
        get collection_path(collection_for(owner, public: false))
        expect(response).to have_http_status(404)
      end
    end

    it "le propriétaire garde toutes les actions" do
      sign_in owner
      get collection_path(public_collection)
      expect(response.body).to include(public_collection.invite_token)
        .and include(new_collection_item_path(public_collection)).and include("Note perso")
    end
  end

  describe "DELETE /collections/:id" do
    it "supprime la collection avec ses items et leurs détails" do
      sign_in owner
      collection = collection_for(owner)
      item = create(:item, collection: collection)
      delete collection_path(collection)
      expect(Collection.exists?(collection.id)).to be false
      expect(Item.exists?(item.id)).to be false
      expect(BookDetail.exists?(item.item_detailable_id)).to be false
    end
  end
end
