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
      [ "Tome 10", "Tome 2", "Élan", "arbre", "Zelda" ].each { |title| collection_for(owner, title: title) }
      get collections_path
      expect(assigns(:collections).map(&:title)).to eq([ "arbre", "Élan", "Tome 2", "Tome 10", "Zelda" ])
    end

    it "n'affiche que les 6 items les plus récents, et le bon nombre d'items par collection" do
      collection = collection_for(owner)
      8.times { |i| create(:item, collection: collection, title: "Item #{i}", created_at: i.minutes.ago) }
      get collections_path
      expect(assigns(:recent_items).map(&:title)).to eq((0..5).map { |i| "Item #{i}" })
      expect(response.body).to include("8 items")
    end

    it "chaque collection est une capsule à la couleur de sa catégorie, avec son nombre d'items ; puis « Nouvelle collection »" do
      games = collection_for(owner, title: "Mes jeux", category: "video_games")
      2.times { create(:item, collection: games) }
      get collections_path
      capsule = Nokogiri::HTML(response.body).at_css("a[href='#{collection_path(games)}']")
      expect(capsule["class"]).to include("rounded-full", "bg-blue-100")
      expect(capsule.text.squish).to include("Mes jeux", "2 items")
      expect(response.body).to include("Nouvelle collection", "2 items dans 1 capsule")
      collection_for(owner, title: "Mangas", category: "books")
      get collections_path
      expect(response.body).to include("2 items dans 2 capsules")
    end

    it "sans collection : le logo et un bouton pour créer la première" do
      get collections_path
      expect(response.body).to include("Aucune collection", "Créer une collection", "logo-")
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

  describe "POST /collections" do
    it "crée la collection, dont on devient propriétaire, et redirige vers elle" do
      sign_in owner
      expect { post collections_path, params: { collection: { title: "Ma collection", category: "books" } } }
        .to change(Collection, :count).by(1)
      expect(response).to redirect_to(collection_path(Collection.last))
      expect(owner.user_collections.find_by(collection: Collection.last).role).to eq("owner")
    end

    it "catégorie masquée (figurines, en refonte) : plus proposée, et refusée si la requête est fabriquée" do
      sign_in owner
      get new_collection_path
      expect(response.body).not_to include('data-category="figurines"')
      expect { post collections_path, params: { collection: { title: "Mes Funko", category: "figurines" } } }
        .not_to change(Collection, :count)
      expect(response.body).to include("Cette catégorie n&#39;est pas disponible pour le moment.")
    end

    it "sans titre : le formulaire affiche l'erreur" do
      sign_in owner
      post collections_path, params: { collection: { title: "", category: "books" } }
      expect(response).to have_http_status(422)
      expect(response.body).to include("Le titre ne peut pas être vide")
    end

    it "une collection de figurines existante garde sa catégorie à la modification" do
      sign_in owner
      collection = Collection.new(title: "Funko", category: "figurines").tap { |c| c.save!(validate: false) }
      UserCollection.create!(user: owner, collection: collection, role: "owner")
      get edit_collection_path(collection)
      expect(response.body).to include('data-category="figurines"')
      patch collection_path(collection), params: { collection: { title: "Mes Funko" } }
      expect(collection.reload.title).to eq("Mes Funko")
    end
  end

  describe "DELETE /collections/:id" do
    it "supprime la collection avec ses items et leurs détails" do
      sign_in owner
      collection = collection_for(owner)
      item = create(:item, collection: collection)
      delete collection_path(collection)
      expect(response).to redirect_to(collections_path)
      expect(Collection.exists?(collection.id)).to be false
      expect(Item.exists?(item.id)).to be false
      expect(BookDetail.exists?(item.item_detailable_id)).to be false
    end
  end
end
