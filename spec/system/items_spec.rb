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

    def open_pile
      visit collection_path(games)
      find("[data-action='click->quick-add#open']").click
    end

    def choose_game(query, name)
      fill_in placeholder: "Titre du jeu…", with: query
      find("[data-games-search-target='results'] div", text: name).click
    end

    def pile = find("[data-game-pile-target='list']")

    it "jeu choisi par son titre : il va dans la pile, puis l'envoi l'ajoute à la collection et vide la pile" do
      open_pile
      choose_game("Zelda", "The Legend of Zelda")

      # Champ vidé pour chercher le jeu suivant ; jeu sorti sur une seule plateforme : elle est déjà choisie
      expect(find_field(placeholder: "Titre du jeu…").value).to eq("")
      expect(pile.find("select").value).to eq("Switch")
      click_on "Ajouter le jeu"

      expect(page).to have_no_css("[data-game-pile-target='list'] div")
      expect(page).to have_no_button("Ajouter le jeu")
      expect(page).to have_current_path(collection_path(games))
      item = games.items.last
      expect(item.title).to eq("The Legend of Zelda")
      expect(item.item_detailable.platform).to eq("Switch")
      expect(item.item_detailable.completed).to be(false)
      expect(item.product.igdb_id).to eq(1)
    end

    it "plusieurs jeux : plateforme (parmi celles du jeu) et « complet » choisis ligne par ligne, puis un seul envoi" do
      multi = { "id" => 2, "name" => "Hades", "platforms" => [ { "name" => "PlayStation 5" }, { "name" => "Xbox Series X|S" } ] }
      allow(IgdbService).to receive(:search) { |query| query.include?("Hades") ? [ multi ] : [ zelda ] }
      open_pile
      choose_game("Zelda", "The Legend of Zelda")
      choose_game("Hades", "Hades")

      hades = pile.find(":scope > div", text: "Hades") # la ligne du jeu (elle contient d'autres div)
      expect(hades.all("select option").map(&:value)).to eq([ "", "PS5", "Xbox Series" ])
      hades.find("select").select("PS5")
      hades.check("Complet")
      click_on "Ajouter les 2 jeux"

      expect(page).to have_no_css("[data-game-pile-target='list'] div")
      details = games.items.reload.to_h { |item| [ item.title, item.item_detailable ] }
      expect(details["Hades"]).to have_attributes(platform: "PS5", completed: true)
      expect(details["The Legend of Zelda"]).to have_attributes(platform: "Switch", completed: false)
    end

    it "pile longue : seule la liste défile, le bouton d'envoi reste visible en bas de l'écran" do
      visit collection_path(games)
      long_pile = Array.new(30) { |i| { id: i + 1, name: "Jeu #{i + 1}", platform: "Switch" } }
      page.execute_script("localStorage.setItem('game-pile-#{games.id}', #{long_pile.to_json.to_json})")
      visit collection_path(games)
      find("[data-action='click->quick-add#open']").click

      expect(page).to have_button("Ajouter les 30 jeux")
      list_scrolls, button_visible = page.evaluate_script(<<~JS)
        (() => {
          const list = document.querySelector("[data-game-pile-target='list']")
          const button = document.querySelector("[data-game-pile-target='submit']").getBoundingClientRect()
          return [ list.scrollHeight > list.clientHeight, button.bottom <= window.innerHeight ]
        })()
      JS
      expect(list_scrolls).to be(true)
      expect(button_visible).to be(true)
    end

    it "la pile est gardée par le navigateur : fermer le panneau ne la perd pas, ✕ retire un jeu" do
      open_pile
      choose_game("Zelda", "The Legend of Zelda")
      find("[data-quick-add-target='panel'] h2 + button").click # ferme et recharge la page

      find("[data-action='click->quick-add#open']").click
      expect(pile).to have_content("The Legend of Zelda")
      pile.click_on "✕"
      expect(page).to have_no_css("[data-game-pile-target='list'] div")
      expect(games.items).to be_empty
    end

    it "déjà dans la collection sur la même plateforme : alerte (sans blocage) ; autre plateforme : rien" do
      multi = zelda.merge("platforms" => [ { "name" => "Nintendo Switch" }, { "name" => "Wii U" } ])
      allow(IgdbService).to receive(:search).and_return([ multi ])
      create(:item, collection: games, title: "Zelda", product: create(:product, igdb_id: 1),
                    item_detailable_type: "VideoGameDetail", item_detailable: create(:video_game_detail, platform: "Switch"))
      open_pile
      choose_game("Zelda", "The Legend of Zelda")

      pile.find("select").select("Wii U")
      expect(pile).to have_no_content("Déjà dans ta collection")
      pile.find("select").select("Switch")
      expect(pile).to have_content("Déjà dans ta collection sur Switch")

      click_on "Ajouter le jeu"
      expect(page).to have_no_css("[data-game-pile-target='list'] div")
      expect(games.items.count).to eq(2)
    end

    describe "scan en rafale" do
      let!(:box) { create(:barcode_product, barcode: "0045496420246", raw_title: "Zelda Switch", platform: "Switch", edition: "Collector") }

      before do
        allow(BarcodeService).to receive(:lookup) { |ean, kind:| box if ean == box.barcode }
        allow(BarcodeService).to receive(:names_for).and_return([ "The Legend of Zelda" ])
      end

      # Code lu par la caméra : remplacé ici par un appel direct (pas de caméra dans le navigateur de test)
      def scan(code)
        page.execute_script(<<~JS, code)
          Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller~='game-pile']"), "game-pile").scan(arguments[0])
        JS
      end

      it "boîte scannée : la ligne se remplit (plateforme de la boîte), puis l'envoi garde le code-barres et l'édition" do
        open_pile
        scan(box.barcode)

        expect(pile).to have_content("The Legend of Zelda")
        expect(pile.find("select").value).to eq("Switch")
        click_on "Ajouter le jeu"

        expect(page).to have_no_css("[data-game-pile-target='list'] div")
        item = games.items.last
        expect(item).to have_attributes(title: "The Legend of Zelda", barcode: box.barcode)
        expect(item.item_detailable).to have_attributes(platform: "Switch", edition: "Collector")
        expect(box.reload.product).to eq(item.product) # boîte confirmée pour les prochains scans
      end

      it "code introuvable : ligne en rouge avec la raison, ni comptée ni envoyée (les autres jeux partent)" do
        open_pile
        scan("123")
        expect(pile).to have_css("div.text-red-600", text: "Jeu introuvable pour ce code")
        expect(find("[data-game-pile-target='submit']")).to be_disabled # rien à envoyer

        choose_game("Zelda", "The Legend of Zelda")
        expect(page).to have_css("[data-game-pile-target='summary']", text: "1 code introuvable ne sera pas ajouté")
        click_on "Ajouter le jeu"

        expect(pile).to have_no_content("The Legend of Zelda")
        expect(pile).to have_css("div.text-red-600", text: "Code 123")
        expect(games.items.count).to eq(1)
      end

      it "recherche interrompue par la fermeture du panneau : relancée à la réouverture ; envoi bloqué pendant la recherche" do
        visit collection_path(games)
        page.execute_script("localStorage.setItem('game-pile-#{games.id}', JSON.stringify([ { barcode: '#{box.barcode}', searching: true } ]))")
        allow(BarcodeService).to receive(:lookup) { sleep 1; box } # recherche lente : on voit la ligne en attente
        visit collection_path(games)
        find("[data-action='click->quick-add#open']").click

        expect(pile).to have_content("Recherche du code #{box.barcode}")
        expect(find("[data-game-pile-target='submit']")).to be_disabled
        expect(page).to have_css("[data-game-pile-target='summary']", text: "1 recherche en cours")
        expect(pile).to have_content("The Legend of Zelda")
        expect(find("[data-game-pile-target='submit']")).not_to be_disabled
        expect(page).to have_no_css("[data-game-pile-target='summary']") # phrase vide : cachée
      end

      it "la caméra prend la place de la recherche, avec le dernier jeu trouvé ; « Terminer » et « Taper un titre » y ramènent" do
        open_pile
        # Fausse caméra : le navigateur de test n'en a pas
        page.execute_script("navigator.mediaDevices.getUserMedia = async () => new MediaStream()")
        search = "[data-game-pile-target='searchRow']"
        find("button[aria-label='Scanner des boîtes']").click

        expect(page).to have_css("[data-game-pile-target='scanner']", visible: true)
        expect(page).to have_css(search, visible: :hidden)
        scan(box.barcode)
        expect(page).to have_css("[data-game-pile-target='lastFound']", text: "✓ The Legend of Zelda")

        click_on "Terminer"
        expect(page).to have_css(search, visible: true)
        expect(page).to have_css("[data-game-pile-target='scanner']", visible: :hidden)
        expect(page).to have_no_css("[data-game-pile-target='lastFound']")

        find("button[aria-label='Scanner des boîtes']").click
        click_on "Taper un titre"
        expect(page).to have_css(search, visible: true)
        expect(page.evaluate_script("document.activeElement.placeholder")).to eq("Titre du jeu…")
      end

      it "compte free : pas de bouton de scan" do
        user.update!(role: "free")
        open_pile
        expect(page).to have_no_button("Scanner des boîtes")
      end
    end

    it "envoi refusé par le serveur : le jeu reste dans la pile, en rouge, avec la raison du refus" do
      open_pile
      choose_game("Zelda", "The Legend of Zelda")
      allow_any_instance_of(ItemSaver).to receive(:save) do |saver|
        saver.item.errors.add(:base, "Plateforme inconnue")
        false
      end
      click_on "Ajouter le jeu"

      expect(pile).to have_css("div.text-red-600", text: "The Legend of Zelda")
      expect(pile).to have_css("div.text-red-600 p", text: "Plateforme inconnue")
      expect(games.items).to be_empty
    end
  end

  describe "formulaire complet : pré-remplissage par la recherche de livre" do
    it "la liste et la fiche viennent de la BnF (bouton « Chercher ») ; l'item est relié à l'œuvre et garde son ISBN" do
      allow(BnfService).to receive(:search_books).with("Veiller sur elle").and_return(
        [ { isbn: "9782378803759", title: "Veiller sur elle", volume: nil, author: "Jean-Baptiste Andrea", publisher: "l'Iconoclaste", year: 2023 } ]
      )
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
        fill_in placeholder: "Titre ou ISBN...", with: "Veiller sur elle"
        click_on "Chercher"
        find("[data-book-search-target='results'] > div", text: "Jean-Baptiste Andrea · l'Iconoclaste, 2023").click
        expect(page).to have_field(placeholder: "Auteur", with: "Jean-Baptiste Andrea")
      end
      click_on "Valider"

      expect(page).to have_content("Item ajouté !")
      expect(Item.last).to have_attributes(product: veiller, barcode: "9782378803759")
      expect(Item.last.item_detailable).to have_attributes(publisher: "l'Iconoclaste", pages: 580, isbn: "9782378803759",
                                                           description: "Roman de Jean-Baptiste Andrea")
    end
  end

  describe "recherche de livre : touche Entrée et messages" do
    before do
      visit new_collection_item_path(collection_of("books"))
      find("[data-type='BookDetail']").click
    end

    it "Entrée lance la recherche sans envoyer le formulaire" do
      allow(BnfService).to receive(:search_books).and_return([])
      within("[data-form='BookDetail']") do
        fill_in placeholder: "Titre ou ISBN...", with: "Titre introuvable"
        find("[data-book-search-target='query']").send_keys(:enter)
        expect(page).to have_content("Aucun livre trouvé à la BnF pour « Titre introuvable »")
      end
      expect(Item.count).to eq(0)
    end

    it "BnF qui ne répond pas : message « réessaie »" do
      allow(BnfService).to receive(:search_books).and_raise(BnfService::Unavailable, "timeout")
      within("[data-form='BookDetail']") do
        fill_in placeholder: "Titre ou ISBN...", with: "Fourth wing"
        click_on "Chercher"
        expect(page).to have_content("La BnF ne répond pas pour le moment")
        expect(page).to have_button("Chercher", disabled: false)
      end
    end
  end

  describe "formulaire complet : pré-remplissage par la recherche de film" do
    it "la liste vient de TMDB, la fiche du catalogue (Wikidata, Wikipédia) ; l'item est relié à l'œuvre" do
      allow(ExternalApi).to receive(:tmdb)
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

  # Type figurine masqué à la création (Item::HIDDEN_TYPES) : l'identification reste testée sur une figurine existante
  def edit_existing_figurine
    collection = collection_of("mixed")
    detail = FigurineDetail.new(edition: "Standard", condition_box: "Neuf").tap { |d| d.save!(validate: false) }
    item = Item.create!(title: "Figurine", collection: collection, item_detailable: detail)
    visit edit_collection_item_path(collection, item)
  end

  describe "identification de figurine par photo" do
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

      edit_existing_figurine
      attach_file "figurine-identify-input", Rails.root.join("spec/fixtures/files/figurine.jpg"), make_visible: true

      expect(page).to have_field(with: "Goku")
      expect(received[:media_type]).to eq("image/jpeg")
      expect(jpeg_size(received[:bytes]).max).to be <= 1568 # la photo d'origine fait 2400 px de large
    end

    it "figurine non reconnue : un message s'affiche (et non plus un formulaire vide, ni un chargement sans fin)" do
      allow(FigurineIdentificationService).to receive(:identify).and_return({})

      edit_existing_figurine
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
      click_on "Estimer la valeur" # bouton cadenassé (🔒), réservé aux comptes Premium

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
      edit_existing_figurine

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
