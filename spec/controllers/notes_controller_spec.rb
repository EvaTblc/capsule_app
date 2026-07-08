require "rails_helper"

RSpec.describe NotesController, type: :controller do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET #index" do
    it "retourne un succès" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "assigne les notes de l'utilisateur" do
      note = create(:note, user: user)
      get :index
      expect(assigns(:notes)).to include(note)
    end

    it "n'affiche pas les notes des autres users" do
      autre_user = create(:user)
      note_autre = create(:note, user: autre_user)
      get :index
      expect(assigns(:notes)).not_to include(note_autre)
    end
  end

  describe "GET #show" do
    let(:note) { create(:note, user: user) }

    it "retourne un succès" do
      get :show, params: { id: note.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    context "avec des paramètres valides" do
      it "crée une note" do
        expect {
          post :create, params: { note: { title: "Ma note", comment: "Contenu", reminder: false } }
        }.to change(Note, :count).by(1)
      end

      it "redirige vers la note créée" do
        post :create, params: { note: { title: "Ma note", comment: "Contenu", reminder: false } }
        expect(response).to redirect_to(note_path(Note.last))
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:note) { create(:note, user: user) }

    it "supprime la note" do
      expect {
        delete :destroy, params: { id: note.id }
      }.to change(Note, :count).by(-1)
    end

    it "redirige vers l'index" do
      delete :destroy, params: { id: note.id }
      expect(response).to redirect_to(notes_path)
    end
  end
end
