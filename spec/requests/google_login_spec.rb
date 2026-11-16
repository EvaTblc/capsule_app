require "rails_helper"

RSpec.describe "Connexion Google", type: :request do
  before { OmniAuth.config.test_mode = true }
  after do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  def mock_google(email:, verified: true, uid: "google-123")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: uid,
      info: { email: verified ? email : nil, email_verified: verified, image: nil }
    )
  end

  def google_callback
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
    get user_google_oauth2_omniauth_callback_path
  ensure
    Rails.application.env_config.delete("omniauth.auth")
  end

  it "compte existant par e-mail : connexion réussie, compte relié, message explicite" do
    create(:user, email: "eva@gmail.com")
    mock_google(email: "eva@gmail.com")
    google_callback
    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to include("relié à Google")
  end

  it "reste connecté : cookie de reconnexion posé (sinon, déconnectée à chaque fermeture de l'appli)" do
    create(:user, email: "eva@gmail.com")
    mock_google(email: "eva@gmail.com")
    google_callback
    expect(response.cookies["remember_user_token"]).to be_present
  end

  it "ferme une session déjà ouverte avec l'ancien mot de passe" do
    existing = create(:user, email: "eva@gmail.com")
    sign_in existing
    get collections_path
    expect(response).to have_http_status(200)

    # Pendant ce temps, la vraie propriétaire se connecte avec Google, dans un autre navigateur
    mock_google(email: "eva@gmail.com")
    User.from_omniauth(OmniAuth.config.mock_auth[:google_oauth2])

    get collections_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "adresse non vérifiée : renvoyée vers l'inscription avec le message" do
    mock_google(email: "eva@gmail.com", verified: false)
    google_callback
    expect(response).to redirect_to(new_user_registration_url)
    expect(flash[:alert]).to include("n'a pas vérifié")
  end

  # Démarrage de la connexion : un POST avec le jeton CSRF, hors de Turbo (sa requête fetch ne peut pas suivre
  # la redirection vers Google, bloquée par la CSP). Le GET est refusé : il permettait de lancer une connexion
  # depuis un autre site (CVE-2015-9284)
  describe "démarrage de la connexion" do
    before { OmniAuth.config.test_mode = false }

    it "le bouton est un formulaire POST, hors de Turbo" do
      get new_user_session_path
      form = Nokogiri::HTML(response.body).at_css("form[action='#{user_google_oauth2_omniauth_authorize_path}']")
      expect(form).to be_present
      expect(form["method"]).to eq("post")
      expect(form["data-turbo"]).to eq("false")
    end

    it "POST : redirige vers Google" do
      post user_google_oauth2_omniauth_authorize_path
      expect(response).to have_http_status(302)
      expect(response.location).to start_with("https://accounts.google.com/")
    end

    it "GET : refusé, aucune redirection vers Google" do
      get user_google_oauth2_omniauth_authorize_path
      expect(response).to have_http_status(404)
    end
  end
end
