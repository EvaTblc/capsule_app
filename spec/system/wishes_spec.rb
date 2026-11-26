require "rails_helper"

RSpec.describe "Souhaits", type: :system do
  let(:user) { create(:user) }
  let(:zelda) { { "id" => 1, "name" => "The Legend of Zelda", "platforms" => [ { "name" => "Nintendo Switch" } ] } }

  def collection_of(category)
    create(:collection, title: "Ma collection", category: category).tap do |collection|
      create(:user_collection, user: user, collection: collection)
    end
  end

  before do
    sign_in user
    allow(IgdbService).to receive(:search).and_return([ zelda ])
    allow(IgdbService).to receive(:game) { |id| zelda.merge("id" => id) }
  end

  def choose_game(query, name)
    fill_in placeholder: "Rechercher un jeu...", with: query
    find("[data-games-search-target='results'] div", text: name).click
  end

  it "jeu choisi via la recherche : titre et plateforme remplis, souhait relié à l'œuvre du catalogue" do
    games = collection_of("video_games")
    visit new_collection_wish_path(games)
    choose_game("Zelda", "The Legend of Zelda")

    # Jeu sorti sur une seule plateforme : elle est déjà choisie
    expect(find_field("Titre").value).to eq("The Legend of Zelda")
    expect(find_field("Plateforme").value).to eq("Switch")
    fill_in "Prix maximum (€)", with: "25"
    click_on "Ajouter à mes souhaits"

    expect(page).to have_content("Souhait ajouté !")
    wish = games.wishes.last
    expect(wish).to have_attributes(title: "The Legend of Zelda", platform: "Switch", max_price: 25, author: user)
    expect(wish.product.igdb_id).to eq(1)
  end

  it "formulaire réaffiché après une erreur : le jeu choisi n'est pas perdu" do
    games = collection_of("video_games")
    visit new_collection_wish_path(games)
    choose_game("Zelda", "The Legend of Zelda")
    fill_in "Prix maximum (€)", with: "0"
    page.execute_script("document.querySelector('[name=\"wish[max_price]\"]').removeAttribute('min')") # passer la vérification du navigateur
    click_on "Ajouter à mes souhaits"

    expect(page).to have_content("Le prix maximum doit être supérieur à 0 €.")
    fill_in "Prix maximum (€)", with: "25"
    click_on "Ajouter à mes souhaits"

    expect(page).to have_content("Souhait ajouté !")
    expect(games.wishes.last.product.igdb_id).to eq(1)
  end

  it "collection de livres : pas de recherche de jeu, le titre se tape à la main" do
    books = collection_of("books")
    visit new_collection_wish_path(books)
    expect(page).to have_no_field(placeholder: "Rechercher un jeu...")

    fill_in "Titre", with: "Veiller sur elle"
    click_on "Ajouter à mes souhaits"

    expect(page).to have_content("Souhait ajouté !")
    expect(books.wishes.last).to have_attributes(title: "Veiller sur elle", product: nil)
  end

  it "depuis la collection : taper sur un souhait ouvre sa fiche, on le modifie, puis on le supprime" do
    games = collection_of("video_games")
    create(:wish, collection: games, title: "Ōkami", platform: "PS2", max_price: 20)
    visit collection_path(games)

    click_on "Ōkami"
    expect(page).to have_content("Mon souhait")
    expect(find_field("Plateforme").value).to eq("PS2")
    fill_in "Prix maximum (€)", with: "15"
    click_on "Enregistrer"

    expect(page).to have_content("Souhait modifié.")
    expect(page).to have_content("15 €")

    click_on "Ōkami"
    accept_confirm("Supprimer ce souhait ?") { click_on "Supprimer ce souhait" }
    expect(page).to have_content("Souhait supprimé.")
    expect(page).to have_link("Ajouter un souhait")
    expect(games.wishes).to be_empty
  end

  it "« Trouvé ! » : depuis la fiche, le formulaire d'item arrive pré-rempli, et le souhait devient un item" do
    games = collection_of("video_games")
    okami = create(:product, title: "Ōkami", igdb_id: 1)
    create(:wish, collection: games, title: "Ōkami", product: okami, platform: "PS2", edition: "PAL")
    visit collection_path(games)

    click_on "Ōkami"
    click_on "Je l'ai trouvé !"
    expect(page).to have_field("Rechercher un jeu...") # type jeu déjà choisi : ses champs sont visibles
    expect(find("input[name='item[title]']").value).to eq("Ōkami")
    expect(find("input[name='video_game_detail[edition]']").value).to eq("PAL")
    click_on "Valider"

    expect(page).to have_content("Item ajouté !")
    item = games.items.last
    expect(item).to have_attributes(title: "Ōkami", product: okami)
    expect(item.item_detailable).to have_attributes(platform: "PS2", edition: "PAL")
    expect(games.wishes).to be_empty
  end
end
