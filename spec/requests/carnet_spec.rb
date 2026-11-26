require "rails_helper"

RSpec.describe "Mon Carnet", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  def page_text = Nokogiri::HTML(response.body).text.squish

  def collection_of(title)
    create(:collection, title: title, category: "video_games").tap do |collection|
      create(:user_collection, user: user, collection: collection)
    end
  end

  describe "Ce que je cherche" do
    it "les souhaits de toutes mes collections, groupés par collection (triées), chacun vers sa fiche" do
      games = collection_of("Mes jeux")
      retro = collection_of("Rétro")
      okami = create(:wish, collection: games, title: "Ōkami", max_price: 20)
      create(:wish, collection: retro, title: "Chrono Trigger")
      create(:wish, collection: create(:collection), title: "Pas à moi")

      get carnet_path
      expect(page_text).to include("Ce que je cherche 2 souhaits Mes jeux Ōkami", "Rétro Chrono Trigger")
      expect(page_text).not_to include("Pas à moi")
      expect(response.body).to include(edit_collection_wish_path(games, okami))
    end

    it "aucun souhait : explique où en ajouter" do
      get carnet_path
      expect(page_text).to include("Rien pour l'instant : ajoute un souhait depuis une de tes collections")
    end
  end

  describe "événements" do
    it "prochaine sortie : l'événement à venir le plus proche, avec le compte à rebours" do
      create(:event, user: user, title: "Brocante passée", date: Date.current - 2)
      create(:event, user: user, title: "Vide-grenier de Montreuil", date: Date.current + 5, address: "Place de la mairie")
      create(:event, user: user, title: "Plus tard", date: Date.current + 20)

      get carnet_path
      expect(page_text).to include("Prochaine sortie · dans 5 jours Vide-grenier de Montreuil Place de la mairie")
      expect(page_text).to include("Événements 2 à venir")
    end

    it "demain / aujourd'hui" do
      create(:event, user: user, title: "Demain", date: Date.current + 1)
      get carnet_path
      expect(page_text).to include("Prochaine sortie · demain")
    end

    it "rien à venir : pas de prochaine sortie, et une invitation à en ajouter" do
      get carnet_path
      expect(page_text).not_to include("Prochaine sortie")
      expect(page_text).to include("Aucun événement pour l'instant")
    end

    it "bouton flottant « Événement » vers le formulaire ; sans adresse, invitation à en saisir une" do
      get carnet_path
      page = Nokogiri::HTML(response.body)
      expect(page.css("a[href='#{new_event_path}']").text.squish).to eq("Événement")
      expect(page_text).to include("Ajoute ton adresse dans ton profil pour trouver les brocantes près de chez toi")
    end

    it "les événements des autres n'apparaissent pas" do
      create(:event, user: create(:user), title: "Secret", date: Date.current + 3)
      get carnet_path
      expect(page_text).not_to include("Secret")
    end
  end

  it "onglet « Mon Carnet » de la barre de navigation" do
    get carnet_path
    current = Nokogiri::HTML(response.body).css("nav[aria-label='Navigation principale'] a[aria-current='page']").text.squish
    expect(current).to eq("Mon Carnet")
  end

  it "nombre de requêtes constant, quel que soit le nombre de souhaits, de collections et d'événements" do
    count = lambda do
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:sql] =~ /\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/ }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get carnet_path }
      queries
    end
    create(:wish, collection: collection_of("Une"), title: "Un")
    create(:event, user: user, date: Date.current + 1)
    get carnet_path # chauffe
    small = count.call
    3.times do |i|
      create(:wish, collection: collection_of("Coll #{i}"), title: "Jeu #{i}")
      create(:event, user: user, date: Date.current + i + 2)
    end
    expect(count.call).to eq(small)
  end
end
