require "rails_helper"

RSpec.describe ApplicationHelper, "#mapbox_public_token", type: :helper do
  it "renvoie le token public de la carte (restreint aux URL du site chez Mapbox)" do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:mapbox, :public_token).and_return("pk.carte")
    expect(helper.mapbox_public_token).to eq("pk.carte")
  end
end
