require "rails_helper"

RSpec.describe "Profil", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  def collection_with_role(title, role, category: "books")
    Collection.create!(title: title, category: category).tap do |c|
      UserCollection.create!(user: user, collection: c, role: role)
    end
  end

  def game(collection)
    create(:item, collection: collection, item_detailable: create(:video_game_detail, platform: "Switch"),
                  item_detailable_type: "VideoGameDetail")
  end

  def count_queries
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:sql] =~ /\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/ }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    queries
  end

  it "nombre de requêtes constant, quel que soit le nombre de collections, d'items et d'amis" do
    add = lambda do |n|
      games = collection_with_role("Jeux #{n}", "owner", category: "video_games")
      books = collection_with_role("Livres #{n}", "member")
      n.times { game(games); create(:item, collection: books) }
      create(:friendship, requester: user, receiver: create(:user), status: "accepted")
    end
    add.(2)
    get profile_path # chauffe : la 1re requête de test ne recharge pas l'utilisateur depuis la session
    small = count_queries { get profile_path }
    add.(10)
    expect(count_queries { get profile_path }).to eq(small)
  end

  it "un item d'un autre type dans une collection (livre parmi les jeux) : le profil s'affiche, sans le compter" do
    games = collection_with_role("Jeux", "owner", category: "video_games")
    game(games)
    create(:item, collection: games) # livre (type par défaut de la factory)
    get profile_path
    expect(response).to have_http_status(200)
  end

  it "le bouton « Retirer » de chaque ami vise la bonne amitié, dans les deux sens" do
    asked = create(:friendship, requester: user, receiver: create(:user), status: "accepted")
    received = create(:friendship, requester: create(:user), receiver: user, status: "accepted")
    get profile_path
    expect(response.body).to include(friendship_path(asked), friendship_path(received))
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
