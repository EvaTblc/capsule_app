require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { should have_many(:user_collections) }
    it { should have_many(:notes) }
    it { should have_many(:events) }
    it { should have_many(:sent_friendships).class_name("Friendship") }
    it { should have_many(:received_friendships).class_name("Friendship") }
  end

  describe "validations" do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end

  describe "#accepted_friends" do
    it "retourne les amis acceptés des deux côtés" do
      eva = create(:user)
      ami = create(:user)
      create(:friendship, requester: eva, receiver: ami, status: "accepted")

      expect(eva.accepted_friends).to include(ami)
    end

    it "ne retourne pas les demandes en attente" do
      eva = create(:user)
      ami = create(:user)
      create(:friendship, requester: eva, receiver: ami, status: "pending")

      expect(eva.accepted_friends).not_to include(ami)
    end

    it "retourne les amis dans les deux sens" do
      eva = create(:user)
      ami = create(:user)
      create(:friendship, requester: ami, receiver: eva, status: "accepted")

      expect(eva.accepted_friends).to include(ami)
    end
  end

  describe "suppression du compte" do
    let(:eva) { create(:user) }
    let(:bob) { create(:user) }
    let(:alice) { create(:user) }

    def collection_owned_by(owner, members: [])
      Collection.create!(title: "Collec", category: "books").tap do |collection|
        UserCollection.create!(user: owner, collection: collection, role: "owner")
        # Le premier membre de la liste est le plus ancien
        members.each_with_index do |member, i|
          UserCollection.create!(user: member, collection: collection, role: "member", created_at: (10 - i).days.ago)
        end
      end
    end

    it "supprime ses notes, événements et amitiés" do
      create(:note, user: eva)
      create(:event, user: eva)
      create(:friendship, requester: eva, receiver: bob)
      expect { eva.destroy! }.not_to raise_error
      expect(Note.where(user_id: eva.id)).to be_empty
      expect(Friendship.count).to eq(0)
    end

    it "garde les notes partagées chez l'ami, sans expéditeur" do
      shared = create(:note, user: bob, sender: eva)
      eva.destroy!
      expect(shared.reload.sender_id).to be_nil
    end

    it "supprime une collection sans autre membre, avec ses items" do
      collection = collection_owned_by(eva)
      item = create(:item, collection: collection)
      eva.destroy!
      expect(Collection.exists?(collection.id)).to be false
      expect(Item.exists?(item.id)).to be false
    end

    it "transmet une collection partagée au plus ancien membre" do
      collection = collection_owned_by(eva, members: [ bob, alice ])
      item = create(:item, collection: collection)
      eva.destroy!
      expect(collection.reload.user_collections.find_by(user: bob).role).to eq("owner")
      expect(collection.user_collections.find_by(user: alice).role).to eq("member")
      expect(Item.exists?(item.id)).to be true
    end

    it "ne promeut personne s'il reste un autre propriétaire" do
      collection = collection_owned_by(eva, members: [ alice ])
      UserCollection.create!(user: bob, collection: collection, role: "owner")
      eva.destroy!
      expect(collection.reload.user_collections.find_by(user: alice).role).to eq("member")
    end

    it "ne touche pas aux collections dont il n'est que membre" do
      collection = collection_owned_by(bob, members: [ eva ])
      eva.destroy!
      expect(collection.reload.user_collections.pluck(:user_id)).to eq([ bob.id ])
    end
  end
end
