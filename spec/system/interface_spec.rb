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

  describe "mot de passe oublié" do
    it "la demande affiche la confirmation en français" do
      create(:user, email: "eva@example.com")
      visit new_user_password_path
      fill_in "Email", with: "eva@example.com"
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
  end
end
