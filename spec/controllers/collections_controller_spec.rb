require "rails_helper"

RSpec.describe CollectionsController, type: :controller do
  let(:user) { create(:user) }
  let(:collection) { create(:collection) }

  before { sign_in user }

  before do
    create(:user_collection, user: user, collection: collection, role: "owner")
  end

  describe "GET #index" do
    it "retourne un succès" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "assigne les collections de l'utilisateur" do
      get :index
      expect(assigns(:collections)).to include(collection)
    end
  end

  describe "GET #show" do
    it "retourne un succès" do
      get :show, params: { id: collection.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    context "avec des paramètres valides" do
      it "crée une collection" do
        expect {
          post :create, params: { collection: { title: "Ma collection", category: "books" } }
        }.to change(Collection, :count).by(1)
      end

      it "redirige vers la collection créée" do
        post :create, params: { collection: { title: "Ma collection", category: "books" } }
        expect(response).to redirect_to(collection_path(Collection.last))
      end
    end
  end

  describe "DELETE #destroy" do
    it "supprime la collection" do
      expect {
        delete :destroy, params: { id: collection.id }
      }.to change(Collection, :count).by(-1)
    end

    it "redirige vers l'index" do
      delete :destroy, params: { id: collection.id }
      expect(response).to redirect_to(collections_path)
    end
  end
end
