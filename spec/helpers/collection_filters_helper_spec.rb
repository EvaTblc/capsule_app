require "rails_helper"

RSpec.describe CollectionFiltersHelper, type: :helper do
  def item_with(detail, title: "Un titre")
    build(:item, title: title, item_detailable: detail, item_detailable_type: detail.class.name)
  end

  it "filtre rapide selon la catégorie (plateforme, format, type d'item pour « Divers »)" do
    expect(helper.item_facet(item_with(VideoGameDetail.new(platform: "Switch")), "video_games")).to eq("Switch")
    expect(helper.item_facet(item_with(MovieDetail.new(format: "DVD")), "movies")).to eq("DVD")
    expect(helper.item_facet(item_with(BookDetail.new), "mixed")).to eq("Livre")
    expect(helper.item_facet(item_with(BoardGameDetail.new), "board_games")).to be_nil
  end

  it "valeurs des filtres : sans doublon, ordre naturel, rien s'il n'y a qu'un seul choix" do
    items = [ "PS5", "Switch", "PS5", nil ].map { |platform| item_with(VideoGameDetail.new(platform: platform)) }
    expect(helper.collection_facets(items, "video_games")).to eq([ "PS5", "Switch" ])
    expect(helper.collection_facets(items.first(1), "video_games")).to eq([])
  end

  it "tris proposés : titre, ajout, puis le critère de la catégorie s'il existe" do
    expect(helper.collection_sort_options("books").map(&:last)).to eq(%w[title recent secondary])
    expect(helper.collection_sort_options("books").last.first).to eq("Auteur")
    expect(helper.collection_sort_options("board_games").map(&:last)).to eq(%w[title recent])
  end

  it "texte de recherche : titre et info sous le titre, sans accents ni majuscules" do
    expect(helper.item_search_text(item_with(BookDetail.new(author: "Albert Camus"), title: "L'Étranger"))).to eq("l'etranger albert camus")
  end
end
