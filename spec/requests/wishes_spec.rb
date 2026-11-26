require "rails_helper"

RSpec.describe "Souhaits", type: :request do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, category: "video_games") }
  before do
    create(:user_collection, user: user, collection: collection)
    sign_in user
  end

  def wish_params(overrides = {})
    { wish: { title: "Ōkami", platform: "PS2", edition: "PAL", max_price: "20", note: "Boîte et notice" }.merge(overrides) }
  end

  describe "ajouter un souhait" do
    it "membre : le souhait est créé, avec lui pour auteur, et on revient à la collection" do
      expect { post collection_wishes_path(collection), params: wish_params }.to change(collection.wishes, :count).by(1)
      wish = collection.wishes.last
      expect(wish).to have_attributes(title: "Ōkami", platform: "PS2", edition: "PAL", max_price: 20, note: "Boîte et notice", author: user)
      expect(response).to redirect_to(collection_path(collection))
    end

    it "jeu choisi via la recherche : l'œuvre est retrouvée côté serveur à partir de son identifiant IGDB" do
      okami = create(:product, title: "Ōkami", igdb_id: 1234)
      expect(ProductCatalog).to receive(:game).with("1234").and_return(okami)
      post collection_wishes_path(collection), params: wish_params.merge(product: { igdb_id: "1234" })
      expect(collection.wishes.last.product).to eq(okami)
    end

    it "l'auteur, la collection et l'œuvre ne se forgent pas dans le formulaire" do
      other = create(:user)
      other_collection = create(:collection)
      forged = wish_params(author_id: other.id, collection_id: other_collection.id, product_id: create(:product).id)
      post collection_wishes_path(collection), params: forged
      wish = Wish.last
      expect(wish).to have_attributes(author: user, collection: collection, product: nil)
    end

    it "titre manquant : le formulaire est réaffiché (422, pour Turbo) avec un message en français, rien n'est créé" do
      expect { post collection_wishes_path(collection), params: wish_params(title: "") }.not_to change(Wish, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Donne un titre à ton souhait.", 'name="wish[title]"')
    end

    it "prix à 0 € : message en français" do
      post collection_wishes_path(collection), params: wish_params(max_price: "0")
      expect(response.body).to include("Le prix maximum doit être supérieur à 0 €.")
    end

    it "même jeu déjà en souhait dans la collection : message en français" do
      okami = create(:product, igdb_id: 1234)
      create(:wish, collection: collection, product: okami)
      allow(ProductCatalog).to receive(:game).and_return(okami)
      post collection_wishes_path(collection), params: wish_params.merge(product: { igdb_id: "1234" })
      expect(response.body).to include("Ce jeu est déjà dans les souhaits de cette collection.")
    end
  end

  describe "formulaire d'ajout" do
    it "collection de jeux : titre, plateforme (« Peu importe » par défaut), édition, prix maximum, note" do
      get new_collection_wish_path(collection)
      page = Nokogiri::HTML(response.body)
      expect(page.css("form[action='#{collection_wishes_path(collection)}'][method='post']")).to be_present
      %w[title platform edition max_price note].each { |field| expect(page.css("[name='wish[#{field}]']")).to be_present }
      expect(page.css("select[name='wish[platform]'] option").first.text).to eq("Peu importe")
      expect(page.css("input[name='wish[max_price]']").first["step"]).to eq("0.01")
    end

    it "collection de livres : ni plateforme ni édition" do
      books = create(:collection, category: "books")
      create(:user_collection, user: user, collection: books)
      get new_collection_wish_path(books)
      expect(response.body).not_to include("wish[platform]", "wish[edition]")
      expect(response.body).to include("wish[title]")
    end

    it "collection dont on n'est pas membre : 404, rien n'est créé" do
      stranger = create(:collection)
      expect { post collection_wishes_path(stranger), params: wish_params }.not_to change(Wish, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "identifiant de collection piégé (SQL) : 404, jamais interprété" do
      expect { post "/collections/#{CGI.escape('1=1) OR (1=1')}/wishes", params: wish_params }.not_to change(Wish, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "non connecté : renvoyé vers la connexion" do
      sign_out user
      post collection_wishes_path(collection), params: wish_params
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
