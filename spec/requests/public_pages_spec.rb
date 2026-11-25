require "rails_helper"

# Ton de Capsule : « tu » partout, écrans d'entrée compris (accueil, connexion, inscription, mot de passe).
# Les messages de Devise, affichés avant et après connexion, et la page des crédits restent neutres.
RSpec.describe "Pages publiques", type: :request do
  TUTOIEMENT = /\b(tu|ton|ta|tes|toi|te)\b|\b\w+-toi\b/i
  VOUVOIEMENT = /\b(vous|votre|vos)\b|\b\w+-vous\b/i

  def visible_text(html) = Nokogiri::HTML(html).css("body").text

  {
    "accueil" => "/",
    "connexion" => "/users/sign_in",
    "inscription" => "/users/sign_up",
    "mot de passe oublié" => "/users/password/new"
  }.each do |name, path|
    it "#{name} : tutoiement, aucun vouvoiement ; identité Capsule (logo, police servie par l'appli)" do
      get path
      expect(response).to have_http_status(200)
      text = visible_text(response.body)
      expect(text).to match(TUTOIEMENT)
      expect(text).not_to match(VOUVOIEMENT)
      expect(response.body).to include("logo-").and include("capsule")
      expect(response.body).not_to include("fonts.googleapis.com", "fonts.gstatic.com") # aucune IP de visiteur envoyée à Google
    end
  end

  it "crédits : tournures neutres, ni tu ni vous" do
    get credits_path
    expect(visible_text(response.body)).not_to match(TUTOIEMENT)
    expect(visible_text(response.body)).not_to match(VOUVOIEMENT)
  end

  it "les messages de Devise sont neutres (ni tu, ni forme genrée)" do
    messages = YAML.load_file(Rails.root.join("config/locales/devise.fr.yml"))["fr"].to_s
    expect(messages).not_to match(TUTOIEMENT)
    expect(messages).not_to match(/\b(connectée|déconnectée|inscrite)\b/)
  end

  describe "crédits" do
    it "attribue chaque source, avec le logo et la mention exacte exigés par TMDB" do
      get credits_path
      expect(response.body).to include("credits/tmdb", # logo TMDB obligatoire
                                       "This product uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB.",
                                       "IGDB.com", "catalogue général de la BnF", "Discogs", "UPCitemdb", "EAN-DB", "OpenStreetMap", "Anthropic", "Baloo 2", "SIL Open Font License")
    end

    it "est accessible depuis l'accueil et depuis le profil" do
      get root_path
      expect(response.body).to include(credits_path)
      sign_in create(:user)
      get profile_path
      expect(response.body).to include(credits_path)
    end
  end

  describe "inscription" do
    it "est en français, dans le style de la connexion" do
      get new_user_registration_path
      expect(response.body).to include("Créer mon compte", "Continuer avec Google", "Déjà un compte&nbsp;?")
      expect(response.body).not_to include("Sign up")
    end

    it "crée le compte" do
      expect {
        post user_registration_path, params: { user: { email: "nouvelle@example.com", password: "motdepasse", password_confirmation: "motdepasse" } }
      }.to change(User, :count).by(1)
    end

    it "affiche les erreurs (confirmation différente)" do
      post user_registration_path, params: { user: { email: "x@example.com", password: "motdepasse", password_confirmation: "autre" } }
      expect(response).to have_http_status(422)
      expect(response.body).to include("La confirmation ne correspond pas au mot de passe.")
    end
  end
end
