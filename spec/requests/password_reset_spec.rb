require "rails_helper"

RSpec.describe "Mot de passe oublié", type: :request do
  include ActiveJob::TestHelper

  let!(:user) { create(:user, email: "eva@example.com") }

  def request_reset(email) = post(user_password_path, params: { user: { email: email } })

  it "envoie l'e-mail en tâche de fond, en français, depuis noreply@capsule.click" do
    expect { request_reset("eva@example.com") }.to have_enqueued_mail(Devise::Mailer, :reset_password_instructions)

    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ "eva@example.com" ])
    expect(mail.from).to eq([ "noreply@capsule.click" ])
    expect(mail.subject).to eq("Réinitialise ton mot de passe Capsule")
    expect(mail.body.encoded).to include("Choisir un nouveau mot de passe")
    expect(mail.body.encoded).to match(%r{/users/password/edit\?reset_password_token=\w+})
  end

  it "affiche un message en français (et non plus « Translation missing »)" do
    request_reset("eva@example.com")
    expect(flash[:notice]).to include("tu vas recevoir")
    expect(flash[:notice]).not_to include("Translation missing")
  end

  it "ne révèle pas si une adresse a un compte (mode paranoid)" do
    request_reset("eva@example.com")
    known = flash[:notice]
    expect { request_reset("inconnue@example.com") }.not_to have_enqueued_mail
    expect(flash[:notice]).to eq(known)
  end

  it "le lien de l'e-mail permet bien de changer le mot de passe" do
    request_reset("eva@example.com")
    perform_enqueued_jobs
    token = ActionMailer::Base.deliveries.last.body.encoded[/reset_password_token=([\w-]+)/, 1]

    put user_password_path, params: { user: { reset_password_token: token, password: "nouveau-mdp-123", password_confirmation: "nouveau-mdp-123" } }
    expect(user.reload.valid_password?("nouveau-mdp-123")).to be true
  end
end

RSpec.describe "Pages du mot de passe oublié", type: :request do
  include ActiveJob::TestHelper

  it "la page de demande est en français, dans le style de la connexion" do
    get new_user_password_path
    expect(response.body).to include("Mot de passe oublié ? Pas de panique.", "Recevoir le lien", "Se connecter")
    expect(response.body).not_to include("Forgot your password?")
  end

  it "après la demande, le message de confirmation s'affiche sur la page de connexion" do
    create(:user, email: "eva@example.com")
    post user_password_path, params: { user: { email: "eva@example.com" } }
    follow_redirect!
    expect(response.body).to include("tu vas recevoir")
  end

  context "page de nouveau mot de passe" do
    let(:user) { create(:user) }
    let(:token) { user.send_reset_password_instructions }

    it "est en français" do
      get edit_user_password_path(reset_password_token: token)
      expect(response.body).to include("Choisis ton nouveau mot de passe.", "Nouveau mot de passe", "6 caractères minimum")
    end

    it "affiche les erreurs (mot de passe trop court, confirmation différente)" do
      put user_password_path, params: { user: { reset_password_token: token, password: "abc", password_confirmation: "xyz" } }
      expect(response).to have_http_status(422)
      expect(response.body).to include("Enregistrer mon mot de passe")
      expect(response.body).to match(/trop court/i)
    end
  end
end

RSpec.describe "Messages flash", type: :request do
  it "s'affichent enfin dans l'appli (ils n'étaient rendus nulle part)" do
    sign_in create(:user)
    get invite_path(token: "lien-bidon")
    follow_redirect!
    expect(response.body).to include("Lien invalide.")
    expect(response.body).to include('data-controller="flash"')
  end
end

RSpec.describe "Traductions Devise" do
  it "tous les messages anglais de Devise ont leur traduction française" do
    english = YAML.load_file(Rails.root.join("config/locales/devise.en.yml"))["en"]
    french = YAML.load_file(Rails.root.join("config/locales/devise.fr.yml"))["fr"]
    keys = ->(hash, prefix = nil) { hash.flat_map { |k, v| v.is_a?(Hash) ? keys.(v, [ prefix, k ].compact.join(".")) : [ [ prefix, k ].compact.join(".") ] } }
    expect(keys.(french)).to match_array(keys.(english))
  end
end
