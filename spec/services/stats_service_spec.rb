require "rails_helper"

RSpec.describe StatsService do

  describe ".call" do
    context "stats communces - condition" do
      it "retourne le % par condition" do
        collection = create(:collection, category: "video_games")
        detail1 = create(:video_game_detail, completed: true)
        detail2 = create(:video_game_detail, completed: true)
        detail3 = create(:video_game_detail, completed: true)
        create(:item, collection: collection, item_detailable: detail1, item_detailable_type: "VideoGameDetail", condition: "Neuf")
        create(:item, collection: collection, item_detailable: detail2, item_detailable_type: "VideoGameDetail", condition: "Bon Etat")
        create(:item, collection: collection, item_detailable: detail3, item_detailable_type: "VideoGameDetail", condition: "Mauvais")
        result =  StatsService.call(collection)
        expect(result[:condition]["Neuf"]).to eq(33)
        expect(result[:condition]["Bon Etat"]).to eq(33)
        expect(result[:condition]["Mauvais"]).to eq(33)
      end
    end

    context "stats JV - jeux complets" do
      it "retourne le % de jeux complets" do
        collection = create(:collection, category: "video_games")
        detail1 = create(:video_game_detail, completed: true)
        detail2 = create(:video_game_detail, completed: true)
        detail3 = create(:video_game_detail, completed: false)
        create(:item, collection: collection, item_detailable: detail1, item_detailable_type: "VideoGameDetail", condition: "Neuf")
        create(:item, collection: collection, item_detailable: detail2, item_detailable_type: "VideoGameDetail", condition: "Bon Etat")
        create(:item, collection: collection, item_detailable: detail3, item_detailable_type: "VideoGameDetail", condition: "Mauvais")

        result =  StatsService.call(collection)
        expect(result[:completed]).to eq(66)
      end
    end
  end
end
