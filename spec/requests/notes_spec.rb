require "rails_helper"

RSpec.describe "Notes", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  describe "POST /notes" do
    it "sans titre : formulaire réaffiché avec le message, onglet Note" do
      post notes_path, params: { note: { title: "" } }
      expect(response).to have_http_status(422)
      expect(response.body).to include("Le titre ne peut pas être vide")
      expect(response.body).to include('data-carnet-toggle-initial-value="note"')
    end

    it "accepte une de ses propres collections" do
      collection = Collection.create!(title: "Mienne", category: "books")
      UserCollection.create!(user: user, collection: collection, role: "owner")
      post notes_path, params: { note: { title: "OK", collection_id: collection.id } }
      expect(Note.last.collection).to eq(collection)
    end

    it "refuse la collection d'un autre, avec un message" do
      collection = Collection.create!(title: "Secrète", category: "books")
      UserCollection.create!(user: create(:user), collection: collection, role: "owner")
      post notes_path, params: { note: { title: "Spam", collection_id: collection.id } }
      expect(response.body).to include("Cette collection n&#39;est pas accessible")
    end
  end

  describe "PATCH /notes/:id" do
    it "refuse aussi la collection d'un autre à la modification" do
      note = create(:note, user: user)
      collection = Collection.create!(title: "Secrète", category: "books")
      UserCollection.create!(user: create(:user), collection: collection, role: "owner")
      patch note_path(note), params: { note: { collection_id: collection.id } }
      expect(response).to have_http_status(422)
      expect(note.reload.collection_id).to be_nil
    end
  end

  describe "POST /notes/:id/share" do
    it "copie la note chez l'ami et renvoie du HTML (pas du texte échappé)" do
      friend = create(:user)
      create(:friendship, requester: user, receiver: friend, status: "accepted")
      note = create(:note, user: user)

      expect { post share_note_path(note), params: { friend_id: friend.id }, as: :turbo_stream }.to change(friend.notes, :count).by(1)
      expect(response.body).to include('<p class="text-xs text-green-500 font-semibold">Envoyé !</p>')
    end
  end
end
