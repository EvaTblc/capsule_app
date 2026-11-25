require "rails_helper"

RSpec.describe "Interface (navigateur)", type: :system do
  describe "messages flash" do
    it "s'affichent puis disparaissent au tap" do
      sign_in create(:user)
      visit invite_path(token: "lien-bidon")

      flash = find("[data-controller='flash']", text: "Lien invalide.")
      flash.click
      expect(page).not_to have_css("[data-controller='flash']")
    end
  end

  describe "avatar" do
    it "affiche l'initiale quand la photo de profil ne se charge pas" do
      # Adresse extérieure : bloquée pendant les tests, donc l'image échoue comme un lien Google expiré
      sign_in create(:user, email: "eva@example.com", avatar_url: "https://lh3.googleusercontent.com/introuvable.jpg")
      visit collections_path

      expect(page).to have_css("[data-avatar-target='fallback']", text: "E", visible: true)
      expect(page).to have_css("[data-avatar-target='img']", visible: false)
    end
  end

  describe "écrans d'entrée" do
    it "connexion : le bouton œil affiche puis masque le mot de passe, la police du logo est chargée" do
      visit new_user_session_path
      field = find_field("user_password")
      expect(field[:type]).to eq("password")

      find("button[aria-label='Afficher le mot de passe']").click
      expect(field[:type]).to eq("text")
      find("button[aria-label='Masquer le mot de passe']").click
      expect(field[:type]).to eq("password")

      # Police servie par l'appli (la CSP refuserait Google Fonts) : réellement chargée par le navigateur
      expect(page.evaluate_async_script(<<~JS)).to be(true)
        const done = arguments[0]
        document.fonts.load("800 50px 'Baloo 2'").then(fonts => done(fonts.length > 0))
      JS
    end
  end

  describe "mot de passe oublié" do
    it "la demande affiche la confirmation en français" do
      create(:user, email: "eva@example.com")
      visit new_user_password_path
      fill_in "E-mail", with: "eva@example.com"
      click_on "Recevoir le lien"

      expect(page).to have_css("[data-controller='flash']", text: "va arriver dans quelques minutes")
    end
  end

  describe "page d'une collection : grille ou liste, recherche instantanée" do
    let(:user) { create(:user) }
    let(:games) do
      Collection.create!(title: "Mes jeux", category: "video_games").tap do |c|
        UserCollection.create!(user: user, collection: c, role: "owner")
        Item.create!(title: "Mario Kart 8 Deluxe", collection: c, item_detailable: VideoGameDetail.create!(platform: "Switch", completed: true))
        Item.create!(title: "Elden Ring", collection: c, item_detailable: VideoGameDetail.create!(platform: "PS5"))
      end
    end

    before { sign_in user }

    it "grille par défaut ; la liste choisie est retenue d'une visite à l'autre" do
      visit collection_path(games)
      expect(page).to have_css("[data-collection-filter-target='list'][data-view='grid']")
      expect(page).to have_css("button[aria-label='Vue grille'][aria-pressed='true']")

      find("button[aria-label='Vue liste']").click
      expect(page).to have_css("[data-collection-filter-target='list'][data-view='list']")
      expect(page).to have_content("Complet")

      visit collection_path(games)
      expect(page).to have_css("[data-collection-filter-target='list'][data-view='list']")
      expect(page).to have_css("button[aria-label='Vue liste'][aria-pressed='true']")
    end

    it "la recherche filtre les items pendant la frappe" do
      visit collection_path(games)
      fill_in placeholder: "Chercher dans Mes jeux…", with: "mario"
      expect(page).to have_link(href: %r{/items/}, text: "Mario Kart 8 Deluxe", count: 1)
      expect(page).not_to have_text("Elden Ring")

      fill_in placeholder: "Chercher dans Mes jeux…", with: "zelda"
      expect(page).to have_content("Aucun résultat")
    end

    it "recherche sans accents, aussi sur la plateforme" do
      Item.create!(title: "Pokémon Épée", collection: games, item_detailable: VideoGameDetail.create!(platform: "Switch"))
      visit collection_path(games)
      fill_in placeholder: "Chercher dans Mes jeux…", with: "pokemon epee"
      expect(page).to have_text("Pokémon Épée")
      expect(page).not_to have_text("Mario Kart")

      fill_in placeholder: "Chercher dans Mes jeux…", with: "ps5"
      expect(page).to have_text("Elden Ring")
      expect(page).not_to have_text("Pokémon Épée")
    end

    it "filtres rapides (plateforme, Complets), compteur, et tri retenu" do
      visit collection_path(games)
      expect(page).to have_text("2 items")

      click_on "PS5"
      expect(page).to have_text("Elden Ring")
      expect(page).not_to have_text("Mario Kart")
      expect(page).to have_text("1 item sur 2")

      click_on "Tous"
      click_on "Complets"
      expect(page).to have_text("Mario Kart")
      expect(page).not_to have_text("Elden Ring")

      click_on "Complets"
      select "Plateforme", from: "Trier par"
      titles = all("[data-collection-filter-target='list'] a").map { |card| card["href"] }
      expect(titles.first).to include("/items/#{games.items.find_by(title: 'Elden Ring').id}") # « ps5 » avant « switch »

      visit collection_path(games)
      expect(page).to have_select("Trier par", selected: "Plateforme")
    end
  end
end
