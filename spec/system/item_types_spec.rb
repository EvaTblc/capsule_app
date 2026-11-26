require "rails_helper"

# Chaque type d'item proposé, parcours complet à la main (sans recherche ni scan) :
# ajout par le formulaire complet → fiche → modification → grille de la collection.
# Figurine absente : type masqué tant qu'il est en refonte (Item::HIDDEN_TYPES)
RSpec.describe "Types d'items : parcours complet (navigateur)", type: :system do
  let(:user) { create(:user, :premium) }
  before { sign_in user }

  def collection_of(category)
    Collection.create!(title: "Ma collection #{category}", category: category).tap do |c|
      UserCollection.create!(user: user, collection: c, role: "owner")
    end
  end

  # fields : { placeholder => valeur } dans le bloc du type ; selects : { label visible => option }
  def add_item(collection, type, title:, fields: {}, selects: {}, check: nil)
    visit new_collection_item_path(collection)
    find("[data-type='#{type}']").click
    within("[data-form='#{type}']") do
      fill_in placeholder: "Titre de l'item...", with: title
      fields.each { |placeholder, value| fill_in placeholder: placeholder, with: value }
      selects.each { |label, option| find(:xpath, ".//label[normalize-space()='#{label}']/following-sibling::select[1]").select(option) }
      check(check) if check
    end
    click_on "Valider"
  end

  def edit_title(collection, item, new_title)
    visit edit_collection_item_path(collection, item)
    within("[data-form='#{item.item_detailable_type}']") { fill_in placeholder: "Titre de l'item...", with: new_title }
    click_on "Valider"
  end

  def expect_in_grid(collection, title)
    visit collection_path(collection)
    expect(page).to have_css("[data-collection-filter-target='list'] a", text: title)
  end

  it "Livre" do
    books = collection_of("books")
    add_item(books, "BookDetail", title: "Dune",
             fields: { "Auteur" => "Frank Herbert", "ISBN" => "9782221256939", "Éditeur" => "Robert Laffont",
                       "Nombre de pages" => "800", "Genre" => "Science-fiction", "Description..." => "Arrakis." },
             selects: { "État" => "Bon état" })
    expect(page).to have_content("Item ajouté !")
    expect(page).to have_content("Frank Herbert")
    expect(page).to have_content("Robert Laffont")
    item = Item.last
    expect(item.item_detailable).to have_attributes(author: "Frank Herbert", pages: 800, genre: "Science-fiction")
    edit_title(books, item, "Dune (poche)")
    expect(page).to have_content("Item mis à jour !")
    expect(item.reload.item_detailable.author).to eq("Frank Herbert")
    expect_in_grid(books, "Dune (poche)")
  end

  it "Jeu vidéo" do
    games = collection_of("video_games")
    visit new_collection_item_path(games)
    find("[data-type='VideoGameDetail']").click
    within("[data-form='VideoGameDetail']") do
      fill_in placeholder: "Titre de l'item...", with: "Okami"
      fill_in placeholder: "Genre", with: "Aventure"
      fill_in placeholder: "Développeur", with: "Clover Studio"
      fill_in placeholder: "Standard, Collector, Steelbook...", with: "Standard"
      click_on "PS5"
      check "Jeu complet avec notice ?"
    end
    click_on "Valider"
    expect(page).to have_content("Item ajouté !")
    item = Item.last
    expect(item.item_detailable).to have_attributes(platform: "PS5", genre: "Aventure", developer: "Clover Studio", completed: true)
    expect(page).to have_css("section span", text: "Complet")
    edit_title(games, item, "Okami HD")
    expect(page).to have_content("Item mis à jour !")
    expect(item.reload.item_detailable).to have_attributes(platform: "PS5", completed: true)
    expect_in_grid(games, "Okami HD")
  end

  it "Film" do
    movies = collection_of("movies")
    add_item(movies, "MovieDetail", title: "Inception",
             fields: { "Réalisateur" => "Christopher Nolan", "Année" => "2010", "Studio" => "Warner",
                       "Format (DVD, Blu-ray...)" => "Blu-ray", "Standard, Collector, Steelbook..." => "Steelbook" })
    expect(page).to have_content("Item ajouté !")
    item = Item.last
    expect(item.item_detailable).to have_attributes(director: "Christopher Nolan", year: 2010, format: "Blu-ray", edition: "Steelbook")
    edit_title(movies, item, "Inception (4K)")
    expect(page).to have_content("Item mis à jour !")
    expect(item.reload.item_detailable.format).to eq("Blu-ray")
    expect_in_grid(movies, "Inception (4K)")
  end

  it "Musique" do
    music = collection_of("music")
    add_item(music, "MusicDetail", title: "Random Access Memories",
             fields: { "Artiste" => "Daft Punk", "Album" => "Random Access Memories", "Année" => "2013",
                       "Label" => "Columbia", "Format (CD, Vinyl...)" => "Vinyle", "Genre" => "Électro" })
    expect(page).to have_content("Item ajouté !")
    item = Item.last
    expect(item.item_detailable).to have_attributes(artist: "Daft Punk", year: 2013, format: "Vinyle")
    edit_title(music, item, "RAM")
    expect(page).to have_content("Item mis à jour !")
    expect(item.reload.item_detailable.artist).to eq("Daft Punk")
    expect_in_grid(music, "RAM")
  end

  it "Carte à collectionner" do
    cards = collection_of("trading_cards")
    add_item(cards, "TcgDetail", title: "Dracaufeu",
             fields: { "Jeu (Pokemon, Magic...)" => "Pokémon", "Set" => "Évolutions", "Numéro de carte" => "11/108",
                       "Rareté" => "Holo" },
             selects: { "État" => "Très bon état" })
    expect(page).to have_content("Item ajouté !")
    item = Item.last
    expect(item.item_detailable).to have_attributes(game: "Pokémon", card_set: "Évolutions", card_number: "11/108")
    edit_title(cards, item, "Dracaufeu holo")
    expect(page).to have_content("Item mis à jour !")
    expect_in_grid(cards, "Dracaufeu holo")
  end

  it "Jeu de société" do
    boards = collection_of("board_games")
    add_item(boards, "BoardGameDetail", title: "Catan",
             fields: { "Éditeur" => "Kosmos", "Joueurs min" => "3", "Joueurs max" => "4", "Durée" => "90" })
    expect(page).to have_content("Item ajouté !")
    item = Item.last
    expect(item.item_detailable).to have_attributes(publisher: "Kosmos", min_players: 3, max_players: 4, duration: 90)
    edit_title(boards, item, "Catan (5-6 joueurs)")
    expect(page).to have_content("Item mis à jour !")
    expect_in_grid(boards, "Catan (5-6 joueurs)")
  end

  it "Commentaire : enregistré quel que soit le type" do
    games = collection_of("video_games")
    visit new_collection_item_path(games)
    find("[data-type='VideoGameDetail']").click
    within("[data-form='VideoGameDetail']") { fill_in placeholder: "Titre de l'item...", with: "Halo" }
    fill_in placeholder: "Un commentaire sur cet item...", with: "Acheté à la brocante"
    click_on "Valider"
    expect(page).to have_content("Item ajouté !")
    expect(Item.last.comment).to eq("Acheté à la brocante")
    expect(page).to have_content("Acheté à la brocante")
  end
end
