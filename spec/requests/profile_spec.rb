require "rails_helper"

RSpec.describe "Profil", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  def collection_with_role(title, role)
    Collection.create!(title: title, category: "books").tap do |c|
      UserCollection.create!(user: user, collection: c, role: role)
    end
  end

  it "montre ses collections et celles partagées avec soi" do
    collection_with_role("Mes livres", "owner")
    collection_with_role("Livres d'une amie", "member")
    get profile_path
    expect(assigns(:collections_owned).map(&:title)).to eq([ "Mes livres" ])
    expect(assigns(:collections_shared).map(&:title)).to eq([ "Livres d'une amie" ])
  end

  it "page adresse" do
    get edit_address_path
    expect(response).to have_http_status(200)
  end

  it "enregistre l'adresse et revient au profil" do
    patch update_address_path, params: { user: { address: "Nantes, Loire-Atlantique" } }
    expect(user.reload.address).to eq("Nantes, Loire-Atlantique")
    expect(response).to redirect_to(profile_path)
  end
end
