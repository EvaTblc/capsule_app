require "rails_helper"

RSpec.describe "Barre d'onglets", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  def current_tab
    Nokogiri::HTML(response.body).css("nav[aria-label='Navigation principale'] a[aria-current='page']").map(&:text).map(&:strip)
  end

  it "l'onglet de la page en cours est signalé (et lui seul)" do
    get collections_path
    expect(current_tab).to eq([ "Collections" ])

    get notes_path
    expect(current_tab).to eq([ "Mon Carnet" ])

    get profile_path
    expect(current_tab).to eq([ "Profil" ])
  end

  it "une page d'item reste dans l'onglet Collections" do
    collection = Collection.create!(title: "Jeux", category: "video_games")
    UserCollection.create!(user: user, collection: collection, role: "owner")
    item = Item.create!(title: "Elden Ring", collection: collection, item_detailable: VideoGameDetail.create!(completed: false))
    get collection_item_path(collection, item)
    expect(current_tab).to eq([ "Collections" ])
    expect(response.body).not_to include("#EF4444") # plus de ✕ rouge pour un jeu incomplet
  end
end
