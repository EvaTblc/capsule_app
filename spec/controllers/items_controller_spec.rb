require "rails_helper"

RSpec.describe ItemsController, type: :controller do
  let(:user) { create(:user) }
  let(:collection) { create(:collection) }
  let(:book_detail) { create(:book_detail) }
  let(:item) { create(:item, collection: collection, item_detailable: book_detail, item_detailable_type: "BookDetail", item_type: "BookDetail") }

  before do
    sign_in user
    create(:user_collection, user: user, collection: collection, role: "owner")
  end

  describe "GET #show" do
    it "retourne un succès" do
      get :show, params: { collection_id: collection.id, id: item.id }
      expect(response).to have_http_status(:success)
    end

    it "assigne l'item" do
      get :show, params: { collection_id: collection.id, id: item.id }
      expect(assigns(:item)).to eq(item)
    end
  end

  describe "GET #new" do
    it "retourne un succès" do
      get :new, params: { collection_id: collection.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    context "avec un BookDetail" do
      it "crée un item et un book_detail" do
        expect {
          post :create, params: {
            collection_id: collection.id,
            item: { title: "Dune", condition: "Neuf", item_type: "BookDetail" },
            book_detail: { author: "Frank Herbert", isbn: "9782266320481" }
          }
        }.to change(Item, :count).by(1).and change(BookDetail, :count).by(1)
      end

      it "redirige vers la collection" do
        post :create, params: {
          collection_id: collection.id,
          item: { title: "Dune", condition: "Neuf", item_type: "BookDetail" },
          book_detail: { author: "Frank Herbert", isbn: "9782266320481" }
        }
        expect(response).to redirect_to(collection_path(collection))
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:item_to_destroy) { create(:item, collection: collection, item_detailable: create(:book_detail), item_detailable_type: "BookDetail", item_type: "BookDetail") }

    it "supprime l'item" do
      expect {
        delete :destroy, params: { collection_id: collection.id, id: item_to_destroy.id }
      }.to change(Item, :count).by(-1)
    end

    it "redirige vers la collection" do
      delete :destroy, params: { collection_id: collection.id, id: item_to_destroy.id }
      expect(response).to redirect_to(collection_path(collection))
    end
  end
end
