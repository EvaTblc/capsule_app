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
end
