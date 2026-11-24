require "rails_helper"

RSpec.describe GameSummaryRecovery do
  include ActiveJob::TestHelper

  let(:collection) { Collection.create!(title: "Jeux", category: "video_games") }

  def game(title, product: nil, description: nil, summary_en: nil)
    Item.create!(title: title, collection: collection, product: product,
                 item_detailable: VideoGameDetail.create!(description: description, summary_en: summary_en))
  end

  let(:translated) { create(:product, igdb_id: 1, description: "Attrapez-les tous", details: { "summary_en" => "Catch them all" }) }
  let(:english_only) { create(:product, igdb_id: 2, details: { "summary_en" => "A wolf goddess" }) }
  let(:without_summary) { create(:product, igdb_id: 3, details: {}) }

  let!(:diamant) { game("Pokémon Diamant", product: translated) }
  let!(:okami) { game("Okami", product: english_only) }
  let!(:obscur) { game("Jeu obscur", product: without_summary) }

  it "ne retient que les jeux sans aucun résumé et reliés au catalogue" do
    game("Sans lien au catalogue")
    game("Déjà en français", product: english_only, description: "Une déesse louve")
    game("Traduction en attente", product: english_only, summary_en: "A wolf goddess")
    expect(described_class.candidates).to contain_exactly(diamant, okami, obscur)
  end

  it "mode essai : classe les jeux sans rien écrire ni mettre en file" do
    results = nil
    expect { results = described_class.run }.not_to have_enqueued_job
    expect(results.to_h { |result| [ result.item, result.status ] })
      .to eq(diamant => :copied_french, okami => :to_translate, obscur => :no_summary)
    expect(okami.item_detailable.reload.summary_en).to be_nil
  end

  it "APPLY : copie le français de l'œuvre sans traduction ; sinon l'anglais, puis traduction en arrière-plan" do
    expect { described_class.run(apply: true) }.to have_enqueued_job(TranslationJob).with(okami.id).exactly(:once)
    expect(diamant.item_detailable.reload).to have_attributes(description: "Attrapez-les tous", summary_en: "Catch them all")
    expect(okami.item_detailable.reload).to have_attributes(summary_en: "A wolf goddess", description: nil)
    expect(obscur.item_detailable.reload).to have_attributes(summary_en: nil, description: nil)
  end

  it "relançable : une fois les résumés rendus, plus rien à faire" do
    described_class.run(apply: true)
    expect(described_class.candidates.map(&:title)).to eq([ "Jeu obscur" ])
  end
end
