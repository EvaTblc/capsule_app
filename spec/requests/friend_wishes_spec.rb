require "rails_helper"

RSpec.describe "Souhaits d'un ami", type: :request do
  let(:user) { create(:user) }
  let(:lou) { create(:user, email: "lou@exemple.fr") }
  let(:lou_games) { create(:collection, title: "Jeux de Lou", category: "video_games") }
  let(:lou_books) { create(:collection, title: "Bibliothèque", category: "books") }

  before do
    create(:friendship, requester: lou, receiver: user, status: "accepted")
    sign_in user
  end

  def wish_by(member, collection, title, **attributes)
    create(:wish, :by_member, member: member, collection: collection, title: title, **attributes)
  end

  def sections
    Nokogiri::HTML(response.body).css("section").map do |section|
      [ section.at_css("h2").text.squish, section.css(".divide-y > div p.font-bold").map(&:text) ]
    end
  end

  it "groupés par collection (triées), titres triés, en lecture seule (aucun lien vers une fiche)" do
    wish_by(lou, lou_games, "Zelda 10", max_price: 20)
    create(:wish, collection: lou_games, author: lou, title: "Zelda 2")
    wish_by(lou, lou_books, "Veiller sur elle")
    get friend_wishes_path(lou)

    expect(response.body).to include("Ce que lou cherche")
    expect(sections).to eq([ [ "Bibliothèque", [ "Veiller sur elle" ] ], [ "Jeux de Lou", [ "Zelda 2", "Zelda 10" ] ] ])
    expect(response.body).not_to include("/wishes/")
    expect(response.body).to include("20\u00a0€") # espace insécable : le prix ne se coupe pas
  end

  it "seulement ce que l'ami a ajouté : pas les souhaits des autres membres de ses collections" do
    wish_by(lou, lou_games, "Ōkami")
    stranger = create(:user)
    create(:user_collection, user: stranger, collection: lou_games, role: "member")
    create(:wish, collection: lou_games, author: stranger, title: "Pas de Lou")
    get friend_wishes_path(lou)
    expect(response.body).to include("Ōkami")
    expect(response.body).not_to include("Pas de Lou")
  end

  it "ami qui a coupé l'interrupteur : message, aucun souhait" do
    wish_by(lou, lou_games, "Secret")
    lou.update!(wishes_visible_to_friends: false)
    get friend_wishes_path(lou)
    expect(response.body).to include("lou ne partage pas ses souhaits.")
    expect(response.body).not_to include("Secret")
  end

  it "ami sans souhait : message" do
    get friend_wishes_path(lou)
    expect(Nokogiri::HTML(response.body).text).to include("lou ne cherche rien pour l'instant.")
  end

  it "pas (ou pas encore) ami : 404" do
    pending_friend = create(:user)
    create(:friendship, requester: user, receiver: pending_friend, status: "pending")
    get friend_wishes_path(pending_friend)
    expect(response).to have_http_status(:not_found)
    sign_in user # après un 404, le cookie de session n'est pas réécrit
    get friend_wishes_path(create(:user))
    expect(response).to have_http_status(:not_found)
  end

  it "profil : chaque ami mène à ses souhaits" do
    get profile_path
    expect(response.body).to include(friend_wishes_path(lou), "Voir ses souhaits")
  end

  it "nombre de requêtes constant, quel que soit le nombre de souhaits et de collections" do
    wish_by(lou, lou_games, "Un")
    get friend_wishes_path(lou) # chauffe
    count = lambda do
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:sql] =~ /\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/ }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get friend_wishes_path(lou) }
      queries
    end
    small = count.call
    3.times { |i| wish_by(lou, create(:collection, title: "Coll #{i}"), "Jeu #{i}") }
    expect(count.call).to eq(small)
  end
end
