require "rails_helper"

# Ton de Capsule : « vous » sur les pages publiques (avant connexion), « tu » une fois dans l'appli.
# Les messages de Devise, affichés des deux côtés, restent neutres.
RSpec.describe "Pages publiques", type: :request do
  TUTOIEMENT = /\b(tu|ton|ta|tes|toi|te)\b|\b\w+-toi\b/i

  def visible_text(html) = Nokogiri::HTML(html).css("body").text

  {
    "accueil" => "/",
    "connexion" => "/users/sign_in",
    "inscription" => "/users/sign_up",
    "mot de passe oublié" => "/users/password/new"
  }.each do |name, path|
    it "#{name} : vouvoiement, aucun tutoiement" do
      get path
      expect(response).to have_http_status(200)
      expect(visible_text(response.body)).not_to match(TUTOIEMENT)
    end
  end

  it "les messages de Devise sont neutres (ni tu, ni forme genrée)" do
    messages = YAML.load_file(Rails.root.join("config/locales/devise.fr.yml"))["fr"].to_s
    expect(messages).not_to match(TUTOIEMENT)
    expect(messages).not_to match(/\b(connectée|déconnectée|inscrite)\b/)
  end

  describe "inscription" do
    it "est en français, dans le style de la connexion" do
      get new_user_registration_path
      expect(response.body).to include("Créer mon compte", "Continuer avec Google", "Déjà un compte ?")
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
