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

  describe "#all_friends" do
    it "retourne les amis acceptés des deux côtés" do
      eva = create(:user)
      ami = create(:user)
      create(:friendship, requester: eva, receiver: ami, status: "accepted")

      expect(eva.all_friends).to include(ami)
    end

    it "ne retourne pas les demandes en attente" do
      eva = create(:user)
      ami = create(:user)
      create(:friendship, requester: eva, receiver: ami, status: "pending")

      expect(eva.all_friends).not_to include(ami)
    end

    it "retourne les amis dans les deux sens" do
      eva = create(:user)
      ami = create(:user)
      create(:friendship, requester: ami, receiver: eva, status: "accepted")

      expect(eva.all_friends).to include(ami)
    end
  end
end
