require "rails_helper"

RSpec.describe "Invitations", type: :request do
  let(:owner) { create(:user) }
  let(:guest) { create(:user) }
  let!(:collection) do
    Collection.create!(title: "Partagée", category: "books").tap do |c|
      UserCollection.create!(user: owner, collection: c, role: "owner")
    end
  end

  it "rejoindre une collection crée une adhésion membre" do
    sign_in guest
    expect { get invite_path(token: collection.invite_token) }.to change(UserCollection, :count).by(1)
    expect(collection.user_collections.find_by(user: guest).role).to eq("member")
  end

  it "rejoindre deux fois ne crée pas de doublon" do
    UserCollection.create!(user: guest, collection: collection, role: "member")
    sign_in guest
    expect { get invite_path(token: collection.invite_token) }.not_to change(UserCollection, :count)
  end

  it "le propriétaire qui ouvre son propre lien reste propriétaire" do
    sign_in owner
    get invite_path(token: collection.invite_token)
    expect(collection.user_collections.find_by(user: owner).role).to eq("owner")
  end

  it "un lien invalide redirige avec un message" do
    sign_in guest
    get invite_path(token: "nimporte-quoi")
    expect(flash[:alert]).to eq("Lien invalide.")
  end
end
