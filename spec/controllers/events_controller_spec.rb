require "rails_helper"

RSpec.describe EventsController, type: :controller do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET #show" do
    let(:event) { create(:event, user: user) }

    it "retourne un succès" do
      get :show, params: { id: event.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    context "avec des paramètres valides" do
      it "crée un event" do
        expect {
          post :create, params: { event: { title: "Vide grenier", date: Date.today + 7, address: "Nantes", reminder: false } }
        }.to change(Event, :count).by(1)
      end

      it "redirige vers l'event créé" do
        post :create, params: { event: { title: "Vide grenier", date: Date.today + 7, address: "Nantes", reminder: false } }
        expect(response).to redirect_to(event_path(Event.last))
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:event) { create(:event, user: user) }

    it "supprime l'event" do
      expect {
        delete :destroy, params: { id: event.id }
      }.to change(Event, :count).by(-1)
    end

    it "redirige vers notes_path" do
      delete :destroy, params: { id: event.id }
      expect(response).to redirect_to(notes_path)
    end
  end

  describe "POST #list_events" do
    context "quand l'user n'a pas d'adresse" do
      it "ne plante pas" do
        allow(Geocoder).to receive(:search).and_return([])
        allow(Scraper).to receive(:call).and_return([])
        post :list_events, format: :turbo_stream
        expect(response).to have_http_status(:success)
      end
    end

    context "quand le scraper retourne des events" do
      it "crée les events en base" do
        user.update(address: "Nantes")
        allow(Geocoder).to receive(:search).and_return(
          [double(postal_code: "44000", latitude: 47.21, longitude: -1.55, coordinates: [47.21, -1.55])]
        )
        allow(Scraper).to receive(:call).and_return([
          {
            title: "Vide grenier test",
            date: Date.today + 2,
            address: "Place du Commerce",
            city: "Nantes",
            latitude: 47.21,
            longitude: -1.55,
            url: "https://brocabrac.fr/test"
          }
        ])

        expect {
          post :list_events, format: :turbo_stream
        }.to change(Event, :count).by(1)
      end
    end
  end
end
