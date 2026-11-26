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

  describe "section « Je cherche » de la collection" do
    def section
      Nokogiri::HTML(response.body).xpath("//h2[text()='Je cherche']/ancestor::div[contains(@class,'mb-4')][1]").first
    end

    it "aucun souhait : un bouton « Ajouter un souhait » vers le formulaire" do
      get collection_path(collection)
      expect(section.css("a[href='#{new_collection_wish_path(collection)}']").text.squish).to eq("Ajouter un souhait")
    end

    it "souhaits triés comme les items, avec plateforme, édition et prix à la française" do
      create(:wish, collection: collection, title: "Zelda 10", platform: "Switch", edition: "PAL", max_price: "12.5")
      create(:wish, collection: collection, title: "Zelda 2", max_price: 20)
      create(:wish, collection: collection, title: "Ōkami")
      get collection_path(collection)
      rows = section.css(".divide-y > a").map { |row| row.text.squish }
      # Tri naturel sans accents : Ōkami à la lettre O, Zelda 2 avant Zelda 10
      expect(rows).to eq([ "Ōkami", "Zelda 2 Prix maximum :≤ 20 €", "Zelda 10 Switch · PAL Prix maximum :≤ 12,50 €" ])
      expect(section.text).to include("Souhait") # bouton d'ajout, une fois la liste commencée
    end

    it "collection partagée : chaque souhait dit qui l'a ajouté" do
      lou = create(:user, email: "lou@exemple.fr")
      create(:user_collection, user: lou, collection: collection, role: "member")
      create(:wish, collection: collection, author: lou, title: "Ōkami")
      get collection_path(collection)
      expect(section.text.squish).to include("Ōkami ajouté par lou")
    end

    it "collection solo : pas de mention de l'auteur" do
      create(:wish, collection: collection, author: user, title: "Ōkami")
      get collection_path(collection)
      expect(section.text).not_to include("ajouté par")
    end

    it "visiteur d'une collection publique : pas de section, pas de souhaits" do
      public_collection = create(:collection, public: true)
      create(:wish, collection: public_collection, title: "Secret")
      get collection_path(public_collection)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Je cherche", "Secret")
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

  describe "fiche d'un souhait (modifier, supprimer)" do
    let(:wish) { create(:wish, collection: collection, title: "Okami", max_price: 20) }

    it "la ligne de la collection mène à la fiche, pré-remplie, avec « Enregistrer »" do
      wish
      get collection_path(collection)
      expect(response.body).to include(edit_collection_wish_path(collection, wish))
      get edit_collection_wish_path(collection, wish)
      page = Nokogiri::HTML(response.body)
      expect(page.css("input[name='wish[title]']").first["value"]).to eq("Okami")
      expect(page.text).to include("Enregistrer", "Supprimer ce souhait")
      expect(page.css("input[name='wish[max_price]']").first["value"]).to eq("20") # pas « 20.0 »
    end

    it "modifier : enregistré par n'importe quel membre, retour à la collection" do
      patch collection_wish_path(collection, wish), params: { wish: { title: "Ōkami", max_price: "15" } }
      expect(wish.reload).to have_attributes(title: "Ōkami", max_price: 15)
      expect(response).to redirect_to(collection_path(collection))
    end

    it "modifier sans toucher au jeu : le souhait reste relié à la même œuvre (champ caché renvoyé)" do
      okami = create(:product, igdb_id: 1234)
      wish.update!(product: okami)
      allow(ProductCatalog).to receive(:game).with("1234").and_return(okami)
      patch collection_wish_path(collection, wish), params: { wish: { title: "Ōkami" }, product: { igdb_id: "1234" } }
      expect(wish.reload.product).to eq(okami)
    end

    it "modifier avec une erreur : fiche réaffichée (422), rien n'est changé" do
      patch collection_wish_path(collection, wish), params: { wish: { title: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Donne un titre à ton souhait.")
      expect(wish.reload.title).to eq("Okami")
    end

    it "supprimer : le souhait disparaît, retour à la collection" do
      wish
      expect { delete collection_wish_path(collection, wish) }.to change(Wish, :count).by(-1)
      expect(response).to redirect_to(collection_path(collection))
    end

    it "souhait d'une autre collection, appelé via la mienne (id forgé) : 404, ni lu, ni modifié, ni supprimé" do
      other_wish = create(:wish, title: "Pas à moi")
      # Après un 404, le cookie de session n'est pas réécrit : on se reconnecte avant chaque requête
      get edit_collection_wish_path(collection, other_wish)
      expect(response).to have_http_status(:not_found)
      sign_in user
      patch collection_wish_path(collection, other_wish), params: { wish: { title: "Piraté" } }
      expect(response).to have_http_status(:not_found)
      sign_in user
      expect { delete collection_wish_path(collection, other_wish) }.not_to change(Wish, :count)
      expect(response).to have_http_status(:not_found)
      expect(other_wish.reload.title).to eq("Pas à moi")
    end

    it "non-membre, via la vraie collection du souhait : 404" do
      other_wish = create(:wish, title: "Pas à moi")
      get edit_collection_wish_path(other_wish.collection, other_wish)
      expect(response).to have_http_status(:not_found)
      sign_in user
      expect { delete collection_wish_path(other_wish.collection, other_wish) }.not_to change(Wish, :count)
    end
  end

  describe "« Trouvé ! » : le souhait devient un item" do
    let(:okami) { create(:product, title: "Ōkami", igdb_id: 1234) }
    let(:wish) { create(:wish, collection: collection, title: "Ōkami", product: okami, platform: "PS2", edition: "PAL") }

    def game_item_params(extra = {})
      { item: { item_type: "VideoGameDetail", title: "Ōkami" }, video_game_detail: { platform: "PS2", edition: "PAL" },
        product: { igdb_id: "1234" } }.merge(extra)
    end

    it "la fiche du souhait propose « Trouvé ! » vers le formulaire d'item" do
      get edit_collection_wish_path(collection, wish)
      expect(response.body).to include(new_collection_item_path(collection, wish_id: wish.id), "Je l'ai trouvé !")
    end

    it "formulaire d'item pré-rempli : type jeu, titre, jeu du catalogue, plateforme, édition, souhait d'origine" do
      get new_collection_item_path(collection, wish_id: wish.id)
      page = Nokogiri::HTML(response.body)
      expect(page.css("input[name='item[item_type]']").first["value"]).to eq("VideoGameDetail")
      expect(page.css("input[name='item[title]']").first["value"]).to eq("Ōkami")
      expect(page.css("input[name='product[igdb_id]']").first["value"]).to eq("1234")
      expect(page.css("input[name='video_game_detail[platform]']").first["value"]).to eq("PS2")
      expect(page.css("input[name='video_game_detail[edition]']").first["value"]).to eq("PAL")
      expect(page.css("input[name='wish_id']").first["value"]).to eq(wish.id.to_s)
    end

    it "item enregistré : le souhait disparaît" do
      allow(ProductCatalog).to receive(:game).and_return(okami)
      wish
      expect { post collection_items_path(collection), params: game_item_params(wish_id: wish.id) }
        .to change(Item, :count).by(1).and change(Wish, :count).by(-1)
      expect(collection.items.last.product).to eq(okami)
    end

    it "item refusé (titre vide) : le souhait reste, et le formulaire réaffiché le garde en mémoire" do
      wish
      params = game_item_params(wish_id: wish.id)
      params[:item][:title] = ""
      expect { post collection_items_path(collection), params: params }.not_to change(Wish, :count)
      expect(response.body).to include(%(name="wish_id" id="wish_id" value="#{wish.id}"))
    end

    it "souhait d'une autre collection (id forgé) : ni pré-rempli, ni supprimé" do
      allow(ProductCatalog).to receive(:game).and_return(okami)
      other_wish = create(:wish, title: "Pas à moi")
      get new_collection_item_path(collection, wish_id: other_wish.id)
      expect(response.body).not_to include("Pas à moi", 'name="wish_id"')
      expect { post collection_items_path(collection), params: game_item_params(wish_id: other_wish.id) }
        .not_to change(Wish, :count)
    end

    it "collection de livres : seulement le titre (pas de détail de jeu)" do
      books = create(:collection, category: "books")
      create(:user_collection, user: user, collection: books)
      book_wish = create(:wish, collection: books, title: "Veiller sur elle")
      get new_collection_item_path(books, wish_id: book_wish.id)
      page = Nokogiri::HTML(response.body)
      expect(page.css("input[name='item[item_type]']").first["value"]).to be_blank
      expect(response.body).to include("Veiller sur elle")
    end
  end
end
