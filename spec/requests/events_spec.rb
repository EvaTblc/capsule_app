require "rails_helper"

RSpec.describe "Événements", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  describe "POST /events" do
    it "sans titre : formulaire réaffiché avec le message, onglet Événement" do
      post events_path, params: { event: { title: "" } }
      expect(response).to have_http_status(422)
      expect(response.body).to include("Le titre ne peut pas être vide")
      expect(response.body).to include('data-carnet-toggle-initial-value="event"')
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
