require "rails_helper"

RSpec.describe Friendship, type: :model do
  describe "associations" do
    it { should belong_to(:requester).class_name("User") }
    it { should belong_to(:receiver).class_name("User") }
  end

  describe "status" do
    it "peut être pending" do
      friendship = build(:friendship, status: "pending")
      expect(friendship.status).to eq("pending")
    end

    it "peut être accepted" do
      friendship = build(:friendship, status: "accepted")
      expect(friendship.status).to eq("accepted")
    end

    it "peut être rejected" do
      friendship = build(:friendship, status: "rejected")
      expect(friendship.status).to eq("rejected")
    end
  end

  describe "bidirectionnalité" do
    it "requester et receiver sont des users différents" do
      requester = create(:user)
      receiver = create(:user)
      friendship = build(:friendship, requester: requester, receiver: receiver)
      expect(friendship.requester).not_to eq(friendship.receiver)
    end
  end

  describe "unicité par paire" do
    let(:eva) { create(:user) }
    let(:ami) { create(:user) }
    before { create(:friendship, requester: eva, receiver: ami) }

    it "refuse un doublon dans le même sens" do
      expect(build(:friendship, requester: eva, receiver: ami)).not_to be_valid
    end

    it "refuse un doublon dans le sens inverse" do
      expect(build(:friendship, requester: ami, receiver: eva)).not_to be_valid
    end

    it "est garantie par la base, même sans passer par les validations" do
      expect {
        Friendship.insert_all!([{ requester_id: ami.id, receiver_id: eva.id, status: "pending", created_at: Time.current, updated_at: Time.current }])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "refuse l'amitié avec soi-même" do
      expect(build(:friendship, requester: eva, receiver: eva)).not_to be_valid
    end

    it ".between trouve l'amitié dans les deux sens" do
      expect(Friendship.between(ami, eva).count).to eq(1)
    end
  end
end
