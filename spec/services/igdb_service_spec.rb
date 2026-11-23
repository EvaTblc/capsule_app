require "rails_helper"

RSpec.describe IgdbService do
  describe ".cover_ids" do
    it "une requête pour tous les jeux ; ceux sans jaquette sont absents" do
      expect(described_class).to receive(:post)
        .with("games", "fields cover.image_id; where id = (1560,77); limit 500;")
        .and_return([ { "id" => 1560, "cover" => { "image_id" => "co2a8w" } }, { "id" => 77 } ])
      expect(described_class.cover_ids([ 1560, "77", 1560 ])).to eq(1560 => "co2a8w")
    end

    it "IGDB ne répond pas : nil ; aucun jeu : {} sans requête" do
      allow(described_class).to receive(:post).and_return(nil)
      expect(described_class.cover_ids([ 1 ])).to be_nil
      expect(described_class.cover_ids([])).to eq({})
    end
  end

  it ".cover_url : adresse du serveur d'images d'IGDB, rien pour un identifiant douteux" do
    expect(described_class.cover_url("co2a8w")).to eq("https://images.igdb.com/igdb/image/upload/t_cover_big/co2a8w.jpg")
    expect(described_class.cover_url("../../x")).to be_nil
    expect(described_class.cover_url(nil)).to be_nil
  end
end
