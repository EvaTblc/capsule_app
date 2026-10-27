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

    before { allow_any_instance_of(Api::SearchController).to receive(:igdb_search).and_return([ zelda ]) }

    it "recherche, choix du jeu, ajout : confirmation dans le panneau, sans quitter la page" do
      visit collection_path(games)
      find("[data-action='click->quick-add#open']").click

      fill_in placeholder: "Rechercher un jeu...", with: "Zelda"
      find("[data-games-search-target='results'] div", text: "The Legend of Zelda").click
      click_on "Ajouter →"

      expect(page).to have_css("#quick-add-list", text: "✓ The Legend of Zelda")
      expect(page).to have_current_path(collection_path(games))
      expect(games.items.last.title).to eq("The Legend of Zelda")
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
