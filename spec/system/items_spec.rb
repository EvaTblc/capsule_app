require "rails_helper"

# Parcours réels dans Chrome : ce sont les contrôleurs Stimulus qui sont testés ici
RSpec.describe "Items (navigateur)", type: :system do
  let(:user) { create(:user, :premium) } # premium : accès aux fonctions payantes (identification de figurine...)
  before { sign_in user }

  def collection_of(category)
    Collection.create!(title: "Ma collec", category: category).tap do |c|
      UserCollection.create!(user: user, collection: c, role: "owner")
    end
  end

  describe "formulaire complet" do
    let(:books) { collection_of("books") }

    it "le choix du type n'affiche que ses champs, puis l'item créé mène à sa fiche avec un message" do
      visit new_collection_item_path(books)
      find("[data-type='BookDetail']").click

      expect(page).to have_css("[data-form='BookDetail']", visible: true)
      expect(page).to have_css("[data-form='VideoGameDetail']", visible: false)

      within("[data-form='BookDetail']") do
        fill_in placeholder: "Titre de l'item...", with: "Dune"
        fill_in placeholder: "Auteur", with: "Frank Herbert"
        fill_in placeholder: "Description...", with: "Un classique."
      end
      click_on "Valider"

      expect(page).to have_current_path(collection_item_path(books, Item.last))
      expect(page).to have_content("Dune")
      expect(page).to have_css("[data-controller='flash']", text: "Item ajouté !")
    end

    it "sans titre : le formulaire reste affiché avec l'erreur" do
      visit new_collection_item_path(books)
      find("[data-type='BookDetail']").click
      click_on "Valider"

      expect(page).to have_content("Le titre ne peut pas être vide")
      expect(Item.count).to eq(0)
    end
  end

  describe "ajout rapide de jeux" do
    let(:games) { collection_of("video_games") }
    let(:zelda) { { "id" => 1, "name" => "The Legend of Zelda", "platforms" => [ { "name" => "Nintendo Switch" } ] } }

    before do
      allow(IgdbService).to receive(:search).and_return([ zelda ])
      allow(IgdbService).to receive(:game) { |id| zelda.merge("id" => id) }
    end

    it "recherche, choix du jeu, ajout : confirmation dans le panneau, sans quitter la page" do
      visit collection_path(games)
      find("[data-action='click->quick-add#open']").click

      fill_in placeholder: "Rechercher un jeu...", with: "Zelda"
      find("[data-games-search-target='results'] div", text: "The Legend of Zelda").click
      click_on "Ajouter →"

      expect(page).to have_css("#quick-add-list", text: "✓ The Legend of Zelda")
      expect(page).to have_current_path(collection_path(games))
      expect(games.items.last.title).to eq("The Legend of Zelda")
      # Jeu sorti sur une seule plateforme : elle est choisie (avant : « Nintendo Switch », hors liste)
      expect(games.items.last.item_detailable.platform).to eq("Switch")
      expect(games.items.last.product.igdb_id).to eq(1)
    end

    it "jeu multiplateforme : la plateforme choisie par l'utilisateur n'est pas écrasée par le choix du jeu" do
      multi = zelda.merge("platforms" => [ { "name" => "PlayStation 5" }, { "name" => "Xbox Series X|S" } ])
      allow(IgdbService).to receive(:search).and_return([ multi ])
      visit collection_path(games)
      find("[data-action='click->quick-add#open']").click

      click_on "PS5"
      fill_in placeholder: "Rechercher un jeu...", with: "Zelda"
      find("[data-games-search-target='results'] div", text: "The Legend of Zelda").click
      click_on "Ajouter →"

      expect(page).to have_css("#quick-add-list", text: "✓ The Legend of Zelda")
      expect(games.items.last.item_detailable.platform).to eq("PS5")
    end
  end

  describe "formulaire complet : pré-remplissage par la recherche de livre" do
    it "la liste vient de Google Books, la fiche de la BnF ; l'item est relié à l'œuvre et garde son ISBN" do
      allow_any_instance_of(Api::SearchController).to receive(:get_json)
        .and_return("items" => [ { "id" => "g1", "volumeInfo" => { "title" => "Veiller sur elle", "authors" => [ "Jean-Baptiste Andrea" ],
                                                                   "description" => "Texte Google",
                                                                   "industryIdentifiers" => [ { "type" => "ISBN_13", "identifier" => "9782378803759" } ] } } ])
      allow(BnfService).to receive(:find_by_ean).and_return(
        kind: "book", bnf_ark: "ark:/12148/x", title: "Veiller sur elle", complement: nil, support: "1 vol. (580 p.)",
        publisher: "l'Iconoclaste", release_year: 2023, creators: { "070" => [ "Jean-Baptiste Andrea" ] }
      )
      allow(WikimediaService).to receive(:book_work_id).and_return("Q123360390")
      veiller = create(:product, :book, wikidata_id: "Q123360390", description: "Roman de Jean-Baptiste Andrea")
      allow(ProductCatalog).to receive(:book).and_return(veiller)
      books = collection_of("books")

      visit new_collection_item_path(books)
      find("[data-type='BookDetail']").click
      within("[data-form='BookDetail']") do
        fill_in placeholder: "Rechercher un livre...", with: "Veiller sur elle"
        find("[data-book-search-target='results'] div", text: "Veiller sur elle").click
        expect(page).to have_field(placeholder: "Auteur", with: "Jean-Baptiste Andrea")
        expect(page).not_to have_field(with: "Texte Google")
      end
      click_on "Valider"

      expect(page).to have_content("Item ajouté !")
      expect(Item.last).to have_attributes(product: veiller, barcode: "9782378803759")
      expect(Item.last.item_detailable).to have_attributes(publisher: "l'Iconoclaste", pages: 580, isbn: "9782378803759",
                                                           description: "Roman de Jean-Baptiste Andrea")
    end
  end

  describe "formulaire complet : pré-remplissage par la recherche de film" do
    it "la liste vient de TMDB, la fiche du catalogue (Wikidata, Wikipédia) ; l'item est relié à l'œuvre" do
      allow_any_instance_of(Api::SearchController).to receive(:tmdb_get)
        .and_return("results" => [ { "id" => 77338, "title" => "Intouchables", "release_date" => "2011-11-02", "overview" => "Texte TMDB" } ])
      intouchables = create(:product, :movie, tmdb_id: 77338, title: "Intouchables", release_year: 2011,
                                              creator: "Olivier Nakache, Éric Toledano", description: "Comédie dramatique (Wikipédia)",
                                              description_source: "wikipedia", details: { "studios" => [ "Gaumont" ], "wikipedia_url" => "https://fr.wikipedia.org/wiki/Intouchables_(film)" })
      allow(ProductCatalog).to receive(:movie).and_return(intouchables)
      movies = collection_of("movies")

      visit new_collection_item_path(movies)
      find("[data-type='MovieDetail']").click
      within("[data-form='MovieDetail']") do
        fill_in placeholder: "Rechercher un film...", with: "Intouchables"
        find("[data-movie-search-target='results'] div", text: "Intouchables (2011)").click

        expect(page).to have_field(placeholder: "Réalisateur", with: "Olivier Nakache, Éric Toledano")
        expect(page).to have_field(placeholder: "Studio", with: "Gaumont")
        expect(page).not_to have_field(with: "Texte TMDB") # le résumé vient de Wikipédia, pas de TMDB
      end
      click_on "Valider"

      expect(page).to have_content("Item ajouté !")
      expect(Item.last.product).to eq(intouchables)
      expect(page).to have_link("Résumé : Wikipédia (CC BY-SA)", href: "https://fr.wikipedia.org/wiki/Intouchables_(film)")
    end
  end

  describe "plateformes : boutons pour les actuelles, liste déroulante pour les autres" do
    let(:games) { collection_of("video_games") }

    def open_game_form
      visit new_collection_item_path(games)
      find("[data-type='VideoGameDetail']").click
    end

    it "plateforme choisie dans la liste, puis un bouton : la liste revient à zéro, la dernière choisie est enregistrée" do
      open_game_form
      within("[data-form='VideoGameDetail']") do
        find("[data-games-search-target='platformList']").select("Game Boy Advance")
        expect(find("[data-games-search-target='platform']", visible: false).value).to eq("Game Boy Advance")

        click_on "Switch 2"
        expect(find("[data-games-search-target='platformList']").value).to eq("")
        expect(page).to have_css("button.bg-purple-100[data-platform='Switch 2']")

        find("[data-games-search-target='platformList']").select("PC")
        expect(page).not_to have_css("button.bg-purple-100[data-platform]")
        fill_in placeholder: "Titre de l'item...", with: "Doom"
      end
      click_on "Valider"

      expect(page).to have_content("Item ajouté !")
      expect(Item.last.item_detailable.platform).to eq("PC")
    end

    it "jeu sorti sur une seule plateforme rétro : sélectionnée automatiquement dans la liste" do
      gba = { "id" => 5, "name" => "Golden Sun", "platforms" => [ { "name" => "Game Boy Advance" } ] }
      allow(IgdbService).to receive(:search).and_return([ gba ])
      allow(IgdbService).to receive(:game).and_return(gba)

      open_game_form
      within("[data-form='VideoGameDetail']") do
        fill_in placeholder: "Rechercher un jeu...", with: "Golden Sun"
        find("[data-games-search-target='results'] div", text: "Golden Sun").click
        expect(find("[data-games-search-target='platformList']").value).to eq("Game Boy Advance")
      end
    end

    it "modification d'un jeu rétro : sa plateforme est présélectionnée dans la liste" do
      item = create(:item, collection: games, title: "Golden Sun", item_detailable_type: "VideoGameDetail",
                           item_detailable: create(:video_game_detail, platform: "Game Boy Advance"))
      visit edit_collection_item_path(games, item)
      expect(find("[data-form='VideoGameDetail'] [data-games-search-target='platformList']").value).to eq("Game Boy Advance")
    end

    it "ajout rapide : après un ajout, la liste revient aussi à zéro" do
      allow(IgdbService).to receive(:search).and_return([])
      visit collection_path(games)
      find("[data-action='click->quick-add#open']").click
      find("[data-games-search-target='platformList']").select("Wii")
      find("[data-games-search-target='title']", visible: false).execute_script("this.value = 'Wii Sports'")
      click_on "Ajouter →"

      expect(page).to have_css("#quick-add-list", text: "✓ Wii Sports")
      expect(games.items.last.item_detailable.platform).to eq("Wii")
      expect(find("[data-games-search-target='platformList']").value).to eq("")
    end
  end

  describe "formulaire complet : pré-remplissage par la recherche de jeu" do
    it "plateforme, genre, développeur et année remplis ; l'édition se saisit et s'enregistre" do
      botw = { "id" => 7, "name" => "The Legend of Zelda: Breath of the Wild", "first_release_date" => 1488499200,
               "platforms" => [ { "name" => "Nintendo Switch" } ], "genres" => [ { "name" => "Adventure" } ],
               "involved_companies" => [ { "developer" => true, "company" => { "name" => "Nintendo EPD" } } ] }
      allow(IgdbService).to receive(:search).and_return([ botw ])
      allow(IgdbService).to receive(:game).with(7).and_return(botw) # relu par le serveur à l'enregistrement
      games = collection_of("video_games")

      visit new_collection_item_path(games)
      find("[data-type='VideoGameDetail']").click
      within("[data-form='VideoGameDetail']") do
        fill_in placeholder: "Rechercher un jeu...", with: "Zelda"
        find("[data-games-search-target='results'] div", text: "Breath of the Wild").click

        expect(page).to have_field(placeholder: "Développeur", with: "Nintendo EPD")
        expect(page).to have_field(placeholder: "Genre", with: "Adventure")
        expect(find("[data-games-search-target='releaseDate']").value).to eq("2017")
        expect(page).to have_css("button.bg-purple-100[data-platform='Switch']")
        fill_in placeholder: "Standard, Collector, Steelbook...", with: "Collector"
      end
      click_on "Valider"

      expect(page).to have_content("Item ajouté !")
      expect(Item.last.item_detailable).to have_attributes(platform: "Switch", developer: "Nintendo EPD", release_date: 2017, edition: "Collector")
      # L'œuvre du catalogue est créée à partir d'IGDB, pas des champs du formulaire (l'édition reste sur l'item)
      expect(Item.last.product).to have_attributes(igdb_id: 7, title: "The Legend of Zelda: Breath of the Wild", creator: "Nintendo EPD")
    end
  end

  describe "identification de figurine par photo" do
    let(:figurines) { collection_of("figurines") }

    # Dimensions d'un JPEG lues dans son en-tête (marqueur SOF), sans librairie d'image
    def jpeg_size(bytes)
      index = 2
      while index < bytes.bytesize
        marker = bytes.getbyte(index + 1)
        length = bytes.byteslice(index + 2, 2).unpack1("n")
        return bytes.byteslice(index + 5, 4).unpack("nn").reverse if (0xC0..0xC2).cover?(marker)

        index += 2 + length
      end
    end

    it "la photo est réduite et convertie en JPEG dans le navigateur, puis les champs sont remplis" do
      received = nil
      allow(FigurineIdentificationService).to receive(:identify) do |base64, media_type:|
        received = { bytes: Base64.decode64(base64), media_type: media_type }
        { "name" => "Goku", "series" => "Dragon Ball" }
      end

      visit new_collection_item_path(figurines)
      find("[data-type='FigurineDetail']").click
      attach_file "figurine-identify-input", Rails.root.join("spec/fixtures/files/figurine.jpg"), make_visible: true

      expect(page).to have_field(with: "Goku")
      expect(received[:media_type]).to eq("image/jpeg")
      expect(jpeg_size(received[:bytes]).max).to be <= 1568 # la photo d'origine fait 2400 px de large
    end

    it "figurine non reconnue : un message s'affiche (et non plus un formulaire vide, ni un chargement sans fin)" do
      allow(FigurineIdentificationService).to receive(:identify).and_return({})

      visit new_collection_item_path(figurines)
      find("[data-type='FigurineDetail']").click
      attach_file "figurine-identify-input", Rails.root.join("spec/fixtures/files/figurine.jpg"), make_visible: true

      expect(page).to have_css("[data-figurine-identify-target='loader']", text: "Figurine non reconnue")
      expect(page).not_to have_content("Identification en cours")
    end
  end

  describe "compte free : fonctions payantes verrouillées" do
    before { user.free! }

    it "estimer la valeur : bouton cadenassé, le clic explique sans appeler le serveur" do
      expect(EstimationService).not_to receive(:estimate)
      books = collection_of("books")
      item = create(:item, collection: books)

      visit collection_item_path(books, item)
      expect(page).not_to have_text("Cette fonction est réservée aux comptes Premium.")
      click_on "Estimer la valeur · Premium"

      expect(page).to have_css("#estimation", text: "Cette fonction est réservée aux comptes Premium.")
    end

    it "scan d'un jeu : bouton cadenassé, la caméra ne s'ouvre pas" do
      visit new_collection_item_path(collection_of("video_games"))
      find("[data-type='VideoGameDetail']").click

      within("[data-form='VideoGameDetail']") do
        expect(page).not_to have_css("[data-action='click->games-search#startScan']")
        click_on "Fonction Premium"
        expect(page).to have_text("Cette fonction est réservée aux comptes Premium.")
      end
    end

    it "identification de figurine : bouton cadenassé, pas de champ photo" do
      visit new_collection_item_path(collection_of("figurines"))
      find("[data-type='FigurineDetail']").click

      within("[data-form='FigurineDetail']") do
        expect(page).not_to have_css("#figurine-identify-input", visible: :all)
        expect(page).to have_button("Identifier ma figurine · Premium")
      end
    end

    it "scan d'un livre (gratuit) : reste disponible" do
      visit new_collection_item_path(collection_of("books"))
      find("[data-type='BookDetail']").click
      expect(page).to have_css("[data-action='click->book-search#startScan']")
    end
  end

  it "compte premium : scan d'un jeu disponible" do
    visit new_collection_item_path(collection_of("video_games"))
    find("[data-type='VideoGameDetail']").click
    expect(page).to have_css("[data-action='click->games-search#startScan']")
  end
end
