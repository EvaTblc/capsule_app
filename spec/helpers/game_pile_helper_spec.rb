require "rails_helper"

RSpec.describe GamePileHelper, type: :helper do
  let(:collection) { create(:collection) }
  let(:zelda) { create(:product, igdb_id: 7346) }
  let(:mario) { create(:product, igdb_id: 1074) }

  def game(product, platform, in_collection: collection)
    create(:item, collection: in_collection, product: product,
                  item_detailable: create(:video_game_detail, platform: platform), item_detailable_type: "VideoGameDetail")
  end

  it "jeux de la collection reliés au catalogue, avec leurs plateformes (sans doublon ni plateforme vide)" do
    game(zelda, "Switch")
    game(zelda, "Wii U")
    game(zelda, "Switch")
    game(mario, nil)

    expect(helper.owned_games(collection)).to eq(7346 => [ "Switch", "Wii U" ], 1074 => [])
  end

  it "ignore les jeux non reliés au catalogue, les autres types d'items et les autres collections" do
    game(nil, "Switch")
    create(:item, collection: collection)
    game(zelda, "PS4", in_collection: create(:collection))

    expect(helper.owned_games(collection)).to eq({})
  end

  describe "wanted_games (alerte « Tu le cherches ! »)" do
    it "souhaits reliés au catalogue : identifiant du souhait, plateforme (nil pour « Peu importe »), prix à la française" do
      okami = create(:wish, collection: collection, product: zelda, platform: "Switch", max_price: "12.5")
      any = create(:wish, collection: collection, product: mario, platform: "", max_price: nil)

      expect(helper.wanted_games(collection)).to eq(
        7346 => [ { id: okami.id, platform: "Switch", max_price: "12,50 €" } ],
        1074 => [ { id: any.id, platform: nil, max_price: nil } ]
      )
    end

    it "ignore les souhaits tapés à la main (sans œuvre) et ceux des autres collections" do
      create(:wish, collection: collection, product: nil, title: "Introuvable")
      create(:wish, collection: create(:collection), product: zelda)
      expect(helper.wanted_games(collection)).to eq({})
    end
  end
end
