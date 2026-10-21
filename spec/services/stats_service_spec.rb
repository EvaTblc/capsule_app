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
        create(:item, collection: collection, item_detailable: detail2, item_detailable_type: "VideoGameDetail", condition: "Bon état")
        create(:item, collection: collection, item_detailable: detail3, item_detailable_type: "VideoGameDetail", condition: "Mauvais état")
        result =  StatsService.call(collection)
        expect(result[:condition]["Neuf"]).to eq(33)
        expect(result[:condition]["Bon état"]).to eq(33)
        expect(result[:condition]["Mauvais état"]).to eq(33)
      end
    end

    context "stats JV - jeux complets" do
      it "retourne le % de jeux complets" do
        collection = create(:collection, category: "video_games")
        detail1 = create(:video_game_detail, completed: true)
        detail2 = create(:video_game_detail, completed: true)
        detail3 = create(:video_game_detail, completed: false)
        create(:item, collection: collection, item_detailable: detail1, item_detailable_type: "VideoGameDetail", condition: "Neuf")
        create(:item, collection: collection, item_detailable: detail2, item_detailable_type: "VideoGameDetail", condition: "Bon état")
        create(:item, collection: collection, item_detailable: detail3, item_detailable_type: "VideoGameDetail", condition: "Mauvais état")

        result =  StatsService.call(collection)
        expect(result[:completed]).to eq(66)
      end
    end

    context "collection de jeux vide" do
      it "ne plante pas (division par zéro) et renvoie completed nil" do
        collection = create(:collection, category: "video_games")
        expect(StatsService.call(collection)).to eq(condition: {}, completed: nil)
      end
    end

    context "performance" do
      it "fait un nombre de requêtes constant, quel que soit le nombre de jeux" do
        collection = create(:collection, category: "video_games")
        5.times do |i|
          create(:item, collection: collection, item_detailable: create(:video_game_detail, completed: i.even?),
                        item_detailable_type: "VideoGameDetail", condition: "Neuf")
        end

        queries = 0
        counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
        result = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { StatsService.call(collection) }

        expect(result).to eq(condition: { "Neuf" => 100 }, completed: 60)
        expect(queries).to be <= 4
      end
    end
  end
end
