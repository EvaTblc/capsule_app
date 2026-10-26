require "rails_helper"

RSpec.describe ApplicationHelper, "#mapbox_public_token", type: :helper do
  def stub_mapbox(**keys)
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:mapbox, :public_token).and_return(keys[:public_token])
    allow(Rails.application.credentials).to receive(:dig).with(:mapbox, :api_key).and_return(keys[:api_key])
  end

  it "utilise le token public restreint quand il existe" do
    stub_mapbox(public_token: "pk.restreint", api_key: "pk.ancien")
    expect(helper.mapbox_public_token).to eq("pk.restreint")
  end

  it "se replie sur l'ancien token tant que le nouveau n'est pas configuré (rien ne casse)" do
    stub_mapbox(public_token: nil, api_key: "pk.ancien")
    expect(helper.mapbox_public_token).to eq("pk.ancien")
  end
end
