require "rails_helper"

RSpec.describe EstimationService do
  describe ".estimate" do
    let(:user) { create(:user) }
    let(:collection) { create(:collection, category: "books") }
    let(:book_detail) { create(:book_detail, author: "Kamome Shirahama") }
    let(:item) { create(:item, title: "L'Atelier des Sorciers", collection: collection, item_detailable: book_detail, condition: "Très bon état") }

    context "quand l'API répond correctement" do
      it "retourne un prix et une explication" do
        allow(HTTP).to receive(:post).and_return(
          double(body: double(to_s: '{"content": [{"text": "{\"price\": \"10€ - 15€\", \"explanation\": \"Manga en bon état.\"}"}]}'))
        )

        result = EstimationService.estimate(item)
        expect(result["price"]).to eq("10€ - 15€")
        expect(result["explanation"]).to eq("Manga en bon état.")
      end
    end

    context "quand l'API retourne du JSON malformé" do
      it "retourne une estimation par défaut" do
        allow(HTTP).to receive(:post).and_return(
          double(body: double(to_s: '{"content": [{"text": "pas du json"}]}'))
        )

        result = EstimationService.estimate(item)
        expect(result["price"]).to eq("N/A")
        expect(result["explanation"]).to eq("Estimation indisponible")
      end
    end

    context "quand l'API échoue" do
      it "retourne une estimation par défaut" do
        allow(HTTP).to receive(:post).and_raise(StandardError)

        result = EstimationService.estimate(item)
        expect(result["price"]).to eq("N/A")
      end
    end
  end
end
