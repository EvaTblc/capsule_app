require "rails_helper"

RSpec.describe BarcodeProduct, type: :model do
  describe "associations" do
    it { should belong_to(:product).optional }
    it { should belong_to(:confirmed_by).class_name("User").optional }
  end

  describe "code-barres" do
    it "est ramené à 13 chiffres : la même boîte lue en UPC (12) ou en EAN (13) n'existe qu'une fois" do
      box = create(:barcode_product, barcode: "045496464851")
      expect(box.barcode).to eq("0045496464851")
      expect(build(:barcode_product, barcode: "0045496464851")).not_to be_valid
    end

    it "retire espaces et tirets" do
      expect(build(:barcode_product, barcode: " 0-045496-464851 ").barcode).to eq("0045496464851")
    end

    it "une recherche avec le code à 12 chiffres trouve la boîte enregistrée sur 13" do
      box = create(:barcode_product, barcode: "0045496464851")
      expect(described_class.find_by(barcode: "045496464851")).to eq(box)
    end

    it "refuse un code de plus de 13 chiffres (GTIN-14)" do
      expect(build(:barcode_product, barcode: "10045496464851")).not_to be_valid
    end
  end

  it "refuse un type ou une source inconnus, sans lever d'exception" do
    box = build(:barcode_product, kind: "music", source: "amazon")
    expect(box).not_to be_valid
    expect(box.errors.attribute_names).to include(:kind, :source)
  end

  it { should validate_presence_of(:fetched_at) }

  describe "#confirm!" do
    let(:box) { create(:barcode_product) }
    let(:eva) { create(:user) }
    let(:bob) { create(:user) }

    it "relie la boîte à l'œuvre, avec la date et l'auteur de la validation" do
      diamant = create(:product)
      box.confirm!(diamant, by: eva)
      expect(box.reload).to have_attributes(product: diamant, confirmed_by: eva, confirmed_at: be_within(1.second).of(Time.current))
    end

    it "la dernière validation gagne (correction d'une erreur)" do
      box.confirm!(create(:product, title: "Pokémon Perle"), by: eva)
      diamant = create(:product)
      box.confirm!(diamant, by: bob)
      expect(box.reload).to have_attributes(product: diamant, confirmed_by: bob)
      expect(eva.confirmed_barcode_products).to be_empty
      expect(bob.confirmed_barcode_products).to eq([ box ])
    end

    it "suppression du compte qui a validé : la boîte garde son œuvre, sans auteur" do
      diamant = create(:product)
      box.confirm!(diamant, by: eva)
      eva.destroy!
      expect(box.reload).to have_attributes(product: diamant, confirmed_by: nil)
    end
  end
end
