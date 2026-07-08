require "rails_helper"

RSpec.describe Event, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:sender).optional }
  end

  describe "reminder" do
    it "est false par défaut" do
      event = build(:event)
      expect(event.reminder).to eq(false)
    end

    it "peut être true" do
      event = build(:event, reminder: true)
      expect(event.reminder).to eq(true)
    end
  end

  describe "date" do
    it "peut être nil" do
      event = build(:event, date: nil)
      expect(event.date).to be_nil
    end

    it "accepte une date future" do
      event = build(:event, date: 7.days.from_now.to_date)
      expect(event.date).to eq(7.days.from_now.to_date)
    end
  end

  describe "geocoding" do
    it "a latitude et longitude nil sans adresse" do
      event = build(:event, address: nil, latitude: nil, longitude: nil)
      expect(event.latitude).to be_nil
      expect(event.longitude).to be_nil
    end
  end
end
