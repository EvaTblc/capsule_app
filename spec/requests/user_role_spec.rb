require "rails_helper"

# Le rôle ne se change que depuis la console : aucun formulaire ne doit l'accepter,
# sinon n'importe qui pourrait se donner les fonctions payantes, voire l'accès admin
RSpec.describe "Rôle de l'utilisateur", type: :request do
  it "l'inscription crée un compte free, même si le formulaire envoie un autre rôle" do
    post user_registration_path, params: {
      user: { email: "pirate@example.com", password: "password123", password_confirmation: "password123", role: "admin" }
    }
    expect(User.find_by!(email: "pirate@example.com")).to be_free
  end

  it "Mon compte ne permet pas de changer son rôle" do
    user = create(:user)
    sign_in user
    put user_registration_path, params: { user: { role: "admin", current_password: "password123" } }
    expect(user.reload).to be_free
  end

  it "le profil affiche le type de compte" do
    sign_in create(:user, :premium)
    get profile_path
    expect(response.body).to include("Premium")
  end

  it "la page adresse ne permet pas de changer son rôle" do
    user = create(:user)
    sign_in user
    patch update_address_path, params: { user: { address: "Paris", role: "premium" } }
    expect(user.reload).to be_free
  end
end
