require "rails_helper"

RSpec.describe "PWA", type: :request do
  describe "GET /service-worker" do
    before { get pwa_service_worker_path(format: :js) }

    it "est servi sans connexion" do
      expect(response).to have_http_status(200)
    end

    # Les pages HTML contiennent les données de l'utilisateur : elles ne doivent jamais être mises en cache,
    # sinon elles restent lisibles hors ligne après la déconnexion
    it "ne précache aucune page privée" do
      expect(response.body).not_to include('"/collections"')
      expect(response.body).not_to match(/PRECACHE_URLS/)
    end

    it "ne stocke les réponses que pour les assets versionnés" do
      expect(response.body.scan("cache.put").size).to eq(1)
      expect(response.body).to include('pathname.startsWith("/assets/")')
    end
  end

  describe "GET /offline" do
    it "est accessible sans connexion (affichée quand le réseau manque)" do
      get offline_path
      expect(response).to have_http_status(200)
    end
  end
end
