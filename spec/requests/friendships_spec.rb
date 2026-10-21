require "rails_helper"

RSpec.describe "Demandes d'ami", type: :request do
  let(:eva) { create(:user) }
  let(:ami) { create(:user) }
  before { sign_in eva }

  def demander = post(friendships_path, params: { receiver_email: ami.email })

  it "première demande : créée" do
    expect { demander }.to change(Friendship, :count).by(1)
    expect(flash[:notice]).to eq("Demande envoyée !")
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
end
