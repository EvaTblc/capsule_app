require "rails_helper"

RSpec.describe Product, type: :model do
  describe "associations" do
    it { should have_many(:barcode_products) }
    it { should have_many(:items) }
  end

  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:fetched_at) }

    it "refuse un type inconnu, sans lever d'exception" do
      product = build(:product, kind: "music")
      expect(product).not_to be_valid
      expect(product.errors[:kind]).to be_present
    end

    it "un identifiant externe n'appartient qu'à une seule œuvre, mais plusieurs œuvres peuvent ne pas en avoir" do
      create(:product, igdb_id: 1560)
      expect(build(:product, igdb_id: 1560)).not_to be_valid
      expect { 2.times { create(:product, :book) } }.not_to raise_error
    end
  end

  describe "#stale?" do
    it "vrai au-delà de 6 mois : les données seront rafraîchies" do
      expect(build(:product, fetched_at: 7.months.ago)).to be_stale
      expect(build(:product, fetched_at: 5.months.ago)).not_to be_stale
    end
  end

  describe "suppression" do
    it "les boîtes et les items restent, sans référence vers l'œuvre" do
      product = create(:product)
      box = create(:barcode_product, product: product)
      item = create(:item, product: product)
      product.destroy!
      expect(box.reload.product).to be_nil
      expect(item.reload.product).to be_nil
    end
  end
end
