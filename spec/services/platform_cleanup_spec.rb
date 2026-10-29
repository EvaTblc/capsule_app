require "rails_helper"

RSpec.describe PlatformCleanup do
  describe ".verdict" do
    it "plateforme de l'appli, ou vide : rien à faire" do
      expect(described_class.verdict("Switch")).to eq([ :ok, "Switch" ])
      expect(described_class.verdict(nil)).to eq([ :ok, nil ])
      expect(described_class.verdict("")).to eq([ :ok, "" ])
    end

    it "nom IGDB : remplacé par la plateforme de l'appli" do
      expect(described_class.verdict("Nintendo Switch")).to eq([ :fix, "Switch" ])
      expect(described_class.verdict("Super Famicom")).to eq([ :fix, "Super Nintendo" ])
    end

    it "nom à la fois IGDB et de l'appli : déjà correct, pas touché" do
      expect(described_class.verdict("Wii")).to eq([ :ok, "Wii" ])
    end

    it "liste de plusieurs plateformes (ancien bug) : à corriger à la main" do
      expect(described_class.verdict("Wii U, Game Boy Advance")).to eq([ :list, "Wii U, Game Boy Advance" ])
    end

    it "inconnue : à corriger à la main" do
      expect(described_class.verdict("NES")).to eq([ :unknown, "NES" ])
    end
  end

  describe ".run" do
    let!(:correct) { create(:video_game_detail, platform: "PS5") }
    let!(:igdb) { create(:video_game_detail, platform: "Nintendo Switch") }
    let!(:list) { create(:video_game_detail, platform: "Wii U, Game Boy Advance") }

    it "mode essai (par défaut) : le verdict de chaque jeu, et rien n'est enregistré" do
      results = described_class.run

      expect(results).to contain_exactly([ correct, :ok, "PS5" ], [ igdb, :fix, "Switch" ], [ list, :list, "Wii U, Game Boy Advance" ])
      expect(igdb.reload.platform).to eq("Nintendo Switch")
    end

    it "apply: true : seuls les noms IGDB sont corrigés" do
      described_class.run(apply: true)

      expect(igdb.reload.platform).to eq("Switch")
      expect(correct.reload.platform).to eq("PS5")
      expect(list.reload.platform).to eq("Wii U, Game Boy Advance")
    end
  end
end
