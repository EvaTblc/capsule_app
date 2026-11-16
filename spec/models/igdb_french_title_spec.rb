require "rails_helper"

RSpec.describe IgdbFrenchTitle do
  it "range le titre sans accents ni majuscules, et le suit quand il change" do
    title = described_class.create!(igdb_id: 1, igdb_game_id: 10, name: "Pokémon Épée")
    expect(title.normalized_name).to eq("pokemon epee")

    title.update!(name: "Zelda : Les Larmes du Royaume")
    expect(title.normalized_name).to eq("zelda les larmes du royaume")
  end

  describe ".sync" do
    def page(range) = range.map { |i| { "id" => i, "game" => i + 1000, "name" => "Jeu #{i}" } }

    it "récupère les titres page par page (500 au plus), sans doublon quand on la relance" do
      allow(IgdbService).to receive(:post) do |endpoint, body|
        expect(endpoint).to eq("alternative_names")
        expect(body).to include('where comment = "French title"', "sort id asc")
        body.include?("offset 0;") ? page(1..500) : page(501..503)
      end

      expect(described_class.sync).to eq(503)
      expect(described_class.sync).to eq(503)
      expect(described_class.find_by(igdb_id: 501)).to have_attributes(igdb_game_id: 1501, name: "Jeu 501")
    end

    it "met à jour un titre corrigé chez IGDB" do
      described_class.create!(igdb_id: 1, igdb_game_id: 10, name: "Pokemon Epee")
      allow(IgdbService).to receive(:post).and_return([ { "id" => 1, "game" => 10, "name" => "Pokémon Épée" } ])
      described_class.sync
      expect(described_class.find_by(igdb_id: 1).name).to eq("Pokémon Épée")
    end

    it "IGDB ne répond pas : erreur, plutôt qu'une synchronisation incomplète qui passerait pour réussie" do
      allow(IgdbService).to receive(:post).and_return(nil)
      expect { described_class.sync }.to raise_error(RuntimeError, /IGDB n'a pas répondu/)
    end
  end
end
