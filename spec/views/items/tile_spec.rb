require "rails_helper"

RSpec.describe "items/_tile", type: :view do
  let(:collection) { Collection.create!(title: "Ma collec", category: "mixed") }

  def tile_for(detail, title: "Un titre")
    item = Item.create!(title: title, collection: collection, item_detailable: detail)
    render partial: "items/tile", locals: { item: item }
    rendered
  end

  it "sans photo : une vignette générique pour chaque type d'item" do
    {
      BookDetail.create!(author: "Albert Camus") => "Albert Camus",
      VideoGameDetail.create!(platform: "Switch") => "background: #dc2626",
      MovieDetail.create!(format: "Blu-ray", year: 2010) => "Blu-ray",
      MusicDetail.create!(artist: "IAM", format: "CD") => "IAM",
      FigurineDetail.create!(manufacturer: "Funko", edition: "Standard", condition_box: "Neuf") => "Funko",
      TcgDetail.create!(card_set: "Alpha", card_number: "#232") => "#232",
      BoardGameDetail.create!(publisher: "Kosmos", min_players: 3, max_players: 4) => "3–4 joueurs"
    }.each do |detail, expected|
      html = tile_for(detail, title: "Titre #{detail.class.name}")
      expect(html).to include("Titre #{detail.class.name}", expected)
      expect(html).not_to include("<img")
    end
  end

  it "avec photo : la photo, pas la vignette générique" do
    item = Item.create!(title: "Pokémon Diamant", collection: collection, item_detailable: VideoGameDetail.create!(platform: "Nintendo DS"))
    item.images.attach(io: File.open(Rails.root.join("spec/fixtures/files/figurine.jpg")), filename: "photo.jpg", content_type: "image/jpeg")
    render partial: "items/tile", locals: { item: item }
    expect(rendered).to include("<img")
    expect(rendered).to include("/rails/active_storage/representations/") # vignette réduite, pas la photo d'origine
    expect(rendered).not_to include("NINTENDO DS", "Nintendo DS")
  end

  it "jeu relié au catalogue sans photo : sa jaquette IGDB ; avec photo : la photo d'abord" do
    product = create(:product, igdb_id: 1560, details: { "cover_image_id" => "co2a8w" })
    item = Item.create!(title: "Pokémon Diamant", collection: collection, product: product,
                        item_detailable: VideoGameDetail.create!(platform: "Nintendo DS"))
    render partial: "items/tile", locals: { item: item }
    expect(rendered).to include("https://images.igdb.com/igdb/image/upload/t_cover_big/co2a8w.jpg")
    expect(rendered).not_to include("NINTENDO DS", "Nintendo DS")

    item.images.attach(io: File.open(Rails.root.join("spec/fixtures/files/figurine.jpg")), filename: "photo.jpg", content_type: "image/jpeg")
    render partial: "items/tile", locals: { item: item }
    expect(rendered).not_to include("images.igdb.com")
  end

  it "badge « Complet » pour un jeu complet, rien pour un jeu incomplet" do
    expect(tile_for(VideoGameDetail.create!(completed: true))).to include("Complet")
    expect(tile_for(VideoGameDetail.create!(completed: false))).not_to include("Complet")
  end
end
