require "rails_helper"

RSpec.describe "Mon compte", type: :request do
  let(:user) { create(:user, email: "eva@example.com", password: "ancien-mdp", password_confirmation: "ancien-mdp") }
  before { sign_in user }

  def update_account(**attributes) = put(user_registration_path, params: { user: attributes })

  it "est accessible depuis le profil (la page n'avait aucun lien)" do
    get profile_path
    expect(response.body).to include(edit_user_registration_path, "Mon compte")
  end

  it "est en français, au tutoiement, sans le texte anglais de Devise" do
    get edit_user_registration_path
    expect(response.body).to include("Mon compte", "Mot de passe actuel", "Nécessaire pour confirmer tes modifications", "Supprimer mon compte")
    expect(response.body).not_to include("Edit User", "leave blank", "Cancel my account")
  end

  it "change l'e-mail avec le bon mot de passe actuel" do
    update_account(email: "nouvelle@example.com", current_password: "ancien-mdp")
    expect(user.reload.email).to eq("nouvelle@example.com")
  end

  it "change le mot de passe" do
    update_account(password: "nouveau-mdp", password_confirmation: "nouveau-mdp", current_password: "ancien-mdp")
    expect(user.reload.valid_password?("nouveau-mdp")).to be true
  end

  it "refuse sans le bon mot de passe actuel, avec un message" do
    update_account(email: "pirate@example.com", current_password: "faux")
    expect(response).to have_http_status(422)
    expect(response.body).to include("Le mot de passe actuel est incorrect.")
    expect(user.reload.email).to eq("eva@example.com")
  end

  it "compte Google : explique comment obtenir un mot de passe" do
    user.update_columns(provider: "google_oauth2", uid: "123")
    get edit_user_registration_path
    expect(response.body).to include("relié à Google", new_user_password_path)
  end

  it "compte e-mail : pas de message Google" do
    get edit_user_registration_path
    expect(response.body).not_to include("relié à Google")
  end

  it "supprime le compte" do
    expect { delete user_registration_path }.to change(User, :count).by(-1)
  end
end
