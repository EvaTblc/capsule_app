require "rails_helper"

RSpec.describe ApplicationHelper, "#mapbox_public_token", type: :helper do
  it "renvoie le token public de la carte (restreint aux URL du site chez Mapbox)" do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:mapbox, :public_token).and_return("pk.carte")
    expect(helper.mapbox_public_token).to eq("pk.carte")
  end
end

RSpec.describe ApplicationHelper, type: :helper do
  it "items_count : pluriel à la française (0 et 1 au singulier)" do
    expect([ 0, 1, 2, 13 ].map { |count| helper.items_count(count) }).to eq([ "0 item", "1 item", "2 items", "13 items" ])
  end

  it "category_label : chaque catégorie de collection a un nom français" do
    Collection::CATEGORIES.each do |category|
      expect(I18n.exists?("categories.#{category}")).to be(true), "catégorie sans traduction : #{category}"
    end
    expect(helper.category_label("video_games")).to eq("Jeux vidéo")
  end

  it "item_type_label : chaque type d'item a un nom français" do
    Item::TYPE_TO_ICON.each_key do |type|
      expect(I18n.exists?("item_types.#{type}")).to be(true), "type sans traduction : #{type}"
    end
    expect(helper.item_type_label("BoardGameDetail")).to eq("Jeu de société")
  end

  it "fiche d'item : chaque champ affiché a un libellé français" do
    Item::TYPE_TO_ICON.each_key do |type|
      fields = type.constantize.column_names - %w[id created_at updated_at summary_en]
      missing = fields.reject { |field| I18n.exists?("show.#{type.underscore}.#{field}") }
      expect(missing).to be_empty, "#{type} : champs sans libellé #{missing}"
    end
  end
end
