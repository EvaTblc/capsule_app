require "rails_helper"

RSpec.describe "Connexion par e-mail", type: :request do
  let!(:user) { create(:user, email: "eva@example.com") }

  def sign_in_with(remember_me:)
    post user_session_path, params: { user: { email: "eva@example.com", password: "password123", remember_me: remember_me } }
  end

  it "la case « Rester connecté » est cochée par défaut" do
    get new_user_session_path
    checkbox = Nokogiri::HTML(response.body).at_css("input[type=checkbox][name='user[remember_me]']")
    expect(checkbox["checked"]).to be_present
  end

  it "case cochée : cookie de reconnexion posé" do
    sign_in_with(remember_me: "1")
    expect(response).to redirect_to(root_path)
    expect(response.cookies["remember_user_token"]).to be_present
  end

  it "case décochée (ordinateur partagé) : connectée seulement le temps de la session" do
    sign_in_with(remember_me: "0")
    expect(response).to redirect_to(root_path)
    expect(response.cookies["remember_user_token"]).to be_nil
  end
end
