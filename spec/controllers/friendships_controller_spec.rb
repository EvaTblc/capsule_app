require "rails_helper"

RSpec.describe FriendshipsController, type: :controller do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before { sign_in user }

  describe "POST #create" do
    it "crée une demande d'amitié" do
      expect {
        post :create, params: { receiver_email: other_user.email }
      }.to change(Friendship, :count).by(1)
    end

    it "crée la demande avec status pending" do
      post :create, params: { receiver_email: other_user.email }
      expect(Friendship.last.status).to eq("pending")
    end

    it "redirige vers le profil" do
      post :create, params: { receiver_email: other_user.email }
      expect(response).to redirect_to(profile_path)
    end

    context "avec un email inexistant" do
      it "ne crée pas de friendship" do
        expect {
          post :create, params: { receiver_email: "inconnu@test.com" }
        }.not_to change(Friendship, :count)
      end

      it "redirige vers le profil avec une alerte" do
        post :create, params: { receiver_email: "inconnu@test.com" }
        expect(response).to redirect_to(profile_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "quand on s'ajoute soi-même" do
      it "ne crée pas de friendship" do
        expect {
          post :create, params: { receiver_email: user.email }
        }.not_to change(Friendship, :count)
      end
    end
  end

  describe "PATCH #accept" do
    let!(:friendship) { create(:friendship, requester: other_user, receiver: user, status: "pending") }

    it "accepte la demande" do
      patch :accept, params: { id: friendship.id }
      expect(friendship.reload.status).to eq("accepted")
    end

    it "redirige vers le profil" do
      patch :accept, params: { id: friendship.id }
      expect(response).to redirect_to(profile_path)
    end
  end

  describe "PATCH #reject" do
    let!(:friendship) { create(:friendship, requester: other_user, receiver: user, status: "pending") }

    it "refuse la demande" do
      patch :reject, params: { id: friendship.id }
      expect(friendship.reload.status).to eq("rejected")
    end
  end

  describe "DELETE #destroy" do
    let!(:friendship) { create(:friendship, requester: user, receiver: other_user, status: "accepted") }

    it "supprime l'amitié" do
      expect {
        delete :destroy, params: { id: friendship.id }
      }.to change(Friendship, :count).by(-1)
    end

    it "redirige vers le profil" do
      delete :destroy, params: { id: friendship.id }
      expect(response).to redirect_to(profile_path)
    end
  end
end
