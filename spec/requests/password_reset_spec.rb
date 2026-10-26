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

RSpec.describe "Traductions Devise" do
  it "tous les messages anglais de Devise ont leur traduction française" do
    english = YAML.load_file(Rails.root.join("config/locales/devise.en.yml"))["en"]
    french = YAML.load_file(Rails.root.join("config/locales/devise.fr.yml"))["fr"]
    keys = ->(hash, prefix = nil) { hash.flat_map { |k, v| v.is_a?(Hash) ? keys.(v, [ prefix, k ].compact.join(".")) : [ [ prefix, k ].compact.join(".") ] } }
    expect(keys.(french)).to match_array(keys.(english))
  end
end
