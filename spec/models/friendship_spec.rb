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
end
