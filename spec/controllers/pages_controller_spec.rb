require "rails_helper"

RSpec.describe PagesController, type: :controller do
  let(:user) { create(:user) }

  describe "GET #home" do
    it "retourne un succès sans être connecté" do
      get :home
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #profile" do
    before { sign_in user }

    it "retourne un succès" do
      get :profile
      expect(response).to have_http_status(:success)
    end

    it "assigne les collections owned" do
      collection = create(:collection)
      create(:user_collection, user: user, collection: collection, role: "owner")
      get :profile
      expect(assigns(:collections_owned)).to include(collection)
    end

    it "assigne les collections shared" do
      collection = create(:collection)
      create(:user_collection, user: user, collection: collection, role: "member")
      get :profile
      expect(assigns(:collections_shared)).to include(collection)
    end
  end

  describe "GET #edit_address" do
    before { sign_in user }

    it "retourne un succès" do
      get :edit_address
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH #update_address" do
    before { sign_in user }

    it "met à jour l'adresse" do
      patch :update_address, params: { user: { address: "Nantes, Loire-Atlantique" } }
      expect(user.reload.address).to eq("Nantes, Loire-Atlantique")
    end

    it "redirige vers le profil" do
      patch :update_address, params: { user: { address: "Nantes, Loire-Atlantique" } }
      expect(response).to redirect_to(profile_path)
    end
  end
end
