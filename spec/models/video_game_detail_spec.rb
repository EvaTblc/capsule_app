require "rails_helper"

RSpec.describe VideoGameDetail, type: :model do
  describe "associations" do
    it "peut avoir un item associé" do
      detail = create(:video_game_detail)
      item = create(:item, item_detailable: detail, item_detailable_type: "VideoGameDetail")
      expect(detail.item).to eq(item)
    end
  end

  describe "validations release_date" do
    it "est valide sans release_date" do
      detail = build(:video_game_detail, release_date: nil)
      expect(detail).to be_valid
    end

    it "est valide avec une année correcte" do
      detail = build(:video_game_detail, release_date: 2024)
      expect(detail).to be_valid
    end

    it "est invalide avec une année avant 1900" do
      detail = build(:video_game_detail, release_date: 1850)
      expect(detail).not_to be_valid
    end

    it "est invalide avec un nombre qui n'est pas sur 4 chiffres" do
      detail = build(:video_game_detail, release_date: 24)
      expect(detail).not_to be_valid
    end

    it "est invalide avec un decimal" do
      detail = build(:video_game_detail, release_date: 2024.5)
      expect(detail).not_to be_valid
    end
  end

  describe "validations platform" do
    it "est valide avec une plateforme de l'appli, des boutons comme de la liste" do
      expect(build(:video_game_detail, platform: "Switch 2")).to be_valid
      expect(build(:video_game_detail, platform: "Game Boy Advance")).to be_valid
    end

    it "est valide sans plateforme" do
      expect(build(:video_game_detail, platform: nil)).to be_valid
      expect(build(:video_game_detail, platform: "")).to be_valid
    end

    it "est invalide avec un nom IGDB ou une liste de plateformes" do
      expect(build(:video_game_detail, platform: "Nintendo Switch")).not_to be_valid
      expect(build(:video_game_detail, platform: "Wii U, Game Boy Advance")).not_to be_valid
    end
  end
end
