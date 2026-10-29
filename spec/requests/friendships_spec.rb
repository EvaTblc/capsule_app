require "rails_helper"

RSpec.describe "Demandes d'ami", type: :request do
  let(:eva) { create(:user) }
  let(:ami) { create(:user) }
  before { sign_in eva }

  def demander = post(friendships_path, params: { receiver_email: ami.email })

  it "première demande : créée en attente, retour au profil" do
    expect { demander }.to change(Friendship, :count).by(1)
    expect(Friendship.last).to have_attributes(requester: eva, receiver: ami, status: "pending")
    expect(response).to redirect_to(profile_path)
    expect(flash[:notice]).to eq("Demande envoyée !")
  end

  it "email inconnu : rien de créé, alerte" do
    expect { post friendships_path, params: { receiver_email: "inconnu@test.com" } }.not_to change(Friendship, :count)
    expect(response).to redirect_to(profile_path)
    expect(flash[:alert]).to be_present
  end

  it "sa propre adresse : rien de créé" do
    expect { post friendships_path, params: { receiver_email: eva.email } }.not_to change(Friendship, :count)
  end

  it "deuxième demande : pas de doublon" do
    demander
    expect { demander }.not_to change(Friendship, :count)
    expect(flash[:alert]).to eq("Demande déjà envoyée.")
  end

  it "l'autre m'avait déjà demandé : on devient amis, sans doublon inverse" do
    demande = create(:friendship, requester: ami, receiver: eva, status: "pending")
    expect { demander }.not_to change(Friendship, :count)
    expect(demande.reload).to be_accepted
    expect(flash[:notice]).to eq("Vous êtes maintenant amis !")
  end

  it "déjà amis : message clair" do
    create(:friendship, requester: ami, receiver: eva, status: "accepted")
    demander
    expect(flash[:alert]).to eq("Vous êtes déjà amis.")
  end

  it "l'autre m'a refusée : pas de nouvelle demande, et le refus n'est pas révélé" do
    create(:friendship, requester: eva, receiver: ami, status: "rejected")
    expect { demander }.not_to change(Friendship, :count)
    expect(flash[:alert]).to eq("Demande déjà envoyée.")
  end

  describe "réponse à une demande reçue" do
    let!(:demande) { create(:friendship, requester: ami, receiver: eva, status: "pending") }

    it "accepter" do
      patch accept_friendship_path(demande)
      expect(demande.reload.status).to eq("accepted")
      expect(response).to redirect_to(profile_path)
    end

    it "refuser" do
      patch reject_friendship_path(demande)
      expect(demande.reload.status).to eq("rejected")
    end
  end

  it "retirer un ami" do
    amitie = create(:friendship, requester: eva, receiver: ami, status: "accepted")
    expect { delete friendship_path(amitie) }.to change(Friendship, :count).by(-1)
    expect(response).to redirect_to(profile_path)
  end
end
