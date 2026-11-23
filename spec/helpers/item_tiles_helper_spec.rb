require "rails_helper"

RSpec.describe ItemTilesHelper, type: :helper do
  def item_with(detail)
    build(:item, item_detailable: detail, item_detailable_type: detail.class.name)
  end

  it "bandeau de plateforme : une couleur pour chaque plateforme de l'appli, une couleur neutre sinon" do
    missing = VideoGameDetail::PLATFORMS - ItemTilesHelper::PLATFORM_BANDS.keys - [ "Atari", "Autres" ]
    expect(missing).to be_empty, "plateformes sans couleur : #{missing}"
    expect(helper.platform_band_color("Switch")).to eq("#dc2626")
    expect(helper.platform_band_color("Plateforme inconnue")).to eq(ItemTilesHelper::DEFAULT_BAND)
  end

  it "bandeau de film : une couleur pour chaque support de l'appli" do
    expect(MovieDetail::FORMATS - ItemTilesHelper::FORMAT_BANDS.keys).to be_empty
  end

  it "sous-titre : l'info la plus utile selon le type, sans les champs vides" do
    expect(helper.item_tile_subtitle(item_with(VideoGameDetail.new(platform: "Switch")))).to eq("Switch")
    expect(helper.item_tile_subtitle(item_with(BookDetail.new(author: "Albert Camus")))).to eq("Albert Camus")
    expect(helper.item_tile_subtitle(item_with(MovieDetail.new(format: "Blu-ray", year: 2010)))).to eq("Blu-ray · 2010")
    expect(helper.item_tile_subtitle(item_with(MusicDetail.new(artist: "IAM", format: "")))).to eq("IAM")
    expect(helper.item_tile_subtitle(item_with(TcgDetail.new(card_set: "Alpha", card_number: "#232")))).to eq("Alpha · #232")
    expect(helper.item_tile_subtitle(item_with(BoardGameDetail.new))).to be_nil
  end

  it "jaquette IGDB : seulement pour un jeu relié au catalogue qui en a une" do
    game = build(:product, igdb_id: 1560, details: { "cover_image_id" => "co2a8w" })
    item = item_with(VideoGameDetail.new).tap { |i| i.product = game }
    expect(helper.item_cover_url(item)).to eq("https://images.igdb.com/igdb/image/upload/t_cover_big/co2a8w.jpg")
    expect(helper.item_cover_url(item, size: :cover_small)).to include("/t_cover_small/")
    expect(helper.item_cover_url(item_with(VideoGameDetail.new))).to be_nil
    game.details = { "cover_image_id" => "../x" }
    expect(helper.item_cover_url(item)).to be_nil
  end

  it "badge : seulement une info positive" do
    expect(helper.item_tile_badge(item_with(VideoGameDetail.new(completed: true)))).to eq("Complet")
    expect(helper.item_tile_badge(item_with(VideoGameDetail.new(completed: false)))).to be_nil
    expect(helper.item_tile_badge(item_with(FigurineDetail.new(is_complete: true)))).to eq("Complète")
    expect(helper.item_tile_badge(item_with(BookDetail.new))).to be_nil
  end

  it "nombre de joueurs" do
    expect(helper.board_game_players(BoardGameDetail.new(min_players: 2, max_players: 5))).to eq("2–5 joueurs")
    expect(helper.board_game_players(BoardGameDetail.new(min_players: 2, max_players: 2))).to eq("2 joueurs")
    expect(helper.board_game_players(BoardGameDetail.new(max_players: 1))).to eq("1 joueur")
    expect(helper.board_game_players(BoardGameDetail.new)).to be_nil
  end
end
