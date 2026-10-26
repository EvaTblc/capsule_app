require "rails_helper"

RSpec.describe "Lien d'invitation et membres", type: :request do
  let(:owner) { create(:user) }
  let(:member) { create(:user) }
  let(:other_member) { create(:user) }
  let!(:collection) do
    Collection.create!(title: "Partagée", category: "books").tap do |c|
      UserCollection.create!(user: owner, collection: c, role: "owner")
      UserCollection.create!(user: member, collection: c, role: "member")
      UserCollection.create!(user: other_member, collection: c, role: "member")
    end
  end
  def membership_of(user) = collection.user_collections.find_by(user: user)

  describe "régénérer le lien" do
    it "le propriétaire crée un nouveau lien : l'ancien ne fonctionne plus, le nouveau oui" do
      old_token = collection.invite_token
      sign_in owner
      patch regenerate_invite_collection_path(collection)
      expect(collection.reload.invite_token).not_to eq(old_token)

      newcomer = create(:user)
      sign_in newcomer
      expect { get invite_path(token: old_token) }.not_to change(UserCollection, :count)
      sign_in newcomer
      expect { get invite_path(token: collection.invite_token) }.to change(UserCollection, :count).by(1)
    end

    it "les membres actuels gardent leur accès" do
      sign_in owner
      patch regenerate_invite_collection_path(collection)
      expect(collection.member?(member)).to be true
    end

    it "un simple membre ne peut pas régénérer le lien" do
      old_token = collection.invite_token
      sign_in member
      patch regenerate_invite_collection_path(collection)
      expect(collection.reload.invite_token).to eq(old_token)
    end
  end

  describe "affichage" do
    it "le propriétaire voit le lien, le bouton « Nouveau lien » et peut retirer les membres" do
      sign_in owner
      get collection_path(collection)
      expect(response.body).to include(collection.invite_token, "Nouveau lien", "Retirer")
    end

    it "un simple membre voit la liste des membres, sans le lien d'invitation ni « Retirer »" do
      sign_in member
      get collection_path(collection)
      expect(response.body).to include("Membres", member.email.split("@").first, "Quitter")
      expect(response.body).not_to include(collection.invite_token)
      expect(response.body).not_to include("Nouveau lien")
      expect(response.body).not_to include("Retirer")
    end
  end

  describe "retirer un membre" do
    it "le propriétaire retire un membre, qui perd l'accès" do
      sign_in owner
      expect { delete collection_membership_path(collection, membership_of(member)) }.to change(UserCollection, :count).by(-1)
      expect(collection.member?(member)).to be false

      sign_in member
      get collection_path(collection)
      expect(response).to have_http_status(404)
    end

    it "les notes du membre retiré ne restent pas affichées dans la collection" do
      note = create(:note, user: member, collection: collection)
      sign_in owner
      delete collection_membership_path(collection, membership_of(member))
      expect(note.reload.collection_id).to be_nil
      expect(Note.exists?(note.id)).to be true # la note reste à son auteur
    end

    it "un membre ne peut pas retirer un autre membre" do
      sign_in member
      expect { delete collection_membership_path(collection, membership_of(other_member)) }.not_to change(UserCollection, :count)
    end

    it "le propriétaire ne peut pas être retiré" do
      sign_in owner
      expect { delete collection_membership_path(collection, membership_of(owner)) }.not_to change(UserCollection, :count)
    end

    it "une personne extérieure ne peut rien retirer (404)" do
      sign_in create(:user)
      delete collection_membership_path(collection, membership_of(member))
      expect(response).to have_http_status(404)
      expect(collection.member?(member)).to be true
    end
  end

  describe "quitter une collection" do
    it "un membre peut partir de lui-même" do
      sign_in member
      delete collection_membership_path(collection, membership_of(member))
      expect(response).to redirect_to(collections_path)
      expect(collection.member?(member)).to be false
    end
  end

  it "supprimer la collection supprime toujours ses notes (pas de détachement dans ce cas)" do
    note = create(:note, user: member, collection: collection)
    collection.destroy
    expect(Note.exists?(note.id)).to be false
  end
end
