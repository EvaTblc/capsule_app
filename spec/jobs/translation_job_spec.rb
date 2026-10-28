require "rails_helper"

RSpec.describe TranslationJob do
  let(:detail) { create(:video_game_detail, summary_en: "Catch them all", description: nil) }
  let(:item) { create(:item, item_detailable: detail, item_detailable_type: "VideoGameDetail") }

  it "traduit le résumé de l'item" do
    allow(TranslationService).to receive(:translate_batch).and_return([ "Attrapez-les tous" ])
    described_class.perform_now(item.id)
    expect(detail.reload.description).to eq("Attrapez-les tous")
  end

  it "item relié à une œuvre sans traduction : la traduction est gardée sur l'œuvre, pour tout le monde" do
    product = create(:product)
    item.update!(product: product)
    allow(TranslationService).to receive(:translate_batch).and_return([ "Attrapez-les tous" ])
    described_class.perform_now(item.id)
    expect(product.reload).to have_attributes(description: "Attrapez-les tous", description_source: "igdb_translated")
  end

  it "œuvre déjà traduite entre-temps (pour quelqu'un d'autre) : reprise, sans appel à Claude" do
    item.update!(product: create(:product, description: "Attrapez-les tous"))
    expect(TranslationService).not_to receive(:translate_batch)
    described_class.perform_now(item.id)
    expect(detail.reload.description).to eq("Attrapez-les tous")
  end

  it "description déjà présente : rien à faire" do
    detail.update!(description: "Ma description")
    expect(TranslationService).not_to receive(:translate_batch)
    described_class.perform_now(item.id)
    expect(detail.reload.description).to eq("Ma description")
  end
end
