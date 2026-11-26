require "rails_helper"

RSpec.describe EventsHelper, type: :helper do
  it "dit quand a lieu l'événement, par rapport à aujourd'hui" do
    travel_to Date.new(2026, 11, 26) do
      expect(helper.event_countdown(Date.new(2026, 11, 26))).to eq("aujourd'hui")
      expect(helper.event_countdown(Date.new(2026, 11, 27))).to eq("demain")
      expect(helper.event_countdown(Date.new(2026, 12, 1))).to eq("dans 5 jours")
      expect(helper.event_countdown(Date.new(2026, 11, 25))).to eq("hier")
      expect(helper.event_countdown(Date.new(2026, 11, 23))).to eq("il y a 3 jours")
    end
  end
end
