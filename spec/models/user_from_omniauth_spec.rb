require "rails_helper"

RSpec.describe User, ".from_omniauth" do
  # Même forme que ce que renvoie omniauth-google-oauth2 : info.email n'est rempli que si l'adresse est vérifiée
  def google_auth(uid: "google-123", email: "eva@gmail.com", verified: true, image: "https://img/avatar.jpg")
    OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: uid,
      info: { email: verified ? email : nil, unverified_email: email, email_verified: verified, image: image }
    )
  end

  it "connecte le compte déjà relié à ce compte Google" do
    user = create(:user, provider: "google_oauth2", uid: "google-123")
    expect(User.from_omniauth(google_auth)).to eq(user)
  end

  it "crée un compte quand l'adresse est inconnue" do
    user = User.from_omniauth(google_auth)
    expect(user).to be_persisted
    expect(user).to have_attributes(email: "eva@gmail.com", uid: "google-123", avatar_url: "https://img/avatar.jpg")
  end

  context "compte e-mail existant avec la même adresse (cas qui échouait avant : « email déjà pris »)" do
    let!(:existing) { create(:user, email: "eva@gmail.com", password: "ancien-mot-de-passe", password_confirmation: "ancien-mot-de-passe") }

    it "relie Google au compte existant au lieu d'en créer un autre" do
      user = nil
      expect { user = User.from_omniauth(google_auth) }.not_to change(User, :count)
      expect(user).to eq(existing)
      expect(existing.reload).to have_attributes(provider: "google_oauth2", uid: "google-123")
      expect(user.just_linked_to_google).to be true
    end

    it "remplace le mot de passe (protection contre le pré-détournement de compte)" do
      User.from_omniauth(google_auth)
      expect(existing.reload.valid_password?("ancien-mot-de-passe")).to be false
    end

    it "trouve le compte même si Google renvoie l'adresse avec des majuscules" do
      expect(User.from_omniauth(google_auth(email: "Eva@Gmail.com"))).to eq(existing)
    end

    it "garde l'avatar existant" do
      existing.update!(avatar_url: "https://img/mon-avatar.jpg")
      User.from_omniauth(google_auth)
      expect(existing.reload.avatar_url).to eq("https://img/mon-avatar.jpg")
    end
  end

  it "refuse une adresse non vérifiée par Google, sans toucher au compte existant" do
    existing = create(:user, email: "eva@gmail.com")
    user = User.from_omniauth(google_auth(verified: false))
    expect(user).not_to be_persisted
    expect(user.errors.full_messages.first).to include("n'a pas vérifié")
    expect(existing.reload.uid).to be_nil
  end

  it "refuse de remplacer en silence le lien vers un autre compte Google" do
    create(:user, email: "eva@gmail.com", provider: "google_oauth2", uid: "autre-compte")
    user = User.from_omniauth(google_auth(uid: "google-123"))
    expect(user).not_to be_persisted
    expect(user.errors.full_messages.first).to include("déjà reliée à un autre compte Google")
  end

  it "la base interdit de relier un même compte Google à deux comptes" do
    create(:user, provider: "google_oauth2", uid: "google-123")
    expect { create(:user, provider: "google_oauth2", uid: "google-123") }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
