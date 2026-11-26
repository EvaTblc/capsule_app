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
end
