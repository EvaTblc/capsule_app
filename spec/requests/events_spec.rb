require "rails_helper"

RSpec.describe "Événements", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  describe "POST /events" do
    it "crée l'événement et redirige vers lui" do
      expect { post events_path, params: { event: { title: "Vide grenier", date: Date.today + 7, address: "Nantes", reminder: false } } }
        .to change(user.events, :count).by(1)
      expect(response).to redirect_to(event_path(Event.last))
      follow_redirect!
      expect(response.body).to include("Vide grenier")
    end

    it "sans titre : formulaire réaffiché avec le message" do
      post events_path, params: { event: { title: "" } }
      expect(response).to have_http_status(422)
      expect(response.body).to include("Le titre ne peut pas être vide", "Nouvel événement", 'name="event[title]"')
    end

    it "page « Nouvel événement » : formulaire complet, retour au carnet" do
      get new_event_path
      page = Nokogiri::HTML(response.body)
      %w[title date address url comment reminder].each { |field| expect(page.css("[name='event[#{field}]']")).to be_present }
      expect(page.css("a[href='#{carnet_path}']")).to be_present
    end
  end

  describe "PATCH /events/:id" do
    it "modifier : titre « Modifier l'événement », erreurs affichées" do
      event = create(:event, user: user, title: "Brocante")
      get edit_event_path(event)
      expect(Nokogiri::HTML(response.body).text).to include("Modifier l'événement")
      patch event_path(event), params: { event: { title: "" } }
      expect(response).to have_http_status(422)
      expect(response.body).to include("Le titre ne peut pas être vide")
    end
  end

  describe "GET /events/:id (détail)" do
    def page_text = Nokogiri::HTML(response.body).text.squish

    it "date en toutes lettres et compte à rebours, rappel, adresse, lien, commentaire, Modifier / Supprimer" do
      event = create(:event, user: user, title: "Vide-grenier de Montreuil", date: Date.new(2026, 12, 1), reminder: true,
                             address: "Place de la mairie", url: "https://brocabrac.fr/1", comment: "Parking derrière l'église")
      travel_to Date.new(2026, 11, 26) do
        get event_path(event)
      end
      expect(page_text).to include("mardi 1 décembre · dans 5 jours", "Vide-grenier de Montreuil", "Rappel activé",
                                   "Place de la mairie", "Voir l'annonce", "Parking derrière l'église")
      page = Nokogiri::HTML(response.body)
      expect(page.css("a[href='#{edit_event_path(event)}']").text.squish).to eq("Modifier")
      expect(page.css("button").map { |button| button["aria-label"] }).to include("Supprimer l'événement")
      expect(page.css("a[href='https://brocabrac.fr/1']").first["rel"]).to eq("noopener")
    end

    it "événement minimal (ni date, ni adresse, ni lien) : la page s'affiche quand même" do
      event = Event.create!(user: user, title: "Sans rien")
      get event_path(event)
      expect(response).to have_http_status(:ok)
      expect(page_text).to include("Sans rien")
      expect(page_text).not_to include("Rappel activé", "Voir l'annonce")
    end

    it "partage : un bouton par ami ; aucun ami, pas de section" do
      get event_path(create(:event, user: user))
      expect(page_text).not_to include("Partager avec")
      friend = create(:user, email: "lou@exemple.fr")
      create(:friendship, requester: user, receiver: friend, status: "accepted")
      event = create(:event, user: user)
      get event_path(event)
      share = Nokogiri::HTML(response.body).css("#share-event-#{event.id} button").map { |button| button.text.squish }
      expect(share).to eq([ "L lou" ]) # initiale de l'avatar, puis le nom
    end
  end

  describe "DELETE /events/:id" do
    it "supprime l'événement et revient au carnet" do
      event = create(:event, user: user)
      expect { delete event_path(event) }.to change(Event, :count).by(-1)
      expect(response).to redirect_to(carnet_path)
    end
  end

  describe "POST /events/:id/share" do
    let(:friend) { create(:user) }
    before { create(:friendship, requester: user, receiver: friend, status: "accepted") }

    it "copie l'événement chez l'ami" do
      event = create(:event, user: user, url: "https://brocabrac.fr/1")
      expect { post share_event_path(event), params: { friend_id: friend.id } }.to change(friend.events, :count).by(1)
      expect(friend.events.last.sender).to eq(user)
    end

    it "réponse Turbo : le partage est remplacé par « Envoyé à … ! »" do
      event = create(:event, user: user)
      post share_event_path(event), params: { friend_id: friend.id }, as: :turbo_stream
      expect(response.body).to include(%(target="share-event-#{event.id}"), "Envoyé à #{friend.email.split('@').first} !")
    end

    it "ne duplique pas une brocante que l'ami a déjà (et ne plante pas)" do
      event = create(:event, user: user, url: "https://brocabrac.fr/1")
      create(:event, user: friend, url: "https://brocabrac.fr/1")
      expect { post share_event_path(event), params: { friend_id: friend.id } }.not_to change(Event, :count)
      expect(response).to redirect_to(event_path(event))
    end

    it "partage toujours un événement saisi à la main (sans lien)" do
      event = create(:event, user: user, url: nil)
      create(:event, user: friend, url: nil)
      expect { post share_event_path(event), params: { friend_id: friend.id } }.to change(friend.events, :count).by(1)
    end
  end

  describe "POST /events/list (brocantes autour de chez soi)" do
    let(:brocante) do
      { title: "Vide grenier", date: Date.today + 2, address: "Place", city: "Nantes",
        latitude: 47.21, longitude: -1.55, url: "https://brocabrac.fr/x" }
    end

    def list_events = post(list_events_path, as: :turbo_stream)

    it "sans adresse : pas de scraping, message clair" do
      expect(Scraper).not_to receive(:call)
      list_events
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Ajoute ton adresse")
    end

    context "avec une adresse" do
      before { user.update_columns(address: "Nantes", latitude: 47.2, longitude: -1.5) }

      def with_postal_code(code)
        allow(Geocoder).to receive(:search).and_return([ double(postal_code: code, coordinates: [ 47.2, -1.5 ]) ])
      end

      it "importe les brocantes avec les coordonnées du scraper, sans les regéocoder" do
        with_postal_code("44000")
        allow(Scraper).to receive(:call).with("44").and_return([ brocante ])
        expect { list_events }.to change(Event, :count).by(1)
        expect(Geocoder).to have_received(:search).once # seulement pour trouver le département
        expect(Event.last.latitude.to_f).to eq(47.21)
        expect(response.body).to include("Vide grenier")
      end

      it "scraper en panne : la page reste affichée avec un message" do
        with_postal_code("44000")
        allow(Scraper).to receive(:call).and_raise(Scraper::NetworkError, "boom")
        list_events
        expect(response).to have_http_status(:success)
        expect(response.body).to include("indisponible")
      end

      it("Ajaccio → département 2a") do
        with_postal_code("20000")
        expect(Scraper).to receive(:call).with("2a").and_return([])
        list_events
      end

      it("Bastia → département 2b") do
        with_postal_code("20200")
        expect(Scraper).to receive(:call).with("2b").and_return([])
        list_events
      end

      it "DOM : pas de scraping, message métropole" do
        with_postal_code("97110")
        expect(Scraper).not_to receive(:call)
        list_events
        expect(response.body).to include("France métropolitaine")
      end
    end
  end
end
