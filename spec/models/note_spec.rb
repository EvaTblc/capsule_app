require "rails_helper"

RSpec.describe Note, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:collection).optional }
  end

  describe "reminder" do
    it "est false par défaut" do
      note = build(:note)
      expect(note.reminder).to eq(false)
    end

    it "peut être true" do
      note = build(:note, reminder: true)
      expect(note.reminder).to eq(true)
    end
  end

  describe "associations avec collection" do
    it "peut exister sans collection" do
      note = build(:note, collection: nil)
      expect(note).to be_valid
    end

    it "peut être liée à une collection" do
      collection = create(:collection)
      note = build(:note, collection: collection)
      expect(note.collection).to eq(collection)
    end
  end
end
