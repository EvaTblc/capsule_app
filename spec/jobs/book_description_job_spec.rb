require "rails_helper"

RSpec.describe BookDescriptionJob, type: :job do
  include ActiveJob::TestHelper

  let(:detail) { create(:book_detail, author: "Frank Herbert", description: nil) }
  let(:item) { create(:item, title: "Dune", item_detailable: detail) }

  it "remplit la description générée" do
    expect(BookDescriptionService).to receive(:generate)
      .with(title: "Dune", author: "Frank Herbert", isbn: anything).and_return("Un classique.")
    BookDescriptionJob.perform_now(item.id)
    expect(detail.reload.description).to eq("Un classique.")
  end

  it "ne remplace pas une description existante" do
    detail.update!(description: "Déjà là")
    expect(BookDescriptionService).not_to receive(:generate)
    BookDescriptionJob.perform_now(item.id)
  end

  it "résumé généré gardé sur l'œuvre : les prochains ajouts de ce livre le reprendront" do
    product = create(:product, :book, wikidata_id: "Q123")
    item.update!(product: product)
    allow(BookDescriptionService).to receive(:generate).and_return("Un classique.")
    BookDescriptionJob.perform_now(item.id)
    expect(product.reload).to have_attributes(description: "Un classique.", description_source: "claude_generated")
  end

  it "œuvre qui a déjà un résumé (Wikipédia, ou généré pour quelqu'un d'autre) : repris, sans appel à Claude" do
    item.update!(product: create(:product, :book, wikidata_id: "Q123", description: "Résumé de Wikipédia"))
    expect(BookDescriptionService).not_to receive(:generate)
    BookDescriptionJob.perform_now(item.id)
    expect(detail.reload.description).to eq("Résumé de Wikipédia")
  end

  it "se reprogramme si l'API échoue" do
    allow(BookDescriptionService).to receive(:generate).and_raise(AnthropicClient::Error, "overloaded")
    expect { BookDescriptionJob.perform_now(item.id) }.to have_enqueued_job(BookDescriptionJob)
  end
end
