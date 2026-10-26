require "rails_helper"

# Après une déconnexion, le bouton « retour » ne doit pas réafficher de page privée :
# ni depuis le cache du navigateur (Cache-Control), ni depuis le cache interne de Turbo
RSpec.describe "Mise en cache des pages", type: :request do
  let(:user) { create(:user) }

  context "utilisateur connecté" do
    before { sign_in user }

    it "les pages ne sont jamais stockées par le navigateur" do
      get collections_path
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    it "Turbo ne garde pas de copie de la page" do
      get collections_path
      expect(response.body).to include('<meta name="turbo-cache-control" content="no-cache">')
    end

    it "les réponses de l'API non plus" do
      get "/api/search/book"
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end
  end

  context "visiteur non connecté" do
    it "les pages publiques restent cachables normalement" do
      get root_path
      expect(response.headers["Cache-Control"]).not_to include("no-store")
      expect(response.body).not_to include("turbo-cache-control")
    end
  end
end
