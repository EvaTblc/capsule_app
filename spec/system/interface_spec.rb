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

      expect(page).to have_css("[data-controller='flash']", text: "tu vas recevoir")
    end
  end
end
